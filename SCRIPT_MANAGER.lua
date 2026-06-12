-- Derpetson Scripts - loader publico
-- Este arquivo nao contem os scripts reais. Ele envia o MAC/HWID para aprovacao
-- e baixa do servidor somente os scripts liberados no painel.

setDefaultTab("Main")

local emblemId = 3
local JQM_LICENSE_SERVER = "https://jequimultiassessoria.com.br/license_server/api.php"
local JQM_PENDING_MESSAGE = "AGUARDANDO LIBERACAO MANDE MENSAGEM NO WHATSAPP PARA 33 999987736"

local JQM_SCRIPTS = {
  { name = "combo", label = "Combo" },
  { name = "holiday_aoe", label = "Holiday AOE" },
  { name = "castle_manager", label = "Castle Manager" }
}

storage.JQMScriptManager = type(storage.JQMScriptManager) == "table" and storage.JQMScriptManager or {}
storage.JQMScriptManager.selected = type(storage.JQMScriptManager.selected) == "table" and storage.JQMScriptManager.selected or {}
storage.Combo = type(storage.Combo) == "table" and storage.Combo or {}
storage.Combo.licenseKey = storage.Combo.licenseKey or ""

local function jqmUrlEncode(value)
  value = tostring(value or "")
  value = value:gsub("\n", "\r\n")
  value = value:gsub("([^%w%-%_%.%~])", function(char)
    return string.format("%%%02X", string.byte(char))
  end)
  return value
end

local function jqmWarn(text)
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
  local current = _G
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
  local fn, loadErr = loader(data, "@jqm_" .. tostring(scriptName) .. ".lua")
  if not fn then
    jqmWarn("payload invalido: " .. tostring(loadErr))
    return false
  end
  local ok, runErr = pcall(fn)
  if not ok then
    jqmWarn("erro no script: " .. tostring(runErr))
    return false
  end
  jqmWarn("carregado: " .. tostring(scriptName))
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

local function jqmAllScriptsCsv()
  local scripts = {}
  for _, item in ipairs(JQM_SCRIPTS) do
    table.insert(scripts, item.name)
  end
  return table.concat(scripts, ",")
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
  local scripts = jqmAllScriptsCsv()
  jqmHttpGet(jqmBuildUrl("request", { scripts = scripts }), function(data, err)
    if err or not data then
      jqmWarn(JQM_PENDING_MESSAGE)
      return
    end

    if data:find('"ok":true', 1, true) or data:find('"ok": true', 1, true) then
      local allowed = jqmScriptsFromResponse(data)
      if #allowed == 0 then
        jqmWarn("nenhum script liberado para este MAC.")
        return
      end
      jqmWarn("liberado. carregando scripts.")
      for _, scriptName in ipairs(allowed) do
        JQMLoadScript(scriptName)
      end
      return
    end

    jqmWarn(JQM_PENDING_MESSAGE)
  end)
end

UI.Separator()
UI.Label("Derpetson Scripts")
UI.Label("Acesso por MAC")
UI.Button("Acessar Scripts", jqmRequestOrLoad)
