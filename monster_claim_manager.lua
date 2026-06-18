-- ============================================================
-- MONSTER CLAIM MANAGER
-- OTCv8 / vBot / CaveBot / TargetBot
--
-- Um arquivo com dois modos independentes:
--   1) Hunter ativo: encontra e reporta o monstro.
--   2) Killer ativo: disputa por distancia, vai ate o monstro e ataca.
--
-- Configure o topo do arquivo antes de usar.
-- ============================================================

if type(setDefaultTab) == "function" then setDefaultTab("Tools") end
storage = storage or {}

local MONSTER_CLAIM_MANAGER_VERSION = 2026061805
local MONSTER_CLAIM_MANAGER_URL = "https://raw.githubusercontent.com/Thesaidctm/script-holidayys/main/monster_claim_manager.lua"
local MONSTER_CLAIM_MANAGER_FILE = "monster_claim_manager.lua"

CONFIG = {
  secret = "wolf123",

  -- Editavel para testar com outros mobs.
  monsterName = "Exalted Wolf",
  monsterMatchMode = "contains", -- "contains" ou "exact"

  communicationMode = "guild",
  guildSendMethod = "auto", -- "guildsay", "sayChannel", "talkChannel", "say" ou "auto"
  guildChannelId = 0, -- guildsay chegou com channelId=0
  guildTalkMode = 8, -- guildsay chegou com mode=8
  guildListenMode = 8, -- guildsay chegou como mode=8
  guildListenChannelId = 0, -- guildsay chegou como channelId=0
  allowSayFallback = false,

  killers = {
    "NomeKiller1",
    "NomeKiller2",
    "NomeKiller3",
    "NomeKiller4"
  },

  hunterSendInterval = 1000,
  monsterLostTimeout = 5000,
  hunterAttackOtherMonsters = true,
  useMonsterPosition = true,

  claimWaitTime = 500,
  killerSignalTimeout = 15000,
  arriveDistance = 3,
  newOccurrenceDistance = 5,
  maxKillerAttemptTime = 120000,

  floorPenalty = 100,
  noPathPenalty = 500,
  transitionActionPenalty = 10,
  findPathMaxDistance = 120,
  directWalkInterval = 250,
  transitionWalkInterval = 300,
  transitionActionInterval = 800,
  transitionReachDistance = 0,
  stuckTimeout = 2200,
  stuckMinProgress = 1,
  ignoreDirectAfterStuckMs = 2500,

  useCaveBotLabels = false,

  debug = true,
  debugTalk = false,
  debugNavigation = true
}

TRANSITIONS = {
  { name = "1Wolf 1", from = {x = 54720, y = 54806, z = 7}, to = {x = 54714, y = 54805, z = 6}, action = "walk" },
  { name = "1Wolf 2", from = {x = 54694, y = 54796, z = 6}, to = {x = 54694, y = 54796, z = 7}, action = "walk" },
  { name = "1Wolf 3", from = {x = 54694, y = 54796, z = 7}, to = {x = 54692, y = 54802, z = 6}, action = "walk" },
  { name = "1Wolf 4", from = {x = 54692, y = 54802, z = 6}, to = {x = 54689, y = 54808, z = 5}, action = "walk" },
  { name = "1Wolf 5", from = {x = 54689, y = 54808, z = 5}, to = {x = 54690, y = 54813, z = 4}, action = "walk" },
  { name = "1Wolf 6", from = {x = 54690, y = 54813, z = 4}, to = {x = 54693, y = 54813, z = 5}, action = "walk" },
  { name = "1Wolf 7", from = {x = 54693, y = 54813, z = 5}, to = {x = 54699, y = 54818, z = 6}, action = "walk" },
  { name = "1Wolf 8", from = {x = 54700, y = 54803, z = 6}, to = {x = 54699, y = 54803, z = 7}, action = "walk" },
  { name = "1Wolf 9", from = {x = 54699, y = 54803, z = 7}, to = {x = 54705, y = 54803, z = 6}, action = "walk" },
  { name = "1Wolf 10", from = {x = 54720, y = 54806, z = 6}, to = {x = 54726, y = 54806, z = 7}, action = "walk" },
  { name = "1Wolf 11", from = {x = 54784, y = 54779, z = 7}, to = {x = 54782, y = 54779, z = 6}, action = "walk" },
  { name = "1Wolf 12", from = {x = 54784, y = 54779, z = 6}, to = {x = 54788, y = 54773, z = 7}, action = "walk" },
  { name = "1Wolf 13", from = {x = 54794, y = 54753, z = 7}, to = {x = 54794, y = 54751, z = 6}, action = "walk" },
  { name = "1Wolf 14", from = {x = 54794, y = 54753, z = 6}, to = {x = 54794, y = 54759, z = 7}, action = "walk" },
  { name = "1Wolf 15", from = {x = 54799, y = 54774, z = 7}, to = {x = 54800, y = 54771, z = 6}, action = "walk" },
  { name = "1Wolf 16", from = {x = 54799, y = 54774, z = 6}, to = {x = 54805, y = 54776, z = 7}, action = "walk" },
  { name = "1Wolf 17", from = {x = 54817, y = 54771, z = 7}, to = {x = 54816, y = 54766, z = 6}, action = "walk" },
  { name = "1Wolf 18", from = {x = 54817, y = 54771, z = 6}, to = {x = 54823, y = 54771, z = 7}, action = "walk" },
  { name = "1Wolf 19", from = {x = 54799, y = 54786, z = 7}, to = {x = 54793, y = 54789, z = 6}, action = "walk" },
  { name = "1Wolf 20", from = {x = 54799, y = 54786, z = 6}, to = {x = 54805, y = 54791, z = 7}, action = "walk" },
  { name = "1Wolf 21", from = {x = 54823, y = 54793, z = 7}, to = {x = 54818, y = 54790, z = 6}, action = "walk" },
  { name = "1Wolf 22", from = {x = 54818, y = 54790, z = 6}, to = {x = 54818, y = 54790, z = 5}, action = "walk" },
  { name = "1Wolf 23", from = {x = 54818, y = 54790, z = 5}, to = {x = 54823, y = 54793, z = 6}, action = "walk" },
  { name = "1Wolf 24", from = {x = 54823, y = 54793, z = 6}, to = {x = 54824, y = 54799, z = 7}, action = "walk" },
  { name = "1Wolf 25", from = {x = 54785, y = 54827, z = 7}, to = {x = 54785, y = 54821, z = 6}, action = "walk" },
  { name = "1Wolf 26", from = {x = 54780, y = 54812, z = 6}, to = {x = 54782, y = 54812, z = 5}, action = "walk" },
  { name = "1Wolf 27", from = {x = 54782, y = 54812, z = 5}, to = {x = 54783, y = 54811, z = 4}, action = "walk" },
  { name = "1Wolf 28", from = {x = 54783, y = 54811, z = 4}, to = {x = 54780, y = 54811, z = 5}, action = "walk" },
  { name = "1Wolf 29", from = {x = 54780, y = 54811, z = 5}, to = {x = 54782, y = 54817, z = 6}, action = "walk" },
  { name = "1Wolf 30", from = {x = 54785, y = 54827, z = 6}, to = {x = 54791, y = 54832, z = 7}, action = "walk" },
  { name = "1Wolf 31", from = {x = 54791, y = 54842, z = 7}, to = {x = 54785, y = 54840, z = 6}, action = "walk" },
  { name = "1Wolf 32", from = {x = 54782, y = 54843, z = 6}, to = {x = 54778, y = 54844, z = 5}, action = "walk" },
  { name = "1Wolf 33", from = {x = 54778, y = 54844, z = 5}, to = {x = 54777, y = 54843, z = 4}, action = "walk" },
  { name = "1Wolf 34", from = {x = 54777, y = 54843, z = 4}, to = {x = 54777, y = 54843, z = 3}, action = "walk" },
  { name = "1Wolf 35", from = {x = 54777, y = 54843, z = 3}, to = {x = 54778, y = 54844, z = 4}, action = "walk" },
  { name = "1Wolf 36", from = {x = 54778, y = 54844, z = 4}, to = {x = 54782, y = 54843, z = 5}, action = "walk" },
  { name = "1Wolf 37", from = {x = 54782, y = 54843, z = 5}, to = {x = 54788, y = 54841, z = 6}, action = "walk" },
  { name = "1Wolf 38", from = {x = 54791, y = 54842, z = 6}, to = {x = 54795, y = 54848, z = 7}, action = "walk" },
  { name = "1Wolf 39", from = {x = 54806, y = 54847, z = 7}, to = {x = 54812, y = 54850, z = 6}, action = "walk" },
  { name = "1Wolf 40", from = {x = 54814, y = 54855, z = 6}, to = {x = 54820, y = 54860, z = 7}, action = "walk" },
  { name = "1Wolf 41", from = {x = 54814, y = 54855, z = 7}, to = {x = 54809, y = 54849, z = 6}, action = "walk" },
  { name = "1Wolf 42", from = {x = 54806, y = 54847, z = 6}, to = {x = 54800, y = 54847, z = 7}, action = "walk" },
  { name = "1Wolf 43", from = {x = 54794, y = 54866, z = 7}, to = {x = 54788, y = 54865, z = 6}, action = "walk" },
  { name = "1Wolf 44", from = {x = 54794, y = 54866, z = 6}, to = {x = 54798, y = 54872, z = 7}, action = "walk" },
  { name = "1Wolf 45", from = {x = 54663, y = 54879, z = 7}, to = {x = 54662, y = 54885, z = 6}, action = "walk" },
  { name = "1Wolf 46", from = {x = 54654, y = 54890, z = 6}, to = {x = 54654, y = 54890, z = 5}, action = "walk" },
  { name = "1Wolf 47", from = {x = 54654, y = 54890, z = 5}, to = {x = 54660, y = 54888, z = 6}, action = "walk" },
  { name = "1Wolf 48", from = {x = 54663, y = 54879, z = 6}, to = {x = 54657, y = 54875, z = 7}, action = "walk" },
  { name = "1Wolf 49", from = {x = 54694, y = 54847, z = 7}, to = {x = 54700, y = 54845, z = 6}, action = "walk" },
  { name = "1Wolf 50", from = {x = 54714, y = 54844, z = 6}, to = {x = 54715, y = 54850, z = 7}, action = "walk" },
  { name = "1Wolf 51", from = {x = 54725, y = 54799, z = 7}, to = {x = 54725, y = 54796, z = 6}, action = "walk" },
  { name = "1Wolf 52", from = {x = 54725, y = 54796, z = 6}, to = {x = 54725, y = 54790, z = 7}, action = "walk" },
  { name = "1Wolf 53", from = {x = 54696, y = 54771, z = 7}, to = {x = 54695, y = 54771, z = 6}, action = "walk" },
  { name = "1Wolf 54", from = {x = 54695, y = 54771, z = 6}, to = {x = 54701, y = 54774, z = 7}, action = "walk" },
  { name = "1Wolf 55", from = {x = 54725, y = 54796, z = 7}, to = {x = 54725, y = 54799, z = 6}, action = "walk" }
}

ROUTE_MAP_TEXT = "54725,54801,7;54720,54806,7,0;54714,54805,6;54708,54804,6;54702,54802,6;54696,54801,6;54694,54796,6,0;54694,54796,7,0;54692,54802,6;54692,54802,6,0;54689,54808,5;54689,54808,5,0;54690,54813,4,0;54693,54813,5,0;54699,54818,6;54705,54817,6;54711,54813,6;54715,54807,6;54709,54804,6;54703,54802,6;54700,54803,6,0;54699,54803,7,0;54705,54803,6;54711,54804,6;54717,54804,6;54720,54806,6,0;54726,54806,7;54732,54805,7;54738,54804,7;54744,54804,7;54750,54804,7;54756,54802,7;54762,54802,7;54768,54803,7;54774,54802,7;54774,54796,7;54775,54790,7;54774,54784,7;54771,54778,7;54771,54772,7;54777,54768,7;54783,54769,7;54788,54775,7;54784,54779,7,0;54782,54779,6;54784,54779,6,0;54788,54773,7;54788,54767,7;54793,54761,7;54794,54755,7;54794,54753,7,0;54794,54751,6;54794,54753,6,0;54794,54759,7;54792,54765,7;54791,54771,7;54792,54777,7;54798,54775,7;54799,54774,7,0;54800,54771,6;54799,54774,6,0;54805,54776,7;54811,54775,7;54817,54774,7;54817,54771,7,0;54816,54766,6;54817,54771,6,0;54823,54771,7;54829,54769,7;54829,54775,7;54825,54781,7;54819,54782,7;54813,54783,7;54809,54789,7;54803,54786,7;54799,54786,7,0;54793,54789,6;54799,54788,6;54799,54786,6,0;54805,54791,7;54807,54797,7;54813,54800,7;54819,54800,7;54823,54794,7;54823,54793,7,0;54818,54790,6,0;54818,54790,5,0;54823,54793,6,0;54824,54799,7;54818,54800,7;54812,54800,7;54806,54803,7;54800,54803,7;54794,54802,7;54789,54808,7;54795,54813,7;54801,54815,7;54806,54821,7;54805,54827,7;54799,54830,7;54793,54830,7;54787,54829,7;54785,54827,7,0;54785,54821,6;54782,54815,6;54780,54812,6,0;54782,54812,5,0;54783,54811,4,0;54780,54811,5,0;54782,54817,6;54784,54823,6;54785,54827,6,0;54791,54832,7;54793,54838,7;54791,54842,7,0;54785,54840,6;54782,54843,6,0;54778,54844,5,0;54777,54843,4,0;54777,54843,3,0;54778,54844,4,0;54782,54843,5,0;54788,54841,6;54791,54842,6,0;54795,54848,7;54801,54850,7;54806,54847,7,0;54812,54850,6;54814,54855,6,0;54820,54860,7;54814,54858,7;54814,54855,7,0;54809,54849,6;54806,54847,6,0;54800,54847,7;54798,54853,7;54798,54859,7;54798,54865,7;54794,54866,7,0;54788,54865,6;54794,54866,6;54794,54866,6,0;54798,54872,7;54798,54878,7;54792,54875,7;54786,54875,7;54780,54875,7;54774,54876,7;54768,54879,7;54767,54885,7;54762,54891,7;54756,54892,7;54750,54896,7;54744,54898,7;54739,54904,7;54735,54910,7;54729,54914,7;54728,54920,7;54734,54925,7;54734,54919,7;54730,54913,7;54724,54912,7;54718,54914,7;54712,54919,7;54706,54919,7;54705,54925,7;54704,54919,7;54705,54913,7;54705,54907,7;54702,54901,7;54696,54897,7;54690,54896,7;54684,54895,7;54678,54892,7;54672,54887,7;54671,54881,7;54665,54877,7;54663,54879,7,0;54662,54885,6;54656,54889,6;54654,54890,6,0;54654,54890,5,0;54660,54888,6;54662,54882,6;54663,54879,6,0;54657,54875,7;54653,54869,7;54647,54869,7;54641,54871,7;54635,54870,7;54629,54870,7;54635,54870,7;54641,54871,7;54647,54870,7;54653,54869,7;54658,54863,7;54664,54863,7;54663,54857,7;54659,54851,7;54665,54852,7;54671,54848,7;54673,54842,7;54678,54848,7;54680,54854,7;54686,54854,7;54692,54855,7;54694,54849,7;54694,54847,7,0;54700,54845,6;54706,54845,6;54712,54844,6;54714,54844,6,0;54715,54850,7;54709,54851,7;54715,54848,7;54721,54848,7;54722,54842,7;54723,54836,7;54718,54830,7;54720,54824,7;54721,54818,7;54725,54812,7;54725,54806,7;54725,54800,7;54725,54799,7,0;54725,54796,6,0;54725,54790,7;54724,54784,7;54730,54781,7;54736,54781,7;54741,54787,7;54736,54781,7;54730,54780,7;54724,54781,7;54718,54781,7;54712,54781,7;54706,54780,7;54700,54775,7;54695,54771,7;54696,54771,7,0;54695,54771,6,0;54701,54774,7;54707,54779,7;54713,54779,7;54719,54781,7;54724,54787,7;54725,54793,7;54725,54796,7,0;54725,54799,6,0"

local STORAGE_KEY = "monster_claim_manager"
storage[STORAGE_KEY] = storage[STORAGE_KEY] or {}
local settings = storage[STORAGE_KEY]

if settings.hunterEnabled == nil then settings.hunterEnabled = false end
if settings.killerEnabled == nil then settings.killerEnabled = false end
if settings.monsterName == nil then settings.monsterName = CONFIG.monsterName end
if settings.killersText == nil then settings.killersText = table.concat(CONFIG.killers or {}, ", ") end
if settings.guildChannelId == nil then settings.guildChannelId = CONFIG.guildChannelId end
if settings.guildTalkMode == nil then settings.guildTalkMode = CONFIG.guildTalkMode end

-- ============================================================
-- HELPERS BASICOS
-- ============================================================

local function nowMs()
  if type(now) == "number" then return now end
  if type(now) == "function" then
    local ok, value = pcall(now)
    if ok and type(value) == "number" then return value end
  end
  if g_clock and g_clock.millis then
    local ok, value = pcall(function() return g_clock.millis() end)
    if ok and type(value) == "number" then return value end
  end
  return math.floor(os.clock() * 1000)
end

local function trim(text)
  text = tostring(text or "")
  return text:gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalize(text)
  return trim(text):lower():gsub("%s+", " ")
end

local function safeField(text)
  text = tostring(text or "")
  text = text:gsub("|", "/")
  return text
end

local function cfgMonsterName()
  local name = trim(settings.monsterName)
  if name == "" then name = CONFIG.monsterName end
  return name
end

local function cfgGuildChannelId()
  local id = tonumber(settings.guildChannelId)
  if id ~= nil then return id end
  return tonumber(CONFIG.guildChannelId)
end

local function cfgGuildTalkMode()
  local mode = tonumber(settings.guildTalkMode)
  if mode ~= nil then return mode end
  return tonumber(CONFIG.guildTalkMode) or 8
end

local function cfgDebugTalk()
  return CONFIG.debugTalk == true
end

local function logInfo(text)
  if CONFIG.debug ~= true then return end
  if type(warn) == "function" then
    warn("[MCM] " .. tostring(text or ""))
  elseif type(print) == "function" then
    print("[MCM] " .. tostring(text or ""))
  end
end

local function navInfo(text)
  if CONFIG.debugNavigation == true then logInfo(text) end
end

local function tableCount(tbl)
  local count = 0
  for _ in pairs(tbl or {}) do count = count + 1 end
  return count
end

local function sameName(a, b)
  return normalize(a) == normalize(b)
end

local function playerName()
  if player and player.getName then
    local ok, name = pcall(function() return player:getName() end)
    if ok and name then return tostring(name) end
  end
  if g_game and g_game.getLocalPlayer then
    local ok, localPlayer = pcall(function() return g_game.getLocalPlayer() end)
    if ok and localPlayer and localPlayer.getName then
      local okName, name = pcall(function() return localPlayer:getName() end)
      if okName and name then return tostring(name) end
    end
  end
  return "unknown"
end

local function posCopy(p)
  if not p or not p.x or not p.y or not p.z then return nil end
  return { x = tonumber(p.x), y = tonumber(p.y), z = tonumber(p.z) }
end

local function playerPos()
  if player and player.getPosition then
    local ok, p = pcall(function() return player:getPosition() end)
    if ok then return posCopy(p) end
  end
  return nil
end

local function creaturePos(creature)
  if creature and creature.getPosition then
    local ok, p = pcall(function() return creature:getPosition() end)
    if ok then return posCopy(p) end
  end
  return nil
end

local function posText(p)
  if not p then return "0,0,0" end
  return tostring(p.x) .. "," .. tostring(p.y) .. "," .. tostring(p.z)
end

local function parsePos(text)
  local x, y, z = tostring(text or ""):match("(%-?%d+),(%-?%d+),(%-?%d+)")
  if not x then return nil end
  return { x = tonumber(x), y = tonumber(y), z = tonumber(z) }
end

local function distance2d(a, b)
  if not a or not b then return 999999 end
  return math.abs(a.x - b.x) + math.abs(a.y - b.y)
end

local function distanceCost(a, b)
  if not a or not b then return 999999 end
  return math.abs(a.x - b.x)
    + math.abs(a.y - b.y)
    + math.abs(a.z - b.z) * CONFIG.floorPenalty
end

local function sameOccurrencePos(a, b)
  return a and b and distanceCost(a, b) <= CONFIG.newOccurrenceDistance
end

local function splitPipe(text)
  local parts = {}
  for item in tostring(text or ""):gmatch("([^|]+)") do
    table.insert(parts, item)
  end
  return parts
end

local function parseNameList(text)
  local names = {}
  text = tostring(text or "")
  text = text:gsub("\r", "\n")
  text = text:gsub("[,;|]", "\n")
  for line in text:gmatch("[^\n]+") do
    local name = trim(line)
    if name ~= "" then table.insert(names, name) end
  end
  return names
end

local function configuredKillers()
  local names = parseNameList(settings.killersText)
  if #names > 0 then return names end
  return CONFIG.killers or {}
end

local function saveConfiguredKillers(names)
  settings.killersText = table.concat(names or {}, ", ")
end

local function findNameIndex(names, wanted)
  wanted = normalize(wanted)
  for index, name in ipairs(names or {}) do
    if normalize(name) == wanted then return index end
  end
  return nil
end

local function occurrenceKey(monsterName, p)
  return normalize(monsterName) .. "|" .. posText(p)
end

-- ============================================================
-- CREATURES / COMBAT
-- ============================================================

local function getSpectatorsSafe()
  if type(getSpectators) == "function" then
    local ok, specs = pcall(function() return getSpectators() end)
    if ok and type(specs) == "table" then return specs end
    ok, specs = pcall(function() return getSpectators(false) end)
    if ok and type(specs) == "table" then return specs end
  end
  return {}
end

local function creatureName(creature)
  if creature and creature.getName then
    local ok, name = pcall(function() return creature:getName() end)
    if ok and name then return tostring(name) end
  end
  return ""
end

local function isMonsterCreature(creature)
  if not creature then return false end
  if creature.isMonster then
    local ok, value = pcall(function() return creature:isMonster() end)
    if ok then return value == true end
  end
  if creature.isPlayer then
    local ok, value = pcall(function() return creature:isPlayer() end)
    if ok and value == true then return false end
  end
  return false
end

local function healthPercent(creature)
  if creature and creature.getHealthPercent then
    local ok, hp = pcall(function() return creature:getHealthPercent() end)
    hp = tonumber(hp)
    if ok and hp then return hp end
  end
  return 100
end

local function isConfiguredMonster(creature, monsterName)
  if not isMonsterCreature(creature) then return false end
  monsterName = monsterName or cfgMonsterName()
  local name = normalize(creatureName(creature))
  local wanted = normalize(monsterName)
  if wanted == "" then return false end
  if CONFIG.monsterMatchMode == "exact" then return name == wanted end
  return name:find(wanted, 1, true) ~= nil
end

local function findConfiguredMonster(monsterName)
  local best = nil
  local bestDist = 999999
  local me = playerPos()
  for _, creature in ipairs(getSpectatorsSafe()) do
    if isConfiguredMonster(creature, monsterName) and healthPercent(creature) > 0 then
      local p = creaturePos(creature)
      local d = distanceCost(me, p)
      if not best or d < bestDist then
        best = creature
        bestDist = d
      end
    end
  end
  return best
end

local function currentTarget()
  if g_game and g_game.getAttackingCreature then
    local ok, target = pcall(function() return g_game.getAttackingCreature() end)
    if ok then return target end
  end
  if type(target) == "function" then
    local ok, t = pcall(target)
    if ok then return t end
  end
  return nil
end

local function attackCreature(creature)
  if not creature then return false end
  if g_game and g_game.attack then
    local ok = pcall(function() g_game.attack(creature) end)
    if ok then return true end
  end
  if type(attack) == "function" then
    local ok = pcall(function() attack(creature) end)
    if ok then return true end
  end
  return false
end

local function cancelCurrentAttack()
  if g_game and g_game.cancelAttack then
    local ok = pcall(function() g_game.cancelAttack() end)
    if ok then return true end
  end
  if g_game and g_game.cancelAttackAndFollow then
    local ok = pcall(function() g_game.cancelAttackAndFollow() end)
    if ok then return true end
  end
  local globalCancel = _G and _G.cancelAttack or nil
  if type(globalCancel) == "function" then
    local ok = pcall(globalCancel)
    if ok then return true end
  end
  return false
end

local function attackOtherMonster()
  for _, creature in ipairs(getSpectatorsSafe()) do
    if isMonsterCreature(creature)
      and not isConfiguredMonster(creature)
      and healthPercent(creature) > 0 then
      return attackCreature(creature)
    end
  end
  return false
end

local function setCaveBot(on)
  if not CaveBot then return false end
  if on and CaveBot.setOn then
    local ok = pcall(function() CaveBot.setOn() end)
    return ok == true
  end
  if not on and CaveBot.setOff then
    local ok = pcall(function() CaveBot.setOff() end)
    return ok == true
  end
  return false
end

local function setTargetBot(on)
  if not TargetBot then return false end
  if on and TargetBot.setOn then
    local ok = pcall(function() TargetBot.setOn() end)
    return ok == true
  end
  if not on and TargetBot.setOff then
    local ok = pcall(function() TargetBot.setOff() end)
    return ok == true
  end
  return false
end

-- ============================================================
-- GUILD COMMUNICATION
-- ============================================================

local lastGuildWarnAt = 0

local function warnGuild(text)
  local tm = nowMs()
  if tm - lastGuildWarnAt < 3000 then return end
  lastGuildWarnAt = tm
  logInfo(text)
end

local function sendBySayChannel(channelId, msg)
  if not channelId or type(sayChannel) ~= "function" then return false end
  local ok, result = pcall(function() return sayChannel(channelId, msg) end)
  return ok and result ~= false
end

local function sendByTalkChannel(channelId, msg)
  if not channelId or not g_game or type(g_game.talkChannel) ~= "function" then return false end

  local ok, result = pcall(function()
    return g_game.talkChannel(cfgGuildTalkMode(), channelId, msg)
  end)
  if ok and result ~= false then return true end

  ok, result = pcall(function()
    return g_game.talkChannel(channelId, msg)
  end)
  return ok and result ~= false
end

local function sendByGuildSay(msg)
  if type(guildsay) ~= "function" then return false end
  local ok, result = pcall(function() return guildsay(msg) end)
  return ok and result ~= false
end

local function sendGuildMessage(msg)
  msg = tostring(msg or "")
  if msg == "" then return false end

  local method = tostring(CONFIG.guildSendMethod or "sayChannel")
  local channelId = cfgGuildChannelId()

  if method ~= "say" and not channelId then
    warnGuild("guildChannelId esta nil. Preencha CONFIG.guildChannelId no topo do script.")
    if method ~= "auto" then return false end
  end

  if method == "sayChannel" then
    return sendBySayChannel(channelId, msg)
  end

  if method == "talkChannel" then
    return sendByTalkChannel(channelId, msg)
  end

  if method == "guildsay" then
    return sendByGuildSay(msg)
  end

  if method == "say" then
    if CONFIG.allowSayFallback ~= true then
      warnGuild("allowSayFallback esta false. Evitei enviar por say local.")
      return false
    end
    if type(say) == "function" then
      local ok, result = pcall(function() return say(msg) end)
      return ok and result ~= false
    end
    return false
  end

  if method == "auto" then
    if sendByGuildSay(msg) then return true end
    if channelId == 0 and sendByTalkChannel(channelId, msg) then return true end
    if sendBySayChannel(channelId, msg) then return true end
    if sendByTalkChannel(channelId, msg) then return true end
    if CONFIG.allowSayFallback == true and type(say) == "function" then
      local ok, result = pcall(function() return say(msg) end)
      if ok and result ~= false then return true end
    end
  end

  warnGuild("Nao consegui enviar mensagem na guild: " .. msg)
  return false
end

local function sendFoundMessage(pos, hp)
  return sendGuildMessage(
    "WOLF_FOUND|" .. safeField(CONFIG.secret) .. "|" ..
    safeField(playerName()) .. "|" ..
    safeField(cfgMonsterName()) .. "|" ..
    posText(pos) .. "|" ..
    tostring(math.floor(tonumber(hp) or 0))
  )
end

local function sendLostMessage()
  return sendGuildMessage(
    "WOLF_LOST|" .. safeField(CONFIG.secret) .. "|" ..
    safeField(playerName()) .. "|" ..
    safeField(cfgMonsterName())
  )
end

local function sendClaimMessage(monsterName, distance, pos)
  return sendGuildMessage(
    "WOLF_CLAIM|" .. safeField(CONFIG.secret) .. "|" ..
    safeField(playerName()) .. "|" ..
    safeField(monsterName) .. "|" ..
    tostring(math.floor(distance or 0)) .. "|" ..
    posText(pos)
  )
end

local function sendAssignedMessage(monsterName, distance, pos)
  return sendGuildMessage(
    "WOLF_ASSIGNED|" .. safeField(CONFIG.secret) .. "|" ..
    safeField(playerName()) .. "|" ..
    safeField(monsterName) .. "|" ..
    tostring(math.floor(distance or 0)) .. "|" ..
    posText(pos)
  )
end

local function sendDoneMessage(monsterName, pos)
  return sendGuildMessage(
    "WOLF_DONE|" .. safeField(CONFIG.secret) .. "|" ..
    safeField(playerName()) .. "|" ..
    safeField(monsterName) .. "|" ..
    posText(pos)
  )
end

-- ============================================================
-- UPGRADE FORCADO
-- ============================================================

local upgradeCheckBusy = false

local function currentScriptPath()
  if type(CONFIG.upgradeWritePath) == "string" and trim(CONFIG.upgradeWritePath) ~= "" then
    return trim(CONFIG.upgradeWritePath)
  end

  local profile = nil
  if type(botConfigName) == "string" and trim(botConfigName) ~= "" then
    profile = trim(botConfigName)
  elseif type(configName) == "string" and trim(configName) ~= "" then
    profile = trim(configName)
  else
    profile = "MAGE_FINAL"
  end

  return "/bot/" .. profile .. "/" .. MONSTER_CLAIM_MANAGER_FILE
end

local function extractRemoteVersion(data)
  local version = tostring(data or ""):match("MONSTER_CLAIM_MANAGER_VERSION%s*=%s*(%d+)")
  return tonumber(version)
end

local function validateUpgradeFile(data)
  data = tostring(data or "")

  if #data < 1000 then
    return false, "arquivo remoto muito pequeno."
  end

  if not data:find("MONSTER CLAIM MANAGER", 1, true) then
    return false, "arquivo remoto nao parece ser o Monster Claim Manager."
  end

  if not data:find("MONSTER_CLAIM_MANAGER_VERSION", 1, true) then
    return false, "arquivo remoto nao possui versao."
  end

  if not data:find("MonsterClaimSetupWindow", 1, true) then
    return false, "arquivo remoto nao possui a interface esperada."
  end

  return true
end

local function backupCurrentScript(path)
  if type(g_resources) ~= "table" then return end
  if type(g_resources.fileExists) ~= "function" then return end
  if type(g_resources.readFileContents) ~= "function" then return end
  if type(g_resources.writeFileContents) ~= "function" then return end

  local okExists, exists = pcall(function()
    return g_resources.fileExists(path)
  end)
  if not okExists or exists ~= true then return end

  local okRead, content = pcall(function()
    return g_resources.readFileContents(path)
  end)
  if not okRead or not content or tostring(content) == "" then return end

  pcall(function()
    g_resources.writeFileContents(path .. ".bak", content)
  end)
end

local function writeUpgradeFile(data, remoteVersion)
  if type(g_resources) ~= "table" or type(g_resources.writeFileContents) ~= "function" then
    logInfo("Upgrade forcado indisponivel: g_resources.writeFileContents nao encontrado.")
    return false
  end

  local path = currentScriptPath()
  backupCurrentScript(path)

  local ok, err = pcall(function()
    g_resources.writeFileContents(path, data)
  end)

  if not ok then
    logInfo("Upgrade forcado falhou ao gravar: " .. tostring(err))
    return false
  end

  logInfo("Upgrade forcado aplicado. Versao remota=" .. tostring(remoteVersion) .. " Arquivo=" .. path)
  logInfo("Recarregue o bot/perfil para carregar a nova versao.")
  return true
end

local function finishForceUpgrade(data, err)
  upgradeCheckBusy = false

  if err and tostring(err) ~= "" then
    logInfo("Upgrade forcado falhou: " .. tostring(err))
    return
  end

  local valid, reason = validateUpgradeFile(data)
  if not valid then
    logInfo("Upgrade forcado cancelado: " .. tostring(reason))
    return
  end

  local remoteVersion = extractRemoteVersion(data)
  if not remoteVersion then
    logInfo("Upgrade forcado falhou: nao encontrei versao no arquivo remoto.")
    return
  end

  writeUpgradeFile(tostring(data or ""), remoteVersion)
end

local function requestUpgradeFile(url)
  local started = false

  if type(HTTP) == "table" and type(HTTP.get) == "function" then
    local ok = pcall(function()
      HTTP.get(url, function(data, err)
        finishForceUpgrade(data, err)
      end)
    end)
    if ok then started = true end
  end

  if not started and type(g_http) == "table" and type(g_http.get) == "function" then
    local ok = pcall(function()
      g_http.get(url, function(data, err)
        finishForceUpgrade(data, err)
      end)
    end)
    if ok then started = true end
  end

  if not started then
    upgradeCheckBusy = false
    logInfo("Upgrade forcado indisponivel: HTTP.get/g_http.get nao encontrado neste cliente.")
  end
end

local function forceMonsterClaimUpgrade()
  if upgradeCheckBusy == true then
    logInfo("Upgrade forcado ja esta em andamento.")
    return false
  end

  upgradeCheckBusy = true
  logInfo("Baixando update forcado do Monster Claim...")
  requestUpgradeFile(MONSTER_CLAIM_MANAGER_URL)
  return true
end

-- ============================================================
-- KILLER AUTH / DISTANCE / CLAIMS
-- ============================================================

local function isAuthorizedKiller(name)
  name = name or playerName()
  for _, killerName in ipairs(configuredKillers()) do
    if sameName(killerName, name) then return true end
  end
  return false
end

local function pathFound(path)
  if path == true then return true end
  if type(path) == "table" then return #path > 0 end
  return false
end

local function hasDirectPath(fromPos, toPos)
  if not fromPos or not toPos then return false end
  if distanceCost(fromPos, toPos) <= CONFIG.arriveDistance then return true end

  local maxDist = CONFIG.findPathMaxDistance or 120
  local params = { ignoreNonPathable = false, ignoreCreatures = true, precision = 1 }

  if type(findPath) == "function" then
    local ok, path = pcall(function() return findPath(fromPos, toPos, maxDist, params) end)
    if ok and pathFound(path) then return true end
    ok, path = pcall(function() return findPath(fromPos, toPos, maxDist) end)
    if ok and pathFound(path) then return true end
  end

  if g_map and type(g_map.findPath) == "function" then
    local ok, path = pcall(function() return g_map.findPath(fromPos, toPos, maxDist, params) end)
    if ok and pathFound(path) then return true end
    ok, path = pcall(function() return g_map.findPath(fromPos, toPos, maxDist) end)
    if ok and pathFound(path) then return true end
  end

  return false
end

local autoWalkTo
local performTransitionAction
local routeGraph = nil

local function routeNodePos(node)
  if not node then return nil end
  return { x = node.x, y = node.y, z = node.z }
end

local function addRouteEdge(edges, fromIndex, toIndex, cost)
  edges[fromIndex] = edges[fromIndex] or {}
  table.insert(edges[fromIndex], { to = toIndex, cost = cost })
end

local function buildRouteGraph()
  if routeGraph then return routeGraph end

  local nodes = {}
  for token in tostring(ROUTE_MAP_TEXT or ""):gmatch("[^;]+") do
    local x, y, z, flag = token:match("(%-?%d+),(%-?%d+),(%-?%d+),?(%d*)")
    if x then
      table.insert(nodes, {
        index = #nodes + 1,
        x = tonumber(x),
        y = tonumber(y),
        z = tonumber(z),
        transition = flag == "0"
      })
    end
  end

  local edges = {}
  for index = 1, #nodes - 1 do
    local a = nodes[index]
    local b = nodes[index + 1]

    if a.z == b.z then
      local cost = math.max(1, distance2d(a, b))
      addRouteEdge(edges, index, index + 1, cost)
      addRouteEdge(edges, index + 1, index, cost)
    elseif a.transition == true then
      local cost = CONFIG.transitionActionPenalty + math.abs(a.z - b.z) * CONFIG.floorPenalty + distance2d(a, b)
      addRouteEdge(edges, index, index + 1, cost)
    end
  end

  routeGraph = { nodes = nodes, edges = edges }
  return routeGraph
end

local function nearestRouteNode(pos, preferReachable)
  if not pos then return nil end

  local graph = buildRouteGraph()
  local best = nil
  local bestScore = nil

  for _, node in ipairs(graph.nodes or {}) do
    if node.z == pos.z then
      local nodePos = routeNodePos(node)
      local dist = distance2d(pos, nodePos)
      local reachable = dist <= CONFIG.arriveDistance or hasDirectPath(pos, nodePos)
      local score = dist

      if preferReachable == true and not reachable then
        score = score + CONFIG.noPathPenalty
      end

      if not bestScore or score < bestScore then
        best = node
        bestScore = score
      end
    end
  end

  return best, bestScore
end

local function findRoutePath(startIndex, goalIndex)
  local graph = buildRouteGraph()
  if not startIndex or not goalIndex then return nil end

  local dist = {}
  local prev = {}
  local visited = {}
  dist[startIndex] = 0

  while true do
    local current = nil
    local currentDist = nil

    for index, value in pairs(dist) do
      if not visited[index] and (not currentDist or value < currentDist) then
        current = index
        currentDist = value
      end
    end

    if not current then break end
    if current == goalIndex then break end

    visited[current] = true
    for _, edge in ipairs(graph.edges[current] or {}) do
      local nextDist = currentDist + edge.cost
      if dist[edge.to] == nil or nextDist < dist[edge.to] then
        dist[edge.to] = nextDist
        prev[edge.to] = current
      end
    end
  end

  if startIndex ~= goalIndex and not prev[goalIndex] then return nil end

  local indexes = {}
  local cursor = goalIndex
  while cursor do
    table.insert(indexes, 1, cursor)
    if cursor == startIndex then break end
    cursor = prev[cursor]
  end

  local nodes = {}
  for _, index in ipairs(indexes) do
    table.insert(nodes, graph.nodes[index])
  end

  return nodes, dist[goalIndex] or 0
end

local function planRouteToActive(active, me)
  if not active or not me then return false end

  local startNode = nearestRouteNode(me, true)
  local goalNode = nearestRouteNode(active.pos, false)
  if not startNode or not goalNode then
    navInfo("Mapa embutido sem node compativel para origem/destino.")
    return false
  end

  local nodes, cost = findRoutePath(startNode.index, goalNode.index)
  if not nodes or #nodes == 0 then
    navInfo("Mapa embutido sem rota entre nodes " .. tostring(startNode.index) .. " e " .. tostring(goalNode.index))
    return false
  end

  active.routeNodes = nodes
  active.routeIndex = 1
  active.routeTarget = posText(active.pos)
  active.nextRouteWalkAt = 0
  navInfo("Rota embutida calculada: " .. tostring(#nodes) .. " nodes custo=" .. tostring(cost))
  return true
end

local function followEmbeddedRoute(active, me, tm)
  if not active or not me then return false end

  if active.routeTarget ~= posText(active.pos) or not active.routeNodes then
    if not planRouteToActive(active, me) then return false end
  end

  local node = active.routeNodes[active.routeIndex]
  if not node then
    if me.z == active.pos.z then
      if tm >= (active.nextRouteWalkAt or 0) then
        active.nextRouteWalkAt = tm + CONFIG.directWalkInterval
        navInfo("Fim da rota embutida. Indo ao alvo exato " .. posText(active.pos))
        autoWalkTo(active.pos)
      end
      return true
    end
    active.routeNodes = nil
    return false
  end

  local nodePos = routeNodePos(node)
  local reachDistance = node.transition == true and 0 or 1
  local nextNode = active.routeNodes[active.routeIndex + 1]

  if me.z ~= node.z then
    active.routeIndex = active.routeIndex + 1
    return true
  end

  if distance2d(me, nodePos) <= reachDistance then
    if nextNode and nextNode.z ~= node.z then
      if tm >= (active.nextTransitionActionAt or 0) then
        active.nextTransitionActionAt = tm + CONFIG.transitionActionInterval
        navInfo("Executando transition da rota em " .. posText(nodePos) .. " para " .. posText(nextNode))
        performTransitionAction({ name = "route " .. tostring(node.index), from = nodePos, to = routeNodePos(nextNode), action = "walk" })
      end
      return true
    end

    active.routeIndex = active.routeIndex + 1
    return true
  end

  if tm >= (active.nextRouteWalkAt or 0) then
    active.nextRouteWalkAt = tm + CONFIG.transitionWalkInterval
    navInfo("Seguindo rota embutida node " .. tostring(node.index) .. " em " .. posText(nodePos))
    autoWalkTo(nodePos)
  end

  return true
end

local function estimateCost(fromPos, targetPos)
  if not fromPos or not targetPos then return 999999 end

  local base = distanceCost(fromPos, targetPos)
  if hasDirectPath(fromPos, targetPos) then return base end

  local startNode = nearestRouteNode(fromPos, true)
  local goalNode = nearestRouteNode(targetPos, false)
  if startNode and goalNode then
    local _, routeCost = findRoutePath(startNode.index, goalNode.index)
    if routeCost then
      return routeCost + distance2d(fromPos, routeNodePos(startNode)) + distance2d(targetPos, routeNodePos(goalNode))
    end
  end

  local best = base + CONFIG.noPathPenalty
  for _, transition in ipairs(TRANSITIONS or {}) do
    if transition.from and transition.to then
      local cost = distanceCost(fromPos, transition.from)
        + CONFIG.transitionActionPenalty
        + distanceCost(transition.to, targetPos)
      if cost < best then best = cost end
    end
  end

  return best
end

local killerState = {
  occurrences = {},
  active = nil,
  lastAssignedSent = {},
  lastNoRouteWarnAt = 0
}

local function getOccurrence(monsterName, pos, create)
  local key = occurrenceKey(monsterName, pos)
  local occ = killerState.occurrences[key]
  if not occ and create == true then
    occ = {
      key = key,
      monsterName = monsterName,
      pos = posCopy(pos),
      firstSeenAt = nowMs(),
      lastFoundAt = nowMs(),
      decisionAt = nowMs() + CONFIG.claimWaitTime,
      claims = {},
      assignedTo = nil,
      assignedDistance = nil,
      hunterName = nil,
      done = false
    }
    killerState.occurrences[key] = occ
  end
  return occ
end

local function findSimilarOccurrence(monsterName, pos)
  for _, occ in pairs(killerState.occurrences) do
    if sameName(occ.monsterName, monsterName)
      and not occ.done
      and sameOccurrencePos(occ.pos, pos) then
      return occ
    end
  end
  return nil
end

local function chooseWinner(occ)
  local bestName = nil
  local bestDistance = nil

  for name, claim in pairs(occ.claims or {}) do
    local distance = tonumber(claim.distance)
    if distance and isAuthorizedKiller(name) then
      if not bestName
        or distance < bestDistance
        or (distance == bestDistance and normalize(name) < normalize(bestName)) then
        bestName = name
        bestDistance = distance
      end
    end
  end

  return bestName, bestDistance
end

local function resetKillerActive(reason, sendDone)
  if killerState.active and sendDone == true then
    sendDoneMessage(killerState.active.monsterName, killerState.active.pos)
  end

  killerState.active = nil
  setCaveBot(true)
  setTargetBot(true)

  if reason then logInfo(reason) end
end

-- ============================================================
-- NAVIGATION / TRANSITIONS
-- ============================================================

function autoWalkTo(pos)
  if not pos or type(autoWalk) ~= "function" then return false end
  local ok = pcall(function() autoWalk({ x = pos.x, y = pos.y, z = pos.z }) end)
  return ok == true
end

local function getTileSafe(pos)
  if not pos or not g_map or not g_map.getTile then return nil end
  local ok, tile = pcall(function() return g_map.getTile(pos) end)
  if ok then return tile end
  return nil
end

local function usePosition(pos)
  if not pos then return false end

  if type(use) == "function" then
    local ok = pcall(function() use(pos) end)
    if ok then return true end
  end

  local tile = getTileSafe(pos)
  if tile then
    local thing = nil
    if tile.getTopUseThing then
      local ok, result = pcall(function() return tile:getTopUseThing() end)
      if ok then thing = result end
    end
    if not thing and tile.getTopThing then
      local ok, result = pcall(function() return tile:getTopThing() end)
      if ok then thing = result end
    end
    if thing and g_game and g_game.use then
      local ok = pcall(function() g_game.use(thing) end)
      if ok then return true end
    end
  end

  if g_game and g_game.use then
    local ok = pcall(function() g_game.use(pos) end)
    if ok then return true end
  end

  return false
end

local function sayWords(words)
  words = trim(words)
  if words == "" then return false end
  if type(say) == "function" then
    local ok = pcall(function() say(words) end)
    if ok then return true end
  end
  if type(saySpell) == "function" then
    local ok = pcall(function() saySpell(words) end)
    if ok then return true end
  end
  if type(cast) == "function" then
    local ok = pcall(function() cast(words) end)
    if ok then return true end
  end
  return false
end

function performTransitionAction(transition)
  if not transition then return false end

  local action = normalize(transition.action or "walk")
  navInfo("Executando transition: " .. tostring(transition.name or "?") .. " action=" .. action)

  if action == "walk" then
    local me = playerPos()
    if me and distanceCost(me, transition.from) <= CONFIG.transitionReachDistance then
      return autoWalkTo(transition.to) or autoWalkTo(transition.from)
    end
    return autoWalkTo(transition.from)
  end

  if action == "use" then
    return usePosition(transition.usePos or transition.from)
  end

  if action == "say" then
    return sayWords(transition.words)
  end

  if action == "gotolabel" or action == "label" then
    if CONFIG.useCaveBotLabels == true
      and CaveBot
      and CaveBot.gotoLabel
      and transition.label then
      local ok = pcall(function() CaveBot.gotoLabel(transition.label) end)
      return ok == true
    end
    return false
  end

  if action == "custom" and type(transition.fn) == "function" then
    local ok = pcall(function() transition.fn(transition) end)
    return ok == true
  end

  return false
end

local function chooseTransition(fromPos, targetPos, active)
  local best = nil
  local bestScore = nil

  for index, transition in ipairs(TRANSITIONS or {}) do
    if transition.from and transition.to then
      local usedCount = active and active.usedTransitions and active.usedTransitions[index] or 0
      if usedCount < 3 then
        local reachPenalty = hasDirectPath(fromPos, transition.from) and 0 or CONFIG.noPathPenalty
        local score = distanceCost(fromPos, transition.from)
          + reachPenalty
          + CONFIG.transitionActionPenalty
          + distanceCost(transition.to, targetPos)
          + usedCount * 250

        if not bestScore or score < bestScore then
          bestScore = score
          best = transition
          best.index = index
        end
      end
    end
  end

  return best, bestScore
end

local function updateProgress(active, me)
  if not active or not me then return false end

  local dist = distanceCost(me, active.pos)
  if not active.lastDistance or dist < active.lastDistance - CONFIG.stuckMinProgress then
    active.lastDistance = dist
    active.lastProgressAt = nowMs()
    return true
  end

  if dist > active.lastDistance then active.lastDistance = dist end
  return false
end

local function navigateToActive()
  local active = killerState.active
  if not active then return false end

  local tm = nowMs()
  local me = playerPos()
  if not me then return false end

  updateProgress(active, me)

  if distanceCost(me, active.pos) <= CONFIG.arriveDistance then
    active.arrivedAt = active.arrivedAt or tm
    return true
  end

  local stuck = active.lastProgressAt and tm - active.lastProgressAt > CONFIG.stuckTimeout
  if stuck then
    active.ignoreDirectUntil = tm + CONFIG.ignoreDirectAfterStuckMs
    active.lastProgressAt = tm
    navInfo("Possivel travamento detectado. Tentando TRANSITIONS.")
  end

  local canDirect = tm >= (active.ignoreDirectUntil or 0) and hasDirectPath(me, active.pos)
  if canDirect then
    if tm >= (active.nextWalkAt or 0) then
      active.nextWalkAt = tm + CONFIG.directWalkInterval
      navInfo("Caminho direto encontrado: autoWalk alvo " .. posText(active.pos))
      autoWalkTo(active.pos)
    end
    return true
  end

  if followEmbeddedRoute(active, me, tm) then
    return true
  end

  local transition = chooseTransition(me, active.pos, active)
  if not transition then
    if tm - killerState.lastNoRouteWarnAt > 3000 then
      killerState.lastNoRouteWarnAt = tm
      logInfo("Sem caminho direto e sem TRANSITIONS cadastradas para " .. posText(active.pos))
    end
    return false
  end

  local distToTransition = distanceCost(me, transition.from)
  if distToTransition > CONFIG.transitionReachDistance then
    if tm >= (active.nextTransitionWalkAt or 0) then
      active.nextTransitionWalkAt = tm + CONFIG.transitionWalkInterval
      navInfo("Indo para transition " .. tostring(transition.name or "?") .. " em " .. posText(transition.from))
      autoWalkTo(transition.from)
    end
    return true
  end

  if tm >= (active.nextTransitionActionAt or 0) then
    active.nextTransitionActionAt = tm + CONFIG.transitionActionInterval
    active.usedTransitions = active.usedTransitions or {}
    active.usedTransitions[transition.index] = (active.usedTransitions[transition.index] or 0) + 1
    return performTransitionAction(transition)
  end

  return true
end

-- ============================================================
-- HUNTER MODE
-- ============================================================

local hunterState = {
  lastSendAt = 0,
  monsterVisible = false,
  lastSeenAt = 0,
  lastSentPosSource = nil
}

local function chooseReportPosition(creature)
  local source = "hunter"
  local p = nil

  if CONFIG.useMonsterPosition == true then
    p = creaturePos(creature)
    if p then source = "monster" end
  end

  if not p then
    p = playerPos()
    source = "hunter"
  end

  return p, source
end

local function runHunter()
  local tm = nowMs()
  local monster = findConfiguredMonster()

  if monster then
    hunterState.monsterVisible = true
    hunterState.lastSeenAt = tm
    setCaveBot(false)

    local target = currentTarget()
    if target and isConfiguredMonster(target) then
      cancelCurrentAttack()
    end

    if CONFIG.hunterAttackOtherMonsters == true and not currentTarget() then
      attackOtherMonster()
    end

    if tm - hunterState.lastSendAt >= CONFIG.hunterSendInterval then
      local p, source = chooseReportPosition(monster)
      local hp = healthPercent(monster)
      if p and sendFoundMessage(p, hp) then
        hunterState.lastSendAt = tm
        hunterState.lastSentPosSource = source
        logInfo("Hunter reportou " .. cfgMonsterName() .. " em " .. posText(p) .. " hp=" .. tostring(hp) .. " source=" .. source)
      end
    end

    return
  end

  local target = currentTarget()
  if target and isConfiguredMonster(target) then
    cancelCurrentAttack()
  end

  if hunterState.monsterVisible and tm - hunterState.lastSeenAt > CONFIG.monsterLostTimeout then
    hunterState.monsterVisible = false
    hunterState.lastSendAt = 0
    setCaveBot(true)
    sendLostMessage()
    logInfo("Hunter perdeu " .. cfgMonsterName() .. ". CaveBot retomado.")
  end
end

-- ============================================================
-- KILLER MODE
-- ============================================================

local function startKillerAssignment(occ, assignedDistance)
  killerState.active = {
    key = occ.key,
    monsterName = occ.monsterName,
    pos = posCopy(occ.pos),
    assignedDistance = assignedDistance,
    startedAt = nowMs(),
    lastSignalAt = occ.lastFoundAt or nowMs(),
    lastProgressAt = nowMs(),
    lastDistance = nil,
    fighting = false,
    lastSeenMonsterAt = 0,
    usedTransitions = {}
  }

  setCaveBot(false)
  setTargetBot(true)
  logInfo("Killer assumiu " .. occ.monsterName .. " em " .. posText(occ.pos) .. " dist=" .. tostring(assignedDistance))
  navigateToActive()
end

local function processPendingDecisions()
  if settings.killerEnabled ~= true or not isAuthorizedKiller() then return end

  local tm = nowMs()
  for _, occ in pairs(killerState.occurrences) do
    if not occ.done and not occ.assignedTo and tm >= occ.decisionAt then
      local winner, distance = chooseWinner(occ)
      if winner then
        occ.assignedTo = winner
        occ.assignedDistance = distance

        if sameName(winner, playerName()) then
          if not killerState.lastAssignedSent[occ.key] then
            killerState.lastAssignedSent[occ.key] = tm
            sendAssignedMessage(occ.monsterName, distance, occ.pos)
          end
          startKillerAssignment(occ, distance)
        else
          logInfo("Outro killer venceu: " .. tostring(winner) .. " dist=" .. tostring(distance))
        end
      end
    end
  end
end

local function attackAssignedMonster()
  local active = killerState.active
  if not active then return false end

  local monster = findConfiguredMonster(active.monsterName)
  if not monster then
    if active.fighting == true
      and nowMs() - active.lastSeenMonsterAt > CONFIG.monsterLostTimeout then
      local donePos = posCopy(active.pos)
      resetKillerActive("Monstro sumiu depois da luta. Finalizando ocorrencia.", false)
      sendDoneMessage(active.monsterName, donePos)
      return true
    end
    return false
  end

  active.fighting = true
  active.lastSeenMonsterAt = nowMs()
  active.lastSignalAt = nowMs()

  local target = currentTarget()
  if not target or not isConfiguredMonster(target, active.monsterName) then
    attackCreature(monster)
    logInfo("Killer atacando " .. active.monsterName)
  end

  return true
end

local function runKiller()
  if not isAuthorizedKiller() then return end

  processPendingDecisions()

  local active = killerState.active
  if not active then return end

  local tm = nowMs()
  if tm - active.startedAt > CONFIG.maxKillerAttemptTime then
    resetKillerActive("Failsafe: tempo maximo para chegar/lutar excedido.", false)
    return
  end

  if tm - active.lastSignalAt > CONFIG.killerSignalTimeout then
    resetKillerActive("Failsafe: sem atualizacao do Hunter por timeout.", false)
    return
  end

  setCaveBot(false)
  setTargetBot(true)

  if attackAssignedMonster() then return end
  navigateToActive()
end

-- ============================================================
-- TALK PARSER
-- ============================================================

local function parseTalkArgs(...)
  local args = {...}
  local data = {
    name = args[1],
    level = args[2],
    mode = args[3],
    text = args[4],
    channelId = args[5]
  }

  if type(data.text) ~= "string" then
    for _, value in ipairs(args) do
      if type(value) == "string" and value:find("^WOLF_") then
        data.text = value
        break
      end
    end
  end

  return data
end

local function talkAllowed(data)
  if CONFIG.guildListenMode ~= nil and tonumber(data.mode) ~= tonumber(CONFIG.guildListenMode) then
    return false
  end
  if CONFIG.guildListenChannelId ~= nil and tonumber(data.channelId) ~= tonumber(CONFIG.guildListenChannelId) then
    return false
  end
  return true
end

local function validProtocol(parts, expected)
  if parts[1] ~= expected then return false end
  if parts[2] ~= CONFIG.secret then return false end
  return true
end

local function handleFound(parts)
  if settings.killerEnabled ~= true or not isAuthorizedKiller() then return end
  if not validProtocol(parts, "WOLF_FOUND") then return end

  local hunterName = parts[3]
  local monsterName = parts[4]
  local pos = parsePos(parts[5])
  local hp = tonumber(parts[6]) or 0
  if not pos or not sameName(monsterName, cfgMonsterName()) then return end

  local occ = findSimilarOccurrence(monsterName, pos) or getOccurrence(monsterName, pos, true)
  occ.hunterName = hunterName
  occ.lastFoundAt = nowMs()
  occ.pos = posCopy(pos)
  occ.hp = hp

  if killerState.active and sameOccurrencePos(killerState.active.pos, pos) then
    if posText(killerState.active.pos) ~= posText(pos) then
      killerState.active.routeNodes = nil
      killerState.active.routeTarget = nil
    end
    killerState.active.pos = posCopy(pos)
    killerState.active.lastSignalAt = nowMs()
    return
  end

  if occ.assignedTo and not sameName(occ.assignedTo, playerName()) then
    return
  end

  local myPos = playerPos()
  if not myPos then return end

  if not occ.claims[playerName()] then
    local cost = estimateCost(myPos, pos)
    if sendClaimMessage(monsterName, cost, pos) then
      occ.claims[playerName()] = { distance = cost, at = nowMs() }
      occ.decisionAt = nowMs() + CONFIG.claimWaitTime
      logInfo("Claim enviado dist=" .. tostring(cost) .. " alvo=" .. posText(pos))
    else
      logInfo("Falha ao enviar claim. Confira guildChannelId/metodo de envio.")
    end
  end
end

local function handleClaim(parts)
  if settings.killerEnabled ~= true or not isAuthorizedKiller() then return end
  if not validProtocol(parts, "WOLF_CLAIM") then return end

  local killerName = parts[3]
  local monsterName = parts[4]
  local distance = tonumber(parts[5])
  local pos = parsePos(parts[6])
  if not distance or not pos or not sameName(monsterName, cfgMonsterName()) then return end
  if not isAuthorizedKiller(killerName) then return end

  local occ = findSimilarOccurrence(monsterName, pos) or getOccurrence(monsterName, pos, true)
  occ.claims[killerName] = { distance = distance, at = nowMs() }
  occ.lastFoundAt = math.max(occ.lastFoundAt or 0, nowMs() - CONFIG.claimWaitTime)
end

local function handleAssigned(parts)
  if settings.killerEnabled ~= true or not isAuthorizedKiller() then return end
  if not validProtocol(parts, "WOLF_ASSIGNED") then return end

  local killerName = parts[3]
  local monsterName = parts[4]
  local distance = tonumber(parts[5])
  local pos = parsePos(parts[6])
  if not pos or not sameName(monsterName, cfgMonsterName()) then return end
  if not isAuthorizedKiller(killerName) then return end

  local occ = findSimilarOccurrence(monsterName, pos) or getOccurrence(monsterName, pos, true)
  occ.assignedTo = killerName
  occ.assignedDistance = distance

  if sameName(killerName, playerName()) then
    startKillerAssignment(occ, distance)
  elseif killerState.active and sameOccurrencePos(killerState.active.pos, pos) then
    resetKillerActive("Outro killer foi designado: " .. tostring(killerName), false)
  else
    logInfo("Designado: " .. tostring(killerName) .. " para " .. posText(pos))
  end
end

local function clearOccurrencesForMonster(monsterName, reason)
  for key, occ in pairs(killerState.occurrences) do
    if sameName(occ.monsterName, monsterName) then
      occ.done = true
      killerState.occurrences[key] = nil
    end
  end

  if killerState.active and sameName(killerState.active.monsterName, monsterName) then
    resetKillerActive(reason, false)
  end
end

local function handleLost(parts)
  if not validProtocol(parts, "WOLF_LOST") then return end
  local monsterName = parts[4]
  if not sameName(monsterName, cfgMonsterName()) then return end
  clearOccurrencesForMonster(monsterName, "Recebido WOLF_LOST. Resetando ocorrencia.")
end

local function handleDone(parts)
  if not validProtocol(parts, "WOLF_DONE") then return end
  local monsterName = parts[4]
  if not sameName(monsterName, cfgMonsterName()) then return end
  clearOccurrencesForMonster(monsterName, "Recebido WOLF_DONE. Resetando ocorrencia.")
end

local function handleProtocolText(text)
  text = tostring(text or "")
  if not text:find("^WOLF_") then return end

  local parts = splitPipe(text)
  if parts[1] == "WOLF_FOUND" then
    handleFound(parts)
  elseif parts[1] == "WOLF_CLAIM" then
    handleClaim(parts)
  elseif parts[1] == "WOLF_ASSIGNED" then
    handleAssigned(parts)
  elseif parts[1] == "WOLF_LOST" then
    handleLost(parts)
  elseif parts[1] == "WOLF_DONE" then
    handleDone(parts)
  end
end

if type(onTalk) == "function" then
  onTalk(function(...)
    local data = parseTalkArgs(...)

    if cfgDebugTalk() then
      local debugText =
        "Talk Debug | name=" .. tostring(data.name) ..
        " | level=" .. tostring(data.level) ..
        " | mode=" .. tostring(data.mode) ..
        " | channelId=" .. tostring(data.channelId) ..
        " | text=" .. tostring(data.text)
      if type(warn) == "function" then
        warn(debugText)
      elseif type(print) == "function" then
        print(debugText)
      end
    end

    if not talkAllowed(data) then return end
    handleProtocolText(data.text)
  end)
end

-- ============================================================
-- SETUP UI
-- ============================================================

local ui = nil
local setupWindow = nil
local setupWindowLoaded = false
local refreshUi

local function setWidgetText(widget, text)
  if widget and widget.setText then
    pcall(function()
      text = tostring(text or "")
      if widget.getText and tostring(widget:getText() or "") == text then return end
      widget:setText(text)
    end)
  end
end

local function setWidgetOn(widget, value)
  if widget and widget.setOn then
    pcall(function() widget:setOn(value == true) end)
  end
end

local function setupControl(id)
  if not setupWindow then return nil end
  if setupWindow[id] then return setupWindow[id] end
  if setupWindow.body and setupWindow.body[id] then return setupWindow.body[id] end
  return nil
end

local function fillSetupWindow()
  if not setupWindow then return end
  setWidgetText(setupControl("monsterName"), cfgMonsterName())
  setWidgetText(setupControl("leaderInput"), "")
end

local function refreshLeaderList()
  local list = setupControl("leadersList")
  if not list then return end

  if list.destroyChildren then pcall(function() list:destroyChildren() end) end

  local names = configuredKillers()
  for _, name in ipairs(names) do
    local row = nil
    local ok = false
    if g_ui and g_ui.createWidget then
      ok, row = pcall(function() return g_ui.createWidget("MonsterClaimLeaderItem", list) end)
    end
    if (not ok or not row) and UI and UI.createWidget then
      ok, row = pcall(function() return UI.createWidget("MonsterClaimLeaderItem", list) end)
    end
    if row then
      setWidgetText(row, name)

      if row.remove then
        row.remove.onClick = function()
          local current = configuredKillers()
          local index = findNameIndex(current, name)
          if index then table.remove(current, index) end
          saveConfiguredKillers(current)
          refreshLeaderList()
          refreshUi()
          return true
        end
      end

      if row.up then
        row.up.onClick = function()
          local current = configuredKillers()
          local index = findNameIndex(current, name)
          if index and index > 1 then
            current[index], current[index - 1] = current[index - 1], current[index]
            saveConfiguredKillers(current)
            refreshLeaderList()
            refreshUi()
          end
          return true
        end
      end

      if row.down then
        row.down.onClick = function()
          local current = configuredKillers()
          local index = findNameIndex(current, name)
          if index and index < #current then
            current[index], current[index + 1] = current[index + 1], current[index]
            saveConfiguredKillers(current)
            refreshLeaderList()
            refreshUi()
          end
          return true
        end
      end
    end
  end
end

local function createSetupWindow()
  if setupWindow then return setupWindow end
  if not g_ui or not g_ui.loadUIFromString or not UI or not UI.createWindow then return nil end

  if setupWindowLoaded ~= true then
    pcall(function()
      g_ui.loadUIFromString([[
MonsterClaimLeaderItem < Label
  height: 16
  text-offset: 4 0
  background-color: alpha
  color: #f0f0f0
  font: verdana-11px-bold
  focusable: true

  $focus:
    background-color: #00000055

  Button
    id: remove
    anchors.right: parent.right
    anchors.top: parent.top
    margin-right: 18
    width: 14
    height: 14
    text: x

  Button
    id: down
    anchors.right: remove.left
    anchors.top: remove.top
    margin-right: 2
    width: 14
    height: 14
    text: v

  Button
    id: up
    anchors.right: down.left
    anchors.top: remove.top
    margin-right: 2
    width: 14
    height: 14
    text: ^

MonsterClaimSetupWindow < MainWindow
  text: Monster Claim
  size: 520 330
  padding: 10
  @onEscape: self:hide()

  Panel
    id: body
    anchors.fill: parent
    image-source: /images/ui/panel_flat
    image-border: 5
    padding: 12

    Label
      id: title
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: 18
      text-align: center
      color: #ffd36b
      font: verdana-11px-bold
      text: MONSTER CLAIM MANAGER

    Label
      id: monsterLabel
      anchors.top: title.bottom
      anchors.left: parent.left
      margin-top: 14
      width: 76
      height: 22
      color: #dce4ee
      font: verdana-11px-bold
      text: Monstro:

    TextEdit
      id: monsterName
      anchors.top: monsterLabel.top
      anchors.left: monsterLabel.right
      anchors.right: parent.right
      height: 22

    Label
      id: leadersTitle
      anchors.top: monsterLabel.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 15
      height: 18
      text-align: center
      color: #ffd36b
      font: verdana-11px-bold
      text: Lideres autorizados

    TextList
      id: leadersList
      anchors.top: leadersTitle.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 7
      height: 118
      padding: 2
      padding-right: 18
      vertical-scrollbar: leadersScroll

    VerticalScrollBar
      id: leadersScroll
      anchors.top: leadersList.top
      anchors.bottom: leadersList.bottom
      anchors.right: leadersList.right
      step: 14
      pixels-scroll: true

    Button
      id: addLeader
      anchors.top: leadersList.bottom
      anchors.right: parent.right
      margin-top: 8
      width: 42
      height: 22
      text: +

    TextEdit
      id: leaderInput
      anchors.top: addLeader.top
      anchors.left: parent.left
      anchors.right: addLeader.left
      margin-right: 6
      height: 22
      text-align: center

    Label
      id: status
      anchors.top: leaderInput.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 12
      height: 16
      text-align: center
      color: #80f0a4
      font: verdana-11px-bold
      text: Alteracoes salvas automaticamente

    Button
      id: upgradeCheck
      anchors.left: parent.left
      anchors.bottom: parent.bottom
      anchors.right: parent.horizontalCenter
      margin-right: 4
      height: 26
      text: Atualizar Agora

    Button
      id: close
      anchors.left: parent.horizontalCenter
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      margin-left: 4
      height: 26
      text: Fechar
]])
    end)
    setupWindowLoaded = true
  end

  local root = rootWidget or (g_ui.getRootWidget and g_ui.getRootWidget())
  local ok, window = pcall(function() return UI.createWindow("MonsterClaimSetupWindow", root) end)
  if not ok or not window then
    ok, window = pcall(function() return UI.createWindow("MonsterClaimSetupWindow") end)
  end
  if not ok or not window then return nil end

  setupWindow = window
  setupWindow:hide()

  local monsterEdit = setupControl("monsterName")
  local leaderInput = setupControl("leaderInput")
  local addLeader = setupControl("addLeader")
  local upgradeCheck = setupControl("upgradeCheck")
  local close = setupControl("close")

  if monsterEdit then
    monsterEdit.onTextChange = function(_, text)
      local value = trim(text)
      if value ~= "" then settings.monsterName = value end
      refreshUi()
    end
  end

  local function addLeaderFromInput()
    if not leaderInput or not leaderInput.getText then return false end
    local name = trim(leaderInput:getText())
    if name == "" then return false end

    local current = configuredKillers()
    if not findNameIndex(current, name) then
      table.insert(current, name)
      saveConfiguredKillers(current)
    end

    setWidgetText(leaderInput, "")
    refreshLeaderList()
    refreshUi()
    return true
  end

  if addLeader then
    addLeader.onClick = addLeaderFromInput
  end

  if leaderInput then
    leaderInput.onKeyPress = function(_, keyCode)
      if keyCode == 5 then
        addLeaderFromInput()
        return true
      end
      return false
    end
  end

  if upgradeCheck then
    upgradeCheck.onClick = function()
      forceMonsterClaimUpgrade()
      return true
    end
  end

  if close then
    close.onClick = function()
      setupWindow:hide()
      return true
    end
  end

  fillSetupWindow()
  refreshLeaderList()
  return setupWindow
end

local function openSetupWindow()
  local window = createSetupWindow()
  if not window then
    logInfo("Janela de setup indisponivel neste cliente.")
    return false
  end
  fillSetupWindow()
  refreshLeaderList()
  window:show()
  window:raise()
  if window.focus then window:focus() end
  return true
end

refreshUi = function()
  if not ui then return end
  setWidgetOn(ui.hunter, settings.hunterEnabled == true)
  setWidgetOn(ui.killer, settings.killerEnabled == true)
end

if type(setupUI) == "function" then
  local ok, panel = pcall(function()
    return setupUI([[
Panel
  height: 58
  image-source: /images/ui/panel_flat
  image-border: 5
  padding: 4

  BotSwitch
    id: hunter
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.horizontalCenter
    margin-right: 3
    height: 22
    text-align: center
    text: Hunter

  BotSwitch
    id: killer
    anchors.top: parent.top
    anchors.left: parent.horizontalCenter
    anchors.right: parent.right
    margin-left: 3
    height: 22
    text-align: center
    text: Killer

  Button
    id: setup
    anchors.top: hunter.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 5
    height: 22
    text: Setup
]])
  end)

  if ok and panel then
    ui = panel

    if ui.hunter then
      ui.hunter.onClick = function()
        settings.hunterEnabled = not settings.hunterEnabled
        if settings.hunterEnabled ~= true and hunterState.monsterVisible == true then
          hunterState.monsterVisible = false
          setCaveBot(true)
        end
        refreshUi()
        return true
      end
    end

    if ui.killer then
      ui.killer.onClick = function()
        settings.killerEnabled = not settings.killerEnabled
        if settings.killerEnabled ~= true then
          resetKillerActive("Killer ativo desligado.", false)
        end
        refreshUi()
        return true
      end
    end

    if ui.setup then
      ui.setup.onClick = openSetupWindow
    end

    refreshUi()
  end
end

-- ============================================================
-- MAIN LOOPS
-- ============================================================

macro(200, function()
  if settings.hunterEnabled == true then
    runHunter()
  end
end)

macro(200, function()
  if settings.killerEnabled == true then
    runKiller()
  end
end)

macro(1000, function()
  refreshUi()

  local tm = nowMs()
  for key, occ in pairs(killerState.occurrences) do
    if tm - (occ.lastFoundAt or occ.firstSeenAt or tm) > CONFIG.killerSignalTimeout * 2 then
      killerState.occurrences[key] = nil
    end
  end
end)
