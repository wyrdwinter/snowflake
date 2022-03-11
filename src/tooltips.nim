# ----------------------------------------------------------------------------- #
#
# snowflake/tooltips
#
# Procedures to pull tooltip content from the NWN game files.
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

import std/[tables, strutils]
import neverwinter/[tlk, twoda]
import servers, nwn

# ----------------------------------------------------------------------------- #

type
  Description* = object
    index*: int
    name*: string
    icon*: string
    description*: string

  LookupTable* = Table[Natural, Description]

  Tooltips* = object
    spells*: LookupTable
    skills*: LookupTable
    feats*: LookupTable
    classes*: LookupTable

# ----------------------------------------------------------------------------- #

# Dependencies injected from calling module
var
  tlks*: ref Table[Server, Tlk] = nil
  twoDAs*: ref Table[Server, Table[string, TwoDA]] = nil

# ----------------------------------------------------------------------------- #

proc silentlyQuery2da(server: Server, twoDA: string, row: Natural, column: string): string =
  try:
    result = query2da(server, twoDA, row, column)
  except TwoDAError:
    result = ""

proc silentlyQueryTlk(server: Server, strRef: string): string =
  if strRef == "": return ""

  try:
    result = queryTlk(server, StrRef(strRef.parseInt()))
  except TlkError:
    result = ""

proc tooltips*(server: Server = Server.BaseGame): Tooltips =
  var
    spells: LookupTable = LookupTable()
    skills: LookupTable = LookupTable()
    feats: LookupTable = LookupTable()
    classes: LookupTable = LookupTable()
    s: Server = Server.BaseGame

  proc selectServerWith2da(twoDA: string): Server =
    if twoDAs[server].hasKey(twoDA): result = server
    else: result = Server.BaseGame

  s = selectServerWith2da("spells.2da")

  for i in 0..<twoDAs[s]["spells.2da"].len:
    spells[i] = Description()
    spells[i].index = i
    spells[i].name = silentlyQueryTlk(s, silentlyQuery2da(s, "spells.2da", i, "Name"))
    spells[i].icon = silentlyQuery2da(s, "spells.2da", i, "IconResRef").toLowerAscii()
    spells[i].description = silentlyQueryTlk(s, silentlyQuery2da(s, "spells.2da", i, "SpellDesc"))

  s = selectServerWith2da("skills.2da")

  for i in 0..<twoDAs[s]["skills.2da"].len:
    skills[i] = Description()
    skills[i].index = i
    skills[i].name = silentlyQueryTlk(s, silentlyQuery2da(s, "skills.2da", i, "Name"))
    skills[i].icon = silentlyQuery2da(s, "skills.2da", i, "Icon").toLowerAscii()
    skills[i].description = silentlyQueryTlk(s, silentlyQuery2da(s, "skills.2da", i, "Description"))

  s = selectServerWith2da("feat.2da")

  for i in 0..<twoDAs[s]["feat.2da"].len:
    feats[i] = Description()
    feats[i].index = i
    feats[i].name = silentlyQueryTlk(s, silentlyQuery2da(s, "feat.2da", i, "FEAT"))
    feats[i].icon = silentlyQuery2da(s, "feat.2da", i, "ICON").toLowerAscii()
    feats[i].description = silentlyQueryTlk(s, silentlyQuery2da(s, "feat.2da", i, "DESCRIPTION"))

  s = selectServerWith2da("classes.2da")

  for i in 0..<twoDAs[s]["classes.2da"].len:
    classes[i] = Description()
    classes[i].index = i
    classes[i].name = silentlyQueryTlk(s, silentlyQuery2da(s, "classes.2da", i, "Name"))
    classes[i].icon = silentlyQuery2da(s, "classes.2da", i, "Icon").toLowerAscii()
    classes[i].description = silentlyQueryTlk(s, silentlyQuery2da(s, "classes.2da", i, "Description"))

  result.spells = spells
  result.skills = skills
  result.feats = feats
  result.classes = classes

proc addTooltipsToCharacter*(character: Character, tooltips: Tooltips): Character =
  # This clusterfuck exists because Mustache sucks. Yeah.
  result = character

  for spellbookIndex in 0..<result.spellbooks.len:
    for spellLevel, spellsAtLevel in result.spellbooks[spellbookIndex].spells:
      for i in 0..<spellsAtLevel.len:
        for j in 0..<tooltips.spells.len:
          if spellsAtLevel[i].index == tooltips.spells[j].index:
            result.spellbooks[spellbookIndex].spells[spellLevel][i].tooltipName = tooltips.spells[j].name
            result.spellbooks[spellbookIndex].spells[spellLevel][i].tooltipIcon = tooltips.spells[j].icon
            result.spellbooks[spellbookIndex].spells[spellLevel][i].tooltipDescription = tooltips.spells[j].description

  for i in 0..<result.skills.len:
    for j in 0..<tooltips.skills.len:
      if result.skills[i].index == tooltips.skills[j].index:
        result.skills[i].tooltipName = tooltips.skills[j].name
        result.skills[i].tooltipIcon = tooltips.skills[j].icon
        result.skills[i].tooltipDescription = tooltips.skills[j].description

  for i in 0..<result.feats.len:
    for j in 0..<tooltips.feats.len:
      if result.feats[i].index == tooltips.feats[j].index:
        result.feats[i].tooltipName = tooltips.feats[j].name
        result.feats[i].tooltipIcon = tooltips.feats[j].icon
        result.feats[i].tooltipDescription = tooltips.feats[j].description

  for i in 0..<tooltips.classes.len:
    if tooltips.classes[i].index == int(result.classes.first.index):
      result.classes.first.tooltipName = tooltips.classes[i].name
      result.classes.first.tooltipIcon = tooltips.classes[i].icon
      result.classes.first.tooltipDescription = tooltips.classes[i].description
    elif result.classes.second != nil and
         tooltips.classes[i].index == int(result.classes.second.index):
      result.classes.second.tooltipName = tooltips.classes[i].name
      result.classes.second.tooltipIcon = tooltips.classes[i].icon
      result.classes.second.tooltipDescription = tooltips.classes[i].description
    elif result.classes.third != nil and
         tooltips.classes[i].index == int(result.classes.third.index):
      result.classes.third.tooltipName = tooltips.classes[i].name
      result.classes.third.tooltipIcon = tooltips.classes[i].icon
      result.classes.third.tooltipDescription = tooltips.classes[i].description
