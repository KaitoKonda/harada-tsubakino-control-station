function Calibrate(vehicles, rate)

    % Drop first packets to avoid startup transients.
    dumpLength = 10;
    vehicleNames = fieldnames(vehicles);

    for j = 1:dumpLength

        for i = 1:length(vehicleNames)
            vehicles.(vehicleNames{i}).receive();
        end

        [~] = waitfor(rate);
    end

    for i = 1:length(vehicleNames)
        vehicle = vehicles.(vehicleNames{i});
        odometry = vehicle.receive();

        % Calibrate according to odometry semantics, not communication protocol.
        switch vehicle.odometryType
            case 'position&orientation'
                vehicle.positionOffset    = vehicle.positionOffset - odometry.position;
                vehicle.orientationOffset = vehicle.orientationOffset - odometry.orientation;

            case {'speed&angularVelocity','velocity&angularVelocity'}
                % Initialize integration state from configured offsets.
                vehicle.position    = vehicle.positionOffset;
                vehicle.orientation = vehicle.orientationOffset;

            otherwise
                error('Invalid odometryType for %s', vehicle.name)
        end
    end
end