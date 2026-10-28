#!/usr/bin/env python3
# Copyright 2026 The oforth Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

"""taqoz.py talks to the TAQOZ in a P2 board's flash: it resets the board by
its DTR line, with no loader to answer, so that the board boots what its
flash holds, and then sends a file of Forth source a line at a time at
921600 baud, TAQOZ's, waiting for each line's answer, and prints what TAQOZ
says. It is how the benchmarks are run against TAQOZ Reloaded on the same
board.

Usage: scripts/taqoz.py PORT FILE

Run it under the shared board lock, as every use of the port is:

    flock -o -w 900 /tmp/p2-board.lock scripts/taqoz.py /dev/ttyUSB0 bench/taqoz.fth
"""

import fcntl
import os
import select
import struct
import sys
import termios
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
    if len(sys.argv) != 3:
        sys.exit("usage: taqoz.py PORT FILE")
    port, path = sys.argv[1], sys.argv[2]
    with open(path, "rb") as f:
        lines = f.read().split(b"\n")
    fd = os.open(port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    attrs = termios.tcgetattr(fd)
    attrs[0] = attrs[1] = attrs[3] = 0
    attrs[2] = termios.CS8 | termios.CREAD | termios.CLOCAL | termios.B921600
    attrs[4] = attrs[5] = termios.B921600
    attrs[6][termios.VMIN] = attrs[6][termios.VTIME] = 0
    termios.tcsetattr(fd, termios.TCSANOW, attrs)
    dtr = struct.pack("I", termios.TIOCM_DTR)
    fcntl.ioctl(fd, termios.TIOCMBIS, dtr)
    time.sleep(0.05)
    fcntl.ioctl(fd, termios.TIOCMBIC, dtr)
    time.sleep(0.05)
    fcntl.ioctl(fd, termios.TIOCMBIS, dtr)
    termios.tcflush(fd, termios.TCIFLUSH)
    out = sys.stdout.buffer
    out.write(read_until(fd, [b"TAQOZ#"], 5.0))
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
        os.write(fd, line.rstrip(b"\r") + b"\r")
        if defining and b";" not in words:
            out.write(read_until(fd, [b"???"], 5.0, idle=0.3))
        else:
            defining = False
            out.write(read_until(fd, [b" ok\r", b" ok\n", b"???"], 60.0))
        out.flush()
    os.close(fd)


if __name__ == "__main__":
    main()
