-- BotServerNav.lua - safe farm navigation coordinator for BotServer.
-- It sends/receives navigation targets through BotServer topic "farm_nav"
-- Scouts publish Exalted Wolf positions; movement stays under the user's CaveBot.

BOTSERVER_NAV_TOPIC = "farm_nav"
BOTSERVER_EXALTED_WOLF_TOPIC = "exalted_wolf"
BOTSERVER_NAV_MW_TOPIC = "nav_mw_target"
BOTSERVER_NAV_STATUS_TOPIC = "wolf_status"
BOTSERVER_NAV_PANEL = "BOTserver"
NAV_REACTIVATE_DISTANCE = 10
NAV_WALK_TICK_MS = 350
NAV_COMBAT_WALK_TICK_MS = 300
NAV_PRESSURE_WALK_TICK_MS = 10
NAV_EXALTED_WALK_TICK_MS = 10
NAV_PATH_RECALC_MS = 650
NAV_EXALTED_PATH_RECALC_MS = 120
NAV_STAIR_RECALC_MS = 1200
NAV_AUTOWALK_REISSUE_MS = 600
NAV_COMBAT_AUTOWALK_REISSUE_MS = 400
NAV_PRESSURE_AUTOWALK_REISSUE_MS = 10
NAV_EXALTED_AUTOWALK_REISSUE_MS = 10
NAV_LURE_WITH_TARGETBOT_MS = 650
NAV_APPROACH_THRESHOLD = 8
NAV_FINE_SCAN_DISTANCE = 12
NAV_FINE_SCAN_MS = 250
NAV_NIGHTWOLF_LURE_MS = 10
NAV_FINE_UPDATE_MS = 600
NAV_DUPLICATE_TARGET_MS = 8000
NAV_NEAR_TARGET_MS = 3000
NAV_NEAR_TARGET_DISTANCE = 2
NAV_SCOUT_SCAN_MS = 1000
NAV_INPUT_DEDUPE_MS = 4000
NAV_INPUT_NEAR_DEDUPE_MS = 2500
NAV_INPUT_NEAR_DISTANCE = 3
NAV_LEGACY_TEXT_INPUT_ENABLED = false
NAV_START_LOCK_MS = 1800
NAV_START_LOCK_DISTANCE = 3
NAV_SCOUT_WAIT_EXALTED_MS = 60000
NAV_EXALTED_PROTECT_MS = 300
NAV_EXALTED_ARRIVAL_DISTANCE = 3
NAV_EXALTED_MISSING_RESTORE_MS = 4000
NAV_EXALTED_MISSING_DISTANCE = 5
NAV_EXALTED_STOP_ATTACK_HP = 50
NAV_EXALTED_SCOUT_CLAIM_MS = 45000
NAV_EXALTED_SCOUT_CLAIM_DISTANCE = 6
NAV_EXALTED_KILLER_RELEASE_DISTANCE = 8
NAV_AREA_WARN_MS = 5000
NAV_MW_RUNE_ID = 3180
NAV_MW_COOLDOWN_MS = 900
NAV_MW_TILE_RETRY_MS = 18000
NAV_MW_MAX_RANGE = 7
ExaltedLeaderWatchdog = ExaltedLeaderWatchdog or { missingAt = 0, lastSeenAt = 0 }
ExaltedLeaderWatchdog.missingAt = tonumber(ExaltedLeaderWatchdog.missingAt) or 0
ExaltedLeaderWatchdog.lastSeenAt = tonumber(ExaltedLeaderWatchdog.lastSeenAt) or 0
ScoutExaltedWatchdog = ScoutExaltedWatchdog or { missingAt = 0, lastSeenAt = 0 }
ScoutExaltedWatchdog.missingAt = tonumber(ScoutExaltedWatchdog.missingAt) or 0
ScoutExaltedWatchdog.lastSeenAt = tonumber(ScoutExaltedWatchdog.lastSeenAt) or 0
NavInputGuard = NavInputGuard or { signature = "", at = 0, source = "", target = nil }
NavStartGuard = NavStartGuard or { signature = "", at = 0, target = nil }
NavStartQueue = NavStartQueue or { event = nil, target = nil, sender = "", forceFine = false, at = 0 }

function navMillis()
  local n = tonumber(now)
  if n then return n end
  if os and type(os.time) == "function" then return os.time() * 1000 end
  return 0
end

function stopBotServerNavMacros()
  if type(BotServerNavMacros) ~= "table" then
    BotServerNavMacros = {}
    return
  end

  for _, botServerNavMacro in ipairs(BotServerNavMacros) do
    if botServerNavMacro then
      pcall(function()
        if type(botServerNavMacro.setOff) == "function" then
          botServerNavMacro:setOff()
        elseif type(botServerNavMacro.setOn) == "function" then
          botServerNavMacro:setOn(false)
        end
      end)
    end
  end

  BotServerNavMacros = {}
end

local function registerBotServerNavMacro(botServerNavMacro)
  BotServerNavMacros = BotServerNavMacros or {}
  if botServerNavMacro then
    table.insert(BotServerNavMacros, botServerNavMacro)
  end
  return botServerNavMacro
end

if BotServerNav and type(BotServerNav.stop) == "function" then
  pcall(function() BotServerNav.stop() end)
end

stopBotServerNavMacros()

BotServerNavInstanceId = (tonumber(BotServerNavInstanceId) or 0) + 1
local BOTSERVER_NAV_INSTANCE_ID = BotServerNavInstanceId

local NAV_IGNORE_AREAS = {
  { name = "DP", x1 = 54701, y1 = 54762, z1 = 7, x2 = 54713, y2 = 54772, z2 = 7 },
  { name = "DP 8", x1 = 54701, y1 = 54762, z1 = 8, x2 = 54713, y2 = 54772, z2 = 8 },
  {
    name = "Barco DP",
    z = 6,
    points = {
      { x = 54683, y = 54773 },
      { x = 54684, y = 54767 },
      { x = 54697, y = 54767 },
      { x = 54698, y = 54763 },
      { x = 54693, y = 54763 },
      { x = 54693, y = 54765 },
      { x = 54684, y = 54765 },
      { x = 54683, y = 54760 },
      { x = 54682, y = 54758 },
      { x = 54679, y = 54758 },
      { x = 54676, y = 54760 },
      { x = 54675, y = 54773 }
    }
  }
}

local NAV_ALLOWED_AREAS = {
  { name = "LIMITACAO MAPA", x1 = 54617, y1 = 54728, z1 = 0, x2 = 54847, y2 = 54940, z2 = 15, anyZ = true }
}

storage = storage or {}
storage[BOTSERVER_NAV_PANEL] = storage[BOTSERVER_NAV_PANEL] or {}
local navConfig = storage[BOTSERVER_NAV_PANEL]
local navRouteMode = "idle"

local function text(value)
  return tostring(value or "")
end

local function isCurrentInstance()
  return BotServerNavInstanceId == BOTSERVER_NAV_INSTANCE_ID
end

local function localPlayerName()
  if type(name) == "function" then
    local ok, value = pcall(name)
    if ok and value then return text(value) end
  end
  if player and player.getName then
    local ok, value = pcall(function() return player:getName() end)
    if ok and value then return text(value) end
  end
  return ""
end

local function isEnabled()
  if not isCurrentInstance() then return false end
  return navConfig.navScoutEnabled == true
    or navConfig.navLeaderEnabled == true
    or navConfig.navMwEnabled == true
end

local function isLocalScout()
  return navConfig.navScoutEnabled == true
end

local function isAllowed()
  return isLocalScout()
end

local function isLocalLeader()
  return navConfig.navLeaderEnabled == true
end

local function notify(message)
  message = "[BotServerNav] " .. text(message)
  if modules and modules.game_textmessage and modules.game_textmessage.displayStatusMessage then
    pcall(function() modules.game_textmessage.displayStatusMessage(message) end)
  elseif print then
    print(message)
  end
end

local function normalizePosition(value)
  if type(value) ~= "table" then return nil end
  local x = tonumber(value.x or value[1])
  local y = tonumber(value.y or value[2])
  local z = tonumber(value.z or value[3])
  if not x or not y or not z then return nil end
  return { x = math.floor(x), y = math.floor(y), z = math.floor(z) }
end

local function positionText(pos)
  pos = normalizePosition(pos)
  if not pos then return "" end
  return pos.x .. "," .. pos.y .. "," .. pos.z
end

local function numberList(raw)
  local values = {}
  for value in text(raw):gmatch("%-?%d+") do
    table.insert(values, tonumber(value))
  end
  return values
end

local function parseIgnoredArea(chunk)
  local values = numberList(chunk)
  if #values >= 6 then
    return {
      x1 = values[1],
      y1 = values[2],
      z1 = values[3],
      x2 = values[4],
      y2 = values[5],
      z2 = values[6]
    }
  end

  if #values == 5 then
    return {
      x1 = values[1],
      y1 = values[2],
      z1 = values[5],
      x2 = values[3],
      y2 = values[4],
      z2 = values[5]
    }
  end

  return nil
end

local function areaIgnoresFloor(area)
  if type(area) ~= "table" then return false end
  if area.anyZ == true then return true end
  local name = text(area.name):lower()
  return name:find("limitacao mapa", 1, true) ~= nil
end

local function positionInArea(pos, area)
  pos = normalizePosition(pos)
  if not pos or type(area) ~= "table" then return false end

  if type(area.points) == "table" then
    if not areaIgnoresFloor(area) and tonumber(area.z) and pos.z ~= tonumber(area.z) then return false end
    if #area.points < 3 then return false end

    local function pointOnSegment(px, py, ax, ay, bx, by)
      local cross = (py - ay) * (bx - ax) - (px - ax) * (by - ay)
      if cross ~= 0 then return false end
      return px >= math.min(ax, bx) and px <= math.max(ax, bx)
        and py >= math.min(ay, by) and py <= math.max(ay, by)
    end

    local inside = false
    local j = #area.points
    for i = 1, #area.points do
      local a = area.points[i]
      local b = area.points[j]
      local ax, ay = tonumber(a.x), tonumber(a.y)
      local bx, by = tonumber(b.x), tonumber(b.y)

      if ax and ay and bx and by then
        if pointOnSegment(pos.x, pos.y, ax, ay, bx, by) then return true end
        if (ay > pos.y) ~= (by > pos.y) then
          local intersectX = (bx - ax) * (pos.y - ay) / (by - ay) + ax
          if pos.x < intersectX then inside = not inside end
        end
      end

      j = i
    end

    return inside
  end

  local anyZ = areaIgnoresFloor(area)
  if not area.x1 or not area.x2 or not area.y1 or not area.y2 or (not anyZ and (not area.z1 or not area.z2)) then
    return false
  end

  local minX = math.min(area.x1, area.x2)
  local maxX = math.max(area.x1, area.x2)
  local minY = math.min(area.y1, area.y2)
  local maxY = math.max(area.y1, area.y2)
  local minZ = anyZ and pos.z or math.min(area.z1, area.z2)
  local maxZ = anyZ and pos.z or math.max(area.z1, area.z2)

  return pos.x >= minX and pos.x <= maxX
    and pos.y >= minY and pos.y <= maxY
    and pos.z >= minZ and pos.z <= maxZ
end

local function isAllowedNavPosition(pos)
  pos = normalizePosition(pos)
  if not pos then return false end
  if #NAV_ALLOWED_AREAS == 0 then return true end

  for _, area in ipairs(NAV_ALLOWED_AREAS) do
    if positionInArea(pos, area) then return true end
  end

  return false
end

local function isIgnoredTarget(pos)
  pos = normalizePosition(pos)
  if not pos then return true end

  for _, area in ipairs(NAV_IGNORE_AREAS) do
    if positionInArea(pos, area) then return true end
  end

  local raw = text(navConfig.navIgnoreArea or "")
  if raw == "" then return false end

  for chunk in raw:gmatch("[^;\n]+") do
    local area = parseIgnoredArea(chunk)
    if area and positionInArea(pos, area) then return true end
  end

  return false
end

local function parseText(rawText)
  local raw = text(rawText)
  local lower = raw:lower()
  local x, y, z

  if lower:find("boss|", 1, true) then
    x, y, z = lower:match("|%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*|")
  end

  if not x and lower:find("coordenada", 1, true) then
    x, y, z = lower:match("x%s*[:=]?%s*(%d+)%D+y%s*[:=]?%s*(%d+)%D+z%s*[:=]?%s*(%d+)")
  end

  if not x and (lower:find("exalted", 1, true) or lower:find("wolf", 1, true) or lower:find("boss", 1, true) or lower:find("exiva", 1, true)) then
    x, y, z = lower:match("(%d+)%s*,%s*(%d+)%s*,%s*(%d+)")
  end

  x, y, z = tonumber(x), tonumber(y), tonumber(z)
  if not x or not y or not z then return nil end

  local hp = tonumber(lower:match("hp%s*(%d+)%%")) or 0
  local scout = raw:match("[Ss][Cc][Oo][Uu][Tt]%s+([^|]+)")
  if scout then scout = scout:gsub("^%s+", ""):gsub("%s+$", "") end
  return {
    kind = "legacy_exiva",
    x = x,
    y = y,
    z = z,
    hp = hp,
    scout = scout,
    position = { x = x, y = y, z = z },
    location = x .. "," .. y .. "," .. z,
    sourceText = raw
  }
end

local function getPlayerPosition()
  if player and player.getPosition then
    local ok, value = pcall(function() return player:getPosition() end)
    if ok then return normalizePosition(value) end
  end
  if type(pos) == "function" then
    local ok, value = pcall(pos)
    if ok then return normalizePosition(value) end
  end
  return nil
end

local function isLocalInsideNavArea()
  return isAllowedNavPosition(getPlayerPosition())
end

local function distanceTo(targetPos)
  local currentPos = getPlayerPosition()
  targetPos = normalizePosition(targetPos)
  if not currentPos or not targetPos then return 999999 end

  if type(getDistanceBetween) == "function" then
    local ok, value = pcall(getDistanceBetween, currentPos, targetPos)
    if ok and tonumber(value) then return tonumber(value) end
  end

  if currentPos.z ~= targetPos.z then return 999999 end
  return math.max(math.abs(currentPos.x - targetPos.x), math.abs(currentPos.y - targetPos.y))
end

local function setDestination(targetPos)
  targetPos = normalizePosition(targetPos)
  if not targetPos then return false end

  storage.walkDestination = positionText(targetPos)

  if modules and modules.derpetsonWalkManager and type(modules.derpetsonWalkManager.setDestination) == "function" then
    pcall(function() modules.derpetsonWalkManager.setDestination(targetPos) end)
  end

  return true
end

local exaltedCavebotWasOn = nil
local exaltedCavebotPausedByNav = false
local lastExaltedCavebotPauseAt = 0
local exaltedTargetbotPausedByNav = false
local lastExaltedTargetbotPauseAt = 0
local cavebotRestoreUntil = 0

local function isCavebotOn()
  if CaveBot and type(CaveBot.isOn) == "function" then
    local ok, value = pcall(function() return CaveBot.isOn() end)
    if ok then return value == true end
  end
  return false
end

local function isTargetbotOn()
  if TargetBot and type(TargetBot.isOn) == "function" then
    local ok, value = pcall(function() return TargetBot.isOn() end)
    if ok then return value == true end
  end
  return false
end

local function setTargetbotOn()
  if not TargetBot or type(TargetBot.setOn) ~= "function" then return false end
  local ok = pcall(function() TargetBot.setOn() end)
  return ok == true
end

local function pauseTargetbotForExalted()
  if not TargetBot then return false end
  local currentTime = navMillis()
  if exaltedTargetbotPausedByNav and currentTime - lastExaltedTargetbotPauseAt < 500 then
    return true
  end
  if exaltedTargetbotPausedByNav and isTargetbotOn() ~= true then
    lastExaltedTargetbotPauseAt = currentTime
    return true
  end
  if TargetBot.setOff then
    pcall(function() TargetBot.setOff() end)
    exaltedTargetbotPausedByNav = true
    lastExaltedTargetbotPauseAt = currentTime
    return true
  end
  return false
end

local function setCavebotOn()
  if not CaveBot or type(CaveBot.setOn) ~= "function" then return false end
  local ok = pcall(function() CaveBot.setOn() end)
  return ok == true
end

local function forceCavebotOnForNav(duration)
  cavebotRestoreUntil = math.max(cavebotRestoreUntil or 0, navMillis() + (tonumber(duration) or 2500))
  setCavebotOn()

  if type(schedule) == "function" then
    schedule(250, function()
      if navMillis() <= (cavebotRestoreUntil or 0) then setCavebotOn() end
    end)
    schedule(750, function()
      if navMillis() <= (cavebotRestoreUntil or 0) then setCavebotOn() end
    end)
    schedule(1500, function()
      if navMillis() <= (cavebotRestoreUntil or 0) then setCavebotOn() end
    end)
  end
end

local function pauseCavebotForExalted()
  if not CaveBot then return false end
  local currentTime = navMillis()
  if exaltedCavebotPausedByNav and currentTime - lastExaltedCavebotPauseAt < 500 then
    return true
  end
  if exaltedCavebotWasOn == nil then
    exaltedCavebotWasOn = isCavebotOn()
  end
  if exaltedCavebotPausedByNav and isCavebotOn() ~= true then
    lastExaltedCavebotPauseAt = currentTime
    return true
  end
  if CaveBot.setOff then
    pcall(function() CaveBot.setOff() end)
    exaltedCavebotPausedByNav = true
    lastExaltedCavebotPauseAt = currentTime
    return true
  end
  return false
end

local function keepCavebotPausedForExalted()
  if not isCurrentInstance() or navRouteMode ~= "exalted" then return false end
  if not isLocalLeader() and not isLocalScout() then return false end
  local paused = pauseCavebotForExalted()
  if isLocalLeader() then
    paused = pauseTargetbotForExalted() or paused
  end
  return paused
end

local function restoreCavebotAfterExalted()
  local restored = false
  if exaltedCavebotPausedByNav then
    forceCavebotOnForNav(2500)
    restored = true
  end
  exaltedCavebotWasOn = nil
  exaltedCavebotPausedByNav = false
  lastExaltedCavebotPauseAt = 0
  if exaltedTargetbotPausedByNav then
    setTargetbotOn()
    restored = true
  end
  exaltedTargetbotPausedByNav = false
  lastExaltedTargetbotPauseAt = 0
  return restored
end

local function setCavebotByDistance(targetPos)
  local paused = pauseCavebotForExalted()
  if isLocalLeader() then
    paused = pauseTargetbotForExalted() or paused
  end
  return paused
end

local WALK_STEP_DISTANCE = 10
local STAIR_PATH_CACHE = STAIR_PATH_CACHE or {}

local function botServerDistance(pos1, pos2)
  if not pos1 or not pos2 then return 999999 end
  return math.max(math.abs(pos1.x - pos2.x), math.abs(pos1.y - pos2.y))
end

local function scheduleEvent(delay, callback)
  if type(schedule) ~= "function" then return nil end
  return schedule(delay, callback)
end

local lastNavAreaWarnAt = 0

local function notifyNavAreaBlocked(action)
  local currentTime = navMillis()
  if currentTime - lastNavAreaWarnAt < NAV_AREA_WARN_MS then return end
  lastNavAreaWarnAt = currentTime
  notify(text(action) .. " bloqueado fora da LIMITACAO MAPA")
end

local function removeScheduledEvent(event)
  if event and type(removeEvent) == "function" then
    pcall(function() removeEvent(event) end)
  end
end

local function safeStopGame()
  if g_game and type(g_game.stop) == "function" then
    pcall(function() g_game.stop() end)
  end
end

local function setChaseOff()
  if g_game and type(g_game.setChaseMode) == "function" then
    pcall(function() g_game.setChaseMode(0) end)
  end
end

local function getLocalPlayerObject()
  if g_game and type(g_game.getLocalPlayer) == "function" then
    local ok, value = pcall(function() return g_game.getLocalPlayer() end)
    if ok and value then return value end
  end
  return player
end

local function getCreatureName(creature)
  if creature and creature.getName then
    local ok, value = pcall(function() return creature:getName() end)
    if ok and value then return text(value) end
  end

  return ""
end

local function getAttackingCreature()
  if g_game then
    if type(g_game.isAttacking) == "function" then
      local ok, attacking = pcall(function() return g_game.isAttacking() end)
      if ok and attacking ~= true then return nil end
    end

    if type(g_game.getAttackingCreature) == "function" then
      local ok, creature = pcall(function() return g_game.getAttackingCreature() end)
      if ok and creature then return creature end
    end
  end

  if type(getTarget) == "function" then
    local ok, creature = pcall(getTarget)
    if ok and creature then return creature end
  end

  return nil
end

local lastExaltedChaseAt = 0
local exaltedHpHoldActive = false
local lastExaltedHpHoldNoticeAt = 0

local function normalizedCreatureName(creature)
  return getCreatureName(creature):lower():gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function compactCreatureName(creature)
  return normalizedCreatureName(creature):gsub("%s+", "")
end

local function isExaltedWolfCreature(creature)
  return compactCreatureName(creature) == "exaltedwolf"
end

local function isNightWolfCreature(creature)
  local name = normalizedCreatureName(creature)
  return name == "night wolf" or name == "nightwolf" or compactCreatureName(creature) == "nightwolf"
end

local shouldStopExaltedAttackByHp = nil

BotServerNavLureState = BotServerNavLureState or { untilAt = 0 }
BotServerNavTargetBotLurePatchInstalled = BotServerNavTargetBotLurePatchInstalled or false
BotServerNavTargetBotBlockPatchInstalled = BotServerNavTargetBotBlockPatchInstalled or false
if TargetBot
  and TargetBot.Creature
  and BotServerNavTargetBotOriginalBlockedCreature
  and TargetBot.Creature.isBlockedCreature ~= BotServerNavTargetBotOriginalBlockedCreature then
  TargetBot.Creature.isBlockedCreature = BotServerNavTargetBotOriginalBlockedCreature
  BotServerNavTargetBotBlockPatchInstalled = false
end
if BotServerNavTargetBotLurePatchInstalled
  and TargetBot
  and TargetBot.Creature
  and BotServerNavTargetBotOriginalWalk
  and TargetBot.Creature.walk ~= BotServerNavTargetBotOriginalWalk then
  TargetBot.Creature.walk = BotServerNavTargetBotOriginalWalk
  if BotServerNavTargetBotOriginalBlockedCreature then
    TargetBot.Creature.isBlockedCreature = BotServerNavTargetBotOriginalBlockedCreature
  end
  BotServerNavTargetBotLurePatchInstalled = false
end

local function isNavLureActive()
  return isCurrentInstance() and tonumber(BotServerNavLureState.untilAt or 0) > navMillis()
end

local function markNavLureMovement(duration)
  local untilAt = navMillis() + (tonumber(duration) or NAV_LURE_WITH_TARGETBOT_MS)
  BotServerNavLureState.untilAt = math.max(tonumber(BotServerNavLureState.untilAt) or 0, untilAt)

  if TargetBot and type(TargetBot.allowCaveBot) == "function" then
    pcall(function() TargetBot.allowCaveBot(NAV_LURE_WITH_TARGETBOT_MS) end)
  end
  if TargetBot and type(TargetBot.setLureSafety) == "function" then
    pcall(function() TargetBot.setLureSafety(NAV_LURE_WITH_TARGETBOT_MS) end)
  end
end

local function installNavTargetBotLurePatch()
  if not TargetBot or not TargetBot.Creature then return false end

  if not BotServerNavTargetBotLurePatchInstalled and type(TargetBot.Creature.walk) == "function" then
    BotServerNavTargetBotOriginalWalk = TargetBot.Creature.walk
    TargetBot.Creature.walk = function(creature, config, targets, dangerLevel)
      return BotServerNavTargetBotOriginalWalk(creature, config, targets, dangerLevel)
    end
    BotServerNavTargetBotLurePatchInstalled = true
  end

  if not BotServerNavTargetBotBlockPatchInstalled then
    BotServerNavTargetBotOriginalBlockedCreature = TargetBot.Creature.isBlockedCreature
    TargetBot.Creature.isBlockedCreature = function(creature)
      if isExaltedWolfCreature(creature)
        and isCurrentInstance()
        and isLocalInsideNavArea()
        and isLocalScout() then
        return true
      end

      if isNightWolfCreature(creature)
        and isCurrentInstance()
        and isLocalInsideNavArea()
        and isLocalLeader()
        and navRouteMode == "exalted" then
        return true
      end

      if BotServerNavTargetBotOriginalBlockedCreature then
        return BotServerNavTargetBotOriginalBlockedCreature(creature)
      end
      return false
    end
    BotServerNavTargetBotBlockPatchInstalled = true
  end

  return BotServerNavTargetBotLurePatchInstalled or BotServerNavTargetBotBlockPatchInstalled
end

local function creaturePositionForProtection(creature)
  if creature and type(creature.getPosition) == "function" then
    local ok, value = pcall(function() return creature:getPosition() end)
    if ok then return normalizePosition(value) end
  end
  return nil
end

local function creatureHpForProtection(creature)
  if creature and type(creature.getHealthPercent) == "function" then
    local ok, value = pcall(function() return creature:getHealthPercent() end)
    if ok then return tonumber(value) or 0 end
  end
  return 100
end

local function protectionSpectators()
  local fallback = {}

  if type(getSpectators) == "function" then
    local attempts = {
      function() return getSpectators(false) end,
      function() return getSpectators() end
    }
    for _, attempt in ipairs(attempts) do
      local ok, spectators = pcall(attempt)
      if ok and type(spectators) == "table" then
        fallback = spectators
        if #spectators > 0 then return spectators end
      end
    end
  end

  local playerPos = getPlayerPosition()
  if playerPos and g_map and type(g_map.getSpectators) == "function" then
    local ok, spectators = pcall(function() return g_map.getSpectators(playerPos) end)
    if ok and type(spectators) == "table" then
      return spectators
    end
  end

  return fallback
end

local function findVisibleExaltedWolfForProtection()
  for _, creature in ipairs(protectionSpectators()) do
    if isExaltedWolfCreature(creature) and creatureHpForProtection(creature) > 0 then
      return creature
    end
  end
  return nil
end

local function cancelProtectedAttack()
  local stopped = false
  if g_game and type(g_game.cancelAttackAndFollow) == "function" then
    local ok = pcall(function() g_game.cancelAttackAndFollow() end)
    stopped = stopped or ok
  end
  if g_game and type(g_game.cancelAttack) == "function" then
    local ok = pcall(function() g_game.cancelAttack() end)
    stopped = stopped or ok
  end
  if not stopped and g_game and type(g_game.stop) == "function" then
    pcall(function() g_game.stop() end)
  end
end

shouldStopExaltedAttackByHp = function(creature)
  if not isExaltedWolfCreature(creature) then return false end
  local hp = creatureHpForProtection(creature)
  return hp > 0 and hp <= NAV_EXALTED_STOP_ATTACK_HP
end

local function stopExaltedAttackOnLowHp(creature)
  if not isCurrentInstance() or not isLocalInsideNavArea() then return false end
  if not isLocalScout() then return false end
  if not shouldStopExaltedAttackByHp(creature) then
    if exaltedHpHoldActive then exaltedHpHoldActive = false end
    return false
  end

  local target = getAttackingCreature()
  if isExaltedWolfCreature(target) then
    cancelProtectedAttack()
  end
  setChaseOff()
  exaltedHpHoldActive = true

  local currentTime = navMillis()
  if currentTime - lastExaltedHpHoldNoticeAt > 3000 then
    lastExaltedHpHoldNoticeAt = currentTime
    notify("Exalted com HP baixo; ataque pausado")
  end
  return true
end

local function cancelNightWolfAttack()
  if not isLocalLeader() then return false end
  local target = getAttackingCreature()
  if not isNightWolfCreature(target) then return false end
  if navRouteMode == "exalted" then
    cancelProtectedAttack()
  end
  setChaseOff()
  markNavLureMovement(NAV_LURE_WITH_TARGETBOT_MS)
  return true
end

local function setChaseOn()
  if g_game and type(g_game.setChaseMode) == "function" then
    pcall(function() g_game.setChaseMode(1) end)
  end
end

local function chaseExaltedWolfForLeader()
  if not isLocalLeader() or not isLocalInsideNavArea() then return false end

  local wolf = findVisibleExaltedWolfForProtection()
  if not wolf then return false end
  local currentTime = navMillis()
  if navRouteMode ~= "exalted" then
    navRouteMode = "exalted"
  end
  ExaltedLeaderWatchdog.lastSeenAt = currentTime
  ExaltedLeaderWatchdog.missingAt = 0
  pauseCavebotForExalted()
  pauseTargetbotForExalted()
  local currentTarget = getAttackingCreature()
  if isNightWolfCreature(currentTarget) then
    cancelNightWolfAttack()
    currentTarget = nil
  end

  if g_game and type(g_game.attack) == "function"
    and (currentTarget ~= wolf or currentTime - lastExaltedChaseAt >= 100) then
    lastExaltedChaseAt = currentTime
    pcall(function() g_game.attack(wolf) end)
  end
  setChaseOn()
  return true
end

local isGameOnline

local function shouldYieldToCombat()
  if isLocalLeader() and navRouteMode == "exalted" then
    chaseExaltedWolfForLeader()
    cancelNightWolfAttack()
    return false
  end
  cancelNightWolfAttack()
  local target = getAttackingCreature()
  if stopExaltedAttackOnLowHp(target) then return false end
  if isNightWolfCreature(target) then return false end
  if target then return true end
  chaseExaltedWolfForLeader()
  cancelNightWolfAttack()
  return getAttackingCreature() ~= nil
end

local function keepWalkingOverNightWolf()
  if not isCurrentInstance() or not isGameOnline() then return false end
  if not (isLocalScout() or isLocalLeader()) then return false end

  local target = getAttackingCreature()
  if not isNightWolfCreature(target) then return false end

  setChaseOff()
  markNavLureMovement(NAV_LURE_WITH_TARGETBOT_MS)
  if navRouteMode ~= "exalted" then
    setCavebotOn()
  end
  return true
end

local function keepScoutOffExalted()
  if not isCurrentInstance() or not isGameOnline() then return false end
  if not isLocalScout() then return false end

  local target = getAttackingCreature()
  if not isExaltedWolfCreature(target) then return false end

  cancelProtectedAttack()
  setChaseOff()
  if navRouteMode ~= "exalted" then
    setCavebotOn()
  end
  return true
end

function isGameOnline()
  if g_game and type(g_game.isOnline) == "function" then
    local ok, value = pcall(function() return g_game.isOnline() end)
    if ok then return value == true end
  end
  return true
end

local function getStorageDestination()
  if storage.tempStairDestination then
    local temp = normalizePosition(storage.tempStairDestination)
    if temp then return temp end
  end

  local coords = {}
  for coord in text(storage.walkDestination):gmatch("[^,]+") do
    table.insert(coords, tonumber(coord))
  end

  if #coords == 3 and coords[1] and coords[2] and coords[3] then
    return { x = math.floor(coords[1]), y = math.floor(coords[2]), z = math.floor(coords[3]) }
  end

  return nil
end

local function samePosition(pos1, pos2)
  pos1 = normalizePosition(pos1)
  pos2 = normalizePosition(pos2)
  return pos1 and pos2 and pos1.x == pos2.x and pos1.y == pos2.y and pos1.z == pos2.z
end

local function posKey(pos)
  pos = normalizePosition(pos)
  if not pos then return "" end
  return pos.x .. "," .. pos.y .. "," .. pos.z
end

local function safeThingId(thing)
  if not thing or type(thing.getId) ~= "function" then return nil end
  local ok, id = pcall(function() return thing:getId() end)
  if ok then return tonumber(id) end
  return nil
end

local function getTileSafe(tilePos)
  tilePos = normalizePosition(tilePos)
  if not tilePos or not g_map or type(g_map.getTile) ~= "function" then return nil end
  local ok, tile = pcall(function() return g_map.getTile(tilePos) end)
  if ok then return tile end
  return nil
end

local function tileCanShootSafe(tile)
  if not tile then return false end
  if type(tile.canShoot) == "function" then
    local ok, canShoot = pcall(function() return tile:canShoot() end)
    if ok then return canShoot ~= false end
  end
  return true
end

local function tileHasCreatureSafe(tile)
  if not tile then return false end
  if type(tile.getCreatures) == "function" then
    local ok, creatures = pcall(function() return tile:getCreatures() end)
    if ok and creatures and #creatures > 0 then return true end
  end
  if type(tile.getTopCreature) == "function" then
    local ok, creature = pcall(function() return tile:getTopCreature() end)
    if ok and creature then return true end
  end
  return false
end

local NAV_MW_WALL_IDS = {
  [2128] = true,
  [2129] = true,
  [2130] = true
}

local function tileHasMwallSafe(tile)
  if not tile then return false end

  local function isWall(thing)
    local id = safeThingId(thing)
    return id and NAV_MW_WALL_IDS[id] == true
  end

  if type(tile.getItems) == "function" then
    local ok, items = pcall(function() return tile:getItems() end)
    if ok and items then
      for _, item in ipairs(items) do
        if isWall(item) then return true end
      end
    end
  end

  if type(tile.getThings) == "function" then
    local ok, things = pcall(function() return tile:getThings() end)
    if ok and things then
      for _, thing in ipairs(things) do
        if isWall(thing) then return true end
      end
    end
  end

  if type(tile.getTopUseThing) == "function" then
    local ok, thing = pcall(function() return tile:getTopUseThing() end)
    if ok and isWall(thing) then return true end
  end

  return false
end

local function mapSightClearSafe(fromPos, toPos)
  if not fromPos or not toPos or fromPos.z ~= toPos.z then return false end
  if not g_map or type(g_map.isSightClear) ~= "function" then return true end

  local ok, clear = pcall(function() return g_map.isSightClear(fromPos, toPos, true) end)
  if ok then return clear ~= false end

  ok, clear = pcall(function() return g_map.isSightClear(fromPos, toPos) end)
  if ok then return clear ~= false end

  return true
end

local function getTopUseThingSafe(tile)
  if not tile then return nil end
  if type(tile.getTopUseThing) == "function" then
    local ok, thing = pcall(function() return tile:getTopUseThing() end)
    if ok and thing then return thing end
  end
  if type(tile.getTopThing) == "function" then
    local ok, thing = pcall(function() return tile:getTopThing() end)
    if ok and thing then return thing end
  end
  return nil
end

local function useMwallOnTile(tile)
  local thing = getTopUseThingSafe(tile)
  if not thing then return false end

  if type(useWith) == "function" then
    local ok = pcall(function() useWith(NAV_MW_RUNE_ID, thing) end)
    if ok then return true end
  end

  if g_game and type(g_game.useInventoryItemWith) == "function" then
    local ok = pcall(function() g_game.useInventoryItemWith(NAV_MW_RUNE_ID, thing) end)
    if ok then return true end
  end

  return false
end

local function hashText(value)
  value = text(value)
  local hash = 0
  for index = 1, #value do
    hash = (hash + (value:byte(index) or 0) * index) % 9973
  end
  return hash
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

  local stepX = signNumber(dx)
  local stepY = signNumber(dy)
  return stepX, stepY, math.max(math.abs(dx), math.abs(dy))
end

local function markProtectedMwPosition(open, targetPos, offsetX, offsetY, maxRadius)
  if type(open) ~= "table" or not targetPos then return end
  offsetX = tonumber(offsetX) or 0
  offsetY = tonumber(offsetY) or 0
  if offsetX == 0 and offsetY == 0 then return end
  if math.max(math.abs(offsetX), math.abs(offsetY)) > (maxRadius or 2) then return end

  open[posKey({ x = targetPos.x + offsetX, y = targetPos.y + offsetY, z = targetPos.z })] = true
end

local function markMwAttackGate(open, targetPos, sourcePos, maxRadius)
  local stepX, stepY = getDirectionStepFromSource(targetPos, sourcePos)
  if stepX == 0 and stepY == 0 then return end

  if stepX ~= 0 and stepY ~= 0 then
    markProtectedMwPosition(open, targetPos, stepX, stepY, maxRadius)
    markProtectedMwPosition(open, targetPos, stepX, 0, maxRadius)
    markProtectedMwPosition(open, targetPos, 0, stepY, maxRadius)
    return
  end

  if stepX ~= 0 then
    for side = -1, 1 do
      markProtectedMwPosition(open, targetPos, stepX, side, maxRadius)
    end
    return
  end

  for side = -1, 1 do
    markProtectedMwPosition(open, targetPos, side, stepY, maxRadius)
  end
end

local function markMwLineCorridor(open, targetPos, sourcePos, maxRadius)
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
              markProtectedMwPosition(open, targetPos, offsetX, offsetY, radius)
            end
          end
        end
      end
    end
  end
end

local function markOpenMwLine(open, targetPos, sourcePos, maxRadius)
  if not targetPos or not sourcePos or targetPos.z ~= sourcePos.z then return end
  markMwAttackGate(open, targetPos, sourcePos, maxRadius)
  markMwLineCorridor(open, targetPos, sourcePos, maxRadius)
end

local function payloadAttackerPosition(message)
  if type(message) ~= "table" then return nil end
  return normalizePosition(message.attackerPosition)
    or normalizePosition(message.callerPosition)
    or normalizePosition({ x = message.attackerX, y = message.attackerY, z = message.attackerZ })
    or normalizePosition({ x = message.callerX, y = message.callerY, z = message.callerZ })
end

local navMwState = {
  lastCastAt = 0,
  tiles = {}
}

local function cleanupNavMwTiles(tm)
  tm = tm or navMillis()
  for key, expiresAt in pairs(navMwState.tiles) do
    if tonumber(expiresAt) and tonumber(expiresAt) <= tm then
      navMwState.tiles[key] = nil
    end
  end
end

local function buildNavMwallCandidates(targetPos, playerPos, attackerPos)
  local candidates = {}
  if not targetPos or not playerPos or targetPos.z ~= playerPos.z then return candidates end
  attackerPos = normalizePosition(attackerPos)

  local open = {}
  markOpenMwLine(open, targetPos, attackerPos, 2)
  markOpenMwLine(open, targetPos, playerPos, 2)

  for radius = 1, 2 do
    for dx = -radius, radius do
      for dy = -radius, radius do
        if math.max(math.abs(dx), math.abs(dy)) == radius then
          local tilePos = { x = targetPos.x + dx, y = targetPos.y + dy, z = targetPos.z }
          if not open[posKey(tilePos)]
            and not samePosition(tilePos, playerPos)
            and isAllowedNavPosition(tilePos)
            and not isIgnoredTarget(tilePos)
          then
            table.insert(candidates, {
              pos = tilePos,
              distance = botServerDistance(playerPos, tilePos),
              radius = radius,
              tie = hashText(localPlayerName() .. "|" .. positionText(tilePos))
            })
          end
        end
      end
    end
  end

  table.sort(candidates, function(a, b)
    if a.radius ~= b.radius then return a.radius < b.radius end
    if a.distance ~= b.distance then return a.distance < b.distance end
    if a.tie ~= b.tie then return a.tie < b.tie end
    return positionText(a.pos) < positionText(b.pos)
  end)

  return candidates
end

local function tryNavMwallAroundTarget(targetPos, sourceName, attackerPos)
  if navConfig.navMwEnabled ~= true then return false end
  targetPos = normalizePosition(targetPos)
  local playerPos = getPlayerPosition()
  if not targetPos or not playerPos or targetPos.z ~= playerPos.z then return false end
  if not isAllowedNavPosition(targetPos) or isIgnoredTarget(targetPos) then return false end
  if not isLocalInsideNavArea() then return false end
  if botServerDistance(playerPos, targetPos) > NAV_MW_MAX_RANGE then return false end

  local tm = navMillis()
  if tm - (tonumber(navMwState.lastCastAt) or 0) < NAV_MW_COOLDOWN_MS then return false end
  cleanupNavMwTiles(tm)

  for _, candidate in ipairs(buildNavMwallCandidates(targetPos, playerPos, attackerPos)) do
    local key = posKey(candidate.pos)
    if not navMwState.tiles[key] then
      local tile = getTileSafe(candidate.pos)
      if tile
        and tileCanShootSafe(tile)
        and not tileHasCreatureSafe(tile)
        and not tileHasMwallSafe(tile)
        and mapSightClearSafe(playerPos, candidate.pos)
      then
        if useMwallOnTile(tile) then
          navMwState.lastCastAt = tm
          navMwState.tiles[key] = tm + NAV_MW_TILE_RETRY_MS
          notify("MW nav " .. positionText(candidate.pos) .. " alvo " .. positionText(targetPos) .. " por " .. text(sourceName))
          return true
        end
      end
    end
  end

  return false
end

local function getPositionAfterSteps(startPos, directions, numSteps)
  local result = { x = startPos.x, y = startPos.y, z = startPos.z }
  local steps = math.min(numSteps, #directions)

  for i = 1, steps do
    local dir = directions[i]
    if dir == 0 then
      result.y = result.y - 1
    elseif dir == 1 then
      result.x = result.x + 1
    elseif dir == 2 then
      result.y = result.y + 1
    elseif dir == 3 then
      result.x = result.x - 1
    elseif dir == 4 then
      result.x = result.x + 1
      result.y = result.y - 1
    elseif dir == 5 then
      result.x = result.x + 1
      result.y = result.y + 1
    elseif dir == 6 then
      result.x = result.x - 1
      result.y = result.y + 1
    elseif dir == 7 then
      result.x = result.x - 1
      result.y = result.y - 1
    end
  end

  return result
end

local function canAutoWalk()
  return type(autoWalk) == "function"
end

local function canFindPath()
  return type(findPath) == "function"
end

local navAutoWalkState = {
  signature = "",
  at = 0
}

local function isLocalAutoWalking()
  local localPlayer = getLocalPlayerObject()
  if localPlayer and type(localPlayer.isAutoWalking) == "function" then
    local ok, value = pcall(function() return localPlayer:isAutoWalking() end)
    return ok and value == true
  end
  return false
end

local function runTargetBotWalkTo(targetPos, precision)
  targetPos = normalizePosition(targetPos)
  if not targetPos or not TargetBot or type(TargetBot.walkTo) ~= "function" then return false end

  markNavLureMovement(NAV_LURE_WITH_TARGETBOT_MS)

  local target = getAttackingCreature()
  if target and not isExaltedWolfCreature(target) then
    setChaseOff()
  end

  local playerPos = getPlayerPosition()
  local maxDist = 30
  if playerPos and playerPos.z == targetPos.z then
    maxDist = math.max(12, math.min(80, botServerDistance(playerPos, targetPos) + 10))
  end

  local params = {
    ignoreNonPathable = true,
    ignoreCreatures = true,
    precision = precision or 1
  }

  local ok, result = pcall(function() return TargetBot.walkTo(targetPos, maxDist, params) end)
  if not ok or result == false then return false end

  if TargetBot.setLureSafety then
    pcall(function() TargetBot.setLureSafety(600) end)
  end

  return true
end

local function navigationPrecision(targetPos)
  local dist = distanceTo(targetPos)
  if dist > NAV_APPROACH_THRESHOLD then return NAV_APPROACH_THRESHOLD end
  return 1
end

local function runAutoWalk(targetPos, precision)
  targetPos = normalizePosition(targetPos)
  if not targetPos then return false end

  local currentTime = navMillis()
  precision = precision or 1
  local inCombat = shouldYieldToCombat()
  local signature = positionText(targetPos) .. ":" .. text(precision)

  if inCombat then
    installNavTargetBotLurePatch()
    local combatTarget = getAttackingCreature()
    if combatTarget and not isExaltedWolfCreature(combatTarget) and navRouteMode ~= "exalted" then
      BotServerNavLureState.untilAt = 0
      setChaseOff()
      navAutoWalkState.signature = signature
      navAutoWalkState.at = currentTime
      return true
    end

    markNavLureMovement(NAV_LURE_WITH_TARGETBOT_MS)

    local elapsed = currentTime - navAutoWalkState.at
    local combatReissueMs = navRouteMode == "exalted" and NAV_EXALTED_AUTOWALK_REISSUE_MS or NAV_COMBAT_AUTOWALK_REISSUE_MS
    if navAutoWalkState.signature == signature and elapsed < combatReissueMs and isLocalAutoWalking() then
      return true
    end

  else
    local elapsed = currentTime - navAutoWalkState.at
    local reissueMs = NAV_AUTOWALK_REISSUE_MS
    if navRouteMode == "exalted" then
      reissueMs = NAV_EXALTED_AUTOWALK_REISSUE_MS
    end
    local movingNightWolf = isNightWolfCreature(getAttackingCreature())
    if movingNightWolf then
      reissueMs = NAV_PRESSURE_AUTOWALK_REISSUE_MS
    end
    if navAutoWalkState.signature == signature and elapsed < reissueMs and isLocalAutoWalking() then
      return true
    end
  end

  if not canAutoWalk() then
    if inCombat then return runTargetBotWalkTo(targetPos, precision) end
    return false
  end

  local currentTarget = getAttackingCreature()
  if stopExaltedAttackOnLowHp(currentTarget) then
    setChaseOff()
  elseif isLocalLeader() and isExaltedWolfCreature(currentTarget) then
    setChaseOn()
  else
    setChaseOff()
  end
  local params = { ignoreNonPathable = true, ignoreCreatures = true, precision = precision }
  local ok, result = pcall(autoWalk, targetPos, 1000, params)
  if ok and result ~= false then
    navAutoWalkState.signature = signature
    navAutoWalkState.at = currentTime
    return true
  end

  ok, result = pcall(autoWalk, targetPos, params)
  if ok and result ~= false then
    navAutoWalkState.signature = signature
    navAutoWalkState.at = currentTime
    return true
  end

  return false
end

local navLadders = {
  { pos = { x = 54724, y = 54796, z = 7 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54725, y = 54796, z = 7 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54726, y = 54796, z = 7 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54724, y = 54796, z = 6 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54725, y = 54796, z = 6 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54726, y = 54796, z = 6 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54724, y = 54799, z = 6 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54725, y = 54799, z = 6 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54726, y = 54799, z = 6 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54724, y = 54799, z = 7 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54725, y = 54799, z = 7 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54726, y = 54799, z = 7 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54720, y = 54805, z = 7 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54720, y = 54806, z = 7 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54720, y = 54805, z = 6 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54720, y = 54806, z = 6 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54693, y = 54813, z = 6 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54690, y = 54812, z = 5 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54690, y = 54813, z = 5 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54686, y = 54812, z = 4 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54684, y = 54812, z = 3 }, type = "ladder_up", dir = "up" },
  { pos = { x = 54700, y = 54803, z = 7 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54699, y = 54803, z = 7 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54692, y = 54802, z = 6 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54684, y = 54812, z = 2 }, type = "ladder_down", dir = "down" },
  { pos = { x = 54686, y = 54812, z = 3 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54689, y = 54808, z = 4 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54692, y = 54802, z = 5 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54690, y = 54812, z = 4 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54690, y = 54813, z = 4 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54693, y = 54813, z = 5 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54694, y = 54796, z = 6 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54694, y = 54796, z = 7 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54699, y = 54803, z = 6 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54700, y = 54803, z = 6 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54714, y = 54843, z = 7 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54714, y = 54844, z = 7 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54694, y = 54847, z = 7 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54694, y = 54847, z = 6 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54714, y = 54843, z = 6 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54714, y = 54844, z = 6 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54663, y = 54879, z = 7 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54654, y = 54890, z = 6 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54654, y = 54890, z = 5 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54663, y = 54879, z = 6 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54794, y = 54866, z = 7 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54794, y = 54866, z = 6 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54791, y = 54842, z = 7 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54782, y = 54843, z = 6 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54778, y = 54844, z = 5 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54777, y = 54843, z = 4 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54777, y = 54843, z = 3 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54778, y = 54844, z = 4 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54782, y = 54843, z = 5 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54791, y = 54842, z = 6 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54806, y = 54847, z = 7 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54814, y = 54855, z = 7 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54814, y = 54855, z = 6 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54806, y = 54847, z = 6 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54785, y = 54827, z = 7 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54780, y = 54811, z = 6 }, type = "ladder_up", dir = "up" },
  { pos = { x = 54783, y = 54811, z = 5 }, type = "ladder_up", dir = "up" },
  { pos = { x = 54783, y = 54811, z = 4 }, type = "ladder_down", dir = "down" },
  { pos = { x = 54780, y = 54811, z = 5 }, type = "ladder_down", dir = "down" },
  { pos = { x = 54785, y = 54827, z = 6 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54767, y = 54825, z = 7 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54762, y = 54822, z = 6 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54762, y = 54822, z = 5 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54767, y = 54825, z = 6 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54759, y = 54843, z = 7 }, moveTo = { x = 54759, y = 54844, z = 7 }, exit = { x = 54759, y = 54844, z = 6 }, type = "stairs_up", dir = "up", action = "move" },
  { pos = { x = 54759, y = 54845, z = 6 }, moveTo = { x = 54759, y = 54844, z = 6 }, exit = { x = 54759, y = 54844, z = 7 }, type = "stairs_down", dir = "down", action = "move" },
  { pos = { x = 54823, y = 54793, z = 7 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54818, y = 54790, z = 6 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54818, y = 54790, z = 5 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54823, y = 54793, z = 6 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54799, y = 54786, z = 7 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54799, y = 54786, z = 6 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54784, y = 54779, z = 7 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54784, y = 54778, z = 7 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54784, y = 54778, z = 6 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54784, y = 54779, z = 6 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54799, y = 54774, z = 7 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54817, y = 54771, z = 7 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54794, y = 54753, z = 7 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54793, y = 54753, z = 7 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54799, y = 54774, z = 6 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54817, y = 54771, z = 6 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54793, y = 54753, z = 6 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54794, y = 54753, z = 6 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54765, y = 54859, z = 7 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54686, y = 54752, z = 7 }, type = "ladder_up", dir = "up" },
  { pos = { x = 54686, y = 54752, z = 6 }, type = "ladder_down", dir = "down" },
  { pos = { x = 54695, y = 54771, z = 7 }, type = "ladder_up", dir = "up" },
  { pos = { x = 54695, y = 54771, z = 6 }, type = "ladder_down", dir = "down" },
  { pos = { x = 54708, y = 54775, z = 7 }, type = "ladder_up", dir = "up" },
  { pos = { x = 54708, y = 54775, z = 6 }, type = "ladder_down", dir = "down" },
  { pos = { x = 54722, y = 54777, z = 7 }, type = "ladder_up", dir = "up" },
  { pos = { x = 54722, y = 54777, z = 6 }, type = "ladder_down", dir = "down" },
  { pos = { x = 54718, y = 54772, z = 7 }, type = "ladder_up", dir = "up" },
  { pos = { x = 54718, y = 54772, z = 6 }, type = "ladder_down", dir = "down" },
  { pos = { x = 54712, y = 54754, z = 7 }, type = "ladder_up", dir = "up" },
  { pos = { x = 54712, y = 54754, z = 6 }, type = "ladder_down", dir = "down" },
  { pos = { x = 54740, y = 54755, z = 7 }, type = "stairs_up", dir = "up" },
  { pos = { x = 54740, y = 54755, z = 6 }, type = "stairs_down", dir = "down" },
  { pos = { x = 54749, y = 54754, z = 7 }, type = "ladder_up", dir = "up" },
  { pos = { x = 54749, y = 54754, z = 6 }, type = "ladder_down", dir = "down" },
  { pos = { x = 54731, y = 54765, z = 7 }, type = "ladder_up", dir = "up" },
  { pos = { x = 54731, y = 54765, z = 6 }, type = "ladder_down", dir = "down" },
  { pos = { x = 54733, y = 54770, z = 7 }, type = "ladder_up", dir = "up" },
  { pos = { x = 54733, y = 54770, z = 6 }, type = "ladder_down", dir = "down" },
  { pos = { x = 54743, y = 54770, z = 7 }, type = "ladder_up", dir = "up" },
  { pos = { x = 54743, y = 54770, z = 6 }, type = "ladder_down", dir = "down" },
  { pos = { x = 54736, y = 54775, z = 7 }, type = "ladder_up", dir = "up" },
  { pos = { x = 54736, y = 54775, z = 6 }, type = "ladder_down", dir = "down" },
  { pos = { x = 54738, y = 54785, z = 7 }, type = "ladder_up", dir = "up" },
  { pos = { x = 54738, y = 54785, z = 6 }, type = "ladder_down", dir = "down" }
}

local stagedState = {
  active = false,
  event = nil,
  steps = 0,
  stuck = 0,
  lastStuckPos = nil,
  lastCalcPos = nil,
  lastPathAt = 0
}

local stairState = {
  active = false,
  event = nil,
  stuck = 0,
  lastStuckPos = nil,
  lastCalcPos = nil,
  lastSequenceAt = 0,
  lastSequenceKey = "",
  lastBestStair = nil
}

local navTargetState = {
  signature = "",
  target = nil,
  at = 0
}

local startBotServerStagedWalk
local stopBotServerStagedWalk
local startBotServerStairWalk
local stopBotServerStairWalk
local botServerStairWalk

local function activeWalkTick()
  if navRouteMode == "exalted" then return NAV_EXALTED_WALK_TICK_MS end
  return NAV_WALK_TICK_MS
end

local function activeCombatWalkTick()
  if navRouteMode == "exalted" then return NAV_EXALTED_WALK_TICK_MS end
  return NAV_COMBAT_WALK_TICK_MS
end

local function activePathRecalcMs(inCombat, pressureMove)
  if pressureMove then return NAV_PRESSURE_WALK_TICK_MS end
  if navRouteMode == "exalted" then return NAV_EXALTED_PATH_RECALC_MS end
  if inCombat then return NAV_COMBAT_WALK_TICK_MS end
  return NAV_PATH_RECALC_MS
end

local function scheduleStagedWalk(delay)
  if stagedState.active then
    stagedState.event = scheduleEvent(delay or activeWalkTick(), function()
      if BotServerNav and BotServerNav._stagedWalk then
        BotServerNav._stagedWalk()
      end
    end)
  end
end

local function scheduleStairWalk(delay)
  if stairState.active then
    stairState.event = scheduleEvent(delay or activeWalkTick(), function()
      if BotServerNav and BotServerNav._stairWalk then
        BotServerNav._stairWalk()
      end
    end)
  end
end

local function blockTempStairPath(playerPos)
  local temp = normalizePosition(storage.tempStairDestination)
  if not playerPos or not temp then return end
  local key = positionText(playerPos) .. "-" .. positionText(temp)
  STAIR_PATH_CACHE[key] = math.huge
  storage.tempStairDestination = nil
end

local function botServerStagedWalk()
  if not isLocalLeader() and not isLocalScout() then
    if stopBotServerStagedWalk then stopBotServerStagedWalk() end
    return
  end

  local localPlayer = getLocalPlayerObject()
  if not localPlayer or not isGameOnline() then
    if stopBotServerStagedWalk then stopBotServerStagedWalk() end
    return
  end

  local playerPos = normalizePosition(localPlayer:getPosition())
  local destination = getStorageDestination()
  if not playerPos or not destination then
    if stopBotServerStagedWalk then stopBotServerStagedWalk() end
    return
  end

  if samePosition(playerPos, destination) then
    if storage.tempStairDestination then
      storage.tempStairDestination = nil
      if stopBotServerStagedWalk then stopBotServerStagedWalk() end
      scheduleEvent(50, function()
        if startBotServerStairWalk then startBotServerStairWalk() end
      end)
    else
      if stopBotServerStagedWalk then stopBotServerStagedWalk() end
    end
    return
  end

  local currentTime = navMillis()
  local inCombat = shouldYieldToCombat()
  local pressureMove = isNightWolfCreature(getAttackingCreature())

  if inCombat and playerPos.z == destination.z and runAutoWalk(destination, navigationPrecision(destination)) then
    stagedState.stuck = 0
    stagedState.lastStuckPos = playerPos
    scheduleStagedWalk(activeCombatWalkTick())
    return
  end

  if pressureMove and playerPos.z == destination.z and runAutoWalk(destination, navigationPrecision(destination)) then
    stagedState.stuck = 0
    stagedState.lastStuckPos = playerPos
    scheduleStagedWalk(NAV_PRESSURE_WALK_TICK_MS)
    return
  end

  if stagedState.lastCalcPos and playerPos.z == stagedState.lastCalcPos.z then
    local distWalked = botServerDistance(playerPos, stagedState.lastCalcPos)
    local isAutoWalking = false
    if localPlayer.isAutoWalking then
      local ok, value = pcall(function() return localPlayer:isAutoWalking() end)
      isAutoWalking = ok and value == true
    end
    if distWalked < 5 and isAutoWalking then
      scheduleStagedWalk(pressureMove and NAV_PRESSURE_WALK_TICK_MS or nil)
      return
    end
  end

  stagedState.lastCalcPos = playerPos

  local pathRecalcMs = activePathRecalcMs(inCombat, pressureMove)
  if stagedState.lastPathAt > 0 and currentTime - stagedState.lastPathAt < pathRecalcMs then
    scheduleStagedWalk(pressureMove and NAV_PRESSURE_WALK_TICK_MS or (inCombat and activeCombatWalkTick() or nil))
    return
  end
  stagedState.lastPathAt = currentTime

  if samePosition(stagedState.lastStuckPos, playerPos) then
    stagedState.stuck = stagedState.stuck + 1
    if stagedState.stuck >= 4 then
      blockTempStairPath(playerPos)
      stagedState.stuck = 0
      if stopBotServerStagedWalk then stopBotServerStagedWalk() end
      scheduleEvent(50, function()
        if startBotServerStairWalk then startBotServerStairWalk() end
      end)
      return
    end
  else
    stagedState.stuck = 0
    stagedState.lastStuckPos = playerPos
  end

  local path = nil
  if canFindPath() then
    local ok, value = pcall(findPath, playerPos, destination, 1000, {
      ignoreNonPathable = true,
      precision = 1,
      ignoreCreatures = true
    })
    if ok then path = value end
  end

  if not path or #path == 0 then
    if storage.tempStairDestination then
      blockTempStairPath(playerPos)
    elseif playerPos.z == destination.z then
      runAutoWalk(destination, navigationPrecision(destination))
      scheduleStagedWalk(pressureMove and NAV_PRESSURE_WALK_TICK_MS or (inCombat and activeCombatWalkTick() or nil))
      return
    end

    if stopBotServerStagedWalk then stopBotServerStagedWalk() end
    scheduleEvent(50, function()
      if startBotServerStairWalk then startBotServerStairWalk() end
    end)
    return
  end

  if #path < WALK_STEP_DISTANCE then
    runAutoWalk(destination, navigationPrecision(destination))
    scheduleStagedWalk(pressureMove and NAV_PRESSURE_WALK_TICK_MS or (inCombat and activeCombatWalkTick() or nil))
    return
  end

  local stepPos = getPositionAfterSteps(playerPos, path, WALK_STEP_DISTANCE)
  runAutoWalk(stepPos, 1)
  stagedState.steps = stagedState.steps + 1
  scheduleStagedWalk(pressureMove and NAV_PRESSURE_WALK_TICK_MS or (inCombat and activeCombatWalkTick() or nil))
end

startBotServerStagedWalk = function()
  if stagedState.active then return true end
  stagedState.active = true
  stagedState.steps = 0
  stagedState.stuck = 0
  stagedState.lastStuckPos = nil
  stagedState.lastCalcPos = nil
  stagedState.lastPathAt = 0
  scheduleStagedWalk(20)
  return true
end

stopBotServerStagedWalk = function()
  if not stagedState.active then return end
  stagedState.active = false
  removeScheduledEvent(stagedState.event)
  stagedState.event = nil
  stagedState.stuck = 0
  stagedState.lastStuckPos = nil
  stagedState.lastCalcPos = nil
  stagedState.lastPathAt = 0
  safeStopGame()
end

local function posToKey(pos)
  return pos.x .. "," .. pos.y .. "," .. pos.z
end

local function cachedPathCost(fromPos, toPos, isDestination)
  local key1 = posToKey(fromPos) .. "-" .. posToKey(toPos)
  local key2 = posToKey(toPos) .. "-" .. posToKey(fromPos)

  if STAIR_PATH_CACHE[key1] then return STAIR_PATH_CACHE[key1] end
  if STAIR_PATH_CACHE[key2] then return STAIR_PATH_CACHE[key2] end

  local dist = botServerDistance(fromPos, toPos)
  local cost = nil

  if dist > 60 then
    cost = dist * 10
  elseif canFindPath() then
    local ok, path = pcall(findPath, fromPos, toPos, 250, {
      ignoreNonPathable = true,
      precision = 1,
      ignoreCreatures = true
    })
    if ok and path then
      cost = #path
    end
  end

  if not cost then
    if dist <= 1 then
      cost = 1
    elseif isDestination then
      cost = dist * 10
    else
      cost = math.huge
    end
  end

  STAIR_PATH_CACHE[key1] = cost
  return cost
end

local function stairExitPosition(stair)
  if not stair then return nil end
  if stair.exit then
    local explicitExit = normalizePosition(stair.exit)
    if explicitExit then return explicitExit end
  end
  if not stair.pos then return nil end
  local exitZ = stair.dir == "up" and (stair.pos.z - 1) or (stair.pos.z + 1)
  return { x = stair.pos.x, y = stair.pos.y, z = exitZ }
end

local function stairMovePosition(stair)
  if not stair then return nil end
  if stair.moveTo then
    local moveTo = normalizePosition(stair.moveTo)
    if moveTo then return moveTo end
  end
  return normalizePosition(stair.pos)
end

local function isMoveStair(stair)
  return stair and (stair.action == "move" or stair.mode == "move" or stair.noUse == true)
end

local function isStairCandidateBlocked(playerPos, stair)
  if not playerPos or not stair or not stair.pos then return true end
  local key1 = posToKey(playerPos) .. "-" .. posToKey(stair.pos)
  local key2 = posToKey(stair.pos) .. "-" .. posToKey(playerPos)
  return STAIR_PATH_CACHE[key1] == math.huge or STAIR_PATH_CACHE[key2] == math.huge
end

local function getBestStairSequence(playerPos, destination, laddersList)
  do
    if not playerPos or not destination then return nil end
    if playerPos.z == destination.z then return "WALK_DIRECT" end

    local currentGap = math.abs(playerPos.z - destination.z)
    local bestStair = nil
    local bestScore = math.huge

    for _, stair in ipairs(laddersList or {}) do
      if stair.pos and stair.pos.z == playerPos.z and not isStairCandidateBlocked(playerPos, stair) then
        local exitPos = stairExitPosition(stair)
        if exitPos and math.abs(exitPos.z - destination.z) < currentGap then
          local entryCost = botServerDistance(playerPos, stair.pos)
          local exitCost = botServerDistance(exitPos, destination)
          local zCost = math.abs(exitPos.z - destination.z) * 50
          local score = entryCost + exitCost + zCost
          if isMoveStair(stair) then score = score - 2 end
          if score < bestScore then
            bestScore = score
            bestStair = stair
          end
        end
      end
    end

    return bestStair
  end

  local nodes = {}
  local startKey = posToKey(playerPos)
  local destKey = posToKey(destination)

  nodes[startKey] = { pos = playerPos, dist = 0 }
  nodes[destKey] = { pos = destination, dist = math.huge }

  for _, stair in ipairs(laddersList) do
    local entryKey = posToKey(stair.pos)
    nodes[entryKey] = nodes[entryKey] or { pos = stair.pos, dist = math.huge }
    nodes[entryKey].stairEntry = stair

    local exitPos = stairExitPosition(stair)
    if exitPos then
      local exitKey = posToKey(exitPos)
      nodes[exitKey] = nodes[exitKey] or { pos = exitPos, dist = math.huge }
    end
  end

  local unvisited = {}
  for key in pairs(nodes) do table.insert(unvisited, key) end

  local previous = {}

  while #unvisited > 0 do
    local minDist = math.huge
    local selectedKey = nil
    local selectedIndex = nil

    for index, key in ipairs(unvisited) do
      if nodes[key].dist < minDist then
        minDist = nodes[key].dist
        selectedKey = key
        selectedIndex = index
      end
    end

    if not selectedKey or minDist == math.huge then break end
    if selectedKey == destKey then break end

    table.remove(unvisited, selectedIndex)
    local current = nodes[selectedKey]

    for _, nextKey in ipairs(unvisited) do
      local nextNode = nodes[nextKey]
      local alt = nil

      if current.pos.z == nextNode.pos.z then
        alt = current.dist + cachedPathCost(current.pos, nextNode.pos, nextKey == destKey)
      elseif current.stairEntry then
        local exitPos = stairExitPosition(current.stairEntry)
        if exitPos and nextNode.pos.z == exitPos.z then
          local walkCost = cachedPathCost(exitPos, nextNode.pos, nextKey == destKey)
          if walkCost < math.huge then alt = current.dist + 1 + walkCost end
        end
      end

      if alt and alt < nextNode.dist then
        nextNode.dist = alt
        previous[nextKey] = selectedKey
      end
    end
  end

  if not previous[destKey] and startKey ~= destKey then
    if playerPos.z ~= destination.z then
      local bestFallback = nil
      local bestFallbackCost = math.huge

      for _, stair in ipairs(laddersList) do
        if stair.pos.z == playerPos.z then
          local exitPos = stairExitPosition(stair)
          if exitPos and math.abs(exitPos.z - destination.z) < math.abs(playerPos.z - destination.z) then
            local cost = cachedPathCost(playerPos, stair.pos, false)
            if cost < bestFallbackCost then
              bestFallbackCost = cost
              bestFallback = stair
            end
          end
        end
      end

      if bestFallback then return bestFallback end
    end

    return nil
  end

  local currentKey = destKey
  local pathKeys = {}
  while currentKey do
    table.insert(pathKeys, 1, currentKey)
    currentKey = previous[currentKey]
  end

  for index = 1, #pathKeys - 1 do
    local node = nodes[pathKeys[index]]
    local nextNode = nodes[pathKeys[index + 1]]
    if node.stairEntry and node.pos.z == playerPos.z then
      local exitPos = stairExitPosition(node.stairEntry)
      if exitPos and nextNode.pos.z == exitPos.z then return node.stairEntry end
    end
  end

  return "WALK_DIRECT"
end

local function blockStairPath(playerPos, stair)
  if not playerPos or not stair then return end
  local key1 = posToKey(playerPos) .. "-" .. posToKey(stair.pos)
  local key2 = posToKey(stair.pos) .. "-" .. posToKey(playerPos)
  STAIR_PATH_CACHE[key1] = math.huge
  STAIR_PATH_CACHE[key2] = math.huge
  stairState.lastSequenceKey = ""
  stairState.lastBestStair = nil
end

local function getBestStairSequenceCached(playerPos, destination, laddersList)
  local currentTime = navMillis()
  local key = posToKey(playerPos) .. ">" .. posToKey(destination)

  if stairState.lastSequenceKey == key and currentTime - stairState.lastSequenceAt < NAV_STAIR_RECALC_MS then
    return stairState.lastBestStair
  end

  local bestStair = getBestStairSequence(playerPos, destination, laddersList)
  stairState.lastSequenceKey = key
  stairState.lastSequenceAt = currentTime
  stairState.lastBestStair = bestStair
  return bestStair
end

local function useTopThingAt(pos)
  if not g_map or not g_game or type(g_map.getTile) ~= "function" or type(g_game.use) ~= "function" then
    return false
  end

  local ok, tile = pcall(function() return g_map.getTile(pos) end)
  if not ok or not tile or not tile.getTopUseThing then return false end

  local thing = tile:getTopUseThing()
  if not thing then return false end

  return pcall(function() g_game.use(thing) end)
end

local function runMoveStairTransition(stair, playerPos)
  local moveTo = stairMovePosition(stair)
  if not moveTo then return false end

  if not samePosition(playerPos, moveTo) then
    if not runAutoWalk(moveTo, 0) then return false end
  end

  scheduleEvent(160, function()
    local currentPlayer = getLocalPlayerObject()
    local currentPos = currentPlayer and normalizePosition(currentPlayer:getPosition())
    if currentPos and currentPos.z ~= playerPos.z then
      if stopBotServerStairWalk then stopBotServerStairWalk() end
      if startBotServerStagedWalk then startBotServerStagedWalk() end
    elseif stairState.active then
      botServerStairWalk()
    end
  end)
  return true
end

botServerStairWalk = function()
  if not isLocalLeader() and not isLocalScout() then
    if stopBotServerStairWalk then stopBotServerStairWalk() end
    return
  end

  local localPlayer = getLocalPlayerObject()
  if not localPlayer or not isGameOnline() then
    if stopBotServerStairWalk then stopBotServerStairWalk() end
    return
  end

  local playerPos = normalizePosition(localPlayer:getPosition())
  local destination = getStorageDestination()
  if not playerPos or not destination then
    if stopBotServerStairWalk then stopBotServerStairWalk() end
    return
  end

  if samePosition(playerPos, destination) then
    if stopBotServerStairWalk then stopBotServerStairWalk() end
    return
  end

  local inCombat = shouldYieldToCombat()
  local pressureMove = isNightWolfCreature(getAttackingCreature())
  if inCombat and playerPos.z == destination.z and runAutoWalk(destination, navigationPrecision(destination)) then
    stairState.stuck = 0
    stairState.lastStuckPos = playerPos
    scheduleStairWalk(activeCombatWalkTick())
    return
  end

  if pressureMove and playerPos.z == destination.z and runAutoWalk(destination, navigationPrecision(destination)) then
    stairState.stuck = 0
    stairState.lastStuckPos = playerPos
    scheduleStairWalk(NAV_PRESSURE_WALK_TICK_MS)
    return
  end

  if stairState.lastCalcPos and playerPos.z == stairState.lastCalcPos.z then
    local distWalked = botServerDistance(playerPos, stairState.lastCalcPos)
    local isAutoWalking = false
    if localPlayer.isAutoWalking then
      local ok, value = pcall(function() return localPlayer:isAutoWalking() end)
      isAutoWalking = ok and value == true
    end
    if distWalked < 5 and isAutoWalking then
      scheduleStairWalk(pressureMove and NAV_PRESSURE_WALK_TICK_MS or (inCombat and activeCombatWalkTick() or nil))
      return
    end
  end

  stairState.lastCalcPos = playerPos

  local bestStair = getBestStairSequenceCached(playerPos, destination, navLadders)

  if bestStair and bestStair ~= "WALK_DIRECT" then
    if samePosition(stairState.lastStuckPos, playerPos) then
      stairState.stuck = stairState.stuck + 1
      if stairState.stuck >= 4 then
        blockStairPath(playerPos, bestStair)
        stairState.stuck = 0
        if stopBotServerStairWalk then stopBotServerStairWalk() end
        if startBotServerStagedWalk then startBotServerStagedWalk() end
        return
      end
    else
      stairState.stuck = 0
      stairState.lastStuckPos = playerPos
    end
  end

  if bestStair == "WALK_DIRECT" then
    if stopBotServerStairWalk then stopBotServerStairWalk() end
    scheduleEvent(50, function()
      if startBotServerStagedWalk then startBotServerStagedWalk() end
    end)
    return
  elseif bestStair then
    local moveStair = isMoveStair(bestStair)
    local moveTo = moveStair and stairMovePosition(bestStair) or nil
    if samePosition(playerPos, bestStair.pos) or (moveTo and samePosition(playerPos, moveTo)) then
      if moveStair then
        if runMoveStairTransition(bestStair, playerPos) then return end
      elseif useTopThingAt(playerPos) then
        scheduleEvent(200, function()
          local currentPlayer = getLocalPlayerObject()
          local currentPos = currentPlayer and normalizePosition(currentPlayer:getPosition())
          if currentPos and currentPos.z ~= playerPos.z then
            if stopBotServerStairWalk then stopBotServerStairWalk() end
            if startBotServerStagedWalk then startBotServerStagedWalk() end
          elseif stairState.active then
            botServerStairWalk()
          end
        end)
        return
      end
    else
      storage.tempStairDestination = bestStair.pos
      if stopBotServerStairWalk then stopBotServerStairWalk() end
      scheduleEvent(50, function()
        if startBotServerStagedWalk then startBotServerStagedWalk() end
      end)
      return
    end
  else
    if stopBotServerStairWalk then stopBotServerStairWalk() end
    scheduleEvent(50, function()
      if startBotServerStagedWalk then startBotServerStagedWalk() end
    end)
    return
  end

  scheduleStairWalk(pressureMove and NAV_PRESSURE_WALK_TICK_MS or (inCombat and activeCombatWalkTick() or nil))
end

startBotServerStairWalk = function()
  if stairState.active then return true end
  stairState.active = true
  stairState.stuck = 0
  stairState.lastStuckPos = nil
  stairState.lastCalcPos = nil
  stairState.lastSequenceAt = 0
  stairState.lastSequenceKey = ""
  stairState.lastBestStair = nil
  scheduleStairWalk(20)
  return true
end

stopBotServerStairWalk = function()
  if not stairState.active then return end
  stairState.active = false
  stairState.stuck = 0
  stairState.lastStuckPos = nil
  stairState.lastCalcPos = nil
  stairState.lastSequenceAt = 0
  stairState.lastSequenceKey = ""
  stairState.lastBestStair = nil
  removeScheduledEvent(stairState.event)
  stairState.event = nil
  safeStopGame()
end

local function stopBotServerNavWalker()
  removeScheduledEvent(NavStartQueue.event)
  NavStartQueue.event = nil
  NavStartQueue.target = nil
  NavStartQueue.sender = ""
  NavStartQueue.forceFine = false
  if stopBotServerStagedWalk then stopBotServerStagedWalk() end
  if stopBotServerStairWalk then stopBotServerStairWalk() end
  storage.tempStairDestination = nil
  navTargetState.signature = ""
  navTargetState.target = nil
  navTargetState.at = 0
  navAutoWalkState.signature = ""
  navAutoWalkState.at = 0
end

local function abortExaltedNavigation(reason)
  stopBotServerNavWalker()
  navRouteMode = "idle"
  exaltedHpHoldActive = false
  ExaltedLeaderWatchdog.missingAt = 0
  ExaltedLeaderWatchdog.lastSeenAt = 0
  ScoutExaltedWatchdog.missingAt = 0
  ScoutExaltedWatchdog.lastSeenAt = 0
  NavStartGuard.signature = ""
  NavStartGuard.at = 0
  NavStartGuard.target = nil
  NavInputGuard.signature = ""
  NavInputGuard.at = 0
  NavInputGuard.target = nil
  restoreCavebotAfterExalted()
  notify("Exalted abortado: " .. text(reason))
  return false
end

local lastExaltedFinishAt = 0
local scoutExaltedWaitUntil = 0
local scoutExaltedWaitSignature = ""

local function finishExaltedLeaderNavigation(reason)
  if not isCurrentInstance() or not isLocalLeader() then return false end

  local currentTime = navMillis()
  if currentTime - lastExaltedFinishAt < 2000 then return false end
  lastExaltedFinishAt = currentTime

  stopBotServerNavWalker()
  navRouteMode = "idle"
  exaltedHpHoldActive = false
  ExaltedLeaderWatchdog.missingAt = 0
  ExaltedLeaderWatchdog.lastSeenAt = 0
  ScoutExaltedWatchdog.missingAt = 0
  ScoutExaltedWatchdog.lastSeenAt = 0
  NavStartGuard.signature = ""
  NavStartGuard.at = 0
  NavStartGuard.target = nil
  NavInputGuard.signature = ""
  NavInputGuard.at = 0
  NavInputGuard.target = nil
  local restored = restoreCavebotAfterExalted()
  notify(restored and "Exalted finalizado; CaveBot restaurado" or "Exalted finalizado")
  return true
end

local function finishScoutExaltedWait(reason)
  if not isCurrentInstance() or not isLocalScout() then return false end
  if scoutExaltedWaitUntil <= 0 and navRouteMode ~= "exalted" then return false end

  scoutExaltedWaitUntil = 0
  scoutExaltedWaitSignature = ""
  stopBotServerNavWalker()
  navRouteMode = "idle"
  exaltedHpHoldActive = false
  ExaltedLeaderWatchdog.missingAt = 0
  ExaltedLeaderWatchdog.lastSeenAt = 0
  ScoutExaltedWatchdog.missingAt = 0
  ScoutExaltedWatchdog.lastSeenAt = 0
  NavStartGuard.signature = ""
  NavStartGuard.at = 0
  NavStartGuard.target = nil
  restoreCavebotAfterExalted()
  notify("Scout liberado do Exalted: " .. text(reason))
  return true
end

local function pauseScoutForExalted(targetPos)
  targetPos = normalizePosition(targetPos)
  if not isCurrentInstance() or not isLocalScout() or not targetPos then return false end

  local signature = positionText(targetPos)
  local currentTime = navMillis()
  if scoutExaltedWaitSignature == signature and scoutExaltedWaitUntil > currentTime then return true end

  navTargetState.signature = ""
  navTargetState.target = nil
  navTargetState.at = 0
  navAutoWalkState.signature = ""
  navAutoWalkState.at = 0

  navRouteMode = "exalted"
  scoutExaltedWaitSignature = signature
  scoutExaltedWaitUntil = currentTime + NAV_SCOUT_WAIT_EXALTED_MS
  ScoutExaltedWatchdog.missingAt = 0
  ScoutExaltedWatchdog.lastSeenAt = currentTime
  pauseCavebotForExalted()
  notify("Scout marcou Exalted em " .. signature)
  return true
end

local function startBotServerNavWalker(targetPos)
  targetPos = normalizePosition(targetPos)
  if not targetPos or not canAutoWalk() then return false end
  if not getLocalPlayerObject() then return false end

  stopBotServerNavWalker()
  storage.walkDestination = positionText(targetPos)
  startBotServerStagedWalk()
  return true
end

local function startExistingWalker(targetPos)
  if startBotServerNavWalker(targetPos) then return true end

  if modules and modules.derpetsonWalkManager and type(modules.derpetsonWalkManager.start) == "function" then
    pcall(function() modules.derpetsonWalkManager.start() end)
    return true
  end

  if modules and modules.stagedWalk and type(modules.stagedWalk.startStagedWalk) == "function" then
    pcall(function() modules.stagedWalk.startStagedWalk() end)
    return true
  end

  if type(autoWalk) == "function" then
    local params = { ignoreNonPathable = true, ignoreCreatures = true, precision = 1 }
    local ok, result = pcall(autoWalk, targetPos, 1000, params)
    if ok and result ~= false then return true end
    ok, result = pcall(autoWalk, targetPos, params)
    if ok and result ~= false then return true end
  end

  return false
end

local function shouldRestartNavigation(targetPos, forceFine)
  targetPos = normalizePosition(targetPos)
  if not targetPos then return false end

  local currentTime = navMillis()
  local signature = positionText(targetPos)

  if navTargetState.target then
    local lastTarget = normalizePosition(navTargetState.target)
    local elapsed = currentTime - navTargetState.at
    if lastTarget and lastTarget.z == targetPos.z then
      local targetDistance = botServerDistance(lastTarget, targetPos)
      local playerDistance = distanceTo(lastTarget)
      if forceFine == true then
        if signature == navTargetState.signature and elapsed < NAV_FINE_UPDATE_MS then
          return false
        end
        return elapsed >= NAV_FINE_UPDATE_MS or targetDistance > 0
      end
      if playerDistance > NAV_FINE_SCAN_DISTANCE and targetDistance <= NAV_APPROACH_THRESHOLD and elapsed < NAV_DUPLICATE_TARGET_MS then
        return false
      end
      if signature == navTargetState.signature and elapsed < NAV_DUPLICATE_TARGET_MS then
        return false
      end
      if targetDistance <= NAV_NEAR_TARGET_DISTANCE and elapsed < NAV_NEAR_TARGET_MS then
        return false
      end
    end
  end

  return true
end

local function markNavigationStarted(targetPos)
  targetPos = normalizePosition(targetPos)
  if not targetPos then return end
  navTargetState.signature = positionText(targetPos)
  navTargetState.target = { x = targetPos.x, y = targetPos.y, z = targetPos.z }
  navTargetState.at = navMillis()
end

local function isNavWalkerRunning()
  return (stagedState and stagedState.active == true) or (stairState and stairState.active == true)
end

local function startNavigation(targetPos, senderName, forceFine)
  targetPos = normalizePosition(targetPos)
  if not isEnabled() or not targetPos then return false end
  if not isLocalLeader() then return false end
  if not isAllowedNavPosition(targetPos) then
    notifyNavAreaBlocked("destino")
    return false
  end
  if not isLocalInsideNavArea() then
    notifyNavAreaBlocked("leader")
    return false
  end

  local currentTime = navMillis()
  local startGuardTarget = normalizePosition(NavStartGuard.target)
  if startGuardTarget and startGuardTarget.z == targetPos.z
    and currentTime - (tonumber(NavStartGuard.at) or 0) < NAV_START_LOCK_MS
    and botServerDistance(startGuardTarget, targetPos) <= NAV_START_LOCK_DISTANCE
    and isNavWalkerRunning()
  then
    return true
  end

  if isNavWalkerRunning() and not shouldRestartNavigation(targetPos, forceFine) then return true end

  if not setDestination(targetPos) then
    return abortExaltedNavigation("falha ao setar destino")
  end

  navRouteMode = "exalted"
  ExaltedLeaderWatchdog.missingAt = 0
  ExaltedLeaderWatchdog.lastSeenAt = 0
  local started = startExistingWalker(targetPos)
  if not started then
    return abortExaltedNavigation("falha ao iniciar walker")
  end

  setCavebotByDistance(targetPos)
  NavStartGuard.signature = positionText(targetPos)
  NavStartGuard.at = currentTime
  NavStartGuard.target = { x = targetPos.x, y = targetPos.y, z = targetPos.z }
  markNavigationStarted(targetPos)
  notify("destino " .. positionText(targetPos) .. " por " .. text(senderName))
  return true
end

local function queueNavigationStart(targetPos, senderName, forceFine)
  targetPos = normalizePosition(targetPos)
  if not targetPos then return false end

  NavStartQueue.target = { x = targetPos.x, y = targetPos.y, z = targetPos.z }
  NavStartQueue.sender = text(senderName)
  NavStartQueue.forceFine = forceFine == true
  NavStartQueue.at = navMillis()

  if NavStartQueue.event then return true end

  NavStartQueue.event = scheduleEvent(30, function()
    NavStartQueue.event = nil
    local queuedTarget = normalizePosition(NavStartQueue.target)
    local queuedSender = text(NavStartQueue.sender)
    local queuedForceFine = NavStartQueue.forceFine == true
    NavStartQueue.target = nil
    NavStartQueue.sender = ""
    NavStartQueue.forceFine = false
    if queuedTarget then
      startNavigation(queuedTarget, queuedSender, queuedForceFine)
    end
  end)

  return true
end

local function payloadPosition(message)
  if type(message) ~= "table" then
    message = parseText(message)
  end
  if type(message) ~= "table" then return nil end
  return normalizePosition(message.position) or normalizePosition({ x = message.x, y = message.y, z = message.z })
end

local function sendLeaderNavStatus(status, targetPos, scoutName, sourceType)
  targetPos = normalizePosition(targetPos)
  if not targetPos or not BotServer or type(BotServer.send) ~= "function" then return false end

  local payload = {
    kind = "exalted_wolf",
    status = text(status),
    leader = localPlayerName(),
    scout = text(scoutName),
    source = text(sourceType),
    x = targetPos.x,
    y = targetPos.y,
    z = targetPos.z,
    position = targetPos,
    location = positionText(targetPos),
    sentAt = navMillis()
  }

  pcall(function() BotServer.send(BOTSERVER_NAV_STATUS_TOPIC, payload) end)
  return true
end

local scoutExaltedClaim = { scout = "", position = nil, at = 0 }
local lastScoutClaimIgnoredNoticeAt = 0

local function normalizeScoutName(value)
  return text(value):gsub("^%s+", ""):gsub("%s+$", "")
end

local function clearExpiredScoutExaltedClaim()
  if text(scoutExaltedClaim.scout) == "" then return end
  if navMillis() - (tonumber(scoutExaltedClaim.at) or 0) <= NAV_EXALTED_SCOUT_CLAIM_MS then return end
  scoutExaltedClaim.scout = ""
  scoutExaltedClaim.position = nil
  scoutExaltedClaim.at = 0
end

local function sameScoutClaimSpot(a, b)
  a = normalizePosition(a)
  b = normalizePosition(b)
  if not a or not b or a.z ~= b.z then return false end
  return botServerDistance(a, b) <= NAV_EXALTED_SCOUT_CLAIM_DISTANCE
end

local function preferScoutClaim(candidate, current)
  candidate = normalizeScoutName(candidate):lower()
  current = normalizeScoutName(current):lower()
  if current == "" then return true end
  if candidate == "" then return false end
  return candidate < current
end

local function noteScoutExaltedClaim(scoutName, targetPos)
  scoutName = normalizeScoutName(scoutName)
  targetPos = normalizePosition(targetPos)
  if scoutName == "" or not targetPos then return false end

  clearExpiredScoutExaltedClaim()
  local currentPos = normalizePosition(scoutExaltedClaim.position)
  local sameSpot = currentPos and sameScoutClaimSpot(currentPos, targetPos)
  local shouldReplace = not currentPos or not sameSpot or scoutExaltedClaim.scout == scoutName

  if sameSpot and scoutExaltedClaim.scout ~= scoutName then
    shouldReplace = preferScoutClaim(scoutName, scoutExaltedClaim.scout)
  end

  if shouldReplace then
    scoutExaltedClaim.scout = scoutName
    scoutExaltedClaim.position = { x = targetPos.x, y = targetPos.y, z = targetPos.z }
    scoutExaltedClaim.at = navMillis()
  end

  return scoutExaltedClaim.scout == scoutName
end

local function isAnotherScoutClaimingExalted(targetPos)
  clearExpiredScoutExaltedClaim()
  local claimPos = normalizePosition(scoutExaltedClaim.position)
  if not claimPos or not sameScoutClaimSpot(claimPos, targetPos) then return false end
  local localName = normalizeScoutName(localPlayerName())
  return normalizeScoutName(scoutExaltedClaim.scout) ~= "" and normalizeScoutName(scoutExaltedClaim.scout) ~= localName
end

local function notifyScoutClaimIgnored()
  local currentTime = navMillis()
  if currentTime - lastScoutClaimIgnoredNoticeAt < 5000 then return end
  lastScoutClaimIgnoredNoticeAt = currentTime
  notify("Exalted ja tem Scout: " .. text(scoutExaltedClaim.scout) .. "; seguindo rota")
end

local function handleMessage(senderName, message, sourceType)
  if not isEnabled() then return false end
  local sourceName = text(senderName)
  if type(message) == "table" and text(message.scout) ~= "" then
    sourceName = text(message.scout)
  end
  local targetPos = payloadPosition(message)
  if not targetPos then return false end
  if not isAllowedNavPosition(targetPos) then return false end
  if isIgnoredTarget(targetPos) then return false end

  local currentTime = navMillis()
  local inputSignature = positionText(targetPos)
  local inputSource = text(sourceType)
  local lastInputTarget = normalizePosition(NavInputGuard.target)
  local inputElapsed = currentTime - (tonumber(NavInputGuard.at) or 0)
  local activeExaltedWalker = navRouteMode == "exalted" and isNavWalkerRunning()

  if activeExaltedWalker and inputSignature == text(NavInputGuard.signature) and inputElapsed < NAV_INPUT_DEDUPE_MS then
    return false
  end

  if activeExaltedWalker and lastInputTarget and lastInputTarget.z == targetPos.z
    and inputElapsed < NAV_INPUT_NEAR_DEDUPE_MS
    and botServerDistance(lastInputTarget, targetPos) <= NAV_INPUT_NEAR_DISTANCE
  then
    return false
  end

  NavInputGuard.signature = inputSignature
  NavInputGuard.at = currentTime
  NavInputGuard.source = inputSource
  NavInputGuard.target = { x = targetPos.x, y = targetPos.y, z = targetPos.z }

  noteScoutExaltedClaim(sourceName, targetPos)
  if isLocalScout() and isAnotherScoutClaimingExalted(targetPos) then
    finishScoutExaltedWait("outro scout")
  end

  if not isLocalLeader() then return false end
  if not isLocalInsideNavArea() then
    notifyNavAreaBlocked("leader")
    return false
  end
  notify("Leader recebeu " .. (inputSource ~= "" and inputSource or "nav") .. " " .. inputSignature .. " de " .. text(sourceName))
  local accepted = queueNavigationStart(targetPos, sourceName)
  if accepted then
    sendLeaderNavStatus("accepted", targetPos, sourceName, inputSource ~= "" and inputSource or "nav")
  end
  return accepted
end

local function handleNavMwMessage(senderName, message)
  if not isCurrentInstance() or navConfig.navMwEnabled ~= true then return false end
  local sourceName = text(senderName)
  if type(message) == "table" and text(message.caller) ~= "" then
    sourceName = text(message.caller)
  end

  local targetPos = payloadPosition(message)
  if not targetPos then return false end
  if not isAllowedNavPosition(targetPos) then return false end
  if isIgnoredTarget(targetPos) then return false end

  return tryNavMwallAroundTarget(targetPos, sourceName, payloadAttackerPosition(message))
end

local function handleExaltedWolfTopic(senderName, message)
  if not isEnabled() or type(message) ~= "table" then return false end
  local kind = text(message.kind):lower()
  if kind ~= "" and kind ~= "exalted_wolf" then return false end

  local status = text(message.status):lower()
  if message.dead == true or status == "dead" or status == "death" or status == "killed" or status == "loot" then
    finishExaltedLeaderNavigation(status ~= "" and status or "exalted-topic")
    finishScoutExaltedWait(status ~= "" and status or "exalted-topic")
    return true
  end

  local targetPos = payloadPosition(message)
  if not targetPos then return false end
  if not isAllowedNavPosition(targetPos) then return false end
  if isIgnoredTarget(targetPos) then return false end

  local sourceName = text(message.scout)
  if sourceName == "" then sourceName = text(message.sender) end
  if sourceName == "" then sourceName = text(message.name) end
  if sourceName == "" then sourceName = text(senderName) end

  return handleMessage(sourceName, message, "exalted_wolf")
end

local function publishFromText(rawText)
  if not isEnabled() then return false end
  if not isLocalInsideNavArea() then
    notifyNavAreaBlocked("exiva")
    return false
  end
  local localName = localPlayerName()

  local payload = parseText(rawText)
  if not payload then return false end
  local targetPos = payloadPosition(payload)
  if not isAllowedNavPosition(targetPos) then return false end
  if isIgnoredTarget(targetPos) then return false end

  if isLocalScout() and BotServer and BotServer.send then
    payload.scout = text(payload.scout) ~= "" and payload.scout or localName
    pcall(function() BotServer.send(BOTSERVER_NAV_TOPIC, payload) end)
  end

  return handleMessage(localName, payload, "legacy")
end

local function millis()
  return navMillis()
end

local function creatureName(creature)
  return getCreatureName(creature)
end

local function creaturePosition(creature)
  if creature and creature.getPosition then
    local ok, value = pcall(function() return creature:getPosition() end)
    if ok then return normalizePosition(value) end
  end

  return nil
end

local function creatureHp(creature)
  if creature and creature.getHealthPercent then
    local ok, value = pcall(function() return creature:getHealthPercent() end)
    if ok then return tonumber(value) or 0 end
  end

  return 0
end

local function tableHasValues(values)
  if type(values) ~= "table" then return false end
  if #values > 0 then return true end
  for _, _ in pairs(values) do
    return true
  end
  return false
end

local function visibleSpectators()
  if type(getSpectators) ~= "function" then return nil end

  local attempts = {
    function() return getSpectators(false) end,
    function() return getSpectators() end
  }

  local fallback = nil
  for _, attempt in ipairs(attempts) do
    local ok, spectators = pcall(attempt)
    if ok and type(spectators) == "table" then
      fallback = fallback or spectators
      if tableHasValues(spectators) then return spectators end
    end
  end

  return fallback
end

local function isPlayerCreatureForNav(creature)
  if not creature or type(creature.isPlayer) ~= "function" then return false end
  local ok, value = pcall(function() return creature:isPlayer() end)
  return ok and value == true
end

local function guildLocationForNavPlayer(playerName)
  if type(vBot) ~= "table" or type(vBot.BotServerGuildLocations) ~= "table" then return nil end
  return vBot.BotServerGuildLocations[text(playerName)]
end

local function isGuildLocationScout(info)
  if type(info) ~= "table" then return false end
  if info.scoutActive == true or info.navScoutEnabled == true then return true end
  return text(info.role):lower() == "scout"
end

local function isGuildLocationKiller(info)
  if type(info) ~= "table" then return false end
  if info.killerActive == true or info.navLeaderEnabled == true then return true end
  local role = text(info.role):lower()
  return role == "killer" or role == "leader"
end

local function findVisibleKillerNearExalted(targetPos)
  targetPos = normalizePosition(targetPos)
  if not targetPos then return nil end
  local localName = normalizeScoutName(localPlayerName())
  local spectators = visibleSpectators()
  if type(spectators) ~= "table" then return nil end

  for _, creature in ipairs(spectators) do
    if isPlayerCreatureForNav(creature) then
      local playerName = normalizeScoutName(creatureName(creature))
      if playerName ~= "" and playerName ~= localName then
        local info = guildLocationForNavPlayer(playerName)
        if isGuildLocationKiller(info) then
          local playerPos = creaturePosition(creature) or normalizePosition(info)
          if playerPos and playerPos.z == targetPos.z and botServerDistance(playerPos, targetPos) <= NAV_EXALTED_KILLER_RELEASE_DISTANCE then
            return playerName
          end
        end
      end
    end
  end

  return nil
end

local function findOtherVisibleScoutNearExalted(targetPos)
  targetPos = normalizePosition(targetPos)
  if not targetPos then return nil end
  local localName = normalizeScoutName(localPlayerName())
  local spectators = visibleSpectators()
  if type(spectators) ~= "table" then return nil end

  for _, creature in ipairs(spectators) do
    if isPlayerCreatureForNav(creature) then
      local playerName = normalizeScoutName(creatureName(creature))
      if playerName ~= "" and playerName ~= localName then
        local info = guildLocationForNavPlayer(playerName)
        if isGuildLocationScout(info) then
          local playerPos = creaturePosition(creature) or normalizePosition(info)
          if playerPos and playerPos.z == targetPos.z and botServerDistance(playerPos, targetPos) <= 8 then
            return playerName
          end
        end
      end
    end
  end

  return nil
end

local function scoutShouldReleaseToVisibleScout()
  if not isLocalScout() then return false end
  local spectators = visibleSpectators()
  if type(spectators) ~= "table" then return false end

  for _, creature in ipairs(spectators) do
    if isExaltedWolfCreature(creature) and creatureHp(creature) > 0 then
      local targetPos = creaturePosition(creature)
      local otherScout = findOtherVisibleScoutNearExalted(targetPos)
      if otherScout then
        noteScoutExaltedClaim(otherScout, targetPos)
        notifyScoutClaimIgnored()
        return true
      end

      local killerName = findVisibleKillerNearExalted(targetPos)
      if killerName then
        notify("Killer chegou: " .. text(killerName) .. "; Scout seguindo rota")
        return true
      end
    end
  end

  return false
end

local lastWolfSignature = ""
local lastWolfSentAt = 0

local function sendExaltedWolf(creature)
  if not isLocalScout() then return false end
  if not isLocalInsideNavArea() then
    notifyNavAreaBlocked("scout")
    return false
  end

  local localName = localPlayerName()

  local targetPos = creaturePosition(creature)
  if not targetPos then return false end
  if not isAllowedNavPosition(targetPos) then return false end
  if isIgnoredTarget(targetPos) then return false end

  local visibleKiller = findVisibleKillerNearExalted(targetPos)
  if visibleKiller then
    keepScoutOffExalted()
    finishScoutExaltedWait("killer chegou")
    notify("Killer chegou: " .. text(visibleKiller) .. "; Scout seguindo rota")
    return false
  end

  local visibleScout = findOtherVisibleScoutNearExalted(targetPos)
  if visibleScout then
    noteScoutExaltedClaim(visibleScout, targetPos)
    keepScoutOffExalted()
    finishScoutExaltedWait("outro scout")
    notifyScoutClaimIgnored()
    return false
  end

  if isAnotherScoutClaimingExalted(targetPos) then
    keepScoutOffExalted()
    finishScoutExaltedWait("outro scout")
    notifyScoutClaimIgnored()
    return false
  end

  noteScoutExaltedClaim(localName, targetPos)
  keepScoutOffExalted()
  pauseScoutForExalted(targetPos)

  local hp = creatureHp(creature)
  local signature = positionText(targetPos) .. ":" .. text(hp)
  local currentTime = millis()
  local elapsed = currentTime - lastWolfSentAt

  if elapsed < 1000 then return false end
  if signature == lastWolfSignature and elapsed < 3000 then return false end

  lastWolfSignature = signature
  lastWolfSentAt = currentTime

  local payload = {
    kind = "exalted_wolf",
    bossName = creatureName(creature),
    scout = localName,
    x = targetPos.x,
    y = targetPos.y,
    z = targetPos.z,
    hp = hp,
    position = targetPos,
    location = positionText(targetPos),
    sentAt = currentTime
  }

  if BotServer and BotServer.send then
    pcall(function() BotServer.send(BOTSERVER_NAV_TOPIC, payload) end)
  end

  notify("Exalted Wolf enviado: " .. payload.location)
  return handleMessage(localName, payload, "local_scout")
end

local leaderFineSignature = ""
local leaderFineAt = 0

local function refineLeaderTargetFromVisibleWolf()
  if not isLocalLeader() then return false end
  if not isLocalInsideNavArea() then return false end
  if not navTargetState.target then return false end
  if distanceTo(navTargetState.target) > NAV_FINE_SCAN_DISTANCE then return false end

  local spectators = visibleSpectators()
  if type(spectators) ~= "table" then return false end

  for _, creature in ipairs(spectators) do
    if creatureName(creature):lower():find("exalted wolf", 1, true) then
      local targetPos = creaturePosition(creature)
      if not targetPos or isIgnoredTarget(targetPos) then return false end
      if not isAllowedNavPosition(targetPos) then return false end

      local currentTime = navMillis()
      local signature = positionText(targetPos) .. ":" .. text(creatureHp(creature))
      if currentTime - leaderFineAt < NAV_FINE_UPDATE_MS then
        return false
      end

      leaderFineSignature = signature
      leaderFineAt = currentTime
      return startNavigation(targetPos, "leader-scan", true)
    end
  end

  return false
end

function checkExaltedLeaderMissingRestore()
  if not isCurrentInstance() or navRouteMode ~= "exalted" or not isLocalLeader() then
    ExaltedLeaderWatchdog.missingAt = 0
    return false
  end

  local currentTime = navMillis()
  local wolf = findVisibleExaltedWolfForProtection()
  if wolf then
    ExaltedLeaderWatchdog.lastSeenAt = currentTime
    ExaltedLeaderWatchdog.missingAt = 0
    return false
  end

  local target = getAttackingCreature()
  if isExaltedWolfCreature(target) and creatureHpForProtection(target) <= 0 then
    return finishExaltedLeaderNavigation("dead-target")
  end

  local targetPos = normalizePosition(navTargetState.target)
  local playerPos = getPlayerPosition()
  if not targetPos then
    if ExaltedLeaderWatchdog.lastSeenAt <= 0 then
      ExaltedLeaderWatchdog.missingAt = 0
      return false
    end
    if ExaltedLeaderWatchdog.missingAt <= 0 then
      ExaltedLeaderWatchdog.missingAt = currentTime
      return false
    end
    if currentTime - ExaltedLeaderWatchdog.missingAt >= NAV_EXALTED_MISSING_RESTORE_MS then
      return finishExaltedLeaderNavigation("exalted-sumiu")
    end
    return false
  end

  if not playerPos or targetPos.z ~= playerPos.z then
    ExaltedLeaderWatchdog.missingAt = 0
    return false
  end

  if botServerDistance(playerPos, targetPos) > NAV_EXALTED_MISSING_DISTANCE then
    ExaltedLeaderWatchdog.missingAt = 0
    return false
  end

  if ExaltedLeaderWatchdog.missingAt <= 0 then
    ExaltedLeaderWatchdog.missingAt = currentTime
    return false
  end

  if currentTime - ExaltedLeaderWatchdog.missingAt >= NAV_EXALTED_MISSING_RESTORE_MS then
    return finishExaltedLeaderNavigation("exalted-sumiu")
  end

  return false
end

function checkScoutExaltedMissingRestore()
  if not isCurrentInstance() or not isLocalScout() or scoutExaltedWaitUntil <= 0 then
    ScoutExaltedWatchdog.missingAt = 0
    return false
  end

  local currentTime = navMillis()
  local wolf = findVisibleExaltedWolfForProtection()
  if wolf then
    ScoutExaltedWatchdog.lastSeenAt = currentTime
    ScoutExaltedWatchdog.missingAt = 0
    return false
  end

  local target = getAttackingCreature()
  if isExaltedWolfCreature(target) and creatureHpForProtection(target) <= 0 then
    return finishScoutExaltedWait("dead-target")
  end

  if ScoutExaltedWatchdog.missingAt <= 0 then
    ScoutExaltedWatchdog.missingAt = currentTime
    return false
  end

  if currentTime - ScoutExaltedWatchdog.missingAt >= NAV_EXALTED_MISSING_RESTORE_MS then
    return finishScoutExaltedWait("exalted-sumiu")
  end

  return false
end

if type(macro) == "function" then
  registerBotServerNavMacro(macro(NAV_NIGHTWOLF_LURE_MS, function()
    installNavTargetBotLurePatch()
    if navRouteMode ~= "exalted" and navMillis() <= (cavebotRestoreUntil or 0) then
      setCavebotOn()
    end
    keepCavebotPausedForExalted()
    keepScoutOffExalted()
    keepWalkingOverNightWolf()
  end))

  registerBotServerNavMacro(macro(NAV_FINE_SCAN_MS, function()
    installNavTargetBotLurePatch()
    chaseExaltedWolfForLeader()
    refineLeaderTargetFromVisibleWolf()
    checkExaltedLeaderMissingRestore()
  end))

  registerBotServerNavMacro(macro(NAV_SCOUT_SCAN_MS, function()
    if not isLocalScout() then return end
    if not isLocalInsideNavArea() then return end
    if scoutExaltedWaitUntil > 0 then
      if scoutShouldReleaseToVisibleScout() then
        finishScoutExaltedWait("outro scout")
        return
      end
      if checkScoutExaltedMissingRestore() then return end
      if navMillis() < scoutExaltedWaitUntil then return end
      finishScoutExaltedWait("timeout")
      return
    end

    local spectators = visibleSpectators()
    if type(spectators) ~= "table" then return end

    for _, creature in ipairs(spectators) do
      if creatureName(creature):lower():find("exalted wolf", 1, true) then
        sendExaltedWolf(creature)
        return
      end
    end
  end))

end

if BotServer and BotServer.listen then
  pcall(function()
    BotServer.listen(BOTSERVER_EXALTED_WOLF_TOPIC, function(senderName, message)
      handleExaltedWolfTopic(senderName, message)
    end)
  end)
  pcall(function()
    BotServer.listen(BOTSERVER_NAV_TOPIC, function(senderName, message)
      handleMessage(senderName, message, "botserver")
    end)
  end)
  pcall(function()
    BotServer.listen(BOTSERVER_NAV_MW_TOPIC, function(senderName, message)
      handleNavMwMessage(senderName, message)
    end)
  end)
end

local lastLegacyExivaSignature = ""
local lastLegacyExivaAt = 0

local function handleLegacyExivaText(rawText)
  if NAV_LEGACY_TEXT_INPUT_ENABLED ~= true then return false end
  if not isEnabled() then return false end

  local payload = parseText(rawText)
  if not payload then return false end

  local signature = positionText(payload.position) .. ":" .. text(payload.hp)
  local currentTime = navMillis()
  if signature == lastLegacyExivaSignature and currentTime - lastLegacyExivaAt < 1500 then
    return false
  end

  lastLegacyExivaSignature = signature
  lastLegacyExivaAt = currentTime
  return publishFromText(rawText)
end

if type(onCreatureHealthPercentChange) == "function" then
  onCreatureHealthPercentChange(function(creature, healthPercent)
    if tonumber(healthPercent) and tonumber(healthPercent) <= 0 and isExaltedWolfCreature(creature) then
      finishExaltedLeaderNavigation("dead")
      finishScoutExaltedWait("dead")
    end
  end)
end

BotServerNav = {
  topic = BOTSERVER_NAV_TOPIC,
  exaltedTopic = BOTSERVER_EXALTED_WOLF_TOPIC,
  mwTopic = BOTSERVER_NAV_MW_TOPIC,
  statusTopic = BOTSERVER_NAV_STATUS_TOPIC,
  isAllowed = isAllowed,
  isScout = isLocalScout,
  isLeader = isLocalLeader,
  isNavLureActive = isNavLureActive,
  parseText = parseText,
  handleMessage = handleMessage,
  handleExaltedWolfTopic = handleExaltedWolfTopic,
  handleNavMwMessage = handleNavMwMessage,
  publishFromText = publishFromText,
  start = startNavigation,
  stop = function()
    stopBotServerNavMacros()
    stopBotServerNavWalker()
  end,
  _stagedWalk = botServerStagedWalk,
  _stairWalk = botServerStairWalk,
  isIgnoredTarget = isIgnoredTarget,
  sendExaltedWolf = sendExaltedWolf,
  sendBoss = function(x, y, z, hp)
    local payload
    if type(x) == "table" then
      payload = {
        x = tonumber(x.x),
        y = tonumber(x.y),
        z = tonumber(x.z),
        hp = tonumber(x.hp or y) or 0
      }
    else
      payload = {
        x = tonumber(x),
        y = tonumber(y),
        z = tonumber(z),
        hp = tonumber(hp) or 0
      }
    end

    local targetPos = normalizePosition(payload)
    if not targetPos then return false end
    if not isLocalInsideNavArea() then
      notifyNavAreaBlocked("scout")
      return false
    end
    if not isAllowedNavPosition(targetPos) then return false end
    if isIgnoredTarget(targetPos) then return false end
    payload.position = targetPos
    payload.location = positionText(targetPos)

    local localName = localPlayerName()
    if not isLocalScout() then return false end
    if isAnotherScoutClaimingExalted(targetPos) then
      finishScoutExaltedWait("outro scout")
      notifyScoutClaimIgnored()
      return false
    end
    noteScoutExaltedClaim(localName, targetPos)
    payload.scout = localName

    if BotServer and BotServer.send then
      pcall(function() BotServer.send(BOTSERVER_NAV_TOPIC, payload) end)
    end

    return handleMessage(localName, payload, "manual")
  end
}
