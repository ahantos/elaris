import sys; sys.path.insert(0, sys.argv[2])
from patchlib import *
p = sys.argv[1]; s = load(p)
s = block(s, "CLOAK", '''
  9:  [[3, "KKK.KKK"]],
  10: [[2, "KFuuKFuuK"], [23, "KKK"]],
  11: [[1, "KFFFuFFFFuFK"], [22, "KFuuK"]],
  12: [[1, "KFFFFFfFFFFf"], [22, "KFFuFK"]],
  13: [[1, "KFuFFffFFFFf"], [22, "KfFFFK"]],
  14: [[1, "KFuFffffffff"]],
  15: [[1, "KFFFffffffff"]],
  16: [[1, "KFFfffffffff"]],
  17: [[1, "KuFfffffffff"]],
  18: [[1, "KuFfffffffff"]],
  19: [[1, "KFFfffffffff"]],
  20: [[1, "KFFfffffffff"]],
  21: [[1, "KFFfffffffff"]],
  22: [[1, "KFuFffffffff"]],
  23: [[1, "KFuFffffffff"]],
  24: [[0, "KFFFFffffffff"]],
  25: [[0, "KFFFFfffffff"]],
  26: [[0, "KuFFFFffffff"]],
  27: [[0, "KuFFFFFffff"]],
  28: [[0, "KFFFuFFfff"]],
  29: [[0, "KFFFuFFfff"]],
  30: [[0, "KFuFFFFfff"]],
  31: [[0, "KFuFFFffff"]],
  32: [[0, "KFFFFFfFff"]],
  33: [[0, "KFFFuFfFff"]],
  34: [[0, "KKFFuKKfFKK"]],
  35: [[2, "KKK..KK"]],
''')
s = block(s, "NEAR_ARM", '''
  12: [[5, "KKKKK"]],
  13: [[4, "KcdddcK"]],
  14: [[4, "KbcddcK"]],
  15: [[4, "KbcddcK"]],
  16: [[4, "KbcddcK"]],
  17: [[4, "KbccdcK"]],
  18: [[4, "KabccbK"]],
  19: [[4, "KabcdcK"]],
  20: [[4, "KabcdcK"]],
  21: [[4, "KabccbK"], [13, "KKKK"]],
  22: [[4, "KabccaKKKcddcK"]],
  23: [[4, "KabacdddccdccK"]],
  24: [[4, "KaabccccbcccbK"]],
  25: [[4, "KKabbbbbabbbaK"]],
  26: [[6, "KKKKKKKKKKKK"]],
''')
s = block(s, "ARM_GEAR", '''
  18: [[4, "KyYYYyK"]],
  19: [[4, "KyyYyyK"]],
  23: [[10, "mmL"]],
  24: [[10, "mLL"]],
  25: [[10, "LLl"]],
''')
s = block(s, "TORSO_GEAR", '''
  14: [[20, "lLm"]],
  15: [[19, "lLm"]],
  16: [[18, "lYY"]],
  17: [[17, "lLyy"]],
  18: [[16, "lLm"]],
  19: [[15, "lLm"]],
  20: [[14, "lLm"]],
  21: [[13, "lLm"]],
  22: [[12, "lLm"]],
  23: [[11, "lLm"]],
  24: [[11, "lLm"]],
  25: [[11, "lLm"]],
  26: [[11, "lLm"]],
''')
s = block(s, "HELMET", '''
  0:  [[16, "KKKK"]],
  1:  [[15, "K3454K"]],
  2:  [[14, "K234543K"]],
  3:  [[13, "K12345443K"]],
  4:  [[13, "K11234443K"]],
  5:  [[13, "K11223443K"]],
  6:  [[12, "K2334455443K"]],
  7:  [[12, "KKKKKKKKKKKK"]],
  8:  [[21, "4K"]],
  9:  [[21, "3K"]],
  10: [[21, "K"]],
''')
s = setrow(s, "WEAPON", 0, '[[4, "KK"]]')
s = setrow(s, "WEAPON", 1, '[[3, "K45K"]]')
s = rep(s, 'r: "#4f181c", R: "#7e282a", e: "#a63f33"', 'r: "#48181b", R: "#742628", e: "#9a3a30"')
s = rep(s, 'f: "#3b3431", F: "#62574c", u: "#8f8370"', 'f: "#3f3733", F: "#6b5f52", u: "#978a75"')
save(p, s)
