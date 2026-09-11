"""Convert a Stein Games Classic Weapons Pack FBX into a self-contained Godot GLB.

Run by Blender in background mode. The converter repairs missing FBX image paths,
rebuilds common PBR links (including Stein's RMAO convention), normalizes weapon
scale and bakes a consistent +Y-forward source orientation. Blender +Y becomes
Godot -Z after glTF export, matching Dustline's viewmodel frame.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def args_after_double_dash() -> list[str]:
    argv = sys.argv
    if "--" not in argv:
        raise SystemExit("expected: blender -b --python convert_stein_weapon.py -- SOURCE OUTPUT ROOT KIND")
    return argv[argv.index("--") + 1 :]


def normalized_name(path: Path) -> str:
    return path.stem.lower().replace("-", "_").replace(" ", "_")


def texture_score(path: Path, tokens: tuple[str, ...], source_dir: Path) -> int:
    name = normalized_name(path)
    score = sum(12 for token in tokens if token in name)
    try:
        rel = path.relative_to(source_dir)
        score += max(0, 10 - len(rel.parts))
    except ValueError:
        pass
    return score


def find_texture(files: list[Path], tokens: tuple[str, ...], source_dir: Path) -> Path | None:
    ranked = sorted(
        ((texture_score(path, tokens, source_dir), path) for path in files),
        key=lambda item: item[0],
        reverse=True,
    )
    return ranked[0][1] if ranked and ranked[0][0] > 0 else None


def image_node(nodes, image_path: Path, non_color: bool = False):
    image = bpy.data.images.load(str(image_path), check_existing=True)
    if non_color:
        try:
            image.colorspace_settings.name = "Non-Color"
        except Exception:
            pass
    node = nodes.new("ShaderNodeTexImage")
    node.image = image
    node.label = image_path.name
    return node


def repair_material(material, textures: list[Path], source_dir: Path) -> None:
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        bsdf = nodes.new("ShaderNodeBsdfPrincipled")
        output = next((n for n in nodes if n.type == "OUTPUT_MATERIAL"), None) or nodes.new("ShaderNodeOutputMaterial")
        links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])

    base = find_texture(textures, ("basecolor", "base_color", "albedo", "diffuse", "color"), source_dir)
    normal = find_texture(textures, ("normal", "nrm"), source_dir)
    rough = find_texture(textures, ("roughness", "rough"), source_dir)
    metal = find_texture(textures, ("metallic", "metalness", "metal"), source_dir)
    rmao = find_texture(textures, ("rmao", "orm", "arm"), source_dir)

    if base:
        node = image_node(nodes, base)
        links.new(node.outputs["Color"], bsdf.inputs["Base Color"])
    if normal:
        node = image_node(nodes, normal, True)
        normal_map = nodes.new("ShaderNodeNormalMap")
        normal_map.inputs["Strength"].default_value = 1.0
        links.new(node.outputs["Color"], normal_map.inputs["Color"])
        links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])

    if rmao:
        node = image_node(nodes, rmao, True)
        separate = nodes.new("ShaderNodeSeparateColor")
        separate.mode = "RGB"
        links.new(node.outputs["Color"], separate.inputs["Color"])
        # Stein v1.1: R = roughness, G = metallic, B = AO.
        links.new(separate.outputs["Red"], bsdf.inputs["Roughness"])
        links.new(separate.outputs["Green"], bsdf.inputs["Metallic"])
    else:
        if rough:
            node = image_node(nodes, rough, True)
            links.new(node.outputs["Color"], bsdf.inputs["Roughness"])
        if metal:
            node = image_node(nodes, metal, True)
            links.new(node.outputs["Color"], bsdf.inputs["Metallic"])


def resolve_imported_image_paths(asset_root: Path) -> None:
    by_name: dict[str, Path] = {}
    for path in asset_root.rglob("*"):
        if path.is_file():
            by_name.setdefault(path.name.lower(), path)
    for image in bpy.data.images:
        if not image.filepath:
            continue
        current = Path(bpy.path.abspath(image.filepath))
        if current.exists():
            continue
        candidate = by_name.get(current.name.lower())
        if candidate:
            image.filepath = str(candidate)
            try:
                image.reload()
            except Exception:
                pass


def bounds(objects) -> tuple[Vector, Vector]:
    points: list[Vector] = []
    for obj in objects:
        if obj.type != "MESH":
            continue
        for corner in obj.bound_box:
            points.append(obj.matrix_world @ Vector(corner))
    if not points:
        raise RuntimeError("Stein import produced no mesh bounds")
    minimum = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    maximum = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return minimum, maximum


def main() -> None:
    raw = args_after_double_dash()
    if len(raw) != 4:
        raise SystemExit("expected SOURCE OUTPUT ASSET_ROOT KIND")
    source = Path(raw[0]).resolve()
    output = Path(raw[1]).resolve()
    asset_root = Path(raw[2]).resolve()
    kind = raw[3].lower()
    target_length = 0.40 if kind == "pistol" else 1.25

    bpy.ops.wm.read_factory_settings(use_empty=True)
    # Keep this import call conservative so it works across Blender 4.x/5.x.
    bpy.ops.import_scene.fbx(filepath=str(source))
    imported = list(bpy.context.scene.objects)
    meshes = [obj for obj in imported if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"no mesh objects imported from {source}")

    resolve_imported_image_paths(asset_root)
    pngs = [p for p in asset_root.rglob("*.png") if p.is_file()]
    for material in bpy.data.materials:
        repair_material(material, pngs, source.parent)

    root = bpy.data.objects.new("SteinWeapon", None)
    bpy.context.scene.collection.objects.link(root)
    for obj in imported:
        if obj.parent is None:
            obj.parent = root

    minimum, maximum = bounds(meshes)
    center = (minimum + maximum) * 0.5
    longest = max((maximum - minimum).x, (maximum - minimum).y, (maximum - minimum).z)
    scale = target_length / max(longest, 1e-6)

    root.rotation_euler.z = math.radians(90.0)
    root.scale = (scale, scale, scale)
    root.location = Vector((center.y * scale, -center.x * scale, -center.z * scale))
    bpy.context.view_layer.update()

    for image in bpy.data.images:
        if image.source == "FILE":
            try:
                image.pack()
            except Exception:
                pass

    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format="GLB",
        export_yup=True,
        export_apply=True,
        export_materials="EXPORT",
        export_image_format="AUTO",
    )
    print(f"STEIN_CONVERT_OK kind={kind} source={source} output={output}")


if __name__ == "__main__":
    main()
