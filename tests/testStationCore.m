function tests = testStationCore
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    root = fileparts(fileparts(mfilename('fullpath')));
    testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
end

function testDefaultSimulation(testCase)
    result = runControlStation("simulation", durationSeconds=0.1, showUi=false, ...
        waitForNextCycle=false, saveRunLog=false);
    verifyEqual(testCase, result.status, "completed");
    verifyEqual(testCase, result.vehicleNames, "pi3");
    verifyTrue(testCase, all(result.odometryFresh(:)));
    verifyTrue(testCase, all(result.commandSent(:)));
    verifyEqual(testCase, result.stationConfig.controlRateHz, 20);
    verifyEqual(testCase, result.experimentConfig.controllerName, "@(vehicles)manual.commands(vehicles)");
    verifyEqual(testCase, result.vehicleSettings.commandSink, "rosDrive");
    verifyEqual(testCase, result.commands, zeros(size(result.commands)));
end

function testSelectedVelocitySimulationMoves(testCase)
    controller = @(vehicles) struct('katchaka', [0.1 0]); %#ok<NASGU>
    result = runControlStation("simulation", vehicleNames="katchaka", durationSeconds=0.2, ...
        controller=controller, showUi=false, waitForNextCycle=false, saveRunLog=false);
    verifyEqual(testCase, result.status, "completed");
    verifyGreaterThan(testCase, result.states(end,1,1), 2);
end

function testResolverRejectsInvalidSelection(testCase)
    catalog = shared.vehicleCatalog();
    experiment = shared.experimentConfig();
    stationSettings = shared.stationConfig();
    verifyError(testCase, @() shared.resolveVehicleSettings(catalog, experiment, ...
        stationSettings, "simulation", "missing"), 'Station:UnknownVehicle');
    verifyError(testCase, @() shared.resolveVehicleSettings(catalog, experiment, ...
        stationSettings, "simulation", ["pi1","pi1"]), 'Station:DuplicateVehicle');
end

function testInputChoicesAndPersistentMotiveMapping(testCase)
    catalog = shared.vehicleCatalog();
    experiment = shared.experimentConfig();
    stationSettings = shared.stationConfig();
    verifyEqual(testCase, string(fieldnames(catalog)), ...
        ["katchaka"; "pi1"; "pi2"; "pi3"]);
    settings = shared.resolveVehicleSettings(catalog, experiment, ...
        stationSettings, "simulation", "pi3");
    verifyEqual(testCase, settings.odometrySource, "otos");
    verifyEqual(testCase, settings.odometryInput.messageType, "geometry_msgs/Pose2D");
    verifyEqual(testCase, settings.odometryInput.topic, "/pi3/odometry/otos");
    verifyEqual(testCase, settings.initialState, [-1 0 0]);
    verifyEqual(testCase, settings.commandOutput.topic, "/pi3/rover_drive");
    verifyEqual(testCase, settings.motive.name, "pi3");
    experiment.vehicleSettings.pi3.odometrySource = "wheelOdometry";
    settings = shared.resolveVehicleSettings(catalog, experiment, ...
        stationSettings, "simulation", "pi3");
    verifyEqual(testCase, settings.odometryInput.topic, "/pi3/odometry/wheel");
    verifyEqual(testCase, settings.odometryInput.kind, "velocity");
    experiment.vehicleSettings.pi3.odometrySource = "motive";
    settings = shared.resolveVehicleSettings(catalog, experiment, ...
    stationSettings, "simulation", "pi3");
    verifyEqual(testCase, settings.odometryInput.topic, "/pi3/odometry/motive");
    verifyFalse(testCase, isfield(settings, 'coordinateMode'));
    experiment.vehicleSettings.pi3.coordinateMode = "global";
    verifyError(testCase, @() shared.resolveVehicleSettings(catalog, experiment, ...
        stationSettings, "simulation", "pi3"), 'Station:ObsoleteCoordinateMode');
end

function testOdometrySourceDeterminesCoordinates(testCase)
    experiment = shared.experimentConfig();
    experiment.vehicleSettings.pi3.initialState = [10 20 0];
    experiment.vehicleSettings.pi3.odometrySource = "otos";
    catalog = shared.vehicleCatalog();
    stationSettings = shared.stationConfig();
    settings = shared.resolveVehicleSettings(catalog, experiment, ...
        stationSettings, "simulation", "pi3");
    estimator = station.StateEstimator(settings, 1);
    % 採用前の測定ではなく、calibrate 時点の最新測定を初期位置に合わせる。
    estimator.accept(struct('number', 0, 'receivedAt', 0.5, ...
        'value', struct('position', [1;1], 'orientation', 0)));
    estimator.accept(struct('number', 1, 'receivedAt', 1, ...
        'value', struct('position', [3;4], 'orientation', pi/2)));
    estimator.calibrate(1);
    verifyEqual(testCase, estimator.snapshot(), [10 20 0 0 0], 'AbsTol', 1e-12);
    estimator.accept(struct('number', 2, 'receivedAt', 2, ...
        'value', struct('position', [3;5], 'orientation', pi/2)));
    estimator.update(1, 2);
    verifyEqual(testCase, estimator.position, [11;20], 'AbsTol', 1e-12);

    experiment.vehicleSettings.pi3.odometrySource = "motive";
    settings = shared.resolveVehicleSettings(catalog, experiment, ...
        stationSettings, "simulation", "pi3");
    estimator = station.StateEstimator(settings, 1);
    estimator.accept(struct('number', 1, 'receivedAt', 1, ...
        'value', struct('position', [3;4], 'orientation', pi/2)));
    estimator.calibrate(1);
    verifyEqual(testCase, estimator.snapshot(), [3 4 pi/2 0 0], 'AbsTol', 1e-12);

    catalog.pi3.odometrySources.unknownPosition = catalog.pi3.odometrySources.otos;
    experiment.vehicleSettings.pi3.odometrySource = "unknownPosition";
    verifyError(testCase, @() shared.resolveVehicleSettings( ...
        catalog, experiment, stationSettings, "simulation", "pi3"), ...
        'Station:UnknownSourceSemantics');
end

function testCommandBatchValidation(testCase)
    stationSettings = shared.stationConfig();
    names = ["pi1","pi2"];
    verifyError(testCase, @() station.validateCommands( ...
        struct('pi1',[0 0]), names, stationSettings), 'Station:InvalidCommands');
    verifyError(testCase, @() station.validateCommands( ...
        struct('pi1',[0 0], 'pi2',[NaN 0]), names, stationSettings), ...
        'Station:InvalidCommands');
    verifyError(testCase, @() station.validateCommands( ...
        struct('pi1',[0 0], 'pi2',[stationSettings.maxLinearVelocity+1 0]), ...
        names, stationSettings), 'Station:CommandLimit');
end

function testMouseControllerSendsOnlyToEnabledVehicles(testCase)
    vehicles = struct('pi1', [], 'pi2', [], 'pi3', []);
    commands = station.MouseController.buildCommands(vehicles, ...
        ["pi1", "pi3"], "forward", 0.05, 0.2);
    verifyEqual(testCase, commands.pi1, [0.05 0]);
    verifyEqual(testCase, commands.pi2, [0 0]);
    verifyEqual(testCase, commands.pi3, [0.05 0]);
    commands = station.MouseController.buildCommands(vehicles, ...
        ["pi1", "pi3"], "left", 0.05, 0.2);
    verifyEqual(testCase, commands.pi1, [0 0.2]);
    verifyEqual(testCase, commands.pi3, [0 0.2]);
    commands = station.MouseController.buildCommands(vehicles, ...
        ["pi1", "pi3"], "", 0.05, 0.2);
    verifyEqual(testCase, commands, station.stopController(vehicles));
end

function testMouseControllerWindowClosesAfterRun(testCase)
    manual = station.MouseController();
    cleanup = onCleanup(@() manual.close()); %#ok<NASGU>
    experiment = shared.experimentConfig();
    experiment.controller = @(vehicles) manual.commands(vehicles);
    experiment.cleanupController = @() manual.close();
    result = runControlStation("simulation", vehicleNames="pi3", durationSeconds=0.05, ...
        experimentConfig=experiment, showUi=false, waitForNextCycle=false, saveRunLog=false);
    verifyEqual(testCase, result.status, "completed");
    verifyEmpty(testCase, manual.figureHandle);
    verifyFalse(testCase, isfield(result.experimentConfig, 'cleanupController'));
end

function testMouseControllerButtonCallbacks(testCase)
    manual = station.MouseController();
    cleanup = onCleanup(@() manual.close()); %#ok<NASGU>
    vehicles = struct('pi3', []);
    verifyEqual(testCase, manual.commands(vehicles).pi3, [0 0]);
    selector = findobj(manual.figureHandle, 'Style', 'togglebutton');
    set(selector, 'Value', 1);
    callback = get(selector, 'Callback');
    callback(selector, []);
    buttons = findobj(manual.figureHandle, 'Style', 'pushbutton');
    forward = buttons(strcmp(string(get(buttons, 'String')), "前進"));
    verifyNumElements(testCase, forward, 1);
    callback = get(forward, 'ButtonDownFcn');
    callback(forward, []);
    commands = manual.commands(vehicles);
    verifyEqual(testCase, commands.pi3, [0.05 0]);
    callback = get(manual.figureHandle, 'WindowButtonUpFcn');
    callback(manual.figureHandle, []);
    verifyEqual(testCase, manual.commands(vehicles).pi3, [0 0]);
end

function testPositionMapShowsVehiclePoses(testCase)
    map = station.PositionMap(["pi1", "pi2"]);
    cleanup = onCleanup(@() map.close()); %#ok<NASGU>
    map.update(reshape([1 2 0 0 0 3 4 pi/2 0 0], 1, 5, 2));
    axisHandle = findobj(map.figureHandle, 'Type', 'axes');
    markers = findobj(axisHandle, 'Type', 'line', 'Marker', 'o');
    verifyNumElements(testCase, markers, 2);
    verifyEqual(testCase, sort([markers.XData]), [1 3]);
    verifyEqual(testCase, sort([markers.YData]), [2 4]);
    limits = ylim(axisHandle);
    verifyGreaterThan(testCase, limits(2), 4);
    map.close();
    verifyEmpty(testCase, map.figureHandle);
    map.update(reshape([1 2 0 0 0 3 4 pi/2 0 0], 1, 5, 2));
end

function testNatNetFrameAndMapping(testCase)
    raw = struct('ID', 5, 'x', 1, 'y', 2, 'z', 3, ...
        'qx', 0, 'qy', 0, 'qz', 0, 'qw', 1, 'Tracked', true);
    frame = struct('iFrame', 42, 'nRigidBodies', 1, 'RigidBodies', raw);
    decoded = bridge.decodeNatNetFrame(frame);
    verifyEqual(testCase, decoded.frameNumber, 42);
    verifyTrue(testCase, decoded.bodies(1).tracked);
    [position, quaternion] = bridge.MotiveCoordinateTransform.toRos( ...
        decoded.bodies(1).position, decoded.bodies(1).quaternion);
    verifyEqual(testCase, position, [1 -3 2]);
    verifyEqual(testCase, quaternion, [0 0 0 1], 'AbsTol', 1e-12);
    settings = shared.resolveVehicleSettings(shared.vehicleCatalog(), shared.experimentConfig(), ...
        shared.stationConfig(), "simulation", "pi1");
    model = struct('RigidBodyCount', 1, ...
        'RigidBody', struct('Name', 'pi1', 'ID', 5));
    mapping = bridge.resolveRigidBodyMappings(settings, model);
    verifyEqual(testCase, mapping.id, 5);
end

function testFailedControllerStillSavesRun(testCase)
    folder = testCase.applyFixture( ...
        matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
    stationSettings = shared.stationConfig();
    stationSettings.logDirectory = folder;
    badController = @(vehicles) struct('pi1', [NaN 0]); %#ok<NASGU>
    verifyError(testCase, @() runControlStation("simulation", vehicleNames="pi1", ...
        durationSeconds=0.05, controller=badController, ...
        stationConfig=stationSettings, showUi=false, waitForNextCycle=false), ...
        'Station:InvalidCommands');
    logs = dir(fullfile(folder, '*.mat'));
    verifyNumElements(testCase, logs, 1);
    saved = load(fullfile(logs(1).folder, logs(1).name));
    verifyEqual(testCase, saved.result.status, "error");
    verifyFalse(testCase, any(saved.result.commandSent(:)));
end
