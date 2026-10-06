% ensureRosSession：ROS 接続を開始するか、同じ設定の接続を再利用する。

function ensureRosSession(config)
    persistent activeConfig
    assert(isfield(config, 'masterUri') && isfield(config, 'nodeHost') && ...
        strlength(string(config.masterUri)) > 0 && ...
        strlength(string(config.nodeHost)) > 0, ...
        'Station:MissingRosAddress', 'Set ROS masterUri and nodeHost.');
    try
        rosinit(char(config.masterUri), 'NodeHost', char(config.nodeHost));
        activeConfig = config;
    catch exception
        try
            rosnode('list');
        catch
            rethrow(exception)
        end
        % 既存接続の由来が不明なときは、別設定として使い回さず終了する。
        assert(~isempty(activeConfig) && isequal(activeConfig, config), ...
            'Station:RosConfigMismatch', ...
            'Existing ROS settings differ. Stop the experiment and run rosshutdown.');
    end
end
