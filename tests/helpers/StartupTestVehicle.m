classdef StartupTestVehicle < handle
    properties
        estimator
        clock
        receiveEnabled = true
        nextSampleAt = 0
        number = 0
        sent = zeros(0,2)
        closed = false
    end
    methods
        function obj = StartupTestVehicle(settings, timeout)
            obj.clock = tic;
            obj.estimator = station.StateEstimator(settings, timeout);
        end
        function poll(obj)
            now = toc(obj.clock);
            if obj.receiveEnabled && now >= obj.nextSampleAt
                obj.number = obj.number + 1;
                obj.estimator.accept(struct('number', obj.number, 'receivedAt', now, ...
                    'value', struct('speed', 0, 'angularVelocity', 0)));
            end
        end
        function [fresh, details] = hasFreshObservation(obj)
            obj.poll();
            details = obj.odometryDiagnostics();
            fresh = details.fresh;
        end
        function details = odometryDiagnostics(obj)
            details = obj.estimator.diagnostics(toc(obj.clock));
        end
        function calibrate(obj)
            obj.poll();
            obj.estimator.calibrate(toc(obj.clock));
        end
        function [fresh, details] = update(obj, dt)
            obj.poll();
            now = toc(obj.clock);
            fresh = obj.estimator.update(dt, now);
            details = obj.estimator.diagnostics(now);
        end
        function state = snapshot(obj), state = obj.estimator.snapshot(); end
        function sent = send(obj, command)
            obj.sent(end+1,:) = command;
            sent = true;
        end
        function errors = close(obj)
            obj.closed = true;
            errors = strings(0,1);
        end
    end
end
