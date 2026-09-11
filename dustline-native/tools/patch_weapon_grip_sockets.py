#!/usr/bin/env python3
"""Inject reviewed first-person grip sockets into supplemental Steel Tide GLBs.

The upstream P226/AWM supplemental mechanism exports deliberately contain the
real Magazine / ChargingHandle mechanisms and their moving-hand sockets, but do
not export the static first-person PrimaryGripSocket / SupportGripSocket nodes
used by Dustline's DJMaesen arm adapter. Re-importing cannot create nodes that
are absent from the source GLB, so bootstrap patches those two marker nodes into
the reviewed GLB before Godot imports it.

No visible mesh, material, animation or mechanism data is changed. The patch is
idempotent and discovers the Blender/glTF axis conversion from the known
Magazine and ChargingHandle authored rest positions before writing root-local
marker translations.
"""
from __future__ import annotations

import argparse
import itertools
import json
from pathlib import Path
import struct
import sys

JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942
MAGIC = b"glTF"

# Authored root-local Godot metres. P226 follows the reviewed Steel Tide
# service-pistol two-hand geometry used by the GSh-18 arm family. AWM uses an
# independent precision-rifle calibration: firing hand immediately behind the
# magazine/action group and support hand on the forward stock/fore-end.
GRIP_SPECS = {
    "p226": {
        "primary": (0.0, -0.04006, 0.22579),
        "support": (-0.09510, -0.04929, 0.22227),
        "provenance": "Steel Tide service-pistol reviewed grip calibration",
    },
    "awm": {
        "primary": (0.0, -0.10200, -0.07500),
        "support": (-0.04300, 0.01000, -0.52000),
        "provenance": "Dustline AWM precision-rifle grip calibration on 2.00 m canonical body",
    },
}

# These authored mechanism rest positions are shared by the supplemental
# builder and let us infer Blender/glTF -> Godot signed-axis permutation without
# making assumptions about exporter coordinate conversion.
REFERENCE_GODOT = {
    "Magazine": (0.0, -0.20, -0.31),
    "ChargingHandle": (0.075, 0.085, -0.05),
}


def read_glb(path: Path) -> tuple[dict, list[tuple[int, bytes]]]:
    raw = path.read_bytes()
    if len(raw) < 20 or raw[:4] != MAGIC:
        raise RuntimeError(f"not a GLB 2.0 file: {path}")
    version, total = struct.unpack_from("<II", raw, 4)
    if version != 2 or total != len(raw):
        raise RuntimeError(f"invalid GLB header: {path}")
    offset = 12
    chunks: list[tuple[int, bytes]] = []
    doc = None
    while offset < len(raw):
        length, kind = struct.unpack_from("<II", raw, offset)
        offset += 8
        payload = raw[offset : offset + length]
        offset += length
        chunks.append((kind, payload))
        if kind == JSON_CHUNK:
            doc = json.loads(payload.rstrip(b" \t\r\n\x00").decode("utf-8"))
    if doc is None:
        raise RuntimeError(f"GLB has no JSON chunk: {path}")
    return doc, chunks


def write_glb(path: Path, doc: dict, chunks: list[tuple[int, bytes]]) -> None:
    compact = json.dumps(doc, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    compact += b" " * ((4 - len(compact) % 4) % 4)
    rebuilt: list[tuple[int, bytes]] = []
    replaced = False
    for kind, payload in chunks:
        if kind == JSON_CHUNK and not replaced:
            rebuilt.append((kind, compact))
            replaced = True
        else:
            rebuilt.append((kind, payload))
    if not replaced:
        rebuilt.insert(0, (JSON_CHUNK, compact))
    total = 12 + sum(8 + len(payload) for _, payload in rebuilt)
    out = bytearray(MAGIC + struct.pack("<II", 2, total))
    for kind, payload in rebuilt:
        out += struct.pack("<II", len(payload), kind)
        out += payload
    path.write_bytes(out)


def node_translation(node: dict) -> tuple[float, float, float]:
    if "translation" in node:
        value = node["translation"]
        return float(value[0]), float(value[1]), float(value[2])
    if "matrix" in node:
        matrix = node["matrix"]
        return float(matrix[12]), float(matrix[13]), float(matrix[14])
    return 0.0, 0.0, 0.0


def find_node(doc: dict, name: str) -> int:
    for index, node in enumerate(doc.get("nodes", [])):
        if node.get("name") == name:
            return index
    raise RuntimeError(f"required GLB node not found: {name}")


def parent_map(doc: dict) -> dict[int, int]:
    result: dict[int, int] = {}
    for parent, node in enumerate(doc.get("nodes", [])):
        for child in node.get("children", []):
            result[int(child)] = parent
    return result


def apply_mapping(v: tuple[float, float, float], perm, signs) -> tuple[float, float, float]:
    return tuple(float(signs[i]) * float(v[perm[i]]) for i in range(3))


def discover_axis_mapping(doc: dict):
    observed = {
        name: node_translation(doc["nodes"][find_node(doc, name)])
        for name in REFERENCE_GODOT
    }
    best = None
    for perm in itertools.permutations(range(3)):
        for signs in itertools.product((-1.0, 1.0), repeat=3):
            error = 0.0
            for name, godot_pos in REFERENCE_GODOT.items():
                mapped = apply_mapping(godot_pos, perm, signs)
                target = observed[name]
                error += sum((mapped[i] - target[i]) ** 2 for i in range(3))
            if best is None or error < best[0]:
                best = (error, perm, signs)
    assert best is not None
    error, perm, signs = best
    # The reference positions are exact authored pivots, so a large residual
    # means the hierarchy/export contract changed and blindly patching would be
    # unsafe.
    if error > 0.0025:
        raise RuntimeError(
            "could not resolve GLB axis mapping from authored mechanism pivots; "
            f"squared residual={error:.6f}, observed={observed}"
        )
    return perm, signs, error, observed


def root_parent_for_mechanisms(doc: dict) -> int | None:
    parents = parent_map(doc)
    magazine = find_node(doc, "Magazine")
    action = find_node(doc, "ChargingHandle")
    p_mag = parents.get(magazine)
    p_action = parents.get(action)
    if p_mag is not None and p_mag == p_action:
        return p_mag
    # Fall back to the common top-level ancestor if the exporter inserted
    # intermediate pivots.
    def ancestors(index: int) -> list[int]:
        chain = []
        while index in parents:
            index = parents[index]
            chain.append(index)
        return chain
    mag_chain = ancestors(magazine)
    action_chain = set(ancestors(action))
    for node in mag_chain:
        if node in action_chain:
            return node
    return None


def ensure_socket(doc: dict, parent: int | None, name: str, translation, extras: dict) -> int:
    for index, node in enumerate(doc.get("nodes", [])):
        if node.get("name") == name:
            node["translation"] = list(translation)
            node["extras"] = extras
            return index
    nodes = doc.setdefault("nodes", [])
    index = len(nodes)
    nodes.append({"name": name, "translation": list(translation), "extras": extras})
    if parent is not None:
        children = nodes[parent].setdefault("children", [])
        if index not in children:
            children.append(index)
    else:
        scene_index = int(doc.get("scene", 0))
        scenes = doc.setdefault("scenes", [{"nodes": []}])
        roots = scenes[scene_index].setdefault("nodes", [])
        roots.append(index)
    return index


def patch(path: Path, profile: str) -> None:
    spec = GRIP_SPECS[profile]
    doc, chunks = read_glb(path)
    perm, signs, error, observed = discover_axis_mapping(doc)
    parent = root_parent_for_mechanisms(doc)
    primary = apply_mapping(spec["primary"], perm, signs)
    support = apply_mapping(spec["support"], perm, signs)
    common = {
        "dustline_runtime_socket": True,
        "calibration_profile": profile,
        "provenance": spec["provenance"],
    }
    ensure_socket(doc, parent, "PrimaryGripSocket", primary, {**common, "role": "primary"})
    ensure_socket(doc, parent, "SupportGripSocket", support, {**common, "role": "support"})
    write_glb(path, doc, chunks)

    # Round-trip audit the patched JSON before handing it to Godot.
    verify, _ = read_glb(path)
    for name in ("PrimaryGripSocket", "SupportGripSocket"):
        find_node(verify, name)
    print(
        f"[DUSTLINE SOCKET PATCH] {profile} parent={parent} "
        f"axis_perm={perm} signs={signs} residual={error:.8f} "
        f"primary={primary} support={support} refs={observed}"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--profile", choices=sorted(GRIP_SPECS), required=True)
    parser.add_argument("glb", type=Path)
    args = parser.parse_args()
    patch(args.glb, args.profile)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"error: grip socket patch failed: {exc}", file=sys.stderr)
        raise
