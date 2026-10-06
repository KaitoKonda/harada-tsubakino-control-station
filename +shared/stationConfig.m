% stationConfig：制御用 PC に共通の設定を作る。

function config = stationConfig()
    % まず空の設定を一つ作る。
    root = fileparts(fileparts(mfilename('fullpath')));
    % ROS マスターの URI と、車両側から到達できる PC のアドレスを入れる。
    % アドレスが未確認なら空欄のまま返す。推測した実機 IP は入れない。
    config.ros.masterUri = "http://localhost:11311";
    config.ros.nodeHost = "192.168.208.136"; % Set to the control PC address reachable by vehicles.
    % Motive PC の施設 LAN 側 IP と、この PC の施設 LAN 側 IP を別々に入れる。
    % Motive の通信方式、フレーム取得周期、ROS の親フレーム名を入れる。
    config.motive.serverIp = ""; % Motive PC on the facility LAN.
    config.motive.clientIp = ""; % Control PC on the facility LAN.
    config.motive.connectionType = "Unicast";
    config.motive.pollRateHz = 120;
    config.motive.frameId = "mocap";
    % 制御周期、標準の実行時間、接続待ちの期限、状態の有効期限を入れる。
    config.controlRateHz = 20;
    config.durationSeconds = 250;
    config.connectionTimeoutSeconds = 5;
    config.odometryTimeoutSeconds = 0.25;
    % 前進速度と角速度の上限、ログ保存先を入れる。
    config.maxLinearVelocity = 0.2;
    config.maxAngularVelocity = 0.5;
    config.logDirectory = fullfile(root, 'logs');
    % この段階では接続を始めない。後で選ばれた mode と通信方式を見て、
    % resolveVehicleSettings が必要な項目だけを検査する。
    % 車両名、初期位置、制御則はここに書かず、完成した設定を返す。
end
