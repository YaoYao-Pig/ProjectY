"""地块与建筑共享的低多边形网格工具；须通过 Blender MCP 在 Blender 中执行。"""

import math
import bpy
import bmesh

PALETTE = {
    "Grass": "759754", "GrassSide": "617944",
    "Rock": "9e9685", "RockDark": "898379", "RockLight": "b1a895",
    "Shore": "849c66", "Riverbed": "7d9671", "Earth": "948365",
    "City": "bca27b", "Water": "4da5b2", "WaterDeep": "246384",
    "Plaster": "ded0ad", "PlasterShade": "c9b994", "Gable": "e4d3ad",
    "Roof": "a8694e", "RoofShade": "875241", "Timber": "66594a",
    "TimberLight": "8c7558", "Stone": "aea18b", "Window": "536a68",
}


def srgb_linear(value):
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def ensure_material(key):
    """调色板使用 sRGB 色值；节点内转换为线性颜色，避免 Unity 重建时颜色偏亮。"""
    name = "M_MapLP_" + key
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    material = bpy.data.materials.new(name)
    rgb = tuple(int(PALETTE[key][i:i + 2], 16) / 255 for i in (0, 2, 4))
    rgba = tuple(srgb_linear(value) for value in rgb) + (1.0,)
    material.diffuse_color = rgba
    material.use_nodes = True
    node = material.node_tree.nodes.get("Principled BSDF")
    assert node is not None
    # 根据当前版本实际存在的输入设置哑光、不透明材质。
    assert all(key in node.inputs for key in ("Base Color", "Roughness", "Metallic"))
    node.inputs["Base Color"].default_value = rgba
    node.inputs["Roughness"].default_value = 0.88
    node.inputs["Metallic"].default_value = 0.0
    material["palette_srgb"] = "#" + PALETTE[key]
    return material


class MeshBuilder:
    def __init__(self):
        self.vertices = []
        self.faces = []
        self.face_materials = []
        self.material_keys = []

    def part(self, vertices, faces, materials):
        offset = len(self.vertices)
        self.vertices.extend(vertices)
        self.faces.extend(tuple(index + offset for index in face) for face in faces)
        if isinstance(materials, str):
            materials = [materials] * len(faces)
        assert len(materials) == len(faces)
        for key in materials:
            if key not in self.material_keys:
                self.material_keys.append(key)
            self.face_materials.append(self.material_keys.index(key))

    def box(self, center, size, material):
        x, y, z = center
        a, b, c = (value / 2 for value in size)
        vertices = [(x - a, y - b, z - c), (x + a, y - b, z - c),
                    (x + a, y + b, z - c), (x - a, y + b, z - c),
                    (x - a, y - b, z + c), (x + a, y - b, z + c),
                    (x + a, y + b, z + c), (x - a, y + b, z + c)]
        self.part(vertices, [(3, 2, 1, 0), (0, 1, 5, 4), (1, 2, 6, 5),
                             (2, 3, 7, 6), (3, 0, 4, 7), (4, 5, 6, 7)], material)

    def ridge_roof(self, half_width, half_depth, eave, peak, y_offset=0):
        # 山墙朝向 Blender -Y；导出后面向 Unity +Z。
        a, b = half_width, half_depth
        self.part([(-a, -b + y_offset, eave), (a, -b + y_offset, eave),
                   (a, b + y_offset, eave), (-a, b + y_offset, eave),
                   (0, -b + y_offset, peak), (0, b + y_offset, peak)],
                  [(0, 1, 4), (2, 3, 5), (0, 4, 5, 3), (1, 2, 5, 4), (3, 2, 1, 0)],
                  ["Gable", "PlasterShade", "RoofShade", "Roof", "Timber"])

    def beam(self, start, end, width, depth, material="Timber"):
        # 仅处理前后立面内的斜木梁，保持顶点明确与面数可控。
        ax, ay, az = start
        bx, by, bz = end
        length = math.hypot(bx - ax, bz - az)
        ox, oz = -(bz - az) / length * width / 2, (bx - ax) / length * width / 2
        vertices = []
        for sign in (-1, 1):
            vertices.extend([(ax - ox, ay + sign * depth / 2, az - oz),
                             (bx - ox, by + sign * depth / 2, bz - oz),
                             (bx + ox, by + sign * depth / 2, bz + oz),
                             (ax + ox, ay + sign * depth / 2, az + oz)])
        self.part(vertices, [(3, 2, 1, 0), (0, 1, 5, 4), (1, 2, 6, 5),
                             (2, 3, 7, 6), (3, 0, 4, 7), (4, 5, 6, 7)], material)

    def hex_prism(self, radius, bottom, top, top_material, side_material):
        ring = [(radius * math.cos(math.radians(30 + 60 * i)),
                 radius * math.sin(math.radians(30 + 60 * i))) for i in range(6)]
        vertices = [(x, y, bottom) for x, y in ring] + [(x, y, top) for x, y in ring]
        faces = [tuple(reversed(range(6))), tuple(range(6, 12))]
        faces.extend((i, (i + 1) % 6, (i + 1) % 6 + 6, i + 6) for i in range(6))
        self.part(vertices, faces, [side_material, top_material] + [side_material] * 6)

    def finish(self, name, collection):
        assert name not in bpy.data.objects, "禁止覆盖现存对象: " + name
        mesh = bpy.data.meshes.new(name + "_Mesh")
        mesh.from_pydata(self.vertices, [], self.faces)
        for key in self.material_keys:
            mesh.materials.append(ensure_material(key))
        for face, material_index in zip(mesh.polygons, self.face_materials):
            face.material_index = material_index
            face.use_smooth = False
        # 分离体也逐个统一外向法线，不添加平滑法线或隐藏的几何修改器。
        editable = bmesh.new()
        editable.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(editable, faces=list(editable.faces))
        editable.to_mesh(mesh)
        editable.free()
        mesh.update()
        # 平面/盒状 UV 以米为尺度，当前材质无需图片，但保留后续绘制入口。
        uv = mesh.uv_layers.new(name="UVMap")
        for face in mesh.polygons:
            dominant = max(range(3), key=lambda index: abs(face.normal[index]))
            axes = [axis for axis in range(3) if axis != dominant]
            for loop_index in face.loop_indices:
                coordinate = mesh.vertices[mesh.loops[loop_index].vertex_index].co
                uv.data[loop_index].uv = (coordinate[axes[0]], coordinate[axes[1]])
        obj = bpy.data.objects.new(name, mesh)
        collection.objects.link(obj)
        obj["style_family"] = "ProjectY_MapLowPoly"
        obj["front_axis_blender"] = "-Y"
        obj["front_axis_unity"] = "+Z"
        obj["units"] = "metres"
        obj["palette_srgb"] = ";".join(key + ":#" + PALETTE[key] for key in self.material_keys)
        return obj


def master_collection():
    return bpy.data.collections["MapLP_AssetMasters"]
