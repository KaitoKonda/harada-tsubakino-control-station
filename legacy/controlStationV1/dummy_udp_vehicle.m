function dummy_udp_vehicle(managerIP, odometryPort, commandPort, odometryType, rateHz)
%DUMMY_UDP_VEHICLE Standalone loopback transport test with a 0.25 s command timeout.
% dummy_udp_vehicle("127.0.0.1",12345,34567,"speed&angularVelocity",20)
    if nargin<1, managerIP="127.0.0.1"; end
    if nargin<2, odometryPort=12345; end
    if nargin<3, commandPort=34567; end
    if nargin<4, odometryType="speed&angularVelocity"; end
    if nargin<5, rateHz=20; end
    validateattributes(rateHz,{'numeric'},{'scalar','positive','finite'});
    assert(ismember(string(odometryType),["position&orientation","speed&angularVelocity"]), ...
        'Station:InvalidSettings','Unsupported UDP odometry type.');
    odometryTx=udpport("datagram","IPV4","ByteOrder","big-endian");
    commandRx=udpport("datagram","IPV4","LocalPort",commandPort,"ByteOrder","big-endian");
    cleaner=onCleanup(@() release(odometryTx,commandRx));
    fprintf('Dummy UDP: state -> %s:%d, command port=%d. Ctrl+C to stop.\n', ...
        managerIP,odometryPort,commandPort);
    x=0; y=0; theta=0; v=0; w=0; seq=0;
    received=[];
    previous=tic;
    while true
        step=tic;
        dt=toc(previous);
        previous=tic;
        count=commandRx.NumDatagramsAvailable;
        if count>0
            packets=read(commandRx,count,"uint8");
            for k=1:numel(packets)
                bytes=uint8(packets(k).Data);
                if numel(bytes)~=16, continue; end
                command=typecast(bytes(:),'double');
                [~,~,endian]=computer;
                if endian=='L', command=swapbytes(command); end
                if all(isfinite(command))
                    v=command(1); w=command(2); received=tic;
                end
            end
        end
        if isempty(received) || toc(received)>0.25
            v=0; w=0;
        end
        x=x+v*cos(theta)*dt;
        y=y+v*sin(theta)*dt;
        theta=theta+w*dt;
        seq=seq+1;
        if odometryType=="position&orientation"
            packet=[x y theta];
        else
            packet=[seq v w];
        end
        write(odometryTx,packet,"double",managerIP,odometryPort);
        pause(max(0,1/rateHz-toc(step)));
    end
end

function release(tx,rx)
    delete(rx);
    delete(tx);
end
