# NodeJS BotServer

A modular and extensible BotServer server inspired by [otcv8botserver](https://github.com/OTCv8/otcv8botserver), built with Node.js.

---
### 🧩 Features

- 📡 WebSocket interface for real-time bot communication  
- 🌐 Optional HTTP web UI for monitoring  
- 🧱 Modular architecture (drop plugins in `/modules`)  
- 🪵 Auto file logging to `logs/output.log`  
- 🧠 Auto-install missing dependencies  
- 🔌 Built-in plugin hook system (WS + lifecycle)
---


### 📦 Requirements

- [Node.js](https://nodejs.org/)

---

### 🧩 Plugins

See [Plugin Documentation](docs/plugins.md) for a list of available modules.

![Plugins](assets/plugins-badge.svg)

---

### 🔗 Links

- 🌐 [Website](https://www.trainorcreations.com)
- 💬 [Discord](https://trainorcreations.com/discord)
- 💖 [Donate](https://trainorcreations.com/donate)

---

## ⚙️ Setup

1. **Download & Install Node.js**
   - Install it from [nodejs.org](https://nodejs.org/)

2. **Run the Server**
   - Launch `start-server.bat`
   - Automatically installs dependencies on first run

3. **Logging**
   - All console output (stdout & errors) is logged to `logs/output.log`
   - Colors are stripped from log files for clean reading

> 💡 **Optional:**  
> Don’t want a module/plugin?
> - Disable the web interface: rename `modules/server/http.js` → `modules/server/http.js.disabled`  
> or
> - Modify the meta data at the bottom of the module to enabled: true/false

---

### 🤖 vBot Integration

1. Open `_Loader.lua`
2. Add the following at the top:
   ```lua
   BotServer.url = "ws://localhost:8080/" -- add this line
   -- load all otui files, order doesn't matter
   ```
### 📤 Sending Character Info (Lua)

To allow the server to register your character data, you can send character information from your bot using a Lua script.

Add the following to your bot script (e.g., inside a Macro):
   ```lua
   macro(10000, "Send Char Info", function()
     if not BotServer._websocket then return end
   
     BotServer.send("char_info", {
       name       = player:getName(),
       level      = player:getLevel(),
       vocation   = player:getVocation(),
       health     = player:getHealth(),
       maxHealth  = player:getMaxHealth(),
       mana       = player:getMana(),
       maxMana    = player:getMaxMana(),
       experience = player:getExperience(),
       expPercent = player:getLevelPercent(),
       location   = pos() and string.format("%d, %d, %d", pos().x, pos().y, pos().z)
     })
   end)
   ```

## Web UI

![Web UI Preview](assets/web-ui-preview.png)

## WebSocket Terminal View

![WebSocket Terminal](assets/ws-terminal.preview.png)
