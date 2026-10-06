classdef FakeNatNetSource < handle
    properties
        model
        body
        frameNumber double = 0
    end
    methods
        function obj = FakeNatNetSource(bodyName, id)
            obj.model = struct('RigidBodyCount', 1, ...
                'RigidBody', struct('Name', char(bodyName), 'ID', id));
            obj.body = struct('ID', id, 'x', 1, 'y', 2, 'z', 3, ...
                'qx', 0, 'qy', 0, 'qz', 0, 'qw', 1, 'Tracked', true);
        end
        function frame = getFrame(obj)
            obj.frameNumber = obj.frameNumber + 1;
            frame = struct('iFrame', obj.frameNumber, ...
                'nRigidBodies', 1, 'RigidBodies', obj.body);
        end
        function close(~)
        end
    end
end
