function commands = ControllerStop(vehicles)
%CONTROLLERSTOP Safe default for any selected set of vehicles.
    commands = struct();
    for name = string(fieldnames(vehicles)).'
        commands.(name) = [0 0];
    end
end
