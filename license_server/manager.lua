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
local JQM_MANAGER_VERSION = 2026061229
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

local JQM_NATIVE_TITLES = {
  combo = { "Combo System", "SMART PVP", "COMBO ESPART", "COMBO ESPART V3" },
  holiday_aoe = { "Holiday AOE", "HOLIDAY AOE" },
  castle_manager = { "Castle Manager", "CASTLE PRO", "Castle_Manager" }
}

local JQM_NATIVE_WIDGET_CLASSES = {
  castle_manager = { "CastleManagerBotPanel" }
}

local JQM_SETUP_IDS = { "setup", "Setup", "push", "edit", "cfg", "config" }

local JQM_MENU_ITEMS = {
  { id = "dashboard", label = "Dashboard", module = nil },
  { id = "combat", label = "Combate", module = "combo" },
  { id = "pvp", label = "PvP", module = "combo" },
  { id = "castle", label = "Castle", module = "castle_manager" },
  { id = "defense", label = "Defesa", module = "holiday_aoe" },
  { id = "utility", label = "Utilidades", module = nil },
  { id = "general", label = "Geral", module = nil }
}

local JQM_MENU_CONTROL_IDS = {
  dashboard = "navDashboard",
  combat = "navCombat",
  pvp = "navPvp",
  castle = "navCastle",
  defense = "navDefense",
  utility = "navUtility",
  general = "navGeneral"
}

local JQM_MODULE_DETAIL = {
  combo = {
    title = "Combo Espart V3",
    category = "Combate / PvP",
    storageKey = "ComboSystem_MultiLideres",
    summary = {
      { label = "Caller", key = "callersText", default = "nao definido" },
      { label = "Delay", key = "comboSpellStepMs", default = 500, suffix = "ms" },
      { label = "Modo", key = "smartRotationEnabled", default = false, on = "Inteligente", off = "Manual" }
    },
    config = {
      { label = "Caller", key = "callersText", default = "" },
      { label = "Chat", key = "chatName", default = "ESPARTANOS" },
      { label = "Delay combo", key = "comboSpellStepMs", default = 500, kind = "number", suffix = "ms" },
      { label = "Cooldown", key = "comboSpellCooldownMs", default = 700, kind = "number", suffix = "ms" },
      { label = "Smart rotation", key = "smartRotationEnabled", default = false, kind = "bool" },
      { label = "Trap", key = "trapEnabled", default = false, kind = "bool" }
    }
  },
  castle_manager = {
    title = "Castle Pro",
    category = "Castle",
    storageKey = "CastleManagerPro",
    summary = {
      { label = "Area", key = "ultimaArea", default = "-" },
      { label = "Logout", key = "timeoutLogoutMin", default = 3, suffix = " min" },
      { label = "Whitelist", key = "usarWhitelist", default = true, on = "Ligada", off = "Desligada" }
    },
    config = {
      { label = "Guilds aliadas", key = "guildsAliadasText", default = "" },
      { label = "Guilds inimigas", key = "guildsInimigasText", default = "" },
      { label = "Espera dominio", key = "tempoEsperaDominioMin", default = 10, kind = "number", suffix = " min" },
      { label = "Timeout logout", key = "timeoutLogoutMin", default = 3, kind = "number", suffix = " min" },
      { label = "Whitelist", key = "usarWhitelist", default = true, kind = "bool" },
      { label = "Check PZ", key = "usarCheckPzComando", default = true, kind = "bool" }
    }
  },
  holiday_aoe = {
    title = "Holiday AOE",
    category = "Defesa",
    storageKey = "holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii",
    summary = {
      { label = "Vocacao", key = "forceVocation", default = "auto" },
      { label = "Loop", key = "mainLoopMs", default = 100, suffix = "ms" },
      { label = "Safe mode", key = "pveSafeMode", default = false, on = "ON", off = "OFF" }
    },
    config = {
      { label = "Vocacao", key = "forceVocation", default = "knight" },
      { label = "Loop combate", key = "mainLoopMs", default = 100, kind = "number", suffix = "ms" },
      { label = "Scan", key = "scanIntervalMs", default = 150, kind = "number", suffix = "ms" },
      { label = "Min wave mobs", key = "minWaveMobs", default = 1, kind = "number" },
      { label = "Safe mode", key = "pveSafeMode", default = false, kind = "bool" },
      { label = "Combo mode", key = "enableComboMode", default = false, kind = "bool" }
    }
  }
}

local JQM_STATUS_THEME = {
  active = { text = "ATIVO", color = "#76ff9f", bg = "#17281cdd" },
  inactive = { text = "INATIVO", color = "#ff7b7b", bg = "#251616dd" },
  paused = { text = "PAUSADO", color = "#ffd36b", bg = "#2d2617dd" },
  error = { text = "ERRO", color = "#ff9b52", bg = "#2a1b12dd" },
  loading = { text = "CARREGANDO", color = "#6bb7ff", bg = "#152233dd" }
}

local jqmWindow = nil
local jqmLauncher = nil
local jqmUiLoaded = false
local jqmManagerTab = nil
local jqmLoadedRows = {}
local jqmNativeRows = {}
local jqmNativeSetupButtons = {}
local jqmOpenManager = nil
local jqmCreateWindow = nil
local jqmScriptLabel = nil
local jqmScriptItem = nil
local jqmWarn = nil
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
  for _, parentId in ipairs({ "headerPanel", "statsPanel", "sidePanel", "mainPanel", "moduleListPanel", "detailPanel", "configPanel", "nativeBridgePanel", "listPanel", "helpPanel", "footer" }) do
    local panel = jqmChild(jqmWindow, parentId)
    local child = jqmChild(panel, id)
    if child then return child end
  end
  return nil
end

storage.JQMScriptManager = type(storage.JQMScriptManager) == "table" and storage.JQMScriptManager or {}
storage.JQMScriptManager.selected = type(storage.JQMScriptManager.selected) == "table" and storage.JQMScriptManager.selected or {}
storage.JQMScriptManager.loaded = type(storage.JQMScriptManager.loaded) == "table" and storage.JQMScriptManager.loaded or {}
storage.JQMScriptManager.view = storage.JQMScriptManager.view or "dashboard"
storage.JQMScriptManager.focus = storage.JQMScriptManager.focus or "combo"
storage.Combo = type(storage.Combo) == "table" and storage.Combo or {}
storage.Combo.licenseKey = storage.Combo.licenseKey or ""

local jqmUiSyncing = false
local jqmConfigRowBindings = {}

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

local function jqmSetTooltip(widget, text)
  if widget and widget.setTooltip then
    pcall(function() widget:setTooltip(tostring(text or "")) end)
  end
end

local function jqmMenuItem(viewId)
  for _, item in ipairs(JQM_MENU_ITEMS) do
    if item.id == viewId then return item end
  end
  return JQM_MENU_ITEMS[1]
end

local function jqmDetail(scriptName)
  return JQM_MODULE_DETAIL[scriptName]
end

local function jqmModuleStorage(scriptName)
  local detail = jqmDetail(scriptName)
  if not detail or not detail.storageKey then return nil end
  storage[detail.storageKey] = type(storage[detail.storageKey]) == "table" and storage[detail.storageKey] or {}
  return storage[detail.storageKey]
end

local function jqmConfigValue(scriptName, field)
  local data = jqmModuleStorage(scriptName)
  if not data or not field then return field and field.default or "" end
  if data[field.key] == nil then
    data[field.key] = field.default
  end
  return data[field.key]
end

local function jqmFormatConfigValue(scriptName, field)
  local value = jqmConfigValue(scriptName, field)
  if field and field.kind == "bool" then
    return value == true and "ON" or "OFF"
  end
  if type(value) == "boolean" then
    if field and field.on and field.off then
      return value and field.on or field.off
    end
    return value and "ON" or "OFF"
  end
  if value == nil or value == "" then value = field and field.default or "" end
  return tostring(value or "") .. tostring(field and field.suffix or "")
end

local function jqmParseConfigValue(field, text)
  if field and field.kind == "bool" then
    local value = tostring(text or ""):lower()
    return value == "on" or value == "true" or value == "1" or value == "sim" or value == "ativo"
  end
  if field and field.kind == "number" then
    local number = tonumber(tostring(text or ""):match("%-?%d+"))
    return number or tonumber(field.default) or 0
  end
  return tostring(text or "")
end

local function jqmSetConfigValue(scriptName, field, value)
  local data = jqmModuleStorage(scriptName)
  if not data or not field then return end
  data[field.key] = value
end

local function jqmModuleEnabled(scriptName)
  local data = jqmModuleStorage(scriptName)
  if scriptName == "holiday_aoe" and data then
    return data.enablePveMode == true or data.enablePvpMode == true or data.enableComboMode == true
  end
  if data and data.enabled ~= nil then return data.enabled == true end
  return jqmRuntimeLoaded[scriptName] == true
end

local function jqmSetModuleEnabled(scriptName, enabled)
  local data = jqmModuleStorage(scriptName)
  if data then
    if scriptName == "holiday_aoe" then
      data.enablePveMode = enabled == true
      if enabled ~= true then
        data.enablePvpMode = false
        data.enableComboMode = false
      end
    else
      data.enabled = enabled == true
    end
  end
  if scriptName == "castle_manager" then
    local api = jqmGlobal.CastleManager
    if type(api) == "table" and type(api.setEnabled) == "function" then
      pcall(function() api.setEnabled(enabled == true) end)
    end
  elseif scriptName == "holiday_aoe" then
    local api = jqmGlobal.HolidayAOE
    if type(api) == "table" and type(api.setEnabled) == "function" then
      pcall(function() api.setEnabled(enabled == true) end)
    end
  end
end

local function jqmModuleStateKey(scriptName)
  if jqmRuntimeLoaded[scriptName] ~= true then return "inactive" end
  if jqmModuleEnabled(scriptName) then return "active" end
  return "paused"
end

local function jqmStatusTheme(state)
  return JQM_STATUS_THEME[state or "inactive"] or JQM_STATUS_THEME.inactive
end

local function jqmSelectView(viewId, scriptName)
  local menu = jqmMenuItem(viewId)
  storage.JQMScriptManager.view = menu.id
  storage.JQMScriptManager.focus = scriptName or menu.module or storage.JQMScriptManager.focus or "combo"
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
      jqmSetText(jqmWindowControl(prefix .. "Gear"), "CFG")
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

jqmCaptureNativeSetup = function(scriptName, row, className)
  if not scriptName or not row then return false end
  local button = jqmFindSetupButton(row)
  if not button then return false end
  if not jqmNativeWidgetMatches(scriptName, row, className) then return false end

  jqmNativeRows[scriptName] = row
  jqmNativeSetupButtons[scriptName] = button
  return true
end

local function jqmFindExistingNativeRow(scriptName)
  if jqmNativeRows[scriptName] and jqmNativeSetupButtons[scriptName] then return jqmNativeRows[scriptName] end
  local tab = jqmEnsureManagerTab()
  local titles = JQM_NATIVE_TITLES[scriptName]
  if not tab or not titles then return nil end

  local function scan(widget, depth)
    if not widget or depth <= 0 then return nil end
    if widget ~= jqmLauncher and jqmDirectSetupButton(widget) and jqmWidgetTreeHasText(widget, titles, 2) then
      return widget
    end
    for _, child in ipairs(jqmChildren(widget)) do
      local found = scan(child, depth - 1)
      if found then return found end
    end
    return nil
  end

  local found = scan(tab, 8)
  if found then
    if jqmCaptureNativeSetup(scriptName, found) then
      return jqmNativeRows[scriptName]
    end
  end
  return nil
end

local function jqmOpenNativeSetup(scriptName)
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
  local hint = jqmWindowControl(prefix .. "Hint")
  jqmSetText(jqmWindowControl(prefix .. "Gear"), "CFG")
  jqmSetVisible(loadButton, true)
  jqmSetVisible(hint, true)
  if not jqmNativeSetupButtons[scriptName] then
    jqmFindExistingNativeRow(scriptName)
  end

  if jqmNativeSetupButtons[scriptName] then
    jqmSetText(loadButton, "Abrir Setup " .. (item.short or item.label))
    jqmSetText(hint, "Setup original capturado dentro da central.")
    jqmSetColor(hint, "#7ee8a8")
  else
    jqmSetText(loadButton, "Setup nao capturado")
    jqmSetText(hint, "Reinicie o bot e carregue este modulo pela central.")
    jqmSetColor(hint, "#ffd36b")
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

local function jqmSelectedSummary()
  local labels = jqmSelectedLabels()
  if #labels == 0 then return "Nenhum script selecionado" end
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

local function jqmCountByState(state)
  local count = 0
  for _, item in ipairs(JQM_SCRIPTS) do
    if jqmModuleStateKey(item.name) == state then count = count + 1 end
  end
  return count
end

local function jqmMainSummary()
  local count = jqmCountByState("active")
  if count == 1 then return "1 produto ativo" end
  if count > 1 then return tostring(count) .. " produtos ativos" end
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
  local state = jqmModuleStateKey(scriptName)
  local theme = jqmStatusTheme(state)
  local titleColor = state == "inactive" and "#cfd8e3" or "#f3f7ff"
  return theme.text, theme.color, theme.bg, titleColor
end

local function jqmSetManagerStatus(text)
  jqmSetText(jqmChild(jqmLauncher, "status") or jqmChild(jqmLauncher, "subtitle"), text)
  jqmSetText(jqmWindowControl("status"), text)
end

local function jqmUpdateModuleCard(item, hover)
  if not item then return end
  local prefix = JQM_CARD_PREFIX[item.name]
  if not prefix then return end

  local card = jqmWindowControl(prefix .. "Card")
  local icon = jqmWindowControl(prefix .. "Icon")
  local title = jqmWindowControl(prefix .. "Title")
  local desc = jqmWindowControl(prefix .. "Desc")
  local badge = jqmWindowControl(prefix .. "Badge")
  local gear = jqmWindowControl(prefix .. "Gear")
  local statusText, statusColor, bgColor, titleColor = jqmModuleStatus(item.name)
  local selected = storage.JQMScriptManager.focus == item.name

  if hover == true then
    bgColor = "#243041ee"
    titleColor = "#ffffff"
  elseif selected then
    bgColor = "#223044ee"
    titleColor = "#ffffff"
  end

  jqmSetText(icon, item.icon or "")
  jqmSetText(title, item.short or item.label)
  jqmSetText(desc, item.desc or item.file or "")
  jqmSetText(badge, statusText)
  jqmSetColor(badge, statusColor)
  jqmSetColor(title, titleColor)
  jqmSetColor(icon, statusColor)
  jqmSetColor(desc, "#9fb2c4")
  jqmSetColor(gear, hover and "#ffd36b" or "#dce4ee")
  jqmSetBackground(card, bgColor)
end

local function jqmRenderStats()
  jqmSetText(jqmWindowControl("activeCount"), tostring(jqmCountByState("active")))
  jqmSetText(jqmWindowControl("pausedCount"), tostring(jqmCountByState("paused")))
  jqmSetText(jqmWindowControl("inactiveCount"), tostring(jqmCountByState("inactive")))
  jqmSetText(jqmWindowControl("totalCount"), tostring(#JQM_SCRIPTS))
  jqmSetText(jqmWindowControl("status"), jqmMainSummary())
end

local function jqmRenderMenu()
  local current = storage.JQMScriptManager.view or "dashboard"
  for _, item in ipairs(JQM_MENU_ITEMS) do
    local button = jqmWindowControl(JQM_MENU_CONTROL_IDS[item.id])
    if button then
      local selected = item.id == current
      jqmSetText(button, item.label)
      jqmSetColor(button, selected and "#ffffff" or "#cfd8e3")
      jqmSetBackground(button, selected and "#26364dee" or "#141a23dd")
    end
  end
end

local function jqmSummaryLine(scriptName, index)
  local detail = jqmDetail(scriptName)
  local field = detail and detail.summary and detail.summary[index]
  if not field then return "" end
  return tostring(field.label or "") .. ": " .. jqmFormatConfigValue(scriptName, field)
end

local function jqmSetConfigRow(index, label, value, field, scriptName)
  local row = jqmWindowControl("configRow" .. tostring(index))
  local labelWidget = jqmWindowControl("configLabel" .. tostring(index))
  local editWidget = jqmWindowControl("configValue" .. tostring(index))
  local actionWidget = jqmWindowControl("configAction" .. tostring(index))
  jqmConfigRowBindings[index] = field and { scriptName = scriptName, field = field } or nil

  if not field then
    jqmSetVisible(row, false)
    return
  end

  jqmSetVisible(row, true)
  jqmSetText(labelWidget, label or "")
  jqmUiSyncing = true
  jqmSetText(editWidget, value or "")
  jqmUiSyncing = false

  if field.kind == "bool" then
    jqmSetVisible(actionWidget, true)
    jqmSetText(actionWidget, "Alternar")
    jqmSetColor(editWidget, value == "ON" and "#76ff9f" or "#ff7b7b")
  else
    jqmSetVisible(actionWidget, false)
    jqmSetColor(editWidget, "#e8edf4")
  end
end

local function jqmRenderConfigRows(scriptName)
  local detail = jqmDetail(scriptName)
  local fields = detail and detail.config or {}
  jqmSetText(jqmWindowControl("configTitle"), scriptName and "Configuracoes principais" or "Central")
  for index = 1, 6 do
    local field = fields[index]
    if field then
      jqmSetConfigRow(index, field.label, jqmFormatConfigValue(scriptName, field), field, scriptName)
    else
      jqmSetConfigRow(index)
    end
  end
end

local function jqmRenderUtilityView(viewId)
  local title = viewId == "general" and "Configuracoes gerais" or "Utilidades"
  local subtitle = viewId == "general" and "Licenca, permissao e ambiente" or "Atualizador, licenca e carregamento"
  jqmSetText(jqmWindowControl("detailTitle"), title)
  jqmSetText(jqmWindowControl("detailSubtitle"), subtitle)
  jqmSetText(jqmWindowControl("detailBadge"), "ONLINE")
  jqmSetColor(jqmWindowControl("detailBadge"), "#6bb7ff")
  jqmSetText(jqmWindowControl("summaryLine1"), "Servidor: Jequi Multi Assessoria")
  jqmSetText(jqmWindowControl("summaryLine2"), "Licenca: " .. ((storage.Combo and storage.Combo.licenseKey ~= "" and "informada") or "key opcional"))
  jqmSetText(jqmWindowControl("summaryLine3"), "HWID/MAC: enviado automaticamente")
  jqmSetText(jqmWindowControl("detailPrimary"), "Carregar liberados")
  jqmSetText(jqmWindowControl("detailSecondary"), "Marcar todos")
  jqmSetText(jqmWindowControl("detailAdvanced"), "Limpar selecao")
  jqmRenderConfigRows(nil)
end

local function jqmRenderDashboard()
  jqmSetText(jqmWindowControl("detailTitle"), "Dashboard")
  jqmSetText(jqmWindowControl("detailSubtitle"), "Resumo geral dos produtos liberados")
  jqmSetText(jqmWindowControl("detailBadge"), "CONTROL")
  jqmSetColor(jqmWindowControl("detailBadge"), "#ffd36b")
  jqmSetText(jqmWindowControl("summaryLine1"), "Ativos: " .. tostring(jqmCountByState("active")) .. "  Pausados: " .. tostring(jqmCountByState("paused")))
  jqmSetText(jqmWindowControl("summaryLine2"), "Inativos: " .. tostring(jqmCountByState("inactive")) .. "  Total: " .. tostring(#JQM_SCRIPTS))
  jqmSetText(jqmWindowControl("summaryLine3"), "Acoes centralizadas: carregar, pausar e configurar")
  jqmSetText(jqmWindowControl("detailPrimary"), "Carregar liberados")
  jqmSetText(jqmWindowControl("detailSecondary"), "Marcar todos")
  jqmSetText(jqmWindowControl("detailAdvanced"), "Limpar selecao")
  jqmRenderConfigRows(nil)
end

local function jqmRenderModuleDetail(scriptName)
  local item = jqmScriptItem(scriptName)
  local detail = jqmDetail(scriptName)
  if not item or not detail then
    jqmRenderDashboard()
    return
  end

  local state = jqmModuleStateKey(scriptName)
  local theme = jqmStatusTheme(state)
  jqmSetText(jqmWindowControl("detailTitle"), detail.title or item.label)
  jqmSetText(jqmWindowControl("detailSubtitle"), tostring(detail.category or item.category or "") .. "  |  " .. tostring(item.desc or ""))
  jqmSetText(jqmWindowControl("detailBadge"), theme.text)
  jqmSetColor(jqmWindowControl("detailBadge"), theme.color)
  jqmSetText(jqmWindowControl("summaryLine1"), jqmSummaryLine(scriptName, 1))
  jqmSetText(jqmWindowControl("summaryLine2"), jqmSummaryLine(scriptName, 2))
  jqmSetText(jqmWindowControl("summaryLine3"), jqmSummaryLine(scriptName, 3))
  if jqmRuntimeLoaded[scriptName] == true then
    jqmSetText(jqmWindowControl("detailPrimary"), jqmModuleEnabled(scriptName) and "Desativar" or "Ativar")
    jqmSetText(jqmWindowControl("detailSecondary"), "Recarregar")
    jqmSetText(jqmWindowControl("detailAdvanced"), jqmNativeSetupButtons[scriptName] and "Setup nativo" or "Setup indisponivel")
  else
    jqmSetText(jqmWindowControl("detailPrimary"), "Ativar")
    jqmSetText(jqmWindowControl("detailSecondary"), "Solicitar acesso")
    jqmSetText(jqmWindowControl("detailAdvanced"), "Aguardando carga")
  end
  jqmRenderConfigRows(scriptName)
end

local function jqmRenderMainView()
  local view = storage.JQMScriptManager.view or "dashboard"
  local menu = jqmMenuItem(view)
  if view == "dashboard" then
    jqmRenderDashboard()
  elseif view == "utility" or view == "general" then
    jqmRenderUtilityView(view)
  else
    jqmRenderModuleDetail(menu.module or storage.JQMScriptManager.focus or "combo")
  end
end

local function jqmCurrentModule()
  local view = storage.JQMScriptManager.view or "dashboard"
  local menu = jqmMenuItem(view)
  return menu.module or storage.JQMScriptManager.focus
end

local function jqmRefreshManagerUi()
  for _, item in ipairs(JQM_SCRIPTS) do
    jqmUpdateModuleCard(item, false)
    if jqmRuntimeLoaded[item.name] == true then
      jqmEnsureLoadedRow(item.name)
      jqmPrepareProxySetup(item.name)
    end
  end
  jqmRenderStats()
  jqmRenderMenu()
  jqmRenderMainView()
  jqmSetText(jqmChild(jqmLauncher, "status") or jqmChild(jqmLauncher, "subtitle"), jqmMainSummary())
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
    storage.JQMScriptManager.selected[item.name] = value == true
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
    jqmSetText(jqmWindowControl(prefix .. "Hint"), "Script carregado. Setup nativo nao exposto.")
    jqmSetColor(jqmWindowControl(prefix .. "Hint"), "#ffd36b")
    jqmSetText(jqmWindowControl(prefix .. "Gear"), "CFG")
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
  height: 66
  margin-top: 4
  padding: 5
  image-source: /images/ui/panel_flat
  image-border: 5
  background-color: #111820dd

  Label
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: open.left
    margin-right: 5
    height: 15
    text-align: left
    color: #ffd36b
    font: verdana-11px-bold
    text: DERPETSON

  Label
    id: subtitle
    anchors.top: title.bottom
    anchors.left: parent.left
    anchors.right: open.left
    margin-top: 1
    margin-right: 5
    height: 14
    text-align: left
    color: #dce4ee
    font: verdana-11px
    text: scripts premium

  Label
    id: status
    anchors.top: subtitle.bottom
    anchors.left: parent.left
    anchors.right: open.left
    margin-top: 2
    margin-right: 5
    height: 16
    text-align: left
    color: #7ee8a8
    font: verdana-11px-bold
    text: Selecionar scripts

  Button
    id: open
    anchors.top: parent.top
    anchors.right: parent.right
    width: 50
    height: 54
    text-align: center
    text: Abrir

DerpetsonScriptsWindow < MainWindow
  text: Derpetson Scripts
  size: 500 635
  padding: 10
  @onEscape: self:hide()

  Panel
    id: headerPanel
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 66
    image-source: /images/ui/panel_flat
    image-border: 5
    padding: 7
    background-color: #111820ee

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
      text: Addon premium para modulos liberados

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
    height: 455
    image-source: /images/ui/panel_flat
    image-border: 5
    padding: 7
    background-color: #0f141bdd

    Label
      id: combatCategory
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: 15
      color: #ffd36b
      font: verdana-11px-bold
      text: [ATK] COMBATE

    Panel
      id: comboCard
      anchors.top: combatCategory.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 3
      height: 110
      padding: 5
      image-source: /images/ui/panel_flat
      image-border: 5
      background-color: #171b22dd

      Label
        id: comboIcon
        anchors.left: parent.left
        anchors.top: parent.top
        width: 28
        height: 98
        text-align: center
        color: #ffd36b
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
        color: #cfd8e3
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
        color: #9fb2c4
        font: verdana-11px
        text: COMBO_ESPART_V3.lua

      Label
        id: comboBadge
        anchors.right: comboGear.left
        anchors.top: parent.top
        margin-right: 4
        width: 48
        height: 16
        text-align: center
        color: #ff6f6f
        font: verdana-11px-bold
        text: Inativo

      Button
        id: comboGear
        anchors.right: parent.right
        anchors.top: parent.top
        width: 30
        height: 32
        text: CFG

      Panel
        id: comboNative
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: comboDesc.bottom
        margin-top: 6
        height: 60
        padding: 1
        image-source: /images/ui/panel_flat
        image-border: 5
        background-color: #0d121add

        Button
          id: comboLoad
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          margin: 4
          height: 28
          text: Iniciar COMBO ESPART

        Label
          id: comboHint
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: comboLoad.bottom
          margin-top: 2
          height: 16
          text-align: center
          color: #9fb2c4
          font: verdana-11px
          text: depois o Setup original aparece aqui

    Label
      id: castleCategory
      anchors.top: comboCard.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 8
      height: 15
      color: #ffd36b
      font: verdana-11px-bold
      text: [CST] CASTLE

    Panel
      id: castleCard
      anchors.top: castleCategory.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 3
      height: 110
      padding: 5
      image-source: /images/ui/panel_flat
      image-border: 5
      background-color: #171b22dd

      Label
        id: castleIcon
        anchors.left: parent.left
        anchors.top: parent.top
        width: 28
        height: 98
        text-align: center
        color: #ffd36b
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
        color: #cfd8e3
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
        color: #9fb2c4
        font: verdana-11px
        text: CASTLE_MANAGER_LOGOUT.lua

      Label
        id: castleBadge
        anchors.right: castleGear.left
        anchors.top: parent.top
        margin-right: 4
        width: 48
        height: 16
        text-align: center
        color: #ff6f6f
        font: verdana-11px-bold
        text: Inativo

      Button
        id: castleGear
        anchors.right: parent.right
        anchors.top: parent.top
        width: 30
        height: 32
        text: CFG

      Panel
        id: castleNative
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: castleDesc.bottom
        margin-top: 6
        height: 60
        padding: 1
        image-source: /images/ui/panel_flat
        image-border: 5
        background-color: #0d121add

        Button
          id: castleLoad
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          margin: 4
          height: 28
          text: Iniciar CASTLE PRO

        Label
          id: castleHint
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: castleLoad.bottom
          margin-top: 2
          height: 16
          text-align: center
          color: #9fb2c4
          font: verdana-11px
          text: depois o Setup original aparece aqui

    Label
      id: defenseCategory
      anchors.top: castleCard.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 8
      height: 15
      color: #ffd36b
      font: verdana-11px-bold
      text: [DEF] DEFESA

    Panel
      id: holidayCard
      anchors.top: defenseCategory.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 3
      height: 110
      padding: 5
      image-source: /images/ui/panel_flat
      image-border: 5
      background-color: #171b22dd

      Label
        id: holidayIcon
        anchors.left: parent.left
        anchors.top: parent.top
        width: 28
        height: 98
        text-align: center
        color: #ffd36b
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
        color: #cfd8e3
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
        color: #9fb2c4
        font: verdana-11px
        text: holiday_aoe.lua

      Label
        id: holidayBadge
        anchors.right: holidayGear.left
        anchors.top: parent.top
        margin-right: 4
        width: 48
        height: 16
        text-align: center
        color: #ff6f6f
        font: verdana-11px-bold
        text: Inativo

      Button
        id: holidayGear
        anchors.right: parent.right
        anchors.top: parent.top
        width: 30
        height: 32
        text: CFG

      Panel
        id: holidayNative
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: holidayDesc.bottom
        margin-top: 6
        height: 60
        padding: 1
        image-source: /images/ui/panel_flat
        image-border: 5
        background-color: #0d121add

        Button
          id: holidayLoad
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          margin: 4
          height: 28
          text: Iniciar HOLIDAY AOE

        Label
          id: holidayHint
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: holidayLoad.bottom
          margin-top: 2
          height: 16
          text-align: center
          color: #9fb2c4
          font: verdana-11px
          text: depois o Setup original aparece aqui

    Label
      id: utilityCategory
      anchors.top: holidayCard.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 8
      height: 15
      color: #ffd36b
      font: verdana-11px-bold
      text: [CFG] UTILIDADES

    Panel
      id: updateCard
      anchors.top: utilityCategory.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 3
      height: 34
      padding: 5
      image-source: /images/ui/panel_flat
      image-border: 5
      background-color: #151a20dd

      Label
        id: updateIcon
        anchors.left: parent.left
        anchors.top: parent.top
        width: 28
        height: 24
        text-align: center
        color: #ffd36b
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
        color: #e8fff0
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
    height: 40
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
      text: Status

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
      text: Ativo / Pausado / Inativo

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

DerpetsonControlWindow < MainWindow
  text: Derpetson Scripts
  size: 660 520
  padding: 9
  @onEscape: self:hide()

  Panel
    id: headerPanel
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 66
    image-source: /images/ui/panel_flat
    image-border: 5
    padding: 7
    background-color: #0f151dee

    Label
      id: title
      anchors.top: parent.top
      anchors.left: parent.left
      width: 210
      height: 18
      color: #ffd36b
      font: verdana-11px-bold
      text: DERPETSON SCRIPTS

    Label
      id: subtitle
      anchors.top: title.bottom
      anchors.left: parent.left
      width: 210
      margin-top: 2
      height: 15
      color: #dce4ee
      font: verdana-11px
      text: Control Center

    Label
      id: status
      anchors.top: subtitle.bottom
      anchors.left: parent.left
      width: 210
      margin-top: 3
      height: 15
      color: #7ee8a8
      font: verdana-11px-bold
      text: Selecionar scripts

    Panel
      id: statsPanel
      anchors.top: parent.top
      anchors.right: parent.right
      width: 335
      height: 50
      background-color: #111923cc

      Label
        id: activeLabel
        anchors.top: parent.top
        anchors.left: parent.left
        margin-left: 8
        margin-top: 6
        width: 58
        height: 13
        color: #76ff9f
        font: verdana-11px-bold
        text: Ativos

      Label
        id: activeCount
        anchors.top: activeLabel.bottom
        anchors.left: activeLabel.left
        margin-top: 3
        width: 58
        height: 16
        text-align: center
        color: #ffffff
        font: verdana-11px-bold
        text: 0

      Label
        id: pausedLabel
        anchors.top: parent.top
        anchors.left: activeLabel.right
        margin-left: 20
        margin-top: 6
        width: 62
        height: 13
        color: #ffd36b
        font: verdana-11px-bold
        text: Pausados

      Label
        id: pausedCount
        anchors.top: pausedLabel.bottom
        anchors.left: pausedLabel.left
        margin-top: 3
        width: 62
        height: 16
        text-align: center
        color: #ffffff
        font: verdana-11px-bold
        text: 0

      Label
        id: inactiveLabel
        anchors.top: parent.top
        anchors.left: pausedLabel.right
        margin-left: 20
        margin-top: 6
        width: 62
        height: 13
        color: #ff7b7b
        font: verdana-11px-bold
        text: Inativos

      Label
        id: inactiveCount
        anchors.top: inactiveLabel.bottom
        anchors.left: inactiveLabel.left
        margin-top: 3
        width: 62
        height: 16
        text-align: center
        color: #ffffff
        font: verdana-11px-bold
        text: 0

      Label
        id: totalLabel
        anchors.top: parent.top
        anchors.left: inactiveLabel.right
        margin-left: 20
        margin-top: 6
        width: 52
        height: 13
        color: #6bb7ff
        font: verdana-11px-bold
        text: Total

      Label
        id: totalCount
        anchors.top: totalLabel.bottom
        anchors.left: totalLabel.left
        margin-top: 3
        width: 52
        height: 16
        text-align: center
        color: #ffffff
        font: verdana-11px-bold
        text: 3

  Panel
    id: sidePanel
    anchors.top: headerPanel.bottom
    anchors.left: parent.left
    anchors.bottom: footer.top
    margin-top: 8
    margin-bottom: 8
    width: 146
    image-source: /images/ui/panel_flat
    image-border: 5
    padding: 6
    background-color: #111820ee

    Label
      id: menuTitle
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: 15
      color: #ffd36b
      font: verdana-11px-bold
      text: Navegacao

    Button
      id: navDashboard
      anchors.top: menuTitle.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 6
      height: 24
      text-align: left
      text: Dashboard

    Button
      id: navCombat
      anchors.top: navDashboard.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 4
      height: 24
      text-align: left
      text: Combate

    Button
      id: navPvp
      anchors.top: navCombat.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 4
      height: 24
      text-align: left
      text: PvP

    Button
      id: navCastle
      anchors.top: navPvp.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 4
      height: 24
      text-align: left
      text: Castle

    Button
      id: navDefense
      anchors.top: navCastle.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 4
      height: 24
      text-align: left
      text: Defesa

    Button
      id: navUtility
      anchors.top: navDefense.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 4
      height: 24
      text-align: left
      text: Utilidades

    Button
      id: navGeneral
      anchors.top: navUtility.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 4
      height: 24
      text-align: left
      text: Geral

    Panel
      id: moduleListPanel
      anchors.top: navGeneral.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      margin-top: 10
      background-color: #0d121acc

      Label
        id: moduleTitle
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        margin-top: 5
        height: 14
        text-align: center
        color: #9fb2c4
        font: verdana-11px
        text: Modulos

      Panel
        id: comboCard
        anchors.top: moduleTitle.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        margin-top: 5
        height: 46
        padding: 4
        image-source: /images/ui/panel_flat
        image-border: 5
        background-color: #171b22dd

        Label
          id: comboIcon
          anchors.left: parent.left
          anchors.top: parent.top
          width: 25
          height: 36
          text-align: center
          color: #ffd36b
          font: verdana-11px-bold
          text: ATK

        Label
          id: comboTitle
          anchors.left: comboIcon.right
          anchors.right: parent.right
          anchors.top: parent.top
          margin-left: 3
          height: 15
          color: #e8edf4
          font: verdana-11px-bold
          text: COMBO

        Label
          id: comboDesc
          anchors.left: comboIcon.right
          anchors.right: parent.right
          anchors.top: comboTitle.bottom
          margin-left: 3
          height: 13
          color: #9fb2c4
          font: verdana-11px
          text: runas

        Label
          id: comboBadge
          anchors.left: comboIcon.right
          anchors.top: comboDesc.bottom
          margin-left: 3
          width: 70
          height: 13
          color: #ff7b7b
          font: verdana-11px-bold
          text: INATIVO

      Panel
        id: castleCard
        anchors.top: comboCard.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        margin-top: 5
        height: 46
        padding: 4
        image-source: /images/ui/panel_flat
        image-border: 5
        background-color: #171b22dd

        Label
          id: castleIcon
          anchors.left: parent.left
          anchors.top: parent.top
          width: 25
          height: 36
          text-align: center
          color: #ffd36b
          font: verdana-11px-bold
          text: CST

        Label
          id: castleTitle
          anchors.left: castleIcon.right
          anchors.right: parent.right
          anchors.top: parent.top
          margin-left: 3
          height: 15
          color: #e8edf4
          font: verdana-11px-bold
          text: CASTLE

        Label
          id: castleDesc
          anchors.left: castleIcon.right
          anchors.right: parent.right
          anchors.top: castleTitle.bottom
          margin-left: 3
          height: 13
          color: #9fb2c4
          font: verdana-11px
          text: logout

        Label
          id: castleBadge
          anchors.left: castleIcon.right
          anchors.top: castleDesc.bottom
          margin-left: 3
          width: 70
          height: 13
          color: #ff7b7b
          font: verdana-11px-bold
          text: INATIVO

      Panel
        id: holidayCard
        anchors.top: castleCard.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        margin-top: 5
        height: 46
        padding: 4
        image-source: /images/ui/panel_flat
        image-border: 5
        background-color: #171b22dd

        Label
          id: holidayIcon
          anchors.left: parent.left
          anchors.top: parent.top
          width: 25
          height: 36
          text-align: center
          color: #ffd36b
          font: verdana-11px-bold
          text: DEF

        Label
          id: holidayTitle
          anchors.left: holidayIcon.right
          anchors.right: parent.right
          anchors.top: parent.top
          margin-left: 3
          height: 15
          color: #e8edf4
          font: verdana-11px-bold
          text: HOLIDAY

        Label
          id: holidayDesc
          anchors.left: holidayIcon.right
          anchors.right: parent.right
          anchors.top: holidayTitle.bottom
          margin-left: 3
          height: 13
          color: #9fb2c4
          font: verdana-11px
          text: defesa

        Label
          id: holidayBadge
          anchors.left: holidayIcon.right
          anchors.top: holidayDesc.bottom
          margin-left: 3
          width: 70
          height: 13
          color: #ff7b7b
          font: verdana-11px-bold
          text: INATIVO

  Panel
    id: mainPanel
    anchors.top: headerPanel.bottom
    anchors.left: sidePanel.right
    anchors.right: parent.right
    anchors.bottom: footer.top
    margin-left: 8
    margin-top: 8
    margin-bottom: 8
    image-source: /images/ui/panel_flat
    image-border: 5
    padding: 8
    background-color: #101720ee

    Panel
      id: detailPanel
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: 132
      background-color: #131c28dd

      Label
        id: detailTitle
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: detailBadge.left
        margin-left: 8
        margin-top: 8
        height: 18
        color: #ffffff
        font: verdana-11px-bold
        text: Dashboard

      Label
        id: detailBadge
        anchors.top: parent.top
        anchors.right: parent.right
        margin-right: 8
        margin-top: 8
        width: 92
        height: 18
        text-align: center
        color: #ffd36b
        font: verdana-11px-bold
        text: CONTROL

      Label
        id: detailSubtitle
        anchors.top: detailTitle.bottom
        anchors.left: detailTitle.left
        anchors.right: parent.right
        margin-top: 4
        height: 15
        color: #9fb2c4
        font: verdana-11px
        text: Resumo geral

      Label
        id: summaryLine1
        anchors.top: detailSubtitle.bottom
        anchors.left: detailTitle.left
        anchors.right: parent.right
        margin-top: 9
        height: 15
        color: #e8edf4
        font: verdana-11px
        text: Ativos: 0

      Label
        id: summaryLine2
        anchors.top: summaryLine1.bottom
        anchors.left: detailTitle.left
        anchors.right: parent.right
        margin-top: 3
        height: 15
        color: #e8edf4
        font: verdana-11px
        text: Inativos: 0

      Label
        id: summaryLine3
        anchors.top: summaryLine2.bottom
        anchors.left: detailTitle.left
        anchors.right: parent.right
        margin-top: 3
        height: 15
        color: #e8edf4
        font: verdana-11px
        text: Pronto

      Button
        id: detailPrimary
        anchors.left: detailTitle.left
        anchors.bottom: parent.bottom
        margin-bottom: 7
        width: 112
        height: 24
        text: Ativar

      Button
        id: detailSecondary
        anchors.left: detailPrimary.right
        anchors.bottom: detailPrimary.bottom
        margin-left: 6
        width: 120
        height: 24
        text: Recarregar

      Button
        id: detailAdvanced
        anchors.left: detailSecondary.right
        anchors.bottom: detailPrimary.bottom
        margin-left: 6
        width: 120
        height: 24
        text: Avancado

    Panel
      id: configPanel
      anchors.top: detailPanel.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      margin-top: 8
      margin-bottom: 10
      background-color: #0d121add

      Label
        id: configTitle
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        margin-left: 8
        margin-top: 7
        height: 16
        color: #ffd36b
        font: verdana-11px-bold
        text: Configuracoes principais

      Panel
        id: configRow1
        anchors.top: configTitle.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        margin-top: 7
        margin-left: 8
        margin-right: 8
        height: 29

        Label
          id: configLabel1
          anchors.left: parent.left
          anchors.top: parent.top
          width: 118
          height: 20
          margin-top: 4
          color: #dce4ee
          font: verdana-11px-bold
          text: Campo

        TextEdit
          id: configValue1
          anchors.left: configLabel1.right
          anchors.right: configAction1.left
          anchors.top: parent.top
          margin-left: 8
          margin-right: 6
          height: 23
          text: ""

        Button
          id: configAction1
          anchors.right: parent.right
          anchors.top: parent.top
          width: 62
          height: 23
          text: OK

      Panel
        id: configRow2
        anchors.top: configRow1.bottom
        anchors.left: configRow1.left
        anchors.right: configRow1.right
        margin-top: 4
        height: 29

        Label
          id: configLabel2
          anchors.left: parent.left
          anchors.top: parent.top
          width: 118
          height: 20
          margin-top: 4
          color: #dce4ee
          font: verdana-11px-bold
          text: Campo

        TextEdit
          id: configValue2
          anchors.left: configLabel2.right
          anchors.right: configAction2.left
          anchors.top: parent.top
          margin-left: 8
          margin-right: 6
          height: 23
          text: ""

        Button
          id: configAction2
          anchors.right: parent.right
          anchors.top: parent.top
          width: 62
          height: 23
          text: OK

      Panel
        id: configRow3
        anchors.top: configRow2.bottom
        anchors.left: configRow1.left
        anchors.right: configRow1.right
        margin-top: 4
        height: 29

        Label
          id: configLabel3
          anchors.left: parent.left
          anchors.top: parent.top
          width: 118
          height: 20
          margin-top: 4
          color: #dce4ee
          font: verdana-11px-bold
          text: Campo

        TextEdit
          id: configValue3
          anchors.left: configLabel3.right
          anchors.right: configAction3.left
          anchors.top: parent.top
          margin-left: 8
          margin-right: 6
          height: 23
          text: ""

        Button
          id: configAction3
          anchors.right: parent.right
          anchors.top: parent.top
          width: 62
          height: 23
          text: OK

      Panel
        id: configRow4
        anchors.top: configRow3.bottom
        anchors.left: configRow1.left
        anchors.right: configRow1.right
        margin-top: 4
        height: 29

        Label
          id: configLabel4
          anchors.left: parent.left
          anchors.top: parent.top
          width: 118
          height: 20
          margin-top: 4
          color: #dce4ee
          font: verdana-11px-bold
          text: Campo

        TextEdit
          id: configValue4
          anchors.left: configLabel4.right
          anchors.right: configAction4.left
          anchors.top: parent.top
          margin-left: 8
          margin-right: 6
          height: 23
          text: ""

        Button
          id: configAction4
          anchors.right: parent.right
          anchors.top: parent.top
          width: 62
          height: 23
          text: OK

      Panel
        id: configRow5
        anchors.top: configRow4.bottom
        anchors.left: configRow1.left
        anchors.right: configRow1.right
        margin-top: 4
        height: 29

        Label
          id: configLabel5
          anchors.left: parent.left
          anchors.top: parent.top
          width: 118
          height: 20
          margin-top: 4
          color: #dce4ee
          font: verdana-11px-bold
          text: Campo

        TextEdit
          id: configValue5
          anchors.left: configLabel5.right
          anchors.right: configAction5.left
          anchors.top: parent.top
          margin-left: 8
          margin-right: 6
          height: 23
          text: ""

        Button
          id: configAction5
          anchors.right: parent.right
          anchors.top: parent.top
          width: 62
          height: 23
          text: OK

      Panel
        id: configRow6
        anchors.top: configRow5.bottom
        anchors.left: configRow1.left
        anchors.right: configRow1.right
        margin-top: 4
        height: 29

        Label
          id: configLabel6
          anchors.left: parent.left
          anchors.top: parent.top
          width: 118
          height: 20
          margin-top: 4
          color: #dce4ee
          font: verdana-11px-bold
          text: Campo

        TextEdit
          id: configValue6
          anchors.left: configLabel6.right
          anchors.right: configAction6.left
          anchors.top: parent.top
          margin-left: 8
          margin-right: 6
          height: 23
          text: ""

        Button
          id: configAction6
          anchors.right: parent.right
          anchors.top: parent.top
          width: 62
          height: 23
          text: OK

    Panel
      id: nativeBridgePanel
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: 1
      visible: false

      Panel
        id: comboNative
        anchors.left: parent.left
        anchors.top: parent.top
        width: 1
        height: 1

      Panel
        id: castleNative
        anchors.left: comboNative.right
        anchors.top: parent.top
        width: 1
        height: 1

      Panel
        id: holidayNative
        anchors.left: castleNative.right
        anchors.top: parent.top
        width: 1
        height: 1

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
      width: 84
      height: 24
      text: Todos

    Button
      id: clearButton
      anchors.left: allButton.right
      anchors.top: parent.top
      margin-left: 6
      width: 84
      height: 24
      text: Limpar

    Button
      id: confirmButton
      anchors.left: clearButton.right
      anchors.right: closeButton.left
      anchors.top: parent.top
      margin-left: 6
      margin-right: 6
      height: 24
      text: Carregar liberados

    Button
      id: closeButton
      anchors.right: parent.right
      anchors.top: parent.top
      width: 72
      height: 24
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
  local okWindow, window = pcall(function() return UI.createWindow("DerpetsonControlWindow", root) end)
  if not okWindow or not window then
    okWindow, window = pcall(function() return UI.createWindow("DerpetsonControlWindow") end)
  end
  if not okWindow or not window then
    okWindow, window = pcall(function() return UI.createWindow("DerpetsonScriptsWindow", root) end)
  end
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
    end
  end
  if jqmWindowControl("clearButton") then
    jqmWindowControl("clearButton").onClick = function() jqmSetAllSelected(false) end
  end

  for _, menu in ipairs(JQM_MENU_ITEMS) do
    local button = jqmWindowControl(JQM_MENU_CONTROL_IDS[menu.id])
    if button then
      button.onClick = function()
        jqmSelectView(menu.id, menu.module)
        jqmRefreshManagerUi()
      end
    end
  end

  if jqmWindowControl("detailPrimary") then
    jqmWindowControl("detailPrimary").onClick = function()
      local scriptName = jqmCurrentModule()
      if not scriptName then
        jqmRequestOrLoad()
        return
      end
      storage.JQMScriptManager.focus = scriptName
      if jqmRuntimeLoaded[scriptName] == true then
        jqmSetModuleEnabled(scriptName, not jqmModuleEnabled(scriptName))
        jqmRefreshManagerUi()
        return
      end
      jqmActivateSelected(scriptName)
    end
  end

  if jqmWindowControl("detailSecondary") then
    jqmWindowControl("detailSecondary").onClick = function()
      local scriptName = jqmCurrentModule()
      if scriptName and jqmRuntimeLoaded[scriptName] ~= true then
        jqmActivateSelected(scriptName)
      else
        jqmRequestOrLoad()
      end
    end
  end

  if jqmWindowControl("detailAdvanced") then
    jqmWindowControl("detailAdvanced").onClick = function()
      local scriptName = jqmCurrentModule()
      if not scriptName then
        jqmSetAllSelected(false)
        return
      end
      if jqmRuntimeLoaded[scriptName] == true and jqmOpenNativeSetup(scriptName) then return end
      jqmWarn("setup avancado indisponivel: " .. jqmScriptLabel(scriptName))
    end
  end

  for index = 1, 6 do
    local edit = jqmWindowControl("configValue" .. tostring(index))
    if edit then
      edit.onTextChange = function(_, text)
        if jqmUiSyncing then return end
        local binding = jqmConfigRowBindings[index]
        if not binding or not binding.field or binding.field.kind == "bool" then return end
        jqmSetConfigValue(binding.scriptName, binding.field, jqmParseConfigValue(binding.field, text))
      end
    end
    local action = jqmWindowControl("configAction" .. tostring(index))
    if action then
      action.onClick = function()
        local binding = jqmConfigRowBindings[index]
        if not binding or not binding.field then return end
        local current = jqmConfigValue(binding.scriptName, binding.field)
        if binding.field.kind == "bool" then
          jqmSetConfigValue(binding.scriptName, binding.field, current ~= true)
          jqmRefreshManagerUi()
        end
      end
    end
  end

  local function bindModuleCard(scriptName)
    local item = jqmScriptItem(scriptName)
    local prefix = JQM_CARD_PREFIX[scriptName]
    if not item or not prefix then return end

    local function selectModule()
      storage.JQMScriptManager.focus = scriptName
      if scriptName == "combo" then
        storage.JQMScriptManager.view = "combat"
      elseif scriptName == "castle_manager" then
        storage.JQMScriptManager.view = "castle"
      elseif scriptName == "holiday_aoe" then
        storage.JQMScriptManager.view = "defense"
      end
      jqmRefreshManagerUi()
    end
    local function hoverModule(_, hovered)
      jqmUpdateModuleCard(item, hovered == true)
    end

    for _, suffix in ipairs({ "Card", "Icon", "Title", "Desc", "Badge" }) do
      local widget = jqmWindowControl(prefix .. suffix)
      if widget then
        widget.onClick = selectModule
        widget.onHoverChange = hoverModule
      end
    end

    local gear = jqmWindowControl(prefix .. "Gear")
    if gear then
      gear.onClick = selectModule
      gear.onHoverChange = hoverModule
    end

    local loadButton = jqmWindowControl(prefix .. "Load")
    if loadButton then
      loadButton.onClick = selectModule
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

local function jqmCleanupDuplicateLaunchers(keep)
  local tab = jqmEnsureManagerTab()
  if not tab or not tab.getChildren then return end
  local ok, children = pcall(function() return tab:getChildren() end)
  if not ok or type(children) ~= "table" then return end

  for _, child in ipairs(children) do
    if child and child ~= keep and child.destroy then
      local title = jqmChild(child, "title")
      local open = jqmChild(child, "open") or jqmChild(child, "openButton")
      if open and jqmGetText(title) == "Derpetson Scripts" then
        pcall(function() child:destroy() end)
      end
    end
  end
end

local function jqmUseExternalLauncher()
  local external = jqmGlobal.DerpetsonLauncherRow
  if not external then return false end

  local old = jqmGlobal.JQMScriptManagerLauncher
  if old and old ~= external and old.destroy then
    pcall(function() old:destroy() end)
  end

  jqmLauncher = external
  jqmGlobal.JQMScriptManagerLauncher = external
  jqmCleanupDuplicateLaunchers(external)
  jqmBindClick(jqmChild(jqmLauncher, "open") or jqmChild(jqmLauncher, "openButton"), jqmOpenManager)
  jqmBindClick(jqmChild(jqmLauncher, "title"), jqmOpenManager)
  jqmBindClick(jqmChild(jqmLauncher, "subtitle"), jqmOpenManager)
  jqmBindClick(jqmChild(jqmLauncher, "status"), jqmOpenManager)
  jqmBindClick(jqmLauncher, jqmOpenManager)
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
  jqmGlobal.JQMScriptManagerLauncher = panel
  jqmBindClick(jqmChild(jqmLauncher, "open"), jqmOpenManager)
  jqmBindClick(jqmChild(jqmLauncher, "title"), jqmOpenManager)
  jqmBindClick(jqmChild(jqmLauncher, "status"), jqmOpenManager)
  jqmBindClick(jqmLauncher, jqmOpenManager)
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
    jqmGlobal.JQMScriptManagerLauncher = panel
    jqmBindClick(jqmChild(jqmLauncher, "open"), jqmOpenManager)
    jqmBindClick(jqmChild(jqmLauncher, "title"), jqmOpenManager)
    jqmBindClick(jqmChild(jqmLauncher, "subtitle"), jqmOpenManager)
    jqmBindClick(jqmChild(jqmLauncher, "status"), jqmOpenManager)
    jqmBindClick(jqmLauncher, jqmOpenManager)
    jqmRefreshManagerUi()
  elseif UI and UI.Button then
    UI.Button("Derpetson Scripts", jqmOpenManager, jqmEnsureManagerTab())
  end
elseif UI and UI.Button then
  UI.Button("Derpetson Scripts", jqmOpenManager, jqmEnsureManagerTab())
end
