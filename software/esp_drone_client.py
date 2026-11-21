# SPDX-License-Identifier: GPL-3.0-only
"""ESP-Drone CRTP/UDP workbench client, verified against upstream 9d5a4f8.

This is a host client, not flight-controller firmware and not a white-label
drone protocol. Default invocation only prints a packet; --send enables UDP.
"""
from __future__ import annotations
import argparse
import json
import math
import socket
import struct
import time

DEFAULT_HOST = "192.168.43.42"
DEFAULT_PORT = 2390
MAX_CRTP_BYTES = 31


def encode_frame(header: int, payload: bytes = b"") -> bytes:
    if not isinstance(header, int) or not 0 <= header <= 255:
        raise ValueError("header must be one byte")
    raw = bytes([header]) + bytes(payload)
    if len(raw) > MAX_CRTP_BYTES:
        raise ValueError("CRTP header plus payload must be at most 31 bytes")
    return raw + bytes([sum(raw) & 0xFF])


def decode_frame(datagram: bytes) -> tuple[int, bytes]:
    if not 2 <= len(datagram) <= 32:
        raise ValueError("UDP frame length must be 2..32")
    if (sum(datagram[:-1]) & 0xFF) != datagram[-1]:
        raise ValueError("checksum mismatch")
    return datagram[0], datagram[1:-1]


def setpoint_frame(roll: float = 0, pitch: float = 0, yaw_rate: float = 0,
                   thrust: int = 0) -> bytes:
    """Legacy RPYT in stabilize mode: degrees, degrees, deg/s, raw thrust."""
    for label, value, limit in (("roll", roll, 15), ("pitch", pitch, 15), ("yaw", yaw_rate, 90)):
        if not math.isfinite(value) or abs(value) > limit:
            raise ValueError(f"{label} must be finite and within +/-{limit}")
    if isinstance(thrust, bool) or not isinstance(thrust, int) or not 0 <= thrust <= 60000:
        raise ValueError("thrust must be an integer in 0..60000")
    return encode_frame(0x30, struct.pack("<fffH", roll, pitch, yaw_rate, thrust))


def transmit(sock: socket.socket, destination: tuple[str, int], frame: bytes) -> int:
    decode_frame(frame)
    return sock.sendto(frame, destination)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--roll", type=float, default=0)
    parser.add_argument("--pitch", type=float, default=0)
    parser.add_argument("--yaw", type=float, default=0)
    parser.add_argument("--thrust", type=int, default=0)
    parser.add_argument("--send", action="store_true", help="send to the specified ESP-Drone")
    parser.add_argument("--seconds", type=float, default=.5, help="bench session, 0..2 s")
    parser.add_argument("--listen", type=float, default=0, help="receive console/CRTP data, 0..10 s")
    args = parser.parse_args()
    if not 1 <= args.port <= 65535 or not 0 <= args.seconds <= 2 or not 0 <= args.listen <= 10:
        parser.error("port or duration outside the documented range")
    try:
        frame = setpoint_frame(args.roll, args.pitch, args.yaw, args.thrust)
    except (ValueError, TypeError) as exc:
        parser.error(str(exc))
    print(json.dumps({"destination": [args.host, args.port], "hex": frame.hex(),
                      "bytes": len(frame), "network_enabled": args.send}))
    if not args.send:
        return
    destination = (args.host, args.port)
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.settimeout(.1)
        zero = setpoint_frame()
        try:
            # The firmware requires an initial zero-thrust packet to unlock RPYT.
            transmit(sock, destination, zero)
            until = time.monotonic() + args.seconds
            while time.monotonic() < until:
                transmit(sock, destination, frame)
                time.sleep(.05)
            until = time.monotonic() + args.listen
            while time.monotonic() < until:
                transmit(sock, destination, zero)
                try:
                    response, address = sock.recvfrom(128)
                    if address[0] != socket.gethostbyname(args.host):
                        continue
                    header, payload = decode_frame(response)
                    text = payload.decode("utf-8", errors="replace") if header >> 4 == 0 else None
                    print(json.dumps({"header": header, "payload_hex": payload.hex(), "console": text}))
                except socket.timeout:
                    pass
                except ValueError as exc:
                    print(json.dumps({"discarded_response": str(exc)}))
        finally:
            for _ in range(3):
                transmit(sock, destination, zero)
        print("UDP session ended. No aircraft state or flight result was verified.")


if __name__ == "__main__":
    main()
