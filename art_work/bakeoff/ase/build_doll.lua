-- Builds a1_doll.aseprite: A1's ten layers, back to front, indexed in A1's palette.
-- usage: Aseprite -b --script-param dir=<work folder> [--script-param out=<file>] --script ase/build_doll.lua
local dir = app.params["dir"]
local PAL = dofile(dir .. "/ase/palette.lua")
local ORDER = { "cloak", "body", "legs", "boots", "torso_gear", "helmet", "shield", "near_arm", "arm_gear", "weapon" }
local spr = Sprite(32, 48, ColorMode.INDEXED)
spr:setPalette(PAL.make())
spr.transparentColor = 0
for i, name in ipairs(ORDER) do
  local layer = (i == 1) and spr.layers[1] or spr:newLayer()
  layer.name = name
  local img = PAL.load(dir .. "/out/sprites/a1/" .. name .. ".png", 32, 48)
  spr:newCel(layer, 1, img, Point(0, 0))
end
-- "out" names the file to write (default a1_doll.aseprite). Rebuilding gives the ten A1
-- layers only: the axe layer comes back by replaying ase/axe_p1.txt to axe_p7.txt with
-- ase/edit.lua, in order.
local out = app.params["out"] or "a1_doll.aseprite"
spr:saveAs(dir .. "/" .. out)
spr:saveCopyAs(dir .. "/ase/out/doll_check.png")
print("layers", #spr.layers, "saved", out)
