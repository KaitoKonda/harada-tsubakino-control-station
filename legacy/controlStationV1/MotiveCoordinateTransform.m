classdef MotiveCoordinateTransform
    %MOTIVECOORDINATETRANSFORM Convert Motive Y-up poses to ROS Z-up poses.

    methods (Static)
        function [positionROS, quaternionROS] = toROS(positionMotive, quaternionMotive)
            arguments
                positionMotive (1,3) double
                quaternionMotive (1,4) double
            end

            % Motive: X right, Y up, Z backward/forward according to its
            % right-handed frame. ROS frame used here: x=X, y=-Z, z=Y.
            C = [1 0 0; 0 0 -1; 0 1 0];
            positionROS = (C * positionMotive(:)).';

            rotationMotive = MotiveCoordinateTransform.quaternionToRotation(quaternionMotive);
            rotationROS = C * rotationMotive * C.';
            quaternionROS = MotiveCoordinateTransform.rotationToQuaternion(rotationROS);
        end
    end

    methods (Static, Access = private)
        function R = quaternionToRotation(q)
            q = q / norm(q);
            x = q(1); y = q(2); z = q(3); w = q(4);
            R = [1-2*(y*y+z*z), 2*(x*y-z*w),   2*(x*z+y*w); ...
                 2*(x*y+z*w),   1-2*(x*x+z*z), 2*(y*z-x*w); ...
                 2*(x*z-y*w),   2*(y*z+x*w),   1-2*(x*x+y*y)];
        end

        function q = rotationToQuaternion(R)
            % Numerically stable matrix-to-quaternion conversion, [x y z w].
            if trace(R) > 0
                s = 2 * sqrt(trace(R) + 1);
                q = [(R(3,2)-R(2,3))/s, (R(1,3)-R(3,1))/s, ...
                     (R(2,1)-R(1,2))/s, s/4];
            elseif R(1,1) > R(2,2) && R(1,1) > R(3,3)
                s = 2 * sqrt(1 + R(1,1) - R(2,2) - R(3,3));
                q = [s/4, (R(1,2)+R(2,1))/s, (R(1,3)+R(3,1))/s, ...
                     (R(3,2)-R(2,3))/s];
            elseif R(2,2) > R(3,3)
                s = 2 * sqrt(1 + R(2,2) - R(1,1) - R(3,3));
                q = [(R(1,2)+R(2,1))/s, s/4, (R(2,3)+R(3,2))/s, ...
                     (R(1,3)-R(3,1))/s];
            else
                s = 2 * sqrt(1 + R(3,3) - R(1,1) - R(2,2));
                q = [(R(1,3)+R(3,1))/s, (R(2,3)+R(3,2))/s, s/4, ...
                     (R(2,1)-R(1,2))/s];
            end
            q = q / norm(q);
            if q(4) < 0
                q = -q;
            end
        end
    end
end
