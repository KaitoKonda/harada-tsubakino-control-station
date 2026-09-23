function EstablishConnection(vehicles, config)
%ESTABLISHCONNECTION Wait in wall-clock seconds and identify missing vehicles.
    started=tic;
    names=string(fieldnames(vehicles)).';
    connected=false(size(names));
    while toc(started)<config.connectionTimeoutSeconds
        stopErrors=StopVehicles(vehicles);
        assert(isempty(stopErrors),'Station:StopFailed','A zero command could not be sent.');
        for i=1:numel(names)
            connected(i)=~isempty(vehicles.(names(i)).receive());
        end
        if all(connected), return; end
        pause(1/config.rateHz);
    end
    error('Station:ConnectionTimeout','No fresh odometry from: %s',strjoin(names(~connected),', '));
end
