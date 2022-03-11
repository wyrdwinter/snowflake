# ----------------------------------------------------------------------------- #
#
# snowflake/utils
#
# A grab-bag of utility procedures, templates, and macros.
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

import std/strutils

# ----------------------------------------------------------------------------- #

proc isRefType[T](value: T): bool =
  var s: string = $(typeof(value))

  s.len > 3 and s[2..<s.len] == "ref"

proc hyphenatedToCamelCase(s: string): string =
  for segment in s.toLowerAscii().split("-"):
    result.add(segment.capitalizeAscii())

  if result.len > 0:
    result[0] = result[0].toLowerAscii()

proc camelCaseToHyphenated*(s: string): string =
  for c in s:
    if c.isUpperAscii():
      result.add("-" & $(c).toLowerAscii())
    else:
      result.add($(c))
