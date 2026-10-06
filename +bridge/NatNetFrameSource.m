% NatNetFrameSource：公式 MATLAB Plugin から生データを取る。

classdef NatNetFrameSource < handle
    properties (SetAccess = private)
        client = []
        model = struct()
    end

    methods
        function obj = NatNetFrameSource(config)
            % serverIp、clientIp、通信方式を受け取る。
            % MATLAB が natnet クラスを見つけられるかを調べる。
            % 見つからなければプラグインの追加を案内し、接続は始めない。
            % 配布元の natnet.m や DLL 自体は書き換えない。
            assert(exist('natnet', 'class') == 8, 'Motive:NatNetMissing', ...
                'Add the OptiTrack MATLAB Plugin natnet.m and DLL files to the MATLAB path.');
            assert(strlength(string(config.serverIp)) > 0 && ...
                strlength(string(config.clientIp)) > 0, ...
                'Motive:MissingAddress', 'Set Motive serverIp and clientIp.');
            obj.client = natnet();
            try
                % natnet インスタンスを作り、公式サンプルで成功した引数順と方式で
                % ConnectToNatNet を呼ぶ。戻り値と IsConnected の両方を確かめる。
                connected = obj.client.ConnectToNatNet( ...
                    char(config.clientIp), char(config.serverIp), ...
                    char(config.connectionType));
                assert(connected == 1 && obj.client.IsConnected == 1, ...
                    'Motive:ConnectionFailed', ...
                    'NatNet connection failed; check IPs and transmission type.');
                % 接続できたら getModelDescription を呼び、剛体名と ID を渡せる形にする。
                obj.model = obj.client.getModelDescription();
            % 接続できなければ、インスタンスを閉じて段階を示して終了する。
            catch exception
                obj.close();
                rethrow(exception)
            end
        end

        % getFrame が呼ばれるたびに、プラグインの getFrame を一回呼ぶ。
        % 生の戻り値を変えずに返し、空の戻り値と例外は別々に知らせる。
        function frame = getFrame(obj)
            assert(~isempty(obj.client) && obj.client.IsConnected == 1, ...
                'Motive:Disconnected', 'NatNet is not connected.');
            frame = obj.client.getFrame();
        end

        % close が呼ばれたら disconnect を試み、内部の参照を外す。
        function close(obj)
            if isempty(obj.client), return; end
            try
                obj.client.disconnect();
            catch exception
                warning('Motive:CleanupFailed', '%s', exception.message);
            end
            obj.client = [];
        end

        function delete(obj)
            obj.close();
        end
    end
end
