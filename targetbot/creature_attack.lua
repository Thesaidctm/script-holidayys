local targetBotLure = false
local targetCount = 0
local delayValue = 0
local lureMax = 0
local anchorPosition = nil
local lastCall = now
local delayFrom = nil
local dynamicLureDelay = false
local nextDynamicLureDelayAt = 0

local function isBlockedAoEMob(creature)
  return TargetBot.Creature and TargetBot.Creature.isBlockedCreature and TargetBot.Creature.isBlockedCreature(creature)
end

local function safeKillUnder()
  return (storage and storage.extras and storage.extras.killUnder) or 30
end

-- Mantem o cliente em modo parado ao atacar.
-- Alguns clientes continuam seguindo o monstro pelo chase mode nativo mesmo com chase=false no TargetBot.
local function forceStandAttackMode()
  if g_game.setChaseMode then
    pcall(function() g_game.setChaseMode(0) end) -- 0 = dont follow / stand mode na maioria dos OTC/vBot
  end
end

local function caveBotIsOn()
  return CaveBot and CaveBot.isOn and CaveBot.isOn()
end

local function markLureSafety(ms)
  if TargetBot and TargetBot.setLureSafety then
    TargetBot.setLureSafety(ms or 300)
  end
end

local function isLureMovementConfig(config)
  return config and (
    config.lure
    or config.lureCavebot
    or config.dynamicLure
    or config.closeLure
    or config.rePosition
    or config.keepDistance
    or config.lureKeepDistanceCavebot
    or config.antiTrap == true
  )
end

local function posDistance(a, b)
  if not a or not b then return 999 end
  return math.max(math.abs((a.x or 0) - (b.x or 0)), math.abs((a.y or 0) - (b.y or 0)))
end

local function tileIsFree(tile)
  if not tile then return false end
  local ok, walkable = pcall(function() return tile:isWalkable(false) end)
  if not ok then
    ok, walkable = pcall(function() return tile:isWalkable() end)
  end
  if not ok or not walkable then return false end
  if tile.hasCreature and tile:hasCreature() then return false end
  return true
end

local function getNearbyMonsters(position, range)
  if not position or not g_map or not g_map.getSpectatorsInRange then return {} end
  local ok, specs = pcall(function()
    return g_map.getSpectatorsInRange(position, false, range or 2, range or 2)
  end)
  if ok and specs then return specs end
  return {}
end

local function countMonstersNear(position, range, specs)
  local count = 0
  range = range or 1
  for _, spec in ipairs(specs or getNearbyMonsters(position, range)) do
    if spec and spec.isMonster and spec:isMonster() and not isBlockedAoEMob(spec) then
      local spos = spec:getPosition()
      if spos and spos.z == position.z and posDistance(position, spos) <= range then
        count = count + 1
      end
    end
  end
  return count
end

function getWalkableTilesCount(position)
  local count = 0
  for _, tile in pairs(getNearTiles(position)) do
    if tileIsFree(tile) then
      count = count + 1
    end
  end
  return count
end

local function chooseBetterTile(fromPos, minTiles)
  local bestPos = nil
  local bestScore = nil
  local specs = getNearbyMonsters(fromPos, 4)

  for dx = -2, 2 do
    for dy = -2, 2 do
      if not (dx == 0 and dy == 0) then
        local candidate = {x = fromPos.x + dx, y = fromPos.y + dy, z = fromPos.z}
        local tile = g_map.getTile(candidate)
        if tileIsFree(tile) then
          local path = findPath(fromPos, candidate, 4, {
            ignoreNonPathable = true,
            ignoreCreatures = false,
            precision = 0
          })
          if path and path[1] then
            local freeTiles = getWalkableTilesCount(candidate)
            local closeMonsters = countMonstersNear(candidate, 1, specs)
            local nearMonsters = countMonstersNear(candidate, 2, specs)
            local score = (freeTiles * 120) - (closeMonsters * 90) - (nearMonsters * 25) - (#path * 8)
            if freeTiles >= (minTiles or 4) then
              score = score + 40
            end
            if not bestScore or score > bestScore then
              bestScore = score
              bestPos = candidate
            end
          end
        end
      end
    end
  end

  return bestPos
end

function rePosition(minTiles)
  minTiles = minTiles or 8
  if now - lastCall < 200 then return end
  local pPos = player:getPosition()
  local playerTilesCount = getWalkableTilesCount(pPos)
  local adjacentMonsters = countMonstersNear(pPos, 1)

  if playerTilesCount > minTiles and adjacentMonsters < 3 then return end
  local targetPos = chooseBetterTile(pPos, minTiles)

  if targetPos then
    lastCall = now
    markLureSafety(400)
    return TargetBot.walkTo(targetPos, 4, {ignoreNonPathable = true, ignoreCreatures = false, precision = 0})
  end
end

local function getNearestEligibleMonster(currentConfig)
  local pos = player:getPosition()
  local creatures = g_map.getSpectatorsInRange(pos, false, 8, 8)
  local nearestCreature = nil
  local nearestDistance = 999
  local nearestPath = nil

  for _, spec in ipairs(creatures) do
    if spec:isMonster() and not isBlockedAoEMob(spec) then
      local path = findPath(pos, spec:getPosition(), 10, {
        ignoreLastCreature = true,
        ignoreCreatures = true,
        ignoreNonPathable = true,
        ignoreCost = true
      })

      if path and path[1] then
        local params = TargetBot.Creature.calculateParams(spec, path)
        if params.priority > 0 and params.config then
          if #path < nearestDistance then
            nearestDistance = #path
            nearestCreature = spec
            nearestPath = path
          end
        end
      end
    end
  end

  return nearestCreature, nearestPath, nearestDistance
end

local function getCurrentCaveBotGotoPos()
  if not CaveBot or not CaveBot.isOn or not CaveBot.isOn() or not CaveBotList then
    return nil
  end

  local list = CaveBotList()
  if not list then return nil end

  local current = list:getFocusedChild() or list:getFirstChild()
  if not current then return nil end

  local currentIndex = list:getChildIndex(current)
  local total = list:getChildCount()
  if not currentIndex or not total or total == 0 then
    return nil
  end

  for offset = 0, total - 1 do
    local index = currentIndex + offset
    if index > total then
      index = index - total
    end

    local child = list:getChildByIndex(index)
    if child and child.action == "goto" then
      local pos = regexMatch(child.value, "\\s*([0-9]+)\\s*,\\s*([0-9]+)\\s*,\\s*([0-9]+)")
      if pos and pos[1] then
        return {
          x = tonumber(pos[1][2]),
          y = tonumber(pos[1][3]),
          z = tonumber(pos[1][4])
        }
      end
    end
  end

  return nil
end

local function chooseRetreatTile(fromPos, threatPos, waypointPos)
  local bestPos = nil
  local bestScore = nil
  local candidates = {
    {x = fromPos.x - 1, y = fromPos.y - 1, z = fromPos.z},
    {x = fromPos.x,     y = fromPos.y - 1, z = fromPos.z},
    {x = fromPos.x + 1, y = fromPos.y - 1, z = fromPos.z},
    {x = fromPos.x - 1, y = fromPos.y,     z = fromPos.z},
    {x = fromPos.x + 1, y = fromPos.y,     z = fromPos.z},
    {x = fromPos.x - 1, y = fromPos.y + 1, z = fromPos.z},
    {x = fromPos.x,     y = fromPos.y + 1, z = fromPos.z},
    {x = fromPos.x + 1, y = fromPos.y + 1, z = fromPos.z}
  }

  for _, candidate in ipairs(candidates) do
    local tile = g_map.getTile(candidate)
    if tileIsFree(tile) then
      local distThreat = math.max(math.abs(candidate.x - threatPos.x), math.abs(candidate.y - threatPos.y))
      local distWaypoint = 0

      if waypointPos and waypointPos.z == candidate.z then
        distWaypoint = math.max(math.abs(candidate.x - waypointPos.x), math.abs(candidate.y - waypointPos.y))
      end

      local score = (distThreat * 100) - distWaypoint
      if not bestScore or score > bestScore then
        bestScore = score
        bestPos = candidate
      end
    end
  end

  return bestPos
end

local function safeHealthPercent(creature)
  if creature and creature.getHealthPercent then
    local hp = creature:getHealthPercent()
    if hp and hp > 0 then
      return math.max(1, math.min(100, hp))
    end
  end
  return 100
end

local function getBestGroupRuneTarget(config)
  local playerPos = player:getPosition()
  local visible = g_map.getSpectatorsInRange(playerPos, false, 8, 8)
  local bestTarget = nil
  local bestCount = 0
  local bestScore = nil
  local minTargets = config.groupRuneAttackTargets or 2

  for _, candidate in ipairs(visible) do
    if candidate:isMonster() and not isBlockedAoEMob(candidate) then
      local center = candidate:getPosition()
      local around = g_map.getSpectatorsInRange(center, false, config.groupRuneAttackRadius or 1, config.groupRuneAttackRadius or 1)
      local playersAround = false
      local monsters = 0
      local missingHpScore = 0
      local lowHpCount = 0
      local lowestHp = 100

      for _, spec in ipairs(around) do
        if not spec:isLocalPlayer() and spec:isPlayer() and (not config.groupAttackIgnoreParty or spec:getShield() <= 2) then
          playersAround = true
        elseif spec:isMonster() and not isBlockedAoEMob(spec) then
          local hp = safeHealthPercent(spec)
          monsters = monsters + 1
          missingHpScore = missingHpScore + (100 - hp)
          if hp <= safeKillUnder() then
            lowHpCount = lowHpCount + 1
          end
          if hp < lowestHp then
            lowestHp = hp
          end
        end
      end

      -- Prefer packs already damaged, so lured low-HP mobs get finished
      -- instead of repeatedly runing a healthier pack with the same size.
      local score = (missingHpScore * 10) + (lowHpCount * 250) + (monsters * 100) - lowestHp

      if monsters >= minTargets and (not playersAround or config.groupAttackIgnorePlayers) and (not bestScore or score > bestScore) then
        bestScore = score
        bestCount = monsters
        bestTarget = candidate
      end
    end
  end

  return bestTarget, bestCount
end

TargetBot.Creature.attack = function(params, targets, isLooting, dangerLevel) -- params {config, creature, danger, priority}
  if player:isWalking() then
    lastWalk = now
  end

  local config = params.config
  local creature = params.creature

  -- Sempre deixa em stand mode antes de atacar; evita follow automatico do cliente.
  forceStandAttackMode()

  if g_game.getAttackingCreature() ~= creature then
    g_game.attack(creature)
  end

  local lureMovementPriority = false
  if isLooting then
    lureMovementPriority = TargetBot.isLureSafetyActive and TargetBot.isLureSafetyActive()
    if not lureMovementPriority
      and TargetBot.canLure
      and TargetBot.canLure()
      and isLureMovementConfig(config)
      and (targets or 0) > 0
      and creature:getHealthPercent() >= safeKillUnder() then
      lureMovementPriority = true
      markLureSafety(250)
    end
  end

  if not isLooting or lureMovementPriority then
    TargetBot.Creature.walk(creature, config, targets, dangerLevel or 0)
  end

  -- Magias ficam no holiday_aoe.lua; runa AOE de hunt fica aqui no TargetBot.
  if config.useGroupAttackRune and (config.groupAttackRune or 0) > 100 then
    local bestTarget, bestCount = getBestGroupRuneTarget(config)
    if bestTarget and bestCount >= (config.groupRuneAttackTargets or 2) then
      if TargetBot.useAttackItem(config.groupAttackRune, 0, bestTarget, config.groupRuneAttackDelay) then
        return
      end
    end
  end
end

TargetBot.Creature.walk = function(creature, config, targets, dangerLevel)
  local cpos = creature:getPosition()
  local pos = player:getPosition()
  local killUnder = safeKillUnder()

  local isTrapped = true
  local dirs = {{-1, 1}, {0, 1}, {1, 1}, {-1, 0}, {1, 0}, {-1, -1}, {0, -1}, {1, -1}}
  for i = 1, #dirs do
    local tile = g_map.getTile({x = pos.x - dirs[i][1], y = pos.y - dirs[i][2], z = pos.z})
    if tileIsFree(tile) then
      isTrapped = false
      break
    end
  end

  -- data for external dynamic lure
  if config.dynamicLure then
    local minLure = config.lureMin or 1
    local maxLure = config.lureMax or config.lureCount or 3
    if targets <= minLure then
      targetBotLure = true
    elseif targets >= maxLure then
      targetBotLure = false
    end
  else
    targetBotLure = false
  end

  targetCount = targets or 0
  delayValue = config.lureDelay or 250
  lureMax = config.lureMax or config.lureCount or 0
  dynamicLureDelay = config.dynamicLureDelay
  delayFrom = config.delayFrom

  -- Anti-trap preventivo: antes de ficar totalmente fechado, busca um tile mais aberto.
  -- Usa a mesma ideia do Reposition Better Tile, mas com contagem real de tiles livres.
  local antiTrapEnabled = config.antiTrap == true
  if antiTrapEnabled and creature:getHealthPercent() >= killUnder then
    local openTiles = getWalkableTilesCount(pos)
    local adjacentMonsters = countMonstersNear(pos, 1)
    local minOpenTiles = config.antiTrapMinOpenTiles or 2
    local trapMobs = config.antiTrapMobs or 3

    if openTiles <= minOpenTiles or adjacentMonsters >= trapMobs then
      markLureSafety(600)
      if rePosition(math.max(config.rePositionAmount or 5, minOpenTiles + 2)) then
        return
      end
    end
  end

  -- FIX PRINCIPAL: quando Dynamic lure + Lure using cavebot estiverem ligados,
  -- o TargetBot nao segura o boneco para finalizar mob; ele libera o CaveBot continuamente.
  -- O controle de velocidade fica por dynamicLureDelay/CaveBot.delay.
  if TargetBot.canLure() and config.dynamicLure and config.lureCavebot and caveBotIsOn() and not isTrapped then
    anchorPosition = nil
    markLureSafety(300)

    if config.lureKeepDistanceCavebot and dangerLevel <= (config.lureKeepDistanceMaxDanger or 6) then
      local nearestCreature, nearestPath, nearestDistance = getNearestEligibleMonster(config)
      local keepRange = config.keepDistanceRange or 2
      if nearestCreature and nearestPath and nearestDistance < keepRange then
        local retreatPos = chooseRetreatTile(pos, nearestCreature:getPosition(), getCurrentCaveBotGotoPos())
        if retreatPos then
          return TargetBot.walkTo(retreatPos, 1, {ignoreNonPathable = true, ignoreCreatures = false, precision = 0})
        end
      end
    end

    return TargetBot.allowCaveBot(250)
  end

  -- MAGE: manter distancia usando cavebot, sem travar a rota quando a distancia esta ok.
  if TargetBot.canLure()
    and config.lureKeepDistanceCavebot
    and not isTrapped
    and dangerLevel <= (config.lureKeepDistanceMaxDanger or 6) then

    local nearestCreature, nearestPath, nearestDistance = getNearestEligibleMonster(config)
    local keepRange = config.keepDistanceRange or 2
    markLureSafety(300)

    if nearestCreature and nearestPath and nearestDistance < 999 then
      if nearestDistance < keepRange then
        local retreatPos = chooseRetreatTile(pos, nearestCreature:getPosition(), getCurrentCaveBotGotoPos())
        if retreatPos then
          return TargetBot.walkTo(retreatPos, 1, {ignoreNonPathable = true, ignoreCreatures = false, precision = 0})
        end
      end
      return TargetBot.allowCaveBot(250)
    else
      return TargetBot.allowCaveBot(250)
    end
  end

  -- vBot 4.8 close lure
  if config.closeLure and (config.closeLureAmount or 0) <= getMonsters(1) then
    markLureSafety(250)
    return TargetBot.allowCaveBot(150)
  end

  -- luring classico/vBot
  if TargetBot.canLure() and (config.lure or config.lureCavebot or config.dynamicLure) and creature:getHealthPercent() >= killUnder and not isTrapped then
    markLureSafety(250)
    if targetBotLure then
      anchorPosition = nil
      return TargetBot.allowCaveBot(150)
    else
      if targets < (config.lureCount or 1) then
        if config.lureCavebot then
          anchorPosition = nil
          return TargetBot.allowCaveBot(150)
        else
          local path = findPath(pos, cpos, 5, {ignoreNonPathable = true, precision = 2})
          if path then
            return TargetBot.walkTo(cpos, 10, {marginMin = 5, marginMax = 6, ignoreNonPathable = true})
          end
        end
      end
    end
  end

  local currentDistance = findPath(pos, cpos, 10, {ignoreCreatures = true, ignoreNonPathable = true, ignoreCost = true})
  if not currentDistance then return end

  if (not config.chase or #currentDistance == 1) and not config.avoidAttacks and not config.keepDistance and config.rePosition and creature:getHealthPercent() >= killUnder then
    return rePosition(config.rePositionAmount or 6)
  end

  -- Follow controlado por botoes do target:
  -- Chase = persegue sempre; KillUnder Chase = persegue apenas abaixo do killUnder global.
  local killUnderChase = config.killUnderChase and killUnder > 1 and creature:getHealthPercent() < killUnder
  if (config.chase or killUnderChase) and not config.keepDistance then
    if #currentDistance > 1 then
      return TargetBot.walkTo(cpos, 10, {ignoreNonPathable = true, precision = 1})
    end
  elseif config.keepDistance then
    if not anchorPosition or distanceFromPlayer(anchorPosition) > (config.anchorRange or 3) then
      anchorPosition = pos
    end
    local desired = config.keepDistanceRange or 2
    if #currentDistance ~= desired and #currentDistance ~= desired + 1 then
      if config.anchor and anchorPosition and getDistanceBetween(pos, anchorPosition) <= (config.anchorRange or 3) * 2 then
        return TargetBot.walkTo(cpos, 10, {
          ignoreNonPathable = true,
          marginMin = desired,
          marginMax = desired + 1,
          maxDistanceFrom = {anchorPosition, config.anchorRange or 3}
        })
      else
        return TargetBot.walkTo(cpos, 10, {
          ignoreNonPathable = true,
          marginMin = desired,
          marginMax = desired + 1
        })
      end
    end
  end

  -- target only movement
  if config.avoidAttacks then
    local diffx = cpos.x - pos.x
    local diffy = cpos.y - pos.y
    local candidates = {}
    if math.abs(diffx) == 1 and diffy == 0 then
      candidates = {{x = pos.x, y = pos.y - 1, z = pos.z}, {x = pos.x, y = pos.y + 1, z = pos.z}}
    elseif diffx == 0 and math.abs(diffy) == 1 then
      candidates = {{x = pos.x - 1, y = pos.y, z = pos.z}, {x = pos.x + 1, y = pos.y, z = pos.z}}
    end
    for _, candidate in ipairs(candidates) do
      local tile = g_map.getTile(candidate)
      if tileIsFree(tile) then
        return TargetBot.walkTo(candidate, 2, {ignoreNonPathable = true})
      end
    end
  elseif config.faceMonster then
    local diffx = cpos.x - pos.x
    local diffy = cpos.y - pos.y
    local candidates = {}
    if diffx == 1 and diffy == 1 then
      candidates = {{x = pos.x + 1, y = pos.y, z = pos.z}, {x = pos.x, y = pos.y - 1, z = pos.z}}
    elseif diffx == -1 and diffy == 1 then
      candidates = {{x = pos.x - 1, y = pos.y, z = pos.z}, {x = pos.x, y = pos.y - 1, z = pos.z}}
    elseif diffx == -1 and diffy == -1 then
      candidates = {{x = pos.x, y = pos.y - 1, z = pos.z}, {x = pos.x - 1, y = pos.y, z = pos.z}}
    elseif diffx == 1 and diffy == -1 then
      candidates = {{x = pos.x, y = pos.y - 1, z = pos.z}, {x = pos.x + 1, y = pos.y, z = pos.z}}
    else
      local dir = player:getDirection()
      if diffx == 1 and dir ~= 1 then turn(1)
      elseif diffx == -1 and dir ~= 3 then turn(3)
      elseif diffy == 1 and dir ~= 2 then turn(2)
      elseif diffy == -1 and dir ~= 0 then turn(0)
      end
    end
    for _, candidate in ipairs(candidates) do
      local tile = g_map.getTile(candidate)
      if tileIsFree(tile) then
        return TargetBot.walkTo(candidate, 2, {ignoreNonPathable = true})
      end
    end
  end
end

onPlayerPositionChange(function(newPos, oldPos)
  if not CaveBot or CaveBot.isOff() then return end
  if not TargetBot or TargetBot.isOff() then return end
  if not lureMax or lureMax == 0 then return end
  if storage.TargetBotDelayWhenPlayer then return end
  if not dynamicLureDelay then return end

  if targetCount < (delayFrom or math.max(1, math.floor(lureMax / 2))) or not target() then return end
  if now < nextDynamicLureDelayAt then return end

  local ppos = player:getPosition()
  if getWalkableTilesCount(ppos) <= 2 or countMonstersNear(ppos, 1) >= 3 then
    -- Quando o cerco comeca, nao segura o CaveBot; deixar andar e reposicionar salva mais.
    markLureSafety(600)
    return
  end

  nextDynamicLureDelayAt = now + math.max(150, math.floor((delayValue or 0) / 2))
  markLureSafety(math.max(250, math.floor((delayValue or 0) / 2)))
  CaveBot.delay(delayValue or 0)
end)
