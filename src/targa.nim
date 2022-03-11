# ----------------------------------------------------------------------------- #
#
# Derived from: https://github.com/BontaVlad/nimtga
# Originally authored by Bonta Vlad, MIT license.
#
# ----------------------------------------------------------------------------- #

import std/[streams, strutils, colors, os]

type
  Header* = object
    # Here we have some details for each field:
    # Field(1)
    # ID LENGTH (1 byte):
    #   Number of bites of field 6, max 255.
    #   Is 0 if no image id is present.
    # Field(2)
    # COLOR MAP TYPE (1 byte):
    #   - 0 : no color map included with the image
    #   - 1 : color map included with the image
    # Field(3)
    # IMAGE TYPE (1 byte):
    #   - 0  : no data included
    #   - 1  : uncompressed color map image
    #   - 2  : uncompressed true color image
    #   - 3  : uncompressed black and white image
    #   - 9  : run-length encoded color map image
    #   - 10 : run-length encoded true color image
    #   - 11 : run-length encoded black and white image
    # Field(4)
    # COLOR MAP SPECIFICATION (5 bytes):
    #   - first_entry_index (2 bytes) : index of first color map entry
    #   - color_map_length  (2 bytes)
    #   - color_map_entry_size (1 byte)
    #  Field(5)
    # IMAGE SPECIFICATION (10 bytes):
    #   - x_origin  (2 bytes)
    #   - y_origin  (2 bytes)
    #   - image_width   (2 bytes)
    #   - image_height  (2 bytes)
    #   - pixel_depth   (1 byte):
    #       - 8 bit  : grayscale
    #       - 16 bit : RGB (5-5-5-1) bit per color
    #                  Last one is alpha (visible or not)
    #       - 24 bit : RGB (8-8-8) bit per color
    #       - 32 bit : RGBA (8-8-8-8) bit per color
    #   - image_descriptor (1 byte):
    #       - bit 3-0 : number of attribute bit per pixel
    #       - bit 5-4 : order in which pixel data is transferred
    #                   from the file to the screen
    #  +-----------------------------------+-------------+-------------+
    #  | Screen destination of first pixel | Image bit 5 | Image bit 4 |
    #  +-----------------------------------+-------------+-------------+
    #  | bottom left                       |           0 |           0 |
    #  | bottom right                      |           0 |           1 |
    #  | top left                          |           1 |           0 |
    #  | top right                         |           1 |           1 |
    #  +-----------------------------------+-------------+-------------+
    #       - bit 7-6 : must be zero to insure future compatibility

    # Field(1)
    id_length*: uint8
    # Field(2)
    color_map_type*: uint8
    # Field(3)
    image_type*: uint8
    # Field(4)
    first_entry_index*: uint16
    color_map_length*: uint16
    color_map_entry_size*: uint8
    # Field(5)
    x_origin*: uint16
    y_origin*: uint16
    image_width*: uint16
    image_height*: uint16
    pixel_depth*: uint8
    image_descriptor*: uint8

  Footer* = object
    extension_area_offset*: uint32  # 4 bytes
    developer_directory_offset*: uint32 # 4 bytes
    signature*, dot*, eend*: string

  PixelKind* = enum
    pkBW,
    pkRGB,
    pkRGBA

  Pixel* = object
    case kind*: PixelKind
      of pkBW: bw_val*: tuple[a: uint8]
      of pkRGB: rgb_val*: tuple[r, g, b: uint8]
      of pkRGBA: rgba_val*: tuple[r, g, b, a: uint8]

  EncodedPixel = tuple[rep_count: uint8, value: seq[Pixel]]

  Image* = object
    header*: Header
    footer*: Footer
    new_tga_format*: bool
    first_pixel*: int
    bottom_left*: int
    bottom_right*: int
    top_left*: int
    top_right*: int
    pixels*: seq[Pixel]

template isLittleEndian(): bool =
  cpuEndian == Endianness.littleEndian

proc `==`*(a, b: Pixel): bool =
  if a.kind == b.kind:
    case a.kind
      of pkBW: result = a.bw_val == b.bw_val
      of pkRGB: result = a.rgb_val == b.rgb_val
      of pkRGBA: result = a.rgba_val == b.rgba_val
  else:
    result = false

proc height*(self: Image): int =
  result = self.header.image_height.int

proc width*(self: Image): int =
  result = self.header.image_width.int

proc get_rgb_from_16(data: int16): tuple[r, g, b: uint8] =
  # Construct an RGB color from 16 bit of data.
  # Args:
  #     second_byte (bytes): the first bytes read
  #     first_byte (bytes): the second bytes read
  # Returns:
  #     tuple(int, int, int): the RGB color
  let
    c_r = cast[uint8]((data and 0b1111100000000000) shr 11)
    c_g = cast[uint8]((data and 0b0000011111000000) shr 6)
    c_b = cast[uint8]((data and 0b111110) shr 1)

  result.r = c_r.uint8
  result.g = c_g.uint8
  result.b = c_b.uint8

proc toColor*(pixel: Pixel): Color =
  # TODO: this is ugly as fuck
  case pixel.kind
    of pkBW: return rgb(pixel.bw_val.a.int, pixel.bw_val.a.int, pixel.bw_val.a.int)
    of pkRGB: return rgb(pixel.rgb_val.r.int, pixel.rgb_val.g.int, pixel.rgb_val.b.int)
    of pkRGBA: return rgb(pixel.rgba_val.r.int, pixel.rgba_val.g.int, pixel.rgba_val.b.int)

proc newPixel* (arr: seq[uint]): Pixel {.inline.} =
  case arr.len
    of 1:
      result.kind = pkBW
      result.bw_val.a = arr[0].uint8
    of 3:
      result.kind = pkRGB
      result.rgb_val.r = arr[0].uint8
      result.rgb_val.g = arr[1].uint8
      result.rgb_val.b = arr[2].uint8
    of 4:
      result.kind = pkRGBA
      result.rgba_val.r = arr[0].uint8
      result.rgba_val.g = arr[1].uint8
      result.rgba_val.b = arr[2].uint8
      result.rgba_val.a = arr[3].uint8
    else: raise newException(ValueError, "Invalid pixel data")

proc `$`*(pixel: Pixel): string =
  case pixel.kind
    of pkBW: result = "bw: $#" % [$pixel.bw_val.a]
    of pkRGB: result = "r: $#, g: $#, b: $#" % [$pixel.rgb_val.r, $pixel.rgb_val.g, $pixel.rgb_val.b]
    of pkRGBA: result = "r: $#, g: $#, b: $#, alpha: $#" % [$pixel.rgba_val.r, $pixel.rgba_val.g, $pixel.rgba_val.b, $pixel.rgba_val.a]

proc `[]`*(pixel: Pixel, index: int): uint8 {.inline.} =
  case pixel.kind
    of pkBW: result = pixel.bw_val.a
    of pkRGB: result = [pixel.rgb_val.r, pixel.rgb_val.g, pixel.rgb_val.b][index]
    of pkRGBA: result = [pixel.rgba_val.r, pixel.rgba_val.g, pixel.rgba_val.b, pixel.rgba_val.a][index]

template to_int(expr: untyped): uint8 =
  cast[uint8](expr).uint8

proc parse_pixel(self: var Image, fs: Stream): Pixel =
  case self.header.image_type.int
    of 3, 11:
      let val = fs.readInt8().to_int
      result = Pixel(kind: pkBW, bw_val: (a: val))
    of 2, 10:
      case self.header.pixel_depth
        of 16:
          result = Pixel(
            kind: pkRGB,
            rgb_val: get_rgb_from_16(fs.readInt16())
          )
        of 24:
          result = Pixel(
            kind: pkRGB,
            rgb_val: (fs.readInt8().to_int, fs.readInt8().to_int, fs.readInt8().to_int)
          )
        of 32:
          result = Pixel(
            kind: pkRGBA,
            rgba_val: (fs.readInt8().to_int, fs.readInt8().to_int, fs.readInt8().to_int, fs.readInt8().to_int)
          )
        else: raise newException(ValueError, "unsupported pixel depth")
    else: raise newException(ValueError, "unsupported image type")

proc load(self: var Image, stream: Stream, streamLength: int) =
  self.header.id_length = stream.readInt8().uint8
  self.header.color_map_type = stream.readInt8().uint8
  self.header.image_type = stream.readInt8().uint8
  self.header.first_entry_index = stream.readInt16().uint16
  self.header.color_map_length = stream.readInt16().uint16
  self.header.color_map_entry_size = stream.readInt8().uint8
  self.header.x_origin = stream.readInt16().uint16
  self.header.y_origin = stream.readInt16().uint16
  self.header.image_width = stream.readInt16().uint16
  self.header.image_height = stream.readInt16().uint16
  self.header.pixel_depth = stream.readInt8().uint8
  self.header.image_descriptor = stream.readInt8().uint8

  let original_position = stream.getPosition()

  stream.setPosition(streamLength - 26)
  self.footer.extension_area_offset = stream.readInt32().uint32
  self.footer.developer_directory_offset = stream.readInt32().uint32
  self.footer.signature = stream.readStr(16)
  self.footer.dot = stream.readStr(1)
  self.footer.eend = stream.readStr(1)

  if self.footer.signature == "TRUEVISION-XFILE":
    self.new_tga_format = true

  stream.setPosition(original_position)

  let tot_pixels = self.header.image_height.int * self.header.image_width.int

  self.pixels = @[]

  # no compression
  if self.header.image_type.int in [2, 3]:
    for row in 0 .. self.header.image_height.int - 1:
      for col in 0 .. self.header.image_width.int - 1:
        self.pixels.add(self.parse_pixel(stream))

  # compressde
  elif self.header.image_type.int in [10, 11]:
    var
      pixel_count = 0
      pixel: Pixel

    while pixel_count < tot_pixels:
      let
        repetition_count = stream.readInt8()
        RLE: bool = (repetition_count and 0b10000000) shr 7 == 1
        count: int = (repetition_count and 0b01111111).int + 1

      pixel_count += count
      if RLE:
        pixel = self.parse_pixel(stream)
        for num in 0 .. count - 1:
          self.pixels.add(pixel)
      else:
        for num in 0 .. count - 1:
          pixel = self.parse_pixel(stream)
          self.pixels.add(pixel)

proc loadFileString(self: var Image, image: string) =
  let ss: StringStream = newStringStream(image)

  defer: ss.close()

  self.load(ss, image.len)

proc load(self: var Image, fileName: string) =
  var
    f: File
    fs: FileStream

  if not open(f, fileName, fmRead):
    raise newException(IOError, "Failed to open file: $#" % fileName)

  fs = newFileStream(fileName)

  if isNil(fs):
    raise newException(IOError, "Failed to open file: $#" % fileName)

  defer: fs.close()

  self.load(fs, getFileSize(f).int)

template write_value[T](f: var File, data: T) =
  var tmp: T
  shallowCopy(tmp, data)
  let sz = sizeof(tmp)
  let written_bytes = f.writeBuffer(addr(tmp), sz)
  doAssert(sz == written_bytes, "Wrong number of bytes written")

template write_data(f: var File, data: string) =
  for str in data:
    f.write_value(str)

template write_pixel(f: var File, pixel: Pixel) =
  var fields: seq[uint8]

  for name, value in pixel.fieldPairs:
    when name != "kind":
      for v in value.fields:
        f.write_value(v)

proc write_header(f: var File, image: Image) =
  f.write_value(image.header.id_length)
  f.write_value(image.header.color_map_type)
  f.write_value(image.header.image_type)
  f.write_value(image.header.first_entry_index)
  f.write_value(image.header.color_map_length)
  f.write_value(image.header.color_map_entry_size)
  f.write_value(image.header.x_origin)
  f.write_value(image.header.y_origin)
  f.write_value(image.header.image_width)
  f.write_value(image.header.image_height)
  f.write_value(image.header.pixel_depth)
  f.write_value(image.header.image_descriptor)

proc write_footer(f: var File, image: Image) =
  f.write_value(image.footer.extension_area_offset)
  f.write_value(image.footer.developer_directory_offset)
  f.write_data(image.footer.signature)
  f.write_data(image.footer.dot)
  f.write_data(image.footer.eend)

iterator encode(row: seq[Pixel]): EncodedPixel {.inline.} =
  # Run-length encoded (RLE) images comprise two types of data
  # elements:Run-length Packets and Raw Packets.

  # The first field (1 byte) of each packet is called the
  # Repetition Count field. The second field is called the
  # Pixel Value field. For Run-length Packets, the Pixel Value
  # field contains a single pixel value. For Raw
  # Packets, the field is a variable number of pixel values.

  # The highest order bit of the Repetition Count indicates
  # whether the packet is a Raw Packet or a Run-length
  # Packet. If bit 7 of the Repetition Count is set to 1, then
  # the packet is a Run-length Packet. If bit 7 is set to
  # zero, then the packet is a Raw Packet.

  # The lower 7 bits of the Repetition Count specify how many
  # pixel values are represented by the packet. In
  # the case of a Run-length packet, this count indicates how
  # many successive pixels have the pixel value
  # specified by the Pixel Value field. For Raw Packets, the
  # Repetition Count specifies how many pixel values
  # are actually contained in the next field. This 7 bit value
  # is actually encoded as 1 less than the number of
  # pixels in the packet (a value of 0 implies 1 pixel while a
  # value of 0x7F implies 128 pixels).

  # Run-length Packets should never encode pixels from more than
  # one scan line. Even if the end of one scan
  # line and the beginning of the next contain pixels of the same
  # value, the two should be encoded as separate
  # packets. In other words, Run-length Packets should not wrap
  # from one line to another. This scheme allows
  # software to create and use a scan line table for rapid, random
  # access of individual lines. Scan line tables are
  # discussed in further detail in the Extension Area section of
  # this document.


  # Pixel format data example:

  # +=======================================+
  # | Uncompressed pixel run                |
  # +=========+=========+=========+=========+
  # | Pixel 0 | Pixel 1 | Pixel 2 | Pixel 3 |
  # +---------+---------+---------+---------+
  # | 144     | 144     | 144     | 144     |
  # +---------+---------+---------+---------+

  # +==========================================+
  # | Run-length Packet                        |
  # +============================+=============+
  # | Repetition Count           | Pixel Value |
  # +----------------------------+-------------+
  # | 1 bit |       7 bit        |             |
  # +----------------------------|     144     |
  # |   1   |  3 (num pixel - 1) |             |
  # +----------------------------+-------------+

  # +====================================================================================+
  # | Raw Packet                                                                         |
  # +============================+=============+=============+=============+=============+
  # | Repetition Count           | Pixel Value | Pixel Value | Pixel Value | Pixel Value |
  # +----------------------------+-------------+-------------+-------------+-------------+
  # | 1 bit |       7 bit        |             |             |             |             |
  # +----------------------------|     144     |     144     |     144     |     144     |
  # |   0   |  3 (num pixel - 1) |             |             |             |             |
  # +----------------------------+-------------+-------------+-------------+-------------+

  # States:
  # - 0: init
  # - 1: run-length packet
  # - 2: raw packets

  var
    state = 0
    index = 0
    repetition_count: uint8 = 0
    pixel_value: seq[Pixel]

  pixel_value = @[]
  while index <= row.high:
    if state == 0:
      repetition_count = 0
      if index == row.high:
        pixel_value = @[row[index]]
        yield (repetition_count, pixel_value)
      elif row[index] == row[index + 1]:
        repetition_count = repetition_count or 0b10000000
        pixel_value = @[row[index]]
        state = 1
      else:
        pixel_value = @[row[index]]
        state = 2
      inc(index)
    elif state == 1 and row[index] == pixel_value[0]:
        if (repetition_count and 0b1111111) == 127:
          yield (repetition_count, pixel_value)
          repetition_count = 0b10000000
        else:
          inc(repetition_count)
        inc(index)
    elif state == 2 and row[index] != pixel_value[0]:
      if (repetition_count and 0b1111111) == 127:
        yield (repetition_count, pixel_value)
        repetition_count = 0
        pixel_value = @[row[index]]
      else:
        inc(repetition_count)
        pixel_value.add(row[index])
      inc(index)
    else:
      yield(repetition_count, pixel_value)
      state = 0

  if state != 0:
    yield(repetition_count, pixel_value)

proc save*(self: var Image, filename: string, compress=false, force_16_bit=false) =
  # ID LENGTH
  self.header.id_length = 0
  # COLOR MAP TYPE
  self.header.color_map_type = 0
  # COLOR MAP SPECIFICATION
  self.header.first_entry_index = 0
  self.header.color_map_length = 0
  self.header.color_map_entry_size = 0
  # IMAGE SPECIFICATION
  self.header.x_origin = 0
  self.header.y_origin = 0
  # IMAGE TYPE
  # IMAGE SPECIFICATION (pixel_depht)
  let tmp_pixel = self.pixels[0]

  case tmp_pixel.kind
    of pkBW:
      self.header.image_type = 3
      self.header.pixel_depth = 8
    of pkRGB:
      self.header.image_type = 2
      if force_16_bit:
        self.header.pixel_depth = 16
      else:
        self.header.pixel_depth = 24
    of pkRGBA:
      self.header.image_type = 2
      self.header.pixel_depth = 32

  if compress:
    case self.header.image_type
      of 3: self.header.image_type = 11
      of 2: self.header.image_type = 10
      else: discard

  var f = open(filename, fmWrite)

  if isNil(f):
    raise newException(IOError, "Failed to open/create file: $#" % filename)

  defer: f.close()
  f.write_header(self)

  if not compress:
    for pixel in self.pixels:
      f.write_pixel(pixel)
  elif compress:
    let
      width = self.header.image_width.int
      height = self.header.image_height.int

    var index = 0

    for row in 1 .. height:
      for count, value in encode(self.pixels[index .. index - 1 + width]):
        f.write_value(count)
        if count.int > 127:
          f.write_pixel(value[0])
        else:
          for pixel in value:
            f.write_pixel(pixel)
      index += width

  f.write_footer(self)

proc newImageImpl(): Image =
  result.header = Header()
  result.footer = Footer()
  result.new_tga_format = false
  # Screen destination of first pixel
  result.bottom_left = 0b0
  result.bottom_right = 0b1 shl 4
  result.top_left = 0b1 shl 5
  result.top_right = 0b1 shl 4 or 0b1 shl 5
  # Default values
  result.header.image_descriptor = result.top_left.uint8

proc newImageFromString*(image: string): Image =
  result = newImageImpl()
  result.loadFileString(image)

proc newImage*(): Image =
  result = newImageImpl()

proc newImage*(filename: string): Image =
  result = newImageImpl()
  result.load(filename)

proc newImage*(header: Header, footer: Footer): Image =
  result = newImageImpl()
  result.header = header
  result.footer = footer
  result.pixels = @[]
