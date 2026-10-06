function commands = ValidateCommands(commands, vehicles, config)
%VALIDATECOMMANDS Validate the whole batch before any vehicle receives a command.
    names = fieldnames(vehicles);
    assert(isstruct(commands) && isscalar(commands) && ...
        isequal(sort(fieldnames(commands)), sort(names)), ...
        'Station:InvalidCommands', 'Controller must return exactly one command per selected vehicle.');
    for i = 1:numel(names)
        value = commands.(names{i});
        assert(isnumeric(value) && isreal(value) && numel(value)==2 && ...
            all(isfinite(value(:))), 'Station:InvalidCommands', ...
            'Command for %s must contain two finite real numbers.',names{i});
        value = double(value(:).');
        assert(abs(value(1))<=config.maxSpeed && abs(value(2))<=config.maxAngularVelocity, ...
            'Station:CommandLimit', 'Command exceeds the configured limit for %s.',names{i});
        commands.(names{i}) = value;
    end
end
