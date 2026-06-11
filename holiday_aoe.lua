-- HOLIDAY AOE public bridge. O codigo real fica no servidor de licencas.
-- holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii

setDefaultTab("Main")

local HOLIDAY_AOE_SCRIPT_VERSION = 2026061103
local HOLIDAY_AOE_SCRIPT_NAME = "holiday_aoe.lua"
local HOLIDAY_AOE_OTUI_NAME = "holiday_aoe.otui"
local HOLIDAY_AOE_UPDATE_URL = "https://api.github.com/repos/Thesaidctm/script-holidayys/contents/holiday_aoe.lua?ref=main"
local HOLIDAY_AOE_OTUI_UPDATE_URL = "https://api.github.com/repos/Thesaidctm/script-holidayys/contents/holiday_aoe.otui?ref=main"

local JQM_REMOTE_SCRIPT = "holiday_aoe"
local JQM_LICENSE_SERVER = "https://jequimultiassessoria.com.br/license_server/api.php"
local emblemId = 3

if type(storage) == "table" then
  storage.Combo = type(storage.Combo) == "table" and storage.Combo or {}
  storage.Combo.licenseKey = storage.Combo.licenseKey or ""
end

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
      if #list > 0 then
        return table.concat(list, "\n")
      end
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

local function jqmBuildUrl(scriptName, publicIp)
  local machineId = jqmMachineId()
  local key = ""
  if type(storage) == "table" and type(storage.Combo) == "table" then
    key = storage.Combo.licenseKey or ""
  end
  local params = {
    action = "script",
    script = scriptName,
    key = key,
    hwid = machineId,
    mac = machineId,
    ip = publicIp or "",
    char = jqmPlayerName(),
    emblem = emblemId
  }
  local parts = {}
  for k, v in pairs(params) do
    table.insert(parts, jqmUrlEncode(k) .. "=" .. jqmUrlEncode(v))
  end
  return JQM_LICENSE_SERVER .. "?" .. table.concat(parts, "&")
end

local function jqmRunPayload(data)
  if type(data) ~= "string" or data == "" then
    jqmWarn("payload vazio")
    return false
  end
  if data:sub(1, 1) == "{" then
    if data:find("device_pending", 1, true) then
      jqmWarn("dispositivo enviado para aprovacao. Aguarde liberacao no painel.")
    else
      jqmWarn("licenca recusada: " .. data)
    end
    return false
  end
  local loader = loadstring or load
  if not loader then
    jqmWarn("loadstring/load indisponivel neste OTC")
    return false
  end
  local fn, loadErr = loader(data, "@jqm_remote_" .. JQM_REMOTE_SCRIPT .. ".lua")
  if not fn then
    jqmWarn("payload invalido: " .. tostring(loadErr))
    return false
  end
  local ok, runErr = pcall(fn)
  if not ok then
    jqmWarn("erro no script remoto: " .. tostring(runErr))
    return false
  end
  jqmWarn("script remoto carregado: " .. JQM_REMOTE_SCRIPT)
  return true
end

local function jqmLoadRemote(scriptName)
  local function requestWithIp(publicIp)
    jqmHttpGet(jqmBuildUrl(scriptName, publicIp), function(data, err)
      if err or not data then
        jqmWarn("falha ao baixar script: " .. tostring(err or "sem dados"))
        return
      end
      jqmRunPayload(data)
    end)
  end

  jqmHttpGet("https://api.ipify.org", function(ip)
    requestWithIp(ip or "")
  end)
end

JQMLicense = JQMLicense or {}
JQMLicense.load = jqmLoadRemote

jqmLoadRemote(JQM_REMOTE_SCRIPT)

local JQM_COMPAT_PAD = [=[
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 001. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 002. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 003. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 004. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 005. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 006. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 007. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 008. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 009. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 010. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 011. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 012. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 013. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 014. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 015. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 016. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 017. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 018. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 019. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 020. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 021. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 022. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 023. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 024. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 025. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 026. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 027. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 028. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 029. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 030. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 031. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 032. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 033. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 034. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 035. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 036. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 037. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 038. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 039. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 040. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 041. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 042. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 043. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 044. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 045. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 046. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 047. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 048. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 049. This public file intentionally contains no private combat logic.
HOLIDAY AOE holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii bridge compatibility padding 050. This public file intentionally contains no private combat logic.
]=]

if false then print(JQM_COMPAT_PAD) end
