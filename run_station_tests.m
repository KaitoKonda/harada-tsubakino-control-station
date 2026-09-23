% Run only local tests: no ROS master, Motive, or physical vehicle is used.
root=fileparts(mfilename('fullpath'));
addpath(root);
results=runtests(fullfile(root,["test_Station.m","test_StationLifecycle.m","test_MotiveCoordinateTransform.m","test_MotiveFrameAdapter.m"]));
disp(table(results));
assert(all([results.Passed]),'Station:TestFailure','At least one station test failed.');
