#!/bin/sh
# Copyright 2026 The oforth Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# f2012.sh runs the Forth-2012 test suite's tests of the CORE and CORE EXT
# word sets (Gerry Jackson's suite, after John Hayes' tests) on the board:
# the REPL INCLUDEs the suite's files from build/f2012, which the loader
# serves by 9P, and the script prints what failed and the tester's count of
# errors, which must be 0. The suite is fetched at a pinned commit into
# build/f2012, checked by its hashes, and never committed: its files carry
# their own notices. It takes the board lock itself; the run takes about
# half a minute.
#
# Usage: scripts/f2012.sh [PORT]

set -eu
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
SUMS
ogo build -o $dir/oforth.binary .
# Each file is INCLUDEd by a line of its own, so that an error stops only
# that file, core.fr's test of ACCEPT taking the line after its own; the
# lines are all sent at once, and the loader is left when the count of
# errors has come.
rm -f $dir/raw.txt
flock -o -w 900 /tmp/p2-board.lock sh -c "
	for i in 1 2 3 4 5 6; do fuser -s $port || break; sleep 5; done
	fuser -s $port && { echo 'port busy'; exit 1; }
	(sleep 4
	printf 'INCLUDE tester.fr\\rINCLUDE core.fr\\rtyped for ACCEPT\\r'
	for f in coreplustest.fth utilities.fth coreexttest.fth; do printf 'INCLUDE %s\\r' \$f; done
	printf 'DECIMAL CR .( errors: ) #ERRORS @ .\\r'
	for i in \$(seq 240); do grep -q -a 'errors: [0-9]' $dir/raw.txt 2>/dev/null && break; sleep 0.5; done
	sleep 1; printf '\\035') |
		timeout 180 ogo loadp2 -t -NOEOF -9 $dir -p $port -b 230400 $dir/oforth.binary > $dir/raw.txt"
tr -d '\r' < $dir/raw.txt > $dir/out.txt
# CORE-EXT-ERRORS is the suite's errorreport.fth's, which is not loaded.
grep -a 'errors:\|INCORRECT RESULT: T\|WRONG NUMBER OF RESULTS: T\| ?$\|error:\|: No such' $dir/out.txt |
	grep -a -v 'CORE-EXT-ERRORS ?$'
