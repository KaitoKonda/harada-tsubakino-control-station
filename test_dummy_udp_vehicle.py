"""Loopback-only checks of the standalone Python dummy."""
import pathlib
import socket
import struct
import subprocess
import sys
import time
import unittest


class DummyUDPTest(unittest.TestCase):
    def test_command_motion_zero_and_timeout(self):
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as odom, \
                socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as command:
            odom.bind(("127.0.0.1", 0))
            odom.settimeout(0.2)
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
                probe.bind(("127.0.0.1", 0))
                command_port = probe.getsockname()[1]
            process = subprocess.Popen(
                [sys.executable, str(pathlib.Path(__file__).with_name("dummy_udp_vehicle.py")),
                 "--manager-ip", "127.0.0.1", "--odometry-port", str(odom.getsockname()[1]),
                 "--command-port", str(command_port), "--rate-hz", "50"],
                stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
            )
            try:
                def wait_for(expected):
                    deadline = time.monotonic() + 3
                    while time.monotonic() < deadline:
                        try:
                            data, _ = odom.recvfrom(1024)
                        except socket.timeout:
                            continue
                        value = struct.unpack(">ddd", data)
                        if value[1:] == expected:
                            return
                    self.fail(f"No state with speed/angular velocity {expected}")

                wait_for((0.0, 0.0))
                command.sendto(struct.pack(">dd", -0.1, 0.2), ("127.0.0.1", command_port))
                wait_for((-0.1, 0.2))
                command.sendto(struct.pack(">dd", 0, 0), ("127.0.0.1", command_port))
                wait_for((0.0, 0.0))
                command.sendto(struct.pack(">dd", 0.1, 0), ("127.0.0.1", command_port))
                wait_for((0.1, 0.0))
                wait_for((0.0, 0.0))
            finally:
                process.terminate()
                process.communicate(timeout=5)


if __name__ == "__main__":
    unittest.main()
