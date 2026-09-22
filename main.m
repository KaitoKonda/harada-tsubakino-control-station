function main
    clear variables
    close all

    DESKTOP_IP = '192.168.11.53';
    try
        rosinit('http://localhost:11311','NodeHost',DESKTOP_IP)
    catch
    end

    % Read vehicle settings and register each vehicle object.
    vehicleSettings = readmatrix('vehiclesMyDesk.xlsx','OutputType','string','Range','A2');
    vehicles = RegisterVehicles(vehicleSettings);
    vehicleNames = fieldnames(vehicles);
    vehicleCleanup = onCleanup(@() CleanupVehicles(vehicles)); %#ok<NASGU>

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

        for i = 1:length(vehicleNames)
            vehicles.(vehicleNames{i}).update(rate);
            vehicles.(vehicleNames{i}).print;
        end

        commands = ControllerOneLine(vehicles);

        for i = 1:length(vehicleNames)
            vehicles.(vehicleNames{i}).send(commands.(vehicleNames{i}));
        end

        [~] = waitfor(rate);
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