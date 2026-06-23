setDefaultTab("Main")

storage = storage or {}
vBot = vBot or {}

local panelName = "BOTserver"
local DEFAULT_BOTSERVER_URL = "wss://bot.jequimultiassessoria.com.br/"
local DEFAULT_BOTSERVER_CHANNEL = "derpetson_wolf"
local BOTSERVER_VERSION = "2026062302"
local BOTSERVER_UPDATE_BASE = "https://bot.jequimultiassessoria.com.br/botserver"
local BOTSERVER_UPDATE_FILES = {"BotServer.lua", "BotServer.otui", "BotServerNav.lua"}
local BOTSERVER_GUILD_POSITION_TOPIC = "guild_pos"
local BOTSERVER_EXALTED_WOLF_TOPIC = "exalted_wolf"
local BOTSERVER_NAV_MW_TOPIC = "nav_mw_target"
local BOTSERVER_ATTACK_COMBO_TOPIC = "attack_combo_target"
local BOTSERVER_MINIMAP_FILE = "minimap854.otmm"
local TIER_ORB_ITEM_ID = 11844
local BOTSERVER_POSITION_MOVE_INTERVAL_MS = 300
local BOTSERVER_POSITION_KEEPALIVE_MS = 1500
local BOTSERVER_RADAR_REPOSITION_INTERVAL_MS = 1000
local BOTSERVER_RADAR_WIDGET_ID_PREFIX = "botserver_guild_pin_"

local updateInProgress = false

if botServerWindow and botServerWindow.destroy then
  pcall(function() botServerWindow:destroy() end)
end
botServerWindow = nil

function toText(value)
  if value == nil then return "" end
  return tostring(value)
end

function compactStatusText(text)
  local value = toText(text):gsub("^%[BotServer%]%s*", "")
  value = value:gsub("Atualizacao concluida%. Reinicie o bot para aplicar%.", "Atualizado. Reinicie.")
  value = value:gsub("Falha na atualizacao:", "Falha:")
  value = value:gsub(" atualizado de .*$", " atualizado")

  if #value > 34 then
    return value:sub(1, 31) .. "..."
  end

  return value
end

function setUpdateStatusText(text)
  if botServerWindow and botServerWindow.updateStatus and botServerWindow.updateStatus.setText then
    local fullText = toText(text)
    local compactText = compactStatusText(fullText)
    pcall(function()
      botServerWindow.updateStatus:setText(compactText)
    end)
    pcall(function()
      botServerWindow.updateStatus:setTooltip(fullText)
    end)
    pcall(function()
      if botServerWindow.updateStatus.setTextWrap then
        botServerWindow.updateStatus:setTextWrap(false)
      end
    end)
  end
end

function notifyBotServer(text)
  text = "[BotServer] " .. toText(text)
  setUpdateStatusText(text)

  if type(warn) == "function" then
    warn(text)
  elseif type(print) == "function" then
    print(text)
  end
end

function stripTrailingSlash(value)
  value = toText(value):gsub("\\", "/")
  while value:sub(-1) == "/" do
    value = value:sub(1, -2)
  end
  return value
end

function normalizeBotDirPath(value)
  value = stripTrailingSlash(value)
  if value == "" then return nil end
  if value:sub(1, 1) == "/" then return value end
  if value:sub(1, 4) == "bot/" then return "/" .. value end
  return "/bot/" .. value
end

function botResourceFileExists(path)
  if not path or path == "" then return false end
  if not g_resources or type(g_resources.fileExists) ~= "function" then return false end
  local ok, exists = pcall(function()
    return g_resources.fileExists(path)
  end)
  return ok and exists == true
end

function addUniqueBotDir(values, dir)
  dir = normalizeBotDirPath(dir)
  if not dir then return end
  for _, existing in ipairs(values) do
    if existing == dir then return end
  end
  table.insert(values, dir)
end

function getVBotDirCandidates(baseDir)
  local dirs = {}
  baseDir = normalizeBotDirPath(baseDir)
  if not baseDir then return dirs end
  addUniqueBotDir(dirs, baseDir .. "/vBot")
  addUniqueBotDir(dirs, baseDir .. "/vbot")
  addUniqueBotDir(dirs, baseDir .. "/VBot")
  addUniqueBotDir(dirs, baseDir .. "/Vbot")
  return dirs
end

function findBotServerInstallInBase(baseDir)
  baseDir = normalizeBotDirPath(baseDir)
  if not baseDir then return nil end

  for _, dir in ipairs(getVBotDirCandidates(baseDir)) do
    if botResourceFileExists(dir .. "/BotServer.lua") then
      return dir
    end
  end

  if botResourceFileExists(baseDir .. "/BotServer.lua") then
    return baseDir
  end

  return nil
end

function rememberBotInstallDir(dir)
  dir = normalizeBotDirPath(dir)
  if dir and storage then
    storage.BotServerInstallDir = dir
  end
  return dir
end

function getCurrentScriptBotDir()
  if type(debug) ~= "table" or type(debug.getinfo) ~= "function" then return nil end

  local ok, info = pcall(function() return debug.getinfo(1, "S") end)
  if not ok or type(info) ~= "table" then return nil end

  local source = toText(info.source)
  if source:sub(1, 1) == "@" then source = source:sub(2) end
  source = source:gsub("\\", "/")

  local botIndex = source:find("/bot/", 1, true)
  if botIndex then source = source:sub(botIndex) end
  if source:sub(1, 4) == "bot/" then source = "/" .. source end
  if source:sub(1, 5) ~= "/bot/" then return nil end
  if not source:find("/", 6, true) then return nil end

  local dir = source:gsub("/[^/]+$", "")
  if dir == source then return nil end
  return normalizeBotDirPath(dir)
end

function getActiveBotDir()
  local scriptDir = getCurrentScriptBotDir()
  if scriptDir and botResourceFileExists(scriptDir .. "/BotServer.lua") then
    return scriptDir
  end

  if type(configDir) == "string" and configDir ~= "" then
    return normalizeBotDirPath(configDir)
  end

  local ok, option = pcall(function()
    if modules and modules.game_bot and modules.game_bot.contentsPanel and modules.game_bot.contentsPanel.config then
      local current = modules.game_bot.contentsPanel.config:getCurrentOption()
      if current and current.text then return current.text end
    end
    return nil
  end)

  if ok and option and option ~= "" then
    option = toText(option)
    return normalizeBotDirPath(option)
  end

  if g_resources and type(g_resources.listDirectoryFiles) == "function" and type(g_resources.fileExists) == "function" then
    local attempts = {
      function() return g_resources.listDirectoryFiles("/bot") end,
      function() return g_resources.listDirectoryFiles("/bot", false, false) end,
      function() return g_resources.listDirectoryFiles("/bot", false, true) end
    }

    for _, attempt in ipairs(attempts) do
      local ok, files = pcall(attempt)

      if ok and type(files) == "table" then
        for _, configName in ipairs(files) do
          local cleanName = toText(configName):gsub("^/bot/", "")
          local dir = stripTrailingSlash("/bot/" .. cleanName)
          if g_resources.fileExists(dir .. "/BotServer.lua") then
            return dir
          end
        end
      end
    end
  end

  return nil
end

function getBotInstallDir()
  local scriptDir = getCurrentScriptBotDir()
  if scriptDir and botResourceFileExists(scriptDir .. "/BotServer.lua") then
    return rememberBotInstallDir(scriptDir)
  end

  local savedDir = storage and normalizeBotDirPath(storage.BotServerInstallDir) or nil
  if savedDir and botResourceFileExists(savedDir .. "/BotServer.lua") then
    return savedDir
  end

  local baseDir = getActiveBotDir()
  if baseDir then
    local installDir = findBotServerInstallInBase(baseDir)
    if installDir then return rememberBotInstallDir(installDir) end
  end

  if g_resources and type(g_resources.listDirectoryFiles) == "function" then
    local attempts = {
      function() return g_resources.listDirectoryFiles("/bot") end,
      function() return g_resources.listDirectoryFiles("/bot", false, false) end,
      function() return g_resources.listDirectoryFiles("/bot", false, true) end
    }

    for _, attempt in ipairs(attempts) do
      local ok, files = pcall(attempt)
      if ok and type(files) == "table" then
        for _, configName in ipairs(files) do
          local cleanName = toText(configName):gsub("^/bot/", "")
          local dir = stripTrailingSlash("/bot/" .. cleanName)
          local installDir = findBotServerInstallInBase(dir)
          if installDir then return rememberBotInstallDir(installDir) end
        end
      end
    end
  end

  return baseDir
end

function getBotFilePath(fileName)
  local dir = getBotInstallDir()
  if not dir then return nil end
  return dir .. "/" .. fileName
end

function resourceFileExists(path)
  return botResourceFileExists(path)
end

function botServerUiStyleExists(styleName)
  if not g_ui or type(g_ui.getStyle) ~= "function" then return false end
  local ok, style = pcall(function()
    return g_ui.getStyle(styleName)
  end)
  return ok and style ~= nil
end

function importBotServerOtui()
  if not g_ui or type(g_ui.importStyle) ~= "function" then return end
  if botServerWindow ~= nil then return end

  local activeOtui = getBotFilePath("BotServer.otui")
  if not resourceFileExists(activeOtui) then return end

  BotServerImportedOtui = BotServerImportedOtui or {}
  local importKey = activeOtui .. "#" .. BOTSERVER_VERSION
  if BotServerImportedOtui[activeOtui] == importKey then return end
  if botServerUiStyleExists("BotServerWindow") and botServerUiStyleExists("FeaturePanel") then
    BotServerImportedOtui[activeOtui] = importKey
    return
  end

  local ok, err = pcall(function()
    g_ui.importStyle(activeOtui)
  end)
  if ok then
    BotServerImportedOtui[activeOtui] = importKey
  else
    notifyBotServer("OTUI nao importou: " .. toText(err))
  end
end

function normalizeHttpBody(a, b, c)
  if type(a) == "string" and a ~= "" then return a end
  if type(b) == "string" and b ~= "" then return b end
  if type(c) == "string" and c ~= "" then return c end

  if type(a) == "table" then
    if type(a.data) == "string" then return a.data end
    if type(a.body) == "string" then return a.body end
    if type(a.response) == "string" then return a.response end
  end

  return nil
end

function collectHttpClients()
  local clients = {}

  if type(HTTP) == "table" then table.insert(clients, HTTP) end
  if type(g_http) == "table" then table.insert(clients, g_http) end
  if modules and modules.corelib and type(modules.corelib.HTTP) == "table" then
    table.insert(clients, modules.corelib.HTTP)
  end

  return clients
end

function httpGet(url, callback)
  local done = false
  local timeoutEvent = nil

  local function finish(body, err)
    if done then return end
    done = true

    if timeoutEvent and type(removeEvent) == "function" then
      pcall(function() removeEvent(timeoutEvent) end)
    end

    callback(body, err)
  end

  if type(schedule) == "function" then
    timeoutEvent = schedule(10000, function()
      finish(nil, "timeout")
    end)
  end

  local clients = collectHttpClients()
  if #clients == 0 then
    finish(nil, "HTTP.get indisponivel")
    return false
  end

  for _, http in ipairs(clients) do
    if type(http.get) == "function" then
      local ok = pcall(function()
        local result = http.get(url, function(a, b, c)
          local body = normalizeHttpBody(a, b, c)
          if body then
            finish(body, nil)
          else
            finish(nil, toText(b ~= nil and b or c))
          end
        end)

        if type(result) == "string" and result ~= "" then
          finish(result, nil)
        end
      end)

      if ok then return true end
    end
  end

  finish(nil, "falha ao iniciar HTTP.get")
  return false
end

function isValidUpdateFile(fileName, content)
  if type(content) ~= "string" or #content < 30 then return false end

  if fileName == "BotServer.lua" then
    return content:find("BOTSERVER_VERSION", 1, true)
      and content:find("BotServerUpdater", 1, true)
      and content:find("BotServer.listen", 1, true)
  end

  if fileName == "BotServer.otui" then
    return content:find("BotServerWindow", 1, true)
      and content:find("BotServerData", 1, true)
      and content:find("updateButton", 1, true)
  end

  if fileName == "BotServerNav.lua" then
    return content:find("BotServerNav.lua", 1, true)
      and content:find("safe farm navigation coordinator", 1, true)
      and content:find("BOTSERVER_NAV_TOPIC", 1, true)
      and content:find("BotServerNav", 1, true)
      and content:find("sendBoss", 1, true)
      and content:find("BotServer.listen", 1, true)
      and not content:find("function stopStairWalk", 1, true)
      and not content:find("liderFarmMacro", 1, true)
  end

  if fileName == "city_tier.cfg" or fileName == "tier_full_ice.cfg" then
    return content:find("goto:", 1, true)
      and content:find("config:", 1, true)
  end

  return false
end

function addUnique(values, value)
  value = stripTrailingSlash(value)
  if value == "" then return end

  for _, existing in ipairs(values) do
    if existing == value then return end
  end

  table.insert(values, value)
end

function getUpdateBases()
  local bases = {}
  addUnique(bases, storage.BotServerUpdateUrl or "")
  addUnique(bases, BOTSERVER_UPDATE_BASE)
  addUnique(bases, "http://bot.jequimultiassessoria.com.br/botserver")
  return bases
end

function downloadUpdateFile(fileName, callback)
  local bases = getUpdateBases()
  local index = 1

  local function tryNext(lastErr)
    if index > #bases then
      callback(nil, lastErr or "nenhum servidor respondeu")
      return
    end

    local base = bases[index]
    index = index + 1

    local cacheBust = toText(now or BOTSERVER_VERSION)
    local url = base .. "/" .. fileName .. "?v=" .. cacheBust

    httpGet(url, function(content, err)
      if isValidUpdateFile(fileName, content) then
        callback(content, nil, base)
        return
      end

      tryNext(err or "arquivo invalido em " .. base)
    end)
  end

  tryNext()
end

function writeBotFile(fileName, content)
  if not g_resources or type(g_resources.writeFileContents) ~= "function" then
    return false, "g_resources.writeFileContents indisponivel"
  end

  local path = getBotFilePath(fileName)
  if not path then
    return false, "diretorio ativo do bot nao encontrado"
  end

  local backupPath = path .. ".bak"

  pcall(function()
    if type(g_resources.fileExists) == "function" and g_resources.fileExists(path)
      and type(g_resources.readFileContents) == "function" then
      local oldContent = g_resources.readFileContents(path)
      if type(oldContent) == "string" and oldContent ~= "" then
        g_resources.writeFileContents(backupPath, oldContent)
      end
    end
  end)

  local ok, err = pcall(function()
    local result = g_resources.writeFileContents(path, content)
    if result == false then
      error("writeFileContents retornou false")
    end
  end)

  if not ok then return false, err end
  return true
end

function updateBotServer()
  if updateInProgress then
    notifyBotServer("Atualizacao ja esta em andamento")
    return false
  end

  updateInProgress = true
  notifyBotServer("Baixando atualizacao...")

  local index = 1

  local function finish(ok, message)
    updateInProgress = false

    if ok then
      notifyBotServer("Atualizacao concluida. Reinicie o bot para aplicar.")
    else
      notifyBotServer("Falha na atualizacao: " .. toText(message))
    end
  end

  local function nextFile()
    local fileName = BOTSERVER_UPDATE_FILES[index]
    if not fileName then
      finish(true)
      return
    end

    setUpdateStatusText("Baixando " .. fileName .. "...")

    downloadUpdateFile(fileName, function(content, err, base)
      if not content then
        finish(false, fileName .. " - " .. toText(err))
        return
      end

      local ok, writeErr = writeBotFile(fileName, content)
      if not ok then
        finish(false, fileName .. " - " .. toText(writeErr))
        return
      end

      notifyBotServer(fileName .. " atualizado de " .. toText(base))
      index = index + 1
      nextFile()
    end)
  end

  nextFile()
  return true
end

BotServerUpdater = BotServerUpdater or {}
BotServerUpdater.version = BOTSERVER_VERSION
BotServerUpdater.url = BOTSERVER_UPDATE_BASE
BotServerUpdater.update = updateBotServer
BotServerUpdater.check = updateBotServer

function isOldBotServerUrl(value)
  value = tostring(value or "")
  return value == ""
    or value == "ws://127.0.0.1:5000/send"
    or value == "ws://127.0.0.1:5000/"
    or value == "ws://localhost:5000/"
    or value == "ws://127.0.0.1:8000/"
    or value == "ws://localhost:8000/"
end

function configureBotServer()
  if isOldBotServerUrl(storage.BotServerUrl) then
    storage.BotServerUrl = DEFAULT_BOTSERVER_URL
  end

  if not storage.BotServerChannel or storage.BotServerChannel == "" or tostring(storage.BotServerChannel):match("^%d+$") then
    storage.BotServerChannel = DEFAULT_BOTSERVER_CHANNEL
  end

  if not storage.BotServerUpdateUrl or storage.BotServerUpdateUrl == "" then
    storage.BotServerUpdateUrl = BOTSERVER_UPDATE_BASE
  end

  storage.DerpetsonWolfNodeBridge = storage.DerpetsonWolfNodeBridge or {}
  storage.DerpetsonWolfNodeBridge.serverUrl = storage.BotServerUrl
  storage.DerpetsonWolfNodeBridge.channel = storage.BotServerChannel

  if BotServer then
    BotServer.url = storage.BotServerUrl
  end
end

function ensureBotServerConnected()
  configureBotServer()

  if not BotServer or type(BotServer.init) ~= "function" then
    return false
  end

  if BotServer._websocket then
    return true
  end

  pcall(function()
    local playerName = "unknown"
    if type(name) == "function" then
      local ok, value = pcall(name)
      if ok and value then playerName = tostring(value) end
    end
    BotServer.init(playerName, tostring(storage.BotServerChannel or DEFAULT_BOTSERVER_CHANNEL))
  end)

  return BotServer._websocket ~= nil
end

function sendBotServerMessage(topic, message)
  if not ensureBotServerConnected() then return false end
  if not BotServer or type(BotServer.send) ~= "function" then return false end

  local ok = pcall(function()
    if message == nil then
      BotServer.send(topic)
    else
      BotServer.send(topic, message)
    end
  end)

  return ok == true
end

function listenBotServer(topic, callback)
  if not BotServer or type(BotServer.listen) ~= "function" then return false end

  local ok = pcall(function()
    BotServer.listen(topic, callback)
  end)

  return ok == true
end

configureBotServer()
importBotServerOtui()

local ui = setupUI([[
Panel
  height: 18
  Button
    id: botServer
    anchors.left: parent.left
    anchors.right: parent.right
    text-align: center
    height: 18
    !text: tr('BotServer')
]])
ui:setId(panelName)

if not storage[panelName] then
  storage[panelName] = {
    manaInfo = true,
    mwallInfo = true,
    outfit = false,
    broadcasts = true,
    locations = true,
    radarMarks = true,
    autoVoc = true,
    navScoutEnabled = false,
    navLeaderEnabled = false,
    navMwEnabled = false,
    comboEnabled = false,
    attackComboEnabled = false,
    mapOutfits = false,
    navPotionEnabled = false
  }
end

local config = storage[panelName]
if config.locations == nil then config.locations = true end
if config.radarMarks == nil then config.radarMarks = true end
if config.autoVoc == nil then config.autoVoc = true end
if config.comboEnabled == nil then config.comboEnabled = false end
if config.attackComboEnabled == nil then config.attackComboEnabled = false end
if config.mapOutfits == nil then config.mapOutfits = false end
if config.navPotionEnabled == nil then config.navPotionEnabled = false end
if config.navMwEnabled == nil then config.navMwEnabled = false end
config.navEnabled = false
if config.navScoutEnabled == nil then config.navScoutEnabled = false end
if config.navLeaderEnabled == nil then config.navLeaderEnabled = false end

function safePlayerCall(methodName, defaultValue)
  if not player or not player[methodName] then return defaultValue end
  local ok, value = pcall(function()
    return player[methodName](player)
  end)
  if ok and value ~= nil then return value end
  return defaultValue
end

function currentMillis()
  local n = tonumber(now)
  if n then return n end
  if os and type(os.time) == "function" then return os.time() * 1000 end
  return 0
end

local botServerNavLoading = false

function setBotServerNavMacroState(enabled)
  return enabled == true
end

function isBotServerNavActive()
  return config.navScoutEnabled == true
    or config.navLeaderEnabled == true
    or config.navMwEnabled == true
end

function stopBotServerNav()
  setBotServerNavMacroState(false)
  if BotServerNav and type(BotServerNav.stop) == "function" then
    pcall(function() BotServerNav.stop() end)
  end
  if modules and modules.derpetsonWalkManager and type(modules.derpetsonWalkManager.stop) == "function" then
    pcall(function() modules.derpetsonWalkManager.stop() end)
  elseif modules and modules.stagedWalk and type(modules.stagedWalk.stopStagedWalk) == "function" then
    pcall(function() modules.stagedWalk.stopStagedWalk() end)
  end
  if g_game and type(g_game.stop) == "function" then
    pcall(function() g_game.stop() end)
  end
end

function tryLoadBotServerNavFile()
  if BotServerNavLoadedVersion == BOTSERVER_VERSION then
    setBotServerNavMacroState(isBotServerNavActive())
    return true
  end

  local paths = {
    getBotFilePath("BotServerNav.lua"),
    "/BotServerNav.lua",
    "BotServerNav.lua"
  }

  local function runNavContent(path, content)
    local loader = type(loadstring) == "function" and loadstring or load
    if type(loader) == "function" then
      local chunk, compileErr = loader(content, "@" .. toText(path))
      if not chunk then return false, compileErr end
      return pcall(chunk)
    end

    return false, "loadstring/load unavailable"
  end

  for _, path in ipairs(paths) do
    if path and path ~= "" then
      local validLocalFile = false
      local content = nil
      if g_resources and type(g_resources.readFileContents) == "function" and resourceFileExists(path) then
        local okRead
        okRead, content = pcall(function() return g_resources.readFileContents(path) end)
        validLocalFile = okRead and isValidUpdateFile("BotServerNav.lua", content)
      end

      local ok = false
      local loadErr = nil
      if validLocalFile then
        ok, loadErr = runNavContent(path, content)
      end
      if ok then
        BotServerNavLoadedVersion = BOTSERVER_VERSION
        setBotServerNavMacroState(isBotServerNavActive())
        return true
      elseif validLocalFile and loadErr then
        notifyBotServer("BotServerNav erro: " .. toText(loadErr))
      end
    end
  end

  return false
end

function loadBotServerNav(downloadIfMissing)
  if not isBotServerNavActive() then return false end
  if tryLoadBotServerNavFile() then return true end
  if downloadIfMissing ~= true or botServerNavLoading == true then return false end

  botServerNavLoading = true
  notifyBotServer("Baixando BotServerNav...")
  downloadUpdateFile("BotServerNav.lua", function(content, err, base)
    botServerNavLoading = false
    if not content then
      notifyBotServer("BotServerNav falhou: " .. toText(err))
      return
    end

    local ok, writeErr = writeBotFile("BotServerNav.lua", content)
    if not ok then
      notifyBotServer("BotServerNav falhou: " .. toText(writeErr))
      return
    end

    notifyBotServer("BotServerNav atualizado")
    if not tryLoadBotServerNavFile() then
      notifyBotServer("BotServerNav nao carregou")
    end
  end)

  return false
end

function normalizePosition(value)
  if type(value) == "table" then
    local x = tonumber(value.x or value[1])
    local y = tonumber(value.y or value[2])
    local z = tonumber(value.z or value[3])
    if x and y and z then
      return { x = math.floor(x), y = math.floor(y), z = math.floor(z) }
    end
  end

  if type(value) == "string" then
    local x, y, z = value:match("(%-?%d+)%D+(%-?%d+)%D+(%-?%d+)")
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if x and y and z then
      return { x = math.floor(x), y = math.floor(y), z = math.floor(z) }
    end
  end

  return nil
end

function normalizeTextValue(value)
  local v = tostring(value or ""):lower():gsub("%s+", " ")
  return v:gsub("^%s+", ""):gsub("%s+$", "")
end

function vocationKeyFromValue(value)
  local v = normalizeTextValue(value)
  if v == "1" or v == "5" or v == "13" or v == "sorcerer" or v == "ms" or v == "master sorcerer" then return "sorcerer" end
  if v == "2" or v == "6" or v == "14" or v == "druid" or v == "ed" or v == "elder druid" then return "druid" end
  if v == "3" or v == "7" or v == "12" or v == "paladin" or v == "rp" or v == "royal paladin" then return "paladin" end
  if v == "4" or v == "8" or v == "11" or v == "knight" or v == "ek" or v == "elite knight" then return "knight" end
  return nil
end

function shortVocationLabel(value)
  local key = vocationKeyFromValue(value)
  if key == "sorcerer" then return "MS" end
  if key == "druid" then return "ED" end
  if key == "paladin" then return "RP" end
  if key == "knight" then return "EK" end
  return "?"
end

function fullVocationLabel(value)
  local key = vocationKeyFromValue(value)
  if key == "sorcerer" then return "MS - Sorcerer" end
  if key == "druid" then return "ED - Druid" end
  if key == "paladin" then return "RP - Paladin" end
  if key == "knight" then return "EK - Knight" end
  return "Unknown"
end

function getLocalPlayerNameSafe()
  if type(name) == "function" then
    local ok, value = pcall(name)
    if ok and value then return tostring(value or "") end
  end

  if player and player.getName then
    local ok, value = pcall(function() return player:getName() end)
    if ok and value then return tostring(value or "") end
  end

  return ""
end

function callVocationMethod(object, methodName)
  if not object or type(object[methodName]) ~= "function" then return nil end
  local ok, value = pcall(function() return object[methodName](object) end)
  if ok then return vocationKeyFromValue(value) end
  return nil
end

function readLocalPlayerVocation()
  local localPlayer = player
  if not localPlayer and g_game and type(g_game.getLocalPlayer) == "function" then
    local ok, value = pcall(function() return g_game.getLocalPlayer() end)
    if ok and value then localPlayer = value end
  end

  local methods = {
    "getVocation",
    "getVocationId",
    "getProfession",
    "getProfessionId",
    "getClass",
    "getClassId"
  }

  for _, methodName in ipairs(methods) do
    local detected = callVocationMethod(localPlayer, methodName)
    if detected then return detected end
  end

  if type(getVocation) == "function" then
    local ok, value = pcall(function() return getVocation() end)
    local detected = ok and vocationKeyFromValue(value) or nil
    if detected then return detected end
  end

  if type(vocation) == "function" then
    local ok, value = pcall(function() return vocation() end)
    local detected = ok and vocationKeyFromValue(value) or nil
    if detected then return detected end
  end

  return nil
end

function currentDetectedVocation()
  local detected = vocationKeyFromValue(config.detectedVocation)
  if not detected then return nil end

  local savedPlayer = tostring(config.detectedVocationPlayer or "")
  local currentPlayer = getLocalPlayerNameSafe()
  if savedPlayer ~= "" and currentPlayer == "" then return nil end
  if savedPlayer ~= "" and currentPlayer ~= "" and savedPlayer ~= currentPlayer then return nil end

  return detected
end

function applyDetectedVocation(vocation, source)
  local key = vocationKeyFromValue(vocation)
  if not key then return false end

  local old = vocationKeyFromValue(config.detectedVocation)
  config.detectedVocation = key
  config.detectedVocationSource = tostring(source or "auto")
  local playerName = getLocalPlayerNameSafe()
  if playerName ~= "" then config.detectedVocationPlayer = playerName end

  if old ~= key then
    notifyBotServer("Auto Voc: " .. fullVocationLabel(key))
    return true
  end

  return false
end

function detectVocationFromText(text)
  local raw = tostring(text or "")
  if raw == "" then return nil end

  local lower = raw:lower()
  if not lower:find("%[vocation%]") and not lower:find("vocacao", 1, true) then
    return nil
  end

  local id, label = raw:match("%[[Vv][Oo][Cc][Aa][Tt][Ii][Oo][Nn]%]%s*(%d+)%s*|%s*([^%[%]\r\n]+)")
  local detected = vocationKeyFromValue(id) or vocationKeyFromValue(label)
  if detected then return detected end

  if lower:find("master sorcerer", 1, true) or lower:find("sorcerer", 1, true) then return "sorcerer" end
  if lower:find("elder druid", 1, true) or lower:find("druid", 1, true) then return "druid" end
  if lower:find("royal paladin", 1, true) or lower:find("paladin", 1, true) then return "paladin" end
  if lower:find("elite knight", 1, true) or lower:find("knight", 1, true) then return "knight" end

  return nil
end

function handleVocationDetectionText(text)
  if config.autoVoc ~= true then return false end
  local detected = detectVocationFromText(text)
  if not detected then return false end
  return applyDetectedVocation(detected, "login")
end

function probeBotServerVocation(source)
  if config.autoVoc ~= true then return false end
  local detected = readLocalPlayerVocation()
  if not detected then return false end
  return applyDetectedVocation(detected, source or "player")
end

function getBotServerVocationInfo()
  local raw = safePlayerCall("getVocation", nil)
  local detected = nil

  if config.autoVoc == true then
    detected = currentDetectedVocation() or readLocalPlayerVocation()
    if detected then applyDetectedVocation(detected, "player") end
  end

  local key = detected or vocationKeyFromValue(raw)
  return {
    raw = raw,
    key = key,
    label = fullVocationLabel(key or raw),
    short = shortVocationLabel(key or raw),
    value = key or raw or 0
  }
end

function getPlayerPositionSafe()
  local p = nil
  if type(pos) == "function" then
    local ok, value = pcall(pos)
    if ok then p = value end
  end

  if not p and player and player.getPosition then
    local ok, value = pcall(function() return player:getPosition() end)
    if ok then p = value end
  end

  return normalizePosition(p)
end

function getPositionSignature(p)
  p = normalizePosition(p)
  if not p then return "" end
  return tostring(p.x) .. ":" .. tostring(p.y) .. ":" .. tostring(p.z)
end

function getLocationString(p)
  p = normalizePosition(p) or getPlayerPositionSafe()
  if not p then return "" end
  return string.format("%d, %d, %d", p.x, p.y, p.z)
end

function getPlayerNameFallback()
  if type(name) == "function" then
    local ok, value = pcall(name)
    if ok and value then return value end
  end
  return "unknown"
end

function getBotServerRolePayload()
  local scout = config.navScoutEnabled == true
  local killer = config.navLeaderEnabled == true
  local role = ""
  if scout then
    role = "Scout"
  elseif killer then
    role = "Killer"
  end

  return {
    scoutActive = scout,
    killerActive = killer,
    navScoutEnabled = scout,
    navLeaderEnabled = killer,
    role = role
  }
end

function getPlayerOutfitSafe()
  if player and type(player.getOutfit) == "function" then
    local ok, value = pcall(function() return player:getOutfit() end)
    if ok and type(value) == "table" then return value end
  end
  return nil
end

function getOutfitSignature(outfit)
  if type(outfit) ~= "table" then return "" end
  return table.concat({
    tostring(outfit.type or outfit.lookType or outfit[1] or ""),
    tostring(outfit.head or outfit.lookHead or outfit[2] or ""),
    tostring(outfit.body or outfit.lookBody or outfit[3] or ""),
    tostring(outfit.legs or outfit.lookLegs or outfit[4] or ""),
    tostring(outfit.feet or outfit.lookFeet or outfit[5] or ""),
    tostring(outfit.addons or outfit.lookAddons or outfit[6] or ""),
    tostring(outfit.mount or outfit.lookMount or "")
  }, ":")
end

function tableContainsCI(values, value)
  value = toText(value):lower()
  if type(values) ~= "table" or value == "" then return false end
  for _, item in ipairs(values) do
    if toText(item):lower() == value then return true end
  end
  return false
end

function tableFindCI(values, value)
  value = toText(value):lower()
  if type(values) ~= "table" or value == "" then return nil end
  for index, item in ipairs(values) do
    if toText(item):lower() == value then return index end
  end
  return nil
end

function tableRemoveValueCI(values, value)
  local index = tableFindCI(values, value)
  if index then
    table.remove(values, index)
    return true
  end
  return false
end

function shortComboVocFromValue(value)
  local key = vocationKeyFromValue(value)
  if key == "knight" then return "EK" end
  if key == "druid" then return "ED" end
  if key == "sorcerer" then return "MS" end
  if key == "paladin" then return "RP" end
  return nil
end

function ensureComboConfig()
  if type(config.combo) ~= "table" then
    config.combo = {}
  end

  local combo = config.combo
  if type(combo.enemyList) ~= "table" then combo.enemyList = {} end
  combo.leaderList = nil
  if type(combo.voc) ~= "table" then combo.voc = {} end

  local defaults = {
    EK = { enabled = true, prio = 1 },
    ED = { enabled = true, prio = 2 },
    MS = { enabled = true, prio = 3 },
    RP = { enabled = true, prio = 4 }
  }
  for voc, def in pairs(defaults) do
    if type(combo.voc[voc]) ~= "table" then combo.voc[voc] = { enabled = def.enabled, prio = def.prio } end
    if combo.voc[voc].enabled == nil then combo.voc[voc].enabled = def.enabled end
    if tonumber(combo.voc[voc].prio) == nil then combo.voc[voc].prio = def.prio end
  end

  if combo.useOrder == nil then combo.useOrder = true end
  if combo.useVoc == nil then combo.useVoc = false end
  if combo.useLevel == nil then combo.useLevel = false end
  if combo.levelDesc == nil then combo.levelDesc = false end
  if combo.enemyGuild == nil then combo.enemyGuild = false end
  return combo
end

function ensureNavPotionConfig()
  if type(config.navPotion) ~= "table" then config.navPotion = {} end
  local pot = config.navPotion
  if pot.potDistance == nil then pot.potDistance = 5 end
  if pot.mpRequestEnabled == nil then pot.mpRequestEnabled = false end
  if pot.mpRequestPercent == nil then pot.mpRequestPercent = 50 end
  if not pot.myVoc then
    pot.myVoc = shortComboVocFromValue(getBotServerVocationInfo().key) or "EK"
  end

  for _, voc in ipairs({"EK", "ED", "MS", "RP"}) do
    if pot["hp" .. voc] == nil then pot["hp" .. voc] = 80 end
    if pot["hpEnabled" .. voc] == nil then pot["hpEnabled" .. voc] = true end
    if pot["mpEnabled" .. voc] == nil then pot["mpEnabled" .. voc] = true end
    if pot["hpItem" .. voc] == nil then pot["hpItem" .. voc] = 266 end
    if pot["mpItem" .. voc] == nil then pot["mpItem" .. voc] = 268 end
  end

  return pot
end

local comboSettings = ensureComboConfig()
local navPotionSettings = ensureNavPotionConfig()

function getOpenContainersSafe()
  if type(getContainers) == "function" then
    local ok, containers = pcall(getContainers)
    if ok and type(containers) == "table" then return containers end
  end

  if g_game and type(g_game.getContainers) == "function" then
    local ok, containers = pcall(function() return g_game.getContainers() end)
    if ok and type(containers) == "table" then return containers end
  end

  return {}
end

function itemIdSafe(item)
  if not item or type(item.getId) ~= "function" then return nil end
  local ok, value = pcall(function() return item:getId() end)
  if ok then return tonumber(value) end
  return nil
end

function itemCountSafe(item)
  if not item then return 0 end
  if type(item.getCount) == "function" then
    local ok, value = pcall(function() return item:getCount() end)
    if ok and tonumber(value) and tonumber(value) > 0 then return math.floor(tonumber(value)) end
  end
  return 1
end

function containerItemsSafe(container)
  if not container or type(container.getItems) ~= "function" then return {} end
  local ok, items = pcall(function() return container:getItems() end)
  if ok and type(items) == "table" then return items end
  return {}
end

function countTierOrbsInOpenBackpacks()
  local count = 0
  local containers = 0

  for _, container in pairs(getOpenContainersSafe()) do
    if container and container.lootContainer ~= true then
      containers = containers + 1
      for _, item in ipairs(containerItemsSafe(container)) do
        if itemIdSafe(item) == TIER_ORB_ITEM_ID then
          count = count + itemCountSafe(item)
        end
      end
    end
  end

  return count, containers
end

local lastTierOrbCount = nil
local lastTierOrbReportAt = 0
local lastTierOrbSignature = ""
local lastExaltedWolfLootSignature = ""
local lastExaltedWolfLootAt = 0

function isExaltedWolfLootText(text)
  local value = toText(text):lower()
  return value:find("loot of exalted wolf:", 1, true) ~= nil
end

function sendExaltedWolfLootReport(text)
  if not isExaltedWolfLootText(text) then return false end
  local p = getPlayerPositionSafe()
  if not p then return false end

  local tm = currentMillis()
  local signature = table.concat({
    toText(text),
    getPositionSignature(p)
  }, ":")
  if signature == lastExaltedWolfLootSignature and tm - lastExaltedWolfLootAt < 5000 then
    return false
  end

  lastExaltedWolfLootSignature = signature
  lastExaltedWolfLootAt = tm

  return sendBotServerMessage(BOTSERVER_EXALTED_WOLF_TOPIC, {
    kind = "exalted_wolf",
    status = "loot",
    loot = true,
    lootText = toText(text),
    scout = safePlayerCall("getName", getPlayerNameFallback()),
    x = p.x,
    y = p.y,
    z = p.z,
    position = p,
    location = getLocationString(p),
    sentAt = tm
  })
end

function sendTierOrbReport(reason, delta)
  if not ensureBotServerConnected() then return false end

  local count, containers = countTierOrbsInOpenBackpacks()
  local p = getPlayerPositionSafe()
  local roleInfo = getBotServerRolePayload()
  local playerName = safePlayerCall("getName", getPlayerNameFallback())
  local tm = currentMillis()
  delta = math.max(0, math.floor(tonumber(delta) or 0))

  local canInferDelta = reason ~= "startup"
    and reason ~= "container_open"
    and reason ~= "container_close"
    and reason ~= "role_change"
  if delta <= 0 and canInferDelta and lastTierOrbCount ~= nil and count > lastTierOrbCount then
    delta = count - lastTierOrbCount
    if not reason or reason == "scan" then reason = "scan_delta" end
  end

  local signature = table.concat({
    toText(playerName),
    tostring(count),
    tostring(delta),
    toText(reason),
    tostring(roleInfo.scoutActive),
    tostring(roleInfo.killerActive),
    p and getPositionSignature(p) or "nopos"
  }, ":")

  if delta <= 0 and signature == lastTierOrbSignature and tm - lastTierOrbReportAt < 5000 then
    return false
  end

  lastTierOrbCount = count
  lastTierOrbSignature = signature
  lastTierOrbReportAt = tm

  return sendBotServerMessage("tier_orbs", {
    name = playerName,
    itemId = TIER_ORB_ITEM_ID,
    count = count,
    delta = delta,
    containers = containers,
    reason = reason or "scan",
    source = "bot_client",
    x = p and p.x or nil,
    y = p and p.y or nil,
    z = p and p.z or nil,
    position = p,
    location = getLocationString(p),
    scoutActive = roleInfo.scoutActive,
    killerActive = roleInfo.killerActive,
    navScoutEnabled = roleInfo.navScoutEnabled,
    navLeaderEnabled = roleInfo.navLeaderEnabled,
    role = roleInfo.role,
    sentAt = tm
  })
end

function handleTierOrbContainerChange(reason, item, oldItem)
  if itemIdSafe(item) ~= TIER_ORB_ITEM_ID then return false end

  local newCount = itemCountSafe(item)
  local oldCount = 0
  if oldItem and itemIdSafe(oldItem) == TIER_ORB_ITEM_ID then
    oldCount = itemCountSafe(oldItem)
  end

  local delta = math.max(0, newCount - oldCount)
  if delta <= 0 and reason == "container_add" then delta = newCount end
  if delta <= 0 then
    sendTierOrbReport(reason or "container_change", 0)
    return false
  end

  return sendTierOrbReport(reason or "container_change", delta)
end

function startTierOrbCollection()
  local count, containers = countTierOrbsInOpenBackpacks()
  lastTierOrbCount = count
  lastTierOrbSignature = ""
  lastTierOrbReportAt = 0

  local playerName = safePlayerCall("getName", getPlayerNameFallback())
  local p = getPlayerPositionSafe()
  local sent = sendBotServerMessage("tier_orbs_control", {
    action = "start_collection",
    startedBy = playerName,
    sourceCharacter = playerName,
    itemId = TIER_ORB_ITEM_ID,
    count = count,
    containers = containers,
    x = p and p.x or nil,
    y = p and p.y or nil,
    z = p and p.z or nil,
    position = p,
    location = getLocationString(p),
    sentAt = currentMillis()
  })

  notifyBotServer(sent and "Coleta Tier Orb iniciada" or "Falha ao iniciar coleta Tier Orb")
  return sent
end

function boolFromValue(value)
  return value == true or value == 1 or value == "1" or value == "true" or value == "yes"
end

function getCreatureNameSafe(creature)
  if creature and creature.getName then
    local ok, value = pcall(function() return creature:getName() end)
    if ok and value then return toText(value) end
  end
  return ""
end

function isCreaturePlayerSafe(creature)
  if not creature or type(creature.isPlayer) ~= "function" then return false end
  local ok, value = pcall(function() return creature:isPlayer() end)
  return ok and value == true
end

function isCreatureLocalPlayerSafe(creature)
  if not creature then return false end
  if type(creature.isLocalPlayer) == "function" then
    local ok, value = pcall(function() return creature:isLocalPlayer() end)
    if ok and value == true then return true end
  end
  local playerName = safePlayerCall("getName", getPlayerNameFallback())
  local creatureName = getCreatureNameSafe(creature)
  return playerName ~= "" and creatureName ~= "" and creatureName:lower() == toText(playerName):lower()
end

function getCreatureSkullSafe(creature)
  if creature and type(creature.getSkull) == "function" then
    local ok, value = pcall(function() return creature:getSkull() end)
    if ok then return tonumber(value) or 0 end
  end
  return 0
end

function isTimedSquareVisibleSafe(creature)
  if creature and type(creature.isTimedSquareVisible) == "function" then
    local ok, value = pcall(function() return creature:isTimedSquareVisible() end)
    return ok and value == true
  end
  return false
end

function getSpectatorsSafe()
  if type(getSpectators) == "function" then
    local ok, specs = pcall(function() return getSpectators(false) end)
    if ok and type(specs) == "table" then return specs end
    ok, specs = pcall(function() return getSpectators() end)
    if ok and type(specs) == "table" then return specs end
  end

  local p = getPlayerPositionSafe()
  if g_map and p and type(g_map.getSpectators) == "function" then
    local ok, specs = pcall(function() return g_map.getSpectators(p, false) end)
    if ok and type(specs) == "table" then return specs end
    ok, specs = pcall(function() return g_map.getSpectators(p) end)
    if ok and type(specs) == "table" then return specs end
  end

  return {}
end

function getAttackingCreatureSafe()
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

function getBotServerCombatInfo()
  local attackers = {}
  local attackerNames = {}
  local playerName = safePlayerCall("getName", getPlayerNameFallback())

  for _, creature in ipairs(getSpectatorsSafe()) do
    if isCreaturePlayerSafe(creature) and not isCreatureLocalPlayerSafe(creature) then
      local timed = isTimedSquareVisibleSafe(creature)
      local skull = getCreatureSkullSafe(creature)
      if timed or skull > 2 then
        local name = getCreatureNameSafe(creature)
        if name ~= "" then
          table.insert(attackers, { name = name, skull = skull, timedSquare = timed })
          table.insert(attackerNames, name)
        end
      end
    end
  end

  local target = getAttackingCreatureSafe()
  local targetName = target and getCreatureNameSafe(target) or ""
  local targetPlayer = target and isCreaturePlayerSafe(target) and not isCreatureLocalPlayerSafe(target) or false

  return {
    alive = safePlayerCall("getHealth", 0) > 0,
    dead = safePlayerCall("getHealth", 0) <= 0,
    underPkAttack = #attackers > 0,
    pkAttackers = attackers,
    pkAttackerNames = table.concat(attackerNames, ", "),
    targetPlayer = targetPlayer,
    targetName = targetName,
    targetSkull = target and getCreatureSkullSafe(target) or 0,
    playerName = playerName
  }
end

local lastExaltedWolfReportSignature = ""
local lastExaltedWolfReportAt = 0
local lastExaltedWolfDeathSignature = ""
local lastExaltedWolfDeathAt = 0

function getCreaturePositionSafe(creature)
  if creature and type(creature.getPosition) == "function" then
    local ok, value = pcall(function() return creature:getPosition() end)
    if ok then return normalizePosition(value) end
  end
  return nil
end

function getCreatureHealthPercentSafe(creature)
  if creature and type(creature.getHealthPercent) == "function" then
    local ok, value = pcall(function() return creature:getHealthPercent() end)
    if ok and tonumber(value) then return tonumber(value) end
  end
  return nil
end

function isExaltedWolfCreature(creature)
  local creatureName = getCreatureNameSafe(creature):lower()
  return creatureName:find("exalted wolf", 1, true) ~= nil
end

function sendExaltedWolfReport(creature, status, force)
  if not ensureBotServerConnected() then return false end
  if not creature or not isExaltedWolfCreature(creature) then return false end

  local p = getCreaturePositionSafe(creature)
  if not p then return false end

  local hp = getCreatureHealthPercentSafe(creature)
  local dead = status == "dead" or status == "death" or status == "killed" or (hp ~= nil and hp <= 0)
  local tm = currentMillis()
  local signature = table.concat({
    getPositionSignature(p),
    tostring(math.floor(tonumber(hp) or -1)),
    dead and "dead" or "seen"
  }, ":")

  if dead then
    if force ~= true and signature == lastExaltedWolfDeathSignature and tm - lastExaltedWolfDeathAt < 10000 then
      return false
    end
    lastExaltedWolfDeathSignature = signature
    lastExaltedWolfDeathAt = tm
  else
    if force ~= true and signature == lastExaltedWolfReportSignature and tm - lastExaltedWolfReportAt < 1500 then
      return false
    end
    lastExaltedWolfReportSignature = signature
    lastExaltedWolfReportAt = tm
  end

  return sendBotServerMessage(BOTSERVER_EXALTED_WOLF_TOPIC, {
    kind = "exalted_wolf",
    status = dead and "dead" or "seen",
    dead = dead,
    hp = hp,
    name = safePlayerCall("getName", getPlayerNameFallback()),
    sender = safePlayerCall("getName", getPlayerNameFallback()),
    x = p.x,
    y = p.y,
    z = p.z,
    position = p,
    location = getLocationString(p),
    sentAt = tm
  })
end

function scanExaltedWolfPosition()
  for _, creature in ipairs(getSpectatorsSafe()) do
    if isExaltedWolfCreature(creature) then
      local hp = getCreatureHealthPercentSafe(creature)
      sendExaltedWolfReport(creature, hp ~= nil and hp <= 0 and "dead" or "seen", hp ~= nil and hp <= 0)
      return true
    end
  end
  return false
end

function sendCharacterInfo()
  if not ensureBotServerConnected() then return end
  local p = getPlayerPositionSafe()
  local vocationInfo = getBotServerVocationInfo()
  local roleInfo = getBotServerRolePayload()
  local combatInfo = getBotServerCombatInfo()
  local health = safePlayerCall("getHealth", 0)
  local maxHealth = safePlayerCall("getMaxHealth", 0)

  pcall(function()
    BotServer.send("char_info", {
      name = safePlayerCall("getName", getPlayerNameFallback()),
      level = safePlayerCall("getLevel", 0),
      vocation = vocationInfo.value,
      vocationRaw = vocationInfo.raw,
      vocationKey = vocationInfo.key,
      vocationLabel = vocationInfo.label,
      health = health,
      maxHealth = maxHealth,
      alive = combatInfo.alive,
      dead = combatInfo.dead,
      underPkAttack = combatInfo.underPkAttack,
      pkAttackers = combatInfo.pkAttackers,
      pkAttackerNames = combatInfo.pkAttackerNames,
      targetPlayer = combatInfo.targetPlayer,
      targetName = combatInfo.targetName,
      targetSkull = combatInfo.targetSkull,
      outfit = getPlayerOutfitSafe(),
      mana = safePlayerCall("getMana", 0),
      maxMana = safePlayerCall("getMaxMana", 0),
      experience = safePlayerCall("getExperience", 0),
      expPercent = safePlayerCall("getLevelPercent", 0),
      location = getLocationString(p),
      x = p and p.x or nil,
      y = p and p.y or nil,
      z = p and p.z or nil,
      position = p,
      map = BOTSERVER_MINIMAP_FILE,
      scoutActive = roleInfo.scoutActive,
      killerActive = roleInfo.killerActive,
      navScoutEnabled = roleInfo.navScoutEnabled,
      navLeaderEnabled = roleInfo.navLeaderEnabled,
      role = roleInfo.role
    })
  end)
end

function getGuildLocationName(messageName, message)
  if type(message) == "table" and message.name and message.name ~= "" then
    return toText(message.name)
  end
  return toText(messageName or "")
end

function parseGuildLocationPayload(messageName, message)
  if type(message) ~= "table" then return nil end

  local p = normalizePosition(message.position)
    or normalizePosition(message.pos)
    or normalizePosition(message.location)
    or normalizePosition({ x = message.x, y = message.y, z = message.z })

  if not p then return nil end

  return {
    name = getGuildLocationName(messageName, message),
    level = tonumber(message.level) or 0,
    vocation = message.vocation,
    vocationRaw = message.vocationRaw,
    vocationKey = vocationKeyFromValue(message.vocationKey or message.vocation),
    vocationLabel = message.vocationLabel,
    health = tonumber(message.health) or 0,
    maxHealth = tonumber(message.maxHealth) or 0,
    alive = not boolFromValue(message.dead) and message.alive ~= false,
    dead = boolFromValue(message.dead),
    underPkAttack = boolFromValue(message.underPkAttack),
    pkAttackers = type(message.pkAttackers) == "table" and message.pkAttackers or {},
    pkAttackerNames = toText(message.pkAttackerNames or ""),
    targetPlayer = boolFromValue(message.targetPlayer),
    targetName = toText(message.targetName or ""),
    targetSkull = tonumber(message.targetSkull) or 0,
    leader = boolFromValue(message.leader or message.dashboardLeader),
    highlighted = boolFromValue(message.highlighted or message.dashboardHighlight),
    caller = boolFromValue(message.caller or message.dashboardCaller),
    scoutActive = boolFromValue(message.scoutActive or message.navScoutEnabled),
    killerActive = boolFromValue(message.killerActive or message.navLeaderEnabled),
    navScoutEnabled = boolFromValue(message.navScoutEnabled or message.scoutActive),
    navLeaderEnabled = boolFromValue(message.navLeaderEnabled or message.killerActive),
    role = toText(message.role),
    outfit = type(message.outfit) == "table" and message.outfit or nil,
    x = p.x,
    y = p.y,
    z = p.z,
    location = getLocationString(p),
    map = toText(message.map or BOTSERVER_MINIMAP_FILE),
    receivedAt = currentMillis()
  }
end

function rememberGuildLocation(messageName, message)
  local info = parseGuildLocationPayload(messageName, message)
  if not info or info.name == "" then return false end
  vBot.BotServerGuildLocations = vBot.BotServerGuildLocations or {}
  vBot.BotServerGuildLocations[info.name] = info
  return true
end

local lastGuildPositionSignature = ""
local lastGuildPositionPayloadSignature = ""
local lastGuildPositionSentAt = 0

function sendGuildPosition(force)
  if config.locations ~= true then return false end
  local p = getPlayerPositionSafe()
  if not p then return false end
  local vocationInfo = getBotServerVocationInfo()
  local roleInfo = getBotServerRolePayload()
  local combatInfo = getBotServerCombatInfo()
  local playerName = safePlayerCall("getName", getPlayerNameFallback())
  local level = safePlayerCall("getLevel", 0)
  local health = safePlayerCall("getHealth", 0)
  local maxHealth = safePlayerCall("getMaxHealth", 0)
  local outfit = getPlayerOutfitSafe()
  local tm = currentMillis()
  local positionSignature = getPositionSignature(p)
  local payloadSignature = table.concat({
    toText(playerName),
    toText(level),
    positionSignature,
    toText(vocationInfo.value),
    toText(vocationInfo.key),
    tostring(health),
    tostring(maxHealth),
    tostring(combatInfo.underPkAttack),
    tostring(combatInfo.targetPlayer),
    toText(combatInfo.pkAttackerNames),
    toText(combatInfo.targetName),
    tostring(roleInfo.scoutActive),
    tostring(roleInfo.killerActive),
    getOutfitSignature(outfit)
  }, ":")

  local payload = {
    name = playerName,
    level = level,
    vocation = vocationInfo.value,
    vocationRaw = vocationInfo.raw,
    vocationKey = vocationInfo.key,
    vocationLabel = vocationInfo.label,
    health = health,
    maxHealth = maxHealth,
    alive = combatInfo.alive,
    dead = combatInfo.dead,
    underPkAttack = combatInfo.underPkAttack,
    pkAttackers = combatInfo.pkAttackers,
    pkAttackerNames = combatInfo.pkAttackerNames,
    targetPlayer = combatInfo.targetPlayer,
    targetName = combatInfo.targetName,
    targetSkull = combatInfo.targetSkull,
    outfit = outfit,
    x = p.x,
    y = p.y,
    z = p.z,
    position = p,
    location = getLocationString(p),
    map = BOTSERVER_MINIMAP_FILE,
    scoutActive = roleInfo.scoutActive,
    killerActive = roleInfo.killerActive,
    navScoutEnabled = roleInfo.navScoutEnabled,
    navLeaderEnabled = roleInfo.navLeaderEnabled,
    role = roleInfo.role,
    sentAt = currentMillis()
  }

  rememberGuildLocation(payload.name, payload)

  if force ~= true and lastGuildPositionSentAt > 0 then
    local elapsed = tm - lastGuildPositionSentAt
    local moved = positionSignature ~= lastGuildPositionSignature
    if payloadSignature == lastGuildPositionPayloadSignature and elapsed < BOTSERVER_POSITION_KEEPALIVE_MS then
      return false
    end
    if moved and elapsed < BOTSERVER_POSITION_MOVE_INTERVAL_MS then
      return false
    end
  end

  lastGuildPositionSignature = positionSignature
  lastGuildPositionPayloadSignature = payloadSignature
  lastGuildPositionSentAt = tm

  return sendBotServerMessage(BOTSERVER_GUILD_POSITION_TOPIC, payload)
end

function getOwnVocation()
  local info = getBotServerVocationInfo()
  return info.value
end

function formatVocation(value)
  return shortVocationLabel(value)
end

function getCreatureByPlayerName(playerName)
  if type(getPlayerByName) == "function" then
    local ok, creature = pcall(function() return getPlayerByName(playerName) end)
    if ok and creature then return creature end
  end

  if type(getCreatureByName) == "function" then
    local ok, creature = pcall(function() return getCreatureByName(playerName) end)
    if ok and creature then return creature end
  end

  return nil
end

function applyVocationText(playerName, vocation)
  if config.outfit ~= true then return end
  if not playerName or not vocation then return end

  local creature = getCreatureByPlayerName(playerName)
  if not creature or not creature.setText then return end

  pcall(function()
    creature:setText("\n" .. formatVocation(vocation) .. "\n")
  end)
end

function clearKnownVocationText()
  if type(vBot.BotServerMembers) ~= "table" then return end

  for playerName, _ in pairs(vBot.BotServerMembers) do
    local creature = getCreatureByPlayerName(playerName)
    if creature and creature.setText then
      pcall(function() creature:setText("") end)
    end
  end
end

function sendOwnVocation()
  if config.autoVoc ~= true then return end
  sendBotServerMessage("voc", getOwnVocation())
end

function getManaPercentSafe()
  if type(manapercent) ~= "function" then return 0 end
  local ok, value = pcall(manapercent)
  if ok and value ~= nil then return value end
  return 0
end

ensureBotServerConnected()

vBot.BotServerMembers = vBot.BotServerMembers or {}
vBot.BotServerGuildLocations = vBot.BotServerGuildLocations or {}

function formatGuildLocationAge(receivedAt)
  local age = math.max(0, math.floor((currentMillis() - (tonumber(receivedAt) or 0)) / 1000))
  if age <= 1 then return "agora" end
  if age < 60 then return tostring(age) .. "s" end
  return tostring(math.floor(age / 60)) .. "m"
end

local botServerRadarPins = {}
local botServerRadarLastFloor = nil
local botServerRadarLastCameraSignature = ""
local botServerRadarLastRepositionAt = 0
local botServerRadarCleanedOrphans = false

function getMinimapWidget()
  if modules and modules.game_minimap and modules.game_minimap.minimapWidget then
    return modules.game_minimap.minimapWidget
  end
  return nil
end

function getRadarWidgetId(name)
  local value = toText(name):lower():gsub("[^%w_%-]+", "_")
  if value == "" then value = "unknown" end
  return BOTSERVER_RADAR_WIDGET_ID_PREFIX .. value
end

function getWidgetIdSafe(widget)
  if not widget or not widget.getId then return "" end
  local ok, value = pcall(function() return widget:getId() end)
  if ok and value then return toText(value) end
  return ""
end

function getWidgetTooltipSafe(widget)
  if not widget or not widget.getTooltip then return "" end
  local ok, value = pcall(function() return widget:getTooltip() end)
  if ok and value then return toText(value) end
  return ""
end

function isTrackedRadarWidget(widget)
  for _, pin in pairs(botServerRadarPins or {}) do
    if pin == widget then return true end
  end
  return false
end

function isBotServerRadarWidget(widget)
  if not widget then return false end
  if widget.botServerGuildPin == true then return true end
  if widget.botServerGuildInfo ~= nil then return true end
  if widget.botServerRadarVisualSignature ~= nil then return true end
  if widget.botServerRadarPositionSignature ~= nil then return true end
  if type(widget.name) == "string" and vBot.BotServerGuildLocations and vBot.BotServerGuildLocations[widget.name] then return true end

  local widgetId = getWidgetIdSafe(widget)
  if widgetId:sub(1, #BOTSERVER_RADAR_WIDGET_ID_PREFIX) == BOTSERVER_RADAR_WIDGET_ID_PREFIX then return true end

  local tooltip = getWidgetTooltipSafe(widget)
  local hasPosition = tooltip:find("%d+,%s*%d+,%s*%d+") ~= nil
  local hasSeparator = tooltip:find(" | ", 1, true) ~= nil
  local hasVocation = tooltip:find("Knight", 1, true) ~= nil
    or tooltip:find("Paladin", 1, true) ~= nil
    or tooltip:find("Druid", 1, true) ~= nil
    or tooltip:find("Sorcerer", 1, true) ~= nil
  return hasPosition and hasSeparator and hasVocation
end

function cleanupGuildRadarWidgets(parent, keepTracked)
  if not parent or not parent.getChildren then return end

  local function scan(widget, depth)
    if not widget or depth > 6 then return end

    if widget ~= parent and isBotServerRadarWidget(widget) and (keepTracked ~= true or not isTrackedRadarWidget(widget)) then
      if widget.destroy then pcall(function() widget:destroy() end) end
      return
    end

    if widget.getChildren then
      local ok, children = pcall(function() return widget:getChildren() end)
      if ok and type(children) == "table" then
        for _, child in ipairs(children) do scan(child, depth + 1) end
      end
    end
  end

  scan(parent, 0)
end

function getRadarPinColor(info)
  local key = vocationKeyFromValue(info and (info.vocationKey or info.vocation))
  if key == "knight" then return "#8f969a" end
  if key == "druid" then return "#21b45b" end
  if key == "paladin" then return "#f2c94c" end
  if key == "sorcerer" then return "#e54848" end
  return "#b8c2cc"
end

function getRadarPinBorderColor(info)
  if boolFromValue(info and (info.underPkAttack or info.targetPlayer)) then return "#ffffff" end
  if boolFromValue(info and (info.leader or info.highlighted)) then return "#58a6ff" end
  return "#2a1600"
end

function applyRadarPinMarker(pin, info)
  if not pin then return end
  local leader = boolFromValue(info and (info.leader or info.highlighted))

  if leader then
    pcall(function() if pin.setText then pin:setText("Ã¢Ëœâ€¦") end end)
    pcall(function() if pin.setColor then pin:setColor(getRadarPinColor(info)) end end)
    pcall(function() if pin.setBackgroundColor then pin:setBackgroundColor("#00000000") end end)
    pcall(function() if pin.setSize then pin:setSize({ width = 18, height = 18 }) end end)
    pcall(function() if pin.setBorderWidth then pin:setBorderWidth(0) end end)
  else
    pcall(function() if pin.setText then pin:setText("") end end)
    pcall(function() if pin.setSize then pin:setSize({ width = 10, height = 10 }) end end)
    pcall(function() if pin.setBorderWidth then pin:setBorderWidth(1) end end)
  end
end

function isLocalPlayerDead()
  if safePlayerCall("getHealth", 0) <= 0 then return true end
  if player and type(player.isDead) == "function" then
    local ok, value = pcall(function() return player:isDead() end)
    if ok and value == true then return true end
  end
  return false
end

function destroyGuildRadarMarks()
  for _, widget in pairs(botServerRadarPins or {}) do
    if widget and widget.destroy then
      pcall(function() widget:destroy() end)
    end
  end
  botServerRadarPins = {}
  cleanupGuildRadarWidgets(getMinimapWidget(), false)
  botServerRadarLastFloor = nil
  botServerRadarLastCameraSignature = ""
  botServerRadarLastRepositionAt = 0
  botServerRadarCleanedOrphans = false
end

function focusMinimapOnGuildLocation(info)
  local minimap = getMinimapWidget()
  if not minimap or not info then return false end
  local p = normalizePosition(info)
  if not p then return false end

  pcall(function()
    if minimap.setCameraPosition then
      minimap:setCameraPosition({ x = p.x, y = p.y, z = p.z })
    end
  end)
  return true
end

function getGuildRadarTooltip(name, info)
  local suffix = ""
  if boolFromValue(info and (info.underPkAttack or info.targetPlayer)) then
    suffix = suffix .. " | PK"
  end
  if boolFromValue(info and (info.leader or info.highlighted)) then
    suffix = suffix .. " | Leader"
  end
  if boolFromValue(info and info.caller) then
    suffix = suffix .. " | Caller"
  end
  return string.format(
    "%s | %s | %s | %s",
    toText(name),
    getLocationString(info),
    fullVocationLabel(info.vocationKey or info.vocation),
    formatGuildLocationAge(info.receivedAt)
  ) .. suffix
end

function ensureGuildRadarPin(name, info, minimap)
  local pin = botServerRadarPins[name]
  local destroyed = false
  if pin and pin.isDestroyed then
    local ok, value = pcall(function() return pin:isDestroyed() end)
    destroyed = ok and value == true
  end

  if pin and not destroyed then return pin end
  if not g_ui or type(g_ui.createWidget) ~= "function" then return nil end

  local ok, widget = pcall(function()
    return g_ui.createWidget("BotServerGuildMiniPin", minimap)
  end)
  if not ok or not widget then return nil end

  pcall(function() widget:setId(getRadarWidgetId(name)) end)
  widget.botServerGuildPin = true
  widget.name = name
  widget.botServerGuildInfo = info
  widget.onMouseRelease = function(pinWidget, _, button)
    if button == 1 or button == MouseLeftButton then
      focusMinimapOnGuildLocation(pinWidget and pinWidget.botServerGuildInfo or info)
      return true
    end
    return false
  end

  botServerRadarPins[name] = widget
  return widget
end

function updateGuildRadarMarks()
  if config.locations ~= true or config.radarMarks ~= true then
    destroyGuildRadarMarks()
    return
  end

  if isLocalPlayerDead() then
    destroyGuildRadarMarks()
    return
  end

  local minimap = getMinimapWidget()
  if not minimap or not minimap.centerInPosition then
    destroyGuildRadarMarks()
    return
  end

  if botServerRadarCleanedOrphans ~= true then
    cleanupGuildRadarWidgets(minimap, true)
    botServerRadarCleanedOrphans = true
  end

  local camera = nil
  if minimap.getCameraPosition then
    local ok, value = pcall(function() return minimap:getCameraPosition() end)
    if ok then camera = normalizePosition(value) end
  end

  local cameraFloor = camera and tonumber(camera.z) or nil
  local floorChanged = botServerRadarLastFloor ~= cameraFloor
  botServerRadarLastFloor = cameraFloor
  local cameraSignature = camera and getPositionSignature(camera) or "none"
  local cameraChanged = botServerRadarLastCameraSignature ~= cameraSignature
  botServerRadarLastCameraSignature = cameraSignature
  local tm = currentMillis()
  local refreshPositions = cameraChanged or (tm - botServerRadarLastRepositionAt >= BOTSERVER_RADAR_REPOSITION_INTERVAL_MS)
  if refreshPositions then botServerRadarLastRepositionAt = tm end

  local seen = {}
  for name, info in pairs(vBot.BotServerGuildLocations or {}) do
    local p = normalizePosition(info)
    if p and not boolFromValue(info.dead) then
      seen[name] = true
      local pin = ensureGuildRadarPin(name, info, minimap)
      if pin then
        pin.botServerGuildInfo = info
        local sameFloor = not camera or tonumber(camera.z) == tonumber(p.z)
        local positionSignature = tostring(p.x) .. ":" .. tostring(p.y) .. ":" .. tostring(p.z)
        local visualSignature = table.concat({
          positionSignature,
          tostring(info.vocationKey or info.vocation or ""),
          tostring(info.underPkAttack or ""),
          tostring(info.targetPlayer or ""),
          tostring(info.leader or info.highlighted or ""),
          tostring(info.caller or ""),
          tostring(info.receivedAt or "")
        }, ":")

        if pin.botServerRadarVisualSignature ~= visualSignature then
          pin.botServerRadarVisualSignature = visualSignature
          pcall(function() pin:setTooltip(getGuildRadarTooltip(name, info)) end)
          pcall(function() pin:setBackgroundColor(getRadarPinColor(info)) end)
          pcall(function() pin:setBorderColor(getRadarPinBorderColor(info)) end)
          applyRadarPinMarker(pin, info)
        end

        if pin.botServerRadarVisible ~= sameFloor or floorChanged then
          pin.botServerRadarVisible = sameFloor
          pcall(function() pin:setVisible(sameFloor) end)
        end

        if sameFloor and (refreshPositions or pin.botServerRadarPositionSignature ~= positionSignature) then
          pin.botServerRadarPositionSignature = positionSignature
          pcall(function() pin:breakAnchors() end)
          pcall(function() minimap:centerInPosition(pin, { x = p.x, y = p.y, z = p.z }) end)
          pcall(function() pin:raise() end)
        end
      end
    end
  end

  for name, widget in pairs(botServerRadarPins or {}) do
    if not seen[name] then
      if widget and widget.destroy then pcall(function() widget:destroy() end) end
      botServerRadarPins[name] = nil
    end
  end
end

local botServerMapOutfitWidgets = botServerMapOutfitWidgets or {}

function destroyMapOutfitWidgets()
  for name, data in pairs(botServerMapOutfitWidgets or {}) do
    if data and data.widget and data.widget.destroy then
      pcall(function() data.widget:destroy() end)
    end
    botServerMapOutfitWidgets[name] = nil
  end
end

function updateMapOutfitWidgets()
  if config.locations ~= true or config.mapOutfits ~= true then
    destroyMapOutfitWidgets()
    return
  end

  if isLocalPlayerDead() then
    destroyMapOutfitWidgets()
    return
  end

  local minimap = getMinimapWidget()
  if not minimap or not minimap.centerInPosition then
    destroyMapOutfitWidgets()
    return
  end

  local camera = nil
  if minimap.getCameraPosition then
    local ok, value = pcall(function() return minimap:getCameraPosition() end)
    if ok then camera = normalizePosition(value) end
  end
  if not camera then return end

  local seen = {}
  local tm = currentMillis()
  for name, info in pairs(vBot.BotServerGuildLocations or {}) do
    local p = normalizePosition(info)
    local outfit = type(info.outfit) == "table" and info.outfit or nil
    if p and outfit and not boolFromValue(info.dead) and tm - (tonumber(info.receivedAt) or 0) < 10000 then
      seen[name] = true
      local data = botServerMapOutfitWidgets[name]
      if not data or not data.widget then
        local ok, widget = pcall(function() return g_ui.createWidget("UICreature") end)
        if ok and widget then
          pcall(function() widget:setSize({ width = 60, height = 60 }) end)
          pcall(function() widget:setPhantom(true) end)
          pcall(function() widget:setFocusable(false) end)
          pcall(function() minimap:insertChild(1, widget) end)
          local label = nil
          pcall(function()
            label = g_ui.createWidget("UILabel", widget)
            label:setColor("#00FF00")
            label:setFont("verdana-11px-rounded")
            label:setTextAutoResize(true)
            label:addAnchor(6, "parent", 6)
            label:addAnchor(2, "parent", 1)
          end)
          data = { widget = widget, label = label, signature = "" }
          botServerMapOutfitWidgets[name] = data
        end
      end

      if data and data.widget then
        local diffZ = tonumber(camera.z) - tonumber(p.z)
        local diffText = tostring(diffZ)
        if diffZ > 0 then diffText = "+" .. diffText end
        local renderPos = { x = p.x, y = p.y, z = camera.z }
        local signature = table.concat({
          tostring(p.x), tostring(p.y), tostring(p.z), tostring(camera.z),
          tostring(outfit.type or outfit.lookType or outfit[1] or ""),
          tostring(outfit.head or outfit.lookHead or ""),
          tostring(outfit.body or outfit.lookBody or ""),
          tostring(outfit.legs or outfit.lookLegs or ""),
          tostring(outfit.feet or outfit.lookFeet or "")
        }, ":")

        if data.signature ~= signature then
          data.signature = signature
          pcall(function() data.widget:setOutfit(outfit) end)
          pcall(function() data.widget:setTooltip(toText(name)) end)
          if data.label then
            pcall(function() data.label:setText(toText(name) .. " (" .. diffText .. ")") end)
          end
        elseif data.label then
          pcall(function() data.label:setText(toText(name) .. " (" .. diffText .. ")") end)
        end

        pcall(function() data.widget.pos = renderPos end)
        pcall(function() minimap:centerInPosition(data.widget, renderPos) end)
      end
    end
  end

  for name, data in pairs(botServerMapOutfitWidgets or {}) do
    if not seen[name] then
      if data and data.widget and data.widget.destroy then pcall(function() data.widget:destroy() end) end
      botServerMapOutfitWidgets[name] = nil
    end
  end
end

local comboTargetId = nil
local lastComboTargetSentSignature = ""
local comboConnectedMembers = comboConnectedMembers or {}

function isDashboardCaller()
  local playerName = safePlayerCall("getName", getPlayerNameFallback())
  local info = vBot.BotServerGuildLocations and vBot.BotServerGuildLocations[playerName] or nil
  return boolFromValue(info and info.caller)
end

function isGuildInfoCaller(playerName)
  local info = vBot.BotServerGuildLocations and vBot.BotServerGuildLocations[playerName] or nil
  return boolFromValue(info and info.caller)
end

function getCreatureTextSafe(creature)
  if creature and type(creature.getText) == "function" then
    local ok, value = pcall(function() return creature:getText() end)
    if ok then return toText(value) end
  end
  return ""
end

function getComboCreatureVoc(creature)
  local text = getCreatureTextSafe(creature):upper()
  if text:find("EK", 1, true) then return "EK" end
  if text:find("ED", 1, true) then return "ED" end
  if text:find("MS", 1, true) then return "MS" end
  if text:find("RP", 1, true) then return "RP" end
  return nil
end

function getComboCreatureLevel(creature)
  local value = getCreatureTextSafe(creature):match("%d+")
  return tonumber(value) or 0
end

function canShootCreature(creature)
  local p = getCreaturePositionSafe(creature)
  if not p or not g_map or type(g_map.getTile) ~= "function" then return false end
  local ok, tile = pcall(function() return g_map.getTile(p) end)
  if not ok or not tile or type(tile.canShoot) ~= "function" then return false end
  local okShoot, canShoot = pcall(function() return tile:canShoot() end)
  return okShoot and canShoot == true
end

function canSeeCreatureForAttack(creature)
  if not canShootCreature(creature) then return false end
  local ownPos = getPlayerPositionSafe()
  local targetPos = getCreaturePositionSafe(creature)
  if not ownPos or not targetPos or ownPos.z ~= targetPos.z then return false end

  if g_map and type(g_map.isSightClear) == "function" then
    local ok, clear = pcall(function() return g_map.isSightClear(ownPos, targetPos, true) end)
    if ok then return clear ~= false end
    ok, clear = pcall(function() return g_map.isSightClear(ownPos, targetPos) end)
    if ok then return clear ~= false end
  end

  return true
end

function comboCreatureAllowedByVoc(creature)
  local voc = getComboCreatureVoc(creature)
  if not voc then return true end
  local cfg = comboSettings.voc and comboSettings.voc[voc] or nil
  return not cfg or cfg.enabled ~= false
end

function isEnemyGuildCreature(creature)
  if not creature or type(creature.isPlayer) ~= "function" then return false end
  local okPlayer, isPlayer = pcall(function() return creature:isPlayer() end)
  if not okPlayer or isPlayer ~= true then return false end
  if creature == player then return false end
  if type(creature.getEmblem) ~= "function" then return false end
  local ok, emblem = pcall(function() return creature:getEmblem() end)
  return ok and tonumber(emblem) == 2
end

function comboCreatureSort(a, b)
  if comboSettings.useOrder then
    local maxIndex = #comboSettings.enemyList + 1
    local indexA = tableFindCI(comboSettings.enemyList, getCreatureNameSafe(a)) or maxIndex
    local indexB = tableFindCI(comboSettings.enemyList, getCreatureNameSafe(b)) or maxIndex
    if indexA ~= indexB then return indexA < indexB end
  end

  if comboSettings.useVoc then
    local vocA = getComboCreatureVoc(a)
    local vocB = getComboCreatureVoc(b)
    local prioA = vocA and comboSettings.voc[vocA] and tonumber(comboSettings.voc[vocA].prio) or nil
    local prioB = vocB and comboSettings.voc[vocB] and tonumber(comboSettings.voc[vocB].prio) or nil
    if prioA and prioB and prioA ~= prioB then return prioA < prioB end
  end

  if comboSettings.useLevel then
    local levelA = getComboCreatureLevel(a)
    local levelB = getComboCreatureLevel(b)
    if levelA ~= levelB then
      if comboSettings.levelDesc then return levelA > levelB end
      return levelA < levelB
    end
  end

  local ownPos = getPlayerPositionSafe()
  local posA = getCreaturePositionSafe(a)
  local posB = getCreaturePositionSafe(b)
  if ownPos and posA and posB and type(getDistanceBetween) == "function" then
    return getDistanceBetween(posA, ownPos) < getDistanceBetween(posB, ownPos)
  end
  return getCreatureNameSafe(a) < getCreatureNameSafe(b)
end

function findComboTarget()
  local enemies = {}
  local added = {}

  for _, enemyName in ipairs(comboSettings.enemyList or {}) do
    local creature = getCreatureByPlayerName(enemyName)
    local name = creature and getCreatureNameSafe(creature) or ""
    if creature and name ~= "" and not added[name:lower()] and canShootCreature(creature) and comboCreatureAllowedByVoc(creature) then
      added[name:lower()] = true
      table.insert(enemies, creature)
    end
  end

  if comboSettings.enemyGuild == true then
    for _, creature in ipairs(getSpectatorsSafe()) do
      local name = getCreatureNameSafe(creature)
      if name ~= "" and not added[name:lower()] and isEnemyGuildCreature(creature) and canShootCreature(creature) and comboCreatureAllowedByVoc(creature) then
        added[name:lower()] = true
        table.insert(enemies, creature)
      end
    end
  end

  if #enemies == 0 then return nil end
  table.sort(enemies, comboCreatureSort)
  return enemies[1]
end

function getCreatureByIdSafe(id)
  if not id then return nil end
  if type(getCreatureById) == "function" then
    local ok, creature = pcall(function() return getCreatureById(id) end)
    if ok then return creature end
  end
  return nil
end

function attackCreatureSafe(creature)
  if not creature or not g_game or type(g_game.attack) ~= "function" then return false end
  local ok = pcall(function() g_game.attack(creature) end)
  return ok == true
end

function getCreatureIdValueSafe(creature)
  if not creature or type(creature.getId) ~= "function" then return nil end
  local ok, id = pcall(function() return creature:getId() end)
  if ok and id then return id end
  return nil
end

function positionDistanceSafe(a, b)
  a = normalizePosition(a)
  b = normalizePosition(b)
  if not a or not b or a.z ~= b.z then return 999999 end
  return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y))
end

local attackComboTargetInfo = nil
local lastAttackComboTargetSentSignature = ""
local lastAttackComboTargetSentAt = 0

function resolveAttackComboTarget(data)
  if type(data) ~= "table" then return nil end

  local targetId = data.id or data.targetId
  local target = getCreatureByIdSafe(targetId)
  if target then return target end

  local targetName = toText(data.targetName or data.name)
  local targetNameLower = targetName:lower()
  local targetPos = normalizePosition(data.position) or normalizePosition({ x = data.x, y = data.y, z = data.z })
  local candidates = {}

  for _, creature in ipairs(getSpectatorsSafe()) do
    local name = getCreatureNameSafe(creature)
    local pos = getCreaturePositionSafe(creature)
    local nameMatches = targetNameLower == "" or name:lower() == targetNameLower
    local dist = targetPos and positionDistanceSafe(pos, targetPos) or 0
    local posMatches = not targetPos or dist <= 2

    if name ~= "" and nameMatches and posMatches then
      table.insert(candidates, {
        creature = creature,
        dist = dist,
        player = isCreaturePlayerSafe(creature)
      })
    end
  end

  if #candidates == 0 and targetNameLower ~= "" then
    for _, creature in ipairs(getSpectatorsSafe()) do
      local name = getCreatureNameSafe(creature)
      if name:lower() == targetNameLower then
        table.insert(candidates, {
          creature = creature,
          dist = targetPos and positionDistanceSafe(getCreaturePositionSafe(creature), targetPos) or 0,
          player = isCreaturePlayerSafe(creature)
        })
      end
    end
  end

  if #candidates == 0 then return nil end
  table.sort(candidates, function(a, b)
    if a.player ~= b.player then return a.player == true end
    if a.dist ~= b.dist then return a.dist < b.dist end
    return getCreatureNameSafe(a.creature) < getCreatureNameSafe(b.creature)
  end)

  return candidates[1].creature
end

function isFriendNameSafe(playerName)
  local friends = storage.playerList and storage.playerList.friendList or {}
  return tableContainsCI(friends, playerName)
end

function isAttackComboFallbackEnemy(creature)
  local creatureName = getCreatureNameSafe(creature)
  if creatureName == "" or isCreatureLocalPlayerSafe(creature) or isFriendNameSafe(creatureName) then return false end
  if tableContainsCI(comboSettings.enemyList, creatureName) then return true end
  if comboSettings.enemyGuild == true and isEnemyGuildCreature(creature) then return true end
  if isTimedSquareVisibleSafe(creature) then return true end
  if getCreatureSkullSafe(creature) > 2 then return true end
  return false
end

function findAttackComboVisibleFallback()
  local ownPos = getPlayerPositionSafe()
  local candidates = {}
  local added = {}

  local function addCandidate(creature)
    if not creature then return end
    local name = getCreatureNameSafe(creature)
    local key = name:lower()
    if name == "" or added[key] then return end
    if not isAttackComboFallbackEnemy(creature) then return end
    if not canSeeCreatureForAttack(creature) then return end

    added[key] = true
    local pos = getCreaturePositionSafe(creature)
    table.insert(candidates, {
      creature = creature,
      druid = getComboCreatureVoc(creature) == "ED",
      dist = ownPos and pos and positionDistanceSafe(ownPos, pos) or 999
    })
  end

  for _, enemyName in ipairs(comboSettings.enemyList or {}) do
    addCandidate(getCreatureByPlayerName(enemyName))
  end

  for _, creature in ipairs(getSpectatorsSafe()) do
    addCandidate(creature)
  end

  if #candidates == 0 then return nil end
  table.sort(candidates, function(a, b)
    if a.druid ~= b.druid then return a.druid == true end
    if a.dist ~= b.dist then return a.dist < b.dist end
    return getCreatureNameSafe(a.creature) < getCreatureNameSafe(b.creature)
  end)

  return candidates[1].creature
end

function attackComboCurrentTarget()
  if config.attackComboEnabled ~= true or not attackComboTargetInfo then return false end
  local target = resolveAttackComboTarget(attackComboTargetInfo)
  if target and not canSeeCreatureForAttack(target) then target = nil end
  if not target then target = findAttackComboVisibleFallback() end
  if not target then return false end

  local currentTarget = getAttackingCreatureSafe()
  if currentTarget ~= target then
    return attackCreatureSafe(target)
  end

  return true
end

function clearAttackComboTarget()
  attackComboTargetInfo = nil
  if g_game and type(g_game.attack) == "function" then
    pcall(function() g_game.attack() end)
  end
end

function sendAttackComboTarget(creature)
  if config.attackComboEnabled ~= true then return false end
  if not isDashboardCaller() then return false end

  local tm = currentMillis()
  if not creature then
    if lastAttackComboTargetSentSignature == "clear" and tm - lastAttackComboTargetSentAt < 800 then
      return false
    end
    lastAttackComboTargetSentSignature = "clear"
    lastAttackComboTargetSentAt = tm
    return sendBotServerMessage(BOTSERVER_ATTACK_COMBO_TOPIC, {
      clear = true,
      caller = safePlayerCall("getName", getPlayerNameFallback()),
      sentAt = tm
    })
  end

  local targetPos = getCreaturePositionSafe(creature)
  local targetName = getCreatureNameSafe(creature)
  local targetId = getCreatureIdValueSafe(creature)
  local hp = getCreatureHealthPercentSafe(creature)
  local signature = table.concat({
    tostring(targetId or ""),
    targetName,
    targetPos and getPositionSignature(targetPos) or "",
    tostring(hp or "")
  }, ":")

  if signature == lastAttackComboTargetSentSignature and tm - lastAttackComboTargetSentAt < 300 then
    return false
  end

  lastAttackComboTargetSentSignature = signature
  lastAttackComboTargetSentAt = tm

  return sendBotServerMessage(BOTSERVER_ATTACK_COMBO_TOPIC, {
    id = targetId,
    targetId = targetId,
    targetName = targetName,
    hp = hp,
    caller = safePlayerCall("getName", getPlayerNameFallback()),
    x = targetPos and targetPos.x or nil,
    y = targetPos and targetPos.y or nil,
    z = targetPos and targetPos.z or nil,
    position = targetPos,
    location = getLocationString(targetPos),
    sentAt = tm
  })
end

function sendComboTarget(creature)
  if not isDashboardCaller() then return false end
  local targetId = nil
  if creature and type(creature.getId) == "function" then
    local ok, id = pcall(function() return creature:getId() end)
    if ok then targetId = id end
  end
  local signature = tostring(targetId or "none")
  if signature == lastComboTargetSentSignature then return false end
  lastComboTargetSentSignature = signature
  return sendBotServerMessage("LeaderTarget", targetId)
end

local lastNavMwTargetSignature = ""
local lastNavMwTargetSentAt = 0

function sendNavMwTarget(creature)
  if config.navMwEnabled ~= true then return false end
  if not isDashboardCaller() then return false end
  if not creature then
    lastNavMwTargetSignature = ""
    return false
  end

  local targetPos = getCreaturePositionSafe(creature)
  if not targetPos then return false end

  local tm = currentMillis()
  local targetName = getCreatureNameSafe(creature)
  local hp = getCreatureHealthPercentSafe(creature)
  local attackerPos = getPlayerPositionSafe()
  local signature = table.concat({
    targetName,
    getPositionSignature(targetPos),
    attackerPos and getPositionSignature(attackerPos) or "",
    tostring(hp or "")
  }, ":")

  if signature == lastNavMwTargetSignature and tm - lastNavMwTargetSentAt < 500 then
    return false
  end

  lastNavMwTargetSignature = signature
  lastNavMwTargetSentAt = tm

  return sendBotServerMessage(BOTSERVER_NAV_MW_TOPIC, {
    kind = "nav_mw_target",
    caller = safePlayerCall("getName", getPlayerNameFallback()),
    targetName = targetName,
    hp = hp,
    attacker = safePlayerCall("getName", getPlayerNameFallback()),
    attackerPosition = attackerPos,
    callerPosition = attackerPos,
    attackerX = attackerPos and attackerPos.x or nil,
    attackerY = attackerPos and attackerPos.y or nil,
    attackerZ = attackerPos and attackerPos.z or nil,
    x = targetPos.x,
    y = targetPos.y,
    z = targetPos.z,
    position = targetPos,
    location = getLocationString(targetPos),
    sentAt = tm
  })
end

function syncComboSettings()
  return sendBotServerMessage("SyncEnemyList", {
    enemyList = comboSettings.enemyList,
    useOrder = comboSettings.useOrder,
    useVoc = comboSettings.useVoc,
    useLevel = comboSettings.useLevel,
    levelDesc = comboSettings.levelDesc,
    enemyGuild = comboSettings.enemyGuild,
    voc = comboSettings.voc
  })
end

local potMembers = potMembers or {}
local lockPotion = lockPotion or {}

function navPotionOwnVoc()
  return navPotionSettings.myVoc or shortComboVocFromValue(getBotServerVocationInfo().key) or "EK"
end

function usePotionOnCreature(itemId, creature)
  itemId = tonumber(itemId) or 0
  if itemId <= 0 or not creature or type(usewith) ~= "function" then return false end
  local ok = pcall(function() usewith(itemId, creature) end)
  return ok == true
end

function loadBotServerIntegratedStyles()
  if not g_ui or type(g_ui.loadUIFromString) ~= "function" then return end
  pcall(function()
    g_ui.loadUIFromString([[
BotServerListItem < Label
  height: 16
  focusable: true
  text-offset: 2 0
  background-color: alpha
  $focus:
    background-color: #00000055

BotServerComboWindow < MainWindow
  text: Combo Settings
  size: 430 315
  @onEscape: self:hide()

  Label
    id: enemyTitle
    text: Inimigos
    anchors.top: parent.top
    anchors.left: parent.left
    width: 170
    text-align: center

  TextList
    id: enemyList
    anchors.top: enemyTitle.bottom
    anchors.left: parent.left
    width: 170
    height: 120
    vertical-scrollbar: enemyScroll

  VerticalScrollBar
    id: enemyScroll
    anchors.top: enemyList.top
    anchors.bottom: enemyList.bottom
    anchors.right: enemyList.right
    step: 14
    pixels-scroll: true

  TextEdit
    id: enemyName
    anchors.top: enemyList.bottom
    anchors.left: enemyList.left
    width: 126
    margin-top: 5

  Button
    id: addEnemy
    text: +
    anchors.top: enemyName.top
    anchors.left: enemyName.right
    anchors.right: enemyList.right
    margin-left: 3

  Button
    id: removeEnemy
    text: Remover
    anchors.top: enemyName.bottom
    anchors.left: enemyList.left
    width: 58
    margin-top: 5

  Button
    id: enemyUp
    text: ^
    anchors.top: removeEnemy.top
    anchors.left: removeEnemy.right
    width: 35
    margin-left: 5

  Button
    id: enemyDown
    text: v
    anchors.top: removeEnemy.top
    anchors.left: enemyUp.right
    width: 35
    margin-left: 5

  Button
    id: syncList
    text: Sync
    anchors.top: removeEnemy.top
    anchors.left: enemyDown.right
    anchors.right: enemyList.right
    margin-left: 5

  Label
    id: modeTitle
    text: Prioridade
    anchors.top: parent.top
    anchors.left: enemyList.right
    anchors.right: parent.right
    margin-left: 16
    text-align: center

  BotSwitch
    id: enemyGuild
    text: Guild inimiga
    anchors.top: modeTitle.bottom
    anchors.left: modeTitle.left
    anchors.right: modeTitle.right
    margin-top: 8

  BotSwitch
    id: useOrder
    text: Ordem da lista
    anchors.top: enemyGuild.bottom
    anchors.left: modeTitle.left
    anchors.right: modeTitle.right
    margin-top: 5

  BotSwitch
    id: useVoc
    text: Por vocacao
    anchors.top: useOrder.bottom
    anchors.left: modeTitle.left
    anchors.right: modeTitle.right
    margin-top: 5

  BotSwitch
    id: useLevel
    text: Por level
    anchors.top: useVoc.bottom
    anchors.left: modeTitle.left
    anchors.right: modeTitle.right
    margin-top: 5

  BotSwitch
    id: levelDesc
    text: Level maior primeiro
    anchors.top: useLevel.bottom
    anchors.left: modeTitle.left
    anchors.right: modeTitle.right
    margin-top: 5

  Label
    id: vocTitle
    text: Voc prio EK ED MS RP
    anchors.top: levelDesc.bottom
    anchors.left: modeTitle.left
    anchors.right: modeTitle.right
    margin-top: 8
    text-align: center

  TextEdit
    id: vocEK
    anchors.top: vocTitle.bottom
    anchors.left: modeTitle.left
    width: 42
    margin-top: 5
    text-align: center

  TextEdit
    id: vocED
    anchors.top: vocEK.top
    anchors.left: vocEK.right
    width: 42
    margin-left: 5
    text-align: center

  TextEdit
    id: vocMS
    anchors.top: vocEK.top
    anchors.left: vocED.right
    width: 42
    margin-left: 5
    text-align: center

  TextEdit
    id: vocRP
    anchors.top: vocEK.top
    anchors.left: vocMS.right
    width: 42
    margin-left: 5
    text-align: center

  Label
    id: callerHint
    text: Caller do dashboard envia target.
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: closeButton.top
    margin-bottom: 10
    text-align: center

  Button
    id: closeButton
    text: Fechar
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    size: 55 21

BotServerPotionWindow < MainWindow
  text: Nav Potion
  size: 430 330
  @onEscape: self:hide()

  Label
    id: myVocLabel
    text: Minha voc
    anchors.top: parent.top
    anchors.left: parent.left
    width: 80

  TextEdit
    id: myVoc
    anchors.top: parent.top
    anchors.left: myVocLabel.right
    width: 55
    text-align: center

  Label
    id: distanceLabel
    text: Distancia
    anchors.top: parent.top
    anchors.left: myVoc.right
    margin-left: 14
    width: 70

  TextEdit
    id: distance
    anchors.top: parent.top
    anchors.left: distanceLabel.right
    width: 45
    text-align: center

  BotSwitch
    id: mpRequestEnabled
    text: Pedir MP
    anchors.top: myVoc.bottom
    anchors.left: parent.left
    width: 110
    margin-top: 8

  Label
    id: mpPercentLabel
    text: MP %
    anchors.top: mpRequestEnabled.top
    anchors.left: mpRequestEnabled.right
    margin-left: 12
    width: 45

  TextEdit
    id: mpPercent
    anchors.top: mpRequestEnabled.top
    anchors.left: mpPercentLabel.right
    width: 45
    text-align: center

  Label
    id: tableHint
    text: Voc | HP% | HP item | MP item
    anchors.top: mpRequestEnabled.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 12
    text-align: center

  TextEdit
    id: hpEK
    anchors.top: tableHint.bottom
    anchors.left: parent.left
    margin-top: 8
    width: 45
    text-align: center
  TextEdit
    id: hpItemEK
    anchors.top: hpEK.top
    anchors.left: hpEK.right
    margin-left: 8
    width: 65
    text-align: center
  TextEdit
    id: mpItemEK
    anchors.top: hpEK.top
    anchors.left: hpItemEK.right
    margin-left: 8
    width: 65
    text-align: center

  TextEdit
    id: hpED
    anchors.top: hpEK.bottom
    anchors.left: parent.left
    margin-top: 6
    width: 45
    text-align: center
  TextEdit
    id: hpItemED
    anchors.top: hpED.top
    anchors.left: hpED.right
    margin-left: 8
    width: 65
    text-align: center
  TextEdit
    id: mpItemED
    anchors.top: hpED.top
    anchors.left: hpItemED.right
    margin-left: 8
    width: 65
    text-align: center

  TextEdit
    id: hpMS
    anchors.top: hpED.bottom
    anchors.left: parent.left
    margin-top: 6
    width: 45
    text-align: center
  TextEdit
    id: hpItemMS
    anchors.top: hpMS.top
    anchors.left: hpMS.right
    margin-left: 8
    width: 65
    text-align: center
  TextEdit
    id: mpItemMS
    anchors.top: hpMS.top
    anchors.left: hpItemMS.right
    margin-left: 8
    width: 65
    text-align: center

  TextEdit
    id: hpRP
    anchors.top: hpMS.bottom
    anchors.left: parent.left
    margin-top: 6
    width: 45
    text-align: center
  TextEdit
    id: hpItemRP
    anchors.top: hpRP.top
    anchors.left: hpRP.right
    margin-left: 8
    width: 65
    text-align: center
  TextEdit
    id: mpItemRP
    anchors.top: hpRP.top
    anchors.left: hpItemRP.right
    margin-left: 8
    width: 65
    text-align: center

  Label
    id: note
    text: Todos do channel podem usar quando ligar.
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: closeButton.top
    margin-bottom: 10
    text-align: center

  Button
    id: closeButton
    text: Fechar
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    size: 55 21
]])
  end)
end

local comboWindow = nil
local potionWindow = nil

function refreshComboWindow()
  if not comboWindow then return end
  if comboWindow.enemyList and comboWindow.enemyList.destroyChildren then
    comboWindow.enemyList:destroyChildren()
    for _, enemyName in ipairs(comboSettings.enemyList or {}) do
      local item = g_ui.createWidget("BotServerListItem", comboWindow.enemyList)
      item:setText(enemyName)
    end
  end
  if comboWindow.enemyGuild then comboWindow.enemyGuild:setOn(comboSettings.enemyGuild == true) end
  if comboWindow.useOrder then comboWindow.useOrder:setOn(comboSettings.useOrder == true) end
  if comboWindow.useVoc then comboWindow.useVoc:setOn(comboSettings.useVoc == true) end
  if comboWindow.useLevel then comboWindow.useLevel:setOn(comboSettings.useLevel == true) end
  if comboWindow.levelDesc then comboWindow.levelDesc:setOn(comboSettings.levelDesc == true) end
  for _, voc in ipairs({"EK", "ED", "MS", "RP"}) do
    local edit = comboWindow["voc" .. voc]
    if edit then edit:setText(tostring(comboSettings.voc[voc] and comboSettings.voc[voc].prio or 1)) end
  end
end

function setupComboWindowHandlers()
  if not comboWindow then return end
  if comboWindow.closeButton then comboWindow.closeButton.onClick = function() comboWindow:hide() end end

  local function addEnemy()
    local text = comboWindow.enemyName and comboWindow.enemyName:getText() or ""
    text = toText(text):gsub("^%s+", ""):gsub("%s+$", "")
    if text ~= "" and not tableContainsCI(comboSettings.enemyList, text) then
      table.insert(comboSettings.enemyList, text)
      if comboWindow.enemyName then comboWindow.enemyName:setText("") end
      refreshComboWindow()
    end
  end

  if comboWindow.addEnemy then comboWindow.addEnemy.onClick = addEnemy end
  if comboWindow.enemyName then
    comboWindow.enemyName.onKeyPress = function(_, keyCode)
      if keyCode == 5 then
        addEnemy()
        return true
      end
      return false
    end
  end
  if comboWindow.removeEnemy then
    comboWindow.removeEnemy.onClick = function()
      local focused = comboWindow.enemyList and comboWindow.enemyList:getFocusedChild()
      if focused then
        tableRemoveValueCI(comboSettings.enemyList, focused:getText())
        refreshComboWindow()
      end
    end
  end
  if comboWindow.enemyUp then
    comboWindow.enemyUp.onClick = function()
      local focused = comboWindow.enemyList and comboWindow.enemyList:getFocusedChild()
      local index = focused and tableFindCI(comboSettings.enemyList, focused:getText())
      if index and index > 1 then
        comboSettings.enemyList[index], comboSettings.enemyList[index - 1] = comboSettings.enemyList[index - 1], comboSettings.enemyList[index]
        refreshComboWindow()
      end
    end
  end
  if comboWindow.enemyDown then
    comboWindow.enemyDown.onClick = function()
      local focused = comboWindow.enemyList and comboWindow.enemyList:getFocusedChild()
      local index = focused and tableFindCI(comboSettings.enemyList, focused:getText())
      if index and index < #comboSettings.enemyList then
        comboSettings.enemyList[index], comboSettings.enemyList[index + 1] = comboSettings.enemyList[index + 1], comboSettings.enemyList[index]
        refreshComboWindow()
      end
    end
  end
  if comboWindow.syncList then comboWindow.syncList.onClick = syncComboSettings end

  if comboWindow.enemyGuild then comboWindow.enemyGuild.onClick = function(w) comboSettings.enemyGuild = not comboSettings.enemyGuild; w:setOn(comboSettings.enemyGuild) end end
  if comboWindow.useOrder then
    comboWindow.useOrder.onClick = function()
      comboSettings.useOrder = true
      comboSettings.useVoc = false
      comboSettings.useLevel = false
      refreshComboWindow()
    end
  end
  if comboWindow.useVoc then
    comboWindow.useVoc.onClick = function(w)
      comboSettings.useVoc = not comboSettings.useVoc
      comboSettings.useOrder = false
      if not comboSettings.useVoc and not comboSettings.useLevel then comboSettings.useOrder = true end
      refreshComboWindow()
    end
  end
  if comboWindow.useLevel then
    comboWindow.useLevel.onClick = function()
      comboSettings.useLevel = not comboSettings.useLevel
      comboSettings.useOrder = false
      if not comboSettings.useVoc and not comboSettings.useLevel then comboSettings.useOrder = true end
      refreshComboWindow()
    end
  end
  if comboWindow.levelDesc then comboWindow.levelDesc.onClick = function(w) comboSettings.levelDesc = not comboSettings.levelDesc; w:setOn(comboSettings.levelDesc) end end

  for _, voc in ipairs({"EK", "ED", "MS", "RP"}) do
    local edit = comboWindow["voc" .. voc]
    if edit then
      edit.onTextChange = function(_, text)
        local value = tonumber(text)
        if value then comboSettings.voc[voc].prio = value end
      end
    end
  end
  refreshComboWindow()
end

function setupPotionWindowHandlers()
  if not potionWindow then return end
  if potionWindow.closeButton then potionWindow.closeButton.onClick = function() potionWindow:hide() end end

  local function bindText(id, tableRef, key, fallback)
    local widget = potionWindow[id]
    if not widget then return end
    widget:setText(tostring(tableRef[key] or fallback or ""))
    widget.onTextChange = function(_, text)
      local numberValue = tonumber(text)
      tableRef[key] = numberValue or toText(text)
    end
  end

  bindText("myVoc", navPotionSettings, "myVoc", "EK")
  bindText("distance", navPotionSettings, "potDistance", 5)
  bindText("mpPercent", navPotionSettings, "mpRequestPercent", 50)
  if potionWindow.mpRequestEnabled then
    potionWindow.mpRequestEnabled:setOn(navPotionSettings.mpRequestEnabled == true)
    potionWindow.mpRequestEnabled.onClick = function(w)
      navPotionSettings.mpRequestEnabled = not navPotionSettings.mpRequestEnabled
      w:setOn(navPotionSettings.mpRequestEnabled)
    end
  end

  for _, voc in ipairs({"EK", "ED", "MS", "RP"}) do
    bindText("hp" .. voc, navPotionSettings, "hp" .. voc, 80)
    bindText("hpItem" .. voc, navPotionSettings, "hpItem" .. voc, 266)
    bindText("mpItem" .. voc, navPotionSettings, "mpItem" .. voc, 268)
  end
end

rootWidget = g_ui and g_ui.getRootWidget and g_ui.getRootWidget()
if rootWidget then
  loadBotServerIntegratedStyles()
  if UI and type(UI.createWindow) == "function" then
    pcall(function()
      comboWindow = UI.createWindow("BotServerComboWindow", rootWidget)
      comboWindow:hide()
      setupComboWindowHandlers()
    end)
    pcall(function()
      potionWindow = UI.createWindow("BotServerPotionWindow", rootWidget)
      potionWindow:hide()
      setupPotionWindowHandlers()
    end)
  end

  local ok, createdWindow = pcall(function()
    return g_ui.createWidget('BotServerWindow', rootWidget)
  end)

  if ok and createdWindow then
    botServerWindow = createdWindow
    botServerWindow:hide()

    local dataPanel = botServerWindow.Data
    local featurePanel = botServerWindow.Features

    if featurePanel and featurePanel.Feature9 then
      local legacyFarmNav = featurePanel.Feature9
      pcall(function() legacyFarmNav:setOn(false) end)
      pcall(function() legacyFarmNav:hide() end)
      pcall(function() legacyFarmNav:setVisible(false) end)
      legacyFarmNav.onClick = nil
      if legacyFarmNav.destroy then
        pcall(function() legacyFarmNav:destroy() end)
      end
    end

    if dataPanel and dataPanel.Channel then
      dataPanel.Channel:setText(storage.BotServerChannel)
      dataPanel.Channel.onTextChange = function(widget, text)
        storage.BotServerChannel = text
        storage.DerpetsonWolfNodeBridge.channel = text
      end
    end

    if dataPanel and dataPanel.Random then
      dataPanel.Random.onClick = function(widget)
        storage.BotServerChannel = DEFAULT_BOTSERVER_CHANNEL
        storage.DerpetsonWolfNodeBridge.channel = storage.BotServerChannel
        if dataPanel.Channel then
          dataPanel.Channel:setText(storage.BotServerChannel)
        end
      end
    end

    if featurePanel and featurePanel.Feature1 then
      featurePanel.Feature1:setOn(config.manaInfo)
      featurePanel.Feature1.onClick = function(widget)
        config.manaInfo = not config.manaInfo
        widget:setOn(config.manaInfo)
      end
    end

    if featurePanel and featurePanel.Feature2 then
      featurePanel.Feature2:setOn(config.mwallInfo)
      featurePanel.Feature2.onClick = function(widget)
        config.mwallInfo = not config.mwallInfo
        widget:setOn(config.mwallInfo)
      end
    end

    if featurePanel and featurePanel.Feature4 then
      featurePanel.Feature4:setOn(config.outfit)
      featurePanel.Feature4.onClick = function(widget)
        config.outfit = not config.outfit
        widget:setOn(config.outfit)
        if config.outfit then
          sendBotServerMessage("voc", "yes")
          for playerName, vocation in pairs(vBot.BotServerMembers) do
            applyVocationText(playerName, vocation)
          end
        else
          clearKnownVocationText()
        end
      end
    end

    if featurePanel and featurePanel.Feature5 then
      featurePanel.Feature5:setOn(config.broadcasts)
      featurePanel.Feature5.onClick = function(widget)
        config.broadcasts = not config.broadcasts
        widget:setOn(config.broadcasts)
      end
    end

    if featurePanel and featurePanel.Feature6 then
      featurePanel.Feature6:setOn(config.locations)
      featurePanel.Feature6.onClick = function(widget)
        config.locations = not config.locations
        widget:setOn(config.locations)
        if config.locations then
          sendGuildPosition(true)
          updateGuildRadarMarks()
        else
          destroyGuildRadarMarks()
          destroyMapOutfitWidgets()
        end
      end
    end

    if featurePanel and featurePanel.Feature7 then
      featurePanel.Feature7:setOn(config.radarMarks)
      featurePanel.Feature7.onClick = function(widget)
        config.radarMarks = not config.radarMarks
        widget:setOn(config.radarMarks)
        if config.radarMarks then
          sendGuildPosition(true)
          updateGuildRadarMarks()
        else
          destroyGuildRadarMarks()
        end
      end
    end

    if featurePanel and featurePanel.Feature8 then
      featurePanel.Feature8:setOn(config.autoVoc)
      featurePanel.Feature8.onClick = function(widget)
        config.autoVoc = not config.autoVoc
        widget:setOn(config.autoVoc)
        if config.autoVoc then
          local detectedNow = probeBotServerVocation("ui")
          local detected = currentDetectedVocation()
          if detectedNow or detected then
            notifyBotServer("Auto Voc ligado: " .. fullVocationLabel(detected or config.detectedVocation))
          else
            notifyBotServer("Auto Voc ligado; aguardando vocacao")
          end
          sendOwnVocation()
          sendCharacterInfo()
          sendGuildPosition(true)
        else
          notifyBotServer("Auto Voc desligado")
        end
      end
    end

    if featurePanel and featurePanel.Feature10 then
      featurePanel.Feature10:setOn(config.navScoutEnabled)
      featurePanel.Feature10.onClick = function(widget)
        config.navScoutEnabled = not config.navScoutEnabled
        if config.navScoutEnabled then
          config.navLeaderEnabled = false
          if featurePanel.Feature11 then featurePanel.Feature11:setOn(false) end
        end
        widget:setOn(config.navScoutEnabled)
        if config.navScoutEnabled then
          notifyBotServer("Nav Scout ligado")
          loadBotServerNav(true)
        else
          notifyBotServer("Nav Scout desligado")
          if not isBotServerNavActive() then stopBotServerNav() end
        end
        sendCharacterInfo()
        sendGuildPosition(true)
        sendTierOrbReport("role_change", 0)
      end
    end

    if featurePanel and featurePanel.Feature11 then
      featurePanel.Feature11:setOn(config.navLeaderEnabled)
      featurePanel.Feature11.onClick = function(widget)
        config.navLeaderEnabled = not config.navLeaderEnabled
        if config.navLeaderEnabled then
          config.navScoutEnabled = false
          if featurePanel.Feature10 then featurePanel.Feature10:setOn(false) end
        end
        widget:setOn(config.navLeaderEnabled)
        if config.navLeaderEnabled then
          notifyBotServer("Nav Leader ligado")
          loadBotServerNav(true)
        else
          notifyBotServer("Nav Leader desligado")
          if not isBotServerNavActive() then stopBotServerNav() end
        end
        sendCharacterInfo()
        sendGuildPosition(true)
        sendTierOrbReport("role_change", 0)
      end
    end

    if featurePanel and featurePanel.Feature12 then
      featurePanel.Feature12:setOn(config.comboEnabled)
      featurePanel.Feature12.onClick = function(widget)
        config.comboEnabled = not config.comboEnabled
        widget:setOn(config.comboEnabled)
        if config.comboEnabled then
          notifyBotServer("Combo ligado")
          syncComboSettings()
        else
          notifyBotServer("Combo desligado")
          if isDashboardCaller() then sendBotServerMessage("LeaderTarget", nil) end
          comboTargetId = nil
        end
      end
    end

    if featurePanel and featurePanel.ComboSetup then
      featurePanel.ComboSetup.onClick = function()
        if not comboWindow then
          notifyBotServer("Combo Setup nao carregou")
          return
        end
        refreshComboWindow()
        comboWindow:show()
        comboWindow:raise()
        comboWindow:focus()
      end
    end

    if featurePanel and featurePanel.Feature14 then
      featurePanel.Feature14:setOn(config.mapOutfits)
      featurePanel.Feature14.onClick = function(widget)
        config.mapOutfits = not config.mapOutfits
        widget:setOn(config.mapOutfits)
        if config.mapOutfits then
          notifyBotServer("Map Outfits ligado")
          sendGuildPosition(true)
          updateMapOutfitWidgets()
        else
          notifyBotServer("Map Outfits desligado")
          destroyMapOutfitWidgets()
        end
      end
    end

    if featurePanel and featurePanel.Feature15 then
      featurePanel.Feature15:setOn(config.navPotionEnabled)
      featurePanel.Feature15.onClick = function(widget)
        config.navPotionEnabled = not config.navPotionEnabled
        widget:setOn(config.navPotionEnabled)
        notifyBotServer(config.navPotionEnabled and "Nav Potion ligado" or "Nav Potion desligado")
      end
    end

    if featurePanel and featurePanel.Feature16 then
      featurePanel.Feature16:setOn(config.navMwEnabled)
      featurePanel.Feature16.onClick = function(widget)
        config.navMwEnabled = not config.navMwEnabled
        widget:setOn(config.navMwEnabled)
        if config.navMwEnabled then
          notifyBotServer("Nav MW ligado")
          loadBotServerNav(true)
        else
          notifyBotServer("Nav MW desligado")
          if not isBotServerNavActive() then stopBotServerNav() end
        end
      end
    end

    if featurePanel and featurePanel.Feature17 then
      featurePanel.Feature17:setOn(config.attackComboEnabled)
      featurePanel.Feature17.onClick = function(widget)
        config.attackComboEnabled = not config.attackComboEnabled
        widget:setOn(config.attackComboEnabled)
        if config.attackComboEnabled then
          notifyBotServer("Attack Combo ligado")
          if isDashboardCaller() then sendAttackComboTarget(getAttackingCreatureSafe()) end
        else
          notifyBotServer("Attack Combo desligado")
          if isDashboardCaller() then sendAttackComboTarget(nil) end
          clearAttackComboTarget()
        end
      end
    end

    if featurePanel and featurePanel.PotionSetup then
      featurePanel.PotionSetup.onClick = function()
        if not potionWindow then
          notifyBotServer("Potion Setup nao carregou")
          return
        end
        setupPotionWindowHandlers()
        potionWindow:show()
        potionWindow:raise()
        potionWindow:focus()
      end
    end

    if featurePanel and featurePanel.TierOrbStart then
      featurePanel.TierOrbStart.onClick = function()
        startTierOrbCollection()
      end
    end

    if featurePanel and featurePanel.Broadcast and featurePanel.broadcastText then
      featurePanel.Broadcast.onClick = function(widget)
        sendBotServerMessage("broadcast", featurePanel.broadcastText:getText())
        featurePanel.broadcastText:setText('')
      end
    end

    if botServerWindow.updateButton then
      botServerWindow.updateButton.onClick = function(widget)
        updateBotServer()
      end
    end

    setUpdateStatusText("v" .. BOTSERVER_VERSION)
  else
    notifyBotServer("Nao foi possivel criar BotServerWindow. Confira BotServer.otui.")
  end
end

function updateStatusText()
  if not botServerWindow or not botServerWindow.Data then return end

  if BotServer and BotServer._websocket then
    if botServerWindow.Data.ServerStatus then
      botServerWindow.Data.ServerStatus:setText("CONNECTED")
    end

    if serverCount and botServerWindow.Data.Members then
      botServerWindow.Data.Members:setText("Members: " .. #serverCount)
      if ServerMembers then
        local text = ""
        local memberRegex = [["([a-z 'A-z-]*)"*]]
        local re = regexMatch(ServerMembers, memberRegex)
        for i = 1, #re do
          if i == 1 then
            text = re[i][2]
          else
            text = text .. "\n" .. re[i][2]
          end
        end
        botServerWindow.Data.Members:setTooltip(text)
      end
    end
  else
    if botServerWindow.Data.ServerStatus then
      botServerWindow.Data.ServerStatus:setText("DISCONNECTED")
    end
    if botServerWindow.Data.Participants then
      botServerWindow.Data.Participants:setText("-")
    end
  end
end

if type(macro) == "function" then
  macro(2000, function()
    ensureBotServerConnected()
    sendBotServerMessage("list")
    updateStatusText()
  end)

  macro(10000, function()
    sendCharacterInfo()
  end)

  macro(5000, function()
    sendTierOrbReport("scan", 0)
  end)

  macro(500, function()
    scanExaltedWolfPosition()
  end)

  macro(300, function()
    sendGuildPosition(false)
    updateGuildRadarMarks()
    updateMapOutfitWidgets()
    if config.navMwEnabled == true and isDashboardCaller() then
      sendNavMwTarget(getAttackingCreatureSafe())
    end
    if config.attackComboEnabled == true and isDashboardCaller() then
      sendAttackComboTarget(getAttackingCreatureSafe())
    end
  end)

  macro(200, function()
    if config.comboEnabled ~= true then return end
    if isDashboardCaller() then
      local currentTarget = getAttackingCreatureSafe()
      if not currentTarget then
        local target = findComboTarget()
        if target then
          attackCreatureSafe(target)
          sendComboTarget(target)
        else
          sendComboTarget(nil)
        end
      else
        sendComboTarget(currentTarget)
      end
      return
    end

    local target = getCreatureByIdSafe(comboTargetId)
    if target then
      local currentTarget = getAttackingCreatureSafe()
      if currentTarget ~= target then attackCreatureSafe(target) end
    end
  end)

  macro(200, function()
    if config.attackComboEnabled ~= true then return end
    if isDashboardCaller() then return end
    attackComboCurrentTarget()
  end)

  macro(1000, function()
    if config.comboEnabled == true then
      sendBotServerMessage("ComboMember", safePlayerCall("getName", getPlayerNameFallback()))
    end
    local changed = false
    for memberName, timestamp in pairs(comboConnectedMembers or {}) do
      if currentMillis() - timestamp >= 10000 then
        comboConnectedMembers[memberName] = nil
        changed = true
      end
    end
    if changed then refreshComboWindow() end
  end)

  macro(1000, function()
    if config.navPotionEnabled ~= true then return end
    sendBotServerMessage("NavPotionReq", { type = "ping", voc = navPotionOwnVoc() })

    for _, creature in ipairs(getSpectatorsSafe()) do
      if creature and isCreaturePlayerSafe(creature) and not isCreatureLocalPlayerSafe(creature) then
        local targetName = getCreatureNameSafe(creature)
        local voc = potMembers[targetName]
        if voc and not lockPotion[targetName] then
          local myPos = getPlayerPositionSafe()
          local targetPos = getCreaturePositionSafe(creature)
          if myPos and targetPos and type(getDistanceBetween) == "function" and getDistanceBetween(myPos, targetPos) <= (tonumber(navPotionSettings.potDistance) or 5) then
            local hp = nil
            if type(creature.getHealthPercent) == "function" then
              local ok, value = pcall(function() return creature:getHealthPercent() end)
              if ok then hp = tonumber(value) end
            end
            local hpEnabled = navPotionSettings["hpEnabled" .. voc] ~= false
            local hpThreshold = tonumber(navPotionSettings["hp" .. voc]) or 80
            local hpItem = tonumber(navPotionSettings["hpItem" .. voc]) or 0
            if hpEnabled and hp and hp <= hpThreshold and hpItem > 0 then
              usePotionOnCreature(hpItem, creature)
              return
            end
          end
        end
      end
    end
  end)

  macro(1000, function()
    if config.navPotionEnabled ~= true then return end
    if navPotionSettings.mpRequestEnabled ~= true then return end
    local manaPercent = nil
    if type(manapercent) == "function" then
      local ok, value = pcall(manapercent)
      if ok then manaPercent = tonumber(value) end
    end
    if manaPercent and manaPercent <= (tonumber(navPotionSettings.mpRequestPercent) or 50) then
      sendBotServerMessage("NavPotionReq", { type = "MP", voc = navPotionOwnVoc() })
    end
  end)

  macro(5000, function()
    probeBotServerVocation("player")
  end)

  local lastMana = 0
  macro(500, function()
    if config.manaInfo then
      local currentMana = getManaPercentSafe()
      if currentMana ~= lastMana then
        lastMana = currentMana
        sendBotServerMessage("mana", {mana = lastMana})
      end
    end
  end)
end

if type(onAddItem) == "function" then
  onAddItem(function(container, slot, item, oldItem)
    handleTierOrbContainerChange("container_add", item, oldItem)
  end)
end

if type(onContainerUpdateItem) == "function" then
  onContainerUpdateItem(function(container, slot, item, oldItem)
    handleTierOrbContainerChange("container_update", item, oldItem)
  end)
end

if type(onRemoveItem) == "function" then
  onRemoveItem(function(container, slot, item)
    if itemIdSafe(item) == TIER_ORB_ITEM_ID then
      sendTierOrbReport("container_remove", 0)
    end
  end)
end

if type(onContainerOpen) == "function" then
  onContainerOpen(function()
    if type(schedule) == "function" then
      schedule(250, function() sendTierOrbReport("container_open", 0) end)
    else
      sendTierOrbReport("container_open", 0)
    end
  end)
end

if type(onContainerClose) == "function" then
  onContainerClose(function()
    if type(schedule) == "function" then
      schedule(250, function() sendTierOrbReport("container_close", 0) end)
    else
      sendTierOrbReport("container_close", 0)
    end
  end)
end

if type(onPlayerPositionChange) == "function" then
  onPlayerPositionChange(function(newPos, oldPos)
    if not newPos then return end
    sendGuildPosition(false)
    updateGuildRadarMarks()
    updateMapOutfitWidgets()
  end)
end

if type(onCreaturePositionChange) == "function" then
  onCreaturePositionChange(function(creature, newPos, oldPos)
    if config.navPotionEnabled ~= true then return end
    if not creature or not isCreaturePlayerSafe(creature) or isCreatureLocalPlayerSafe(creature) then return end
    local creatureName = getCreatureNameSafe(creature)
    if creatureName == "" or not potMembers[creatureName] then return end
    local myPos = getPlayerPositionSafe()
    local targetPos = normalizePosition(newPos)
    if not myPos or not targetPos or type(getDistanceBetween) ~= "function" then return end
    if getDistanceBetween(myPos, targetPos) > (tonumber(navPotionSettings.potDistance) or 5) then return end
    lockPotion[creatureName] = true
    if type(schedule) == "function" then
      schedule(1000, function() lockPotion[creatureName] = false end)
    else
      lockPotion[creatureName] = false
    end
  end)
end

if type(onCreatureHealthPercentChange) == "function" then
  onCreatureHealthPercentChange(function(creature, healthPercent)
    if creature and isExaltedWolfCreature(creature) then
      sendExaltedWolfReport(creature, tonumber(healthPercent) and tonumber(healthPercent) <= 0 and "dead" or "seen", tonumber(healthPercent) and tonumber(healthPercent) <= 0)
    end

    if creature and isCreatureLocalPlayerSafe(creature) and tonumber(healthPercent) and tonumber(healthPercent) <= 0 then
      destroyGuildRadarMarks()
      destroyMapOutfitWidgets()
      sendCharacterInfo()
      sendGuildPosition(true)
    end
  end)
end

if type(onTextMessage) == "function" then
  onTextMessage(function(_, text)
    sendExaltedWolfLootReport(text)
    if toText(text):lower():find("you are dead", 1, true) then
      destroyGuildRadarMarks()
      destroyMapOutfitWidgets()
      sendCharacterInfo()
      sendGuildPosition(true)
    end
  end)
end

probeBotServerVocation("startup")
sendCharacterInfo()
sendGuildPosition(true)
sendTierOrbReport("startup", 0)
updateGuildRadarMarks()

local regex = [["(.*?)"]]
listenBotServer("list", function(name, data)
  if json and type(json.encode) == "function" then
    serverCount = regexMatch(json.encode(data), regex)
    ServerMembers = json.encode(data)
  end
end)

listenBotServer(BOTSERVER_GUILD_POSITION_TOPIC, function(name, message)
  if rememberGuildLocation(name, message) then
    updateGuildRadarMarks()
    updateMapOutfitWidgets()
  end
end)

listenBotServer("ComboMember", function(sender, memberName)
  comboConnectedMembers[toText(memberName ~= nil and memberName or sender)] = currentMillis()
  refreshComboWindow()
end)

listenBotServer("LeaderTarget", function(sender, newTargetId)
  if config.comboEnabled ~= true then return end
  if not isGuildInfoCaller(sender) then return end
  comboTargetId = newTargetId
  if not newTargetId and g_game and type(g_game.attack) == "function" then
    pcall(function() g_game.attack() end)
  end
end)

listenBotServer(BOTSERVER_ATTACK_COMBO_TOPIC, function(sender, data)
  if config.attackComboEnabled ~= true then return end
  if not isGuildInfoCaller(sender) then return end
  if type(data) ~= "table" or data.clear == true then
    clearAttackComboTarget()
    return
  end

  attackComboTargetInfo = data
  attackComboCurrentTarget()
end)

listenBotServer("SyncEnemyList", function(sender, data)
  if type(data) ~= "table" then return end
  if not isGuildInfoCaller(sender) then return end
  if type(data.enemyList) == "table" then comboSettings.enemyList = data.enemyList end
  if data.useOrder ~= nil then comboSettings.useOrder = data.useOrder == true end
  if data.useVoc ~= nil then comboSettings.useVoc = data.useVoc == true end
  if data.useLevel ~= nil then comboSettings.useLevel = data.useLevel == true end
  if data.levelDesc ~= nil then comboSettings.levelDesc = data.levelDesc == true end
  if data.enemyGuild ~= nil then comboSettings.enemyGuild = data.enemyGuild == true end
  if type(data.voc) == "table" then comboSettings.voc = data.voc end
  ensureComboConfig()
  refreshComboWindow()
end)

listenBotServer("NavPotionReq", function(sender, data)
  if config.navPotionEnabled ~= true or type(data) ~= "table" then return end
  if data.voc then potMembers[sender] = toText(data.voc):upper() end
  if data.type ~= "MP" then return end
  if lockPotion[sender] then return end

  local creature = getCreatureByPlayerName(sender)
  if not creature or isCreatureLocalPlayerSafe(creature) then return end
  local myPos = getPlayerPositionSafe()
  local targetPos = getCreaturePositionSafe(creature)
  if not myPos or not targetPos or type(getDistanceBetween) ~= "function" then return end
  if getDistanceBetween(myPos, targetPos) > (tonumber(navPotionSettings.potDistance) or 5) then return end

  local voc = toText(data.voc):upper()
  if voc == "" then return end
  local mpEnabled = navPotionSettings["mpEnabled" .. voc] ~= false
  local mpItem = tonumber(navPotionSettings["mpItem" .. voc]) or 0
  if mpEnabled and mpItem > 0 then usePotionOnCreature(mpItem, creature) end
end)

if type(onAttackingCreatureChange) == "function" then
  onAttackingCreatureChange(function(creature)
    if config.comboEnabled == true and isDashboardCaller() then
      sendComboTarget(creature)
    end
    if config.navMwEnabled == true and isDashboardCaller() then
      sendNavMwTarget(creature)
    end
    if config.attackComboEnabled == true and isDashboardCaller() then
      sendAttackComboTarget(creature)
    end
  end)
end

if ui and ui.botServer then
  ui.botServer.onClick = function(widget)
    if not botServerWindow then
      notifyBotServer("Janela nao carregada")
      return
    end
    botServerWindow:show()
    botServerWindow:raise()
    botServerWindow:focus()
  end
end

if botServerWindow and botServerWindow.closeButton then
  botServerWindow.closeButton.onClick = function(widget)
    botServerWindow:hide()
  end
end

if isBotServerNavActive() then
  loadBotServerNav(true)
end

-- scripts

-- mwalls
config.mwalls = config.mwalls or {}
listenBotServer("mwall", function(name, message)
  if config.mwallInfo and type(message) == "table" then
    local wallPos = message["pos"]
    local duration = tonumber(message["duration"]) or 0
    if wallPos and duration > 0 and (not config.mwalls[wallPos] or config.mwalls[wallPos] < now) then
      config.mwalls[wallPos] = now + duration - 150
    end
  end
end)

if type(onAddThing) == "function" then
  onAddThing(function(tile, thing)
    if config.mwallInfo and tile and thing and thing.isItem and thing:isItem() and thing.getId and thing:getId() == 2129 then
      local tilePos = tile:getPosition()
      local wallPos = tilePos.x .. "," .. tilePos.y .. "," .. tilePos.z
      if not config.mwalls[wallPos] or config.mwalls[wallPos] < now then
        config.mwalls[wallPos] = now + 20000
        sendBotServerMessage("mwall", {pos = wallPos, duration = 20000})
      end
    end
  end)
end

listenBotServer("mana", function(name, message)
  if config.manaInfo and type(message) == "table" then
    local manaValue = tonumber(message["mana"])
    if manaValue and type(getPlayerByName) == "function" then
      local creature = getPlayerByName(name)
      if creature and creature.setManaPercent then
        creature:setManaPercent(manaValue)
      end
    end
  end
end)

-- vocation
if type(onTalk) == "function" then
  onTalk(function(_, _, _, text)
    if config.autoVoc and handleVocationDetectionText(text) then
      sendOwnVocation()
      sendCharacterInfo()
      sendGuildPosition(true)
    end
  end)
end

if type(onTextMessage) == "function" then
  onTextMessage(function(_, text)
    if config.autoVoc and handleVocationDetectionText(text) then
      sendOwnVocation()
      sendCharacterInfo()
      sendGuildPosition(true)
    end
  end)
end

if config.autoVoc then
  sendOwnVocation()
  sendBotServerMessage("voc", "yes")
end

listenBotServer("voc", function(name, message)
  if message == "yes" then
    if config.autoVoc then
      sendOwnVocation()
    end
    return
  end

  vBot.BotServerMembers[name] = message
  applyVocationText(name, message)
end)

-- broadcast
listenBotServer("broadcast", function(name, message)
  if config.broadcasts and type(broadcastMessage) == "function" then
    broadcastMessage(toText(name) .. ": " .. toText(message))
  end
end)

addSeparator()

