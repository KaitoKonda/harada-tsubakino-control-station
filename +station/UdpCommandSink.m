% UdpCommandSink：UDP へ指令を送る。

classdef UdpCommandSink < handle
    properties (SetAccess = private)
        port = []
        targetIp string
        targetPort double
    end

    methods
        function obj = UdpCommandSink(config)
            % 指定された送信元ポートを開き、宛先 IP とポートを保持する。
            obj.targetIp = string(config.targetIp);
            obj.targetPort = double(config.targetPort);
            obj.port = udpport("datagram", "IPV4", ...
                "LocalPort", config.localPort, "ByteOrder", "big-endian");
        end

        % send が [speed, angularVelocity] を受け取ったら、
        % その順でビッグエンディアンの double 二個、16 バイトへ変換する。
        % 一つのデータグラムとして宛先へ書き込む。
        % 車両の受領を UDP 書き込み成功から推定しない。
        % ゼロ指令も同じ send を通して送る。
        function sent = send(obj, command)
            write(obj.port, double(command(:).'), "double", ...
                char(obj.targetIp), obj.targetPort);
            % 書き込み呼び出しの成否を Vehicle へ返す。
            sent = true;
        end

        % close が呼ばれたら UDP ポートを閉じる。
        function close(obj)
            if ~isempty(obj.port)
                delete(obj.port);
                obj.port = [];
            end
        end

        function delete(obj)
            obj.close();
        end
    end
end
