-- Builds a1_swing.aseprite: the C swing as an Aseprite animation. 80 x 74, indexed in
-- A1's palette, 8 frames with their own durations, one tag "swing", and every piece of
-- gear on its own layer so it can be hidden or swapped. Sections are moved by giving
-- each frame's cel a position; only the arm, its gear, the sword and the effects
-- change picture between frames.
-- usage: Aseprite -b --script-param dir=<work folder> --script ase/build_swing.lua
local dir = app.params["dir"]
local PAL = dofile(dir .. "/ase/palette.lua")
local CW, CH, OX, OY = 80, 74, 14, 26        -- canvas, and where the 32 x 48 figure stands
local PX, PY, UP = 14, 8, 20                 -- origin of figure coordinates inside the part pictures
local WAIST = 24                             -- figure row where the upper body is cut from the hips

local function crop(img, x, y, w, h)
  local out = Image(w, h, ColorMode.INDEXED)
  out:drawImage(img, Point(-x, -y))
  return out
end
-- picture and offset with the empty border removed
local function trim(img)
  local r = img:shrinkBounds()
  if r.isEmpty then return nil end
  return crop(img, r.x, r.y, r.width, r.height), r.x, r.y
end
local function a1(n) return PAL.load(dir .. "/out/sprites/a1/" .. n .. ".png", 32, 48) end
local function part(n) return PAL.load(dir .. "/out/sprites/swing_" .. n .. ".png") end

local body = a1("body")
local pic = {
  cloak = a1("cloak"), legs = a1("legs"), boots = a1("boots"), torso_gear = a1("torso_gear"),
  helmet = a1("helmet"), shield = a1("shield"), near_arm = a1("near_arm"), arm_gear = a1("arm_gear"),
  weapon = a1("weapon"),
  body_torso = crop(body, 0, 0, 32, WAIST),
  body_legs = crop(body, 0, WAIST, 32, 48 - WAIST),
  sword_back = part("sword_back"), arm_fwd = part("arm_fwd"), bracer_fwd = part("bracer_fwd"),
  sword_fwd = part("sword_fwd"), smear = part("smear"),
  hit = { [0] = part("hit_0"), part("hit_1"), part("hit_2") },
}
pic.pauldron = crop(pic.arm_gear, 0, 0, 32, 18)     -- the fur on the shoulder, which does not swing

-- the same table of moves as c_swing.px.js
local F = {
  { ms = 167, lean = 0,  sink = 0, cloak = 0,  arm = "idle",   dx = 0,  dy = 0 },
  { ms = 83,  lean = -1, sink = 0, cloak = 0,  arm = "windup", dx = -1, dy = -1 },
  { ms = 167, lean = -1, sink = 0, cloak = -1, arm = "windup", dx = -2, dy = -3 },
  { ms = 83,  lean = 1,  sink = 0, cloak = -1, arm = "strike", dx = 0,  dy = 0, smear = true },
  { ms = 83,  lean = 2,  sink = 1, cloak = 1,  arm = "strike", dx = 1,  dy = 1, hit = 0, hx = -5, hy = -5 },
  { ms = 167, lean = 2,  sink = 1, cloak = 2,  arm = "strike", dx = 1,  dy = 2, hit = 1, hx = -7, hy = -6 },
  { ms = 167, lean = 1,  sink = 0, cloak = 2,  arm = "strike", dx = 0,  dy = 1, hit = 2, hx = -7, hy = -6 },
  { ms = 83,  lean = 0,  sink = 0, cloak = 1,  arm = "idle",   dx = 1,  dy = -1 },
}
local HITX, HITY = OX + 54, OY + 31

local spr = Sprite(CW, CH, ColorMode.INDEXED)
spr:setPalette(PAL.make())
spr.transparentColor = 0
local NAMES = { "cloak", "body_legs", "body_torso", "legs", "boots", "torso_gear", "helmet", "shield",
  "fx_smear", "near_arm", "arm_gear", "weapon", "fx_hit" }
local L = {}
for i, n in ipairs(NAMES) do
  local layer = (i == 1) and spr.layers[1] or spr:newLayer()
  layer.name = n
  L[n] = layer
end
for i = 2, #F do spr:newEmptyFrame() end

-- put a picture on a layer at a canvas position, trimmed so the cel is only as big as its pixels
local function cel(layer, frame, img, x, y)
  local t, tx, ty = trim(img)
  if t then spr:newCel(L[layer], frame, t, Point(x + tx, y + ty)) end
end

for i, f in ipairs(F) do
  spr.frames[i].duration = f.ms / 1000
  local ux, uy = OX + f.lean, OY + f.sink
  cel("cloak", i, pic.cloak, OX + f.cloak, OY)
  cel("body_legs", i, pic.body_legs, OX, OY + WAIST)
  cel("body_torso", i, pic.body_torso, ux, uy)
  cel("legs", i, pic.legs, OX, OY)
  cel("boots", i, pic.boots, OX, OY)
  cel("torso_gear", i, pic.torso_gear, ux, uy)
  cel("helmet", i, pic.helmet, ux, uy)
  cel("shield", i, pic.shield, ux, uy)
  local ax, ay = ux + f.dx, uy + f.dy
  if f.arm == "idle" then
    cel("near_arm", i, pic.near_arm, ax, ay)
    cel("arm_gear", i, pic.arm_gear, ax, ay)
    cel("weapon", i, pic.weapon, ax, ay)
  elseif f.arm == "windup" then
    cel("near_arm", i, pic.near_arm, ax, ay)
    cel("arm_gear", i, pic.arm_gear, ax, ay)
    cel("weapon", i, pic.sword_back, ax - PX, ay - PY)
  else
    cel("near_arm", i, pic.arm_fwd, ax - PX, ay - PY)
    local gear = Image(CW, CH, ColorMode.INDEXED)          -- fur at the shoulder plus the bracer on the forearm
    gear:drawImage(pic.pauldron, Point(ux, uy))
    gear:drawImage(pic.bracer_fwd, Point(ax - PX, ay - PY))
    cel("arm_gear", i, gear, 0, 0)
    cel("weapon", i, pic.sword_fwd, ax - PX, ay - PY)
  end
  if f.smear then cel("fx_smear", i, pic.smear, OX + 1 - PX, OY - PY - UP) end
  if f.hit then cel("fx_hit", i, pic.hit[f.hit], HITX + f.hx, HITY + f.hy) end
end

local tag = spr:newTag(1, #F)
tag.name = "swing"
spr:saveAs(dir .. "/a1_swing.aseprite")
print("frames", #spr.frames, "layers", #spr.layers, "cels", #spr.cels, "tags", #spr.tags)
