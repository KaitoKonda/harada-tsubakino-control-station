function dummy_udp_vehicle(managerIP, odometryPort, commandPort, odometryType, rateHz)
% DUMMY_UDP_VEHICLE Simple UDP dummy vehicle for manager-side integration tests.
%   dummy_udp_vehicle("127.0.0.1",12345,23456,"speed&angularVelocity",20)

    if nargin < 1 || strlength(managerIP) == 0
        managerIP = "127.0.0.1";
    end
    if nargin < 2 || isempty(odometryPort)
        odometryPort = 12345;
    end
    if nargin < 3 || isempty(commandPort)
        commandPort = 23456;
    end
    if nargin < 4 || strlength(odometryType) == 0
        odometryType = "speed&angularVelocity";
    end
    if nargin < 5 || isempty(rateHz)
        rateHz = 20;
    end

    odometryTx = udpport("ByteOrder","big-endian");
    commandRx  = udpport("LocalPort",commandPort,"ByteOrder","big-endian");
    cleaner = onCleanup(@() localCleanup(odometryTx, commandRx)); %#ok<NASGU>

    fprintf("Dummy UDP vehicle started: odometry->%s:%d, commandPort=%d, type=%s\n", ...
        managerIP, odometryPort, commandPort, odometryType);
    fprintf("Press Ctrl+C to stop.\n");

    t = 0;
    dt = 1 / rateHz;
    x = 0;
    y = 0;
    theta = 0;
    v = 0.5;
    w = 0.3;
    seq = 0;

    while true
        t = t + dt;
        seq = seq + 1;

        switch odometryType
            case "position&orientation"
                x = x + v * cos(theta) * dt;
                y = y + v * sin(theta) * dt;
                theta = theta + w * dt;
                packet = [x, y, theta];

            case {"speed&angularVelocity","velocity&angularVelocity"}
                packet = [double(seq), v, w];

            otherwise
                error("Unsupported odometryType: %s", odometryType)
        end

        write(odometryTx, packet, "double", managerIP, odometryPort);

        % Optional command read for visibility during testing.
        if commandRx.NumBytesAvailable >= 16
            command = read(commandRx, floor(commandRx.NumBytesAvailable / 8), "double");
            fprintf("Received command: %s\n", mat2str(command(:).'));
        end

        pause(dt);
    end
end

function localCleanup(odometryTx, commandRx)
    if ~isempty(commandRx)
        delete(commandRx)
    end
    if ~isempty(odometryTx)
        delete(odometryTx)
    end
end
