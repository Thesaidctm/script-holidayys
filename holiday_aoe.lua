-- ============================================================
-- HOLIDAY AOE VOCATION SPELLS V19.1 - SAFE ICON + COMBO + PERFIS + COOLDOWNS + AUTO UPDATE
-- Baseado no script enviado pelo usuario.
--
-- Ajustes principais:
-- - Auto vocacao no login, com fallback manual EK/RP/MS/ED.
-- - Modo PvE: rotacao leve com prioridade e minimos de mobs.
-- - Modo PvP Combo: tenta castar todos os grupos habilitados da vocacao no mesmo ciclo.
-- - PvP MS/ED NAO usa wave; usa exori max vis / exori max frigo em single target.
-- - Loop central leve: tick curto, trabalho pesado cacheado por intervalo.
-- - V13: loop real e varredura de mobs desacoplados para aliviar CaveBot/TargetBot.
-- - V13: cooldowns flutuantes por magia usada, arrastaveis com Ctrl.
-- - V13: magias de ataque respeitam cooldown real e grupos compartilhados A/B/C.
-- - V13: janelas de insistencia antes/depois do cooldown para reduzir buracos entre casts.
-- - V13: cooldown de magia fica pendente e e cancelado se o servidor avisar falta de mana.
-- - V13: cada magia respeita custo de mana percentual do servidor.
-- - V15/V18: icon SAFE bloqueia area/wave somente quando existe player na tela.
-- - V15: cooldown manual registrado para as magias ofensivas principais.
-- - V16: SD sempre ativa para MS/ED em PVE/PVP e Paralyze Rune opcional no PVP.
-- - V17: icon COMBO tenta categorias A/B/C em sequencia e respeita SAFE para area/wave.
-- - V17: e-ring configuravel na aba interna usando IDs do PvPScripts3 salvo no storage.
-- - Aura com item arrastavel/configuravel e prioridade alta.
-- - Sem schedule/delay bloqueante no combate.
-- - EK corrigido: somente exori gran. Removidos exori mas e exori.
-- - MS/ED: gran mas vis/tera corrigidos para sair antes da wave no PvE.
-- ============================================================

setDefaultTab("Main")

local HOLIDAY_AOE_SCRIPT_VERSION = 2026060902
local HOLIDAY_AOE_SCRIPT_NAME = "holiday_aoe.lua"
local HOLIDAY_AOE_OTUI_NAME = "holiday_aoe.otui"
local HOLIDAY_AOE_UPDATE_URL = "https://api.github.com/repos/Thesaidctm/script-holidayys/contents/holiday_aoe.lua?ref=main"
local HOLIDAY_AOE_OTUI_UPDATE_URL = "https://api.github.com/repos/Thesaidctm/script-holidayys/contents/holiday_aoe.otui?ref=main"

-- ============================================================
-- 0) STORAGE / DEFAULTS
-- ============================================================

local panelName = "holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii"
storage[panelName] = storage[panelName] or {}
aoeSettings = storage[panelName]

local function focusGameMapSoon(delay)
  if not schedule then return end
  schedule(delay or 30, function()
    if g_game and g_game.isOnline and not g_game.isOnline() then return end
    if modules and modules.game_interface and modules.game_interface.getMapPanel then
      local ok, mapPanel = pcall(function() return modules.game_interface.getMapPanel() end)
      if ok and mapPanel and mapPanel.focus then
        pcall(function() mapPanel:focus() end)
      end
    end
  end)
end

local function initDefaults()
  local defaults = {
    enableAura = true,
    enableDefense = true,
    enableBuff = true,
    enableSummon = false,
    enableWave = true,
    enableArea = true, -- legado
    enableMageArea = true,
    enableRpMasSan = true,
    enableEkArea = true,
    enableRpSingle = true,
    enableMageSd = true,
    enableParalyzeRune = false,
    enableMageStrongArea = true,
    enableEkSingle = true,
    useRpGranCon = true,
    useRpCon = true,
    useEkIco = true,
    useEkGranIco = true,
    enableEkGran = true,
    enableEkMas = false, -- removido: servidor nao possui exori mas
    enableEkExori = false, -- removido: servidor nao possui exori
    enableDebug = false,
    enablePvpSingle = true,
    enableCooldownIcons = true,
    enablePveMode = true,
    enablePvpMode = false,
    enableComboMode = false,
    pveSafeMode = true,
    enableEnergyRing = false,
    autoUpdateEnabled = true,
    autoUpdateIntervalSeconds = 600,
    autoReloadAfterUpdate = false,
    -- Modo de combate: pve = economico/leve; pvp = combo todos os grupos.
    combatMode = "pve",

    -- Vocacao: auto detecta no login; botoes manuais servem como fallback.
    autoDetectVocation = true,
    detectedVocation = "",
    detectedVocationPlayer = "",
    forceVocation = "knight",

    -- Minimos de mobs
    minWaveMobs = 1,
    minAreaMsEd = 1,
    minAreaRp = 3,
    minEkGran = 2,

    -- Intervalos/intervalos
    mainLoopMs = 100,
    scanIntervalMs = 150,
    idleScanIntervalMs = 300,
    turnThrottleMs = 150,
    attackLeadMs = 500,
    attackPostMs = 500,
    manaFailCheckMs = 500,
    rpUtitoRenewMs = 10000,
    ekUtitoRenewMs = 10000,
    auraDelay = 100,
    auraCooldownSec = 120,
    utanaVidCooldownSec = 120,
    auraItemId = 5571,
    sdRuneId = 3155,
    paralyzeRuneId = 3165,
    paralyzeIntervalMs = 6000,
    energyRingItemId = 3051,
    energyRingActiveId = 3088,
    energyRingHp = 70,
    energyRingMp = 70,
    energyRingDelayMs = 250,

    -- HP/defesas
    auraHp = 25,
    utamoHpOn = 45,
    utamoHpOff = 60,
    knightUtamoHp = 45,

    -- Area 6x6 assimetrica, igual ao anterior
    aoe6Left = 3,
    aoe6Right = 2,
    aoe6Up = 3,
    aoe6Down = 2,

    -- Spells padrao
    msWaveSpell = "exevo vis hur",
    edWaveSpell = "exevo tera hur",
    msPvpSingleSpell = "exori max vis",
    edPvpSingleSpell = "exori max FRIGO",
    msAreaSpell = "exevo gran mas vis",
    edAreaSpell = "exevo gran mas tera",
    msStrongAreaSpell = "exevo gran mas flam",
    edStrongAreaSpell = "exevo gran mas frigo",
    rpMasSanSpell = "exevo mas san",
    rpGranConSpell = "exori gran con",
    rpConSpell = "exori con",
    ekIcoSpell = "exori ico",
    ekGranIcoSpell = "exori gran ico",
    ekGranSpell = "exori gran",

    note = "V19.1: auto update scope hotfix"
  }

  for k, v in pairs(defaults) do
    if aoeSettings[k] == nil then
      aoeSettings[k] = v
    end
  end

  -- Migra storage antigo para o novo Auto seguro.
  if aoeSettings.forceVocation == "auto" or aoeSettings.forceVocation == "automatico" or aoeSettings.forceVocation == "automatico" then
    aoeSettings.autoDetectVocation = true
    aoeSettings.forceVocation = "knight"
  end

  -- V13: ativa a area forte sem summon uma vez para perfis que ja tinham salvo o antigo "false".
  -- Depois disso, se o usuario desligar pela janela, respeita a escolha.
  if aoeSettings.strongAreaAutoEnabledV13 ~= true then
    aoeSettings.enableMageStrongArea = true
    aoeSettings.strongAreaAutoEnabledV13 = true
  end

  -- V9: magias fixas no codigo, sem campo custom na janela.
  -- Isso limpa texto antigo salvo no storage e remove o problema do "area extra" aparecendo para editar.
  aoeSettings.msWaveSpell = "exevo vis hur"
  aoeSettings.edWaveSpell = "exevo tera hur"
  aoeSettings.msPvpSingleSpell = "exori max vis"
  aoeSettings.edPvpSingleSpell = "exori max frigo"
  aoeSettings.msAreaSpell = "exevo gran mas vis"
  aoeSettings.edAreaSpell = "exevo gran mas tera"
  aoeSettings.msStrongAreaSpell = "exevo gran mas flam"
  aoeSettings.edStrongAreaSpell = "exevo gran mas frigo"
  aoeSettings.rpMasSanSpell = "exevo mas san"
  aoeSettings.rpGranConSpell = "exori gran con"
  aoeSettings.rpConSpell = "exori con"
  aoeSettings.ekIcoSpell = "exori ico"
  aoeSettings.ekGranIcoSpell = "exori gran ico"
  aoeSettings.ekGranSpell = "exori gran"
  aoeSettings.enableEkMas = false
  aoeSettings.enableEkExori = false
end

initDefaults()

-- ============================================================
-- 1) HELPERS DE CONFIG
-- ============================================================

function aoeGet(id, defaultValue)
  if not aoeSettings then return defaultValue end
  local value = aoeSettings[id]
  if value == nil then return defaultValue end
  local n = tonumber(value)
  if n == nil then return defaultValue end
  return n
end

function aoeText(id, defaultValue)
  if not aoeSettings then return defaultValue end
  local value = aoeSettings[id]
  if value == nil or value == "" then return defaultValue end
  return tostring(value)
end

function aoeIsOn(id, defaultValue)
  if not aoeSettings then return defaultValue end
  if aoeSettings[id] == nil then return defaultValue end
  return aoeSettings[id] == true
end

local function normalizeTextValue(value)
  local v = tostring(value or ""):lower():gsub("%s+", " ")
  return v:gsub("^%s+", ""):gsub("%s+$", "")
end

local function vocationKeyFromValue(value)
  local v = normalizeTextValue(value)
  if v == "1" or v == "5" or v == "sorcerer" or v == "ms" or v == "master sorcerer" then return "sorcerer" end
  if v == "2" or v == "6" or v == "druid" or v == "ed" or v == "elder druid" then return "druid" end
  if v == "3" or v == "7" or v == "paladin" or v == "rp" or v == "royal paladin" then return "paladin" end
  if v == "4" or v == "8" or v == "knight" or v == "ek" or v == "elite knight" then return "knight" end
  return nil
end

local function normalizeVocationName(value)
  return vocationKeyFromValue(value) or "knight"
end

local function formatVocationLabel(vocation)
  vocation = normalizeVocationName(vocation)
  if vocation == "sorcerer" then return "MS - Sorcerer" end
  if vocation == "druid" then return "ED - Druid" end
  if vocation == "paladin" then return "RP - Paladin" end
  return "EK - Knight"
end

local function normalizeCombatMode(value)
  local v = tostring(value or "pve"):lower()
  if v == "pvp" or v == "combo" or v == "pk" then return "pvp" end
  return "pve"
end

aoeSettings.forceVocation = normalizeVocationName(aoeSettings.forceVocation)
aoeSettings.combatMode = normalizeCombatMode(aoeSettings.combatMode)
aoeSettings.detectedVocation = vocationKeyFromValue(aoeSettings.detectedVocation) or ""
aoeSettings.detectedVocationPlayer = tostring(aoeSettings.detectedVocationPlayer or "")
aoeSettings.autoDetectVocation = aoeSettings.autoDetectVocation ~= false

local profileSkills = {
  sorcerer = {
    { action = "sd", label = "SD Rune", item = 3155, modes = { pve = true, pvp = true }, locked = true },
    { action = "paralyze", label = "Paralyze Rune", item = 3165, modes = { pvp = true } },
    { action = "wave", label = "Exevo Vis Hur", item = 8092, modes = { pve = true } },
    { action = "pvpSingle", label = "Exori Max Vis", item = 8092, modes = { pvp = true } },
    { action = "area", label = "Gran Mas Vis", item = 8092, modes = { pve = true, pvp = true } },
    { action = "strongArea", label = "Gran Mas Flam", item = 3071, modes = { pve = true, pvp = true } }
  },
  druid = {
    { action = "sd", label = "SD Rune", item = 3155, modes = { pve = true, pvp = true }, locked = true },
    { action = "paralyze", label = "Paralyze Rune", item = 3165, modes = { pvp = true } },
    { action = "wave", label = "Exevo Tera Hur", item = 8084, modes = { pve = true } },
    { action = "pvpSingle", label = "Exori Max Frigo", item = 8140, modes = { pvp = true } },
    { action = "area", label = "Gran Mas Tera", item = 8084, modes = { pve = true, pvp = true } },
    { action = "strongArea", label = "Gran Mas Frigo", item = 3067, modes = { pve = true, pvp = true } }
  },
  paladin = {
    { action = "paralyze", label = "Paralyze Rune", item = 3165, modes = { pvp = true } },
    { action = "masSan", label = "Exevo Mas San", item = 7365, modes = { pve = true, pvp = true } },
    { action = "granCon", label = "Exori Gran Con", item = 7364, modes = { pve = true, pvp = true } },
    { action = "con", label = "Exori Con", item = 7364, modes = { pve = true, pvp = true } }
  },
  knight = {
    { action = "paralyze", label = "Paralyze Rune", item = 3165, modes = { pvp = true } },
    { action = "gran", label = "Exori Gran", item = 7434, modes = { pve = true, pvp = true } },
    { action = "granIco", label = "Exori Gran Ico", item = 7434, modes = { pve = true, pvp = true } },
    { action = "ico", label = "Exori Ico", item = 7434, modes = { pve = true, pvp = true } }
  }
}

local profileDefaults = {
  pve = {
    sorcerer = { sd = true, wave = true, area = true, strongArea = true },
    druid = { sd = true, wave = true, area = true, strongArea = true },
    paladin = { masSan = true, granCon = true, con = true },
    knight = { gran = true, granIco = true, ico = true }
  },
  pvp = {
    sorcerer = { sd = true, paralyze = false, pvpSingle = true, area = true, strongArea = true },
    druid = { sd = true, paralyze = false, pvpSingle = true, area = true, strongArea = true },
    paladin = { paralyze = false, masSan = true, granCon = true, con = true },
    knight = { paralyze = false, gran = true, granIco = true, ico = true }
  }
}

local function profileSkillAllowedInMode(skill, mode)
  return not skill.modes or skill.modes[mode] == true
end

local function ensureSkillProfiles()
  if type(aoeSettings.skillProfiles) ~= "table" then aoeSettings.skillProfiles = {} end

  for mode, vocations in pairs(profileDefaults) do
    if type(aoeSettings.skillProfiles[mode]) ~= "table" then aoeSettings.skillProfiles[mode] = {} end
    for vocation, skills in pairs(vocations) do
      if type(aoeSettings.skillProfiles[mode][vocation]) ~= "table" then
        aoeSettings.skillProfiles[mode][vocation] = {}
      end
      for action, value in pairs(skills) do
        if aoeSettings.skillProfiles[mode][vocation][action] == nil then
          aoeSettings.skillProfiles[mode][vocation][action] = value
        end
      end
    end
  end

  if aoeSettings.skillProfilesMigratedV14 ~= true then
    for _, vocation in ipairs({"sorcerer", "druid"}) do
      aoeSettings.skillProfiles.pve[vocation].sd = aoeIsOn("enableMageSd", false)
      aoeSettings.skillProfiles.pve[vocation].wave = aoeIsOn("enableWave", true)
      aoeSettings.skillProfiles.pve[vocation].area = aoeIsOn("enableMageArea", true)
      aoeSettings.skillProfiles.pve[vocation].strongArea = aoeIsOn("enableMageStrongArea", true)
      aoeSettings.skillProfiles.pvp[vocation].sd = aoeIsOn("enableMageSd", false)
      aoeSettings.skillProfiles.pvp[vocation].pvpSingle = aoeIsOn("enablePvpSingle", true)
      aoeSettings.skillProfiles.pvp[vocation].area = aoeIsOn("enableMageArea", true)
      aoeSettings.skillProfiles.pvp[vocation].strongArea = aoeIsOn("enableMageStrongArea", true)
    end

    aoeSettings.skillProfiles.pve.paladin.masSan = aoeIsOn("enableRpMasSan", true)
    aoeSettings.skillProfiles.pve.paladin.granCon = aoeIsOn("enableRpSingle", true) and aoeIsOn("useRpGranCon", true)
    aoeSettings.skillProfiles.pve.paladin.con = aoeIsOn("enableRpSingle", true) and aoeIsOn("useRpCon", true)
    aoeSettings.skillProfiles.pvp.paladin.masSan = aoeIsOn("enableRpMasSan", true)
    aoeSettings.skillProfiles.pvp.paladin.granCon = aoeIsOn("enableRpSingle", true) and aoeIsOn("useRpGranCon", true)
    aoeSettings.skillProfiles.pvp.paladin.con = aoeIsOn("enableRpSingle", true) and aoeIsOn("useRpCon", true)

    aoeSettings.skillProfiles.pve.knight.gran = aoeIsOn("enableEkArea", true) and aoeIsOn("enableEkGran", true)
    aoeSettings.skillProfiles.pve.knight.granIco = aoeIsOn("enableEkSingle", true) and aoeIsOn("useEkGranIco", true)
    aoeSettings.skillProfiles.pve.knight.ico = aoeIsOn("enableEkSingle", true) and aoeIsOn("useEkIco", true)
    aoeSettings.skillProfiles.pvp.knight.gran = aoeIsOn("enableEkArea", true) and aoeIsOn("enableEkGran", true)
    aoeSettings.skillProfiles.pvp.knight.granIco = aoeIsOn("enableEkSingle", true) and aoeIsOn("useEkGranIco", true)
    aoeSettings.skillProfiles.pvp.knight.ico = aoeIsOn("enableEkSingle", true) and aoeIsOn("useEkIco", true)

    if normalizeCombatMode(aoeSettings.combatMode or "pve") == "pvp" then
      aoeSettings.enablePvpMode = true
    end

    aoeSettings.skillProfilesMigratedV14 = true
  end

  -- V16: SD passa a compor sempre os perfis mage em PVE e PVP.
  if aoeSettings.sdAlwaysEnabledV16 ~= true then
    for _, vocation in ipairs({"sorcerer", "druid"}) do
      aoeSettings.skillProfiles.pve[vocation].sd = true
      aoeSettings.skillProfiles.pvp[vocation].sd = true
    end
    aoeSettings.enableMageSd = true
    aoeSettings.sdAlwaysEnabledV16 = true
  end

  -- V18: storages antigos podiam deixar o Mas San salvo como falso e travar o perfil novo.
  if aoeSettings.rpMasSanEnabledV18 ~= true then
    aoeSettings.enableRpMasSan = true
    aoeSettings.skillProfiles.pve.paladin.masSan = true
    aoeSettings.skillProfiles.pvp.paladin.masSan = true
    aoeSettings.rpMasSanEnabledV18 = true
  end
end

ensureSkillProfiles()

local function profileSkillOn(mode, vocation, action, defaultValue)
  mode = mode == "pvp" and "pvp" or "pve"
  vocation = normalizeVocationName(vocation)
  if action == "sd" and (vocation == "sorcerer" or vocation == "druid") then
    return true
  end
  ensureSkillProfiles()
  local byMode = aoeSettings.skillProfiles[mode] or {}
  local byVoc = byMode[vocation] or {}
  if byVoc[action] == nil then return defaultValue == true end
  return byVoc[action] == true
end

local function setProfileSkill(mode, vocation, action, value)
  mode = mode == "pvp" and "pvp" or "pve"
  vocation = normalizeVocationName(vocation)
  ensureSkillProfiles()
  aoeSettings.skillProfiles[mode][vocation][action] = value == true
end

local function nowMs()
  if now then return now end
  if g_clock and g_clock.millis then return g_clock.millis() end
  return math.floor(os.clock() * 1000)
end

HolidayAOE = HolidayAOE or {}

local function debugWarn(text)
  if aoeIsOn("enableDebug", false) and warn then warn(text) end
end

do
local holidayAoeAutoUpdateBusy = false
local holidayAoeLastUpdateErrorAt = 0

local function holidayAoeEpochSeconds()
  if os and os.time then return os.time() end
  return math.floor(nowMs() / 1000)
end

local function holidayAoeUpdateMessage(text)
  local message = "[HOLIDAY AOE] " .. tostring(text)
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

local function holidayAoeUpdateError(text, force)
  local tm = holidayAoeEpochSeconds()
  if force or tm >= holidayAoeLastUpdateErrorAt + 3600 then
    holidayAoeLastUpdateErrorAt = tm
    holidayAoeUpdateMessage(text)
  end
end

local function holidayAoeOnce(callback)
  local called = false
  return function(...)
    if called then return end
    called = true
    callback(...)
  end
end

local function holidayAoeNormalizeHttpArgs(a, b, c)
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

local function holidayAoeBase64Decode(data)
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

local function holidayAoeDecodeJsonString(value)
  value = tostring(value or "")
  value = value:gsub("\\n", "")
  value = value:gsub("\\r", "")
  value = value:gsub("\\t", "")
  value = value:gsub("\\/", "/")
  value = value:gsub('\\"', '"')
  value = value:gsub("\\\\", "\\")
  return value
end

local function holidayAoeExtractGithubApiScript(data)
  if type(data) ~= "string" or not data:find('"content"%s*:', 1) then return nil end
  if not data:find('"encoding"%s*:%s*"base64"', 1) then return nil end

  local encoded = data:match('"content"%s*:%s*"(.-)"')
  if not encoded then return nil end

  return holidayAoeBase64Decode(holidayAoeDecodeJsonString(encoded))
end

local function holidayAoeHttpGet(url, callback)
  local done = holidayAoeOnce(callback)
  local httpCandidates = {}
  if type(HTTP) == "table" then table.insert(httpCandidates, HTTP) end
  if type(g_http) == "table" then table.insert(httpCandidates, g_http) end
  if modules and modules.corelib and type(modules.corelib.HTTP) == "table" then table.insert(httpCandidates, modules.corelib.HTTP) end
  if modules and modules._G and type(modules._G.HTTP) == "table" then table.insert(httpCandidates, modules._G.HTTP) end

  for _, http in ipairs(httpCandidates) do
    if type(http) == "table" and type(http.get) == "function" then
      local ok = pcall(function()
        local response = http.get(url, function(a, b, c)
          local data, err = holidayAoeNormalizeHttpArgs(a, b, c)
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

local function holidayAoeConfigFilePath(fileName)
  local config = ""
  if type(configName) == "string" and configName ~= "" then
    config = configName
  elseif type(botConfigName) == "string" and botConfigName ~= "" then
    config = botConfigName
  else
    config = "MAGE_FINAL"
  end
  return "/bot/" .. config .. "/" .. tostring(fileName or "")
end

local function holidayAoeScriptPath()
  return holidayAoeConfigFilePath(HOLIDAY_AOE_SCRIPT_NAME)
end

local function holidayAoeExtractScriptVersion(data)
  if type(data) ~= "string" then return nil end
  return tonumber(data:match("HOLIDAY_AOE_SCRIPT_VERSION%s*=%s*(%d+)"))
end

local function holidayAoeLooksLikeScript(data)
  return type(data) == "string"
    and #data > 10000
    and data:find("holiday_aoe_vocation_v12_sem_icones_pvp_area_ascii", 1, true) ~= nil
    and data:find("HOLIDAY AOE", 1, true) ~= nil
    and holidayAoeExtractScriptVersion(data) ~= nil
end

local function holidayAoeLooksLikeOtui(data)
  return type(data) == "string"
    and data:find("HolidayAoeV2Window", 1, true) ~= nil
    and data:find("HolidayAoeV2", 1, true) ~= nil
end

local function holidayAoeNormalizeDownloadedScript(data)
  if holidayAoeLooksLikeScript(data) then return data end

  local decoded = holidayAoeExtractGithubApiScript(data)
  if holidayAoeLooksLikeScript(decoded) then return decoded end

  return data
end

local function holidayAoeNormalizeDownloadedOtui(data)
  if holidayAoeLooksLikeOtui(data) then return data end

  local decoded = holidayAoeExtractGithubApiScript(data)
  if holidayAoeLooksLikeOtui(decoded) then return decoded end

  return data
end

local function holidayAoeSaveTextFile(fileName, data, label)
  if type(g_resources) ~= "table" or type(g_resources.writeFileContents) ~= "function" then
    holidayAoeUpdateMessage("Nao foi possivel atualizar " .. tostring(label or fileName) .. ": g_resources.writeFileContents indisponivel.")
    return false
  end

  local scriptPath = holidayAoeConfigFilePath(fileName)
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
    holidayAoeUpdateMessage("Falha ao salvar " .. tostring(label or fileName) .. ": " .. tostring(err))
    return false
  end

  return true
end

local function holidayAoeUpdateOtuiFile()
  holidayAoeHttpGet(HOLIDAY_AOE_OTUI_UPDATE_URL, function(data, err)
    if err or not data then
      holidayAoeUpdateError("Falha ao baixar OTUI: " .. tostring(err or "sem dados"), false)
      return
    end

    data = holidayAoeNormalizeDownloadedOtui(data)
    if not holidayAoeLooksLikeOtui(data) then
      holidayAoeUpdateError("OTUI remoto ignorado: arquivo invalido.", false)
      return
    end

    if holidayAoeSaveTextFile(HOLIDAY_AOE_OTUI_NAME, data, "OTUI") then
      aoeSettings.installedOtuiVersion = tonumber(aoeSettings.installedScriptVersion) or HOLIDAY_AOE_SCRIPT_VERSION
    end
  end)
end

local function holidayAoeSaveDownloadedScript(data, remoteVersion)
  if not holidayAoeSaveTextFile(HOLIDAY_AOE_SCRIPT_NAME, data, "script") then return false end

  aoeSettings.installedScriptVersion = remoteVersion
  holidayAoeUpdateOtuiFile()
  holidayAoeUpdateMessage("Atualizado para versao " .. tostring(remoteVersion) .. ". Recarregue o bot para aplicar.")

  if aoeSettings.autoReloadAfterUpdate == true and type(schedule) == "function" and type(reload) == "function" then
    schedule(1500, function() reload() end)
  end

  return true
end

local function runHolidayAoeAutoUpdate(force)
  if aoeSettings.autoUpdateEnabled ~= true and force ~= true then return false end
  if holidayAoeAutoUpdateBusy then return false end

  local tm = holidayAoeEpochSeconds()
  local interval = tonumber(aoeSettings.autoUpdateIntervalSeconds) or 600
  if interval < 60 then interval = 60 end
  if interval > 86400 then interval = 86400 end
  if force ~= true and tm < tonumber(aoeSettings.nextAutoUpdateCheckAt or 0) then return false end

  aoeSettings.nextAutoUpdateCheckAt = tm + interval
  holidayAoeAutoUpdateBusy = true

  holidayAoeHttpGet(HOLIDAY_AOE_UPDATE_URL, function(data, err)
    holidayAoeAutoUpdateBusy = false
    if err or not data then
      holidayAoeUpdateError("Falha ao checar update: " .. tostring(err or "sem dados"), force)
      return
    end

    data = holidayAoeNormalizeDownloadedScript(data)
    if not holidayAoeLooksLikeScript(data) then
      holidayAoeUpdateError("Update ignorado: arquivo remoto invalido.", force)
      return
    end

    local remoteVersion = holidayAoeExtractScriptVersion(data)
    if not remoteVersion then
      holidayAoeUpdateError("Update ignorado: versao remota ausente.", force)
      return
    end

    aoeSettings.lastRemoteScriptVersion = remoteVersion
    if remoteVersion <= HOLIDAY_AOE_SCRIPT_VERSION then
      if force then holidayAoeUpdateMessage("Ja esta na ultima versao: " .. tostring(HOLIDAY_AOE_SCRIPT_VERSION)) end
      return
    end

    holidayAoeSaveDownloadedScript(data, remoteVersion)
  end)

  return true
end

function HolidayAOE.checkUpdateNow()
  return runHolidayAoeAutoUpdate(true)
end

function HolidayAOE.getUpdateSummary()
  return {
    version = HOLIDAY_AOE_SCRIPT_VERSION,
    remoteVersion = tonumber(aoeSettings.lastRemoteScriptVersion) or 0,
    autoUpdateEnabled = aoeSettings.autoUpdateEnabled == true,
    nextCheckAt = tonumber(aoeSettings.nextAutoUpdateCheckAt) or 0,
    busy = holidayAoeAutoUpdateBusy == true
  }
end

aoeSettings.installedScriptVersion = HOLIDAY_AOE_SCRIPT_VERSION
if schedule then
  schedule(2500, function() runHolidayAoeAutoUpdate(false) end)
else
  runHolidayAoeAutoUpdate(false)
end
end

-- ============================================================
-- 2) INTERFACE
-- Janela principal: mostra ajustes gerais; skills ofensivas ficam nos icons PVE/PVP.
-- Intervalo visual removido; sem janela de icones.
-- ============================================================

local classWidgets = {}
local function addClassWidget(classKey, widget)
  if not widget then return end
  classWidgets[classKey] = classWidgets[classKey] or {}
  table.insert(classWidgets[classKey], widget)
end

local function classMatches(classKey, vocation)
  if classKey == vocation then return true end
  if classKey == "mage" and (vocation == "sorcerer" or vocation == "druid") then return true end
  return false
end

local function refreshClassSettingsVisibility()
  local vocation = normalizeVocationName(aoeText("forceVocation", "knight"))
  for classKey, widgets in pairs(classWidgets) do
    local visible = classMatches(classKey, vocation)
    for _, widget in ipairs(widgets) do
      if widget then
        pcall(function()
          if visible then widget:show() else widget:hide() end
        end)
      end
    end
  end
end

local aoeWindow = nil
local refreshModeIconVisuals = function() end
local refreshVocationControls = function() end

local function getLocalPlayerNameSafe()
  if player and player.getName then
    local ok, name = pcall(function() return player:getName() end)
    if ok and name then return tostring(name or "") end
  end
  if g_game and type(g_game.getLocalPlayer) == "function" then
    local ok, localPlayer = pcall(function() return g_game.getLocalPlayer() end)
    if ok and localPlayer and localPlayer.getName then
      local okName, name = pcall(function() return localPlayer:getName() end)
      if okName and name then return tostring(name or "") end
    end
  end
  return ""
end

local function getLocalPlayerObject()
  if player then return player end
  if g_game and type(g_game.getLocalPlayer) == "function" then
    local ok, localPlayer = pcall(function() return g_game.getLocalPlayer() end)
    if ok and localPlayer then return localPlayer end
  end
  return nil
end

local function callVocationMethod(object, methodName)
  if not object or type(object[methodName]) ~= "function" then return nil end
  local ok, value = pcall(function() return object[methodName](object) end)
  if ok then return vocationKeyFromValue(value) end
  return nil
end

local function readLocalPlayerVocation()
  local localPlayer = getLocalPlayerObject()
  local methods = {
    "getVocation",
    "getVocationId",
    "getProfession",
    "getProfessionId",
    "getClass",
    "getClassId"
  }

  for _, methodName in ipairs(methods) do
    local vocation = callVocationMethod(localPlayer, methodName)
    if vocation then return vocation end
  end

  if type(getVocation) == "function" then
    local ok, value = pcall(function() return getVocation() end)
    local vocation = ok and vocationKeyFromValue(value) or nil
    if vocation then return vocation end
  end

  if type(vocation) == "function" then
    local ok, value = pcall(function() return vocation() end)
    local detected = ok and vocationKeyFromValue(value) or nil
    if detected then return detected end
  end

  return nil
end

local function currentDetectedVocation()
  local detected = vocationKeyFromValue(aoeSettings.detectedVocation)
  if not detected then return nil end

  local savedPlayer = tostring(aoeSettings.detectedVocationPlayer or "")
  local currentPlayer = getLocalPlayerNameSafe()
  if savedPlayer ~= "" and currentPlayer == "" then
    return nil
  end
  if savedPlayer ~= "" and currentPlayer ~= "" and savedPlayer ~= currentPlayer then
    return nil
  end

  return detected
end

local function getActiveVocation()
  local detected = currentDetectedVocation()
  if aoeSettings.autoDetectVocation ~= false and detected then
    aoeSettings.forceVocation = detected
  end
  aoeSettings.forceVocation = normalizeVocationName(aoeSettings.forceVocation)
  return aoeSettings.forceVocation
end

local function applyDetectedVocation(vocation, source)
  vocation = vocationKeyFromValue(vocation)
  if not vocation then return false end

  local oldDetected = vocationKeyFromValue(aoeSettings.detectedVocation)
  local oldActive = normalizeVocationName(aoeSettings.forceVocation)
  local playerName = getLocalPlayerNameSafe()

  aoeSettings.detectedVocation = vocation
  if playerName ~= "" then aoeSettings.detectedVocationPlayer = playerName end
  aoeSettings.detectedVocationSource = tostring(source or "auto")

  if aoeSettings.autoDetectVocation ~= false then
    aoeSettings.forceVocation = vocation
  end

  pcall(refreshClassSettingsVisibility)
  pcall(refreshVocationControls)
  pcall(refreshModeIconVisuals)

  if oldDetected ~= vocation or oldActive ~= normalizeVocationName(aoeSettings.forceVocation) then
    debugWarn("Vocacao detectada por " .. tostring(source or "auto") .. ": " .. formatVocationLabel(vocation))
    return true
  end

  return false
end

local function detectVocationFromText(text)
  local raw = tostring(text or "")
  if raw == "" then return nil end

  local lower = raw:lower()
  if not lower:find("%[vocation%]") and not lower:find("vocacao", 1, true) then
    return nil
  end

  local id, label = raw:match("%[[Vv][Oo][Cc][Aa][Tt][Ii][Oo][Nn]%]%s*(%d+)%s*|%s*([^%[%]\r\n]+)")
  local vocation = vocationKeyFromValue(id) or vocationKeyFromValue(label)
  if vocation then return vocation end

  if lower:find("master sorcerer", 1, true) or lower:find("sorcerer", 1, true) then return "sorcerer" end
  if lower:find("elder druid", 1, true) or lower:find("druid", 1, true) then return "druid" end
  if lower:find("royal paladin", 1, true) or lower:find("paladin", 1, true) then return "paladin" end
  if lower:find("elite knight", 1, true) or lower:find("knight", 1, true) then return "knight" end

  return nil
end

local function handleVocationDetectionText(text)
  local detected = detectVocationFromText(text)
  if not detected then return false end
  applyDetectedVocation(detected, "login")
  return true
end

local function probeLocalPlayerVocation(source)
  if aoeSettings.autoDetectVocation == false then return false end
  local detected = readLocalPlayerVocation()
  if not detected then return false end
  return applyDetectedVocation(detected, source or "player")
end

function HolidayAOE.detectVocationNow()
  return probeLocalPlayerVocation("manual")
end

local function cloneHolidayCoachTable(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local copy = {}
  seen[value] = copy
  for k, v in pairs(value) do
    copy[cloneHolidayCoachTable(k, seen)] = cloneHolidayCoachTable(v, seen)
  end
  return copy
end

function HolidayAOE.getCoachSnapshot()
  return cloneHolidayCoachTable(aoeSettings)
end

function HolidayAOE.applyCoachSnapshot(data)
  if type(data) ~= "table" then return false end
  for k in pairs(aoeSettings) do
    aoeSettings[k] = nil
  end
  for k, v in pairs(cloneHolidayCoachTable(data)) do
    aoeSettings[k] = v
  end
  ensureSkillProfiles()
  aoeSettings.forceVocation = normalizeVocationName(aoeSettings.forceVocation)
  aoeSettings.combatMode = normalizeCombatMode(aoeSettings.combatMode)
  aoeSettings.detectedVocation = vocationKeyFromValue(aoeSettings.detectedVocation) or ""
  aoeSettings.detectedVocationPlayer = tostring(aoeSettings.detectedVocationPlayer or "")
  aoeSettings.autoDetectVocation = aoeSettings.autoDetectVocation ~= false
  pcall(refreshClassSettingsVisibility)
  pcall(refreshVocationControls)
  pcall(refreshModeIconVisuals)
  return true
end

function HolidayAOE.setCoachValue(key, value)
  if not key then return false end
  aoeSettings[key] = value
  ensureSkillProfiles()
  if key == "forceVocation" then
    aoeSettings.forceVocation = normalizeVocationName(aoeSettings.forceVocation)
  elseif key == "detectedVocation" then
    aoeSettings.detectedVocation = vocationKeyFromValue(aoeSettings.detectedVocation) or ""
  end
  pcall(refreshClassSettingsVisibility)
  pcall(refreshVocationControls)
  pcall(refreshModeIconVisuals)
  return true
end

function HolidayAOE.getCoachValue(key)
  if not key then return nil end
  return aoeSettings[key]
end

function HolidayAOE.getCoachSummary()
  return {
    version = HOLIDAY_AOE_SCRIPT_VERSION,
    autoUpdateEnabled = aoeSettings.autoUpdateEnabled == true,
    lastRemoteScriptVersion = tonumber(aoeSettings.lastRemoteScriptVersion) or 0,
    vocation = getActiveVocation(),
    autoDetectVocation = aoeSettings.autoDetectVocation ~= false,
    detectedVocation = currentDetectedVocation() or "",
    combatMode = normalizeCombatMode(aoeSettings.combatMode),
    enablePveMode = aoeSettings.enablePveMode == true,
    enablePvpMode = aoeSettings.enablePvpMode == true,
    pveSafeMode = aoeSettings.pveSafeMode == true,
    mainLoopMs = tonumber(aoeSettings.mainLoopMs) or 100,
    scanIntervalMs = tonumber(aoeSettings.scanIntervalMs) or 150,
    minWaveMobs = tonumber(aoeSettings.minWaveMobs) or 1,
    minAreaMsEd = tonumber(aoeSettings.minAreaMsEd) or 1,
    minAreaRp = tonumber(aoeSettings.minAreaRp) or 3,
    minEkGran = tonumber(aoeSettings.minEkGran) or 2
  }
end

local okWindow = pcall(function()
  aoeWindow = UI.createWindow('HolidayAoeV2Window', rootWidget)
end)

if okWindow and aoeWindow then
  aoeWindow:hide()

  aoeWindow.closeButton.onClick = function(widget)
    aoeWindow:hide()
  end

  aoeWindow.onGeometryChange = function(widget, old, new)
    if old.height == 0 then return end
    aoeSettings.height = new.height
  end

  local savedWindowHeight = tonumber(aoeSettings.height) or 650
  if savedWindowHeight < 650 then savedWindowHeight = 650 end
  aoeSettings.height = savedWindowHeight
  aoeWindow:setHeight(savedWindowHeight)

  local leftPanel = aoeWindow.content.left
  local rightPanel = aoeWindow.content.right

  local function addLabel(text, dest, tooltip)
    local widget = UI.createWidget('HolidayAoeV2VocationLabel', dest)
    widget:setText(text)
    widget:setTooltip(tooltip or "")
    return widget
  end

  local function addSection(text, dest, tooltip)
    local widget = UI.createWidget('HolidayAoeV2Section', dest)
    widget:setText(text)
    widget:setTooltip(tooltip or "")
    return widget
  end

  local function addCheckBox(id, title, defaultValue, dest, tooltip)
    local widget = UI.createWidget('HolidayAoeV2CheckBox', dest)
    widget.onClick = function()
      widget:setOn(not widget:isOn())
      aoeSettings[id] = widget:isOn()
      focusGameMapSoon()
    end
    widget:setText(title)
    widget:setTooltip(tooltip or "")
    if aoeSettings[id] == nil then
      widget:setOn(defaultValue)
    else
      widget:setOn(aoeSettings[id])
    end
    aoeSettings[id] = widget:isOn()
    return widget
  end

  local function addScrollBar(id, title, min, max, defaultValue, dest, tooltip)
    local widget = UI.createWidget('HolidayAoeV2ScrollBar', dest)
    widget.text:setTooltip(tooltip or "")
    widget.scroll:setTooltip(tooltip or "")
    widget.scroll:setRange(min, max)
    if max - min > 1000 then
      widget.scroll:setStep(100)
    elseif max - min > 100 then
      widget.scroll:setStep(10)
    else
      widget.scroll:setStep(1)
    end
    widget.scroll.onValueChange = function(scroll, value)
      widget.text:setText(title .. ": " .. value)
      aoeSettings[id] = value
    end
    local savedValue = tonumber(aoeSettings[id] or defaultValue) or defaultValue
    savedValue = math.min(max, math.max(min, savedValue))
    widget.scroll:setValue(savedValue)
    widget.scroll.onValueChange(widget.scroll, widget.scroll:getValue())
    return widget
  end

  local function addFallbackTextEdit(id, title, defaultValue, dest, tooltip)
    local widget = UI.createWidget('HolidayAoeV2TextEdit', dest)
    widget.text:setText(title)
    widget.text:setTooltip(tooltip or "")
    widget.textEdit:setText(tostring(aoeSettings[id] or defaultValue or ""))
    widget.textEdit.onTextChange = function(widget, text)
      local n = tonumber(text)
      if n and n > 0 then aoeSettings[id] = n end
    end
    aoeSettings[id] = aoeSettings[id] or defaultValue or ""
    return widget
  end

  local function addItemSelector(id, title, defaultValue, dest, tooltip)
    local okBox, box = pcall(function()
      return UI.createWidget('HolidayAoeV2ItemBox', dest)
    end)

    local itemWidget = okBox and box and (box.item or (box.slot and box.slot.item)) or nil
    local idLabel = box and (box.idLabel or (box.slot and box.slot.idLabel)) or nil
    local hintLabel = box and (box.hint or (box.slot and box.slot.hint)) or nil

    if okBox and box and itemWidget then
      if box.title then box.title:setText(title) end
      if idLabel then idLabel:setText("ID: " .. tostring(aoeGet(id, defaultValue))) end
      if hintLabel then hintLabel:setText("Arraste o item aqui") end
      pcall(function() box:setTooltip(tooltip or "Arraste o item para este campo.") end)
      pcall(function() itemWidget:setTooltip(tooltip or "Arraste o item para este campo.") end)
      pcall(function() itemWidget:setItemId(aoeGet(id, defaultValue)) end)

      itemWidget.onItemChange = function(widget, itemId)
        local newId = itemId
        if widget and widget.getItemId then
          local ok, value = pcall(function() return widget:getItemId() end)
          if ok and value then newId = value end
        end
        if type(newId) == "table" and newId.getId then
          local ok, value = pcall(function() return newId:getId() end)
          if ok and value then newId = value end
        end
        newId = tonumber(newId)
        if newId and newId > 0 then
          aoeSettings[id] = newId
          if idLabel then idLabel:setText("ID: " .. tostring(newId)) end
          if warn then warn(tostring(title) .. " definido: " .. tostring(newId)) end
        end
      end

      return box
    end

    -- Fallback seguro: se o BotItem nao existir no client, ainda da para informar o ID.
    return addFallbackTextEdit(id, "ID " .. title, defaultValue, dest, tooltip)
  end

  local function addClassCheckBox(classKey, id, title, defaultValue, dest, tooltip)
    local widget = addCheckBox(id, title, defaultValue, dest, tooltip)
    addClassWidget(classKey, widget)
    return widget
  end

  local function addClassScrollBar(classKey, id, title, min, max, defaultValue, dest, tooltip)
    local widget = addScrollBar(id, title, min, max, defaultValue, dest, tooltip)
    addClassWidget(classKey, widget)
    return widget
  end

  local function addClassLabel(classKey, text, dest, tooltip)
    local widget = addLabel(text, dest, tooltip)
    addClassWidget(classKey, widget)
    return widget
  end

  local function addVocList(dest)
    local title = addLabel("Vocacao", dest, "Auto detecta a vocacao no login. Os botoes manuais desligam o Auto.")
    local autoBox = addCheckBox("autoDetectVocation", "AUTO VOC", true, dest, "Usa a vocacao detectada pelo servidor/player no login.")
    local detectedLabel = addLabel("Detectada: -", dest, "Ultima vocacao detectada para o personagem atual.")

    local options = {
      { key = "knight",   label = "EK - Knight" },
      { key = "paladin",  label = "RP - Paladin" },
      { key = "sorcerer", label = "MS - Sorcerer" },
      { key = "druid",    label = "ED - Druid" }
    }

    local buttons = {}

    local function refreshVocButtons()
      local current = getActiveVocation()
      local detected = currentDetectedVocation()
      if autoBox and autoBox.setOn then
        autoBox:setOn(aoeSettings.autoDetectVocation ~= false)
      end
      if title and title.setText then
        title:setText("Vocacao: " .. formatVocationLabel(current))
      end
      if detectedLabel and detectedLabel.setText then
        detectedLabel:setText("Detectada: " .. (detected and formatVocationLabel(detected) or "-"))
      end
      for _, item in ipairs(buttons) do
        local prefix = "[ ] "
        if item.key == current then prefix = "[X] " end
        item.widget:setText(prefix .. item.label)
      end
      refreshClassSettingsVisibility()
    end

    autoBox.onClick = function(widget)
      local enabled = not widget:isOn()
      widget:setOn(enabled)
      aoeSettings.autoDetectVocation = enabled
      if enabled then probeLocalPlayerVocation("ui") end
      refreshVocButtons()
      focusGameMapSoon()
    end

    for _, opt in ipairs(options) do
      local button = UI.createWidget('HolidayAoeV2VocButton', dest)
      button:setTooltip("Selecionar " .. opt.label)
      button.onClick = function(widget)
        aoeSettings.forceVocation = opt.key
        aoeSettings.autoDetectVocation = false
        refreshVocButtons()
        if warn then warn("Vocacao selecionada: " .. opt.label) end
        focusGameMapSoon()
      end
      table.insert(buttons, { widget = button, key = opt.key, label = opt.label })
    end

    refreshVocationControls = refreshVocButtons
    refreshVocButtons()
  end

  local function openHolidayWindow()
    aoeWindow:show()
    aoeWindow:raise()
    refreshClassSettingsVisibility()
    focusGameMapSoon()
  end

  local okLauncher, launcher = pcall(function()
    return setupUI([[
Panel
  height: 48
  image-source: /images/ui/panel_flat
  image-border: 5
  padding: 4

  Button
    id: setup
    anchors.top: parent.top
    anchors.right: parent.right
    width: 62
    height: 40
    text-align: center
    text: Abrir

  Label
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: setup.left
    margin-right: 5
    height: 16
    text-align: center
    color: #47f4ff
    font: verdana-11px-bold
    text: Holiday AoE V19.1

  Label
    id: subtitle
    anchors.top: title.bottom
    anchors.left: parent.left
    anchors.right: setup.left
    margin-top: 2
    margin-right: 5
    height: 14
    text-align: center
    color: #dce4ee
    font: verdana-11px
    text: SAFE / COMBO / Aura
]])
  end)
  if okLauncher and launcher and launcher.setup then
    launcher.setup.onClick = openHolidayWindow
    if launcher.title then launcher.title.onClick = openHolidayWindow end
    if launcher.subtitle then launcher.subtitle.onClick = openHolidayWindow end
  else
    UI.Button("Holiday AoE V19.1", openHolidayWindow)
  end
  UI.Separator()

  -- Coluna esquerda: geral/aura/modo.
  addSection("VOCACAO", leftPanel)
  addVocList(leftPanel)

  addSection("ITEM AURA", leftPanel)
  addCheckBox("enableAura", "Aura Ativa", true, leftPanel, "Usa o item configurado no HP definido.")
  addItemSelector("auraItemId", "Item Aura", 5571, leftPanel, "Arraste o item da aura. O ID fica salvo no storage.")
  addScrollBar("auraHp", "HP Aura", 1, 100, 25, leftPanel, "HP para usar o item de aura.")
  addScrollBar("auraCooldownSec", "CD Aura (s)", 1, 600, 120, leftPanel, "Cooldown geral da aura. Tambem da para editar pelo botao direito no icone da aura.")

  addSection("SAFE / COMBO", leftPanel)
  local safeCheck = addCheckBox("pveSafeMode", "SAFE Area", true, leftPanel, "Bloqueia wave/area com player na tela. No COMBO, single target continua.")
  local oldSafeClick = safeCheck.onClick
  safeCheck.onClick = function(widget)
    if oldSafeClick then oldSafeClick(widget) end
    refreshModeIconVisuals()
  end
  local comboCheck = addCheckBox("enableComboMode", "COMBO A/B/C", false, leftPanel, "Tenta categorias A, B e C em sequencia.")
  local oldComboClick = comboCheck.onClick
  comboCheck.onClick = function(widget)
    if oldComboClick then oldComboClick(widget) end
    refreshModeIconVisuals()
  end

  addSection("E-RING", leftPanel)
  addCheckBox("enableEnergyRing", "E-ring Ativo", false, leftPanel, "Equipa energy ring no HP/MP configurado.")
  addItemSelector("energyRingItemId", "Energy Ring", 3051, leftPanel, "ID do energy ring na backpack.")
  addItemSelector("energyRingActiveId", "Ring Equipado", 3088, leftPanel, "ID do energy ring quando esta equipado.")
  addScrollBar("energyRingHp", "HP E-ring", 1, 100, 70, leftPanel, "HP para equipar energy ring.")
  addScrollBar("energyRingMp", "MP Min E-ring", 1, 100, 70, leftPanel, "Mana minima para equipar energy ring.")

  addSection("GERAL", leftPanel)
  addCheckBox("enableDefense", "Usar Defesas", true, leftPanel, "MS/ED utamo vita/exana vita; EK utamo tempo.")
  addCheckBox("enableBuff", "Usar Buffs", true, leftPanel, "RP/EK renovam utito apenas com target.")
  addCheckBox("enableSummon", "Renovar Summon", false, leftPanel, "Renova summon quando ele sumir da tela.")
  addCheckBox("enableCooldownIcons", "Cooldowns flutuantes", true, leftPanel, "Mostra cada magia usada em uma caixinha flutuante. Segure Ctrl para arrastar.")
  addScrollBar("mainLoopMs", "Loop Combate", 75, 300, 100, leftPanel, "Intervalo real do Holiday AoE. Maior = CaveBot mais fluido.")
  addScrollBar("scanIntervalMs", "Scan em combate", 100, 500, 150, leftPanel, "Intervalo para varrer criaturas quando existe target.")
  addScrollBar("idleScanIntervalMs", "Scan sem target", 150, 800, 300, leftPanel, "Intervalo para varrer criaturas quando nao existe target.")
  addScrollBar("turnThrottleMs", "Trava giro wave", 75, 500, 150, leftPanel, "Limita viradas da wave para nao brigar com caminhada.")
  addScrollBar("attackLeadMs", "Insistir antes CD", 0, 1000, 500, leftPanel, "Comeca a tentar magia de ataque antes do cooldown real terminar. Nao altera o cooldown real.")
  addScrollBar("attackPostMs", "Pos-check CD", 0, 1000, 500, leftPanel, "Continua tentando por uma janela depois do cooldown previsto antes de abrir o proximo cooldown.")
  addScrollBar("manaFailCheckMs", "Check falta mana", 100, 1000, 500, leftPanel, "Espera mensagem de falta de mana antes de confirmar cooldown da magia.")
  addCheckBox("autoUpdateEnabled", "Auto Update", true, leftPanel, "Checa o GitHub e atualiza o holiday_aoe.lua quando houver versao nova.")
  addCheckBox("autoReloadAfterUpdate", "Reload apos update", false, leftPanel, "Recarrega o bot automaticamente depois de baixar update.")
  local updateButton = UI.createWidget('HolidayAoeV2VocButton', leftPanel)
  updateButton:setText("Checar Update")
  updateButton:setTooltip("Forca uma checagem de update do Holiday AoE.")
  updateButton.onClick = function()
    if HolidayAOE and HolidayAOE.checkUpdateNow then
      HolidayAOE.checkUpdateNow()
    end
    focusGameMapSoon(100)
  end
  addCheckBox("enableDebug", "Debug", false, leftPanel, "Mostra logs de decisao.")

  -- Coluna direita: ajustes finos que nao dependem do perfil PVE/PVP.
  addSection("CLASSE ATIVA", rightPanel, "As skills ofensivas ficam no botao direito dos icons PVE/PVP.")

  addClassLabel("mage", "MS / ED", rightPanel, "Configuracoes compartilhadas para sorcerer/druid.")
  addClassScrollBar("mage", "minWaveMobs", "Mobs Wave", 1, 10, 1, rightPanel, "Minimo de mobs na wave 3x5.")
  addClassScrollBar("mage", "minAreaMsEd", "Mobs Area", 1, 20, 1, rightPanel, "Minimo para gran mas vis/tera no PvE.")
  addClassScrollBar("mage", "utamoHpOn", "HP Liga Utamo", 1, 100, 45, rightPanel, "MS/ED liga utamo vita.")
  addClassScrollBar("mage", "utamoHpOff", "HP Remove Utamo", 1, 100, 60, rightPanel, "MS/ED remove utamo vita.")

  addClassLabel("paladin", "RP", rightPanel, "Configuracoes do Royal Paladin.")
  addClassScrollBar("paladin", "minAreaRp", "Mobs Mas San", 1, 20, 3, rightPanel, "Minimo para exevo mas san no PvE.")
  addClassScrollBar("paladin", "rpUtitoRenewMs", "Renovar Utito", 1000, 30000, 10000, rightPanel, "Renova utito tempo san.")

  addClassLabel("knight", "EK", rightPanel, "Configuracoes do Elite Knight.")
  addClassScrollBar("knight", "minEkGran", "Mobs Gran", 1, 8, 2, rightPanel, "Mobs colados para exori gran no PvE.")
  addClassScrollBar("knight", "ekUtitoRenewMs", "Renovar Utito", 1000, 30000, 10000, rightPanel, "Renova utito tempo.")
  addClassScrollBar("knight", "knightUtamoHp", "HP Utamo EK", 1, 100, 45, rightPanel, "EK usa utamo tempo.")

  refreshClassSettingsVisibility()
else
  UI.Button("Holiday AoE V19.1: OTUI faltando", function()
    warn("Coloque o arquivo .otui na mesma pasta do script.")
  end)
  UI.Separator()
end

-- ============================================================
-- 2.1) ICONES PVE/PVP E CONFIG DE SKILLS
-- ============================================================

if type(aoeSettings.modeIconPositions) ~= "table" then
  aoeSettings.modeIconPositions = {}
end

local profileConfigWindow = nil
local profileConfigMode = "pve"
local profileConfigVocation = normalizeVocationName(aoeSettings.forceVocation or "knight")
local modeIcons = {}

local function vocLabel(vocation)
  if vocation == "sorcerer" then return "MS" end
  if vocation == "druid" then return "ED" end
  if vocation == "paladin" then return "RP" end
  return "EK"
end

local function clearProfileSkillList(window)
  if not window or not window.skillList or not window.skillList.getChildren then return end
  for _, child in pairs(window.skillList:getChildren()) do
    child:destroy()
  end
end

local function renderProfileConfigWindow()
  local window = profileConfigWindow
  if not window then return end

  local mode = profileConfigMode == "pvp" and "pvp" or "pve"
  local vocation = normalizeVocationName(profileConfigVocation)
  profileConfigVocation = vocation

  window.title:setText(string.upper(mode) .. " " .. vocLabel(vocation))

  local vocButtons = {
    { key = "sorcerer", widget = window.msButton },
    { key = "druid", widget = window.edButton },
    { key = "paladin", widget = window.rpButton },
    { key = "knight", widget = window.ekButton }
  }

  for _, item in ipairs(vocButtons) do
    local prefix = item.key == vocation and "[X] " or "[ ] "
    item.widget:setText(prefix .. vocLabel(item.key))
  end

  pcall(function()
    window.safeBox:setVisible(mode == "pve")
    window.safeBox:setOn(aoeSettings.pveSafeMode == true)
  end)

  clearProfileSkillList(window)

  for _, skill in ipairs(profileSkills[vocation] or {}) do
    if profileSkillAllowedInMode(skill, mode) then
      local row = UI.createWidget("HolidayAoeV2CheckBox", window.skillList)
      row:setText(skill.label)
      row:setTooltip((mode == "pvp" and "PvP skill" or "PvE skill") .. " - " .. skill.label)
      row:setOn(skill.locked == true or profileSkillOn(mode, vocation, skill.action, false))
      row.onClick = function(widget)
        if skill.locked == true then
          widget:setOn(true)
          setProfileSkill(mode, vocation, skill.action, true)
          return
        end
        local newValue = not widget:isOn()
        widget:setOn(newValue)
        setProfileSkill(mode, vocation, skill.action, newValue)
      end
    end
  end
end

local function ensureProfileConfigWindow()
  if profileConfigWindow then return profileConfigWindow end
  if not setupUI or not g_ui or not g_ui.getRootWidget then return nil end

  local ok, window = pcall(function()
    return setupUI([[
MainWindow
  text: Skills Holiday
  size: 310 365
  @onEscape: self:hide()

  Label
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 20
    text-align: center
    color: #f7d774
    font: verdana-11px-bold
    text: PVE

  Button
    id: msButton
    anchors.top: title.bottom
    anchors.left: parent.left
    margin-top: 8
    width: 65
    height: 21
    text: MS

  Button
    id: edButton
    anchors.top: msButton.top
    anchors.left: msButton.right
    margin-left: 6
    width: 65
    height: 21
    text: ED

  Button
    id: rpButton
    anchors.top: msButton.top
    anchors.left: edButton.right
    margin-left: 6
    width: 65
    height: 21
    text: RP

  Button
    id: ekButton
    anchors.top: msButton.top
    anchors.left: rpButton.right
    margin-left: 6
    width: 65
    height: 21
    text: EK

  BotSwitch
    id: safeBox
    anchors.top: msButton.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 8
    height: 20
    text: SAFE Area

  ScrollablePanel
    id: skillList
    anchors.top: safeBox.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: closeButton.top
    margin-top: 8
    margin-bottom: 8
    padding: 4
    image-source: /images/ui/menubox
    image-border: 4
    image-border-top: 17
    vertical-scrollbar: skillScroll
    layout:
      type: verticalBox

  VerticalScrollBar
    id: skillScroll
    anchors.top: skillList.top
    anchors.bottom: skillList.bottom
    anchors.right: skillList.right
    margin-right: 3

  Button
    id: closeButton
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    width: 70
    height: 22
    text: Fechar
]], g_ui.getRootWidget())
  end)

  if not ok or not window then return nil end

  window:hide()
  window.closeButton.onClick = function()
    window:hide()
    focusGameMapSoon()
  end
  window.safeBox.onClick = function(widget)
    local newValue = not widget:isOn()
    widget:setOn(newValue)
    aoeSettings.pveSafeMode = newValue
    updateModeIconVisual("safe")
    focusGameMapSoon()
  end

  local function bindVoc(button, vocation)
    button.onClick = function()
      profileConfigVocation = vocation
      aoeSettings.forceVocation = vocation
      aoeSettings.autoDetectVocation = false
      refreshClassSettingsVisibility()
      pcall(refreshVocationControls)
      renderProfileConfigWindow()
      focusGameMapSoon()
    end
  end

  bindVoc(window.msButton, "sorcerer")
  bindVoc(window.edButton, "druid")
  bindVoc(window.rpButton, "paladin")
  bindVoc(window.ekButton, "knight")

  profileConfigWindow = window
  return profileConfigWindow
end

local function showProfileConfig(mode)
  local window = ensureProfileConfigWindow()
  if not window then return end
  profileConfigMode = mode == "pvp" and "pvp" or "pve"
  profileConfigVocation = normalizeVocationName(aoeSettings.forceVocation or profileConfigVocation)
  renderProfileConfigWindow()
  window:show()
  window:raise()
  focusGameMapSoon()
end

local function updateModeIconVisual(key)
  local icon = modeIcons[key]
  if not icon then return end

  local settingsKey = "enablePveMode"
  if key == "pvp" then
    settingsKey = "enablePvpMode"
  elseif key == "combo" then
    settingsKey = "enableComboMode"
  elseif key == "safe" then
    settingsKey = "pveSafeMode"
  end

  local enabled = aoeSettings[settingsKey] == true
  local color = enabled and "#7dff8a" or "#ff6b6b"
  local bg = enabled and "#132018dd" or "#221111dd"
  local text = key == "safe" and "SAFE" or (key == "combo" and "COMBO" or string.upper(key))

  if icon.setBackgroundColor then
    pcall(function() icon:setBackgroundColor(bg) end)
  end
  if icon.label then
    icon.label:setText(text)
    if icon.label.setColor then icon.label:setColor(color) end
  elseif icon.setText then
    pcall(function() icon:setText(text) end)
    if icon.setColor then pcall(function() icon:setColor(color) end) end
  end
end

refreshModeIconVisuals = function()
  updateModeIconVisual("pve")
  updateModeIconVisual("pvp")
  updateModeIconVisual("safe")
  updateModeIconVisual("combo")
end

local function attachModeIconDrag(icon, key)
  if not icon then return end

  icon.onDragEnter = function(widget, mousePos)
    widget:breakAnchors()
    widget.movingReference = { x = mousePos.x - widget:getX(), y = mousePos.y - widget:getY() }
    return true
  end

  icon.onDragMove = function(widget, mousePos, moved)
    local parent = widget:getParent()
    if not parent then return false end
    local parentRect = parent:getRect()
    local x = math.min(math.max(parentRect.x, mousePos.x - widget.movingReference.x), parentRect.x + parentRect.width - widget:getWidth())
    local y = math.min(math.max(parentRect.y, mousePos.y - widget.movingReference.y), parentRect.y + parentRect.height - widget:getHeight())
    widget:move(x, y)
    return true
  end

  icon.onDragLeave = function(widget, posInfo)
    aoeSettings.modeIconPositions[key] = { x = widget:getX(), y = widget:getY() }
    return true
  end
end

local function placeModeIcon(icon, key, x, y)
  if not icon then return end
  local pos = aoeSettings.modeIconPositions[key] or { x = x, y = y }
  local parent = icon.getParent and icon:getParent() or nil
  if parent and parent.getRect then
    local okRect, rect = pcall(function() return parent:getRect() end)
    if okRect and rect then
      local px, py = tonumber(pos.x), tonumber(pos.y)
      if not px or not py or px < rect.x or py < rect.y or px > rect.x + rect.width - 20 or py > rect.y + rect.height - 20 then
        pos = { x = x, y = y }
        aoeSettings.modeIconPositions[key] = pos
      end
    end
  end
  pcall(function() icon:breakAnchors() end)
  pcall(function() icon:move(pos.x, pos.y) end)
end

local function createModeIcon(key, title, itemId, settingsKey, x, y, options)
  local icon = nil
  options = options or {}
  local opensProfile = options.opensProfile ~= false
  local profileMode = options.profileMode or key
  local changesCombatMode = options.changesCombatMode ~= false

  if setupUI and g_ui and g_ui.getRootWidget then
    local ok, widget = pcall(function()
      return setupUI([[
Panel
  background-color: #111111dd
  opacity: 0.9
  padding: 1
  height: 34
  width: 72
  focusable: true
  phantom: false
  draggable: true

  BotItem
    id: icon
    anchors.left: parent.left
    anchors.top: parent.top
    size: 32 32
    phantom: true

  Label
    id: label
    anchors.left: icon.right
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    margin-left: 3
    height: 18
    text-align: center
    font: verdana-11px-rounded
]], g_ui.getRootWidget())
    end)
    if ok then
      icon = widget
      if icon.icon and icon.icon.setItemId then pcall(function() icon.icon:setItemId(itemId) end) end
      if icon.label then icon.label:setText(title) end
      icon.onMouseRelease = function(widget, mousePos, button)
        if button == 2 and opensProfile then
          showProfileConfig(profileMode)
          return true
        end
        aoeSettings[settingsKey] = not aoeSettings[settingsKey]
        if changesCombatMode then aoeSettings.combatMode = key end
        updateModeIconVisual(key)
        return true
      end
      if icon.icon then
        icon.icon.onMouseRelease = icon.onMouseRelease
      end
    end
  elseif type(addIcon) == "function" then
    local modeMacro = macro(250, "Holiday " .. title, function() end)
    if aoeSettings[settingsKey] == true then
      modeMacro.setOn()
    else
      modeMacro.setOff()
    end

    icon = addIcon("Holiday" .. title, { item = itemId, text = title }, modeMacro)
    local oldRelease = icon and icon.onMouseRelease
    if icon then
      icon.onMouseRelease = function(widget, mousePos, button)
        if button == 2 and opensProfile then
          showProfileConfig(profileMode)
          return true
        end
        if oldRelease then oldRelease(widget, mousePos, button) end
        if modeMacro.isOn then
          aoeSettings[settingsKey] = modeMacro:isOn()
        else
          aoeSettings[settingsKey] = not aoeSettings[settingsKey]
        end
        if changesCombatMode then aoeSettings.combatMode = key end
        updateModeIconVisual(key)
        return true
      end
    end
  end

  if not icon then return nil end

  pcall(function() icon:setTooltip(options.tooltip or (title .. " | botao direito: skills")) end)
  local oldRelease = icon.onMouseRelease
  icon.onMouseRelease = function(widget, mousePos, button)
    if button == 2 and opensProfile then
      showProfileConfig(profileMode)
      return true
    end
    local handled = false
    if oldRelease then
      handled = oldRelease(widget, mousePos, button) == true
    end
    focusGameMapSoon()
    return handled
  end
  attachModeIconDrag(icon, key)
  placeModeIcon(icon, key, x, y)
  modeIcons[key] = icon
  pcall(function() icon:show() end)
  updateModeIconVisual(key)
  return icon
end

createModeIcon("pve", "PVE", 5808, "enablePveMode", 40, 400)
createModeIcon("pvp", "PVP", 10159, "enablePvpMode", 40, 450)
createModeIcon("safe", "SAFE", 3420, "pveSafeMode", 40, 500, {
  changesCombatMode = false,
  profileMode = "pve",
  tooltip = "SAFE | bloqueia wave/area com player na tela | botao direito: skills PVE"
})
createModeIcon("combo", "COMBO", 3155, "enableComboMode", 40, 550, {
  changesCombatMode = false,
  opensProfile = false,
  tooltip = "COMBO | usa categorias A/B/C em sequencia e respeita SAFE"
})

-- ============================================================
-- 3) FUNCOES COMPARTILHADAS
-- ============================================================

local SUMMON_IGNORE = {
  ["thundergiant"] = true,
  ["grovebeast"] = true,
  ["emberwing"] = true,
  ["skullfrost"] = true
}

local SUMMON_CONFIG = {
  sorcerer = { spell = "utevo sorcerer res", keywords = {"thundergiant"} },
  druid    = { spell = "utevo druid res",    keywords = {"grovebeast"} },
  paladin  = { spell = "utevo paladin res",  keywords = {"emberwing"} },
  knight   = { spell = "utevo knight res",   keywords = {"skullfrost"} }
}

local function isOnline()
  return g_game and g_game.isOnline and g_game.isOnline()
end

local function getPlayerPos()
  return player and player.getPosition and player:getPosition() or nil
end

local function safePos(c)
  if not c or not c.getPosition then return nil end
  local p = c:getPosition()
  if not p or p.x == nil or p.y == nil or p.z == nil then return nil end
  return p
end

local function creatureNameLower(c)
  if not c or not c.getName then return "" end
  local n = c:getName()
  if not n then return "" end
  return n:lower()
end

local function isIgnoredName(n)
  if not n or n == "" then return false end
  for summonName, _ in pairs(SUMMON_IGNORE) do
    if n:find(summonName, 1, true) then return true end
  end
  if type(IGNORE) == "table" and IGNORE[n] == true then return true end
  return false
end

local function isValidMob(c)
  if not c then return false end
  if c.isPlayer then
    local ok, value = pcall(function() return c:isPlayer() end)
    if ok and value == true then return false end
  end
  if c.isNpc then
    local ok, value = pcall(function() return c:isNpc() end)
    if ok and value == true then return false end
  end
  if isIgnoredName(creatureNameLower(c)) then return false end
  if c.isMonster then
    local ok, value = pcall(function() return c:isMonster() end)
    if ok then return value == true end
  end
  return false
end

local function isCreaturePlayer(c)
  if not c or not c.isPlayer then return false end
  local ok, value = pcall(function() return c:isPlayer() end)
  return ok and value == true
end

local function isAliveMob(c)
  if not c then return false end
  if not safePos(c) then return false end
  if c.getHealthPercent then
    local hp = c:getHealthPercent()
    if not hp or hp <= 0 then return false end
  end
  return true
end

local function getAttackTarget()
  if not g_game or not g_game.getAttackingCreature then return nil end
  local target = g_game.getAttackingCreature()
  if target and isAliveMob(target) then return target end
  return nil
end

local function getTargetCreature()
  local t = getAttackTarget()
  if t and isValidMob(t) and isAliveMob(t) and not isIgnoredName(creatureNameLower(t)) then return t end
  return nil
end

local function isSafePartyPlayer(c)
  if not c then return false end
  if c.getName and player and player.getName then
    local okName, name = pcall(function() return c:getName() end)
    local okPlayer, playerName = pcall(function() return player:getName() end)
    if okName and okPlayer and name == playerName then return true end
  end

  return false
end

local function hasUnsafePlayer(specs)
  for _, c in ipairs(specs or {}) do
    if isCreaturePlayer(c) and not isSafePartyPlayer(c) then
      return true
    end
  end
  return false
end

local function getCreatureId(c)
  if c and c.getId then
    local ok, id = pcall(function() return c:getId() end)
    if ok then return id end
  end
  return nil
end

local function getSpectatorsSafe()
  local ok, specs = pcall(function()
    return getSpectators(false)
  end)
  if ok and specs then return specs end
  return {}
end

local function scanMobsAndSummons(specs)
  local mobs = {}
  local summonFound = {
    sorcerer = false,
    druid = false,
    paladin = false,
    knight = false
  }

  for _, c in ipairs(specs or {}) do
    local n = creatureNameLower(c)

    for vocName, config in pairs(SUMMON_CONFIG) do
      for _, keyword in ipairs(config.keywords or {}) do
        if n:find(keyword, 1, true) then
          summonFound[vocName] = true
        end
      end
    end

    if isValidMob(c) and isAliveMob(c) then
      local p = safePos(c)
      if p then
        table.insert(mobs, { creature = c, pos = p, id = getCreatureId(c) })
      end
    end
  end

  return mobs, summonFound
end

local cachedMobs = {}
local cachedSpectators = {}
local cachedSummonFound = {
  sorcerer = false,
  druid = false,
  paladin = false,
  knight = false
}
local nextCreatureScan = 0

local function getCachedMobsAndSummons(tm, hasTarget)
  local interval = hasTarget and aoeGet("scanIntervalMs", 150) or aoeGet("idleScanIntervalMs", 300)
  interval = math.max(75, tonumber(interval) or 150)

  if tm >= nextCreatureScan then
    local specs = getSpectatorsSafe()
    cachedSpectators = specs or {}
    cachedMobs, cachedSummonFound = scanMobsAndSummons(specs)
    nextCreatureScan = tm + interval
  end

  return cachedMobs, cachedSummonFound
end

local nextSafeBlockDebug = 0
local function debugSafeBlock(text)
  local tm = nowMs()
  if tm < nextSafeBlockDebug then return end
  nextSafeBlockDebug = tm + 1500
  debugWarn(text)
end

local function pveSafeAreaBlocked(targetIsPlayer, strictPlayers)
  if aoeSettings.pveSafeMode ~= true then return false end

  if hasUnsafePlayer(cachedSpectators) then
    debugSafeBlock("SAFE: player na tela, segurando area/wave.")
    return true
  end

  return false
end

local function dist(a, b)
  return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y))
end

local function castSpell(text)
  if not text or text == "" then return false end

  -- Prefer TargetBot.saySpell when available, igual ao padrao do vBot HP.
  -- Isso evita conflito com targetbot/cavebot em alguns clients.
  if TargetBot and TargetBot.saySpell then
    local ok, didCast = pcall(function() return TargetBot.saySpell(text) end)
    if ok then return didCast == true end
  end

  if cast then
    local ok = pcall(function() cast(text) end)
    if ok then return true end
  end

  if say then
    local ok = pcall(function() say(text) end)
    if ok then return true end
  end

  return false
end

local function turnTo(dir)
  if g_game and g_game.turn then
    g_game.turn(dir)
  elseif turn then
    turn(dir)
  end
end

local function safeUseItemById(itemId)
  itemId = tonumber(itemId)
  if not itemId or itemId <= 0 then return false end

  if use then
    local ok = pcall(function() use(itemId) end)
    if ok then return true end
  end
  if g_game and g_game.useInventoryItem then
    local ok = pcall(function() g_game.useInventoryItem(itemId) end)
    if ok then return true end
  end
  return false
end

local function safeUseItemObject(item)
  if not item then return false end
  if use then
    local ok = pcall(function() use(item) end)
    if ok then return true end
  end
  if g_game and g_game.use then
    local ok = pcall(function() g_game.use(item) end)
    if ok then return true end
  end
  return false
end

local function getAmmoSlotItem()
  if getAmmo then
    local ok, item = pcall(function() return getAmmo() end)
    if ok and item then return item end
  end

  if getInventoryItem then
    local slot = SlotAmmo or 10
    local ok, item = pcall(function() return getInventoryItem(slot) end)
    if ok and item then return item end
  end

  return nil
end

local function getRingSlotItem()
  if getInventoryItem then
    local slot = SlotFinger or InventorySlotFinger or 9
    local ok, item = pcall(function() return getInventoryItem(slot) end)
    if ok and item then return item end
  end

  return nil
end

local function safeEquipItemId(itemId)
  itemId = tonumber(itemId)
  if not itemId or itemId <= 0 then return false end

  if g_game and g_game.equipItemId then
    local ok = pcall(function() g_game.equipItemId(itemId) end)
    if ok then return true end
  end

  return safeUseItemById(itemId)
end

local function selfHealthPercentSafe()
  if hppercent then
    local ok, hp = pcall(function() return hppercent() end)
    if ok and hp ~= nil then return tonumber(hp) end
  end

  if player and player.getHealthPercent then
    local ok, hp = pcall(function() return player:getHealthPercent() end)
    if ok and hp ~= nil then return tonumber(hp) end
  end

  return nil
end

local function selfManaPercentSafe()
  if manapercent then
    local ok, mana = pcall(function() return manapercent() end)
    if ok and mana ~= nil then return tonumber(mana) end
  end

  if player and player.getManaPercent then
    local ok, mana = pcall(function() return player:getManaPercent() end)
    if ok and mana ~= nil then return tonumber(mana) end
  end

  return nil
end

local function safeUseAuraItem(itemId)
  itemId = tonumber(itemId)

  local ammoItem = getAmmoSlotItem()
  if ammoItem then
    local okId, ammoId = pcall(function() return ammoItem:getId() end)
    if not itemId or itemId <= 0 or (okId and tonumber(ammoId) == itemId) then
      if safeUseItemObject(ammoItem) then return true end
    end
  end

  if not itemId or itemId <= 0 then return false end
  return safeUseItemById(itemId)
end

local function safeUseWithItem(itemId, target)
  if not itemId or not target then return false end
  if useWith then
    local ok = pcall(function() useWith(itemId, target) end)
    if ok then return true end
  end
  if g_game and g_game.useInventoryItemWith then
    local ok = pcall(function() g_game.useInventoryItemWith(itemId, target) end)
    if ok then return true end
  end
  return false
end

local function manaShieldOn(fallback)
  if hasState then return hasState(1) end
  return fallback == true
end

local function countMobsAround(myPos, range, mobs, target)
  if not myPos then return 0 end
  local count = 0
  local seen = {}

  for _, item in ipairs(mobs or {}) do
    local p = item.pos
    if p and p.z == myPos.z and dist(myPos, p) <= range then
      count = count + 1
      if item.id then seen[item.id] = true end
    end
  end

  if target and isAliveMob(target) and not isIgnoredName(creatureNameLower(target)) then
    local id = getCreatureId(target)
    if not id or not seen[id] then
      local tp = safePos(target)
      if tp and tp.z == myPos.z and dist(myPos, tp) <= range then
        count = count + 1
      end
    end
  end

  return count
end

-- ============================================================
-- 4) WAVE 3x5 / AREA
-- ============================================================

local WAVE_WIDTH = 3
local WAVE_LENGTH = 5
local WAVE_START_AHEAD = 1

local function inWave3x5(myPos, p, dir)
  if not myPos or not p then return false end
  if p.z ~= myPos.z then return false end

  local dx = p.x - myPos.x
  local dy = p.y - myPos.y
  local halfW = math.floor(WAVE_WIDTH / 2)

  if dir == 0 then
    return (dx >= -halfW and dx <= halfW) and (dy <= -WAVE_START_AHEAD and dy >= -(WAVE_START_AHEAD + WAVE_LENGTH - 1))
  elseif dir == 2 then
    return (dx >= -halfW and dx <= halfW) and (dy >= WAVE_START_AHEAD and dy <= (WAVE_START_AHEAD + WAVE_LENGTH - 1))
  elseif dir == 1 then
    return (dy >= -halfW and dy <= halfW) and (dx >= WAVE_START_AHEAD and dx <= (WAVE_START_AHEAD + WAVE_LENGTH - 1))
  else
    return (dy >= -halfW and dy <= halfW) and (dx <= -WAVE_START_AHEAD and dx >= -(WAVE_START_AHEAD + WAVE_LENGTH - 1))
  end
end

local function dirTo(fromPos, toPos)
  local dx = toPos.x - fromPos.x
  local dy = toPos.y - fromPos.y
  if math.abs(dx) > math.abs(dy) then
    return (dx > 0) and 1 or 3
  else
    return (dy > 0) and 2 or 0
  end
end

local function dirName(dir)
  if dir == 0 then return "N" end
  if dir == 1 then return "E" end
  if dir == 2 then return "S" end
  return "W"
end

local function countMobsInWave3x5(myPos, dir, mobs, target)
  local count = 0
  local seen = {}

  for _, item in ipairs(mobs or {}) do
    if item.pos and inWave3x5(myPos, item.pos, dir) then
      count = count + 1
      if item.id then seen[item.id] = true end
    end
  end

  if target and isAliveMob(target) and not isIgnoredName(creatureNameLower(target)) then
    local id = getCreatureId(target)
    if not id or not seen[id] then
      local tp = safePos(target)
      if tp and inWave3x5(myPos, tp, dir) then
        count = count + 1
      end
    end
  end

  return count
end

local function bestWaveDirection(myPos, target, mobs)
  local tp = safePos(target)
  if not myPos or not tp then return nil, 0 end

  local targetDir = dirTo(myPos, tp)
  local bestDir = targetDir
  local bestCnt = countMobsInWave3x5(myPos, targetDir, mobs, target)

  for d = 0, 3 do
    local c = countMobsInWave3x5(myPos, d, mobs, target)
    if c > bestCnt then
      bestCnt = c
      bestDir = d
    end
  end

  return bestDir, bestCnt
end

local function inAoE6x6(myPos, p)
  if not myPos or not p then return false end
  if p.z ~= myPos.z then return false end

  local dx = p.x - myPos.x
  local dy = p.y - myPos.y

  return dx >= -aoeGet("aoe6Left", 3)
     and dx <= aoeGet("aoe6Right", 2)
     and dy >= -aoeGet("aoe6Up", 3)
     and dy <= aoeGet("aoe6Down", 2)
end

local function countMobsAoE6x6(myPos, mobs)
  local count = 0
  for _, item in ipairs(mobs or {}) do
    if item.pos and inAoE6x6(myPos, item.pos) then
      count = count + 1
    end
  end
  return count
end

-- ============================================================
-- 5) ESTADO DE INTERVALOS
-- ============================================================

local nextAura = 0
local nextEnergyRing = 0
local nextDefense = 0
local nextSummon = 0
local nextWave = 0
local nextArea = 0
local nextPvpSingle = 0
local nextRpCon = 0
local nextRpGranCon = 0
local nextRpMasSan = 0
local nextParalyze = 0
local nextRpUtito = 0
local nextEkUtito = 0
local nextEkGran = 0
local nextEkGranIco = 0
local nextEkIco = 0
local nextTurn = 0
local lastDebug = 0
local utamoAtivo = false

local cooldownLabels = {
  aura = "Aura",
  utamo_tempo = "Utamo EK",
  utana_vid = "Utana Vid",
  summon = "Summon",
  paralyze = "Paralyze",
  rp_buff = "Utito RP",
  ek_buff = "Utito EK",
  ms_wave = "MS Wave",
  ed_wave = "ED Wave",
  ms_area = "MS Area",
  ed_area = "ED Area",
  ms_pvp_single = "Max Vis",
  ed_pvp_single = "Max Frigo",
  rp_mas_san = "Mas San",
  rp_gran_con = "Gran Con",
  rp_con = "Exori Con",
  ek_gran = "Exori Gran"
}

local cooldownDefaultIconIds = {
  utamo_tempo = 3081,
  utana_vid = 3049,
  summon = 5957,
  paralyze = 3165,
  ms_summon = 5957,
  ed_summon = 5957,
  rp_summon = 5957,
  ek_summon = 5957,
  rp_buff = 7439,
  ek_buff = 7439,
  ms_wave = 8092,
  ms_pvp_single = 8092,
  ms_area = 8092,
  ms_strong_area = 3071,
  ed_wave = 8084,
  ed_area = 8084,
  ed_pvp_single = 8140,
  ed_strong_area = 3067,
  rp_mas_san = 7365,
  rp_gran_con = 7364,
  rp_con = 7364,
  ek_gran = 7434,
  ek_gran_ico = 7434,
  ek_ico = 7434
}

local cooldownIconStyle = [[
Panel
  background-color: #111111dd
  opacity: 0.9
  padding: 1
  height: 34
  width: 70
  focusable: true
  phantom: false
  draggable: true

  BotItem
    id: icon
    anchors.left: parent.left
    anchors.top: parent.top
    size: 32 32
    phantom: true

  Label
    id: time
    anchors.left: icon.right
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    margin-left: 3
    height: 18
    color: #ffd36b
    text-align: center
    font: verdana-11px-rounded
]]

local activeCooldowns = {}
local cooldownWidgets = {}
local cooldownOrder = {"aura", "utana_vid", "summon"}

if type(aoeSettings.cooldownIconPositions) ~= "table" then
  aoeSettings.cooldownIconPositions = {}
end

local function getCooldownOrderIndex(key)
  for i, existing in ipairs(cooldownOrder) do
    if existing == key then return i end
  end
  table.insert(cooldownOrder, key)
  return #cooldownOrder
end

local function cooldownDefaultPosition(key)
  local idx = getCooldownOrderIndex(key)
  local col = (idx - 1) % 2
  local row = math.floor((idx - 1) / 2)
  return { x = 260 + (col * 74), y = 90 + (row * 38) }
end

local function ctrlPressed()
  return modules
     and modules.corelib
     and modules.corelib.g_keyboard
     and modules.corelib.g_keyboard.isCtrlPressed
     and modules.corelib.g_keyboard.isCtrlPressed()
end

local function attachCooldownWidgetDrag(key, widget)
  widget.onDragEnter = function(w, mousePos)
    if not ctrlPressed() then return false end
    w:breakAnchors()
    w.movingReference = { x = mousePos.x - w:getX(), y = mousePos.y - w:getY() }
    return true
  end

  widget.onDragMove = function(w, mousePos, moved)
    local parent = w:getParent()
    if not parent then return false end
    local parentRect = parent:getRect()
    local x = math.min(math.max(parentRect.x, mousePos.x - w.movingReference.x), parentRect.x + parentRect.width - w:getWidth())
    local y = math.min(math.max(parentRect.y, mousePos.y - w.movingReference.y), parentRect.y + parentRect.height - w:getHeight())
    w:move(x, y)
    return true
  end

  widget.onDragLeave = function(w, pos)
    aoeSettings.cooldownIconPositions[key] = { x = w:getX(), y = w:getY() }
    return true
  end
end

local function cooldownIconId(key)
  if type(aoeSettings.cooldownIconIds) == "table" then
    local customId = tonumber(aoeSettings.cooldownIconIds[key])
    if customId and customId > 0 then return customId end
  end

  if key == "aura" then return aoeGet("auraItemId", 5571) end
  if key == "ms_sd" or key == "ed_sd" then return aoeGet("sdRuneId", 3155) end
  if key == "paralyze" then return aoeGet("paralyzeRuneId", 3165) end

  return tonumber(cooldownDefaultIconIds[key]) or 0
end

local function updateCooldownWidgetIcon(key, widget)
  if not widget or not widget.icon or not widget.icon.setItemId then return end
  local iconId = cooldownIconId(key)
  if not iconId or iconId <= 0 or widget.currentIconId == iconId then return end

  pcall(function() widget.icon:setItemId(iconId) end)
  widget.currentIconId = iconId
end

local cooldownIconConfigWindow = nil

local function defaultCooldownIconId(key)
  if key == "aura" then return aoeGet("auraItemId", 5571) end
  if key == "ms_sd" or key == "ed_sd" then return aoeGet("sdRuneId", 3155) end
  if key == "paralyze" then return aoeGet("paralyzeRuneId", 3165) end
  return tonumber(cooldownDefaultIconIds[key]) or 0
end

local function ensureCooldownIconConfigWindow()
  if cooldownIconConfigWindow then return cooldownIconConfigWindow end
  if not setupUI or not g_ui or not g_ui.getRootWidget then return nil end

  local ok, window = pcall(function()
    return setupUI([[
MainWindow
  text: Configurar Icone
  size: 245 182
  @onEscape: self:hide()

  Label
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 18
    text-align: center
    text: Cooldown

  BotItem
    id: preview
    anchors.top: title.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    margin-top: 6
    size: 34 34

  Label
    id: idLabel
    anchors.top: preview.bottom
    anchors.left: parent.left
    margin-top: 8
    width: 45
    height: 18
    text-offset: 0 3
    text: ID:

  TextEdit
    id: iconId
    anchors.top: idLabel.top
    anchors.left: idLabel.right
    anchors.right: parent.right
    height: 18
    text-align: center

  Label
    id: auraCdLabel
    anchors.top: iconId.bottom
    anchors.left: parent.left
    margin-top: 7
    width: 75
    height: 18
    text-offset: 0 3
    text: CD Aura:

  TextEdit
    id: auraCooldownSec
    anchors.top: auraCdLabel.top
    anchors.left: auraCdLabel.right
    anchors.right: parent.right
    height: 18
    text-align: center

  Button
    id: resetButton
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    width: 60
    height: 21
    text: Reset

  Button
    id: saveButton
    anchors.right: closeButton.left
    anchors.bottom: parent.bottom
    margin-right: 5
    width: 60
    height: 21
    text: Salvar

  Button
    id: closeButton
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    width: 60
    height: 21
    text: Fechar
]], g_ui.getRootWidget())
  end)

  if not ok or not window then return nil end

  window:hide()
  window.closeButton.onClick = function()
    window:hide()
    focusGameMapSoon()
  end

  window.iconId.onTextChange = function(_, text)
    if window.updatingIconId then return end
    local id = tonumber(text)
    if id and id > 0 and window.preview and window.preview.setItemId then
      pcall(function() window.preview:setItemId(id) end)
    end
  end

  window.auraCooldownSec.onTextChange = function(_, text)
    local sec = tonumber(text)
    if window.cooldownKey == "aura" and sec and sec > 0 then
      aoeSettings.auraCooldownSec = sec
    end
  end

  if window.preview then
    window.preview.onItemChange = function(widget)
      if not widget or not widget.getItemId then return end
      local okItem, id = pcall(function() return widget:getItemId() end)
      id = okItem and tonumber(id) or nil
      if id and id > 0 then
        local text = tostring(id)
        if window.iconId:getText() ~= text then
          window.updatingIconId = true
          window.iconId:setText(text)
          window.updatingIconId = false
        end
      end
    end
  end

  window.saveButton.onClick = function()
    local key = window.cooldownKey
    local id = tonumber(window.iconId:getText())
    if not key or not id or id <= 0 then return end

    aoeSettings.cooldownIconIds = aoeSettings.cooldownIconIds or {}
    aoeSettings.cooldownIconIds[key] = id

    local widget = cooldownWidgets[key]
    if widget then
      widget.currentIconId = nil
      updateCooldownWidgetIcon(key, widget)
    end

    if key == "aura" then
      local sec = tonumber(window.auraCooldownSec:getText())
      if sec and sec > 0 then
        aoeSettings.auraCooldownSec = sec
      end
    end

    window:hide()
    focusGameMapSoon()
  end

  window.resetButton.onClick = function()
    local key = window.cooldownKey
    if not key then return end

    if type(aoeSettings.cooldownIconIds) == "table" then
      aoeSettings.cooldownIconIds[key] = nil
    end

    local id = defaultCooldownIconId(key)
    window.iconId:setText(tostring(id))
    if key == "aura" then
      aoeSettings.auraCooldownSec = 120
      window.auraCooldownSec:setText("120")
    end
    if window.preview and window.preview.setItemId then
      pcall(function() window.preview:setItemId(id) end)
    end

    local widget = cooldownWidgets[key]
    if widget then
      widget.currentIconId = nil
      updateCooldownWidgetIcon(key, widget)
    end
    focusGameMapSoon()
  end

  cooldownIconConfigWindow = window
  return cooldownIconConfigWindow
end

local function showCooldownIconConfig(key)
  local window = ensureCooldownIconConfigWindow()
  if not window then return end

  local id = cooldownIconId(key)
  local label = activeCooldowns[key] and activeCooldowns[key].label or cooldownLabels[key] or key
  local isAura = key == "aura"

  window.cooldownKey = key
  window.title:setText(tostring(label))
  window.updatingIconId = true
  window.iconId:setText(tostring(id))
  window.updatingIconId = false
  window.auraCooldownSec:setText(tostring(aoeGet("auraCooldownSec", 120)))
  pcall(function()
    if isAura then
      window.auraCdLabel:show()
      window.auraCooldownSec:show()
    else
      window.auraCdLabel:hide()
      window.auraCooldownSec:hide()
    end
  end)
  if window.preview and window.preview.setItemId then
    pcall(function() window.preview:setItemId(id) end)
  end
  window:show()
  window:raise()
  window:focus()
end

local function ensureCooldownWidget(key)
  if cooldownWidgets[key] then return cooldownWidgets[key] end
  if not setupUI or not g_ui or not g_ui.getRootWidget then return nil end

  local ok, widget = pcall(function()
    return setupUI(cooldownIconStyle, g_ui.getRootWidget())
  end)
  if not ok or not widget then return nil end

  local posInfo = aoeSettings.cooldownIconPositions[key] or cooldownDefaultPosition(key)
  pcall(function() widget:setPosition({ x = posInfo.x, y = posInfo.y }) end)
  pcall(function() widget:setTooltip((cooldownLabels[key] or key) .. " | Botao direito: ID | Ctrl + arrastar") end)
  updateCooldownWidgetIcon(key, widget)
  attachCooldownWidgetDrag(key, widget)
  widget.onMouseRelease = function(_, mousePos, button)
    if button ~= 2 then return false end
    showCooldownIconConfig(key)
    return true
  end
  if widget.icon then
    widget.icon.onMouseRelease = function(_, mousePos, button)
      if button ~= 2 then return false end
      showCooldownIconConfig(key)
      return true
    end
  end
  cooldownWidgets[key] = widget
  return widget
end

local function destroyCooldownWidget(key)
  local widget = cooldownWidgets[key]
  if widget then
    pcall(function() widget:destroy() end)
    cooldownWidgets[key] = nil
  end
end

local function destroyAllCooldownWidgets()
  local keys = {}
  for key, _ in pairs(cooldownWidgets) do
    table.insert(keys, key)
  end
  for _, key in ipairs(keys) do
    destroyCooldownWidget(key)
  end
end

local function formatCooldownMs(ms)
  if ms <= 0 then return "OK" end
  if ms >= 10000 then return tostring(math.ceil(ms / 1000)) .. "s" end
  return string.format("%.1fs", math.max(0.1, ms / 1000))
end

local function trackCooldown(key, tm, cdMs, label)
  cdMs = tonumber(cdMs) or 0
  if not key or cdMs <= 0 then return end
  local item = activeCooldowns[key] or {}
  item.label = label or cooldownLabels[key] or key
  item.endsAt = tm + cdMs
  activeCooldowns[key] = item
end

local function trackCooldownUntil(key, tm, endsAt, label)
  if not key or not endsAt or endsAt <= tm then return end
  local item = activeCooldowns[key] or {}
  item.label = label or cooldownLabels[key] or key
  item.endsAt = endsAt
  activeCooldowns[key] = item
end

local function ensureCooldownEntry(key, label)
  if not key or key == "" then return end
  getCooldownOrderIndex(key)
  local item = activeCooldowns[key] or {}
  item.label = label or item.label or cooldownLabels[key] or key
  item.endsAt = tonumber(item.endsAt) or 0
  activeCooldowns[key] = item
end

local alwaysVisibleCooldownKeys = {}
local refreshAlwaysVisibleCooldowns = function()
  ensureCooldownEntry("aura", cooldownLabels.aura or "Aura")
  ensureCooldownEntry("utana_vid", cooldownLabels.utana_vid or "Utana Vid")
  ensureCooldownEntry("summon", cooldownLabels.summon or "Summon")
end

refreshAlwaysVisibleCooldowns()

local manualSpellCooldownHooks = {}

local function normalizeCastText(text)
  return tostring(text or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
end

local function registerManualSpellCooldown(text, callback)
  local key = normalizeCastText(text)
  if key == "" or type(callback) ~= "function" then return end
  manualSpellCooldownHooks[key] = callback
end

local function auraCooldownMs()
  return math.max(1, aoeGet("auraCooldownSec", 120)) * 1000
end

local function utanaVidCooldownMs()
  return math.max(1, aoeGet("utanaVidCooldownSec", 120)) * 1000
end

local function markAuraCooldown(tm)
  local cd = auraCooldownMs()
  nextAura = tm + cd
  trackCooldown("aura", tm, cd)
  return cd
end

local function markUtanaVidCooldown(tm)
  local cd = utanaVidCooldownMs()
  trackCooldown("utana_vid", tm, cd)
  return cd
end

local function isAuraUseItemId(itemId)
  itemId = tonumber(itemId)
  if not itemId or itemId <= 0 then return false end

  local configuredId = aoeGet("auraItemId", 0)
  if configuredId > 0 and itemId == configuredId then return true end

  local ammoItem = getAmmoSlotItem()
  if ammoItem then
    local okId, ammoId = pcall(function() return ammoItem:getId() end)
    if okId and tonumber(ammoId) == itemId then
      aoeSettings.auraItemId = itemId

      local widget = cooldownWidgets.aura
      if widget then
        widget.currentIconId = nil
        updateCooldownWidgetIcon("aura", widget)
      end

      return true
    end
  end

  return false
end

if type(onUse) == "function" then
  onUse(function(pos, itemId, stackPos, subType)
    if not isAuraUseItemId(itemId) then return end

    local tm = nowMs()
    local cd = markAuraCooldown(tm)
    debugWarn("Aura manual detectada: item " .. tostring(itemId) .. " cd=" .. tostring(math.floor(cd / 1000)) .. "s")
  end)
end

if type(onTalk) == "function" then
  onTalk(function(name, level, mode, text, channelId, pos)
    handleVocationDetectionText(text)

    local playerName = player and player.getName and player:getName() or nil
    if playerName and name ~= playerName then return end

    local spoken = normalizeCastText(text)
    local tm = nowMs()

    if spoken == "utana vid" then
      local cd = markUtanaVidCooldown(tm)
      debugWarn("Utana Vid detectado: cd=" .. tostring(math.floor(cd / 1000)) .. "s")
      return
    end

    local manualHook = manualSpellCooldownHooks[spoken]
    if manualHook then manualHook(tm, spoken) end
  end)
end

macro(100, function()
  local tm = nowMs()

  if not aoeIsOn("enableCooldownIcons", true) then
    destroyAllCooldownWidgets()
    return
  end

  refreshAlwaysVisibleCooldowns()

  for key, item in pairs(activeCooldowns) do
    local widget = ensureCooldownWidget(key)
    if widget then
      updateCooldownWidgetIcon(key, widget)
      pcall(function() widget:setTooltip(tostring(item.label or cooldownLabels[key] or key) .. " | Botao direito: ID | Ctrl + arrastar") end)

      local remaining = (item.endsAt or tm) - tm
      local text = "OK"
      local color = "#7dff8a"
      if remaining > 0 then
        text = formatCooldownMs(remaining)
        color = "#ffd36b"
      end

      if widget.time then
        widget.time:setText(text)
        if widget.time.setColor then widget.time:setColor(color) end
      else
        widget:setText(text)
        if widget.setColor then widget:setColor(color) end
      end
    end
  end
end)

-- Mantemos intervalos internos para evitar spam/travamento do cavebot.
local function markNext(key, tm, cdMs)
  cdMs = tonumber(cdMs) or 0
  trackCooldown(key, tm, cdMs)
  return tm + cdMs
end

local attackCooldowns = {
  sorcerer = {
    sd = { icon = "ms_sd", label = "SD", group = "A", cd = 2000, mana = 0 },
    paralyze = { icon = "paralyze", label = "Paralyze", group = "A", cd = 2000, mana = 0 },
    wave = { icon = "ms_wave", label = "Vis Hur", group = "B", cd = 6000, mana = 10 },
    pvpSingle = { icon = "ms_pvp_single", label = "Max Vis", group = "B", cd = 6000, mana = 15 },
    area = { icon = "ms_area", label = "Gran Mas Vis", group = "C", cd = 12000, mana = 25 },
    strongArea = { icon = "ms_strong_area", label = "Gran Mas Flam", group = "C", cd = 16000, mana = 45 },
    summon = { icon = "summon", label = "Summon MS", cd = 180000, mana = 0 }
  },
  druid = {
    sd = { icon = "ed_sd", label = "SD", group = "A", cd = 2000, mana = 0 },
    paralyze = { icon = "paralyze", label = "Paralyze", group = "A", cd = 2000, mana = 0 },
    wave = { icon = "ed_wave", label = "Tera Hur", group = "B", cd = 6000, mana = 8 },
    pvpSingle = { icon = "ed_pvp_single", label = "Max Frigo", group = "B", cd = 5000, mana = 8 },
    area = { icon = "ed_area", label = "Gran Mas Tera", group = "C", cd = 12000, mana = 30 },
    strongArea = { icon = "ed_strong_area", label = "Gran Mas Frigo", group = "C", cd = 16000, mana = 45 },
    summon = { icon = "summon", label = "Summon ED", cd = 180000, mana = 0 }
  },
  paladin = {
    paralyze = { icon = "paralyze", label = "Paralyze", group = "A", cd = 2000, mana = 0 },
    con = { icon = "rp_con", label = "Exori Con", group = "A", cd = 2000, mana = 1 },
    granCon = { icon = "rp_gran_con", label = "Gran Con", group = "B", cd = 5000, mana = 10 },
    masSan = { icon = "rp_mas_san", label = "Mas San", group = "C", cd = 12000, mana = 20 },
    summon = { icon = "summon", label = "Summon RP", cd = 180000, mana = 0 }
  },
  knight = {
    paralyze = { icon = "paralyze", label = "Paralyze", group = "A", cd = 2000, mana = 0 },
    ico = { icon = "ek_ico", label = "Exori Ico", group = "A", cd = 2000, mana = 1 },
    granIco = { icon = "ek_gran_ico", label = "Gran Ico", group = "B", cd = 6000, mana = 15 },
    gran = { icon = "ek_gran", label = "Exori Gran", group = "C", cd = 10000, mana = 25 },
    summon = { icon = "summon", label = "Summon EK", cd = 180000, mana = 0 }
  }
}

local alwaysVisibleAttackActions = {
  sorcerer = { "sd", "paralyze", "wave", "pvpSingle", "area", "strongArea" },
  druid = { "sd", "paralyze", "wave", "pvpSingle", "area", "strongArea" },
  paladin = { "paralyze", "con", "granCon", "masSan" },
  knight = { "paralyze", "ico", "granIco", "gran" }
}

local attackCooldownIconKeys = {}
for _, actions in pairs(attackCooldowns) do
  for _, meta in pairs(actions) do
    if meta.icon and meta.icon ~= "summon" then
      attackCooldownIconKeys[meta.icon] = true
    end
  end
end

refreshAlwaysVisibleCooldowns = function()
  local keep = {
    aura = true,
    utana_vid = true,
    summon = true
  }

  ensureCooldownEntry("aura", cooldownLabels.aura or "Aura")
  ensureCooldownEntry("utana_vid", cooldownLabels.utana_vid or "Utana Vid")
  ensureCooldownEntry("summon", cooldownLabels.summon or "Summon")

  local vocation = getActiveVocation()
  local modes = {
    { key = "pve" },
    { key = "pvp" }
  }

  for _, modeInfo in ipairs(modes) do
    local modeDefaults = profileDefaults[modeInfo.key] and profileDefaults[modeInfo.key][vocation] or {}
    for _, action in ipairs(alwaysVisibleAttackActions[vocation] or {}) do
      if modeDefaults[action] ~= nil and profileSkillOn(modeInfo.key, vocation, action, false) then
        local meta = attackCooldowns[vocation] and attackCooldowns[vocation][action] or nil
        if meta and meta.icon then
          local label = meta.label or cooldownLabels[meta.icon] or action
          if meta.group then label = label .. " [G" .. meta.group .. "]" end
          ensureCooldownEntry(meta.icon, label)
          keep[meta.icon] = true
        end
      end
    end
  end

  local tm = nowMs()
  for key, _ in pairs(alwaysVisibleCooldownKeys) do
    if not keep[key] then
      alwaysVisibleCooldownKeys[key] = nil
      local item = activeCooldowns[key]
      if not item or (tonumber(item.endsAt) or 0) <= tm then
        activeCooldowns[key] = nil
        destroyCooldownWidget(key)
      end
    end
  end

  for key, _ in pairs(attackCooldownIconKeys) do
    if not keep[key] then
      activeCooldowns[key] = nil
      destroyCooldownWidget(key)
    end
  end

  alwaysVisibleCooldownKeys = keep
end

refreshAlwaysVisibleCooldowns()

local groupCooldowns = {
  sorcerer = { A = 0, B = 0, C = 0 },
  druid = { A = 0, B = 0, C = 0 },
  paladin = { A = 0, B = 0, C = 0 },
  knight = { A = 0, B = 0, C = 0 }
}

local individualCooldowns = {
  sorcerer = {},
  druid = {},
  paladin = {},
  knight = {}
}

local pendingAttackCooldowns = {
  sorcerer = {},
  druid = {},
  paladin = {},
  knight = {}
}

local pendingAttackSeq = 0

local function getAttackMeta(vocation, action)
  return attackCooldowns[vocation] and attackCooldowns[vocation][action] or nil
end

local function attackCooldownKey(meta, action)
  return meta and (meta.group or action) or action
end

local function getPendingAttackCooldown(vocation, action)
  local meta = getAttackMeta(vocation, action)
  local pending = pendingAttackCooldowns[vocation]
  if not meta or not pending then return nil end
  return pending[attackCooldownKey(meta, action)]
end

local function attackCooldownEnd(vocation, action)
  local meta = getAttackMeta(vocation, action)
  if not meta then return 0 end
  if meta.group then
    local groups = groupCooldowns[vocation]
    return groups and (groups[meta.group] or 0) or 0
  end
  local individual = individualCooldowns[vocation]
  return individual and (individual[action] or 0) or 0
end

local function attackLeadMs()
  return math.max(0, aoeGet("attackLeadMs", 500))
end

local function attackPostMs()
  return math.max(0, aoeGet("attackPostMs", 500))
end

local function manaFailCheckMs()
  return math.max(100, aoeGet("manaFailCheckMs", 500))
end

local function currentManaPercent()
  if manapercent then
    local ok, value = pcall(function() return manapercent() end)
    if ok and value ~= nil then return tonumber(value) end
  end

  if player and player.getManaPercent then
    local ok, value = pcall(function() return player:getManaPercent() end)
    if ok and value ~= nil then return tonumber(value) end
  end

  if player and player.getMana then
    local okMana, mana = pcall(function() return player:getMana() end)
    if not okMana or mana == nil then return nil end
    mana = tonumber(mana)
    if not mana then return nil end
    if mana >= 0 and mana <= 100 then
      return mana
    end

    if player.getMaxMana then
      local okMax, maxMana = pcall(function() return player:getMaxMana() end)
      maxMana = okMax and tonumber(maxMana) or nil
      if maxMana and maxMana > 0 then
        return math.min(100, math.max(0, math.floor((mana * 100) / maxMana)))
      end
    end

    return math.min(100, math.max(0, mana))
  end

  return nil
end

local function attackHasMana(vocation, action)
  local meta = getAttackMeta(vocation, action)
  if not meta then return true end
  local needed = tonumber(meta.mana) or 0
  if needed <= 0 then return true end

  local mana = currentManaPercent()
  if mana == nil then return true end
  if mana >= needed then return true end

  debugWarn("Mana insuficiente para " .. tostring(meta.label or action) .. ": " .. tostring(mana) .. "%/" .. tostring(needed) .. "%")
  return false
end

local function attackCanAttempt(vocation, action, tm, nextAt)
  if getPendingAttackCooldown(vocation, action) then return false end
  if not attackHasMana(vocation, action) then return false end
  local readyAt = math.max(tonumber(nextAt) or 0, attackCooldownEnd(vocation, action))
  return tm + attackLeadMs() >= readyAt
end

local function isManaFailureText(text)
  local t = tostring(text or ""):lower()
  return t:find("not enough mana", 1, true)
      or t:find("do not have enough mana", 1, true)
      or t:find("don't have enough mana", 1, true)
      or t:find("insufficient mana", 1, true)
      or t:find("mana suficiente", 1, true)
      or t:find("sem mana", 1, true)
      or t:find("falta mana", 1, true)
      or (t:find("need", 1, true) and t:find("mana", 1, true))
      or (t:find("precisa", 1, true) and t:find("mana", 1, true))
end

local function cancelPendingManaCooldowns(tm)
  local bestVocation = nil
  local bestKey = nil
  local bestItem = nil

  for vocation, pending in pairs(pendingAttackCooldowns) do
    for key, item in pairs(pending) do
      if item and tm >= (item.startedAt or 0) and tm <= (item.checkUntil or tm) + 250 then
        if not bestItem or (item.seq or 0) > (bestItem.seq or 0) then
          bestVocation = vocation
          bestKey = key
          bestItem = item
        end
      end
    end
  end

  if bestVocation and bestKey and bestItem then
    pendingAttackCooldowns[bestVocation][bestKey] = nil
    debugWarn("Cooldown cancelado por falta de mana: " .. tostring(bestItem.label or bestKey))
  end
end

if type(onTextMessage) == "function" then
  onTextMessage(function(mode, text)
    handleVocationDetectionText(text)
    if not isManaFailureText(text) then return end
    local tm = nowMs()
    cancelPendingManaCooldowns(tm)
  end)
end

local nextVocationProbe = 0
macro(500, function()
  if not isOnline() then return end
  if aoeSettings.autoDetectVocation == false then return end

  local tm = nowMs()
  if tm < nextVocationProbe then return end
  nextVocationProbe = tm + 1500

  probeLocalPlayerVocation("player")
end)

local function commitPendingAttackCooldown(vocation, key, item)
  if item.group and groupCooldowns[vocation] then
    groupCooldowns[vocation][item.group] = item.endsAt
  elseif individualCooldowns[vocation] then
    individualCooldowns[vocation][item.action] = item.endsAt
  end
  trackCooldownUntil(item.icon, nowMs(), item.endsAt, item.label)
end

macro(50, function()
  local tm = nowMs()
  for vocation, pending in pairs(pendingAttackCooldowns) do
    for key, item in pairs(pending) do
      if tm >= (item.checkUntil or 0) then
        pending[key] = nil
        commitPendingAttackCooldown(vocation, key, item)
      end
    end
  end
end)

local function markAttackCooldown(vocation, action, tm)
  local meta = getAttackMeta(vocation, action)
  if not meta then return tm end
  local cd = tonumber(meta.cd) or 0

  -- Durante as janelas de insistencia, tenta sem resetar o cooldown cheio.
  -- Assim cobrimos um pequeno atraso do servidor sem perder a cadencia real dos grupos.
  local currentEnd = attackCooldownEnd(vocation, action)
  if meta.group and currentEnd > tm then
    return math.min(currentEnd, tm + 100)
  end

  local cooldownBase = tm
  if meta.group and currentEnd > 0 then
    local postEnd = currentEnd + attackPostMs()
    if tm <= postEnd then
      return math.min(postEnd, tm + 100)
    end
    cooldownBase = currentEnd
    if cooldownBase + cd <= tm then
      cooldownBase = tm
    end
  end

  local endsAt = cooldownBase + cd
  local label = meta.label
  if meta.group then label = label .. " [G" .. meta.group .. "]" end

  local key = attackCooldownKey(meta, action)
  local checkMs = manaFailCheckMs()
  pendingAttackSeq = pendingAttackSeq + 1
  pendingAttackCooldowns[vocation][key] = {
    action = action,
    group = meta.group,
    icon = meta.icon or action,
    label = label,
    endsAt = endsAt,
    startedAt = tm,
    checkUntil = tm + checkMs,
    seq = pendingAttackSeq
  }

  return tm + checkMs
end

local function forceAttackCooldown(vocation, action, tm)
  local meta = getAttackMeta(vocation, action)
  if not meta then return nil end

  local cd = tonumber(meta.cd) or 0
  if cd <= 0 then return nil end

  local endsAt = tm + cd
  local label = meta.label
  if meta.group then label = label .. " [G" .. meta.group .. "]" end

  if meta.group and groupCooldowns[vocation] then
    groupCooldowns[vocation][meta.group] = math.max(tonumber(groupCooldowns[vocation][meta.group]) or 0, endsAt)
  elseif individualCooldowns[vocation] then
    individualCooldowns[vocation][action] = math.max(tonumber(individualCooldowns[vocation][action]) or 0, endsAt)
  end

  trackCooldownUntil(meta.icon or action, tm, endsAt, label)
  return endsAt, cd
end

local function registerAttackManualCooldowns()
  local entries = {
    { spell = aoeText("msWaveSpell", "exevo vis hur"), vocation = "sorcerer", action = "wave" },
    { spell = aoeText("msPvpSingleSpell", "exori max vis"), vocation = "sorcerer", action = "pvpSingle" },
    { spell = aoeText("msAreaSpell", "exevo gran mas vis"), vocation = "sorcerer", action = "area" },
    { spell = aoeText("msStrongAreaSpell", "exevo gran mas flam"), vocation = "sorcerer", action = "strongArea" },

    { spell = aoeText("edWaveSpell", "exevo tera hur"), vocation = "druid", action = "wave" },
    { spell = aoeText("edPvpSingleSpell", "exori max frigo"), vocation = "druid", action = "pvpSingle" },
    { spell = "exori max frigo", vocation = "druid", action = "pvpSingle" },
    { spell = aoeText("edAreaSpell", "exevo gran mas tera"), vocation = "druid", action = "area" },
    { spell = aoeText("edStrongAreaSpell", "exevo gran mas frigo"), vocation = "druid", action = "strongArea" },

    { spell = aoeText("rpMasSanSpell", "exevo mas san"), vocation = "paladin", action = "masSan" },
    { spell = aoeText("rpGranConSpell", "exori gran con"), vocation = "paladin", action = "granCon" },
    { spell = aoeText("rpConSpell", "exori con"), vocation = "paladin", action = "con" },

    { spell = aoeText("ekGranSpell", "exori gran"), vocation = "knight", action = "gran" },
    { spell = aoeText("ekGranIcoSpell", "exori gran ico"), vocation = "knight", action = "granIco" },
    { spell = aoeText("ekIcoSpell", "exori ico"), vocation = "knight", action = "ico" }
  }

  for _, entry in ipairs(entries) do
    local vocation = entry.vocation
    local action = entry.action
    registerManualSpellCooldown(entry.spell, function(tm)
      local _, cd = forceAttackCooldown(vocation, action, tm)
      local meta = getAttackMeta(vocation, action)
      if cd and meta then
        debugWarn("Cooldown manual detectado: " .. tostring(meta.label or action) .. " cd=" .. tostring(math.floor(cd / 1000)) .. "s")
      end
    end)
  end
end

registerAttackManualCooldowns()

-- ============================================================
-- 7) ACOES POR PRIORIDADE
-- ============================================================

local function tryAura(tm)
  if not aoeIsOn("enableAura", true) then return false end
  if tm < nextAura then return false end
  local hp = selfHealthPercentSafe()
  if hp and hp <= aoeGet("auraHp", 25) then
    local auraItem = aoeGet("auraItemId", 5571)
    if safeUseAuraItem(auraItem) then
      local cd = markAuraCooldown(tm)
      debugWarn("Aura usada: item " .. tostring(auraItem) .. " cd=" .. tostring(math.floor(cd / 1000)) .. "s")
      return true
    end
  end
  return false
end

local function tryEnergyRing(tm)
  if not aoeIsOn("enableEnergyRing", false) then return false end
  if tm < nextEnergyRing then return false end

  local hp = selfHealthPercentSafe()
  local mana = selfManaPercentSafe()
  if not hp or not mana then return false end
  if hp > aoeGet("energyRingHp", 70) then return false end
  if mana < aoeGet("energyRingMp", 70) then return false end

  local ringItem = aoeGet("energyRingItemId", 3051)
  local activeRing = aoeGet("energyRingActiveId", 3088)
  local equipped = getRingSlotItem()
  if equipped and equipped.getId then
    local ok, currentId = pcall(function() return equipped:getId() end)
    currentId = ok and tonumber(currentId) or nil
    if currentId == ringItem or currentId == activeRing then
      return false
    end
  end

  if safeEquipItemId(ringItem) then
    nextEnergyRing = tm + math.max(100, aoeGet("energyRingDelayMs", 250))
    debugWarn("E-ring equipado: item " .. tostring(ringItem))
    return true
  end

  nextEnergyRing = tm + 500
  return false
end

local function tryDefense(tm, vocation)
  if not aoeIsOn("enableDefense", true) then return false end
  if tm < nextDefense then return false end

  local hp = selfHealthPercentSafe()
  if not hp then return false end

  if vocation == "sorcerer" or vocation == "druid" then
    local shield = manaShieldOn(utamoAtivo)
    if hp <= aoeGet("utamoHpOn", 45) and not shield then
      if castSpell("utamo vita") then
        utamoAtivo = true
        nextDefense = tm + 1000
        return true
      end
    end
    if hp >= aoeGet("utamoHpOff", 60) and shield then
      if castSpell("exana vita") then
        utamoAtivo = false
        nextDefense = tm + 1000
        return true
      end
    end
  end

  if vocation == "knight" and hp <= aoeGet("knightUtamoHp", 45) then
    if castSpell("utamo tempo") then
      nextDefense = tm + 14000
      trackCooldown("utamo_tempo", tm, 14000)
      return true
    end
  end

  return false
end

local function tryBuff(tm, vocation, target)
  if not aoeIsOn("enableBuff", true) then return false end
  if not target then return false end

  if vocation == "paladin" and tm >= nextRpUtito then
    if castSpell("utito tempo san") then
      nextRpUtito = markNext("rp_buff", tm, aoeGet("rpUtitoRenewMs", 10000))
      return true
    end
  end

  if vocation == "knight" and tm >= nextEkUtito then
    if castSpell("utito tempo") then
      nextEkUtito = markNext("ek_buff", tm, aoeGet("ekUtitoRenewMs", 10000))
      return true
    end
  end

  return false
end

local function trySummon(tm, vocation, summonFound)
  if not aoeIsOn("enableSummon", false) then return false end
  if not attackCanAttempt(vocation, "summon", tm, nextSummon) then return false end
  if summonFound and summonFound[vocation] then return false end

  local config = SUMMON_CONFIG[vocation]
  if config and config.spell then
    if castSpell(config.spell) then
      nextSummon = markAttackCooldown(vocation, "summon", tm)
      return true
    end
  end

  return false
end

local function tryMageSd(tm, vocation, target, mode)
  if vocation ~= "sorcerer" and vocation ~= "druid" then return false end
  if not profileSkillOn(mode or "pve", vocation, "sd", false) then return false end
  if not target then return false end
  if not attackCanAttempt(vocation, "sd", tm, 0) then return false end

  if safeUseWithItem(aoeGet("sdRuneId", 3155), target) then
    markAttackCooldown(vocation, "sd", tm)
    return true
  end

  return false
end

local function tryParalyzeRune(tm, vocation, target, mode)
  if (mode or "pvp") ~= "pvp" then return false end
  if not target or not isCreaturePlayer(target) then return false end
  if not profileSkillOn("pvp", vocation, "paralyze", false) then return false end
  if tm < nextParalyze then return false end
  if not attackCanAttempt(vocation, "paralyze", tm, 0) then return false end

  if safeUseWithItem(aoeGet("paralyzeRuneId", 3165), target) then
    nextParalyze = tm + math.max(2000, aoeGet("paralyzeIntervalMs", 6000))
    markAttackCooldown(vocation, "paralyze", tm)
    return true
  end

  return false
end

local function tryMsEdWave(tm, vocation, target, myPos, mobs, mode, safeAreaBlocked)
  if safeAreaBlocked then return false end
  if not target or not myPos then return false end
  if (mode or "pve") ~= "pve" then return false end
  if not profileSkillOn("pve", vocation, "wave", true) then return false end
  if not attackCanAttempt(vocation, "wave", tm, nextWave) then return false end

  local minWaveMobs = math.max(1, aoeGet("minWaveMobs", 1))
  local bestDir, bestCnt = bestWaveDirection(myPos, target, mobs)
  if bestDir and bestCnt >= minWaveMobs then
    if tm < nextTurn then return false end

    -- A wave agora tem prioridade e sempre vira para a direcao com mais mobs.
    turnTo(bestDir)
    nextTurn = tm + aoeGet("turnThrottleMs", 150)

    local spellText = vocation == "druid"
      and aoeText("edWaveSpell", "exevo tera hur")
      or aoeText("msWaveSpell", "exevo vis hur")

    if castSpell(spellText) then
      nextWave = markAttackCooldown(vocation, "wave", tm)
      debugWarn("Wave " .. tostring(vocation) .. " dir=" .. dirName(bestDir) .. " mobs=" .. tostring(bestCnt))
      return true
    end
  end

  if bestDir then
    debugWarn("Wave segurada: mobs=" .. tostring(bestCnt) .. "/" .. tostring(minWaveMobs) .. " dir=" .. dirName(bestDir))
  end
  nextWave = tm + 250
  return false
end

local function tryMsEdOffense(tm, vocation, target, myPos, mobs, summonFound, mode, safeAreaBlocked)
  if not myPos then return false end
  mode = mode or "pve"

  -- V12: a area principal vem antes da wave no PvE.
  -- Ela nao depende de target; basta ter mobs no 6x6.
  -- Isso corrige o caso em que o cavebot/targetbot ainda nao setou target e o gran mas nao saia.
  if not safeAreaBlocked and profileSkillOn(mode, vocation, "area", true) and attackCanAttempt(vocation, "area", tm, nextArea) then
    local hitCount = countMobsAoE6x6(myPos, mobs)
    if hitCount >= aoeGet("minAreaMsEd", 1) then
      local summonActive = summonFound and summonFound[vocation]

      if profileSkillOn(mode, vocation, "strongArea", true) and not summonActive and attackCanAttempt(vocation, "strongArea", tm, nextArea) then
        local strongSpell = vocation == "druid"
          and aoeText("edStrongAreaSpell", "exevo gran mas frigo")
          or aoeText("msStrongAreaSpell", "exevo gran mas flam")

        if castSpell(strongSpell) then
          nextArea = markAttackCooldown(vocation, "strongArea", tm)
          debugWarn("Mage area forte mobs=" .. tostring(hitCount))
          return true
        end
      end

      if attackCanAttempt(vocation, "area", tm, nextArea) and vocation == "sorcerer" then
        if castSpell(aoeText("msAreaSpell", "exevo gran mas vis")) then
          nextArea = markAttackCooldown(vocation, "area", tm)
          debugWarn("MS area VIS mobs=" .. tostring(hitCount))
          return true
        end
      elseif attackCanAttempt(vocation, "area", tm, nextArea) and vocation == "druid" then
        if castSpell(aoeText("edAreaSpell", "exevo gran mas tera")) then
          nextArea = markAttackCooldown(vocation, "area", tm)
          debugWarn("ED area TERA mobs=" .. tostring(hitCount))
          return true
        end
      end
    end
  end

  -- Se nao tiver mobs suficientes para area e tiver target, usa a wave direcional no PvE.
  if target and tryMsEdWave(tm, vocation, target, myPos, mobs, mode, safeAreaBlocked) then return true end
  if target and tryMageSd(tm, vocation, target, mode) then return true end

  return false
end

local function tryMageAreaCategory(tm, vocation, myPos, mobs, summonFound, mode, safeAreaBlocked)
  if safeAreaBlocked or not myPos then return false end
  if not profileSkillOn(mode, vocation, "area", true) then return false end
  if not attackCanAttempt(vocation, "area", tm, nextArea) then return false end

  local hitCount = countMobsAoE6x6(myPos, mobs)
  if hitCount < aoeGet("minAreaMsEd", 1) then return false end

  local summonActive = summonFound and summonFound[vocation]
  if profileSkillOn(mode, vocation, "strongArea", true) and not summonActive and attackCanAttempt(vocation, "strongArea", tm, nextArea) then
    local strongSpell = vocation == "druid"
      and aoeText("edStrongAreaSpell", "exevo gran mas frigo")
      or aoeText("msStrongAreaSpell", "exevo gran mas flam")

    if castSpell(strongSpell) then
      nextArea = markAttackCooldown(vocation, "strongArea", tm)
      debugWarn("Combo mage C forte mobs=" .. tostring(hitCount))
      return true
    end
  end

  if attackCanAttempt(vocation, "area", tm, nextArea) and vocation == "sorcerer" then
    if castSpell(aoeText("msAreaSpell", "exevo gran mas vis")) then
      nextArea = markAttackCooldown(vocation, "area", tm)
      debugWarn("Combo MS C mobs=" .. tostring(hitCount))
      return true
    end
  elseif attackCanAttempt(vocation, "area", tm, nextArea) and vocation == "druid" then
    if castSpell(aoeText("edAreaSpell", "exevo gran mas tera")) then
      nextArea = markAttackCooldown(vocation, "area", tm)
      debugWarn("Combo ED C mobs=" .. tostring(hitCount))
      return true
    end
  end

  return false
end

local function tryRpMasSan(tm, myPos, mobs, mode, safeAreaBlocked)
  mode = mode or "pve"
  if not myPos then return false end

  if not safeAreaBlocked and profileSkillOn(mode, "paladin", "masSan", true) and attackCanAttempt("paladin", "masSan", tm, nextRpMasSan) then
    local hitCount = countMobsAoE6x6(myPos, mobs)
    if hitCount >= aoeGet("minAreaRp", 3) then
      if castSpell(aoeText("rpMasSanSpell", "exevo mas san")) then
        nextRpMasSan = markAttackCooldown("paladin", "masSan", tm)
        debugWarn("RP mas san mobs=" .. tostring(hitCount))
        return true
      end
    end
  end

  return false
end

local function tryRpOffense(tm, target, myPos, mobs, mode, safeAreaBlocked)
  mode = mode or "pve"
  if tryRpMasSan(tm, myPos, mobs, mode, safeAreaBlocked) then return true end
  if not target or not myPos then return false end

  if profileSkillOn(mode, "paladin", "granCon", true) and attackCanAttempt("paladin", "granCon", tm, nextRpGranCon) then
    if castSpell(aoeText("rpGranConSpell", "exori gran con")) then
      nextRpGranCon = markAttackCooldown("paladin", "granCon", tm)
      return true
    end
  end

  if profileSkillOn(mode, "paladin", "con", true) and attackCanAttempt("paladin", "con", tm, nextRpCon) then
    if castSpell(aoeText("rpConSpell", "exori con")) then
      nextRpCon = markAttackCooldown("paladin", "con", tm)
      return true
    end
  end

  return false
end

local function tryPveCombo(tm, vocation, target, myPos, mobs, summonFound, safeAreaBlocked)
  if not aoeIsOn("enableComboMode", false) then return false end
  if not myPos then return false end

  local didCast = false

  if vocation == "sorcerer" or vocation == "druid" then
    if target and tryMageSd(tm, vocation, target, "pve") then didCast = true end
    if target and tryMsEdWave(tm, vocation, target, myPos, mobs, "pve", safeAreaBlocked) then didCast = true end
    if tryMageAreaCategory(tm, vocation, myPos, mobs, summonFound, "pve", safeAreaBlocked) then didCast = true end
  elseif vocation == "paladin" then
    if target and profileSkillOn("pve", "paladin", "con", true) and attackCanAttempt("paladin", "con", tm, nextRpCon) then
      if castSpell(aoeText("rpConSpell", "exori con")) then
        didCast = true
        nextRpCon = markAttackCooldown("paladin", "con", tm)
      end
    end

    if target and profileSkillOn("pve", "paladin", "granCon", true) and attackCanAttempt("paladin", "granCon", tm, nextRpGranCon) then
      if castSpell(aoeText("rpGranConSpell", "exori gran con")) then
        didCast = true
        nextRpGranCon = markAttackCooldown("paladin", "granCon", tm)
      end
    end

    if tryRpMasSan(tm, myPos, mobs, "pve", safeAreaBlocked) then didCast = true end
  elseif vocation == "knight" and target then
    if profileSkillOn("pve", "knight", "ico", true) and attackCanAttempt("knight", "ico", tm, nextEkIco) then
      if castSpell(aoeText("ekIcoSpell", "exori ico")) then
        didCast = true
        nextEkIco = markAttackCooldown("knight", "ico", tm)
      end
    end

    if profileSkillOn("pve", "knight", "granIco", true) and attackCanAttempt("knight", "granIco", tm, nextEkGranIco) then
      if castSpell(aoeText("ekGranIcoSpell", "exori gran ico")) then
        didCast = true
        nextEkGranIco = markAttackCooldown("knight", "granIco", tm)
      end
    end

    local closeCount = countMobsAround(myPos, 1, mobs, target)
    if not safeAreaBlocked and profileSkillOn("pve", "knight", "gran", true) and closeCount >= aoeGet("minEkGran", 2) and attackCanAttempt("knight", "gran", tm, nextEkGran) then
      if castSpell(aoeText("ekGranSpell", "exori gran")) then
        didCast = true
        nextEkGran = markAttackCooldown("knight", "gran", tm)
      end
    end
  end

  if didCast then debugWarn("Combo PVE A/B/C executado para " .. tostring(vocation)) end
  return didCast
end

local function tryEkOffense(tm, target, myPos, mobs, mode, safeAreaBlocked)
  if not target or not myPos then return false end
  mode = mode or "pve"

  local closeCount = countMobsAround(myPos, 1, mobs, target)

  if not safeAreaBlocked and profileSkillOn(mode, "knight", "gran", true) and closeCount >= aoeGet("minEkGran", 2) and attackCanAttempt("knight", "gran", tm, nextEkGran) then
    if castSpell(aoeText("ekGranSpell", "exori gran")) then
      nextEkGran = markAttackCooldown("knight", "gran", tm)
      debugWarn("EK gran mobs=" .. tostring(closeCount))
      return true
    end
  end

  if profileSkillOn(mode, "knight", "granIco", true) and attackCanAttempt("knight", "granIco", tm, nextEkGranIco) then
    if castSpell(aoeText("ekGranIcoSpell", "exori gran ico")) then
      nextEkGranIco = markAttackCooldown("knight", "granIco", tm)
      return true
    end
  end

  if profileSkillOn(mode, "knight", "ico", true) and attackCanAttempt("knight", "ico", tm, nextEkIco) then
    if castSpell(aoeText("ekIcoSpell", "exori ico")) then
      nextEkIco = markAttackCooldown("knight", "ico", tm)
      return true
    end
  end

  return false
end

local function tryPvpCombo(tm, vocation, target, myPos, mobs, summonFound, safeAreaBlocked)
  if not aoeIsOn("enablePvpMode", false) then return false end
  if not target or not myPos or not isCreaturePlayer(target) then return false end
  local didCast = false

  -- PvP ignora minimo de mobs. O alvo precisa ser player e o icon PVP precisa estar ativo.
  if tryParalyzeRune(tm, vocation, target, "pvp") then didCast = true end

  if vocation == "sorcerer" then
    if tryMageSd(tm, vocation, target, "pvp") then didCast = true end

    if profileSkillOn("pvp", vocation, "pvpSingle", true) and attackCanAttempt(vocation, "pvpSingle", tm, nextPvpSingle) then
      if castSpell(aoeText("msPvpSingleSpell", "exori max vis")) then
        didCast = true
        nextPvpSingle = markAttackCooldown(vocation, "pvpSingle", tm)
        debugWarn("PvP MS single: " .. aoeText("msPvpSingleSpell", "exori max vis"))
      end
    end
    if not safeAreaBlocked and profileSkillOn("pvp", vocation, "area", true) and attackCanAttempt(vocation, "area", tm, nextArea) then
      local summonActive = summonFound and summonFound[vocation]
      if profileSkillOn("pvp", vocation, "strongArea", true) and not summonActive and attackCanAttempt(vocation, "strongArea", tm, nextArea) then
        if castSpell(aoeText("msStrongAreaSpell", "exevo gran mas flam")) then
          didCast = true
          nextArea = markAttackCooldown(vocation, "strongArea", tm)
        end
      elseif attackCanAttempt(vocation, "area", tm, nextArea) then
        if castSpell(aoeText("msAreaSpell", "exevo gran mas vis")) then
          didCast = true
          nextArea = markAttackCooldown(vocation, "area", tm)
        end
      end
    end
  elseif vocation == "druid" then
    if tryMageSd(tm, vocation, target, "pvp") then didCast = true end

    if profileSkillOn("pvp", vocation, "pvpSingle", true) and attackCanAttempt(vocation, "pvpSingle", tm, nextPvpSingle) then
      if castSpell(aoeText("edPvpSingleSpell", "exori max frigo")) then
        didCast = true
        nextPvpSingle = markAttackCooldown(vocation, "pvpSingle", tm)
        debugWarn("PvP ED single: " .. aoeText("edPvpSingleSpell", "exori max frigo"))
      end
    end
    if not safeAreaBlocked and profileSkillOn("pvp", vocation, "area", true) and attackCanAttempt(vocation, "area", tm, nextArea) then
      local summonActive = summonFound and summonFound[vocation]
      if profileSkillOn("pvp", vocation, "strongArea", true) and not summonActive and attackCanAttempt(vocation, "strongArea", tm, nextArea) then
        if castSpell(aoeText("edStrongAreaSpell", "exevo gran mas frigo")) then
          didCast = true
          nextArea = markAttackCooldown(vocation, "strongArea", tm)
        end
      elseif attackCanAttempt(vocation, "area", tm, nextArea) then
        if castSpell(aoeText("edAreaSpell", "exevo gran mas tera")) then
          didCast = true
          nextArea = markAttackCooldown(vocation, "area", tm)
        end
      end
    end
  elseif vocation == "paladin" then
    if profileSkillOn("pvp", "paladin", "con", true) and attackCanAttempt("paladin", "con", tm, nextRpCon) then
      if castSpell(aoeText("rpConSpell", "exori con")) then
        didCast = true
        nextRpCon = markAttackCooldown("paladin", "con", tm)
      end
    end
    if profileSkillOn("pvp", "paladin", "granCon", true) and attackCanAttempt("paladin", "granCon", tm, nextRpGranCon) then
      if castSpell(aoeText("rpGranConSpell", "exori gran con")) then
        didCast = true
        nextRpGranCon = markAttackCooldown("paladin", "granCon", tm)
      end
    end
    if not safeAreaBlocked and profileSkillOn("pvp", "paladin", "masSan", true) and attackCanAttempt("paladin", "masSan", tm, nextRpMasSan) then
      if castSpell(aoeText("rpMasSanSpell", "exevo mas san")) then
        didCast = true
        nextRpMasSan = markAttackCooldown("paladin", "masSan", tm)
      end
    end

  elseif vocation == "knight" then
    if profileSkillOn("pvp", "knight", "ico", true) and attackCanAttempt("knight", "ico", tm, nextEkIco) then
      if castSpell(aoeText("ekIcoSpell", "exori ico")) then
        didCast = true
        nextEkIco = markAttackCooldown("knight", "ico", tm)
      end
    end
    if profileSkillOn("pvp", "knight", "granIco", true) and attackCanAttempt("knight", "granIco", tm, nextEkGranIco) then
      if castSpell(aoeText("ekGranIcoSpell", "exori gran ico")) then
        didCast = true
        nextEkGranIco = markAttackCooldown("knight", "granIco", tm)
      end
    end
    if not safeAreaBlocked and profileSkillOn("pvp", "knight", "gran", true) and attackCanAttempt("knight", "gran", tm, nextEkGran) then
      if castSpell(aoeText("ekGranSpell", "exori gran")) then
        didCast = true
        nextEkGran = markAttackCooldown("knight", "gran", tm)
      end
    end
  end

  if didCast then debugWarn("PvP Combo executado para " .. tostring(vocation)) end
  return didCast
end

-- ============================================================
-- 8) LOOP CENTRAL LEVE
-- ============================================================

local nextMainLoop = 0

macro(50, function()
  if not isOnline() then return end

  local tm = nowMs()
  local loopMs = math.max(75, aoeGet("mainLoopMs", 100))
  if tm < nextMainLoop then return end
  nextMainLoop = tm + loopMs

  local vocation = getActiveVocation()

  local target = getAttackTarget()
  local targetIsPlayer = isCreaturePlayer(target)
  local targetIsCreature = target and isValidMob(target) and not targetIsPlayer
  local pveEnabled = aoeIsOn("enablePveMode", true)
  local pvpEnabled = aoeIsOn("enablePvpMode", false)
  local comboEnabled = aoeIsOn("enableComboMode", false)
  local mode = targetIsPlayer and "pvp" or "pve"
  aoeSettings.combatMode = mode

  local myPos = getPlayerPos()
  local mobs = cachedMobs
  local summonFound = cachedSummonFound
  local scanned = false

  local function ensureScan()
    if not scanned then
      mobs, summonFound = getCachedMobsAndSummons(tm, target ~= nil)
      scanned = true
    end
    return mobs, summonFound
  end

  -- Aura continua prioridade absoluta.
  if tryAura(tm) then return end
  if tryEnergyRing(tm) then return end

  if targetIsPlayer then
    if not pvpEnabled then
      if tryDefense(tm, vocation) then return end
      return
    end

    tryDefense(tm, vocation)
    tryBuff(tm, vocation, target)

    ensureScan()
    trySummon(tm, vocation, summonFound)
    local safeAreaBlocked = pveSafeAreaBlocked(targetIsPlayer, comboEnabled)
    tryPvpCombo(tm, vocation, target, myPos, mobs, summonFound, safeAreaBlocked)
  else
    if tryDefense(tm, vocation) then return end

    if targetIsCreature and tryBuff(tm, vocation, target) then return end

    if aoeIsOn("enableSummon", false) then
      ensureScan()
      if trySummon(tm, vocation, summonFound) then return end
    end

    if not pveEnabled then return end

    local safeAreaBlocked = false
    if vocation == "sorcerer" or vocation == "druid" or vocation == "paladin" or targetIsCreature then
      ensureScan()
      safeAreaBlocked = pveSafeAreaBlocked(targetIsPlayer)
    end

    if comboEnabled then
      local comboTarget = targetIsCreature and target or nil
      if tryPveCombo(tm, vocation, comboTarget, myPos, mobs, summonFound, safeAreaBlocked) then return end
    end

    -- MS/ED podem usar gran mas vis/tera mesmo antes do target ser definido pelo targetbot.
    if vocation == "sorcerer" or vocation == "druid" then
      local pveTarget = targetIsCreature and target or nil
      if tryMsEdOffense(tm, vocation, pveTarget, myPos, mobs, summonFound, "pve", safeAreaBlocked) then return end
    else
      if vocation == "paladin" then
        local rpTarget = targetIsCreature and target or nil
        if tryRpOffense(tm, rpTarget, myPos, mobs, "pve", safeAreaBlocked) then return end
      elseif vocation == "knight" then
        if not targetIsCreature then return end
        if tryEkOffense(tm, target, myPos, mobs, "pve", safeAreaBlocked) then return end
      end
    end
  end

  if aoeIsOn("enableDebug", false) and tm >= lastDebug then
    lastDebug = tm + 30000
    ensureScan()
    warn("Holiday V19.1 | modo=" .. mode .. " | voc=" .. vocation .. " | mobs=" .. tostring(#mobs) .. " | targetPlayer=" .. tostring(targetIsPlayer))
  end
end)

-- ============================================================
-- 9) AUTO ACCEPT PARTY MANTIDO, SEM DELAY BLOQUEANTE
-- ============================================================

setDefaultTab("Tools")
UI.Separator()

local nextPartyAccept = 0
macro(1000, function()
  if not player then return end
  local tm = nowMs()
  if tm < nextPartyAccept then return end
  if player.getShield and player:getShield() > 2 then return end

  local spectators = getSpectatorsSafe()
  if not spectators then return end

  for _, spec in ipairs(spectators) do
    if spec and spec.isPlayer and spec:isPlayer() and spec.getShield and spec:getShield() == 1 then
      if g_game and g_game.partyJoin and spec.getId then
        g_game.partyJoin(spec:getId())
        nextPartyAccept = tm + 1000
      end
      return
    end
  end
end)
