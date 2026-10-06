% katchaka：katchaka の固定的な通信候補を作る。

function profile = katchaka()
    % 空のプロファイルを作り、name を "katchaka" にする。
    profile.name = "katchaka";
    % 状態入力候補ごとに方式、ポートまたはトピック、位置か速度かを書く。
    % 旧版の参考値は状態 UDP 12345、指令元 23456、指令先 34567。
    profile.odometrySources.udpVelocity = struct( ...
        'protocol', "udp", 'kind', "velocity", ...
        'localPort', 12345);
    % 指令先候補ごとに方式、送信元、宛先ポートを記録する。
    % 旧版の宛先 127.0.0.1 は PC 内試験用なので、実機 IP として写さない。
    % 実際に使う候補と実機アドレスは確認後に設定し、プロファイルを返す。
    profile.commandSinks.udpDrive = struct( ...
        'protocol', "udp", 'localPort', 23456, ...
        'targetPort', 34567, 'targetIp', "");
    % 今回の初期位置はここで選ばない。
end
