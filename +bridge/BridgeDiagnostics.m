% BridgeDiagnostics：区間集計、状態変化、診断ファイルを管理する。
classdef BridgeDiagnostics < handle
    properties (SetAccess = private)
        logPath string = ""
        intervalSeconds double = 1
        staleWarningSeconds double = 0.5
        logPoseDetails logical = false
    end
    properties (Access = private)
        clockStart
        fileId double = -1
        closed logical = false
        mappings = struct([])
        window
        totals
        vehicleWindow
        vehicleTotals
        vehicleStates = strings(1,0)
        vehicleReasons = strings(1,0)
        lastPublish = []
        lastPose = {}
        lastPoseFrame = []
        lastNew double = NaN
        lastFrame double = NaN
        readyAt double = NaN
        windowStart double = 0
        observedAt double = 0
        streamStale logical = false
        invalidSignature string = ""
    end
    methods
        function obj = BridgeDiagnostics(config, logDirectory)
            obj.clockStart = tic;
            obj.window = obj.emptyCounts();
            obj.totals = obj.emptyCounts();
            obj.vehicleWindow = zeros(0,5);
            obj.vehicleTotals = zeros(0,5);
            for name = ["logIntervalSeconds", "staleWarningSeconds"]
                if isfield(config, name)
                    validateattributes(config.(name), {'numeric'}, {'scalar','real','finite','positive'});
                end
            end
            if isfield(config, 'logIntervalSeconds'), obj.intervalSeconds = config.logIntervalSeconds; end
            if isfield(config, 'staleWarningSeconds'), obj.staleWarningSeconds = config.staleWarningSeconds; end
            if isfield(config, 'logPoseDetails'), obj.logPoseDetails = config.logPoseDetails; end

            saveLog = true;
            if isfield(config, 'saveDiagnosticLog'), saveLog = config.saveDiagnosticLog; end
            if saveLog
                try
                    if ~isfolder(logDirectory), mkdir(logDirectory); end
                    [~, suffix] = fileparts(tempname(logDirectory));
                    stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
                    obj.logPath = string(fullfile(logDirectory, ['motiveBridge_' stamp '_' suffix '.log']));
                    [obj.fileId, message] = fopen(obj.logPath, 'w', 'n', 'UTF-8');
                    if obj.fileId < 0, error('Motive:LogOpenFailed', '%s', message); end
                    obj.log('[LOG] %s', obj.logPath);
                catch exception
                    obj.logPath = "";
                    obj.log('[WARN] diagnostic file unavailable: %s', exception.message);
                end
            end
        end

        function log(obj, format, varargin)
            if obj.closed, return; end
            stamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));
            line = sprintf('[%s] %s\n', stamp, sprintf(format, varargin{:}));
            fprintf('%s', line);
            if obj.fileId >= 0
                try
                    count = fprintf(obj.fileId, '%s', line);
                    [message, number] = ferror(obj.fileId);
                    if count < 0 || number ~= 0, error('Motive:LogWriteFailed', '%s', message); end
                catch exception
                    fclose(obj.fileId);
                    obj.fileId = -1;
                    fprintf('[WARN] diagnostic file write stopped: %s\n', exception.message);
                end
            end
        end

        function configure(obj, mappings)
            obj.mappings = mappings;
            n = numel(mappings);
            obj.vehicleWindow = zeros(n,5);
            obj.vehicleTotals = zeros(n,5);
            obj.vehicleStates = repmat("waiting", 1, n);
            obj.vehicleReasons = strings(1,n);
            obj.lastPublish = nan(1,n);
            obj.lastPose = cell(1,n);
            obj.lastPoseFrame = nan(1,n);
            obj.readyAt = toc(obj.clockStart);
            obj.windowStart = obj.readyAt;
            obj.observedAt = obj.readyAt;
            for m = mappings
                obj.log('[MAP] vehicle=%s -> rigidBody=%s(ID=%g) -> %s childFrame=%s', ...
                    m.vehicleName, m.bodyName, m.id, m.topic, m.childFrameId);
                obj.log('[WAIT] %s(ID=%g): waiting for first frame', m.vehicleName, m.id);
            end
        end

        function observe(obj, stats, nowSeconds)
            % nowSeconds はテストでのみ指定。実運転では単調増加する toc を使う。
            if nargin < 3, nowSeconds = toc(obj.clockStart); end
            obj.observedAt = nowSeconds;
            obj.window.polls = obj.window.polls + 1;
            obj.totals.polls = obj.totals.polls + 1;
            switch stats.frameStatus
                case "empty", field = 'empty';
                case "duplicate", field = 'duplicates';
                case "new", field = 'newFrames';
                otherwise, error('Motive:InvalidDiagnostics', 'Unknown frame status.');
            end
            obj.window.(field) = obj.window.(field) + 1;
            obj.totals.(field) = obj.totals.(field) + 1;
            if stats.frameStatus == "new"
                obj.lastNew = nowSeconds;
                obj.lastFrame = stats.frameNumber;
                obj.window.invalidBodies = obj.window.invalidBodies + stats.invalidCount;
                obj.totals.invalidBodies = obj.totals.invalidBodies + stats.invalidCount;
                if obj.streamStale
                    obj.log('[OK] NatNet frame updates recovered; frame=%g', stats.frameNumber);
                    obj.streamStale = false;
                end
                signature = strjoin(stats.invalidReasons, '; ');
                if strlength(signature) > 0 && signature ~= obj.invalidSignature
                    obj.log('[WARN] invalid rigid bodies: %s', signature);
                end
                obj.invalidSignature = signature;
                statuses = ["published", "untracked", "missing", "invalid", "suppressed"];
                for i = 1:numel(obj.mappings)
                    v = stats.vehicles(i);
                    column = find(statuses == v.status, 1);
                    obj.vehicleWindow(i,column) = obj.vehicleWindow(i,column) + 1;
                    obj.vehicleTotals(i,column) = obj.vehicleTotals(i,column) + 1;
                    if v.status == "published"
                        obj.lastPublish(i) = nowSeconds;
                    end
                    obj.lastPose{i} = v;
                    obj.lastPoseFrame(i) = stats.frameNumber;
                    if v.status ~= obj.vehicleStates(i) || v.reason ~= obj.vehicleReasons(i)
                        m = obj.mappings(i);
                        if v.status == "published"
                            if obj.vehicleTotals(i,1) == 1
                                detail = "first publish completed";
                            else
                                detail = "publishing recovered";
                            end
                            obj.log('[OK] %s(ID=%g): %s frame=%g', m.vehicleName, m.id, detail, stats.frameNumber);
                        else
                            obj.log('[WARN] %s(ID=%g): %s frame=%g', m.vehicleName, m.id, v.reason, stats.frameNumber);
                        end
                        obj.vehicleStates(i) = v.status;
                        obj.vehicleReasons(i) = v.reason;
                    end
                end
            end
            reference = obj.lastNew;
            if isnan(reference), reference = obj.readyAt; end
            if nowSeconds - reference >= obj.staleWarningSeconds && ~obj.streamStale
                obj.log('[WARN] NatNet frame is not advancing; lastFrame=%g secondsSinceLastNewFrame=%s secondsSinceReady=%.3f', ...
                    obj.lastFrame, obj.since(nowSeconds, obj.lastNew), nowSeconds-obj.readyAt);
                obj.streamStale = true;
            end
            if nowSeconds - obj.windowStart >= obj.intervalSeconds
                obj.report(nowSeconds);
            end
        end

        function report(obj, nowSeconds)
            if nargin < 2, nowSeconds = toc(obj.clockStart); end
            if obj.window.polls == 0, return; end
            c = obj.window;
            obj.log('[INTERVAL %.3fs] polls=%d newFrames=%d duplicates=%d empty=%d invalidBodies=%d lastFrame=%g secondsSinceLastNewFrame=%s', ...
                nowSeconds-obj.windowStart, c.polls, c.newFrames, c.duplicates, c.empty, ...
                c.invalidBodies, obj.lastFrame, obj.since(nowSeconds, obj.lastNew));
            for i = 1:numel(obj.mappings)
                m = obj.mappings(i);
                v = obj.vehicleWindow(i,:);
                obj.log('  %s(ID=%g): published=%d untracked=%d missing=%d invalid=%d suppressed=%d secondsSinceLastPublish=%s state=%s', ...
                    m.vehicleName, m.id, v(1), v(2), v(3), v(4), v(5), ...
                    obj.since(nowSeconds, obj.lastPublish(i)), obj.vehicleStates(i));
                if obj.logPoseDetails && ~isempty(obj.lastPose{i})
                    pose = obj.lastPose{i};
                    obj.log('[POSE] %s ID=%g frame=%g state=%s motive[m]=%s ros[m]=%s motiveQuat=%s rosQuat=%s', ...
                        m.vehicleName, m.id, obj.lastPoseFrame(i), pose.status, ...
                        mat2str(pose.positionMotive,6), mat2str(pose.positionRos,6), ...
                        mat2str(pose.quaternionMotive,6), mat2str(pose.quaternionRos,6));
                end
            end
            obj.window = obj.emptyCounts();
            obj.vehicleWindow(:) = 0;
            obj.windowStart = nowSeconds;
        end

        function logException(obj, exception, stage)
            obj.log('[ERROR] stage=%s identifier=%s\n%s', stage, exception.identifier, ...
                getReport(exception, 'extended', 'hyperlinks', 'off'));
        end

        function close(obj)
            if obj.closed, return; end
            obj.report(max(toc(obj.clockStart), obj.observedAt));
            c = obj.totals;
            obj.log('[END] polls=%d newFrames=%d duplicates=%d empty=%d invalidBodies=%d published=%d', ...
                c.polls, c.newFrames, c.duplicates, c.empty, c.invalidBodies, sum(obj.vehicleTotals(:,1)));
            for i = 1:numel(obj.mappings)
                obj.log('[TOTAL] %s(ID=%g): published=%d', ...
                    obj.mappings(i).vehicleName, obj.mappings(i).id, obj.vehicleTotals(i,1));
            end
            if obj.fileId >= 0, fclose(obj.fileId); obj.fileId = -1; end
            obj.closed = true;
        end

        function delete(obj)
            obj.close();
        end
    end
    methods (Static, Access = private)
        function counts = emptyCounts()
            counts = struct('polls',0,'newFrames',0,'duplicates',0,'empty',0,'invalidBodies',0);
        end
        function text = since(nowSeconds, lastTime)
            if isnan(lastTime), text = 'never'; else, text = sprintf('%.3f', nowSeconds-lastTime); end
        end
    end
end
