# Parlworld – VFX-Meshes per Blender-Skript (Blender 5.x)
# Aufruf: blender --background --factory-startup --python vfx_build.py -- <ausgabeordner>
# Erzeugt eigene Effekt-Meshes mit Texturen und exportiert sie als GLB (+ Vorschau-Render).
# Achsen: Blender +Y wird beim glTF-Export zu Roblox -Z (= vorne). Blender +Z = oben.
import bpy, bmesh, math, os, sys, random
import numpy as np

out_dir = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.dirname(__file__)
os.makedirs(out_dir, exist_ok=True)
random.seed(7)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


# ---------------------------------------------------------------- Texturen
def make_image(name, size, fn):
    """fn(u, v) -> (r, g, b, a) als numpy-Arrays; u,v in [0,1]"""
    w, h = size
    u, v = np.meshgrid(np.linspace(0, 1, w), np.linspace(0, 1, h))
    r, g, b, a = fn(u, v)
    px = np.stack([r, g, b, a], axis=-1).astype(np.float32).ravel()
    img = bpy.data.images.new(name, w, h, alpha=True)
    img.pixels.foreach_set(px)
    img.filepath_raw = os.path.join(out_dir, name + ".png")
    img.file_format = "PNG"
    img.save()
    img.pack()
    return img


def lerp(a, b, t):
    return a + (b - a) * t


def flame_tex(u, v):
    # v = 0 Basis (heißer Kern) -> v = 1 Spitze; Rand dunkler, Flammen-Streifen
    t = np.clip(v, 0, 1)
    streak = 0.5 + 0.5 * np.sin(u * math.tau * 6 + v * 9)
    core = np.clip(1.0 - t * 1.4, 0, 1)
    r = np.clip(1.0 - 0.05 * t, 0, 1)
    g = np.clip(lerp(0.95, 0.25, t) * (0.85 + 0.15 * streak) + 0.1 * core, 0, 1)
    b = np.clip(lerp(0.55, 0.02, np.clip(t * 2, 0, 1)) * core + 0.02, 0, 1)
    a = np.clip(1.15 - t ** 2.2 * (0.8 + 0.4 * (1 - streak)), 0.15, 1)
    return r, g, b, a


def egg_tex(u, v):
    base_r, base_g, base_b = 0.98, 0.94, 0.84
    noise = np.random.default_rng(3).random(u.shape)
    spots = (noise > 0.985).astype(np.float32)
    shade = 0.96 + 0.04 * np.sin(v * math.pi)
    r = (base_r * shade) * (1 - spots * 0.45)
    g = (base_g * shade) * (1 - spots * 0.55)
    b = (base_b * shade) * (1 - spots * 0.7)
    return r, g, b, np.ones_like(u)


def shell_tex(u, v):
    r, g, b, a = egg_tex(u, v)
    inner = v < 0.08
    return np.where(inner, 1.0, r), np.where(inner, 0.98, g), np.where(inner, 0.93, b), a


def slash_tex(u, v):
    # u entlang der Sichel (0..1), v quer (0 außen scharf .. 1 innen weich)
    along = np.sin(np.clip(u, 0, 1) * math.pi) ** 0.6
    edge = np.clip(1.0 - v, 0, 1) ** 1.6
    a = np.clip(along * (0.25 + 0.75 * edge), 0, 1)
    r = np.ones_like(u)
    g = np.clip(0.92 + 0.08 * edge, 0, 1)
    b = np.clip(0.65 + 0.35 * edge, 0, 1)
    return r, g, b, a


def feather_tex(u, v):
    # u quer, v längs (0 Kiel .. 1 Spitze): creme mit türkiser Spitze, Kiel-Linie
    tip = np.clip((v - 0.6) / 0.4, 0, 1)
    shaft = np.exp(-((u - 0.5) ** 2) / 0.0015)
    barbs = 0.9 + 0.1 * np.sin((v * 40) + np.abs(u - 0.5) * 30)
    r = lerp(0.98, 0.25, tip) * barbs - shaft * 0.15
    g = lerp(0.95, 0.75, tip) * barbs - shaft * 0.1
    b = lerp(0.85, 0.72, tip) * barbs
    a = np.clip(1.0 - (np.abs(u - 0.5) * 2) ** 6, 0, 1)
    return np.clip(r, 0, 1), np.clip(g, 0, 1), np.clip(b, 0, 1), a


def material(name, img, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    bsdf.inputs["Roughness"].default_value = 0.6
    if emission > 0:
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emission
    if hasattr(mat, "surface_render_method"):
        mat.surface_render_method = "BLENDED"
    elif hasattr(mat, "blend_method"):
        mat.blend_method = "BLEND"
    return mat


# ---------------------------------------------------------------- Geometrie-Helfer
def new_obj(name, bm, mat):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(mat)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def cylinder_uv(bm, uv_layer, u_from_angle=True):
    # UVs: u = Winkel um Z, v = Höhe (normiert)
    zs = [v.co.z for v in bm.verts]
    zmin, zmax = min(zs), max(zs)
    for f in bm.faces:
        for loop in f.loops:
            co = loop.vert.co
            ang = (math.atan2(co.y, co.x) / math.tau) % 1.0
            loop[uv_layer].uv = (ang, (co.z - zmin) / max(1e-6, zmax - zmin))


# 1) Feuerball: Tropfenform mit Flammenzungen, Spitze nach hinten (Blender -Y)
def build_fireball(mat):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=16, radius=0.5)
    for v in bm.verts:
        x, y, z = v.co
        # entlang Z modellieren, danach drehen: z>0 wird zum Schweif
        if z > 0:
            k = z / 0.5
            taper = 1 - 0.85 * k ** 0.9
            ang = math.atan2(y, x)
            flick = 1 + 0.35 * math.sin(ang * 5 + k * 4) * k
            v.co.x, v.co.y = x * taper * flick, y * taper * flick
            v.co.z = z * (1 + 1.8 * k)
    uv = bm.loops.layers.uv.new("UVMap")
    cylinder_uv(bm, uv)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=__import__("mathutils").Matrix.Rotation(math.radians(90), 3, "X"))
    return new_obj("vfx_fireball", bm, mat)


# 2) Flammenkranz: 12 gebogene Flammenzungen im Kreis (Radius 1, Höhe ~1.2)
def build_flame_ring(mat):
    import mathutils
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    n = 12
    for i in range(n):
        a = i / n * math.tau
        h = 0.9 + 0.5 * random.random()
        tmp = bmesh.new()
        bmesh.ops.create_cone(tmp, cap_ends=False, segments=10, radius1=0.22, radius2=0.0, depth=h)
        for v in tmp.verts:
            k = (v.co.z + h / 2) / h
            v.co.x += 0.18 * k ** 2 * math.sin(i * 1.7)
            v.co.y += 0.12 * k ** 2
            v.co.z += h / 2
        tuv = tmp.loops.layers.uv.new("UVMap")
        cylinder_uv(tmp, tuv)
        mat_rot = mathutils.Matrix.Rotation(a, 4, "Z") @ mathutils.Matrix.Translation((1.0, 0, 0))
        bmesh.ops.transform(tmp, matrix=mat_rot, verts=tmp.verts)
        me = bpy.data.meshes.new("tmp")
        tmp.to_mesh(me)
        tmp.free()
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
    return new_obj("vfx_flamering", bm, mat)


# 3) Ei + 5 Schalensplitter
def egg_shape(bm):
    for v in bm.verts:
        z = v.co.z
        s = 1.0 - 0.18 * max(0.0, z / 0.5)  # oben spitzer
        v.co.x *= s * 0.78
        v.co.y *= s * 0.78
        v.co.z *= 1.0


def build_egg(mat):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=28, v_segments=18, radius=0.5)
    egg_shape(bm)
    uv = bm.loops.layers.uv.new("UVMap")
    cylinder_uv(bm, uv)
    return new_obj("vfx_egg", bm, mat)


def build_shells(mat):
    objs = []
    sectors = [(0, 0.35, -0.5, 0.05), (0.35, 0.7, -0.5, 0.1), (0.7, 1.0, -0.5, 0.0),
               (0.0, 0.5, 0.05, 0.5), (0.5, 1.0, 0.1, 0.5)]
    for i, (a0, a1, z0, z1) in enumerate(sectors):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=28, v_segments=18, radius=0.5)
        egg_shape(bm)
        kill = []
        for f in bm.faces:
            c = f.calc_center_median()
            ang = (math.atan2(c.y, c.x) / math.tau) % 1.0
            jag = 0.012 * math.sin(c.z * 22 + i)  # leicht unregelmäßige Bruchkante
            if not (a0 + jag <= ang <= a1 + jag and z0 <= c.z <= z1):
                kill.append(f)
        bmesh.ops.delete(bm, geom=kill, context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        # um eigenen Mittelpunkt zentrieren
        cx = sum(v.co.x for v in bm.verts) / len(bm.verts)
        cy = sum(v.co.y for v in bm.verts) / len(bm.verts)
        cz = sum(v.co.z for v in bm.verts) / len(bm.verts)
        for v in bm.verts:
            v.co.x -= cx; v.co.y -= cy; v.co.z -= cz
        uv = bm.loops.layers.uv.new("UVMap")
        cylinder_uv(bm, uv)
        ob = new_obj("vfx_eggshell_%d" % (i + 1), bm, mat)
        mod = ob.modifiers.new("dicke", "SOLIDIFY")
        mod.thickness = 0.03
        objs.append(ob)
    return objs


# 4) Hieb-Sichel: flache Mondsichel in der XY-Ebene, Öffnung nach vorne
def build_slash(mat):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    segs, r_out, r_in = 24, 1.0, 0.72
    rows = []
    for i in range(segs + 1):
        t = i / segs
        a = math.radians(-70 + 140 * t)
        thick = math.sin(t * math.pi)
        ro = r_out
        ri = r_out - (r_out - r_in) * thick - 0.01
        rows.append((bm.verts.new((math.sin(a) * ro, math.cos(a) * ro, 0)),
                     bm.verts.new((math.sin(a) * ri, math.cos(a) * ri, 0)), t))
    for i in range(segs):
        (a0, b0, t0), (a1, b1, t1) = rows[i], rows[i + 1]
        f = bm.faces.new((a0, a1, b1, b0))
        for loop in f.loops:
            vtx = loop.vert
            tt = t0 if vtx in (a0, b0) else t1
            vv = 0.0 if vtx in (a0, a1) else 1.0
            loop[uv].uv = (tt, vv)
    ob = new_obj("vfx_slash", bm, mat)
    ob.data.polygons.foreach_set("use_smooth", [False] * len(ob.data.polygons))
    return ob


# 5) Feder: flaches, leicht gebogenes Blatt, Länge 1 (entlang +Z)
def build_feather(mat):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    rows = 12
    grid = []
    for j in range(rows + 1):
        v = j / rows
        width = 0.16 * math.sin(min(1, v * 1.05) * math.pi) ** 0.7 + 0.01
        bend = 0.12 * v ** 2
        row = []
        for i, u in enumerate((0.0, 0.5, 1.0)):
            x = (u - 0.5) * 2 * width
            row.append((bm.verts.new((x, bend + abs(x) * 0.15, v)), u, v))
        grid.append(row)
    for j in range(rows):
        for i in range(2):
            quad = [grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]]
            f = bm.faces.new([q[0] for q in quad])
            for loop, q in zip(f.loops, quad):
                loop[uv].uv = (q[1], q[2])
    ob = new_obj("vfx_feather", bm, mat)
    mod = ob.modifiers.new("dicke", "SOLIDIFY")
    mod.thickness = 0.008
    return ob


# ---------------------------------------------------------------- Aufbau
flame_img = make_image("vfx_flame", (128, 256), flame_tex)
egg_img = make_image("vfx_eggskin", (256, 256), egg_tex)
shell_img = make_image("vfx_shell", (128, 128), shell_tex)
slash_img = make_image("vfx_slashtex", (256, 64), slash_tex)
feather_img = make_image("vfx_feathertex", (64, 256), feather_tex)

m_flame = material("mat_flame", flame_img, emission=3.0)
m_egg = material("mat_egg", egg_img)
m_shell = material("mat_shell", shell_img)
m_slash = material("mat_slash", slash_img, emission=2.0)
m_feather = material("mat_feather", feather_img)

objs = []
objs.append(build_fireball(m_flame))
objs.append(build_flame_ring(m_flame))
objs.append(build_egg(m_egg))
objs += build_shells(m_shell)
objs.append(build_slash(m_slash))
objs.append(build_feather(m_feather))

# Modifikatoren anwenden
for ob in objs:
    bpy.context.view_layer.objects.active = ob
    for mod in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)

# ---------------------------------------------------------------- Vorschau-Render (Objekte nebeneinander)
for i, ob in enumerate(objs):
    ob.location = ((i % 6) * 2.6 - 6.5, 0, (i // 6) * -2.8)
cam_data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_data)
bpy.context.collection.objects.link(cam)
cam.location = (0, -16, -1.2)
cam.rotation_euler = (math.radians(90), 0, 0)
cam_data.lens = 32
scene.camera = cam
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3
sun.rotation_euler = (math.radians(50), 0, math.radians(30))
bpy.context.collection.objects.link(sun)
scene.world = bpy.data.worlds.new("w")
scene.world.color = (0.08, 0.1, 0.14)
scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in {e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items} else "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 1400, 700
scene.render.filepath = os.path.join(out_dir, "vfx_preview.png")
bpy.ops.render.render(write_still=True)

# ---------------------------------------------------------------- Export (Objekte wieder an Ursprung)
for ob in objs:
    ob.location = (0, 0, 0)
cam.select_set(False)
sun.select_set(False)
for ob in bpy.context.scene.objects:
    ob.select_set(ob in objs)
bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, "parlworld_vfx.glb"), export_format="GLB",
                          use_selection=True, export_image_format="AUTO", export_apply=True)
print("FERTIG", [o.name for o in objs])
