# ----------------------------------------------------------------------------- #
#
# snowflake/character
#
# Parses and queries a JSON representation of a character's GFF.
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

import std/[json, tables, strutils, strformat, math]
import neverwinter/languages
import nwn, servers

# ----------------------------------------------------------------------------- #

proc `v`(json: JsonNode, keys: varargs[string]): JsonNode =
  result = json

  for k in keys:
    result = result[k]["value"]

proc parseExoLocString(json: JsonNode, server: Server): string =
  if json.hasKey("id"):
    result = queryTlk(server, StrRef(json["id"].getInt()))
  elif json["value"].getFields().len > 0:
    # Assume English - therefore, we only care about key 0.
    result = json["value"]["0"].getStr()

# ----------------------------------------------------------------------------- #

proc itemProperty(jsonItemProperty: JsonNode, server: Server = Server.BaseGame): ItemProperty =
  proc hasSubtype(index: StrRef): bool =
    result = true

    try:
      discard query2da(server, "itempropdef.2da", index, "SubTypeResRef")
    except TwoDAError:
      result = false

  proc hasCost(): bool =
    jsonItemProperty.v("CostTable").getInt() != 255 and jsonItemProperty.v("CostValue").getInt() != 65535

  proc hasParam(): bool =
    jsonItemProperty.v("Param1").getInt() != 255 and jsonItemProperty.v("Param1Value").getInt() != 255

  proc hasParamResRef(index: StrRef): bool =
    result = true

    try:
      discard query2da(server, "itempropdef.2da", index, "Param1ResRef")
    except TwoDAError:
      result = false

  let
    index: StrRef = StrRef(jsonItemProperty.v("PropertyName").getInt())
    nameIndex: StrRef = StrRef(query2da(server, "itempropdef.2da", index, "Name").parseInt())
    name: string = queryTlk(server, nameIndex)

  result.index = int(index)
  result.name = name

  if hasSubtype(index):
    let
      subtypeIndex: StrRef = StrRef(jsonItemProperty.v("Subtype").getInt())
      subtype2da: string = query2da(server, "itempropdef.2da", index, "SubTypeResRef").toLowerAscii() & ".2da"
      subtypeNameIndex: StrRef = StrRef(query2da(server, subtype2da, subtypeIndex, "Name").parseInt())

    result.subtypeName = queryTlk(server, subtypeNameIndex)

  if hasCost():
    let
      costValueIndex: StrRef = StrRef(jsonItemProperty.v("CostValue").getInt())
      costTableIndex: Natural = query2da(server, "itempropdef.2da", index, "CostTableResRef").parseInt()
      costTable2da: string = query2da(server, "iprp_costtable.2da", costTableIndex, "Name").toLowerAscii() & ".2da"

    if costTable2da == "iprp_base1.2da":
      # seriously, bioware, what the fuck
      result.costValue = ""
    else:
      let costTableNameIndex: StrRef = StrRef(query2da(server, costTable2da, costValueIndex, "Name").parseInt())

      result.costValue = queryTlk(server, costTableNameIndex)

  if hasParam():
    let
      paramIndex: StrRef = StrRef(jsonItemProperty.v("Param1").getInt())
      paramValueIndex: StrRef = StrRef(jsonItemProperty.v("Param1Value").getInt())

    var paramTableIndex: Natural = 0
    if hasParamResRef(index):
      paramTableIndex = query2da(server, "itempropdef.2da", index, "Param1ResRef").parseInt()
    else:
      paramTableIndex = paramIndex

    let
      paramTable2da: string = query2da(server, "iprp_paramtable.2da", paramTableIndex, "TableResRef").toLowerAscii() & ".2da"
      paramTableNameIndex: StrRef = StrRef(query2da(server, paramTable2da, paramValueIndex, "Name").parseInt())

    result.paramValue = queryTlk(server, paramTableNameIndex)

proc baseArmorClass(armor: JsonNode, server: Server = Server.BaseGame): int =
  proc itemTag(item: JsonNode): string =
    item.v("Tag").getStr()

  proc sinfarCraftedItem(armor: JsonNode): bool =
    const CraftedItemPrefix: string = "I_CRAFT"
    let tag: string = itemTag(armor)

    tag.len >= CraftedItemPrefix.len and
    tag[0..<CraftedItemPrefix.len] == CraftedItemPrefix

  if server == Server.Sinfar:
    # The armor AC is revealed in the tag.
    # "Tag": {
    #   "type": "cexostring",
    #   "value": "I_CRAFT_I_16_0_ENCHANTED"
    # },
    #
    # Where the format is: I_CRAFT_I_<BASEITEM>_<BASEAC>_ENCHANTED
    # - BASEITEM = 16, i.e. armor
    # - BASEAC = 0..8
    #
    # The dexterity bonus can be derived from this.
    #
    # Still unclear how the Sinfar armor system works as a whole.
    # Perhaps custom NWNX function to set base AC value dynamically
    # according to the tag.
    #
    # Unclear how this interacts with the
    # presentation layer, i.e. the interface correctly displays
    # armors as unusable even though everything is apparently
    # cloth according to parts_chest.2da.
    if sinfarCraftedItem(armor):
      result = itemTag(armor).split("_")[4].parseInt()
    else:
      # Most likely a 'new player outfit' or something we otherwise don't
      # know about. AC 0.
      result = 0
  else:
    let
      chestAppearanceIndex: StrRef = StrRef(armor.v("ArmorPart_Torso").getInt())
      armorBonus: int = int(query2da(server, "parts_chest.2da", chestAppearanceIndex, "ACBONUS").parseFloat().floor())

    result = armorBonus

# ----------------------------------------------------------------------------- #

proc damageSummary(character: JsonNode, weapon: Weapon | ref Weapon, offhand: bool = false): string =
  if not character.hasKey("CombatInfo"):
    return "Unknown"

  let
    baseDamageLower: int = weapon.damageDice
    baseDamageUpper: int = weapon.damageDice * weapon.damageDie

  var
    damageModifier: int = 0
    criticalRangeUpper: int = 20
    criticalRangeLower: int = 0
    criticalMultiplier: int = 0

  if offhand:
    damageModifier = character.v("CombatInfo", "OffHandDamageMod").getInt()
    criticalRangeLower = criticalRangeUpper - character.v("CombatInfo", "OffHandCritRng").getInt() + 1
    criticalMultiplier = character.v("CombatInfo", "OffHandCritMult").getInt()
  else:
    damageModifier = character.v("CombatInfo", "OnHandDamageMod").getInt()
    criticalRangeLower = criticalRangeUpper - character.v("CombatInfo", "OnHandCritRng").getInt() + 1
    criticalMultiplier = character.v("CombatInfo", "OnHandCritMult").getInt()

  fmt("{baseDamageLower}-{baseDamageUpper} + {damageModifier} (Critical: {criticalRangeLower}-{criticalRangeUpper} / x{criticalMultiplier})")

proc damageSummary(character: JsonNode, unarmed: Unarmed | ref Unarmed): string =
  let
    baseDamageLower: int = unarmed.damageDice
    baseDamageUpper: int = unarmed.damageDice * unarmed.damageDie

  fmt("{baseDamageLower}-{baseDamageUpper} + {unarmed.damageModifier} (Critical: {unarmed.criticalRange.lower}-{unarmed.criticalRange.upper}/x{unarmed.criticalMultiplier})")

# ----------------------------------------------------------------------------- #

proc hasFeat(character: JsonNode, featIndex: FeatIndex | int): bool =
  for feat in character.v("FeatList"):
    if feat.v("Feat").getInt() == int(featIndex):
      result = true

proc hasClass(character: JsonNode, classIndex: ClassIndex | int): bool =
  for class in character.v("ClassList"):
    if class.v("Class").getInt() == int(classIndex):
      result = true

# ----------------------------------------------------------------------------- #

proc abilityScore(character: JsonNode, abilityIndex: AbilityIndex): int =
  case abilityIndex:
    of AbilityIndex.Strength: result = character.v("Str").getInt()
    of AbilityIndex.Dexterity: result = character.v("Dex").getInt()
    of AbilityIndex.Constitution: result = character.v("Con").getInt()
    of AbilityIndex.Intelligence: result = character.v("Int").getInt()
    of AbilityIndex.Wisdom: result = character.v("Wis").getInt()
    of AbilityIndex.Charisma: result = character.v("Cha").getInt()
    else: result = -1

proc gearedAbilityScore(character: JsonNode, abilityIndex: AbilityIndex, server: Server = Server.BaseGame): int =
  let
    baseAbilityScore = abilityScore(character, abilityIndex)
    equippedItems = character.v("Equip_ItemList")

  var totalAbilityIncrease: int = 0

  for item in equippedItems:
    if item.hasKey("PropertiesList"):
      for jsonItemProperty in item.v("PropertiesList"):
        let property = itemProperty(jsonItemProperty, server)

        if property.index == int(ItemPropertyIndex.PropAbility):
          # Chop off leading character and convert, e.g. "+6" -> 6
          let abilityIncrease = property.costValue[1..<property.costValue.len].parseInt()

          if property.subtypeName == AbilityTable[abilityIndex]:
            totalAbilityIncrease += abilityIncrease

  baseAbilityScore + totalAbilityIncrease

proc abilityScoreModifier(abilityScore: int): int =
  int((abilityScore - 10) / 2)

proc raciallyModifiedAbility(ability: Ability, race: Race): Ability =
  proc adjust(ability: Ability, amount: int): Ability =
    result = ability

    result.base += amount
    result.geared += amount
    result.modifier += int(amount / 2)

  result = ability

  case race.index:
    of RaceIndex.Dwarf:
      case ability.index:
        of AbilityIndex.Constitution: result = adjust(ability, 2)
        of AbilityIndex.Charisma: result = adjust(ability, -2)
        else: discard
    of RaceIndex.Elf:
      case ability.index:
        of AbilityIndex.Dexterity: result = adjust(ability, 2)
        of AbilityIndex.Constitution: result = adjust(ability, -2)
        else: discard
    of RaceIndex.Gnome:
      case ability.index:
        of AbilityIndex.Constitution: result = adjust(ability, 2)
        of AbilityIndex.Strength: result = adjust(ability, -2)
        else: discard
    of RaceIndex.Halfling:
      case ability.index:
        of AbilityIndex.Dexterity: result = adjust(ability, 2)
        of AbilityIndex.Strength: result = adjust(ability, -2)
        else: discard
    of RaceIndex.HalfOrc:
      case ability.index:
        of AbilityIndex.Strength: result = adjust(ability, 2)
        of AbilityIndex.Intelligence: result = adjust(ability, -2)
        of AbilityIndex.Charisma: result = adjust(ability, -2)
        else: discard
    else: discard

proc raciallyModifiedAbilities(abilities: Abilities, race: Race): Abilities =
  result = abilities

  for k, v in result.fieldPairs:
    v = raciallyModifiedAbility(v, race)

# ----------------------------------------------------------------------------- #

proc alignmentFromDimensions(positionLawChaos: AlignmentRange, positionGoodEvil: AlignmentRange): AlignmentIndex =
  case positionLawChaos
    of 70..100:
      case positionGoodEvil
        of 70..100: result = AlignmentIndex.LawfulGood
        of 31..69: result = AlignmentIndex.LawfulNeutral
        of 0..30: result = AlignmentIndex.LawfulEvil
    of 31..69:
      case positionGoodEvil
        of 70..100: result = AlignmentIndex.NeutralGood
        of 31..69: result = AlignmentIndex.TrueNeutral
        of 0..30: result = AlignmentIndex.NeutralEvil
    of 0..30:
      case positionGoodEvil
        of 70..100: result = AlignmentIndex.ChaoticGood
        of 31..69: result = AlignmentIndex.ChaoticNeutral
        of 0..30: result = AlignmentIndex.ChaoticEvil

proc alignmentTitleFromDimensions(positionLawChaos: AlignmentRange, positionGoodEvil: AlignmentRange): string =
  case positionLawChaos
    of 100:
      case positionGoodEvil:
        of 100: result = "Crusader"
        of 50: result = "Judge"
        of 0: result = "Dominator"
        else: result = ""
    of 50:
      case positionGoodEvil:
        of 100: result = "Benefactor"
        of 50: result = "Reconciler"
        of 0: result = "Malefactor"
        else: result = ""
    of 0:
      case positionGoodEvil:
        of 100: result = "Rebel"
        of 50: result = "Free Spirit"
        of 0: result = "Destroyer"
        else: result = ""
    else: result = ""

# ----------------------------------------------------------------------------- #

proc weaponById(character: JsonNode, id: int, server: Server = Server.BaseGame): ref Weapon =
  let equippedItems: JsonNode = character.v("Equip_ItemList")
  var jsonWeapon: JsonNode = nil

  # Find Weapon

  for item in equippedItems:
    if item.v("ObjectId").getInt() == id:
      jsonWeapon = item

  if jsonWeapon != nil:
    result = new(Weapon)

    result.id = id
    result.name = (if jsonWeapon.hasKey("DisplayName"): jsonWeapon.v("DisplayName").getStr() else: parseExoLocString(jsonWeapon["LocalizedName"], server))
    result.baseItemIndex = jsonWeapon.v("BaseItem").getInt()
    result.baseItemName = queryTlk(server, StrRef(query2da(server, "baseitems.2da", result.baseItemIndex, "Name").parseInt()))
    result.size = WeaponSizeTable[query2da(server, "baseitems.2da", result.baseItemIndex, "WeaponSize").parseInt()]
    result.damageDie = query2da(server, "baseitems.2da", result.baseItemIndex, "DieToRoll").parseInt()
    result.damageDice = query2da(server, "baseitems.2da", result.baseItemIndex, "NumDice").parseInt()
    result.criticalRange.lower = 20 - query2da(server, "baseitems.2da", result.baseItemIndex, "CritThreat").parseInt() + 1
    result.criticalRange.upper = 20
    result.criticalMultiplier = query2da(server, "baseitems.2da", result.baseItemIndex, "CritHitMult").parseInt()

    for jsonWeaponProperty in jsonWeapon.v("PropertiesList"):
      result.properties.add(itemProperty(jsonWeaponProperty, server))

proc mainWeapon(character: JsonNode, server: Server = Server.BaseGame): ref Weapon =
  result = weaponById(character, character.v("CombatInfo", "RightEquip").getInt(), server)

proc offhandWeapon(character: JsonNode, server: Server = Server.BaseGame): ref Weapon =
  result = weaponById(character, character.v("CombatInfo", "LeftEquip").getInt(), server)

proc armorDexterityBonus(character: JsonNode, server: Server = Server.BaseGame): int =
  let equippedItems: JsonNode = character.v("Equip_ItemList")
  var armor: JsonNode = nil

  for item in equippedItems:
    if item.hasKey("BaseItem") and item.v("BaseItem").getInt() == int(BaseItemIndex.Armor):
      armor = item

  if armor != nil:
    result = query2da(server, "armor.2da", baseArmorClass(armor, server), "DEXBONUS").parseInt()
  else:
    result = -1

proc unarmed(character: JsonNode, server: Server = Server.BaseGame): ref Unarmed =
  result = new(Unarmed)

  let
    creatureSize: int = character.v("CreatureSize").getInt()
    equippedItems: JsonNode = character.v("Equip_ItemList")

  var
    race: Race = Race()
    str: Ability = Ability()
    monkLevels: int = 0
    jsonGloves: JsonNode = nil

  race.index = RaceIndex(character.v("Race").getInt())

  str.base = abilityScore(character, AbilityIndex.Strength)
  str.geared = gearedAbilityScore(character, AbilityIndex.Strength, server)
  str.modifier = abilityScoreModifier(str.geared)
  str = raciallyModifiedAbility(str, race)

  for class in character.v("ClassList"):
    if class.v("Class").getInt() == int(ClassIndex.Monk):
      monkLevels = class.v("ClassLevel").getInt()

  result.damageDice = 1

  case creatureSize
    of int(CreatureSizeIndex.Small):
      if monkLevels >= 16: result.damageDice = 2

      case monkLevels
        of 1..3: result.damageDie = 4
        of 4..7: result.damageDie = 6
        of 8..11: result.damageDie = 8
        of 12..15: result.damageDie = 10
        of 16..40: result.damageDie = 6
        else: result.damageDie = 2
    of int(CreatureSizeIndex.Medium):
      case monkLevels
        of 1..3: result.damageDie = 6
        of 4..7: result.damageDie = 8
        of 8..11: result.damageDie = 10
        of 12..15: result.damageDie = 12
        of 16..40: result.damageDie = 20
        else: result.damageDie = 3
    else: raise newException(GffError, "Invalid character size")

  if hasFeat(character, FeatIndex.ImprovedCriticalUnarmedStrike):
    result.criticalRange.lower = 19
  else:
    result.criticalRange.lower = 20

  result.criticalRange.upper = 20

  result.criticalMultiplier = 2
  result.damageModifier = str.modifier

  if hasFeat(character, FeatIndex.WeaponSpecializationUnarmedStrike):
    result.damageModifier += 2
  if hasFeat(character, FeatIndex.EpicWeaponSpecializationUnarmedStrike):
    result.damageModifier += 4

  result.damageSummary = damageSummary(character, result)

  for item in equippedItems:
    if item.v("BaseItem").getInt() == int(BaseItemIndex.Gloves):
      jsonGloves = item

  if jsonGloves != nil:
    for jsonGlovesProperty in jsonGloves.v("PropertiesList"):
      result.glovesProperties.add(itemProperty(jsonGlovesProperty, server))

# ----------------------------------------------------------------------------- #

proc mainAttacksModifier(character: JsonNode): int =
  for attack in character.v("CombatInfo", "AttackList"):
    if attack.v("WeaponWield").getInt() == int(WeaponWield.Main):
      return attack.v("Modifier").getInt()

proc offhandAttacksModifier(character: JsonNode): int =
  for attack in character.v("CombatInfo", "AttackList"):
    if attack.v("WeaponWield").getInt() == int(WeaponWield.Offhand):
      return attack.v("Modifier").getInt()

proc baseAttackBonus(character: JsonNode): int =
  if character.hasKey("BaseAttackBonus"):
    result = character.v("BaseAttackBonus").getInt()
  else:
    result = 0

proc baseAttackBonusAtLevel(character: JsonNode, level: int): int =
  var classes = Classes()

  for i in 0..<level:
    var
      levelStats = character.v("LvlStatList")[i]
      class = levelStats.v("LvlStatClass").getInt()

    for field in classes.fields:
      if field == nil:
        field = new(Class)
        field.index = class
        field.levels = 1
        break

      if int(field.index) == class:
        field.levels += 1
        break

  for field in classes.fields:
    if field != nil:
      case BaseAttackProgression[field.index]:
        of ClassBAB.Full: result += field.levels
        of ClassBAB.ThreeQuarters: result += int(0.75 * float(field.levels))
        of ClassBAB.Half: result += int(0.5 * float(field.levels))

proc mainLeadingAttackBonus(character: JsonNode): int =
  let
    mainAttackMod: int = character.v("CombatInfo", "OnHandAttackMod").getInt()
    baseAttackBonus: int = baseAttackBonus(character)

  result = baseAttackBonus + mainAttackMod

proc offhandLeadingAttackBonus(character: JsonNode): int =
  let
    offhandAttackMod: int = character.v("CombatInfo", "OffHandAttackMod").getInt()
    baseAttackBonus: int = baseAttackBonus(character)

  result = baseAttackBonus + offHandAttackMod

proc unarmedLeadingAttackBonus(character: JsonNode, server: Server = Server.BaseGame): int =
  result = baseAttackBonus(character)

  var
    race: Race = Race()
    str: Ability = Ability()
    dex: Ability = Ability()

  race.index = RaceIndex(character.v("Race").getInt())

  str.index = AbilityIndex.Strength
  str.base = abilityScore(character, AbilityIndex.Strength)
  str.geared = gearedAbilityScore(character, AbilityIndex.Strength, server)
  str.modifier = abilityScoreModifier(str.geared)
  str = raciallyModifiedAbility(str, race)

  dex.index = AbilityIndex.Dexterity
  dex.base = abilityScore(character, AbilityIndex.Dexterity)
  dex.geared = gearedAbilityScore(character, AbilityIndex.Dexterity, server)
  dex.modifier = abilityScoreModifier(dex.geared)
  dex = raciallyModifiedAbility(dex, race)

  if hasFeat(character, FeatIndex.WeaponFinesse) and dex.modifier > str.modifier:
    result += dex.modifier
  else:
    result += str.modifier

  if hasFeat(character, FeatIndex.WeaponFocusUnarmedStrike): result += 1
  if hasFeat(character, FeatIndex.EpicProwess): result += 1
  if hasFeat(character, FeatIndex.EpicWeaponFocusUnarmedStrike): result += 2

proc numAttacks(character: JsonNode): int =
  let maxLevel: int = character.v("LvlStatList").len
  var baseAttackBonus: int = 0

  if maxLevel > 20:
    baseAttackBonus = baseAttackBonusAtLevel(character, 20)
  else:
    baseAttackBonus = baseAttackBonusAtLevel(character, maxLevel)

  if baseAttackBonus == 20:
    result = 4
  else:
    result = int(baseAttackBonus / 4)

proc mainNumAttacks(character: JsonNode): int =
  result = character.v("CombatInfo", "NumAttacks").getInt()

proc offhandNumAttacks(character: JsonNode): int =
  if hasFeat(character, FeatIndex.ImprovedTwoWeaponFighting):
    result = 2
  else:
    result = 1

proc unarmedNumAttacks(character: JsonNode): int =
  if hasClass(character, ClassIndex.Monk):
    let maxLevel: int = character.v("LvlStatList").len
    var baseAttackBonus: int = 0

    if maxLevel > 20:
      baseAttackBonus = baseAttackBonusAtLevel(character, 20)
    else:
      baseAttackBonus = baseAttackBonusAtLevel(character, maxLevel)

    case baseAttackBonus:
      of 0..3: result = 1
      of 4..6: result = 2
      of 7..9: result = 3
      of 10..12: result = 4
      of 13..15: result = 5
      of 16..20: result = 6
      else: discard
  else:
    result = numAttacks(character)

proc mainAttackBonuses(character: JsonNode, server: Server = Server.BaseGame): seq[int] =
  let
    mainAttacksModifier: int = mainAttacksModifier(character)
    mainWeapon: ref Weapon = mainWeapon(character, server)
    leadingAttackBonus: int = mainLeadingAttackBonus(character)

  var
    numAttacks: int = 0
    adjustment: int = 0

  if hasClass(character, ClassIndex.Monk) and
     mainWeapon != nil and
     mainWeapon.baseItemIndex == int(BaseItemIndex.Kama):
    numAttacks = unarmedNumAttacks(character)
    adjustment = 3
  else:
    numAttacks = numAttacks(character)
    adjustment = 5

  for attack in 0..<numAttacks:
    result.add(leadingAttackBonus + mainAttacksModifier - (attack * adjustment))

proc offhandAttackBonuses(character: JsonNode, server: Server = Server.BaseGame): seq[int] =
  let
    offhandAttacksModifier: int = offhandAttacksModifier(character)
    mainWeapon: ref Weapon = mainWeapon(character, server)
    offhandWeapon: ref Weapon = offhandWeapon(character, server)
    leadingAttackBonus: int = offhandLeadingAttackBonus(character)

  var
    numAttacks: int = 1
    adjustment: int = 5

  if hasFeat(character, FeatIndex.ImprovedTwoWeaponFighting):
    numAttacks = 2

  if hasClass(character, ClassIndex.Monk) and mainWeapon.baseItemIndex == int(BaseItemIndex.Kama):
    adjustment = 3

  for attack in 0..<numAttacks:
    result.add(leadingAttackBonus + offhandAttacksModifier - (attack * adjustment))

proc unarmedAttackBonuses(character: JsonNode, server: Server = Server.BaseGame): seq[int] =
  let
    leadingAB: int = unarmedLeadingAttackBonus(character, server)
    numAttacks: int = unarmedNumAttacks(character)

  var reduction: int = 0

  if hasClass(character, ClassIndex.Monk):
    reduction = 3
  else:
    reduction = 5

  for i in 0..<numAttacks:
    result.add(leadingAB - (i * reduction))

proc spontaneousCasterClass(class: JsonNode, server: Server = Server.BaseGame): bool =
  let classIndex: int = class.v("Class").getInt()

  int(classIndex) in SpontaneousCasterClasses

proc preparedCasterClass(class: JsonNode, server: Server = Server.BaseGame): bool =
  let classIndex: int = class.v("Class").getInt()

  int(classIndex) in PreparedCasterClasses

# ----------------------------------------------------------------------------- #

proc jsonToCharacter*(json: JsonNode, server: Server = Server.BaseGame): Character =
  result.firstName = parseExoLocString(json["FirstName"], server)
  result.lastName = parseExoLocString(json["LastName"], server)

  result.race.index = RaceIndex(json.v("Race").getInt())
  result.race.name = queryTlk(server, StrRef(query2da(server, "racialtypes.2da", Natural(result.race.index), "Name").parseInt()))
  result.subrace = json.v("Subrace").getStr()
  result.sex.index = SexIndex(json.v("Gender").getInt())
  result.sex.name = queryTlk(server, StrRef(query2da(server, "gender.2da", Natural(result.sex.index), "Name").parseInt()))
  result.alignment.positionLawChaos = json.v("LawfulChaotic").getInt()
  result.alignment.positionGoodEvil = json.v("GoodEvil").getInt()
  result.alignment.index = alignmentFromDimensions(result.alignment.positionLawChaos, result.alignment.positionGoodEvil)
  result.alignment.title = alignmentTitleFromDimensions(result.alignment.positionLawChaos, result.alignment.positionGoodEvil)
  result.alignment.name = queryTlk(server, StrRef(query2da(server, "iprp_alignment.2da", Natural(result.alignment.index), "Name").parseInt()))
  result.experience.current = json.v("Experience").getInt()
  result.experience.nextLevel = nextLevelXP(json.v("LvlStatList").len)
  result.experience.maxLevel = json.v("LvlStatList").len == 40

  for k, v in result.abilities.fieldPairs:
    case k:
      of "strength": v.index = AbilityIndex.Strength
      of "dexterity": v.index = AbilityIndex.Dexterity
      of "constitution": v.index = AbilityIndex.Constitution
      of "intelligence": v.index = AbilityIndex.Intelligence
      of "wisdom": v.index = AbilityIndex.Wisdom
      of "charisma": v.index = AbilityIndex.Charisma
      else: discard

    v.name = queryTlk(server, StrRef(query2da(server, "iprp_abilities.2da", Natural(v.index), "Name").parseInt()))
    v.base = abilityScore(json, v.index)
    v.geared = gearedAbilityScore(json, v.index, server)
    v.modifier = abilityScoreModifier(v.geared)
    v.gearedIncreaseColored = v.geared > v.base
    v.gearedDecreaseColored = v.geared < v.base

    v.modifierIncreaseColored = v.gearedIncreaseColored
    v.modifierDecreaseColored = v.gearedDecreaseColored

  result.abilities = raciallyModifiedAbilities(result.abilities, result.race)

  let armorDexBonus: int = armorDexterityBonus(json, server)
  if armorDexBonus >= 0 and result.abilities.dexterity.modifier > armorDexBonus:
    result.abilities.dexterity.modifier = armorDexBonus
    result.abilities.dexterity.modifierIncreaseColored = false
    result.abilities.dexterity.modifierDecreaseColored = true

  # result.hitPoints.base =
  result.hitPoints.total = (0, 0)
  result.hitPoints.total.current = json.v("PregameCurrent").getInt()
  result.hitPoints.total.maximum = json.v("MaxHitPoints").getInt()
  result.armor.armorClass.total = json.v("ArmorClass").getInt()
  if json.hasKey("CombatInfo"):
    result.armor.arcaneSpellFailure = json.v("CombatInfo", "ArcaneSpellFail").getInt()
    result.armor.checkPenalty = json.v("CombatInfo", "ArmorCheckPen").getInt()
    result.spellResistance = json.v("CombatInfo", "SpellResistance").getInt()
  result.savingThrows.fortitude = (0, 0)
  result.savingThrows.reflex = (0, 0)
  result.savingThrows.will = (0, 0)
  # result.savingThrows.fortitude.base =
  # result.savingThrows.reflex.base =
  # result.savingThrows.will.base =
  result.savingThrows.fortitude.total = json.v("FortSaveThrow").getInt()
  result.savingThrows.reflex.total = json.v("RefSaveThrow").getInt()
  result.savingThrows.will.total = json.v("WillSaveThrow").getInt()
  result.attacks.baseAttackBonus = baseAttackBonus(json)

  # Spellbooks

  const MaxSpellLevel: int = 9

  proc undefinedSpell(spell: JsonNode): bool =
    spell.v("Spell").getInt() == 65535

  proc preparedSpellbook(class: JsonNode): Spellbook =
    let
      classIndex: StrRef = StrRef(class.v("Class").getInt())
      classNameIndex: StrRef = StrRef(query2da(server, "classes.2da", classIndex, "Name").parseInt())
      className: string = queryTlk(server, classNameIndex)

    result = Spellbook(class: className, spells: initTable[SpellLevel, seq[Spell]]())

    for i in 0..MaxSpellLevel:
      if class{"MemorizedList" & $(i)} != nil:
        result.spells[$(i)] = @[]

        for spell in class.v("MemorizedList" & $(i)):
          if undefinedSpell(spell):
            continue

          let
            spellIndex: StrRef = StrRef(spell.v("Spell").getInt())
            spellNameIndex: StrRef = StrRef(query2da(server, "spells.2da", spellIndex, "Name").parseInt())
            spellName: string = queryTlk(server, spellNameIndex)
            spellMetamagicIndex: StrRef = StrRef(MetamagicIndex[spell.v("SpellMetaMagic").getInt()])
            spellMetamagicNameIndex: StrRef = StrRef(query2da(server, "metamagic.2da", spellMetamagicIndex, "Name").parseInt())
            spellMetamagicName: string = queryTlk(server, spellMetamagicNameIndex)
            spellMetamagic: Metamagic = Metamagic(index: int(spellMetamagicIndex), name: spellMetamagicName)
            spellReady: bool = bool(spell.v("Ready").getInt())

          result.spells[$(i)].add(Spell(index: int(spellIndex), name: spellName, metamagic: spellMetamagic, ready: spellReady))

  proc spontaneousSpellbook(class: JsonNode): Spellbook =
    let
      classIndex: StrRef = StrRef(class.v("Class").getInt())
      classNameIndex: StrRef = StrRef(query2da(server, "classes.2da", classIndex, "Name").parseInt())
      className: string = queryTlk(server, classNameIndex)

    result = Spellbook(class: className, spells: initTable[SpellLevel, seq[Spell]](), spontaneous: true)

    for i in 0..MaxSpellLevel:
      if class{"KnownList" & $(i)} != nil:
        result.spells[$(i)] = @[]

        for spell in class.v("KnownList" & $(i)):
          if undefinedSpell(spell):
            continue

          let
            spellIndex: StrRef = StrRef(spell.v("Spell").getInt())
            spellNameIndex: StrRef = StrRef(query2da(server, "spells.2da", spellIndex, "Name").parseInt())
            spellName: string = queryTlk(server, spellNameIndex)

          result.spells[$(i)].add(Spell(index: int(spellIndex), name: spellName))

  proc parseSpellbook(class: JsonNode): Spellbook =
    if spontaneousCasterClass(class, server):
      result = spontaneousSpellbook(class)
    elif preparedCasterClass(class, server):
      result = preparedSpellbook(class)

  for class in json.v("ClassList"):
    let spellbook: Spellbook = parseSpellbook(class)

    if spellbook.spells.len > 0:
      result.spellbooks.add(spellbook)

  # Skills

  for i in 0..<json.v("SkillList").len:
    let
      skillIndex: StrRef = StrRef(i)
      skillNameIndex: StrRef = StrRef(query2da(server, "skills.2da", skillIndex, "Name").parseInt())
      skillName: string = queryTlk(server, skillNameIndex)
      skillRank: int = json.v("SkillList")[i].v("Rank").getInt()

    result.skills.add(Skill(index: int(skillIndex), name: skillName, rank: skillRank))

  # Feats

  for f in json.v("FeatList"):
    let
      featIndex: StrRef = StrRef(f.v("Feat").getInt())
      featNameIndex: StrRef = StrRef(query2da(server, "feat.2da", featIndex, "FEAT").parseInt())
      featName: string = queryTlk(server, featNameIndex)

    result.feats.add(Feat(index: int(featIndex), name: featName))

  # Level History

  let levelStatList: JsonNode = json.v("LvlStatList")
  for i in 0..<len(levelStatList):
    let
      jsonLevel: JsonNode = levelStatList[i]
      classIndex: int = jsonLevel.v("LvlStatClass").getInt()
      classNameIndex: StrRef = StrRef(query2da(server, "classes.2da", classIndex, "Name").parseInt())
      className: string = queryTlk(server, classNameIndex)
      hitDie: int = jsonLevel.v("LvlStatHitDie").getInt()
      availableSkillPoints: int = jsonLevel.v("SkillPoints").getInt()
      abilityIncreaseIndex: AbilityIndex = AbilityIndex(if jsonLevel{"LvlStatAbility"} != nil: jsonLevel.v("LvlStatAbility").getInt() else: -1)
      abilityIncreaseName: string = (if abilityIncreaseIndex >= AbilityIndex(0): AbilityTable[abilityIncreaseIndex] else: "")

    var level: Level = Level()

    level.index = i + 1
    level.class = Class()
    level.class.index = classIndex
    level.class.name = className
    level.hitDie = hitDie
    level.abilityIncrease = Ability()
    level.abilityIncrease.index = abilityIncreaseIndex
    level.abilityIncrease.name = abilityIncreaseName
    level.availableSkillPoints = availableSkillPoints
    level.skillIncreases = @[]
    level.feats = @[]

    for skillIndex in 0..<len(jsonLevel.v("SkillList")):
      let
        skillNameIndex: StrRef = StrRef(query2da(server, "skills.2da", skillIndex, "Name").parseInt())
        skillName: string = queryTlk(server, skillNameIndex)
        skillRank: int = jsonLevel.v("SkillList")[skillIndex].v("Rank").getInt()

      if skillRank > 0:
        level.skillIncreases.add(Skill(index: skillIndex, name: skillName, rank: skillRank))

    for feat in jsonLevel.v("FeatList"):
      let
        featIndex: StrRef = StrRef(feat.v("Feat").getInt())
        featNameIndex: StrRef = StrRef(query2da(server, "feat.2da", featIndex, "FEAT").parseInt())
        featName: string = queryTlk(server, featNameIndex)

      level.feats.add(Feat(index: int(featIndex), name: featName))

    result.levelHistory.add(level)

  # Class List

  for level in result.levelHistory:
    for field in result.classes.fields:
      if field == nil:
        field = new(Class)
        field.index = level.class.index
        field.name = level.class.name
        field.levels = 1
        break

      if field.index == level.class.index:
        field.levels += 1
        break

  if json.hasKey("CombatInfo"):
    # Dual-Wielding Check

    let offhandWeaponEquipped: int = json.v("CombatInfo", "OffHandWeaponEq").getInt()

    # Attacks

    let jsonAttackList = json.v("CombatInfo", "AttackList")

    result.attacks.mainModifier = mainAttacksModifier(json)
    result.attacks.offhandModifier = offhandAttacksModifier(json)

    result.attacks.unarmedLeadingAttackBonus = unarmedLeadingAttackBonus(json, server)
    result.attacks.unarmedNumAttacks = unarmedNumAttacks(json)
    result.attacks.unarmedAttackBonuses = unarmedAttackBonuses(json, server)

    result.attacks.mainLeadingAttackBonus = mainLeadingAttackBonus(json)
    result.attacks.mainNumAttacks = mainNumAttacks(json)
    result.attacks.mainAttackBonuses = mainAttackBonuses(json, server)

    if offHandWeaponEquipped == 1:
      result.attacks.offhandLeadingAttackBonus = offhandLeadingAttackBonus(json)
      result.attacks.offhandNumAttacks = offhandNumAttacks(json)
      result.attacks.offhandAttackBonuses = offhandAttackBonuses(json, server)

    result.unarmedStrike = unarmed(json, server)

    # Weapons

    result.mainWeapon = mainWeapon(json, server)

    if result.mainWeapon != nil:
      result.mainWeapon.damageModifier = json.v("CombatInfo", "OnHandDamageMod").getInt()
      result.mainWeapon.damageSummary = damageSummary(json, result.mainWeapon)

      if offHandWeaponEquipped == 1:
        result.offhandWeapon = offhandWeapon(json, server)

        if result.offhandWeapon != nil:
          result.offhandWeapon.damageModifier = json.v("CombatInfo", "OffHandDamageMod").getInt()
          result.offhandWeapon.damageSummary = damageSummary(json, result.offhandWeapon, true)
