classdef StartupTestWindow < handle
    properties
        ready = false
        autoStart = true
        stopRequested = false
        closed = false
        onReady = []
        onCheckStop = []
    end
    methods
        function markReady(obj)
            obj.ready = true;
            if ~isempty(obj.onReady), obj.onReady(); end
        end
        function value = isStarted(obj), value = obj.ready && obj.autoStart; end
        function value = shouldStop(obj)
            if ~isempty(obj.onCheckStop), obj.onCheckStop(); end
            value = obj.stopRequested;
        end
        function close(obj), obj.closed = true; end
    end
end
