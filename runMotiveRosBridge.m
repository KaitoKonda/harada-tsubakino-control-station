% runMotiveRosBridge：Motive ブリッジを始める入口。

function runMotiveRosBridge(station, experiment, selectedNames)
    % stationConfig、experimentConfig、vehicleCatalog を読み込む。
    if nargin < 1 || isempty(station), station = shared.stationConfig(); end
    if nargin < 2 || isempty(experiment), experiment = shared.experimentConfig(); end
    if nargin < 3, selectedNames = strings(0,1); end
    % resolveVehicleSettings を呼び、今回の車両設定を確定する。
    settings = shared.resolveVehicleSettings(shared.vehicleCatalog(), experiment, ...
        station, "bridge", selectedNames);
    % 状態入力として Motive を選んだ車両だけを取り出す。
    % 対象が一台もなければ、そのことを表示して接続せず終了する。
    usesMotive = arrayfun(@(s) s.odometrySource == "motive", settings);
    motiveSettings = settings(usesMotive);
    assert(~isempty(motiveSettings), 'Motive:NoMappings', ...
        'No selected vehicle uses Motive odometry.');
    % 対象の車両名、剛体名または ID、配信先トピックを一覧表示する。
    for vehicle = motiveSettings
        fprintf('%s: Motive %s (ID %g) -> %s\n', vehicle.name, ...
            vehicle.motive.name, vehicle.motive.id, vehicle.odometryInput.topic);
    end
    % 共有 ROS 接続を確認してから MotiveRosBridge を作る。
    % 作成に失敗したら、開きかけた資源を閉じてエラーの段階を示す。
    % 共有 ROS マスターは、他の利用者がいる可能性があるため勝手に止めない。
    shared.ensureRosSession(station.ros);
    bridgeInstance = bridge.MotiveRosBridge(station.motive, motiveSettings);
    % Ctrl+C、例外、通常終了のどれでもブリッジの close を一回試みる。
    cleanup = onCleanup(@() bridgeInstance.close()); %#ok<NASGU>
    % 成功したら Ctrl+C で止められることを表示する。
    fprintf('Motive bridge is running. Press Ctrl+C to stop.\n');
    % pollRateHz から次の更新時刻を求め、MotiveRosBridge.update を繰り返す。
    period = 1 / station.motive.pollRateHz;
    lastReport = tic;
    while true
        step = tic;
        % 取得できない状態が続いても、前の位置を新しい測定として送らない。
        stats = bridgeInstance.update();
        % 戻った取得数、対象数、配信数を一定間隔で表示する。
        if toc(lastReport) >= 1
            fprintf('frameNumber=%g receivedCount=%d matchedCount=%d trackedCount=%d publishedCount=%d invalidCount=%d\n', ...
                stats.frameNumber, stats.receivedCount, stats.matchedCount, ...
                stats.trackedCount, stats.publishedCount, stats.invalidCount);
            if stats.invalidCount > 0
                fprintf('  Invalid rigid bodies: %s\n', ...
                    strjoin(stats.invalidReasons, '; '));
            end
            lastReport = tic;
        end
        pause(max(0, period - toc(step)));
    end
end
