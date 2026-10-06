% MotiveRosBridge：一フレームずつ ROS へ渡す。

classdef MotiveRosBridge < handle
    properties (SetAccess = private)
        source = []
        mappings = struct([])
        publishers = {}
        frameId string = "mocap"
        lastFrameNumber double = NaN
    end

    methods
        function obj = MotiveRosBridge(motiveConfig, vehicleSettings, frameSource)
            obj.frameId = string(motiveConfig.frameId);
            try
                % NatNetFrameSource を開き、モデル記述の剛体名と ID を取得する。
                if nargin < 3 || isempty(frameSource)
                    obj.source = bridge.NatNetFrameSource(motiveConfig);
                else
                    obj.source = frameSource;
                end
                % resolveRigidBodyMappings に今回の車両設定とモデル記述を渡す。
                % どれか一台でも対応が確定しなければ、配信を始めず接続を閉じる。
                obj.mappings = bridge.resolveRigidBodyMappings(vehicleSettings, obj.source.model);
                % 対応が確定した各トピックについて RosOdometryPublisher を作る。
                obj.publishers = cell(1, numel(obj.mappings));
                for index = 1:numel(obj.mappings)
                    obj.publishers{index} = bridge.RosOdometryPublisher(obj.mappings(index).topic);
                end
            % 接続や照合に失敗したら開いた資源を閉じ、元の例外を伝える。
            catch exception
                obj.close();
                rethrow(exception)
            end
        end

        % lastFrameNumber は未処理を表す NaN から始める。
        function stats = update(obj)
            stats = struct('frameNumber', NaN, 'receivedCount', 0, ...
                'matchedCount', 0, 'trackedCount', 0, 'publishedCount', 0, ...
                'invalidCount', 0, 'invalidReasons', strings(0,1));
            % update が呼ばれたら NatNetFrameSource から最新フレームを一つ取る。
            % 空なら「受信なし」を返し、前回の位置は配信しない。
            frame = obj.source.getFrame();
            if isempty(frame), return; end
            % decodeNatNetFrame に渡し、番号と剛体一覧を得る。
            decoded = bridge.decodeNatNetFrame(frame);
            stats.frameNumber = decoded.frameNumber;
            stats.receivedCount = numel(decoded.bodies);
            stats.invalidCount = decoded.invalidCount;
            stats.invalidReasons = decoded.invalidReasons;
            % 番号が前回と同じなら「新フレームなし」を返す。
            % 新しい番号なら保存し、剛体一覧を一つずつ見る。
            if decoded.frameNumber == obj.lastFrameNumber, return; end
            obj.lastFrameNumber = decoded.frameNumber;
            for body = decoded.bodies
                % 対応表にない剛体は数だけ記録して飛ばす。
                mappingIndex = find([obj.mappings.id] == body.id, 1);
                if isempty(mappingIndex), continue; end
                stats.matchedCount = stats.matchedCount + 1;
                % 対応表にあっても追跡不可なら配信せず、その件数を増やす。
                if ~body.tracked, continue; end
                stats.trackedCount = stats.trackedCount + 1;
                % 追跡中なら MotiveCoordinateTransform で位置と姿勢を変換する。
                [position, quaternion] = bridge.MotiveCoordinateTransform.toRos( ...
                    body.position, body.quaternion);
                mapping = obj.mappings(mappingIndex);
                % 対応する RosOdometryPublisher へ渡し、送信成否を記録する。
                if obj.publishers{mappingIndex}.publish(position, quaternion, ...
                        obj.frameId, mapping.childFrameId, decoded.frameNumber)
                    stats.publishedCount = stats.publishedCount + 1;
                end
            end
            % フレーム番号、受信数、対応数、追跡数、配信数を返す。
        end

        % close では各 publisher と NatNetFrameSource を個別に閉じる。
        % 一つの解放が失敗しても残りの解放を続ける。
        function close(obj)
            for index = 1:numel(obj.publishers)
                try
                    if ~isempty(obj.publishers{index})
                        obj.publishers{index}.close();
                    end
                catch exception
                    warning('Motive:CleanupFailed', '%s', exception.message);
                end
            end
            obj.publishers = {};
            if ~isempty(obj.source)
                obj.source.close();
                obj.source = [];
            end
        end

        function delete(obj)
            obj.close();
        end
    end
end
