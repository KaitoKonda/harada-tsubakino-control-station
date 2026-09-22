function vehicles = RegisterVehicles(vehicleSettings)

    numberofVehicles = size(vehicleSettings,1);

    for i = 1:numberofVehicles
        vehicleName            = vehicleSettings(i,1);
        vehicles.(vehicleName) = Vehicle(vehicleSettings(i,:));
    end

end