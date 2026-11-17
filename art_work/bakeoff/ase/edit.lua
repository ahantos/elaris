-- Applies a list of pixel edits to one layer of an .aseprite file, saves the file, and
-- exports pictures to look at. This is the "draw in the editor's own file" loop.
-- usage: Aseprite -b --script-param dir=<work folder> --script-param file=a1_doll.aseprite
--          --script-param layer=weapon_axe --script-param edits=ase/axe_p1.txt
--          --script-param hide=weapon --script-param tag=p1 --script ase/edit.lua
-- Edit file, one command per line (figure coordinates, palette keys as in a1.px.js):
--   row Y X CHARS     draw a run; "." leaves a pixel, "_" erases it
--   px X Y KEY        one pixel
--   clear             empty the layer
local dir = app.params["dir"]
local PAL = dofile(dir .. "/ase/palette.lua")
local spr = app.open(dir .. "/" .. app.params["file"])
assert(spr, "cannot open file")
local name = app.params["layer"]
local layer
for _, l in ipairs(spr.layers) do if l.name == name then layer = l end end
if not layer then
  layer = spr:newLayer()            -- new layers go on top, above "weapon"
  layer.name = name
end
local cel = layer:cel(1)
local img = cel and cel.image:clone() or Image(spr.width, spr.height, ColorMode.INDEXED)
local ox, oy = 0, 0
if cel then ox, oy = cel.position.x, cel.position.y end
if cel and (img.width ~= spr.width or img.height ~= spr.height or ox ~= 0 or oy ~= 0) then
  local full = Image(spr.width, spr.height, ColorMode.INDEXED)
  full:drawImage(img, Point(ox, oy))
  img, ox, oy = full, 0, 0
end
local function put(x, y, k)
  if k == "." then return end
  local idx = (k == "_") and 0 or PAL.index[k]
  assert(idx, "unknown palette key '" .. k .. "'")
  assert(x >= 0 and y >= 0 and x < spr.width and y < spr.height, "pixel outside the canvas: " .. x .. "," .. y)
  img:drawPixel(x, y, idx)
end
local n = 0
for line in io.lines(dir .. "/" .. app.params["edits"]) do
  local cmd, rest = line:match("^%s*(%a+)%s*(.*)$")
  if cmd == "row" then
    local y, x, chars = rest:match("^(%-?%d+)%s+(%-?%d+)%s+(%S+)")
    for i = 1, #chars do put(tonumber(x) + i - 1, tonumber(y), chars:sub(i, i)) end
    n = n + 1
  elseif cmd == "px" then
    local x, y, k = rest:match("^(%-?%d+)%s+(%-?%d+)%s+(%S)")
    put(tonumber(x), tonumber(y), k)
    n = n + 1
  elseif cmd == "clear" then
    img:clear()
    n = n + 1
  end
end
if cel then cel.image = img; cel.position = Point(0, 0) else spr:newCel(layer, 1, img, Point(0, 0)) end
spr:saveAs(dir .. "/" .. app.params["file"])

-- exports: the figure with some layers hidden, and the edited layer alone
local tag = app.params["tag"] or "edit"
local hide = {}
for h in (app.params["hide"] or ""):gmatch("[^,]+") do hide[h] = true end
local was = {}
for _, l in ipairs(spr.layers) do was[l] = l.isVisible; l.isVisible = not hide[l.name] end
spr:saveCopyAs(dir .. "/ase/out/" .. tag .. "_figure.png")
for _, l in ipairs(spr.layers) do l.isVisible = (l == layer) end
spr:saveCopyAs(dir .. "/ase/out/" .. tag .. "_layer.png")
for _, l in ipairs(spr.layers) do l.isVisible = was[l] end
print("applied", n, "commands to layer", name, "; layers now", #spr.layers)
