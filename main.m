function main
    clear variables
    close all

    config = motive_config();
    try
        rosinit(char(config.rosMasterURI), 'NodeHost', char(config.rosNodeHost))
    catch exception
        % Reuse a working global ROS node, but do not hide real startup errors.
        try
            rosnode('list');
            warning('Reusing the existing MATLAB ROS node. motive_config.m was not reapplied.')
        catch
            rethrow(exception)
        end
    end

    % Read vehicle settings and register each vehicle object.
    vehicleSettings = readmatrix('vehiclesMyDesk.xlsx','OutputType','string','Range','A2');
    vehicles = RegisterVehicles(vehicleSettings);
    vehicleNames = fieldnames(vehicles);
    vehicleCleanup = onCleanup(@() CleanupVehicles(vehicles));

    % Main loop rate.
    freq = 20;
    rate = rosrate(freq);

    % Wait for initial communication from all vehicles.
    EstablishConnection(vehicles, rate)

    Calibrate(vehicles, rate)

    Standby(vehicles, rate)

    progress = waitbar(0, 'Iteration 0', 'Name', 'simulation message', 'CreateCancelBtn', 'delete(gcbf)', 'WindowStyle', 'alwaysontop');

    maximumIteration = 5000;
    for j = 1:maximumIteration
        time = rate.TotalElapsedTime;
        fprintf('Step: %d - Time Elapsed: %f\n',j,time)

        if ~ishandle(progress)
            disp('Stopped by user.');
            break
        else
            waitbar(j/maximumIteration, progress, ['Iteration ' num2str(j)]);
        end

        odometryFresh = false(1, length(vehicleNames));
        for i = 1:length(vehicleNames)
            odometryFresh(i) = vehicles.(vehicleNames{i}).update(rate);
            vehicles.(vehicleNames{i}).print;
        end

        if ~all(odometryFresh)
            warning('Stale odometry detected. Sending zero commands: %s', ...
                mat2str(odometryFresh))
            SendZeroCommands(vehicles);
            [~] = waitfor(rate);
            continue
        end

        commands = ControllerOneLine(vehicles);

        for i = 1:length(vehicleNames)
            vehicles.(vehicleNames{i}).send(commands.(vehicleNames{i}));
        end

        [~] = waitfor(rate);
    end
end

function SendZeroCommands(vehicles)
    vehicleNames = fieldnames(vehicles);
    for i = 1:length(vehicleNames)
        vehicles.(vehicleNames{i}).send([0, 0]);
    end
end

function CleanupVehicles(vehicles)
    vehicleNames = fieldnames(vehicles);
    for i = 1:length(vehicleNames)
        vehicle = vehicles.(vehicleNames{i});
        if ~isempty(vehicle) && isvalid(vehicle)
            delete(vehicle);
        end
    end
end

function Standby(vehicles, rate)
    standbyButton = waitbar(1, sprintf('All vehicles standby.\n Close this dialogue to start the simulation.'),...
        'Name', 'simulation message', 'CreateCancelBtn', 'delete(gcbf)', 'WindowStyle', 'alwaysontop');
    disp('All vehicles standby.')
    vehicleNames = fieldnames(vehicles);
    while ishandle(standbyButton)
        for i = 1:length(vehicleNames)
            vehicles.(vehicleNames{i}).update(rate);
        end
        [~] = waitfor(rate);
    end
end
