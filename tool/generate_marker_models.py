"""Generates the 3D map pins in assets/markers/*.glb (one colour per marker kind).
Run:  python3 tool/generate_marker_models.py      (only needed if you change the colours)
Each pin is a cone with a sphere on top; its tip is the model's origin, so the
tip sits exactly on the spot a teacher tapped. Height is 0.12 units."""
import json, math, struct, os

COLORS = {
    'exit': (0.10, 0.70, 0.30), 'assembly': (0.10, 0.40, 0.90),
    'extinguisher': (0.85, 0.10, 0.10), 'firstaid': (0.95, 0.45, 0.55),
    'stairs': (0.55, 0.25, 0.80), 'hazard': (1.00, 0.70, 0.00),
    'other': (0.45, 0.50, 0.55),
}

def pin():
    pos, nor, idx = [], [], []
    seg = 24
    h, r_cone = 0.08, 0.03
    # cone: tip at origin, opening upward
    tip = len(pos); pos.append((0, 0, 0)); nor.append((0, -1, 0))
    base = len(pos)
    for i in range(seg):
        a = 2 * math.pi * i / seg
        x, z = r_cone * math.cos(a), r_cone * math.sin(a)
        pos.append((x, h, z)); 
        n = (math.cos(a) * h, r_cone, math.sin(a) * h)
        l = math.sqrt(sum(c * c for c in n)); nor.append(tuple(c / l for c in n))
    for i in range(seg):
        idx += [tip, base + (i + 1) % seg, base + i]
    # sphere on top
    R, cy = 0.04, h + 0.02
    rings, sl = 12, 24
    s0 = len(pos)
    for i in range(rings + 1):
        t = math.pi * i / rings
        for j in range(sl + 1):
            a = 2 * math.pi * j / sl
            nx, ny, nz = math.sin(t) * math.cos(a), math.cos(t), math.sin(t) * math.sin(a)
            pos.append((R * nx, cy + R * ny, R * nz)); nor.append((nx, ny, nz))
    for i in range(rings):
        for j in range(sl):
            a = s0 + i * (sl + 1) + j; b = a + sl + 1
            idx += [a, a + 1, b, b, a + 1, b + 1]
    return pos, nor, idx

def glb(color):
    pos, nor, idx = pin()
    pb = b''.join(struct.pack('<3f', *p) for p in pos)
    nb = b''.join(struct.pack('<3f', *n) for n in nor)
    ib = b''.join(struct.pack('<H', i) for i in idx)
    ib += b'\0' * (-len(ib) % 4)
    blob = pb + nb + ib
    mn = [min(p[k] for p in pos) for k in range(3)]; mx = [max(p[k] for p in pos) for k in range(3)]
    g = {
        'asset': {'version': '2.0', 'generator': 'arise marker tool'},
        'scene': 0, 'scenes': [{'nodes': [0]}], 'nodes': [{'mesh': 0}],
        'meshes': [{'primitives': [{'attributes': {'POSITION': 0, 'NORMAL': 1}, 'indices': 2, 'material': 0}]}],
        'materials': [{'pbrMetallicRoughness': {'baseColorFactor': [*color, 1], 'metallicFactor': 0.0, 'roughnessFactor': 0.6},
                       'emissiveFactor': [c * 0.35 for c in color]}],
        'buffers': [{'byteLength': len(blob)}],
        'bufferViews': [
            {'buffer': 0, 'byteOffset': 0, 'byteLength': len(pb), 'target': 34962},
            {'buffer': 0, 'byteOffset': len(pb), 'byteLength': len(nb), 'target': 34962},
            {'buffer': 0, 'byteOffset': len(pb) + len(nb), 'byteLength': len(idx) * 2, 'target': 34963}],
        'accessors': [
            {'bufferView': 0, 'componentType': 5126, 'count': len(pos), 'type': 'VEC3', 'min': mn, 'max': mx},
            {'bufferView': 1, 'componentType': 5126, 'count': len(nor), 'type': 'VEC3'},
            {'bufferView': 2, 'componentType': 5123, 'count': len(idx), 'type': 'SCALAR'}],
    }
    js = json.dumps(g, separators=(',', ':')).encode()
    js += b' ' * (-len(js) % 4)
    total = 12 + 8 + len(js) + 8 + len(blob)
    return (struct.pack('<4sII', b'glTF', 2, total) + struct.pack('<I4s', len(js), b'JSON') + js +
            struct.pack('<I4s', len(blob), b'BIN\0') + blob)

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'markers')
os.makedirs(out, exist_ok=True)
for kind, col in COLORS.items():
    open(os.path.join(out, kind + '.glb'), 'wb').write(glb(col))
    print('wrote', kind + '.glb')
