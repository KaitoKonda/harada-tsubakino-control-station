classdef FakeNatNetSource < handle
    properties
        model
        body
        frameNumber double = 0
        advanceFrame logical = true
        returnEmpty logical = false
    end
    methods
        function obj = FakeNatNetSource(bodyName, id)
            obj.model = struct('RigidBodyCount', 1, ...
                'RigidBody', struct('Name', char(bodyName), 'ID', id));
            obj.body = struct('ID', id, 'x', 1, 'y', 2, 'z', 3, ...
                'qx', 0, 'qy', 0, 'qz', 0, 'qw', 1, 'Tracked', true);
        end
        function frame = getFrame(obj)
            if obj.returnEmpty, frame = []; return; end
            if obj.advanceFrame, obj.frameNumber = obj.frameNumber + 1; end
            frame = struct('iFrame', obj.frameNumber, ...
                'nRigidBodies', numel(obj.body), 'RigidBodies', obj.body);
        end
        function close(~)
        end
    end
end
