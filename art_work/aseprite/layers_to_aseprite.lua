-- Build one layered Aseprite file from a folder of same-sized layer PNGs.
-- Run in batch mode:
--   aseprite -b --script-param dir=<folder> --script-param out=<file.aseprite>
--            --script-param layers=body,trousers,... --script layers_to_aseprite.lua

local dir = app.params["dir"]
local out = app.params["out"]
local list = app.params["layers"]
if not dir or not out or not list then
  print("usage: --script-param dir=... --script-param out=... --script-param layers=a,b,c")
  return
end

local function load_rgb(path)
  local source = Sprite{ fromFile = path }
  if source.colorMode ~= ColorMode.RGB then
    app.activeSprite = source
    app.command.ChangePixelFormat{ format = "rgb" }
  end
  local image = Image(source.width, source.height, ColorMode.RGB)
  image:drawSprite(source, 1)
  local w, h = source.width, source.height
  source:close()
  return image, w, h
end

local sprite = nil
local count = 0
for name in string.gmatch(list, "([^,]+)") do
  local image, w, h = load_rgb(dir .. "/" .. name .. ".png")
  local layer
  if sprite == nil then
    sprite = Sprite(w, h, ColorMode.RGB)
    layer = sprite.layers[1]
  else
    layer = sprite:newLayer()
  end
  layer.name = name
  sprite:newCel(layer, 1, image, Point(0, 0))
  count = count + 1
end

sprite:saveAs(out)
print("saved " .. out .. " with " .. count .. " layers, " .. sprite.width .. "x" .. sprite.height)
