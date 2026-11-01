#!/bin/sh
# Copyright 2026 The oforth Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# size.sh measures what the benchmarks take of each system's memory once
# they are loaded, and the room they leave: bench/'s five, in each system's
# dialect, and the third parties' programs as scripts/third.sh gives them
# (third.sh -n writes them), after each system's prelude, which is not
# counted. Nothing is timed and the third parties' programs are not run, so
# what a program allots while it runs, as Stanford Trees does, is not in it.
#
# Each system is asked by its own words, three times: twice before the
# program, so that what the asking itself takes is known and taken off, and
# once after it.
#
#   - OctoForth: its code space, by the address of an empty word defined
#     there and then, which the space's first word, DUP, and its 32768 longs
#     (main.ogo) give the room after; its data space, by UNUSED. Its headers
#     are in tables of their own, outside both spaces, and not counted.
#   - P2XCForth: its one memory, code, headers and data, by here@, and the
#     room up to its own lastfree.
#   - TAQOZ Reloaded: its code, by HERE; its names, by @WORDS, which grow
#     down towards the code, the code's room being between the two; and its
#     data space, where the variables, the arrays and CREATE's and ALLOT's
#     data are, by the address of a long defined there and then, the room
#     being up to TAQOZ's buffers, BUFFERS. The data space is moved first,
#     above the image (bench/third/prelude-taqoz.fth, bench/taqoz.fth), and
#     asked after that.
#
# It prints a line for each program on each system, in bytes. It takes the
# board lock for each run; all of them take about five minutes.
#
# Usage: scripts/size.sh [PORT]

set -eu
port=${1:-/dev/ttyUSB0}
dir=build/size
rm -rf $dir
mkdir -p $dir/run $dir/log
scripts/third.sh -n >/dev/null
ogo build --no-inline -o build/oforth.binary .
taqoz=$(scripts/taqoz.sh)
python3 -I - $dir <<'PY'
import os, sys
d = sys.argv[1]
# Each system's way to say what it holds: the definition of a word that
# writes "@SZ@" and the numbers on the stack, and the lines that put them
# there, # being the probe's number, which makes its names its own.
probe = {
    "oforth": (": szz. CR 64 EMIT 83 EMIT 90 EMIT 64 EMIT"
               " SPACE . SPACE . SPACE . ;",
               [": zz# ; ' zz# UNUSED ' DUP szz."]),
    "p2xc": (": szz. cr 64 emit 83 emit 90 emit 64 emit"
             " 32 emit . 32 emit . ;",
             ["here@ lastfree @ szz."]),
    "taqoz": (": SZZ. CR 64 EMIT 83 EMIT 90 EMIT 64 EMIT"
              " SPACE . SPACE . SPACE . SPACE . ;",
              ["long zd#", "HERE @WORDS zd# BUFFERS SZZ."]),
}

def strip_timed(s):
    out, skip = [], False
    for l in s.split("\n"):
        if skip:
            skip = False
            continue
        if l.startswith("\\ @TIME "):
            skip = True
            continue
        out.append(l)
    return "\n".join(out)

def write(system, prog, pre, body):
    define, lines = probe[system]
    ask = lambda n: "\n".join(l.replace("#", str(n)) for l in lines)
    # The first line is a comment: a system still starting may lose it.
    text = "\n".join(["\\ scripts/size.sh", pre, define, ask(0), ask(1),
                      body, ask(2), ""])
    path = "%s/run/%s-%s.fth" % (d, system, prog)
    open(path, "w", encoding="latin-1").write(text)

def read(path):
    return open(path, encoding="latin-1").read()

for system in ("oforth", "p2xc", "taqoz"):
    pre = ""
    if system == "p2xc":
        if not os.path.exists("build/p2xc/author.fth"):
            continue
        pre = read("build/p2xc/author.fth")
    body = read("bench/%s.fth" % system)
    if system == "taqoz":
        # bench/taqoz.fth moves the data space first, which goes before
        # the asking, as the prelude does for the third parties' programs.
        org = "$20000 org\n"
        assert body.count(org) == 1
        pre, body = org.strip(), body.replace(org, "")
    write(system, "bench", pre, body)
    for prog in ("sieve", "bubble", "matrix", "fib", "stan"):
        # The programs that run there, as scripts/third.sh says.
        if (system, prog) in (("p2xc", "sieve"), ("p2xc", "stan"),
                              ("taqoz", "stan")):
            continue
        path = "build/third/run/%s-%s.fth" % (system, prog)
        if not os.path.exists(path):
            continue
        s = read(path)
        pre = read("bench/third/prelude-%s.fth" % system)
        if system == "p2xc":
            pre = read("build/p2xc/author.fth") + pre
        assert s.startswith(pre + "\n"), path
        write(system, prog, pre, strip_timed(s[len(pre) + 1:]))
PY
wait_port="for i in 1 2 3 4 5 6; do fuser -s $port || break; sleep 5; done; fuser -s $port && { echo 'port busy'; exit 1; }"
for f in $dir/run/*.fth; do
	run=$(basename $f .fth)
	system=${run%%-*}
	case $system in
	oforth) bin=build/oforth.binary ;;
	p2xc) bin=build/p2xc/p2xc.binary ;;
	taqoz) bin=$taqoz ;;
	esac
	flock -o -w 900 /tmp/p2-board.lock sh -c "$wait_port
		timeout 900 python3 -I scripts/session.py -log $dir/log/$run.txt $port $system $bin $f"
done
python3 -I - $dir <<'PY'
import glob, os, re, sys
d = sys.argv[1]
for log in sorted(glob.glob(d + "/log/*.txt")):
    run = os.path.basename(log)[:-4]
    system, prog = run.split("-", 1)
    s = open(log, "rb").read().decode("latin-1")
    n = {"oforth": 3, "p2xc": 2, "taqoz": 4}[system]
    got = [[int(x) for x in m.groups()]
           for m in re.finditer(r"@SZ@" + r"\s+(-?\d+)" * n, s)]
    if len(got) != 3:
        print("%s %s: %d answers of 3, see %s" % (system, prog, len(got), log))
        continue
    a, b, c = got
    if system == "oforth":
        # DUP's address, UNUSED, the new word's address
        over_c, over_d = b[2] - a[2], a[1] - b[1]
        print("%-6s %-6s code %6d data %6d  room: code %6d data %6d" % (
            system, prog, c[2] - b[2] - over_c, b[1] - c[1] - over_d,
            c[0] + 32768 * 4 - c[2], c[1]))
    elif system == "p2xc":
        # lastfree, here@
        print("%-6s %-6s all %6d  room %6d" % (
            system, prog, c[1] - b[1] - (b[1] - a[1]), c[0] - c[1]))
    else:
        # BUFFERS, the long's address, @WORDS, HERE
        over_c, over_n, over_d = b[3] - a[3], a[2] - b[2], b[1] - a[1]
        print("%-6s %-6s code %6d names %6d data %6d  room: code %6d data %6d" % (
            system, prog, c[3] - b[3] - over_c, b[2] - c[2] - over_n,
            c[1] - b[1] - over_d, c[2] - c[3], c[0] - c[1] - 4))
    if prog == "bench":
        if system == "oforth":
            print("%-13s room at start: code %6d data %6d" % (
                system, a[0] + 32768 * 4 - a[2], a[1]))
        elif system == "p2xc":
            print("%-13s room at start, after author.fth: %6d" % (
                system, a[0] - a[1]))
        else:
            print("%-13s room at start: code %6d data %6d" % (
                system, a[2] - a[3], a[0] - a[1] - 4))
PY
