classdef StartupTestRunner < station.StationRunner
    properties
        testVehicle
        testWindow
        testMap
    end
    methods
        function obj = StartupTestRunner(config, experiment, settings, options)
            obj@station.StationRunner("experiment", config, experiment, settings, options);
            obj.testVehicle = StartupTestVehicle(settings, config.odometryTimeoutSeconds);
            obj.testWindow = StartupTestWindow();
            obj.testMap = StartupTestMap();
        end
    end
    methods (Access = protected)
        function vehicle = createVehicle(obj, ~), vehicle = obj.testVehicle; end
        function window = createControlWindow(obj), window = obj.testWindow; end
        function map = createPositionMap(obj), map = obj.testMap; end
    end
end
