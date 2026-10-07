function tests = testStationStartup
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    root = fileparts(fileparts(mfilename('fullpath')));
    testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
    testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'tests', 'helpers')));
end

function testSimulationWithRealUiRecordsStartupTiming(testCase)
    result = runControlStation("simulation", durationSeconds=0.1, ...
        controller=@station.stopController, showUi=true, ...
        waitForNextCycle=false, saveRunLog=false);
    verifyEqual(testCase, result.status, "completed");
    phases = [result.diagnostics.phase];
    verifyEqual(testCase, phases(1:2), ["uiInitialized", "initialMapDrawn"]);
    verifyGreaterThan(testCase, result.diagnostics(1).durationSeconds, 0);
    verifyTrue(testCase, all(result.odometryFresh(:)));
    fprintf('UI initialization: %.3f s, initial position draw: %.3f s\n', ...
        result.diagnostics(1).durationSeconds, result.diagnostics(2).durationSeconds);
end

function runner = makeRunner(testCase, saveLog)
    if nargin < 2, saveLog = false; end
    config = shared.stationConfig();
    if saveLog
        config.logDirectory = testCase.applyFixture( ...
            matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
    end
    config.durationSeconds = 0.1;
    config.connectionTimeoutSeconds = 0.4;
    experiment = shared.experimentConfig();
    experiment.controller = @station.stopController;
    settings = shared.resolveVehicleSettings(shared.vehicleCatalog(), experiment, ...
        config, "simulation", "katchaka");
    options = struct('showUi', true, 'waitForNextCycle', true, 'saveRunLog', saveLog);
    runner = StartupTestRunner(config, experiment, settings, options);
    testCase.addTeardown(@() delete(runner));
end

function testSlowFirstDrawWaitsForNewObservation(testCase)
    runner = makeRunner(testCase);
    runner.testMap.afterFirstDraw = @() delayNextSample(runner.testVehicle, 0.1);
    result = runner.run();
    verifyEqual(testCase, result.status, "completed");
    phases = [result.diagnostics.phase];
    drawing = result.diagnostics(phases == "initialMapDrawn");
    verifyGreaterThan(testCase, drawing.durationSeconds, 0.25);
    ready = result.diagnostics(phases == "ready");
    verifyGreaterThan(testCase, numel(ready), 1);
    verifyFalse(testCase, ready(1).vehicles.katchaka.fresh);
    verifyTrue(testCase, ready(end).vehicles.katchaka.fresh);
    verifyGreaterThan(testCase, ready(end).vehicles.katchaka.sampleNumber, ...
        ready(1).vehicles.katchaka.sampleNumber);
    verifyTrue(testCase, runner.testWindow.ready);
    verifyTrue(testCase, runner.testVehicle.closed);
    verifyEqual(testCase, runner.testVehicle.sent, zeros(size(runner.testVehicle.sent)));
end

function testNoNewSampleAfterDrawTimesOutWithStartDisabled(testCase)
    runner = makeRunner(testCase);
    % 期限内の古い測定でも、描画後の新測定の代わりにはしない。
    runner.testMap.firstDrawSeconds = 0;
    runner.testMap.afterFirstDraw = @() disableReception(runner.testVehicle);
    verifyError(testCase, @() runner.run(), 'Station:ConnectionTimeout');
    verifyFalse(testCase, runner.testWindow.ready);
    result = runner.logger.result;
    ready = result.diagnostics([result.diagnostics.phase] == "ready");
    verifyTrue(testCase, ready(1).vehicles.katchaka.fresh);
    verifyFalse(testCase, ready(end).vehicles.katchaka.fresh);
    verifyTrue(testCase, runner.testVehicle.closed);
    verifyEqual(testCase, runner.testVehicle.sent, zeros(size(runner.testVehicle.sent)));
end

function testStandbyLossStillStopsAndLogsFailedCycle(testCase)
    runner = makeRunner(testCase, true);
    runner.testWindow.autoStart = false;
    runner.testWindow.onReady = @() disableReception(runner.testVehicle);
    verifyError(testCase, @() runner.run(), 'Station:OdometryLost');
    result = runner.logger.result;
    saved = load(result.logFilePath, 'result');
    verifyEqual(testCase, saved.result.diagnostics, result.diagnostics);
    standby = result.diagnostics([result.diagnostics.phase] == "standby");
    details = standby(end).vehicles.katchaka;
    verifyFalse(testCase, details.fresh);
    verifyGreaterThan(testCase, details.ageSeconds, details.timeoutSeconds);
    verifyEmpty(testCase, result.elapsedSeconds);
    verifyTrue(testCase, runner.testVehicle.closed);
    verifyEqual(testCase, runner.testVehicle.sent, zeros(size(runner.testVehicle.sent)));
end

function testStopDuringReadinessCancels(testCase)
    runner = makeRunner(testCase);
    runner.testMap.afterFirstDraw = @() requestStop(runner.testWindow);
    result = runner.run();
    verifyEqual(testCase, result.status, "cancelled");
    verifyFalse(testCase, runner.testWindow.ready);
    verifyEmpty(testCase, result.elapsedSeconds);
    verifyTrue(testCase, runner.testVehicle.closed);
end

function testStartCannotBypassFreshnessCheck(testCase)
    runner = makeRunner(testCase);
    runner.testWindow.onReady = @() loseReceptionBeforeStart(runner.testVehicle);
    verifyError(testCase, @() runner.run(), 'Station:OdometryLost');
    verifyEmpty(testCase, runner.logger.result.elapsedSeconds);
end

function testRealWindowGuardsEarlyStartAndStop(testCase)
    window = station.StationWindow("experiment", "katchaka");
    testCase.addTeardown(@() delete(window));
    button = findobj(window.figureHandle, 'Style', 'pushbutton', 'String', 'Start');
    callback = get(button, 'Callback');
    verifyEqual(testCase, get(button, 'Enable'), 'off');
    callback(button, []);
    verifyFalse(testCase, window.isStarted());
    window.markReady();
    verifyEqual(testCase, get(button, 'Enable'), 'on');
    stop = findobj(window.figureHandle, 'Style', 'pushbutton', 'String', 'Stop');
    stopCallback = get(stop, 'Callback');
    stopCallback(stop, []);
    callback(button, []);
    verifyTrue(testCase, window.shouldStop());
    verifyFalse(testCase, window.isStarted());
end

function delayNextSample(vehicle, delay)
    vehicle.nextSampleAt = toc(vehicle.clock) + delay;
end

function disableReception(vehicle)
    vehicle.receiveEnabled = false;
end

function requestStop(window)
    window.stopRequested = true;
end

function loseReceptionBeforeStart(vehicle)
    disableReception(vehicle);
    pause(0.3);
end
