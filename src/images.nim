# ----------------------------------------------------------------------------- #
#
# snowflake/images
#
# Conversion between TGA and PNG objects.
#
# ----------------------------------------------------------------------------- #
#
# Copyright (C) 2022 Wyrd (https://github.com/wyrdwinter)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# ----------------------------------------------------------------------------- #

import nimPNG
import targa

# ----------------------------------------------------------------------------- #

proc tgaToPNG*(tga: Image): auto =
  proc originBottomLeft: bool =
    tga.header.x_origin == 0 and tga.header.y_origin == 0

  proc originTopLeft: bool =
    tga.header.x_origin == 0 and tga.header.y_origin == 1

  proc originBottomRight: bool =
    tga.header.x_origin == 1 and tga.header.y_origin == 0

  proc originTopRight: bool =
    tga.header.x_origin == 1 and tga.header.y_origin == 1

  if tga.header.image_type != 2 or
     (tga.header.pixel_depth != 24 and tga.header.pixel_depth != 32):
    raise newException(ValueError, "TGA must be uncompressed, 24 RGB or 32 bit RGBA")

  let
    tgaPixels: seq[Pixel] = tga.pixels
    width: int = int(tga.header.image_width)
    height: int = int(tga.header.image_height)

  var pngPixels: seq[uint8] = @[]

  proc addPixel(pixel: Pixel) =
    # Apparently, the PNG expects the pixels to be ordered as b, g, r
    if pixel.kind == pkRGB:
      pngPixels.add(pixel.rgb_val.b)
      pngPixels.add(pixel.rgb_val.g)
      pngPixels.add(pixel.rgb_val.r)
    elif pixel.kind == pkRGBA:
      pngPixels.add(pixel.rgba_val.b)
      pngPixels.add(pixel.rgba_val.g)
      pngPixels.add(pixel.rgba_val.r)

  if originBottomLeft():
    for row in countdown(height - 1, 0):
      for col in 0..<width:
        addPixel(tga.pixels[(row * width) + col])
  elif originTopLeft():
    for row in 0..<height:
      for col in 0..<width:
        addPixel(tga.pixels[(row * width) + col])
  elif originBottomRight():
    for row in countdown(height - 1, 0):
      for col in countdown(width - 1, 0):
        addPixel(tga.pixels[(row * width) + col])
  elif originTopRight():
    for row in 0..<height:
      for col in countdown(width - 1, 0):
        addPixel(tga.pixels[(row * width) + col])

  result = encodePNG24(pngPixels, width, height)
