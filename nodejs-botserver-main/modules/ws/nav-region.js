const fs = require('fs');
const path = require('path');

const DEFAULT_LEASE_MS = 15000;
const ACTIVE_MEMBER_TTL_MS = 12000;
const ROUTE_REFRESH_MS = 15000;
const VERTICAL_LOCK_FLOORS = 1;
const REGION_XY_LOCK_PADDING = 2;
const SCAN_RADIUS = 7;
const TARGET_REACHED_RADIUS = 6;
const EXPLORE_SEGMENT_POINTS = 18;
const EXPLORE_MIN_SEGMENT_POINTS = 8;
const ASSIGNMENT_STALE_MS = 60000;
const DEATH_RADIUS = 14;
const ROUTE_COLORS = [
    '#7dd3fc',
    '#86efac',
    '#fde68a',
    '#fca5a5',
    '#c4b5fd',
    '#f9a8d4',
    '#67e8f9',
    '#bef264',
    '#fdba74',
    '#93c5fd'
];

const ROUTE_FILES = [
    { id: 'city_tier', name: 'City Tier', file: 'city_tier.cfg' },
    { id: 'tier_full_ice', name: 'Tier Full Ice', file: 'tier_full_ice.cfg' }
];

module.exports = async ({ utils, state }) => {
    state.navRegionCoordinator = state.navRegionCoordinator || {
        channels: {},
        routesLoadedAt: 0,
        routeBucketKey: '',
        routePoints: [],
        routePointsByRoute: {},
        claims: 0,
        releases: 0,
        denied: 0
    };

    const root = state.navRegionCoordinator;
    const now = () => Date.now();

    function channelName(ws) {
        return String(ws?.userData?.channel || 'default');
    }

    function userName(ws, payload) {
        return String(payload?.name || ws?.userData?.name || '');
    }

    function cleanId(value) {
        return String(value || '').replace(/[^a-z0-9_-]+/gi, '_').slice(0, 48) || 'anon';
    }

    function getChannelState(channel) {
        if (!root.channels[channel]) {
            root.channels[channel] = {
                regions: {},
                members: {},
                assignments: {},
                scanned: {},
                scannedResetAt: 0,
                seq: 0
            };
        }
        const channelState = root.channels[channel];
        channelState.regions = channelState.regions || {};
        channelState.members = channelState.members || {};
        channelState.assignments = channelState.assignments || {};
        channelState.scanned = channelState.scanned || {};
        channelState.seq = Number(channelState.seq) || 0;
        return channelState;
    }

    function finiteLease(value) {
        const n = Number(value);
        if (!Number.isFinite(n)) return DEFAULT_LEASE_MS;
        return Math.max(5000, Math.min(60000, n));
    }

    function normalizePosition(pos) {
        if (!pos || typeof pos !== 'object') return null;
        const x = Number(pos.x);
        const y = Number(pos.y);
        const z = Number(pos.z);
        if (!Number.isFinite(x) || !Number.isFinite(y) || !Number.isFinite(z)) return null;
        return { x: Math.floor(x), y: Math.floor(y), z: Math.floor(z) };
    }

    function pointKey(pos) {
        return `${pos.x},${pos.y},${pos.z}`;
    }

    function routePath(route) {
        const candidates = [
            path.join(process.cwd(), 'data', 'nav-routes', route.file),
            path.join(process.cwd(), 'public', 'botserver', route.file),
            path.join(process.cwd(), route.file)
        ];
        return candidates.find(file => fs.existsSync(file));
    }

    function parseRouteFile(route) {
        const filePath = routePath(route);
        if (!filePath) return [];

        const content = fs.readFileSync(filePath, 'utf8');
        const points = [];
        for (const line of content.split(/\r?\n/)) {
            const match = line.match(/^\s*(goto|use)\s*:\s*(-?\d+)\s*,\s*(-?\d+)\s*,\s*(-?\d+)/i);
            if (!match) continue;
            const pos = normalizePosition({ x: match[2], y: match[3], z: match[4] });
            if (!pos) continue;
            points.push({
                action: 'goto',
                x: pos.x,
                y: pos.y,
                z: pos.z,
                key: pointKey(pos),
                routeId: route.id,
                routeName: route.name,
                routeIndex: points.length
            });
        }
        return points;
    }

    function loadRoutes(force = false) {
        const bucket = ROUTE_FILES
            .map(route => {
                const file = routePath(route);
                if (!file) return `${route.id}:missing`;
                const stat = fs.statSync(file);
                return `${route.id}:${stat.mtimeMs}:${stat.size}`;
            })
            .join('|');

        if (!force && root.routeBucketKey === bucket && root.routesLoadedAt && now() - root.routesLoadedAt < ROUTE_REFRESH_MS) {
            return root.routePoints;
        }

        const routePoints = [];
        const routePointsByRoute = {};
        const seen = new Set();
        for (const route of ROUTE_FILES) {
            const points = parseRouteFile(route);
            routePointsByRoute[route.id] = [];
            for (const point of points) {
                const key = point.key || pointKey(point);
                if (seen.has(key)) continue;
                seen.add(key);
                const enriched = {
                    ...point,
                    id: `point_${route.id}_${point.routeIndex}`,
                    routeOrder: routePoints.length,
                    color: ROUTE_COLORS[routePoints.length % ROUTE_COLORS.length]
                };
                routePoints.push(enriched);
                routePointsByRoute[route.id].push(enriched);
            }
        }

        root.routePoints = routePoints;
        root.routePointsByRoute = routePointsByRoute;
        root.routeBucketKey = bucket;
        root.routesLoadedAt = now();
        return root.routePoints;
    }

    function boundsFor(points) {
        const bounds = points.reduce((acc, point) => {
            if (!acc) {
                return { x1: point.x, y1: point.y, z1: point.z, x2: point.x, y2: point.y, z2: point.z };
            }
            acc.x1 = Math.min(acc.x1, point.x);
            acc.y1 = Math.min(acc.y1, point.y);
            acc.z1 = Math.min(acc.z1, point.z);
            acc.x2 = Math.max(acc.x2, point.x);
            acc.y2 = Math.max(acc.y2, point.y);
            acc.z2 = Math.max(acc.z2, point.z);
            return acc;
        }, null);

        if (!bounds) return null;
        bounds.center = {
            x: Math.round((bounds.x1 + bounds.x2) / 2),
            y: Math.round((bounds.y1 + bounds.y2) / 2),
            z: Math.round((bounds.z1 + bounds.z2) / 2)
        };
        return bounds;
    }

    function expandedLockBounds(region) {
        const bounds = region?.bounds;
        if (!bounds) return null;
        return {
            x1: bounds.x1 - REGION_XY_LOCK_PADDING,
            y1: bounds.y1 - REGION_XY_LOCK_PADDING,
            z1: bounds.z1 - VERTICAL_LOCK_FLOORS,
            x2: bounds.x2 + REGION_XY_LOCK_PADDING,
            y2: bounds.y2 + REGION_XY_LOCK_PADDING,
            z2: bounds.z2 + VERTICAL_LOCK_FLOORS
        };
    }

    function distance(a, b) {
        const left = normalizePosition(a);
        const right = normalizePosition(b);
        if (!left || !right) return Infinity;
        const xy = Math.max(Math.abs(left.x - right.x), Math.abs(left.y - right.y));
        const floor = Math.abs(left.z - right.z);
        return xy + floor * 18;
    }

    function routeDistance(a, b) {
        const left = normalizePosition(a);
        const right = normalizePosition(b);
        if (!left || !right) return Infinity;
        const xy = Math.max(Math.abs(left.x - right.x), Math.abs(left.y - right.y));
        const floor = Math.abs(left.z - right.z);
        return xy + floor * 4;
    }

    function eventPosition(value) {
        const source = value?.position && typeof value.position === 'object' ? value.position : value;
        return normalizePosition(source);
    }

    function collectDeathEvents() {
        const tier = state.tierOrbs || {};
        const events = [];
        const seen = new Set();
        const add = (death) => {
            const pos = eventPosition(death);
            if (!pos) return;
            const at = Number(death?.at || death?.lootAt || death?.startedAt || 0) || 0;
            const key = `${pointKey(pos)}:${at}`;
            if (seen.has(key)) return;
            seen.add(key);
            events.push({ pos, at });
        };

        if (Array.isArray(tier.deaths)) tier.deaths.forEach(add);
        if (Array.isArray(tier.collections)) tier.collections.forEach(collection => add(collection?.latestDeath));
        add(tier.latestWolfDeath);
        add(tier.latestWolf);
        return events;
    }

    function latestDeathAt() {
        return collectDeathEvents().reduce((latest, death) => Math.max(latest, Number(death.at) || 0), 0);
    }

    function deathStatsForPoints(points, deaths) {
        let count = 0;
        let nearest = Infinity;
        for (const death of deaths) {
            let best = Infinity;
            for (const point of points) {
                best = Math.min(best, routeDistance(point, death.pos));
            }
            nearest = Math.min(nearest, best);
            if (best <= DEATH_RADIUS) count++;
        }
        return {
            count,
            nearest: Number.isFinite(nearest) ? nearest : null
        };
    }

    function pointDeathWeight(point, deaths) {
        let weight = 0;
        let nearest = Infinity;
        for (const death of deaths) {
            const d = routeDistance(point, death.pos);
            nearest = Math.min(nearest, d);
            if (d <= DEATH_RADIUS) weight += Math.max(1, DEATH_RADIUS - d + 1);
        }
        return {
            heat: weight,
            cold: Number.isFinite(nearest) ? Math.min(50, nearest * 0.45) : 30
        };
    }

    function cleanup(channelState) {
        const currentTime = now();
        for (const [regionId, claim] of Object.entries(channelState.regions || {})) {
            if (!claim || !claim.expiresAt || claim.expiresAt <= currentTime) {
                delete channelState.regions[regionId];
                delete channelState.assignments[regionId];
            }
        }
        for (const [name, member] of Object.entries(channelState.members || {})) {
            if (!member?.seenAt || currentTime - member.seenAt > ACTIVE_MEMBER_TTL_MS) {
                delete channelState.members[name];
            }
        }
    }

    function resetScannedIfNeeded(channelState) {
        const deathAt = latestDeathAt();
        if (deathAt > (Number(channelState.scannedResetAt) || 0)) {
            channelState.scanned = {};
            channelState.scannedResetAt = deathAt;
        }
    }

    function touchMember(channelState, name, payload) {
        if (!name) return;
        const role = String(payload.role || '');
        if (role !== 'scout' && role !== 'leader') return;
        channelState.members[name] = {
            role,
            position: normalizePosition(payload.position),
            seenAt: now()
        };
    }

    function activeCounts(channelState) {
        cleanup(channelState);
        const counts = { scout: 0, leader: 0, total: 0 };
        for (const member of Object.values(channelState.members || {})) {
            if (!member || now() - member.seenAt > ACTIVE_MEMBER_TTL_MS) continue;
            if (member.role === 'scout') counts.scout++;
            if (member.role === 'leader') counts.leader++;
            counts.total++;
        }
        return counts;
    }

    function roleCanExplore(channelState, role) {
        const counts = activeCounts(channelState);
        if (role === 'scout') return true;
        if (role === 'leader') return counts.scout <= 0;
        return false;
    }

    function markScannedNearPosition(channelState, pos, name) {
        const position = normalizePosition(pos);
        if (!position) return;
        loadRoutes(false);

        for (const point of root.routePoints) {
            if (routeDistance(point, position) > SCAN_RADIUS) continue;
            channelState.scanned[point.key] = {
                at: now(),
                by: name,
                x: point.x,
                y: point.y,
                z: point.z
            };
        }
    }

    function isScanned(channelState, point) {
        return Boolean(channelState.scanned?.[point.key]);
    }

    function otherMemberDistance(channelState, point, name) {
        let best = Infinity;
        for (const [memberName, member] of Object.entries(channelState.members || {})) {
            if (memberName === name || !member?.position) continue;
            if (now() - member.seenAt > ACTIVE_MEMBER_TTL_MS) continue;
            best = Math.min(best, distance(point, member.position));
        }
        return best;
    }

    function otherClaimDistance(channelState, point, name) {
        let best = Infinity;
        const currentTime = now();
        for (const [regionId, claim] of Object.entries(channelState.regions || {})) {
            if (!claim || claim.name === name || claim.expiresAt <= currentTime) continue;
            const region = channelState.assignments[regionId];
            const anchor = region?.target || region?.bounds?.center || claim.position;
            best = Math.min(best, distance(point, anchor));
        }
        return best;
    }

    function chooseTargetPoint(channelState, payload, name) {
        const points = loadRoutes(false);
        if (!points.length) return null;

        const position = normalizePosition(payload.position);
        const deaths = collectDeathEvents();
        const unscanned = points.filter(point => !isScanned(channelState, point));
        const candidates = unscanned;
        if (!candidates.length) return null;

        let best = null;
        let bestScore = -Infinity;
        for (const point of candidates) {
            const memberSpread = otherMemberDistance(channelState, point, name);
            const claimSpread = otherClaimDistance(channelState, point, name);
            const fromSelf = position ? distance(point, position) : 40;
            const death = pointDeathWeight(point, deaths);

            let score = 0;
            score += Math.min(Number.isFinite(memberSpread) ? memberSpread : 80, 80) * 5;
            score += Math.min(Number.isFinite(claimSpread) ? claimSpread : 100, 100) * 6;
            score += Math.min(fromSelf, 120) * 0.45;
            score += death.heat * 12;
            score += death.cold;
            if (fromSelf < 12) score -= 350;

            if (score > bestScore) {
                bestScore = score;
                best = point;
            }
        }
        return best;
    }

    function buildSegment(channelState, target) {
        const routePoints = root.routePointsByRoute[target.routeId] || [];
        if (!routePoints.length) return [target];

        const start = routePoints.findIndex(point => point.key === target.key);
        const startIndex = start >= 0 ? start : 0;
        const selected = [];
        const selectedKeys = new Set();

        for (let offset = 0; offset < routePoints.length && selected.length < EXPLORE_SEGMENT_POINTS; offset++) {
            const point = routePoints[(startIndex + offset) % routePoints.length];
            if (!point || selectedKeys.has(point.key)) continue;
            if (isScanned(channelState, point) && point.key !== target.key) continue;
            selected.push(point);
            selectedKeys.add(point.key);
        }

        return selected.length ? selected : [target];
    }

    function buildAssignment(channelState, payload, name, target) {
        const points = buildSegment(channelState, target);
        const deaths = collectDeathEvents();
        const stats = deathStatsForPoints(points, deaths);
        const bounds = boundsFor(points);
        channelState.seq += 1;
        const id = `explore_${cleanId(name)}_${channelState.seq}_${cleanId(target.key)}`;

        return {
            id,
            routeId: target.routeId,
            routeName: target.routeName || 'Exploracao',
            name: `Exploracao ${channelState.seq}`,
            mode: 'explore',
            large: false,
            color: ROUTE_COLORS[channelState.seq % ROUTE_COLORS.length],
            target: { x: target.x, y: target.y, z: target.z },
            finish: points[points.length - 1],
            points,
            bounds,
            pointCount: points.length,
            heatCount: stats.count,
            nearestDeathDistance: stats.nearest,
            hot: stats.count > 0,
            cold: stats.count === 0,
            scannedCount: Object.keys(channelState.scanned || {}).length,
            totalRoutePoints: root.routePoints.length
        };
    }

    function segmentComplete(channelState, region, position) {
        const pos = normalizePosition(position);
        if (!region?.points?.length) return true;
        const scannedCount = region.points.filter(point => isScanned(channelState, point)).length;
        const reachedFinish = pos && distance(pos, region.finish || region.target) <= TARGET_REACHED_RADIUS;
        if (reachedFinish) return true;
        return scannedCount >= Math.max(3, Math.ceil(region.points.length * 0.75));
    }

    function shouldReassign(channelState, claim, region, payload) {
        if (!claim || !region) return true;
        if (now() - Number(claim.claimedAt || 0) > ASSIGNMENT_STALE_MS) return true;
        return segmentComplete(channelState, region, payload.position);
    }

    function removeClaimsByName(channelState, name) {
        for (const [regionId, claim] of Object.entries(channelState.regions || {})) {
            if (claim && claim.name === name) {
                delete channelState.regions[regionId];
                delete channelState.assignments[regionId];
            }
        }
    }

    function claimAssignment(channelState, name, payload, region) {
        const expiresAt = now() + finiteLease(payload.leaseMs);
        const role = String(payload.role || '');
        const position = normalizePosition(payload.position);
        removeClaimsByName(channelState, name);
        channelState.assignments[region.id] = region;
        channelState.regions[region.id] = {
            name,
            role,
            routeId: region.routeId,
            routeName: region.routeName,
            regionName: region.name,
            mode: region.mode,
            position,
            target: region.target,
            claimedAt: now(),
            expiresAt,
            bundleId: region.id,
            bundleSize: 1,
            primaryRegionId: region.id
        };
        root.claims += 1;
        return expiresAt;
    }

    function refreshAssignment(channelState, name, payload, regionId) {
        const claim = channelState.regions[regionId];
        const region = channelState.assignments[regionId];
        if (!claim || !region || claim.name !== name) return null;
        const expiresAt = now() + finiteLease(payload.leaseMs);
        channelState.regions[regionId] = {
            ...claim,
            position: normalizePosition(payload.position),
            expiresAt
        };
        return { region, expiresAt };
    }

    function claimResponse(name, payload, region, expiresAt) {
        return {
            action: 'claim_result',
            requester: name,
            target: name,
            regionId: region.id,
            regionIds: [region.id],
            routeId: region.routeId,
            routeName: region.routeName,
            regionName: region.name,
            mode: region.mode,
            role: String(payload.role || ''),
            large: false,
            color: region.color,
            bounds: region.bounds,
            lockBounds: expandedLockBounds(region),
            verticalLockFloors: VERTICAL_LOCK_FLOORS,
            points: region.points,
            pointCount: region.pointCount,
            heatCount: region.heatCount,
            hot: region.hot === true,
            cold: region.cold === true,
            scannedCount: region.scannedCount,
            totalRoutePoints: region.totalRoutePoints,
            bundleSize: 1,
            granted: true,
            expiresAt,
            owner: {
                name,
                role: String(payload.role || ''),
                routeId: region.routeId,
                routeName: region.routeName,
                regionName: region.name,
                mode: region.mode,
                bundleSize: 1,
                expiresAt
            }
        };
    }

    function compactClaim(channel, claim, region) {
        return {
            id: region.id,
            routeId: region.routeId,
            routeName: region.routeName,
            name: region.name,
            mode: region.mode,
            large: false,
            bounds: region.bounds,
            lockBounds: expandedLockBounds(region),
            verticalLockFloors: VERTICAL_LOCK_FLOORS,
            center: region.bounds?.center || null,
            target: region.target,
            finish: region.finish,
            color: region.color,
            pointCount: region.pointCount,
            points: region.points,
            heatCount: region.heatCount,
            hot: region.hot === true,
            cold: region.cold === true,
            scannedCount: region.scannedCount,
            totalRoutePoints: region.totalRoutePoints,
            owner: {
                name: claim.name,
                role: claim.role,
                routeId: claim.routeId,
                routeName: claim.routeName,
                regionName: claim.regionName,
                mode: claim.mode,
                channel,
                remainingMs: Math.max(0, claim.expiresAt - now()),
                expiresAt: claim.expiresAt
            }
        };
    }

    function snapshot() {
        loadRoutes(false);
        const items = [];
        for (const [channel, channelState] of Object.entries(root.channels || {})) {
            cleanup(channelState);
            resetScannedIfNeeded(channelState);
            for (const [regionId, claim] of Object.entries(channelState.regions || {})) {
                const region = channelState.assignments?.[regionId];
                if (!claim || !region || claim.expiresAt <= now()) continue;
                items.push(compactClaim(channel, claim, region));
            }
        }
        return items;
    }

    root.snapshot = snapshot;
    loadRoutes(true);

    utils.registerWsHook('nav_region', (ws, msg, response) => {
        const payload = msg.message || {};
        const action = String(payload.action || 'claim');
        const channel = channelName(ws);
        const channelState = getChannelState(channel);
        const name = userName(ws, payload);
        const requestedRegionId = String(payload.regionId || '').trim();

        loadRoutes(false);
        resetScannedIfNeeded(channelState);
        touchMember(channelState, name, payload);
        markScannedNearPosition(channelState, payload.position, name);
        cleanup(channelState);

        if (!name) {
            response.message = {
                action: 'claim_result',
                requester: name,
                target: name,
                granted: false,
                reason: 'invalid_user'
            };
            return false;
        }

        if (action === 'release') {
            const current = requestedRegionId ? channelState.regions[requestedRegionId] : null;
            const released = Boolean(current && current.name === name);
            if (released) {
                delete channelState.regions[requestedRegionId];
                delete channelState.assignments[requestedRegionId];
                root.releases++;
            } else {
                removeClaimsByName(channelState, name);
            }
            response.message = {
                action: 'region_released',
                requester: name,
                regionId: requestedRegionId,
                released
            };
            return false;
        }

        if (action !== 'claim' && action !== 'heartbeat') {
            response.message = {
                action: 'claim_result',
                requester: name,
                target: name,
                regionId: requestedRegionId,
                granted: false,
                reason: 'invalid_action'
            };
            return false;
        }

        if (!roleCanExplore(channelState, String(payload.role || ''))) {
            removeClaimsByName(channelState, name);
            root.denied++;
            response.message = {
                action: 'claim_result',
                requester: name,
                target: name,
                regionId: requestedRegionId,
                granted: false,
                reason: 'lease_lost',
                owner: {
                    name: 'Scouts ativos',
                    role: 'scout'
                }
            };
            return false;
        }

        const currentClaim = requestedRegionId ? channelState.regions[requestedRegionId] : null;
        const currentRegion = requestedRegionId ? channelState.assignments[requestedRegionId] : null;
        if (
            action === 'heartbeat'
            && currentClaim
            && currentRegion
            && currentClaim.name === name
            && !shouldReassign(channelState, currentClaim, currentRegion, payload)
        ) {
            const refreshed = refreshAssignment(channelState, name, payload, requestedRegionId);
            if (refreshed) {
                response.message = claimResponse(name, payload, refreshed.region, refreshed.expiresAt);
                return false;
            }
        }

        const target = chooseTargetPoint(channelState, payload, name);
        if (!target) {
            removeClaimsByName(channelState, name);
            root.denied++;
            response.message = {
                action: 'claim_result',
                requester: name,
                target: name,
                regionId: requestedRegionId,
                granted: false,
                reason: 'no_route_point_available'
            };
            return false;
        }

        const region = buildAssignment(channelState, payload, name, target);
        const expiresAt = claimAssignment(channelState, name, payload, region);
        response.message = claimResponse(name, payload, region, expiresAt);
        return false;
    }, state);

    utils.log.success(`Nav exploration coordinator loaded (${root.routePoints.length} route points)`);
};

module.exports.meta = {
    name: 'nav-region',
    description: 'Coordinates dynamic BotServerNav exploration targets and avoids already scanned route points.',
    author: 'Codex',
    version: '2.0.0',
    priority: 30,
    enabled: false
};
