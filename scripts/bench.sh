#!/bin/sh
# Copyright 2026 The oforth Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# bench.sh runs the benchmarks of bench/ on the board, in clocks: OctoForth's,
# TAQOZ Reloaded's, the one in the board's flash (V2.14.0 of 2024-02-19,
# talked to by scripts/taqoz.py), and P2XCForth's if scripts/p2xc.sh has
# built it. Each is a line of results:
# the empty loop, the calls, the sieve, fib and the factorials. It takes the
# board lock for each system; the three take about two minutes.
#
# Usage: scripts/bench.sh [PORT]

set -eu
port=${1:-/dev/ttyUSB0}
mkdir -p build
ogo build -o build/oforth.binary .
wait_port="for i in 1 2 3 4 5 6; do fuser -s $port || break; sleep 5; done; fuser -s $port && { echo 'port busy'; exit 1; }"
printf 'OctoForth   '
flock -o -w 900 /tmp/p2-board.lock sh -c "$wait_port
	(sleep 4; while IFS= read -r l; do printf '%s\r' \"\$l\"; sleep 0.2; done < bench/oforth.fth; sleep 4; printf '\035') |
		timeout 60 ogo loadp2 -t -NOEOF -p $port -b 230400 build/oforth.binary" |
	tr -d '\r' | sed -n 's/^\(empty\|call\|sieve\|fib\|fact\) \([0-9]*\) .*/\2/p' | tr '\n' ' '
echo
printf 'TAQOZ       '
flock -o -w 900 /tmp/p2-board.lock sh -c "$wait_port
	timeout 300 python3 -I scripts/taqoz.py $port bench/taqoz.fth" |
	tr -d '\r' | sed -n 's/^TAQOZ# [a-z]* \. --- \([0-9]*\)  *ok.*/\1/p' | tr '\n' ' '
echo
if [ -f build/p2xc/p2xc.binary ]; then
	printf 'P2XCForth   '
	flock -o -w 900 /tmp/p2-board.lock sh -c "$wait_port
		(sleep 5; while IFS= read -r l; do printf '%s\r\n' \"\$l\"; sleep 1; done < bench/p2xc.fth; sleep 3; printf '\035') |
			timeout 90 ogo loadp2 -b 230400 -t -NOEOF -p $port build/p2xc/p2xc.binary" |
		tr -d '\r' | sed -n 's/^ [a-z]*  \.  \([0-9]*\)$/\1/p' | tr '\n' ' '
	echo
fi
