function Calibrate(vehicles)
%CALIBRATE Explicit global coordinates or a rigid transform to initial pose.
    for name=string(fieldnames(vehicles)).'
        vehicles.(name).calibrate();
    end
end
