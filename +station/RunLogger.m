% RunLogger：一回の運転を後で読める形に残す。

classdef RunLogger < handle
    properties (SetAccess = private)
        result
    end
    properties (Access = private)
        saveRunLog logical
        finished logical = false
    end

    methods
        function obj = RunLogger(mode, station, experiment, settings, saveRunLog)
            % 開始時に、実行日時、mode、車両の並び、確定済み設定、制御則名を受け取る。
            % 状態列と指令列の順序を結果の中に保持する。
            obj.saveRunLog = logical(saveRunLog);
            names = string({settings.name});
            loggedExperiment = experiment;
            loggedExperiment.controllerName = string(func2str(experiment.controller));
            loggedExperiment = rmfield(loggedExperiment, 'controller');
            if isfield(loggedExperiment, 'cleanupController')
                loggedExperiment = rmfield(loggedExperiment, 'cleanupController');
            end
            obj.result = struct('mode', string(mode), ...
                'startedAt', string(datetime('now')), ...
                'stationConfig', station, 'experimentConfig', loggedExperiment, ...
                'vehicleSettings', settings, 'vehicleNames', names, ...
                'status', "starting", 'errorText', "", 'elapsedSeconds', zeros(0,1), ...
                'states', zeros(0,5,numel(names)), ...
                'commands', zeros(0,2,numel(names)), ...
                'odometryFresh', false(0,numel(names)), ...
                'commandSent', false(0,numel(names)), ...
                'shutdownErrors', strings(0,1), 'logFilePath', "", ...
                'stateComponents', ["x","y","yaw","speed","angularVelocity"], ...
                'commandComponents', ["speed","angularVelocity"]);
            % 同じ名前のログを上書きしない保存先を決める。
            if obj.saveRunLog
                if ~isfolder(station.logDirectory), mkdir(station.logDirectory); end
                obj.result.logFilePath = string(tempname(station.logDirectory)) + ".mat";
            end
        end

        % StationRunner が一周期を終えるたびに、相対時刻、各車両の状態、
        % odometryFresh、計算した指令、送信呼び出しの成否を同じ行へ追加する。
        % 送信が例外で途中停止したときは、送れていない車両を成功にしない。
        % 送信呼び出しの成功を、車両が指令を受け取った証拠とは書かない。
        function record(obj, elapsedSeconds, states, odometryFresh, commands, commandSent)
            index = size(obj.result.elapsedSeconds, 1) + 1;
            obj.result.elapsedSeconds(index,1) = elapsedSeconds;
            obj.result.states(index,:,:) = states;
            obj.result.odometryFresh(index,:) = odometryFresh;
            obj.result.commands(index,:,:) = commands;
            obj.result.commandSent(index,:) = commandSent;
        end

        % 終了を知らされたら、status、エラー全文、停止時の個別エラー、
        % 終了日時を結果に加え、指定があればファイルへ保存する。
        % 呼び出し元には、保存に成功したかとログの場所を返す。
        function finish(obj, status, errorText, shutdownErrors)
            if obj.finished, return; end
            obj.finished = true;
            obj.result.status = string(status);
            obj.result.errorText = string(errorText);
            obj.result.shutdownErrors = string(shutdownErrors(:));
            obj.result.endedAt = string(datetime('now'));
            fprintf('Run ended: %s\n', obj.result.status);
            if strlength(obj.result.errorText) > 0
                fprintf('%s\n', obj.result.errorText);
            end
            if obj.saveRunLog
                try
                    result = obj.result; %#ok<NASGU>
                    save(char(obj.result.logFilePath), 'result');
                    fprintf('Run log: %s\n', obj.result.logFilePath);
                % 保存に失敗したら警告を出すが、安全停止の処理を巻き戻さない。
                catch exception
                    warning('Station:LogFailed', ...
                        'Could not save run log: %s', exception.message);
                end
            end
        end
    end
end
