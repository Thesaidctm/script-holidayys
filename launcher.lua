-- Derpetson Scripts launcher standalone.
-- Entregue este arquivo ao cliente para abrir a central no OTC_BOT dele.

local DERPETSON_LAUNCHER_VERSION = 2026061218
local DERPETSON_MANAGER_URL = "https://jequimultiassessoria.com.br/license_server/manager.lua?v=2026061217"

local function derpGlobals()
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

local derpGlobal = derpGlobals()

local function derpWarn(text)
  local message = "[Derpetson] " .. tostring(text or "")
  if modules and modules.game_textmessage and modules.game_textmessage.displayGameMessage then
    pcall(function() modules.game_textmessage.displayGameMessage(message) end)
  end
  if warn then warn(message) end
end

local function derpNormalizeHttp(a, b, c)
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

local function derpHttpGet(url, callback)
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
          local data, err = derpNormalizeHttp(a, b, c)
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

local function derpSelectMainTab()
  if type(setDefaultTab) ~= "function" then return nil end
  for _, tabName in ipairs({ "Main", "main", "MAIN" }) do
    local ok, tab = pcall(function() return setDefaultTab(tabName) end)
    if ok and tab then return tab end
  end
  return nil
end

local function derpLoadManager()
  if type(derpGlobal.JQMOpenManager) == "function" then
    derpGlobal.JQMOpenManager()
    return
  end
  if derpGlobal.DerpetsonLauncherLoading == true then return end
  derpGlobal.DerpetsonLauncherLoading = true

  derpHttpGet(DERPETSON_MANAGER_URL, function(data, err)
    derpGlobal.DerpetsonLauncherLoading = false
    if err or type(data) ~= "string" or data == "" then
      derpWarn("falha ao carregar central: " .. tostring(err or "sem dados"))
      return
    end

    local loader = loadstring or load
    if not loader then
      derpWarn("loadstring/load indisponivel neste OTC")
      return
    end

    local fn, loadErr = loader(data, "@derpetson_manager.lua")
    if not fn then
      derpWarn("central invalida: " .. tostring(loadErr))
      return
    end

    local ok, runErr = pcall(fn)
    if not ok then
      derpWarn("erro na central: " .. tostring(runErr))
      return
    end

    if type(derpGlobal.JQMOpenManager) == "function" then
      derpGlobal.JQMOpenManager()
    end
  end)
end

local function derpCreateLauncher()
  if derpGlobal.DerpetsonLauncherVersion == DERPETSON_LAUNCHER_VERSION then
    if type(derpGlobal.JQMOpenManager) == "function" then derpGlobal.JQMOpenManager() end
    return
  end
  derpGlobal.DerpetsonLauncherVersion = DERPETSON_LAUNCHER_VERSION

  derpSelectMainTab()

  if type(setupUI) == "function" then
    local ok, row = pcall(function()
      return setupUI([[
Panel
  height: 54
  margin-top: 4
  padding: 5
  image-source: /images/ui/panel_flat
  image-border: 5
  background-color: #111820dd

  Label
    id: title
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.right: open.left
    margin-right: 5
    height: 16
    color: #ffd36b
    font: verdana-11px-bold
    text: Derpetson Scripts

  Label
    id: subtitle
    anchors.left: parent.left
    anchors.top: title.bottom
    anchors.right: open.left
    margin-right: 5
    height: 16
    color: #7ee8a8
    font: verdana-11px-bold
    text: Central de acesso

  Button
    id: open
    anchors.right: parent.right
    anchors.top: parent.top
    width: 54
    height: 40
    text: Abrir
]])
    end)
    if ok and row then
      if row.open then row.open.onClick = derpLoadManager end
      if row.title then row.title.onClick = derpLoadManager end
      if row.subtitle then row.subtitle.onClick = derpLoadManager end
      return
    end
  end

  if UI and UI.Button then
    UI.Button("Derpetson Scripts", derpLoadManager)
  else
    derpWarn("setupUI/UI.Button indisponivel neste OTC")
  end
end

derpCreateLauncher()
