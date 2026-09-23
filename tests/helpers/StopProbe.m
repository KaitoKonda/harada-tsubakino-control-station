classdef StopProbe < handle
    properties
        fail logical = false
        calls double = 0
    end
    methods
        function send(obj,~)
            obj.calls=obj.calls+1;
            if obj.fail, error('Test:SendFailure','Injected send failure.'); end
        end
    end
end
