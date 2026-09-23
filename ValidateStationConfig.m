function ValidateStationConfig(config)
%VALIDATESTATIONCONFIG Reject invalid settings before opening any transports.
    for field=["rateHz","durationSeconds","connectionTimeoutSeconds", ...
            "odometryTimeoutSeconds","maxSpeed","maxAngularVelocity"]
        assert(isfield(config,field),'Station:InvalidConfig','Missing setting: %s',field);
        validateattributes(config.(field),{'numeric'},{'scalar','real','finite','positive'},mfilename,char(field));
    end
    assert(isfield(config,'controller') && isa(config.controller,'function_handle'), ...
        'Station:InvalidConfig','controller must be a function handle.');
    assert(isfield(config,'vehicleFile') && isfile(config.vehicleFile), ...
        'Station:InvalidConfig','vehicleFile does not exist.');
    assert(isfield(config,'logDirectory') && strlength(string(config.logDirectory))>0, ...
        'Station:InvalidConfig','logDirectory is required.');
end
