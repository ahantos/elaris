"""Hand corrections to single baked variants, applied by tools/bake.py after the turn.

PATCHES = { "sprite@angle": [(x0, y0, [rows]), ...] }
Coordinates are those of the piece's own master canvas, as printed by
    python tools/bake.py --show sprite@angle
In a row, "." leaves a pixel alone, "_" erases it, any other character is a palette key.

What is here: the point of the sword. A machine turn leaves the last two rows of a
blade blunt or ragged (a flat end four pixels wide, or a lone pixel off the tip). Each
patch re-draws only those rows so the blade ends in a point; the body of the blade and
the crossguard are left as baked (the guard is re-drawn as a regular bar by the baker).
Angles not listed (0, 90, -27 and the ones no animation uses yet) needed nothing or
have not been looked at; say so before using a new one.
"""

PATCHES = {
    # tip up and right, 2:1. Was a two-pixel nub beside an empty corner.
    "broad_sword__weapon@27": [
        (15, 3, [".._4",
                 "_245"]),
    ],
    # tip up-right on the diagonal. Was a flat end four pixels wide.
    "broad_sword__weapon@45": [
        (21, 8, [".__54",
                 "_5412"]),
    ],
    # tip right and up, 1:2. Was a flat end six pixels wide.
    "broad_sword__weapon@63": [
        (24, 15, ["..___544",
                  "__54412"]),
    ],
    # tip right and down. Was a notch with a dark pixel inside the point.
    "broad_sword__weapon@117": [
        (27, 40, ["_2144",
                  ".._24"]),
    ],
    # tip left and up. Was a lone pixel off the end and a blunt four-row butt.
    "broad_sword__weapon@-63": [
        (-20, 16, ["445"]),
        (-20, 17, ["_2"]),
        (-19, 18, ["_"]),
        (-19, 19, ["_"]),
        (-18, 20, ["_"]),
    ],
}
