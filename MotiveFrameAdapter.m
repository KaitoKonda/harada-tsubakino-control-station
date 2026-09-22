classdef MotiveFrameAdapter
    %MOTIVEFRAMEADAPTER Normalize MATLAB wrapper and raw NatNet frames.

    methods (Static)
        function [frameNumber, rigidBodies] = unpack(frame)
            if isempty(frame)
                frameNumber = NaN;
                rigidBodies = [];
                return
            end

            % natnet.m getFrame() wrapper format.
            if isstruct(frame) && isfield(frame, 'Frame') && isfield(frame, 'RigidBody')
                frameNumber = double(frame.Frame);
                rigidBodies = frame.RigidBody;
                return
            end

            % Raw NatNetML FrameOfMocapData format, retained for compatibility.
            if MotiveFrameAdapter.hasMember(frame, 'iFrame') ...
                    && MotiveFrameAdapter.hasMember(frame, 'RigidBodies')
                frameNumber = double(frame.iFrame);
                rigidBodies = frame.RigidBodies;
                return
            end

            error('MotiveFrameAdapter:UnsupportedFrame', ...
                ['Unsupported NatNet frame format. Run fieldnames(frame) or ' ...
                 'properties(frame) and compare it with the installed OptiSample files.'])
        end
    end

    methods (Static, Access = private)
        function result = hasMember(value, name)
            result = (isstruct(value) && isfield(value, name)) ...
                || (isobject(value) && isprop(value, name));
        end
    end
end
