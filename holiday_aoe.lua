-- Holiday AOE public bridge.
-- Compatibilidade: clientes antigos que ainda carregam este arquivo agora abrem
-- apenas o Derpetson Scripts, onde todos os produtos ficam em uma aba unica.

local JQM_MANAGER_URL = "https://jequimultiassessoria.com.br/license_server/manager.lua?v=2026061213"

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
  if type(jqmGlobal.JQMOpenManager) == "function" then
    jqmGlobal.JQMOpenManager()
    return
  end
  if jqmGlobal.JQMScriptManagerBootstrapLoading == true then return end
  jqmGlobal.JQMScriptManagerBootstrapLoading = true

  jqmHttpGet(JQM_MANAGER_URL, function(data, err)
    jqmGlobal.JQMScriptManagerBootstrapLoading = false
    if err or type(data) ~= "string" or data == "" then
      jqmWarn("falha ao carregar central: " .. tostring(err or "sem dados"))
      return
    end

    local loader = loadstring or load
    if not loader then
      jqmWarn("loadstring/load indisponivel neste OTC")
      return
    end

    local fn, loadErr = loader(data, "@jqm_script_manager.lua")
    if not fn then
      jqmWarn("central invalida: " .. tostring(loadErr))
      return
    end

    local ok, runErr = pcall(fn)
    if not ok then
      jqmWarn("erro na central: " .. tostring(runErr))
      return
    end
    jqmWarn("central Derpetson carregada")
  end)
end

jqmLoadManager()
