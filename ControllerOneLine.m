function commands = ControllerOneLine(vehicles)

    % One line formation.
    
    pi1 = vehicles.pi1;
    pi2 = vehicles.pi2;
    pi3 = vehicles.pi3;
    katchaka = vehicles.katchaka;

    % TODO

    V1 = 0; omega1 = 0;
    V2 = 0; omega2 = 0;
    V3 = 0; omega3 = 0;
    Vk = 0; omegak = 0;

    commands.pi1 = [V1, omega1];
    commands.pi2 = [V2, omega2];
    commands.pi3 = [V3, omega3];
    commands.katchaka = [Vk, omegak];

end