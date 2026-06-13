-- Holiday AOE public bridge.
-- Compatibilidade: clientes antigos que ainda carregam este arquivo agora abrem
-- apenas o Derpetson Scripts, onde todos os produtos ficam em uma aba unica.

local JQM_MANAGER_URL = "https://jequimultiassessoria.com.br/license_server/manager.lua?v=2026061236"

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

local function jqmWarn(text)
  local message = "[JQM] " .. tostring(text or "")
  if modules and modules.game_textmessage and modules.game_textmessage.displayGameMessage then
    pcall(function() modules.game_textmessage.displayGameMessage(message) end)
  end
  if warn then warn(message) end
end

local function jqmLoadChunk(source, chunkName)
  local lastErr = nil
  if type(loadstring) == "function" then
    local ok, fn, err = pcall(loadstring, source, chunkName)
    if ok and type(fn) == "function" then return fn, nil end
    lastErr = ok and err or fn
  end
  if type(load) == "function" then
    local ok, fn, err = pcall(load, source, chunkName)
    if ok and type(fn) == "function" then return fn, nil end
    lastErr = ok and err or fn

    ok, fn, err = pcall(load, source)
    if ok and type(fn) == "function" then return fn, nil end
    lastErr = ok and err or fn
  end
  return nil, lastErr or "loadstring/load indisponivel"
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

local function jqmLoadManager()
  if jqmGlobal.JQMScriptManagerBootstrapLoading == true then return end
  jqmGlobal.JQMScriptManagerBootstrapLoading = true
  local oldOpenManager = jqmGlobal.JQMOpenManager
  local oldManagerVersion = jqmGlobal.JQMScriptManagerVersion

  jqmHttpGet(JQM_MANAGER_URL, function(data, err)
    jqmGlobal.JQMScriptManagerBootstrapLoading = false
    if err or type(data) ~= "string" or data == "" then
      jqmWarn("falha ao carregar central: " .. tostring(err or "sem dados"))
      if type(oldOpenManager) == "function" then pcall(oldOpenManager) end
      return
    end

    local fn, loadErr = jqmLoadChunk(data, "@jqm_script_manager.lua")
    if not fn then
      jqmWarn("central invalida: " .. tostring(loadErr))
      if type(oldOpenManager) == "function" then pcall(oldOpenManager) end
      return
    end

    jqmGlobal.JQMOpenManager = nil
    jqmGlobal.JQMScriptManagerVersion = nil
    local ok, runErr = pcall(fn)
    if not ok then
      jqmGlobal.JQMOpenManager = oldOpenManager
      jqmGlobal.JQMScriptManagerVersion = oldManagerVersion
      jqmWarn("erro na central: " .. tostring(runErr))
      if type(oldOpenManager) == "function" then pcall(oldOpenManager) end
      return
    end
    if type(jqmGlobal.JQMOpenManager) == "function" then
      local opened, openErr = pcall(jqmGlobal.JQMOpenManager)
      if not opened then jqmWarn("erro ao abrir central: " .. tostring(openErr)) end
    end
    jqmWarn("central Derpetson carregada")
  end)
end

local function jqmEnsureBridgeLauncher()
  if jqmGlobal.DerpetsonLauncherRow then
    jqmGlobal.JQMScriptManagerBridgeLauncher = jqmGlobal.DerpetsonLauncherRow
    return
  end
  if jqmGlobal.JQMScriptManagerLauncher then
    jqmGlobal.JQMScriptManagerBridgeLauncher = jqmGlobal.JQMScriptManagerLauncher
    return
  end
  if jqmGlobal.JQMScriptManagerBridgeLauncher then return end
  if type(setupUI) ~= "function" then return end
  local ok, row = pcall(function()
    return setupUI([[
Panel
  height: 50
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
    height: 15
    color: #7ee8a8
    font: verdana-11px
    text: iniciar / configurar

  Button
    id: open
    anchors.right: parent.right
    anchors.top: parent.top
    width: 54
    height: 38
    text: Abrir
]])
  end)
  if ok and row then
    jqmGlobal.JQMScriptManagerBridgeLauncher = row
    if row.open then row.open.onClick = jqmLoadManager end
    if row.title then row.title.onClick = jqmLoadManager end
    if row.subtitle then row.subtitle.onClick = jqmLoadManager end
  end
end

jqmEnsureBridgeLauncher()
jqmLoadManager()
