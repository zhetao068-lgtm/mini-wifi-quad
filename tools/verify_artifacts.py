"""Verify portable release artifacts with Python's standard library.

These checks cover delivered geometry and integrity, not physical flight.
The historical 63-check design report is preserved separately in data/.
"""
from collections import Counter, defaultdict
from pathlib import Path
import hashlib
import json
import math
import struct
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def check_stl(path, record):
    data = path.read_bytes()
    count = struct.unpack_from("<I", data, 80)[0]
    require(len(data) == 84 + 50 * count, f"Invalid STL length: {path.name}")
    require(sha256(data) == record["sha256"], f"STL hash mismatch: {path.name}")
    edges = Counter()
    adjacency = defaultdict(set)
    points = set()
    volume = 0.0
    for offset in range(84, len(data), 50):
        values = struct.unpack_from("<12fH", data, offset)
        vertices = [tuple(values[j:j + 3]) for j in (3, 6, 9)]
        require(all(math.isfinite(v) for vertex in vertices for v in vertex), "Nonfinite vertex")
        keys = [tuple(round(v, 6) for v in vertex) for vertex in vertices]
        require(len(set(keys)) == 3, f"Degenerate triangle: {path.name}")
        points.update(keys)
        for a, b in zip(keys, keys[1:] + keys[:1]):
            edges[tuple(sorted((a, b)))] += 1
            adjacency[a].add(b)
            adjacency[b].add(a)
        a, b, c = vertices
        volume += (a[0] * (b[1] * c[2] - b[2] * c[1])
                   - a[1] * (b[0] * c[2] - b[2] * c[0])
                   + a[2] * (b[0] * c[1] - b[1] * c[0])) / 6
    require(all(count == 2 for count in edges.values()), f"Open/nonmanifold edge: {path.name}")
    unseen = set(points)
    start = unseen.pop()
    pending = [start]
    while pending:
        for vertex in adjacency[pending.pop()]:
            if vertex in unseen:
                unseen.remove(vertex)
                pending.append(vertex)
    require(not unseen, f"Disconnected mesh: {path.name}")
    size = [max(p[i] for p in points) - min(p[i] for p in points) for i in range(3)]
    require(all(abs(a - b) < 0.0001 for a, b in zip(size, record["size_mm"])),
            f"STL envelope mismatch: {path.name}")
    require(abs(abs(volume) - record["volume_mm3"]) < 0.01, f"STL volume mismatch: {path.name}")


def main():
    manifest = json.loads((ROOT / "manifest-v0.7.0.json").read_text(encoding="utf-8"))
    for record in manifest["files"]:
        path = ROOT / record["path"]
        require(path.is_file(), f"Missing file: {record['path']}")
        content = path.read_bytes()
        require(len(content) == record["bytes"] and sha256(content) == record["sha256"],
                f"Release hash mismatch: {record['path']}")

    structure = json.loads((ROOT / "data/structure-check-v07.json").read_text(encoding="utf-8"))
    for name, record in structure["parts"].items():
        check_stl(ROOT / "cad" / name, record)
    mass = sum(record["petg_unit_theory_g"] * record["quantity"]
               for record in structure["parts"].values() if record["installed"])
    require(abs(mass - structure["petg_installed_theory_g"]) < 0.00001, "Printed mass mismatch")
    scene = ROOT / "cad/quad-v07-assembly-r21.c4d"
    require(sha256(scene.read_bytes()) == structure["native_scene_sha256"], "C4D scene hash mismatch")

    ns = {"m": "http://schemas.microsoft.com/3dmanufacturing/core/2015/02"}
    with zipfile.ZipFile(ROOT / "cad/quad-v07-assembly-geometry.3mf") as archive:
        require(archive.testzip() is None, "3MF archive CRC failure")
        model = ET.fromstring(archive.read("3D/3dmodel.model"))
        require(model.attrib["unit"] == "millimeter", "Unexpected 3MF unit")
        require(len(model.findall("m:resources/m:object", ns)) == 5, "Expected 5 3MF objects")
        require(len(model.findall("m:build/m:item", ns)) == 9, "Expected 9 3MF instances")

    upstream_dir = ROOT / "software/programming"
    upstream = json.loads((upstream_dir / "upstream-source-manifest.json").read_text(encoding="utf-8"))
    with zipfile.ZipFile(upstream_dir / "esp-drone-source-9d5a4f8.zip") as archive:
        require(archive.testzip() is None, "Upstream archive CRC failure")
        files = {name for name in archive.namelist() if not name.endswith("/")}
        require(files == {record["file"] for record in upstream["files"]}, "Upstream file set mismatch")
        for record in upstream["files"]:
            require(sha256(archive.read(record["file"])) == record["sha256"],
                    f"Upstream hash mismatch: {record['file']}")

    print(json.dumps({
        "passed": True,
        "manifest_files": len(manifest["files"]),
        "closed_connected_stl_files": len(structure["parts"]),
        "assembly_instances": 9,
        "upstream_source_files": len(upstream["files"]),
        "physical_hardware_or_flight_verified": False,
    }, indent=2))


if __name__ == "__main__":
    main()
