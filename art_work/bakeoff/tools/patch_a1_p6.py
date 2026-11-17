import sys; sys.path.insert(0, sys.argv[2])
from patchlib import *
p = sys.argv[1]; s = load(p)
s = setrow(s, "CLOAK", 27, '[[3, "FFFFFffffffffff"]]')
s = setrow(s, "CLOAK", 28, '[[3, "FFFFffffffffff"]]')
s = setrow(s, "WEAPON", 31, '[[5, "44"]]')
s = setrow(s, "WEAPON", 25, '[[1, "34444454"]]')
s = setrow(s, "WEAPON", 19, '[[3, "214"]]')      # a nick in the working edge
s = setrow(s, "WEAPON", 18, '[[3, "2145"]]')
s = setrow(s, "BODY", 5, '[[13, "KhhhHdd"]]')
s = setrow(s, "NEAR_ARM", 25, '[[5, "Kbbcc"]]')
s = setrow(s, "LEGS", 24, '[[11, "KlmMMM44mLl"]]')
save(p, s)
