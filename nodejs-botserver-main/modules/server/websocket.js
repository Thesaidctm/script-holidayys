module.exports = async ({ config, utils, state }) => {
    const WebSocket = require('ws');

    const server = await new Promise((resolve, reject) => {
        const options = {
            maxPayload: config.WS_MAX_PAYLOAD,
        };

        if (state.httpServer && config.WS_PORT === config.HTTP_PORT) {
            options.server = state.httpServer;
        } else {
            options.port = config.WS_PORT;
        }

        const wss = new WebSocket.Server(options);

        if (options.server) {
            utils.log.success(`WebSocket server attached to HTTP port ${config.WS_PORT}`);
            state.wsStartTime = Date.now();
            return resolve(wss);
        }

        wss.on('listening', () => {
            utils.log.success(`WebSocket server running on port ${config.WS_PORT}`);
            state.wsStartTime = Date.now();
            resolve(wss);
        });

        wss.on('error', (err) => {
            if (err.code === 'EADDRINUSE') {
                return reject(new Error(`Port ${config.WS_PORT} already in use`));
            }
            reject(err);
        });
    });

    const millis = () => Date.now();
    const NAV_DEBUG_TOPICS = new Set([
        'farm_nav',
        'exalted_wolf',
        'wolf_report',
        'wolf_assign',
        'wolf_done',
        'wolf_status'
    ]);

    function compactPayload(payload) {
        if (payload === undefined || payload === null) return payload;
        try {
            const safe = typeof payload === 'object'
                ? JSON.parse(JSON.stringify(payload))
                : payload;
            const json = JSON.stringify(safe);
            if (json && json.length > 1600) {
                return { truncated: true, text: json.slice(0, 1600) };
            }
            return safe;
        } catch {
            return String(payload).slice(0, 1600);
        }
    }

    function pushNavDebugEvent(event) {
        state.navDebugEvents = Array.isArray(state.navDebugEvents) ? state.navDebugEvents : [];
        const item = {
            id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
            at: Date.now(),
            time: new Date().toLocaleString('pt-BR'),
            ...event
        };
        state.navDebugEvents.unshift(item);
        if (state.navDebugEvents.length > 200) {
            state.navDebugEvents.length = 200;
        }
        return item;
    }

    function sendMessageToChannel(channel, message, options = {}) {
        if (!state.channels[channel]) return [];

        const body = JSON.stringify(message);
        const receivers = [];
        state.channels[channel].forEach((client) => {
            try {
                receivers.push(client.userData?.name || '');
                client.send(body);
            } catch (error) {
                utils.log.warn(`WS send failed [${channel}]: ${error.message}`);
            }
        });

        if (NAV_DEBUG_TOPICS.has(message.topic)) {
            pushNavDebugEvent({
                direction: options.direction || 'broadcast',
                source: options.source || 'client',
                topic: message.topic,
                channel,
                sender: options.sender || message.name || '',
                receiverCount: receivers.length,
                receivers,
                status: receivers.length > 0 ? 'sent' : 'empty-channel',
                note: options.note || '',
                message: compactPayload(message.message)
            });
        }

        return receivers;
    }

    state.pushNavDebugEvent = pushNavDebugEvent;
    state.sendWsMessageToChannel = sendMessageToChannel;

    server.on('connection', (ws) => {
        state.connections++;
        utils.log.info(`\x1b[33mClient connected.\x1b[0m Total: \x1b[36m${state.connections}\x1b[0m`);

        ws.userData = {
            name: '',
            channel: '',
            lastPing: 0,
            lastPingSent: 0,
            packets: 0,
            packetsTime: 0,
            totalPackets: 0,
            activeTime: millis(),
            messagesSent: 0
        };

        ws.messageId = 0;

        ws.on('message', (message) => {
            if (message.length > config.WS_MAX_PAYLOAD) {
                state.blocked++;
                return ws.close();
            }

            try {
                processMessage(ws, message);
            } catch (err) {
                state.exceptions++;
                console.error(`JSON parse error: ${err.message}`);
                console.error(`Invalid payload:`, message.toString());
                return ws.close();
            }
        });

        ws.on('close', () => {
            const { name, channel } = ws.userData;
            if (state.channels[channel]) {
                state.channels[channel].delete(ws);
                if (state.channels[channel].size === 0) {
                    delete state.channels[channel];
                }
            }

            utils.log.dim(`\x1b[31m${name} disconnected from channel:\x1b[0m \x1b[35m${channel}\x1b[0m`);
            state.connections--;
        });

        ws.on('error', (error) => {
            console.error(`WebSocket error: ${error.message}`);
        });
    });

    setInterval(sendPing, config.PING_INTERVAL || 1000);

    function sendPing() {
        Object.keys(state.channels).forEach((channel) => {
            state.channels[channel].forEach((ws) => {
                try {
                    ws.userData.lastPingSent = millis();
                    ws.send(JSON.stringify({ type: 'ping', ping: ws.userData.lastPing }));
                } catch {
                    ws.terminate();
                }
            });
        });
    }

    function processMessage(ws, message) {
        state.packets++;

        const userData = ws.userData;
        const msg = JSON.parse(message);

        if (!userData.name || !userData.channel) {
            if (msg.type !== 'init') return ws.close();

            userData.name = msg.name;
            userData.channel = msg.channel;
            userData.lastPingSent = millis();
            userData.activeTime = millis();
            userData.messagesSent = 0;

            if (!state.channels[userData.channel]) {
                state.channels[userData.channel] = new Set();
                state.channels[userData.channel].created = new Date();
            }

            state.channels[userData.channel].add(ws);

            utils.log.info(`\x1b[36m${userData.name} has joined channel:\x1b[0m \x1b[35m${userData.channel}\x1b[0m`);
            return;
        }

        const currentSeconds = Math.floor(Date.now() / 1000);
        if (userData.packetsTime < currentSeconds) {
            userData.packetsTime = currentSeconds + 1;
            userData.packets = 0;
        }

        userData.packets++;
        userData.totalPackets++;

        if (userData.packets > config.WS_MAX_PACKETS || message.length > config.WS_MAX_PAYLOAD) {
            state.blocked++;
            return ws.close();
        }

        if (msg.type === 'ping') {
            userData.lastPing = millis() - userData.lastPingSent;
            return;
        }

        if (msg.type !== 'message') return ws.close();

        const response = {
            type: 'message',
            id: ++ws.messageId,
            name: userData.name,
            topic: msg.topic,
        };

        if (!msg.topic || msg.topic.length > config.WS_MAX_TOPIC_LENGTH) {
            return ws.close();
        }

        if (msg.topic === 'list') {
            const users = Array.from(state.channels[userData.channel]).map(client => client.userData.name);
            response.message = users;
            ws.send(JSON.stringify(response));
            return;
        }

        response.message = msg.message;

        const hook = state.wsTopicHooks?.[msg.topic];
        if (hook) {
            try {
                const r = hook(ws, msg, response);
                if (r === true) {
                    if (NAV_DEBUG_TOPICS.has(msg.topic)) {
                        const consumedByCoordinator = msg.topic === 'wolf_status'
                            || msg.topic === 'wolf_report'
                            || msg.topic === 'wolf_done';
                        pushNavDebugEvent({
                            direction: consumedByCoordinator ? 'coordinator' : 'blocked',
                            source: 'hook',
                            topic: msg.topic,
                            channel: userData.channel,
                            sender: userData.name,
                            receiverCount: 0,
                            receivers: [],
                            status: consumedByCoordinator ? 'hook-consumed' : 'hook-blocked',
                            message: compactPayload(msg.message)
                        });
                    }
                    return;
                }
            } catch (err) {
                utils.log.warn(`WS Hook Error [${msg.topic}]: ${err.message}`);
            }
        }

        dispatchMessage(ws, response);
        userData.messagesSent++;
    }

    function dispatchMessage(ws, message) {
        const channel = ws.userData.channel;
        sendMessageToChannel(channel, message, {
            direction: 'broadcast',
            source: 'client',
            sender: ws.userData?.name || message.name || ''
        });
    }
};

module.exports.deps = ['ws'];

module.exports.meta = {
    name: 'websocket-server',
    description: 'WebSocket server for handling real-time client communication, channels, and ping tracking.',
    author: 'Lee',
    version: '1.0.0',
    priority: 60,
    enabled: true
};
