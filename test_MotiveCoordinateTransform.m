function tests = test_MotiveCoordinateTransform
    tests = functiontests(localfunctions);
end

function testIdentityPoseUsesExpectedAxisMapping(testCase)
    [position, quaternion] = MotiveCoordinateTransform.toROS([1 2 3], [0 0 0 1]);
    verifyEqual(testCase, position, [1 -3 2], 'AbsTol', 1e-12);
    verifyEqual(testCase, quaternion, [0 0 0 1], 'AbsTol', 1e-12);
end

function testPositiveMotiveYawBecomesPositiveRosYaw(testCase)
    halfAngle = pi / 4;
    motiveQuaternion = [0 sin(halfAngle) 0 cos(halfAngle)];
    [~, rosQuaternion] = MotiveCoordinateTransform.toROS([0 0 0], motiveQuaternion);
    expected = [0 0 sin(halfAngle) cos(halfAngle)];
    verifyEqual(testCase, rosQuaternion, expected, 'AbsTol', 1e-12);
end

function testQuaternionOutputIsNormalized(testCase)
    [~, quaternion] = MotiveCoordinateTransform.toROS([0 0 0], [0.2 0.3 0.4 0.5]);
    verifyEqual(testCase, norm(quaternion), 1, 'AbsTol', 1e-12);
end
