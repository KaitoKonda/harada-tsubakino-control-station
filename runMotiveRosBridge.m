% runMotiveRosBridge：Motive ブリッジを始める入口。
function runMotiveRosBridge(station, experiment, selectedNames)
    if nargin < 1 || isempty(station), station = shared.stationConfig(); end
    diagnostics = bridge.BridgeDiagnostics(station.motive, station.logDirectory);
    logCleanup = onCleanup(@() diagnostics.close()); %#ok<NASGU>
    stage = "configuration";
    try
        diagnostics.log('[START] NatNet client=%s server=%s type=%s', ...
            station.motive.clientIp, station.motive.serverIp, station.motive.connectionType);
        diagnostics.log('[START] ROS master=%s nodeHost=%s', station.ros.masterUri, station.ros.nodeHost);
        if nargin < 2 || isempty(experiment), experiment = shared.experimentConfig(); end
        if nargin < 3, selectedNames = strings(0,1); end
        settings = shared.resolveVehicleSettings(shared.vehicleCatalog(), experiment, ...
            station, "bridge", selectedNames);
        motiveSettings = settings(arrayfun(@(s) s.odometrySource == "motive", settings));
        assert(~isempty(motiveSettings), 'Motive:NoMappings', ...
            'No selected vehicle uses Motive odometry.');
        for vehicle = motiveSettings
            diagnostics.log('[REQUEST] vehicle=%s rigidBody=%s configuredID=%g topic=%s', ...
                vehicle.name, vehicle.motive.name, vehicle.motive.id, vehicle.odometryInput.topic);
        end
        stage = "ROS connection";
        shared.ensureRosSession(station.ros);
        diagnostics.log('[OK] ROS session ready');
        stage = "NatNet connection / model description";
        source = bridge.NatNetFrameSource(station.motive);
        sourceCleanup = onCleanup(@() closeResource(source, diagnostics)); %#ok<NASGU>
        diagnostics.log('[OK] NatNet connected');
        model = source.model;
        if isstruct(model) && isfield(model, 'RigidBodyCount') && isfield(model, 'RigidBody')
            diagnostics.log('[MODEL] rigidBodies=%d', model.RigidBodyCount);
            for index = 1:min(double(model.RigidBodyCount), numel(model.RigidBody))
                body = model.RigidBody(index);
                diagnostics.log('[MODEL] %s(ID=%g)', string(body.Name), double(body.ID));
            end
        end
        stage = "rigid-body mapping / ROS publishers";
        bridgeInstance = bridge.MotiveRosBridge(station.motive, motiveSettings, source);
        bridgeCleanup = onCleanup(@() closeResource(bridgeInstance, diagnostics)); %#ok<NASGU>
        diagnostics.configure(bridgeInstance.mappings);
        diagnostics.log('[READY] pollTarget=%gHz frameId=%s; published counts send() completions, not subscriber receipts. Press Ctrl+C to stop.', ...
            station.motive.pollRateHz, station.motive.frameId);
        period = 1 / station.motive.pollRateHz;
        while true
            step = tic;
            stage = "frame acquisition / decode / ROS publish";
            stats = bridgeInstance.update();
            stage = "diagnostics";
            diagnostics.observe(stats);
            pause(max(0, period - toc(step)));
        end
    catch exception
        diagnostics.logException(exception, stage);
        rethrow(exception)
    end

end

function closeResource(resource, diagnostics)
    % 匿名関数にハンドルを保持し、Ctrl+C・例外でも資源を解放する。
    % 共有 ROS セッションは停止しない。
    try
        resource.close();
    catch exception
        diagnostics.logException(exception, "cleanup");
    end
end
