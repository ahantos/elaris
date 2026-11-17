"""Write the proof animations as data: anims/idle.json, idle2.json, walk.json, walk2.json, swing.json.

usage: python tools/make_anims.py

This is the hand-written source of the animations: every number below was chosen by
eye from frame sheets, onion skins and the checks of tools/preview.py. The JSON it
writes is all the game reads. It also writes poses.json (stills for final_rig.png),
fx.json and fx_gen.px.js (the sword's smear, an arc fitted to the path the tip really takes).
A frame with a joint outside its range (rig.json) is refused here, before it is written.
"""
import json
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from riglib import Rig, ROOT  # noqa: E402
from author import P, clean, feet, plant, REST_SOLE  # noqa: E402

rig = Rig()


def frame(ms, pose, fx=None):
    faults = rig.limit_faults(pose)
    if faults:
        raise ValueError("joint out of range: " + ", ".join(
            "%s bent %+.0f (range %d..%d)" % (n, d, r[0], r[1]) for n, d, r in faults))
    f = {"ms": ms, "pieces": clean(pose)}
    if fx:
        f["fx"] = fx
    return f


def save(name, anim):
    os.makedirs(os.path.join(ROOT, "anims"), exist_ok=True)
    anim = dict({"format": "elaris-anim/1", "name": name}, **anim)
    text = json.dumps(anim, indent=1)
    # one piece per line reads better than one number per line
    text = re.sub(r"\{\s+([^{}]*?)\s+\}", lambda m: "{ " + re.sub(r"\s+", " ", m.group(1)) + " }", text)
    path = os.path.join(ROOT, "anims", name + ".json")
    with open(path, "w", encoding="utf-8", newline=chr(10)) as fh:
        fh.write(text + chr(10))
    print("wrote anims/%s.json  frames %d  total %d ms" % (name, len(anim["frames"]), sum(f["ms"] for f in anim["frames"])))


def lag(seq, i):
    """one pixel of follow-through: where a part that rides a tick late sits, relative to
    what carries it, given the carrier's offsets over the loop"""
    return max(-1, min(1, seq[(i - 1) % len(seq)] - seq[i]))


# ====================================================================== IDLE
# Breathing, four frames. The chest, shoulders, head and mantle rise one pixel and
# sink again; the hands do not, so the sword and the shield stand still (the elbows
# take up the pixel). The head goes up a tick after the chest and comes down a tick
# after it; the hem of the cloak trails the mantle the same way.
def idle():
    def breath(torso, head, hem):
        return P(torso=(0, torso), head=(0, head),
                 near_forearm=(0, -torso), far_forearm=(0, -torso),
                 cloak_lower=(0, hem))
    frames = [
        frame(520, breath(0, 0, 0)),
        frame(180, breath(-1, 1, 1)),        # chest up; head and hem not yet
        frame(520, breath(-1, 0, 0)),
        frame(180, breath(0, -1, -1)),       # chest down; head and hem still up
    ]
    return {"loop": True, "canvas": {"w": 48, "h": 56, "origin": [8, 6]},
            "planted": {"near": [[0, 1, 2, 3]], "far": [[0, 1, 2, 3]]}, "frames": frames}


# ====================================================================== IDLE 2
# The same breath, with the lower body in it. A wave runs down the figure: the chest
# rises, a tick later the hips settle a pixel (the knees take it up, the feet stay),
# a tick after that the kilt follows; then the chest sinks, the hips come back up,
# the kilt last. Two long holds (the rest pose, and breathed-in-and-settled) with two
# short frames between them each way. Hands, sword and shield do not move.
def idle2():
    #        ms  hips  chest  head  hem  kilt      (chest is relative to the hips; head, hem, kilt are the lags)
    steps = [(430, 0, 0, 0, 0, 0),
             (130, 0, -1, 1, 1, 0),        # chest up; head and hem not yet
             (130, 1, -2, 0, 0, -1),       # hips settle; the kilt has not followed
             (430, 1, -2, 0, 0, 0),
             (130, 1, -1, -1, -1, 0),      # chest down; head and hem still up
             (130, 0, 0, 0, 0, 1)]         # hips up; the kilt still down
    frames = []
    for ms, hips, chest, head, hem, kilt in steps:
        top = hips + chest                 # where the shoulders are, on screen
        pose = P(hips=(0, hips), torso=(0, chest), head=(0, head), cloak_lower=(0, hem), skirt=(0, kilt),
                 near_forearm=(0, -top), far_forearm=(0, -top))
        feet(rig, pose, near_thigh=0, near_shin=0, far_thigh=0, far_shin=0)
        frames.append(frame(ms, pose))
    return {"loop": True, "canvas": {"w": 48, "h": 56, "origin": [8, 6]},
            "planted": {"near": [[0, 1, 2, 3, 4, 5]], "far": [[0, 1, 2, 3, 4, 5]]}, "frames": frames}


# ====================================================================== WALK (first version)
# One full cycle, six frames, in place. The figure covers 32 px (one tile) per cycle;
# "travel" is how far the game moves it during each frame, so a planted foot stays on
# its spot of floor: contact, down, passing for the far leg, then the same for the near.
def walk():
    travel = [5, 6, 5, 5, 6, 5]
    STEP = 8                      # a foot lands this far ahead of where it stands at rest
    LIFT = 3
    # sole x of the supporting foot over its four frames on the ground
    ground = [STEP, STEP - 5, STEP - 11, STEP - 16]          # +8, +3, -3, -8
    bob = [1, 2, 0, 1, 2, 0]      # hips: contact, down (lowest), passing (highest)
    frames = []
    for i in range(6):
        half = i // 3             # 0: far leg leads, 1: near leg leads
        k = i % 3
        lead, trail = ("far", "near") if half == 0 else ("near", "far")
        pos = {}
        pos[lead] = (ground[k], 0)
        # the trailing foot: still down at contact, then lifted and brought through
        pos[trail] = [(ground[3], 0), (-5, -LIFT), (1, -LIFT)][k]
        pose = P(hips=(0, bob[i]), torso=(1, 0))
        hints = {}
        if k == 0:        # contact: front leg reaching, back leg pushing off on its toes
            hints = {lead + "_thigh": -27, lead + "_shin": [-27, 0],
                     trail + "_thigh": 27, trail + "_shin": [27, 45]}
        elif k == 1:      # down: weight onto the front leg, back foot lifted behind
            hints = {lead + "_thigh": [-27, 0], lead + "_shin": [0, 27],
                     trail + "_thigh": [-27, 0, 27], trail + "_shin": [27, 45, 63]}
        else:             # passing: standing leg straight, free leg coming through knee first
            hints = {lead + "_thigh": [0, 27], lead + "_shin": [0, 27],
                     trail + "_thigh": [-27, -45], trail + "_shin": [0, 27, 45]}
        # in this three-quarter view the far hip is drawn 7 px ahead of the near one, so the two
        # contacts would look very unlike (feet 25 px apart, then 9 px and crossed). Walking
        # brings the feet in under the body: each track is moved 1 px toward the other.
        pos["near"] = (pos["near"][0] + 1, pos["near"][1])
        pos["far"] = (pos["far"][0] - 1, pos["far"][1])
        feet(rig, pose, near=pos["near"], far=pos["far"], **hints)
        # the near arm swings against the near leg. The elbow only folds forward, so going
        # forward the forearm leads (upper arm down, forearm ahead); going back the upper arm leads.
        upper = [0, 0, 0, 27, 0, 0][i]
        fore = [-27, 0, 0, 0, 0, 0][i]
        nudge = [0, 1, -1, 0, -1, 1][i]
        pose.update(P(near_upper_arm=(upper, nudge, 0), near_forearm=fore))
        pose.update(P(far_upper_arm=([1, 0, 0, -1, 0, 0][i], 0)))
        # the head rides a tick behind the bob, which steadies it
        pose.update(P(head=(0, lag(bob, i))))
        pose.update(P(cloak_lower=([-1, -1, 0, -1, -1, 0][i], lag(bob, i))))
        frames.append(frame(100, pose))
    planted = {"far": [[0, 1, 2, 3]], "near": [[3, 4, 5, 0]]}
    return {"loop": True, "canvas": {"w": 64, "h": 56, "origin": [16, 6]}, "travel": travel,
            "planted": planted, "frames": frames}


# ====================================================================== WALK 2
# Heavier and quieter: eight frames of 90 ms (contact, down, passing, up for each leg),
# the same 32 px per cycle, so the travel is an even 4 px every frame.
# A foot is on the ground for five frames (+8, +4, 0, -4, -8 from under its hip) and in
# the air for three. Everything else is cut to one pixel: the body drops 1, the sword
# arm goes 1 px each way, head, hem and kilt follow a frame late by 1.
# The legs walk under the middle of the body (each hip joint is slid 4 px inward, under
# the kilt), so the two contacts look alike and the legs pass in front of each other
# instead of crossing.
def walk2():
    N = 8
    travel = [4] * N
    ground = [8, 4, 0, -4, -8]
    air = [(-5, -2), (0, -3), (5, -1)]
    bob = [1, 1, 0, 0, 1, 1, 0, 0]
    IN = {"near": 4, "far": -4}
    hints = [
        dict(thigh=-27, shin=[-27, -14]),             # 0 contact: reaching, heel first
        dict(thigh=[-27, -14], shin=[-14, 0]),        # 1 down: the knee gives
        dict(thigh=[-14, 0], shin=[0, 14]),           # 2 passing: under the body
        dict(thigh=[0, 14], shin=[14, 27]),           # 3 up: body carried over it
        dict(thigh=[14, 27], shin=[27, 45]),          # 4 behind, heel off (the other foot lands)
        dict(thigh=[-14, 0, 14], shin=[27, 45]),      # 5 lifted behind
        dict(thigh=[-27, -14], shin=[14, 27, 45]),    # 6 coming through, knee first
        dict(thigh=[-27, -45], shin=[-27, -14, 0]),   # 7 reaching
    ]
    frames = []
    for i in range(N):
        pose = P(hips=(0, bob[i]))
        for leg, phase in (("far", i), ("near", (i + 4) % N)):
            x, lift = (ground[phase], 0) if phase <= 4 else air[phase - 5]
            target = (REST_SOLE[leg][0] + IN[leg] + x, REST_SOLE[leg][1] + lift)
            plant(rig, pose, leg, target, hip=(IN[leg], 0), **hints[phase])
        # near arm: one pixel forward while the near leg is behind, one back while it leads
        pose.update(P(near_upper_arm=([1, 1, 0, 0, -1, -1, 0, 0][i], 0)))
        pose.update(P(far_upper_arm=([-1, 0, 0, 0, 1, 0, 0, 0][i], 0)))
        pose.update(P(head=(0, lag(bob, i)), cloak_lower=(0, lag(bob, i))))
        # the kilt gives a pixel forward a frame after the near thigh has swung forward under it,
        # and rides a frame behind the bob
        pose.update(P(skirt=([0, 0, 0, 0, 1, 1, 1, 0][i], lag(bob, i))))
        frames.append(frame(90, pose))
    planted = {"far": [[0, 1, 2, 3, 4]], "near": [[4, 5, 6, 7, 0]]}
    return {"loop": True, "canvas": {"w": 64, "h": 56, "origin": [16, 6]}, "travel": travel,
            "planted": planted, "frames": frames}


# ====================================================================== SWING
def swing():
    fr = []

    def add(ms, pose, near=(0, 0), far=(0, 0), fx=None, **hints):
        feet(rig, pose, near=near, far=far, **hints)
        fr.append(frame(ms, pose, fx))

    # 0 ready
    add(100, P())
    # 1 weight starts back, knees give; the elbow folds and brings the hilt up to the shoulder
    add(100, P(hips=(-1, 1), torso=(-1, 0), head=(1, 0), near_upper_arm=(0, -1, 0), near_forearm=-135, weapon=-27,
               far_upper_arm=(1, 0), cloak_lower=(1, 0)))
    # 2 wound up, held: weight on the back foot, torso turned back, arm overhead with the elbow
    #   folded, the blade hanging back behind the head
    add(170, P(hips=(-2, 1), torso=(-1, 0), head=(1, 0), near_upper_arm=(180, -1, 0), near_forearm=135, weapon=-63,
               far_upper_arm=(-27, 0, 0), cloak_lower=(0, 0)))
    # 3 the cut, one frame: the front foot leaves the ground, the arm drives forward, the blade
    #   has come over the top (the smear covers the way it came)
    add(50, P(hips=(1, 0), torso=(1, 0), near_upper_arm=(-90, 0, 0), near_forearm=-117, weapon=45,
              cloak_lower=(-1, 0)), far=(3, -2))
    # 4 impact, held: front foot down a step ahead, arm straight out
    add(130, P(hips=(4, 1), torso=(2, 0), head=(0, 0), near_upper_arm=(-63, 0, 0), near_forearm=-90, weapon=90,
               cloak_lower=(-2, 0)), far=(6, 0))
    # 5 follow-through: the blade drops past the line, the body sinks a pixel
    add(90, P(hips=(4, 2), torso=(2, 0), head=(0, 1), near_upper_arm=(-45, 0, 0), near_forearm=-63, weapon=117,
              cloak_lower=(0, 0)), far=(6, 0))
    # 6-8 recovery, the slow part: the arm is drawn back first with the blade still low and
    #   forward, the front foot comes home, and only then the blade is stood up again
    add(110, P(hips=(3, 1), torso=(1, 0), near_upper_arm=(-27, 0, 0), near_forearm=-45, weapon=90,
               cloak_lower=(1, 0)), far=(6, 0))
    add(120, P(hips=(2, 0), torso=(1, 0), near_upper_arm=(0, 0, 0), near_forearm=-27, weapon=63,
               cloak_lower=(1, 0)), far=(3, -1))
    add(110, P(hips=(1, 0), torso=(0, 0), near_upper_arm=(0, 0, 0), near_forearm=0, weapon=27,
               cloak_lower=(1, 0)))

    # effect layers. The smear trails the point of the blade into the cut frame: an arc about
    # the shoulder, ending just behind where the point is in frame 3.
    s2, s3, s4 = rig.solve(fr[2]["pieces"]), rig.solve(fr[3]["pieces"]), rig.solve(fr[4]["pieces"])
    t2, t3 = rig.anchor(s2, "weapon", "tip"), rig.anchor(s3, "weapon", "tip")
    cx, cy = s3["near_upper_arm"][0], s3["near_upper_arm"][1]

    def bearing(p):                                   # clockwise from straight up, in degrees
        return math.degrees(math.atan2(p[0] + 0.5 - cx, -(p[1] + 0.5 - cy)))
    R = math.hypot(t3[0] + 0.5 - cx, t3[1] + 0.5 - cy)
    a1 = bearing(t3) - 4
    a0 = max(bearing(t2), a1 - 50)
    smear = {"R": round(R, 1), "a0": round(a0, 1), "a1": round(a1, 1)}
    fr[3]["fx"] = [{"name": "smear", "x": cx, "y": cy, "z": 79, "needs": "weapon"}]
    # the hit: where the blade meets whoever stands in the next tile, two thirds along it
    h4, tip4 = rig.anchor(s4, "near_forearm", "hand"), rig.anchor(s4, "weapon", "tip")
    hx, hy = round(h4[0] + (tip4[0] - h4[0]) * 0.72), round(h4[1] + (tip4[1] - h4[1]) * 0.72)
    fr[4]["fx"] = [{"name": "hit_0", "x": hx, "y": hy}]
    fr[5]["fx"] = [{"name": "hit_1", "x": hx + 1, "y": hy}]
    fr[6]["fx"] = [{"name": "hit_2", "x": hx + 1, "y": hy + 1}]
    planted = {"near": [[0, 1, 2, 3, 4, 5, 6, 7, 8]], "far": [[0, 1, 2], [4, 5, 6], [8, 0]]}
    return {"loop": True, "canvas": {"w": 112, "h": 84, "origin": [34, 32]}, "planted": planted,
            "frames": fr}, smear


SMEAR_JS = """// GENERATED by tools/make_anims.py from the swing's own numbers. Do not edit by hand.
// The sword's smear: a thin arc about the shoulder, behind the point of the blade.
// Brightest and two pixels thick next to the blade, thinning and darkening to the tail.
pal({ 2: "#3d4f56", 3: "#819796", 4: "#c7cfcc", 5: "#f1f2ec" })

const R = %(R)s, A0 = %(a0)s, A1 = %(a1)s, C = %(C)d
sprite("fx__smear", { w: 2 * C, h: 2 * C }, (c) => {
  for (let y = 0; y < c.h; y++)
    for (let x = 0; x < c.w; x++) {
      const dx = x + 0.5 - C, dy = y + 0.5 - C, r = Math.hypot(dx, dy)
      const a = Math.atan2(dx, -dy) * 180 / Math.PI      // clockwise from straight up
      if (a < A0 || a > A1) continue
      const t = (A1 - a) / (A1 - A0)                     // 0 at the blade, 1 at the tail
      const w = 2.2 * (1 - t) + 0.9
      if (r > R + 0.5 || r < R + 0.5 - w) continue
      c.px(x, y, t < 0.3 ? "4" : t < 0.65 ? "3" : "2")
    }
})
"""


def write_fx(smear):
    C = int(smear["R"]) + 4
    with open(os.path.join(ROOT, "fx_gen.px.js"), "w", encoding="utf-8", newline=chr(10)) as fh:
        fh.write(SMEAR_JS % dict(smear, C=C))
    fx = {
        "_comment": "Effect pictures (built by pxl from fx.px.js and fx_gen.px.js). 'origin' is the pixel of the "
                    "picture that is put on the x, y an animation frame gives. Written by tools/make_anims.py.",
        "fx": {
            "hit_0": {"sprite": "fx__hit_0", "origin": [5, 5]},
            "hit_1": {"sprite": "fx__hit_1", "origin": [7, 6]},
            "hit_2": {"sprite": "fx__hit_2", "origin": [7, 7]},
            "smear": {"sprite": "fx__smear", "origin": [C, C]},
        },
    }
    with open(os.path.join(ROOT, "fx.json"), "w", encoding="utf-8", newline=chr(10)) as fh:
        fh.write(json.dumps(fx, indent=1) + chr(10))


def main():
    sw, smear = swing()
    write_fx(smear)
    anims = {"idle": idle(), "idle2": idle2(), "walk": walk(), "walk2": walk2(), "swing": sw}
    for name, a in anims.items():
        save(name, a)
    # stills for final_rig.png. Two come from the animations; the raised arm is a test pose
    # at the far end of the shoulder's range, with the elbow folded.
    raised = P(hips=(-1, 1), torso=(-1, 0), head=(1, 0), near_upper_arm=180, near_forearm=135, weapon=-63)
    feet(rig, raised)
    frame(0, raised)
    poses = {"rest": {}, "arm_raised": clean(raised), "step_forward": anims["walk"]["frames"][0]["pieces"],
             "strike": anims["swing"]["frames"][4]["pieces"]}
    with open(os.path.join(ROOT, "poses.json"), "w", encoding="utf-8", newline=chr(10)) as fh:
        fh.write(json.dumps(poses, indent=1) + chr(10))


if __name__ == "__main__":
    main()
