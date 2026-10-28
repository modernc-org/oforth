#!/usr/bin/env python3
# Copyright 2026 The oforth Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

"""session.py runs a file of Forth source on a Forth on the board and times
what it marks: a line after a comment "\\ @TIME name" is a timed command,
which must write "{" just before the work and "}" just after it (123 EMIT
and 125 EMIT around it), and the time between the two arriving is the
work's. Every system is timed the same way, by this host's clock, so that
programs that run longer than a 32-bit counter of clocks lasts are timed
too; the resolution is a few milliseconds of the serial line's latency.

The systems:

    oforth BINARY   OctoForth, loaded by ogo loadp2 at 230400 baud
    p2xc BINARY     P2XCForth, loaded so, its lines ended by CR LF
    taqoz           the TAQOZ in the board's flash, booted by a reset with
                    no loader, at 921600 baud

It prints a line "TIME name ms" for each timed command, and writes all the
system said to the log given with -log.

Usage: scripts/session.py [-log FILE] PORT SYSTEM [BINARY] FILE

Run it under the shared board lock, as every use of the port is.
"""

import fcntl
import os
import re
import select
import struct
import subprocess
import sys
import termios
import time

# What ends a system's answer to a line, matched against the output's end.
READY = {
    "oforth": re.compile(rb"( ok| compiled| \?|error: [^\n]*)\r?\n$"),
    "p2xc": re.compile(rb"\n[^\n]*> $"),
    "taqoz": re.compile(rb"(ok|\?\?\?|---)\s*$"),
}
EOL = {"oforth": b"\r", "p2xc": b"\r\n", "taqoz": b"\r"}


class Port:
    """The board's serial line, directly or through ogo loadp2."""

    def __init__(self, port, system, binary):
        self.proc = None
        if system == "taqoz":
            self.fd = os.open(port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
            a = termios.tcgetattr(self.fd)
            a[0] = a[1] = a[3] = 0
            a[2] = termios.CS8 | termios.CREAD | termios.CLOCAL | termios.B921600
            a[4] = a[5] = termios.B921600
            a[6][termios.VMIN] = a[6][termios.VTIME] = 0
            termios.tcsetattr(self.fd, termios.TCSANOW, a)
            dtr = struct.pack("I", termios.TIOCM_DTR)
            fcntl.ioctl(self.fd, termios.TIOCMBIS, dtr)
            time.sleep(0.05)
            fcntl.ioctl(self.fd, termios.TIOCMBIC, dtr)
            time.sleep(0.05)
            fcntl.ioctl(self.fd, termios.TIOCMBIS, dtr)
            termios.tcflush(self.fd, termios.TCIFLUSH)
            self.rfd = self.wfd = self.fd
        else:
            self.proc = subprocess.Popen(
                ["ogo", "loadp2", "-t", "-NOEOF", "-p", port, "-b", "230400", binary],
                stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            self.rfd = self.proc.stdout.fileno()
            self.wfd = self.proc.stdin.fileno()
            os.set_blocking(self.rfd, False)

    def write(self, b):
        os.write(self.wfd, b)

    def read(self, timeout):
        """Answers what arrived within timeout seconds, with its time."""
        r, _, _ = select.select([self.rfd], [], [], timeout)
        if not r:
            return b"", time.time()
        try:
            return os.read(self.rfd, 65536), time.time()
        except BlockingIOError:
            return b"", time.time()

    def close(self):
        if self.proc:
            try:
                self.write(b"\x1d")
            except OSError:
                pass
            try:
                self.proc.wait(5)
            except subprocess.TimeoutExpired:
                self.proc.kill()
        else:
            os.close(self.fd)


def main():
    args = sys.argv[1:]
    log = None
    if args[:1] == ["-log"]:
        log = open(args[1], "wb")
        args = args[2:]
    if len(args) not in (3, 4):
        sys.exit(__doc__)
    port, system = args[0], args[1]
    binary = args[2] if len(args) == 4 else None
    path = args[-1]
    lines = open(path, "rb").read().split(b"\n")
    p = Port(port, system, binary)
    ready = READY[system]
    out = b""

    def wait(secs, quiet=None):
        """Reads until the system is ready again; answers the output and
        the arrival times of the first { and the first } in it."""
        nonlocal out
        got = b""
        t_open = t_close = None
        deadline = time.time() + secs
        last = time.time()
        while time.time() < deadline:
            b, t = p.read(0.05)
            if b:
                last = t
                if t_open is None and b"{" in b:
                    t_open = t
                if t_open is not None and t_close is None and b"}" in b:
                    t_close = t
                got += b
                if log:
                    log.write(b)
                    log.flush()
                # Ready is the end, the closing mark seen or not: a timed
                # command that failed answers with the prompt and no }.
                if ready.search(got):
                    break
            elif quiet is not None and got and time.time() - last > quiet:
                break
        out += got
        return got, t_open, t_close

    # The banner, and the system's first prompt.
    wait(15, quiet=1.5)
    timed = None
    for line in lines:
        line = line.rstrip(b"\r")
        m = re.match(rb"\\ @TIME (\S+)", line, re.I)
        if m:
            timed = m.group(1).decode()
            continue
        if not line.strip():
            continue
        p.write(line + EOL[system])
        if timed:
            got, t0, t1 = wait(120)
            if t0 is None or t1 is None:
                print("TIME %s failed" % timed, flush=True)
            else:
                print("TIME %s %d" % (timed, round((t1 - t0) * 1000)), flush=True)
            timed = None
        else:
            # A line that is no timed command is answered at once; an
            # error's answer is the system's own, so its end is not looked
            # for, but its quiet after it.
            wait(30, quiet=0.5)
    p.close()


if __name__ == "__main__":
    main()
