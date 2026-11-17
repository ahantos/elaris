-- A1's palette, in the order used for the indexed .aseprite files.
-- Index 0 is transparent. Keys are the same letters as in a1.px.js.
local P = {
  { "K", 0x17, 0x12, 0x1c },                                        -- shared near-black
  { "a", 0x5f, 0x2f, 0x33 }, { "b", 0x8c, 0x55, 0x40 }, { "c", 0xb5, 0x7a, 0x55 }, { "d", 0xdb, 0xa8, 0x78 },   -- skin
  { "h", 0x2b, 0x21, 0x26 }, { "H", 0x55, 0x40, 0x3a },             -- hair
  { "f", 0x40, 0x36, 0x3a }, { "F", 0x6a, 0x5c, 0x4c }, { "u", 0x92, 0x83, 0x69 }, { "U", 0xb9, 0xaa, 0x88 },   -- fur
  { "l", 0x38, 0x21, 0x1f }, { "L", 0x59, 0x36, 0x2a }, { "m", 0x7e, 0x4c, 0x36 }, { "M", 0xa0, 0x70, 0x48 },   -- leather
  { "W", 0x7a, 0x5c, 0x3a }, { "y", 0x9f, 0x80, 0x52 },             -- wood (its dark is leather L)
  { "0", 0x0f, 0x1a, 0x28 }, { "1", 0x20, 0x2e, 0x37 }, { "2", 0x3d, 0x4f, 0x56 },
  { "3", 0x81, 0x97, 0x96 }, { "4", 0xc7, 0xcf, 0xcc }, { "5", 0xf1, 0xf2, 0xec },                              -- steel
  { "p", 0x24, 0x14, 0x1c }, { "q", 0x4c, 0x2a, 0x26 }, { "r", 0x77, 0x45, 0x28 },
  { "s", 0xa0, 0x6c, 0x34 }, { "t", 0xc9, 0x98, 0x4f }, { "v", 0xec, 0xd6, 0xa2 },                              -- bronze, and spark colours
}
local M = { list = P, index = {}, rgb = {} }
for i, e in ipairs(P) do
  M.index[e[1]] = i
  M.rgb[(e[2] << 16) | (e[3] << 8) | e[4]] = i
end
M.index["w"] = M.index["L"]          -- shield wood's darkest tone is the same colour as leather L
function M.make()
  local pal = Palette(#P + 1)
  pal:setColor(0, Color{ r = 0, g = 0, b = 0, a = 0 })
  for i, e in ipairs(P) do pal:setColor(i, Color{ r = e[2], g = e[3], b = e[4], a = 255 }) end
  return pal
end
-- a picture file (any PNG colour mode) as an indexed image in this palette.
-- The file is opened as a sprite and turned to RGB first: Image{ fromFile } hands back
-- palette indices for an indexed PNG, and an opened sprite's cel is trimmed and offset.
function M.load(path, w, h)
  local s = app.open(path)
  assert(s, "cannot read " .. path)
  app.sprite = s
  if s.colorMode ~= ColorMode.RGB then app.command.ChangePixelFormat{ format = "rgb" } end
  local out = Image(w or s.width, h or s.height, ColorMode.INDEXED)
  local pc = app.pixelColor
  for _, cel in ipairs(s.cels) do
    if cel.frameNumber == 1 then
      local ox, oy = cel.position.x, cel.position.y
      for it in cel.image:pixels() do
        local v = it()
        if pc.rgbaA(v) > 0 then
          local key = (pc.rgbaR(v) << 16) | (pc.rgbaG(v) << 8) | pc.rgbaB(v)
          local idx = M.rgb[key]
          assert(idx, string.format("%s: colour #%06x at %d,%d is not in the palette", path, key, it.x + ox, it.y + oy))
          out:drawPixel(it.x + ox, it.y + oy, idx)
        end
      end
    end
  end
  s:close()
  return out
end
return M
