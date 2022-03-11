# ----------------------------------------------------------------------------- #
#
# snowflake/nwn
#
# Types and procedures that relate to NWN's core game files and file formats.
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

import std/[tables, options]
import neverwinter/[tlk, twoda]

import servers

# ----------------------------------------------------------------------------- #

type
  CreatureSizeIndex* {.pure.} = enum
    Invalid = 0,
    Tiny = 1,
    Small = 2,
    Medium = 3,
    Large = 4,
    Huge = 5

  FeatIndex* {.pure.} = enum
    ImprovedTwoWeaponFighting = 20,
    WeaponFinesse = 42,
    ImprovedCriticalUnarmedStrike = 62,
    WeaponFocusUnarmedStrike = 100,
    WeaponSpecializationUnarmedStrike = 138,
    EpicProwess = 584,
    EpicWeaponFocusUnarmedStrike = 630,
    EpicWeaponSpecializationUnarmedStrike = 668

  SexIndex* {.pure.} = enum
    Male = 0,
    Female = 1

  Sex* = object
    index*: SexIndex
    name*: string

  RaceIndex* {.pure.} = enum
    Dwarf = 0,
    Elf = 1,
    Gnome = 2,
    Halfling = 3,
    HalfElf = 4,
    HalfOrc = 5,
    Human = 6

  Race* = object
    index*: RaceIndex
    name*: string

  ClassIndex* {.pure.} = enum
    Barbarian = 0,
    Bard = 1,
    Cleric = 2,
    Druid = 3,
    Fighter = 4,
    Monk = 5,
    Paladin = 6,
    Ranger = 7,
    Rogue = 8,
    Sorcerer = 9,
    Wizard = 10,
    Shadowdancer = 27,
    HarperScout = 28,
    ArcaneArcher = 29,
    Assassin = 30,
    Blackguard = 31,
    ChampionOfTorm = 32,
    WeaponMaster = 33,
    PaleMaster = 34,
    Shifter = 35,
    DwarvenDefender = 36,
    DragonDisciple = 37,
    PurpleDragonKnight = 41

  ClassBAB* {.pure.} = enum
    Full = 0,
    ThreeQuarters = 1,
    Half = 2

  Class* = object
    index*: int
    name*: string
    levels*: int

    tooltipName*: string
    tooltipIcon*: string
    tooltipDescription*: string

  Classes* = object
    first*: ref Class
    second*: ref Class
    third*: ref Class

  AlignmentIndex* {.pure.} = enum
    LawfulGood = 0,
    LawfulNeutral = 1,
    LawfulEvil = 2,
    NeutralGood = 3,
    TrueNeutral = 4,
    NeutralEvil = 5,
    ChaoticGood = 6,
    ChaoticNeutral = 7,
    ChaoticEvil = 8

  AlignmentRange* = range[0..100]

  Alignment* = object
    index*: AlignmentIndex
    name*: string
    title*: string
    positionLawChaos*: AlignmentRange
    positionGoodEvil*: AlignmentRange

  Experience* = object
    current*: int
    nextLevel*: int
    maxLevel*: bool

  AbilityIndex* {.pure.} = enum
    None = -1,
    Strength = 0,
    Dexterity = 1,
    Constitution = 2,
    Intelligence = 3,
    Wisdom = 4,
    Charisma = 5

  Ability* = object
    index*: AbilityIndex
    name*: string
    base*: int
    geared*: int
    modifier*: int
    gearedIncreaseColored*: bool
    gearedDecreaseColored*: bool
    modifierIncreaseColored*: bool
    modifierDecreaseColored*: bool

  Abilities* = object
    strength*: Ability
    dexterity*: Ability
    constitution*: Ability
    intelligence*: Ability
    wisdom*: Ability
    charisma*: Ability

  HitPointPair* = tuple
    current: int
    maximum: int

  HitPoints* = object
    base*: HitPointPair
    total*: HitPointPair

  ArmorClass* = object
    total*: int
    armor*: int
    shield*: int
    dodge*: int
    natural*: int
    deflection*: int
    other*: int

  Armor* = object
    armorClass*: ArmorClass
    arcaneSpellFailure*: range[0..100]
    checkPenalty*: int

  SavingThrowPair* = tuple
    base: int
    total: int

  SavingThrows* = object
    fortitude*: SavingThrowPair
    reflex*: SavingThrowPair
    will*: SavingThrowPair

  Attacks* = object
    baseAttackBonus*: int
    mainModifier*: int
    offhandModifier*: int

    unarmedLeadingAttackBonus*: int
    unarmedNumAttacks*: int
    unarmedAttackBonuses*: seq[int]

    mainLeadingAttackBonus*: int
    mainNumAttacks*: int
    mainAttackBonuses*: seq[int]

    offhandLeadingAttackBonus*: int
    offhandNumAttacks*: int
    offhandAttackBonuses*: seq[int]

  BaseItemIndex* {.pure.} = enum
    Armor = 16,
    Gloves = 36,
    Kama = 40

  ItemPropertyIndex* {.pure.} = enum
    PropAbility = 0

  ItemProperty* = object
    index*: int
    name*: string
    subtypeName*: string
    costValue*: string
    paramValue*: string

  CriticalRange* = tuple
    lower: range[1..20]
    upper: range[20..20]

  Unarmed* = object
    damageDie*: int
    damageDice*: int
    criticalRange*: CriticalRange
    criticalMultiplier*: int
    damageModifier*: int
    damageSummary*: string
    glovesProperties*: seq[ItemProperty]

  WeaponWield* {.pure.} = enum
    # Note: This is distinct from the WeaponWield animation referenced
    #       in baseitems.2da; it appears to be a fairly arbitrary
    #       name used in the character GFF's CombatInfo section.
    Main = 1,
    Offhand = 2

  Weapon* = object
    id*: int
    name*: string
    baseItemIndex*: int
    baseItemName*: string
    size*: string
    damageDie*: int
    damageDice*: int
    criticalRange*: CriticalRange
    criticalMultiplier*: int
    damageModifier*: int
    damageSummary*: string
    properties*: seq[ItemProperty]

  MetamagicValue* {.pure.} = enum
    None = 0x00,
    Empower = 0x01,
    Extend = 0x02,
    Maximize = 0x04,
    Quicken = 0x08,
    Silent = 0x10,
    Still = 0x20

  Metamagic* = object
    index*: int
    name*: string

  SpellLevel* = string

  Spell* = object
    index*: int
    name*: string
    metamagic*: Metamagic
    ready*: bool

    tooltipName*: string
    tooltipIcon*: string
    tooltipDescription*: string

  Spellbook* = object
    class*: string
    spells*: Table[SpellLevel, seq[Spell]]
    spontaneous*: bool

  Skill* = object
    index*: int
    name*: string
    rank*: int

    tooltipName*: string
    tooltipIcon*: string
    tooltipDescription*: string

  Feat* = object
    index*: int
    name*: string

    tooltipName*: string
    tooltipIcon*: string
    tooltipDescription*: string

  Level* = object
    index*: int
    class*: Class
    hitDie*: int
    abilityIncrease*: Ability
    availableSkillPoints*: int
    skillIncreases*: seq[Skill]
    feats*: seq[Feat]

  Character* = object
    firstName*: string
    lastName*: string

    race*: Race
    subrace*: string
    sex*: Sex
    classes*: Classes
    alignment*: Alignment
    experience*: Experience

    abilities*: Abilities

    hitPoints*: HitPoints
    armor*: Armor
    spellResistance*: int
    savingThrows*: SavingThrows
    attacks*: Attacks

    unarmedStrike*: ref Unarmed
    mainWeapon*: ref Weapon
    offhandWeapon*: ref Weapon

    spellbooks*: seq[Spellbook]

    skills*: seq[Skill]
    feats*: seq[Feat]

    levelHistory*: seq[Level]

  GffError* = object of CatchableError
  TlkError* = object of CatchableError
  TwoDAError* = object of CatchableError

# ----------------------------------------------------------------------------- #

const
  TlkMagicNumber: StrRef = 16777216

  AbilityTable*: Table[AbilityIndex, string] = {
    AbilityIndex.Strength: "Strength",
    AbilityIndex.Dexterity: "Dexterity",
    AbilityIndex.Constitution: "Constitution",
    AbilityIndex.Intelligence: "Intelligence",
    AbilityIndex.Wisdom: "Wisdom",
    AbilityIndex.Charisma: "Charisma"
  }.toTable

  WeaponSizeTable*: Table[int, string] = {
    1: "Tiny",
    2: "Small",
    3: "Medium",
    4: "Large"
  }.toTable

  BaseAttackProgression*: Table[int, ClassBAB] = {
    int(ClassIndex.Barbarian): ClassBAB.Full,
    int(ClassIndex.Bard): ClassBAB.ThreeQuarters,
    int(ClassIndex.Cleric): ClassBAB.ThreeQuarters,
    int(ClassIndex.Druid): ClassBAB.ThreeQuarters,
    int(ClassIndex.Fighter): ClassBAB.Full,
    int(ClassIndex.Monk): ClassBAB.ThreeQuarters,
    int(ClassIndex.Paladin): ClassBAB.Full,
    int(ClassIndex.Ranger): ClassBAB.Full,
    int(ClassIndex.Rogue): ClassBAB.ThreeQuarters,
    int(ClassIndex.Sorcerer): ClassBAB.Half,
    int(ClassIndex.Wizard): ClassBAB.Half,
    int(ClassIndex.Shadowdancer): ClassBAB.ThreeQuarters,
    int(ClassIndex.HarperScout): ClassBAB.ThreeQuarters,
    int(ClassIndex.ArcaneArcher): ClassBAB.Full,
    int(ClassIndex.Assassin): ClassBAB.ThreeQuarters,
    int(ClassIndex.Blackguard): ClassBAB.Full,
    int(ClassIndex.ChampionOfTorm): ClassBAB.Full,
    int(ClassIndex.WeaponMaster): ClassBAB.Full,
    int(ClassIndex.PaleMaster): ClassBAB.Half,
    int(ClassIndex.Shifter): ClassBAB.ThreeQuarters,
    int(ClassIndex.DwarvenDefender): ClassBAB.Full,
    int(ClassIndex.DragonDisciple): ClassBAB.ThreeQuarters,
    int(ClassIndex.PurpleDragonKnight): ClassBAB.Full
  }.toTable

  SpontaneousCasterClasses*: seq[int] = @[
    int(ClassIndex.Bard),
    int(ClassIndex.Sorcerer)
  ]

  PreparedCasterClasses*: seq[int] = @[
    int(ClassIndex.Cleric),
    int(ClassIndex.Druid),
    int(ClassIndex.Paladin),
    int(ClassIndex.Ranger),
    int(ClassIndex.Wizard),
    int(ClassIndex.PaleMaster)
  ]

  # hard-coded because there's not a clear way to derive this mapping from a
  # 2da or something.
  MetamagicIndex*: Table[int, int] = {
    0x00: 0, # None
    0x01: 2, # Empower
    0x02: 3, # Extend
    0x04: 4, # Maximize
    0x08: 1, # Quicken
    0x10: 5, # Silent
    0x20: 6  # Still
  }.toTable

# ----------------------------------------------------------------------------- #

# Dependencies injected from calling module
var
  tlks*: ref Table[Server, Tlk] = nil
  twoDAs*: ref Table[Server, Table[string, TwoDA]] = nil

# ----------------------------------------------------------------------------- #

proc nextLevelXP*(currentLevel: int): int =
  if currentLevel == 40: return -1

  for l in 1..currentLevel:
    result += l * 1000

proc queryTlk*(server: Server, strRef: StrRef): string =
  var queryResult: Option[TlkEntry]

  if strRef >= TlkMagicNumber:
    queryResult = tlks[server][strRef - TlkMagicNumber]
  else:
    queryResult = tlks[Server.BaseGame][strRef]

  if queryResult.isSome: return queryResult.get().text

  raise newException(TlkError, "Tlk lookup failed")

proc query2da*(server: Server, twoDA: string, row: Natural, column: string): string =
  var queryResult: Cell

  for s in (server, Server.BaseGame).fields:
    if twoDAs[s].hasKey(twoDA):
      queryResult = `[]`(twoDAs[s][twoDA], row, column)
      if queryResult.isSome: return queryResult.get()

  raise newException(TwoDAError, "2da lookup failed")
