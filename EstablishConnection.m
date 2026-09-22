function EstablishConnection(vehicles, rate)
    
    maximumIteration = 100;
    vehicleNames = fieldnames(vehicles);
    isConnected = false(1,length(vehicleNames));

    % 最大試行回数まで繰り返す
    for j = 1:maximumIteration

        % タイムスタンプ
        time = rate.TotalElapsedTime;
        fprintf('Step: %d - Time Elapsed: %f\n',j,time)

        % 各車両でデータを受信
        for i = 1:length(vehicleNames)
            odometry = vehicles.(vehicleNames{i}).receive();
            isConnected(i) = ~isempty(odometry);
        end

        % 受信状況を表示
        fprintf('isConnected: %s\n', mat2str(isConnected))

        % 全車両から受信したら正常終了
        if all(isConnected)
            disp('All connection established.')
            return
        end

        % 少し待つ
        [~] = waitfor(rate);
    end

    % 最大試行回数に到達したら異常終了
    error('Connection failed: %s\n', mat2str(isConnected))
end