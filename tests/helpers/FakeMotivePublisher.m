classdef FakeMotivePublisher < handle
    properties
        frames = []
        positions = {}
        fail logical = false
        closed logical = false
    end
    methods
        function sent = publish(obj, position, ~, ~, ~, frameNumber)
            if obj.fail, error('Test:PublishFailed', 'Simulated publish failure.'); end
            sent = isempty(obj.frames) || obj.frames(end) ~= frameNumber;
            if sent
                obj.frames(end+1) = frameNumber;
                obj.positions{end+1} = position;
            end
        end
        function close(obj)
            obj.closed = true;
        end
    end
end
