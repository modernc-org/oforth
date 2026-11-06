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
    taqoz BINARY    TAQOZ Reloaded, the image scripts/taqoz.sh fetches,
                    loaded so at 921600 baud into a cleared hub RAM

It prints a line "TIME name ms" for each timed command, and writes all the
system said to the log given with -log.

Usage: scripts/session.py [-log FILE] PORT SYSTEM BINARY FILE

Run it under the shared board lock, as every use of the port is.
"""

import os
import re
import select
import subprocess
import sys
import time

# What ends a system's answer to a line, matched against the output's end.
READY = {
    "oforth": re.compile(rb"( ok| compiled| \?|error: [^\n]*)\r?\n$"),
    "p2xc": re.compile(rb"\n[^\n]*> $"),
    # TAQOZ writes its next prompt after the ok, and when both came in one
    # read, a timed command waited out its 120 s (seen 2026-11-06).
    "taqoz": re.compile(rb"(ok|\?\?\?|---)\s*(TAQOZ# )?$"),
}
EOL = {"oforth": b"\r", "p2xc": b"\r\n", "taqoz": b"\r"}
# What ends a system's banner, where its quiet after it does not: TAQOZ
# says nothing for 1.7 s after the loader hands it over, before it probes
# the SD card and writes its prompt, and a line sent in that silence was
# lost (seen 2026-11-06).
BANNER = {
    "taqoz": re.compile(rb"TAQOZ# $"),
}


class Port:
    """The board's serial line, through ogo loadp2."""

    def __init__(self, port, system, binary):
        loader = ["ogo", "loadp2", "-t", "-NOEOF", "-p", port, "-b", "230400"]
        if system == "taqoz":
            loader = ["ogo", "loadp2", "-ZERO", "-t", "-NOEOF", "-p", port, "-b", "921600"]
        self.proc = subprocess.Popen(
            loader + [binary],
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
        try:
            self.write(b"\x1d")
        except OSError:
            pass
        try:
            self.proc.wait(5)
        except subprocess.TimeoutExpired:
            self.proc.kill()


def main():
    args = sys.argv[1:]
    log = None
    if args[:1] == ["-log"]:
        log = open(args[1], "wb")
        args = args[2:]
    if len(args) != 4:
        sys.exit(__doc__)
    port, system, binary, path = args
    lines = open(path, "rb").read().split(b"\n")
    p = Port(port, system, binary)
    ready = READY[system]
    out = b""

    def wait(secs, quiet=None, until=ready):
        """Reads until the system is ready again, as until says; answers
        the output and the arrival times of the first { and the first }
        in it."""
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
                if until.search(got):
                    break
            elif quiet is not None and got and time.time() - last > quiet:
                break
        out += got
        return got, t_open, t_close

    # The banner, and the system's first prompt.
    if system in BANNER:
        wait(15, until=BANNER[system])
    else:
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
