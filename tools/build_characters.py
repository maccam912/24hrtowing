"""Build the three winter roadside characters and their shared texture atlas.

Run with python3 tools/build_characters.py. The output GLBs are editable in Blender
and import directly into Godot. Contour coordinates are metres in Godot/glTF
coordinates (+Y up, -Z facing forward); each leg joint rotates around its own
anatomical pivot. No external models, textures, or Python packages are required.
"""

import functools
import itertools
import json
import math
import operator
import random
import struct
import zlib
from math import cos, pi, sin, sqrt
from pathlib import Path

DEST = Path(__file__).resolve().parents[1] / "assets" / "characters"
PALETTE = [
    "262728",
    "343e43",
    "363736",
    "374658",
    "38453f",
    "39464d",
    "3c4541",
    "414b46",
    "453d38",
    "46566a",
    "46595b",
    "473e38",
    "483f38",
    "4b5652",
    "514440",
    "514740",
    "515c69",
    "58676b",
    "5c5549",
    "616e79",
    "665048",
    "666e64",
    "6f7673",
    "705e4b",
    "776858",
    "7b6650",
    "804732",
    "8a5e51",
    "8b7861",
    "8d765a",
    "978269",
    "996c63",
    "a26049",
    "a79072",
    "ad8570",
    "ae9e72",
    "b0a47d",
    "b59d7c",
    "b9ac91",
    "ba927f",
    "bd795a",
    "bd8875",
    "c48d77",
    "c69d84",
    "c9b7a4",
    "d4a78e",
]

SWATCHES = {color: (i % 8, i // 8) for i, color in enumerate(PALETTE)}


def add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def mul(a, t):
    return tuple(x * t for x in a)


def length(v):
    return sqrt(sum(t * t for t in v))


def unit(v):
    return mul(v, 1 / max(length(v), 1e-9))


def cross(a, b):
    return (
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    )


def sgnpow(x, p):
    return math.copysign(abs(x) ** p, x)


class Mesh:
    def __init__(self):
        self.positions = []
        self.normals = []
        self.colors = []
        self.indices = []

    def piece(self, vertices, polygons, paint, smooth=0.82):
        # Blend surface-area normals with face normals to retain large garment planes.
        acc = [(0, 0, 0)] * len(vertices)
        normals = []
        for poly in polygons:
            a, b, c = [vertices[i] for i in poly[:3]]
            n = cross(sub(b, a), sub(c, a))
            normals.append(unit(n))
            for i in poly:
                acc[i] = add(acc[i], n)
        for p, n in zip(polygons, normals):
            offset = len(self.positions)
            for i in p:
                self.positions.append(vertices[i])
                self.normals.append(
                    unit(add(mul(n, 1 - smooth), mul(unit(acc[i]), smooth)))
                )
                self.colors.append(paint)
            for j in range(1, len(p) - 1):
                self.indices.extend((offset, offset + j, offset + j + 1))

    def rings(self, rows, paint, smooth=0.82):
        count = len(rows[0])
        vertices = functools.reduce(operator.iadd, rows, [])
        faces = []
        for j in range(len(rows) - 1):
            for i in range(count):
                a = j * count + i
                b = j * count + (i + 1) % count
                faces.append((a, a + count, b + count, b))
        self.piece(vertices, faces, paint, smooth)
        self.piece(rows[0], [list(range(count))], paint, 0)
        self.piece(rows[-1], [list(range(count))[::-1]], paint, 0)

    def loft(self, params, paint, sides=12, square=0.89, smooth=0.82):
        self.rings(
            [
                [
                    (
                        x + rx * sgnpow(sin(i * 2 * pi / sides), square),
                        y,
                        z - rz * sgnpow(cos(i * 2 * pi / sides), square),
                    )
                    for i in range(sides)
                ]
                for y, x, z, rx, rz in params
            ],
            paint,
            smooth,
        )

    def path(self, sections, paint, sides=9, smooth=0.78):
        # Ring axes follow the sleeve from shoulder through elbow to wrist.
        centers = [row[0] for row in sections]
        rings = []
        for i, (p, w, h) in enumerate(sections):
            tangent = unit(
                sub(centers[min(i + 1, len(centers) - 1)], centers[max(i - 1, 0)])
            )
            # Local X across a sleeve. Other direction follows the turn at the elbow.
            depth = unit(cross((1, 0, 0), tangent))
            if length(depth) < 0.5:
                depth = (0, 0, 1)
            breadth = unit(cross(tangent, depth))
            rings.append(
                [
                    add(
                        p,
                        add(
                            mul(breadth, w * sin(2 * pi * k / sides)),
                            mul(depth, -h * cos(2 * pi * k / sides)),
                        ),
                    )
                    for k in range(sides)
                ]
            )
        self.rings(rings, paint, smooth)

    def line(self, a, b, w, paint, h=None):
        self.path([(a, w, h or w), (b, w, h or w)], paint, 6)

    def patch(self, vs, paint):
        # Direct faces toward the front of the wearer for reliable local lighting.
        n = cross(sub(vs[1], vs[0]), sub(vs[2], vs[0]))
        if n[2] > 0:
            vs = list(reversed(vs))
        self.piece(vs, [list(range(len(vs)))], paint, 0)


def quat(rx=0, ry=0, rz=0):
    x, y, z = [v / 2 for v in (rx, ry, rz)]
    return (
        sin(x) * cos(y) * cos(z) - cos(x) * sin(y) * sin(z),
        cos(x) * sin(y) * cos(z) + sin(x) * cos(y) * sin(z),
        cos(x) * cos(y) * sin(z) - sin(x) * sin(y) * cos(z),
        cos(x) * cos(y) * cos(z) + sin(x) * sin(y) * sin(z),
    )


class Model:
    def __init__(self):
        self.blob = bytearray()
        self.views = []
        self.access = []
        self.meshes = []
        self.nodes = []
        self.anim = []

    def accessor(self, values, kind, letter="f", target=None, bounds=False):
        size = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[kind]
        v = list(values)
        fmt = "<" + letter * size
        data = b"".join(struct.pack(fmt, *row) for row in v)
        self.blob.extend(b"\0" * (-len(self.blob) % 4))
        start = len(self.blob)
        self.blob.extend(data)
        view = {"buffer": 0, "byteOffset": start, "byteLength": len(data)}
        if target:
            view["target"] = target
        self.views.append(view)
        result = {
            "bufferView": len(self.views) - 1,
            "componentType": {"f": 5126, "H": 5123}[letter],
            "count": len(v),
            "type": kind,
        }
        if bounds:
            result["min"] = list(map(min, zip(*v)))
            result["max"] = list(map(max, zip(*v)))
        self.access.append(result)
        return len(self.access) - 1

    def node(self, name, pivot=(0, 0, 0), parent=None, mesh=None):
        n = {"name": name}
        i = len(self.nodes)
        n["translation"] = sub(
            pivot, self.nodes[parent]["_pivot"] if parent is not None else (0, 0, 0)
        )
        n["_pivot"] = pivot
        if parent is not None:
            self.nodes[parent].setdefault("children", []).append(i)
        if mesh:
            pos = self.accessor(
                [sub(p, pivot) for p in mesh.positions],
                "VEC3",
                target=34962,
                bounds=True,
            )
            norm = self.accessor(mesh.normals, "VEC3", target=34962)
            uv = []
            for (x, y, z), col in zip(mesh.positions, mesh.colors):
                if col.startswith("face_"):
                    skin = col.removeprefix("face_")
                    origin = 256 if skin == "ba927f" else 384
                    u = max(0, min(1, (x + 0.105) / 0.210))
                    v = max(0, min(1, 1 - (y - 1.449) / 0.21))
                    uv.append(((origin + 4 + 120 * u) / 512, (4 + 120 * v) / 256))
                    continue
                tx, ty = SWATCHES[col]
                # Project local cloth and skin detail inside the painted swatch with a two-pixel gutter.
                u = 0.5 + (x * 0.77 + z * 0.37) * 1.35
                v = (0.97 - y * 0.53) if y < 1.43 else (0.96 - (y - 1.43) * 2.45)
                uv.append(
                    (
                        (tx * 32 + 2 + 28 * max(0, min(1, u))) / 512,
                        (ty * 32 + 2 + 28 * max(0, min(1, v))) / 256,
                    )
                )
            texcoords = self.accessor(uv, "VEC2", target=34962)
            ids = self.accessor([(j,) for j in mesh.indices], "SCALAR", "H", 34963)
            n["mesh"] = len(self.meshes)
            self.meshes.append(
                {
                    "name": name,
                    "primitives": [
                        {
                            "attributes": {
                                "POSITION": pos,
                                "NORMAL": norm,
                                "TEXCOORD_0": texcoords,
                            },
                            "indices": ids,
                            "material": 0,
                        }
                    ],
                }
            )
        self.nodes.append(n)
        return i

    def clip(self, name, times, channels):
        ts = self.accessor([(t,) for t in times], "SCALAR", bounds=True)
        anim = {"name": name, "channels": [], "samplers": []}
        for node, path, values in channels:
            ac = self.accessor(values, "VEC4" if path == "rotation" else "VEC3")
            s = len(anim["samplers"])
            anim["samplers"].append({"input": ts, "output": ac})
            anim["channels"].append(
                {"sampler": s, "target": {"node": node, "path": path}}
            )
        self.anim.append(anim)

    def write(self, path):
        for n in self.nodes:
            del n["_pivot"]
        data = {
            "asset": {"version": "2.0", "generator": "24 HR Towing character models"},
            "scene": 0,
            "scenes": [{"nodes": [0]}],
            "nodes": self.nodes,
            "meshes": self.meshes,
            "images": [{"uri": "winter_palette.png"}],
            "textures": [{"source": 0}],
            "materials": [
                {
                    "name": "Winter wear",
                    "pbrMetallicRoughness": {
                        "baseColorTexture": {"index": 0},
                        "metallicFactor": 0,
                        "roughnessFactor": 0.94,
                    },
                }
            ],
            "buffers": [{"byteLength": len(self.blob)}],
            "bufferViews": self.views,
            "accessors": self.access,
            "animations": self.anim,
        }
        js = json.dumps(data, separators=(",", ":")).encode()
        js += b" " * (-len(js) % 4)
        self.blob += b"\0" * (-len(self.blob) % 4)
        path.write_bytes(
            struct.pack("<4sII", b"glTF", 2, 28 + len(js) + len(self.blob))
            + struct.pack("<I4s", len(js), b"JSON")
            + js
            + struct.pack("<I4s", len(self.blob), b"BIN\0")
            + self.blob
        )


def leg(m, s, deputy):
    # One heel is planted a half shoe-length behind the other.
    pants = "39464d" if deputy else "46566a"
    x = 0.141 if s == 1 else -0.086
    dz = 0.081 if s == 1 else -0.057
    h = (s * 0.112, 0.852, dz * 0.22)
    k = (x + s * 0.012, 0.487, dz - (0.074 if s == 1 else 0.024))
    upper = Mesh()
    lower = Mesh()
    upper.loft(
        [
            (0.43, k[0], k[2], 0.074, 0.079),
            (0.49, k[0], k[2], 0.083, 0.085),
            (0.55, k[0], k[2] + 0.009, 0.077, 0.079),
            (0.69, x, dz, 0.086, 0.08),
            (0.79, h[0] - 0.012 * s, dz * 0.52 + 0.016, 0.090, 0.082),
            (0.85, h[0] - 0.021 * s, 0.021, 0.076, 0.064),
        ],
        pants,
    )
    lower.loft(
        [
            (0.105, x + s * 0.044, dz + 0.027, 0.071, 0.065),
            (0.161, x + s * 0.043, dz + 0.02, 0.088, 0.081),
            (0.194, x + s * 0.038, dz + 0.03, 0.082, 0.069),
            (0.224, x + s * 0.037, dz + 0.018, 0.081, 0.080),
            (0.31, x + s * 0.028, dz + 0.016, 0.070, 0.069),
            (0.396, x + s * 0.02, dz + 0.012, 0.078, 0.084),
            (0.465, k[0], k[2], 0.078, 0.081),
            (0.5, k[0], k[2], 0.079, 0.078),
        ],
        pants,
    )
    # Distinct leather upper, toe box and rubber outsole; boot toe points slightly outward.
    bx = x + s * 0.045
    lower.loft(
        [
            (0.012, bx + s * 0.010, dz - 0.05, 0.084, 0.149),
            (0.026, bx + s * 0.013, dz - 0.052, 0.087, 0.15),
            (0.049, bx + s * 0.012, dz - 0.052, 0.086, 0.15),
        ],
        "262728",
        12,
        0.55,
        0.48,
    )
    lower.loft(
        [
            (0.048, bx + s * 0.012, dz - 0.053, 0.083, 0.148),
            (0.073, bx + s * 0.012, dz - 0.055, 0.084, 0.147),
            (0.091, bx + s * 0.009, dz - 0.052, 0.081, 0.141),
            (0.112, bx, dz - 0.020, 0.078, 0.116),
            (0.155, bx, dz + 0.007, 0.070, 0.085),
            (0.205, bx, dz + 0.021, 0.066, 0.073),
        ],
        "473e38" if not deputy else "363736",
        12,
        0.73,
    )
    for i in range(3):
        za = dz - 0.105 + i * 0.011
        ya = 0.107 + i * 0.012
        lower.line(
            (bx - 0.029, ya, za), (bx + 0.030, ya + 0.003, za + 0.004), 0.003, "776858"
        )
    thigh = m.node("Left_thigh" if s == 1 else "Right_thigh", h, 0, upper)
    shin = m.node("Left_boot" if s == 1 else "Right_boot", k, thigh, lower)
    return thigh, shin


def torso_and_arms(deputy, farm):
    t = Mesh()
    coat = "4b5652" if deputy else ("8b7861" if farm else "a26049")
    dark = "38453f" if deputy else ("705e4b" if farm else "804732")
    seams = "666e64" if deputy else ("a79072" if farm else "bd795a")
    scarf = "6f7673" if deputy else ("58676b" if farm else "b59d7c")
    # Chest flattened across front, broad angled shoulder yoke, shaped waist and hips.
    t.loft(
        [
            (0.794, 0.004, 0.005, 0.210, 0.119),
            (0.819, 0.003, 0.005, 0.222, 0.128),
            (0.908, 0, 0.016, 0.213, 0.125),
            (1.008, -0.006, 0.022, 0.196, 0.123),
            (1.117, -0.009, 0.014, 0.208, 0.137),
            (1.235, -0.012, -0.002, 0.235, 0.150),
            (1.322, -0.013, -0.010, 0.239, 0.143),
            (1.382, -0.010, -0.014, 0.205, 0.125),
            (1.417, -0.005, -0.019, 0.137, 0.104),
            (1.431, -0.003, -0.023, 0.080, 0.083),
        ],
        coat,
        16,
        0.72,
    )
    t.loft(
        [
            (0.789, 0.004, 0.005, 0.211, 0.120),
            (0.802, 0.004, 0.005, 0.215, 0.124),
            (0.821, 0.003, 0.005, 0.221, 0.128),
        ],
        dark,
        16,
        0.72,
    )
    # Center front placket follows the coat where the front bows over the chest.
    front = [
        (0.81, -0.124),
        (0.91, -0.114),
        (1.01, -0.106),
        (1.12, -0.129),
        (1.235, -0.159),
        (1.32, -0.159),
        (1.38, -0.146),
    ]
    for (y, z), (ny, nz) in itertools.pairwise(front):
        t.patch(
            [(-0.019, y, z), (0.008, y, z), (0.008, ny, nz), (-0.019, ny, nz)], dark
        )
        t.line((0.007, y, z - 0.001), (0.007, ny, nz - 0.001), 0.0028, seams)
    for s in (-1, 1):
        t.line((s * 0.094, 0.915, -0.115), (s * 0.171, 1.005, -0.087), 0.009, dark)
        t.line((s * 0.097, 0.919, -0.119), (s * 0.173, 1.009, -0.089), 0.003, seams)
    # A high collar and uneven folds around the neck.
    t.loft(
        [
            (1.365, 0, -0.018, 0.117, 0.107),
            (1.399, -0.002, -0.018, 0.127, 0.112),
            (1.422, -0.004, -0.020, 0.120, 0.112),
            (1.443, -0.003, -0.023, 0.111, 0.104),
            (1.464, -0.003, -0.025, 0.101, 0.097),
        ],
        dark if deputy else scarf,
        14,
        0.88,
        0.61,
    )
    if not deputy:
        t.patch(
            [
                (-0.108, 1.431, -0.086),
                (-0.055, 1.369, -0.144),
                (0.09, 1.415, -0.123),
                (0.10, 1.437, -0.098),
                (-0.01, 1.416, -0.139),
            ],
            "978269" if not farm else "46595b",
        )
        t.patch(
            [
                (-0.065, 1.401, -0.136),
                (-0.026, 1.375, -0.15),
                (-0.049, 1.279, -0.16),
                (-0.103, 1.287, -0.154),
            ],
            scarf,
        )
        for s in (-1, 1):
            t.patch(
                [
                    (s * 0.142, 1.386, -0.113),
                    (s * 0.196, 1.354, -0.108),
                    (s * 0.127, 1.285, -0.155),
                    (s * 0.081, 1.365, -0.147),
                ],
                dark,
            )
    else:
        # Department shoulder patch, flapped breast pockets and shield.
        for s in (-1, 1):
            t.patch(
                [
                    (s * 0.057, 1.23, -0.15),
                    (s * 0.156, 1.23, -0.133),
                    (s * 0.15, 1.15, -0.124),
                    (s * 0.057, 1.145, -0.138),
                ],
                dark,
            )
            t.patch(
                [
                    (s * 0.055, 1.238, -0.152),
                    (s * 0.159, 1.235, -0.137),
                    (s * 0.145, 1.215, -0.14),
                    (s * 0.098, 1.202, -0.149),
                    (s * 0.055, 1.212, -0.152),
                ],
                seams,
            )
        t.patch(
            [
                (-0.115, 1.317, -0.152),
                (-0.08, 1.318, -0.156),
                (-0.081, 1.292, -0.157),
                (-0.099, 1.275, -0.157),
                (-0.115, 1.287, -0.153),
            ],
            "ae9e72",
        )
        t.patch(
            [
                (0.070, 1.283, -0.157),
                (0.139, 1.278, -0.148),
                (0.139, 1.264, -0.149),
                (0.07, 1.269, -0.158),
            ],
            "b9ac91",
        )
    # Continuous sleeves with a relaxed elbow; one glove is at the scarf or radio,
    # the other presses into a hand-warmer pocket. No T-pose or round-ball joints.
    t.path(
        [
            ((-0.180, 1.339, -0.004), 0.059, 0.085),
            ((-0.225, 1.308, -0.009), 0.086, 0.089),
            ((-0.253, 1.239, -0.008), 0.083, 0.082),
            ((-0.285, 1.127, -0.011), 0.076, 0.079),
            ((-0.294, 1.08, -0.041), 0.079, 0.073),
            ((-0.293, 1.055, -0.072), 0.069, 0.066),
            ((-0.269, 1.038, -0.103), 0.073, 0.070),
            ((-0.222, 1.018, -0.139), 0.064, 0.066),
            ((-0.176, 0.992, -0.144), 0.059, 0.056),
        ],
        coat,
    )
    t.path(
        [
            ((-0.206, 1.012, -0.146), 0.062, 0.060),
            ((-0.178, 0.993, -0.148), 0.060, 0.057),
            ((-0.167, 0.988, -0.146), 0.055, 0.054),
        ],
        dark,
    )
    t.path(
        [
            ((-0.176, 0.991, -0.147), 0.044, 0.048),
            ((-0.153, 0.984, -0.144), 0.051, 0.042),
            ((-0.127, 0.969, -0.131), 0.038, 0.032),
            ((-0.116, 0.96, -0.113), 0.020, 0.025),
        ],
        "453d38",
    )
    t.path(
        [
            ((0.164, 1.353, -0.016), 0.060, 0.072),
            ((0.216, 1.326, -0.015), 0.087, 0.088),
            ((0.244, 1.258, -0.009), 0.082, 0.084),
            ((0.271, 1.175, -0.025), 0.076, 0.08),
            ((0.283, 1.115, -0.064), 0.076, 0.075),
            ((0.274, 1.097, -0.094), 0.070, 0.073),
            ((0.247, 1.112, -0.129), 0.072, 0.074),
            ((0.211, 1.157, -0.161), 0.069, 0.069),
            ((0.157, 1.227, -0.184), 0.061, 0.065),
            ((0.121, 1.272, -0.184), 0.055, 0.058),
        ],
        coat,
    )
    t.path(
        [
            ((0.143, 1.245, -0.185), 0.061, 0.063),
            ((0.118, 1.272, -0.185), 0.056, 0.059),
            ((0.114, 1.281, -0.182), 0.051, 0.055),
        ],
        dark,
    )
    t.path(
        [
            ((0.118, 1.275, -0.185), 0.042, 0.044),
            ((0.097, 1.3, -0.185), 0.045, 0.043),
            ((0.074, 1.32, -0.176), 0.045, 0.037),
            ((0.056, 1.343, -0.154), 0.033, 0.032),
            ((0.054, 1.351, -0.137), 0.023, 0.022),
        ],
        "514740",
    )
    t.path(
        [
            ((0.097, 1.317, -0.166), 0.025, 0.021),
            ((0.105, 1.347, -0.153), 0.02, 0.018),
            ((0.100, 1.366, -0.144), 0.013, 0.014),
        ],
        "514740",
        7,
    )
    return t


def face(deputy, farm):
    t = Mesh()
    skin = "ad8570" if (deputy or farm) else "ba927f"
    cheek = "bd8875" if (deputy or farm) else "c48d77"
    lips = "8a5e51" if (deputy or farm) else "996c63"
    hair = "514440" if not farm else "5c5549"
    knit = "515c69" if not deputy else "414b46"
    if farm:
        knit = "7b6650"
    base = 1.449
    shift = -0.035
    # A shaped jaw, full cheek plane and slim temple rather than an oval sphere.
    widths = [
        (0, -0.99),
        (0.45, -0.97),
        (0.78, -0.86),
        (0.94, -0.52),
        (1, -0.05),
        (0.96, 0.46),
        (0.76, 0.84),
        (0.4, 0.97),
        (0, 1),
        (-0.4, 0.97),
        (-0.76, 0.84),
        (-0.96, 0.46),
        (-1, -0.05),
        (-0.94, -0.52),
        (-0.78, -0.86),
        (-0.45, -0.97),
    ]
    head = [
        (0.000, 0.041, 0.052, -0.018),
        (0.015, 0.057, 0.069, -0.013),
        (0.035, 0.076, 0.08, -0.008),
        (0.057, 0.085, 0.088, -0.002),
        (0.077, 0.091, 0.086, 0.001),
        (0.104, 0.095, 0.090, 0.001),
        (0.125, 0.094, 0.084, 0.003),
        (0.145, 0.093, 0.092, 0.001),
        (0.172, 0.093, 0.093, 0.004),
        (0.198, 0.087, 0.092, 0.005),
        (0.232, 0.063, 0.071, 0.004),
        (0.244, 0.03, 0.038, 0.003),
    ]
    wide = 1.06 if (deputy or farm) else 0.98

    def pt(x, y, z):
        return (x * wide, base + y, shift + z)

    t.rings(
        [[pt(x * w, y, zc + z * d) for x, z in widths] for y, w, d, zc in head],
        "face_" + skin,
        0.95,
    )
    # Profiles of the cheekbones, ear rim and inner cartilage.
    for s in (-1, 1):
        t.loft(
            [
                (base + 0.074, s * wide * 0.091, shift + 0.001, 0.006, 0.012),
                (base + 0.084, s * wide * 0.094, shift + 0.001, 0.011, 0.017),
                (base + 0.112, s * wide * 0.097, shift + 0.003, 0.015, 0.021),
                (base + 0.135, s * wide * 0.095, shift + 0.005, 0.012, 0.019),
                (base + 0.146, s * wide * 0.092, shift + 0.006, 0.006, 0.01),
            ],
            skin,
            9,
            0.88,
        )
        t.loft(
            [
                (base + 0.088, s * wide * 0.101, shift + 0.002, 0.007, 0.006),
                (base + 0.107, s * wide * 0.106, shift + 0.002, 0.008, 0.012),
                (base + 0.128, s * wide * 0.102, shift + 0.005, 0.005, 0.008),
            ],
            cheek,
            8,
        )

    def patch(points, col):
        offset = -0.004 if col in (lips, cheek) else 0
        t.patch([pt(x, y, z + offset) for x, y, z in points], col)

    # Four planes carry the bridge into the nose tip and nostril wings.
    nose = [
        (0, 0.148, -0.092),
        (-0.011, 0.132, -0.087),
        (-0.015, 0.093, -0.094),
        (-0.021, 0.080, -0.10),
        (-0.013, 0.075, -0.108),
        (0, 0.071, -0.113),
        (0.013, 0.075, -0.108),
        (0.021, 0.080, -0.10),
        (0.015, 0.093, -0.094),
        (0.011, 0.132, -0.087),
        (0, 0.088, -0.124),
        (0, 0.082, -0.124),
    ]
    for indices, col in [
        ([0, 1, 2, 10], skin),
        ([0, 10, 8, 9], skin),
        ([2, 3, 4, 11, 10], cheek),
        ([8, 10, 11, 6, 7], skin),
        ([4, 5, 6, 11], cheek),
    ]:
        patch([nose[i] for i in indices], col)
    for s in (-1, 1):
        # Socket, upper eyelid, iris and eyebrow all share the slope around the temple.
        def eye_patch(arr, col, side=s):
            patch([(side * x, y, z - 0.004) for x, y, z in arr], col)

        eye_patch(
            [
                (0.020, 0.126, -0.084),
                (0.034, 0.134, -0.086),
                (0.056, 0.133, -0.081),
                (0.069, 0.126, -0.074),
                (0.060, 0.120, -0.078),
                (0.032, 0.117, -0.086),
            ],
            cheek,
        )
        eye_patch(
            [
                (0.021, 0.1225, -0.087),
                (0.034, 0.1275, -0.090),
                (0.050, 0.128, -0.0875),
                (0.062, 0.124, -0.082),
                (0.052, 0.119, -0.086),
                (0.034, 0.1185, -0.089),
            ],
            "c9b7a4",
        )
        eye_patch(
            [
                (0.037, 0.126, -0.091),
                (0.047, 0.1265, -0.0905),
                (0.048, 0.119, -0.0898),
                (0.038, 0.1189, -0.091),
            ],
            "483f38",
        )
        eye_patch(
            [
                (0.019, 0.122, -0.088),
                (0.033, 0.129, -0.091),
                (0.049, 0.130, -0.089),
                (0.064, 0.125, -0.082),
                (0.050, 0.127, -0.089),
                (0.033, 0.1265, -0.091),
            ],
            "665048",
        )
        eye_patch(
            [
                (0.016, 0.142, -0.095),
                (0.037, 0.149, -0.094),
                (0.055, 0.148, -0.090),
                (0.072, 0.142, -0.080),
                (0.050, 0.143, -0.091),
                (0.029, 0.141, -0.095),
                (0.019, 0.138, -0.095),
            ],
            hair,
        )
    patch(
        [
            (-0.030, 0.049, -0.086),
            (-0.012, 0.055, -0.088),
            (0, 0.053, -0.089),
            (0.010, 0.055, -0.088),
            (0.029, 0.049, -0.086),
            (0.010, 0.048, -0.091),
            (-0.009, 0.047, -0.091),
        ],
        lips,
    )
    patch(
        [
            (-0.027, 0.048, -0.086),
            (-0.008, 0.048, -0.092),
            (0.008, 0.049, -0.092),
            (0.029, 0.049, -0.086),
            (0.012, 0.044, -0.09),
            (-0.010, 0.043, -0.09),
        ],
        cheek,
    )
    if farm:
        patch(
            [
                (-0.034, 0.052, -0.084),
                (-0.014, 0.065, -0.088),
                (0, 0.060, -0.092),
                (0.013, 0.064, -0.088),
                (0.032, 0.053, -0.085),
                (0.031, 0.046, -0.086),
                (0.012, 0.052, -0.091),
                (-0.014, 0.050, -0.091),
                (-0.03, 0.045, -0.086),
            ],
            hair,
        )
    # Hair nape drops into the collar. A few wider tapered locks frame the temples.
    t.loft(
        [
            (base + 0.060, 0, shift + 0.066, 0.056, 0.037),
            (base + 0.087, 0, shift + 0.057, 0.084, 0.050),
            (base + 0.139, 0, shift + 0.048, 0.093, 0.065),
            (base + 0.17, 0, shift + 0.028, 0.094, 0.077),
        ],
        hair,
        12,
    )
    for s in (-1, 1):
        zpin = shift - 0.016
        t.loft(
            [
                (base + (0.083 if deputy else 0.05), s * 0.092, zpin, 0.008, 0.013),
                (base + 0.104, s * 0.092, zpin, 0.014, 0.020),
                (base + 0.145, s * 0.09, zpin + 0.001, 0.017, 0.03),
                (base + 0.175, s * 0.084, zpin, 0.02, 0.038),
            ],
            hair,
            8,
        )
    if deputy:
        t.loft(
            [
                (base + 0.149, 0, shift + 0.004, 0.097, 0.101),
                (base + 0.159, 0, shift + 0.005, 0.104, 0.103),
                (base + 0.191, 0, shift + 0.006, 0.102, 0.105),
                (base + 0.221, 0, shift + 0.012, 0.093, 0.097),
                (base + 0.246, 0, shift + 0.018, 0.060, 0.076),
                (base + 0.250, 0, shift + 0.024, 0.02, 0.035),
            ],
            knit,
            14,
        )
        # Billed patrol cap, underside and front edge follow the curve over the brow.
        t.loft(
            [
                (base + 0.148, 0, shift - 0.080, 0.087, 0.065),
                (base + 0.152, 0, shift - 0.080, 0.087, 0.067),
                (base + 0.157, 0, shift - 0.077, 0.085, 0.064),
            ],
            "3c4541",
            12,
            0.69,
        )
        patch(
            [
                (-0.012, 0.187, -0.10),
                (0.012, 0.187, -0.10),
                (0.011, 0.165, -0.101),
                (0, 0.159, -0.101),
                (-0.012, 0.166, -0.101),
            ],
            "b0a47d",
        )
    else:
        t.loft(
            [
                (base + 0.145, 0, shift + 0.004, 0.100, 0.103),
                (base + 0.166, 0, shift + 0.007, 0.106, 0.111),
                (base + 0.196, 0, shift + 0.007, 0.107, 0.111),
                (base + 0.222, -0.004, shift + 0.016, 0.10, 0.101),
                (base + 0.247, -0.013, shift + 0.024, 0.079, 0.084),
                (base + 0.263, -0.022, shift + 0.029, 0.04, 0.043),
                (base + 0.266, -0.027, shift + 0.031, 0.015, 0.015),
            ],
            knit,
            16,
            0.94,
        )
        band = "616e79" if not farm else "8d765a"
        t.loft(
            [
                (base + 0.147, 0, shift + 0.004, 0.102, 0.106),
                (base + 0.15, 0, shift + 0.004, 0.105, 0.109),
                (base + 0.177, 0, shift + 0.007, 0.110, 0.114),
                (base + 0.182, 0, shift + 0.007, 0.109, 0.113),
            ],
            band,
            16,
        )
        for i in range(24):
            a = 2 * pi * i / 24
            t.line(
                (sin(a) * 0.105, base + 0.151, shift + 0.004 - cos(a) * 0.109),
                (sin(a) * 0.11, base + 0.178, shift + 0.007 - cos(a) * 0.114),
                0.0017,
                knit,
            )
    return t


def model(deputy=False, farm=False):
    m = Model()
    m.node("Deputy" if deputy else "Motorist")
    legs = [leg(m, s, deputy) for s in (-1, 1)]
    spine = m.node("Jacket", (0.00, 0.865, 0.012), 0, torso_and_arms(deputy, farm))
    head = m.node("Head", (0, 1.443, -0.023), spine, face(deputy, farm))
    # Small asymmetric posture replaces the rigid, square standing pose.
    head_pose = (-0.07, 0.13, -0.047) if not deputy else (-0.028, -0.13, 0.024)

    def headrot(pitch=0, yaw=0, roll=0):
        return quat(head_pose[0] + pitch, head_pose[1] + yaw, head_pose[2] + roll)

    m.clip(
        "idle",
        [0.0, 1.45, 2.9, 4.35, 5.8],
        [
            (
                spine,
                "rotation",
                [
                    quat(-0.04, 0, 0.023),
                    quat(-0.049, 0.008, 0.027),
                    quat(-0.04, 0, 0.023),
                    quat(-0.047, -0.007, 0.019),
                    quat(-0.04, 0, 0.023),
                ],
            ),
            (
                head,
                "rotation",
                [
                    headrot(),
                    headrot(-0.009, 0.025),
                    headrot(0.004, 0.07),
                    headrot(0.014, 0.035),
                    headrot(),
                ],
            ),
        ],
    )
    phases = [0, 0.25, 0.5, 0.75, 1]
    ch = [
        (head, "rotation", [headrot(-0.028)] * 5),
        (
            spine,
            "rotation",
            [
                quat(-0.08, 0.035 * cos(2 * pi * p), 0.014 * sin(2 * pi * p))
                for p in phases
            ],
        ),
    ]
    for i, (thigh, shin) in enumerate(legs):
        offset = i * pi
        ch.append(
            (
                thigh,
                "rotation",
                [quat(0.52 * cos(2 * pi * p + offset) - 0.10, 0, 0) for p in phases],
            )
        )
        ch.append(
            (
                shin,
                "rotation",
                [
                    quat(-0.08 - 0.70 * max(0, -sin(2 * pi * p + offset)), 0, 0)
                    for p in phases
                ],
            )
        )
    m.clip("walk", [0, 0.19, 0.38, 0.57, 0.76], ch)
    m.write(
        DEST
        / (
            "deputy.glb"
            if deputy
            else "farm_driver.glb"
            if farm
            else "stranded_driver.glb"
        )
    )


def make_palette():
    assert len(PALETTE) <= 64
    pixels = bytearray(512 * 256 * 3)
    rng = random.Random(61)
    for c, (tx, ty) in SWATCHES.items():
        tint = [int(c[i : i + 2], 16) for i in (0, 2, 4)]
        skin = c in ["ad8570", "ba927f", "bd8875", "c48d77"]
        for y in range(32):
            for x in range(32):
                # Dull woven fabric; smoother skin and burnished leather.
                n = (
                    0.9 * sin(y * 1.94 + x * 0.8)
                    + 1.9 * sin(y * 0.39 + x * 0.48)
                    + 1.2 * cos(y * 0.61 - x * 0.53)
                    + rng.uniform(-3.0, 3.0)
                )
                if skin:
                    n *= 0.45
                i = 3 * ((ty * 32 + y) * 512 + tx * 32 + x)
                pixels[i : i + 3] = bytes(max(0, min(255, round(v + n))) for v in tint)
    # Paint orbital, cheek and chin tones directly onto a face projection.
    # Coordinates below are in metres relative to the chin and jaw centreline.
    for origin, base in [(256, (186, 146, 127)), (384, (173, 133, 112))]:
        for py in range(128):
            for px in range(128):
                x = (px - 4) / 120 * 0.21 - 0.105
                y = (1 - (py - 4) / 120) * 0.21

                def spot(cx, cy, rx, ry, horizontal=x, vertical=y):
                    return math.exp(
                        -(((abs(horizontal) - cx) / rx) ** 2)
                        - ((vertical - cy) / ry) ** 2
                    )

                orbital = spot(0.042, 0.120, 0.035, 0.016)
                cheek = spot(0.061, 0.085, 0.027, 0.024)
                temple = spot(0.089, 0.159, 0.027, 0.039)
                jaw = spot(0.079, 0.044, 0.025, 0.038)
                philtrum = spot(0.005, 0.062, 0.005, 0.009)
                brow = spot(0.039, 0.140, 0.025, 0.008)
                chin = spot(0.016, 0.025, 0.029, 0.015)
                shadow = (
                    12 * orbital
                    + 11 * temple
                    + 14 * jaw
                    + 7 * philtrum
                    + 7 * brow
                    - 4 * chin
                )
                n = rng.uniform(-2.2, 2.2)
                pigment = (
                    base[0] + 3 * cheek,
                    base[1] - 13 * cheek,
                    base[2] - 7 * cheek,
                )
                i = 3 * (py * 512 + origin + px)
                pixels[i : i + 3] = bytes(round(v - shadow + n) for v in pigment)

    def chunk(tag, data):
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data))
        )

    scan = b"".join(bytes(1) + pixels[y * 1536 : y * 1536 + 1536] for y in range(256))
    (DEST / "winter_palette.png").write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", 512, 256, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(scan, 9))
        + chunk(b"IEND", b"")
    )


if __name__ == "__main__":
    DEST.mkdir(parents=True, exist_ok=True)
    make_palette()
    model()
    model(deputy=True)
    model(farm=True)
