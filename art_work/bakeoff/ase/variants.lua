-- Exports the looks of a1_doll.aseprite that the comparison sheet needs, without
-- changing the file: with the axe, with the sword, the axe layer alone, and the axe
-- figure in bronze. The bronze one is a palette swap done in the editor: the six
-- steel palette entries are set to the six bronze colours, nothing is redrawn.
local dir = app.params["dir"]
local PAL = dofile(dir .. "/ase/palette.lua")
local spr = app.open(dir .. "/a1_doll.aseprite")
local function show(hidden)
  for _, l in ipairs(spr.layers) do l.isVisible = not hidden[l.name] end
end
show({ weapon = true });      spr:saveCopyAs(dir .. "/ase/out/a1_axe.png")
show({ weapon_axe = true });  spr:saveCopyAs(dir .. "/ase/out/a1_sword.png")
show({ weapon = true, helmet = true, shield = true }); spr:saveCopyAs(dir .. "/ase/out/a1_axe_nohelm_noshield.png")
for _, l in ipairs(spr.layers) do l.isVisible = (l.name == "weapon_axe") end
spr:saveCopyAs(dir .. "/ase/out/weapon_axe.png")
show({ weapon = true })
local pal = spr.palettes[1]
local steel, bronze = { "0", "1", "2", "3", "4", "5" }, { "p", "q", "r", "s", "t", "v" }
for i = 1, 6 do pal:setColor(PAL.index[steel[i]], pal:getColor(PAL.index[bronze[i]])) end
spr:saveCopyAs(dir .. "/ase/out/a1_axe_bronze.png")
print("exported variants; layers:", #spr.layers)
