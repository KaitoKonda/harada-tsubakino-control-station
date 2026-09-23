classdef StationRun < handle
%STATIONRUN Retain mutable run data for reliable error/Ctrl+C cleanup.
    properties
        result
        vehicles = struct()
        window = []
        logEnabled logical = true
    end
    properties (Access=private)
        finished logical = false
    end
    methods
        function obj=StationRun(result,logEnabled)
            obj.result=result;
            obj.logEnabled=logEnabled;
        end
        function finish(obj)
            if obj.finished, return; end
            obj.finished=true;
            if ismember(obj.result.status,["starting","standby","running"])
                obj.result.status="interrupted";
            end
            obj.result.shutdownErrors=StopVehicles(obj.vehicles);
            StopVehicles(obj.vehicles,true);
            if ~isempty(obj.window) && isgraphics(obj.window), delete(obj.window); end
            obj.result.endedAt=string(datetime('now'));
            fprintf('Run ended: %s\n',obj.result.status);
            if strlength(obj.result.error)>0, fprintf('%s\n',obj.result.error); end
            if obj.logEnabled
                try
                    result=obj.result;
                    save(char(obj.result.logFile),'result');
                    fprintf('Run log: %s\n',obj.result.logFile);
                catch exception
                    warning('Station:LogFailed','Could not save run log: %s',exception.message);
                end
            end
        end
    end
end
