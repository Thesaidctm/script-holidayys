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
local JQM_MANAGER_VERSION = 2026061214
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
  { name = "combo", label = "COMBO ESPART V3", short = "COMBO ESPART", file = "COMBO_ESPART_V3.lua", desc = "Combo, runas e prioridades", category = "COMBATE", icon = "ATK" },
  { name = "castle_manager", label = "CASTLE PRO", short = "CASTLE PRO", file = "CASTLE_MANAGER_LOGOUT.lua", desc = "Castle, seguranca e logout", category = "CASTLE", icon = "CST" },
  { name = "holiday_aoe", label = "HOLIDAY AOE", short = "HOLIDAY AOE", file = "holiday_aoe.lua", desc = "Area, combo e PvP", category = "DEFESA", icon = "DEF" }
}

local JQM_MODULES = {
  {
    key = "combo_espart",
    script = "combo",
    prefix = "combo",
    category = "COMBATE",
    icon = "ATK",
    label = "COMBO ESPART",
    file = "COMBO_ESPART_V3.lua",
    desc = "Delay, caller, runas e prioridades",
    defaults = {
      enabled = false,
      delay = "250",
      caller = "",
      cooldowns = "auto",
      spells = "auto",
      priority = "menor hp",
      advanced = false,
      pvp = true
    },
    fields = {
      { key = "delay", label = "Delay de Combo", kind = "text" },
      { key = "caller", label = "Caller", kind = "text" },
      { key = "cooldowns", label = "Cooldowns", kind = "text" },
      { key = "spells", label = "Lista de Magias", kind = "text" },
      { key = "priority", label = "Prioridades", kind = "text" },
      { key = "advanced", label = "Opcoes avancadas", kind = "bool" },
      { key = "pvp", label = "PVP", kind = "bool" }
    }
  },
  {
    key = "smart_pvp",
    script = nil,
    prefix = "smart",
    category = "COMBATE",
    icon = "PVP",
    label = "SMART PVP",
    file = "Hub interno",
    desc = "Anti push, SSA, ring e trap",
    defaults = {
      enabled = false,
      antiPush = true,
      ssa = true,
      mightRing = true,
      magicWall = true,
      antiTrap = true,
      antiKs = false
    },
    fields = {
      { key = "antiPush", label = "Anti Push", kind = "bool" },
      { key = "ssa", label = "SSA", kind = "bool" },
      { key = "mightRing", label = "Might Ring", kind = "bool" },
      { key = "magicWall", label = "Magic Wall", kind = "bool" },
      { key = "antiTrap", label = "Anti Trap", kind = "bool" },
      { key = "antiKs", label = "Anti KS", kind = "bool" }
    }
  },
  {
    key = "castle_pro",
    script = "castle_manager",
    prefix = "castle",
    category = "CASTLE",
    icon = "CST",
    label = "CASTLE PRO",
    file = "CASTLE_MANAGER_LOGOUT.lua",
    desc = "Areas, whitelist e seguranca",
    defaults = {
      enabled = false,
      areas = "",
      whitelist = "",
      logout = true,
      cavebot = true,
      antiInvasao = true
    },
    fields = {
      { key = "areas", label = "Lista de Areas", kind = "text" },
      { key = "whitelist", label = "Whitelist", kind = "text" },
      { key = "logout", label = "Logout", kind = "bool" },
      { key = "cavebot", label = "Cavebot", kind = "bool" },
      { key = "antiInvasao", label = "Anti Invasao", kind = "bool" }
    }
  },
  {
    key = "holiday_aoe",
    script = "holiday_aoe",
    prefix = "holiday",
    category = "DEFESA",
    icon = "DEF",
    label = "HOLIDAY AOE",
    file = "holiday_aoe.lua",
    desc = "Magias, monstros e safe mode",
    defaults = {
      enabled = false,
      spells = "auto",
      cooldowns = "auto",
      priority = "menor hp",
      monsters = "3",
      safeMode = true,
      enableWave = true,
      enableMageArea = true,
      enablePvpStrongArea = true
    },
    fields = {
      { key = "spells", label = "Magias", kind = "text" },
      { key = "cooldowns", label = "Cooldowns", kind = "text" },
      { key = "priority", label = "Prioridades", kind = "text" },
      { key = "monsters", label = "Monstros minimos", kind = "text" },
      { key = "safeMode", label = "Safe Mode", kind = "bool" },
      { key = "enableWave", label = "Usar Wave", kind = "bool" },
      { key = "enableMageArea", label = "Area Mage", kind = "bool" },
      { key = "enablePvpStrongArea", label = "Area PvP extra", kind = "bool" }
    }
  }
}

local JQM_MODULE_BY_KEY = {}
for _, module in ipairs(JQM_MODULES) do
  JQM_MODULE_BY_KEY[module.key] = module
end

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

local jqmWindow = nil
local jqmLauncher = nil
local jqmUiLoaded = false
local jqmManagerTab = nil
local jqmPayloadSink = nil
local jqmLoadedRows = {}
local jqmOpenManager = nil
local jqmRefreshManagerUi = nil
local jqmActivateSelected = nil

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

local function jqmEnsurePayloadSink()
  if jqmPayloadSink then return jqmPayloadSink end
  local tab = jqmEnsureManagerTab()
  if UI and UI.createWidget and tab then
    local ok, panel = pcall(function() return UI.createWidget("Panel", tab) end)
    if ok and panel then
      jqmPayloadSink = panel
      if panel.setHeight then pcall(function() panel:setHeight(0) end) end
      if panel.setVisible then pcall(function() panel:setVisible(false) end) end
      if panel.hide then pcall(function() panel:hide() end) end
      return jqmPayloadSink
    end
  end
  return tab
end

local function jqmWindowControl(id)
  if not jqmWindow then return nil end
  if jqmWindow[id] then return jqmWindow[id] end
  if jqmWindow.recursiveGetChildById then
    local ok, widget = pcall(function() return jqmWindow:recursiveGetChildById(id) end)
    if ok and widget then return widget end
  end
  for _, parentId in ipairs({ "headerPanel", "dashboardPanel", "sidebarPanel", "detailPanel", "configPanel", "listPanel", "helpPanel", "footer" }) do
    local panel = jqmWindow[parentId]
    if panel and panel[id] then return panel[id] end
  end
  return nil
end

storage.JQMScriptManager = type(storage.JQMScriptManager) == "table" and storage.JQMScriptManager or {}
storage.JQMScriptManager.selected = type(storage.JQMScriptManager.selected) == "table" and storage.JQMScriptManager.selected or {}
storage.JQMScriptManager.loaded = type(storage.JQMScriptManager.loaded) == "table" and storage.JQMScriptManager.loaded or {}
storage.JQMScriptManager.modules = type(storage.JQMScriptManager.modules) == "table" and storage.JQMScriptManager.modules or {}
storage.JQMScriptManager.activeModule = storage.JQMScriptManager.activeModule or "combo_espart"
storage.JQMScriptManager.lastUpdate = storage.JQMScriptManager.lastUpdate or ""
storage.Combo = type(storage.Combo) == "table" and storage.Combo or {}
storage.Combo.licenseKey = storage.Combo.licenseKey or ""
local JQM_AOE_STORAGE = "holiday_aoe_vocation_v10_ek_gran_only"

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

local function jqmTouchUpdate()
  storage.JQMScriptManager.lastUpdate = os and os.date and os.date("%H:%M:%S") or "agora"
end

local function jqmCopyDefaults(defaults)
  local copy = {}
  for key, value in pairs(defaults or {}) do
    copy[key] = value
  end
  return copy
end

local function jqmModuleData(moduleKey)
  storage.JQMScriptManager.modules = type(storage.JQMScriptManager.modules) == "table" and storage.JQMScriptManager.modules or {}
  local data = storage.JQMScriptManager.modules[moduleKey]
  if type(data) ~= "table" then
    data = {}
    storage.JQMScriptManager.modules[moduleKey] = data
  end
  local def = JQM_MODULE_BY_KEY[moduleKey]
  if type(data.config) ~= "table" then
    data.config = jqmCopyDefaults(def and def.defaults or {})
  end
  if def and type(def.defaults) == "table" then
    for key, value in pairs(def.defaults) do
      if data.config[key] == nil then data.config[key] = value end
    end
  end
  if data.enabled == nil and data.config.enabled ~= nil then
    data.enabled = data.config.enabled == true
  end
  return data
end

local function jqmBoolText(value)
  return value == true and "ON" or "OFF"
end

local function jqmValueText(value)
  if value == true or value == false then return jqmBoolText(value) end
  return tostring(value or "")
end

local function jqmComboStorage()
  storage.Combo = type(storage.Combo) == "table" and storage.Combo or {}
  return storage.Combo
end

local function jqmAoeStorage()
  storage[JQM_AOE_STORAGE] = type(storage[JQM_AOE_STORAGE]) == "table" and storage[JQM_AOE_STORAGE] or {}
  return storage[JQM_AOE_STORAGE]
end

local function jqmApplyModuleConfig(module, fieldKey, value)
  if not module then return end
  if module.key == "combo_espart" then
    local combo = jqmComboStorage()
    if fieldKey == "enabled" then combo.enabled = value == true end
    if fieldKey == "caller" then combo.chatName = tostring(value or "") end
    if fieldKey == "priority" then combo.jqmPriority = tostring(value or "") end
    if fieldKey == "pvp" then combo.jqmPvp = value == true end
    if fieldKey == "advanced" then combo.jqmAdvanced = value == true end
    if fieldKey == "delay" then combo.jqmDelay = tostring(value or "") end
    if fieldKey == "cooldowns" then combo.jqmCooldowns = tostring(value or "") end
    if fieldKey == "spells" then combo.jqmSpells = tostring(value or "") end
    return
  end

  if module.key == "holiday_aoe" then
    local aoe = jqmAoeStorage()
    if fieldKey == "enabled" then aoe.enabled = value == true end
    if fieldKey == "safeMode" then aoe.enableDefense = value == true end
    if fieldKey == "enableWave" then aoe.enableWave = value == true end
    if fieldKey == "enableMageArea" then aoe.enableMageArea = value == true end
    if fieldKey == "enablePvpStrongArea" then aoe.enablePvpStrongArea = value == true end
    if fieldKey == "monsters" then
      local n = tonumber(value)
      if n then
        aoe.minWaveMobs = n
        aoe.minAreaMsEd = n
        aoe.minAreaRp = n
        aoe.minEkGran = n
      end
    end
    if fieldKey == "cooldowns" then aoe.jqmCooldowns = tostring(value or "") end
    if fieldKey == "spells" then aoe.jqmSpells = tostring(value or "") end
    if fieldKey == "priority" then aoe.jqmPriority = tostring(value or "") end
    return
  end

  if module.key == "smart_pvp" then
    storage.JQMSmartPVP = type(storage.JQMSmartPVP) == "table" and storage.JQMSmartPVP or {}
    storage.JQMSmartPVP[fieldKey] = value
    return
  end

  if module.key == "castle_pro" then
    storage.JQMCastlePro = type(storage.JQMCastlePro) == "table" and storage.JQMCastlePro or {}
    storage.JQMCastlePro[fieldKey] = value
  end
end

local function jqmModuleRuntimeActive(module)
  if not module then return false end
  return jqmModuleData(module.key).enabled == true
end

for _, module in ipairs(JQM_MODULES) do
  function module:getStatus()
    local data = jqmModuleData(self.key)
    if data.paused == true then
      return "Pausado", "#ffd36b", "#2d2617dd", "#fff0c0"
    end
    if jqmModuleRuntimeActive(self) then
      return "Ativo", "#76ff9f", "#183820dd", "#e8fff0"
    end
    return "Inativo", "#ff7676", "#171b22dd", "#cfd8e3"
  end

  function module:getConfig()
    return jqmModuleData(self.key).config
  end

  function module:saveConfig(fieldKey, value)
    local data = jqmModuleData(self.key)
    data.config[fieldKey] = value
    if fieldKey == "enabled" then data.enabled = value == true end
    jqmApplyModuleConfig(self, fieldKey, value)
    jqmTouchUpdate()
  end

  function module:setEnabled(value)
    local enabled = value == true
    local data = jqmModuleData(self.key)
    data.enabled = enabled
    data.config.enabled = enabled
    data.paused = false
    if self.script then storage.JQMScriptManager.selected[self.script] = enabled end
    jqmApplyModuleConfig(self, "enabled", enabled)
    jqmTouchUpdate()
    if enabled and self.script and type(jqmActivateSelected) == "function" then
      jqmActivateSelected(self.script)
    elseif type(jqmRefreshManagerUi) == "function" then
      jqmRefreshManagerUi()
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

local function jqmMainSummary()
  local count = jqmLoadedCount()
  if count == 1 then return "1 produto ativo" end
  if count > 1 then return tostring(count) .. " produtos ativos" end
  return "Selecionar scripts"
end

local function jqmScriptLabel(scriptName)
  for _, item in ipairs(JQM_SCRIPTS) do
    if item.name == scriptName then return item.label end
  end
  return tostring(scriptName or "")
end

local function jqmScriptItem(scriptName)
  for _, item in ipairs(JQM_SCRIPTS) do
    if item.name == scriptName then return item end
  end
  return nil
end

local function jqmSetManagerStatus(text)
  jqmSetText(jqmLauncher and jqmLauncher.status, text)
  jqmSetText(jqmWindowControl("status"), text)
end

local function jqmActiveModule()
  local module = JQM_MODULE_BY_KEY[storage.JQMScriptManager.activeModule]
  if module then return module end
  storage.JQMScriptManager.activeModule = "combo_espart"
  return JQM_MODULE_BY_KEY.combo_espart
end

local function jqmSyncLoadedModules()
  for _, module in ipairs(JQM_MODULES) do
    if module.script and jqmRuntimeLoaded[module.script] == true then
      local data = jqmModuleData(module.key)
      data.runtimeLoaded = true
    end
  end
end

local function jqmDashboardCounts()
  local active, inactive, paused = 0, 0, 0
  for _, module in ipairs(JQM_MODULES) do
    local status = module:getStatus()
    if status == "Ativo" then
      active = active + 1
    elseif status == "Pausado" then
      paused = paused + 1
    else
      inactive = inactive + 1
    end
  end
  return active, inactive, paused
end

local function jqmUpdateModuleCard(module, hover)
  if not module then return end
  local prefix = module.prefix
  if not prefix then return end

  local card = jqmWindowControl(prefix .. "Card")
  local icon = jqmWindowControl(prefix .. "Icon")
  local title = jqmWindowControl(prefix .. "Title")
  local desc = jqmWindowControl(prefix .. "Desc")
  local badge = jqmWindowControl(prefix .. "Badge")
  local enable = jqmWindowControl(prefix .. "Enable")
  local gear = jqmWindowControl(prefix .. "Gear")
  local selected = storage.JQMScriptManager.activeModule == module.key
  local statusText, statusColor, bgColor, titleColor = module:getStatus()

  if hover == true then
    bgColor = "#243041ee"
    titleColor = "#ffffff"
  end
  if selected then
    bgColor = "#273341ee"
    titleColor = "#ffffff"
  end

  jqmSetText(icon, module.icon or "")
  jqmSetText(title, module.label)
  jqmSetText(desc, module.desc or module.file or "")
  jqmSetText(badge, statusText)
  jqmSetText(enable, statusText == "Ativo" and "Desativar" or "Ativar")
  jqmSetText(gear, "CFG")
  jqmSetColor(badge, statusColor)
  jqmSetColor(title, titleColor)
  jqmSetColor(icon, statusColor)
  jqmSetColor(desc, "#9fb2c4")
  jqmSetColor(gear, hover and "#ffd36b" or "#dce4ee")
  jqmSetColor(enable, statusText == "Ativo" and "#76ff9f" or "#dce4ee")
  jqmSetBackground(card, bgColor)
end

local jqmRowBindings = {}
local jqmInputLocks = {}

local function jqmSetInputText(inputId, text)
  local input = jqmWindowControl(inputId)
  jqmInputLocks[inputId] = true
  jqmSetText(input, text)
  jqmInputLocks[inputId] = false
end

local function jqmRefreshDashboard()
  local active, inactive, paused = jqmDashboardCounts()
  local ramText = "RAM: n/d"
  if collectgarbage then
    local ok, kb = pcall(function() return collectgarbage("count") end)
    if ok and kb then ramText = string.format("RAM: %.1f MB", tonumber(kb) / 1024) end
  end
  jqmSetText(jqmWindowControl("activeMetric"), "Ativos: " .. tostring(active))
  jqmSetText(jqmWindowControl("inactiveMetric"), "Inativos: " .. tostring(inactive))
  jqmSetText(jqmWindowControl("pausedMetric"), "Pausados: " .. tostring(paused))
  jqmSetText(jqmWindowControl("cpuMetric"), "CPU: n/d")
  jqmSetText(jqmWindowControl("ramMetric"), ramText)
  jqmSetText(jqmWindowControl("updateMetric"), "Atualizado: " .. tostring(storage.JQMScriptManager.lastUpdate or "-"))
end

local function jqmRefreshDetailPanel()
  local module = jqmActiveModule()
  if not module then return end
  local statusText, statusColor = module:getStatus()
  local cfg = module:getConfig()
  jqmSetText(jqmWindowControl("detailTitle"), module.label)
  jqmSetText(jqmWindowControl("detailSubtitle"), module.desc or module.file or "")
  jqmSetText(jqmWindowControl("detailBadge"), statusText)
  jqmSetColor(jqmWindowControl("detailBadge"), statusColor)
  jqmSetText(jqmWindowControl("detailLoad"), statusText == "Ativo" and "Desativar" or "Ativar")

  for index = 1, 8 do
    local field = module.fields and module.fields[index]
    local row = jqmWindowControl("configRow" .. tostring(index))
    local label = jqmWindowControl("configLabel" .. tostring(index))
    local input = jqmWindowControl("configInput" .. tostring(index))
    local action = jqmWindowControl("configAction" .. tostring(index))
    jqmRowBindings[index] = field and { module = module, field = field } or nil
    jqmSetVisible(row, field ~= nil)
    if field then
      local value = cfg[field.key]
      jqmSetText(label, field.label)
      jqmSetInputText("configInput" .. tostring(index), jqmValueText(value))
      jqmSetText(action, field.kind == "bool" and "Alternar" or "OK")
      jqmSetColor(input, field.kind == "bool" and (value == true and "#76ff9f" or "#ff7676") or "#e8edf4")
    end
  end
end

local function jqmSaveConfigInput(index, text)
  local binding = jqmRowBindings[index]
  if not binding or not binding.module or not binding.field then return end
  if binding.field.kind == "bool" then return end
  binding.module:saveConfig(binding.field.key, tostring(text or ""))
  jqmRefreshDashboard()
end

local function jqmConfigAction(index)
  local binding = jqmRowBindings[index]
  if not binding or not binding.module or not binding.field then return end
  local cfg = binding.module:getConfig()
  if binding.field.kind == "bool" then
    binding.module:saveConfig(binding.field.key, cfg[binding.field.key] ~= true)
  else
    local input = jqmWindowControl("configInput" .. tostring(index))
    local value = input and input.getText and input:getText() or cfg[binding.field.key]
    binding.module:saveConfig(binding.field.key, tostring(value or ""))
  end
  jqmRefreshManagerUi()
end

jqmRefreshManagerUi = function()
  jqmSyncLoadedModules()
  for _, module in ipairs(JQM_MODULES) do
    jqmUpdateModuleCard(module, false)
  end
  jqmRefreshDashboard()
  jqmRefreshDetailPanel()
  jqmSetText(jqmLauncher and jqmLauncher.status, jqmMainSummary())
  jqmSetText(jqmWindowControl("status"), "Hub central de gerenciamento")
end

local jqmRequestSingle = nil
local jqmWarn = nil

jqmActivateSelected = function(scriptName)
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
  height: 36
  margin-top: 4
  padding: 4
  image-source: /images/ui/panel_flat
  image-border: 5
  background-color: #151a20dd

  Label
    id: icon
    anchors.left: parent.left
    anchors.top: parent.top
    width: 20
    height: 28
    text-align: center
    color: #ffd36b
    font: verdana-11px-bold

  Label
    id: title
    anchors.left: icon.right
    anchors.right: gear.left
    anchors.top: parent.top
    margin-left: 3
    margin-right: 4
    height: 15
    text-align: left
    color: #e8fff0
    font: verdana-11px-bold

  Label
    id: state
    anchors.left: icon.right
    anchors.right: gear.left
    anchors.top: title.bottom
    margin-left: 3
    margin-top: 1
    height: 13
    text-align: left
    color: #76ff9f
    font: verdana-11px-bold

  Button
    id: gear
    anchors.right: parent.right
    anchors.top: parent.top
    width: 30
    height: 28
    text: CFG
]], tab)
  end)
  if not ok or not row then return nil end

  jqmLoadedRows[scriptName] = row
  if row.icon then
    jqmSetText(row.icon, item.icon or "")
  end
  if row.title then
    jqmSetText(row.title, item.short or item.label)
  end
  if row.state then
    jqmSetText(row.state, "Ativo")
    jqmSetColor(row.state, "#76ff9f")
  end
  if row.gear then
    row.gear.onClick = function()
      if type(jqmOpenManager) == "function" then jqmOpenManager() end
    end
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
  env.parent = jqmEnsurePayloadSink()
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
      parent = jqmEnsurePayloadSink() or tab
    end
    return parent or tab
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
  for _, module in ipairs(JQM_MODULES) do
    if module.script == scriptName then
      local data = jqmModuleData(module.key)
      data.enabled = true
      data.config.enabled = true
      data.runtimeLoaded = true
      jqmApplyModuleConfig(module, "enabled", true)
    end
  end
  jqmSetManagerStatus(jqmMainSummary())
  if type(jqmRefreshManagerUi) == "function" then jqmRefreshManagerUi() end
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
    width: 36
    height: 54
    text-align: center
    text: CFG

DerpetsonScriptsWindow < MainWindow
  text: Derpetson Scripts
  size: 430 455
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
    height: 278
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
      height: 43
      padding: 5
      image-source: /images/ui/panel_flat
      image-border: 5
      background-color: #171b22dd

      Label
        id: comboIcon
        anchors.left: parent.left
        anchors.top: parent.top
        width: 28
        height: 32
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
      height: 43
      padding: 5
      image-source: /images/ui/panel_flat
      image-border: 5
      background-color: #171b22dd

      Label
        id: castleIcon
        anchors.left: parent.left
        anchors.top: parent.top
        width: 28
        height: 32
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
      height: 43
      padding: 5
      image-source: /images/ui/panel_flat
      image-border: 5
      background-color: #171b22dd

      Label
        id: holidayIcon
        anchors.left: parent.left
        anchors.top: parent.top
        width: 28
        height: 32
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

DerpetsonScriptsHubWindow < MainWindow
  text: Derpetson Scripts
  size: 620 555
  padding: 10
  @onEscape: self:hide()

  Panel
    id: headerPanel
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 58
    image-source: /images/ui/panel_flat
    image-border: 5
    padding: 7
    background-color: #101720ee

    Label
      id: title
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: 17
      text-align: center
      color: #ffd36b
      font: verdana-11px-bold
      text: DERPETSON SCRIPTS

    Label
      id: subtitle
      anchors.top: title.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 2
      height: 14
      text-align: center
      color: #e8edf4
      font: verdana-11px
      text: Hub central de gerenciamento premium

    Label
      id: status
      anchors.top: subtitle.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 2
      height: 15
      text-align: center
      color: #7ee8a8
      font: verdana-11px-bold
      text: Hub central de gerenciamento

  Panel
    id: dashboardPanel
    anchors.top: headerPanel.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 7
    height: 50
    image-source: /images/ui/panel_flat
    image-border: 5
    padding: 6
    background-color: #131b26ee

    Label
      id: activeMetric
      anchors.left: parent.left
      anchors.top: parent.top
      width: 94
      height: 17
      color: #76ff9f
      font: verdana-11px-bold
      text: Ativos: 0

    Label
      id: inactiveMetric
      anchors.left: activeMetric.right
      anchors.top: parent.top
      margin-left: 8
      width: 104
      height: 17
      color: #ff7676
      font: verdana-11px-bold
      text: Inativos: 0

    Label
      id: pausedMetric
      anchors.left: inactiveMetric.right
      anchors.top: parent.top
      margin-left: 8
      width: 104
      height: 17
      color: #ffd36b
      font: verdana-11px-bold
      text: Pausados: 0

    Label
      id: cpuMetric
      anchors.left: parent.left
      anchors.top: activeMetric.bottom
      margin-top: 4
      width: 94
      height: 16
      color: #cfd8e3
      font: verdana-11px
      text: CPU: n/d

    Label
      id: ramMetric
      anchors.left: cpuMetric.right
      anchors.top: activeMetric.bottom
      margin-left: 8
      margin-top: 4
      width: 135
      height: 16
      color: #cfd8e3
      font: verdana-11px
      text: RAM: n/d

    Label
      id: updateMetric
      anchors.left: ramMetric.right
      anchors.right: parent.right
      anchors.top: activeMetric.bottom
      margin-left: 8
      margin-top: 4
      height: 16
      color: #cfd8e3
      font: verdana-11px
      text: Atualizado: -

  Panel
    id: sidebarPanel
    anchors.top: dashboardPanel.bottom
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    margin-top: 8
    margin-bottom: 42
    width: 218
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
      margin-top: 4
      height: 58
      padding: 5
      image-source: /images/ui/panel_flat
      image-border: 5
      background-color: #171b22dd

      Label
        id: comboIcon
        anchors.left: parent.left
        anchors.top: parent.top
        width: 30
        height: 44
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
        height: 15
        color: #cfd8e3
        font: verdana-11px-bold
        text: COMBO ESPART

      Label
        id: comboDesc
        anchors.left: comboIcon.right
        anchors.right: comboGear.left
        anchors.top: comboTitle.bottom
        margin-left: 4
        margin-top: 1
        height: 15
        color: #9fb2c4
        font: verdana-11px
        text: Delay e prioridades

      Label
        id: comboBadge
        anchors.right: comboGear.left
        anchors.top: parent.top
        margin-right: 4
        width: 54
        height: 15
        text-align: center
        color: #ff7676
        font: verdana-11px-bold
        text: Inativo

      Button
        id: comboEnable
        anchors.left: comboIcon.right
        anchors.right: comboGear.left
        anchors.top: comboDesc.bottom
        margin-left: 4
        margin-right: 4
        height: 18
        text: Ativar

      Button
        id: comboGear
        anchors.right: parent.right
        anchors.top: parent.top
        width: 30
        height: 44
        text: CFG

    Panel
      id: smartCard
      anchors.top: comboCard.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 5
      height: 58
      padding: 5
      image-source: /images/ui/panel_flat
      image-border: 5
      background-color: #171b22dd

      Label
        id: smartIcon
        anchors.left: parent.left
        anchors.top: parent.top
        width: 30
        height: 44
        text-align: center
        color: #ffd36b
        font: verdana-11px-bold
        text: PVP

      Label
        id: smartTitle
        anchors.left: smartIcon.right
        anchors.right: smartBadge.left
        anchors.top: parent.top
        margin-left: 4
        margin-right: 4
        height: 15
        color: #cfd8e3
        font: verdana-11px-bold
        text: SMART PVP

      Label
        id: smartDesc
        anchors.left: smartIcon.right
        anchors.right: smartGear.left
        anchors.top: smartTitle.bottom
        margin-left: 4
        margin-top: 1
        height: 15
        color: #9fb2c4
        font: verdana-11px
        text: SSA, ring e trap

      Label
        id: smartBadge
        anchors.right: smartGear.left
        anchors.top: parent.top
        margin-right: 4
        width: 54
        height: 15
        text-align: center
        color: #ff7676
        font: verdana-11px-bold
        text: Inativo

      Button
        id: smartEnable
        anchors.left: smartIcon.right
        anchors.right: smartGear.left
        anchors.top: smartDesc.bottom
        margin-left: 4
        margin-right: 4
        height: 18
        text: Ativar

      Button
        id: smartGear
        anchors.right: parent.right
        anchors.top: parent.top
        width: 30
        height: 44
        text: CFG

    Label
      id: castleCategory
      anchors.top: smartCard.bottom
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
      margin-top: 4
      height: 58
      padding: 5
      image-source: /images/ui/panel_flat
      image-border: 5
      background-color: #171b22dd

      Label
        id: castleIcon
        anchors.left: parent.left
        anchors.top: parent.top
        width: 30
        height: 44
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
        height: 15
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
        height: 15
        color: #9fb2c4
        font: verdana-11px
        text: Areas e logout

      Label
        id: castleBadge
        anchors.right: castleGear.left
        anchors.top: parent.top
        margin-right: 4
        width: 54
        height: 15
        text-align: center
        color: #ff7676
        font: verdana-11px-bold
        text: Inativo

      Button
        id: castleEnable
        anchors.left: castleIcon.right
        anchors.right: castleGear.left
        anchors.top: castleDesc.bottom
        margin-left: 4
        margin-right: 4
        height: 18
        text: Ativar

      Button
        id: castleGear
        anchors.right: parent.right
        anchors.top: parent.top
        width: 30
        height: 44
        text: CFG

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
      margin-top: 4
      height: 58
      padding: 5
      image-source: /images/ui/panel_flat
      image-border: 5
      background-color: #171b22dd

      Label
        id: holidayIcon
        anchors.left: parent.left
        anchors.top: parent.top
        width: 30
        height: 44
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
        height: 15
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
        height: 15
        color: #9fb2c4
        font: verdana-11px
        text: Magias e safe

      Label
        id: holidayBadge
        anchors.right: holidayGear.left
        anchors.top: parent.top
        margin-right: 4
        width: 54
        height: 15
        text-align: center
        color: #ff7676
        font: verdana-11px-bold
        text: Inativo

      Button
        id: holidayEnable
        anchors.left: holidayIcon.right
        anchors.right: holidayGear.left
        anchors.top: holidayDesc.bottom
        margin-left: 4
        margin-right: 4
        height: 18
        text: Ativar

      Button
        id: holidayGear
        anchors.right: parent.right
        anchors.top: parent.top
        width: 30
        height: 44
        text: CFG

  Panel
    id: detailPanel
    anchors.top: dashboardPanel.bottom
    anchors.left: sidebarPanel.right
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    margin-left: 8
    margin-top: 8
    margin-bottom: 42
    image-source: /images/ui/panel_flat
    image-border: 5
    padding: 8
    background-color: #101720ee

    Label
      id: detailTitle
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.right: detailBadge.left
      margin-right: 8
      height: 18
      color: #ffd36b
      font: verdana-11px-bold
      text: COMBO ESPART

    Label
      id: detailBadge
      anchors.right: parent.right
      anchors.top: parent.top
      width: 70
      height: 18
      text-align: center
      color: #ff7676
      font: verdana-11px-bold
      text: Inativo

    Label
      id: detailSubtitle
      anchors.left: parent.left
      anchors.top: detailTitle.bottom
      anchors.right: detailLoad.left
      margin-top: 2
      margin-right: 7
      height: 18
      color: #cfd8e3
      font: verdana-11px
      text: Configuracao centralizada

    Button
      id: detailLoad
      anchors.right: parent.right
      anchors.top: detailBadge.bottom
      margin-top: 1
      width: 86
      height: 22
      text: Ativar

    Panel
      id: configPanel
      anchors.top: detailSubtitle.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      margin-top: 8
      padding: 4
      background-color: #0d121add

      Panel
        id: configRow1
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 34

        Label
          id: configLabel1
          anchors.left: parent.left
          anchors.top: parent.top
          width: 126
          height: 26
          color: #e8edf4
          font: verdana-11px-bold

        TextEdit
          id: configInput1
          anchors.left: configLabel1.right
          anchors.right: configAction1.left
          anchors.top: parent.top
          margin-left: 5
          margin-right: 5
          height: 24

        Button
          id: configAction1
          anchors.right: parent.right
          anchors.top: parent.top
          width: 66
          height: 24
          text: OK

      Panel
        id: configRow2
        anchors.top: configRow1.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        margin-top: 5
        height: 34

        Label
          id: configLabel2
          anchors.left: parent.left
          anchors.top: parent.top
          width: 126
          height: 26
          color: #e8edf4
          font: verdana-11px-bold

        TextEdit
          id: configInput2
          anchors.left: configLabel2.right
          anchors.right: configAction2.left
          anchors.top: parent.top
          margin-left: 5
          margin-right: 5
          height: 24

        Button
          id: configAction2
          anchors.right: parent.right
          anchors.top: parent.top
          width: 66
          height: 24
          text: OK

      Panel
        id: configRow3
        anchors.top: configRow2.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        margin-top: 5
        height: 34

        Label
          id: configLabel3
          anchors.left: parent.left
          anchors.top: parent.top
          width: 126
          height: 26
          color: #e8edf4
          font: verdana-11px-bold

        TextEdit
          id: configInput3
          anchors.left: configLabel3.right
          anchors.right: configAction3.left
          anchors.top: parent.top
          margin-left: 5
          margin-right: 5
          height: 24

        Button
          id: configAction3
          anchors.right: parent.right
          anchors.top: parent.top
          width: 66
          height: 24
          text: OK

      Panel
        id: configRow4
        anchors.top: configRow3.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        margin-top: 5
        height: 34

        Label
          id: configLabel4
          anchors.left: parent.left
          anchors.top: parent.top
          width: 126
          height: 26
          color: #e8edf4
          font: verdana-11px-bold

        TextEdit
          id: configInput4
          anchors.left: configLabel4.right
          anchors.right: configAction4.left
          anchors.top: parent.top
          margin-left: 5
          margin-right: 5
          height: 24

        Button
          id: configAction4
          anchors.right: parent.right
          anchors.top: parent.top
          width: 66
          height: 24
          text: OK

      Panel
        id: configRow5
        anchors.top: configRow4.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        margin-top: 5
        height: 34

        Label
          id: configLabel5
          anchors.left: parent.left
          anchors.top: parent.top
          width: 126
          height: 26
          color: #e8edf4
          font: verdana-11px-bold

        TextEdit
          id: configInput5
          anchors.left: configLabel5.right
          anchors.right: configAction5.left
          anchors.top: parent.top
          margin-left: 5
          margin-right: 5
          height: 24

        Button
          id: configAction5
          anchors.right: parent.right
          anchors.top: parent.top
          width: 66
          height: 24
          text: OK

      Panel
        id: configRow6
        anchors.top: configRow5.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        margin-top: 5
        height: 34

        Label
          id: configLabel6
          anchors.left: parent.left
          anchors.top: parent.top
          width: 126
          height: 26
          color: #e8edf4
          font: verdana-11px-bold

        TextEdit
          id: configInput6
          anchors.left: configLabel6.right
          anchors.right: configAction6.left
          anchors.top: parent.top
          margin-left: 5
          margin-right: 5
          height: 24

        Button
          id: configAction6
          anchors.right: parent.right
          anchors.top: parent.top
          width: 66
          height: 24
          text: OK

      Panel
        id: configRow7
        anchors.top: configRow6.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        margin-top: 5
        height: 34

        Label
          id: configLabel7
          anchors.left: parent.left
          anchors.top: parent.top
          width: 126
          height: 26
          color: #e8edf4
          font: verdana-11px-bold

        TextEdit
          id: configInput7
          anchors.left: configLabel7.right
          anchors.right: configAction7.left
          anchors.top: parent.top
          margin-left: 5
          margin-right: 5
          height: 24

        Button
          id: configAction7
          anchors.right: parent.right
          anchors.top: parent.top
          width: 66
          height: 24
          text: OK

      Panel
        id: configRow8
        anchors.top: configRow7.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        margin-top: 5
        height: 34

        Label
          id: configLabel8
          anchors.left: parent.left
          anchors.top: parent.top
          width: 126
          height: 26
          color: #e8edf4
          font: verdana-11px-bold

        TextEdit
          id: configInput8
          anchors.left: configLabel8.right
          anchors.right: configAction8.left
          anchors.top: parent.top
          margin-left: 5
          margin-right: 5
          height: 24

        Button
          id: configAction8
          anchors.right: parent.right
          anchors.top: parent.top
          width: 66
          height: 24
          text: OK

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
      text: Ativar tudo

    Button
      id: clearButton
      anchors.left: allButton.right
      anchors.top: parent.top
      margin-left: 5
      width: 92
      height: 24
      text: Desativar

    Button
      id: confirmButton
      anchors.left: clearButton.right
      anchors.right: closeButton.left
      anchors.top: parent.top
      margin-left: 5
      margin-right: 5
      height: 24
      text: Carregar liberados

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
  local okWindow, window = pcall(function() return UI.createWindow("DerpetsonScriptsHubWindow", root) end)
  if not okWindow or not window then
    okWindow, window = pcall(function() return UI.createWindow("DerpetsonScriptsHubWindow") end)
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
      for _, module in ipairs(JQM_MODULES) do
        local data = jqmModuleData(module.key)
        data.enabled = true
        data.config.enabled = true
        data.paused = false
        jqmApplyModuleConfig(module, "enabled", true)
        if module.script then storage.JQMScriptManager.selected[module.script] = true end
      end
      jqmTouchUpdate()
      jqmRefreshManagerUi()
      jqmRequestOrLoad()
    end
  end
  if jqmWindowControl("clearButton") then
    jqmWindowControl("clearButton").onClick = function()
      for _, module in ipairs(JQM_MODULES) do
        module:setEnabled(false)
      end
      jqmRefreshManagerUi()
    end
  end
  if jqmWindowControl("detailLoad") then
    jqmWindowControl("detailLoad").onClick = function()
      local module = jqmActiveModule()
      if module then
        module:setEnabled(not jqmModuleRuntimeActive(module))
      end
    end
  end

  for index = 1, 8 do
    local rowIndex = index
    local input = jqmWindowControl("configInput" .. tostring(index))
    local action = jqmWindowControl("configAction" .. tostring(index))
    if input then
      input.onTextChange = function(_, text)
        if jqmInputLocks["configInput" .. tostring(rowIndex)] then return end
        jqmSaveConfigInput(rowIndex, text)
      end
    end
    if action then
      action.onClick = function() jqmConfigAction(rowIndex) end
    end
  end

  local function bindModuleCard(module)
    if not module then return end
    local prefix = module.prefix
    if not prefix then return end

    local function selectModule()
      storage.JQMScriptManager.activeModule = module.key
      jqmRefreshManagerUi()
    end
    local function toggleModule()
      storage.JQMScriptManager.activeModule = module.key
      module:setEnabled(not jqmModuleRuntimeActive(module))
    end
    local function hoverModule(_, hovered)
      jqmUpdateModuleCard(module, hovered == true)
    end

    for _, suffix in ipairs({ "Card", "Icon", "Title", "Desc", "Badge" }) do
      local widget = jqmWindowControl(prefix .. suffix)
      if widget then
        widget.onClick = selectModule
        widget.onHoverChange = hoverModule
      end
    end

    local enable = jqmWindowControl(prefix .. "Enable")
    if enable then
      enable.onClick = toggleModule
      enable.onHoverChange = hoverModule
    end

    local gear = jqmWindowControl(prefix .. "Gear")
    if gear then
      gear.onClick = selectModule
      gear.onHoverChange = hoverModule
    end
  end

  for _, module in ipairs(JQM_MODULES) do
    bindModuleCard(module)
  end

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
