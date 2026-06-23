module.exports = async ({ config, utils, state }) => {
    const express = require('express');
    const path = require('path');
    const http = require('http');
    const fs = require('fs');
    const crypto = require('crypto');
    const { createOtmmMinimapService } = require('./otmm-minimap');
    const apiRouter = express.Router();

    const app = express();
    const httpServer = http.createServer(app);
    state.httpApp = app;
    state.httpServer = httpServer;

    app.use(express.urlencoded({ extended: false }));
    app.use(express.json());

    app.use((req, res, next) => {
        if (req.path === '/') state.httpAllowedRequests++;
        next();
    });

    const publicPath = path.join(process.cwd(), 'public');
    const minimap = createOtmmMinimapService({
        filePath: path.join(publicPath, 'minimap854.otmm')
    });

    const tierDataFile = path.join(process.cwd(), 'data', 'tier-orbs.json');
    const tierSaveDelayMs = 500;
    let tierSaveTimer = null;

    const defaultDepotAreas = [
        { name: 'DP', x1: 54701, y1: 54762, z1: 7, x2: 54713, y2: 54772, z2: 7 },
        { name: 'DP 8', x1: 54701, y1: 54762, z1: 8, x2: 54713, y2: 54772, z2: 8 },
        {
            name: 'Barco DP',
            z: 6,
            points: [
                { x: 54683, y: 54773 },
                { x: 54684, y: 54767 },
                { x: 54697, y: 54767 },
                { x: 54698, y: 54763 },
                { x: 54693, y: 54763 },
                { x: 54693, y: 54765 },
                { x: 54684, y: 54765 },
                { x: 54683, y: 54760 },
                { x: 54682, y: 54758 },
                { x: 54679, y: 54758 },
                { x: 54676, y: 54760 },
                { x: 54675, y: 54773 }
            ]
        }
    ];

    const navDivisionAreas = [
        { name: 'LIMITACAO MAPA', x1: 54617, y1: 54728, z1: 0, x2: 54847, y2: 54940, z2: 15, anyZ: true }
    ];

    const navDivisionAreasText = 'LIMITACAO MAPA: 54617,54728,0,54847,54940,15';

    const defaultEventAreas = navDivisionAreas;
    const wolfHeatmapFloor = 7;
    const wolfHeatmapBucketSize = 5;

    function heatBucketValue(value) {
        return Math.floor(Number(value) / wolfHeatmapBucketSize) * wolfHeatmapBucketSize;
    }

    function heatBucketCenter(value) {
        return heatBucketValue(value) + Math.floor(wolfHeatmapBucketSize / 2);
    }

    function emptyTierData() {
        return {
            version: 1,
            settings: {
                eventAreasText: navDivisionAreasText,
                depotAreasText: '',
                eventAreas: defaultEventAreas,
                depotAreas: defaultDepotAreas
            },
            receivers: {},
            receiverGroups: {},
            receiverTotals: {},
            receiverCredits: {},
            participants: {},
            orbReports: {},
            playerSettings: {},
            leaders: {},
            collection: null,
            collections: [],
            deaths: [],
            days: {},
            leftoversTotal: 0,
            latestWolf: null,
            latestWolfDeath: null,
            latestWolfLoot: null
        };
    }

    function ensureTierData() {
        if (!state.tierOrbs) {
            state.tierOrbs = emptyTierData();
        }
        state.tierOrbs.settings = state.tierOrbs.settings || {};
        state.tierOrbs.receivers = state.tierOrbs.receivers || {};
        state.tierOrbs.receiverGroups = state.tierOrbs.receiverGroups || {};
        state.tierOrbs.receiverTotals = state.tierOrbs.receiverTotals || {};
        state.tierOrbs.receiverCredits = state.tierOrbs.receiverCredits || {};
        for (const [receiver, total] of Object.entries(state.tierOrbs.receiverTotals || {})) {
            if (state.tierOrbs.receiverCredits[receiver] === undefined) {
                state.tierOrbs.receiverCredits[receiver] = Number(total) || 0;
            }
        }
        for (const [receiver, credit] of Object.entries(state.tierOrbs.receiverCredits || {})) {
            state.tierOrbs.receiverTotals[receiver] = wholeCredit(credit);
        }
        state.tierOrbs.participants = state.tierOrbs.participants || {};
        state.tierOrbs.orbReports = state.tierOrbs.orbReports || {};
        state.tierOrbs.playerSettings = state.tierOrbs.playerSettings || {};
        state.tierOrbs.leaders = state.tierOrbs.leaders || {};
        state.tierOrbs.collections = Array.isArray(state.tierOrbs.collections) ? state.tierOrbs.collections : [];
        state.tierOrbs.collection = state.tierOrbs.collection || {
            id: 'legacy',
            startedAt: 0,
            startedAtText: 'Historico anterior',
            startedBy: 'BotServer'
        };
        state.tierOrbs.deaths = Array.isArray(state.tierOrbs.deaths) ? state.tierOrbs.deaths : [];
        state.tierOrbs.days = state.tierOrbs.days || {};
        state.tierOrbs.leftoversTotal = Number(state.tierOrbs.leftoversTotal) || 0;
        state.tierOrbs.latestWolfDeath = state.tierOrbs.latestWolfDeath || null;
        state.tierOrbs.latestWolfLoot = state.tierOrbs.latestWolfLoot || null;
        if (!Array.isArray(state.tierOrbs.settings.eventAreas) || state.tierOrbs.settings.eventAreas.length === 0) {
            state.tierOrbs.settings.eventAreas = defaultEventAreas;
        }
        if (
            String(state.tierOrbs.settings.eventAreasText || '').trim() === 'LIMITACAO MAPA: 54617,54728,7,54847,54940,7'
            || (
                state.tierOrbs.settings.eventAreas.length === 1
                && Number(state.tierOrbs.settings.eventAreas[0]?.x1) === 54617
                && Number(state.tierOrbs.settings.eventAreas[0]?.y1) === 54728
                && Number(state.tierOrbs.settings.eventAreas[0]?.x2) === 54847
                && Number(state.tierOrbs.settings.eventAreas[0]?.y2) === 54940
                && Number(state.tierOrbs.settings.eventAreas[0]?.z1) === 7
                && Number(state.tierOrbs.settings.eventAreas[0]?.z2) === 7
            )
        ) {
            state.tierOrbs.settings.eventAreasText = navDivisionAreasText;
            state.tierOrbs.settings.eventAreas = defaultEventAreas;
        }
        if (!state.tierOrbs.settings.eventAreasText) {
            state.tierOrbs.settings.eventAreasText = navDivisionAreasText;
        }
        if (!Array.isArray(state.tierOrbs.settings.depotAreas)) state.tierOrbs.settings.depotAreas = defaultDepotAreas;
        for (const receiver of Object.values(state.tierOrbs.receivers || {})) {
            const name = normalizeName(receiver);
            if (name && !state.tierOrbs.receiverGroups[name]) {
                state.tierOrbs.receiverGroups[name] = { name, createdAt: Date.now(), updatedAt: Date.now() };
            }
        }
        return state.tierOrbs;
    }

    function loadTierData() {
        try {
            if (fs.existsSync(tierDataFile)) {
                state.tierOrbs = JSON.parse(fs.readFileSync(tierDataFile, 'utf8'));
            }
        } catch (error) {
            utils.log.warn(`Tier Orbs data load failed: ${error.message}`);
        }
        ensureTierData();
    }

    function saveTierData() {
        const data = ensureTierData();
        fs.mkdirSync(path.dirname(tierDataFile), { recursive: true });
        fs.writeFileSync(tierDataFile, JSON.stringify(data, null, 2));
    }

    function scheduleTierSave() {
        clearTimeout(tierSaveTimer);
        tierSaveTimer = setTimeout(() => {
            try {
                saveTierData();
            } catch (error) {
                utils.log.warn(`Tier Orbs data save failed: ${error.message}`);
            }
        }, tierSaveDelayMs);
    }

    loadTierData();

    const authCookieName = 'botserver_session';
    const dashboardUsersFile = path.join(process.cwd(), 'data', 'dashboard-users.json');
    const dashboardPasswordIterations = 120000;
    let dashboardUsersData = null;

    function dashboardAuthEnabled() {
        return config.DASHBOARD_AUTH_ENABLED !== false;
    }

    function dashboardUser() {
        return String(config.DASHBOARD_USERNAME || process.env.BOTSERVER_DASHBOARD_USER || 'admin');
    }

    function dashboardPassword() {
        return String(config.DASHBOARD_PASSWORD || process.env.BOTSERVER_DASHBOARD_PASSWORD || '@Senha123');
    }

    function dashboardSecret() {
        return String(config.DASHBOARD_SESSION_SECRET || process.env.BOTSERVER_DASHBOARD_SECRET || 'botserver-local-session-secret');
    }

    function emptyDashboardUsersData() {
        return {
            version: 1,
            users: {}
        };
    }

    function normalizeDashboardUsername(value) {
        return String(value ?? '').trim().toLowerCase();
    }

    function cleanDashboardRole(value) {
        return String(value || '').toLowerCase() === 'admin' ? 'admin' : 'user';
    }

    function boolDashboardValue(value, defaultValue = false) {
        if (value === undefined || value === null || value === '') return defaultValue;
        return value === true || value === 1 || value === '1' || value === 'true' || value === 'yes' || value === 'on';
    }

    function loadDashboardUsersData() {
        if (dashboardUsersData) return dashboardUsersData;
        dashboardUsersData = emptyDashboardUsersData();
        try {
            if (fs.existsSync(dashboardUsersFile)) {
                const parsed = JSON.parse(fs.readFileSync(dashboardUsersFile, 'utf8'));
                if (parsed && typeof parsed === 'object') {
                    dashboardUsersData = {
                        version: 1,
                        users: parsed.users && typeof parsed.users === 'object' ? parsed.users : {}
                    };
                }
            }
        } catch (error) {
            utils.log.warn(`Dashboard users load failed: ${error.message}`);
        }
        return dashboardUsersData;
    }

    function saveDashboardUsersData() {
        const data = loadDashboardUsersData();
        fs.mkdirSync(path.dirname(dashboardUsersFile), { recursive: true });
        fs.writeFileSync(dashboardUsersFile, JSON.stringify(data, null, 2));
    }

    function hashDashboardPassword(password, salt = crypto.randomBytes(16).toString('hex'), iterations = dashboardPasswordIterations) {
        const digest = 'sha256';
        return {
            salt,
            iterations,
            digest,
            passwordHash: crypto.pbkdf2Sync(String(password), salt, iterations, 32, digest).toString('hex')
        };
    }

    function verifyDashboardPassword(password, user) {
        if (!user?.salt || !user?.passwordHash) return false;
        const iterations = Number(user.iterations) || dashboardPasswordIterations;
        const digest = user.digest || 'sha256';
        const hash = crypto.pbkdf2Sync(String(password), user.salt, iterations, 32, digest).toString('hex');
        return safeCompare(hash, user.passwordHash);
    }

    function isConfigDashboardAdmin(username) {
        return normalizeDashboardUsername(username) === normalizeDashboardUsername(dashboardUser());
    }

    function findDashboardUser(username) {
        const data = loadDashboardUsersData();
        return data.users[normalizeDashboardUsername(username)] || null;
    }

    function publicDashboardUser(user, extra = {}) {
        return {
            username: user.username,
            role: cleanDashboardRole(user.role),
            active: user.active !== false,
            source: user.source || 'local',
            protected: Boolean(user.protected),
            createdAt: user.createdAt || null,
            updatedAt: user.updatedAt || null,
            createdBy: user.createdBy || null,
            lastLoginAt: user.lastLoginAt || null,
            ...extra
        };
    }

    function dashboardUsersSnapshot() {
        const data = loadDashboardUsersData();
        const configAdmin = publicDashboardUser({
            username: dashboardUser(),
            role: 'admin',
            active: true,
            source: 'config',
            protected: true
        });

        const users = Object.values(data.users || {})
            .filter(user => user && normalizeDashboardUsername(user.username))
            .map(user => publicDashboardUser(user))
            .sort((a, b) => a.username.localeCompare(b.username));

        return [configAdmin, ...users];
    }

    function validateDashboardUserInput(username, password, passwordRequired = true) {
        const clean = normalizeDashboardUsername(username);
        if (!/^[a-z0-9_.-]{3,32}$/.test(clean)) {
            const error = new Error('Usuario deve ter 3-32 caracteres: letras, numeros, ponto, hifen ou underline.');
            error.statusCode = 400;
            throw error;
        }
        if (isConfigDashboardAdmin(clean)) {
            const error = new Error('O admin principal e configurado no servidor.');
            error.statusCode = 400;
            throw error;
        }
        if (passwordRequired && String(password || '').length < 6) {
            const error = new Error('Senha deve ter pelo menos 6 caracteres.');
            error.statusCode = 400;
            throw error;
        }
        return clean;
    }

    function authenticateDashboardUser(username, password) {
        const clean = normalizeDashboardUsername(username);
        if (!clean) return null;

        if (isConfigDashboardAdmin(clean) && safeCompare(password, dashboardPassword())) {
            return {
                username: dashboardUser(),
                role: 'admin',
                source: 'config',
                protected: true
            };
        }

        const data = loadDashboardUsersData();
        const user = data.users[clean];
        if (!user || user.active === false || !verifyDashboardPassword(password, user)) return null;

        user.lastLoginAt = Date.now();
        user.updatedAt = user.updatedAt || user.createdAt || Date.now();
        saveDashboardUsersData();
        return publicDashboardUser(user);
    }

    function parseCookies(req) {
        const cookies = {};
        for (const part of String(req.headers.cookie || '').split(';')) {
            const index = part.indexOf('=');
            if (index === -1) continue;
            const key = part.slice(0, index).trim();
            const value = part.slice(index + 1).trim();
            if (key) cookies[key] = decodeURIComponent(value);
        }
        return cookies;
    }

    function safeCompare(a, b) {
        const left = Buffer.from(String(a));
        const right = Buffer.from(String(b));
        return left.length === right.length && crypto.timingSafeEqual(left, right);
    }

    function signSession(user, issuedAt) {
        return crypto
            .createHmac('sha256', dashboardSecret())
            .update(`${user}.${issuedAt}`)
            .digest('hex');
    }

    function createSessionValue(user) {
        const issuedAt = Date.now();
        return Buffer.from(JSON.stringify({
            user,
            issuedAt,
            sig: signSession(user, issuedAt)
        })).toString('base64url');
    }

    function currentDashboardUser(req) {
        if (!dashboardAuthEnabled()) {
            return {
                username: 'local',
                role: 'admin',
                source: 'disabled',
                protected: true
            };
        }
        try {
            const raw = parseCookies(req)[authCookieName];
            if (!raw) return null;
            const data = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8'));
            const user = String(data.user || '');
            const issuedAt = Number(data.issuedAt) || 0;
            const maxAgeMs = 12 * 60 * 60 * 1000;
            if (!user || !issuedAt || Date.now() - issuedAt > maxAgeMs) return null;
            if (!safeCompare(data.sig || '', signSession(user, issuedAt))) return null;
            if (isConfigDashboardAdmin(user)) {
                return {
                    username: dashboardUser(),
                    role: 'admin',
                    source: 'config',
                    protected: true
                };
            }

            const saved = findDashboardUser(user);
            if (!saved || saved.active === false) return null;
            return publicDashboardUser(saved);
        } catch {
            return null;
        }
    }

    function verifySession(req) {
        return Boolean(currentDashboardUser(req));
    }

    function requireDashboardAdmin(req, res) {
        const authUser = currentDashboardUser(req);
        if (!authUser) {
            res.status(401).json({ ok: false, error: 'Login required' });
            return null;
        }
        if (authUser.role !== 'admin') {
            res.status(403).json({ ok: false, error: 'Admin required' });
            return null;
        }
        return authUser;
    }

    function isPublicClientAsset(req) {
        return req.path === '/login'
            || req.path === '/logout'
            || req.path === '/favicon.ico'
            || req.path.startsWith('/botserver/');
    }

    function cookieFlags(req) {
        const secure = req.secure || req.headers['x-forwarded-proto'] === 'https';
        return `HttpOnly; SameSite=Lax; Path=/; Max-Age=${12 * 60 * 60}${secure ? '; Secure' : ''}`;
    }

    function loginHtml(error = '') {
        return `<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>BotServer Login</title>
  <style>
    body{margin:0;min-height:100vh;display:grid;place-items:center;background:#eef2f6;font-family:Arial,sans-serif;color:#1f2933}
    form{width:min(360px,calc(100vw - 32px));background:#fff;border:1px solid #d7dee8;border-radius:8px;padding:24px;box-shadow:0 12px 32px rgba(16,24,40,.12)}
    h1{font-size:22px;margin:0 0 18px}
    label{display:block;font-size:13px;font-weight:700;margin-top:14px}
    input{box-sizing:border-box;width:100%;height:38px;margin-top:6px;border:1px solid #bcc7d5;border-radius:4px;padding:8px 10px;font-size:14px}
    button{width:100%;height:38px;margin-top:18px;border:0;border-radius:4px;background:#0f7f3d;color:#fff;font-weight:800;cursor:pointer}
    .error{min-height:18px;color:#b42318;font-size:13px;margin-top:10px}
  </style>
</head>
<body>
  <form method="post" action="/login" autocomplete="off">
    <h1>BotServer Dashboard</h1>
    <label>Usuario<input name="username" required autofocus></label>
    <label>Senha<input name="password" type="password" required></label>
    <button type="submit">Entrar</button>
    <div class="error">${error ? String(error).replace(/[&<>"]/g, '') : ''}</div>
  </form>
</body>
</html>`;
    }

    app.get('/login', (req, res) => {
        if (verifySession(req)) return res.redirect('/');
        res.setHeader('Cache-Control', 'no-store');
        res.type('html').send(loginHtml(req.query.error ? 'Login invalido' : ''));
    });

    app.post('/login', (req, res) => {
        const username = String(req.body?.username || '');
        const password = String(req.body?.password || '');
        const authUser = authenticateDashboardUser(username, password);
        if (authUser) {
            res.setHeader('Set-Cookie', `${authCookieName}=${encodeURIComponent(createSessionValue(authUser.username))}; ${cookieFlags(req)}`);
            return res.redirect('/');
        }
        state.httpBlockedRequests++;
        return res.redirect('/login?error=1');
    });

    app.get('/logout', (req, res) => {
        res.setHeader('Set-Cookie', `${authCookieName}=; HttpOnly; SameSite=Lax; Path=/; Max-Age=0`);
        res.redirect('/login');
    });

    app.use((req, res, next) => {
        if (
            req.path === '/' ||
            req.path === '/index.html' ||
            req.path === '/script.js' ||
            req.path === '/style.css'
        ) {
            res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
            res.setHeader('Pragma', 'no-cache');
            res.setHeader('Expires', '0');
        }
        next();
    });

    app.use((req, res, next) => {
        if (isPublicClientAsset(req) || verifySession(req)) return next();
        state.httpBlockedRequests++;
        if (req.path.startsWith('/api/')) {
            return res.status(401).json({ ok: false, error: 'Login required' });
        }
        return res.redirect('/login');
    });

    app.use(express.static(publicPath));

    function normalizePosition(value) {
        if (!value) return null;

        if (typeof value === 'object') {
            const x = Number(value.x ?? value[0]);
            const y = Number(value.y ?? value[1]);
            const z = Number(value.z ?? value[2]);
            if (Number.isFinite(x) && Number.isFinite(y) && Number.isFinite(z)) {
                return { x: Math.floor(x), y: Math.floor(y), z: Math.floor(z) };
            }
        }

        if (typeof value === 'string') {
            const match = value.match(/(-?\d+)\D+(-?\d+)\D+(-?\d+)/);
            if (match) {
                return {
                    x: Number(match[1]),
                    y: Number(match[2]),
                    z: Number(match[3])
                };
            }
        }

        return null;
    }

    function getPayloadPosition(payload) {
        return normalizePosition(payload?.position)
            || normalizePosition(payload?.pos)
            || normalizePosition(payload?.location)
            || normalizePosition({ x: payload?.x, y: payload?.y, z: payload?.z });
    }

    function formatPosition(position) {
        return position ? `${position.x}, ${position.y}, ${position.z}` : 'Unknown';
    }

    function normalizeName(value) {
        return String(value ?? '').trim();
    }

    function normalizeKey(value) {
        return normalizeName(value).toLowerCase();
    }

    function boolValue(value) {
        return value === true || value === 1 || value === '1' || value === 'true' || value === 'yes';
    }

    function pad2(value) {
        return String(value).padStart(2, '0');
    }

    function dayKey(date = new Date()) {
        const d = new Date(date);
        return `${pad2(d.getDate())}/${pad2(d.getMonth() + 1)}/${d.getFullYear()}`;
    }

    function timeLabel(date = new Date()) {
        const d = new Date(date);
        return `${pad2(d.getHours())}:${pad2(d.getMinutes())}:${pad2(d.getSeconds())}`;
    }

    function parseAreaLine(line, index) {
        const raw = String(line || '').trim();
        if (!raw) return null;

        const nameMatch = raw.match(/^([^:|=]+)[:|=]\s*(.+)$/);
        const name = nameMatch ? nameMatch[1].trim() : `Area ${index + 1}`;
        const body = nameMatch ? nameMatch[2] : raw;
        const numbers = Array.from(body.matchAll(/-?\d+/g)).map(match => Number(match[0]));

        if (numbers.length >= 6) {
            return {
                name,
                x1: numbers[0],
                y1: numbers[1],
                z1: numbers[2],
                x2: numbers[3],
                y2: numbers[4],
                z2: numbers[5]
            };
        }

        return null;
    }

    function parseAreasText(text) {
        return String(text || '')
            .split(/\r?\n|;/)
            .map(parseAreaLine)
            .filter(Boolean);
    }

    function areaIgnoresFloor(area) {
        return area?.anyZ === true || String(area?.name || '').toLowerCase().includes('limitacao mapa');
    }

    function pointInPolygon(pos, area) {
        if (!area || !Array.isArray(area.points) || area.points.length < 3) return false;
        if (!areaIgnoresFloor(area) && Number.isFinite(Number(area.z)) && Number(area.z) !== Number(pos.z)) return false;

        let inside = false;
        let j = area.points.length - 1;

        for (let i = 0; i < area.points.length; i++) {
            const a = area.points[i];
            const b = area.points[j];
            const ax = Number(a.x);
            const ay = Number(a.y);
            const bx = Number(b.x);
            const by = Number(b.y);

            const cross = (pos.y - ay) * (bx - ax) - (pos.x - ax) * (by - ay);
            const onSegment = cross === 0
                && pos.x >= Math.min(ax, bx)
                && pos.x <= Math.max(ax, bx)
                && pos.y >= Math.min(ay, by)
                && pos.y <= Math.max(ay, by);
            if (onSegment) return true;

            if ((ay > pos.y) !== (by > pos.y)) {
                const intersectX = ((bx - ax) * (pos.y - ay)) / (by - ay) + ax;
                if (pos.x < intersectX) inside = !inside;
            }

            j = i;
        }

        return inside;
    }

    function positionInArea(pos, area) {
        if (!pos || !area) return false;
        if (Array.isArray(area.points)) return pointInPolygon(pos, area);

        const x1 = Number(area.x1);
        const x2 = Number(area.x2);
        const y1 = Number(area.y1);
        const y2 = Number(area.y2);
        const z1 = Number(area.z1);
        const z2 = Number(area.z2);
        const anyZ = areaIgnoresFloor(area);
        if (![x1, x2, y1, y2].every(Number.isFinite)) return false;
        if (!anyZ && ![z1, z2].every(Number.isFinite)) return false;

        return pos.x >= Math.min(x1, x2)
            && pos.x <= Math.max(x1, x2)
            && pos.y >= Math.min(y1, y2)
            && pos.y <= Math.max(y1, y2)
            && (anyZ || (
                pos.z >= Math.min(z1, z2)
                && pos.z <= Math.max(z1, z2)
            ));
    }

    function positionInAnyArea(pos, areas) {
        return Array.isArray(areas) && areas.some(area => positionInArea(pos, area));
    }

    function getOnlineNames() {
        const names = new Set();
        for (const clients of Object.values(state.channels || {})) {
            for (const ws of clients) {
                const name = normalizeName(ws.userData?.name);
                if (name) names.add(normalizeKey(name));
            }
        }
        return names;
    }

    function ensureTierDay(key = dayKey()) {
        const tier = ensureTierData();
        tier.days[key] = tier.days[key] || {
            events: [],
            orbs: 0,
            leftovers: 0,
            deaths: 0
        };
        return tier.days[key];
    }

    function addTierEvent(type, text, extra = {}) {
        const tier = ensureTierData();
        const at = Date.now();
        const key = dayKey(at);
        const day = ensureTierDay(key);
        const event = {
            id: `${at}-${Math.random().toString(36).slice(2, 8)}`,
            type,
            day: key,
            time: timeLabel(at),
            at,
            text,
            ...extra
        };
        day.events.unshift(event);
        day.events = day.events.slice(0, 500);
        scheduleTierSave();
        return event;
    }

    function creditNumber(value) {
        const number = Number(value);
        if (!Number.isFinite(number)) return 0;
        return Math.max(0, number);
    }

    function roundCredit(value) {
        return Math.round(creditNumber(value) * 10000) / 10000;
    }

    function wholeCredit(value) {
        return Math.floor(creditNumber(value) + 1e-9);
    }

    function decimalCredit(value) {
        const credit = creditNumber(value);
        return roundCredit(credit - wholeCredit(credit));
    }

    function rowCreditValue(row) {
        if (!row) return 0;
        if (row.credit !== undefined) return creditNumber(row.credit);
        if (row.creditPerReceiver !== undefined) return creditNumber(row.creditPerReceiver);
        return creditNumber(row.share);
    }

    function totalRegisteredOrbs(tier) {
        return (tier.deaths || []).reduce((sum, death) => sum + (Number(death.orbs) || 0), 0);
    }

    function wholePayableTotal(tier) {
        return Object.values(tier.receiverCredits || {})
            .reduce((sum, value) => sum + wholeCredit(value), 0);
    }

    function technicalLeftoverTotal(tier) {
        return Math.max(0, totalRegisteredOrbs(tier) - wholePayableTotal(tier));
    }

    function receiverCreditTotalsForDay(tier, key = dayKey()) {
        const totals = {};
        for (const death of tier.deaths || []) {
            if (death.day !== key) continue;
            for (const row of death.receivers || []) {
                const receiver = normalizeName(row.receiver);
                if (!receiver) continue;
                totals[receiver] = roundCredit((totals[receiver] || 0) + rowCreditValue(row));
            }
        }
        return totals;
    }

    function technicalLeftoverForDay(tier, key = dayKey()) {
        const day = tier.days?.[key] || {};
        const credits = receiverCreditTotalsForDay(tier, key);
        const whole = Object.values(credits).reduce((sum, value) => sum + wholeCredit(value), 0);
        return Math.max(0, (Number(day.orbs) || 0) - whole);
    }

    function collectionTotals(tier) {
        return {
            deaths: Array.isArray(tier.deaths) ? tier.deaths.length : 0,
            orbs: totalRegisteredOrbs(tier),
            wholeOrbs: wholePayableTotal(tier),
            leftovers: technicalLeftoverTotal(tier),
            reports: Object.keys(tier.orbReports || {}).length
        };
    }

    function summarizeTierCollection(tier) {
        const totals = collectionTotals(tier);
        if (!totals.deaths && !totals.orbs && !totals.leftovers && !totals.reports) return null;

        const nowMs = Date.now();
        return {
            ...(tier.collection || {}),
            endedAt: nowMs,
            endedAtText: utils.formatTimestamp(nowMs),
            totals,
            latestDeath: Array.isArray(tier.deaths) ? tier.deaths[0] || null : null
        };
    }

    function startTierOrbCollection(payload = {}) {
        const tier = ensureTierData();
        const previous = summarizeTierCollection(tier);
        if (previous) {
            tier.collections.unshift(previous);
            tier.collections = tier.collections.slice(0, 50);
        }

        const at = Date.now();
        const startedBy = normalizeName(payload.startedBy || payload.sourceCharacter || payload.character || payload.name) || 'BotServer';
        tier.collection = {
            id: `${at}-${Math.random().toString(36).slice(2, 8)}`,
            startedAt: at,
            startedAtText: utils.formatTimestamp(at),
            startedBy,
            note: normalizeName(payload.note)
        };
        tier.receiverTotals = {};
        tier.receiverCredits = {};
        tier.orbReports = {};
        tier.deaths = [];
        tier.days = {};
        tier.leftoversTotal = 0;
        tier.latestWolf = null;
        tier.latestWolfDeath = null;
        tier.latestWolfLoot = null;

        rebuildTierParticipants(false);
        addTierEvent('collection', `Coleta de Tier Orb iniciada por ${startedBy}.`, {
            collectionId: tier.collection.id,
            character: startedBy
        });
        scheduleTierSave();
        return tier.collection;
    }

    function receiverFor(characterName) {
        const tier = ensureTierData();
        const name = normalizeName(characterName);
        return normalizeName(tier.receivers[name]) || name;
    }

    function playerSettingsFor(characterName) {
        const tier = ensureTierData();
        const name = normalizeName(characterName);
        if (!name) return {};
        const leader = leaderFor(name);
        if (tier.playerSettings[name]) {
            const saved = tier.playerSettings[name];
            const leaderValue = saved.leader === undefined ? leader?.active : saved.leader;
            return {
                ...saved,
                leader: boolValue(leaderValue),
                highlighted: boolValue(saved.highlighted === undefined ? leaderValue : saved.highlighted),
                caller: boolValue(saved.caller),
                leaderRegistered: Boolean(leader),
                leaderNote: leader?.note || ''
            };
        }
        const key = normalizeKey(name);
        const found = Object.keys(tier.playerSettings || {}).find(saved => normalizeKey(saved) === key);
        if (found) {
            const saved = tier.playerSettings[found];
            const leaderValue = saved.leader === undefined ? leader?.active : saved.leader;
            return {
                ...saved,
                leader: boolValue(leaderValue),
                highlighted: boolValue(saved.highlighted === undefined ? leaderValue : saved.highlighted),
                caller: boolValue(saved.caller),
                leaderRegistered: Boolean(leader),
                leaderNote: leader?.note || ''
            };
        }
        if (leader) {
            return {
                leader: leader.active,
                highlighted: leader.active,
                caller: false,
                leaderRegistered: true,
                leaderNote: leader.note || ''
            };
        }
        return {};
    }

    function leaderFor(characterName) {
        const tier = ensureTierData();
        const name = normalizeName(characterName);
        if (!name) return null;
        if (tier.leaders[name]) return tier.leaders[name];
        const key = normalizeKey(name);
        const found = Object.keys(tier.leaders || {}).find(saved => normalizeKey(saved) === key);
        return found ? tier.leaders[found] : null;
    }

    function upsertLeader(characterName, options = {}) {
        const tier = ensureTierData();
        const name = normalizeName(characterName);
        if (!name) return null;
        const stateName = Object.keys(state.guildLocations || {}).find(saved => normalizeKey(saved) === normalizeKey(name))
            || Object.keys(state.characters || {}).find(saved => normalizeKey(saved) === normalizeKey(name))
            || name;
        const existingName = Object.keys(tier.leaders || {}).find(saved => normalizeKey(saved) === normalizeKey(name));
        const key = existingName || stateName;
        const previous = tier.leaders[key] || {};
        const active = options.active === undefined ? boolValue(previous.active) : boolValue(options.active);
        const note = options.note === undefined ? normalizeName(previous.note) : normalizeName(options.note);
        const nowMs = Date.now();

        if (existingName && existingName !== stateName) delete tier.leaders[existingName];

        tier.leaders[stateName] = {
            ...previous,
            name: stateName,
            active,
            note,
            createdAt: previous.createdAt || nowMs,
            updatedAt: nowMs
        };

        tier.playerSettings[stateName] = {
            ...(tier.playerSettings[stateName] || {}),
            leader: active,
            highlighted: active,
            updatedAt: nowMs
        };

        if (state.guildLocations?.[stateName]) {
            state.guildLocations[stateName].leader = active;
            state.guildLocations[stateName].highlighted = active;
            state.guildLocations[stateName].leaderRegistered = true;
            state.guildLocations[stateName].leaderNote = note;
        }
        if (state.characters?.[stateName]) {
            state.characters[stateName].leader = active;
            state.characters[stateName].highlighted = active;
            state.characters[stateName].leaderRegistered = true;
            state.characters[stateName].leaderNote = note;
        }

        scheduleTierSave();
        return tier.leaders[stateName];
    }

    function removeLeader(characterName) {
        const tier = ensureTierData();
        const name = normalizeName(characterName);
        if (!name) return null;
        const existingName = Object.keys(tier.leaders || {}).find(saved => normalizeKey(saved) === normalizeKey(name));
        if (!existingName) return null;
        const removed = tier.leaders[existingName];
        delete tier.leaders[existingName];

        const settings = tier.playerSettings[existingName] || tier.playerSettings[name];
        if (settings) {
            settings.leader = false;
            settings.highlighted = false;
            settings.updatedAt = Date.now();
            tier.playerSettings[existingName] = settings;
        }
        if (state.guildLocations?.[existingName]) {
            state.guildLocations[existingName].leader = false;
            state.guildLocations[existingName].highlighted = false;
            state.guildLocations[existingName].leaderRegistered = false;
            state.guildLocations[existingName].leaderNote = '';
        }
        if (state.characters?.[existingName]) {
            state.characters[existingName].leader = false;
            state.characters[existingName].highlighted = false;
            state.characters[existingName].leaderRegistered = false;
            state.characters[existingName].leaderNote = '';
        }

        scheduleTierSave();
        return removed;
    }

    function leadersSnapshot() {
        const tier = ensureTierData();
        const names = new Set([
            ...Object.keys(tier.leaders || {}),
            ...Object.keys(tier.playerSettings || {}).filter(name => boolValue(tier.playerSettings[name]?.leader)),
            ...Object.keys(state.guildLocations || {})
        ]);

        return Array.from(names)
            .map(name => {
                const record = leaderFor(name);
                const location = state.guildLocations?.[name] || {};
                const character = state.characters?.[name] || {};
                const detected = Boolean(location.name || character.name);
                const active = record ? boolValue(record.active) : boolValue(tier.playerSettings?.[name]?.leader);
                return {
                    name,
                    active,
                    registered: Boolean(record),
                    detected,
                    online: getOnlineNames().has(normalizeKey(name)),
                    note: record?.note || '',
                    channel: location.channel || '',
                    level: location.level || character.level || 0,
                    vocation: location.vocation || character.vocation || 'Unknown',
                    vocationKey: location.vocationKey || character.vocationKey || '',
                    location: location.location || character.location || '',
                    updatedAt: record?.updatedAt || 0,
                    updatedAtText: record?.updatedAt ? utils.formatTimestamp(record.updatedAt) : ''
                };
            })
            .sort((a, b) => {
                if (a.active !== b.active) return a.active ? -1 : 1;
                if (a.registered !== b.registered) return a.registered ? -1 : 1;
                return a.name.localeCompare(b.name);
            });
    }

    function setPlayerSettings(characterName, settings) {
        const tier = ensureTierData();
        const name = normalizeName(characterName);
        if (!name) return {};
        const stateName = Object.keys(state.guildLocations || {}).find(saved => normalizeKey(saved) === normalizeKey(name))
            || Object.keys(state.characters || {}).find(saved => normalizeKey(saved) === normalizeKey(name))
            || name;
        const existingName = Object.keys(tier.playerSettings || {}).find(saved => normalizeKey(saved) === normalizeKey(name));
        const previous = tier.playerSettings[existingName || stateName] || {};
        const legacyLeader = leaderFor(stateName);
        const nowMs = Date.now();
        const previousLeader = previous.leader === undefined ? legacyLeader?.active : previous.leader;
        const previousHighlighted = previous.highlighted === undefined ? previousLeader : previous.highlighted;
        const leader = settings.leader === undefined ? boolValue(previousLeader) : boolValue(settings.leader);
        const highlighted = settings.highlighted === undefined ? boolValue(previousHighlighted) : boolValue(settings.highlighted);
        const caller = settings.caller === undefined ? boolValue(previous.caller) : boolValue(settings.caller);

        if (existingName && existingName !== stateName) delete tier.playerSettings[existingName];

        tier.playerSettings[stateName] = {
            ...previous,
            leader,
            highlighted,
            caller,
            updatedAt: nowMs
        };

        if (state.guildLocations?.[stateName]) {
            state.guildLocations[stateName].leader = leader;
            state.guildLocations[stateName].highlighted = highlighted;
            state.guildLocations[stateName].caller = caller;
        }
        if (state.characters?.[stateName]) {
            state.characters[stateName].leader = leader;
            state.characters[stateName].highlighted = highlighted;
            state.characters[stateName].caller = caller;
        }

        scheduleTierSave();
        return playerSettingsFor(stateName);
    }

    function ensureReceiverGroup(receiverName) {
        const tier = ensureTierData();
        const receiver = normalizeName(receiverName);
        if (!receiver) return '';
        tier.receiverGroups[receiver] = tier.receiverGroups[receiver] || {
            name: receiver,
            createdAt: Date.now()
        };
        tier.receiverGroups[receiver].name = receiver;
        tier.receiverGroups[receiver].updatedAt = Date.now();
        return receiver;
    }

    function renameReceiverGroup(oldName, newName) {
        const tier = ensureTierData();
        const from = normalizeName(oldName);
        const to = normalizeName(newName);
        if (!from || !to) {
            const err = new Error('Recebedor obrigatorio');
            err.statusCode = 400;
            throw err;
        }
        if (from === to) return to;

        const previousGroup = tier.receiverGroups[from] || {};
        delete tier.receiverGroups[from];
        tier.receiverGroups[to] = {
            ...previousGroup,
            name: to,
            updatedAt: Date.now()
        };

        for (const [character, receiver] of Object.entries(tier.receivers || {})) {
            if (normalizeName(receiver) === from) tier.receivers[character] = to;
        }

        if (tier.receiverTotals[from] !== undefined) {
            tier.receiverTotals[to] = (Number(tier.receiverTotals[to]) || 0) + (Number(tier.receiverTotals[from]) || 0);
            delete tier.receiverTotals[from];
        }
        if (tier.receiverCredits[from] !== undefined) {
            tier.receiverCredits[to] = roundCredit((Number(tier.receiverCredits[to]) || 0) + (Number(tier.receiverCredits[from]) || 0));
            tier.receiverTotals[to] = wholeCredit(tier.receiverCredits[to]);
            delete tier.receiverCredits[from];
        }

        for (const death of tier.deaths || []) {
            for (const row of death.receivers || []) {
                if (normalizeName(row.receiver) === from) row.receiver = to;
            }
            for (const character of death.eligibleCharacters || []) {
                if (normalizeName(character.receiver) === from) character.receiver = to;
            }
        }

        return to;
    }

    function removeReceiverGroup(receiverName) {
        const tier = ensureTierData();
        const receiver = normalizeName(receiverName);
        if (!receiver) return '';

        delete tier.receiverGroups[receiver];
        for (const [character, value] of Object.entries(tier.receivers || {})) {
            if (normalizeName(value) === receiver) delete tier.receivers[character];
        }

        return receiver;
    }

    function summarizeParticipant(info, onlineNames = getOnlineNames()) {
        const tier = ensureTierData();
        const name = normalizeName(info?.name);
        const position = normalizePosition(info);
        const online = name ? onlineNames.has(normalizeKey(name)) : false;
        const scout = boolValue(info?.scoutActive || info?.navScoutEnabled);
        const killer = boolValue(info?.killerActive || info?.navLeaderEnabled);
        const eventAreas = Array.isArray(tier.settings.eventAreas) && tier.settings.eventAreas.length
            ? tier.settings.eventAreas
            : defaultEventAreas;
        const depotAreas = tier.settings.depotAreas || [];
        const inValidArea = position ? positionInAnyArea(position, eventAreas) : false;
        const inDepot = position ? positionInAnyArea(position, depotAreas) : false;

        let eligible = true;
        let reason = 'Elegivel';
        if (!name) {
            eligible = false;
            reason = 'sem nome';
        } else if (!online) {
            eligible = false;
            reason = 'offline';
        } else if (!position) {
            eligible = false;
            reason = 'sem coordenada';
        } else if (!inValidArea) {
            eligible = false;
            reason = 'fora da area valida';
        } else if (inDepot) {
            eligible = false;
            reason = 'dentro do DP';
        } else if (!scout && !killer) {
            eligible = false;
            reason = 'Scout/Killer desligado';
        } else if (scout) {
            reason = 'Scout ativo e fora do DP';
        } else if (killer) {
            reason = 'Killer ativo e fora do DP';
        }

        return {
            name,
            receiver: receiverFor(name),
            channel: info?.channel || '',
            level: Number(info?.level) || 0,
            vocation: info?.vocation || 'Unknown',
            scout,
            killer,
            online,
            inValidArea,
            inDepot,
            eligible,
            reason,
            x: position?.x,
            y: position?.y,
            z: position?.z,
            location: position ? formatPosition(position) : 'Unknown',
            lastUpdate: info?.lastUpdate || '',
            lastUpdateMs: Number(info?.lastUpdateMs) || 0
        };
    }

    function rebuildTierParticipants(logChanges = false) {
        const tier = ensureTierData();
        const onlineNames = getOnlineNames();
        const next = {};

        for (const info of Object.values(state.guildLocations || {})) {
            const participant = summarizeParticipant(info, onlineNames);
            if (!participant.name) continue;

            const previous = tier.participants[participant.name];
            if (logChanges && previous) {
                if (previous.eligible !== participant.eligible) {
                    const action = participant.eligible ? 'entrou na divisao' : 'saiu da divisao';
                    addTierEvent('eligibility', `${participant.name} ${action}: ${participant.reason}`, {
                        character: participant.name,
                        eligible: participant.eligible,
                        reason: participant.reason
                    });
                } else if (previous.reason !== participant.reason) {
                    addTierEvent('eligibility', `${participant.name} status: ${participant.reason}`, {
                        character: participant.name,
                        eligible: participant.eligible,
                        reason: participant.reason
                    });
                }
            } else if (logChanges && participant.eligible) {
                addTierEvent('eligibility', `${participant.name} entrou na divisao: ${participant.reason}`, {
                    character: participant.name,
                    eligible: true,
                    reason: participant.reason
                });
            }

            next[participant.name] = participant;
        }

        tier.participants = next;
        return Object.values(next).sort((a, b) => a.name.localeCompare(b.name));
    }

    function uniqueReceiversFrom(participants) {
        const grouped = new Map();
        for (const participant of participants) {
            if (!participant.eligible) continue;
            const receiver = normalizeName(participant.receiver || participant.name);
            if (!grouped.has(receiver)) grouped.set(receiver, []);
            grouped.get(receiver).push(participant.name);
        }
        return grouped;
    }

    function latestLootEvent(maxAgeMs = 10 * 60 * 1000) {
        const tier = ensureTierData();
        const event = tier.latestWolfLoot || null;
        const position = normalizePosition(event?.position);
        const at = Number(event?.lootAt || event?.seenAt) || 0;
        if (!event || !position || !at) return null;
        if (Date.now() - at > maxAgeMs) return null;
        return { ...event, position };
    }

    function rememberExaltedWolf(ws, payload = {}) {
        const position = getPayloadPosition(payload);
        if (!position) return null;

        const kind = String(payload.kind || payload.bossName || payload.name || '').toLowerCase();
        if (kind && !kind.includes('exalted') && !kind.includes('wolf')) return null;
        if (!positionInAnyArea(position, navDivisionAreas)) return null;

        const tier = ensureTierData();
        const status = normalizeName(payload.status || payload.event || payload.reason || 'seen').toLowerCase();
        const lootText = normalizeName(payload.lootText || payload.text || payload.message);
        const lootDetected = boolValue(payload.loot) || status === 'loot' || /loot of\s+exalted wolf\s*:/i.test(lootText);
        const dead = boolValue(payload.dead || payload.killed) || status === 'dead' || status === 'death' || status === 'killed';
        const at = Date.now();
        const previousDeathPosition = normalizePosition(tier.latestWolfDeath?.position);
        const previousDeathAt = Number(tier.latestWolfDeath?.deathAt) || 0;
        const previousLootPosition = normalizePosition(tier.latestWolfLoot?.position);
        const previousLootAt = Number(tier.latestWolfLoot?.lootAt) || 0;
        const duplicateDeath = dead
            && previousDeathPosition
            && previousDeathPosition.x === position.x
            && previousDeathPosition.y === position.y
            && previousDeathPosition.z === position.z
            && at - previousDeathAt < 15000;
        const duplicateLoot = lootDetected
            && previousLootPosition
            && previousLootPosition.x === position.x
            && previousLootPosition.y === position.y
            && previousLootPosition.z === position.z
            && at - previousLootAt < 15000;
        const row = {
            position,
            location: formatPosition(position),
            hp: payload.hp ?? payload.healthPercent ?? null,
            scout: payload.scout || payload.sender || ws.userData?.name || '',
            status: lootDetected ? 'loot' : (dead ? 'dead' : 'seen'),
            lootText,
            seenAt: at,
            seenAtText: utils.formatTimestamp()
        };

        if (lootDetected) {
            tier.latestWolfLoot = {
                ...row,
                lootAt: at,
                lootAtText: row.seenAtText
            };
            if (!duplicateLoot) {
                addTierEvent('wolf_loot', `Loot de Exalted Wolf detectado por ${row.scout || 'desconhecido'} em ${row.location}.`, {
                    character: row.scout,
                    location: row.location,
                    lootText
                });
            } else {
                scheduleTierSave();
            }
            return row;
        }

        tier.latestWolf = row;
        if (dead) {
            tier.latestWolfDeath = {
                ...row,
                deathAt: at,
                deathAtText: row.seenAtText
            };
            if (!duplicateDeath) {
                addTierEvent('wolf_position', `Exalted Wolf morto reportado em ${row.location}.`, {
                    character: row.scout,
                    location: row.location
                });
            } else {
                scheduleTierSave();
            }
        } else {
            scheduleTierSave();
        }
        return row;
    }

    function registerTierDrop(payload = {}) {
        const tier = ensureTierData();
        const orbs = Math.max(0, Math.floor(Number(payload.orbs)));
        if (!Number.isFinite(orbs) || orbs <= 0) {
            const err = new Error('Quantidade de Tier Orbs invalida');
            err.statusCode = 400;
            throw err;
        }

        const participants = rebuildTierParticipants(false);
        const eligible = participants.filter(p => p.eligible);
        const grouped = uniqueReceiversFrom(eligible);
        const receivers = Array.from(grouped.keys()).sort((a, b) => a.localeCompare(b));
        if (receivers.length === 0) {
            const err = new Error('Nenhum recebedor elegivel no momento do drop');
            err.statusCode = 400;
            throw err;
        }

        const creditPerReceiver = roundCredit(orbs / receivers.length);
        const payloadPosition = getPayloadPosition(payload);
        const lootEvent = normalizeName(payload.source) === 'auto_bp' ? latestLootEvent() : null;
        const position = normalizePosition(lootEvent?.position) || payloadPosition || null;
        const at = Date.now();
        const key = dayKey(at);
        const day = ensureTierDay(key);

        const receiverRows = receivers.map(receiver => {
            const characters = grouped.get(receiver) || [];
            const creditBefore = creditNumber(tier.receiverCredits[receiver]);
            const creditAfter = roundCredit(creditBefore + creditPerReceiver);
            const wholeBefore = wholeCredit(creditBefore);
            const wholeAfter = wholeCredit(creditAfter);
            const wholeNow = wholeAfter - wholeBefore;
            tier.receiverCredits[receiver] = creditAfter;
            tier.receiverTotals[receiver] = wholeAfter;
            return {
                receiver,
                characters,
                credit: creditPerReceiver,
                creditPerReceiver,
                share: creditPerReceiver,
                wholeOrbsNow: wholeNow,
                wholeOrbsAfter: wholeAfter,
                creditBefore: roundCredit(creditBefore),
                creditAfter,
                totalAfter: wholeAfter,
                decimalBalanceAfter: decimalCredit(creditAfter)
            };
        });

        day.orbs += orbs;
        day.deaths += 1;

        const death = {
            id: `${at}-${Math.random().toString(36).slice(2, 8)}`,
            day: key,
            time: timeLabel(at),
            at,
            position,
            location: formatPosition(position),
            orbs,
            eligibleCharacters: eligible.map(p => ({
                name: p.name,
                receiver: p.receiver,
                scout: p.scout,
                killer: p.killer,
                location: p.location
            })),
            eligibleCount: eligible.length,
            uniqueReceivers: receivers.length,
            receivers: receiverRows,
            creditPerReceiver,
            share: creditPerReceiver,
            wholeOrbsUnlocked: receiverRows.reduce((sum, row) => sum + (Number(row.wholeOrbsNow) || 0), 0),
            distributed: receiverRows.reduce((sum, row) => sum + (Number(row.wholeOrbsNow) || 0), 0),
            remainder: 0,
            technicalRemainder: 0,
            note: normalizeName(payload.note),
            source: normalizeName(payload.source || 'manual'),
            sourceCharacter: normalizeName(payload.sourceCharacter),
            itemId: payload.itemId ? Number(payload.itemId) : undefined,
            lootText: lootEvent?.lootText || '',
            lootSourceCharacter: lootEvent?.scout || '',
            lootAt: lootEvent?.lootAt || 0,
            lootAtText: lootEvent?.lootAtText || ''
        };

        tier.deaths.unshift(death);
        tier.deaths = tier.deaths.slice(0, 1000);
        tier.leftoversTotal = technicalLeftoverTotal(tier);
        day.leftovers = technicalLeftoverForDay(tier, key);
        death.remainder = tier.leftoversTotal;
        death.technicalRemainder = tier.leftoversTotal;

        addTierEvent('death', `Exalted Wolf morto em ${death.location}. Drop: ${orbs} Tier Orbs.`, { deathId: death.id });
        addTierEvent('drop', `Divisao: credito ${creditPerReceiver.toFixed(4)} para cada recebedor (${receivers.length} cotas). Sobra tecnica: ${tier.leftoversTotal}.`, { deathId: death.id });
        scheduleTierSave();
        return death;
    }

    function buildHeatmap(deaths) {
        const points = new Map();
        for (const death of deaths || []) {
            const pos = normalizePosition(death.position);
            if (!pos) continue;
            const bucketX = heatBucketValue(pos.x);
            const bucketY = heatBucketValue(pos.y);
            const display = {
                x: heatBucketCenter(pos.x),
                y: heatBucketCenter(pos.y),
                z: wolfHeatmapFloor
            };
            const at = Number(death.at) || 0;
            const key = `${bucketX},${bucketY},regional`;
            const current = points.get(key) || {
                x: display.x,
                y: display.y,
                z: display.z,
                bucket: {
                    x1: bucketX,
                    y1: bucketY,
                    x2: bucketX + wolfHeatmapBucketSize - 1,
                    y2: bucketY + wolfHeatmapBucketSize - 1
                },
                count: 0,
                orbs: 0,
                realFloors: [],
                events: [],
                firstAt: at || null,
                lastAt: at || null
            };
            current.count += 1;
            current.orbs += Number(death.orbs) || 0;
            if (!current.realFloors.includes(pos.z)) current.realFloors.push(pos.z);
            current.events.push({
                id: death.id,
                day: death.day,
                time: death.time,
                at,
                x: pos.x,
                y: pos.y,
                z: pos.z,
                location: death.location || formatPosition(pos),
                orbs: Number(death.orbs) || 0
            });
            if (at && (!current.firstAt || at < current.firstAt)) current.firstAt = at;
            if (at && (!current.lastAt || at > current.lastAt)) current.lastAt = at;
            points.set(key, current);
        }
        const values = Array.from(points.values());
        const maxCount = Math.max(1, ...values.map(point => point.count));
        return values
            .map(point => ({
                ...point,
                realFloors: point.realFloors.sort((a, b) => a - b),
                firstAtText: point.firstAt ? timeLabel(point.firstAt) : '',
                lastAtText: point.lastAt ? timeLabel(point.lastAt) : '',
                intensity: point.count / maxCount
            }))
            .sort((a, b) => b.count - a.count);
    }

    function tierSnapshot() {
        const tier = ensureTierData();
        const participants = rebuildTierParticipants(false);
        const eligible = participants.filter(p => p.eligible);
        const online = participants.filter(p => p.online);
        const grouped = uniqueReceiversFrom(eligible);
        const today = ensureTierDay(dayKey());
        const todayCreditTotals = receiverCreditTotalsForDay(tier, dayKey());
        tier.leftoversTotal = technicalLeftoverTotal(tier);
        today.leftovers = technicalLeftoverForDay(tier, dayKey());
        const receivers = Array.from(new Set([
            ...Object.keys(tier.receiverGroups || {}),
            ...Object.values(tier.receivers || {}),
            ...Array.from(grouped.keys())
        ])).filter(Boolean).sort((a, b) => a.localeCompare(b));

        const receiverRows = receivers.map(receiver => {
            const linked = participants.filter(p => p.receiver === receiver).map(p => p.name);
            const eligibleLinked = participants.filter(p => p.receiver === receiver && p.eligible).map(p => p.name);
            const totalCredit = roundCredit(tier.receiverCredits?.[receiver] ?? tier.receiverTotals?.[receiver] ?? 0);
            const wholeOrbs = wholeCredit(totalCredit);
            const todayCredit = roundCredit(todayCreditTotals[receiver] || 0);
            const latestDeath = tier.deaths?.[0] || null;
            const latestRow = (latestDeath?.receivers || []).find(item => normalizeName(item.receiver) === receiver);
            const latestCredit = latestRow ? roundCredit(rowCreditValue(latestRow)) : 0;
            return {
                receiver,
                explicit: Boolean(tier.receiverGroups?.[receiver]),
                characters: linked,
                eligibleCharacters: eligibleLinked,
                characterCount: linked.length,
                eligibleCount: eligibleLinked.length,
                currentShare: grouped.has(receiver) ? 1 : 0,
                activeQuota: grouped.has(receiver),
                latestCredit,
                latestWholeOrbs: Number(latestRow?.wholeOrbsNow) || 0,
                totalToday: todayCredit,
                todayCredit,
                totalCredit,
                wholeOrbs,
                total: wholeOrbs,
                decimalBalance: decimalCredit(totalCredit)
            };
        });

        return {
            collection: tier.collection,
            collections: tier.collections,
            settings: tier.settings,
            receiverMap: tier.receivers,
            receiverGroups: tier.receiverGroups,
            playerSettings: tier.playerSettings,
            shareMode: 'grouped',
            orbReports: Object.values(tier.orbReports || {}).sort((a, b) => String(a.name || '').localeCompare(String(b.name || ''))),
            participants,
            onlineCount: online.length,
            eligibleCount: eligible.length,
            uniqueReceivers: grouped.size,
            receivers: receiverRows,
            deaths: tier.deaths,
            heatmap: buildHeatmap(tier.deaths),
            latestWolf: tier.latestWolf,
            latestWolfDeath: tier.latestWolfDeath,
            latestWolfLoot: tier.latestWolfLoot,
            totals: {
                orbsToday: today.orbs || 0,
                deathsToday: today.deaths || 0,
                totalOrbs: wholePayableTotal(tier),
                wholeOrbsToPay: wholePayableTotal(tier),
                registeredOrbsTotal: totalRegisteredOrbs(tier),
                leftoversToday: today.leftovers || 0,
                leftoversTotal: tier.leftoversTotal || 0,
                technicalLeftover: tier.leftoversTotal || 0,
                latestDeath: tier.deaths[0] || null
            },
            days: Object.entries(tier.days || {})
                .sort((a, b) => b[0].localeCompare(a[0]))
                .map(([day, data]) => ({ day, ...data }))
        };
    }

    function processTierOrbReport(ws, payload = {}) {
        const tier = ensureTierData();
        const itemId = Number(payload.itemId);
        if (itemId !== 11844) return null;

        const name = normalizeName(payload.name || ws.userData?.name);
        if (!name) return null;

        const count = Math.max(0, Math.floor(Number(payload.count) || 0));
        const delta = Math.max(0, Math.floor(Number(payload.delta) || 0));
        const position = getPayloadPosition(payload);
        const previous = tier.orbReports[name] || null;
        const at = Date.now();
        const report = {
            name,
            itemId,
            count,
            delta,
            previousCount: previous ? Number(previous.count) || 0 : null,
            reason: normalizeName(payload.reason),
            source: normalizeName(payload.source || 'bot'),
            position,
            location: formatPosition(position),
            scoutActive: boolValue(payload.scoutActive || payload.navScoutEnabled),
            killerActive: boolValue(payload.killerActive || payload.navLeaderEnabled),
            lastUpdate: utils.formatTimestamp(at),
            lastUpdateMs: at,
            lastDropAt: previous?.lastDropAt || 0,
            lastDrop: previous?.lastDrop || 0
        };

        tier.orbReports[name] = report;

        if (delta > 0) {
            const duplicateWindowMs = 2000;
            const duplicate = previous
                && previous.lastDrop === delta
                && previous.lastDropAt
                && at - previous.lastDropAt < duplicateWindowMs;

            if (!duplicate) {
                try {
                    const death = registerTierDrop({
                        orbs: delta,
                        position,
                        source: 'auto_bp',
                        sourceCharacter: name,
                        itemId,
                        note: `Auto BP ${name}: item ${itemId}`
                    });
                    report.lastDropAt = at;
                    report.lastDrop = delta;
                    report.lastDeathId = death.id;
                    tier.orbReports[name] = report;
                    addTierEvent('auto_drop', `${name} recebeu ${delta} Tier Orbs na BP. Drop registrado automaticamente.`, {
                        character: name,
                        deathId: death.id
                    });
                } catch (error) {
                    report.lastError = error.message;
                    tier.orbReports[name] = report;
                    addTierEvent('auto_drop_error', `${name} recebeu ${delta} Tier Orbs, mas o drop nao foi registrado: ${error.message}`, {
                        character: name
                    });
                }
            }
        }

        scheduleTierSave();
        return report;
    }

    function normalizeVocationKey(value) {
        const v = String(value ?? '').trim().toLowerCase();
        if (['1', '5', '13', 'sorcerer', 'ms', 'master sorcerer'].includes(v)) return 'sorcerer';
        if (['2', '6', '14', 'druid', 'ed', 'elder druid'].includes(v)) return 'druid';
        if (['3', '7', '12', 'paladin', 'rp', 'royal paladin'].includes(v)) return 'paladin';
        if (['4', '8', '11', 'knight', 'ek', 'elite knight'].includes(v)) return 'knight';
        return '';
    }

    function vocationLabel(value) {
        const key = normalizeVocationKey(value);
        if (key === 'sorcerer') return 'MS - Sorcerer';
        if (key === 'druid') return 'ED - Druid';
        if (key === 'paladin') return 'RP - Paladin';
        if (key === 'knight') return 'EK - Knight';
        return 'Unknown';
    }

    function rememberGuildLocation(ws, payload = {}) {
        const position = getPayloadPosition(payload);
        const name = payload.name || ws.userData?.name;
        if (!name || !position) return null;
        const settings = playerSettingsFor(name);
        const health = Number(payload.health) || 0;
        const maxHealth = Number(payload.maxHealth) || 0;
        const dead = boolValue(payload.dead) || (maxHealth > 0 && health <= 0);
        const leaderValue = settings.leader === undefined ? (payload.leader || payload.dashboardLeader) : settings.leader;
        const highlightedValue = settings.highlighted === undefined ? (payload.highlighted || payload.dashboardHighlight || leaderValue) : settings.highlighted;
        const callerValue = settings.caller === undefined ? (payload.caller || payload.dashboardCaller) : settings.caller;

        const info = {
            name,
            channel: ws.userData?.channel || '',
            level: payload.level || 0,
            vocation: payload.vocation || 'Unknown',
            vocationRaw: payload.vocationRaw,
            vocationKey: normalizeVocationKey(payload.vocationKey || payload.vocation),
            vocationLabel: payload.vocationLabel || vocationLabel(payload.vocationKey || payload.vocation),
            outfit: payload.outfit && typeof payload.outfit === 'object' ? payload.outfit : null,
            health,
            maxHealth,
            healthPercent: maxHealth ? (health / maxHealth) * 100 : 0,
            alive: !dead,
            dead,
            underPkAttack: boolValue(payload.underPkAttack),
            pkAttackers: Array.isArray(payload.pkAttackers) ? payload.pkAttackers : [],
            pkAttackerNames: normalizeName(payload.pkAttackerNames),
            targetPlayer: boolValue(payload.targetPlayer),
            targetName: normalizeName(payload.targetName),
            targetSkull: Number(payload.targetSkull) || 0,
            leader: boolValue(leaderValue),
            highlighted: boolValue(highlightedValue),
            caller: boolValue(callerValue),
            leaderRegistered: boolValue(settings.leaderRegistered),
            leaderNote: settings.leaderNote || '',
            scoutActive: boolValue(payload.scoutActive || payload.navScoutEnabled),
            killerActive: boolValue(payload.killerActive || payload.navLeaderEnabled),
            role: payload.role || (boolValue(payload.scoutActive || payload.navScoutEnabled) ? 'Scout' : (boolValue(payload.killerActive || payload.navLeaderEnabled) ? 'Killer' : '')),
            x: position.x,
            y: position.y,
            z: position.z,
            location: payload.location || formatPosition(position),
            map: payload.map || 'minimap854.otmm',
            lastUpdate: utils.formatTimestamp(),
            lastUpdateMs: Date.now()
        };

        state.guildLocations[name] = info;
        rebuildTierParticipants(true);
        return info;
    }

    apiRouter.get('/dashboard-users', (req, res) => {
        const authUser = requireDashboardAdmin(req, res);
        if (!authUser) return;
        res.json({ ok: true, authUser, users: dashboardUsersSnapshot() });
    });

    apiRouter.post('/dashboard-users', (req, res) => {
        const authUser = requireDashboardAdmin(req, res);
        if (!authUser) return;

        try {
            const username = validateDashboardUserInput(req.body?.username, req.body?.password, true);
            const data = loadDashboardUsersData();
            if (data.users[username]) {
                return res.status(409).json({ ok: false, error: 'Usuario ja cadastrado' });
            }

            const nowMs = Date.now();
            data.users[username] = {
                username,
                ...hashDashboardPassword(req.body.password),
                role: cleanDashboardRole(req.body?.role),
                active: boolDashboardValue(req.body?.active, true),
                createdAt: nowMs,
                updatedAt: nowMs,
                createdBy: authUser.username
            };
            saveDashboardUsersData();
            res.json({ ok: true, user: publicDashboardUser(data.users[username]), users: dashboardUsersSnapshot() });
        } catch (error) {
            res.status(error.statusCode || 500).json({ ok: false, error: error.message });
        }
    });

    apiRouter.patch('/dashboard-users/:username', (req, res) => {
        const authUser = requireDashboardAdmin(req, res);
        if (!authUser) return;

        try {
            const username = validateDashboardUserInput(req.params.username, req.body?.password, false);
            const data = loadDashboardUsersData();
            const user = data.users[username];
            if (!user) {
                return res.status(404).json({ ok: false, error: 'Usuario nao encontrado' });
            }

            const isSelf = normalizeDashboardUsername(authUser.username) === username;
            if (req.body?.active !== undefined) {
                const active = boolDashboardValue(req.body.active, true);
                if (isSelf && active === false) {
                    return res.status(400).json({ ok: false, error: 'Voce nao pode desativar seu proprio acesso.' });
                }
                user.active = active;
            }
            if (req.body?.role !== undefined) {
                const role = cleanDashboardRole(req.body.role);
                if (isSelf && role !== 'admin') {
                    return res.status(400).json({ ok: false, error: 'Voce nao pode remover seu proprio admin.' });
                }
                user.role = role;
            }
            if (req.body?.password) {
                if (String(req.body.password).length < 6) {
                    return res.status(400).json({ ok: false, error: 'Senha deve ter pelo menos 6 caracteres.' });
                }
                Object.assign(user, hashDashboardPassword(req.body.password));
            }

            user.updatedAt = Date.now();
            saveDashboardUsersData();
            res.json({ ok: true, user: publicDashboardUser(user), users: dashboardUsersSnapshot() });
        } catch (error) {
            res.status(error.statusCode || 500).json({ ok: false, error: error.message });
        }
    });

    apiRouter.delete('/dashboard-users/:username', (req, res) => {
        const authUser = requireDashboardAdmin(req, res);
        if (!authUser) return;

        try {
            const username = validateDashboardUserInput(req.params.username, null, false);
            if (normalizeDashboardUsername(authUser.username) === username) {
                return res.status(400).json({ ok: false, error: 'Voce nao pode remover seu proprio acesso.' });
            }

            const data = loadDashboardUsersData();
            if (!data.users[username]) {
                return res.status(404).json({ ok: false, error: 'Usuario nao encontrado' });
            }

            delete data.users[username];
            saveDashboardUsersData();
            res.json({ ok: true, users: dashboardUsersSnapshot() });
        } catch (error) {
            res.status(error.statusCode || 500).json({ ok: false, error: error.message });
        }
    });

    apiRouter.get('/modules', (req, res) => {
        const modules = state.loadedModules || [];
        res.json(modules.map(m => ({
            name: m.meta?.name,
            version: m.meta?.version,
            description: m.meta?.description,
            file: m.file,
            priority: m.meta?.priority || 0,
            enabled: m.meta?.enabled !== false
        })));
    });

    function navDebugEventsSnapshot() {
        return Array.isArray(state.navDebugEvents) ? state.navDebugEvents.slice(0, 200) : [];
    }

    function activeNavScoutsSnapshot() {
        return Object.values(state.guildLocations || {})
            .filter(info =>
                boolValue(info.scoutActive) &&
                info.dead !== true &&
                Number.isFinite(Number(info.x)) &&
                Number.isFinite(Number(info.y)) &&
                Number.isFinite(Number(info.z))
            )
            .sort((a, b) => String(a.name || '').localeCompare(String(b.name || '')))
            .map(info => ({
                name: info.name,
                channel: info.channel || '',
                level: info.level || 0,
                vocation: info.vocationLabel || info.vocation || 'Unknown',
                x: Number(info.x),
                y: Number(info.y),
                z: Number(info.z),
                location: info.location || formatPosition(info),
                lastUpdate: info.lastUpdate || '',
                lastUpdateMs: Number(info.lastUpdateMs) || 0
            }));
    }

    function findActiveNavScout(name) {
        const wanted = normalizeKey(name);
        if (!wanted) return null;
        return activeNavScoutsSnapshot().find(info => normalizeKey(info.name) === wanted) || null;
    }

    function buildNavDebugPayload(scout) {
        return {
            kind: 'exalted_wolf',
            status: 'seen',
            test: true,
            navDebug: true,
            bossName: 'Exalted Wolf',
            scout: scout.name,
            sender: scout.name,
            x: scout.x,
            y: scout.y,
            z: scout.z,
            hp: 100,
            position: { x: scout.x, y: scout.y, z: scout.z },
            location: formatPosition(scout),
            source: 'dashboard_nav_debug',
            sentAt: Date.now()
        };
    }

    apiRouter.get('/nav-debug', (req, res) => {
        res.json({
            ok: true,
            scouts: activeNavScoutsSnapshot(),
            events: navDebugEventsSnapshot()
        });
    });

    apiRouter.post('/nav-debug/simulate', (req, res) => {
        const scout = findActiveNavScout(req.body?.character || req.body?.name);
        if (!scout) {
            return res.status(404).json({ ok: false, error: 'Scout ativo nao encontrado' });
        }
        if (!scout.channel) {
            return res.status(400).json({ ok: false, error: 'Scout sem channel ativo' });
        }
        if (typeof state.sendWsMessageToChannel !== 'function') {
            return res.status(503).json({ ok: false, error: 'WebSocket ainda nao esta pronto' });
        }

        const payload = buildNavDebugPayload(scout);
        const response = {
            type: 'message',
            id: Date.now(),
            name: scout.name,
            topic: 'farm_nav',
            message: payload
        };
        const receivers = state.sendWsMessageToChannel(scout.channel, response, {
            direction: 'test',
            source: 'dashboard',
            sender: scout.name,
            note: 'simulacao de coordenada do Exalted'
        });

        res.json({ ok: true, scout, payload, receivers });
    });

    apiRouter.get('/stats', (req, res) => {
        const { characters, channels, connections, exceptions, blocked, packets, httpAllowedRequests, httpBlockedRequests } = state;
        const channelDetails = {};
        const users = [];

        for (const [channelName, clients] of Object.entries(channels)) {
            channelDetails[channelName] = {
                users: clients.size,
                created: clients.created
                    ? utils.formatTimestamp(clients.created)
                    : 'Unknown'
            };

            for (const ws of clients) {
                if (ws.userData?.name) {
                    users.push({
                        name: ws.userData.name,
                        channel: channelName,
                        ping: ws.userData.lastPing || 0,
                        messages: ws.userData.messagesSent || 0,
                        packets: ws.userData.totalPackets || 0,
                        connectedTime: utils.timeAgo(ws.userData.activeTime)
                    });
                }
            }
        }

        const stats = {
            connections,
            exceptions,
            blocked,
            packets,
            httpAllowedRequests,
            httpBlockedRequests,
            channelCount: Object.keys(channels).length,
            channelDetails,
            timestamp: Date.now(),
            wsStarted: state.wsStartTime ? utils.formatTimestamp(state.wsStartTime) : 'N/A',
            wsUptime: utils.timeAgo(state.wsStartTime || Date.now()),
            wsUptimeMs: state.wsStartTime ? Date.now() - state.wsStartTime : 0,
            users,
            authUser: currentDashboardUser(req),
            characters: Object.values(characters).map(c => ({
                name: c.name,
                level: c.level,
                vocation: c.vocation,
                vocationRaw: c.vocationRaw,
                vocationKey: c.vocationKey,
                vocationLabel: c.vocationLabel,
                outfit: c.outfit,
                leader: c.leader,
                highlighted: c.highlighted,
                caller: c.caller,
                leaderRegistered: c.leaderRegistered,
                leaderNote: c.leaderNote,
                health: c.health,
                maxHealth: c.maxHealth,
                healthPercent: c.healthPercent,
                alive: c.alive,
                dead: c.dead,
                underPkAttack: c.underPkAttack,
                pkAttackers: c.pkAttackers,
                pkAttackerNames: c.pkAttackerNames,
                targetPlayer: c.targetPlayer,
                targetName: c.targetName,
                targetSkull: c.targetSkull,
                mana: c.mana,
                maxMana: c.maxMana,
                manaPercent: c.manaPercent,
                experience: c.experience,
                expPercent: c.expPercent,
                location: c.location,
                x: c.x,
                y: c.y,
                z: c.z,
                map: c.map,
                lastUpdate: c.lastUpdate
            })),
            guildLocations: Object.values(state.guildLocations || {}),
            leaders: leadersSnapshot(),
            tierOrbs: tierSnapshot()
        };

        res.json(stats);
    });

    apiRouter.get('/tier-orbs', (req, res) => {
        res.json(tierSnapshot());
    });

    apiRouter.post('/tier-orbs/drop', (req, res) => {
        try {
            const death = registerTierDrop(req.body || {});
            res.json({ ok: true, death, tierOrbs: tierSnapshot() });
        } catch (error) {
            res.status(error.statusCode || 500).json({ ok: false, error: error.message });
        }
    });

    apiRouter.post('/tier-orbs/start', (req, res) => {
        try {
            const collection = startTierOrbCollection(req.body || {});
            res.json({ ok: true, collection, tierOrbs: tierSnapshot() });
        } catch (error) {
            res.status(error.statusCode || 500).json({ ok: false, error: error.message });
        }
    });

    apiRouter.post('/tier-orbs/receiver', (req, res) => {
        const tier = ensureTierData();
        const character = normalizeName(req.body?.character);
        const receiver = normalizeName(req.body?.receiver);

        if (!character) {
            return res.status(400).json({ ok: false, error: 'Personagem obrigatorio' });
        }

        if (!receiver || normalizeKey(receiver) === normalizeKey(character)) {
            delete tier.receivers[character];
            addTierEvent('receiver', `${character} voltou para receber no proprio nome.`, { character, receiver: character });
        } else {
            const group = ensureReceiverGroup(receiver);
            tier.receivers[character] = group;
            addTierEvent('receiver', `${character} vinculado ao recebedor ${group}.`, { character, receiver: group });
        }

        rebuildTierParticipants(false);
        scheduleTierSave();
        res.json({ ok: true, tierOrbs: tierSnapshot() });
    });

    apiRouter.delete('/tier-orbs/receiver/:character', (req, res) => {
        const tier = ensureTierData();
        const character = normalizeName(req.params.character);
        if (character) {
            delete tier.receivers[character];
            addTierEvent('receiver', `${character} voltou para receber no proprio nome.`, { character, receiver: character });
        }
        rebuildTierParticipants(false);
        scheduleTierSave();
        res.json({ ok: true, tierOrbs: tierSnapshot() });
    });

    apiRouter.post('/tier-orbs/groups', (req, res) => {
        try {
            const receiver = ensureReceiverGroup(req.body?.receiver || req.body?.name);
            if (!receiver) {
                return res.status(400).json({ ok: false, error: 'Recebedor obrigatorio' });
            }

            addTierEvent('receiver_group', `Grupo de recebedor criado: ${receiver}.`, { receiver });
            rebuildTierParticipants(false);
            scheduleTierSave();
            res.json({ ok: true, receiver, tierOrbs: tierSnapshot() });
        } catch (error) {
            res.status(error.statusCode || 500).json({ ok: false, error: error.message });
        }
    });

    apiRouter.patch('/tier-orbs/groups/:receiver', (req, res) => {
        try {
            const oldReceiver = normalizeName(req.params.receiver);
            const newReceiver = renameReceiverGroup(oldReceiver, req.body?.receiver || req.body?.name);
            addTierEvent('receiver_group', `Grupo de recebedor renomeado: ${oldReceiver} -> ${newReceiver}.`, {
                receiver: newReceiver,
                oldReceiver
            });
            rebuildTierParticipants(false);
            scheduleTierSave();
            res.json({ ok: true, receiver: newReceiver, tierOrbs: tierSnapshot() });
        } catch (error) {
            res.status(error.statusCode || 500).json({ ok: false, error: error.message });
        }
    });

    apiRouter.delete('/tier-orbs/groups/:receiver', (req, res) => {
        const receiver = removeReceiverGroup(req.params.receiver);
        if (receiver) {
            addTierEvent('receiver_group', `Grupo de recebedor removido: ${receiver}. Personagens voltaram para o proprio nome.`, {
                receiver
            });
        }
        rebuildTierParticipants(false);
        scheduleTierSave();
        res.json({ ok: true, receiver, tierOrbs: tierSnapshot() });
    });

    apiRouter.post('/tier-orbs/settings', (req, res) => {
        const tier = ensureTierData();
        const eventAreasText = String(req.body?.eventAreasText ?? '');
        const depotAreasText = String(req.body?.depotAreasText ?? '');

        tier.settings.eventAreasText = eventAreasText;
        tier.settings.depotAreasText = depotAreasText;
        tier.settings.eventAreas = parseAreasText(eventAreasText);
        tier.settings.depotAreas = depotAreasText.trim() ? parseAreasText(depotAreasText) : defaultDepotAreas;

        addTierEvent('settings', 'Areas de divisao atualizadas.');
        rebuildTierParticipants(true);
        scheduleTierSave();
        res.json({ ok: true, tierOrbs: tierSnapshot() });
    });

    apiRouter.post('/player-settings', (req, res) => {
        const character = normalizeName(req.body?.character || req.body?.name);
        if (!character) {
            return res.status(400).json({ ok: false, error: 'Personagem obrigatorio' });
        }

        const settings = setPlayerSettings(character, {
            leader: req.body?.leader,
            highlighted: req.body?.highlighted ?? req.body?.leader,
            caller: req.body?.caller
        });

        addTierEvent('player_settings', `${character} atualizado: leader=${settings.leader ? 'on' : 'off'}, caller=${settings.caller ? 'on' : 'off'}.`, {
            character,
            leader: settings.leader,
            caller: settings.caller
        });
        res.json({ ok: true, character, settings, tierOrbs: tierSnapshot() });
    });

    apiRouter.get('/leaders', (req, res) => {
        res.json({ ok: true, leaders: leadersSnapshot() });
    });

    apiRouter.post('/leaders', (req, res) => {
        const character = normalizeName(req.body?.character || req.body?.name);
        if (!character) {
            return res.status(400).json({ ok: false, error: 'Personagem obrigatorio' });
        }

        const leader = upsertLeader(character, {
            active: req.body?.active ?? true,
            note: req.body?.note
        });

        addTierEvent('leader', `${leader.name} cadastrado como lider ${leader.active ? 'ativo' : 'inativo'}.`, {
            character: leader.name,
            active: leader.active
        });
        res.json({ ok: true, leader, leaders: leadersSnapshot(), tierOrbs: tierSnapshot() });
    });

    apiRouter.patch('/leaders/:character', (req, res) => {
        const character = normalizeName(req.params.character);
        const current = leaderFor(character);
        if (!current) {
            return res.status(404).json({ ok: false, error: 'Lider nao cadastrado' });
        }

        const leader = upsertLeader(character, {
            active: req.body?.active ?? current.active,
            note: req.body?.note ?? current.note
        });

        addTierEvent('leader', `${leader.name} ${leader.active ? 'ativado' : 'desativado'} como lider.`, {
            character: leader.name,
            active: leader.active
        });
        res.json({ ok: true, leader, leaders: leadersSnapshot(), tierOrbs: tierSnapshot() });
    });

    apiRouter.delete('/leaders/:character', (req, res) => {
        const leader = removeLeader(req.params.character);
        if (!leader) {
            return res.status(404).json({ ok: false, error: 'Lider nao cadastrado' });
        }

        addTierEvent('leader', `${leader.name} removido do cadastro de lideres.`, {
            character: leader.name,
            active: false
        });
        res.json({ ok: true, leader, leaders: leadersSnapshot(), tierOrbs: tierSnapshot() });
    });

    apiRouter.get('/minimap/meta', (req, res) => {
        res.json(minimap.getMeta());
    });

    apiRouter.get('/minimap/view', (req, res) => {
        try {
            const png = minimap.renderView({
                x: req.query.x,
                y: req.query.y,
                z: req.query.z,
                width: req.query.w,
                height: req.query.h,
                scale: req.query.scale
            });

            res.setHeader('Content-Type', 'image/png');
            res.setHeader('Cache-Control', 'public, max-age=5');
            res.send(png);
        } catch (error) {
            res.status(500).json({ error: error.message });
        }
    });

    app.use('/api', apiRouter);

    utils.registerWsHook('char_info', (ws, msg) => {
        const m = msg.message;
        if (typeof m !== 'object' || !m?.name) return true;
        const position = getPayloadPosition(m);
        const settings = playerSettingsFor(m.name);
        const health = Number(m.health) || 0;
        const maxHealth = Number(m.maxHealth) || 0;
        const dead = boolValue(m.dead) || (maxHealth > 0 && health <= 0);
        const leaderValue = settings.leader === undefined ? (m.leader || m.dashboardLeader) : settings.leader;
        const highlightedValue = settings.highlighted === undefined ? (m.highlighted || m.dashboardHighlight || leaderValue) : settings.highlighted;
        const callerValue = settings.caller === undefined ? (m.caller || m.dashboardCaller) : settings.caller;

        state.characters[m.name] = {
            name: m.name,
            level: m.level || 0,
            vocation: m.vocation || 'Unknown',
            vocationRaw: m.vocationRaw,
            vocationKey: normalizeVocationKey(m.vocationKey || m.vocation),
            vocationLabel: m.vocationLabel || vocationLabel(m.vocationKey || m.vocation),
            outfit: m.outfit && typeof m.outfit === 'object' ? m.outfit : null,
            leader: boolValue(leaderValue),
            highlighted: boolValue(highlightedValue),
            caller: boolValue(callerValue),
            leaderRegistered: boolValue(settings.leaderRegistered),
            leaderNote: settings.leaderNote || '',
            scoutActive: boolValue(m.scoutActive || m.navScoutEnabled),
            killerActive: boolValue(m.killerActive || m.navLeaderEnabled),
            role: m.role || (boolValue(m.scoutActive || m.navScoutEnabled) ? 'Scout' : (boolValue(m.killerActive || m.navLeaderEnabled) ? 'Killer' : '')),
            health,
            maxHealth,
            healthPercent: maxHealth ? (health / maxHealth) * 100 : 0,
            alive: !dead,
            dead,
            underPkAttack: boolValue(m.underPkAttack),
            pkAttackers: Array.isArray(m.pkAttackers) ? m.pkAttackers : [],
            pkAttackerNames: normalizeName(m.pkAttackerNames),
            targetPlayer: boolValue(m.targetPlayer),
            targetName: normalizeName(m.targetName),
            targetSkull: Number(m.targetSkull) || 0,
            mana: m.mana || 0,
            maxMana: m.maxMana || 0,
            manaPercent: m.maxMana ? (m.mana / m.maxMana) * 100 : 0,
            experience: m.experience || 0,
            expPercent: m.expPercent || 0,
            location: m.location || formatPosition(position),
            x: position?.x,
            y: position?.y,
            z: position?.z,
            map: m.map || 'minimap854.otmm',
            lastUpdate: utils.formatTimestamp()
        };

        rememberGuildLocation(ws, m);

        return true;
    }, state);

    utils.registerWsHook('guild_pos', (ws, msg, response) => {
        if (typeof msg.message === 'object') {
            const info = rememberGuildLocation(ws, msg.message);
            if (info && response) {
                response.message = {
                    ...msg.message,
                    leader: info.leader,
                    highlighted: info.highlighted,
                    caller: info.caller,
                    outfit: info.outfit,
                    leaderRegistered: info.leaderRegistered,
                    leaderNote: info.leaderNote
                };
            }
        }
    }, state);

    utils.registerWsHook('tier_orbs', (ws, msg) => {
        if (typeof msg.message === 'object') {
            processTierOrbReport(ws, msg.message);
        }
        return true;
    }, state);

    utils.registerWsHook('tier_orbs_control', (ws, msg, response) => {
        const payload = typeof msg.message === 'object' && msg.message ? msg.message : {};
        const action = normalizeName(payload.action || payload.type).toLowerCase();
        if (action !== 'start_collection' && action !== 'start') return true;

        const collection = startTierOrbCollection({
            ...payload,
            startedBy: payload.startedBy || payload.sourceCharacter || ws.userData?.name
        });
        response.message = {
            ok: true,
            action: 'collection_started',
            collection
        };
        return undefined;
    }, state);

    utils.registerWsHook('farm_nav', (ws, msg) => {
        const payload = msg.message || {};
        if (typeof payload !== 'object') return true;

        const saved = rememberExaltedWolf(ws, payload);
        const position = getPayloadPosition(payload);
        utils.log.info(`[nav] farm_nav recebido de ${ws.userData?.name || 'unknown'} em ${ws.userData?.channel || 'unknown'} ${position ? `${position.x},${position.y},${position.z}` : 'sem-pos'}; broadcast permitido${saved ? '' : ' (nao salvo)'}`);
        return undefined;
    }, state);

    utils.registerWsHook('exalted_wolf', (ws, msg) => {
        if (typeof msg.message === 'object') {
            const saved = rememberExaltedWolf(ws, msg.message);
            const position = getPayloadPosition(msg.message);
            utils.log.info(`[nav] exalted_wolf recebido de ${ws.userData?.name || 'unknown'} em ${ws.userData?.channel || 'unknown'} ${position ? `${position.x},${position.y},${position.z}` : 'sem-pos'}; broadcast permitido${saved ? '' : ' (nao salvo)'}`);
            return undefined;
        }
        return true;
    }, state);

    await new Promise((resolve, reject) => {
        const host = config.HOST || 'localhost';
        httpServer.listen(config.HTTP_PORT, () => {
            utils.log.success(`HTTP server running at http://${host}:${config.HTTP_PORT}`);
            resolve();
        }).on('error', (err) => {
            if (err.code === 'EADDRINUSE') {
                reject(new Error(`Port ${config.HTTP_PORT} is already in use.`));
            } else {
                reject(err);
            }
        });
    });
};

module.exports.deps = ['express'];

module.exports.meta = {
    name: 'http-server',
    description: 'Express-based HTTP API and static file server with IP filtering and stats endpoint.',
    author: 'Lee',
    version: '1.0.0',
    priority: 70,
    enabled: true
};
