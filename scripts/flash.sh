#!/bin/sh
# Copyright 2026 The oforth Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# flash.sh writes OctoForth into the board's SPI flash, so that the board
# boots it after a reset or a power-up that no loader answers, the
# P2-EDGE's FLASH switch on. The program is boot/, the REPL that first
# interprets flash:boot.fth if the flash has it. ogo loadp2 -FLASH writes
# its image behind a boot loader of its own that copies it into hub RAM at
# every boot, erasing no more of the flash than it writes, so that the
# flash's files, from 1 MB on (forth/flash.ogo), stay. The loader's helper
# sits at hub $7C000 while it writes, so the image must end below that,
# 507904 bytes. The loader's terminal stays open until the written
# OctoForth's banner comes, since closing the port resets the board, which
# a write in progress does not survive (the first try, 2026-10-30, left 15
# KB of the image). Then scripts/boot.py resets the board and checks that
# OctoForth answers. The REPL is then any terminal's at 230400 baud. It
# takes the board lock itself.
#
# Usage: scripts/flash.sh [PORT]

set -eu
port=${1:-/dev/ttyUSB0}
dir=build/flash
mkdir -p $dir
ogo build --no-inline -o $dir/oforth.binary ./boot
size=$(wc -c < $dir/oforth.binary)
if [ $size -ge 507904 ]; then
	echo "$dir/oforth.binary is $size bytes; the flash takes images under 507904"
	exit 1
fi
out=$dir/flash.txt
: > $out
flock -o -w 900 /tmp/p2-board.lock sh -c "
	for i in 1 2 3 4 5 6; do fuser -s $port || break; sleep 5; done
	fuser -s $port && { echo 'port busy'; exit 1; }
	(for i in \$(seq 60); do sleep 1; grep -aq OctoForth $out && break; done; printf '\035') |
		timeout 90 ogo loadp2 -FLASH -t -NOEOF -p $port -b 230400 $dir/oforth.binary > $out 2>&1
	grep -aq OctoForth $out || { echo 'no banner after the write:'; cat $out; exit 1; }
	python3 -I scripts/boot.py $port '1 2 + .'" | tr -d '\r'
