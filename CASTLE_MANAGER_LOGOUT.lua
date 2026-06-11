-- ============================================
-- CASTLE MANAGER PRO
-- Protecao Castle 24h com logout seguro
-- Duas areas: CASTLE CIMA e CASTLE BAIXO
-- Setup visual em janela + Auto PZ Tile via comando !pz
--
-- Arquivos recomendados:
-- 1) castle_manager_pro.lua
-- 2) castle_manager_pro.otui
--
-- O .lua tambem carrega a interface embutida por seguranca.
-- ============================================

setDefaultTab("Main")

local CASTLE_MANAGER_SCRIPT_VERSION = 2026061101
local CASTLE_MANAGER_SCRIPT_NAME = "CASTLE_MANAGER_LOGOUT.lua"
local CASTLE_MANAGER_UPDATE_URL = "https://api.github.com/repos/Thesaidctm/script-holidayys/contents/CASTLE_MANAGER_LOGOUT.lua?ref=main"

-- ============================================
-- OTUI EMBUTIDO
-- Mantido aqui para o script funcionar mesmo se o .otui nao for carregado pelo client.
-- O arquivo .otui separado foi gerado com o mesmo conteudo.
-- ============================================

local CASTLE_MANAGER_OTUI = [==[
CastleManagerBotPanel < Panel
  height: 56
  margin-top: 4
  padding: 4
  image-source: /images/ui/panel_flat
  image-border: 5

  BotSwitch
    id: enabled
    anchors.top: parent.top
    anchors.left: parent.left
    width: 130
    height: 20
    text-align: center
    text: Castle Manager

  Button
    id: setup
    anchors.top: enabled.top
    anchors.left: enabled.right
    anchors.right: parent.right
    margin-left: 4
    height: 20
    text: Setup

  Label
    id: status
    anchors.top: enabled.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 4
    height: 13
    text-align: center
    color: #ffd36b
    font: verdana-11px-bold
    text: parado

  Label
    id: subStatus
    anchors.top: status.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 1
    height: 13
    text-align: center
    color: #9fb2c4
    font: verdana-11px
    text: area: -

CastleManagerSectionTitle < Panel
  height: 25
  margin-top: 9
  margin-left: 4
  margin-right: 4

  Label
    id: title
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    margin-top: 2
    height: 16
    text-align: center
    color: #ffcc6e
    font: verdana-11px-bold

  Panel
    id: line
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    margin-left: 22
    margin-right: 22
    height: 1
    background-color: #d39b3b99

CastleManagerTextRow < Panel
  height: 47
  margin-top: 6
  margin-left: 5
  margin-right: 5
  padding: 4
  image-source: /images/ui/panel_flat
  image-border: 5

  Label
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 14
    text-align: center
    color: #e8edf4
    font: verdana-11px-bold

  TextEdit
    id: edit
    anchors.top: title.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 4
    height: 18
    text-align: center

  Label
    id: hint
    anchors.top: edit.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 2
    height: 11
    text-align: center
    color: #8f9bad
    font: verdana-11px

CastleManagerSwitchRow < Panel
  height: 25
  margin-top: 5
  margin-left: 5
  margin-right: 5

  BotSwitch
    id: switch
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: 22
    text-align: center

CastleManagerStatusRow < Panel
  height: 22
  margin-top: 3
  margin-left: 5
  margin-right: 5
  background-color: #101620dd

  Label
    id: left
    anchors.left: parent.left
    anchors.top: parent.top
    margin-left: 5
    margin-top: 3
    width: 92
    color: #d8e0ea
    font: verdana-11px-bold

  Label
    id: value
    anchors.right: parent.right
    anchors.left: left.right
    anchors.top: parent.top
    margin-left: 4
    margin-right: 5
    margin-top: 3
    height: 15
    text-align: right
    color: #ffc66d
    font: verdana-11px-bold

CastleManagerInfoBox < Panel
  height: 44
  margin-top: 6
  margin-left: 5
  margin-right: 5
  padding: 5
  image-source: /images/ui/panel_flat
  image-border: 5

  Label
    id: text
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 33
    text-align: center
    color: #9fb2c4
    font: verdana-11px

CastleManagerWindow < MainWindow
  text: Castle Manager Pro
  size: 560 620
  padding: 11
  @onEscape: self:hide()

  Panel
    id: headerPanel
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: 68
    image-source: /images/ui/panel_flat
    image-border: 5
    padding: 7

    Label
      id: title
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: 18
      text-align: center
      color: #47f4ff
      font: verdana-11px-bold
      text: CASTLE MANAGER PRO

    Label
      id: subtitle
      anchors.top: title.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 3
      height: 15
      text-align: center
      color: #e8edf4
      font: verdana-11px
      text: Protecao Castle 24h + Logout seguro + Auto PZ Tile

    Label
      id: modeStrip
      anchors.top: subtitle.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 3
      height: 15
      text-align: center
      color: #9fb2c4
      font: verdana-11px
      text: Duas areas: CASTLE CIMA / CASTLE BAIXO

  VerticalScrollBar
    id: contentScroll
    anchors.top: headerPanel.bottom
    anchors.right: parent.right
    anchors.bottom: footer.top
    margin-top: 9
    margin-bottom: 8
    margin-right: -9
    step: 28
    pixels-scroll: true

  ScrollablePanel
    id: content
    anchors.top: contentScroll.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: footer.top
    margin-bottom: 8
    vertical-scrollbar: contentScroll

    Panel
      id: left
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.horizontalCenter
      margin-top: 4
      margin-left: 8
      margin-right: 9
      layout:
        type: verticalBox
        fit-children: true

    Panel
      id: right
      anchors.top: parent.top
      anchors.left: parent.horizontalCenter
      anchors.right: parent.right
      margin-top: 4
      margin-left: 9
      margin-right: 8
      layout:
        type: verticalBox
        fit-children: true

    VerticalSeparator
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.left: parent.horizontalCenter

  Panel
    id: footer
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 32

    Button
      id: close
      anchors.right: parent.right
      anchors.top: parent.top
      width: 92
      height: 24
      text: Fechar

]==]

pcall(function()
  if g_ui and g_ui.loadUIFromString then
    g_ui.loadUIFromString(CASTLE_MANAGER_OTUI)
  end
end)

-- ============================================
-- STORAGE / DEFAULTS
-- ============================================

local panelName = "CastleManagerPro"
storage[panelName] = storage[panelName] or {}
local cfg = storage[panelName]

local function applyDefault(key, value)
  if cfg[key] == nil then cfg[key] = value end
end

applyDefault("enabled", true)
applyDefault("debug", true)
applyDefault("usarWhitelist", true)

applyDefault("tempoEsperaDominioMin", 10)
applyDefault("timeoutLogoutMin", 3)
applyDefault("cooldownLogoutMs", 1200)
applyDefault("mobScanRange", 8)

applyDefault("usarCheckPzComando", true)
applyDefault("forcarCheckPzAntesLogout", true)
applyDefault("usarForceCtrlQ", true)
applyDefault("comandoPz", "!pz")
applyDefault("intervaloCheckPzMs", 2500)
applyDefault("tempoMaxSemDescerPzMs", 8000)
applyDefault("maxAguardarRespostaPzMs", 12000)
applyDefault("cooldownAndarPzMs", 1200)
applyDefault("maxTentativasAndarPz", 20)

applyDefault("guildsAliadasText", "Se Ta Doido")
applyDefault("guildsInimigasText", "The End")
applyDefault("autoUpdateEnabled", true)
applyDefault("autoUpdateIntervalSeconds", 600)
applyDefault("autoReloadAfterUpdate", false)

local function ativarTodasFuncoesCastle()
  cfg.debug = true
  cfg.usarWhitelist = true
  cfg.usarCheckPzComando = true
  cfg.forcarCheckPzAntesLogout = true
  cfg.usarForceCtrlQ = true
end

if cfg.enabled == true then
  ativarTodasFuncoesCastle()
end

-- ============================================
-- VARIAVEIS APLICADAS PELO SETUP
-- ============================================

local DEBUG_CASTLE = true
local TEMPO_ESPERA_DOMINIO = 10 * 60
local TIMEOUT_LOGOUT_CASTLE = 3 * 60
local COOLDOWN_LOGOUT_MS = 1200
local REAL_MOB_SCAN_RANGE = 8
local USAR_WHITELIST_AREA_CASTLE = true
local LOGOUT_AGRESSIVO_DOMINIO = true

local USAR_CHECK_PZ_COMANDO = true
local FORCAR_CHECK_PZ_ANTES_LOGOUT = true
local USAR_FORCE_CTRL_Q = true
local COMANDO_PZ = "!pz"
local INTERVALO_CHECK_PZ_MS = 2500
local TEMPO_MAX_SEM_DESCER_PZ_MS = 8000
local MAX_AGUARDAR_RESPOSTA_PZ_MS = 12000
local COOLDOWN_ANDAR_PZ_MS = 1200
local MAX_TENTATIVAS_ANDAR_PZ = 20

local guildsAliadasSet = {}
local guildsInimigasSet = {}

-- ============================================
-- AREAS DO CASTLE
-- ============================================

local CASTLE_AREAS = {
  {
    name = "CASTLE CIMA",
    yMargin = 3,
    zMin = 0,
    zMax = 15,
    points = {
      {x = 38181, y = 36579, z = 7},
      {x = 38225, y = 36955, z = 7},
      {x = 37975, y = 36753, z = 7},
      {x = 38391, y = 36757, z = 7},
    }
  },

  {
    name = "CASTLE BAIXO",
    yMargin = 3,
    zMin = 0,
    zMax = 15,
    points = {
      {x = 1159, y = 1201, z = 7},
      {x = 1507, y = 1161, z = 7},
      {x = 1383, y = 1329, z = 7},
      {x = 1371, y = 1029, z = 7},
    }
  }
}

-- ============================================
-- ESTADOS DO SCRIPT
-- ============================================

local ESTADO_IDLE               = "IDLE"
local ESTADO_AGUARDANDO_DOMINIO = "AGUARDANDO_DOMINIO"
local ESTADO_AGUARDANDO_LOGOUT  = "AGUARDANDO_LOGOUT"
local ESTADO_LOGOUT_SOLICITADO  = "LOGOUT_SOLICITADO"

local estadoCastle = ESTADO_IDLE

local guildInvasoraAtual = nil
local ultimoAvisoInvasao = 0
local castleTimer = 0

local cavebotPausadoPeloScript = false
local cavebotEstavaLigado = false
local targetbotPausadoPeloScript = false
local targetbotEstavaLigado = false

local ultimoLogout = 0
local ultimoLogMobs = 0

-- Controle do sistema !pz
local pzUltimoValor = nil
local pzValorAnterior = nil
local pzUltimaRespostaMs = 0
local pzUltimaConsultaMs = 0
local pzUltimaDescidaMs = 0
local pzPrimeiraConsultaSemRespostaMs = 0
local pzEstaDescendo = false
local pzUltimoMovimentoMs = 0
local pzTentativasMovimento = 0
local pzDirecaoIndex = 1

-- Status visual
local ui = nil
local mainWindow = nil
local statusWidgets = {}
local lastAreaName = "-"
local lastEventText = "Pronto."
local lastPzStatus = "-"
local lastMobStatus = "-"
local lastGuildStatus = "-"
local lastLogoutStatus = "-"
local uiBuilt = false

-- ============================================
-- HELPERS BASICOS
-- ============================================

local function nowMs()
  if now then return now end
  if g_clock and g_clock.millis then return g_clock.millis() end
  return os.time() * 1000
end

local function trim(text)
  if not text then return "" end
  text = tostring(text)
  text = text:gsub("^%s+", "")
  text = text:gsub("%s+$", "")
  return text
end

local function normalizeName(name)
  name = trim(name)
  name = name:lower()
  name = name:gsub("%s+", " ")
  return name
end

local function cmNumber(value, default, minValue, maxValue)
  local n = tonumber(value)
  if not n then n = default end
  if minValue and n < minValue then n = minValue end
  if maxValue and n > maxValue then n = maxValue end
  return n
end

local function parseNameSet(text)
  local set = {}
  text = tostring(text or "")
  text = text:gsub("\r", "\n")
  text = text:gsub("[,;|]", "\n")

  for line in text:gmatch("[^\n]+") do
    local name = normalizeName(line)
    if name ~= "" then set[name] = true end
  end

  return set
end

local function aplicarSetupCastle()
  DEBUG_CASTLE = cfg.debug ~= false
  USAR_WHITELIST_AREA_CASTLE = cfg.usarWhitelist ~= false

  TEMPO_ESPERA_DOMINIO = cmNumber(cfg.tempoEsperaDominioMin, 10, 1, 120) * 60
  TIMEOUT_LOGOUT_CASTLE = cmNumber(cfg.timeoutLogoutMin, 3, 1, 60) * 60
  COOLDOWN_LOGOUT_MS = cmNumber(cfg.cooldownLogoutMs, 1200, 300, 10000)
  REAL_MOB_SCAN_RANGE = cmNumber(cfg.mobScanRange, 8, 1, 20)

  USAR_CHECK_PZ_COMANDO = cfg.usarCheckPzComando ~= false
  FORCAR_CHECK_PZ_ANTES_LOGOUT = cfg.forcarCheckPzAntesLogout ~= false
  USAR_FORCE_CTRL_Q = cfg.usarForceCtrlQ ~= false
  COMANDO_PZ = tostring(cfg.comandoPz or "!pz")
  INTERVALO_CHECK_PZ_MS = cmNumber(cfg.intervaloCheckPzMs, 2500, 1000, 15000)
  TEMPO_MAX_SEM_DESCER_PZ_MS = cmNumber(cfg.tempoMaxSemDescerPzMs, 8000, 3000, 30000)
  MAX_AGUARDAR_RESPOSTA_PZ_MS = cmNumber(cfg.maxAguardarRespostaPzMs, 12000, 3000, 60000)
  COOLDOWN_ANDAR_PZ_MS = cmNumber(cfg.cooldownAndarPzMs, 1200, 500, 10000)
  MAX_TENTATIVAS_ANDAR_PZ = cmNumber(cfg.maxTentativasAndarPz, 20, 1, 100)

  guildsAliadasSet = parseNameSet(cfg.guildsAliadasText)
  guildsInimigasSet = parseNameSet(cfg.guildsInimigasText)
end

aplicarSetupCastle()

local function castleLog(text)
  lastEventText = tostring(text or "")
  if DEBUG_CASTLE and warn then
    warn("[CASTLE] " .. tostring(text))
  end
end

local castleManagerUpdateBusy = false
local castleManagerLastUpdateErrorAt = 0

local function castleManagerEpochSeconds()
  if os and os.time then return os.time() end
  return math.floor(nowMs() / 1000)
end

local function castleManagerUpdateMessage(text)
  local message = "[CASTLE] " .. tostring(text)
  lastEventText = tostring(text or "")

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

local function castleManagerUpdateError(text, force)
  local tm = castleManagerEpochSeconds()
  if force or tm >= castleManagerLastUpdateErrorAt + 3600 then
    castleManagerLastUpdateErrorAt = tm
    castleManagerUpdateMessage(text)
  end
end

local function castleManagerOnce(callback)
  local called = false
  return function(...)
    if called then return end
    called = true
    callback(...)
  end
end

local function castleManagerNormalizeHttpArgs(a, b, c)
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

local function castleManagerBase64Decode(data)
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

local function castleManagerDecodeJsonString(value)
  value = tostring(value or "")
  value = value:gsub("\\n", "")
  value = value:gsub("\\r", "")
  value = value:gsub("\\t", "")
  value = value:gsub("\\/", "/")
  value = value:gsub('\\"', '"')
  value = value:gsub("\\\\", "\\")
  return value
end

local function castleManagerExtractGithubApiScript(data)
  if type(data) ~= "string" or not data:find('"content"%s*:', 1) then return nil end
  if not data:find('"encoding"%s*:%s*"base64"', 1) then return nil end

  local encoded = data:match('"content"%s*:%s*"(.-)"')
  if not encoded then return nil end

  return castleManagerBase64Decode(castleManagerDecodeJsonString(encoded))
end

local function castleManagerHttpGet(url, callback)
  local done = castleManagerOnce(callback)
  local httpCandidates = {}
  if type(HTTP) == "table" then table.insert(httpCandidates, HTTP) end
  if type(g_http) == "table" then table.insert(httpCandidates, g_http) end
  if modules and modules.corelib and type(modules.corelib.HTTP) == "table" then table.insert(httpCandidates, modules.corelib.HTTP) end
  if modules and modules._G and type(modules._G.HTTP) == "table" then table.insert(httpCandidates, modules._G.HTTP) end

  for _, http in ipairs(httpCandidates) do
    if type(http) == "table" and type(http.get) == "function" then
      local ok = pcall(function()
        local response = http.get(url, function(a, b, c)
          local data, err = castleManagerNormalizeHttpArgs(a, b, c)
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

local function castleManagerScriptPath()
  local config = ""
  if type(configName) == "string" and configName ~= "" then
    config = configName
  elseif type(botConfigName) == "string" and botConfigName ~= "" then
    config = botConfigName
  else
    config = "MAGE_FINAL"
  end
  return "/bot/" .. config .. "/" .. CASTLE_MANAGER_SCRIPT_NAME
end

local function castleManagerExtractScriptVersion(data)
  if type(data) ~= "string" then return nil end
  return tonumber(data:match("CASTLE_MANAGER_SCRIPT_VERSION%s*=%s*(%d+)"))
end

local function castleManagerLooksLikeScript(data)
  return type(data) == "string"
    and #data > 10000
    and data:find("CASTLE MANAGER PRO", 1, true) ~= nil
    and data:find("CastleManagerBotPanel", 1, true) ~= nil
    and castleManagerExtractScriptVersion(data) ~= nil
end

local function castleManagerNormalizeDownloadedScript(data)
  if castleManagerLooksLikeScript(data) then return data end

  local decoded = castleManagerExtractGithubApiScript(data)
  if castleManagerLooksLikeScript(decoded) then return decoded end

  return data
end

local function castleManagerSaveDownloadedScript(data, remoteVersion)
  if type(g_resources) ~= "table" or type(g_resources.writeFileContents) ~= "function" then
    castleManagerUpdateMessage("Nao foi possivel atualizar: g_resources.writeFileContents indisponivel.")
    return false
  end

  local scriptPath = castleManagerScriptPath()
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
    castleManagerUpdateMessage("Falha ao salvar update: " .. tostring(err))
    return false
  end

  cfg.installedScriptVersion = remoteVersion
  castleManagerUpdateMessage("Atualizado para versao " .. tostring(remoteVersion) .. ". Recarregue o bot para aplicar.")

  if cfg.autoReloadAfterUpdate == true and type(schedule) == "function" and type(reload) == "function" then
    schedule(1500, function() reload() end)
  end

  return true
end

local function runCastleManagerAutoUpdate(force)
  if cfg.autoUpdateEnabled ~= true and force ~= true then return false end
  if castleManagerUpdateBusy then
    if force then castleManagerUpdateMessage("Update ja esta em andamento.") end
    return false
  end

  local tm = castleManagerEpochSeconds()
  local interval = cmNumber(cfg.autoUpdateIntervalSeconds, 600, 60, 86400)
  if force ~= true and tm < tonumber(cfg.nextAutoUpdateCheckAt or 0) then return false end

  cfg.nextAutoUpdateCheckAt = tm + interval
  castleManagerUpdateBusy = true

  if force then
    castleManagerUpdateMessage("Checando update no GitHub...")
  end

  castleManagerHttpGet(CASTLE_MANAGER_UPDATE_URL, function(data, err)
    castleManagerUpdateBusy = false
    if err or not data then
      castleManagerUpdateError("Falha ao checar update: " .. tostring(err or "sem dados"), force)
      return
    end

    data = castleManagerNormalizeDownloadedScript(data)
    if not castleManagerLooksLikeScript(data) then
      castleManagerUpdateError("Update ignorado: arquivo remoto invalido.", force)
      return
    end

    local remoteVersion = castleManagerExtractScriptVersion(data)
    if not remoteVersion then
      castleManagerUpdateError("Update ignorado: versao remota ausente.", force)
      return
    end

    cfg.lastRemoteScriptVersion = remoteVersion
    if remoteVersion <= CASTLE_MANAGER_SCRIPT_VERSION then
      if force then castleManagerUpdateMessage("Ja esta na ultima versao: " .. tostring(CASTLE_MANAGER_SCRIPT_VERSION)) end
      return
    end

    castleManagerSaveDownloadedScript(data, remoteVersion)
  end)

  return true
end

CastleManager = CastleManager or {}
CastleManager.checkUpdateNow = function()
  cfg.nextAutoUpdateCheckAt = 0
  return runCastleManagerAutoUpdate(true)
end
checkCastleManagerUpdate = CastleManager.checkUpdateNow

local function safeCall(fn, fallback)
  local ok, result = pcall(fn)
  if ok then return result end
  return fallback
end

-- ============================================
-- GUILDS
-- ============================================

local function tableHasGuild(set, guildName)
  local alvo = normalizeName(guildName)
  if alvo == "" then return false end
  return set[alvo] == true
end

local function isGuildAliada(guildName)
  return tableHasGuild(guildsAliadasSet, guildName)
end

local function isGuildInimiga(guildName)
  return tableHasGuild(guildsInimigasSet, guildName)
end

-- ============================================
-- BOTS
-- ============================================

local function isCavebotOn()
  if not CaveBot then return false end
  if CaveBot.isOn then
    return safeCall(function() return CaveBot.isOn() end, false) == true
  end
  if CaveBot.isOff then
    return safeCall(function() return not CaveBot.isOff() end, false) == true
  end
  return false
end

local function isTargetbotOn()
  if not TargetBot then return false end
  if TargetBot.isOn then
    return safeCall(function() return TargetBot.isOn() end, false) == true
  end
  if TargetBot.isOff then
    return safeCall(function() return not TargetBot.isOff() end, false) == true
  end
  return false
end

local function isCastleManagerLigado()
  return cfg.enabled == true
end

local function retomarCavebotSeNecessario()
  if not CaveBot then return end

  if cavebotPausadoPeloScript and cavebotEstavaLigado then
    if not isCavebotOn() then
      if CaveBot.setOn and safeCall(function() CaveBot.setOn() return true end, false) then
        castleLog("CaveBot retomado pelo Castle_Manager.")
      end
    end
  end
end

local function retomarTargetbotSeNecessario()
  if not TargetBot then return end

  if targetbotPausadoPeloScript and targetbotEstavaLigado then
    if not isTargetbotOn() then
      if TargetBot.setOn and safeCall(function() TargetBot.setOn() return true end, false) then
        castleLog("TargetBot retomado pelo Castle_Manager.")
      end
    end
  end
end

local function resetPzChecker()
  pzUltimoValor = nil
  pzValorAnterior = nil
  pzUltimaRespostaMs = 0
  pzUltimaConsultaMs = 0
  pzUltimaDescidaMs = 0
  pzPrimeiraConsultaSemRespostaMs = 0
  pzEstaDescendo = false
  pzUltimoMovimentoMs = 0
  pzTentativasMovimento = 0
  pzDirecaoIndex = 1
  lastPzStatus = "-"
end

local function resetState(motivo)
  estadoCastle = ESTADO_IDLE
  guildInvasoraAtual = nil
  ultimoAvisoInvasao = 0
  castleTimer = 0

  cavebotPausadoPeloScript = false
  cavebotEstavaLigado = false
  targetbotPausadoPeloScript = false
  targetbotEstavaLigado = false

  ultimoLogout = 0
  ultimoLogMobs = 0

  resetPzChecker()

  lastLogoutStatus = "-"
  lastGuildStatus = "-"
  castleLog("Reset - " .. (motivo or "motivo desconhecido"))
end

local function pausarTargetbotPeloScript()
  if not isCastleManagerLigado() then return false end

  if not TargetBot then
    castleLog("TargetBot nao encontrado.")
    return false
  end

  if not targetbotPausadoPeloScript then
    targetbotPausadoPeloScript = true
    targetbotEstavaLigado = isTargetbotOn()
  end

  if isTargetbotOn() then
    local desligou = false
    if TargetBot.setOff and safeCall(function() TargetBot.setOff() return true end, false) then desligou = true end
    if TargetBot.stop and safeCall(function() TargetBot.stop() return true end, false) then desligou = true end
    if desligou then castleLog("TargetBot pausado pelo Castle_Manager.") end
  end

  return true
end

local function pausarCavebotPeloScript()
  if not isCastleManagerLigado() then return false end

  if not CaveBot then
    castleLog("CaveBot nao encontrado.")
    return false
  end

  if not cavebotPausadoPeloScript then
    cavebotPausadoPeloScript = true
    cavebotEstavaLigado = isCavebotOn()
  end

  if isCavebotOn() then
    local desligou = false
    if CaveBot.setOff and safeCall(function() CaveBot.setOff() return true end, false) then desligou = true end
    if CaveBot.stop and safeCall(function() CaveBot.stop() return true end, false) then desligou = true end
    if CaveBot.setEnabled and safeCall(function() CaveBot.setEnabled(false) return true end, false) then desligou = true end
    if desligou then castleLog("CaveBot pausado pelo Castle_Manager.") end
  end

  return true
end

local function setEnabled(value)
  local enabled = value == true
  cfg.enabled = enabled

  if enabled then
    ativarTodasFuncoesCastle()
    aplicarSetupCastle()
  end

  pcall(function()
    if ui and ui.enabled and ui.enabled.setOn then ui.enabled:setOn(enabled) end
  end)

  pcall(function()
    if mainWindow and mainWindow.enabledToggle and mainWindow.enabledToggle.switch and mainWindow.enabledToggle.switch.setOn then
      mainWindow.enabledToggle.switch:setOn(enabled)
    end
  end)

  if not enabled and (cavebotPausadoPeloScript or targetbotPausadoPeloScript) then
    retomarCavebotSeNecessario()
    retomarTargetbotSeNecessario()
    resetState("Castle_Manager desligado")
  end
end

-- ============================================
-- POSICAO / AREA
-- ============================================

local function getPlayerPos()
  if player and player.getPosition then
    local p = player:getPosition()
    if p and p.x and p.y and p.z then
      return {x = p.x, y = p.y, z = p.z}
    end
  end

  if pos then
    local p = pos()
    if p and p.x and p.y and p.z then
      return {x = p.x, y = p.y, z = p.z}
    end
  end

  if posx and posy and posz then
    return {x = posx(), y = posy(), z = posz()}
  end

  return nil
end

local function getCastleAreaBounds(area)
  if not area or type(area.points) ~= "table" then return nil end

  local minX, maxX, minY, maxY = nil, nil, nil, nil

  for _, point in ipairs(area.points) do
    local x = tonumber(point.x)
    local y = tonumber(point.y)

    if x and y then
      minX = minX and math.min(minX, x) or x
      maxX = maxX and math.max(maxX, x) or x
      minY = minY and math.min(minY, y) or y
      maxY = maxY and math.max(maxY, y) or y
    end
  end

  if not minX or not maxX or not minY or not maxY then return nil end

  local yMargin = tonumber(area.yMargin) or 0

  return {
    minX = minX,
    maxX = maxX,
    minY = minY - yMargin,
    maxY = maxY + yMargin,
    zMin = tonumber(area.zMin) or 0,
    zMax = tonumber(area.zMax) or 15,
  }
end

local function isInsideCastleArea(position)
  if not USAR_WHITELIST_AREA_CASTLE then
    lastAreaName = "whitelist desligada"
    return true, "whitelist desligada"
  end

  position = position or getPlayerPos()

  if not position or not position.x or not position.y or not position.z then
    lastAreaName = "sem posicao"
    return false, "sem posicao"
  end

  for _, area in ipairs(CASTLE_AREAS) do
    local bounds = getCastleAreaBounds(area)

    if bounds and
       position.x >= bounds.minX and position.x <= bounds.maxX and
       position.y >= bounds.minY and position.y <= bounds.maxY and
       position.z >= bounds.zMin and position.z <= bounds.zMax then
      lastAreaName = area.name or "castle"
      return true, lastAreaName
    end
  end

  lastAreaName = "fora da whitelist"
  return false, "fora da whitelist"
end

-- ============================================
-- SUMMONS / MOBS REAIS
-- ============================================

local SUMMON_IGNORE = {
  ["thundergiant"] = true,
  ["grovebeast"] = true,
  ["emberwing"] = true,
  ["skullfrost"] = true,
  ["druidfamiliar"] = true,
  ["sorcererfamiliar"] = true,
  ["paladinfamiliar"] = true,
  ["knightfamiliar"] = true,
}

local function normalizeMobName(name)
  name = tostring(name or ""):lower()
  return name
    :gsub("^%s*%[[^%]]+%]%s*", "")
    :gsub("%s+", "")
    :gsub("[^%w]", "")
end

local function isSummonName(name)
  local normalized = normalizeMobName(name)
  if normalized == "" then return false end
  if SUMMON_IGNORE[normalized] == true then return true end

  for summonName, _ in pairs(SUMMON_IGNORE) do
    if normalized:find(summonName, 1, true) then return true end
  end

  return normalized:find("summon", 1, true) ~= nil or
         normalized:find("familiar", 1, true) ~= nil
end

local function isSummonCreature(creature)
  if not creature then return false end

  if creature.getType and g_game and g_game.getClientVersion then
    local clientVersion = safeCall(function() return g_game.getClientVersion() end, 0) or 0
    local creatureType = safeCall(function() return creature:getType() end, nil)

    if clientVersion >= 960 and tonumber(creatureType) and tonumber(creatureType) >= 3 then
      return true
    end
  end

  if creature.getName then
    local name = safeCall(function() return creature:getName() end, "")
    if isSummonName(name) then return true end
  end

  return false
end

local function getCastleSpectators(range)
  local p = getPlayerPos()
  if not p then return {} end

  if g_map and g_map.getSpectatorsInRange then
    return safeCall(function()
      return g_map.getSpectatorsInRange(p, false, range or REAL_MOB_SCAN_RANGE, range or REAL_MOB_SCAN_RANGE)
    end, {}) or {}
  end

  if type(getSpectators) == "function" then
    return safeCall(function() return getSpectators(false) end, {}) or {}
  end

  if g_map and g_map.getSpectators then
    return safeCall(function() return g_map.getSpectators(p, false) end, {}) or {}
  end

  return {}
end

local function contarMobsReaisCastle(range)
  local p = getPlayerPos()
  if not p then return 0, 0 end

  local mobsReais = 0
  local summonsIgnorados = 0
  local specs = getCastleSpectators(range or REAL_MOB_SCAN_RANGE)

  for _, creature in ipairs(specs) do
    if creature and creature.isMonster and safeCall(function() return creature:isMonster() end, false) then
      local hp = 100

      if creature.getHealthPercent then
        hp = tonumber(safeCall(function() return creature:getHealthPercent() end, 100)) or 100
      end

      local cpos = nil
      if creature.getPosition then
        cpos = safeCall(function() return creature:getPosition() end, nil)
      end

      if hp > 0 and cpos and cpos.z == p.z then
        if isSummonCreature(creature) then
          summonsIgnorados = summonsIgnorados + 1
        else
          mobsReais = mobsReais + 1
        end
      end
    end
  end

  lastMobStatus = tostring(mobsReais) .. " mobs | " .. tostring(summonsIgnorados) .. " summons"
  return mobsReais, summonsIgnorados
end

-- ============================================
-- AUTO PZ TILE VIA !pz
-- ============================================

local PZ_DIRECOES = {
  {nome = "NORTE", dir = 0, dx = 0,  dy = -1},
  {nome = "SUL",   dir = 2, dx = 0,  dy = 1},
  {nome = "LESTE", dir = 1, dx = 1,  dy = 0},
  {nome = "OESTE", dir = 3, dx = -1, dy = 0},
}

local function extrairTempoPzDaMensagem(text)
  if not text then return nil end

  local msg = tostring(text):lower()

  local segundos = msg:match("wait%s+(%d+)%s+seconds")
  if segundos then return tonumber(segundos) end

  segundos = msg:match("wait%s+(%d+)%s+second")
  if segundos then return tonumber(segundos) end

  segundos = msg:match("aguarde%s+(%d+)%s+segundos")
  if segundos then return tonumber(segundos) end

  segundos = msg:match("espere%s+(%d+)%s+segundos")
  if segundos then return tonumber(segundos) end

  if msg:find("remove your pz", 1, true) then
    segundos = msg:match("(%d+)")
    if segundos then return tonumber(segundos) end
  end

  if msg:find("pz", 1, true) then
    segundos = msg:match("(%d+)%s*seg")
    if segundos then return tonumber(segundos) end

    segundos = msg:match("(%d+)%s*s")
    if segundos then return tonumber(segundos) end
  end

  return nil
end

local function registrarRespostaPz(segundos)
  if not segundos then return end

  local t = nowMs()

  pzValorAnterior = pzUltimoValor
  pzUltimoValor = tonumber(segundos)
  pzUltimaRespostaMs = t
  pzPrimeiraConsultaSemRespostaMs = 0

  if pzValorAnterior ~= nil then
    if pzUltimoValor < pzValorAnterior then
      pzEstaDescendo = true
      pzUltimaDescidaMs = t
      lastPzStatus = "descendo: " .. tostring(pzUltimoValor) .. "s"
      castleLog("PZ descendo corretamente: " .. tostring(pzValorAnterior) .. "s -> " .. tostring(pzUltimoValor) .. "s.")
    elseif pzUltimoValor >= pzValorAnterior then
      if pzUltimaDescidaMs == 0 or (t - pzUltimaDescidaMs) >= TEMPO_MAX_SEM_DESCER_PZ_MS then
        pzEstaDescendo = false
        lastPzStatus = "travado: " .. tostring(pzUltimoValor) .. "s"
        castleLog("PZ nao esta descendo neste tile. Atual: " .. tostring(pzUltimoValor) .. "s | anterior: " .. tostring(pzValorAnterior) .. "s.")
      end
    end
  else
    lastPzStatus = "lido: " .. tostring(pzUltimoValor) .. "s"
    castleLog("Primeira leitura do PZ: " .. tostring(pzUltimoValor) .. "s.")
  end
end

local function consultarPzPorComando()
  if not USAR_CHECK_PZ_COMANDO then return false end
  if not say then
    castleLog("Funcao say() nao encontrada. Nao consigo consultar " .. tostring(COMANDO_PZ) .. ".")
    return false
  end

  local t = nowMs()

  if pzUltimaConsultaMs > 0 and (t - pzUltimaConsultaMs) < INTERVALO_CHECK_PZ_MS then
    return false
  end

  pzUltimaConsultaMs = t
  if not pzUltimoValor and pzPrimeiraConsultaSemRespostaMs == 0 then
    pzPrimeiraConsultaSemRespostaMs = t
  end
  say(COMANDO_PZ)
  lastPzStatus = "consultando..."
  castleLog("Consultando PZ com comando " .. tostring(COMANDO_PZ) .. ".")

  return true
end

local function pzSemRespostaExpirou()
  if not FORCAR_CHECK_PZ_ANTES_LOGOUT then return true end
  if not USAR_CHECK_PZ_COMANDO then return true end
  if type(say) ~= "function" then return true end
  if pzUltimoValor ~= nil then return false end
  if pzPrimeiraConsultaSemRespostaMs == 0 then return false end

  return (nowMs() - pzPrimeiraConsultaSemRespostaMs) >= MAX_AGUARDAR_RESPOSTA_PZ_MS
end

local function pzLeituraAntigaExpirou()
  if not FORCAR_CHECK_PZ_ANTES_LOGOUT then return true end
  if not USAR_CHECK_PZ_COMANDO then return true end
  if not pzUltimoValor or pzUltimoValor <= 0 then return false end
  if pzUltimaRespostaMs == 0 then return false end

  return (nowMs() - pzUltimaRespostaMs) >= MAX_AGUARDAR_RESPOSTA_PZ_MS
end

local function andarUmTileParaTestarPz()
  local t = nowMs()

  if pzTentativasMovimento >= MAX_TENTATIVAS_ANDAR_PZ then
    lastPzStatus = "limite de passos"
    castleLog("Limite de tentativas para achar tile que baixa PZ atingido.")
    return false
  end

  if pzUltimoMovimentoMs > 0 and (t - pzUltimoMovimentoMs) < COOLDOWN_ANDAR_PZ_MS then
    return false
  end

  local dirData = PZ_DIRECOES[pzDirecaoIndex]
  if not dirData then
    pzDirecaoIndex = 1
    dirData = PZ_DIRECOES[pzDirecaoIndex]
  end

  pzDirecaoIndex = pzDirecaoIndex + 1
  if pzDirecaoIndex > #PZ_DIRECOES then pzDirecaoIndex = 1 end

  pzTentativasMovimento = pzTentativasMovimento + 1
  pzUltimoMovimentoMs = t

  lastPzStatus = "testando " .. dirData.nome .. " (" .. tostring(pzTentativasMovimento) .. "/" .. tostring(MAX_TENTATIVAS_ANDAR_PZ) .. ")"
  castleLog("Tentando andar 1 tile para " .. dirData.nome .. " para testar se o PZ comeca a baixar.")

  if g_game and g_game.walk then
    local ok = pcall(function() g_game.walk(dirData.dir) end)
    if ok then return true end
  end

  if walk then
    local ok = pcall(function() walk(dirData.dir) end)
    if ok then return true end
  end

  local p = getPlayerPos()
  if p and autoWalk then
    local destino = {x = p.x + dirData.dx, y = p.y + dirData.dy, z = p.z}
    local ok = pcall(function() autoWalk(destino) end)
    if ok then return true end
  end

  castleLog("Nenhuma funcao de movimento funcionou para testar PZ.")
  return false
end

local function gerenciarPzAntesDoLogout()
  if not USAR_CHECK_PZ_COMANDO then
    lastPzStatus = "check desligado"
    return
  end

  if isPzLocked and not isPzLocked() then
    lastPzStatus = "livre"
    return
  end

  local t = nowMs()

  consultarPzPorComando()

  if not pzUltimoValor then
    return
  end

  if not pzValorAnterior then
    return
  end

  if pzEstaDescendo and pzUltimaDescidaMs > 0 and (t - pzUltimaDescidaMs) <= TEMPO_MAX_SEM_DESCER_PZ_MS then
    if (t - ultimoLogMobs) > 2000 then
      ultimoLogMobs = t
      lastPzStatus = "descendo: " .. tostring(pzUltimoValor) .. "s"
      castleLog("PZ esta descendo. Aguardando liberar para logout. Restante: " .. tostring(pzUltimoValor) .. "s.")
    end
    return
  end

  if not pzEstaDescendo then
    andarUmTileParaTestarPz()
    return
  end
end

-- ============================================
-- PARSER DE MENSAGENS DO CASTLE
-- ============================================

local function limparGuildExtraida(guild)
  guild = trim(guild)
  guild = guild:gsub("^%[", "")
  guild = guild:gsub("%]$", "")
  guild = guild:gsub("%s+[Ee][Ss][Tt].-%s+[Tt]entando.*$", "")
  guild = guild:gsub("%s+[Tt]entando.*$", "")
  guild = guild:gsub("%s+[Tt]entou.*$", "")
  guild = guild:gsub("%s+[Ii]nvad.*$", "")
  guild = guild:gsub("%s+[Dd]omin.*$", "")
  guild = guild:gsub("%s+[Ee][Ss][Tt].-$", "")
  guild = guild:gsub("%.$", "")
  guild = guild:gsub("%-$", "")
  guild = trim(guild)
  return guild
end

local function extrairGuildDaMensagem(text)
  if not text then return nil end

  local guild = text:match('[Pp]ara%s+a%s+[Gg]uild%s+"([^"]+)"')
  if guild then return limparGuildExtraida(guild) end

  guild = text:match("[Pp]ara%s+a%s+[Gg]uild%s*%[([^%]]+)%]")
  if guild then return limparGuildExtraida(guild) end

  guild = text:match("[Pp]ara%s+a%s+[Gg]uild%s+([^%.%-]+)")
  if guild then return limparGuildExtraida(guild) end

  guild = text:match("[Gg]uild%s*:%s*%[([^%]]+)%]")
  if guild then return limparGuildExtraida(guild) end

  guild = text:match("[Dd]a%s+[Gg]uild%s*:%s*%[([^%]]+)%]")
  if guild then return limparGuildExtraida(guild) end

  guild = text:match("[Pp]ela%s+[Gg]uild%s*%[([^%]]+)%]")
  if guild then return limparGuildExtraida(guild) end

  guild = text:match("[Gg]uild%s*%[([^%]]+)%]")
  if guild then return limparGuildExtraida(guild) end

  guild = text:match('[Gg]uild%s+"([^"]+)"')
  if guild then return limparGuildExtraida(guild) end

  guild = text:match("[Gg]uild%s*:%s*([^%.%-]+)")
  if guild then return limparGuildExtraida(guild) end

  guild = text:match("[Dd]a%s+[Gg]uild%s+([^%.%-]+)")
  if guild then return limparGuildExtraida(guild) end

  guild = text:match("[Pp]ela%s+[Gg]uild%s+([^%.%-]+)")
  if guild then return limparGuildExtraida(guild) end

  guild = text:match("[Gg]uild%s+([^%.%-]+)%s+[Tt]ent")
  if guild then return limparGuildExtraida(guild) end

  guild = text:match("[Gg]uild%s+([^%.%-]+)%s+[Ii]nvad")
  if guild then return limparGuildExtraida(guild) end

  guild = text:match("[Gg]uild%s+([^%.%-]+)%s+[Dd]omin")
  if guild then return limparGuildExtraida(guild) end

  return nil
end

local function extrairJogadorDaMensagem(text)
  if not text then return nil end

  local jogador = text:match("[Jj]ogador%s*:%s*([^%.%-]+)")
  if jogador then return limparGuildExtraida(jogador) end

  return nil
end

local function mensagemDominioCastle(msg)
  if not msg then return false end
  if not msg:find("castle", 1, true) then return false end

  return msg:find("dominou", 1, true) ~= nil or
         msg:find("dominado", 1, true) ~= nil or
         msg:find("conquistou", 1, true) ~= nil or
         msg:find("conquista", 1, true) ~= nil
end

local function mensagemInvasaoCastle(msg)
  if not msg then return false end
  if not msg:find("castle", 1, true) then return false end

  return msg:find("tentando invadir", 1, true) ~= nil or
         msg:find("invadir", 1, true) ~= nil or
         msg:find("invadiu", 1, true) ~= nil or
         msg:find("invadiram", 1, true) ~= nil or
         msg:find("invadindo", 1, true) ~= nil or
         msg:find("invas", 1, true) ~= nil
end

local function rotinaCastleAtiva()
  return estadoCastle == ESTADO_AGUARDANDO_DOMINIO or
         estadoCastle == ESTADO_AGUARDANDO_LOGOUT or
         estadoCastle == ESTADO_LOGOUT_SOLICITADO
end

-- ============================================
-- LOGOUT
-- ============================================

local function iniciarLogoutPorDominio(guildDetectada, text)
  if guildDetectada and guildDetectada ~= "" then
    guildInvasoraAtual = guildDetectada
  end

  if not guildInvasoraAtual or guildInvasoraAtual == "" then
    if LOGOUT_AGRESSIVO_DOMINIO then
      guildInvasoraAtual = "desconhecida"
    else
      castleLog("Dominio do castle detectado, mas sem guild conhecida.")
      return true
    end
  end

  lastGuildStatus = tostring(guildInvasoraAtual)

  if isGuildAliada(guildInvasoraAtual) then
    castleLog("Dominio aliado detectado para [" .. tostring(guildInvasoraAtual) .. "]. Retomando CaveBot.")
    retomarCavebotSeNecessario()
    resetState("dominio aliado")
    return true
  end

  if not LOGOUT_AGRESSIVO_DOMINIO and not isGuildInimiga(guildInvasoraAtual) then
    castleLog("Dominio ignorado. Guild nao configurada como inimiga: [" .. tostring(guildInvasoraAtual) .. "].")
    return true
  end

  estadoCastle = ESTADO_AGUARDANDO_LOGOUT
  castleTimer = os.time()
  ultimoLogout = 0
  ultimoLogMobs = 0
  resetPzChecker()

  pausarCavebotPeloScript()

  if LOGOUT_AGRESSIVO_DOMINIO then
    estadoCastle = ESTADO_LOGOUT_SOLICITADO
    lastMobStatus = "ignorado (agressivo)"
    lastPzStatus = "ignorado (agressivo)"
    castleLog("Dominio inimigo confirmado para [" .. tostring(guildInvasoraAtual) .. "]. Logout agressivo imediato, sem aguardar mobs/PZ.")
    return true
  end

  castleLog("Dominio inimigo confirmado para [" .. tostring(guildInvasoraAtual) .. "]. Aguardando limpar mobs/battle/PZ para logout.")
  return true
end

local function iniciarEsperaDominioPorInvasao(guildDetectada, text)
  if rotinaCastleAtiva() then
    castleLog("Novo aviso ignorado, rotina ja ativa para [" .. tostring(guildInvasoraAtual) .. "].")
    return true
  end

  local guildLegivel = guildDetectada and guildDetectada ~= ""
  guildInvasoraAtual = guildLegivel and guildDetectada or "desconhecida"
  lastGuildStatus = tostring(guildInvasoraAtual)
  ultimoAvisoInvasao = os.time()

  if guildLegivel and isGuildAliada(guildDetectada) then
    estadoCastle = ESTADO_IDLE
    castleLog("Invasao ignorada. Guild aliada/sua guild: [" .. guildDetectada .. "].")
    return true
  end

  local jogadorDetectado = extrairJogadorDaMensagem(text)
  local mobsReais, summonsIgnorados = contarMobsReaisCastle(REAL_MOB_SCAN_RANGE)

  estadoCastle = ESTADO_AGUARDANDO_DOMINIO
  castleTimer = os.time()
  ultimoLogout = 0
  ultimoLogMobs = 0
  resetPzChecker()

  pausarCavebotPeloScript()

  if not guildLegivel then
    castleLog("Aviso de invasao do castle sem guild legivel. CaveBot pausado por seguranca por " .. tostring(TEMPO_ESPERA_DOMINIO) .. " segundos.")
  elseif isGuildInimiga(guildDetectada) then
    castleLog("Guild inimiga tentando invadir: [" .. guildDetectada .. "] Jogador: [" .. tostring(jogadorDetectado or "nao identificado") .. "]. CaveBot pausado por " .. tostring(TEMPO_ESPERA_DOMINIO) .. " segundos. TargetBot nao sera desligado nesta fase. Mobs reais: " .. tostring(mobsReais) .. " | summons ignorados: " .. tostring(summonsIgnorados) .. ".")
  else
    castleLog("Guild nao cadastrada tentando invadir: [" .. guildDetectada .. "]. CaveBot pausado por seguranca por " .. tostring(TEMPO_ESPERA_DOMINIO) .. " segundos.")
  end

  return true
end

local function tentarAtalhoCtrlQ()
  if not USAR_FORCE_CTRL_Q and not LOGOUT_AGRESSIVO_DOMINIO then return false end

  lastLogoutStatus = "tentando Ctrl+Q"
  castleLog("Tentando force logout pelo atalho Ctrl+Q.")

  -- Foca o mapa antes de tentar enviar o atalho.
  if modules and modules.game_interface and modules.game_interface.getMapPanel then
    pcall(function()
      local mapPanel = modules.game_interface.getMapPanel()
      if mapPanel and mapPanel.focus then mapPanel:focus() end
    end)
  end

  -- Nem todo OTC permite simular tecla via Lua.
  -- Por isso testamos varios nomes de funcao comuns e mantemos fallback para g_game.logout.
  if g_keyboard then
    local attempts = {
      {name = "pressKey", available = function() return type(g_keyboard.pressKey) == "function" end, run = function() g_keyboard.pressKey("Ctrl+Q") end},
      {name = "keyPress", available = function() return type(g_keyboard.keyPress) == "function" end, run = function() g_keyboard.keyPress("Ctrl+Q") end},
      {name = "sendKeyPress", available = function() return type(g_keyboard.sendKeyPress) == "function" end, run = function() g_keyboard.sendKeyPress("Ctrl+Q") end},
      {name = "press", available = function() return type(g_keyboard.press) == "function" end, run = function() g_keyboard.press("Ctrl+Q") end},
      {name = "keyDown", available = function() return type(g_keyboard.keyDown) == "function" and type(g_keyboard.keyUp) == "function" end, run = function()
        g_keyboard.keyDown("Ctrl")
        g_keyboard.keyDown("Q")
        g_keyboard.keyUp("Q")
        g_keyboard.keyUp("Ctrl")
      end},
    }

    for _, attempt in ipairs(attempts) do
      if attempt.available() then
        local ok = pcall(attempt.run)
        if ok then
          castleLog("Atalho Ctrl+Q enviado/tentado via g_keyboard: " .. tostring(attempt.name))
          return true
        end
      end
    end
  end

  castleLog("Este OTC nao expôs funcao Lua confiavel para simular Ctrl+Q. Usando logout via API do jogo.")
  return false
end

local function tentarForceExitCastle()
  if modules and modules.game_interface and modules.game_interface.forceExit then
    local ok = pcall(function() modules.game_interface.forceExit() end)
    if ok then
      lastLogoutStatus = "forceExit"
      castleLog("ForceExit solicitado pelo modo agressivo do Castle.")
      return true
    end
  end

  return false
end

local function tentarLogoutCastle()
  local t = nowMs()

  if ultimoLogout > 0 and (t - ultimoLogout) < COOLDOWN_LOGOUT_MS then
    return
  end

  if LOGOUT_AGRESSIVO_DOMINIO then
    lastMobStatus = "ignorado (agressivo)"
    lastPzStatus = "ignorado (agressivo)"
  else
    local mobsReais, summonsIgnorados = contarMobsReaisCastle(REAL_MOB_SCAN_RANGE)

    if mobsReais > 0 then
      estadoCastle = ESTADO_AGUARDANDO_LOGOUT
      retomarTargetbotSeNecessario()

      if (t - ultimoLogMobs) > 2000 then
        ultimoLogMobs = t
        castleLog("Aguardando limpar mobs reais antes do logout. Mobs: " .. tostring(mobsReais) .. " | summons ignorados: " .. tostring(summonsIgnorados) .. ". TargetBot mantido no estado atual.")
      end

      return
    end
  end

  ultimoLogout = t
  estadoCastle = ESTADO_LOGOUT_SOLICITADO
  lastLogoutStatus = "tentando"

  -- 1) Tenta o atalho Ctrl+Q, porque no seu client ele e o logout manual.
  -- Mesmo quando o atalho for enviado, segue para as APIs como fallback.
  local logoutTentado = tentarAtalhoCtrlQ() == true

  if LOGOUT_AGRESSIVO_DOMINIO and tentarForceExitCastle() then
    return
  end

  -- 2) Fallbacks por API do client.
  if g_game and g_game.safeLogout then
    local ok = pcall(function() g_game.safeLogout() end)
    if ok then
      logoutTentado = true
      lastLogoutStatus = "safeLogout"
      castleLog("Logout seguro solicitado apos dominio do castle.")
      if not LOGOUT_AGRESSIVO_DOMINIO then return end
    end
  end

  if g_game and g_game.logout then
    local ok = pcall(function() g_game.logout() end)
    if ok then
      logoutTentado = true
      lastLogoutStatus = "logout API"
      castleLog("Logout solicitado apos dominio do castle.")
      if not LOGOUT_AGRESSIVO_DOMINIO then return end
    end
  end

  if logout then
    local ok = pcall(function() logout() end)
    if ok then
      logoutTentado = true
      lastLogoutStatus = "logout global"
      castleLog("Logout global solicitado apos dominio do castle.")
      if not LOGOUT_AGRESSIVO_DOMINIO then return end
    end
  end

  if modules and modules.game_interface and modules.game_interface.forceExit then
    local ok = pcall(function() modules.game_interface.forceExit() end)
    if ok then
      lastLogoutStatus = "forceExit"
      castleLog("ForceExit solicitado apos falha dos metodos comuns de logout.")
      return
    end
  end

  if logoutTentado then
    return
  end

  lastLogoutStatus = "sem funcao"
  castleLog("Nenhuma funcao de logout encontrada. Mantendo CaveBot pausado e tentando novamente ate timeout.")
end

-- ============================================
-- INTERFACE
-- ============================================

local function safeSetText(widget, text)
  if widget and widget.setText then
    pcall(function() widget:setText(tostring(text or "")) end)
  end
end

local function safeSetTooltip(widget, text)
  if widget and widget.setTooltip then
    pcall(function() widget:setTooltip(tostring(text or "")) end)
  end
end

local function safeSetOn(widget, value)
  if widget and widget.setOn then
    pcall(function() widget:setOn(value == true) end)
  elseif widget and widget.setChecked then
    pcall(function() widget:setChecked(value == true) end)
  end
end

local function safeIsOn(widget)
  if widget and widget.isOn then
    local ok, value = pcall(function() return widget:isOn() end)
    if ok then return value == true end
  end
  if widget and widget.isChecked then
    local ok, value = pcall(function() return widget:isChecked() end)
    if ok then return value == true end
  end
  return false
end

local function createWidget(className, dest)
  local ok, widget = pcall(function()
    return UI.createWidget(className, dest)
  end)
  if ok then return widget end
  return nil
end

local function addSection(text, dest)
  local w = createWidget("CastleManagerSectionTitle", dest)
  if w and w.title then safeSetText(w.title, text) end
  return w
end

local function addInfo(text, dest)
  local w = createWidget("CastleManagerInfoBox", dest)
  if w and w.text then safeSetText(w.text, text) end
  return w
end

local function addStatusRow(key, title, dest)
  local w = createWidget("CastleManagerStatusRow", dest)
  if w then
    if w.left then safeSetText(w.left, title) end
    if w.value then safeSetText(w.value, "-") end
    statusWidgets[key] = w
  end
  return w
end

local function setStatusValue(key, value)
  local w = statusWidgets[key]
  if w and w.value then safeSetText(w.value, value) end
end

local function addTextRow(key, title, hint, dest, onChange)
  local w = createWidget("CastleManagerTextRow", dest)
  if not w then return nil end

  if w.title then safeSetText(w.title, title) end
  if w.hint then safeSetText(w.hint, hint or "") end
  if w.edit then
    safeSetText(w.edit, cfg[key])
    safeSetTooltip(w.edit, hint or "")

    w.edit.onTextChange = function(widget, text)
      cfg[key] = tostring(text or "")
      if onChange then onChange(widget, text) end
      aplicarSetupCastle()
    end
  end

  return w
end

local function addNumberRow(key, title, hint, dest, minValue, maxValue)
  return addTextRow(key, title, hint, dest, function(widget, text)
    local n = tonumber(text)
    if n then
      if minValue and n < minValue then n = minValue end
      if maxValue and n > maxValue then n = maxValue end
      cfg[key] = n
    end
  end)
end

local function addSwitchRow(key, title, dest, callback)
  local w = createWidget("CastleManagerSwitchRow", dest)
  if not w then return nil end

  if w.switch then
    safeSetText(w.switch, title)
    safeSetOn(w.switch, cfg[key] == true)

    w.switch.onClick = function(widget)
      local newValue = not safeIsOn(widget)
      safeSetOn(widget, newValue)
      cfg[key] = newValue

      if callback then callback(newValue) end
      aplicarSetupCastle()
    end
  end

  return w
end

local function showWindow()
  if not mainWindow then return end
  mainWindow:show()
  mainWindow:raise()
  mainWindow:focus()
end

local function updateMainPanel()
  if ui then
    if ui.enabled then safeSetOn(ui.enabled, cfg.enabled == true) end

    local status = estadoCastle
    if cfg.enabled ~= true then status = "DESLIGADO" end
    if ui.status then safeSetText(ui.status, status) end

    local sub = "area: " .. tostring(lastAreaName or "-")
    if pzUltimoValor then sub = sub .. " | pz: " .. tostring(pzUltimoValor) .. "s" end
    if ui.subStatus then safeSetText(ui.subStatus, sub) end
  end
end

local function updateWindowStatus()
  setStatusValue("enabled", cfg.enabled and "ligado" or "desligado")
  setStatusValue("estado", estadoCastle)
  setStatusValue("area", lastAreaName)
  setStatusValue("guild", lastGuildStatus)
  setStatusValue("mobs", lastMobStatus)
  setStatusValue("pz", lastPzStatus)
  setStatusValue("logout", lastLogoutStatus)
  setStatusValue("evento", lastEventText)

  local p = getPlayerPos()
  if p then
    setStatusValue("pos", tostring(p.x) .. "," .. tostring(p.y) .. "," .. tostring(p.z))
  else
    setStatusValue("pos", "-")
  end
end

local function buildUI()
  if uiBuilt then return end
  uiBuilt = true

  local okPanel, panel = pcall(function()
    return UI.createWidget("CastleManagerBotPanel")
  end)

  if okPanel and panel then
    ui = panel

    if ui.enabled then
      safeSetOn(ui.enabled, cfg.enabled == true)
      ui.enabled.onClick = function(widget)
        local newValue = not safeIsOn(widget)
        setEnabled(newValue)
      end
    end

    if ui.setup then
      ui.setup.onClick = function() showWindow() end
    end
  else
    warn("[CASTLE] Nao consegui criar CastleManagerBotPanel. Verifique o .otui.")
  end

  local okWindow, win = pcall(function()
    return UI.createWindow("CastleManagerWindow", rootWidget)
  end)

  if not okWindow or not win then
    okWindow, win = pcall(function()
      return UI.createWindow("CastleManagerWindow")
    end)
  end

  if okWindow and win then
    mainWindow = win
    mainWindow:hide()

    if mainWindow.closeButton then
      mainWindow.closeButton.onClick = function() mainWindow:hide() end
    end

    if mainWindow.footer then
      if mainWindow.footer.close then
        mainWindow.footer.close.onClick = function() mainWindow:hide() end
      end
    end

    local left = mainWindow.content and mainWindow.content.left
    local right = mainWindow.content and mainWindow.content.right

    if left and right then
      addSection("Controle", left)
      local enabledToggle = addSwitchRow("enabled", "Ativar tudo", left, function(value)
        setEnabled(value)
      end)
      mainWindow.enabledToggle = enabledToggle

      addSection("Update", left)
      addSwitchRow("autoUpdateEnabled", "Auto Update", left)
      addSwitchRow("autoReloadAfterUpdate", "Reload apos update", left)
      addNumberRow("autoUpdateIntervalSeconds", "Intervalo update", "segundos entre checagens no GitHub", left, 60, 86400)

      addSection("Tempos principais", left)
      addNumberRow("tempoEsperaDominioMin", "Esperar dominio", "minutos aguardando a guild inimiga dominar", left, 1, 120)
      addNumberRow("timeoutLogoutMin", "Timeout de logout", "minutos tentando logout depois do dominio", left, 1, 60)
      addNumberRow("cooldownLogoutMs", "Cooldown logout", "milissegundos entre tentativas de logout", left, 300, 10000)
      addNumberRow("mobScanRange", "Raio de mobs", "SQM para checar mobs reais antes do logout", left, 1, 20)

      addSection("Guilds", left)
      addTextRow("guildsInimigasText", "Guilds inimigas", "separe por virgula, ponto e virgula ou linha", left)
      addTextRow("guildsAliadasText", "Guilds aliadas", "separe por virgula, ponto e virgula ou linha", left)

      addSection("Auto PZ Tile", right)
      addTextRow("comandoPz", "Comando PZ", "exemplo: !pz", right)
      addNumberRow("intervaloCheckPzMs", "Intervalo !pz", "tempo entre consultas do comando, em ms", right, 1000, 15000)
      addNumberRow("tempoMaxSemDescerPzMs", "Sem descer PZ", "se nao cair neste tempo, tenta andar", right, 3000, 30000)
      addNumberRow("maxAguardarRespostaPzMs", "Max resp PZ", "tempo maximo esperando resposta do !pz antes de tentar logout mesmo assim", right, 3000, 60000)
      addNumberRow("cooldownAndarPzMs", "Cooldown andar", "intervalo entre passos testando tile", right, 500, 10000)
      addNumberRow("maxTentativasAndarPz", "Max passos PZ", "limite de passos procurando tile bom", right, 1, 100)

      addSection("Status em tempo real", right)
      addStatusRow("enabled", "Script", right)
      addStatusRow("estado", "Estado", right)
      addStatusRow("pos", "Posicao", right)
      addStatusRow("area", "Area", right)
      addStatusRow("guild", "Guild", right)
      addStatusRow("mobs", "Mobs", right)
      addStatusRow("pz", "PZ", right)
      addStatusRow("logout", "Logout", right)
      addStatusRow("evento", "Evento", right)

      addInfo("A mensagem azul do Default Chat e lida pelo texto: 'You have to wait 60 seconds to remove your Pz.'", right)
    end
  else
    warn("[CASTLE] Nao consegui criar CastleManagerWindow. Verifique o .otui.")
  end
end

buildUI()

cfg.installedScriptVersion = CASTLE_MANAGER_SCRIPT_VERSION
if schedule then
  schedule(3000, function() runCastleManagerAutoUpdate(false) end)
else
  runCastleManagerAutoUpdate(false)
end

macro(10000, function()
  runCastleManagerAutoUpdate(false)
end)

-- ============================================
-- MACRO PRINCIPAL
-- ============================================

macro(100, function()
  updateMainPanel()

  if not isCastleManagerLigado() then
    return
  end

  isInsideCastleArea()

  if estadoCastle ~= ESTADO_AGUARDANDO_DOMINIO and
     estadoCastle ~= ESTADO_AGUARDANDO_LOGOUT and
     estadoCastle ~= ESTADO_LOGOUT_SOLICITADO then
    return
  end

  local elapsed = os.time() - castleTimer

  if castleTimer == 0 or elapsed < 0 then
    retomarCavebotSeNecessario()
    resetState("timer invalido")
    return
  end

  if estadoCastle == ESTADO_AGUARDANDO_DOMINIO then
    if isCavebotOn() then
      pausarCavebotPeloScript()
    end

    if elapsed >= TEMPO_ESPERA_DOMINIO then
      castleLog("Sem dominio inimigo apos " .. tostring(TEMPO_ESPERA_DOMINIO) .. "s. Retomando CaveBot.")
      retomarCavebotSeNecessario()
      resetState("castle nao dominado")
    end

    return
  end

  if elapsed > TIMEOUT_LOGOUT_CASTLE then
    if LOGOUT_AGRESSIVO_DOMINIO and
       (estadoCastle == ESTADO_AGUARDANDO_LOGOUT or estadoCastle == ESTADO_LOGOUT_SOLICITADO) then
      castleLog("Timeout atingido, mas dominio inimigo ja foi confirmado. Mantendo logout agressivo ativo.")
      castleTimer = os.time()
    else
      castleLog("Timeout de logout (" .. tostring(TIMEOUT_LOGOUT_CASTLE) .. "s). Mantendo CaveBot desligado e TargetBot no estado atual para nao voltar a upar no castle.")
      resetState("timeout")
      return
    end
  end

  if isCavebotOn() then
    pausarCavebotPeloScript()
  end

  if LOGOUT_AGRESSIVO_DOMINIO and
     (estadoCastle == ESTADO_AGUARDANDO_LOGOUT or estadoCastle == ESTADO_LOGOUT_SOLICITADO) then
    lastMobStatus = "ignorado (agressivo)"
    lastPzStatus = "ignorado (agressivo)"
    tentarLogoutCastle()
    return
  end

  local mobsReais, summonsIgnorados = contarMobsReaisCastle(REAL_MOB_SCAN_RANGE)

  if mobsReais > 0 then
    retomarTargetbotSeNecessario()

    local t = nowMs()
    if (t - ultimoLogMobs) > 2000 then
      ultimoLogMobs = t
      castleLog("Mobs reais perto (" .. tostring(mobsReais) .. "). CaveBot parado, TargetBot nao sera desligado ainda. Summons ignorados: " .. tostring(summonsIgnorados) .. ".")
    end

    return
  end

  -- Checagem de PZ.
  -- Antes dependia apenas de isPzLocked().
  -- Agora, se "Forcar !pz antes do logout" estiver ligado, ele consulta !pz mesmo se isPzLocked falhar.
  local pzLockedAgora = false
  if isPzLocked then
    pzLockedAgora = isPzLocked() == true
  end

  if pzLockedAgora then
    gerenciarPzAntesDoLogout()

    if pzUltimoValor and pzUltimoValor <= 0 then
      lastPzStatus = "livre por !pz"
    elseif pzSemRespostaExpirou() then
      lastPzStatus = "sem resposta, tentando logout"
      castleLog("isPzLocked ainda ativo, mas o !pz nao respondeu no limite. Vou tentar logout mesmo assim.")
    elseif pzLeituraAntigaExpirou() then
      lastPzStatus = "leitura antiga, tentando logout"
      castleLog("isPzLocked ainda ativo, mas a leitura do !pz ficou antiga. Vou tentar logout mesmo assim.")
    else
      return
    end
  end

  if FORCAR_CHECK_PZ_ANTES_LOGOUT and USAR_CHECK_PZ_COMANDO and pzUltimoValor and pzUltimoValor > 0 and not pzLeituraAntigaExpirou() then
    gerenciarPzAntesDoLogout()
    return
  end

  if FORCAR_CHECK_PZ_ANTES_LOGOUT and USAR_CHECK_PZ_COMANDO and pzUltimoValor and pzUltimoValor > 0 and pzLeituraAntigaExpirou() then
    lastPzStatus = "leitura antiga, tentando logout"
    castleLog("Leitura do !pz ficou antiga. Vou tentar logout mesmo assim.")
  end

  if FORCAR_CHECK_PZ_ANTES_LOGOUT and USAR_CHECK_PZ_COMANDO and not pzUltimoValor and not pzSemRespostaExpirou() then
    consultarPzPorComando()
    lastPzStatus = "forcando consulta antes logout"
    castleLog("Forcando consulta !pz antes do logout, pois ainda nao existe leitura de PZ.")
    return
  end

  if FORCAR_CHECK_PZ_ANTES_LOGOUT and USAR_CHECK_PZ_COMANDO and not pzUltimoValor and pzSemRespostaExpirou() then
    lastPzStatus = "sem resposta, tentando logout"
    castleLog("Sem resposta valida do !pz apos " .. tostring(MAX_AGUARDAR_RESPOSTA_PZ_MS) .. "ms. Vou tentar logout mesmo assim.")
  end

  if lastPzStatus ~= "sem resposta, tentando logout" and lastPzStatus ~= "leitura antiga, tentando logout" then
    lastPzStatus = "livre/nao detectado"
  end

  if estadoCastle == ESTADO_AGUARDANDO_LOGOUT or estadoCastle == ESTADO_LOGOUT_SOLICITADO then
    tentarLogoutCastle()
    return
  end
end)

-- Atualizacao visual mais leve.
macro(300, function()
  updateMainPanel()
  updateWindowStatus()
end)

-- ============================================
-- MACRO DE SEGURANCA
-- ============================================
-- Se desligar pela interface enquanto o script pausou bots, ele retoma.

macro(500, function()
  if (cavebotPausadoPeloScript or targetbotPausadoPeloScript) and not isCastleManagerLigado() then
    castleLog("Castle_Manager foi desligado. Retomando bots por seguranca.")
    retomarCavebotSeNecessario()
    retomarTargetbotSeNecessario()
    resetState("Castle_Manager desligado")
  end
end)

-- ============================================
-- DETECTOR DE MENSAGENS
-- ============================================

onTextMessage(function(mode, text)
  if not isCastleManagerLigado() then
    return
  end

  if not text then return end

  -- A resposta azul do Default Chat do !pz cai aqui pelo texto.
  -- Exemplo: 01:27 You have to wait 60 seconds to remove your Pz.
  local pzSegundos = extrairTempoPzDaMensagem(text)
  if pzSegundos then
    registrarRespostaPz(pzSegundos)
    return
  end

  local msg = text:lower()

  if mensagemDominioCastle(msg) then
    local guildDominante = extrairGuildDaMensagem(text)

    local rotinaAtiva = rotinaCastleAtiva()

    local dentroCastle, areaCastle = isInsideCastleArea()

    if not rotinaAtiva and not dentroCastle then
      castleLog("Dominio do castle ignorado fora da whitelist de area: " .. tostring(areaCastle) .. ".")
      return
    end

    if rotinaAtiva or guildDominante or LOGOUT_AGRESSIVO_DOMINIO then
      return iniciarLogoutPorDominio(guildDominante, text)
    end
  end

  if mensagemInvasaoCastle(msg) then
    local guildDetectada = extrairGuildDaMensagem(text)
    local dentroCastle, areaCastle = isInsideCastleArea()

    if not dentroCastle then
      castleLog("Invasao detectada fora da whitelist de area (" .. tostring(areaCastle) .. "). Pausando CaveBot por seguranca.")
    end

    return iniciarEsperaDominioPorInvasao(guildDetectada, text)
  end
end)
