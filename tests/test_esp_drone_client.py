# SPDX-License-Identifier: GPL-3.0-only
"""Meaningful packet and loopback checks; no physical aircraft connection."""
from pathlib import Path
import importlib.util
import json
import math
import socket
import struct
import unittest

ROOT=Path(__file__).resolve().parent.parent
path=ROOT/"software/esp_drone_client.py"
spec=importlib.util.spec_from_file_location("esp_drone_client",path)
client=importlib.util.module_from_spec(spec)
spec.loader.exec_module(client)


class ProtocolChecks(unittest.TestCase):
    def test_zero_vector_against_upstream_layout(self):
        self.assertEqual(client.setpoint_frame(),bytes.fromhex("30"+"00"*14+"30"))

    def test_nonzero_little_endian_and_checksum(self):
        raw=client.setpoint_frame(1.5,-2.5,10,12000)
        head,payload=client.decode_frame(raw)
        self.assertEqual(head,0x30)
        self.assertEqual(struct.unpack("<fffH",payload),(1.5,-2.5,10,12000))
        self.assertEqual(raw[-1],sum(raw[:-1])&255)

    def test_corrupt_frame_is_rejected(self):
        raw=bytearray(client.setpoint_frame());raw[2]^=1
        with self.assertRaises(ValueError):client.decode_frame(bytes(raw))

    def test_invalid_lengths_are_rejected(self):
        for raw in (b"",b"0",b"x"*33):
            with self.assertRaises(ValueError):client.decode_frame(raw)
        with self.assertRaises(ValueError):client.encode_frame(0,b"x"*31)

    def test_thrust_and_angles_are_validated(self):
        for thrust in (-1,60001,1.5,True):
            with self.assertRaises(ValueError):client.setpoint_frame(thrust=thrust)
        for angle in (16,float("inf"),float("nan")):
            with self.assertRaises(ValueError):client.setpoint_frame(roll=angle)

    def test_limit_is_encoded_without_rounding_or_clipping(self):
        _,payload=client.decode_frame(client.setpoint_frame(-15,15,-90,60000))
        self.assertEqual(struct.unpack("<fffH",payload),(-15,15,-90,60000))

    def test_actual_udp_loopback(self):
        with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as server, socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as sender:
            server.bind(("127.0.0.1",0));server.settimeout(1)
            frame=client.setpoint_frame()
            self.assertEqual(client.transmit(sender,server.getsockname(),frame),16)
            received,_=server.recvfrom(64)
            self.assertEqual(received,frame)


if __name__ == "__main__":
    unittest.main(verbosity=2)
