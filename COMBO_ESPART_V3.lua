-- ComboSystem MultiLideres
-- Versao enxuta: combo chat + hierarquia de callers.

setDefaultTab("Main")

local panelName = "ComboSystem_MultiLideres"
storage[panelName] = storage[panelName] or {}
local settings = storage[panelName]
local oldCombo = storage.Combo or {}
local MAGIC_LONGSWORD_ID = 3278
local GIANT_SWORD_ID = 3281

if settings.enabled == nil then settings.enabled = oldCombo.enabled == true end
if settings.commandPrefix == nil then settings.commandPrefix = "." end
if settings.chatName == nil then settings.chatName = oldCombo.chatName or "Guild" end
if settings.comboChatEnabled == nil then settings.comboChatEnabled = true end
if settings.hierarchyEnabled == nil then settings.hierarchyEnabled = true end
if settings.hierarchyRequiresBattle == nil then settings.hierarchyRequiresBattle = true end
if settings.autoOpenChat == nil then settings.autoOpenChat = true end
if settings.autoOpenChatIntervalMs == nil then settings.autoOpenChatIntervalMs = 2500 end
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
if settings.allowBBeforeFirstCombo == nil then settings.allowBBeforeFirstCombo = false end
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

local function isLocalPlayerName(name)
  if not player or not player.getName then return false end
  local ok, playerName = pcall(function() return player:getName() end)
  return ok and sameName(name, playerName)
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

local function callerCanCommand(name)
  local rank = getCallerRank(name)
  if not rank then return false end
  if settings.hierarchyEnabled ~= true then return true end
  return getVisibleHigherCaller(rank) == nil
end

local function isConfiguredCommandChannel(channelId)
  if channelId == nil then return true end
  if not getChannelId then return true end

  local incomingChannel = toNumber(channelId)
  if not incomingChannel then return true end

  local candidates = {
    settings.chatName,
    settings.ownGuildName,
    "ESPARTANOS",
    "Guild"
  }

  local hasKnownChannel = false
  local seen = {}
  for _, channelName in ipairs(candidates) do
    channelName = trimText(channelName)
    local key = channelName:lower()
    if channelName ~= "" and not seen[key] then
      seen[key] = true
      local ok, configuredChannel = pcall(function() return getChannelId(channelName) end)
      configuredChannel = ok and toNumber(configuredChannel) or nil
      if configuredChannel then
        hasKnownChannel = true
        if incomingChannel == configuredChannel then return true end
      end
    end
  end

  return not hasKnownChannel
end

local function settingNumber(key, defaultValue, minValue, maxValue)
  local value = toNumber(settings[key], defaultValue)
  if not value then value = defaultValue end
  if minValue and value < minValue then value = minValue end
  if maxValue and value > maxValue then value = maxValue end
  return value
end

local nextAutoOpenChatAt = 0

local function isGuildConfiguredChat(chatName)
  local key = normalizeName(chatName)
  if key == "" then return false end
  if key == "guild" or key == "guild chat" then return true end
  if key == normalizeName(settings.ownGuildName) then return true end
  return false
end

local function getChannelIdByName(channelName)
  if not getChannelId then return nil end
  channelName = trimText(channelName)
  if channelName == "" then return nil end
  local ok, channelId = pcall(function() return getChannelId(channelName) end)
  if ok then return channelId end
  return nil
end

local function getConfiguredChatId()
  local chatName = trimText(settings.chatName or "")
  local channelId = getChannelIdByName(chatName)
  if channelId then return channelId end

  if isGuildConfiguredChat(chatName) then
    channelId = getChannelIdByName(settings.ownGuildName)
    if channelId then return channelId end
    channelId = getChannelIdByName("Guild")
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
  if getConfiguredChatId() then return true end

  local chatName = trimText(settings.chatName or "")
  if chatName == "" or not isGuildConfiguredChat(chatName) then return false end

  local tm = timeMs()
  if not force and tm < nextAutoOpenChatAt then return false end
  nextAutoOpenChatAt = tm + settingNumber("autoOpenChatIntervalMs", 2500, 1000, 10000)

  -- Guild channel is 0 in OTC/TFS.
  tryGameCall("joinChannel", 0)

  return getConfiguredChatId() ~= nil
end

local function sendConfiguredChatText(text, retry)
  local chatId = getConfiguredChatId()
  if chatId and sayChannel then
    sayChannel(chatId, text)
    return true
  end

  ensureConfiguredChatOpen(true)

  if retry ~= false and schedule then
    schedule(300, function()
      sendConfiguredChatText(text, false)
    end)
    return false
  end

  warn("Combo Chat: chat da guild nao encontrado.")
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
  lastSpellCastAt = {}
}

local nextSmartRotationCheckAt = 0

local function setSmartRotationStatus(status)
  smartRotation.status = status or "PRESSAO"
end

local function getSmartRotationStatus()
  if settings.smartRotationEnabled ~= true then return "PRESSAO" end

  local tm = timeMs()
  if toNumber(smartRotation.comboExecutingUntil, 0) > tm then return "COMBO EXECUTANDO" end
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
  if spell == "" or cooldown <= 0 then return false end
  if isForbiddenAutoSpell(spell) then return false end
  if not hasAttackTargetSafe() then return false end

  local tm = timeMs()
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

local function castAutoSmartSpell(group, spell, cooldown)
  if not canAutoCastSmartSpell(group, spell, cooldown) then return false end

  local tm = timeMs()
  if castSingleComboSpell(spell) then
    smartRotation.lastAutoCastAt[group] = tm
    rememberSmartSpellCast(spell, tm)
    setSmartRotationStatus("PLANEJANDO")
    return true
  end

  return false
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

local function isTargetLockActive(tm)
  tm = tm or timeMs()
  return targetLock.name ~= "" and toNumber(targetLock.untilMs, 0) > tm
end

local function attackComboCreature(callerName, creature, fallbackName)
  callerName = trimText(callerName)
  local targetName = trimText(safeCreatureName(creature) or fallbackName or "")
  if targetName == "" then return false end
  if isLocalPlayerName(targetName) or isCallerName(targetName) then return false end

  local tm = timeMs()
  local rank = getCallerRank(callerName) or 999
  if isTargetLockActive(tm) and not sameName(targetLock.name, targetName) and rank > toNumber(targetLock.rank, 999) then
    return false
  end

  targetLock.name = targetName
  targetLock.caller = callerName
  targetLock.rank = rank
  targetLock.untilMs = tm + settingNumber("targetLockMs", 1600, 300, 5000)

  if creature and g_game and g_game.attack then
    pcall(function() g_game.attack(creature) end)
    return true
  end

  return false
end

local function attackComboTarget(callerName, targetName)
  targetName = trimText(targetName)
  if targetName == "" then return false end
  return attackComboCreature(callerName, getCreatureByNameSafe(targetName), targetName)
end

local function attackComboTargetId(callerName, targetId)
  local creature = getCreatureByIdSafe(targetId)
  if not creature then return false end
  return attackComboCreature(callerName, creature, tostring(targetId))
end

local function parseComboChat(payload)
  payload = trimText(payload)
  if payload == "" or settings.comboChatEnabled ~= true then return "none", "" end

  local lower = payload:lower()
  if lower == "combo" then return "combo", "" end
  if lower:sub(1, 6) == "combo " then return "none", "" end
  if lower:sub(1, 2) == "t " then
    local targetId = toNumber(trimText(payload:sub(3)))
    if targetId then return "targetId", targetId end
    return "none", ""
  end

  return "target", payload
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
    !text: tr('Combo Chat')

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
  size: 360 650
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
    height: 385

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

    Label
      id: chatLabel
      anchors.top: comboChat.bottom
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
      id: spellLabel
      anchors.top: chatLabel.bottom
      anchors.left: parent.left
      margin-top: 7
      width: 58
      height: 18
      text-offset: 0 3
      text: Magia:

    TextEdit
      id: comboSpell
      anchors.top: spellLabel.top
      anchors.left: spellLabel.right
      anchors.right: parent.right
      margin-left: 5
      height: 18
      text-align: center

    Label
      id: spellLabel2
      anchors.top: spellLabel.bottom
      anchors.left: parent.left
      margin-top: 7
      width: 58
      height: 18
      text-offset: 0 3
      text: Magia 2:

    TextEdit
      id: comboSpell2
      anchors.top: spellLabel2.top
      anchors.left: spellLabel2.right
      anchors.right: parent.right
      margin-left: 5
      height: 18
      text-align: center

    Label
      id: spellLabel3
      anchors.top: spellLabel2.bottom
      anchors.left: parent.left
      margin-top: 7
      width: 58
      height: 18
      text-offset: 0 3
      text: Magia 3:

    TextEdit
      id: comboSpell3
      anchors.top: spellLabel3.top
      anchors.left: spellLabel3.right
      anchors.right: parent.right
      margin-left: 5
      height: 18
      text-align: center

    Label
      id: spellLabel4
      anchors.top: spellLabel3.bottom
      anchors.left: parent.left
      margin-top: 7
      width: 58
      height: 18
      text-offset: 0 3
      text: Magia 4:

    TextEdit
      id: comboSpell4
      anchors.top: spellLabel4.top
      anchors.left: spellLabel4.right
      anchors.right: parent.right
      margin-left: 5
      height: 18
      text-align: center

    Label
      id: delayLabel
      anchors.top: spellLabel4.bottom
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

    Label
      id: autoALabel
      anchors.top: smartRotation.bottom
      anchors.left: parent.left
      margin-top: 7
      width: 58
      height: 18
      text-offset: 0 3
      text: Auto A:

    TextEdit
      id: autoSpellA
      anchors.top: autoALabel.top
      anchors.left: autoALabel.right
      anchors.right: parent.right
      margin-left: 5
      height: 18
      text-align: center

    Label
      id: autoBLabel
      anchors.top: autoALabel.bottom
      anchors.left: parent.left
      margin-top: 7
      width: 58
      height: 18
      text-offset: 0 3
      text: Auto B:

    TextEdit
      id: autoSpellB
      anchors.top: autoBLabel.top
      anchors.left: autoBLabel.right
      anchors.right: parent.right
      margin-left: 5
      height: 18
      text-align: center

    Label
      id: autoACdLabel
      anchors.top: autoBLabel.bottom
      anchors.left: parent.left
      margin-top: 7
      width: 42
      height: 18
      text-offset: 0 3
      text: CD A:

    TextEdit
      id: autoSpellACooldownMs
      anchors.top: autoACdLabel.top
      anchors.left: autoACdLabel.right
      margin-left: 5
      width: 78
      height: 18
      text-align: center

    Label
      id: autoBCdLabel
      anchors.top: autoACdLabel.top
      anchors.left: autoSpellACooldownMs.right
      margin-left: 8
      width: 42
      height: 18
      text-offset: 0 3
      text: CD B:

    TextEdit
      id: autoSpellBCooldownMs
      anchors.top: autoBCdLabel.top
      anchors.left: autoBCdLabel.right
      anchors.right: parent.right
      margin-left: 5
      height: 18
      text-align: center

    Label
      id: comboCCdLabel
      anchors.top: autoACdLabel.bottom
      anchors.left: parent.left
      margin-top: 7
      width: 42
      height: 18
      text-offset: 0 3
      text: CD C:

    TextEdit
      id: comboSpellCCooldownMs
      anchors.top: comboCCdLabel.top
      anchors.left: comboCCdLabel.right
      margin-left: 5
      width: 78
      height: 18
      text-align: center

    Label
      id: comboCSlotLabel
      anchors.top: comboCCdLabel.top
      anchors.left: comboSpellCCooldownMs.right
      margin-left: 8
      width: 42
      height: 18
      text-offset: 0 3
      text: Slot:

    TextEdit
      id: comboSpellCSlot
      anchors.top: comboCSlotLabel.top
      anchors.left: comboCSlotLabel.right
      anchors.right: parent.right
      margin-left: 5
      height: 18
      text-align: center

    Label
      id: smartMarginLabel
      anchors.top: comboCCdLabel.bottom
      anchors.left: parent.left
      margin-top: 7
      width: 58
      height: 18
      text-offset: 0 3
      text: Margem:

    TextEdit
      id: smartSafetyMarginMs
      anchors.top: smartMarginLabel.top
      anchors.left: smartMarginLabel.right
      margin-left: 5
      width: 62
      height: 18
      text-align: center

    Label
      id: autoIntervalLabel
      anchors.top: smartMarginLabel.top
      anchors.left: smartSafetyMarginMs.right
      margin-left: 8
      width: 48
      height: 18
      text-offset: 0 3
      text: Interv:

    TextEdit
      id: autoRotationIntervalMs
      anchors.top: autoIntervalLabel.top
      anchors.left: autoIntervalLabel.right
      anchors.right: parent.right
      margin-left: 5
      height: 18
      text-align: center

    Label
      id: smartStatus
      anchors.top: smartMarginLabel.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 7
      height: 18
      text-align: center
      color: #57c785
      text: PRESSAO

  HorizontalSeparator
    anchors.right: parent.right
    anchors.left: parent.left
    anchors.bottom: closeButton.top
    margin-bottom: 8

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
    local smartStatus = getSmartRotationStatus()
    local color = "#57c785"
    if smartStatus == "AGUARDANDO CALLER COMBO" then
      color = "#ffd36b"
    elseif smartStatus == "COMBO EXECUTANDO" then
      color = "#6bb7ff"
    elseif smartStatus == "PRESSAO" then
      color = "#c7c7c7"
    end
    setLabelText(comboWindow.chatPanel.smartStatus, smartStatus, color)
  end
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

local function syncComboWindow()
  refreshCallerList()
  comboWindow.chatPanel.comboChat:setOn(settings.comboChatEnabled == true)
  comboWindow.chatPanel.hierarchy:setOn(settings.hierarchyEnabled == true)
  comboWindow.chatPanel.autoOpenChat:setOn(settings.autoOpenChat == true)
  comboWindow.chatPanel.smartRotation:setOn(settings.smartRotationEnabled == true)
  comboWindow.chatPanel.chatName:setText(tostring(settings.chatName or "Guild"))
  comboWindow.chatPanel.comboSpell:setText(tostring(settings.comboSpell or ""))
  comboWindow.chatPanel.comboSpell2:setText(tostring(settings.comboSpell2 or ""))
  comboWindow.chatPanel.comboSpell3:setText(tostring(settings.comboSpell3 or ""))
  comboWindow.chatPanel.comboSpell4:setText(tostring(settings.comboSpell4 or ""))
  comboWindow.chatPanel.comboSpellStepMs:setText(tostring(settingNumber("comboSpellStepMs", 500, 300, 3000)))
  comboWindow.chatPanel.autoSpellA:setText(tostring(settings.autoSpellA or ""))
  comboWindow.chatPanel.autoSpellB:setText(tostring(settings.autoSpellB or ""))
  comboWindow.chatPanel.autoSpellACooldownMs:setText(tostring(settingNumber("autoSpellACooldownMs", 2000, 500, 60000)))
  comboWindow.chatPanel.autoSpellBCooldownMs:setText(tostring(settingNumber("autoSpellBCooldownMs", 5000, 500, 60000)))
  comboWindow.chatPanel.comboSpellCCooldownMs:setText(tostring(settingNumber("comboSpellCCooldownMs", 12000, 1000, 60000)))
  comboWindow.chatPanel.comboSpellCSlot:setText(tostring(settingNumber("comboSpellCSlot", 3, 1, 4)))
  comboWindow.chatPanel.smartSafetyMarginMs:setText(tostring(settingNumber("smartSafetyMarginMs", 1000, 0, 10000)))
  comboWindow.chatPanel.autoRotationIntervalMs:setText(tostring(settingNumber("autoRotationIntervalMs", 200, 50, 3000)))
  refreshStatus()
end

bindSwitch(ui.enabled, "enabled")
bindSwitch(comboWindow.chatPanel.comboChat, "comboChatEnabled")
bindSwitch(comboWindow.chatPanel.hierarchy, "hierarchyEnabled")
bindSwitch(comboWindow.chatPanel.autoOpenChat, "autoOpenChat")
bindSwitch(comboWindow.chatPanel.smartRotation, "smartRotationEnabled")

comboWindow.callersPanel.callersBlock.addBtn.onClick = addCallerFromInput
comboWindow.callersPanel.callersBlock.nameEdit.onKeyPress = function(_, keyCode)
  if keyCode == 5 then
    addCallerFromInput()
    return true
  end
  return false
end

comboWindow.chatPanel.chatName:setText(tostring(settings.chatName or "Guild"))
comboWindow.chatPanel.chatName.onTextChange = function(_, text)
  settings.chatName = text
  ensureConfiguredChatOpen(true)
  refreshStatus()
end

comboWindow.chatPanel.comboSpell:setText(tostring(settings.comboSpell or ""))
comboWindow.chatPanel.comboSpell.onTextChange = function(_, text)
  settings.comboSpell = trimText(text)
end

comboWindow.chatPanel.comboSpell2:setText(tostring(settings.comboSpell2 or ""))
comboWindow.chatPanel.comboSpell2.onTextChange = function(_, text)
  settings.comboSpell2 = trimText(text)
end

comboWindow.chatPanel.comboSpell3:setText(tostring(settings.comboSpell3 or ""))
comboWindow.chatPanel.comboSpell3.onTextChange = function(_, text)
  settings.comboSpell3 = trimText(text)
end

comboWindow.chatPanel.comboSpell4:setText(tostring(settings.comboSpell4 or ""))
comboWindow.chatPanel.comboSpell4.onTextChange = function(_, text)
  settings.comboSpell4 = trimText(text)
end

comboWindow.chatPanel.comboSpellStepMs:setText(tostring(settingNumber("comboSpellStepMs", 500, 300, 3000)))
comboWindow.chatPanel.comboSpellStepMs.onTextChange = function(_, text)
  local value = toNumber(trimText(text), 500)
  if value < 300 then value = 300 end
  if value > 3000 then value = 3000 end
  settings.comboSpellStepMs = value
end

comboWindow.chatPanel.autoSpellA:setText(tostring(settings.autoSpellA or ""))
comboWindow.chatPanel.autoSpellA.onTextChange = function(_, text)
  settings.autoSpellA = trimText(text)
end

comboWindow.chatPanel.autoSpellB:setText(tostring(settings.autoSpellB or ""))
comboWindow.chatPanel.autoSpellB.onTextChange = function(_, text)
  settings.autoSpellB = trimText(text)
end

bindNumberEdit(comboWindow.chatPanel.autoSpellACooldownMs, "autoSpellACooldownMs", 2000, 500, 60000)
bindNumberEdit(comboWindow.chatPanel.autoSpellBCooldownMs, "autoSpellBCooldownMs", 5000, 500, 60000)
bindNumberEdit(comboWindow.chatPanel.comboSpellCCooldownMs, "comboSpellCCooldownMs", 12000, 1000, 60000)
bindNumberEdit(comboWindow.chatPanel.comboSpellCSlot, "comboSpellCSlot", 3, 1, 4)
bindNumberEdit(comboWindow.chatPanel.smartSafetyMarginMs, "smartSafetyMarginMs", 1000, 0, 10000)
bindNumberEdit(comboWindow.chatPanel.autoRotationIntervalMs, "autoRotationIntervalMs", 200, 50, 3000)

ui.setup.onClick = function()
  syncComboWindow()
  comboWindow:show()
  comboWindow:raise()
  comboWindow:focus()
end

comboWindow.closeButton.onClick = function()
  comboWindow:hide()
end

refreshCallerList()
refreshStatus()

local comboIconLocked = false

local function callComboTargetIcon()
  local targetId = getCurrentTargetId()
  if not targetId then
    warn("Combo Chat: sem target para chamar.")
    return
  end

  sendConfiguredChatText(".t " .. tostring(targetId))
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

if type(addIcon) == "function" then
  local targetIcon = addIcon("EspartanosCallTarget", {
    item = MAGIC_LONGSWORD_ID,
    text = "CALL\nTARGET",
    switchable = false,
    moveable = true
  }, function()
    callComboTargetIcon()
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
end

macro(100, function()
  runSmartRotation()
end)

macro(1000, function()
  if settings.enabled == true and settings.comboChatEnabled == true then
    ensureConfiguredChatOpen(false)
  end

  if comboWindow and comboWindow.isVisible and comboWindow:isVisible() then
    refreshStatus()
  end
end)

if type(onTalk) == "function" then
  onTalk(function(name, level, mode, text, channelId, pos)
    if settings.enabled ~= true then return end
    if not name or not text or text == "" then return end
    if isLocalPlayerName(name) then return end
    if not callerCanCommand(name) then return end
    if not isConfiguredCommandChannel(channelId) then return end

    local prefix = tostring(settings.commandPrefix or ".")
    if text:sub(1, #prefix) ~= prefix then return end

    local payload = trimText(text:sub(#prefix + 1))
    local action, value = parseComboChat(payload)

    if action == "target" then
      attackComboTarget(name, value)
    elseif action == "targetId" then
      attackComboTargetId(name, value)
    elseif action == "combo" then
      castComboSpell()
    end
  end)
end
