#!/bin/sh
# Copyright 2026 The oforth Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# cardcheck.sh checks the FAT32 volume on the SD card in the board's slot
# with fsck.fat, the board having no tool for it: scripts/carddump, loaded
# on the board, sends what of the card a check needs, the blocks of the
# volume's reserved area, its FATs and its directories that are not all
# zeros, and the script makes of them an image of the volume,
# build/card/card.img, sparse and holding no file's data. fsck.fat -n
# checks the image, writing nothing, and mtools' mdir lists it. Nothing is
# written to the card. Run it after any change of forth/fat.ogo; it takes
# the board lock itself, and a card of 4 GB about a minute. It exits with
# fsck.fat's status.
#
# Usage: scripts/cardcheck.sh [PORT]

set -eu
port=${1:-/dev/ttyUSB0}
dir=build/card
PATH=$PATH:/sbin:/usr/sbin
mkdir -p $dir
ogo build -o $dir/carddump.binary ./scripts/carddump
rm -f $dir/raw.txt
flock -o -w 900 /tmp/p2-board.lock sh -c "
	for i in 1 2 3 4 5 6; do fuser -s $port || break; sleep 5; done
	fuser -s $port && { echo 'port busy'; exit 1; }
	(for i in \$(seq 600); do grep -q -a '^END\|^ERR' $dir/raw.txt 2>/dev/null && break; sleep 1; done
	sleep 1; printf '\\035') |
		timeout 660 ogo loadp2 -t -NOEOF -p $port -b 230400 $dir/carddump.binary > $dir/raw.txt"
tr -d '\r' < $dir/raw.txt > $dir/dump.txt
python3 -I - $dir/dump.txt $dir/card.img <<'PY'
import sys
dump, img = sys.argv[1], sys.argv[2]
out, start, n = None, 0, 0
for line in open(dump, errors='replace'):
    w = line.split()
    if not w:
        continue
    if w[0] == 'ERR':
        sys.exit('carddump: ' + line.strip())
    if w[0] == 'VOL':
        start, size = int(w[1]), int(w[2])
        out = open(img, 'wb')
        out.truncate(size * 512)
    elif w[0] == 'B' and out:
        b, s, d = int(w[1]), int(w[2]), bytes.fromhex(w[3])
        if len(d) != 512 or sum(d) != s:
            sys.exit('block %d did not arrive whole' % b)
        out.seek((b - start) * 512)
        out.write(d)
        n += 1
    elif w[0] == 'END':
        if out is None or int(w[1]) != n:
            sys.exit('the dump is not whole: %d blocks of %s' % (n, w[1]))
        print('%d blocks of the volume from block %d' % (n, start))
        break
else:
    sys.exit('the dump has no end')
PY
rc=0
fsck.fat -n $dir/card.img || rc=$?
mdir -/ -a -i $dir/card.img :: || true
exit $rc
