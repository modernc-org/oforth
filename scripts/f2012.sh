#!/bin/sh
# Copyright 2026 The oforth Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# f2012.sh runs the Forth-2012 test suite's tests of the CORE, CORE EXT, FILE,
# EXCEPTION, DOUBLE and STRING word sets (Gerry Jackson's suite, after John Hayes' tests) on the board:
# the REPL INCLUDEs the suite's files from build/f2012, which the loader
# serves by 9P, and the script prints what failed and the tester's count of
# errors, which must be 0. The suite is fetched at a pinned commit into
# build/f2012, checked by its hashes, and never committed: its files carry
# their own notices. It takes the board lock itself; the run takes about
# half a minute. With -sd, the FILE tests run on the SD card in the slot
# instead of in build/f2012, from a copy of filetest.fth whose three names
# are sd:'s, which the script prints (not both: REQUIRED would find the
# second run's files included by the first).
#
# Usage: scripts/f2012.sh [-sd] [PORT]

set -eu
sd=filetest.fth
if [ "${1:-}" = -sd ]; then
	sd=sdfiletest.fth
	shift
fi
port=${1:-/dev/ttyUSB0}
commit=4c87e5659c5b79bd7a6664daa56603df080c6f9b
dir=build/f2012
mkdir -p $dir
while read -r sum f; do
	[ -f $dir/$f ] || curl -sSf -o $dir/$f \
		"https://raw.githubusercontent.com/gerryjackson/forth2012-test-suite/$commit/src/$f"
	echo "$sum  $dir/$f" | sha256sum -c --quiet -
done <<'SUMS'
12a34cca4f6041b9c79bb4259e7a66af84bcbbfa2ad728a47bf050cd5396f6f7 tester.fr
9beba157c1929f2908199b2b13a5c2a349df2d3dcc79a293e13080efcc860f54 core.fr
d967d1d367b3c0bf91b13944694fb5ac26fa793a63be3ea58bf50779971ef47b coreplustest.fth
69b362b974f2ecebb0dbea1d77281dcca7b112107d7ad7b3e7f764a40c1c83a7 utilities.fth
f35b9a78ac463985e2cfa616f19893204e25f5a51f0512324d8d45fe9e73b71b coreexttest.fth
569584cc70dd5eeee74af1911df1697770417185f6c9f7494bbc06005c76fb2e filetest.fth
b09d273fb8a8afa1438c6f8bc0a43a66e02a171d6f9e0d413c8777c58e126ba3 required-helper1.fth
b09d273fb8a8afa1438c6f8bc0a43a66e02a171d6f9e0d413c8777c58e126ba3 required-helper2.fth
92bce976b74a799f0a7c9f4200e46832eea6371d117e522dea4550a6fe067083 exceptiontest.fth
28d769b65563b6df8085a1bc5c2a36e8cc2bfffe8d6040167079d7c0e1fc37ee doubletest.fth
6f78aafab33acf2c3e09ec428447d539e2f8afe71fa3ca2ed329b2999b129cde stringtest.fth
SUMS
if [ $sd != filetest.fth ]; then
	sed 's/S" \(fatest\|FATEST\)/S" sd:\1/' $dir/filetest.fth > $dir/$sd
	diff $dir/filetest.fth $dir/$sd | grep '^>' || true
fi
ogo build -o $dir/oforth.binary .
# Each file is INCLUDEd by a line of its own, so that an error stops only
# that file, core.fr's test of ACCEPT taking the line after its own; the
# lines are all sent at once, and the loader is left when the count of
# errors has come. filetest.fth writes its files into build/f2012 and
# deletes them.
rm -f $dir/raw.txt
flock -o -w 900 /tmp/p2-board.lock sh -c "
	for i in 1 2 3 4 5 6; do fuser -s $port || break; sleep 5; done
	fuser -s $port && { echo 'port busy'; exit 1; }
	(sleep 4
	printf 'INCLUDE tester.fr\\rINCLUDE core.fr\\rtyped for ACCEPT\\r'
	for f in coreplustest.fth utilities.fth coreexttest.fth $sd exceptiontest.fth doubletest.fth stringtest.fth; do printf 'INCLUDE %s\\r' \$f; done
	printf 'DECIMAL CR .( errors: ) #ERRORS @ .\\r'
	for i in \$(seq 240); do grep -q -a 'errors: [0-9]' $dir/raw.txt 2>/dev/null && break; sleep 0.5; done
	sleep 1; printf '\\035') |
		timeout 180 ogo loadp2 -t -NOEOF -9 $dir -p $port -b 230400 $dir/oforth.binary > $dir/raw.txt"
tr -d '\r' < $dir/raw.txt > $dir/out.txt
# CORE-EXT-ERRORS, FILE-ERRORS and the like are the suite's
# errorreport.fth's, which is not loaded.
grep -a 'errors:\|INCORRECT RESULT: T\|WRONG NUMBER OF RESULTS: T\| ?$\|error:\|: No such' $dir/out.txt |
	grep -a -v '[A-Z-]*-ERRORS ?$'
