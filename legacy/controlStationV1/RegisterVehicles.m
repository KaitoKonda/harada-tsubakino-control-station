function vehicles = RegisterVehicles(settings, mode, timeout)
%REGISTERVEHICLES Roll back already-created vehicles if one initialization fails.
    vehicles = struct();
    try
        for s=settings
            vehicles.(s.name)=Vehicle(s,mode,timeout);
        end
    catch exception
        StopVehicles(vehicles,true);
        rethrow(exception)
    end
end
