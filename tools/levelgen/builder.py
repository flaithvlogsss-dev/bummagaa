"""Shared helpers for the LAST SNOW level generator: node shortcuts for blocks, props,
buildings, walls with door gaps, real doors and every interactable type."""
import collections
from tscn import V3, Col, Tr

BLOCK = "res://scripts/world/lowpoly_block.gd"
BUILDING = "res://scripts/world/building.gd"
PROP = "res://scripts/world/lowpoly_prop.gd"
S_LEVEL_DOOR = "res://scripts/interaction/level_door.gd"
S_DOOR = "res://scripts/interaction/door.gd"
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

KIND_NAMES = {S_LOOT: "loot", S_PICK: "pickup", S_INFO: "info", S_EXAM: "examine", S_HIDE: "hide",
              S_DOOR: "door", S_LEVEL_DOOR: "level_door", S_STATION: "station", S_BED: "bed",
              S_PHONE: "phone", S_GEN: "generator", S_STOVE: "stove"}


def _conv(k, v):
    if k in ("color", "light_color", "trim_color", "roof_color", "sign_color", "window_light") and isinstance(v, tuple):
        return Col(*v)
    if k == "size" and isinstance(v, tuple):
        return V3(*v)
    return v


class Builder:
    def __init__(self, scene, indoor_snow=1.0):
        self.s = scene
        self.counts = collections.Counter()
        # Props parented to these nodes are furniture indoors: no snow on them.
        self.indoor_parents = set()
        self.default_snow_scale = indoor_snow

    # --- Geometry ---------------------------------------------------------------------------

    def block(self, parent, name, pos, size, color, yaw=0, groups=None, fade=None, **kw):
        props = {"transform": Tr(*pos, yaw=yaw), "size": V3(*size), "color": Col(*color)}
        if fade:
            groups = (groups or []) + ["fade:" + fade]
            props["fade_group"] = "fade:" + fade
        for k, v in kw.items():
            props[k] = _conv(k, v)
        return self.s.node(name, "StaticBody3D", parent, props, script=BLOCK, groups=groups)

    def building(self, parent, name, x0, z0, x1, z1, height, color, yaw=0, groups=None, fade=None, **kw):
        """A merged facade building on the rectangle (front = +Z, or -Z with yaw=180)."""
        props = {"transform": Tr((x0 + x1) / 2.0, kw.pop("y", 0), (z0 + z1) / 2.0, yaw=yaw),
                 "size": V3(x1 - x0, height, z1 - z0), "color": Col(*color)}
        if fade:
            groups = (groups or []) + ["fade:" + fade]
            props["fade_group"] = "fade:" + fade
        for k, v in kw.items():
            props[k] = _conv(k, v)
        return self.s.node(name, "StaticBody3D", parent, props, script=BUILDING, groups=groups)

    def prop(self, parent, kind, pos, yaw=0, groups=None, name=None, fade=None, **kw):
        props = {"transform": Tr(*pos, yaw=yaw), "kind": kind}
        snow = kw.pop("snow_scale", 0.0 if parent in self.indoor_parents else self.default_snow_scale)
        if snow != 1.0:
            props["snow_scale"] = snow
        if fade:
            groups = (groups or []) + ["fade:" + fade]
            props["fade_group"] = "fade:" + fade
        for k, v in kw.items():
            props[k] = _conv(k, v)
        return self.s.node(name or kind.title().replace("_", ""), "StaticBody3D", parent, props, script=PROP, groups=groups)

    def walls(self, parent, bid, x0, z0, x1, z1, h, color, doors, t=0.3, cut_sides=("s",), low_sides=None,
              material="plaster", snow=0.6, fade=None):
        """Walls around a rectangle with door gaps. doors = [(side, center, width)]."""
        low_sides = low_sides or {}
        fade = fade if fade is not None else (bid or None)
        for side in ("n", "s", "w", "e"):
            gaps = sorted([(c - w / 2.0, c + w / 2.0) for (sd, c, w) in doors if sd == side])
            a0, a1 = (x0, x1) if side in ("n", "s") else (z0, z1)
            segs, cur = [], a0
            for g0, g1 in gaps:
                if g0 > cur:
                    segs.append((cur, g0))
                cur = g1
            if cur < a1:
                segs.append((cur, a1))
            groups = ["cutaway:" + bid] if side in cut_sides and bid else None
            hh = low_sides.get(side, h)
            for (a, b) in segs:
                self._wall_piece(parent, "Wall", side, a, b, 0, hh, x0, z0, x1, z1, t, color, groups, material, snow, fade)
            for (g0, g1) in gaps:
                if hh >= 2.4:
                    self._wall_piece(parent, "Lintel", side, g0, g1, 2.4, hh - 2.4, x0, z0, x1, z1, t, color, groups, material, snow, fade)

    def _wall_piece(self, parent, name, side, a, b, y, hh, x0, z0, x1, z1, t, color, groups, material, snow, fade):
        L, mid = b - a, (a + b) / 2.0
        if side == "n":
            pos, size = (mid, y, z0 + t / 2), (L, hh, t)
        elif side == "s":
            pos, size = (mid, y, z1 - t / 2), (L, hh, t)
        elif side == "w":
            pos, size = (x0 + t / 2, y, mid), (t, hh, L)
        else:
            pos, size = (x1 - t / 2, y, mid), (t, hh, L)
        self.block(parent, name, pos, size, color, groups=groups, snow_mask=snow, fade=fade, material=material)

    def inner_wall(self, parent, axis, fixed, a0, a1, gaps, h=3.2, color=(0.55, 0.5, 0.44), t=0.2, material="wallpaper"):
        """Interior partition along X (axis='x', at z=fixed) or Z (axis='z', at x=fixed) with door gaps [(center, width)]."""
        cur = a0
        segs = []
        for c, w in sorted(gaps):
            if c - w / 2 > cur:
                segs.append((cur, c - w / 2))
            cur = c + w / 2
        if cur < a1:
            segs.append((cur, a1))
        for (a, b) in segs:
            mid, L = (a + b) / 2.0, b - a
            if axis == "x":
                self.block(parent, "Partition", (mid, 0, fixed), (L, h, t), color, snow_mask=0.0, material=material)
            else:
                self.block(parent, "Partition", (fixed, 0, mid), (t, h, L), color, snow_mask=0.0, material=material)
        for c, w in gaps:
            if h > 2.4:
                if axis == "x":
                    self.block(parent, "PartitionTop", (c, 2.4, fixed), (w, h - 2.4, t), color, snow_mask=0.0, material=material)
                else:
                    self.block(parent, "PartitionTop", (fixed, 2.4, c), (t, h - 2.4, w), color, snow_mask=0.0, material=material)

    # --- Interactables --------------------------------------------------------------------------

    def area(self, parent, name, script, pos, props, shape=("box", (1.6, 2.0, 1.6)), yaw=0, groups=None):
        p = {"transform": Tr(*pos, yaw=yaw)}
        p.update(props)
        n = self.s.node(name, "Area3D", parent, p, script=script, groups=groups)
        if script in KIND_NAMES:
            self.counts[KIND_NAMES[script]] += 1
        if shape[0] == "box":
            sh = self.s.sub("BoxShape3D", {"size": V3(*shape[1])})
            self.s.node("Shape", "CollisionShape3D", n, {"transform": Tr(0, shape[1][1] / 2.0, 0), "shape": sh})
        else:
            sh = self.s.sub("SphereShape3D", {"radius": shape[1]})
            self.s.node("Shape", "CollisionShape3D", n, {"transform": Tr(0, 0.8, 0), "shape": sh})
        return n

    def loot(self, parent, name, pos, title, table="", items=None, shape=(1.6, 2.0, 1.6), yaw=0, **kw):
        p = {"display_name": title, "items": items or {}}
        if table:
            p["loot_table"] = table
        p.update(kw)
        return self.area(parent, name, S_LOOT, pos, p, shape=("box", shape), yaw=yaw)

    def exam(self, parent, name, pos, title, text, shape=(1.8, 2.0, 1.8), yaw=0, label=None, **kw):
        p = {"display_name": label or title, "title": title, "text": text}
        p.update(kw)
        return self.area(parent, name, S_EXAM, pos, p, shape=("box", shape), yaw=yaw)

    def hide(self, parent, name, pos, title, shape=(1.4, 2.0, 2.0), yaw=0):
        return self.area(parent, name, S_HIDE, pos, {"display_name": title}, shape=("box", shape), yaw=yaw)

    def pick(self, parent, name, pos, item, count=1, radius=0.8, **kw):
        p = {"item_id": item, "count": count}
        p.update(kw)
        return self.area(parent, name, S_PICK, pos, p, shape=("sphere", radius))

    def info(self, parent, name, pos, info_id, shape=(1.6, 2.0, 1.4), **kw):
        p = {"info_id": info_id}
        p.update(kw)
        return self.area(parent, name, S_INFO, pos, p, shape=("box", shape))

    def door(self, parent, name, pos, yaw=0, width=1.2, height=2.3, visual="leaf", color=(0.3, 0.23, 0.17),
             fade=None, groups=None, interact=None, blocker=None, visual_kw=None, **props):
        """A real Door (scripts/interaction/door.gd): interaction area + Blocker + Visual.
        visual: "leaf" (hinged door leaf), "rollup" (garage door, shrinks upward), "prop" (visual_kw
        gives a LowPolyProp: wardrobe, drift...), "hatch" (floor hatch plate)."""
        p = {"transform": Tr(*pos, yaw=yaw)}
        p.update(props)
        n = self.s.node(name, "Area3D", parent, p, script=S_DOOR, groups=groups)
        self.counts["door"] += 1
        ia = interact or (width + 0.8, 2.2, 2.6)
        self.s.node("Shape", "CollisionShape3D", n, {"transform": Tr(0, ia[1] / 2.0, 0), "shape": self.s.sub("BoxShape3D", {"size": V3(*ia)})})
        bs = blocker or (width, height, 0.3)
        body = self.s.node("Blocker", "StaticBody3D", n, {})
        self.s.node("Shape", "CollisionShape3D", body, {"transform": Tr(0, bs[1] / 2.0, 0), "shape": self.s.sub("BoxShape3D", {"size": V3(*bs)})})
        vk = dict(visual_kw or {})
        if visual == "leaf":
            vis = self.s.node("Visual", "Node3D", n, {"transform": Tr(-width / 2.0, 0, 0)})
            self.block(vis, "Leaf", (width / 2.0, 0, 0), (width, height, 0.08), color, material="door",
                       snow_mask=0.0, has_collision=False, fade=fade, cast_shadows=False)
            self.block(vis, "Handle", (width - 0.15, 1.0, 0.06), (0.1, 0.08, 0.06), (0.7, 0.62, 0.35), material="metal",
                       snow_mask=0.0, has_collision=False, fade=fade, cast_shadows=False)
        elif visual == "rollup":
            vis = self.s.node("Visual", "Node3D", n, {"transform": Tr(0, height, 0)})
            self.block(vis, "Shutter", (0, -height, 0), (width, height, 0.1), color, material="container",
                       snow_mask=0.3, has_collision=False, fade=fade)
            self.block(vis, "Handle", (0, -height + 0.35, 0.07), (0.4, 0.08, 0.06), (0.2, 0.2, 0.22), material="metal",
                       snow_mask=0.0, has_collision=False, fade=fade, cast_shadows=False)
        elif visual == "hatch":
            vis = self.s.node("Visual", "Node3D", n, {})
            self.block(vis, "Hatch", (0, 0, 0), (width, 0.06, height), color, material="metal", snow_mask=0.2,
                       has_collision=False, fadeable=False, cast_shadows=False)
        else:
            vis = self.s.node("Visual", "Node3D", n, {})
            kind = vk.pop("kind")
            self.prop(vis, kind, vk.pop("pos", (0, 0, 0)), yaw=vk.pop("yaw", 0), fade=fade, **vk)
        return n

    def marker(self, parent, name, pos, yaw=0):
        return self.s.node(name, "Marker3D", parent, {"transform": Tr(*pos, yaw=yaw)})

    def report(self, label):
        total = sum(self.counts.values())
        parts = ", ".join("%s %d" % (k, v) for k, v in sorted(self.counts.items()))
        print("%s: %d interactables (%s)" % (label, total, parts))
