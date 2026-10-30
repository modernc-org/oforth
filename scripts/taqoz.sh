#!/bin/sh
# Copyright 2026 The oforth Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# taqoz.sh fetches TAQOZ Reloaded V2.14.0, the image of 2024-02-19 from
# SourceForge's TAQOZ/binaries, into build/taqoz, checks its hash, and
# prints its path. The benchmark scripts load it into hub RAM by ogo
# loadp2 at 921600 baud, TAQOZ's; it is its author's and never committed.
#
# Usage: scripts/taqoz.sh

set -eu
dir=build/taqoz
f=$dir/_BOOT_P2.BIX
mkdir -p $dir
[ -f $f ] || curl -sSfL -o $f \
	https://sourceforge.net/projects/tachyon-forth/files/TAQOZ/binaries/_BOOT_P2.BIX/download
echo "0e1730ced4d1f87a5e1e7b62d30309456d06245551c3aa142faee42e4b0513c4  $f" | sha256sum -c --quiet - >&2
echo $f
