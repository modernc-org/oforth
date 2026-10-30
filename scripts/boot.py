#!/usr/bin/env python3
# Copyright 2026 The oforth Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

"""boot.py resets a P2 board by its DTR line, with no loader to answer, so
that the board boots what its flash holds, and prints what it says at
230400 baud, OctoForth's, until it is quiet for a second; then it sends
each LINE given, a CR after it, and prints the answer so. It is how
scripts/flash.sh checks the flash's OctoForth.

Usage: scripts/boot.py PORT [LINE...]

Run it under the shared board lock, as every use of the port is:

    flock -w 900 /tmp/p2-board.lock scripts/boot.py /dev/ttyUSB0 '1 2 + .'
"""

import fcntl
import os
import select
import struct
import sys
import termios
import time


def quiet(fd, secs, first):
    """Answers what arrives until nothing has for secs, or nothing has
    come within first."""
    got = b""
    last = time.time()
    while time.time() - last < (secs if got else first):
        ready, _, _ = select.select([fd], [], [], 0.05)
        if ready:
            try:
                got += os.read(fd, 4096)
                last = time.time()
            except BlockingIOError:
                pass
    return got


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    port = sys.argv[1]
    fd = os.open(port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    a = termios.tcgetattr(fd)
    a[0] = a[1] = a[3] = 0
    a[2] = termios.CS8 | termios.CREAD | termios.CLOCAL | termios.B230400
    a[4] = a[5] = termios.B230400
    a[6][termios.VMIN] = a[6][termios.VTIME] = 0
    termios.tcsetattr(fd, termios.TCSANOW, a)
    dtr = struct.pack("I", termios.TIOCM_DTR)
    fcntl.ioctl(fd, termios.TIOCMBIS, dtr)
    time.sleep(0.05)
    fcntl.ioctl(fd, termios.TIOCMBIC, dtr)
    time.sleep(0.05)
    fcntl.ioctl(fd, termios.TIOCMBIS, dtr)
    termios.tcflush(fd, termios.TCIFLUSH)
    out = sys.stdout.buffer
    out.write(quiet(fd, 1.0, 5.0))
    out.flush()
    for line in sys.argv[2:]:
        os.write(fd, line.encode() + b"\r")
        out.write(quiet(fd, 0.5, 5.0))
        out.flush()
    os.close(fd)


if __name__ == "__main__":
    main()
