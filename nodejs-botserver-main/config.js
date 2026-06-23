module.exports = {
    appTitle: 'NodeJS BotServer',
    HTTP_HOST: 'localhost',
    HTTP_PORT: 8080,
    HTTP_ALLOWED_IPS: ['127.0.0.1', '::1'],
    DASHBOARD_AUTH_ENABLED: process.env.BOTSERVER_DASHBOARD_AUTH !== '0',
    DASHBOARD_USERNAME: process.env.BOTSERVER_DASHBOARD_USER || 'admin',
    DASHBOARD_PASSWORD: process.env.BOTSERVER_DASHBOARD_PASSWORD || '@Senha123',
    DASHBOARD_SESSION_SECRET: process.env.BOTSERVER_DASHBOARD_SECRET || 'botserver-local-session-secret',
    WS_PORT: 8080,
    WS_MAX_PAYLOAD: 64 * 1024,
    WS_MAX_PACKETS: 100,
    WS_MAX_TOPIC_LENGTH: 30,
};
