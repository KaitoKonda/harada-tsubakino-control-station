% resolveRigidBodyMappings：車両と剛体の一対一対応を決める。

function mappings = resolveRigidBodyMappings(settings, model)
    % 今回 Motive 入力を選んだ車両設定と、Motive のモデル記述を受け取る。
    selected = settings(arrayfun(@(s) s.odometrySource == "motive", settings));
    assert(~isempty(selected), 'Motive:NoMappings', ...
        'No selected vehicle uses Motive odometry.');
    assert(isstruct(model) && isfield(model, 'RigidBodyCount') && ...
        isfield(model, 'RigidBody') && model.RigidBodyCount > 0, ...
        'Motive:NoRigidBodies', 'Motive did not report rigid-body descriptions.');
    bodies = model.RigidBody;
    count = min(double(model.RigidBodyCount), numel(bodies));
    mappings = struct('vehicleName', {}, 'bodyName', {}, 'id', {}, ...
        'topic', {}, 'childFrameId', {});
    % 車両を一台ずつ取り出し、Streaming ID が指定されているかを調べる。
    for vehicle = selected
        requestedName = string(vehicle.motive.name);
        requestedId = double(vehicle.motive.id);
        candidates = false(1, count);
        % ID があればモデル記述から同じ ID を探す。
        % ID がなければ剛体名と一致する候補を探し、一件だけなら ID を得る。
        for index = 1:count
            if isnan(requestedId)
                candidates(index) = string(bodies(index).Name) == requestedName;
            else
                candidates(index) = double(bodies(index).ID) == requestedId;
            end
        end
        matches = find(candidates);
        % 一件もない、複数ある、名前と ID が食い違う場合は車両名付きで終了する。
        assert(numel(matches) == 1, 'Motive:RigidBodyNotFound', ...
            'Expected one Motive rigid body for %s; found %d.', ...
            vehicle.name, numel(matches));
        matched = bodies(matches);
        foundName = string(matched.Name);
        % 名前も指定されていれば、見つけた剛体名と一致するか確かめる。
        if strlength(requestedName) > 0
            assert(foundName == requestedName, 'Motive:MappingMismatch', ...
                'Motive name and ID disagree for %s.', vehicle.name);
        end
        % 見つけた ID と、その車両の ROS 配信トピックを対応表へ加える。
        % 実際に見つかった剛体名と ID を診断表示用にも返す。
        mappings(end+1) = struct('vehicleName', vehicle.name, ...
            'bodyName', foundName, 'id', double(matched.ID), ...
            'topic', string(vehicle.odometryInput.topic), ...
            'childFrameId', vehicle.name + "/base_link"); %#ok<AGROW>
    end
    % 全車両を処理したら、同じ ID または同じ配信トピックの二重利用を調べる。
    % 重複がなければ車両名、剛体 ID、トピック、子フレーム名を返す。
    assert(numel(unique([mappings.id])) == numel(mappings) && ...
        numel(unique(string({mappings.topic}))) == numel(mappings), ...
        'Motive:DuplicateMapping', 'Motive mappings must be one-to-one.');
end
