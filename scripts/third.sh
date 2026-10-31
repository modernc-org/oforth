#!/bin/sh
# Copyright 2026 The oforth Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# third.sh runs third parties' Forth benchmarks on the board, on OctoForth,
# on P2XCForth if scripts/p2xc.sh has built it, and on TAQOZ Reloaded, the
# image scripts/taqoz.sh fetches, each at 200 MHz, timed by this host
# between two marks the system writes around the work (scripts/session.py),
# in milliseconds:
#
#   - Anton Ertl's four, the ones his "Performance of Forth systems" and
#     Gforth's manual compare systems with: the sieve, bubble sort, matrix
#     multiplication and fib (www.complang.tuwien.ac.at/forth/bench.tar.gz);
#   - the Stanford integer benchmarks John Hennessy gathered, in Martin
#     Fraeman's Forth of 1989, stan.fr, the plain translation of three, each
#     run ten times by its own TIME (www.complang.tuwien.ac.at/forth/
#     stanford-benchmarks.tar.gz).
#
# The archives are fetched into build/third at the hashes below and never
# committed: they state no licence, and Fraeman's file is JHU/APL's. The
# programs are run as they are but for the changes this script prints:
# matrix multiplication's matrices are 64 by 64, not 200 by 200, which
# would take 480 KB of the hub's 512; Fraeman's Swap, a word of his
# Permutation benchmark, is pswap, since a Forth that ignores case takes the
# stack's swap for it elsewhere in the file; and for P2XCForth the files are
# in lower case, which is all it knows, with spaces for TABs, which it does
# not take for spaces, and with a name longer than its 19 characters cut to
# them; for TAQOZ, which takes a name in another case for the same only when
# its own is upper case, the files are in upper case. Each system first loads
# its prelude, bench/third/prelude-SYSTEM.fth, the words the programs need
# that it lacks, which are published there to be judged.
#
# Usage: scripts/third.sh [-n] [-p PROGRAMS] [-s SYSTEMS] [PORT]
#
# PROGRAMS and SYSTEMS are lists in quotes, of sieve bubble matrix fib stan
# and of oforth p2xc taqoz; all of them by default. With -n it only writes
# the programs as each system is given them, build/third/run/SYSTEM-PROG.fth,
# which scripts/size.sh takes.

set -eu
progs="sieve bubble matrix fib stan"
systems="oforth p2xc taqoz"
prepare=
while [ $# -gt 0 ]; do
	case $1 in
	-n) prepare=1; shift ;;
	-p) progs=$2; shift 2 ;;
	-s) systems=$2; shift 2 ;;
	*) break ;;
	esac
done
port=${1:-/dev/ttyUSB0}
dir=build/third
mkdir -p $dir/log
fetch() {
	[ -f $dir/$3 ] || curl -sSf -o $dir/$3 "$1"
	echo "$2  $dir/$3" | sha256sum -c --quiet -
}
fetch https://www.complang.tuwien.ac.at/forth/bench.tar.gz \
	330319fae62600237f7e9647611db74b9f81d7d5a41ec7d727cc8c47242a1b82 bench.tar.gz
fetch https://www.complang.tuwien.ac.at/forth/stanford-benchmarks.tar.gz \
	35df7b168935ffe0e96faf19c4f5996f9b4007eb02981cd67877896f99a104fa stanford.tar.gz
rm -rf $dir/src $dir/run
mkdir -p $dir/src $dir/run
tar -xzf $dir/bench.tar.gz -C $dir/src
tar -xzf $dir/stanford.tar.gz -C $dir/src
python3 -I - $dir <<'PY'
import re, sys
d = sys.argv[1]
progs = {
    "sieve": d + "/src/bench/forth/sieve.fs",
    "bubble": d + "/src/bench/forth/bubble-sort.fs",
    "matrix": d + "/src/bench/forth/matrix-mult.fs",
    "fib": d + "/src/bench/forth/fib.fs",
    "stan": d + "/src/stanford/stan.fr",
}
stan = ["Perm", "Towers", "Queens", "Intmm", "Puzzle", "Quick", "Bubble", "Trees"]
for name, path in progs.items():
    s = open(path, encoding="latin-1").read()
    t = s
    if name == "matrix":
        t = t.replace("200 constant row-size", "64 constant row-size")
    if name == "stan":
        t = re.sub(r"(?<!\S)Swap(?!\S)", "pswap", t)
    if t != s:
        print("changed in %s:" % path.split("/src/")[1])
        for a, b in zip(s.split("\n"), t.split("\n")):
            if a != b:
                print("  - " + a.strip() + "\n  + " + b.strip())
    for system in ("oforth", "p2xc", "taqoz"):
        try:
            pre = open("bench/third/prelude-%s.fth" % system, encoding="latin-1").read()
            if system == "p2xc":
                pre = open("build/p2xc/author.fth", encoding="latin-1").read() + pre
        except FileNotFoundError:
            continue
        case = {"p2xc": str.lower, "taqoz": str.upper}.get(system, lambda x: x)
        if name == "stan":
            timed = "".join("\\ @TIME %s\n%s\n" % (b, case("123 EMIT ' %s TIME 125 EMIT" % b)) for b in stan)
        else:
            timed = "\\ @TIME %s\n%s\n" % (name, case("123 EMIT main 125 EMIT"))
        body = case(t) + "\n" + timed
        if system == "p2xc":
            body = body.replace("\t", " ")
            long = sorted(set(w for w in re.findall(r"(?:^|\s):\s+(\S+)", body) if len(w) > 19))
            for w in long:
                body = re.sub(r"(?<!\S)" + re.escape(w) + r"(?!\S)", w[:19], body)
            if long:
                print("for p2xc, in %s: %s shortened to 19 characters" % (name, ", ".join(long)))
        open("%s/run/%s-%s.fth" % (d, system, name), "w", encoding="latin-1").write(pre + "\n" + body)
PY
[ -z "$prepare" ] || exit 0
ogo build --no-inline --clock 200MHz -o $dir/oforth.binary .
wait_port="for i in 1 2 3 4 5 6; do fuser -s $port || break; sleep 5; done; fuser -s $port && { echo 'port busy'; exit 1; }"
for prog in $progs; do
	for system in $systems; do
		f=$dir/run/$system-$prog.fth
		[ -f $f ] || continue
		case $system-$prog in
		p2xc-sieve)
			echo "p2xc sieve not run: its +LOOP ends at equality, and the sieve's steps past the limit"
			continue ;;
		p2xc-stan)
			echo "p2xc stan not run: it lacks DOES>, which Fraeman's structures are made of, and the file does not load"
			continue ;;
		taqoz-stan)
			echo "taqoz stan not run: its arrays take about 69 KB before Trees allocates, and TAQOZ has 62 KB of room"
			continue ;;
		esac
		case $system in
		oforth) bin=$dir/oforth.binary ;;
		p2xc) bin=build/p2xc/p2xc.binary; [ -f $bin ] || continue ;;
		taqoz) bin=$(scripts/taqoz.sh) ;;
		esac
		flock -o -w 900 /tmp/p2-board.lock sh -c "$wait_port
			timeout 1500 python3 -I scripts/session.py -log $dir/log/$system-$prog.txt $port $system $bin $f" |
			sed "s/^TIME /$system /"
	done
done
