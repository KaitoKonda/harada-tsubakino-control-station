% stopController：選択中の全車両を止める指令を作る。

function commands = stopController(vehicles)
    % 入力の車両名一覧を読み、空の指令集合を作る。
    % 台数や pi1 などの特定の名前を前提にしない。
    commands = struct();
    names = fieldnames(vehicles);
    % 一台ずつ名前を取り出し、その名前に [0, 0] を入れる。
    for index = 1:numel(names)
        commands.(names{index}) = [0 0];
    end
    % 全台分を入れ終えたら指令集合を返す。
end
