-- Derpetson Scripts - loader publico
-- Este arquivo nao contem os scripts reais. Ele envia o MAC/HWID para aprovacao
-- e baixa do servidor somente os scripts liberados no painel.

local function jqmGlobals()
  if type(_G) == "table" then return _G end
  if type(modules) == "table" and type(modules._G) == "table" then return modules._G end
  if type(getfenv) == "function" then
    local ok, env = pcall(getfenv, 0)
    if ok and type(env) == "table" then return env end
    ok, env = pcall(getfenv)
    if ok and type(env) == "table" then return env end
  end
  return {}
end

local jqmGlobal = jqmGlobals()
local JQM_MANAGER_VERSION = 2026061210
if jqmGlobal.JQMScriptManagerVersion == JQM_MANAGER_VERSION then
  if type(jqmGlobal.JQMOpenManager) == "function" then jqmGlobal.JQMOpenManager() end
  return
end
jqmGlobal.JQMScriptManagerVersion = JQM_MANAGER_VERSION

local emblemId = 3
local JQM_LICENSE_SERVER = "https://jequimultiassessoria.com.br/license_server/api.php"
local JQM_PENDING_MESSAGE = "AGUARDANDO LIBERACAO MANDE MENSAGEM NO WHATSAPP PARA 33 999987736"
local JQM_MANAGER_TAB = "Main"
local jqmOriginalSetDefaultTab = setDefaultTab
local jqmRuntimeLoaded = type(jqmGlobal.JQMScriptManagerRuntimeLoaded) == "table" and jqmGlobal.JQMScriptManagerRuntimeLoaded or {}
if jqmGlobal.JQMScriptManagerRuntimeVersion ~= JQM_MANAGER_VERSION then
  jqmRuntimeLoaded = {}
end
jqmGlobal.JQMScriptManagerRuntimeLoaded = jqmRuntimeLoaded
jqmGlobal.JQMScriptManagerRuntimeVersion = JQM_MANAGER_VERSION

local JQM_SCRIPTS = {
  { name = "combo", label = "COMBO_ESPART_V3.lua", desc = "Combo, runas e prioridades" },
  { name = "holiday_aoe", label = "holiday_aoe.lua", desc = "Holiday AOE, area e PvP" },
  { name = "castle_manager", label = "CASTLE_MANAGER_LOGOUT.lua", desc = "Castle, seguranca e logout" }
}

local JQM_SWITCH_IDS = {
  combo = "comboSwitch",
  holiday_aoe = "holidaySwitch",
  castle_manager = "castleSwitch"
}

local jqmWindow = nil
local jqmLauncher = nil
local jqmUiLoaded = false
local jqmManagerTab = nil
local jqmLoadedRows = {}

local function jqmEnsureManagerTab()
  if jqmManagerTab then return jqmManagerTab end
  if type(getTab) == "function" then
    local ok, tab = pcall(function() return getTab(JQM_MANAGER_TAB) end)
    if ok and tab then
      jqmManagerTab = tab
      return jqmManagerTab
    end
  end
  if type(jqmOriginalSetDefaultTab) == "function" then
    local ok, tab = pcall(function() return jqmOriginalSetDefaultTab(JQM_MANAGER_TAB) end)
    if ok and tab then jqmManagerTab = tab end
  end
  return jqmManagerTab
end

jqmEnsureManagerTab()

local function jqmWindowControl(id)
  if not jqmWindow then return nil end
  if jqmWindow[id] then return jqmWindow[id] end
  for _, parentId in ipairs({ "headerPanel", "listPanel", "helpPanel", "footer" }) do
    local panel = jqmWindow[parentId]
    if panel and panel[id] then return panel[id] end
  end
  return nil
end

storage.JQMScriptManager = type(storage.JQMScriptManager) == "table" and storage.JQMScriptManager or {}
storage.JQMScriptManager.selected = type(storage.JQMScriptManager.selected) == "table" and storage.JQMScriptManager.selected or {}
storage.JQMScriptManager.loaded = type(storage.JQMScriptManager.loaded) == "table" and storage.JQMScriptManager.loaded or {}
storage.Combo = type(storage.Combo) == "table" and storage.Combo or {}
storage.Combo.licenseKey = storage.Combo.licenseKey or ""

local function jqmSetText(widget, text)
  if widget and widget.setText then
    pcall(function() widget:setText(tostring(text or "")) end)
  end
end

local function jqmSetOn(widget, value)
  if widget and widget.setOn then
    pcall(function() widget:setOn(value == true) end)
  elseif widget and widget.setChecked then
    pcall(function() widget:setChecked(value == true) end)
  end
end

local function jqmSelectedNames()
  local selected = {}
  for _, item in ipairs(JQM_SCRIPTS) do
    if storage.JQMScriptManager.selected[item.name] == true then
      table.insert(selected, item.name)
    end
  end
  return selected
end

local function jqmSelectedLabels()
  local labels = {}
  for _, item in ipairs(JQM_SCRIPTS) do
    if storage.JQMScriptManager.selected[item.name] == true then
      table.insert(labels, item.label)
    end
  end
  return labels
end

local function jqmSelectedCsv()
  return table.concat(jqmSelectedNames(), ",")
end

local function jqmSelectedSummary()
  local labels = jqmSelectedLabels()
  if #labels == 0 then return "Nenhum script selecionado" end
  if #labels == 1 then return labels[1] end
  return tostring(#labels) .. " scripts selecionados"
end

local function jqmScriptLabel(scriptName)
  for _, item in ipairs(JQM_SCRIPTS) do
    if item.name == scriptName then return item.label end
  end
  return tostring(scriptName or "")
end

local function jqmSetManagerStatus(text)
  jqmSetText(jqmLauncher and jqmLauncher.status, text)
  jqmSetText(jqmWindowControl("status"), text)
end

local function jqmRefreshManagerUi()
  for _, item in ipairs(JQM_SCRIPTS) do
    local switchId = JQM_SWITCH_IDS[item.name]
    local widget = switchId and jqmWindowControl(switchId)
    jqmSetOn(widget, storage.JQMScriptManager.selected[item.name] == true)
  end
  jqmSetText(jqmLauncher and jqmLauncher.status, jqmSelectedSummary())
  jqmSetText(jqmWindowControl("status"), jqmSelectedSummary())
end

local jqmRequestSingle = nil
local jqmWarn = nil

local function jqmActivateSelected(scriptName)
  storage.JQMScriptManager.selected[scriptName] = true
  jqmRefreshManagerUi()
  if type(jqmRequestSingle) == "function" then
    jqmRequestSingle(scriptName)
  end
end

local function jqmSetAllSelected(value)
  for _, item in ipairs(JQM_SCRIPTS) do
    storage.JQMScriptManager.selected[item.name] = value == true
  end
  jqmRefreshManagerUi()
end

local function jqmEnsureLoadedRow(scriptName)
  if jqmLoadedRows[scriptName] then return jqmLoadedRows[scriptName] end
  if type(setupUI) ~= "function" then return nil end

  local item = nil
  for _, script in ipairs(JQM_SCRIPTS) do
    if script.name == scriptName then
      item = script
      break
    end
  end
  if not item then return nil end

  local tab = jqmEnsureManagerTab()
  if not tab then return nil end

  local ok, row = pcall(function()
    return setupUI([[
Panel
  height: 20
  margin-top: 2

  BotSwitch
    id: title
    anchors.left: parent.left
    anchors.right: state.left
    anchors.top: parent.top
    margin-right: 2
    height: 18
    text-align: center
    color: #ffffff

  Label
    id: state
    anchors.right: parent.right
    anchors.top: parent.top
    width: 64
    height: 18
    text-align: center
    color: #7ee8a8
    font: verdana-11px-bold
    text: Carregado
]], tab)
  end)
  if not ok or not row then return nil end

  jqmLoadedRows[scriptName] = row
  if row.title then
    jqmSetText(row.title, item.label)
    jqmSetOn(row.title, true)
  end
  if row.state then
    jqmSetText(row.state, "Carregado")
  end
  return row
end

local function jqmUrlEncode(value)
  value = tostring(value or "")
  value = value:gsub("\n", "\r\n")
  value = value:gsub("([^%w%-%_%.%~])", function(char)
    return string.format("%%%02X", string.byte(char))
  end)
  return value
end

jqmWarn = function(text)
  local message = "[JQM] " .. tostring(text or "")
  if modules and modules.game_textmessage and modules.game_textmessage.displayGameMessage then
    pcall(function() modules.game_textmessage.displayGameMessage(message) end)
  end
  if warn then warn(message) end
end

local function jqmPlayerName()
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
  return ""
end

local function jqmTryCall(path)
  local current = jqmGlobal
  for part in tostring(path):gmatch("[^%.]+") do
    if type(current) ~= "table" and type(current) ~= "userdata" then return nil end
    current = current[part]
    if current == nil then return nil end
  end
  if type(current) ~= "function" then return nil end
  local ok, value = pcall(current)
  if ok and value ~= nil then return tostring(value) end
  return nil
end

local function jqmMachineId()
  if modules and modules.client and modules.client.g_platform and modules.client.g_platform.getMacAddresses then
    local ok, macs = pcall(function()
      return modules.client.g_platform.getMacAddresses()
    end)
    if ok and type(macs) == "table" then
      local list = {}
      for _, mac in pairs(macs) do
        if mac and tostring(mac) ~= "" then
          table.insert(list, tostring(mac))
        end
      end
      if #list > 0 then return table.concat(list, "\n") end
    end
  end

  local candidates = {
    "getMacAddress",
    "g_platform.getMacAddress",
    "g_platform.getMachineId",
    "g_platform.getUUID",
    "g_app.getMachineId",
    "g_app.getUniqueId",
    "g_resources.getMachineId"
  }
  for _, path in ipairs(candidates) do
    local value = jqmTryCall(path)
    if value and value ~= "" then return value end
  end
  return "unknown"
end

local function jqmNormalizeHttp(a, b, c)
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

local function jqmHttpGet(url, callback)
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
          local data, err = jqmNormalizeHttp(a, b, c)
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

local function jqmBaseParams(action, extra)
  local machineId = jqmMachineId()
  local params = {
    action = action,
    key = storage.Combo.licenseKey or "",
    hwid = machineId,
    mac = machineId,
    char = jqmPlayerName(),
    emblem = emblemId
  }
  for key, value in pairs(extra or {}) do
    params[key] = value
  end
  return params
end

local function jqmBuildUrl(action, extra)
  local params = jqmBaseParams(action, extra)
  local parts = {}
  for key, value in pairs(params) do
    table.insert(parts, jqmUrlEncode(key) .. "=" .. jqmUrlEncode(value))
  end
  return JQM_LICENSE_SERVER .. "?" .. table.concat(parts, "&")
end

local function jqmPayloadEnv()
  local env = jqmGlobals()
  if type(env) ~= "table" then env = {} end
  env._G = env
  env.parent = jqmEnsureManagerTab()
  return env
end

local function jqmApplyPayloadEnv(fn)
  if type(fn) ~= "function" then return fn end
  if type(setfenv) == "function" then
    pcall(function() setfenv(fn, jqmPayloadEnv()) end)
  end
  return fn
end

local function jqmRunInManagerTab(fn)
  local originalSetDefaultTab = setDefaultTab
  local originalGetTab = getTab
  local originalLoadstring = loadstring
  local originalLoad = load
  local managerTab = jqmEnsureManagerTab()

  local function selectManagerTab()
    local tab = nil
    if type(originalSetDefaultTab) == "function" then
      local ok, value = pcall(function() return originalSetDefaultTab(JQM_MANAGER_TAB) end)
      if ok and value then tab = value end
    end
    if not tab then tab = jqmEnsureManagerTab() end
    if tab then
      jqmManagerTab = tab
      parent = tab
    end
    return tab
  end

  local function forcedGetTab()
    if type(originalGetTab) == "function" then
      local ok, tab = pcall(function() return originalGetTab(JQM_MANAGER_TAB) end)
      if ok and tab then return tab end
    end
    return selectManagerTab()
  end

  local function forcedSetDefaultTab()
    return selectManagerTab()
  end

  local function wrapLoader(loader)
    return function(...)
      local loaded, loadErr = loader(...)
      if type(loaded) == "function" then
        loaded = jqmApplyPayloadEnv(loaded)
      end
      return loaded, loadErr
    end
  end

  if type(originalSetDefaultTab) == "function" then
    setDefaultTab = forcedSetDefaultTab
  end
  if type(originalGetTab) == "function" then
    getTab = forcedGetTab
  end
  if type(originalLoadstring) == "function" then
    loadstring = wrapLoader(originalLoadstring)
  end
  if type(originalLoad) == "function" then
    load = wrapLoader(originalLoad)
  end
  selectManagerTab()
  jqmApplyPayloadEnv(fn)

  local ok, err = pcall(fn)

  if type(originalSetDefaultTab) == "function" then
    setDefaultTab = originalSetDefaultTab
  end
  if type(originalGetTab) == "function" then
    getTab = originalGetTab
  end
  if type(originalLoadstring) == "function" then
    loadstring = originalLoadstring
  end
  if type(originalLoad) == "function" then
    load = originalLoad
  end
  selectManagerTab()

  return ok, err
end

local function jqmRunPayload(scriptName, data)
  if type(data) ~= "string" or data == "" then
    jqmWarn("payload vazio")
    return false
  end
  if data:sub(1, 1) == "{" then
    if data:find("device_pending", 1, true) then
      jqmWarn(JQM_PENDING_MESSAGE)
    elseif data:find("script_not_allowed", 1, true) then
      jqmWarn("script ainda nao liberado para este MAC.")
    else
      jqmWarn("servidor recusou: " .. data)
    end
    return false
  end

  local loader = loadstring or load
  if not loader then
    jqmWarn("loadstring/load indisponivel neste OTC")
    return false
  end
  if jqmRuntimeLoaded[scriptName] == true then
    jqmEnsureLoadedRow(scriptName)
    jqmSetManagerStatus("Ja carregado")
    jqmWarn("ja carregado: " .. jqmScriptLabel(scriptName))
    return true
  end
  local fn, loadErr = loader(data, "@jqm_" .. tostring(scriptName) .. ".lua")
  if not fn then
    jqmWarn("payload invalido: " .. tostring(loadErr))
    return false
  end
  local ok, runErr = jqmRunInManagerTab(fn)
  if not ok then
    jqmWarn("erro no script: " .. tostring(runErr))
    return false
  end
  jqmRuntimeLoaded[scriptName] = true
  storage.JQMScriptManager.loaded[scriptName] = true
  jqmEnsureLoadedRow(scriptName)
  jqmSetManagerStatus("Carregado na Main")
  jqmWarn("carregado: " .. jqmScriptLabel(scriptName))
  return true
end

function JQMLoadScript(scriptName)
  jqmHttpGet(jqmBuildUrl("script", { script = scriptName }), function(data, err)
    if err or not data then
      jqmWarn("falha ao baixar " .. tostring(scriptName) .. ": " .. tostring(err or "sem dados"))
      return
    end
    jqmRunPayload(scriptName, data)
  end)
end

local function jqmScriptsFromResponse(data)
  local scripts = {}
  data = tostring(data or "")
  for _, item in ipairs(JQM_SCRIPTS) do
    if data:find('"' .. item.name .. '"', 1, true) then
      table.insert(scripts, item.name)
    end
  end
  return scripts
end

local function jqmRequestOrLoad()
  local scripts = jqmSelectedCsv()
  if scripts == "" then
    jqmSetManagerStatus("Marque pelo menos um script")
    jqmWarn("marque pelo menos um script.")
    return
  end
  jqmSetManagerStatus("Conectando ao servidor...")
  jqmHttpGet(jqmBuildUrl("request", { scripts = scripts }), function(data, err)
    if err or not data then
      jqmSetManagerStatus("Aguardando liberacao")
      jqmWarn(JQM_PENDING_MESSAGE)
      return
    end

    if data:find('"ok":true', 1, true) or data:find('"ok": true', 1, true) then
      local allowed = jqmScriptsFromResponse(data)
      if #allowed == 0 then
        jqmSetManagerStatus("Nenhum selecionado liberado")
        jqmWarn("nenhum script liberado para este MAC.")
        return
      end
      jqmSetManagerStatus("Carregando selecionados...")
      jqmWarn("liberado. carregando scripts.")
      for _, scriptName in ipairs(allowed) do
        JQMLoadScript(scriptName)
      end
      return
    end

    jqmSetManagerStatus("Aguardando liberacao")
    jqmWarn(JQM_PENDING_MESSAGE)
  end)
end

jqmRequestSingle = function(scriptName)
  if scriptName == nil or scriptName == "" then return end
  storage.JQMScriptManager.selected[scriptName] = true
  jqmRefreshManagerUi()

  if jqmRuntimeLoaded[scriptName] == true then
    jqmEnsureLoadedRow(scriptName)
    jqmSetManagerStatus("Ja carregado")
    jqmWarn("ja carregado: " .. jqmScriptLabel(scriptName))
    return
  end

  jqmSetManagerStatus("Carregando " .. jqmScriptLabel(scriptName) .. "...")
  jqmHttpGet(jqmBuildUrl("request", { scripts = scriptName }), function(data, err)
    if err or not data then
      jqmSetManagerStatus("Aguardando liberacao")
      jqmWarn(JQM_PENDING_MESSAGE)
      return
    end

    if data:find('"ok":true', 1, true) or data:find('"ok": true', 1, true) then
      local allowed = jqmScriptsFromResponse(data)
      for _, allowedName in ipairs(allowed) do
        if allowedName == scriptName then
          JQMLoadScript(scriptName)
          return
        end
      end
      jqmSetManagerStatus("Sem liberacao para " .. jqmScriptLabel(scriptName))
      jqmWarn("script ainda nao liberado para este MAC.")
      return
    end

    jqmSetManagerStatus("Aguardando liberacao")
    jqmWarn(JQM_PENDING_MESSAGE)
  end)
end

local function jqmLoadManagerUi()
  if jqmUiLoaded then return true end
  if not g_ui or not g_ui.loadUIFromString then return false end

  local ok = pcall(function()
    g_ui.loadUIFromString([[
DerpetsonScriptHubPanel < Panel
  height: 76
  margin-top: 4
  padding: 4
  image-source: /images/ui/panel_flat
  image-border: 5

  Label
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: open.left
    margin-right: 4
    height: 16
    text-align: center
    color: #ffd36b
    font: verdana-11px-bold
    text: Derpetson

  Label
    id: subtitle
    anchors.top: title.bottom
    anchors.left: parent.left
    anchors.right: open.left
    margin-top: 1
    margin-right: 4
    height: 14
    text-align: center
    color: #dce4ee
    font: verdana-11px
    text: scripts

  Label
    id: status
    anchors.top: subtitle.bottom
    anchors.left: parent.left
    anchors.right: open.left
    margin-top: 2
    margin-right: 4
    height: 14
    text-align: center
    color: #7ee8a8
    font: verdana-11px-bold
    text: Selecionar

  Button
    id: open
    anchors.top: parent.top
    anchors.right: parent.right
    width: 52
    height: 64
    text-align: center
    text: Abrir

DerpetsonScriptsWindow < MainWindow
  text: Derpetson Scripts
  size: 420 365
  padding: 10
  @onEscape: self:hide()

  Panel
    id: headerPanel
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 62
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
      color: #ffd36b
      font: verdana-11px-bold
      text: DERPETSON SCRIPTS

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
      text: Clique no produto para carregar; configure pelo botao do script

    Label
      id: status
      anchors.top: subtitle.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 3
      height: 15
      text-align: center
      color: #7ee8a8
      font: verdana-11px-bold
      text: Nenhum script selecionado

  Panel
    id: listPanel
    anchors.top: headerPanel.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 9
    height: 138
    image-source: /images/ui/panel_flat
    image-border: 5
    padding: 8

    BotSwitch
      id: comboSwitch
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: 24
      text-align: center
      text: COMBO_ESPART_V3.lua

    Label
      id: comboDesc
      anchors.top: comboSwitch.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 1
      height: 15
      text-align: center
      color: #9fb2c4
      font: verdana-11px
      text: Combo, runas e prioridades

    BotSwitch
      id: holidaySwitch
      anchors.top: comboDesc.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 6
      height: 24
      text-align: center
      text: holiday_aoe.lua

    Label
      id: holidayDesc
      anchors.top: holidaySwitch.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 1
      height: 15
      text-align: center
      color: #9fb2c4
      font: verdana-11px
      text: Holiday AOE, area e PvP

    BotSwitch
      id: castleSwitch
      anchors.top: holidayDesc.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 6
      height: 24
      text-align: center
      text: CASTLE_MANAGER_LOGOUT.lua

    Label
      id: castleDesc
      anchors.top: castleSwitch.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 1
      height: 15
      text-align: center
      color: #9fb2c4
      font: verdana-11px
      text: Castle, seguranca e logout

  Panel
    id: helpPanel
    anchors.top: listPanel.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 8
    height: 62
    background-color: #101620dd

    Label
      id: helpTitle
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 5
      height: 15
      text-align: center
      color: #ffd36b
      font: verdana-11px-bold
      text: Como usar

    Label
      id: helpLine1
      anchors.top: helpTitle.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 3
      height: 15
      text-align: center
      color: #dce4ee
      font: verdana-11px
      text: 1. Clique no produto verde para carregar na hora.

    Label
      id: helpLine2
      anchors.top: helpLine1.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 2
      height: 15
      text-align: center
      color: #9fb2c4
      font: verdana-11px
      text: 2. Use Limpar apenas para desmarcar a selecao.

  Panel
    id: footer
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 28

    Button
      id: allButton
      anchors.left: parent.left
      anchors.top: parent.top
      width: 72
      height: 24
      text: Todos

    Button
      id: clearButton
      anchors.left: allButton.right
      anchors.top: parent.top
      margin-left: 5
      width: 66
      height: 24
      text: Limpar

    Button
      id: confirmButton
      anchors.left: clearButton.right
      anchors.right: closeButton.left
      anchors.top: parent.top
      margin-left: 5
      margin-right: 5
      height: 24
      text: Carregar todos

    Button
      id: closeButton
      anchors.right: parent.right
      anchors.top: parent.top
      width: 62
      height: 24
      text: Fechar
]])
  end)

  jqmUiLoaded = ok == true
  return jqmUiLoaded
end

local function jqmCreateWindow()
  if jqmWindow then return jqmWindow end
  if not jqmLoadManagerUi() or not UI or not UI.createWindow then return nil end

  local root = rootWidget or (g_ui.getRootWidget and g_ui.getRootWidget())
  local okWindow, window = pcall(function() return UI.createWindow("DerpetsonScriptsWindow", root) end)
  if not okWindow or not window then
    okWindow, window = pcall(function() return UI.createWindow("DerpetsonScriptsWindow") end)
  end
  if not okWindow or not window then return nil end

  jqmWindow = window
  jqmWindow:hide()

  if jqmWindowControl("closeButton") then
    jqmWindowControl("closeButton").onClick = function() jqmWindow:hide() end
  end
  if jqmWindowControl("confirmButton") then
    jqmWindowControl("confirmButton").onClick = jqmRequestOrLoad
  end
  if jqmWindowControl("allButton") then
    jqmWindowControl("allButton").onClick = function()
      jqmSetAllSelected(true)
      jqmRequestOrLoad()
    end
  end
  if jqmWindowControl("clearButton") then
    jqmWindowControl("clearButton").onClick = function() jqmSetAllSelected(false) end
  end
  if jqmWindowControl("comboSwitch") then
    jqmWindowControl("comboSwitch").onClick = function() jqmActivateSelected("combo") end
  end
  if jqmWindowControl("holidaySwitch") then
    jqmWindowControl("holidaySwitch").onClick = function() jqmActivateSelected("holiday_aoe") end
  end
  if jqmWindowControl("castleSwitch") then
    jqmWindowControl("castleSwitch").onClick = function() jqmActivateSelected("castle_manager") end
  end

  jqmRefreshManagerUi()
  return jqmWindow
end

local function jqmOpenManager()
  local window = jqmCreateWindow()
  if window then
    jqmRefreshManagerUi()
    window:show()
    window:raise()
    if window.focus then window:focus() end
    return
  end
  jqmWarn("janela indisponivel neste cliente.")
end

if jqmLoadManagerUi() and UI and UI.createWidget then
  local okPanel, panel = pcall(function()
    if UI and UI.createWidget then
      return UI.createWidget("DerpetsonScriptHubPanel", jqmEnsureManagerTab())
    end
    return nil
  end)
  if okPanel and panel then
    jqmLauncher = panel
    if jqmLauncher.open then jqmLauncher.open.onClick = jqmOpenManager end
    if jqmLauncher.title then jqmLauncher.title.onClick = jqmOpenManager end
    if jqmLauncher.subtitle then jqmLauncher.subtitle.onClick = jqmOpenManager end
    if jqmLauncher.status then jqmLauncher.status.onClick = jqmOpenManager end
    jqmRefreshManagerUi()
  elseif UI and UI.Button then
    UI.Button("Derpetson Scripts", jqmOpenManager, jqmEnsureManagerTab())
  end
elseif UI and UI.Button then
  UI.Button("Derpetson Scripts", jqmOpenManager, jqmEnsureManagerTab())
end

jqmGlobal.JQMOpenManager = jqmOpenManager
