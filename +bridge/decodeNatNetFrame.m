% decodeNatNetFrame：生の NatNet フレームを読み解く。

function decoded = decodeNatNetFrame(frame)
    decoded = struct('frameNumber', NaN, 'bodies', ...
        struct('id', {}, 'position', {}, 'quaternion', {}, 'tracked', {}), ...
        'invalidCount', 0, 'invalidReasons', strings(0,1));
    % 空のフレームなら「受信なし」を返す。
    if isempty(frame), return; end
    % フレームの型を調べ、公式プラグインの生フレーム形式か確認する。
    % MATLAB ラッパ構造体も受け入れ、実際に使う形式を診断できるようにする。
    try
        if isstruct(frame) && isfield(frame, 'Frame') && isfield(frame, 'RigidBody')
            decoded.frameNumber = double(frame.Frame);
            rawBodies = frame.RigidBody;
            count = numel(rawBodies);
        else
            % 実フレームで確認した iFrame と RigidBodies の取り方で番号と個数を読む。
            decoded.frameNumber = double(frame.iFrame);
            rawBodies = frame.RigidBodies;
            count = double(frame.nRigidBodies);
        end
    % フレーム自体が想定外の型なら、型名と観測できた項目を示して終了する。
    catch exception
        error('Motive:UnsupportedFrame', ...
            'Cannot read NatNet frame (%s): %s', class(frame), exception.message);
    end
    assert(isscalar(decoded.frameNumber) && isfinite(decoded.frameNumber), ...
        'Motive:InvalidFrame', 'NatNet frame number is invalid.');
    assert(isscalar(count) && isfinite(count) && count >= 0 && fix(count) == count, ...
        'Motive:InvalidFrame', 'NatNet rigid-body count is invalid.');
    % 配列の要素を一つずつ読み、ID、x/y/z、qx/qy/qz/qw を数値へ変える。
    for index = 1:count
        reason = "";
        try
            raw = rawBodies(index);
            id = double(raw.ID);
            position = double([raw.x raw.y raw.z]);
            quaternion = double([raw.qx raw.qy raw.qz raw.qw]);
            % 同梱 NatNetML.dll の RigidBodyData に Boolean 型の Tracked がある。
            % 生フレームを実機で受け取ったときにもこの型かどうかを確認する。
            % 追跡状態を判断できなければ、追跡中とはみなさず理由を返す。
            tracked = logical(raw.Tracked);
            % 数値が欠ける、非有限、クォータニオンがゼロ長なら、その剛体を不正とする。
            valid = isscalar(id) && isfinite(id) && ...
                all(isfinite(position)) && all(isfinite(quaternion)) && ...
                norm(quaternion) > eps && isscalar(tracked);
            if ~valid, reason = "non-finite pose, invalid ID, or zero quaternion"; end
        catch exception
            valid = false;
            reason = string(exception.message);
        end
        if ~valid
            decoded.invalidCount = decoded.invalidCount + 1;
            decoded.invalidReasons(end+1,1) = ...
                "rigid body " + string(index) + ": " + reason; %#ok<AGROW>
            continue
        end
        % 正常な剛体を id、位置、姿勢、追跡状態の共通形式へ加える。
        decoded.bodies(end+1) = struct('id', id, 'position', position, ...
            'quaternion', quaternion, 'tracked', tracked); %#ok<AGROW>
    end
    % 最後にフレーム番号、剛体一覧、不正件数と理由を返す。
end
