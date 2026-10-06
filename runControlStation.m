% runControlStation：制御ステーションを始める入口。

function result = runControlStation(mode, options)
    % 引数の mode を読む。省略されたら "simulation" とする。
    % mode が "simulation" と "experiment" のどちらでもなければ、
    % 設定や通信を触る前に、その値を示して終了する。
    % 名前付き引数の vehicleNames、durationSeconds、controller などを読み、
    arguments
        mode (1,1) string {mustBeMember(mode, ["simulation", "experiment"])} = "simulation"
        options.vehicleNames string = strings(0,1)
        options.durationSeconds = []
        options.controller = []
        options.showUi (1,1) logical = true
        options.waitForNextCycle (1,1) logical = true
        options.saveRunLog (1,1) logical = true
        options.stationConfig = []
        options.experimentConfig = []
    end
    % 実機モードで画面や実時間待ちを無効にする指定があれば終了する。
    assert(mode == "simulation" || (options.showUi && options.waitForNextCycle), ...
        'Station:ExperimentUIRequired', ...
        'Physical experiments require the start/stop window and real-time pacing.');
    % stationConfig、experimentConfig、vehicleCatalog を順に読む。
    if isempty(options.stationConfig)
        stationSettings = shared.stationConfig();
    else
        stationSettings = options.stationConfig;
    end
    if isempty(options.experimentConfig)
        experiment = shared.experimentConfig();
    else
        experiment = options.experimentConfig;
    end
    % vehicleNames が指定されていれば実験設定の車両一覧を今回だけ置き換える。
    % durationSeconds や controller も指定されていれば今回だけ置き換える。
    if ~isempty(options.durationSeconds), stationSettings.durationSeconds = options.durationSeconds; end
    if ~isempty(options.controller), experiment.controller = options.controller; end
    assert(isa(experiment.controller, 'function_handle'), ...
        'Station:InvalidController', 'Controller must be a function handle.');
    if isfield(experiment, 'cleanupController')
        assert(isa(experiment.cleanupController, 'function_handle'), ...
            'Station:InvalidController', ...
            'Controller cleanup must be a function handle.');
    end
    % resolveVehicleSettings に三つの設定を渡し、使う車両の設定を確定する。
    % 設定が不正なら、どの車両のどの項目かを表示して終了する。
    settings = shared.resolveVehicleSettings(shared.vehicleCatalog(), experiment, ...
        stationSettings, mode, options.vehicleNames);
    % mode、車両名、状態入力、指令先、予定時間を表示する。
    names = string({settings.name});
    fprintf('%s: %s, %.1f seconds\n', mode, ...
        strjoin(names, ', '), stationSettings.durationSeconds);
    for setting = settings
        fprintf('  %s: %s odometry -> %s command\n', ...
            setting.name, setting.odometryInput.protocol, setting.commandOutput.protocol);
    end
    % その確定済み設定で StationRunner を一つ作り、実行を頼む。
    % StationRunner から返った結果を、そのまま呼び出し元へ返す。
    % ここでは制御周期を回さず、ROS や UDP へ直接触れない。
    runner = station.StationRunner(mode, stationSettings, experiment, settings, options);
    result = runner.run();
end
