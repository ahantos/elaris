"""Helpers for writing poses and animations by hand (used by make_anims.py).

The game never runs this: it only reads the JSON these helpers produce.

A pose is {piece: {"a": angle, "dx": .., "dy": ..}}; anything left out stays at rest.
`plant` is the one piece of arithmetic: it puts a foot's sole point on a wanted pixel
by choosing the thigh and shin angles from the pre-drawn set and taking up what is
left with whole-pixel offsets at the hip and the knee (the joints overlap, so one
pixel of offset opens nothing).
"""
import itertools

REST_SOLE = {"near": (12, 47), "far": (21, 46)}


def P(**kw):
    """P(hips=(dx, dy), torso=(dx, dy), near_upper_arm=(angle, dx, dy), weapon=45 ...)
    A number is an angle; a 2-tuple is an offset; a 3-tuple is angle, dx, dy."""
    pose = {}
    for name, v in kw.items():
        if isinstance(v, dict):
            pose[name] = dict(v)
        elif isinstance(v, (int, float)):
            pose[name] = {"a": int(v)}
        elif len(v) == 2:
            pose[name] = {"dx": v[0], "dy": v[1]}
        else:
            pose[name] = {"a": v[0], "dx": v[1], "dy": v[2]}
    return pose


def clean(pose):
    """drop zero offsets and empty entries so the JSON stays short"""
    out = {}
    for name, q in pose.items():
        q = {k: v for k, v in q.items() if not (k in ("dx", "dy") and v == 0)}
        if q:
            out[name] = q
    return out


def plant(rig, pose, leg, target, thigh=None, shin=None, max_off=1, hip=(0, 0)):
    """Put the sole of `leg` ("near"/"far") on `target` (figure x, y).
    thigh / shin: an angle, or a list of angles to choose from (default: all).
    hip: an offset the thigh starts with (the hip joints are hidden under the hips and kilt).
    Returns the offsets left over as (hip, knee) for the record."""
    tname, sname = leg + "_thigh", leg + "_shin"
    tp, sp = rig.pieces[tname], rig.pieces[sname]

    def options(v, piece):
        if v is None:
            return piece["angles"]
        return [v] if isinstance(v, int) else list(v)

    best = None
    for ta, sa in itertools.product(options(thigh, tp), options(shin, sp)):
        trial = dict(pose)
        trial[tname] = {"a": ta, "dx": hip[0], "dy": hip[1]}
        trial[sname] = {"a": sa}
        if any(n in (tname, sname) for n, _, _ in rig.limit_faults(trial)):
            continue                      # hip or knee outside its range (a knee only folds back)
        sole = rig.anchor(rig.solve(trial), sname, "sole")
        ex, ey = target[0] - sole[0], target[1] - sole[1]
        cost = (max(abs(ex), abs(ey)), abs(ex) + abs(ey), abs(ta) + abs(sa))
        if best is None or cost < best[0]:
            best = (cost, ta, sa, ex, ey)
    cost, ta, sa, ex, ey = best
    if max(abs(ex), abs(ey)) > 2 * max_off:
        raise ValueError("%s foot cannot reach %s: best is thigh %d, shin %d, still %d,%d px off"
                         % (leg, target, ta, sa, ex, ey))

    def split(e):
        # the knee takes the first pixel, the hip the second
        k = max(-max_off, min(max_off, e))
        return e - k, k

    hx, kx = split(ex)
    hy, ky = split(ey)
    pose[tname] = {"a": ta, "dx": hip[0] + hx, "dy": hip[1] + hy}
    pose[sname] = {"a": sa, "dx": kx, "dy": ky}
    return (hx, hy), (kx, ky)


def feet(rig, pose, near=(0, 0), far=(0, 0), **kw):
    """plant both feet at offsets from where they stand in the rest pose"""
    for leg, off in (("near", near), ("far", far)):
        if off is None:
            continue
        opts = {k[len(leg) + 1:]: v for k, v in kw.items() if k.startswith(leg + "_")}
        t = (REST_SOLE[leg][0] + off[0], REST_SOLE[leg][1] + off[1])
        plant(rig, pose, leg, t, **opts)
    return pose
