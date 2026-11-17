"""Rebuild everything the game reads, in order, and run the checks.

usage: python tools/build.py [--finals]

  1. pxl builds the masters        rig.px.js, fx.px.js          -> out/sprites
  2. bake                           masters -> rig.json, atlas.png
  3. make_anims                     -> anims/*.json, poses.json, fx.json, fx_gen.px.js
  4. pxl builds the generated smear fx_gen.px.js                 -> out/sprites
  5. bake again (the smear goes into the atlas)
  6. rest pose against A1, joint limits, the checks of every animation
  --finals also rewrites final_rig.png and every final_<animation>.png with its GIFs.

pxl is expected beside the game's repository (../../../pxl from here), or at $PXL.
"""
import glob
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
PXL = os.environ.get("PXL") or os.path.normpath(os.path.join(ROOT, "..", "..", "..", "pxl", "bin", "pxl.js"))


def run(*cmd, quiet=True):
    r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    out = (r.stdout + r.stderr).strip()
    if r.returncode != 0 or not quiet:
        print(out)
    if r.returncode != 0:
        sys.exit("failed: " + " ".join(cmd))
    return out


def pxl(name):
    out = run("node", PXL, "build", name, "--no-preview")
    bad = [l for l in out.split("\n") if "error" in l.lower()]
    if bad:
        print("\n".join(bad))
        sys.exit("pxl reported errors in " + name)


def main():
    py = sys.executable
    pxl("rig.px.js")
    pxl("fx.px.js")
    run(py, "tools/bake.py")
    print(run(py, "tools/make_anims.py"))
    pxl("fx_gen.px.js")
    print(run(py, "tools/bake.py"))
    print("\n".join(l for l in run(py, "tools/rest_check.py").split("\n") if "differing" in l))
    print(run(py, "tools/check_limits.py").split("\n")[-1])
    for path in sorted(glob.glob(os.path.join(ROOT, "anims", "*.json"))):
        name = os.path.splitext(os.path.basename(path))[0]
        run(py, "tools/preview.py", "anims/%s.json" % name, "--quiet")
        txt = open(os.path.join(ROOT, "preview", "%s_full_steel_checks.txt" % name), encoding="utf-8").read()
        print("%-6s %s" % (name, txt[txt.index("RESULT"):].strip().replace("\n", "\n       ")))
    if "--finals" in sys.argv:
        print(run(py, "tools/final_rig.py"))
        names = [os.path.splitext(os.path.basename(p))[0] for p in sorted(glob.glob(os.path.join(ROOT, "anims", "*.json")))]
        print(run(py, "tools/final_anim.py", *names))


if __name__ == "__main__":
    main()
