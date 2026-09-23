function result = launch_dummy_vehicles(varargin)
%LAUNCH_DUMMY_VEHICLES Compatibility entry for the self-contained simulation.
% launch_dummy_vehicles(Vehicles="pi1", Duration=10)
% The old managerIP/desktopIP arguments are no longer needed.
    result=main("simulation",varargin{:});
end
