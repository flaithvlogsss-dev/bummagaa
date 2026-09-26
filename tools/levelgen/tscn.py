"""Tiny .tscn writer used to lay out the LAST SNOW levels."""
import json, math


class V3:
    def __init__(self, x, y, z): self.v = (x, y, z)
    def __str__(self): return "Vector3(%s, %s, %s)" % tuple(num(a) for a in self.v)


class Col:
    def __init__(self, r, g, b, a=1.0): self.v = (r, g, b, a)
    def __str__(self): return "Color(%s, %s, %s, %s)" % tuple(num(a) for a in self.v)


class NP:
    def __init__(self, p): self.p = p
    def __str__(self): return 'NodePath("%s")' % self.p


class Raw:
    def __init__(self, s): self.s = s
    def __str__(self): return self.s


class Rect:
    def __init__(self, x, y, w, h): self.v = (x, y, w, h)
    def __str__(self): return "Rect2(%s, %s, %s, %s)" % tuple(num(a) for a in self.v)


class Tr:
    def __init__(self, x=0, y=0, z=0, yaw=0.0, pitch=0.0, scale=1.0):
        self.o = (x, y, z); self.yaw = yaw; self.pitch = pitch; self.scale = scale
    def __str__(self):
        cy, sy = math.cos(math.radians(self.yaw)), math.sin(math.radians(self.yaw))
        cp, sp = math.cos(math.radians(self.pitch)), math.sin(math.radians(self.pitch))
        ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
        rx = [[1, 0, 0], [0, cp, -sp], [0, sp, cp]]
        m = [[sum(ry[i][k] * rx[k][j] for k in range(3)) * self.scale for j in range(3)] for i in range(3)]
        vals = [m[i][j] for i in range(3) for j in range(3)] + list(self.o)
        return "Transform3D(%s)" % ", ".join(num(a) for a in vals)


def num(a):
    if isinstance(a, bool): return "true" if a else "false"
    a = round(float(a), 5)
    if a == int(a): return str(int(a))
    return repr(a)


def val(v):
    if isinstance(v, bool): return "true" if v else "false"
    if isinstance(v, (int, float)): return num(v)
    if isinstance(v, str): return json.dumps(v, ensure_ascii=False)
    if isinstance(v, list): return "[" + ", ".join(val(x) for x in v) + "]"
    if isinstance(v, dict): return "{" + ", ".join("%s: %s" % (json.dumps(k, ensure_ascii=False), val(x)) for k, x in v.items()) + "}"
    return str(v)


class Scene:
    def __init__(self, root_name, root_type, props=None, script=None):
        self.ext = {}
        self.subs = []
        self.nodes = []
        self.names = {}
        self.root = root_name
        p = {}
        if script:
            p["script"] = self.ext_res(script, "Script")
        p.update(props or {})
        self.nodes.append((root_name, root_type, None, p, None, None))

    def ext_res(self, path, typ):
        if path not in self.ext:
            self.ext[path] = (typ, "%d_%s" % (len(self.ext) + 1, typ.lower()[:5]))
        return Raw('ExtResource("%s")' % self.ext[path][1])

    def sub(self, typ, props):
        key = (typ, json.dumps({k: str(v) for k, v in props.items()}, sort_keys=True))
        for (t, sid, p, k) in self.subs:
            if k == key:
                return Raw('SubResource("%s")' % sid)
        sid = "%s_%d" % (typ, len(self.subs) + 1)
        self.subs.append((typ, sid, props, key))
        return Raw('SubResource("%s")' % sid)

    def node(self, name, typ, parent=".", props=None, script=None, groups=None, instance=None):
        base = name
        key = (parent, base)
        n = self.names.get(key, 0)
        self.names[key] = n + 1
        if n > 0:
            name = "%s%d" % (base, n + 1)
        p = {}
        if script:
            p["script"] = self.ext_res(script, "Script")
        p.update(props or {})
        self.nodes.append((name, typ, parent, p, groups, instance))
        return name if parent == "." else parent + "/" + name

    def dump(self):
        out = ["[gd_scene format=3]", ""]
        for path, (typ, eid) in self.ext.items():
            out.append('[ext_resource type="%s" path="%s" id="%s"]' % (typ, path, eid))
        out.append("")
        for typ, sid, props, _ in self.subs:
            out.append('[sub_resource type="%s" id="%s"]' % (typ, sid))
            for k, v in props.items():
                out.append("%s = %s" % (k, val(v)))
            out.append("")
        for name, typ, parent, props, groups, instance in self.nodes:
            head = '[node name="%s"' % name
            if typ:
                head += ' type="%s"' % typ
            if parent is not None:
                head += ' parent="%s"' % parent
            if groups:
                head += " groups=[%s]" % ", ".join(json.dumps(g) for g in groups)
            if instance:
                head += " instance=%s" % instance
            out.append(head + "]")
            for k, v in props.items():
                out.append("%s = %s" % (k, val(v)))
            out.append("")
        return "\n".join(out)
