const BOSS_TTL_MS = 60000;
const LEADER_TTL_MS = 6000;
const ASSIGN_LOCK_MS = 15000;
const REASSIGN_MARGIN = 8;

module.exports = async ({ utils, state }) => {
    state.wolfCoordinator = state.wolfCoordinator || {
        channels: {},
        startedAt: Date.now(),
        sentAssignments: 0,
        reports: 0,
        pings: 0
    };

    const root = state.wolfCoordinator;

    const now = () => Date.now();

    function channelName(ws) {
        return String(ws?.userData?.channel || 'default');
    }

    function getChannelState(channel) {
        if (!root.channels[channel]) {
            root.channels[channel] = {
                boss: null,
                leaders: new Map(),
                assignedLeader: null,
                assignedUntil: 0,
                lastDispatchKey: ''
            };
        }

        return root.channels[channel];
    }

    function finiteNumber(value) {
        const n = Number(value);
        return Number.isFinite(n) ? n : null;
    }

    function validPos(pos) {
        return pos
            && Number.isFinite(pos.x)
            && Number.isFinite(pos.y)
            && Number.isFinite(pos.z);
    }

    function normalizePos(payload) {
        if (!payload || typeof payload !== 'object') return null;

        const source = payload.pos && typeof payload.pos === 'object' ? payload.pos : payload;
        const x = finiteNumber(source.x);
        const y = finiteNumber(source.y);
        const z = finiteNumber(source.z);

        if (x === null || y === null || z === null) return null;
        return { x, y, z };
    }

    function posKey(pos) {
        return `${pos.x},${pos.y},${pos.z}`;
    }

    function distance(a, b) {
        if (!validPos(a) || !validPos(b)) return Infinity;
        if (a.z !== b.z) return Infinity;
        return Math.max(Math.abs(a.x - b.x), Math.abs(a.y - b.y));
    }

    function connectedClients(channel) {
        const clients = state.channels[channel];
        if (!clients) return [];
        return Array.from(clients).filter(client => client && client.readyState === 1);
    }

    function sendTo(ws, topic, message) {
        try {
            ws.send(JSON.stringify({
                type: 'message',
                id: Date.now(),
                name: 'wolf-coordinator',
                topic,
                message
            }));
            return true;
        } catch {
            return false;
        }
    }

    function cleanupChannel(channel, channelState) {
        const tm = now();

        if (channelState.boss && tm - channelState.boss.seenAt > BOSS_TTL_MS) {
            channelState.boss = null;
            channelState.assignedLeader = null;
            channelState.assignedUntil = 0;
            channelState.lastDispatchKey = '';
        }

        for (const [name, leader] of channelState.leaders.entries()) {
            if (tm - leader.seenAt > LEADER_TTL_MS) {
                channelState.leaders.delete(name);
            }
        }

        if (!state.channels[channel] && !channelState.boss && channelState.leaders.size === 0) {
            delete root.channels[channel];
        }
    }

    function chooseBestLeader(channelState) {
        if (!channelState.boss || now() - channelState.boss.seenAt > BOSS_TTL_MS) {
            return null;
        }

        let best = null;
        for (const [name, leader] of channelState.leaders.entries()) {
            if (now() - leader.seenAt > LEADER_TTL_MS) continue;

            const d = distance(leader.pos, channelState.boss.pos);
            if (!best || d < best.distance) {
                best = { name, distance: d, leader };
            }
        }

        return best;
    }

    function chooseAssignedLeader(channelState, best) {
        if (!best) return null;

        const current = channelState.assignedLeader
            ? channelState.leaders.get(channelState.assignedLeader)
            : null;

        if (current && channelState.assignedUntil > now()) {
            const currentDistance = distance(current.pos, channelState.boss.pos);
            if (currentDistance <= best.distance + REASSIGN_MARGIN) {
                return {
                    name: channelState.assignedLeader,
                    distance: currentDistance,
                    leader: current
                };
            }
        }

        channelState.assignedLeader = best.name;
        channelState.assignedUntil = now() + ASSIGN_LOCK_MS;
        return best;
    }

    function dispatchAssignment(channel) {
        const channelState = getChannelState(channel);
        cleanupChannel(channel, channelState);

        const best = chooseBestLeader(channelState);
        const assigned = chooseAssignedLeader(channelState, best);
        const boss = channelState.boss;
        if (!assigned || !boss) return;

        const dispatchKey = [
            boss.eventId,
            posKey(boss.pos),
            assigned.name,
            Math.floor(channelState.assignedUntil / 1000)
        ].join('|');

        if (channelState.lastDispatchKey === dispatchKey) return;
        channelState.lastDispatchKey = dispatchKey;

        for (const client of connectedClients(channel)) {
            const clientName = String(client.userData?.name || '');
            const isAssigned = clientName === assigned.name;
            sendTo(client, 'wolf_assign', {
                assigned: isAssigned,
                leader: assigned.name,
                boss: boss.pos,
                eventId: boss.eventId,
                scout: boss.scout,
                hp: boss.hp,
                distance: isAssigned && Number.isFinite(assigned.distance) ? assigned.distance : null,
                expiresAt: boss.seenAt + BOSS_TTL_MS,
                assignedUntil: channelState.assignedUntil
            });
        }

        root.sentAssignments++;
        utils.log.info(`[wolf] ${channel}: ${assigned.name} assigned to ${posKey(boss.pos)}`);
    }

    utils.registerWsHook('wolf_report', (ws, msg) => {
        const payload = msg.message || {};
        const pos = normalizePos(payload);
        if (!validPos(pos)) return true;

        const channel = channelName(ws);
        const channelState = getChannelState(channel);
        const key = posKey(pos);
        const oldKey = channelState.boss ? posKey(channelState.boss.pos) : '';

        channelState.boss = {
            pos,
            key,
            hp: payload.hp ?? null,
            scout: String(payload.scout || ws.userData?.name || ''),
            eventId: String(payload.eventId || `${key}:${Math.floor(now() / 10000)}`),
            seenAt: now()
        };

        if (oldKey !== key) {
            channelState.assignedLeader = null;
            channelState.assignedUntil = 0;
            channelState.lastDispatchKey = '';
        }

        root.reports++;
        dispatchAssignment(channel);
        return true;
    }, state);

    utils.registerWsHook('leader_ping', (ws, msg) => {
        const payload = msg.message || {};
        const pos = normalizePos(payload);
        if (!validPos(pos)) return true;

        const channel = channelName(ws);
        const channelState = getChannelState(channel);
        const name = String(payload.name || ws.userData?.name || '');

        if (!name) return true;

        channelState.leaders.set(name, {
            pos,
            seenAt: now(),
            ws
        });

        root.pings++;
        dispatchAssignment(channel);
        return true;
    }, state);

    utils.registerWsHook('wolf_done', (ws, msg) => {
        const channel = channelName(ws);
        const channelState = getChannelState(channel);
        const payload = msg.message || {};
        const eventId = String(payload.eventId || '');

        if (!eventId || (channelState.boss && channelState.boss.eventId === eventId)) {
            channelState.boss = null;
            channelState.assignedLeader = null;
            channelState.assignedUntil = 0;
            channelState.lastDispatchKey = '';

            for (const client of connectedClients(channel)) {
                sendTo(client, 'wolf_clear', {
                    eventId,
                    by: String(ws.userData?.name || '')
                });
            }
        }

        return true;
    }, state);

    utils.registerWsHook('wolf_status', (ws) => {
        const channel = channelName(ws);
        const channelState = getChannelState(channel);
        cleanupChannel(channel, channelState);

        sendTo(ws, 'wolf_status', {
            boss: channelState.boss ? {
                pos: channelState.boss.pos,
                eventId: channelState.boss.eventId,
                scout: channelState.boss.scout,
                hp: channelState.boss.hp,
                seenAt: channelState.boss.seenAt
            } : null,
            assignedLeader: channelState.assignedLeader,
            assignedUntil: channelState.assignedUntil,
            leaders: Array.from(channelState.leaders.entries()).map(([name, leader]) => ({
                name,
                pos: leader.pos,
                seenAt: leader.seenAt
            }))
        });

        return true;
    }, state);

    setInterval(() => {
        for (const [channel, channelState] of Object.entries(root.channels)) {
            cleanupChannel(channel, channelState);
        }
    }, 5000);

    utils.log.success('Wolf coordinator loaded');
};

module.exports.deps = [];

module.exports.meta = {
    name: 'wolf-coordinator',
    description: 'Assigns Exalted Wolf coordinates to the closest active leader.',
    author: 'Derpetson',
    version: '1.0.0',
    priority: 10,
    enabled: true
};
