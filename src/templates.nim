# ----------------------------------------------------------------------------- #
#
# snowflake/templates
#
# Metaprogramming to ease the use of the Mustache template library.
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

import std/tables
import mustache
import servers, utils, nwn, tooltips

# ----------------------------------------------------------------------------- #

template defAtomCastValue*(t: typed) {.dirty.} =
  proc castValue*(value: t): Value =
    Value(kind: vkString, vString: $(value))

template defSeqCastValue*(t: typed) {.dirty.} =
  proc castValue*(value: t): Value =
    var sequence: seq[Value] = @[]

    for v in value:
      sequence.add(castValue(v))

    Value(kind: vkSeq, vSeq: sequence)

template defTableCastValue*(t: typed) {.dirty.} =
  proc castValue*(value: t): Value =
    var table = new(Table[string, Value])

    for k, v in value:
      table[$(k)] = castValue(v)

    Value(kind: vkTable, vTable: table)

template defCompositeCastValue*(t: typed) {.dirty.} =
  proc castValue*(value: t): Value =
    var table = new(Table[string, Value])

    for k, v in value.fieldPairs:
      table[camelCaseToHyphenated(k)] = castValue(v)

    Value(kind: vkTable, vTable: table)

template defCompositeCastValueRef*(t: typed) {.dirty.} =
  proc castValue*(value: t): Value =
    var table = new(Table[string, Value])

    if value != nil:
      for k, v in value[].fieldPairs:
        table[camelCaseToHyphenated(k)] = castValue(v)

    Value(kind: vkTable, vTable: table)

template defTupleCastValue*(t: typed) {.dirty.} =
  defCompositeCastValue(t)

template defObjectCastValue*(t: typed) {.dirty.} =
  defCompositeCastValue(t)

template defObjectCastValueRef*(t: typed) {.dirty.} =
  defCompositeCastValueRef(t)

# ----------------------------------------------------------------------------- #

# TODO - might be able to macro this but that sounds like work

# NWN
defAtomCastValue(Server)
defAtomCastValue(CreatureSizeIndex)
defAtomCastValue(FeatIndex)
defAtomCastValue(SexIndex)
defAtomCastValue(RaceIndex)
defAtomCastValue(ClassIndex)
defAtomCastValue(AlignmentIndex)
defAtomCastValue(AlignmentRange)
defAtomCastValue(AbilityIndex)
defAtomCastValue(BaseItemIndex)
defAtomCastValue(ItemPropertyIndex)
defObjectCastValue(Sex)
defObjectCastValue(Race)
defObjectCastValue(Class)
defObjectCastValueRef(ref Class)
defObjectCastValue(Classes)
defObjectCastValue(Alignment)
defObjectCastValue(Experience)
defObjectCastValue(Ability)
defObjectCastValue(Abilities)
defTupleCastValue(HitPointPair)
defObjectCastValue(HitPoints)
defObjectCastValue(ArmorClass)
defObjectCastValue(Armor)
defTupleCastValue(SavingThrowPair)
defObjectCastValue(SavingThrows)
defObjectCastValue(Attacks)
defObjectCastValue(ItemProperty)
defSeqCastValue(seq[ItemProperty])
defObjectCastValue(CriticalRange)
defObjectCastValue(Unarmed)
defObjectCastValueRef(ref Unarmed)
defObjectCastValue(Weapon)
defObjectCastValueRef(ref Weapon)
defObjectCastValue(Metamagic)
defObjectCastValue(Spell)
defSeqCastValue(seq[Spell])
defObjectCastValue(Spellbook)
defSeqCastValue(seq[Spellbook])
defObjectCastValue(Skill)
defSeqCastValue(seq[Skill])
defObjectCastValue(Feat)
defSeqCastValue(seq[Feat])
defObjectCastValue(Level)
defSeqCastValue(seq[Level])
defObjectCastValue(Character)

# Tooltips
defObjectCastValue(Description)
defTableCastValue(LookupTable)
defTableCastValue(ref LookupTable)
defObjectCastValue(Tooltips)
