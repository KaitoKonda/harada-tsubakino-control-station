% oneLineController：隊列制御の入口。以下は未実装段階の疑似コード。

function commands = oneLineController(vehicles)
    % The formation law remains intentionally inactive until its parameters
    % and expected behaviour have been specified and verified.
    % 現段階では stopController を呼び、そのゼロ指令を返す。
    % 隊列制御を実装するときは、まず車両順と目標間隔を入力から決める。
    % 次に各車両の位置・方位から目標との差を計算する。
    % 差から前進速度と角速度を計算し、全台分の指令を作って返す。
    % 一台でも必要な状態がなければ、走行指令を作らず失敗を伝える。
    % 上限検査と送信はこの関数で行わず、上位へ任せる。
    commands = station.stopController(vehicles);
end
