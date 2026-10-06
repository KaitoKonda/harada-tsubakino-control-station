% MotiveCoordinateTransform：測定座標を ROS 座標へ変える。

classdef MotiveCoordinateTransform
    methods (Static)
        % Motive 位置 [X, Y, Z] と姿勢 [qx, qy, qz, qw] を受け取る。
        % ROS メッセージの作成や NatNet フレームの読み取りはここで行わない。
        function [positionRos, quaternionRos] = toRos(positionMotive, quaternionMotive)
            % 値が有限でクォータニオンの長さがゼロでないかを調べる。
            % 入力不正なら変換値を返さず、どの値が不正かを上位へ知らせる。
            validateattributes(positionMotive, {'numeric'}, ...
                {'real', 'finite', 'numel', 3});
            validateattributes(quaternionMotive, {'numeric'}, ...
                {'real', 'finite', 'numel', 4});
            positionMotive = double(positionMotive(:));
            q = double(quaternionMotive(:).');
            assert(norm(q) > eps, 'Motive:InvalidQuaternion', ...
                'Motive quaternion has zero length.');
            % クォータニオンを正規化し、回転行列 R へ変える。
            q = q / norm(q);
            x = q(1); y = q(2); z = q(3); w = q(4);
            rotation = [1-2*(y*y+z*z), 2*(x*y-z*w),   2*(x*z+y*w); ...
                        2*(x*y+z*w),   1-2*(x*x+z*z), 2*(y*z-x*w); ...
                        2*(x*z-y*w),   2*(y*z+x*w),   1-2*(x*x+y*y)];
            % 現行版の軸対応 x=X、y=-Z、z=Y を表す行列 C を用意する。
            axes = [1 0 0; 0 0 -1; 0 1 0];
            % 位置へ C を掛けて ROS 位置 [x, y, z] を得る。
            positionRos = (axes * positionMotive).';
            % 姿勢は C*R*C' を計算し、ROS 順の [qx, qy, qz, qw] に戻す。
            rotationRos = axes * rotation * axes.';
            % 出力クォータニオンを正規化し、位置と姿勢を返す。
            quaternionRos = bridge.MotiveCoordinateTransform.fromRotation(rotationRos);
        end
    end

    methods (Static, Access = private)
        function q = fromRotation(r)
            if trace(r) > 0
                s = 2 * sqrt(trace(r) + 1);
                q = [(r(3,2)-r(2,3))/s, (r(1,3)-r(3,1))/s, ...
                     (r(2,1)-r(1,2))/s, s/4];
            elseif r(1,1) > r(2,2) && r(1,1) > r(3,3)
                s = 2 * sqrt(1 + r(1,1) - r(2,2) - r(3,3));
                q = [s/4, (r(1,2)+r(2,1))/s, (r(1,3)+r(3,1))/s, ...
                     (r(3,2)-r(2,3))/s];
            elseif r(2,2) > r(3,3)
                s = 2 * sqrt(1 + r(2,2) - r(1,1) - r(3,3));
                q = [(r(1,2)+r(2,1))/s, s/4, (r(2,3)+r(3,2))/s, ...
                     (r(1,3)-r(3,1))/s];
            else
                s = 2 * sqrt(1 + r(3,3) - r(1,1) - r(2,2));
                q = [(r(1,3)+r(3,1))/s, (r(2,3)+r(3,2))/s, s/4, ...
                     (r(2,1)-r(1,2))/s];
            end
            q = q / norm(q);
            if q(4) < 0, q = -q; end
        end
    end
end
