function errors = StopVehicles(vehicles, release)
%STOPVEHICLES Always attempt every vehicle, even if an earlier stop failed.
    if nargin<2, release=false; end
    errors=strings(0,1);
    for name=string(fieldnames(vehicles)).'
        try
            vehicle=vehicles.(name);
            if isempty(vehicle) || ~isvalid(vehicle), continue; end
            if release
                delete(vehicle);
            else
                vehicle.send([0 0]);
            end
        catch exception
            errors(end+1)=name+": "+string(exception.message); %#ok<AGROW>
            warning('Station:StopFailed','%s',errors(end));
        end
    end
end
