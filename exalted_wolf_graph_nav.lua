-- ============================================================
-- EXALTED WOLF GRAPH NAV
-- OTCv8 / vBot
--
-- Uses cavebot_configs/1Wolf.cfg as a map/graph, not as a fixed route.
-- Protocol:
--   EWOLFLOC|ID|CharName|x,y,z
--   EWOLFCLAIM|ID|LeaderName|a caminho|cost
--   EWOLFDONE|ID|LeaderName
--   EWOLFCANCEL|ID|reason
-- ============================================================

local EW_GRAPH_SCRIPT_VERSION = 2026061702
local EW_GRAPH_SCRIPT_NAME = "exalted_wolf_graph_nav.lua"
local EW_GRAPH_LOAD_KEY = "ExaltedWolfGraphNavLoaded_" .. tostring(configName or botConfigName or "default")
if _G and _G[EW_GRAPH_LOAD_KEY] == true then return end
if _G then _G[EW_GRAPH_LOAD_KEY] = true end

setDefaultTab("Tools")

local PANEL_NAME = "exalted_wolf_graph_nav"
storage[PANEL_NAME] = storage[PANEL_NAME] or {}
local settings = storage[PANEL_NAME]

local defaults = {
  enabled = true,
  detectorEnabled = true,
  leaderEnabled = true,
  debug = true,
  cfgPath = "cavebot_configs/1Wolf.cfg",
  leaders = storage.exaltedWolfLeaders or "Landin, Pipoko",
  nearLinkRange = 7,
  transitionCost = 35,
  useCost = 8,
  delayCostDivisor = 100,
  claimBaseDelay = 300,
  claimCostDelay = 50,
  claimMaxDelay = 5000,
  arrivalDistance = 1,
  finalArrivalDistance = 2,
  walkIntervalMs = 350,
  useIntervalMs = 900,
  transitionTimeoutMs = 4000,
  stuckRetryMs = 4500,
  stuckCancelMs = 18000,
  detectorCooldownMs = 12000,
  attackIntervalMs = 250,
  doneAfterLostMs = 7000,
  pauseCaveBot = true,
  iconItemId = 1953,
  updateUrl = "https://raw.githubusercontent.com/Thesaidctm/script-holidayys/main/exalted_wolf_graph_nav.lua",
  scriptPath = EW_GRAPH_SCRIPT_NAME,
  autoUpdateEnabled = false,
  autoUpdateIntervalMs = 600000,
  reloadAfterUpdate = true,
  installedVersion = EW_GRAPH_SCRIPT_VERSION
}

for key, value in pairs(defaults) do
  if settings[key] == nil then settings[key] = value end
end

local EW = {
  graph = nil,
  cfgLoaded = false,
  activeId = nil,
  destination = nil,
  plan = nil,
  steps = nil,
  stepIndex = 1,
  cost = 0,
  claimPending = false,
  claimAt = 0,
  claimed = false,
  pausedBots = false,
  lastWalkAt = 0,
  lastUseAt = 0,
  lastAttackAt = 0,
  lastSeenWolfAt = 0,
  attackedWolf = false,
  lastPosition = nil,
  lastPositionAt = 0,
  lastDetectorAt = 0,
  lastDetectorKey = "",
  lastDebugAt = 0
}

local function nowMs()
  if type(now) == "number" then return now end
  if type(now) == "function" then
    local ok, value = pcall(now)
    if ok and type(value) == "number" then return value end
  end
  if g_clock and g_clock.millis then return g_clock.millis() end
  return math.floor(os.clock() * 1000)
end

local function warnMessage(text)
  local msg = "[EW GRAPH] " .. tostring(text or "")
  if type(warn) == "function" then
    warn(msg)
  elseif type(print) == "function" then
    print(msg)
  end
end

local function debugMessage(text, throttleMs)
  if settings.debug ~= true then return end
  local tm = nowMs()
  throttleMs = throttleMs or 0
  if throttleMs > 0 and tm < EW.lastDebugAt + throttleMs then return end
  EW.lastDebugAt = tm
  warnMessage(text)
end

local function toNumber(value, fallback, minValue, maxValue)
  local n = tonumber(value)
  if n == nil then n = fallback end
  if minValue and n < minValue then n = minValue end
  if maxValue and n > maxValue then n = maxValue end
  return n
end

local function trim(text)
  text = tostring(text or ""):gsub("%s+", " ")
  return text:gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalize(text)
  return trim(text):lower()
end

local function posObject(p)
  if not p then return nil end
  if Position and Position.new then
    return Position.new(p.x, p.y, p.z)
  end
  return { x = p.x, y = p.y, z = p.z }
end

local function localPlayer()
  if player then return player end
  if g_game and g_game.getLocalPlayer then
    local ok, p = pcall(function() return g_game.getLocalPlayer() end)
    if ok then return p end
  end
  return nil
end

local function myName()
  local p = localPlayer()
  if p and p.getName then
    local ok, name = pcall(function() return p:getName() end)
    if ok and name then return tostring(name) end
  end
  return "unknown"
end

local function myPosition()
  if type(pos) == "function" then
    local ok, p = pcall(pos)
    if ok and p then return { x = p.x, y = p.y, z = p.z } end
  end

  local p = localPlayer()
  if p and p.getPosition then
    local ok, v = pcall(function() return p:getPosition() end)
    if ok and v then return { x = v.x, y = v.y, z = v.z } end
  end

  return nil
end

local function distance(a, b)
  if not a or not b then return 999999 end
  if a.z ~= b.z then return 999999 end
  return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y))
end

local function distanceAnyZ(a, b)
  if not a or not b then return 999999 end
  return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y)) + math.abs((a.z or 0) - (b.z or 0)) * 40
end

local function safeSpectators()
  if type(getSpectators) == "function" then
    local ok, specs = pcall(getSpectators)
    if ok and type(specs) == "table" then return specs end
  end

  if g_map and g_map.getSpectators then
    local ok, specs = pcall(function() return g_map.getSpectators(posObject(myPosition()), false) end)
    if ok and type(specs) == "table" then return specs end
  end

  if g_game and g_game.getSpectators then
    local ok, specs = pcall(function() return g_game.getSpectators() end)
    if ok and type(specs) == "table" then return specs end
  end

  return {}
end

local function creatureName(creature)
  if not creature or not creature.getName then return "" end
  local ok, name = pcall(function() return creature:getName() end)
  if ok and name then return tostring(name) end
  return ""
end

local function creaturePosition(creature)
  if not creature or not creature.getPosition then return nil end
  local ok, p = pcall(function() return creature:getPosition() end)
  if ok and p then return { x = p.x, y = p.y, z = p.z } end
  return nil
end

local function isMonster(creature)
  if not creature then return false end
  if creature.isMonster then
    local ok, value = pcall(function() return creature:isMonster() end)
    if ok then return value == true end
  end
  if creature.isPlayer then
    local ok, value = pcall(function() return creature:isPlayer() end)
    if ok and value == true then return false end
  end
  return creatureName(creature) ~= ""
end

local function isExaltedWolf(creature)
  return isMonster(creature) and normalize(creatureName(creature)):find("exalted wolf", 1, true) ~= nil
end

local function findExaltedWolf()
  for _, creature in ipairs(safeSpectators()) do
    if isExaltedWolf(creature) then
      return creature
    end
  end
  return nil
end

local function parseLeaders()
  local leaders = {}
  local text = tostring(settings.leaders or "")
  for name in text:gmatch("([^,;]+)") do
    name = trim(name)
    if name ~= "" then leaders[name:lower()] = true end
  end
  return leaders
end

local function isLeader()
  if settings.leaderEnabled ~= true then return false end
  return parseLeaders()[myName():lower()] == true
end

local function sendGuild(text)
  text = tostring(text or "")
  if text == "" then return false end

  if type(guildsay) == "function" then
    local ok = pcall(function() guildsay(text) end)
    if ok then return true end
  end

  if g_game and g_game.talkChannel and TalkTypes then
    local talkType = TalkTypes.ChannelYellow or TalkTypes.ChannelOrange or 7
    local ok = pcall(function() g_game.talkChannel(talkType, 0, text) end)
    if ok then return true end
  end

  if type(say) == "function" then
    local ok = pcall(function() say(text) end)
    if ok then return true end
  end

  return false
end

local function setBotOff(bot)
  if not bot then return false end
  if bot.setOff then
    local ok = pcall(function() bot.setOff() end)
    if ok then return true end
  end
  if bot.disable then
    local ok = pcall(function() bot.disable() end)
    if ok then return true end
  end
  return false
end

local function setBotOn(bot)
  if not bot then return false end
  if bot.setOn then
    local ok = pcall(function() bot.setOn() end)
    if ok then return true end
  end
  if bot.enable then
    local ok = pcall(function() bot.enable() end)
    if ok then return true end
  end
  return false
end

local function pauseBots()
  if EW.pausedBots then return end
  setBotOff(TargetBot)
  if settings.pauseCaveBot == true then setBotOff(CaveBot) end
  EW.pausedBots = true
  debugMessage("TargetBot pausado para navegar ate o Exalted Wolf.")
end

local function restoreBots()
  if not EW.pausedBots then return end
  setBotOn(TargetBot)
  if settings.pauseCaveBot == true then setBotOn(CaveBot) end
  EW.pausedBots = false
end

local function resetState(reason, keepBotsOff)
  EW.activeId = nil
  EW.destination = nil
  EW.plan = nil
  EW.steps = nil
  EW.stepIndex = 1
  EW.cost = 0
  EW.claimPending = false
  EW.claimAt = 0
  EW.claimed = false
  EW.lastWalkAt = 0
  EW.lastUseAt = 0
  EW.lastAttackAt = 0
  EW.lastSeenWolfAt = 0
  EW.attackedWolf = false
  EW.lastPosition = nil
  EW.lastPositionAt = 0
  if keepBotsOff ~= true then restoreBots() end
  if reason then warnMessage("Reset: " .. tostring(reason)) end
end

local function readFile(path)
  if type(io) ~= "table" or type(io.open) ~= "function" then return nil end
  local f = io.open(path, "r")
  if not f then return nil end
  local data = f:read("*a")
  f:close()
  return data
end

local function writeFile(path, data)
  if not path or path == "" or type(data) ~= "string" then return false end

  if type(g_resources) == "table" and type(g_resources.writeFileContents) == "function" then
    local ok = pcall(function() g_resources.writeFileContents(path, data) end)
    if ok then return true end
  end

  if type(io) == "table" and type(io.open) == "function" then
    local f = io.open(path, "w")
    if f then
      f:write(data)
      f:close()
      return true
    end
  end

  return false
end

local function looksLikeUrl(value)
  return type(value) == "string" and value:lower():find("^https?://") ~= nil
end

local function normalizeHttpResponse(a, b, c)
  local values = { a, b, c }

  for _, value in ipairs(values) do
    if type(value) == "string" and #value > 0 and not looksLikeUrl(value) then
      return value, nil
    end
  end

  for _, value in ipairs(values) do
    if type(value) == "table" then
      if type(value.body) == "string" then return value.body, nil end
      if type(value.data) == "string" then return value.data, nil end
      if type(value.response) == "string" then return value.response, nil end
    end
  end

  for _, value in ipairs(values) do
    if type(value) == "string" and #value > 0 then return value, nil end
  end

  return nil, tostring(b or c or a or "sem resposta HTTP")
end

local function httpGet(url, callback)
  local called = false
  local function done(data, err)
    if called then return end
    called = true
    callback(data, err)
  end

  local httpCandidates = {}
  if type(HTTP) == "table" then table.insert(httpCandidates, HTTP) end
  if type(g_http) == "table" then table.insert(httpCandidates, g_http) end
  if modules and modules.corelib and type(modules.corelib.HTTP) == "table" then table.insert(httpCandidates, modules.corelib.HTTP) end
  if modules and modules._G and type(modules._G.HTTP) == "table" then table.insert(httpCandidates, modules._G.HTTP) end

  for _, http in ipairs(httpCandidates) do
    if type(http) == "table" and type(http.get) == "function" then
      local ok = pcall(function()
        local response = http.get(url, function(a, b, c)
          local data, err = normalizeHttpResponse(a, b, c)
          done(data, err)
        end)
        if type(response) == "string" then done(response, nil) end
      end)
      if ok then return true end
    end
  end

  done(nil, "HTTP.get/g_http.get indisponivel")
  return false
end

local function remoteUrlWithCacheBuster()
  local url = trim(settings.updateUrl)
  if url == "" then return "" end
  local sep = url:find("?", 1, true) and "&" or "?"
  return url .. sep .. "v=" .. tostring(nowMs())
end

local function downloadedScriptVersion(source)
  local version = tostring(source or ""):match("EW_GRAPH_SCRIPT_VERSION%s*=%s*(%d+)")
  return tonumber(version) or 0
end

local function validateDownloadedScript(source)
  if type(source) ~= "string" or #source < 1000 then
    return false, "resposta muito pequena"
  end

  local lower = source:sub(1, 300):lower()
  if lower:find("<!doctype", 1, true) or lower:find("<html", 1, true) then
    return false, "GitHub retornou HTML, nao Lua"
  end

  if not source:find("EXALTED WOLF GRAPH NAV", 1, true) then
    return false, "assinatura do script nao encontrada"
  end

  if not source:find("EWGraphNav", 1, true) then
    return false, "API EWGraphNav nao encontrada"
  end

  return true, nil
end

local updateBusy = false
local function runScriptUpdate(force)
  if updateBusy then
    warnMessage("Atualizacao ja esta em andamento.")
    return false
  end

  local url = remoteUrlWithCacheBuster()
  if url == "" then
    warnMessage("Configure a URL raw do GitHub em updateUrl.")
    return false
  end

  updateBusy = true
  warnMessage("Buscando update no GitHub...")

  httpGet(url, function(data, err)
    updateBusy = false

    if err or not data or data == "" then
      warnMessage("Falha no update: " .. tostring(err or "resposta vazia"))
      return
    end

    local ok, validationErr = validateDownloadedScript(data)
    if not ok then
      warnMessage("Update recusado: " .. tostring(validationErr))
      return
    end

    local remoteVersion = downloadedScriptVersion(data)
    settings.lastRemoteVersion = remoteVersion

    if force ~= true and remoteVersion > 0 and remoteVersion <= EW_GRAPH_SCRIPT_VERSION then
      settings.lastUpdateCheckAt = nowMs()
      warnMessage("Script ja esta atualizado. Remoto=" .. tostring(remoteVersion))
      return
    end

    local path = trim(settings.scriptPath)
    if path == "" then path = EW_GRAPH_SCRIPT_NAME end

    if not writeFile(path, data) then
      warnMessage("Nao consegui gravar update em " .. path .. ". Ajuste scriptPath.")
      return
    end

    settings.installedVersion = remoteVersion > 0 and remoteVersion or EW_GRAPH_SCRIPT_VERSION
    settings.lastUpdateCheckAt = nowMs()
    warnMessage("Update gravado em " .. path .. ". Versao=" .. tostring(settings.installedVersion))

    if settings.reloadAfterUpdate == true and type(reload) == "function" then
      if type(schedule) == "function" then
        schedule(800, function() reload() end)
      else
        reload()
      end
    else
      warnMessage("Recarregue o perfil para usar a nova versao.")
    end
  end)

  return true
end

local function maybeRunAutoUpdate()
  if settings.autoUpdateEnabled ~= true then return end
  local interval = toNumber(settings.autoUpdateIntervalMs, 600000, 60000, 86400000)
  local tm = nowMs()
  if tonumber(settings.nextAutoUpdateAt) and tm < tonumber(settings.nextAutoUpdateAt) then return end
  settings.nextAutoUpdateAt = tm + interval
  runScriptUpdate(false)
end

local EMBEDDED_1WOLF_CFG = [====[
goto:54725,54801,7
goto:54720,54806,7,0
goto:54714,54805,6
goto:54708,54804,6
goto:54702,54802,6
goto:54696,54801,6
goto:54694,54796,6,0
delay:50
goto:54694,54796,7,0
goto:54692,54802,6
goto:54692,54802,6,0
goto:54689,54808,5
goto:54689,54808,5,0
goto:54690,54813,4,0
goto:54693,54813,5,0
goto:54699,54818,6
goto:54705,54817,6
goto:54711,54813,6
goto:54715,54807,6
goto:54709,54804,6
goto:54703,54802,6
goto:54700,54803,6,0
goto:54699,54803,7,0
goto:54705,54803,6
goto:54711,54804,6
goto:54717,54804,6
goto:54720,54806,6,0
goto:54726,54806,7
goto:54732,54805,7
goto:54738,54804,7
goto:54744,54804,7
goto:54750,54804,7
goto:54756,54802,7
goto:54762,54802,7
goto:54768,54803,7
goto:54774,54802,7
goto:54774,54796,7
goto:54775,54790,7
goto:54774,54784,7
goto:54771,54778,7
goto:54771,54772,7
goto:54777,54768,7
goto:54783,54769,7
goto:54788,54775,7
goto:54784,54779,7,0
goto:54782,54779,6
goto:54784,54779,6,0
goto:54788,54773,7
goto:54788,54767,7
goto:54793,54761,7
goto:54794,54755,7
goto:54794,54753,7,0
goto:54794,54751,6
goto:54794,54753,6,0
goto:54794,54759,7
goto:54792,54765,7
goto:54791,54771,7
goto:54792,54777,7
goto:54798,54775,7
goto:54799,54774,7,0
goto:54800,54771,6
goto:54799,54774,6,0
goto:54805,54776,7
goto:54811,54775,7
goto:54817,54774,7
goto:54817,54771,7,0
goto:54816,54766,6
goto:54817,54771,6,0
goto:54823,54771,7
goto:54829,54769,7
goto:54829,54775,7
goto:54825,54781,7
goto:54819,54782,7
goto:54813,54783,7
goto:54809,54789,7
goto:54803,54786,7
goto:54799,54786,7,0
goto:54793,54789,6
goto:54799,54788,6
goto:54799,54786,6,0
goto:54805,54791,7
goto:54807,54797,7
goto:54813,54800,7
goto:54819,54800,7
goto:54823,54794,7
goto:54823,54793,7,0
goto:54818,54790,6,0
goto:54818,54790,5,0
goto:54823,54793,6,0
goto:54824,54799,7
goto:54818,54800,7
goto:54812,54800,7
goto:54806,54803,7
goto:54800,54803,7
goto:54794,54802,7
goto:54789,54808,7
goto:54795,54813,7
goto:54801,54815,7
goto:54806,54821,7
goto:54805,54827,7
goto:54799,54830,7
goto:54793,54830,7
goto:54787,54829,7
goto:54785,54827,7,0
goto:54785,54821,6
goto:54782,54815,6
delay:100
use:54780,54811,6
delay:100
use:54780,54811,6
goto:54780,54812,6,0
use:54783,54811,5
goto:54782,54812,5,0
goto:54783,54811,4,0
goto:54780,54811,5,0
goto:54782,54817,6
delay:100
goto:54784,54823,6
goto:54785,54827,6,0
goto:54791,54832,7
goto:54793,54838,7
goto:54791,54842,7,0
goto:54785,54840,6
goto:54782,54843,6,0
goto:54778,54844,5,0
goto:54777,54843,4,0
goto:54777,54843,3,0
goto:54778,54844,4,0
goto:54782,54843,5,0
goto:54788,54841,6
goto:54791,54842,6,0
goto:54795,54848,7
goto:54801,54850,7
goto:54806,54847,7,0
goto:54812,54850,6
goto:54814,54855,6,0
goto:54820,54860,7
goto:54814,54858,7
goto:54814,54855,7,0
goto:54809,54849,6
goto:54806,54847,6,0
goto:54800,54847,7
goto:54798,54853,7
goto:54798,54859,7
goto:54798,54865,7
goto:54794,54866,7,0
goto:54788,54865,6
goto:54794,54866,6
goto:54794,54866,6,0
goto:54798,54872,7
goto:54798,54878,7
goto:54792,54875,7
goto:54786,54875,7
goto:54780,54875,7
goto:54774,54876,7
goto:54768,54879,7
goto:54767,54885,7
goto:54762,54891,7
goto:54756,54892,7
goto:54750,54896,7
goto:54744,54898,7
goto:54739,54904,7
goto:54735,54910,7
goto:54729,54914,7
goto:54728,54920,7
goto:54734,54925,7
goto:54734,54919,7
goto:54730,54913,7
goto:54724,54912,7
goto:54718,54914,7
goto:54712,54919,7
goto:54706,54919,7
goto:54705,54925,7
goto:54704,54919,7
goto:54705,54913,7
goto:54705,54907,7
goto:54702,54901,7
goto:54696,54897,7
goto:54690,54896,7
goto:54684,54895,7
goto:54678,54892,7
goto:54672,54887,7
goto:54671,54881,7
goto:54665,54877,7
goto:54663,54879,7,0
goto:54662,54885,6
goto:54656,54889,6
goto:54654,54890,6,0
delay:50
goto:54654,54890,5,0
goto:54660,54888,6
goto:54662,54882,6
goto:54663,54879,6,0
goto:54657,54875,7
goto:54653,54869,7
goto:54647,54869,7
goto:54641,54871,7
goto:54635,54870,7
goto:54629,54870,7
goto:54635,54870,7
goto:54641,54871,7
goto:54647,54870,7
goto:54653,54869,7
goto:54658,54863,7
goto:54664,54863,7
goto:54663,54857,7
goto:54659,54851,7
goto:54665,54852,7
goto:54671,54848,7
goto:54673,54842,7
goto:54678,54848,7
goto:54680,54854,7
goto:54686,54854,7
goto:54692,54855,7
goto:54694,54849,7
goto:54694,54847,7,0
goto:54700,54845,6
goto:54706,54845,6
goto:54712,54844,6
goto:54714,54844,6,0
goto:54715,54850,7
goto:54709,54851,7
goto:54715,54848,7
goto:54721,54848,7
goto:54722,54842,7
goto:54723,54836,7
goto:54718,54830,7
goto:54720,54824,7
goto:54721,54818,7
goto:54725,54812,7
goto:54725,54806,7
goto:54725,54800,7
goto:54725,54799,7,0
goto:54725,54796,6,0
goto:54725,54790,7
goto:54724,54784,7
goto:54730,54781,7
goto:54736,54781,7
goto:54741,54787,7
goto:54736,54781,7
goto:54730,54780,7
goto:54724,54781,7
goto:54718,54781,7
goto:54712,54781,7
goto:54706,54780,7
goto:54700,54775,7
goto:54695,54771,7
delay:50
use:54696,54771,7
use:54695,54771,7
goto:54696,54771,7,0
goto:54695,54771,6,0
goto:54701,54774,7
goto:54707,54779,7
goto:54713,54779,7
goto:54719,54781,7
goto:54724,54787,7
goto:54725,54793,7
goto:54725,54796,7,0
goto:54725,54799,6,0
goto:54720,54848,7
goto:54718,54854,7
goto:54718,54860,7
goto:54717,54866,7
goto:54718,54872,7
goto:54716,54878,7
goto:54722,54882,7
goto:54728,54882,7
goto:54734,54883,7
goto:54734,54877,7
goto:54733,54871,7
goto:54733,54865,7
goto:54734,54859,7
goto:54738,54853,7
goto:54744,54847,7
goto:54750,54842,7
goto:54756,54842,7
goto:54759,54844,7,0
goto:54757,54850,6
goto:54751,54856,6
goto:54750,54855,6,0
goto:54750,54855,5,0
goto:54756,54853,6
goto:54758,54847,6
goto:54759,54844,6,0
goto:54761,54838,7
goto:54761,54832,7
goto:54767,54826,7
goto:54767,54825,7,0
goto:54762,54822,6,0
goto:54762,54822,5,0
goto:54767,54825,6,0
goto:54770,54819,7
goto:54764,54816,7
goto:54758,54816,7
goto:54752,54817,7
goto:54746,54823,7
goto:54741,54829,7
goto:54735,54832,7
goto:54730,54838,7
goto:54724,54843,7
goto:54718,54843,7
goto:54718,54849,7
goto:54717,54855,7
goto:54711,54858,7
goto:54705,54861,7
goto:54699,54863,7
goto:54695,54869,7
goto:54690,54863,7
goto:54689,54857,7
goto:54692,54851,7
goto:54698,54850,7
goto:54704,54850,7
goto:54710,54852,7
goto:54716,54850,7
goto:54722,54844,7
goto:54722,54838,7
]====]

local function cfgPathCandidates()
  local path = tostring(settings.cfgPath or "cavebot_configs/1Wolf.cfg")
  local candidates = { path }

  if path:sub(1, 2) ~= "./" then
    table.insert(candidates, "./" .. path)
  end

  if path:sub(1, 1) ~= "/" and not path:match("^%a:[/\\]") then
    local profileNames = {}
    local function addProfileName(value)
      value = trim(value)
      if value ~= "" and not profileNames[value] then
        profileNames[value] = true
        table.insert(candidates, "../" .. value .. "/" .. path)
        table.insert(candidates, "bot/" .. value .. "/" .. path)
        table.insert(candidates, "Holiday/bot/" .. value .. "/" .. path)
      end
    end

    addProfileName(configName)
    addProfileName(botConfigName)
    addProfileName("MAGE_MAKERF")
  end

  return candidates
end

local function parseCfg(text)
  local entries = {}
  if type(text) ~= "string" then return entries end

  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    line = line:gsub("\r", "")
    line = line:match("^%s*(.-)%s*$")

    if line:sub(1, 5) == "goto:" then
      local x, y, z, flag = line:sub(6):match("^(%-?%d+),(%-?%d+),(%-?%d+),?(%-?%d*)$")
      if x then
        local transition = flag == "0"
        table.insert(entries, {
          type = "goto",
          x = tonumber(x),
          y = tonumber(y),
          z = tonumber(z),
          transition = transition,
          precision = transition and 0 or 1
        })
      end
    elseif line:sub(1, 4) == "use:" then
      local x, y, z = line:sub(5):match("^(%-?%d+),(%-?%d+),(%-?%d+)$")
      if x then
        table.insert(entries, { type = "use", x = tonumber(x), y = tonumber(y), z = tonumber(z) })
      end
    elseif line:sub(1, 6) == "delay:" then
      local ms = tonumber(line:sub(7):match("^(%d+)$"))
      if ms then table.insert(entries, { type = "delay", ms = ms }) end
    end
  end

  return entries
end

local function cloneActions(actions)
  local out = {}
  for _, action in ipairs(actions or {}) do
    local copy = {}
    for k, v in pairs(action) do copy[k] = v end
    table.insert(out, copy)
  end
  return out
end

local function actionCost(actions)
  local cost = 0
  for _, action in ipairs(actions or {}) do
    if action.type == "use" then
      cost = cost + toNumber(settings.useCost, 8, 0, 100)
    elseif action.type == "delay" then
      cost = cost + math.ceil((tonumber(action.ms) or 0) / toNumber(settings.delayCostDivisor, 100, 1, 1000))
    end
  end
  return cost
end

local function edgeKey(a, b)
  return tostring(a) .. ">" .. tostring(b)
end

local function addEdge(graph, fromId, toId, special, actions)
  if not fromId or not toId or fromId == toId then return end
  graph.edgeByKey = graph.edgeByKey or {}
  if graph.edgeByKey[edgeKey(fromId, toId)] then return end

  local a = graph.nodes[fromId]
  local b = graph.nodes[toId]
  if not a or not b then return end

  local dist = distanceAnyZ(a, b)
  local cost = dist + actionCost(actions)
  if special == "transition" then
    cost = cost + toNumber(settings.transitionCost, 35, 0, 500)
  end

  local edge = {
    from = fromId,
    to = toId,
    cost = cost,
    transition = special == "transition",
    nearby = special == "nearby",
    actions = cloneActions(actions)
  }

  graph.edges[fromId] = graph.edges[fromId] or {}
  table.insert(graph.edges[fromId], edge)
  graph.edgeByKey[edgeKey(fromId, toId)] = edge
end

local function buildGraph(entries)
  local graph = { nodes = {}, edges = {}, edgeByKey = {} }
  local lastNode = nil
  local pendingActions = {}

  for index, entry in ipairs(entries) do
    if entry.type == "goto" then
      local id = #graph.nodes + 1
      local node = {
        id = id,
        x = entry.x,
        y = entry.y,
        z = entry.z,
        transition = entry.transition == true,
        precision = entry.precision or 1,
        entryIndex = index
      }
      graph.nodes[id] = node
      graph.edges[id] = graph.edges[id] or {}

      if lastNode then
        if lastNode.z == node.z then
          addEdge(graph, lastNode.id, node.id, "normal", pendingActions)
          addEdge(graph, node.id, lastNode.id, "normal", pendingActions)
        elseif lastNode.transition == true then
          addEdge(graph, lastNode.id, node.id, "transition", pendingActions)
          if node.transition == true then
            addEdge(graph, node.id, lastNode.id, "transition", pendingActions)
          end
        elseif node.transition == true then
          addEdge(graph, node.id, lastNode.id, "transition", pendingActions)
        end
      end

      lastNode = node
      pendingActions = {}
    elseif entry.type == "use" or entry.type == "delay" then
      table.insert(pendingActions, entry)
    end
  end

  local range = toNumber(settings.nearLinkRange, 7, 0, 20)
  if range > 0 then
    for i = 1, #graph.nodes do
      for j = i + 1, #graph.nodes do
        local a = graph.nodes[i]
        local b = graph.nodes[j]
        if a.z == b.z and distance(a, b) <= range then
          addEdge(graph, i, j, "nearby", nil)
          addEdge(graph, j, i, "nearby", nil)
        end
      end
    end
  end

  return graph
end

local function loadCfg()
  local attempted = {}
  local loadedPath = nil
  local text = nil

  for _, path in ipairs(cfgPathCandidates()) do
    if path and path ~= "" and not attempted[path] then
      attempted[path] = true
      text = readFile(path)
      if text then
        loadedPath = path
        break
      end
    end
  end

  if not text then
    text = EMBEDDED_1WOLF_CFG
    loadedPath = "embedded://1Wolf.cfg"
  end

  local entries = parseCfg(text)
  if #entries == 0 then
    EW.cfgLoaded = false
    warnMessage("CFG sem entradas validas: " .. tostring(loadedPath))
    return false
  end

  EW.graph = buildGraph(entries)
  EW.cfgLoaded = true
  warnMessage("CFG carregado: " .. tostring(#entries) .. " entradas, " .. tostring(#EW.graph.nodes) .. " nodes. Path=" .. tostring(loadedPath))
  return true
end

local function nearestNode(graph, p)
  if not graph or not p then return nil, 999999 end
  local bestId = nil
  local bestCost = 999999

  for _, node in ipairs(graph.nodes) do
    if node.z == p.z then
      local d = distance(node, p)
      if d < bestCost then
        bestCost = d
        bestId = node.id
      end
    end
  end

  return bestId, bestCost
end

local function dijkstra(graph, startId, goalId)
  if not graph or not startId or not goalId then return nil, 999999 end

  local dist = {}
  local prev = {}
  local used = {}

  for _, node in ipairs(graph.nodes) do
    dist[node.id] = 999999999
  end
  dist[startId] = 0

  while true do
    local current = nil
    local currentDist = 999999999

    for _, node in ipairs(graph.nodes) do
      local id = node.id
      if not used[id] and dist[id] < currentDist then
        current = id
        currentDist = dist[id]
      end
    end

    if not current then break end
    if current == goalId then break end
    used[current] = true

    for _, edge in ipairs(graph.edges[current] or {}) do
      local nextId = edge.to
      local alt = dist[current] + edge.cost
      if alt < dist[nextId] then
        dist[nextId] = alt
        prev[nextId] = current
      end
    end
  end

  if dist[goalId] >= 999999999 then return nil, 999999 end

  local path = {}
  local id = goalId
  while id do
    table.insert(path, 1, id)
    if id == startId then break end
    id = prev[id]
  end

  if path[1] ~= startId then return nil, 999999 end
  return path, dist[goalId]
end

local function findEdge(graph, fromId, toId)
  if not graph then return nil end
  return graph.edgeByKey and graph.edgeByKey[edgeKey(fromId, toId)] or nil
end

local function sameStep(a, b)
  return a and b and a.type == b.type and a.x == b.x and a.y == b.y and a.z == b.z
end

local function addStep(steps, step)
  if not step then return end
  if sameStep(steps[#steps], step) then return end
  table.insert(steps, step)
end

local function addActionSteps(steps, actions)
  for _, action in ipairs(actions or {}) do
    if action.type == "use" then
      addStep(steps, { type = "use", x = action.x, y = action.y, z = action.z })
    elseif action.type == "delay" then
      addStep(steps, { type = "delay", ms = action.ms })
    end
  end
end

local function makeSteps(graph, path, destination)
  local steps = {}
  if not path or #path == 0 then return steps end

  local first = graph.nodes[path[1]]
  addStep(steps, { type = "goto", x = first.x, y = first.y, z = first.z, precision = first.precision or 1 })

  for i = 1, #path - 1 do
    local fromNode = graph.nodes[path[i]]
    local toNode = graph.nodes[path[i + 1]]
    local edge = findEdge(graph, fromNode.id, toNode.id)

    if edge and edge.transition then
      addStep(steps, { type = "goto", x = fromNode.x, y = fromNode.y, z = fromNode.z, precision = 0 })
      addActionSteps(steps, edge.actions)
      addStep(steps, { type = "waitZ", x = fromNode.x, y = fromNode.y, z = fromNode.z, targetZ = toNode.z })
      addStep(steps, { type = "goto", x = toNode.x, y = toNode.y, z = toNode.z, precision = toNode.precision or 1 })
    else
      if edge then addActionSteps(steps, edge.actions) end
      addStep(steps, { type = "goto", x = toNode.x, y = toNode.y, z = toNode.z, precision = toNode.precision or 1 })
    end
  end

  addStep(steps, { type = "final", x = destination.x, y = destination.y, z = destination.z, precision = toNumber(settings.finalArrivalDistance, 2, 0, 8) })
  return steps
end

local function planPath(destination)
  if not EW.cfgLoaded or not EW.graph then
    if not loadCfg() then return nil end
  end

  local current = myPosition()
  if not current or not destination then return nil end

  local startId, startDist = nearestNode(EW.graph, current)
  local goalId, goalDist = nearestNode(EW.graph, destination)
  if not startId or not goalId then return nil end

  local path, graphCost = dijkstra(EW.graph, startId, goalId)
  if not path then return nil end

  local totalCost = graphCost + startDist + goalDist
  local steps = makeSteps(EW.graph, path, destination)

  return {
    startId = startId,
    goalId = goalId,
    path = path,
    steps = steps,
    cost = totalCost,
    startDist = startDist,
    goalDist = goalDist
  }
end

local function autoWalkTo(target, precision)
  local tm = nowMs()
  if tm < EW.lastWalkAt + toNumber(settings.walkIntervalMs, 350, 100, 2000) then return true end
  EW.lastWalkAt = tm

  precision = precision or 1
  local p = posObject(target)

  if g_game and g_game.autoWalk then
    local ok = pcall(function() g_game.autoWalk(p, 100, { precision = precision }) end)
    if ok then return true end
  end

  if type(autoWalk) == "function" then
    local ok = pcall(function() autoWalk(p, precision) end)
    if ok then return true end
  end

  return false
end

local function tileAt(p)
  if not p or not g_map or not g_map.getTile then return nil end
  local ok, tile = pcall(function() return g_map.getTile(posObject(p)) end)
  if ok then return tile end
  return nil
end

local function tileThings(tile)
  if not tile then return {} end
  if tile.getItems then
    local ok, items = pcall(function() return tile:getItems() end)
    if ok and type(items) == "table" and #items > 0 then return items end
  end
  if tile.getThings then
    local ok, things = pcall(function() return tile:getThings() end)
    if ok and type(things) == "table" and #things > 0 then return things end
  end
  if tile.getTopThing then
    local ok, thing = pcall(function() return tile:getTopThing() end)
    if ok and thing then return { thing } end
  end
  return {}
end

local function useThing(thing)
  if not thing then return false end
  if g_game and g_game.use then
    local ok = pcall(function() g_game.use(thing) end)
    if ok then return true end
  end
  if type(use) == "function" then
    local ok = pcall(function() use(thing) end)
    if ok then return true end
  end
  return false
end

local function useAtPosition(p)
  local tm = nowMs()
  if tm < EW.lastUseAt + toNumber(settings.useIntervalMs, 900, 100, 4000) then return true end
  EW.lastUseAt = tm

  local tile = tileAt(p)
  for _, thing in ipairs(tileThings(tile)) do
    if useThing(thing) then return true end
  end

  return false
end

local function attackWolfIfVisible()
  local wolf = findExaltedWolf()
  if not wolf then return false end

  EW.lastSeenWolfAt = nowMs()
  EW.attackedWolf = true
  pauseBots()

  if nowMs() >= EW.lastAttackAt + toNumber(settings.attackIntervalMs, 250, 50, 2000) then
    EW.lastAttackAt = nowMs()
    if g_game and g_game.attack then
      pcall(function() g_game.attack(wolf) end)
    elseif type(attack) == "function" then
      pcall(function() attack(wolf) end)
    end
  end

  return true
end

local function checkStuck()
  local p = myPosition()
  if not p then return false end

  local tm = nowMs()
  if not EW.lastPosition then
    EW.lastPosition = p
    EW.lastPositionAt = tm
    return false
  end

  local same = p.x == EW.lastPosition.x and p.y == EW.lastPosition.y and p.z == EW.lastPosition.z
  if not same then
    EW.lastPosition = p
    EW.lastPositionAt = tm
    return false
  end

  local stuckFor = tm - EW.lastPositionAt
  if stuckFor >= toNumber(settings.stuckCancelMs, 18000, 5000, 60000) then
    sendGuild("EWOLFCANCEL|" .. tostring(EW.activeId or "?") .. "|stuck")
    resetState("travado tempo demais")
    return true
  end

  return false
end

local function executeCurrentStep()
  if not EW.steps or not EW.steps[EW.stepIndex] then return "done" end

  local step = EW.steps[EW.stepIndex]
  local p = myPosition()
  if not p then return "wait" end

  if step.type == "delay" then
    step.untilTime = step.untilTime or (nowMs() + (tonumber(step.ms) or 0))
    if nowMs() >= step.untilTime then return "advance" end
    return "wait"
  end

  if step.type == "use" then
    if p.z ~= step.z then return "advance" end
    if distance(p, step) > 1 then
      autoWalkTo(step, 1)
      return "wait"
    end
    useAtPosition(step)
    return "advance"
  end

  if step.type == "waitZ" then
    if p.z == step.targetZ then
      EW.lastPosition = nil
      return "advance"
    end

    if distance(p, step) > 0 then
      autoWalkTo(step, 0)
      return "wait"
    end

    if nowMs() >= (step.startedAt or 0) + toNumber(settings.transitionTimeoutMs, 4000, 500, 20000) then
      step.startedAt = nowMs()
      useAtPosition(step)
      autoWalkTo(step, 0)
    else
      step.startedAt = step.startedAt or nowMs()
    end

    return "wait"
  end

  if step.type == "goto" or step.type == "final" then
    if p.z ~= step.z then
      debugMessage("Step em z=" .. tostring(step.z) .. ", estou em z=" .. tostring(p.z) .. ". Aguardando transicao.", 1500)
      return "wait"
    end

    local precision = tonumber(step.precision) or (step.type == "final" and toNumber(settings.finalArrivalDistance, 2, 0, 8) or 1)
    local d = distance(p, step)
    if d <= precision then
      return "advance"
    end

    autoWalkTo(step, precision)
    return "wait"
  end

  return "advance"
end

local function acceptPlan(id, destination, plan)
  EW.activeId = id
  EW.destination = destination
  EW.plan = plan
  EW.steps = plan.steps
  EW.stepIndex = 1
  EW.cost = plan.cost
  EW.claimPending = true
  EW.claimed = false
  EW.lastPosition = nil
  EW.lastPositionAt = 0

  local delayMs = math.min(
    toNumber(settings.claimMaxDelay, 5000, 300, 20000),
    toNumber(settings.claimBaseDelay, 300, 0, 5000) + plan.cost * toNumber(settings.claimCostDelay, 50, 0, 500)
  )

  EW.claimAt = nowMs() + delayMs
  warnMessage("EWOLFLOC recebido. Custo=" .. tostring(math.floor(plan.cost)) .. " claim em " .. tostring(math.floor(delayMs)) .. "ms.")
end

local function handleLocMessage(text)
  local id, sender, coords = text:match("^EWOLFLOC|([^|]+)|([^|]+)|([^|]+)$")
  if not id then return end
  if not isLeader() then return end

  if EW.activeId and EW.activeId ~= id and (EW.claimPending or EW.claimed) then
    return
  end

  if EW.activeId == id and (EW.claimPending or EW.claimed) then return end

  local x, y, z = coords:match("^(%-?%d+),(%-?%d+),(%-?%d+)$")
  if not x then
    warnMessage("EWOLFLOC mal formatado: " .. tostring(text))
    return
  end

  local destination = { x = tonumber(x), y = tonumber(y), z = tonumber(z) }
  local plan = planPath(destination)
  if not plan or not plan.steps or #plan.steps == 0 then
    warnMessage("Sem caminho no grafo ate " .. coords .. ". Alerta ignorado.")
    return
  end

  acceptPlan(id, destination, plan)
end

local function handleClaimMessage(text)
  local id, leaderName, status, costText = text:match("^EWOLFCLAIM|([^|]+)|([^|]+)|([^|]+)|(%d+)$")
  if not id then return end
  if id ~= EW.activeId then return end
  if leaderName == myName() then return end

  local otherCost = tonumber(costText) or 999999
  if EW.claimed and EW.cost <= otherCost then
    return
  end

  warnMessage("Claim recebido de " .. tostring(leaderName) .. " para ID=" .. tostring(id) .. ". Cancelando minha tentativa.")
  resetState("outro lider assumiu")
end

local function handleDoneMessage(text)
  local id = text:match("^EWOLFDONE|([^|]+)")
  if id and id == EW.activeId then
    resetState("done recebido")
  end
end

local function handleCancelMessage(text)
  local id = text:match("^EWOLFCANCEL|([^|]+)")
  if id and id == EW.activeId then
    resetState("cancel recebido")
  end
end

local function processProtocol(text)
  text = tostring(text or "")
  if text:sub(1, 9) == "EWOLFLOC|" then
    handleLocMessage(text)
  elseif text:sub(1, 11) == "EWOLFCLAIM|" then
    handleClaimMessage(text)
  elseif text:sub(1, 10) == "EWOLFDONE|" then
    handleDoneMessage(text)
  elseif text:sub(1, 12) == "EWOLFCANCEL|" then
    handleCancelMessage(text)
  end
end

local function maybeSendWolfLocation()
  if settings.enabled ~= true or settings.detectorEnabled ~= true then return end

  local wolf = findExaltedWolf()
  if not wolf then return end

  local wp = creaturePosition(wolf)
  if not wp then return end

  local key = tostring(wp.x) .. "," .. tostring(wp.y) .. "," .. tostring(wp.z)
  local tm = nowMs()
  if EW.lastDetectorKey == key and tm < EW.lastDetectorAt + toNumber(settings.detectorCooldownMs, 12000, 1000, 60000) then
    return
  end

  EW.lastDetectorKey = key
  EW.lastDetectorAt = tm

  local id = tostring(math.floor(tm)) .. "_" .. tostring(wp.x) .. "_" .. tostring(wp.y) .. "_" .. tostring(wp.z)
  local msg = "EWOLFLOC|" .. id .. "|" .. myName() .. "|" .. key
  sendGuild(msg)
  processProtocol(msg)
  warnMessage("Local do Exalted enviado: " .. key)
end

local function runLeader()
  if settings.enabled ~= true then return end
  if not isLeader() then return end

  if EW.claimPending and EW.activeId then
    if nowMs() >= EW.claimAt then
      local claim = "EWOLFCLAIM|" .. EW.activeId .. "|" .. myName() .. "|a caminho|" .. tostring(math.floor(EW.cost))
      sendGuild(claim)
      EW.claimPending = false
      EW.claimed = true
      pauseBots()
      warnMessage("Claim enviado. Executando " .. tostring(#(EW.steps or {})) .. " passos.")
    else
      return
    end
  end

  if not EW.claimed then return end

  pauseBots()

  if attackWolfIfVisible() then return end

  if EW.attackedWolf and nowMs() > EW.lastSeenWolfAt + toNumber(settings.doneAfterLostMs, 7000, 1000, 30000) then
    sendGuild("EWOLFDONE|" .. tostring(EW.activeId or "?") .. "|" .. myName())
    resetState("wolf sumiu apos ataque")
    return
  end

  if checkStuck() then return end

  local result = executeCurrentStep()
  if result == "advance" then
    EW.stepIndex = EW.stepIndex + 1
    EW.lastWalkAt = 0
    EW.lastUseAt = 0
    EW.lastPosition = nil
  elseif result == "done" then
    if EW.destination then
      debugMessage("Cheguei perto do destino. Aguardando Exalted aparecer.", 2500)
    else
      resetState("sem destino")
    end
  end
end

if type(onTalk) == "function" then
  onTalk(function(name, level, mode, text, channelId, pos)
    processProtocol(text)
  end)
end

if type(onTextMessage) == "function" then
  onTextMessage(function(mode, text)
    processProtocol(text)
  end)
end

macro(200, "EW Graph Nav", function()
  maybeSendWolfLocation()
  runLeader()
end)

local ewAutoUpdateMacro = macro(30000, "EW Auto Update", function()
  maybeRunAutoUpdate()
end)

if ewAutoUpdateMacro and ewAutoUpdateMacro.setOn then
  pcall(function() ewAutoUpdateMacro:setOn(settings.autoUpdateEnabled == true) end)
end

if addIcon then
  local icon = addIcon("EWGraphNav", {
    item = toNumber(settings.iconItemId, 1953, 1, 99999),
    text = "EW\nMAP",
    switchable = true,
    moveable = true
  }, function(widget, isOn)
    settings.enabled = isOn ~= false
    if settings.enabled ~= true then resetState("desligado pelo icone") end
  end)

  if icon and icon.setOn then pcall(function() icon:setOn(settings.enabled == true) end) end
end

if UI and UI.Separator then UI.Separator() end
if UI and UI.Label then UI.Label("EW Graph Nav") end
if addTextEdit then
  addTextEdit("ewGraphLeaders", tostring(settings.leaders or ""), function(widget, text)
    settings.leaders = text
    storage.exaltedWolfLeaders = text
  end)

  addTextEdit("ewGraphUpdateUrl", tostring(settings.updateUrl or ""), function(widget, text)
    settings.updateUrl = text
  end)

  addTextEdit("ewGraphScriptPath", tostring(settings.scriptPath or EW_GRAPH_SCRIPT_NAME), function(widget, text)
    settings.scriptPath = text
  end)
end

if type(addSwitch) == "function" then
  local autoUpdateSwitch = addSwitch("ewGraphAutoUpdateEnabled", "EW Auto Update", function(widget)
    settings.autoUpdateEnabled = not settings.autoUpdateEnabled
    if widget and widget.setOn then pcall(function() widget:setOn(settings.autoUpdateEnabled == true) end) end
    if ewAutoUpdateMacro and ewAutoUpdateMacro.setOn then
      pcall(function() ewAutoUpdateMacro:setOn(settings.autoUpdateEnabled == true) end)
    end
  end)

  if autoUpdateSwitch and autoUpdateSwitch.setOn then
    pcall(function() autoUpdateSwitch:setOn(settings.autoUpdateEnabled == true) end)
  end
end

if UI and UI.Button then
  UI.Button("Atualizar EW", function()
    runScriptUpdate(true)
  end)
end

EWGraphNav = {
  load = function(text)
    local entries = parseCfg(text)
    if #entries == 0 then
      warnMessage("CFG manual vazio.")
      return false
    end
    EW.graph = buildGraph(entries)
    EW.cfgLoaded = true
    warnMessage("CFG manual carregado: " .. tostring(#EW.graph.nodes) .. " nodes.")
    return true
  end,
  reload = loadCfg,
  setPath = function(path)
    settings.cfgPath = tostring(path or "")
    return loadCfg()
  end,
  updateNow = function()
    return runScriptUpdate(true)
  end,
  setUpdateUrl = function(url)
    settings.updateUrl = tostring(url or "")
    return settings.updateUrl
  end,
  setScriptPath = function(path)
    settings.scriptPath = tostring(path or "")
    return settings.scriptPath
  end,
  status = function()
    return {
      version = EW_GRAPH_SCRIPT_VERSION,
      updateUrl = settings.updateUrl,
      scriptPath = settings.scriptPath,
      autoUpdateEnabled = settings.autoUpdateEnabled,
      lastRemoteVersion = settings.lastRemoteVersion,
      cfgLoaded = EW.cfgLoaded,
      nodes = EW.graph and #EW.graph.nodes or 0,
      activeId = EW.activeId,
      claimed = EW.claimed,
      claimPending = EW.claimPending,
      cost = EW.cost,
      stepIndex = EW.stepIndex,
      steps = EW.steps and #EW.steps or 0,
      destination = EW.destination
    }
  end,
  reset = function()
    resetState("reset manual")
  end
}

loadCfg()
