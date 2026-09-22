#!/usr/bin/env python3
"""Simple UDP dummy vehicle for manager-side integration tests.

Example:
    python dummy_udp_vehicle.py --manager-ip 127.0.0.1 --odometry-port 12345 \
        --command-port 23456 --odometry-type "speed&angularVelocity" --rate-hz 20
"""

from __future__ import annotations

import argparse
import math
import socket
import struct
import time


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="UDP dummy vehicle")
    parser.add_argument("--manager-ip", default="127.0.0.1")
    parser.add_argument("--odometry-port", type=int, default=12345)
    parser.add_argument("--command-port", type=int, default=34567)
    parser.add_argument(
        "--odometry-type",
        default="speed&angularVelocity",
        choices=["position&orientation", "speed&angularVelocity", "velocity&angularVelocity"],
    )
    parser.add_argument("--rate-hz", type=float, default=20.0)
    return parser.parse_args()


def pack_doubles(values: list[float]) -> bytes:
    return struct.pack(">" + "d" * len(values), *values)  # big-endian doubles


def unpack_doubles(data: bytes) -> list[float]:
    count = len(data) // 8
    if count == 0:
        return []
    return list(struct.unpack(">" + "d" * count, data[: count * 8]))


def main() -> None:
    args = parse_args()

    odom_tx = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    cmd_rx = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    cmd_rx.bind(("", args.command_port))
    cmd_rx.setblocking(False)

    print(
        "Dummy UDP vehicle started: "
        f"odometry->{args.manager_ip}:{args.odometry_port}, "
        f"commandPort={args.command_port}, type={args.odometry_type}"
    )
    print("Press Ctrl+C to stop.")

    dt = 1.0 / args.rate_hz
    x = 0.0
    y = 0.0
    theta = 0.0
    v = 0.5
    w = 0.3
    seq = 0

    try:
        while True:
            start = time.perf_counter()
            seq += 1

            if args.odometry_type == "position&orientation":
                x += v * math.cos(theta) * dt
                y += v * math.sin(theta) * dt
                theta += w * dt
                packet = [x, y, theta]
            else:
                # Keep MATLAB compatibility for speed mode:
                # [seq, speed, angularVelocity]
                packet = [float(seq), v, w]

            odom_tx.sendto(pack_doubles(packet), (args.manager_ip, args.odometry_port))

            # Optional command read for visibility during testing.
            while True:
                try:
                    data, _ = cmd_rx.recvfrom(4096)
                except BlockingIOError:
                    break
                command = unpack_doubles(data)
                if command:
                    print(f"Received command: {command}")

            elapsed = time.perf_counter() - start
            sleep_time = dt - elapsed
            if sleep_time > 0:
                time.sleep(sleep_time)
    except KeyboardInterrupt:
        print("Stopping dummy UDP vehicle.")
    finally:
        cmd_rx.close()
        odom_tx.close()


if __name__ == "__main__":
    main()
