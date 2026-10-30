#!/bin/sh
# Copyright 2026 The oforth Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# release.sh builds a release's binaries and stages them for a GitHub
# Release, as obeam's and ogo's scripts/release.sh do. The binaries are the
# P2's, the same whatever the host, so a release is one zip: oforth.binary,
# the REPL main.ogo makes, for a loader to load into the board's RAM;
# boot.binary, boot/'s, for the board's flash, which runs flash:boot.fth
# first; examples/bench.fth, the benchmarks; README.txt; LICENSE; and
# LICENSE-flexprop, the binaries being flexspin's output, its runtime in
# them. They are built from the tag's sources by git archive, not from the
# working tree, with forth.Version set to the tag, which the banner then
# says; at OctoGo's default clock, 160 MHz, for a 20 MHz crystal.
#
# Usage: scripts/release.sh [VERSION]
#   VERSION defaults to the tag at HEAD, so the flow is: a section in
#   CHANGELOG.md, commit, git tag -a vX.Y.Z, scripts/release.sh. With no tag
#   of the name, HEAD is built, with a warning. FLEXPROP names
#   LICENSE-flexprop when the ogo on PATH is not a module go can download.
#
# Output: build/release/<VERSION>/ with oforth-<VERSION>.zip, which unzips
# into oforth-<VERSION>/, and SHA256SUMS.
#
# It does not test them. The tests and the suite run on the board and come
# before the tag (ogo test ./forth, scripts/f2012.sh); here only
# boot.binary's size is checked, against what the loader's -FLASH writes.

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
	VERSION=$(git describe --tags --exact-match 2>/dev/null) || {
		echo "HEAD has no tag: scripts/release.sh VERSION" >&2
		exit 1
	}
fi
case "$VERSION" in
v[0-9]*) ;;
*)
	echo "a version is vX.Y.Z, not $VERSION" >&2
	exit 1
	;;
esac
if git rev-parse -q --verify "refs/tags/$VERSION" >/dev/null; then
	REF=$VERSION
else
	echo "warning: there is no tag $VERSION; building HEAD" >&2
	REF=HEAD
fi

OGO=$(ogo version | awk 'NR == 1 {print $3}')
case "$OGO" in
v*-* | *+*) echo "warning: ogo $OGO is no final release" >&2 ;;
esac

OUT="$ROOT/build/release/$VERSION"
NAME="oforth-$VERSION"
STAGE="$OUT/$NAME"
SRC="$OUT/src"
rm -rf "$OUT"
mkdir -p "$STAGE/examples" "$SRC"

if [ -z "${FLEXPROP:-}" ]; then
	dir=$(cd "$OUT" && go mod download -json "modernc.org/ogo@$OGO" 2>/dev/null |
		grep '"Dir"' | sed 's/.*"Dir": "\(.*\)",*$/\1/') || true
	FLEXPROP=$dir/internal/flexcc/LICENSE-flexprop
fi
if [ ! -f "$FLEXPROP" ]; then
	echo "no LICENSE-flexprop for ogo $OGO: set FLEXPROP to its path" >&2
	exit 1
fi

git archive "$REF" | tar -x -C "$SRC"
v="$SRC/forth/version.ogo"
sed -e "s/^const Version = \"\"$/const Version = \"$VERSION\"/" \
	-e "s/^const release = \"\"$/const release = \" $VERSION\"/" "$v" > "$v.new"
mv "$v.new" "$v"
grep -q "^const Version = \"$VERSION\"$" "$v" && grep -q "^const release = \" $VERSION\"$" "$v" || {
	echo "$REF:forth/version.ogo: no Version and release to set" >&2
	exit 1
}

echo "building OctoForth $VERSION from $REF with ogo $OGO"
(cd "$SRC" && ogo build -o "$STAGE/oforth.binary" . && ogo build -o "$STAGE/boot.binary" ./boot)
rm -f "$STAGE"/*.p2asm
osize=$(wc -c < "$STAGE/oforth.binary")
size=$(wc -c < "$STAGE/boot.binary")
if [ "$size" -ge 507904 ]; then
	echo "boot.binary is $size bytes; the flash takes images under 507904" >&2
	exit 1
fi

cp "$SRC/LICENSE" "$STAGE/LICENSE"
cp "$FLEXPROP" "$STAGE/LICENSE-flexprop"
cp "$SRC/bench/oforth.fth" "$STAGE/examples/bench.fth"
cat > "$STAGE/README.txt" <<TXT
OctoForth $VERSION (preview)

OctoForth is a Forth for the Parallax Propeller 2 that compiles every colon
definition to P2 machine code as it is defined. These binaries are built
by OctoGo $OGO,
for a board with a 20 MHz crystal, such as the P2-EDGE, which they run at
160 MHz; the console is at 230400 baud.

  oforth.binary       the REPL, for a loader to load into the board's RAM
  boot.binary         the same REPL for the board's flash: it first runs
                      flash:boot.fth, if there is one, unless a key comes
                      within half a second
  examples/bench.fth  five benchmarks, each printing a count of clocks

With the board on a USB port, and FlexProp's loadp2 or OctoGo's ogo loadp2:

  loadp2 -t -b 230400 oforth.binary         the REPL; Ctrl-] leaves the terminal
  loadp2 -t -9 . -b 230400 oforth.binary    the same, with this directory served
                                            to it: INCLUDE examples/bench.fth
  loadp2 -FLASH -t -b 230400 boot.binary    into the flash, which the board then
                                            boots at a reset (a P2-EDGE's DIP
                                            switch FLASH on): leave the terminal
                                            only once the banner has come, and
                                            use loadp2 0.078 or newer

A file named sd:NAME is on the SD card in the board's slot, one named
flash:NAME in the board's flash, written as it is made and read only after,
and any other in the directory the loader's -9 serves.

The documentation, the sources and the issues:
https://gitlab.com/cznic/oforth (issues and PRs are also accepted at the
GitHub mirror, https://github.com/modernc-org/oforth).

Licensing: OctoForth is BSD-licensed (see LICENSE). The binaries are built by
flexspin and include its runtime, and loadp2 is FlexProp's; see
LICENSE-flexprop.
TXT

(cd "$OUT" && zip -q -X -r "$NAME.zip" "$NAME" && sha256sum "$NAME.zip" > SHA256SUMS)
rm -rf "$STAGE" "$SRC"
echo "  oforth.binary $osize bytes, boot.binary $size"
echo "artifacts in $OUT:"
ls -1 "$OUT"
