-- ComboSystem MultiLideres
-- Versao enxuta: combo chat + hierarquia de callers.

setDefaultTab("Main")

local SMART_PVP_SCRIPT_VERSION = 2026061004
local SMART_PVP_SCRIPT_NAME = "COMBO_ESPART_V3.lua"
local SMART_PVP_UPDATE_URL = "https://api.github.com/repos/Thesaidctm/script-holidayys/contents/COMBO_ESPART_V3.lua?ref=main"

local panelName = "ComboSystem_MultiLideres"
storage[panelName] = storage[panelName] or {}
local settings = storage[panelName]
local oldCombo = storage.Combo or {}
local MAGIC_LONGSWORD_ID = 3278
local GIANT_SWORD_ID = 3281

if settings.enabled == nil then settings.enabled = oldCombo.enabled == true end
if settings.commandPrefix == nil then settings.commandPrefix = "." end
if settings.chatName == nil then settings.chatName = oldCombo.chatName or "ESPARTANOS" end
if settings.comboChatEnabled == nil then settings.comboChatEnabled = true end
if settings.hierarchyEnabled == nil then settings.hierarchyEnabled = true end
if settings.hierarchyRequiresBattle == nil then settings.hierarchyRequiresBattle = true end
if settings.autoOpenChat == nil then settings.autoOpenChat = true end
if settings.autoOpenChatIntervalMs == nil then settings.autoOpenChatIntervalMs = 2500 end
if settings.callTargetIntervalMs == nil then settings.callTargetIntervalMs = 500 end
if settings.autoUpdateEnabled == nil then settings.autoUpdateEnabled = true end
if settings.autoUpdateIntervalSeconds == nil then settings.autoUpdateIntervalSeconds = 600 end
if settings.autoReloadAfterUpdate == nil then settings.autoReloadAfterUpdate = false end
if settings.learnGuildChannel == nil then settings.learnGuildChannel = true end
local initialChatName = tostring(settings.chatName or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
if initialChatName == "guild" or initialChatName == "guild chat" then settings.chatName = "ESPARTANOS" end
if settings.comboSpell == nil then settings.comboSpell = "" end
if settings.comboSpell2 == nil then settings.comboSpell2 = "" end
if settings.comboSpell3 == nil then settings.comboSpell3 = "" end
if settings.comboSpell4 == nil then settings.comboSpell4 = "" end
if settings.comboSpellStepMs == nil then settings.comboSpellStepMs = 500 end
if settings.comboSpellCooldownMs == nil then settings.comboSpellCooldownMs = 700 end
if settings.smartRotationEnabled == nil then settings.smartRotationEnabled = false end
if settings.autoSpellA == nil then settings.autoSpellA = "" end
if settings.autoSpellACooldownMs == nil then settings.autoSpellACooldownMs = 2000 end
if settings.autoSpellB == nil then settings.autoSpellB = "" end
if settings.autoSpellBCooldownMs == nil then settings.autoSpellBCooldownMs = 5000 end
if settings.comboSpellCCooldownMs == nil then settings.comboSpellCCooldownMs = 12000 end
if settings.comboSpellCSlot == nil then settings.comboSpellCSlot = 3 end
if settings.smartSafetyMarginMs == nil then settings.smartSafetyMarginMs = 1000 end
if settings.autoRotationIntervalMs == nil then settings.autoRotationIntervalMs = 200 end
if settings.smartCastConfirmMs == nil then settings.smartCastConfirmMs = 500 end
if settings.smartRetryAfterFailMs == nil then settings.smartRetryAfterFailMs = 250 end
if settings.allowBBeforeFirstCombo == nil then settings.allowBBeforeFirstCombo = false end
if settings.smartStatusHudEnabled == nil then settings.smartStatusHudEnabled = true end
if settings.trapEnabled == nil then settings.trapEnabled = false end
if settings.trapRuneId == nil then settings.trapRuneId = 3180 end
if settings.trapStepMs == nil then settings.trapStepMs = 180 end
if settings.trapCooldownMs == nil then settings.trapCooldownMs = 1500 end
if tonumber(settings.trapCooldownVersion) == 2 and tonumber(settings.trapCooldownMs) == 19000 then settings.trapCooldownMs = 1500 end
settings.trapCooldownVersion = 3
if settings.trapWallDurationMs == nil then settings.trapWallDurationMs = 19000 end
if settings.trapMaxTiles == nil then settings.trapMaxTiles = 24 end
if settings.trapWallIdsText == nil then settings.trapWallIdsText = "2128, 2129, 2130" end
if settings.trapPatternVersion == nil then
  local okTrapMax, trapMax = pcall(function() return tonumber(settings.trapMaxTiles) end)
  if not okTrapMax or not trapMax or trapMax <= 8 then settings.trapMaxTiles = 24 end
  settings.trapPatternVersion = 2
end
if settings.autoSelectVocationFromServer == nil then settings.autoSelectVocationFromServer = true end
if settings.presetVocation == nil then settings.presetVocation = "" end
if settings.detectedVocation == nil then settings.detectedVocation = "" end
if settings.presetUseA == nil then settings.presetUseA = true end
if settings.presetBChoice == nil then settings.presetBChoice = 1 end
if settings.presetCChoice == nil then settings.presetCChoice = 1 end
if settings.targetLockMs == nil then settings.targetLockMs = 1600 end
if type(settings.leaderList) ~= "table" then settings.leaderList = {} end

local function trimText(text)
  text = tostring(text or ""):gsub("%s+", " ")
  return text:gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalizeName(name)
  return trimText(name):lower()
end

local function sameName(a, b)
  return normalizeName(a) ~= "" and normalizeName(a) == normalizeName(b)
end

local function migrateLegacySpellNames()
  for _, key in ipairs({"comboSpell", "comboSpell2", "comboSpell3", "comboSpell4", "autoSpellB"}) do
    if normalizeName(settings[key]) == "exori gran max frigo" then
      settings[key] = "exori max frigo"
    end
  end
end

migrateLegacySpellNames()

local function normalizeVocationName(value)
  local v = normalizeName(value)
  if v == "1" or v == "5" or v == "sorcerer" or v == "ms" or v == "master sorcerer" then return "sorcerer" end
  if v == "2" or v == "6" or v == "druid" or v == "ed" or v == "elder druid" then return "druid" end
  if v == "3" or v == "7" or v == "paladin" or v == "rp" or v == "royal paladin" then return "paladin" end
  if v == "4" or v == "8" or v == "knight" or v == "ek" or v == "elite knight" then return "knight" end
  return ""
end

local vocationPresetSpells = {
  sorcerer = {
    label = "MS - Sorcerer",
    a = nil,
    b = {
      { label = "Vis Hur", spell = "exevo vis hur", cd = 6000 },
      { label = "Max Vis", spell = "exori max vis", cd = 6000 }
    },
    c = {
      { label = "Gran Mas Vis", spell = "exevo gran mas vis", cd = 12000 },
      { label = "Gran Mas Flam", spell = "exevo gran mas flam", cd = 16000 }
    }
  },
  druid = {
    label = "ED - Druid",
    a = nil,
    b = {
      { label = "Tera Hur", spell = "exevo tera hur", cd = 6000 },
      { label = "Max Frigo", spell = "exori max frigo", cd = 5000 }
    },
    c = {
      { label = "Gran Mas Tera", spell = "exevo gran mas tera", cd = 12000 },
      { label = "Gran Mas Frigo", spell = "exevo gran mas frigo", cd = 16000 }
    }
  },
  paladin = {
    label = "RP - Paladin",
    a = { label = "Exori Con", spell = "exori con", cd = 2000 },
    b = {
      { label = "Gran Con", spell = "exori gran con", cd = 5000 }
    },
    c = {
      { label = "Mas San", spell = "exevo mas san", cd = 12000 }
    }
  },
  knight = {
    label = "EK - Knight",
    a = { label = "Exori Ico", spell = "exori ico", cd = 2000 },
    b = {
      { label = "Gran Ico", spell = "exori gran ico", cd = 6000 }
    },
    c = {
      { label = "Exori Gran", spell = "exori gran", cd = 10000 }
    }
  }
}

local presetVocationOrder = {"sorcerer", "druid", "paladin", "knight"}

local function getPresetVocation()
  local detected = normalizeVocationName(settings.detectedVocation)
  local selected = normalizeVocationName(settings.presetVocation)
  if settings.autoSelectVocationFromServer == true and detected ~= "" then return detected end
  if selected ~= "" then return selected end
  if detected ~= "" then return detected end
  return ""
end

local function getVocationPresetConfig(vocation)
  vocation = normalizeVocationName(vocation)
  if vocation == "" then vocation = getPresetVocation() end
  return vocationPresetSpells[vocation], vocation
end

local function getPresetChoiceIndex(groupKey, options)
  local key = groupKey == "c" and "presetCChoice" or "presetBChoice"
  local total = type(options) == "table" and #options or 0
  if total <= 0 then
    settings[key] = 1
    return 1
  end

  local ok, value = pcall(function() return tonumber(settings[key]) end)
  local index = math.floor((ok and value) or 1)
  if index < 1 then index = 1 end
  if index > total then index = total end
  settings[key] = index
  return index
end

local function getSelectedPresetSpell(groupKey)
  local config = getVocationPresetConfig()
  if not config then return nil end

  if groupKey == "a" then return config.a end

  local options = config[groupKey]
  local index = getPresetChoiceIndex(groupKey, options)
  return options and options[index] or nil
end

local function formatPresetVocationLabel(vocation)
  local config
  config, vocation = getVocationPresetConfig(vocation)
  return config and config.label or "Aguardando"
end

local function detectVocationFromText(text)
  text = tostring(text or "")
  if text == "" or not text:find("%[VOCATION%]") then return nil end

  local id, label = text:match("%[VOCATION%]%s*(%d+)%s*|%s*([^%[%]\r\n]+)")
  local vocation = normalizeVocationName(id)
  if vocation == "" then vocation = normalizeVocationName(label) end
  if vocation == "" then
    local lower = normalizeName(text)
    if lower:find("sorcerer", 1, true) or lower:find("master sorcerer", 1, true) then vocation = "sorcerer" end
    if lower:find("druid", 1, true) or lower:find("elder druid", 1, true) then vocation = "druid" end
    if lower:find("paladin", 1, true) or lower:find("royal paladin", 1, true) then vocation = "paladin" end
    if lower:find("knight", 1, true) or lower:find("elite knight", 1, true) then vocation = "knight" end
  end
  if vocation == "" then return nil end

  settings.detectedVocation = vocation
  if settings.autoSelectVocationFromServer == true then
    settings.presetVocation = vocation
  end

  return vocation
end

local function timeMs()
  if type(now) == "number" then return now end
  if type(now) == "function" then
    local ok, value = pcall(now)
    if ok and type(value) == "number" then return value end
  end
  if g_clock and g_clock.millis then return g_clock.millis() end
  return math.floor(os.clock() * 1000)
end

local function toNumber(value, defaultValue)
  local ok, numberValue = pcall(function() return tonumber(value) end)
  if ok and numberValue ~= nil then return numberValue end
  return defaultValue
end

local smartPvpAutoUpdateBusy = false
local smartPvpLastUpdateErrorAt = 0

local function smartPvpEpochSeconds()
  if os and os.time then return os.time() end
  return math.floor(timeMs() / 1000)
end

local function smartPvpUpdateMessage(text)
  local message = "[SMART PVP] " .. tostring(text)
  local shown = false
  if modules and modules.game_textmessage and modules.game_textmessage.displayGameMessage then
    local ok = pcall(function() modules.game_textmessage.displayGameMessage(message) end)
    shown = ok == true
  end
  if not shown and warn then
    warn(message)
  elseif not shown and print then
    print(message)
  end
end

local function smartPvpUpdateError(text, force)
  local tm = smartPvpEpochSeconds()
  if force or tm >= smartPvpLastUpdateErrorAt + 3600 then
    smartPvpLastUpdateErrorAt = tm
    smartPvpUpdateMessage(text)
  end
end

local function smartPvpOnce(callback)
  local called = false
  return function(...)
    if called then return end
    called = true
    callback(...)
  end
end

local function smartPvpNormalizeHttpArgs(a, b, c)
  if type(a) == "string" and #a > 0 then return a, nil end
  if type(b) == "string" and #b > 0 then return b, nil end
  if type(c) == "string" and #c > 0 then return c, nil end
  if type(a) == "table" then
    if type(a.body) == "string" then return a.body, nil end
    if type(a.data) == "string" then return a.data, nil end
    if type(a.response) == "string" then return a.response, nil end
  end
  return nil, tostring(b or c or a or "sem resposta HTTP")
end

local function smartPvpBase64Decode(data)
  data = tostring(data or ""):gsub("[^A-Za-z0-9%+/%=]", "")
  if data == "" then return nil end

  local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  local bits = data:gsub(".", function(char)
    if char == "=" then return "" end
    local index = alphabet:find(char, 1, true)
    if not index then return "" end

    local value = index - 1
    local chunk = ""
    for bit = 6, 1, -1 do
      chunk = chunk .. (value % (2 ^ bit) - value % (2 ^ (bit - 1)) > 0 and "1" or "0")
    end
    return chunk
  end)

  return bits:gsub("%d%d%d?%d?%d?%d?%d?%d?", function(byte)
    if #byte ~= 8 then return "" end

    local value = 0
    for bit = 1, 8 do
      if byte:sub(bit, bit) == "1" then
        value = value + (2 ^ (8 - bit))
      end
    end
    return string.char(value)
  end)
end

local function smartPvpDecodeJsonString(value)
  value = tostring(value or "")
  value = value:gsub("\\n", "")
  value = value:gsub("\\r", "")
  value = value:gsub("\\t", "")
  value = value:gsub("\\/", "/")
  value = value:gsub('\\"', '"')
  value = value:gsub("\\\\", "\\")
  return value
end

local function smartPvpExtractGithubApiScript(data)
  if type(data) ~= "string" or not data:find('"content"%s*:', 1) then return nil end
  if not data:find('"encoding"%s*:%s*"base64"', 1) then return nil end

  local encoded = data:match('"content"%s*:%s*"(.-)"')
  if not encoded then return nil end

  return smartPvpBase64Decode(smartPvpDecodeJsonString(encoded))
end

local function smartPvpHttpGet(url, callback)
  local done = smartPvpOnce(callback)
  if type(HTTP) == "table" and type(HTTP.get) == "function" then
    local ok = pcall(function()
      local response = HTTP.get(url, function(a, b, c)
        local data, err = smartPvpNormalizeHttpArgs(a, b, c)
        done(data, err)
      end)
      if type(response) == "string" then done(response, nil) end
    end)
    if ok then return true end
  end

  if type(g_http) == "table" and type(g_http.get) == "function" then
    local ok = pcall(function()
      local response = g_http.get(url, function(a, b, c)
        local data, err = smartPvpNormalizeHttpArgs(a, b, c)
        done(data, err)
      end)
      if type(response) == "string" then done(response, nil) end
    end)
    if ok then return true end
  end

  done(nil, "HTTP.get/g_http.get indisponivel")
  return false
end

local function smartPvpScriptPath()
  local config = ""
  if type(configName) == "string" and configName ~= "" then
    config = configName
  elseif type(botConfigName) == "string" and botConfigName ~= "" then
    config = botConfigName
  else
    config = "MAGE_FINAL"
  end
  return "/bot/" .. config .. "/" .. SMART_PVP_SCRIPT_NAME
end

local function smartPvpExtractScriptVersion(data)
  if type(data) ~= "string" then return nil end
  return toNumber(data:match("SMART_PVP_SCRIPT_VERSION%s*=%s*(%d+)"))
end

local function smartPvpLooksLikeScript(data)
  return type(data) == "string"
    and #data > 10000
    and data:find("ComboSystem_MultiLideres", 1, true) ~= nil
    and data:find("SMART PVP", 1, true) ~= nil
    and smartPvpExtractScriptVersion(data) ~= nil
end

local function smartPvpNormalizeDownloadedScript(data)
  if smartPvpLooksLikeScript(data) then return data end

  local decoded = smartPvpExtractGithubApiScript(data)
  if smartPvpLooksLikeScript(decoded) then return decoded end

  return data
end

local function smartPvpSaveDownloadedScript(data, remoteVersion)
  if type(g_resources) ~= "table" or type(g_resources.writeFileContents) ~= "function" then
    smartPvpUpdateMessage("Nao foi possivel atualizar: g_resources.writeFileContents indisponivel.")
    return false
  end

  local scriptPath = smartPvpScriptPath()
  if type(g_resources.fileExists) == "function" and type(g_resources.readFileContents) == "function" then
    local okRead, currentData = pcall(function()
      if g_resources.fileExists(scriptPath) then return g_resources.readFileContents(scriptPath) end
      return nil
    end)
    if okRead and type(currentData) == "string" and currentData ~= "" then
      pcall(function() g_resources.writeFileContents(scriptPath .. ".bak", currentData) end)
    end
  end

  local okWrite, err = pcall(function()
    g_resources.writeFileContents(scriptPath, data)
  end)
  if not okWrite then
    smartPvpUpdateMessage("Falha ao salvar update: " .. tostring(err))
    return false
  end

  settings.installedScriptVersion = remoteVersion
  smartPvpUpdateMessage("Atualizado para versao " .. tostring(remoteVersion) .. ". Recarregue o bot para aplicar.")

  if settings.autoReloadAfterUpdate == true and type(schedule) == "function" and type(reload) == "function" then
    schedule(1500, function() reload() end)
  end

  return true
end

local function runSmartPvpAutoUpdate(force)
  if settings.autoUpdateEnabled ~= true and force ~= true then return false end
  if smartPvpAutoUpdateBusy then return false end

  local tm = smartPvpEpochSeconds()
  local interval = toNumber(settings.autoUpdateIntervalSeconds, 600) or 600
  if interval < 60 then interval = 60 end
  if interval > 86400 then interval = 86400 end
  if force ~= true and tm < toNumber(settings.nextAutoUpdateCheckAt, 0) then return false end

  settings.nextAutoUpdateCheckAt = tm + interval
  smartPvpAutoUpdateBusy = true

  smartPvpHttpGet(SMART_PVP_UPDATE_URL, function(data, err)
    smartPvpAutoUpdateBusy = false
    if err or not data then
      smartPvpUpdateError("Falha ao checar update: " .. tostring(err or "sem dados"), force)
      return
    end

    data = smartPvpNormalizeDownloadedScript(data)
    if not smartPvpLooksLikeScript(data) then
      smartPvpUpdateError("Update ignorado: arquivo remoto invalido.", force)
      return
    end

    local remoteVersion = smartPvpExtractScriptVersion(data)
    if not remoteVersion or remoteVersion <= SMART_PVP_SCRIPT_VERSION then return end

    smartPvpSaveDownloadedScript(data, remoteVersion)
  end)

  return true
end

if schedule then
  schedule(2000, function() runSmartPvpAutoUpdate(false) end)
else
  runSmartPvpAutoUpdate(false)
end

local function namesToText(list)
  if type(list) ~= "table" then return "" end
  local names = {}
  for _, name in ipairs(list) do
    name = trimText(name)
    if name ~= "" then table.insert(names, name) end
  end
  return table.concat(names, ", ")
end

local function parseNames(text)
  local list = {}
  for rawName in tostring(text or ""):gmatch("[^,;|\n]+") do
    local name = trimText(rawName)
    if name ~= "" then table.insert(list, name) end
  end
  return list
end

if settings.callersText == nil or settings.callersText == "" then
  settings.callersText = namesToText(settings.leaderList)
  if settings.callersText == "" then settings.callersText = namesToText(oldCombo.leaderList) end
  if settings.callersText == "" and storage.comboLeader then settings.callersText = tostring(storage.comboLeader) end
end

if #settings.leaderList == 0 then
  settings.leaderList = parseNames(settings.callersText)
else
  settings.callersText = namesToText(settings.leaderList)
end

local callerCacheKey = nil
local callerCacheList = {}
local callerCacheSet = {}

local function getCallers()
  local cacheKey = tostring(settings.callersText or "") .. "|" .. namesToText(settings.leaderList)
  if callerCacheKey == cacheKey then return callerCacheList end

  local callers = {}
  local seen = {}
  local function add(name)
    name = trimText(name)
    local key = normalizeName(name)
    if key ~= "" and not seen[key] then
      table.insert(callers, name)
      seen[key] = true
    end
  end

  for _, name in ipairs(parseNames(settings.callersText)) do add(name) end
  for _, name in ipairs(settings.leaderList or {}) do add(name) end

  callerCacheKey = cacheKey
  callerCacheList = callers
  callerCacheSet = {}
  for _, name in ipairs(callers) do
    callerCacheSet[normalizeName(name)] = true
  end

  return callers
end

local function syncCallersText()
  settings.callersText = namesToText(settings.leaderList)
  callerCacheKey = nil
end

local function isCallerName(name)
  getCallers()
  return callerCacheSet[normalizeName(name)] == true
end

local function getCallerRank(name)
  local key = normalizeName(name)
  if key == "" then return nil end
  for index, callerName in ipairs(getCallers()) do
    if normalizeName(callerName) == key then return index end
  end
  return nil
end

local function safeCreatureName(creature)
  if not creature or not creature.getName then return nil end
  local ok, name = pcall(function() return creature:getName() end)
  if ok and name and name ~= "" then return name end
  return nil
end

local function safeCreatureId(creature)
  if not creature or not creature.getId then return nil end
  local ok, id = pcall(function() return creature:getId() end)
  if ok then return toNumber(id) end
  return nil
end

local function safeCreaturePosition(creature)
  if not creature or not creature.getPosition then return nil end
  local ok, position = pcall(function() return creature:getPosition() end)
  if not ok or not position or not position.x or not position.y or not position.z then return nil end
  return {x = position.x, y = position.y, z = position.z}
end

local function getLocalPlayerPositionSafe()
  return safeCreaturePosition(player)
end

local function samePosition(a, b)
  return a and b and a.x == b.x and a.y == b.y and a.z == b.z
end

local function positionKey(position)
  if not position then return "" end
  return tostring(position.x) .. "," .. tostring(position.y) .. "," .. tostring(position.z)
end

local function isLocalPlayerName(name)
  if not player or not player.getName then return false end
  local ok, playerName = pcall(function() return player:getName() end)
  return ok and sameName(name, playerName)
end

local function getLocalPlayerNameSafe()
  if not player or not player.getName then return "" end
  local ok, playerName = pcall(function() return player:getName() end)
  if ok then return trimText(playerName) end
  return ""
end

local function getCreatureByNameSafe(name)
  name = trimText(name)
  if name == "" then return nil end

  if getCreatureByName then
    local ok, creature = pcall(function() return getCreatureByName(name, false) end)
    if ok and creature then return creature end
    ok, creature = pcall(function() return getCreatureByName(name) end)
    if ok and creature then return creature end
  end

  if getSpectators then
    local ok, creature = pcall(function()
      for _, spec in ipairs(getSpectators(false) or {}) do
        if sameName(safeCreatureName(spec), name) then return spec end
      end
      return nil
    end)
    if ok and creature then return creature end
  end

  return nil
end

local function creatureIsPlayerSafe(creature)
  if not creature then return false end
  if creature.isPlayer then
    local ok, isPlayer = pcall(function() return creature:isPlayer() end)
    if ok then return isPlayer == true end
  end
  return true
end

local function getBattleSpectatorsSafe()
  if player and player.getPosition and g_map and g_map.getSpectators then
    local okPos, playerPos = pcall(function() return player:getPosition() end)
    if okPos and playerPos then
      local ok, specs = pcall(function() return g_map.getSpectators(playerPos, false) end)
      if ok and specs then return specs end
      ok, specs = pcall(function() return g_map.getSpectators(playerPos) end)
      if ok and specs then return specs end
    end
  end

  if getSpectators then
    local ok, specs = pcall(function() return getSpectators(false) end)
    if ok and specs then return specs end
  end

  return {}
end

local function callerIsBattleVisible(name)
  name = trimText(name)
  if name == "" then return false end

  for _, spec in ipairs(getBattleSpectatorsSafe()) do
    if creatureIsPlayerSafe(spec) and sameName(safeCreatureName(spec), name) then
      return true
    end
  end

  return false
end

local function getCreatureByIdSafe(id)
  id = toNumber(id)
  if not id then return nil end

  if g_map and g_map.getCreatureById then
    local ok, creature = pcall(function() return g_map.getCreatureById(id) end)
    if ok and creature then return creature end
  end

  for _, spec in ipairs(getBattleSpectatorsSafe()) do
    if safeCreatureId(spec) == id then return spec end
  end

  if getSpectators then
    local ok, creature = pcall(function()
      for _, spec in ipairs(getSpectators(false) or {}) do
        if safeCreatureId(spec) == id then return spec end
      end
      return nil
    end)
    if ok and creature then return creature end
  end

  return nil
end

local function getVisibleHigherCaller(beforeRank)
  beforeRank = toNumber(beforeRank)
  if not beforeRank then return nil end

  for index, callerName in ipairs(getCallers()) do
    if index >= beforeRank then break end
    if settings.hierarchyRequiresBattle ~= true or callerIsBattleVisible(callerName) then return callerName end
  end

  return nil
end

local function safeChatChannelId(channelId)
  channelId = toNumber(channelId)
  if not channelId or channelId < 0 then return nil end
  return channelId
end

local GUILD_CHAT_ALIASES = {
  "ESPARTANOS",
  "Guild",
  "Guild Chat",
  "Guild Channel",
  "Guilda",
  "Chat Guild",
  "Chat da Guild",
  "Canal da Guild"
}

local function getKnownGuildChannelIds()
  local ids = {}
  local seen = {}
  local function add(channelId)
    channelId = safeChatChannelId(channelId)
    if channelId ~= nil and not seen[channelId] then
      table.insert(ids, channelId)
      seen[channelId] = true
    end
  end

  add(settings.lastGuildChannelId)
  add(type(CHANNEL_GUILD) ~= "nil" and CHANNEL_GUILD or nil)
  add(type(ChannelGuild) ~= "nil" and ChannelGuild or nil)
  add(8)
  add(0)

  return ids
end

local function getConfiguredChatNames()
  local names = {}
  local seen = {}
  local function add(name)
    name = trimText(name)
    local key = normalizeName(name)
    if key ~= "" and not seen[key] then
      table.insert(names, name)
      seen[key] = true
    end
  end

  add(settings.chatName)
  add(settings.ownGuildName)
  for _, alias in ipairs(GUILD_CHAT_ALIASES) do
    add(alias)
  end
  return names
end

local function rememberComboChatChannel(channelId)
  if settings.learnGuildChannel ~= true then return false end
  channelId = safeChatChannelId(channelId)
  if channelId == nil then return false end
  settings.lastGuildChannelId = channelId
  return true
end

local function callerCanCommand(name)
  local rank = getCallerRank(name)
  if not rank then return false end
  if settings.hierarchyEnabled ~= true then return true end
  return getVisibleHigherCaller(rank) == nil
end

local function isConfiguredCommandChannel(channelId)
  if channelId == nil then return true end
  if not getChannelId then return true end

  local incomingChannel = safeChatChannelId(channelId)
  if not incomingChannel then return false end
  if incomingChannel == safeChatChannelId(settings.lastGuildChannelId) then return true end

  for _, channelName in ipairs(getConfiguredChatNames()) do
    local ok, configuredChannel = pcall(function() return getChannelId(channelName) end)
    configuredChannel = ok and safeChatChannelId(configuredChannel) or nil
    if configuredChannel then
      if incomingChannel == configuredChannel then return true end
    end
  end

  return false
end

local function settingNumber(key, defaultValue, minValue, maxValue)
  local value = toNumber(settings[key], defaultValue)
  if not value then value = defaultValue end
  if minValue and value < minValue then value = minValue end
  if maxValue and value > maxValue then value = maxValue end
  return value
end

local nextAutoOpenChatAt = 0
local lastChatMissingWarnAt = 0

local function isGuildConfiguredChat(chatName)
  local key = normalizeName(chatName)
  if key == "" then return false end
  for _, alias in ipairs(GUILD_CHAT_ALIASES) do
    if key == normalizeName(alias) then return true end
  end
  if key == normalizeName(settings.ownGuildName) then return true end
  return false
end

local function getChannelIdByName(channelName)
  if not getChannelId then return nil end
  channelName = trimText(channelName)
  if channelName == "" then return nil end
  local ok, channelId = pcall(function() return getChannelId(channelName) end)
  if ok then return safeChatChannelId(channelId) end
  return nil
end

local function getConfiguredChatId(allowGuildFallback)
  local chatName = trimText(settings.chatName or "")
  local channelId = getChannelIdByName(chatName)
  if channelId then return channelId end

  if isGuildConfiguredChat(chatName) then
    for _, channelName in ipairs(getConfiguredChatNames()) do
      channelId = getChannelIdByName(channelName)
      if channelId then return channelId end
    end

    if allowGuildFallback ~= false then
      for _, guildChannelId in ipairs(getKnownGuildChannelIds()) do
        return guildChannelId
      end
    end
  end

  if allowGuildFallback ~= false then
    channelId = safeChatChannelId(settings.lastGuildChannelId)
    if channelId then return channelId end
  end

  return nil
end

local function tryGameCall(fnName, value)
  if not g_game or type(g_game[fnName]) ~= "function" then return false end
  return pcall(function() g_game[fnName](value) end)
end

local function ensureConfiguredChatOpen(force)
  if settings.autoOpenChat ~= true then return false end
  if getConfiguredChatId(false) then return true end

  local chatName = trimText(settings.chatName or "")
  if chatName == "" or not isGuildConfiguredChat(chatName) then return false end

  local tm = timeMs()
  if not force and tm < nextAutoOpenChatAt then return false end
  nextAutoOpenChatAt = tm + settingNumber("autoOpenChatIntervalMs", 2500, 1000, 10000)

  -- Guild channel can be 8 in this OTC; some TFS clients expose it as 0 internally.
  tryGameCall("joinChannel", 8)
  tryGameCall("openChannel", 8)
  tryGameCall("joinChannel", 0)
  tryGameCall("openChannel", 0)

  return getConfiguredChatId(false) ~= nil
end

local function getChatDebugText()
  local parts = {}
  for _, channelName in ipairs(getConfiguredChatNames()) do
    local id = getChannelIdByName(channelName)
    table.insert(parts, channelName .. "=" .. tostring(id or "nil"))
  end
  table.insert(parts, "learned=" .. tostring(safeChatChannelId(settings.lastGuildChannelId) or "nil"))
  table.insert(parts, "guildIds=" .. table.concat(getKnownGuildChannelIds(), ","))
  return table.concat(parts, " ")
end

local function sendConfiguredChatByName(text)
  if type(sayin) ~= "function" then return false end
  for _, channelName in ipairs(getConfiguredChatNames()) do
    if isGuildConfiguredChat(channelName) then
      local ok, result = pcall(function() return sayin(channelName, text) end)
      if ok and result ~= false then return true end
    end
  end
  return false
end

local function sendConfiguredChatText(text, retry)
  local chatId = getConfiguredChatId()
  if chatId and type(sayChannel) == "function" then
    local ok, result = pcall(function() return sayChannel(chatId, text) end)
    if ok and result ~= false then return true end
  end

  if sendConfiguredChatByName(text) then return true end

  ensureConfiguredChatOpen(true)

  if retry ~= false and schedule then
    schedule(300, function()
      sendConfiguredChatText(text, false)
    end)
    return false
  end

  local tm = timeMs()
  if tm >= lastChatMissingWarnAt + 3000 then
    lastChatMissingWarnAt = tm
    warn("Combo Chat: chat da guild nao encontrado. " .. getChatDebugText())
  end
  return false
end

local function getCurrentTargetId()
  if not g_game or type(g_game.getAttackingCreature) ~= "function" then return nil end
  local target = g_game.getAttackingCreature()
  if not target or not target.getId then return nil end
  local ok, targetId = pcall(function() return target:getId() end)
  if ok and targetId then return targetId end
  return nil
end

local lastComboSpellAt = 0

local function castSingleComboSpell(spell)
  spell = trimText(spell)
  if spell == "" then return false end

  if say then
    local ok = pcall(function() say(spell) end)
    if ok then return true end
  end

  if saySpell then
    local ok = pcall(function() saySpell(spell) end)
    if ok then return true end
  end

  if cast then
    local ok = pcall(function() cast(spell) end)
    if ok then return true end
  end

  if TargetBot and TargetBot.saySpell then
    local ok, didCast = pcall(function() return TargetBot.saySpell(spell, 0) end)
    if ok and didCast == true then return true end
  end

  return false
end

local function getComboSpellList()
  local spells = {}
  for _, key in ipairs({"comboSpell", "comboSpell2", "comboSpell3", "comboSpell4"}) do
    local spell = trimText(settings[key] or "")
    if spell ~= "" then table.insert(spells, spell) end
  end
  return spells
end

local smartRotation = {
  status = "PRESSAO",
  lastComboAt = nil,
  lastComboCUsedAt = nil,
  nextComboReadyAt = nil,
  comboExecutingUntil = 0,
  lastAutoCastAt = {
    A = 0,
    B = 0
  },
  lastSpellCastAt = {},
  pendingAutoCast = nil,
  pendingSeq = 0,
  nextRetryAt = 0
}

local nextSmartRotationCheckAt = 0

local function setSmartRotationStatus(status)
  smartRotation.status = status or "PRESSAO"
end

local function getSmartRotationStatus()
  if settings.smartRotationEnabled ~= true then return "PRESSAO" end

  local tm = timeMs()
  if toNumber(smartRotation.comboExecutingUntil, 0) > tm then return "COMBO EXECUTANDO" end
  if smartRotation.pendingAutoCast then return "CONFIRMANDO" end
  if smartRotation.nextComboReadyAt and tm >= smartRotation.nextComboReadyAt then
    return "AGUARDANDO CALLER COMBO"
  end

  return smartRotation.status or "PRESSAO"
end

local function rememberSmartSpellCast(spell, castAt)
  local key = normalizeName(spell)
  if key == "" then return end
  smartRotation.lastSpellCastAt[key] = toNumber(castAt, timeMs())
end

local function getSmartSpellLastCastAt(spell)
  local key = normalizeName(spell)
  if key == "" then return 0 end
  return toNumber(smartRotation.lastSpellCastAt[key], 0)
end

local function isForbiddenAutoSpell(spell)
  local key = normalizeName(spell)
  if key == "" then return false end
  if key == "sd" or key == "sudden death" then return true end
  if key:find("paraly", 1, true) or key:find("paralys", 1, true) then return true end
  return false
end

local function hasAttackTargetSafe()
  if not g_game then return false end

  if type(g_game.getAttackingCreature) == "function" then
    local ok, target = pcall(function() return g_game.getAttackingCreature() end)
    if ok and target then return true end
  end

  if type(g_game.isAttacking) == "function" then
    local ok, attacking = pcall(function() return g_game.isAttacking() end)
    if ok then return attacking == true end
  end

  return false
end

local function noteComboForSmartRotation(comboStartAt, spells, stepMs)
  comboStartAt = toNumber(comboStartAt, timeMs())
  spells = type(spells) == "table" and spells or {}
  stepMs = toNumber(stepMs, 500)

  smartRotation.lastComboAt = comboStartAt
  smartRotation.comboExecutingUntil = comboStartAt + (#spells * stepMs) + 500

  for index, spell in ipairs(spells) do
    rememberSmartSpellCast(spell, comboStartAt + ((index - 1) * stepMs))
  end

  local cSlot = math.floor(settingNumber("comboSpellCSlot", 3, 1, 4))
  local cCooldown = settingNumber("comboSpellCCooldownMs", 12000, 1000, 60000)
  smartRotation.lastComboCUsedAt = comboStartAt + ((cSlot - 1) * stepMs)
  smartRotation.nextComboReadyAt = smartRotation.lastComboCUsedAt + cCooldown
  setSmartRotationStatus("COMBO EXECUTANDO")
end

local function canAutoCastSmartSpell(group, spell, cooldown)
  spell = trimText(spell)
  cooldown = toNumber(cooldown, 0)
  if settings.smartRotationEnabled ~= true then return false end
  if smartRotation.pendingAutoCast then return false end
  if spell == "" or cooldown <= 0 then return false end
  if isForbiddenAutoSpell(spell) then return false end
  if not hasAttackTargetSafe() then return false end

  local tm = timeMs()
  if tm < toNumber(smartRotation.nextRetryAt, 0) then return false end
  if tm < toNumber(smartRotation.comboExecutingUntil, 0) then return false end

  local lastGroupCast = toNumber(smartRotation.lastAutoCastAt[group], 0)
  local lastSpellCast = getSmartSpellLastCastAt(spell)
  local lastCast = math.max(lastGroupCast, lastSpellCast)
  if tm < lastCast + cooldown then return false end

  if not smartRotation.nextComboReadyAt then
    return group == "A" or settings.allowBBeforeFirstCombo == true
  end

  if tm >= smartRotation.nextComboReadyAt then return false end

  local margin = settingNumber("smartSafetyMarginMs", 1000, 0, 10000)
  return tm + cooldown + margin <= smartRotation.nextComboReadyAt
end

local function confirmPendingSmartCast(seq)
  local pending = smartRotation.pendingAutoCast
  if not pending or pending.seq ~= seq then return false end

  smartRotation.pendingAutoCast = nil
  if pending.failed == true then return false end

  local castAt = toNumber(pending.startedAt, timeMs())
  smartRotation.lastAutoCastAt[pending.group] = castAt
  rememberSmartSpellCast(pending.spell, castAt)
  setSmartRotationStatus("PLANEJANDO")
  return true
end

local function beginPendingSmartCast(group, spell, cooldown, startedAt)
  local confirmMs = settingNumber("smartCastConfirmMs", 500, 100, 2000)
  smartRotation.pendingSeq = toNumber(smartRotation.pendingSeq, 0) + 1
  local seq = smartRotation.pendingSeq

  smartRotation.pendingAutoCast = {
    seq = seq,
    group = group,
    spell = spell,
    cooldown = cooldown,
    startedAt = toNumber(startedAt, timeMs()),
    confirmAt = timeMs() + confirmMs,
    failed = false
  }

  setSmartRotationStatus("CONFIRMANDO")

  if schedule then
    schedule(confirmMs, function()
      confirmPendingSmartCast(seq)
    end)
  else
    confirmPendingSmartCast(seq)
  end
end

local function castAutoSmartSpell(group, spell, cooldown)
  if not canAutoCastSmartSpell(group, spell, cooldown) then return false end

  local tm = timeMs()
  if castSingleComboSpell(spell) then
    beginPendingSmartCast(group, spell, cooldown, tm)
    return true
  end

  smartRotation.nextRetryAt = tm + settingNumber("smartRetryAfterFailMs", 250, 100, 2000)
  return false
end

local function isSmartCastFailureText(text)
  local lower = normalizeName(text)
  if lower == "" then return false end

  local needles = {
    "not enough mana",
    "do not have enough mana",
    "don't have enough mana",
    "mana insuficiente",
    "sem mana",
    "falta mana",
    "you are exhausted",
    "you are still exhausted",
    "exhausted",
    "cooldown",
    "wait before",
    "not possible",
    "you cannot",
    "you may not",
    "can't cast",
    "cannot cast"
  }

  for _, needle in ipairs(needles) do
    if lower:find(needle, 1, true) then return true end
  end

  return false
end

local function handleSmartCastFailureText(text)
  local pending = smartRotation.pendingAutoCast
  if not pending or not isSmartCastFailureText(text) then return false end

  local tm = timeMs()
  local confirmAt = toNumber(pending.confirmAt, tm)
  if tm > confirmAt + 250 then return false end

  pending.failed = true
  smartRotation.pendingAutoCast = nil
  smartRotation.nextRetryAt = tm + settingNumber("smartRetryAfterFailMs", 250, 100, 2000)
  setSmartRotationStatus("PLANEJANDO")
  return true
end

local function runSmartRotation()
  if settings.enabled ~= true or settings.smartRotationEnabled ~= true then return end

  local tm = timeMs()
  local interval = settingNumber("autoRotationIntervalMs", 200, 50, 3000)
  if tm < nextSmartRotationCheckAt then return end
  nextSmartRotationCheckAt = tm + interval

  if tm < toNumber(smartRotation.comboExecutingUntil, 0) then
    setSmartRotationStatus("COMBO EXECUTANDO")
    return
  end

  if smartRotation.nextComboReadyAt and tm >= smartRotation.nextComboReadyAt then
    setSmartRotationStatus("AGUARDANDO CALLER COMBO")
    return
  end

  if not hasAttackTargetSafe() then
    setSmartRotationStatus("PRESSAO")
    return
  end

  setSmartRotationStatus("PLANEJANDO")

  local spellB = trimText(settings.autoSpellB or "")
  local cooldownB = settingNumber("autoSpellBCooldownMs", 5000, 500, 60000)
  if castAutoSmartSpell("B", spellB, cooldownB) then return end

  local spellA = trimText(settings.autoSpellA or "")
  local cooldownA = settingNumber("autoSpellACooldownMs", 2000, 500, 60000)
  castAutoSmartSpell("A", spellA, cooldownA)
end

local function castComboSpell()
  local spells = getComboSpellList()
  if #spells == 0 then return false end

  local tm = timeMs()
  local cooldown = settingNumber("comboSpellCooldownMs", 700, 100, 5000)
  if tm < lastComboSpellAt + cooldown then return false end

  local stepMs = settingNumber("comboSpellStepMs", 500, 300, 3000)
  lastComboSpellAt = tm + ((#spells - 1) * stepMs)
  noteComboForSmartRotation(tm, spells, stepMs)

  local didCast = false
  for index, spell in ipairs(spells) do
    local spellToCast = spell
    local delayMs = (index - 1) * stepMs
    if delayMs > 0 and schedule then
      schedule(delayMs, function()
        castSingleComboSpell(spellToCast)
      end)
      didCast = true
    elseif castSingleComboSpell(spellToCast) then
      didCast = true
    end
  end

  return didCast
end

local targetLock = {
  name = "",
  caller = "",
  rank = 0,
  untilMs = 0
}

local comboTarget = {
  id = nil,
  name = "",
  caller = "",
  rank = 999,
  lastAt = 0,
  untilMs = 0,
  candidates = {},
  failedUntil = {}
}

local trapState = {
  lastTrapAt = 0,
  lastCallerMissingWarnAt = 0,
  activeWalls = {}
}

local function isTargetLockActive(tm)
  tm = tm or timeMs()
  return targetLock.name ~= "" and toNumber(targetLock.untilMs, 0) > tm
end

local function rememberComboTarget(creature, targetName)
  comboTarget.id = safeCreatureId(creature)
  comboTarget.name = trimText(safeCreatureName(creature) or targetName or "")
  comboTarget.lastAt = timeMs()
end

local function comboTargetCandidateKey(callerName, targetId)
  return normalizeName(callerName) .. "|" .. tostring(toNumber(targetId) or "")
end

local function cleanupComboTargetCandidates(tm)
  tm = tm or timeMs()

  for key, candidate in pairs(comboTarget.candidates or {}) do
    if type(candidate) ~= "table" or toNumber(candidate.untilMs, 0) <= tm then
      comboTarget.candidates[key] = nil
    end
  end

  for key, untilMs in pairs(comboTarget.failedUntil or {}) do
    if toNumber(untilMs, 0) <= tm then
      comboTarget.failedUntil[key] = nil
    end
  end
end

local function markComboTargetCandidateFailed(candidate, durationMs)
  if not candidate then return end
  local key = comboTargetCandidateKey(candidate.caller, candidate.id)
  if key == "|" then return end
  comboTarget.failedUntil[key] = timeMs() + (durationMs or 700)
end

local function isComboTargetCandidateFailed(candidate, tm)
  if not candidate then return true end
  local key = comboTargetCandidateKey(candidate.caller, candidate.id)
  return toNumber(comboTarget.failedUntil[key], 0) > (tm or timeMs())
end

local function rememberComboTargetId(callerName, targetId)
  targetId = toNumber(targetId)
  if not targetId then return false end

  local tm = timeMs()
  local callerKey = normalizeName(callerName)
  local candidate = {
    id = targetId,
    caller = trimText(callerName),
    rank = getCallerRank(callerName) or 999,
    lastAt = tm,
    untilMs = tm + settingNumber("targetLockMs", 1600, 300, 5000)
  }

  if callerKey ~= "" then
    comboTarget.candidates[callerKey] = candidate
  end

  comboTarget.id = targetId
  comboTarget.name = ""
  comboTarget.caller = candidate.caller
  comboTarget.rank = candidate.rank
  comboTarget.lastAt = tm
  comboTarget.untilMs = candidate.untilMs
  return true
end

local function getCurrentAttackCreatureSafe()
  if not g_game or type(g_game.getAttackingCreature) ~= "function" then return nil end
  local ok, creature = pcall(function() return g_game.getAttackingCreature() end)
  if ok then return creature end
  return nil
end

local function getComboTargetCreature()
  local targetId = toNumber(comboTarget.id)
  if targetId then
    local creature = getCreatureByIdSafe(targetId)
    if creature and safeCreaturePosition(creature) then return creature end
  end

  local targetName = trimText(comboTarget.name)
  if targetName ~= "" then
    local creature = getCreatureByNameSafe(targetName)
    if creature and safeCreaturePosition(creature) then return creature end
  end

  targetName = trimText(targetLock.name)
  if targetName ~= "" then
    local creature = getCreatureByNameSafe(targetName)
    if creature and safeCreaturePosition(creature) then return creature end
  end

  local current = getCurrentAttackCreatureSafe()
  if current and safeCreaturePosition(current) then return current end

  return nil
end

local function getBattlePlayerByName(name)
  name = trimText(name)
  if name == "" then return nil end

  for _, spec in ipairs(getBattleSpectatorsSafe()) do
    if creatureIsPlayerSafe(spec) and sameName(safeCreatureName(spec), name) then
      return spec
    end
  end

  return nil
end

local function signNumber(value)
  if value > 0 then return 1 end
  if value < 0 then return -1 end
  return 0
end

local function getDirectionStepFromSource(targetPos, sourcePos)
  if not targetPos or not sourcePos or targetPos.z ~= sourcePos.z then return 0, 0, 0 end

  local dx = sourcePos.x - targetPos.x
  local dy = sourcePos.y - targetPos.y
  if dx == 0 and dy == 0 then return 0, 0, 0 end

  local absDx = math.abs(dx)
  local absDy = math.abs(dy)
  local stepX = signNumber(dx)
  local stepY = signNumber(dy)

  return stepX, stepY, math.max(absDx, absDy)
end

local function markProtectedTrapPosition(open, targetPos, offsetX, offsetY, maxRadius)
  if type(open) ~= "table" or not targetPos then return end
  offsetX = toNumber(offsetX, 0) or 0
  offsetY = toNumber(offsetY, 0) or 0
  if offsetX == 0 and offsetY == 0 then return end
  if math.max(math.abs(offsetX), math.abs(offsetY)) > (maxRadius or 2) then return end

  local openPos = {x = targetPos.x + offsetX, y = targetPos.y + offsetY, z = targetPos.z}
  open[positionKey(openPos)] = true
end

local function markTrapAttackGate(open, targetPos, sourcePos, maxRadius)
  local stepX, stepY = getDirectionStepFromSource(targetPos, sourcePos)
  if stepX == 0 and stepY == 0 then return end

  if stepX ~= 0 and stepY ~= 0 then
    markProtectedTrapPosition(open, targetPos, stepX, stepY, maxRadius)
    markProtectedTrapPosition(open, targetPos, stepX, 0, maxRadius)
    markProtectedTrapPosition(open, targetPos, 0, stepY, maxRadius)
    return
  end

  if stepX ~= 0 then
    for side = -1, 1 do
      markProtectedTrapPosition(open, targetPos, stepX, side, maxRadius)
    end
    return
  end

  for side = -1, 1 do
    markProtectedTrapPosition(open, targetPos, side, stepY, maxRadius)
  end
end

local function markTrapLineCorridor(open, targetPos, sourcePos, maxRadius)
  if type(open) ~= "table" or not targetPos or not sourcePos or targetPos.z ~= sourcePos.z then return end

  local dx = sourcePos.x - targetPos.x
  local dy = sourcePos.y - targetPos.y
  local lengthSq = (dx * dx) + (dy * dy)
  if lengthSq <= 0 then return end

  local radius = maxRadius or 2
  for offsetX = -radius, radius do
    for offsetY = -radius, radius do
      if offsetX ~= 0 or offsetY ~= 0 then
        if math.max(math.abs(offsetX), math.abs(offsetY)) <= radius then
          local dot = (offsetX * dx) + (offsetY * dy)
          if dot > 0 and dot <= lengthSq then
            local cross = (offsetX * dy) - (offsetY * dx)
            if (cross * cross) <= lengthSq then
              markProtectedTrapPosition(open, targetPos, offsetX, offsetY, radius)
            end
          end
        end
      end
    end
  end
end

local function markOpenTrapLine(open, targetPos, sourcePos, maxRadius)
  if type(open) ~= "table" or not targetPos or not sourcePos or targetPos.z ~= sourcePos.z then return end

  markTrapAttackGate(open, targetPos, sourcePos, maxRadius)
  markTrapLineCorridor(open, targetPos, sourcePos, maxRadius)
end

local function hashText(text)
  text = tostring(text or "")
  local hash = 0
  for i = 1, #text do
    hash = (hash + (text:byte(i) or 0) * i) % 9973
  end
  return hash
end

local function parseTrapWallIds()
  local ids = {}
  for rawId in tostring(settings.trapWallIdsText or ""):gmatch("%d+") do
    local id = toNumber(rawId)
    if id then ids[id] = true end
  end
  return ids
end

local function safeThingId(thing)
  if not thing or not thing.getId then return nil end
  local ok, id = pcall(function() return thing:getId() end)
  if ok then return toNumber(id) end
  return nil
end

local function getTileSafe(tilePos)
  if not tilePos or not g_map or not g_map.getTile then return nil end
  local ok, tile = pcall(function() return g_map.getTile(tilePos) end)
  if ok then return tile end
  return nil
end

local function tileCanShootSafe(tile)
  if not tile then return false end
  if tile.canShoot then
    local ok, canShoot = pcall(function() return tile:canShoot() end)
    if ok then return canShoot ~= false end
  end
  return true
end

local function positionDistance(a, b)
  if not a or not b or a.z ~= b.z then return 999 end
  return math.max(math.abs((a.x or 0) - (b.x or 0)), math.abs((a.y or 0) - (b.y or 0)))
end

local function mapSightClearSafe(fromPos, toPos)
  if not g_map or type(g_map.isSightClear) ~= "function" then return nil end

  local ok, clear = pcall(function() return g_map.isSightClear(fromPos, toPos, true) end)
  if ok then return clear ~= false end

  ok, clear = pcall(function() return g_map.isSightClear(fromPos, toPos) end)
  if ok then return clear ~= false end

  return nil
end

local function manualSightClearSafe(fromPos, toPos)
  if not fromPos or not toPos or fromPos.z ~= toPos.z then return false end

  local x1, y1 = toNumber(fromPos.x), toNumber(fromPos.y)
  local x2, y2 = toNumber(toPos.x), toNumber(toPos.y)
  if not x1 or not y1 or not x2 or not y2 then return false end

  local dx = math.abs(x2 - x1)
  local dy = math.abs(y2 - y1)
  local sx = x1 < x2 and 1 or -1
  local sy = y1 < y2 and 1 or -1
  local err = dx - dy
  local x, y = x1, y1

  while not (x == x2 and y == y2) do
    local e2 = err * 2
    if e2 > -dy then
      err = err - dy
      x = x + sx
    end
    if e2 < dx then
      err = err + dx
      y = y + sy
    end

    local tile = getTileSafe({x = x, y = y, z = fromPos.z})
    if not tile or not tileCanShootSafe(tile) then return false end
  end

  return true
end

local function creatureCanBeAttackedNow(creature)
  local targetPos = safeCreaturePosition(creature)
  local localPos = getLocalPlayerPositionSafe()
  if not targetPos or not localPos or targetPos.z ~= localPos.z then return false end

  if creature.getHealthPercent then
    local ok, hp = pcall(function() return creature:getHealthPercent() end)
    if ok and toNumber(hp, 100) <= 0 then return false end
  end

  local maxRange = settingNumber("targetFallbackMaxRange", 8, 1, 15)
  if positionDistance(localPos, targetPos) > maxRange then return false end

  local targetTile = getTileSafe(targetPos)
  if not targetTile or not tileCanShootSafe(targetTile) then return false end

  local sightClear = mapSightClearSafe(localPos, targetPos)
  if sightClear == false then return false end
  if sightClear == nil and not manualSightClearSafe(localPos, targetPos) then return false end

  return true
end

local function tileHasTrapWall(tile, wallIds)
  if not tile or type(wallIds) ~= "table" then return false end

  local function hasWallId(thing)
    local id = safeThingId(thing)
    return id and wallIds[id] == true
  end

  if tile.getItems then
    local ok, items = pcall(function() return tile:getItems() end)
    if ok and items then
      for _, item in ipairs(items) do
        if hasWallId(item) then return true end
      end
    end
  end

  if tile.getThings then
    local ok, things = pcall(function() return tile:getThings() end)
    if ok and things then
      for _, thing in ipairs(things) do
        if hasWallId(thing) then return true end
      end
    end
  end

  local topThing = nil
  if tile.getTopUseThing then
    local ok, thing = pcall(function() return tile:getTopUseThing() end)
    if ok then topThing = thing end
  end
  if hasWallId(topThing) then return true end

  return false
end

local function cleanupActiveTrapWalls(tm)
  tm = tm or timeMs()
  for key, expiresAt in pairs(trapState.activeWalls or {}) do
    if toNumber(expiresAt, 0) <= tm then
      trapState.activeWalls[key] = nil
    end
  end
end

local function hasActiveTrapWallTimer(tilePos, tm)
  if not tilePos then return false end
  tm = tm or timeMs()
  local key = positionKey(tilePos)
  local expiresAt = toNumber(trapState.activeWalls and trapState.activeWalls[key], 0)
  if expiresAt > tm then return true end
  if trapState.activeWalls then trapState.activeWalls[key] = nil end
  return false
end

local function rememberActiveTrapWall(tilePos)
  if not tilePos then return end
  local duration = settingNumber("trapWallDurationMs", 19000, 1000, 60000)
  if duration <= 0 then return end
  trapState.activeWalls[positionKey(tilePos)] = timeMs() + duration
end

local function tileHasCreatureSafe(tile)
  if not tile or not tile.getCreatures then return false end
  local ok, creatures = pcall(function() return tile:getCreatures() end)
  return ok and creatures and #creatures > 0
end

local function useTrapRuneOnTile(tile)
  if not tile then return false end

  local topThing = nil
  if tile.getTopUseThing then
    local ok, thing = pcall(function() return tile:getTopUseThing() end)
    if ok then topThing = thing end
  end
  if not topThing and tile.getTopThing then
    local ok, thing = pcall(function() return tile:getTopThing() end)
    if ok then topThing = thing end
  end
  if not topThing then return false end

  local runeId = settingNumber("trapRuneId", 3180, 1, 99999)
  if useWith then
    local ok = pcall(function() useWith(runeId, topThing) end)
    if ok then return true end
  end

  if g_game and g_game.useInventoryItemWith then
    local ok = pcall(function() g_game.useInventoryItemWith(runeId, topThing) end)
    if ok then return true end
  end

  return false
end

local function buildTrapTiles(targetPos, localPos, callerPos)
  local open = {}
  markOpenTrapLine(open, targetPos, localPos, 2)
  markOpenTrapLine(open, targetPos, callerPos, 2)

  local sourceStepX, sourceStepY = getDirectionStepFromSource(targetPos, localPos)
  if sourceStepX == 0 and sourceStepY == 0 then
    sourceStepX, sourceStepY = getDirectionStepFromSource(targetPos, callerPos)
  end

  local seedName = getLocalPlayerNameSafe()
  local candidates = {}

  for _, radius in ipairs({2, 1}) do
    for offsetX = -radius, radius do
      for offsetY = -radius, radius do
        if math.max(math.abs(offsetX), math.abs(offsetY)) == radius then
          local tilePos = {x = targetPos.x + offsetX, y = targetPos.y + offsetY, z = targetPos.z}
          local key = positionKey(tilePos)
          if not open[key] and not samePosition(tilePos, localPos) and not samePosition(tilePos, callerPos) then
            table.insert(candidates, {
              pos = tilePos,
              radius = radius,
              dot = (offsetX * sourceStepX) + (offsetY * sourceStepY),
              tie = hashText(seedName .. "|" .. tostring(radius) .. "|" .. tostring(offsetX) .. "|" .. tostring(offsetY))
            })
          end
        end
      end
    end
  end

  table.sort(candidates, function(a, b)
    if a.radius ~= b.radius then return a.radius > b.radius end
    if a.dot ~= b.dot then return a.dot < b.dot end
    if a.tie ~= b.tie then return a.tie < b.tie end
    return positionKey(a.pos) < positionKey(b.pos)
  end)

  local tiles = {}
  for _, candidate in ipairs(candidates) do
    table.insert(tiles, candidate.pos)
  end

  return tiles
end

local function tryTrapTile(tilePos, wallIds)
  local tm = timeMs()
  cleanupActiveTrapWalls(tm)
  if hasActiveTrapWallTimer(tilePos, tm) then return false end

  local tile = getTileSafe(tilePos)
  if not tile then return false end
  if not tileCanShootSafe(tile) then return false end
  if tileHasCreatureSafe(tile) then return false end
  if tileHasTrapWall(tile, wallIds) then return false end
  if useTrapRuneOnTile(tile) then
    rememberActiveTrapWall(tilePos)
    return true
  end
  return false
end

local function executeTrapTarget(callerName, targetId)
  if settings.trapEnabled ~= true then return false end

  targetId = toNumber(targetId)
  if targetId then
    rememberComboTargetId(callerName, targetId)
  end

  local tm = timeMs()
  local cooldown = settingNumber("trapCooldownMs", 1500, 300, 10000)
  if tm < toNumber(trapState.lastTrapAt, 0) + cooldown then return false end

  local target = getComboTargetCreature()
  local targetPos = safeCreaturePosition(target)
  local localPos = getLocalPlayerPositionSafe()
  if not target or not targetPos or not localPos or targetPos.z ~= localPos.z then return false end

  local callerIsLocal = isLocalPlayerName(callerName)
  local callerCreature = callerIsLocal and player or getBattlePlayerByName(callerName)
  local callerPos = callerIsLocal and localPos or safeCreaturePosition(callerCreature)
  if callerPos and callerPos.z ~= targetPos.z then callerPos = nil end
  if not callerIsLocal and not callerPos then
    if tm >= toNumber(trapState.lastCallerMissingWarnAt, 0) + 2000 then
      trapState.lastCallerMissingWarnAt = tm
      warn("Trap Target: caller fora do battle, trap ignorada.")
    end
    return false
  end

  local tiles = buildTrapTiles(targetPos, localPos, callerPos)
  if #tiles == 0 then return false end

  trapState.lastTrapAt = tm
  local wallIds = parseTrapWallIds()
  local stepMs = settingNumber("trapStepMs", 180, 50, 1000)
  local maxTiles = math.floor(settingNumber("trapMaxTiles", 24, 1, 24))
  local startDelay = (hashText(getLocalPlayerNameSafe()) % 4) * 70

  for index, tilePos in ipairs(tiles) do
    if index > maxTiles then break end
    local posToTrap = tilePos
    local delayMs = startDelay + ((index - 1) * stepMs)
    if schedule then
      schedule(delayMs, function()
        tryTrapTile(posToTrap, wallIds)
      end)
    else
      tryTrapTile(posToTrap, wallIds)
    end
  end

  return true
end

local function attackComboCreature(callerName, creature, fallbackName, ignorePriorityLock)
  callerName = trimText(callerName)
  local targetName = trimText(safeCreatureName(creature) or fallbackName or "")
  if targetName == "" then return false end
  if isLocalPlayerName(targetName) or isCallerName(targetName) then return false end

  local tm = timeMs()
  local rank = getCallerRank(callerName) or 999
  if not ignorePriorityLock and isTargetLockActive(tm) and not sameName(targetLock.name, targetName) and rank > toNumber(targetLock.rank, 999) then
    return false
  end

  targetLock.name = targetName
  targetLock.caller = callerName
  targetLock.rank = rank
  targetLock.untilMs = tm + settingNumber("targetLockMs", 1600, 300, 5000)
  rememberComboTarget(creature, targetName)
  comboTarget.caller = callerName
  comboTarget.rank = rank
  comboTarget.untilMs = targetLock.untilMs

  if creature and g_game and g_game.attack then
    pcall(function() g_game.attack(creature) end)
    return true
  end

  return false
end

local function getPriorityComboTargetCandidates(tm)
  tm = tm or timeMs()
  cleanupComboTargetCandidates(tm)

  local candidates = {}
  local seen = {}
  for _, callerName in ipairs(getCallers()) do
    local callerKey = normalizeName(callerName)
    local candidate = comboTarget.candidates[callerKey]
    if candidate and not seen[callerKey] and toNumber(candidate.untilMs, 0) > tm then
      table.insert(candidates, candidate)
      seen[callerKey] = true
    end
  end

  return candidates
end

local retryComboTargetId

local function verifyComboTargetAttack(candidate)
  if not candidate or not schedule then return end
  local checkId = toNumber(candidate.id)
  if not checkId then return end

  schedule(180, function()
    local current = getCurrentAttackCreatureSafe()
    if current and safeCreatureId(current) == checkId and creatureCanBeAttackedNow(current) then return end
    markComboTargetCandidateFailed(candidate, settingNumber("targetLockMs", 1600, 300, 5000))
    if retryComboTargetId then retryComboTargetId() end
  end)
end

local function attackBestComboTarget()
  if settings.enabled ~= true or settings.comboChatEnabled ~= true then return false end

  local tm = timeMs()
  local current = getCurrentAttackCreatureSafe()
  local currentId = safeCreatureId(current)

  for _, candidate in ipairs(getPriorityComboTargetCandidates(tm)) do
    local targetId = toNumber(candidate.id)
    if targetId and not isComboTargetCandidateFailed(candidate, tm) then
      local creature = getCreatureByIdSafe(targetId)
      if creature and creatureCanBeAttackedNow(creature) then
        if currentId == targetId then return true end

        if attackComboCreature(candidate.caller, creature, tostring(targetId), true) then
          verifyComboTargetAttack(candidate)
          return true
        end

        markComboTargetCandidateFailed(candidate, 700)
      else
        markComboTargetCandidateFailed(candidate, 900)
      end
    end
  end

  return false
end

local function attackComboTargetId(callerName, targetId)
  targetId = toNumber(targetId)
  if not targetId then return false end

  rememberComboTargetId(callerName, targetId)
  return attackBestComboTarget()
end

function retryComboTargetId()
  return attackBestComboTarget()
end

local function parseComboTargetIdArgument(text)
  text = trimText(text)
  if text == "" then return nil end

  local lower = text:lower()
  lower = lower:gsub("^targetid%s*", "")
  lower = lower:gsub("^target%s*", "")
  lower = lower:gsub("^id%s*", "")
  lower = lower:gsub("^t%s*", "")

  local rawTargetId = lower:match("(%d+)")
  if not rawTargetId then return nil end
  return toNumber(rawTargetId)
end

local function parseComboChat(payload)
  payload = trimText(payload)
  if payload == "" or settings.comboChatEnabled ~= true then return "none", "" end

  local lower = payload:lower()
  if lower == "combo" then return "combo", "" end
  if lower:sub(1, 6) == "combo " then return "none", "" end
  if lower == "trap" then return "trap", "" end
  if lower:sub(1, 6) == "trapid" then
    local targetId = parseComboTargetIdArgument(payload:sub(7))
    if targetId then return "trap", targetId end
    return "none", ""
  end
  if lower:sub(1, 5) == "trap " then
    local targetId = parseComboTargetIdArgument(payload:sub(6))
    if targetId then return "trap", targetId end
    return "none", ""
  end
  if lower:sub(1, 2) == "t " then
    local targetId = parseComboTargetIdArgument(payload:sub(3))
    if targetId then return "targetId", targetId end
    return "none", ""
  end

  return "none", ""
end

local ui = setupUI([[
Panel
  height: 22

  BotSwitch
    id: enabled
    anchors.top: parent.top
    anchors.left: parent.left
    text-align: center
    width: 142
    height: 20
    !text: tr('SMART PVP')

  Button
    id: setup
    anchors.top: prev.top
    anchors.left: prev.right
    anchors.right: parent.right
    margin-left: 3
    height: 20
    text: Setup
]])

g_ui.loadUIFromString([[
ComboCallerNameItem < Label
  background-color: alpha
  text-offset: 3 0
  focusable: true
  height: 16
  padding-right: 52
  color: #f0f3f7
  font: verdana-11px-bold

  $focus:
    background-color: #00000055

  Button
    id: remove
    text: x
    anchors.right: parent.right
    margin-right: 2
    width: 14
    height: 14

  Button
    id: down
    text: v
    anchors.right: prev.left
    margin-right: 2
    width: 14
    height: 14

  Button
    id: up
    text: ^
    anchors.right: prev.left
    margin-right: 2
    width: 14
    height: 14

ComboCallerListBlock < Panel
  height: 124

  TextList
    id: list
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 96
    padding: 2
    vertical-scrollbar: listScrollBar

  VerticalScrollBar
    id: listScrollBar
    anchors.top: list.top
    anchors.bottom: list.bottom
    anchors.right: list.right
    step: 14
    pixels-scroll: true

  TextEdit
    id: nameEdit
    anchors.left: parent.left
    anchors.top: list.bottom
    margin-top: 5
    width: 128
    height: 18
    text-align: center

  Button
    id: addBtn
    text: +
    anchors.right: parent.right
    anchors.left: nameEdit.right
    anchors.top: nameEdit.top
    margin-left: 3
    height: 18

ComboChatWindow < MainWindow
  text: Combo Chat
  size: 360 740
  @onEscape: self:hide()

  Label
    id: status
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 20
    text-align: center
    color: #ffd36b
    font: verdana-11px-bold

  Panel
    id: callersPanel
    image-source: /images/ui/panel_flat
    image-border: 5
    padding: 6
    anchors.top: status.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 8
    height: 154

    Label
      id: callersLabel
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: 16
      text-align: center
      color: #ffd36b
      font: verdana-11px-bold
      text: Callers em ordem de prioridade

    ComboCallerListBlock
      id: callersBlock
      anchors.top: callersLabel.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 5

  Panel
    id: chatPanel
    image-source: /images/ui/panel_flat
    image-border: 5
    padding: 6
    anchors.top: callersPanel.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 8
    height: 480

    BotSwitch
      id: comboChat
      anchors.top: parent.top
      anchors.left: parent.left
      width: 122
      height: 18
      text-align: center
      text: COMBO CHAT

    BotSwitch
      id: hierarchy
      anchors.top: comboChat.top
      anchors.left: comboChat.right
      anchors.right: parent.right
      margin-left: 8
      height: 18
      text-align: center
      text: HIERARQUIA

    BotSwitch
      id: autoVocation
      anchors.top: comboChat.bottom
      anchors.left: parent.left
      margin-top: 7
      width: 102
      height: 18
      text-align: center
      text: AUTO VOC

    Button
      id: presetVocation
      anchors.top: autoVocation.top
      anchors.left: autoVocation.right
      anchors.right: parent.right
      margin-left: 5
      height: 18
      text: VOC

    Label
      id: detectedVocation
      anchors.top: autoVocation.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 7
      height: 18
      text-align: center
      color: #ffd36b
      text: Detectada: -

    BotSwitch
      id: presetUseA
      anchors.top: detectedVocation.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 7
      height: 18
      text-align: center
      text: USAR A

    Button
      id: presetBChoice1
      anchors.top: presetUseA.bottom
      anchors.left: parent.left
      margin-top: 7
      width: 164
      height: 18
      text: B1

    Button
      id: presetBChoice2
      anchors.top: presetBChoice1.top
      anchors.left: presetBChoice1.right
      anchors.right: parent.right
      margin-left: 5
      height: 18
      text: B2

    Button
      id: presetCChoice1
      anchors.top: presetBChoice1.bottom
      anchors.left: parent.left
      margin-top: 7
      width: 164
      height: 18
      text: C1

    Button
      id: presetCChoice2
      anchors.top: presetCChoice1.top
      anchors.left: presetCChoice1.right
      anchors.right: parent.right
      margin-left: 5
      height: 18
      text: C2

    Label
      id: chatLabel
      anchors.top: presetCChoice1.bottom
      anchors.left: parent.left
      margin-top: 7
      width: 42
      height: 18
      text-offset: 0 3
      text: Chat:

    TextEdit
      id: chatName
      anchors.top: chatLabel.top
      anchors.left: chatLabel.right
      anchors.right: parent.right
      margin-left: 5
      height: 18
      text-align: center

    Label
      id: delayLabel
      anchors.top: chatLabel.bottom
      anchors.left: parent.left
      margin-top: 7
      width: 58
      height: 18
      text-offset: 0 3
      text: Delay:

    TextEdit
      id: comboSpellStepMs
      anchors.top: delayLabel.top
      anchors.left: delayLabel.right
      anchors.right: parent.right
      margin-left: 5
      height: 18
      text-align: center

    BotSwitch
      id: autoOpenChat
      anchors.top: delayLabel.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 7
      height: 18
      text-align: center
      text: AUTO ABRIR CHAT

    BotSwitch
      id: smartRotation
      anchors.top: autoOpenChat.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 7
      height: 18
      text-align: center
      text: SMART ROTATION

    BotSwitch
      id: smartStatusHud
      anchors.top: smartRotation.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 7
      height: 18
      text-align: center
      text: STATUS HUD

    BotSwitch
      id: trapEnabled
      anchors.top: smartStatusHud.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 7
      height: 18
      text-align: center
      text: TRAP TARGET

    Label
      id: trapRuneLabel
      anchors.top: trapEnabled.bottom
      anchors.left: parent.left
      margin-top: 7
      width: 42
      height: 18
      text-offset: 0 3
      text: MW:

    TextEdit
      id: trapRuneId
      anchors.top: trapRuneLabel.top
      anchors.left: trapRuneLabel.right
      margin-left: 5
      width: 78
      height: 18
      text-align: center

    Label
      id: trapStepLabel
      anchors.top: trapRuneLabel.top
      anchors.left: trapRuneId.right
      margin-left: 8
      width: 42
      height: 18
      text-offset: 0 3
      text: Delay:

    TextEdit
      id: trapStepMs
      anchors.top: trapStepLabel.top
      anchors.left: trapStepLabel.right
      anchors.right: parent.right
      margin-left: 5
      height: 18
      text-align: center

    Label
      id: trapCooldownLabel
      anchors.top: trapRuneLabel.bottom
      anchors.left: parent.left
      margin-top: 7
      width: 42
      height: 18
      text-offset: 0 3
      text: CD:

    TextEdit
      id: trapCooldownMs
      anchors.top: trapCooldownLabel.top
      anchors.left: trapCooldownLabel.right
      margin-left: 5
      width: 78
      height: 18
      text-align: center

    Label
      id: trapMaxTilesLabel
      anchors.top: trapCooldownLabel.top
      anchors.left: trapCooldownMs.right
      margin-left: 8
      width: 42
      height: 18
      text-offset: 0 3
      text: Tiles:

    TextEdit
      id: trapMaxTiles
      anchors.top: trapMaxTilesLabel.top
      anchors.left: trapMaxTilesLabel.right
      anchors.right: parent.right
      margin-left: 5
      height: 18
      text-align: center

    Label
      id: trapWallDurationLabel
      anchors.top: trapCooldownLabel.bottom
      anchors.left: parent.left
      margin-top: 7
      width: 58
      height: 18
      text-offset: 0 3
      text: Timer:

    TextEdit
      id: trapWallDurationMs
      anchors.top: trapWallDurationLabel.top
      anchors.left: trapWallDurationLabel.right
      anchors.right: parent.right
      margin-left: 5
      height: 18
      text-align: center

    Label
      id: trapWallIdsLabel
      anchors.top: trapWallDurationLabel.bottom
      anchors.left: parent.left
      margin-top: 7
      width: 58
      height: 18
      text-offset: 0 3
      text: Wall IDs:

    TextEdit
      id: trapWallIdsText
      anchors.top: trapWallIdsLabel.top
      anchors.left: trapWallIdsLabel.right
      anchors.right: parent.right
      margin-left: 5
      height: 18
      text-align: center

  HorizontalSeparator
    anchors.right: parent.right
    anchors.left: parent.left
    anchors.bottom: closeButton.top
    margin-bottom: 8

  Button
    id: updateButton
    text: Atualizar
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    size: 78 21

  Button
    id: closeButton
    text: Fechar
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    size: 60 21
]])

local comboWindow = UI.createWindow("ComboChatWindow", rootWidget or g_ui.getRootWidget())
comboWindow:hide()

local function setLabelText(widget, text, color)
  if widget and widget.setText then widget:setText(text or "") end
  if widget and widget.setColor and color then widget:setColor(color) end
end

local function smartStatusColor(status)
  if status == "AGUARDANDO CALLER COMBO" then return "#ffd36b" end
  if status == "COMBO EXECUTANDO" then return "#6bb7ff" end
  if status == "CONFIRMANDO" then return "#ffb86b" end
  if status == "PRESSAO" then return "#c7c7c7" end
  if status == "OFF" then return "#ff6b6b" end
  return "#57c785"
end

local function getSmartRotationDisplayStatus()
  if settings.smartRotationEnabled ~= true then return "OFF" end
  return getSmartRotationStatus()
end

local function getGameRootPanelSafe()
  if modules and modules.game_interface and modules.game_interface.getRootPanel then
    local ok, root = pcall(function() return modules.game_interface.getRootPanel() end)
    if ok and root then return root end
  end
  if rootWidget then return rootWidget end
  if g_ui and g_ui.getRootWidget then
    local ok, root = pcall(function() return g_ui.getRootWidget() end)
    if ok then return root end
  end
  return nil
end

local function ctrlPressed()
  if modules and modules.corelib and modules.corelib.g_keyboard and modules.corelib.g_keyboard.isCtrlPressed then
    local ok, pressed = pcall(function() return modules.corelib.g_keyboard.isCtrlPressed() end)
    if ok then return pressed == true end
  end
  if modules and modules.corelib and modules.corelib.g_keyboard and modules.corelib.g_keyboard.isKeyPressed then
    local ok, pressed = pcall(function()
      return modules.corelib.g_keyboard.isKeyPressed("Ctrl") or modules.corelib.g_keyboard.isKeyPressed("Control")
    end)
    if ok then return pressed == true end
  end
  if g_keyboard and g_keyboard.isCtrlPressed then
    local ok, pressed = pcall(function() return g_keyboard.isCtrlPressed() end)
    if ok then return pressed == true end
  end
  if g_keyboard and g_keyboard.isKeyPressed then
    local ok, pressed = pcall(function()
      return g_keyboard.isKeyPressed("Ctrl") or g_keyboard.isKeyPressed("Control")
    end)
    if ok then return pressed == true end
  end
  return false
end

local smartStatusHud = nil
local refreshSmartStatusHud = nil

local function findSmartStatusHudWidget(root)
  if not root then return nil end

  if root.recursiveGetChildById then
    local ok, widget = pcall(function() return root:recursiveGetChildById("smartPvpStatusHud") end)
    if ok and widget then return widget end
  end

  if root.getChildById then
    local ok, widget = pcall(function() return root:getChildById("smartPvpStatusHud") end)
    if ok and widget then return widget end
  end

  return nil
end

local function destroyOldSmartStatusHuds(root)
  if not root then return end

  for _ = 1, 20 do
    local oldHud = findSmartStatusHudWidget(root)
    if not oldHud then return end
    pcall(function() oldHud:destroy() end)
  end
end

local function createSmartStatusHud()
  if smartStatusHud then return smartStatusHud end
  if not setupUI then return nil end

  local root = getGameRootPanelSafe()
  if not root then return nil end
  destroyOldSmartStatusHuds(root)

  local ok, hud = pcall(function()
    return setupUI([[
Panel
  id: smartPvpStatusHud
  width: 178
  height: 42
  padding: 2
  background-color: #00000088
  opacity: 0.95
  focusable: true
  phantom: false
  draggable: true

  Label
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 14
    text-align: center
    color: #57c785
    font: verdana-11px-rounded
    text: SMART PVP
    phantom: true

  Label
    id: status
    anchors.top: title.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 2
    height: 22
    text-align: center
    color: #c7c7c7
    font: verdana-11px-bold
    text: PRESSAO
    phantom: true
]], root)
  end)

  if not ok or not hud then return nil end

  local savedPos = settings.smartStatusHudPos
  if type(savedPos) == "table" and savedPos.x and savedPos.y and hud.setPosition then
    hud:setPosition({x = savedPos.x, y = savedPos.y})
  elseif hud.setPosition then
    hud:setPosition({x = 315, y = 220})
  end

  if hud.setTooltip then
    hud:setTooltip("Ctrl + arrastar para mover. Use STATUS HUD no setup para esconder.")
  end

  local moving = false
  local moveStart = nil

  hud.onDragEnter = function(widget, mousePos)
    if not ctrlPressed() then return false end
    if widget.breakAnchors then widget:breakAnchors() end
    widget.movingReference = {x = mousePos.x - widget:getX(), y = mousePos.y - widget:getY()}
    return true
  end

  hud.onDragMove = function(widget, mousePos, moved)
    if not widget.movingReference then return false end
    local parent = widget:getParent()
    if parent and parent.getRect and widget.getWidth and widget.getHeight then
      local rect = parent:getRect()
      local x = math.min(math.max(rect.x, mousePos.x - widget.movingReference.x), rect.x + rect.width - widget:getWidth())
      local y = math.min(math.max(rect.y, mousePos.y - widget.movingReference.y), rect.y + rect.height - widget:getHeight())
      widget:move(x, y)
    else
      widget:setPosition({x = mousePos.x - widget.movingReference.x, y = mousePos.y - widget.movingReference.y})
    end
    return true
  end

  hud.onDragLeave = function(widget, pos)
    widget.movingReference = nil
    settings.smartStatusHudPos = widget:getPosition()
    return true
  end

  hud.onMousePress = function(widget, pos, button)
    if button == MouseLeftButton and ctrlPressed() then
      moving = true
      moveStart = pos
      return true
    end
    return false
  end

  hud.onMouseMove = function(widget, pos, button)
    if not moving or not moveStart then return false end
    local dx = pos.x - moveStart.x
    local dy = pos.y - moveStart.y
    local current = widget:getPosition()
    widget:setPosition({x = current.x + dx, y = current.y + dy})
    moveStart = pos
    return true
  end

  hud.onMouseRelease = function(widget, pos, button)
    if button == MouseLeftButton and moving then
      moving = false
      settings.smartStatusHudPos = widget:getPosition()
      return true
    end
    return false
  end

  smartStatusHud = hud
  return smartStatusHud
end

refreshSmartStatusHud = function()
  local hud = createSmartStatusHud()
  if not hud then return end

  if settings.enabled ~= true or settings.smartStatusHudEnabled ~= true then
    if hud.hide then hud:hide() end
    return
  end

  if hud.show then hud:show() end
  local status = getSmartRotationDisplayStatus()
  local color = smartStatusColor(status)
  setLabelText(hud.status, status, color)
  setLabelText(hud.title, "SMART PVP", settings.smartRotationEnabled == true and "#57c785" or "#ff6b6b")
end

local function refreshStatus()
  if not comboWindow or not comboWindow.status then return end
  local callers = getCallers()
  local active = "Callers: " .. tostring(#callers)
  for _, callerName in ipairs(callers) do
    if callerIsBattleVisible(callerName) then
      active = "Caller ativo: " .. callerName
      break
    end
  end
  setLabelText(comboWindow.status, active, #callers > 0 and "#57c785" or "#ff6b6b")

  if comboWindow.chatPanel and comboWindow.chatPanel.smartStatus then
    local smartStatus = getSmartRotationDisplayStatus()
    setLabelText(comboWindow.chatPanel.smartStatus, smartStatus, smartStatusColor(smartStatus))
  end
  if refreshSmartStatusHud then refreshSmartStatusHud() end
end

local function bindSwitch(widget, key)
  widget:setOn(settings[key] == true)
  widget.onClick = function(w)
    settings[key] = not settings[key]
    w:setOn(settings[key])
    refreshStatus()
  end
end

local function bindNumberEdit(widget, key, defaultValue, minValue, maxValue)
  if not widget then return end
  widget:setText(tostring(settingNumber(key, defaultValue, minValue, maxValue)))
  widget.onTextChange = function(_, text)
    local value = toNumber(trimText(text), defaultValue)
    if value < minValue then value = minValue end
    if value > maxValue then value = maxValue end
    settings[key] = math.floor(value)
    refreshStatus()
  end
end

local function findNameIndex(list, name)
  local key = normalizeName(name)
  if key == "" then return nil end
  for i, value in ipairs(list or {}) do
    if normalizeName(value) == key then return i end
  end
  return nil
end

local function refreshCallerList()
  local block = comboWindow.callersPanel.callersBlock
  if not block or not block.list then return end

  if block.list.destroyChildren then
    block.list:destroyChildren()
  elseif block.list.getChildren then
    for _, child in ipairs(block.list:getChildren()) do child:destroy() end
  end

  for _, name in ipairs(settings.leaderList or {}) do
    local ok, row = pcall(function() return g_ui.createWidget("ComboCallerNameItem", block.list) end)
    if not ok or not row then
      ok, row = pcall(function() return UI.createWidget("ComboCallerNameItem", block.list) end)
    end

    if row then
      row:setText(name)
      row.remove.onClick = function()
        local idx = findNameIndex(settings.leaderList, row:getText())
        if idx then table.remove(settings.leaderList, idx) end
        syncCallersText()
        refreshCallerList()
        refreshStatus()
      end
      row.up.onClick = function()
        local idx = findNameIndex(settings.leaderList, row:getText())
        if idx and idx > 1 then
          settings.leaderList[idx], settings.leaderList[idx - 1] = settings.leaderList[idx - 1], settings.leaderList[idx]
          syncCallersText()
          refreshCallerList()
          refreshStatus()
        end
      end
      row.down.onClick = function()
        local idx = findNameIndex(settings.leaderList, row:getText())
        if idx and idx < #settings.leaderList then
          settings.leaderList[idx], settings.leaderList[idx + 1] = settings.leaderList[idx + 1], settings.leaderList[idx]
          syncCallersText()
          refreshCallerList()
          refreshStatus()
        end
      end
    end
  end
end

local function addCallerFromInput()
  local block = comboWindow.callersPanel.callersBlock
  if not block or not block.nameEdit then return end
  local name = trimText(block.nameEdit:getText())
  if name == "" or findNameIndex(settings.leaderList, name) then return end
  table.insert(settings.leaderList, name)
  block.nameEdit:setText("")
  syncCallersText()
  refreshCallerList()
  refreshStatus()
end

local refreshPresetPanel = nil
local syncComboWindow = nil

local function formatCooldownLabel(ms)
  ms = toNumber(ms, 0)
  if ms <= 0 then return "" end
  return " (" .. tostring(math.floor(ms / 1000)) .. "s)"
end

local function presetSpellLabel(groupKey, fallback)
  local spell = getSelectedPresetSpell(groupKey)
  if not spell then return fallback or "-" end
  return tostring(spell.label or spell.spell or fallback or "-") .. formatCooldownLabel(spell.cd)
end

local function presetOptionButtonText(groupKey, index, prefix)
  local config = getVocationPresetConfig()
  local options = config and config[groupKey] or nil
  local option = options and options[index] or nil
  if not option then return prefix .. ": -" end

  local selected = getPresetChoiceIndex(groupKey, options)
  local mark = selected == index and "[X] " or "[ ] "
  return mark .. prefix .. ": " .. tostring(option.label or option.spell or "-")
end

refreshPresetPanel = function()
  if not comboWindow or not comboWindow.chatPanel then return end
  local panel = comboWindow.chatPanel
  local config, vocation = getVocationPresetConfig()

  if panel.autoVocation and panel.autoVocation.setOn then
    panel.autoVocation:setOn(settings.autoSelectVocationFromServer == true)
  end
  if panel.presetUseA and panel.presetUseA.setOn then
    panel.presetUseA:setOn(settings.presetUseA == true)
    if panel.presetUseA.setText then
      panel.presetUseA:setText(config and config.a and "USAR A" or "A VAZIO")
    end
  end
  if panel.presetVocation and panel.presetVocation.setText then
    panel.presetVocation:setText("VOC: " .. formatPresetVocationLabel(vocation))
  end
  if panel.detectedVocation and panel.detectedVocation.setText then
    local detected = normalizeVocationName(settings.detectedVocation)
    local label = detected ~= "" and formatPresetVocationLabel(detected) or "-"
    panel.detectedVocation:setText("Detectada: " .. label)
  end
  if panel.presetBChoice1 and panel.presetBChoice1.setText then
    panel.presetBChoice1:setText(presetOptionButtonText("b", 1, "B1"))
  end
  if panel.presetBChoice2 and panel.presetBChoice2.setText then
    panel.presetBChoice2:setText(presetOptionButtonText("b", 2, "B2"))
  end
  if panel.presetCChoice1 and panel.presetCChoice1.setText then
    panel.presetCChoice1:setText(presetOptionButtonText("c", 1, "C1"))
  end
  if panel.presetCChoice2 and panel.presetCChoice2.setText then
    panel.presetCChoice2:setText(presetOptionButtonText("c", 2, "C2"))
  end
end

local function cyclePresetVocation()
  local current = getPresetVocation()
  local nextIndex = 1
  if current ~= "" then
    for index, vocation in ipairs(presetVocationOrder) do
      if vocation == current then
        nextIndex = index + 1
        break
      end
    end
  end
  if nextIndex > #presetVocationOrder then nextIndex = 1 end
  settings.presetVocation = presetVocationOrder[nextIndex]
  settings.presetBChoice = 1
  settings.presetCChoice = 1
  refreshPresetPanel()
end

local function cyclePresetChoice(groupKey)
  local config = getVocationPresetConfig()
  if not config then return end
  local options = config[groupKey]
  local total = type(options) == "table" and #options or 0
  if total <= 1 then
    refreshPresetPanel()
    return
  end

  local key = groupKey == "c" and "presetCChoice" or "presetBChoice"
  local index = getPresetChoiceIndex(groupKey, options) + 1
  if index > total then index = 1 end
  settings[key] = index
  refreshPresetPanel()
end

local function applyVocationPreset()
  local config = getVocationPresetConfig()
  if not config then return false end

  local spellA = config.a
  local spellB = getSelectedPresetSpell("b")
  local spellC = getSelectedPresetSpell("c")
  local comboSpells = {}

  if spellA and settings.presetUseA == true then
    table.insert(comboSpells, spellA.spell)
  end
  if spellB then table.insert(comboSpells, spellB.spell) end
  local cSlot = #comboSpells + 1
  if spellC then table.insert(comboSpells, spellC.spell) end

  settings.comboSpell = comboSpells[1] or ""
  settings.comboSpell2 = comboSpells[2] or ""
  settings.comboSpell3 = comboSpells[3] or ""
  settings.comboSpell4 = comboSpells[4] or ""

  settings.autoSpellA = (spellA and settings.presetUseA == true) and spellA.spell or ""
  settings.autoSpellACooldownMs = spellA and spellA.cd or 2000
  settings.autoSpellB = spellB and spellB.spell or ""
  settings.autoSpellBCooldownMs = spellB and spellB.cd or 5000
  settings.comboSpellCCooldownMs = spellC and spellC.cd or 12000
  settings.comboSpellCSlot = spellC and cSlot or 3

  return true
end

local function selectPresetChoiceAndApply(groupKey, index)
  local config = getVocationPresetConfig()
  if not config then
    refreshPresetPanel()
    return
  end

  local options = config[groupKey]
  if type(options) ~= "table" or not options[index] then
    refreshPresetPanel()
    return
  end

  local key = groupKey == "c" and "presetCChoice" or "presetBChoice"
  settings[key] = index
  applyVocationPreset()
  syncComboWindow()
end

syncComboWindow = function()
  refreshCallerList()
  comboWindow.chatPanel.comboChat:setOn(settings.comboChatEnabled == true)
  comboWindow.chatPanel.hierarchy:setOn(settings.hierarchyEnabled == true)
  comboWindow.chatPanel.autoOpenChat:setOn(settings.autoOpenChat == true)
  comboWindow.chatPanel.smartRotation:setOn(settings.smartRotationEnabled == true)
  comboWindow.chatPanel.smartStatusHud:setOn(settings.smartStatusHudEnabled == true)
  comboWindow.chatPanel.trapEnabled:setOn(settings.trapEnabled == true)
  comboWindow.chatPanel.chatName:setText(tostring(settings.chatName or "ESPARTANOS"))
  if comboWindow.chatPanel.comboSpell then comboWindow.chatPanel.comboSpell:setText(tostring(settings.comboSpell or "")) end
  if comboWindow.chatPanel.comboSpell2 then comboWindow.chatPanel.comboSpell2:setText(tostring(settings.comboSpell2 or "")) end
  if comboWindow.chatPanel.comboSpell3 then comboWindow.chatPanel.comboSpell3:setText(tostring(settings.comboSpell3 or "")) end
  if comboWindow.chatPanel.comboSpell4 then comboWindow.chatPanel.comboSpell4:setText(tostring(settings.comboSpell4 or "")) end
  comboWindow.chatPanel.comboSpellStepMs:setText(tostring(settingNumber("comboSpellStepMs", 500, 300, 3000)))
  if comboWindow.chatPanel.autoSpellA then comboWindow.chatPanel.autoSpellA:setText(tostring(settings.autoSpellA or "")) end
  if comboWindow.chatPanel.autoSpellB then comboWindow.chatPanel.autoSpellB:setText(tostring(settings.autoSpellB or "")) end
  if comboWindow.chatPanel.autoSpellACooldownMs then comboWindow.chatPanel.autoSpellACooldownMs:setText(tostring(settingNumber("autoSpellACooldownMs", 2000, 500, 60000))) end
  if comboWindow.chatPanel.autoSpellBCooldownMs then comboWindow.chatPanel.autoSpellBCooldownMs:setText(tostring(settingNumber("autoSpellBCooldownMs", 5000, 500, 60000))) end
  if comboWindow.chatPanel.comboSpellCCooldownMs then comboWindow.chatPanel.comboSpellCCooldownMs:setText(tostring(settingNumber("comboSpellCCooldownMs", 12000, 1000, 60000))) end
  if comboWindow.chatPanel.comboSpellCSlot then comboWindow.chatPanel.comboSpellCSlot:setText(tostring(settingNumber("comboSpellCSlot", 3, 1, 4))) end
  if comboWindow.chatPanel.smartSafetyMarginMs then comboWindow.chatPanel.smartSafetyMarginMs:setText(tostring(settingNumber("smartSafetyMarginMs", 1000, 0, 10000))) end
  if comboWindow.chatPanel.autoRotationIntervalMs then comboWindow.chatPanel.autoRotationIntervalMs:setText(tostring(settingNumber("autoRotationIntervalMs", 200, 50, 3000))) end
  comboWindow.chatPanel.trapRuneId:setText(tostring(settingNumber("trapRuneId", 3180, 1, 99999)))
  comboWindow.chatPanel.trapStepMs:setText(tostring(settingNumber("trapStepMs", 180, 50, 1000)))
  comboWindow.chatPanel.trapCooldownMs:setText(tostring(settingNumber("trapCooldownMs", 1500, 300, 10000)))
  comboWindow.chatPanel.trapWallDurationMs:setText(tostring(settingNumber("trapWallDurationMs", 19000, 1000, 60000)))
  comboWindow.chatPanel.trapMaxTiles:setText(tostring(settingNumber("trapMaxTiles", 24, 1, 24)))
  comboWindow.chatPanel.trapWallIdsText:setText(tostring(settings.trapWallIdsText or "2128, 2129, 2130"))
  refreshPresetPanel()
  refreshStatus()
end

bindSwitch(ui.enabled, "enabled")
bindSwitch(comboWindow.chatPanel.comboChat, "comboChatEnabled")
bindSwitch(comboWindow.chatPanel.hierarchy, "hierarchyEnabled")
bindSwitch(comboWindow.chatPanel.autoOpenChat, "autoOpenChat")
bindSwitch(comboWindow.chatPanel.smartRotation, "smartRotationEnabled")
bindSwitch(comboWindow.chatPanel.smartStatusHud, "smartStatusHudEnabled")
bindSwitch(comboWindow.chatPanel.trapEnabled, "trapEnabled")

comboWindow.chatPanel.autoVocation.onClick = function(w)
  settings.autoSelectVocationFromServer = not settings.autoSelectVocationFromServer
  w:setOn(settings.autoSelectVocationFromServer == true)
  applyVocationPreset()
  syncComboWindow()
end

comboWindow.chatPanel.presetUseA.onClick = function(w)
  settings.presetUseA = not settings.presetUseA
  w:setOn(settings.presetUseA == true)
  applyVocationPreset()
  syncComboWindow()
end

comboWindow.chatPanel.presetVocation.onClick = function()
  cyclePresetVocation()
  applyVocationPreset()
  syncComboWindow()
end
comboWindow.chatPanel.presetBChoice1.onClick = function() selectPresetChoiceAndApply("b", 1) end
comboWindow.chatPanel.presetBChoice2.onClick = function() selectPresetChoiceAndApply("b", 2) end
comboWindow.chatPanel.presetCChoice1.onClick = function() selectPresetChoiceAndApply("c", 1) end
comboWindow.chatPanel.presetCChoice2.onClick = function() selectPresetChoiceAndApply("c", 2) end

comboWindow.callersPanel.callersBlock.addBtn.onClick = addCallerFromInput
comboWindow.callersPanel.callersBlock.nameEdit.onKeyPress = function(_, keyCode)
  if keyCode == 5 then
    addCallerFromInput()
    return true
  end
  return false
end

comboWindow.chatPanel.chatName:setText(tostring(settings.chatName or "ESPARTANOS"))
comboWindow.chatPanel.chatName.onTextChange = function(_, text)
  settings.chatName = text
  ensureConfiguredChatOpen(true)
  refreshStatus()
end

if comboWindow.chatPanel.comboSpell then
  comboWindow.chatPanel.comboSpell:setText(tostring(settings.comboSpell or ""))
  comboWindow.chatPanel.comboSpell.onTextChange = function(_, text)
    settings.comboSpell = trimText(text)
  end
end

if comboWindow.chatPanel.comboSpell2 then
  comboWindow.chatPanel.comboSpell2:setText(tostring(settings.comboSpell2 or ""))
  comboWindow.chatPanel.comboSpell2.onTextChange = function(_, text)
    settings.comboSpell2 = trimText(text)
  end
end

if comboWindow.chatPanel.comboSpell3 then
  comboWindow.chatPanel.comboSpell3:setText(tostring(settings.comboSpell3 or ""))
  comboWindow.chatPanel.comboSpell3.onTextChange = function(_, text)
    settings.comboSpell3 = trimText(text)
  end
end

if comboWindow.chatPanel.comboSpell4 then
  comboWindow.chatPanel.comboSpell4:setText(tostring(settings.comboSpell4 or ""))
  comboWindow.chatPanel.comboSpell4.onTextChange = function(_, text)
    settings.comboSpell4 = trimText(text)
  end
end

comboWindow.chatPanel.comboSpellStepMs:setText(tostring(settingNumber("comboSpellStepMs", 500, 300, 3000)))
comboWindow.chatPanel.comboSpellStepMs.onTextChange = function(_, text)
  local value = toNumber(trimText(text), 500)
  if value < 300 then value = 300 end
  if value > 3000 then value = 3000 end
  settings.comboSpellStepMs = value
end

if comboWindow.chatPanel.autoSpellA then
  comboWindow.chatPanel.autoSpellA:setText(tostring(settings.autoSpellA or ""))
  comboWindow.chatPanel.autoSpellA.onTextChange = function(_, text)
    settings.autoSpellA = trimText(text)
  end
end

if comboWindow.chatPanel.autoSpellB then
  comboWindow.chatPanel.autoSpellB:setText(tostring(settings.autoSpellB or ""))
  comboWindow.chatPanel.autoSpellB.onTextChange = function(_, text)
    settings.autoSpellB = trimText(text)
  end
end

bindNumberEdit(comboWindow.chatPanel.autoSpellACooldownMs, "autoSpellACooldownMs", 2000, 500, 60000)
bindNumberEdit(comboWindow.chatPanel.autoSpellBCooldownMs, "autoSpellBCooldownMs", 5000, 500, 60000)
bindNumberEdit(comboWindow.chatPanel.comboSpellCCooldownMs, "comboSpellCCooldownMs", 12000, 1000, 60000)
bindNumberEdit(comboWindow.chatPanel.comboSpellCSlot, "comboSpellCSlot", 3, 1, 4)
bindNumberEdit(comboWindow.chatPanel.smartSafetyMarginMs, "smartSafetyMarginMs", 1000, 0, 10000)
bindNumberEdit(comboWindow.chatPanel.autoRotationIntervalMs, "autoRotationIntervalMs", 200, 50, 3000)
bindNumberEdit(comboWindow.chatPanel.trapRuneId, "trapRuneId", 3180, 1, 99999)
bindNumberEdit(comboWindow.chatPanel.trapStepMs, "trapStepMs", 180, 50, 1000)
bindNumberEdit(comboWindow.chatPanel.trapCooldownMs, "trapCooldownMs", 1500, 300, 10000)
bindNumberEdit(comboWindow.chatPanel.trapWallDurationMs, "trapWallDurationMs", 19000, 1000, 60000)
bindNumberEdit(comboWindow.chatPanel.trapMaxTiles, "trapMaxTiles", 24, 1, 24)

comboWindow.chatPanel.trapWallIdsText:setText(tostring(settings.trapWallIdsText or "2128, 2129, 2130"))
comboWindow.chatPanel.trapWallIdsText.onTextChange = function(_, text)
  settings.trapWallIdsText = trimText(text)
end

ui.setup.onClick = function()
  syncComboWindow()
  comboWindow:show()
  comboWindow:raise()
  comboWindow:focus()
end

comboWindow.closeButton.onClick = function()
  comboWindow:hide()
end

if comboWindow.updateButton then
  comboWindow.updateButton.onClick = function()
    comboSpartForceUpdate()
  end
end

refreshCallerList()
refreshStatus()

local comboIconLocked = false
local trapIconLocked = false
local callTargetIconEnabled = false
local nextCallTargetAt = 0
local lastCallTargetWarnAt = 0
local lastTrapTargetWarnAt = 0

local function sendCurrentTargetIdToComboChat(showWarn)
  if settings.enabled ~= true or settings.comboChatEnabled ~= true then return false end

  local targetId = getCurrentTargetId()
  if not targetId then
    local tm = timeMs()
    if showWarn ~= false and tm >= lastCallTargetWarnAt + 2000 then
      lastCallTargetWarnAt = tm
      warn("Combo Chat: sem target para chamar.")
    end
    return false
  end

  sendConfiguredChatText(".t " .. tostring(targetId))
  return true
end

local function callComboTargetIcon(icon, isOn)
  callTargetIconEnabled = isOn ~= false
  if not callTargetIconEnabled then return end

  nextCallTargetAt = timeMs() + settingNumber("callTargetIntervalMs", 500, 100, 5000)
  sendCurrentTargetIdToComboChat(true)
end

local function runCallTargetIcon()
  if callTargetIconEnabled ~= true then return end
  if settings.enabled ~= true or settings.comboChatEnabled ~= true then return end

  local tm = timeMs()
  if tm < nextCallTargetAt then return end

  nextCallTargetAt = tm + settingNumber("callTargetIntervalMs", 500, 100, 5000)
  sendCurrentTargetIdToComboChat(true)
end

local function callComboSpellIcon(icon, isOn)
  if isOn == false then return end
  if comboIconLocked then return end

  comboIconLocked = true
  sendConfiguredChatText(".combo")

  schedule(2000, function()
    comboIconLocked = false
    if icon and icon.setOn then
      pcall(function() icon:setOn(false) end)
    end
  end)
end

local function callTrapTargetIcon(icon, isOn)
  if isOn == false then return end
  if trapIconLocked then return end

  local targetId = getCurrentTargetId()
  if not targetId then
    local tm = timeMs()
    if tm >= lastTrapTargetWarnAt + 2000 then
      lastTrapTargetWarnAt = tm
      warn("Combo Chat: sem target para trap.")
    end
    if icon and icon.setOn then
      pcall(function() icon:setOn(false) end)
    end
    return
  end

  trapIconLocked = true
  sendConfiguredChatText(".trap " .. tostring(targetId))
  executeTrapTarget(getLocalPlayerNameSafe(), targetId)

  schedule(2000, function()
    trapIconLocked = false
    if icon and icon.setOn then
      pcall(function() icon:setOn(false) end)
    end
  end)
end

if type(addIcon) == "function" then
  local targetIcon = addIcon("EspartanosCallTarget", {
    item = MAGIC_LONGSWORD_ID,
    text = "CALL\nTARGET",
    switchable = true,
    moveable = true
  }, function(icon, isOn)
    callComboTargetIcon(icon, isOn)
  end)

  if targetIcon then
    targetIcon:breakAnchors()
    targetIcon:move(315, 70)
  end

  local comboIcon = addIcon("EspartanosEnviarCombo", {
    item = GIANT_SWORD_ID,
    text = "ENVIAR\nCOMBO",
    switchable = true,
    moveable = true
  }, function(icon, isOn)
    callComboSpellIcon(icon, isOn)
  end)

  if comboIcon then
    comboIcon:breakAnchors()
    comboIcon:move(315, 120)
  end

  local trapIcon = addIcon("EspartanosTrapTarget", {
    item = 3180,
    text = "TRAP\nTARGET",
    switchable = true,
    moveable = true
  }, function(icon, isOn)
    callTrapTargetIcon(icon, isOn)
  end)

  if trapIcon then
    trapIcon:breakAnchors()
    trapIcon:move(315, 170)
  end
end

macro(100, function()
  runCallTargetIcon()
  retryComboTargetId()
  runSmartRotation()
  if refreshSmartStatusHud then refreshSmartStatusHud() end
end)

macro(1000, function()
  runSmartPvpAutoUpdate(false)

  if settings.enabled == true and settings.comboChatEnabled == true then
    ensureConfiguredChatOpen(false)
  end

  if comboWindow and comboWindow.isVisible and comboWindow:isVisible() then refreshStatus() end
  if refreshSmartStatusHud then refreshSmartStatusHud() end
end)

local function handleVocationDetectionText(text)
  local vocation = detectVocationFromText(text)
  if not vocation then return false end
  applyVocationPreset()
  if refreshPresetPanel then refreshPresetPanel() end
  if syncComboWindow then syncComboWindow() end
  refreshStatus()
  return true
end

if type(onTextMessage) == "function" then
  onTextMessage(function(mode, text)
    handleSmartCastFailureText(text)
    handleVocationDetectionText(text)
  end)
end

if type(onTalk) == "function" then
  onTalk(function(name, level, mode, text, channelId, pos)
    handleVocationDetectionText(text)
    if settings.enabled ~= true then return end
    if not name or not text or text == "" then return end
    if isLocalPlayerName(name) then return end
    if not getCallerRank(name) then return end

    local prefix = tostring(settings.commandPrefix or ".")
    if text:sub(1, #prefix) ~= prefix then return end

    rememberComboChatChannel(channelId)
    if not isConfiguredCommandChannel(channelId) then return end

    local payload = trimText(text:sub(#prefix + 1))
    local action, value = parseComboChat(payload)

    if action == "targetId" then
      attackComboTargetId(name, value)
    elseif action == "combo" then
      if not callerCanCommand(name) then return end
      castComboSpell()
    elseif action == "trap" then
      if not callerCanCommand(name) then return end
      executeTrapTarget(name, value)
    end
  end)
end
