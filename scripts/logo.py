#!/usr/bin/env python3
# Copyright 2026 The oforth Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

"""Draw logo.png: OctoGo's gopher with "4th" on its belly.

The gopher is OctoGo's mascot (../ogo/web/logo-full.png, 2000x2000), which is
based on the Go gopher, CC BY 4.0 (README.md has the attribution). The
lettering is DejaVu Sans Bold, rendered into the image, in the navy of the
"P2" chip label below it.

    python3 -I scripts/logo.py [../ogo/web/logo-full.png [logo.png [SIZE]]]
"""

import sys
from PIL import Image, ImageDraw, ImageFont

SRC = sys.argv[1] if len(sys.argv) > 1 else "../ogo/web/logo-full.png"
DST = sys.argv[2] if len(sys.argv) > 2 else "logo.png"
SIZE = int(sys.argv[3]) if len(sys.argv) > 3 else 256
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
NAVY = (28, 55, 84, 255)   # the outlines and the "P2" label
CX, CY = 1000, 1532        # the middle of the lighter belly, in the master

im = Image.open(SRC).convert("RGBA")
assert im.size == (2000, 2000), im.size
d = ImageDraw.Draw(im)

big = ImageFont.truetype(FONT, 230)
small = ImageFont.truetype(FONT, 110)
w4 = d.textlength("4", font=big)
wth = d.textlength("th", font=small)
gap = 8
x0 = CX - (w4 + gap + wth) / 2
# "4" sits on the baseline, "th" is raised to the top of the "4".
asc4 = big.getbbox("4")[1]
top4 = CY - (big.getbbox("4")[3] - asc4) / 2
d.text((x0, top4 - asc4), "4", font=big, fill=NAVY)
d.text((x0 + w4 + gap, top4 - small.getbbox("t")[1] - 4), "th", font=small, fill=NAVY)

im.resize((SIZE, SIZE), Image.LANCZOS).save(DST, optimize=True)
