"""Generates scenes/world/District.tscn and scenes/shelter/Shelter.tscn.
The generated .tscn files are the source of truth afterwards (edit them in Godot)."""
import sys, os, random
sys.path.insert(0, os.path.dirname(__file__))
from tscn import Scene, V3, Col, NP, Raw, Rect, Tr

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BLOCK = "res://scripts/world/lowpoly_block.gd"
PROP = "res://scripts/world/lowpoly_prop.gd"
S_DOOR = "res://scripts/interaction/level_door.gd"
S_LOOT = "res://scripts/interaction/loot_container.gd"
S_PICK = "res://scripts/interaction/item_pickup.gd"
S_INFO = "res://scripts/interaction/info_pickup.gd"
S_EXAM = "res://scripts/interaction/examine.gd"
S_PHONE = "res://scripts/interaction/phone.gd"
S_BED = "res://scripts/interaction/bed.gd"
S_STATION = "res://scripts/interaction/station.gd"
S_GEN = "res://scripts/interaction/generator.gd"
S_STOVE = "res://scripts/interaction/stove.gd"
S_HIDE = "res://scripts/interaction/hiding_spot.gd"
S_LOC = "res://scripts/world/location_zone.gd"
S_INDOOR = "res://scripts/survival/indoor_zone.gd"
S_HEAT = "res://scripts/survival/heat_zone.gd"
S_LIGHT = "res://scripts/weather/lighting_controller.gd"
S_SPAWNER = "res://scripts/combat/enemy_spawner.gd"
S_SHELTER = "res://scripts/shelter/shelter_controller.gd"

random.seed(9)


class Builder:
    def __init__(self, scene):
        self.s = scene

    def block(self, parent, name, pos, size, color, yaw=0, groups=None, fade=None, **kw):
        props = {"transform": Tr(*pos, yaw=yaw), "size": V3(*size), "color": Col(*color)}
        if fade:
            groups = (groups or []) + ["fade:" + fade]
            props["fade_group"] = "fade:" + fade
        for k, v in kw.items():
            props[k] = v
        return self.s.node(name, "StaticBody3D", parent, props, script=BLOCK, groups=groups)

    def prop(self, parent, kind, pos, yaw=0, groups=None, name=None, fade=None, **kw):
        props = {"transform": Tr(*pos, yaw=yaw), "kind": kind}
        if fade:
            groups = (groups or []) + ["fade:" + fade]
            props["fade_group"] = "fade:" + fade
        for k, v in kw.items():
            if k in ("color", "light_color") and isinstance(v, tuple):
                v = Col(*v)
            if k == "size" and isinstance(v, tuple):
                v = V3(*v)
            props[k] = v
        return self.s.node(name or kind.title().replace("_", ""), "StaticBody3D", parent, props, script=PROP, groups=groups)

    def area(self, parent, name, script, pos, props, shape=("box", (1.6, 2.0, 1.6)), yaw=0, groups=None):
        p = {"transform": Tr(*pos, yaw=yaw)}
        p.update(props)
        n = self.s.node(name, "Area3D", parent, p, script=script, groups=groups)
        if shape[0] == "box":
            sh = self.s.sub("BoxShape3D", {"size": V3(*shape[1])})
            self.s.node("Shape", "CollisionShape3D", n, {"transform": Tr(0, shape[1][1] / 2.0, 0), "shape": sh})
        else:
            sh = self.s.sub("SphereShape3D", {"radius": shape[1]})
            self.s.node("Shape", "CollisionShape3D", n, {"transform": Tr(0, 0.8, 0), "shape": sh})
        return n

    def marker(self, parent, name, pos, yaw=0):
        return self.s.node(name, "Marker3D", parent, {"transform": Tr(*pos, yaw=yaw)})

    def walls(self, parent, bid, x0, z0, x1, z1, h, color, doors, t=0.3, cut_sides=("s",), low_sides=None):
        """Walls around a rectangle with door gaps. doors = [(side, center, width)]."""
        low_sides = low_sides or {}
        for side in ("n", "s", "w", "e"):
            gaps = sorted([(c - w / 2.0, c + w / 2.0) for (sd, c, w) in doors if sd == side])
            if side in ("n", "s"):
                a0, a1 = x0, x1
            else:
                a0, a1 = z0, z1
            segs = []
            cur = a0
            for g0, g1 in gaps:
                if g0 > cur:
                    segs.append((cur, g0))
                cur = g1
            if cur < a1:
                segs.append((cur, a1))
            groups = ["cutaway:" + bid] if side in cut_sides and bid else None
            hh = low_sides.get(side, h)
            for (a, b) in segs:
                L = b - a
                mid = (a + b) / 2.0
                if side == "n":
                    pos, size = (mid, 0, z0 + t / 2), (L, hh, t)
                elif side == "s":
                    pos, size = (mid, 0, z1 - t / 2), (L, hh, t)
                elif side == "w":
                    pos, size = (x0 + t / 2, 0, mid), (t, hh, L)
                else:
                    pos, size = (x1 - t / 2, 0, mid), (t, hh, L)
                self.block(parent, "Wall", pos, size, color, groups=groups, snow_mask=0.6, fade=bid or None)
            for (g0, g1) in gaps:
                if hh < 2.4:
                    continue
                L = g1 - g0
                mid = (g0 + g1) / 2.0
                lh = hh - 2.4
                if side == "n":
                    pos, size = (mid, 2.4, z0 + t / 2), (L, lh, t)
                elif side == "s":
                    pos, size = (mid, 2.4, z1 - t / 2), (L, lh, t)
                elif side == "w":
                    pos, size = (x0 + t / 2, 2.4, mid), (t, lh, L)
                else:
                    pos, size = (x1 - t / 2, 2.4, mid), (t, lh, L)
                self.block(parent, "Lintel", pos, size, color, groups=groups, snow_mask=0.6, fade=bid or None)


# =====================================================================================
# DISTRICT
# =====================================================================================

def district():
    s = Scene("District", "Node3D", {
        "level_id": "district", "display_name": "Квартал 9", "is_interior": False,
        "bounds": Rect(-80, -66, 160, 122), "default_spawn": "shelter_door", "ambient_profile": "outdoor",
    }, script="res://scripts/world/district.gd")
    b = Builder(s)
    env = s.sub("Environment", {
        "background_mode": 1, "background_color": Col(0.1, 0.1, 0.16), "ambient_light_source": 2,
        "ambient_light_color": Col(0.12, 0.13, 0.2), "ambient_light_energy": 1.0, "tonemap_mode": 2,
        "ssao_enabled": True, "ssao_radius": 1.5, "ssao_intensity": 1.4, "glow_enabled": True,
        "glow_intensity": 0.55, "glow_bloom": 0.05, "fog_enabled": True, "fog_light_color": Col(0.1, 0.1, 0.16),
        "fog_density": 0.025, "fog_sky_affect": 1.0, "volumetric_fog_enabled": True,
        "volumetric_fog_density": 0.006, "volumetric_fog_albedo": Col(0.9, 0.92, 1.0),
        "volumetric_fog_length": 48.0, "adjustment_enabled": True,
    })
    s.node("Environment", "WorldEnvironment", ".", {"environment": env})
    s.node("Sun", "DirectionalLight3D", ".", {"transform": Tr(0, 30, 0, yaw=35, pitch=-52), "light_color": Col(0.6, 0.7, 1.0),
        "light_energy": 0.2, "shadow_enabled": True, "directional_shadow_max_distance": 70.0})
    s.node("Lighting", "Node", ".", {"environment_path": NP("../Environment"), "sun_path": NP("../Sun"), "outdoor": True}, script=S_LIGHT)

    nav = s.sub("NavigationMesh", {"geometry_parsed_geometry_type": 1, "cell_size": 0.25, "cell_height": 0.25,
        "agent_height": 2.0, "agent_radius": 0.5, "agent_max_climb": 0.25})
    s.node("NavRegion", "NavigationRegion3D", ".", {"navigation_mesh": nav})
    G = s.node("Ground", "Node3D", "NavRegion")
    R = s.node("Roads", "Node3D", "NavRegion")
    B = s.node("Buildings", "Node3D", "NavRegion")
    P = s.node("Props", "Node3D", "NavRegion")

    b.block(G, "Snow", (0, -0.2, -5), (260, 0.2, 230), (0.8, 0.83, 0.88), fadeable=False, cast_shadows=False)
    asphalt = (0.2, 0.21, 0.23)
    walk = (0.42, 0.43, 0.46)
    road = dict(has_collision=False, fadeable=False, cast_shadows=False)
    b.block(R, "MainStreet", (0, 0, 0), (170, 0.03, 10), asphalt, snow_mask=0.55, **road)
    b.block(R, "SidewalkN", (0, 0, -6.5), (170, 0.045, 3), walk, snow_mask=0.8, **road)
    b.block(R, "SidewalkS", (0, 0, 6.5), (170, 0.045, 3), walk, snow_mask=0.8, **road)
    b.block(R, "NarrowStreet", (0, 0, -19), (7, 0.03, 20), asphalt, snow_mask=0.6, **road)
    b.block(R, "Square", (0, 0, -44), (40, 0.035, 28), (0.4, 0.4, 0.43), snow_mask=0.75, **road)
    b.block(R, "NorthRoad", (0, 0, -63), (8, 0.03, 8), asphalt, snow_mask=0.7, **road)
    b.block(R, "Alley", (-38, 0, 27), (6, 0.03, 38), (0.3, 0.3, 0.32), snow_mask=0.65, **road)
    b.block(R, "PharmacyPath", (21, 0, -46), (6, 0.035, 4), walk, snow_mask=0.8, **road)
    b.block(R, "SubstationYard", (29, 0, 11.5), (22, 0.035, 3), walk, snow_mask=0.8, **road)

    # --- Shelter building (Дом 12), north side, door faces the street/camera ---------
    b.block(B, "Shelter", (-51.5, 0, -19), (21, 11, 18), (0.42, 0.27, 0.22), show_on_map=True, map_label="Дом 12", fade="shelter12")
    b.block(B, "ShelterRoof", (-51.5, 11, -19), (18, 2.2, 21), (0.24, 0.2, 0.2), shape="gable", yaw=90, has_collision=False, fade="shelter12")
    for y in (2.0, 5.0, 8.0):
        for x in (-59, -55.5, -47.5, -44):
            lit = (y == 8.0 and x == -44) or (y == 2.0 and x == -55.5)
            b.prop(P, "window", (x, y + 0.6, -9.94), lit=lit, light_color=(1.0, 0.72, 0.4), has_collision=False, fade="shelter12")
    b.prop(P, "door_frame", (-51.5, 0, -9.93), color=(0.3, 0.22, 0.16), has_collision=False, fade="shelter12")
    b.prop(P, "lamp", (-47, 0, -7.2), lit=True, flicker=True, light_color=(1.0, 0.7, 0.4), light_energy=1.6, light_range=9.0, light_shadows=True)

    # --- Shop (enterable) ----------------------------------------------------------------
    shop = s.node("Shop", "Node3D", B)
    b.block(shop, "Floor", (-26, 0, 16), (16, 0.06, 12), (0.35, 0.33, 0.3), snow_mask=0.0, has_collision=False, fadeable=False, show_on_map=True, map_label="Магазин")
    b.walls(shop, "shop", -34, 10, -18, 22, 3.6, (0.55, 0.5, 0.4), [("n", -26.5, 2.4)])
    b.block(shop, "Roof", (-26, 3.6, 16), (16.6, 0.35, 12.6), (0.25, 0.25, 0.27), groups=["cutaway:shop"], has_collision=False, fade="shop")
    b.block(shop, "Sign", (-26.5, 2.7, 9.8), (5, 0.7, 0.15), (0.2, 0.4, 0.75), emission=0.4, snow_mask=0.0, has_collision=False)
    b.prop(shop, "shelf", (-32.6, 0, 13.5), yaw=90)
    b.prop(shop, "shelf", (-32.6, 0, 18.0), yaw=90)
    b.prop(shop, "shelf", (-24.0, 0, 21.4), yaw=180, size=(1.4, 1, 1))
    b.prop(shop, "counter", (-20.8, 0, 13.4), yaw=90)
    b.prop(shop, "crate", (-20.5, 0, 20.5), size=(1.2, 1.2, 1.2))

    # --- Substation (closed, future content) -----------------------------------------------
    b.block(B, "Substation", (29, 0, 20.5), (18, 7, 15), (0.52, 0.52, 0.54), show_on_map=True, map_label="Подстанция №9", fade="substation")
    b.block(B, "SubstationRoof", (29, 7, 20.5), (18.4, 0.5, 15.4), (0.3, 0.3, 0.32), has_collision=False, fade="substation")
    b.prop(P, "door_frame", (29, 0, 12.93), color=(0.2, 0.22, 0.25), has_collision=False, fade="substation")
    b.prop(P, "symbol", (33.5, 0, 12.92), has_collision=False, fade="substation")
    b.prop(P, "fence", (22.5, 0, 10), size=(2.25, 1, 1))
    b.prop(P, "fence", (35.5, 0, 10), size=(2.25, 1, 1))
    b.prop(P, "crate", (37.2, 0, 11.6), color=(0.3, 0.35, 0.3), size=(1.2, 1, 1))
    b.prop(P, "crate", (22, 0, 12), color=(0.35, 0.35, 0.38), size=(2.2, 1.6, 1.4))

    # --- Other south buildings ------------------------------------------------------------
    b.block(B, "Garage", (-14, 0, 38), (12, 3.5, 8), (0.4, 0.42, 0.45), show_on_map=True, fade="garage")
    b.block(B, "House14", (58.5, 0, 20), (27, 12, 20), (0.36, 0.4, 0.46), show_on_map=True, map_label="Дом 14", fade="house14")
    b.block(B, "House14Roof", (58.5, 12, 20), (20, 2.4, 27), (0.22, 0.22, 0.26), shape="gable", yaw=90, has_collision=False, fade="house14")
    for y in (2.0, 5.0, 8.0, 11.0):
        for x in (48, 53, 58, 63, 68):
            lit = (y, x) in ((8.0, 53), (2.0, 63))
            if y < 11.0:
                b.prop(P, "window", (x, y + 0.6, 9.94), lit=lit, has_collision=False, fade="house14")

    # --- Residential house #7 (enterable, Elias), south side, door on the north wall ---
    house = s.node("House7", "Node3D", B)
    b.block(house, "Floor", (-51, 0, 18), (18, 0.06, 16), (0.4, 0.3, 0.22), snow_mask=0.0, has_collision=False, fadeable=False, show_on_map=True, map_label="Дом №7")
    b.walls(house, "house", -60, 10, -42, 26, 3.6, (0.6, 0.55, 0.48), [("n", -51, 2.4)])
    b.block(house, "InnerWallW", (-56.5, 0, 18), (7, 3.2, 0.25), (0.55, 0.5, 0.44), snow_mask=0.0)
    b.block(house, "InnerWallE", (-45.5, 0, 18), (7, 3.2, 0.25), (0.55, 0.5, 0.44), snow_mask=0.0)
    b.block(house, "Upper", (-51, 3.6, 18), (18, 3.4, 16), (0.58, 0.52, 0.45), groups=["cutaway:house"], has_collision=False, fade="house")
    b.block(house, "Roof", (-51, 7.0, 18), (16.4, 2.2, 18.4), (0.3, 0.2, 0.18), shape="gable", groups=["cutaway:house"], has_collision=False, fade="house")
    for x in (-57, -45):
        b.prop(house, "window", (x, 5.0, 9.95), lit=(x == -45), has_collision=False, groups=["cutaway:house"], fade="house")
    b.prop(house, "counter", (-58.9, 0, 13.5), yaw=90)
    b.prop(house, "table", (-47, 0, 13.5))
    b.prop(house, "chair", (-47, 0, 14.4), yaw=180)
    b.prop(house, "crate", (-43.4, 0, 16.8), size=(0.8, 0.6, 0.6), color=(0.6, 0.15, 0.12))
    b.prop(house, "bed", (-58.3, 0, 23.8))
    b.prop(house, "wardrobe", (-44.5, 0, 25.3), yaw=180)
    b.prop(house, "table", (-50.5, 0, 25.0), size=(1.2, 1, 1))
    b.prop(house, "radio_set", (-52.5, 0, 25.2), yaw=180, lit=False)
    b.prop(house, "chair", (-56, 0, 20.3))
    b.prop(house, "candle", (-50.5, 0.82, 25.0), light_energy=0.8, light_range=5.0)

    # --- Narrow street buildings --------------------------------------------------------------
    b.block(B, "BuildingA", (-12.75, 0, -18.5), (18.5, 9, 19), (0.35, 0.38, 0.44), show_on_map=True, fade="bldA")
    b.block(B, "BuildingARoof", (-12.75, 9, -18.5), (18.5, 2.0, 19), (0.22, 0.22, 0.26), shape="gable", has_collision=False, fade="bldA")
    b.block(B, "BuildingB", (12.75, 0, -18.5), (18.5, 8, 19), (0.46, 0.36, 0.3), show_on_map=True, fade="bldB")
    b.block(B, "BuildingBRoof", (12.75, 8, -18.5), (18.5, 2.0, 19), (0.26, 0.2, 0.18), shape="gable", has_collision=False, fade="bldB")
    for x in (-18, -12, -6, 6, 12, 18):
        b.prop(P, "window", (x, 2.6, -8.96), lit=False, has_collision=False, fade="bldA" if x < 0 else "bldB")

    # --- West of square ---------------------------------------------------------------------------
    b.block(B, "House3", (-35, 0, -44.5), (22, 10, 23), (0.4, 0.42, 0.38), show_on_map=True, map_label="Дом 3", fade="house3")
    b.block(B, "House3Roof", (-35, 10, -44.5), (22, 2.2, 23), (0.24, 0.24, 0.22), shape="gable", has_collision=False, fade="house3")
    b.block(B, "East1", (58, 0, -24), (24, 9, 18), (0.44, 0.44, 0.48), show_on_map=True, fade="east1")
    b.block(B, "East1Roof", (58, 9, -24), (24, 2.0, 18), (0.24, 0.24, 0.28), shape="gable", has_collision=False, fade="east1")

    # --- Pharmacy (enterable) -------------------------------------------------------------------
    ph = s.node("Pharmacy", "Node3D", B)
    b.block(ph, "Floor", (32, 0, -46), (16, 0.06, 16), (0.6, 0.62, 0.6), snow_mask=0.0, has_collision=False, fadeable=False, show_on_map=True, map_label="Аптека")
    b.walls(ph, "pharmacy", 24, -54, 40, -38, 3.6, (0.75, 0.78, 0.8), [("w", -46, 2.4)])
    b.block(ph, "BackWall", (36, 0, -46), (0.3, 3.4, 16), (0.7, 0.72, 0.74), snow_mask=0.0)
    b.block(ph, "Roof", (32, 3.6, -46), (16.6, 0.35, 16.6), (0.3, 0.32, 0.34), groups=["cutaway:pharmacy"], has_collision=False, fade="pharmacy")
    b.block(ph, "Cross", (23.8, 2.3, -49), (0.12, 0.9, 0.3), (0.2, 1.0, 0.45), emission=2.0, snow_mask=0.0, has_collision=False)
    b.block(ph, "Cross2", (23.8, 2.6, -49), (0.12, 0.3, 0.9), (0.2, 1.0, 0.45), emission=2.0, snow_mask=0.0, has_collision=False)
    b.prop(ph, "counter", (28, 0, -46), yaw=90, size=(1.4, 1, 1))
    b.prop(ph, "shelf", (30, 0, -53.4))
    b.prop(ph, "shelf", (33.5, 0, -53.4))
    b.prop(ph, "door_frame", (35.83, 0, -46), yaw=90, color=(0.35, 0.3, 0.25), has_collision=False)
    b.prop(ph, "table", (31, 0, -40.5))
    b.prop(ph, "ceiling_lamp", (31, 0, -46), lit=True, flicker=True, light_color=(0.8, 0.95, 1.0), light_energy=0.8, light_range=8.0)

    # --- Square ----------------------------------------------------------------------------------
    b.prop(P, "barrel_fire", (0, 0, -44), lit=True, light_energy=1.6, light_range=9.0)
    b.prop(P, "bench", (-3.6, 0, -44), yaw=90)
    b.prop(P, "bench", (3.6, 0, -44), yaw=-90)
    b.prop(P, "bench", (0, 0, -47.6))
    b.prop(P, "notice_board", (-9, 0, -32.2))
    b.prop(P, "pallet", (-15, 0, -53))
    b.prop(P, "pine", (-17, 0, -57))
    b.prop(P, "pine", (-17, 0, -33), size=(1, 0.8, 1))
    b.prop(P, "kiosk", (12, 0, -53), lit=True)
    b.prop(P, "antenna", (16, 0, -56), size=(1, 1.3, 1))
    b.prop(P, "crate", (14.3, 0, -51.9), color=(0.3, 0.33, 0.4), size=(0.8, 1.2, 0.8))
    b.prop(P, "lamp", (18, 0, -31), lit=True, light_color=(0.75, 0.85, 1.0), light_energy=1.2, light_range=10.0)
    b.prop(P, "bin", (-18.4, 0, -41), yaw=90)

    # --- Narrow street ----------------------------------------------------------------------------
    b.prop(P, "bin", (-2.5, 0, -13.5), yaw=90)
    b.prop(P, "crate", (2.5, 0, -26))
    b.prop(P, "rubble", (2.4, 0, -15))
    b.prop(P, "hydrant", (-2.9, 0, -24))

    # --- Main street --------------------------------------------------------------------------------
    b.prop(P, "car", (-10, 0, 1.2), yaw=8, color=(0.42, 0.18, 0.16))
    b.prop(P, "car", (34, 0, -2.4), yaw=-12, color=(0.25, 0.35, 0.5))
    b.prop(P, "bus", (73, 0, 0), yaw=80)
    for x in (-62, -30, 8, 44):
        b.prop(P, "lamp", (x, 0, -7.0), lit=False)
    for x in (-22, 22, 56):
        b.prop(P, "lamp", (x, 0, 7.0), yaw=180, lit=False)
    b.prop(P, "bin", (18, 0, 7.4))

    # --- Alley ----------------------------------------------------------------------------------
    b.prop(P, "bin", (-39.9, 0, 16), yaw=90)
    b.prop(P, "bin", (-36.1, 0, 31), yaw=-90)
    b.prop(P, "pallet", (-39.7, 0, 23.5))
    b.prop(P, "crate", (-36.2, 0, 37.5))
    b.prop(P, "fence", (-38, 0, 46), size=(1.6, 1, 1))
    b.prop(P, "device", (-38, 0, 43), lit=True)
    b.prop(P, "symbol", (-41.94, 0, 22), yaw=90, has_collision=False, fade="house")
    b.block(B, "AlleyWall", (-34.8, 0, 34), (0.4, 3.0, 16), (0.36, 0.34, 0.33), snow_mask=0.8)
    b.block(B, "AlleyWallW", (-41.2, 0, 36), (0.4, 3.0, 20), (0.36, 0.34, 0.33), snow_mask=0.8)

    # --- North road ----------------------------------------------------------------------------------
    b.prop(P, "barricade", (0, 0, -60.5), size=(1.6, 1, 1))
    for (x, z, sx, sy, sz) in ((-6, -64, 4, 2.2, 3), (6, -63.5, 4.5, 2.5, 3), (0, -66.5, 6, 3.0, 3), (-11, -61, 3, 1.6, 3), (11, -61, 3, 1.8, 3)):
        b.prop(P, "drift", (x, 0, z), size=(sx, sy, sz))

    # --- South yards / trees / drifts ---------------------------------------------------------------
    for (x, z, sc) in ((-30, 40, 1.0), (-25, 50, 1.2), (5, 45, 0.9), (15, 38, 1.1), (40, 45, 1.0), (62, 42, 1.2), (-66, 40, 1.0), (-70, -30, 1.1), (70, -45, 1.0), (-4, 52, 0.8)):
        b.prop(P, "pine", (x, 0, z), size=(1, sc, 1))
    b.prop(P, "bench", (8, 0, 34), yaw=180)
    b.prop(P, "fence", (0, 0, 30), size=(4.0, 1, 1))
    for i in range(22):
        x = random.uniform(-76, 76)
        z = random.choice([random.uniform(9, 54), random.uniform(-64, -30) if abs(x) > 42 else random.uniform(30, 54)])
        if -62 < x < -40 and 8 < z < 28:
            continue
        if -62 < x < -40 and -30 < z < -8:
            continue
        if -42 < x < -33 and z < 47:
            continue
        b.prop(P, "drift", (x, 0, z), size=(random.uniform(1.5, 3.5), random.uniform(0.6, 1.4), random.uniform(1.5, 3.0)), has_collision=False)
    # Edge drifts that visually close the district.
    for x in range(-78, 80, 8):
        b.prop(P, "drift", (x, 0, 55), size=(5, 2.5, 3), has_collision=False)
    for z in range(-60, 56, 8):
        b.prop(P, "drift", (-79, 0, z), size=(3, 2.5, 5), has_collision=False)
        b.prop(P, "drift", (79, 0, z), size=(3, 2.5, 5), has_collision=False)
    for x in range(-78, -8, 8):
        b.prop(P, "drift", (x, 0, -65), size=(5, 2.8, 3), has_collision=False)
    for x in range(14, 80, 8):
        b.prop(P, "drift", (x, 0, -65), size=(5, 2.8, 3), has_collision=False)

    # --- Invisible bounds ----------------------------------------------------------------------------
    bounds = s.node("Bounds", "Node3D", ".")
    for (name, pos, size) in (("West", (-81, 3, -5), (2, 6, 130)), ("East", (81, 3, -5), (2, 6, 130)), ("North", (0, 3, -67.5), (170, 6, 2)), ("South", (0, 3, 57), (170, 6, 2))):
        body = s.node(name, "StaticBody3D", bounds, {"transform": Tr(*pos)})
        s.node("Shape", "CollisionShape3D", body, {"shape": s.sub("BoxShape3D", {"size": V3(*size)})})

    # --- Distant skyline (vanishes in fog / blizzard) --------------------------------------------------
    sky = s.node("Skyline", "Node3D", ".")
    for i in range(26):
        ang = i / 26.0 * 6.283 + random.uniform(-0.1, 0.1)
        import math
        r = random.uniform(115, 150)
        x, z = math.cos(ang) * r, math.sin(ang) * r * 0.9 - 5
        h = random.uniform(16, 38)
        b.block(sky, "Tower", (x, 0, z), (random.uniform(12, 22), h, random.uniform(12, 20)), (0.2, 0.22, 0.27), has_collision=False, fadeable=False, cast_shadows=False, snow_mask=0.5)
        if random.random() < 0.3:
            b.block(sky, "LitWindow", (x, h * 0.6, z + 10.2), (1.2, 1.4, 0.2), (1.0, 0.75, 0.45), emission=2.5, has_collision=False, fadeable=False, cast_shadows=False, snow_mask=0.0)
    b.block(sky, "Meridian", (0, 0, -175), (10, 60, 10), (0.16, 0.17, 0.2), has_collision=False, fadeable=False, cast_shadows=False)
    b.block(sky, "MeridianLight", (0, 60, -175), (1.5, 1.5, 1.5), (1.0, 0.2, 0.15), emission=6.0, has_collision=False, fadeable=False, cast_shadows=False, snow_mask=0.0)

    # --- Zones -------------------------------------------------------------------------------------
    Z = s.node("Zones", "Node3D", ".")
    locs = [
        ("shelter_street", "У дома 12", (-51, 0, -4), (26, 4, 12)),
        ("main_street", "Главная улица", (0, 0, 0), (150, 4, 14)),
        ("car", "Брошенная машина", (-10, 0, 1.5), (9, 4, 7)),
        ("narrow_street", "Узкая улица", (0, 0, -19), (7, 4, 20)),
        ("square", "Малая площадь", (0, 0, -44), (40, 4, 28)),
        ("radio_point", "Радиоточка", (12, 0, -51), (9, 4, 7)),
        ("pharmacy", "Аптека", (32, 0, -46), (16, 4, 16)),
        ("house", "Жилой дом №7", (-51, 0, 18), (18, 4, 16)),
        ("shop", "Магазин «Северный»", (-26, 0, 16), (16, 4, 12)),
        ("alley", "Переулок", (-38, 0, 27), (6, 4, 38)),
        ("substation", "Подстанция №9", (29, 0, 13), (22, 4, 8)),
        ("north_road", "Северная дорога", (0, 0, -61), (12, 4, 8)),
    ]
    for (lid, name, pos, size) in locs:
        b.area(Z, "Loc_" + lid, S_LOC, pos, {"location_id": lid, "display_name": name}, shape=("box", size))
    b.area(Z, "Indoor_shop", S_INDOOR, (-26, 0, 16), {"building_id": "shop"}, shape=("box", (15.2, 3.0, 11.2)))
    b.area(Z, "Indoor_house", S_INDOOR, (-51, 0, 18), {"building_id": "house"}, shape=("box", (17.2, 3.0, 15.2)))
    b.area(Z, "Indoor_pharmacy", S_INDOOR, (30, 0, -46), {"building_id": "pharmacy"}, shape=("box", (11.4, 3.0, 15.2)))
    b.area(Z, "Heat_barrel", S_HEAT, (0, 0, -44), {"strength": 1.7, "first_warm_flag": "found_heat_source"}, shape=("sphere", 3.4))
    b.area(Z, "Heat_device", S_HEAT, (-38, 0, 43), {"strength": 0.6}, shape=("sphere", 2.2))

    # --- Interactables -------------------------------------------------------------------------------
    I = s.node("Interactables", "Node3D", ".")
    b.area(I, "ShelterDoor", S_DOOR, (-51.5, 0, -9.2), {"display_name": "Дом 12 — убежище", "interaction_text": "Войти", "target_level": "shelter", "target_spawn": "default"}, shape=("box", (2.4, 2.4, 1.6)))
    b.area(I, "SubstationDoor", S_EXAM, (29, 0, 12.2), {"display_name": "Дверь подстанции", "interaction_text": "Осмотреть", "title": "Подстанция №9",
        "text": "Заперто изнутри. Сквозь металл идёт низкий ровный гул — будто что-то внутри всё ещё работает. Когда-нибудь вы узнаете, что там.",
        "consequences": [{"add_info": "note_substation"}, {"set_flag": "saw_substation"}]}, shape=("box", (2.2, 2.4, 1.2)))
    b.area(I, "SubstationBox", S_LOOT, (37.2, 0, 11.0), {"display_name": "Ящик у забора", "items": {"pistol_ammo": 2}, "loot_table": "electrical_box"}, shape=("box", (1.6, 1.6, 1.4)))
    # Shop
    b.area(I, "ShopShelf1", S_LOOT, (-31.8, 0, 13.5), {"display_name": "Полка с консервами", "items": {"canned_food": 1}, "loot_table": "shop_food"})
    b.area(I, "ShopShelf2", S_LOOT, (-31.8, 0, 18.0), {"display_name": "Полка с водой", "items": {"water_bottle": 1}, "loot_table": "shop_food"})
    b.area(I, "ShopStock", S_LOOT, (-24.0, 0, 20.6), {"display_name": "Коробки со склада", "items": {}, "loot_table": "shop_stock"})
    b.area(I, "ShopRegister", S_LOOT, (-21.6, 0, 13.4), {"display_name": "Касса", "interaction_text": "Разобрать", "items": {"electronics": 1}, "loot_table": "shop_counter", "found_text": "Из кассы выходит пригоршня плат и проводов."})
    b.area(I, "ShopDoor", S_HIDE, (-20.5, 0, 19.5), {"display_name": "За ящиками"}, shape=("box", (1.4, 2, 1.4)))
    # Car
    b.area(I, "CarInterior", S_LOOT, (-10.3, 0, 2.6), {"display_name": "Брошенная машина", "items": {"pistol": 1, "pistol_ammo": 4}, "loot_table": "car_glovebox",
        "found_text": "В бардачке — старый пистолет, завёрнутый в тряпку. Патронов мало."}, shape=("box", (2.6, 2, 1.4)))
    b.area(I, "CarTrunk", S_LOOT, (-12.9, 0, 1.0), {"display_name": "Багажник", "interaction_text": "Вскрыть", "items": {"electronics": 1}, "loot_table": "car_trunk",
        "required_item": "crowbar", "requirement_text": "Багажник заклинило. Нужна монтировка."}, shape=("box", (1.2, 2, 2.2)))
    b.area(I, "Car2", S_LOOT, (34, 0, -1.0), {"display_name": "Машина", "items": {}, "loot_table": "car_glovebox"}, shape=("box", (2.6, 2, 1.4)))
    b.area(I, "Bus", S_LOOT, (73, 0, 3.0), {"display_name": "Перевёрнутый автобус", "items": {}, "loot_table": "car_trunk"}, shape=("box", (3, 2, 1.6)))
    # House 7
    b.area(I, "HouseKitchen", S_LOOT, (-58.2, 0, 13.5), {"display_name": "Кухонный шкаф", "items": {"canned_food": 1}, "loot_table": "kitchen_cabinet"})
    b.area(I, "HouseToolbox", S_LOOT, (-43.9, 0, 16.8), {"display_name": "Ящик с инструментами", "items": {"crowbar": 1}, "loot_table": "toolbox", "found_text": "Под отвёртками — тяжёлая монтировка."})
    b.area(I, "HouseWardrobe", S_LOOT, (-44.5, 0, 24.5), {"display_name": "Шкаф", "items": {"warm_jacket": 1}, "loot_table": "wardrobe", "found_text": "Старый пуховик. Велик, но тёплый."})
    b.area(I, "HouseChair", S_LOOT, (-56, 0, 20.3), {"display_name": "Сломанный стул", "interaction_text": "Разобрать на доски", "items": {}, "loot_table": "woodpile"})
    b.area(I, "HouseDesk", S_EXAM, (-51.5, 0, 24.3), {"display_name": "Стол с деталями", "title": "Стол Elias",
        "text": "Паяльник, лупа, разобранный приёмник. На листке — начатая схема передатчика и надпись: «не хватает питания и трёх плат»."}, shape=("box", (2.4, 2, 1.4)))
    # Pharmacy
    b.area(I, "PharmacyCounter", S_LOOT, (27.2, 0, -46), {"display_name": "Прилавок", "items": {"bandage": 1}, "loot_table": "pharmacy_shelf"}, shape=("box", (1.4, 2, 2.4)))
    b.area(I, "PharmacyBackroom", S_LOOT, (35.1, 0, -46), {"display_name": "Подсобка", "interaction_text": "Вскрыть", "items": {"medicine": 2, "protective_mask": 1}, "loot_table": "pharmacy_backroom",
        "required_item": "crowbar", "requirement_text": "Дверь подсобки заперта. Нужна монтировка.",
        "found_text": "Монтировка с хрустом выламывает замок. Внутри — лекарства и маска.", "consequences": [{"set_flag": "pharmacy_backroom_opened"}]}, shape=("box", (1.4, 2.2, 2.4)))
    b.area(I, "PharmacyNote", S_INFO, (31, 0, -40.5), {"info_id": "note_pharmacy"}, shape=("box", (1.6, 2, 1.2)))
    b.area(I, "PharmacyShelf", S_LOOT, (31.7, 0, -52.8), {"display_name": "Пустые полки", "items": {}, "empty_text": "Всё выгребли. Остались только пустые коробки."}, shape=("box", (3.4, 2, 1.2)))
    # Square
    b.area(I, "NoticeBoard", S_INFO, (-9, 0, -31.4), {"info_id": "note_evac", "interaction_text": "Прочитать"}, shape=("box", (2.2, 2, 1.2)))
    b.area(I, "WoodPile", S_LOOT, (-15, 0, -52.2), {"display_name": "Поддоны", "interaction_text": "Разобрать", "items": {}, "loot_table": "woodpile"})
    b.area(I, "SquareWater", S_PICK, (6, 0, -38.2), {"item_id": "water_bottle", "count": 1}, shape=("sphere", 0.7))
    b.area(I, "RadioPoint", S_STATION, (12, 0, -51.2), {"display_name": "Радиоточка", "interaction_text": "Настроить приёмник", "panel": "radio", "station_id": "radio_point",
        "consequences": [{"set_flag": "radio_point_used"}]}, shape=("box", (2.4, 2, 1.4)))
    b.area(I, "RadioLocker", S_LOOT, (14.3, 0, -51.1), {"display_name": "Шкафчик радиоточки", "interaction_text": "Открыть", "items": {"electronics": 2}, "loot_table": "radio_equipment",
        "conditions": [{"any": [{"item": "crowbar"}, {"tier_min": ["vera", "cooperative"]}, {"flag": "vera_locker_ok"}, {"npc_not_at": ["vera", "district"]}]}],
        "requirement_text": "Шкафчик заперт, Vera следит за ним. Можно вскрыть монтировкой — или заслужить её доверие."}, shape=("box", (1.2, 2, 1.2)))
    b.area(I, "SquareBin", S_HIDE, (-17.6, 0, -41), {"display_name": "Мусорный бак"}, shape=("box", (1.4, 2, 2.0)))
    # Narrow street
    b.area(I, "NarrowBin", S_HIDE, (-1.7, 0, -13.5), {"display_name": "Мусорный бак"}, shape=("box", (1.4, 2, 2.0)))
    b.area(I, "NarrowCrate", S_LOOT, (2.4, 0, -25.3), {"display_name": "Ящик", "items": {}, "loot_table": "rubble"})
    # Main street
    b.area(I, "StreetBin", S_HIDE, (18, 0, 6.6), {"display_name": "Мусорный бак"}, shape=("box", (2.0, 2, 1.4)))
    # Alley
    b.area(I, "AlleyBin1", S_HIDE, (-39.1, 0, 16), {"display_name": "Мусорный бак"}, shape=("box", (1.4, 2, 2.0)))
    b.area(I, "AlleyBin2", S_HIDE, (-36.9, 0, 31), {"display_name": "Мусорный бак"}, shape=("box", (1.4, 2, 2.0)))
    b.area(I, "AlleyPallets", S_LOOT, (-39.0, 0, 23.5), {"display_name": "Поддоны", "interaction_text": "Разобрать", "items": {"wood": 2}})
    b.area(I, "AlleyCrate", S_LOOT, (-36.9, 0, 37.5), {"display_name": "Ящик", "items": {}, "loot_table": "trash"})
    b.area(I, "Device", S_EXAM, (-38, 0, 42.2), {"display_name": "Тёплый предмет", "title": "Тёплый предмет",
        "text": "Тёмный металлический цилиндр высотой по колено. Он тёплый — как живое существо. Снег тает вокруг него идеальным кругом, асфальт под ним сухой. На крышке выгравирован знак: круг и три черты.\n\nЛучше его не трогать.",
        "consequences": [{"add_info": "device_warm"}]}, shape=("sphere", 1.1))
    b.area(I, "Symbol", S_EXAM, (-40.9, 0, 22), {"display_name": "Знак на стене", "title": "Знак",
        "text": "Свежая краска поверх кирпича: круг и три вертикальные черты внутри, как падающий снег. Краска не замёрзла.",
        "consequences": [{"set_flag": "seen_symbol"}]}, shape=("box", (1.2, 2.4, 1.6)))
    tr1 = b.area(I, "TracksAlley", S_EXAM, (-38, 0, 19), {"display_name": "Странные следы", "title": "Следы",
        "text": "Цепочка трёхпалых следов уходит в глубь переулка. Шаг — почти два метра. Края отпечатков оплавлены, будто то, что прошло здесь, было тёплым.",
        "available_if": [{"day_min": 2}], "hide_when_unavailable": True, "consequences": [{"set_flag": "q04_alley_tracks"}]}, shape=("box", (2.4, 2, 3)))
    b.prop(tr1, "tracks", (0, 0, 0), yaw=180, size=(1, 1, 3.5), has_collision=False, name="Prints")
    tr2 = b.area(I, "TracksDoor", S_EXAM, (-46, 0, -7.6), {"display_name": "Следы у двери", "title": "Следы",
        "text": "Ночью кто-то стоял прямо у двери убежища. Трёхпалые отпечатки. Потом следы уходят на восток, через улицу — к переулку.",
        "available_if": [{"day_min": 2}], "hide_when_unavailable": True, "consequences": [{"set_flag": "q04_door_tracks"}]}, shape=("box", (3, 2, 2)))
    b.prop(tr2, "tracks", (0, 0, 0), yaw=-90, size=(1, 1, 2.2), has_collision=False, name="Prints")
    b.area(I, "NorthRoad", S_EXAM, (0, 0, -58.6), {"display_name": "Северная дорога", "interaction_text": "Осмотреть дорогу", "dialogue_id": "north_road"}, shape=("box", (9, 2, 1.8)))

    # --- Spawns -----------------------------------------------------------------------------------------
    SP = s.node("Spawns", "Node3D", ".")
    for (name, pos, yaw) in (("spawn_shelter_door", (-51.5, 0, -7.6), 180), ("spawn_default", (-51.5, 0, -7.6), 180), ("spawn_square", (0, 0, -37), 0),
            ("spawn_pharmacy", (21, 0, -46), -90), ("spawn_alley", (-38, 0, 12), 180), ("spawn_north_road", (0, 0, -55), 0),
            ("spawn_house", (-51, 0, 7.5), 180), ("spawn_shop", (-26.5, 0, 7.5), 180), ("spawn_narrow_street", (0, 0, -9), 0),
            ("npc_mara_street", (2.1, 0, -19.5), 90), ("npc_elias_house", (-49.5, 0, 22.3), 0), ("npc_vera_radio", (9.2, 0, -50.4), 0),
            ("npc_anton_car", (-6.6, 0, 3.5), 90), ("npc_tomas_shop", (-23.5, 0, 17), 90), ("npc_grey_alley", (-37, 0, 40.2), 0),
            ("npc_mara_pharmacy", (31, 0, -43.5), 90), ("npc_tomas_alley", (-36.8, 0, 34), 90)):
        b.marker(SP, name, pos, yaw)
    s.node("Actors", "Node3D", ".")

    # --- Enemy spawner + routes ----------------------------------------------------------------------
    s.node("EnemySpawner", "Node3D", ".", script=S_SPAWNER)
    routes = s.node("Routes", "Node3D", "EnemySpawner")
    for (rname, pts) in (("Alley", [(-38, 0, 12), (-38, 0, 40), (-37, 0, 26)]),
                         ("Square", [(-14, 0, -55), (14, 0, -56), (14, 0, -34), (-14, 0, -34)]),
                         ("East", [(28, 0, 1), (62, 0, 2), (44, 0, -5)]),
                         ("North", [(-20, 0, -30.5), (22, 0, -30.5), (0, 0, -24)])):
        r = s.node(rname, "Node3D", routes)
        for i, p in enumerate(pts):
            b.marker(r, "P%d" % i, p)
    return s


# =====================================================================================
# SHELTER
# =====================================================================================

def shelter():
    s = Scene("Shelter", "Node3D", {
        "level_id": "shelter", "display_name": "Убежище", "is_interior": True,
        "heated_conditions": [{"any": [{"flag": "stove_lit"}, {"all": [{"flag": "generator_repaired"}, {"not_flag": "generator_failed"}]}]}],
        "bounds": Rect(-12, -9, 24, 18), "default_spawn": "default", "ambient_profile": "indoor",
    }, script="res://scripts/core/level.gd")
    b = Builder(s)
    env = s.sub("Environment", {
        "background_mode": 1, "background_color": Col(0.0, 0.0, 0.0), "ambient_light_source": 2,
        "ambient_light_color": Col(0.24, 0.25, 0.33), "ambient_light_energy": 1.0, "tonemap_mode": 2,
        "ssao_enabled": True, "ssao_radius": 1.0, "ssao_intensity": 1.6, "glow_enabled": True, "glow_intensity": 0.6,
        "adjustment_enabled": True,
    })
    s.node("Environment", "WorldEnvironment", ".", {"environment": env})
    s.node("Lighting", "Node", ".", {"environment_path": NP("../Environment"), "outdoor": False}, script=S_LIGHT)
    s.node("ShelterController", "Node", ".", script=S_SHELTER)
    s.node("Moonlight", "SpotLight3D", ".", {"transform": Tr(-4.5, 2.8, -6.8, yaw=0, pitch=-35), "light_color": Col(0.55, 0.65, 1.0),
        "light_energy": 2.2, "spot_range": 10.0, "spot_angle": 38.0, "shadow_enabled": True})

    geo = s.node("Geometry", "Node3D", ".")
    wall = (0.5, 0.46, 0.42)
    inner = (0.46, 0.43, 0.4)
    b.block(geo, "Floor", (0, -0.1, 0), (18.6, 0.1, 12.6), (0.3, 0.24, 0.18), snow_mask=0.0, fadeable=False)
    b.block(geo, "FloorStorage", (6, 0, -3), (5.8, 0.02, 5.8), (0.32, 0.32, 0.34), snow_mask=0.0, has_collision=False, fadeable=False)
    b.walls(geo, "", -9, -6, 9, 6, 3.0, wall, [("s", 0, 2.0)], cut_sides=(), low_sides={"s": 1.0})
    # Interior partitions
    b.block(geo, "WallMid1", (3, 0, -4.9), (0.25, 3.0, 2.2), inner, snow_mask=0.0)
    b.block(geo, "WallMid2", (3, 0, -0.1), (0.25, 3.0, 3.6), inner, snow_mask=0.0)
    b.block(geo, "WallMid3", (3, 0, 4.9), (0.25, 1.0, 2.2), inner, snow_mask=0.0)
    b.block(geo, "WallStorageW", (4.1, 0, 0), (2.2, 1.2, 0.25), inner, snow_mask=0.0)
    b.block(geo, "WallStorageE", (8.1, 0, 0), (1.8, 1.2, 0.25), inner, snow_mask=0.0)
    b.block(geo, "WallRadioN1", (-7.8, 0, 1.5), (2.4, 3.0, 0.25), inner, snow_mask=0.0)
    b.block(geo, "WallRadioN2", (-3.9, 0, 1.5), (1.8, 3.0, 0.25), inner, snow_mask=0.0)
    b.block(geo, "WallRadioE", (-3, 0, 4.4), (0.25, 1.0, 3.2), inner, snow_mask=0.0)

    P = s.node("Props", "Node3D", ".")
    b.prop(P, "bed", (-7.6, 0, -4.4))
    b.prop(P, "window", (-4.5, 1.7, -5.88), lit=True, light_color=(0.45, 0.55, 0.85), has_collision=False)
    b.prop(P, "phone", (-1.4, 0, -5.4))
    b.prop(P, "table", (-2.2, 0, -1.6))
    b.prop(P, "chair", (-2.2, 0, -0.6), yaw=180)
    b.prop(P, "candle", (-2.4, 0.83, -1.6), lit=True, light_energy=1.6, light_range=8.0)
    b.prop(P, "stove", (1.7, 0, -5.3), lit=False, light_energy=1.8, light_range=8.0, groups=["shelter_stove"])
    b.prop(P, "counter", (-8.4, 0, -1.4), yaw=90)
    b.prop(P, "board", (-8.9, 0, 0.6), yaw=90, color=(0.8, 0.8, 0.78))
    b.block(P, "RedCross", (-8.83, 1.45, 0.6), (0.05, 0.25, 0.08), (0.9, 0.1, 0.1), snow_mask=0.0, has_collision=False)
    b.prop(P, "ceiling_lamp", (-5, 0, -2), lit=True, light_color=(1.0, 0.85, 0.65), light_energy=1.3, light_range=8.0, groups=["power_light"])
    b.prop(P, "ceiling_lamp", (0, 0, 2.5), lit=True, light_color=(1.0, 0.85, 0.65), light_energy=1.1, light_range=7.0, groups=["power_light"])
    b.prop(P, "ceiling_lamp", (6, 0, -3), lit=True, light_color=(1.0, 0.9, 0.75), light_energy=1.0, light_range=6.0, groups=["power_light"])
    b.prop(P, "door_frame", (0, 0, 5.95), color=(0.28, 0.22, 0.16), has_collision=False)
    # Storage
    b.prop(P, "shelf", (8.4, 0, -3.2), yaw=-90)
    b.prop(P, "shelf", (4.4, 0, -5.4))
    b.prop(P, "crate", (6.4, 0, -5.3), size=(2.2, 1.4, 1.2), color=(0.34, 0.3, 0.24))
    b.prop(P, "generator", (7.8, 0, -1.0), lit=False, groups=["shelter_generator"])
    # Workshop
    b.prop(P, "workbench", (6, 0, 5.3), yaw=180)
    b.prop(P, "board", (8.9, 0, 2.6), yaw=-90)
    b.prop(P, "rubble", (4.8, 0, 2.2), groups=["shelter_level_1_only"])
    b.prop(P, "ceiling_lamp", (6, 0, 3), lit=True, light_color=(1.0, 0.95, 0.8), light_energy=1.4, light_range=7.0, groups=["power_light", "shelter_level_2"])
    b.prop(P, "shelf", (3.5, 0, 3.0), yaw=90, groups=["shelter_level_2"])
    b.prop(P, "crate", (8.2, 0, 4.8), size=(0.9, 0.8, 0.9), color=(0.25, 0.3, 0.35), groups=["shelter_level_2"])
    # Radio room
    b.prop(P, "radio_set", (-8.3, 0, 3.6), yaw=90, lit=False, groups=["shelter_radio"])
    b.prop(P, "table", (-6.5, 0, 5.2), size=(1.2, 1, 1))
    b.prop(P, "transmitter", (-5.0, 0, 5.4), yaw=180, groups=["shelter_level_3"])
    b.prop(P, "antenna", (-8.0, 0, 5.3), size=(1, 0.4, 1), groups=["shelter_level_3"], has_collision=False)
    b.prop(P, "ceiling_lamp", (-6, 0, 3.5), lit=True, light_color=(0.9, 1.0, 0.9), light_energy=0.9, light_range=5.0, groups=["power_light", "shelter_level_3"])

    Z = s.node("Zones", "Node3D", ".")
    b.area(Z, "StoveHeat", S_HEAT, (1.7, 0, -4.3), {"strength": 1.2, "active_flag": "stove_lit"}, shape=("sphere", 2.6))

    I = s.node("Interactables", "Node3D", ".")
    b.area(I, "Bed", S_BED, (-7.6, 0, -3.2), {"conditions": [{"any": [{"flag": "first_squall_done"}, {"day_min": 2}, {"hour_between": [23, 7]}]}],
        "requirement_text": "Не уснуть. Сначала нужно понять, что происходит снаружи."}, shape=("box", (1.6, 2, 2.4)))
    b.area(I, "Phone", S_PHONE, (-1.4, 0, -4.7), {"display_name": "Телефон", "interaction_text": "Ответить", "dialogue_id": "intro_phone",
        "available_if": [{"not_flag": "phone_answered"}]}, shape=("box", (1.4, 2, 1.4)))
    b.area(I, "PhoneDead", S_EXAM, (-1.4, 0, -4.7), {"display_name": "Телефон", "interaction_text": "Снять трубку", "title": "Телефон",
        "text": "Тишина. Даже гудка нет. Сообщение Elias осталось на автоответчике — оно в журнале [Q].", "available_if": [{"flag": "phone_answered"}]}, shape=("box", (1.4, 2, 1.4)))
    b.area(I, "WindowIntro", S_EXAM, (-4.5, 0, -5.1), {"display_name": "Окно", "interaction_text": "Посмотреть", "dialogue_id": "intro_window",
        "available_if": [{"flag": "phone_answered"}, {"not_flag": "intro_done"}]}, shape=("box", (2.0, 2, 1.4)))
    b.area(I, "Window", S_EXAM, (-4.5, 0, -5.1), {"display_name": "Окно", "interaction_text": "Посмотреть", "dialogue_id": "window_view",
        "available_if": [{"flag": "intro_done"}]}, shape=("box", (2.0, 2, 1.4)))
    b.area(I, "Kitchen", S_LOOT, (-7.8, 0, -1.4), {"display_name": "Кухонный шкаф", "items": {"canned_food": 1, "water_bottle": 1}})
    b.area(I, "FirstAid", S_LOOT, (-8.2, 0, 0.7), {"display_name": "Аптечка", "items": {"bandage": 1, "medicine": 1}}, shape=("box", (1.4, 2, 1.2)))
    b.area(I, "Flashlight", S_PICK, (7.7, 0.3, -3.5), {"item_id": "flashlight", "count": 1}, shape=("sphere", 0.8))
    b.area(I, "StorageShelf", S_LOOT, (4.4, 0, -4.7), {"display_name": "Полки", "items": {"cloth": 1}}, shape=("box", (1.8, 2, 1.2)))
    b.area(I, "Storage", S_STATION, (6.4, 0, -4.4), {"display_name": "Склад", "interaction_text": "Открыть", "panel": "storage", "station_id": "storage"}, shape=("box", (2.2, 2, 1.2)))
    b.area(I, "Generator", S_GEN, (7.3, 0, -1.6), {}, shape=("box", (1.8, 2, 1.2)))
    b.area(I, "Stove", S_STOVE, (1.7, 0, -4.6), {}, shape=("box", (1.4, 2, 1.2)))
    b.area(I, "Workbench", S_STATION, (6, 0, 4.5), {"display_name": "Верстак", "interaction_text": "Мастерская", "panel": "crafting", "station_id": "workbench",
        "available_if": [{"flag": "intro_done"}]}, shape=("box", (2.2, 2, 1.2)))
    b.area(I, "UpgradeBoard", S_STATION, (8.3, 0, 2.6), {"display_name": "План убежища", "interaction_text": "Улучшения", "panel": "shelter", "station_id": "shelter",
        "available_if": [{"flag": "intro_done"}]}, shape=("box", (1.2, 2, 1.8)))
    b.area(I, "RadioBasic", S_STATION, (-7.6, 0, 3.6), {"display_name": "Радиоприёмник", "interaction_text": "Включить радио", "panel": "radio", "station_id": "shelter_basic",
        "available_if": [{"not": {"shelter_level_min": 3}}, {"flag": "intro_done"}], "consequences": [{"set_flag": "shelter_radio_used"}]}, shape=("box", (1.2, 2, 1.6)))
    b.area(I, "RadioStation", S_STATION, (-7.6, 0, 3.6), {"display_name": "Радиостанция", "interaction_text": "Сканировать эфир", "panel": "radio", "station_id": "shelter_station",
        "available_if": [{"shelter_level_min": 3}]}, shape=("box", (1.2, 2, 1.6)))
    b.area(I, "Transmitter", S_EXAM, (-5.0, 0, 4.6), {"display_name": "Передатчик", "interaction_text": "Выйти в эфир", "dialogue_id": "transmitter",
        "available_if": [{"shelter_level_min": 3}]}, shape=("box", (1.6, 2, 1.2)))
    b.area(I, "Exit", S_DOOR, (0, 0, 5.3), {"display_name": "Выход на улицу", "interaction_text": "Выйти", "target_level": "district", "target_spawn": "shelter_door",
        "required_flag": "intro_done", "requirement_text": "Сначала нужно понять, что происходит."}, shape=("box", (2.2, 2, 1.4)))

    SP = s.node("Spawns", "Node3D", ".")
    for (name, pos, yaw) in (("spawn_start", (-6.4, 0, -2.6), 0), ("spawn_default", (0, 0, 4.1), 0),
            ("npc_shelter_mara", (-4.2, 0, 0.6), 180), ("npc_shelter_elias", (5.0, 0, 1.6), 90), ("npc_shelter_vera", (-5.8, 0, 3.2), 90),
            ("npc_shelter_anton", (0.6, 0, -2.6), 0), ("npc_shelter_tomas", (5.4, 0, -2.4), 0), ("npc_shelter_grey", (-0.6, 0, 3.6), 0)):
        b.marker(SP, name, pos, yaw)
    s.node("Actors", "Node3D", ".")
    return s


if __name__ == "__main__":
    open(os.path.join(ROOT, "scenes/world/District.tscn"), "w").write(district().dump())
    open(os.path.join(ROOT, "scenes/shelter/Shelter.tscn"), "w").write(shelter().dump())
    print("levels written")
