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
local JQM_MANAGER_VERSION = 2026061236
if jqmGlobal.JQMScriptManagerVersion == JQM_MANAGER_VERSION and type(jqmGlobal.JQMOpenManager) == "function" then
  jqmGlobal.JQMOpenManager()
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
  { name = "combo", label = "COMBO ESPART V3", short = "COMBO ESPART", file = "COMBO_ESPART_V3.lua", desc = "Combo, runas e prioridades", category = "COMBATE", icon = "ATK" },
  { name = "castle_manager", label = "CASTLE PRO", short = "CASTLE PRO", file = "CASTLE_MANAGER_LOGOUT.lua", desc = "Castle, seguranca e logout", category = "CASTLE", icon = "CST" },
  { name = "holiday_aoe", label = "HOLIDAY AOE", short = "HOLIDAY AOE", file = "holiday_aoe.lua", desc = "Area, combo e PvP", category = "DEFESA", icon = "DEF" }
}

local JQM_SWITCH_IDS = {
  combo = "comboCard",
  holiday_aoe = "holidayCard",
  castle_manager = "castleCard"
}

local JQM_CARD_PREFIX = {
  combo = "combo",
  holiday_aoe = "holiday",
  castle_manager = "castle"
}

local JQM_CATEGORY_CONTROLS = {
  combo = "combatCategory",
  holiday_aoe = "defenseCategory",
  castle_manager = "castleCategory"
}

local JQM_NATIVE_TITLES = {
  combo = { "COMBO ESPART", "COMBO ESPART V3" },
  holiday_aoe = { "Holiday AOE", "HOLIDAY AOE" },
  castle_manager = { "Castle Manager", "CASTLE PRO", "Castle_Manager" }
}

local JQM_NATIVE_WIDGET_CLASSES = {
  castle_manager = { "CastleManagerBotPanel" }
}

local JQM_SETUP_IDS = { "setup", "Setup", "push", "edit", "cfg", "config" }

local jqmWindow = nil
local jqmLauncher = nil
local jqmUiLoaded = false
local jqmManagerTab = nil
local jqmLoadedRows = {}
local jqmNativeRows = {}
local jqmNativeSetupButtons = {}
local jqmNativeSetupActions = {}
local jqmAllowedScripts = {}
local jqmPermissionsKnown = false
local jqmAutoLoadRunning = false
local jqmOpenManager = nil
local jqmCreateWindow = nil
local jqmScriptLabel = nil
local jqmScriptItem = nil
local jqmWarn = nil
local jqmAutoLoadAllowed = nil
local jqmPrepareProxySetup = nil
local jqmEnsureLoadedRow = nil
local jqmCaptureNativeSetup = nil

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

local function jqmChild(widget, id)
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

local function jqmWindowControl(id)
  if not jqmWindow then return nil end
  local direct = jqmChild(jqmWindow, id)
  if direct then return direct end
  for _, parentId in ipairs({ "headerPanel", "listPanel", "helpPanel", "footer" }) do
    local panel = jqmChild(jqmWindow, parentId)
    local child = jqmChild(panel, id)
    if child then return child end
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

local function jqmGetText(widget)
  if widget and widget.getText then
    local ok, text = pcall(function() return widget:getText() end)
    if ok then return tostring(text or "") end
  end
  return ""
end

local function jqmChildren(widget)
  if widget and widget.getChildren then
    local ok, children = pcall(function() return widget:getChildren() end)
    if ok and type(children) == "table" then return children end
  end
  return {}
end

local function jqmSetOn(widget, value)
  if widget and widget.setOn then
    pcall(function() widget:setOn(value == true) end)
  elseif widget and widget.setChecked then
    pcall(function() widget:setChecked(value == true) end)
  end
end

local function jqmSetColor(widget, color)
  if widget and widget.setColor then
    pcall(function() widget:setColor(color) end)
  end
end

local function jqmSetBackground(widget, color)
  if widget and widget.setBackgroundColor then
    pcall(function() widget:setBackgroundColor(color) end)
  elseif widget and widget.setImageColor then
    pcall(function() widget:setImageColor(color) end)
  end
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

local function jqmSetVisible(widget, visible)
  if not widget then return end
  if visible == false then
    if widget.hide then
      pcall(function() widget:hide() end)
    elseif widget.setVisible then
      pcall(function() widget:setVisible(false) end)
    end
  else
    if widget.show then
      pcall(function() widget:show() end)
    elseif widget.setVisible then
      pcall(function() widget:setVisible(true) end)
    end
  end
end

local function jqmSetHeight(widget, height)
  if widget and widget.setHeight then
    pcall(function() widget:setHeight(tonumber(height) or 0) end)
  end
end

local function jqmNativeHost(scriptName)
  if not jqmWindow and type(jqmCreateWindow) == "function" then
    jqmCreateWindow()
  end
  local prefix = JQM_CARD_PREFIX[scriptName]
  local host = prefix and jqmWindowControl(prefix .. "Native")
  if host then return host end
  return jqmEnsureManagerTab()
end

local function jqmMarkNativeReady(scriptName, row, className)
  local captured = false
  if row and type(jqmCaptureNativeSetup) == "function" then
    captured = jqmCaptureNativeSetup(scriptName, row, className)
  elseif row and not jqmNativeRows[scriptName] then
    jqmNativeRows[scriptName] = row
    captured = true
  end

  local prefix = JQM_CARD_PREFIX[scriptName]
  if prefix then
    if captured and jqmNativeSetupButtons[scriptName] then
      jqmSetText(jqmWindowControl(prefix .. "Gear"), "Setup")
      if type(jqmPrepareProxySetup) == "function" then
        jqmPrepareProxySetup(scriptName)
      else
        jqmSetVisible(jqmWindowControl(prefix .. "Hint"), true)
        jqmSetVisible(jqmWindowControl(prefix .. "Load"), true)
      end
    end
  end
end

local function jqmDirectChild(widget, id)
  if not widget or not id then return nil end
  if widget[id] then return widget[id] end
  if widget.getChildById then
    local ok, child = pcall(function() return widget:getChildById(id) end)
    if ok and child then return child end
  end
  return nil
end

local function jqmDirectSetupButton(widget)
  if not widget then return nil end
  for _, id in ipairs(JQM_SETUP_IDS) do
    local child = jqmDirectChild(widget, id)
    if child then return child end
  end
  return nil
end

local function jqmFindSetupButton(widget)
  if not widget then return nil end
  local direct = jqmDirectSetupButton(widget)
  if direct then return direct end
  for _, id in ipairs(JQM_SETUP_IDS) do
    local child = jqmChild(widget, id)
    if child then return child end
  end
  return nil
end

local function jqmWidgetTreeHasText(widget, texts, depth)
  if not widget or not texts then return false end
  depth = tonumber(depth) or 0
  local value = jqmGetText(widget):lower()
  if value ~= "" then
    for _, text in ipairs(texts) do
      local needle = tostring(text or ""):lower()
      if needle ~= "" and value:find(needle, 1, true) then return true end
    end
  end
  if depth <= 0 then return false end
  for _, child in ipairs(jqmChildren(widget)) do
    if jqmWidgetTreeHasText(child, texts, depth - 1) then return true end
  end
  return false
end

local function jqmNativeClassMatches(scriptName, className)
  local classes = JQM_NATIVE_WIDGET_CLASSES[scriptName]
  if not classes then return false end
  className = tostring(className or "")
  for _, candidate in ipairs(classes) do
    if className == candidate then return true end
  end
  return false
end

local function jqmNativeWidgetMatches(scriptName, widget, className)
  if jqmNativeClassMatches(scriptName, className) then return true end
  local titles = JQM_NATIVE_TITLES[scriptName]
  return titles and jqmWidgetTreeHasText(widget, titles, 3) == true
end

local function jqmNativeHostContains(scriptName, widget)
  if not widget then return false end
  local host = jqmNativeHost(scriptName)
  if not host then return false end
  local current = widget
  for _ = 1, 16 do
    if current == host then return true end
    if not current or not current.getParent then return false end
    local ok, parentWidget = pcall(function() return current:getParent() end)
    if not ok or not parentWidget then return false end
    current = parentWidget
  end
  return false
end

local function jqmRegisterNativeSetupAction(scriptName, action, row)
  if not scriptName or type(action) ~= "function" then return false end
  jqmNativeSetupActions[scriptName] = action
  if row and not jqmNativeRows[scriptName] then
    jqmNativeRows[scriptName] = row
  end
  local prefix = JQM_CARD_PREFIX[scriptName]
  if prefix then
    jqmSetText(jqmWindowControl(prefix .. "Gear"), "SETUP")
    if type(jqmPrepareProxySetup) == "function" then
      jqmPrepareProxySetup(scriptName)
    end
  end
  return true
end

jqmCaptureNativeSetup = function(scriptName, row, className)
  if not scriptName or not row then return false end
  local button = jqmFindSetupButton(row)
  if not button then return false end
  if not jqmNativeHostContains(scriptName, row) and not jqmNativeClassMatches(scriptName, className) then return false end

  jqmNativeRows[scriptName] = row
  jqmNativeSetupButtons[scriptName] = button
  return true
end

local function jqmFindExistingNativeRow(scriptName)
  if jqmNativeRows[scriptName] and jqmNativeSetupButtons[scriptName] then return jqmNativeRows[scriptName] end
  local host = jqmNativeHost(scriptName)
  if not host then return nil end

  local function scan(widget, depth)
    if not widget or depth <= 0 then return nil end
    if widget ~= jqmLauncher and jqmDirectSetupButton(widget) and jqmNativeHostContains(scriptName, widget) then
      return widget
    end
    for _, child in ipairs(jqmChildren(widget)) do
      local found = scan(child, depth - 1)
      if found then return found end
    end
    return nil
  end

  local found = scan(host, 8)
  if found then
    if jqmCaptureNativeSetup(scriptName, found) then
      return jqmNativeRows[scriptName]
    end
  end
  return nil
end

local function jqmOpenNativeSetup(scriptName)
  local action = jqmNativeSetupActions[scriptName]
  if type(action) == "function" then
    local ok, err = pcall(action)
    if not ok then jqmWarn("erro ao abrir setup: " .. tostring(err)) end
    return ok
  end
  if not jqmNativeSetupButtons[scriptName] then
    jqmFindExistingNativeRow(scriptName)
  end
  local button = jqmNativeSetupButtons[scriptName]
  if button and type(button.onClick) == "function" then
    pcall(function() button.onClick(button) end)
    return true
  end
  return false
end

jqmPrepareProxySetup = function(scriptName)
  local item = jqmScriptItem(scriptName)
  local prefix = JQM_CARD_PREFIX[scriptName]
  if not item or not prefix then return end

  local loadButton = jqmWindowControl(prefix .. "Load")
  local action = jqmWindowControl(prefix .. "Action")
  local hint = jqmWindowControl(prefix .. "Hint")
  local gear = jqmWindowControl(prefix .. "Gear")
  jqmSetText(gear, "SETUP")
  jqmSetVisible(action, true)
  jqmSetVisible(hint, true)
  if not jqmNativeSetupButtons[scriptName] and not jqmNativeSetupActions[scriptName] then
    jqmFindExistingNativeRow(scriptName)
  end

  if jqmNativeSetupButtons[scriptName] or jqmNativeSetupActions[scriptName] then
    jqmSetVisible(loadButton, false)
    jqmSetText(action, "Clique em SETUP para configurar.")
    jqmSetText(hint, "")
    jqmSetColor(action, "#83f5a8")
    jqmSetColor(hint, "#7ee8a8")
    jqmSetBackground(gear, "#1f6f3add")
  else
    jqmSetVisible(loadButton, false)
    jqmSetText(action, "Setup original nao capturado.")
    jqmSetText(hint, "")
    jqmSetColor(action, "#c7d2d4")
    jqmSetColor(hint, "#9fb2c4")
    jqmSetBackground(gear, "#263747dd")
  end

  if loadButton then
    loadButton.onClick = function()
      if not jqmOpenNativeSetup(scriptName) then
        jqmWarn("setup nativo nao capturado: " .. jqmScriptLabel(scriptName))
      end
    end
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

local function jqmAllScriptNamesCsv()
  local names = {}
  for _, item in ipairs(JQM_SCRIPTS) do
    table.insert(names, item.name)
  end
  return table.concat(names, ",")
end

local function jqmAllowedCount()
  local count = 0
  for _, item in ipairs(JQM_SCRIPTS) do
    if jqmAllowedScripts[item.name] == true then count = count + 1 end
  end
  return count
end

local function jqmScriptAllowed(scriptName)
  return jqmPermissionsKnown == true and jqmAllowedScripts[scriptName] == true
end

local function jqmSetAllowedScripts(scriptNames)
  jqmAllowedScripts = {}
  for _, scriptName in ipairs(scriptNames or {}) do
    jqmAllowedScripts[scriptName] = true
  end
  jqmPermissionsKnown = true
  storage.JQMScriptManager.allowed = jqmAllowedScripts
  for _, item in ipairs(JQM_SCRIPTS) do
    storage.JQMScriptManager.selected[item.name] = jqmAllowedScripts[item.name] == true and jqmRuntimeLoaded[item.name] ~= true
  end
end

local function jqmSelectedSummary()
  if not jqmPermissionsKnown then return "Consultando permissoes..." end
  local allowed = jqmAllowedCount()
  if allowed == 0 then return "Nenhum script liberado" end
  local labels = jqmSelectedLabels()
  if #labels == 0 then
    if allowed == 1 then return "1 script liberado" end
    return tostring(allowed) .. " scripts liberados"
  end
  if #labels == 1 then return labels[1] end
  return tostring(#labels) .. " scripts selecionados"
end

local function jqmLoadedCount()
  local count = 0
  for _, item in ipairs(JQM_SCRIPTS) do
    if jqmRuntimeLoaded[item.name] == true then
      count = count + 1
    end
  end
  return count
end

local function jqmMainSummary()
  if not jqmPermissionsKnown then return "Consultando permissoes..." end
  local count = jqmLoadedCount()
  if count == 1 then return "1 produto ativo" end
  if count > 1 then return tostring(count) .. " produtos ativos" end
  if jqmAllowedCount() == 0 then return "Nenhum script liberado" end
  return "Selecionar scripts"
end

jqmScriptLabel = function(scriptName)
  for _, item in ipairs(JQM_SCRIPTS) do
    if item.name == scriptName then return item.label end
  end
  return tostring(scriptName or "")
end

jqmScriptItem = function(scriptName)
  for _, item in ipairs(JQM_SCRIPTS) do
    if item.name == scriptName then return item end
  end
  return nil
end

local function jqmModuleStatus(scriptName)
  if jqmRuntimeLoaded[scriptName] == true then
    return "Ativo", "#76ff9f", "#183820dd", "#dfffeb"
  end
  if storage.JQMScriptManager.selected[scriptName] == true then
    return "Marcado", "#ffd36b", "#2d2617dd", "#ffe6a3"
  end
  return "Inativo", "#ff6f6f", "#171b22dd", "#cfd8e3"
end

local function jqmSetManagerStatus(text)
  jqmSetText(jqmChild(jqmLauncher, "status") or jqmChild(jqmLauncher, "subtitle"), text)
  jqmSetText(jqmWindowControl("status"), text)
end

local function jqmSetModuleVisible(scriptName, visible)
  local prefix = JQM_CARD_PREFIX[scriptName]
  local categoryId = JQM_CATEGORY_CONTROLS[scriptName]
  if not prefix then return end
  local card = jqmWindowControl(prefix .. "Card")
  local category = categoryId and jqmWindowControl(categoryId) or nil
  jqmSetVisible(card, visible)
  jqmSetVisible(category, visible)
  jqmSetHeight(card, visible and 78 or 0)
  jqmSetHeight(category, visible and 15 or 0)
end

local function jqmUpdateModuleCard(item, hover)
  if not item then return end
  local prefix = JQM_CARD_PREFIX[item.name]
  if not prefix then return end
  local allowed = jqmScriptAllowed(item.name)
  jqmSetModuleVisible(item.name, allowed)
  if not allowed then return end

  local card = jqmWindowControl(prefix .. "Card")
  local icon = jqmWindowControl(prefix .. "Icon")
  local title = jqmWindowControl(prefix .. "Title")
  local desc = jqmWindowControl(prefix .. "Desc")
  local badge = jqmWindowControl(prefix .. "Badge")
  local gear = jqmWindowControl(prefix .. "Gear")
  local loadButton = jqmWindowControl(prefix .. "Load")
  local action = jqmWindowControl(prefix .. "Action")
  local hint = jqmWindowControl(prefix .. "Hint")
  local statusText, statusColor, bgColor, titleColor = jqmModuleStatus(item.name)
  local setupReady = jqmNativeSetupButtons[item.name] or jqmNativeSetupActions[item.name]

  if hover == true then
    bgColor = "#243041ee"
    titleColor = "#ffffff"
  end

  jqmSetText(icon, item.icon or "")
  jqmSetText(title, item.label)
  jqmSetText(desc, item.desc or item.file or "")
  jqmSetText(badge, statusText)
  if jqmRuntimeLoaded[item.name] == true then
    jqmSetText(gear, "SETUP")
    jqmSetVisible(loadButton, false)
    jqmSetVisible(action, true)
    jqmSetVisible(hint, true)
    if setupReady then
      jqmSetText(action, "Clique em SETUP para configurar.")
      jqmSetText(hint, "")
      jqmSetColor(action, "#83f5a8")
      jqmSetColor(hint, "#7ee8a8")
    else
      jqmSetText(action, "Setup original nao capturado.")
      jqmSetText(hint, "")
      jqmSetColor(action, "#ffd36b")
      jqmSetColor(hint, "#ffd36b")
    end
  elseif storage.JQMScriptManager.selected[item.name] == true then
    jqmSetText(gear, "Carregar")
    jqmSetVisible(loadButton, false)
    jqmSetVisible(action, true)
    jqmSetVisible(hint, true)
    jqmSetText(action, "Carregar agora")
    jqmSetText(hint, "Aguardando carregamento.")
    jqmSetColor(action, "#e6c06b")
    jqmSetColor(hint, "#ffd36b")
  else
    jqmSetText(gear, "Carregar")
    jqmSetVisible(loadButton, false)
    jqmSetVisible(action, true)
    jqmSetVisible(hint, true)
    jqmSetText(action, "Clique em Carregar para ativar.")
    jqmSetText(hint, "")
    jqmSetColor(action, "#d8e0e0")
    jqmSetColor(hint, "#9fb2c4")
  end
  jqmSetColor(badge, statusColor)
  jqmSetColor(title, titleColor)
  jqmSetColor(icon, statusColor)
  jqmSetColor(desc, "#9fb2c4")
  jqmSetColor(gear, jqmRuntimeLoaded[item.name] == true and "#ffffff" or (hover and "#ffd36b" or "#dce4ee"))
  if jqmRuntimeLoaded[item.name] == true then
    jqmSetBackground(gear, setupReady and "#1f6f3add" or "#263747dd")
  elseif storage.JQMScriptManager.selected[item.name] == true then
    jqmSetBackground(gear, "#2b5f83dd")
  else
    jqmSetBackground(gear, hover and "#344152dd" or "#252a32dd")
  end
  jqmSetBackground(card, bgColor)
end

local function jqmRefreshManagerUi()
  for _, item in ipairs(JQM_SCRIPTS) do
    jqmUpdateModuleCard(item, false)
    if jqmRuntimeLoaded[item.name] == true then
      jqmEnsureLoadedRow(item.name)
      jqmPrepareProxySetup(item.name)
    end
  end
  jqmSetText(jqmChild(jqmLauncher, "status") or jqmChild(jqmLauncher, "subtitle"), jqmMainSummary())
  jqmSetText(jqmWindowControl("status"), jqmSelectedSummary())
end

local jqmRequestSingle = nil

local function jqmActivateSelected(scriptName)
  storage.JQMScriptManager.selected[scriptName] = true
  jqmRefreshManagerUi()
  if type(jqmRequestSingle) == "function" then
    jqmRequestSingle(scriptName)
  end
end

local function jqmSetAllSelected(value)
  for _, item in ipairs(JQM_SCRIPTS) do
    storage.JQMScriptManager.selected[item.name] = value == true and jqmScriptAllowed(item.name)
  end
  jqmRefreshManagerUi()
end

jqmEnsureLoadedRow = function(scriptName)
  if jqmNativeRows[scriptName] then return jqmNativeRows[scriptName] end
  local existing = jqmFindExistingNativeRow(scriptName)
  if existing then
    jqmPrepareProxySetup(scriptName)
    return existing
  end
  local prefix = JQM_CARD_PREFIX[scriptName]
  if prefix then
    jqmSetText(jqmWindowControl(prefix .. "Action"), "Script carregado. Setup nativo nao exposto.")
    jqmSetText(jqmWindowControl(prefix .. "Hint"), "")
    jqmSetColor(jqmWindowControl(prefix .. "Action"), "#c7d2d4")
    jqmSetColor(jqmWindowControl(prefix .. "Hint"), "#9fb2c4")
    jqmSetText(jqmWindowControl(prefix .. "Gear"), "SETUP")
  end
  return jqmNativeHost(scriptName)
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

local function jqmPayloadEnv(scriptName)
  local env = jqmGlobals()
  if type(env) ~= "table" then env = {} end
  env._G = env
  env.parent = jqmNativeHost(scriptName)
  return env
end

local function jqmApplyPayloadEnv(fn, scriptName)
  if type(fn) ~= "function" then return fn end
  if type(setfenv) == "function" then
    pcall(function() setfenv(fn, jqmPayloadEnv(scriptName)) end)
  end
  return fn
end

local function jqmRunInManagerTab(scriptName, fn)
  local originalSetDefaultTab = setDefaultTab
  local originalGetTab = getTab
  local originalSetupUI = setupUI
  local originalLoadstring = loadstring
  local originalLoad = load
  local originalUICreateWidget = type(UI) == "table" and UI.createWidget or nil
  local originalUIButton = type(UI) == "table" and UI.Button or nil
  local originalGUiCreateWidget = type(g_ui) == "table" and g_ui.createWidget or nil
  local managerTab = jqmEnsureManagerTab()
  local nativeHost = jqmNativeHost(scriptName)

  local function selectManagerTab()
    local tab = nil
    if type(originalSetDefaultTab) == "function" then
      local ok, value = pcall(function() return originalSetDefaultTab(JQM_MANAGER_TAB) end)
      if ok and value then tab = value end
    end
    if not tab then tab = jqmEnsureManagerTab() end
    if tab then
      jqmManagerTab = tab
      parent = nativeHost or tab
    end
    return parent or tab
  end

  local function forcedGetTab()
    return selectManagerTab()
  end

  local function forcedSetDefaultTab()
    return selectManagerTab()
  end

  local function forcedSetupUI(ui, targetParent)
    if type(originalSetupUI) ~= "function" then return nil end
    local row = originalSetupUI(ui, targetParent or nativeHost or parent)
    if row then jqmMarkNativeReady(scriptName, row) end
    return row
  end

  local function forcedCreateWidget(originalCreateWidget)
    return function(className, targetParent, ...)
      local finalParent = targetParent
      if finalParent == nil and jqmNativeClassMatches(scriptName, className) then
        finalParent = nativeHost or parent
      end
      local widget = originalCreateWidget(className, finalParent, ...)
      if widget then
        jqmMarkNativeReady(scriptName, widget, className)
      end
      return widget
    end
  end

  local function forcedUIButton(text, callback, targetParent, ...)
    local finalParent = targetParent or nativeHost or parent
    local widget = nil
    if type(originalUIButton) == "function" then
      widget = originalUIButton(text, callback, finalParent, ...)
    end
    if type(callback) == "function" and not jqmNativeSetupActions[scriptName] then
      jqmRegisterNativeSetupAction(scriptName, function()
        if widget and type(widget.onClick) == "function" then
          return widget.onClick(widget)
        end
        return callback(widget)
      end, widget or nativeHost)
    end
    if widget then jqmMarkNativeReady(scriptName, widget) end
    return widget
  end

  local function wrapLoader(loader)
    return function(...)
      local loaded, loadErr = loader(...)
      if type(loaded) == "function" then
        loaded = jqmApplyPayloadEnv(loaded, scriptName)
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
  if type(originalSetupUI) == "function" then
    setupUI = forcedSetupUI
  end
  if type(originalUICreateWidget) == "function" and type(UI) == "table" then
    UI.createWidget = forcedCreateWidget(originalUICreateWidget)
  end
  if type(originalUIButton) == "function" and type(UI) == "table" then
    UI.Button = forcedUIButton
  end
  if type(originalGUiCreateWidget) == "function" and type(g_ui) == "table" then
    g_ui.createWidget = forcedCreateWidget(originalGUiCreateWidget)
  end
  if type(originalLoadstring) == "function" then
    loadstring = wrapLoader(originalLoadstring)
  end
  if type(originalLoad) == "function" then
    load = wrapLoader(originalLoad)
  end
  selectManagerTab()
  jqmApplyPayloadEnv(fn, scriptName)

  local ok, err = pcall(fn)

  if type(originalSetDefaultTab) == "function" then
    setDefaultTab = originalSetDefaultTab
  end
  if type(originalGetTab) == "function" then
    getTab = originalGetTab
  end
  if type(originalSetupUI) == "function" then
    setupUI = originalSetupUI
  end
  if type(originalUICreateWidget) == "function" and type(UI) == "table" then
    UI.createWidget = originalUICreateWidget
  end
  if type(originalUIButton) == "function" and type(UI) == "table" then
    UI.Button = originalUIButton
  end
  if type(originalGUiCreateWidget) == "function" and type(g_ui) == "table" then
    g_ui.createWidget = originalGUiCreateWidget
  end
  if type(originalLoadstring) == "function" then
    loadstring = originalLoadstring
  end
  if type(originalLoad) == "function" then
    load = originalLoad
  end
  if managerTab then parent = managerTab end

  return ok, err
end

local function jqmRunPayload(scriptName, data)
  if type(data) ~= "string" or data == "" then
    jqmWarn("payload vazio")
    return false
  end
  local responseStart = data:gsub("^%s+", "")
  if responseStart:sub(1, 1) == "{" then
    if responseStart:find("device_pending", 1, true) then
      jqmWarn(JQM_PENDING_MESSAGE)
    elseif responseStart:find("script_not_allowed", 1, true) then
      jqmWarn("script ainda nao liberado para este MAC.")
    else
      jqmWarn("servidor recusou: " .. responseStart:sub(1, 180))
    end
    return false
  end

  if jqmRuntimeLoaded[scriptName] == true then
    jqmEnsureLoadedRow(scriptName)
    jqmSetManagerStatus("Ja carregado")
    jqmWarn("ja carregado: " .. jqmScriptLabel(scriptName))
    return true
  end
  local fn, loadErr = jqmLoadChunk(data, "@jqm_" .. tostring(scriptName) .. ".lua")
  if not fn then
    jqmWarn("payload invalido: " .. tostring(loadErr))
    return false
  end
  local ok, runErr = jqmRunInManagerTab(scriptName, fn)
  if not ok then
    jqmWarn("erro no script: " .. tostring(runErr))
    return false
  end
  jqmRuntimeLoaded[scriptName] = true
  storage.JQMScriptManager.loaded[scriptName] = true
  jqmEnsureLoadedRow(scriptName)
  jqmSetManagerStatus(jqmMainSummary())
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

local function jqmLoadAllowedScripts()
  local any = false
  for _, item in ipairs(JQM_SCRIPTS) do
    if jqmAllowedScripts[item.name] == true then
      any = true
      storage.JQMScriptManager.selected[item.name] = jqmRuntimeLoaded[item.name] ~= true
      if jqmRuntimeLoaded[item.name] ~= true then
        JQMLoadScript(item.name)
      end
    else
      storage.JQMScriptManager.selected[item.name] = false
    end
  end
  jqmRefreshManagerUi()
  if not any then
    jqmSetManagerStatus("Nenhum script liberado")
  end
end

jqmAutoLoadAllowed = function(force)
  if jqmAutoLoadRunning == true then return end
  if jqmPermissionsKnown == true and force ~= true then
    jqmLoadAllowedScripts()
    return
  end
  jqmAutoLoadRunning = true
  jqmSetManagerStatus("Consultando permissoes...")

  jqmHttpGet(jqmBuildUrl("request", { scripts = jqmAllScriptNamesCsv() }), function(data, err)
    jqmAutoLoadRunning = false
    if err or not data then
      jqmSetManagerStatus("Falha ao consultar permissoes")
      jqmWarn("falha ao consultar permissoes: " .. tostring(err or "sem dados"))
      return
    end

    if data:find('"ok":true', 1, true) or data:find('"ok": true', 1, true) then
      local allowed = jqmScriptsFromResponse(data)
      jqmSetAllowedScripts(allowed)
      jqmRefreshManagerUi()
      if #allowed == 0 then
        jqmSetManagerStatus("Nenhum script liberado")
        jqmWarn("nenhum script liberado para este MAC.")
        return
      end
      jqmSetManagerStatus("Carregando liberados...")
      jqmLoadAllowedScripts()
      return
    end

    jqmSetAllowedScripts({})
    jqmRefreshManagerUi()
    jqmSetManagerStatus("Aguardando liberacao")
    jqmWarn(JQM_PENDING_MESSAGE)
  end)
end

local function jqmRequestOrLoad()
  jqmAutoLoadAllowed(true)
end

jqmRequestSingle = function(scriptName)
  if scriptName == nil or scriptName == "" then return end
  if not jqmPermissionsKnown then
    jqmAutoLoadAllowed(true)
    return
  end
  if not jqmScriptAllowed(scriptName) then
    jqmSetManagerStatus("Sem liberacao para " .. jqmScriptLabel(scriptName))
    jqmWarn("script ainda nao liberado para este MAC.")
    jqmRefreshManagerUi()
    return
  end
  storage.JQMScriptManager.selected[scriptName] = true
  jqmRefreshManagerUi()

  if jqmRuntimeLoaded[scriptName] == true then
    jqmEnsureLoadedRow(scriptName)
    jqmSetManagerStatus("Ja carregado")
    jqmWarn("ja carregado: " .. jqmScriptLabel(scriptName))
    return
  end

  jqmSetManagerStatus("Carregando " .. jqmScriptLabel(scriptName) .. "...")
  JQMLoadScript(scriptName)
end

local function jqmLoadManagerUi()
  if jqmUiLoaded then return true end
  if not g_ui or not g_ui.loadUIFromString then return false end

  local ok = pcall(function()
    g_ui.loadUIFromString([[
DerpetsonScriptHubPanel < Panel
  height: 58
  margin-top: 4
  padding: 5
  image-source: /images/ui/panel_flat
  image-border: 5
  background-color: #0d1719ee

  Label
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: open.left
    margin-right: 5
    height: 16
    text-align: left
    color: #f0c76a
    font: verdana-11px-bold
    text: Derpetson Scripts

  Label
    id: subtitle
    anchors.top: title.bottom
    anchors.left: parent.left
    anchors.right: open.left
    margin-top: 1
    margin-right: 5
    height: 14
    text-align: left
    color: #d5e8df
    font: verdana-11px
    text: Central de acesso

  Label
    id: status
    anchors.top: subtitle.bottom
    anchors.left: parent.left
    anchors.right: open.left
    margin-top: 2
    margin-right: 5
    height: 16
    text-align: left
    color: #7df0a1
    font: verdana-11px-bold
    text: Selecionar scripts

  Button
    id: open
    anchors.top: parent.top
    anchors.right: parent.right
    width: 52
    height: 46
    color: #ffffff
    background-color: #263747dd
    text-align: center
    text: Abrir

DerpetsonScriptsWindow < MainWindow
  text: Derpetson Scripts
  size: 480 585
  padding: 10
  @onEscape: self:hide()

  Panel
    id: headerPanel
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 76
    image-source: /images/ui/panel_flat
    image-border: 5
    padding: 8
    background-color: #0b1518ee

    Label
      id: headerRuneLeft
      anchors.left: parent.left
      anchors.top: parent.top
      width: 48
      height: 18
      text-align: left
      color: #385354
      font: verdana-11px-bold
      text: <::>

    Label
      id: headerRuneRight
      anchors.right: parent.right
      anchors.top: parent.top
      width: 48
      height: 18
      text-align: right
      color: #385354
      font: verdana-11px-bold
      text: <::>

    Label
      id: title
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 2
      height: 20
      text-align: center
      color: #f0c76a
      font: verdana-11px-bold
      text: Derpetson Scripts

    Label
      id: subtitle
      anchors.top: title.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 3
      height: 15
      text-align: center
      color: #e8f5ee
      font: verdana-11px
      text: Central simples para scripts liberados

    Label
      id: status
      anchors.top: subtitle.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 4
      height: 15
      text-align: center
      color: #83f5a8
      font: verdana-11px-bold
      text: Nenhum script selecionado

  Panel
    id: listPanel
    anchors.top: headerPanel.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 9
    height: 396
    image-source: /images/ui/panel_flat
    image-border: 5
    padding: 8
    background-color: #0d171add

    Label
      id: combatCategory
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: 15
      color: #f0c76a
      font: verdana-11px-bold
      text: [ATK] COMBATE

    Panel
      id: comboCard
      anchors.top: combatCategory.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 3
      height: 78
      padding: 6
      image-source: /images/ui/panel_flat
      image-border: 5
      background-color: #182126e8

      Label
        id: comboRune
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 48
        height: 14
        text-align: right
        color: #344747
        font: verdana-11px-bold
        text: r:atk

      Label
        id: comboIcon
        anchors.left: parent.left
        anchors.top: parent.top
        width: 30
        height: 64
        text-align: center
        color: #f0c76a
        font: verdana-11px-bold
        text: ATK

      Label
        id: comboTitle
        anchors.left: comboIcon.right
        anchors.right: comboBadge.left
        anchors.top: parent.top
        margin-left: 4
        margin-right: 4
        height: 16
        color: #f0c76a
        font: verdana-11px-bold
        text: COMBO ESPART V3

      Label
        id: comboDesc
        anchors.left: comboIcon.right
        anchors.right: comboGear.left
        anchors.top: comboTitle.bottom
        margin-left: 4
        margin-top: 1
        height: 14
        color: #b6c4c7
        font: verdana-11px
        text: Combo, runas e prioridades

      Label
        id: comboBadge
        anchors.right: comboGear.left
        anchors.top: parent.top
        margin-right: 4
        width: 58
        height: 16
        text-align: center
        color: #ff6f6f
        font: verdana-11px-bold
        text: Inativo

      Button
        id: comboGear
        anchors.right: parent.right
        anchors.top: parent.top
        width: 62
        height: 28
        color: #ffffff
        background-color: #263747dd
        text: Carregar

      Panel
        id: comboNative
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: comboDesc.bottom
        margin-top: 6
        height: 30
        padding: 1
        image-source: /images/ui/panel_flat
        image-border: 5
        background-color: #0b1114dd

        Label
          id: comboAction
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          margin-top: 2
          height: 14
          text-align: center
          color: #e9f4f0
          font: verdana-11px-bold
          text: Clique em Carregar para ativar.

        Label
          id: comboHint
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: comboAction.bottom
          height: 12
          text-align: center
          color: #9fb2c4
          font: verdana-11px
          text:

    Label
      id: castleCategory
      anchors.top: comboCard.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 8
      height: 15
      color: #f0c76a
      font: verdana-11px-bold
      text: [CST] CASTLE

    Panel
      id: castleCard
      anchors.top: castleCategory.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 3
      height: 78
      padding: 6
      image-source: /images/ui/panel_flat
      image-border: 5
      background-color: #182126e8

      Label
        id: castleRune
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 48
        height: 14
        text-align: right
        color: #344747
        font: verdana-11px-bold
        text: r:cst

      Label
        id: castleIcon
        anchors.left: parent.left
        anchors.top: parent.top
        width: 30
        height: 64
        text-align: center
        color: #f0c76a
        font: verdana-11px-bold
        text: CST

      Label
        id: castleTitle
        anchors.left: castleIcon.right
        anchors.right: castleBadge.left
        anchors.top: parent.top
        margin-left: 4
        margin-right: 4
        height: 16
        color: #f0c76a
        font: verdana-11px-bold
        text: CASTLE PRO

      Label
        id: castleDesc
        anchors.left: castleIcon.right
        anchors.right: castleGear.left
        anchors.top: castleTitle.bottom
        margin-left: 4
        margin-top: 1
        height: 14
        color: #b6c4c7
        font: verdana-11px
        text: Castle, seguranca e logout

      Label
        id: castleBadge
        anchors.right: castleGear.left
        anchors.top: parent.top
        margin-right: 4
        width: 58
        height: 16
        text-align: center
        color: #ff6f6f
        font: verdana-11px-bold
        text: Inativo

      Button
        id: castleGear
        anchors.right: parent.right
        anchors.top: parent.top
        width: 62
        height: 28
        color: #ffffff
        background-color: #263747dd
        text: Carregar

      Panel
        id: castleNative
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: castleDesc.bottom
        margin-top: 6
        height: 30
        padding: 1
        image-source: /images/ui/panel_flat
        image-border: 5
        background-color: #0b1114dd

        Label
          id: castleAction
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          margin-top: 2
          height: 14
          text-align: center
          color: #e9f4f0
          font: verdana-11px-bold
          text: Clique em Carregar para ativar.

        Label
          id: castleHint
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: castleAction.bottom
          height: 12
          text-align: center
          color: #9fb2c4
          font: verdana-11px
          text:

    Label
      id: defenseCategory
      anchors.top: castleCard.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 8
      height: 15
      color: #f0c76a
      font: verdana-11px-bold
      text: [DEF] DEFESA

    Panel
      id: holidayCard
      anchors.top: defenseCategory.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 3
      height: 78
      padding: 6
      image-source: /images/ui/panel_flat
      image-border: 5
      background-color: #182126e8

      Label
        id: holidayRune
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 48
        height: 14
        text-align: right
        color: #344747
        font: verdana-11px-bold
        text: r:def

      Label
        id: holidayIcon
        anchors.left: parent.left
        anchors.top: parent.top
        width: 30
        height: 64
        text-align: center
        color: #f0c76a
        font: verdana-11px-bold
        text: DEF

      Label
        id: holidayTitle
        anchors.left: holidayIcon.right
        anchors.right: holidayBadge.left
        anchors.top: parent.top
        margin-left: 4
        margin-right: 4
        height: 16
        color: #f0c76a
        font: verdana-11px-bold
        text: HOLIDAY AOE

      Label
        id: holidayDesc
        anchors.left: holidayIcon.right
        anchors.right: holidayGear.left
        anchors.top: holidayTitle.bottom
        margin-left: 4
        margin-top: 1
        height: 14
        color: #b6c4c7
        font: verdana-11px
        text: Area, combo e PvP

      Label
        id: holidayBadge
        anchors.right: holidayGear.left
        anchors.top: parent.top
        margin-right: 4
        width: 58
        height: 16
        text-align: center
        color: #ff6f6f
        font: verdana-11px-bold
        text: Inativo

      Button
        id: holidayGear
        anchors.right: parent.right
        anchors.top: parent.top
        width: 62
        height: 28
        color: #ffffff
        background-color: #263747dd
        text: Carregar

      Panel
        id: holidayNative
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: holidayDesc.bottom
        margin-top: 6
        height: 30
        padding: 1
        image-source: /images/ui/panel_flat
        image-border: 5
        background-color: #0b1114dd

        Label
          id: holidayAction
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          margin-top: 2
          height: 14
          text-align: center
          color: #e9f4f0
          font: verdana-11px-bold
          text: Clique em Carregar para ativar.

        Label
          id: holidayHint
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: holidayAction.bottom
          height: 12
          text-align: center
          color: #9fb2c4
          font: verdana-11px
          text:

    Label
      id: utilityCategory
      anchors.top: holidayCard.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 8
      height: 15
      color: #f0c76a
      font: verdana-11px-bold
      text: [CFG] UTILIDADES

    Panel
      id: updateCard
      anchors.top: utilityCategory.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 3
      height: 40
      padding: 6
      image-source: /images/ui/panel_flat
      image-border: 5
      background-color: #182126e8

      Label
        id: updateIcon
        anchors.left: parent.left
        anchors.top: parent.top
        width: 30
        height: 28
        text-align: center
        color: #f0c76a
        font: verdana-11px-bold
        text: CFG

      Label
        id: updateTitle
        anchors.left: updateIcon.right
        anchors.right: updateBadge.left
        anchors.top: parent.top
        margin-left: 4
        margin-right: 4
        height: 15
        color: #f0c76a
        font: verdana-11px-bold
        text: Atualizador

      Label
        id: updateDesc
        anchors.left: updateIcon.right
        anchors.right: updateBadge.left
        anchors.top: updateTitle.bottom
        margin-left: 4
        height: 12
        color: #9fb2c4
        font: verdana-11px
        text: Jequi remoto

      Label
        id: updateBadge
        anchors.right: parent.right
        anchors.top: parent.top
        width: 48
        height: 16
        text-align: center
        color: #76ff9f
        font: verdana-11px-bold
        text: Ativo

  Panel
    id: helpPanel
    anchors.top: listPanel.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 8
    height: 44
    image-source: /images/ui/panel_flat
    image-border: 5
    background-color: #0b1116ee

    Label
      id: helpTitle
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 6
      height: 15
      text-align: center
      color: #f0c76a
      font: verdana-11px-bold
      text: Status

    Label
      id: helpLine1
      anchors.top: helpTitle.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 3
      height: 15
      text-align: center
      color: #d8e0e0
      font: verdana-11px
      text: Ativo / Marcado / Inativo

  Panel
    id: footer
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 30

    Button
      id: allButton
      anchors.left: parent.left
      anchors.top: parent.top
      width: 72
      height: 26
      color: #e8edf4
      background-color: #242a30dd
      text: Todos

    Button
      id: clearButton
      anchors.left: allButton.right
      anchors.top: parent.top
      margin-left: 5
      width: 66
      height: 26
      color: #e8edf4
      background-color: #242a30dd
      text: Limpar

    Button
      id: confirmButton
      anchors.left: clearButton.right
      anchors.right: closeButton.left
      anchors.top: parent.top
      margin-left: 5
      margin-right: 5
      height: 26
      color: #ffffff
      background-color: #314351dd
      text: Carregar todos

    Button
      id: closeButton
      anchors.right: parent.right
      anchors.top: parent.top
      width: 62
      height: 26
      color: #e8edf4
      background-color: #242a30dd
      text: Fechar
]])
  end)

  jqmUiLoaded = ok == true
  return jqmUiLoaded
end

jqmCreateWindow = function()
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
  local function bindModuleCard(scriptName)
    local item = jqmScriptItem(scriptName)
    local prefix = JQM_CARD_PREFIX[scriptName]
    if not item or not prefix then return end

    local function loadModule()
      jqmActivateSelected(scriptName)
    end
    local function setupOrLoadModule()
      if jqmRuntimeLoaded[scriptName] == true then
        if jqmOpenNativeSetup(scriptName) then return end
        jqmWarn("setup nativo nao capturado: " .. jqmScriptLabel(scriptName))
        return
      end
      loadModule()
    end
    local function hoverModule(_, hovered)
      jqmUpdateModuleCard(item, hovered == true)
    end

    for _, suffix in ipairs({ "Card", "Icon", "Title", "Desc", "Badge" }) do
      local widget = jqmWindowControl(prefix .. suffix)
      if widget then
        widget.onClick = loadModule
        widget.onHoverChange = hoverModule
      end
    end

    local gear = jqmWindowControl(prefix .. "Gear")
    if gear then
      gear.onClick = setupOrLoadModule
      gear.onHoverChange = hoverModule
    end

    local loadButton = jqmWindowControl(prefix .. "Load")
    if loadButton then
      loadButton.onClick = function()
        if jqmRuntimeLoaded[scriptName] == true then
          if jqmOpenNativeSetup(scriptName) then return end
          jqmWarn("setup nativo nao capturado: " .. jqmScriptLabel(scriptName))
          return
        end
        loadModule()
      end
      loadButton.onHoverChange = hoverModule
    end
  end

  bindModuleCard("combo")
  bindModuleCard("castle_manager")
  bindModuleCard("holiday_aoe")

  jqmRefreshManagerUi()
  return jqmWindow
end

jqmOpenManager = function()
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

jqmGlobal.JQMOpenManager = jqmOpenManager

local function jqmBindClick(widget, fn)
  if not widget or type(fn) ~= "function" then return false end
  widget.onClick = function()
    fn()
    return true
  end
  widget.onMouseRelease = function()
    fn()
    return true
  end
  return true
end

local function jqmWidgetAlive(widget)
  if not widget then return false end
  if widget.isDestroyed then
    local ok, destroyed = pcall(function() return widget:isDestroyed() end)
    if ok and destroyed then return false end
  end
  if widget.getParent then
    local ok, parentWidget = pcall(function() return widget:getParent() end)
    if ok and not parentWidget then return false end
  end
  return true
end

local function jqmIsDerpetsonLauncher(widget)
  if not widget then return false end
  if jqmGetText(widget) == "Derpetson Scripts" then return true end
  if jqmGetText(jqmChild(widget, "title")) == "Derpetson Scripts" then return true end
  for _, child in ipairs(jqmChildren(widget)) do
    if jqmGetText(child) == "Derpetson Scripts" then return true end
  end
  return false
end

local function jqmOpenFromLauncher()
  if type(jqmGlobal.DerpetsonLauncherOpen) == "function" then
    jqmGlobal.DerpetsonLauncherOpen()
    return
  end
  jqmOpenManager()
end

local function jqmCleanupDuplicateLaunchers(keep)
  local tab = jqmEnsureManagerTab()
  if not tab or not tab.getChildren then return end
  local ok, children = pcall(function() return tab:getChildren() end)
  if not ok or type(children) ~= "table" then return end

  for _, child in ipairs(children) do
    if child and child ~= keep and child.destroy then
      if jqmIsDerpetsonLauncher(child) then
        pcall(function() child:destroy() end)
        if jqmGlobal.DerpetsonLauncherRow == child then jqmGlobal.DerpetsonLauncherRow = nil end
        if jqmGlobal.JQMScriptManagerBridgeLauncher == child then jqmGlobal.JQMScriptManagerBridgeLauncher = nil end
        if jqmGlobal.JQMScriptManagerLauncher == child then jqmGlobal.JQMScriptManagerLauncher = nil end
      end
    end
  end
end

local function jqmUseExternalLauncher()
  local external = jqmGlobal.DerpetsonLauncherRow
  if not jqmWidgetAlive(external) then external = jqmGlobal.JQMScriptManagerBridgeLauncher end
  if not jqmWidgetAlive(external) then external = jqmGlobal.JQMScriptManagerLauncher end
  if not jqmWidgetAlive(external) then return false end

  local old = jqmGlobal.JQMScriptManagerLauncher
  if old and old ~= external and old.destroy then
    pcall(function() old:destroy() end)
  end

  jqmLauncher = external
  jqmGlobal.DerpetsonLauncherRow = external
  jqmGlobal.JQMScriptManagerBridgeLauncher = external
  jqmGlobal.JQMScriptManagerLauncher = external
  jqmCleanupDuplicateLaunchers(external)
  jqmBindClick(jqmChild(jqmLauncher, "open") or jqmChild(jqmLauncher, "openButton"), jqmOpenFromLauncher)
  jqmBindClick(jqmChild(jqmLauncher, "title"), jqmOpenFromLauncher)
  jqmBindClick(jqmChild(jqmLauncher, "subtitle"), jqmOpenFromLauncher)
  jqmBindClick(jqmChild(jqmLauncher, "status"), jqmOpenFromLauncher)
  jqmBindClick(jqmLauncher, jqmOpenFromLauncher)
  jqmRefreshManagerUi()
  return true
end

local function jqmCreateSetupLauncher()
  if jqmLauncher or type(setupUI) ~= "function" then return false end
  local okPanel, panel = pcall(function()
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
    @onClick: JQMOpenManager()

  Label
    id: status
    anchors.left: parent.left
    anchors.top: title.bottom
    anchors.right: open.left
    margin-right: 5
    height: 16
    color: #7ee8a8
    font: verdana-11px-bold
    text: Selecionar scripts
    @onClick: JQMOpenManager()

  Button
    id: open
    anchors.right: parent.right
    anchors.top: parent.top
    width: 54
    height: 40
    text: Abrir
    @onClick: JQMOpenManager()
]])
  end)
  if not okPanel or not panel then return false end
  jqmLauncher = panel
  jqmGlobal.DerpetsonLauncherRow = panel
  jqmGlobal.JQMScriptManagerBridgeLauncher = panel
  jqmGlobal.JQMScriptManagerLauncher = panel
  jqmCleanupDuplicateLaunchers(panel)
  jqmBindClick(jqmChild(jqmLauncher, "open"), jqmOpenFromLauncher)
  jqmBindClick(jqmChild(jqmLauncher, "title"), jqmOpenFromLauncher)
  jqmBindClick(jqmChild(jqmLauncher, "status"), jqmOpenFromLauncher)
  jqmBindClick(jqmLauncher, jqmOpenFromLauncher)
  jqmRefreshManagerUi()
  return true
end

if not jqmUseExternalLauncher() and not jqmCreateSetupLauncher() and jqmLoadManagerUi() and UI and UI.createWidget then
  local okPanel, panel = pcall(function()
    if UI and UI.createWidget then
      return UI.createWidget("DerpetsonScriptHubPanel", jqmEnsureManagerTab())
    end
    return nil
  end)
  if okPanel and panel then
    jqmLauncher = panel
    jqmGlobal.DerpetsonLauncherRow = panel
    jqmGlobal.JQMScriptManagerBridgeLauncher = panel
    jqmGlobal.JQMScriptManagerLauncher = panel
    jqmCleanupDuplicateLaunchers(panel)
    jqmBindClick(jqmChild(jqmLauncher, "open"), jqmOpenFromLauncher)
    jqmBindClick(jqmChild(jqmLauncher, "title"), jqmOpenFromLauncher)
    jqmBindClick(jqmChild(jqmLauncher, "subtitle"), jqmOpenFromLauncher)
    jqmBindClick(jqmChild(jqmLauncher, "status"), jqmOpenFromLauncher)
    jqmBindClick(jqmLauncher, jqmOpenFromLauncher)
    jqmRefreshManagerUi()
  elseif UI and UI.Button then
    local button = UI.Button("Derpetson Scripts", jqmOpenManager, jqmEnsureManagerTab())
    jqmLauncher = button
    jqmGlobal.DerpetsonLauncherRow = button
    jqmGlobal.JQMScriptManagerBridgeLauncher = button
    jqmGlobal.JQMScriptManagerLauncher = button
    jqmCleanupDuplicateLaunchers(button)
  end
elseif UI and UI.Button then
  local button = UI.Button("Derpetson Scripts", jqmOpenManager, jqmEnsureManagerTab())
  jqmLauncher = button
  jqmGlobal.DerpetsonLauncherRow = button
  jqmGlobal.JQMScriptManagerBridgeLauncher = button
  jqmGlobal.JQMScriptManagerLauncher = button
  jqmCleanupDuplicateLaunchers(button)
end

jqmRefreshManagerUi()
if jqmGlobal.JQMScriptManagerAutoLoadVersion ~= JQM_MANAGER_VERSION then
  jqmGlobal.JQMScriptManagerAutoLoadVersion = JQM_MANAGER_VERSION
  jqmAutoLoadAllowed(false)
end
