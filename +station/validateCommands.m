% validateCommands：制御則の出力を全台分まとめて調べる。

function commands = validateCommands(commands, vehicleNames, config)
    % 選択車両名と、制御則が返した名前を比べる。
    % 名前の欠落や余分な名前があれば、その名前を示して終了する。
    names = cellstr(string(vehicleNames(:)));
    assert(isstruct(commands) && isscalar(commands) && ...
        isequal(sort(fieldnames(commands)), sort(names)), ...
        'Station:InvalidCommands', ...
        'Controller must return exactly one command per selected vehicle.');
    % 選択順に各指令を取り出す。
    for index = 1:numel(names)
        value = commands.(names{index});
        % 二要素の実数か、両方が有限かを調べる。
        % 一台でも不正なら車両名と理由を返し、通常指令は何も返さない。
        assert(isnumeric(value) && isreal(value) && numel(value) == 2 && ...
            all(isfinite(value(:))), 'Station:InvalidCommands', ...
            'Command for %s must contain two finite real numbers.', names{index});
        value = double(value(:).');
        % 前進速度と角速度の絶対値を、それぞれの上限と比べる。
        % 上限を超えた値を黙って小さくしない。
        assert(abs(value(1)) <= config.maxLinearVelocity && ...
            abs(value(2)) <= config.maxAngularVelocity, ...
            'Station:CommandLimit', 'Command exceeds the limit for %s.', names{index});
        % 全台が正しければ二要素の数値へ揃え、選択順で返す。
        % StationRunner は成功結果を受け取るまで一台にもその周期の指令を送らない。
        commands.(names{index}) = value;
    end
end
