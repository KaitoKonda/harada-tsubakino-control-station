function tests = test_MotiveFrameAdapter
    tests = functiontests(localfunctions);
end

function testWrapperFrame(testCase)
    bodies = struct('ID', {1, 2});
    frame = struct('Frame', uint64(42), 'RigidBody', bodies);

    [frameNumber, rigidBodies] = MotiveFrameAdapter.unpack(frame);

    verifyEqual(testCase, frameNumber, 42);
    verifyEqual(testCase, [rigidBodies.ID], [1, 2]);
end

function testRawFrame(testCase)
    bodies = struct('ID', {3, 4});
    frame = struct('iFrame', 43, 'nRigidBodies', 2, 'RigidBodies', bodies);

    [frameNumber, rigidBodies] = MotiveFrameAdapter.unpack(frame);

    verifyEqual(testCase, frameNumber, 43);
    verifyEqual(testCase, [rigidBodies.ID], [3, 4]);
end

function testUnsupportedFrameReportsHelpfulError(testCase)
    verifyError(testCase, @() MotiveFrameAdapter.unpack(struct('Unknown', 1)), ...
        'MotiveFrameAdapter:UnsupportedFrame');
end
