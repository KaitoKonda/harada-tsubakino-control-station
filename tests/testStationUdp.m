function tests = testStationUdp
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    root = fileparts(fileparts(mfilename('fullpath')));
    testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
end

function testVelocityInputAndCommandOutput(testCase)
    settings = shared.resolveVehicleSettings(shared.vehicleCatalog(), shared.experimentConfig(), ...
        shared.stationConfig(), "simulation", "katchaka");
    settings.odometryInput.localPort = 27531;
    settings.commandOutput.localPort = 27532;
    settings.commandOutput.targetPort = 27533;
    settings.commandOutput.targetIp = "127.0.0.1";
    receiver = udpport("datagram", "IPV4", ...
        "LocalPort", settings.commandOutput.targetPort, "ByteOrder", "big-endian");
    transmitter = udpport("datagram", "IPV4", "ByteOrder", "big-endian");
    vehicle = station.Vehicle(settings, "experiment", 1);
    cleanup = onCleanup(@() release(vehicle, transmitter, receiver)); %#ok<NASGU>
    write(transmitter, [1 0.1 0], "double", ...
        "127.0.0.1", settings.odometryInput.localPort);
    for index = 1:50
        if vehicle.hasFreshObservation(), break; end
        pause(0.02);
    end
    verifyTrue(testCase, vehicle.hasFreshObservation());
    vehicle.calibrate();
    verifyTrue(testCase, vehicle.update(0.05));
    vehicle.send([0.1 -0.2]);
    for index = 1:50
        if receiver.NumDatagramsAvailable > 0, break; end
        pause(0.02);
    end
    verifyGreaterThan(testCase, receiver.NumDatagramsAvailable, 0);
    packets = read(receiver, receiver.NumDatagramsAvailable, "uint8");
    bytes = uint8(packets(end).Data);
    values = typecast(bytes(:), 'double');
    [~, ~, endian] = computer;
    if endian == 'L', values = swapbytes(values); end
    verifyEqual(testCase, double(values(:).'), [0.1 -0.2], 'AbsTol', 1e-12);
end

function testPositionDatagramIsColumnVector(testCase)
    config = struct('protocol', "udp", 'kind', "position", ...
        'localPort', 27534);
    clock = tic;
    source = station.UdpOdometrySource(config, clock);
    transmitter = udpport("datagram", "IPV4", "ByteOrder", "big-endian");
    cleanup = onCleanup(@() releaseSource(source, transmitter)); %#ok<NASGU>
    write(transmitter, [1 2 0.3], "double", "127.0.0.1", config.localPort);
    sample = [];
    for index = 1:50
        sample = source.read();
        if ~isempty(sample), break; end
        pause(0.02);
    end
    verifyNotEmpty(testCase, sample);
    verifyEqual(testCase, sample.value.position, [1;2]);
end

function release(vehicle, transmitter, receiver)
    vehicle.close();
    delete(transmitter);
    delete(receiver);
end

function releaseSource(source, transmitter)
    source.close();
    delete(transmitter);
end
