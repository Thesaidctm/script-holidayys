-- Derpetson Scripts launcher standalone.
-- Entregue este arquivo ao cliente para abrir a central no OTC_BOT dele.

local DERPETSON_LAUNCHER_VERSION = 2026061231
local DERPETSON_MANAGER_URL = "https://jequimultiassessoria.com.br/license_server/manager.lua?v=2026061231"

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
local derpLauncherRow = nil
local derpLauncherTitle = nil
local derpLauncherStatus = nil
local derpLauncherButton = nil

local function derpChild(widget, id)
  if not widget or not id then return nil end
  if widget[id] then return widget[id] end
  if widget.getChildById then
    local ok, child = pcall(function() return widget:getChildById(id) end)
    if ok and child then return child end
  end
  if widget.recursiveGetChildById then
    local ok, child = pcall(function() return widget:recursiveGetChildById(id) end)
    if ok and child then return child end
  end
  return nil
end

local function derpSetText(widget, text)
  if widget and widget.setText then
    pcall(function() widget:setText(tostring(text or "")) end)
  end
end

local function derpSetStatus(text)
  derpSetText(derpLauncherStatus, text)
  derpSetText(derpChild(derpLauncherRow, "subtitle"), text)
end

local function derpWidgetAlive(widget)
  if not widget then return false end
  if widget.isDestroyed then
    local ok, destroyed = pcall(function() return widget:isDestroyed() end)
    if ok and destroyed then return false end
  end
  if widget.getParent then
    local ok, parent = pcall(function() return widget:getParent() end)
    if ok and not parent then return false end
  end
  return derpChild(widget, "open") ~= nil or derpChild(widget, "openButton") ~= nil
end

local function derpDestroyOldLauncher()
  local old = derpGlobal.DerpetsonLauncherRow
  if derpWidgetAlive(old) and old.destroy then
    pcall(function() old:destroy() end)
  end
  derpGlobal.DerpetsonLauncherRow = nil
  derpLauncherRow = nil
  derpLauncherTitle = nil
  derpLauncherStatus = nil
  derpLauncherButton = nil
end

local function derpWarn(text)
  local message = "[Derpetson] " .. tostring(text or "")
  if modules and modules.game_textmessage and modules.game_textmessage.displayGameMessage then
    pcall(function() modules.game_textmessage.displayGameMessage(message) end)
  end
  if warn then warn(message) end
end

local function derpLoadChunk(source, chunkName)
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
  derpSetStatus("Abrindo central...")
  if type(derpGlobal.JQMOpenManager) == "function" then
    derpGlobal.JQMOpenManager()
    derpSetStatus("Central de acesso")
    return
  end
  if derpGlobal.DerpetsonLauncherLoading == true then
    derpSetStatus("Aguarde...")
    return
  end
  derpGlobal.DerpetsonLauncherLoading = true

  derpHttpGet(DERPETSON_MANAGER_URL, function(data, err)
    derpGlobal.DerpetsonLauncherLoading = false
    if err or type(data) ~= "string" or data == "" then
      derpSetStatus("Erro HTTP")
      derpWarn("falha ao carregar central: " .. tostring(err or "sem dados"))
      return
    end

    local fn, loadErr = derpLoadChunk(data, "@derpetson_manager.lua")
    if not fn then
      derpSetStatus("Central invalida")
      derpWarn("central invalida: " .. tostring(loadErr))
      return
    end

    local ok, runErr = pcall(fn)
    if not ok then
      derpSetStatus("Erro na central")
      derpWarn("erro na central: " .. tostring(runErr))
      return
    end

    if type(derpGlobal.JQMOpenManager) == "function" then
      derpGlobal.JQMOpenManager()
      derpSetStatus("Central de acesso")
    else
      derpSetStatus("Central sem janela")
    end
  end)
end

derpGlobal.DerpetsonLauncherOpen = derpLoadManager

local function derpBindClick(widget)
  if not widget then return false end
  widget.onClick = function()
    derpLoadManager()
    return true
  end
  widget.onMouseRelease = function()
    derpLoadManager()
    return true
  end
  return true
end

local function derpCreateLauncher(force)
  derpLauncherRow = derpGlobal.DerpetsonLauncherRow
  if not force and derpWidgetAlive(derpLauncherRow) then return end
  if force then derpDestroyOldLauncher() end

  derpGlobal.DerpetsonLauncherVersion = DERPETSON_LAUNCHER_VERSION
  derpGlobal.DerpetsonLauncherOpen = derpLoadManager

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
    @onClick: DerpetsonLauncherOpen()

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
    @onClick: DerpetsonLauncherOpen()

  Button
    id: open
    anchors.right: parent.right
    anchors.top: parent.top
    width: 54
    height: 40
    text: Abrir
    @onClick: DerpetsonLauncherOpen()
]])
    end)
    if ok and row then
      derpLauncherRow = row
      derpGlobal.DerpetsonLauncherRow = row
      derpLauncherButton = derpChild(row, "open") or derpChild(row, "openButton")
      derpLauncherTitle = derpChild(row, "title")
      derpLauncherStatus = derpChild(row, "subtitle")
      local bound = false
      bound = derpBindClick(derpLauncherButton) or bound
      bound = derpBindClick(derpLauncherTitle) or bound
      bound = derpBindClick(derpLauncherStatus) or bound
      bound = derpBindClick(row) or bound
      if not bound and UI and UI.Button then
        UI.Button("Derpetson Scripts", derpLoadManager)
      end
      return
    end
  end

  if UI and UI.Button then
    UI.Button("Derpetson Scripts", derpLoadManager)
  else
    derpWarn("setupUI/UI.Button indisponivel neste OTC")
  end
end

local function derpStartKeepAlive()
  if derpGlobal.DerpetsonLauncherKeepAlive and derpGlobal.DerpetsonLauncherKeepAlive.destroy then
    pcall(function() derpGlobal.DerpetsonLauncherKeepAlive:destroy() end)
  end

  if type(macro) == "function" then
    local ok, watcher = pcall(function()
      return macro(2000, function()
        derpLauncherRow = derpGlobal.DerpetsonLauncherRow
        if not derpWidgetAlive(derpLauncherRow) then
          derpCreateLauncher(false)
        end
      end)
    end)
    if ok then
      derpGlobal.DerpetsonLauncherKeepAlive = watcher
      return
    end
  end

  if type(schedule) == "function" then
    local token = (tonumber(derpGlobal.DerpetsonLauncherWatchToken) or 0) + 1
    derpGlobal.DerpetsonLauncherWatchToken = token
    local function watch()
      if derpGlobal.DerpetsonLauncherWatchToken ~= token then return end
      derpLauncherRow = derpGlobal.DerpetsonLauncherRow
      if not derpWidgetAlive(derpLauncherRow) then
        derpCreateLauncher(false)
      end
      schedule(2000, watch)
    end
    schedule(2000, watch)
  end
end

derpCreateLauncher(true)
derpStartKeepAlive()
