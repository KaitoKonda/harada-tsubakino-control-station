classdef StartupTestMap < handle
    properties
        firstDrawSeconds = 0.35
        draws = 0
        afterFirstDraw = []
        closed = false
    end
    methods
        function update(obj, ~)
            obj.draws = obj.draws + 1;
            if obj.draws == 1
                pause(obj.firstDrawSeconds);
                if ~isempty(obj.afterFirstDraw), obj.afterFirstDraw(); end
            end
        end
        function close(obj), obj.closed = true; end
    end
end
