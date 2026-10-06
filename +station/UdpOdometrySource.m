% UdpOdometrySource：UDP から測定を受け取る。

classdef UdpOdometrySource < handle
    properties (SetAccess = private)
        port = []
    end
    properties (Access = private)
        config
        clock
        sampleNumber double = 0
    end

    methods
        function obj = UdpOdometrySource(config, clock)
            obj.config = config;
            obj.clock = clock;
            % 指定されたローカルポートを開く。すでに使用中ならそのポートを示す。
            obj.port = udpport("datagram", "IPV4", ...
                "LocalPort", config.localPort, "ByteOrder", "big-endian");
        end

        function sample = read(obj)
            sample = [];
            % read が呼ばれたら、待機中のデータグラムを一つずつ取り出す。
            % 一つも有効でなければ「新測定なし」を返す。
            count = obj.port.NumDatagramsAvailable;
            if count == 0, return; end
            packets = read(obj.port, count, "uint8");
            for index = 1:numel(packets)
                bytes = uint8(packets(index).Data);
                % 各データグラムの長さが 24 バイトでなければ捨てる。
                if numel(bytes) ~= 24, continue; end
                % 正しい長さならビッグエンディアンの double 三個として読む。
                values = typecast(bytes(:), 'double');
                [~, ~, endian] = computer;
                if endian == 'L', values = swapbytes(values); end
                % 必要な数値がすべて有限でなければ捨て、受信期限を延ばさない。
                if ~all(isfinite(values)), continue; end
                % 位置入力なら [x, y, theta]、速度入力なら
                % [連番, speed, angularVelocity] として解釈する。
                if string(obj.config.kind) == "position"
                    value = struct('position', double(values(1:2)), ...
                        'orientation', double(values(3)));
                else
                    value = struct('speed', double(values(2)), ...
                        'angularVelocity', double(values(3)));
                end
                obj.sampleNumber = obj.sampleNumber + 1;
                % 有効な複数のデータがあれば、最後の有効な値とその受信時刻を返す。
                sample = struct('value', value, ...
                    'receivedAt', toc(obj.clock), 'number', obj.sampleNumber);
            end
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
