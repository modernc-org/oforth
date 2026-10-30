#!/usr/bin/env python3
# Copyright 2026 The oforth Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

"""taqoz.py talks to TAQOZ Reloaded on a P2 board: it loads TAQOZ's image
into hub RAM by ogo loadp2 at 921600 baud, TAQOZ's, and then sends a file
of Forth source a line at a time through the loader's terminal, waiting
for each line's answer, and prints what TAQOZ says. It is how the
benchmarks are run against TAQOZ Reloaded on the same board; the image is
the one scripts/taqoz.sh fetches.

Usage: scripts/taqoz.py PORT IMAGE FILE

Run it under the shared board lock, as every use of the port is:

    flock -o -w 900 /tmp/p2-board.lock scripts/taqoz.py /dev/ttyUSB0 build/taqoz/_BOOT_P2.BIX bench/taqoz.fth
"""

import os
import select
import subprocess
import sys
import time


def read_until(fd, ends, secs, idle=None):
    """Reads until one of ends arrives or secs pass, or, with idle, until
    nothing has arrived for that long, and answers what came."""
    got = b""
    deadline = time.time() + secs
    last = time.time()
    while time.time() < deadline:
        ready, _, _ = select.select([fd], [], [], 0.05)
        if not ready:
            if idle is not None and time.time() - last > idle:
                break
            continue
        last = time.time()
        try:
            got += os.read(fd, 4096)
        except BlockingIOError:
            continue
        if any(e in got for e in ends):
            time.sleep(0.05)
            try:
                got += os.read(fd, 4096)
            except BlockingIOError:
                pass
            break
    return got


def main():
    if len(sys.argv) != 4:
        sys.exit("usage: taqoz.py PORT IMAGE FILE")
    port, image, path = sys.argv[1], sys.argv[2], sys.argv[3]
    with open(path, "rb") as f:
        lines = f.read().split(b"\n")
    proc = subprocess.Popen(
        ["ogo", "loadp2", "-ZERO", "-t", "-NOEOF", "-p", port, "-b", "921600", image],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    fd = proc.stdout.fileno()
    wfd = proc.stdin.fileno()
    os.set_blocking(fd, False)
    out = sys.stdout.buffer
    out.write(read_until(fd, [b"TAQOZ#"], 10.0))
    out.flush()
    # Inside a colon definition TAQOZ answers a line with no "ok": such a
    # line is waited for only until its echo stops.
    defining = False
    for line in lines:
        if not line.strip():
            continue
        words = line.split()
        if words[0] == b":":
            defining = True
        os.write(wfd, line.rstrip(b"\r") + b"\r")
        if defining and b";" not in words:
            out.write(read_until(fd, [b"???"], 5.0, idle=0.3))
        else:
            defining = False
            out.write(read_until(fd, [b" ok\r", b" ok\n", b"???"], 60.0))
        out.flush()
    os.write(wfd, b"\x1d")
    try:
        proc.wait(5)
    except subprocess.TimeoutExpired:
        proc.kill()


if __name__ == "__main__":
    main()
