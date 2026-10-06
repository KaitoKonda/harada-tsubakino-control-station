% StateEstimator：測定値を共通の車両状態へ変える。

classdef StateEstimator < handle
    properties (SetAccess = private)
        position (2,1) double = [0;0]
        orientation (1,1) double = 0
        speed (1,1) double = 0
        angularVelocity (1,1) double = 0
        calibrated logical = false
    end
    properties (Access = private)
        initialState (1,3) double
        odometrySource string
        kind string
        timeout double
        observation = []
        observationTime double = -Inf
        sampleNumber double = -1
        appliedSample double = -1
        previousPoseTime double = NaN
        rotation double = eye(2)
        translation (2,1) double = [0;0]
        yawOffset double = 0
        integrationReady logical = false
    end

    methods
        function obj = StateEstimator(settings, timeout)
            % 初期位置、状態入力名、入力が位置か速度か、状態の期限を受け取る。
            % 状態、最後の有効な測定時刻、前回適用した測定番号を保持する。
            obj.initialState = double(settings.initialState);
            obj.odometrySource = string(settings.odometrySource);
            obj.kind = string(settings.odometryInput.kind);
            obj.timeout = double(timeout);
            % 速度入力なら、指定初期位置を現在位置として積分の準備をする。
            obj.position = obj.initialState(1:2).';
            obj.orientation = obj.initialState(3);
        end

        % 値が非有限、姿勢が不正、時刻が逆行したら状態を更新しない。
        function accept(obj, sample)
            if isempty(sample) || sample.number <= obj.sampleNumber, return; end
            assert(isscalar(sample.receivedAt) && isfinite(sample.receivedAt) && ...
                sample.receivedAt >= obj.observationTime, ...
                'Station:InvalidObservation', 'Observation time must progress.');
            if obj.kind == "position"
                value = sample.value;
                valid = isfield(value, 'position') && ...
                    isfield(value, 'orientation') && ...
                    isnumeric(value.position) && numel(value.position) == 2 && ...
                    all(isfinite(value.position(:))) && ...
                    isnumeric(value.orientation) && ...
                    isscalar(value.orientation) && isfinite(value.orientation);
                assert(valid, 'Station:InvalidObservation', ...
                    'Position observation is invalid.');
                sample.value.position = double(value.position(:));
            else
                value = sample.value;
                valid = isfield(value, 'speed') && ...
                    isfield(value, 'angularVelocity') && ...
                    isnumeric(value.speed) && isscalar(value.speed) && ...
                    isfinite(value.speed) && isnumeric(value.angularVelocity) && ...
                    isscalar(value.angularVelocity) && isfinite(value.angularVelocity);
                assert(valid, 'Station:InvalidObservation', ...
                    'Velocity observation is invalid.');
            end
            obj.observation = sample.value;
            obj.observationTime = double(sample.receivedAt);
            obj.sampleNumber = double(sample.number);
        end

        % 問い合わせ時には現在の時刻と最終受信時刻を比べ、期限超過なら
        % fresh=false と返す。最後の数値は残すが、新測定として扱わない。
        % 実時間と模擬時間は混ぜず、同じ時計系の時刻だけを比較する。
        function fresh = isFresh(obj, now)
            fresh = ~isempty(obj.observation) && ...
                now >= obj.observationTime && ...
                now - obj.observationTime <= obj.timeout;
        end

        % calibrate では最初の有効な測定を受け取る。
        % Motive は共通座標をそのまま使い、OTOS はこの測定を指定初期位置に合わせる。
        function calibrate(obj, now)
            assert(obj.isFresh(now), 'Station:NoFreshOdometry', ...
                'No fresh observation for calibration.');
            obj.rotation = eye(2);
            obj.translation = [0;0];
            obj.yawOffset = 0;
            if obj.kind == "position"
                switch obj.odometrySource
                    case "otos"
                        % 最初に採用した測定の位置と向きを initialState に一致させる。
                        % センサー起動後、採用前に生じた移動は基準から差し引かれる。
                        obj.yawOffset = obj.initialState(3) - obj.observation.orientation;
                        a = obj.yawOffset;
                        obj.rotation = [cos(a) -sin(a); sin(a) cos(a)];
                        obj.translation = obj.initialState(1:2).' - ...
                            obj.rotation * obj.observation.position;
                    case "motive"
                        % Motive の位置・向きは共通座標なので変換しない。
                    otherwise
                        error('Station:UnknownSourceSemantics', ...
                            'Coordinate semantics are not defined for %s.', obj.odometrySource);
                end
                obj.position = obj.rotation * obj.observation.position + obj.translation;
                obj.orientation = obj.observation.orientation + obj.yawOffset;
                obj.previousPoseTime = obj.observationTime;
                obj.appliedSample = obj.sampleNumber;
            else
                obj.position = obj.initialState(1:2).';
                obj.orientation = obj.initialState(3);
            end
            obj.speed = 0;
            obj.angularVelocity = 0;
            obj.integrationReady = false;
            obj.calibrated = true;
        end

        function fresh = update(obj, dt, now)
            validateattributes(dt, {'numeric'}, ...
                {'scalar', 'real', 'finite', 'nonnegative'});
            fresh = obj.isFresh(now);
            if ~fresh
                obj.integrationReady = false;
                return
            end
            assert(obj.calibrated, 'Station:NotCalibrated', ...
                'Vehicle state was not calibrated.');
            if obj.kind == "position"
                % 同じ測定番号のままなら位置・速度をもう一度計算しない。
                if obj.appliedSample == obj.sampleNumber, return; end
                % 新しい位置測定が届いたら、保持した変換を位置と方位へ適用する。
                positionNew = obj.rotation * obj.observation.position + obj.translation;
                orientationNew = obj.observation.orientation + obj.yawOffset;
                elapsed = obj.observationTime - obj.previousPoseTime;
                % 前の測定から時間が進んでいれば、移動量から前進速度を、
                % 最短の方位差から角速度を計算する。
                if isfinite(elapsed) && elapsed > 0
                    delta = positionNew - obj.position;
                    obj.speed = dot(delta, [cos(orientationNew); sin(orientationNew)]) / elapsed;
                    obj.angularVelocity = atan2( ...
                        sin(orientationNew-obj.orientation), ...
                        cos(orientationNew-obj.orientation)) / elapsed;
                else
                    obj.speed = 0;
                    obj.angularVelocity = 0;
                end
                obj.position = positionNew;
                obj.orientation = orientationNew;
                obj.previousPoseTime = obj.observationTime;
                obj.appliedSample = obj.sampleNumber;
            else
                % 新しい速度測定が届いたら、前回と今回の速度を使って姿勢を進める。
                % 受信途絶後の復帰では、届いていなかった時間をまとめて積分しない。
                oldSpeed = obj.speed;
                oldAngular = obj.angularVelocity;
                oldYaw = obj.orientation;
                obj.speed = obj.observation.speed;
                obj.angularVelocity = obj.observation.angularVelocity;
                if obj.integrationReady
                    obj.orientation = oldYaw + ...
                        (oldAngular + obj.angularVelocity) * dt / 2;
                    obj.position = obj.position + dt/2 * ( ...
                        oldSpeed * [cos(oldYaw); sin(oldYaw)] + ...
                        obj.speed * [cos(obj.orientation); sin(obj.orientation)]);
                end
                obj.integrationReady = true;
            end
        end

        function state = snapshot(obj)
            state = [obj.position.' obj.orientation obj.speed obj.angularVelocity];
        end
    end
end
