# ----------------------------------------------------------------------------- #
#
# snowflake
#
# Application entry point and routing.
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

import std/[sequtils, strutils, os, re, json, hashes, times, base64,
            asyncdispatch]
import neverwinter/[resman, resfile, tlk, twoda, gff, gffjson]
import servers, nwn, character, templates, tooltips, targa, images
import jester
import mustache
import redis
import nimPNG

# ----------------------------------------------------------------------------- #

type
  ValidationError = object of CatchableError
  PortraitError = object of CatchableError

  RedisDatabase {.pure.} = enum
    Metadata = 0,
    Characters = 1,
    Portraits = 2,
    Previews = 3,
    SortedSets = 4

# ----------------------------------------------------------------------------- #

const
  JesterHost: string = "localhost"
  JesterPort: int = 5000
  RedisHost: string = "localhost"
  RedisPort: int = 6379
  PathTemplates: string = "./src/templates"
  PathStatic: string = "./src/static"

  ValidServers = @[
    "nwn",
    "sinfar"
  ]

  ValidExposure = @[
    "public",
    "unlisted"
  ]

  ValidExpiration = @[
    "never",
    "10-minutes",
    "1-hours",
    "1-days",
    "1-weeks",
    "1-months",
    "6-months",
    "1-years"
  ]

  ValidTypeTags: Table[string, seq[string]] = {
    "nwn": @[
      "Offensive Melee",
      "Defensive Melee",
      "Offensive Ranged",
      "Defensive Ranged",
      "Stealth",
      "Tank",
      "Nuke Caster",
      "Control Caster",
      "Support Caster",
      "Healer",
      "Arcane Spellsword",
      "Divine Spellsword",
      "Shapeshifter"
    ],
    "sinfar": @[
      "Offensive Melee",
      "Defensive Melee",
      "Offensive Ranged",
      "Defensive Ranged",
      "Stealth",
      "Tank",
      "Nuke Caster",
      "Control Caster",
      "Support Caster",
      "Healer",
      "Arcane Spellsword",
      "Divine Spellsword",
      "Shapeshifter"
    ]
  }.toTable

  ValidFeatureTags: Table[string, seq[string]] = {
    "nwn": @[
      "Stunning Fist",
      "Terrifying Rage",
      "Bard Song",
      "Stun Resistant"
    ],
    "sinfar": @[
      "Stunning Fist",
      "Terrifying Rage",
      "Bard Song",
      "Stun Resistant"
    ]
  }.toTable

  ValidPurposeTags: Table[string, seq[string]] = {
    "nwn": @[
      "PvP",
      "PvE",
      "Roleplaying"
    ],
    "sinfar": @[
      "PvP",
      "PvP: Open World",
      "PvP: CTF",
      "PvP: Duel",
      "PvE",
      "PvE: Farming",
      "PvE: Shard Run",
      "Roleplaying"
    ]
  }.toTable

  TimeOffsets: Table[string, int] = {
    "10-minutes": 600,
    "1-hours": 3600,
    "1-days": 86400,
    "1-weeks": 604800,
    "1-months": 2592000,
    "6-months": 15550000,
    "1-years": 31540000
  }.toTable

  HttpCodeMessages: Table[HttpCode, string] = {
    Http404: "404: Resource Not Found",
    Http422: "422: Unprocessable Entity",
    Http500: "500: Internal Server Error"
  }.toTable

let
  # All databases are keyed with an aggregate hash of:
  # Metadata + Character + Portrait

  # There is one exception to this: we keep a sorted set keyed by 'updated',
  # rather than a hash, in the Metadata database. The values in this sorted
  # set are hashes. The set is sorted by the timestamp at which any given
  # entry is inserted. This set allows us to access the most recently-updated
  # characters for display purposes.

  SchemaMetadata: JsonNode = %*
    {
      "server": "",     # one of ValidServers
      "exposure": "",   # one of ValidExposure
      "expiration": "", # unix timestamp as string
      "tags": {
        "type": [],     # zero or more of ValidTypeTags[server]
        "features": [], # zero or more of ValidFeatureTags[server]
        "purpose": []   # zero or more of ValidPurposeTags[server]
      }
    }

  SchemaCharacters: JsonNode = %*
    {
      "character": {} # character json object
    }

  SchemaPortraits: JsonNode = %*
    {
      "portrait": "" # .tga binary encoded as string
    }

  SchemaPreview: JsonNode = %*
    {
      "name": "",
      "level": "",
      "classes": {
        "first": {
          "name": "",
          "level": ""
        },
        "second": {
          "name": "",
          "level": ""
        },
        "third": {
          "name": "",
          "level": ""
        }
      }
    }

# ----------------------------------------------------------------------------- #

let
  # Note - redisClient isn't garbage collector safe, i.e. having a global that
  #        could be affected by a GC doesn't work in a multi-threaded context,
  #        since Nim has per-thread garbage collection and it's unclear which
  #        thread would own it. Nim avoids this problem by raising a
  #        compilation error when threading is enabled and a variable like this
  #        exists.
  #
  #        however, this application is not multithreaded, so we merely receive
  #        a warning, which should be safe to ignore. could look at using one
  #        of Nim's other garbage collection models but really, who cares.
  redisClient: Redis = open(RedisHost, Port(RedisPort))
  rs: ResMan = newResMan()

rs.add(newResFile("./src/nwn-resources/tlk/dialog.tlk"))
rs.add(newResFile("./src/nwn-resources/tlk/sinfar_v27.tlk"))

var
  tlks: ref Table[Server, Tlk] = newTable[Server, Tlk]()
  twoDAs: ref Table[Server, Table[string, TwoDA]] = newTable[Server, Table[string, TwoDA]]()

tlks[Server.BaseGame] = newTlk(@[
  (male: rs["dialog.tlk"].get(), female: Res(nil))
])
tlks[Server.Sinfar] = newTlk(@[
  (male: rs["sinfar_v27.tlk"].get(), female: Res(nil))
])

twoDAs[Server.BaseGame] = initTable[string, TwoDA]()
twoDAs[Server.Sinfar] = initTable[string, TwoDA]()

for file in toSeq(walkDir("./src/nwn-resources/2da/nwn", relative = true)):
  twoDAs[Server.BaseGame][$(file.path)] = openFileStream("./src/nwn-resources/2da/nwn" & "/" & $(file.path)).readTwoDA()

for file in toSeq(walkDir("./src/nwn-resources/2da/sinfar", relative = true)):
  twoDAs[Server.Sinfar][$(file.path)] = openFileStream("./src/nwn-resources/2da/sinfar" & "/" & $(file.path)).readTwoDA()

# Dependency injection for other modules
nwn.tlks = tlks
nwn.twoDAs = twoDAs
tooltips.tlks = tlks
tooltips.twoDAs = twoDAs

# ----------------------------------------------------------------------------- #

proc validateFile(file: string) =
  try:
    let
      ss: StringStream = newStringStream(file)
      gff: GffRoot =  readGffRoot(ss, false)

    ss.close()
  except:
    raise newException(ValidationError, "Character file validation failed")

proc validatePortrait(portrait: string) =
  if portrait.len > 0:
    var portraitImage: Image = newImage()

    try:
      portraitImage = newImageFromString(portrait)
    except:
      raise newException(ValidationError, "Portrait validation failed")

    if portraitImage.header.image_width != 256 or portraitImage.header.image_height != 512:
      raise newException(PortraitError, "Portrait is the wrong size.")

    if portraitImage.header.image_type != 2:
      raise newException(PortraitError, "Portrait must be an uncompressed true color image.")

    if portraitImage.header.pixel_depth != 24 and
       portraitImage.header.pixel_depth != 32:
      raise newException(PortraitError, "Portrait must be 24-bit RGB or 32-bit RBGA.")

proc validateServer(server: string) =
  if not (server in ValidServers):
    raise newException(ValidationError, "Server validation failed")

proc validateExposure(exposure: string) =
  if not (exposure in ValidExposure):
    raise newException(ValidationError, "Exposure validation failed")

proc validateExpiration(expiration: string) =
  if not (expiration in ValidExpiration):
    raise newException(ValidationError, "Expiration validation failed")

proc validateTags(server: string, validTags: Table[string, seq[string]], testTags: string) =
  for svr, tags in validTags.pairs:
    if svr == server:
      for testTag in testTags.split(","):
        if testTag.len > 0 and not (testTag in tags):
          raise newException(ValidationError, "Tag validation failed")

proc validateTypeTags(server: string, typeTags: string) =
  validateTags(server, ValidTypeTags, typeTags)

proc validateFeatureTags(server: string, featureTags: string) =
  validateTags(server, ValidFeatureTags, featureTags)

proc validatePurposeTags(server: string, purposeTags: string) =
  validateTags(server, ValidPurposeTags, purposeTags)

# ----------------------------------------------------------------------------- #

proc tagMarkup(json: JsonNode, classes: string = ""): string =
  # TODO - imagine iterating through object fields in templates lmoa
  #        thanks mustache, you're a treasure
  result = "<div class=\"tags " & classes & "\">"

  for k, v in json["tags"].pairs:
    for tag in v.items:
      result.add("<span class=\"tag is-info\">" & tag.getStr() & "</span>")

  result.add("</div>")

# ----------------------------------------------------------------------------- #

proc hashExists(hash: string, database: RedisDatabase): bool =
  discard redisClient.select(int(database))
  redisClient.exists(hash)

proc metadataExists(hash: string): bool =
  hashExists(hash, RedisDatabase.Metadata)

proc characterExists(hash: string): bool =
  hashExists(hash, RedisDatabase.Characters)

proc portraitExists(hash: string): bool =
  hashExists(hash, RedisDatabase.Portraits)

proc previewExists(hash: string): bool =
  hashExists(hash, RedisDatabase.Previews)

proc entryExists(hash: string): bool =
  metadataExists(hash) and
  characterExists(hash) and
  portraitExists(hash) and
  previewExists(hash)

proc recentlyUpdatedHashes(): RedisList =
  # Retrieves the 30 most recently-updated hashes, pruning those hashes that
  # have since expired until we have either:
  # * 30 current hashes
  # * the total number of remaining hashes in the set
  # whichever is fewer.
  proc updated(): RedisList =
    discard redisClient.select(int(RedisDatabase.SortedSets))
    result = redisClient.zrevrange("updated", "0", "30")

  proc pruneHash(hash: string) =
    discard redisClient.select(int(RedisDatabase.SortedSets))
    discard redisClient.zrem("updated", hash)

  while true:
    result = updated()

    var nPruned = result.len

    for hash in result:
      if not metadataExists(hash):
        nPruned -= 1
        pruneHash(hash)

    if nPruned == result.len:
      break

proc setRecentlyUpdatedHash(hash: Hash) =
  discard redisClient.select(int(RedisDatabase.SortedSets))
  discard redisClient.zadd("updated", int(getTime().toUnix()), $(hash))

proc metadata(hash: string): JsonNode =
  discard redisClient.select(int(RedisDatabase.Metadata))

  parseJson(redisClient.get(hash))

proc character(hash: string): JsonNode =
  discard redisClient.select(int(RedisDatabase.Characters))

  parseJson(redisClient.get(hash))

proc portrait(hash: string): JsonNode =
  discard redisClient.select(int(RedisDatabase.Portraits))

  parseJson(redisClient.get(hash))

proc preview(hash: string): JsonNode =
  discard redisClient.select(int(RedisDatabase.Previews))

  parseJson(redisClient.get(hash))

proc aggregateHash(metadata: JsonNode,
                   character: JsonNode,
                   portrait: JsonNode): Hash =
  let json = metadata

  json["character"] = character["character"]
  json["portrait"] = portrait["portrait"]

  hash($(json))

proc persistMetadata(hash: Hash, metadata: JsonNode) =
  discard redisClient.select(int(RedisDatabase.Metadata))

  redisClient.setk($(hash), $(metadata))

proc persistCharacter(hash: Hash, character: JsonNode) =
  discard redisClient.select(int(RedisDatabase.Characters))

  redisClient.setk($(hash), $(character))

proc persistPortrait(hash: Hash, portrait: JsonNode) =
  discard redisClient.select(int(RedisDatabase.Portraits))

  redisClient.setk($(hash), $(portrait))

proc persistPreview(hash: Hash, preview: JsonNode) =
  discard redisClient.select(int(RedisDatabase.Previews))

  redisClient.setk($(hash), $(preview))

proc persist(hash: Hash,
             metadata: JsonNode,
             character: JsonNode,
             portrait: JsonNode,
             preview: JsonNode) =
  persistMetadata(hash, metadata)
  persistCharacter(hash, character)
  persistPortrait(hash, portrait)
  persistPreview(hash, preview)

proc setExpiration(hash: Hash, database: RedisDatabase) =
  let
    metadata = metadata($(hash))
    expiration = metadata["expiration"].getStr()

  if expiration != "never":
    discard redisClient.select(int(database))
    discard redisClient.expireAt($(hash), expiration.parseInt())

proc setMetadataExpiration(hash: Hash) =
  setExpiration(hash, RedisDatabase.Metadata)

proc setCharacterExpiration(hash: Hash) =
  setExpiration(hash, RedisDatabase.Characters)

proc setPortraitExpiration(hash: Hash) =
  setExpiration(hash, RedisDatabase.Portraits)

proc setPreviewExpiration(hash: Hash) =
  setExpiration(hash, RedisDatabase.Previews)

proc setExpiration(hash: Hash) =
  setMetadataExpiration(hash)
  setCharacterExpiration(hash)
  setPortraitExpiration(hash)
  setPreviewExpiration(hash)

proc publicExposure(metadata: JsonNode): bool =
  metadata["exposure"].getStr() == "public"

proc expires(metadata: JsonNode): bool =
  metadata["expiration"].getStr() != "never"

# ----------------------------------------------------------------------------- #

template errorResponse(code: HttpCode, message: string) =
  let
    ctx: Context = newContext(searchDirs = @[PathTemplates])
    error: Table[string, string] = {
      "title": HttpCodeMessages[code],
      "message": message
    }.toTable

  ctx["error"] = error
  resp code, render("{{ >error }}", ctx)

# ----------------------------------------------------------------------------- #

settings:
  port = Port(JesterPort)
  bindAddr = JesterHost
  staticDir = PathStatic

routes:
  get "/":
    proc server(metadataJson: JsonNode): Server =
      ServerIndex[metadataJson["server"].getStr()]

    proc characterOverview(hash: string,
                           metadataJson: JsonNode,
                           previewJson: JsonNode): Table[string, string] =
      let
        server: Server = server(metadataJson)

      result = initTable[string, string]()
      result["name"] = previewJson["name"].getStr()
      result["hash"] = hash
      result["server"] = ServerName[server]
      result["level"] = previewJson["level"].getStr()
      result["tags"] = tagMarkup(metadataJson)

      for k, v in previewJson["classes"].pairs:
        if v["name"].getStr().len > 0:
          result["class-" & k & "-name"] = v["name"].getStr()
          result["class-" & k & "-levels"] = v["level"].getStr()

    let ctx: Context = newContext(searchDirs = @[PathTemplates])
    var characterOverviews: seq[Table[string, string]] = @[]

    for hash in recentlyUpdatedHashes():
      let
        metadataJson: JsonNode = metadata(hash)
        previewJson: JsonNode = preview(hash)
        server: Server = server(metadataJson)

      if publicExposure(metadataJson):
        characterOverviews.add(characterOverview(hash, metadataJson, previewJson))

    ctx["character-overviews"] = characterOverviews

    resp render("{{ >main }}", ctx)

  post "/":
    proc expirationTime(expiration: string): string =
      let currentTime: int = int(getTime().toUnix())

      if expiration == "never":
        result = "never"
      else:
        result = $(currentTime + TimeOffsets[expiration])

    proc characterName(character: Character): string =
      if character.firstName.len > 0 and character.lastName.len > 0:
        result = character.firstName & " " & character.lastName
      elif character.firstName.len > 0:
        result = character.firstName
      elif character.lastName.len > 0:
        result = character.lastName

    proc parseGff(file: string): GffRoot =
      let ss: StringStream = newStringStream(file)

      result = readGffRoot(ss, false)

      ss.close()

    proc newCharacterJson(file: string): JsonNode =
      result = copy(SchemaCharacters)
      result["character"] = toJson(parseGff(file))

    proc newPortraitJson(portrait: string): JsonNode =
      result = copy(SchemaPortraits)
      result["portrait"] = %(portrait)

    proc newMetadataJson(server: string,
                         exposure: string,
                         expiration: string,
                         typeTags: string,
                         featureTags: string,
                         purposeTags: string): JsonNode =
      result = copy(SchemaMetadata)
      result["server"] = %(server)
      result["exposure"] = %(exposure)
      result["expiration"] = %(expirationTime(expiration))

      for tag in (typeTags.split(",").filter do (t: string) -> bool: t.len > 0):
        result["tags"]["type"].add(%(tag))

      for tag in (featureTags.split(",").filter do (t: string) -> bool: t.len > 0):
        result["tags"]["features"].add(%(tag))

      for tag in (purposeTags.split(",").filter do (t: string) -> bool: t.len > 0):
        result["tags"]["purpose"].add(%(tag))

    proc newPreviewJson(character: Character): JsonNode =
      result = copy(SchemaPreview)

      result["name"] = %(characterName(character))
      result["level"] = %($(character.levelHistory.len))

      for k, v in character.classes.fieldPairs:
        if v != nil:
          result["classes"][k]["name"] = %(v.name)
          result["classes"][k]["level"] = %($(v.levels))

    try:
      let
        file: string = request.formData["file"].body
        portrait: string = request.formData["portrait"].body
        server: string = request.formData["server"].body
        exposure: string = request.formData["exposure"].body
        expiration: string = request.formData["expiration"].body
        typeTags: string = request.formData["tags-type"].body
        featureTags: string = request.formData["tags-features"].body
        purposeTags: string = request.formData["tags-purpose"].body

      validateFile(file)
      validatePortrait(portrait)
      validateServer(server)
      validateExposure(exposure)
      validateExpiration(expiration)
      validateTypeTags(server, typeTags)
      validateFeatureTags(server, featureTags)
      validatePurposeTags(server, purposeTags)

      let
        characterJson: JsonNode = newCharacterJson(file)
        portraitJson: JsonNode = newPortraitJson(portrait)
        metadataJson: JsonNode = newMetadataJson(server,
                                                 exposure,
                                                 expiration,
                                                 typeTags,
                                                 featureTags,
                                                 purposeTags)
        previewJson: JsonNode = newPreviewJson(jsonToCharacter(characterJson["character"], ServerIndex[server]))
        hs: Hash = aggregateHash(metadataJson, characterJson, portraitJson)

      persist(hs, metadataJson, characterJson, portraitJson, previewJson)
      setExpiration(hs)
      setRecentlyUpdatedHash(hs)

      redirect(uri("/c/" & $(hs)))
    except ValidationError:
      errorResponse(Http422, "")
    except PortraitError:
      errorResponse(Http422, getCurrentExceptionMsg())
    except:
      errorResponse(Http500, "")

  get re"^\/c\/([0-9]+)$":
    proc hasPortrait(portraitJson: JsonNode): bool =
      portraitJson["portrait"].getStr().len > 0

    proc portraitPngBase64(portraitJson: JsonNode): string =
      let
        tga: Image = newImageFromString(portraitJson["portrait"].getStr())
        png = tgaToPNG(tga)
        pngStream: StringStream = newStringStream()

      png.writeChunks(pngStream)
      pngStream.setPosition(0)

      result = encode(pngStream.readAll())

      pngStream.close()

    proc headers(metadataJson: JsonNode): RawHeaders =
      result = @[
        ("Content-Type", "text/html;charset=utf-8")
      ]

      # https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_valid
      # https://www.nginx.com/resources/wiki/start/topics/examples/x-accel/
      if expires(metadataJson):
        result.add(("X-Accel-Expires", "@" & metadataJson["expiration"].getStr()))

    try:
      let
        ctx: Context = newContext(searchDirs = @[PathTemplates])
        hash: string = request.matches[0]

      if not entryExists(hash):
        errorResponse(Http404, "This character either doesn't exist or has expired.")

      let
        characterJson: JsonNode = character(hash)
        portraitJson: JsonNode = portrait(hash)
        metadataJson: JsonNode = metadata(hash)
        server: Server = ServerIndex[metadataJson["server"].getStr()]
        character: Character = jsonToCharacter(characterJson["character"], server)
        tooltips: Tooltips = tooltips(server)
        headers: RawHeaders = headers(metadataJson)

      if hasPortrait(portraitJson):
        ctx["portrait"] = portraitPngBase64(portraitJson)
      else:
        if character.sex.index == SexIndex.Female:
          ctx["portrait-default"] = "/images/portrait-female-default.jpg"
        else:
          ctx["portrait-default"] = "/images/portrait-male-default.jpg"

      ctx["character"] = addTooltipsToCharacter(character, tooltips)
      ctx["tags"] = tagMarkup(metadataJson, "are-medium")

      resp Http200, headers, render("{{ >character }}", ctx)
    except TlkError, TwoDAError:
      errorResponse(Http500, "Character file references an invalid game resource. This is commonly caused by selecting the wrong server when uploading a character. Try uploading again, and if the issue persists, please file a bug report.")
    except:
      errorResponse(Http500, "")

  get "/faq":
    resp render("{{ >faq }}", newContext(searchDirs = @[PathTemplates]))
