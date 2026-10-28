#!/bin/sh
# Copyright 2026 The oforth Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# p2xc.sh builds P2XCForth for the P2-EDGE from its author's archive,
# P2XCForthD.zip of 2026-04-07 or P2XCForthC.zip of 2025-07-11 (Christof
# Eberspaecher, attached to his posts in the Parallax forum thread 176239;
# the project has no repository), into build/p2xc/p2xc.binary, for the
# benchmarks. Its sources are changed in these ways, which it prints, and in
# nothing else: the crystal is the EDGE's 20 MHz, not the Kiss board's 25
# MHz; the SD card is not mounted and its directory not listed, the card in
# the shared board being another project's, and so the start-up's "2 load"
# of a block from it is left out too (D's); and the Spin2 object's #define
# lines are applied by hand, which this flexcc's preprocessor does not do
# for an object the C uses. It compiles with the flexcc OctoGo embeds, built
# from ../ogo. The archive is not this repository's and is never committed.
#
# Usage: scripts/p2xc.sh P2XCForthD.zip

set -eu
zip=${1:?usage: scripts/p2xc.sh P2XCForthD.zip}
dir=build/p2xc
rm -rf $dir
mkdir -p $dir
case $(unzip -Z1 "$zip" | grep -i 'P2XF[CD]\.c$') in
*P2XFD.c) v=D ;;
*P2XFC.c) v=C ;;
*) echo "no P2XCForth sources in $zip"; exit 1 ;;
esac
unzip -p "$zip" P2XCForth$v/P2XF$v.c > $dir/orig.c
unzip -p "$zip" P2XCForth$v/P2XF$v.spin2 > $dir/orig.spin2
echo "P2XCForth$v"
python3 -I - $dir $v <<'PY'
import re, sys
d, v = sys.argv[1], sys.argv[2]
c = open(d + "/orig.c", encoding="latin-1").read().replace("\r\n", "\n")
for old, new in [
    ("enum { _xtlfreq = 25_000_000 } ;",
     "enum { _xtlfreq = 20_000_000 } ; /* P2-EDGE: 20 MHz (was 25 MHz, the Kiss board) */"),
    ('        R0=mount("/sd", _vfs_open_sdcard());\n        if (R0 == 0) {\n'
     '                printf("mounted SD card as /sd\\n");\n        }\n        do_dir("/sd");\n',
     "        /* The SD card is not mounted: the shared board's is another project's. */\n"),
]:
    assert c.count(old) == 1, old[:40]
    c = c.replace(old, new)
if c.count('        " 2 load \\n"\n') == 1:
    c = c.replace('        " 2 load \\n"\n', '        /* " 2 load \\n" left out: no SD card */\n')
open(d + "/P2XF" + v + ".c", "w", encoding="latin-1").write(c)
s = open(d + "/orig.spin2", encoding="latin-1").read().replace("\r\n", "\n")
defs, out = {}, []
for line in s.split("\n"):
    m = re.match(r"#define\s+(\w+)\s+(\w+)", line)
    if m:
        defs[m.group(1)] = m.group(2)
        line = "' (applied by hand) " + line
    out.append(line)
s = "\n".join(out)
for name, reg in defs.items():
    s = re.sub(r"(?<![\w@])" + name + r"(?!\w)", reg, s)
open(d + "/P2XF" + v + ".spin2", "w", encoding="latin-1").write(s)
print("defines applied by hand:", defs)
PY
tr -d '\r' < $dir/orig.c | diff - $dir/P2XF$v.c || true
[ -x build/flexcc ] || (cd ../ogo && go build -o "$OLDPWD/build/flexcc" ./scripts/flexcc)
(cd $dir && ../flexcc -2 -O1 -o p2xc.binary P2XF$v.c 2>&1 | grep -v warning || true)
ls -l $dir/p2xc.binary
