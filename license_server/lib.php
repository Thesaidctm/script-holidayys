<?php
declare(strict_types=1);

const DATA_DIR = __DIR__ . '/data';
const SCRIPT_DIR = __DIR__ . '/scripts';
const CONFIG_FILE = __DIR__ . '/config.php';
const SETTINGS_FILE = DATA_DIR . '/settings.json';
const LICENSES_FILE = DATA_DIR . '/licenses.json';
const PENDING_FILE = DATA_DIR . '/pending_devices.json';
const EVENTS_FILE = DATA_DIR . '/events.log';

define('JQM_LICENSE_APP', true);

function ensure_dirs(): void
{
    foreach ([DATA_DIR, SCRIPT_DIR] as $dir) {
        if (!is_dir($dir)) {
            mkdir($dir, 0775, true);
        }
    }
}

function now_iso(): string
{
    return gmdate('c');
}

function read_json_file(string $file, array $default): array
{
    ensure_dirs();
    if (!is_file($file)) {
        return $default;
    }

    $raw = file_get_contents($file);
    if (!is_string($raw) || trim($raw) === '') {
        return $default;
    }
    $raw = preg_replace('/^\xEF\xBB\xBF/', '', $raw) ?? $raw;

    $data = json_decode($raw, true);
    return is_array($data) ? $data : $default;
}

function write_json_file(string $file, array $data): void
{
    ensure_dirs();
    $tmp = $file . '.tmp';
    file_put_contents($tmp, json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));
    rename($tmp, $file);
}

function app_config(): array
{
    static $config = null;
    if ($config !== null) {
        return $config;
    }

    $config = [
        'storage' => 'json',
        'mysql' => [
            'host' => 'localhost',
            'database' => '',
            'username' => '',
            'password' => '',
            'charset' => 'utf8mb4',
            'table_prefix' => 'jqm_',
        ],
    ];

    if (is_file(CONFIG_FILE)) {
        $loaded = require CONFIG_FILE;
        if (is_array($loaded)) {
            $config = array_replace_recursive($config, $loaded);
        }
    }

    return $config;
}

function use_mysql(): bool
{
    return strtolower((string)(app_config()['storage'] ?? 'json')) === 'mysql';
}

function mysql_config(): array
{
    $mysql = app_config()['mysql'] ?? [];
    return is_array($mysql) ? $mysql : [];
}

function mysql_config_ready(): bool
{
    $mysql = mysql_config();
    foreach (['host', 'database', 'username'] as $key) {
        $value = trim((string)($mysql[$key] ?? ''));
        if ($value === '' || stripos($value, 'PREENCHA') !== false || stripos($value, 'USUARIO_DO_BANCO') !== false) {
            return false;
        }
    }
    return true;
}

function mysql_table(string $name): string
{
    $prefix = preg_replace('/[^a-zA-Z0-9_]/', '', (string)(mysql_config()['table_prefix'] ?? 'jqm_')) ?: 'jqm_';
    return $prefix . $name;
}

function db(): PDO
{
    static $pdo = null;
    if ($pdo instanceof PDO) {
        return $pdo;
    }
    if (!mysql_config_ready()) {
        throw new RuntimeException('Preencha host, usuario e banco em config.php.');
    }

    $mysql = mysql_config();
    $charset = preg_replace('/[^a-zA-Z0-9_]/', '', (string)($mysql['charset'] ?? 'utf8mb4')) ?: 'utf8mb4';
    $dsn = 'mysql:host=' . (string)$mysql['host'] . ';dbname=' . (string)$mysql['database'] . ';charset=' . $charset;
    $pdo = new PDO($dsn, (string)$mysql['username'], (string)($mysql['password'] ?? ''), [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]);
    return $pdo;
}

function mysql_schema_exists(): bool
{
    if (!use_mysql() || !mysql_config_ready()) {
        return false;
    }
    try {
        $stmt = db()->query("SHOW TABLES LIKE " . db()->quote(mysql_table('settings')));
        return (bool)$stmt->fetchColumn();
    } catch (Throwable $e) {
        return false;
    }
}

function mysql_create_schema(): void
{
    $settings = mysql_table('settings');
    $licenses = mysql_table('licenses');
    $devices = mysql_table('devices');
    $pending = mysql_table('pending_devices');
    $events = mysql_table('events');
    $pdo = db();

    $pdo->exec("CREATE TABLE IF NOT EXISTS `$settings` (
        `name` varchar(80) NOT NULL,
        `value` mediumtext NOT NULL,
        PRIMARY KEY (`name`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

    $pdo->exec("CREATE TABLE IF NOT EXISTS `$licenses` (
        `license_key` varchar(64) NOT NULL,
        `owner` varchar(160) NOT NULL DEFAULT '',
        `status` varchar(32) NOT NULL DEFAULT 'active',
        `allowed_scripts` mediumtext NOT NULL,
        `expires_at` date DEFAULT NULL,
        `max_devices` int NOT NULL DEFAULT 1,
        `notes` text,
        `created_at` varchar(40) NOT NULL DEFAULT '',
        `last_seen_at` varchar(40) NOT NULL DEFAULT '',
        `last_ip` varchar(64) NOT NULL DEFAULT '',
        PRIMARY KEY (`license_key`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

    $pdo->exec("CREATE TABLE IF NOT EXISTS `$devices` (
        `id` bigint unsigned NOT NULL AUTO_INCREMENT,
        `license_key` varchar(64) NOT NULL,
        `device_hash` char(64) NOT NULL,
        `hwid_hash` char(64) NOT NULL DEFAULT '',
        `mac_hash` char(64) NOT NULL DEFAULT '',
        `mac_preview` varchar(32) NOT NULL DEFAULT '',
        `first_seen_at` varchar(40) NOT NULL DEFAULT '',
        `last_seen_at` varchar(40) NOT NULL DEFAULT '',
        `last_ip` varchar(64) NOT NULL DEFAULT '',
        `client_ip_sent` varchar(64) NOT NULL DEFAULT '',
        `char_name` text NOT NULL,
        `emblem` varchar(30) NOT NULL DEFAULT '',
        `user_agent` varchar(255) NOT NULL DEFAULT '',
        PRIMARY KEY (`id`),
        UNIQUE KEY `license_device` (`license_key`, `device_hash`),
        KEY `license_key` (`license_key`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

    $pdo->exec("CREATE TABLE IF NOT EXISTS `$pending` (
        `device_hash` char(64) NOT NULL,
        `hwid_hash` char(64) NOT NULL DEFAULT '',
        `mac_hash` char(64) NOT NULL DEFAULT '',
        `mac_preview` varchar(32) NOT NULL DEFAULT '',
        `requested_script` varchar(80) NOT NULL DEFAULT '',
        `first_seen_at` varchar(40) NOT NULL DEFAULT '',
        `last_seen_at` varchar(40) NOT NULL DEFAULT '',
        `last_ip` varchar(64) NOT NULL DEFAULT '',
        `client_ip_sent` varchar(64) NOT NULL DEFAULT '',
        `char_name` text NOT NULL,
        `emblem` varchar(30) NOT NULL DEFAULT '',
        `user_agent` varchar(255) NOT NULL DEFAULT '',
        `requests_count` int NOT NULL DEFAULT 1,
        PRIMARY KEY (`device_hash`),
        KEY `last_seen_at` (`last_seen_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

    try {
        $pdo->exec("ALTER TABLE `$pending` MODIFY `requested_script` varchar(255) NOT NULL DEFAULT ''");
    } catch (Throwable $e) {
        // Coluna ja pode estar no formato esperado ou o usuario pode nao ter ALTER.
    }
    foreach ([$devices, $pending] as $table) {
        try {
            $pdo->exec("ALTER TABLE `$table` MODIFY `char_name` text NOT NULL");
        } catch (Throwable $e) {
            // Coluna ja pode estar no formato esperado ou o usuario pode nao ter ALTER.
        }
    }

    $pdo->exec("CREATE TABLE IF NOT EXISTS `$events` (
        `id` bigint unsigned NOT NULL AUTO_INCREMENT,
        `event_time` varchar(40) NOT NULL,
        `event_type` varchar(80) NOT NULL,
        `ip` varchar(64) NOT NULL,
        `data_json` mediumtext NOT NULL,
        PRIMARY KEY (`id`),
        KEY `event_time` (`event_time`),
        KEY `event_type` (`event_type`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
}

function mysql_settings(): array
{
    if (!mysql_schema_exists()) {
        return [];
    }
    $rows = db()->query('SELECT `name`, `value` FROM `' . mysql_table('settings') . '`')->fetchAll();
    $settings = [];
    foreach ($rows as $row) {
        $settings[(string)$row['name']] = (string)$row['value'];
    }
    return $settings;
}

function mysql_save_settings(array $settings): void
{
    mysql_create_schema();
    $stmt = db()->prepare('REPLACE INTO `' . mysql_table('settings') . '` (`name`, `value`) VALUES (?, ?)');
    foreach ($settings as $name => $value) {
        $stmt->execute([(string)$name, is_scalar($value) ? (string)$value : json_encode($value)]);
    }
}

function install_storage(string $adminUser, string $adminPassword): void
{
    $settings = [
        'installed' => '1',
        'admin_user' => $adminUser,
        'admin_password_hash' => password_hash($adminPassword, PASSWORD_DEFAULT),
        'server_secret' => bin2hex(random_bytes(32)),
        'created_at' => now_iso(),
    ];

    if (use_mysql()) {
        mysql_save_settings($settings);
        save_licenses_db(['licenses' => []]);
        return;
    }

    $settings['installed'] = true;
    write_json_file(SETTINGS_FILE, $settings);
    write_json_file(LICENSES_FILE, ['licenses' => []]);
}

function is_installed(): bool
{
    if (use_mysql()) {
        $settings = settings();
        return !empty($settings['installed']) && !empty($settings['admin_user']) && !empty($settings['admin_password_hash']);
    }

    $settings = read_json_file(SETTINGS_FILE, []);
    return !empty($settings['installed']) && !empty($settings['admin_user']) && !empty($settings['admin_password_hash']);
}

function settings(): array
{
    if (use_mysql()) {
        try {
            return mysql_settings();
        } catch (Throwable $e) {
            return [];
        }
    }
    return read_json_file(SETTINGS_FILE, []);
}

function server_secret(): string
{
    $settings = settings();
    return (string)($settings['server_secret'] ?? 'change-this-secret');
}

function licenses_db(): array
{
    if (use_mysql()) {
        mysql_create_schema();
        $db = ['licenses' => []];
        $licenses = db()->query('SELECT * FROM `' . mysql_table('licenses') . '` ORDER BY `created_at` DESC')->fetchAll();
        foreach ($licenses as $license) {
            $key = (string)$license['license_key'];
            $allowed = json_decode((string)$license['allowed_scripts'], true);
            $db['licenses'][$key] = [
                'key' => $key,
                'owner' => (string)$license['owner'],
                'status' => (string)$license['status'],
                'allowed_scripts' => is_array($allowed) ? $allowed : [],
                'expires_at' => (string)($license['expires_at'] ?? ''),
                'max_devices' => (int)$license['max_devices'],
                'notes' => (string)($license['notes'] ?? ''),
                'devices' => [],
                'created_at' => (string)$license['created_at'],
                'last_seen_at' => (string)$license['last_seen_at'],
                'last_ip' => (string)$license['last_ip'],
            ];
        }

        $devices = db()->query('SELECT * FROM `' . mysql_table('devices') . '` ORDER BY `last_seen_at` DESC')->fetchAll();
        foreach ($devices as $device) {
            $key = (string)$device['license_key'];
            if (!isset($db['licenses'][$key])) {
                continue;
            }
            $hash = (string)$device['device_hash'];
            $db['licenses'][$key]['devices'][$hash] = [
                'device_hash' => $hash,
                'hwid_hash' => (string)$device['hwid_hash'],
                'mac_hash' => (string)$device['mac_hash'],
                'mac_preview' => (string)$device['mac_preview'],
                'first_seen_at' => (string)$device['first_seen_at'],
                'last_seen_at' => (string)$device['last_seen_at'],
                'last_ip' => (string)$device['last_ip'],
                'client_ip_sent' => (string)$device['client_ip_sent'],
                'char' => (string)$device['char_name'],
                'emblem' => (string)$device['emblem'],
                'user_agent' => (string)$device['user_agent'],
            ];
        }
        return $db;
    }

    $db = read_json_file(LICENSES_FILE, ['licenses' => []]);
    if (!isset($db['licenses']) || !is_array($db['licenses'])) {
        $db['licenses'] = [];
    }
    return $db;
}

function save_licenses_db(array $db): void
{
    if (!isset($db['licenses']) || !is_array($db['licenses'])) {
        $db['licenses'] = [];
    }
    if (use_mysql()) {
        mysql_create_schema();
        $pdo = db();
        $pdo->beginTransaction();
        try {
            $pdo->exec('DELETE FROM `' . mysql_table('devices') . '`');
            $pdo->exec('DELETE FROM `' . mysql_table('licenses') . '`');

            $licenseStmt = $pdo->prepare('INSERT INTO `' . mysql_table('licenses') . '` (`license_key`, `owner`, `status`, `allowed_scripts`, `expires_at`, `max_devices`, `notes`, `created_at`, `last_seen_at`, `last_ip`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
            $deviceStmt = $pdo->prepare('INSERT INTO `' . mysql_table('devices') . '` (`license_key`, `device_hash`, `hwid_hash`, `mac_hash`, `mac_preview`, `first_seen_at`, `last_seen_at`, `last_ip`, `client_ip_sent`, `char_name`, `emblem`, `user_agent`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');

            foreach ($db['licenses'] as $key => $license) {
                $expires = trim((string)($license['expires_at'] ?? ''));
                $licenseStmt->execute([
                    (string)$key,
                    (string)($license['owner'] ?? ''),
                    (string)($license['status'] ?? 'active'),
                    json_encode(array_values((array)($license['allowed_scripts'] ?? [])), JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE),
                    $expires !== '' ? $expires : null,
                    max(1, (int)($license['max_devices'] ?? 1)),
                    (string)($license['notes'] ?? ''),
                    (string)($license['created_at'] ?? now_iso()),
                    (string)($license['last_seen_at'] ?? ''),
                    (string)($license['last_ip'] ?? ''),
                ]);

                foreach ((array)($license['devices'] ?? []) as $hash => $device) {
                    $deviceStmt->execute([
                        (string)$key,
                        (string)($device['device_hash'] ?? $hash),
                        (string)($device['hwid_hash'] ?? ''),
                        (string)($device['mac_hash'] ?? ''),
                        (string)($device['mac_preview'] ?? ''),
                        (string)($device['first_seen_at'] ?? ''),
                        (string)($device['last_seen_at'] ?? ''),
                        (string)($device['last_ip'] ?? ''),
                        (string)($device['client_ip_sent'] ?? ''),
                        (string)($device['char'] ?? ''),
                        (string)($device['emblem'] ?? ''),
                        (string)($device['user_agent'] ?? ''),
                    ]);
                }
            }
            $pdo->commit();
        } catch (Throwable $e) {
            $pdo->rollBack();
            throw $e;
        }
        return;
    }
    write_json_file(LICENSES_FILE, $db);
}

function log_event(string $type, array $data = []): void
{
    ensure_dirs();
    if (use_mysql() && mysql_schema_exists()) {
        try {
            $stmt = db()->prepare('INSERT INTO `' . mysql_table('events') . '` (`event_time`, `event_type`, `ip`, `data_json`) VALUES (?, ?, ?, ?)');
            $stmt->execute([
                now_iso(),
                $type,
                client_ip(),
                json_encode($data, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE),
            ]);
            return;
        } catch (Throwable $e) {
            // Fallback abaixo preserva logs se o banco falhar.
        }
    }

    $row = [
        'time' => now_iso(),
        'type' => $type,
        'ip' => client_ip(),
        'data' => $data,
    ];
    file_put_contents(EVENTS_FILE, json_encode($row, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) . PHP_EOL, FILE_APPEND | LOCK_EX);
}

function request_has_device_id(string $hwid, string $mac): bool
{
    $value = strtolower(trim($hwid !== '' ? $hwid : $mac));
    return $value !== '' && $value !== 'unknown' && $value !== 'nil' && $value !== 'null';
}

function device_request_record(string $deviceId, string $hwid, string $mac, string $script, string $char, string $clientIpSent, string $emblem): array
{
    return [
        'device_hash' => $deviceId,
        'hwid_hash' => $hwid !== '' ? hash_value($hwid) : '',
        'mac_hash' => $mac !== '' ? hash_value($mac) : '',
        'mac_preview' => mac_preview($mac),
        'requested_script' => $script,
        'first_seen_at' => now_iso(),
        'last_seen_at' => now_iso(),
        'last_ip' => client_ip(),
        'client_ip_sent' => $clientIpSent,
        'char' => normalize_char_list($char),
        'emblem' => substr($emblem, 0, 20),
        'user_agent' => substr((string)($_SERVER['HTTP_USER_AGENT'] ?? ''), 0, 200),
        'requests_count' => 1,
    ];
}

function normalize_char_list(string $chars): string
{
    $parts = preg_split('/[\r\n,;|]+/', $chars) ?: [];
    $out = [];
    $seen = [];
    foreach ($parts as $part) {
        $name = trim($part);
        if ($name === '') {
            continue;
        }
        $name = substr($name, 0, 80);
        $key = function_exists('mb_strtolower') ? mb_strtolower($name, 'UTF-8') : strtolower($name);
        if (isset($seen[$key])) {
            continue;
        }
        $seen[$key] = true;
        $out[] = $name;
        if (count($out) >= 25) {
            break;
        }
    }
    return implode("\n", $out);
}

function merge_char_names(string $existing, string $incoming): string
{
    return normalize_char_list($existing . "\n" . $incoming);
}

function device_record_for_license(array $record): array
{
    return [
        'device_hash' => (string)($record['device_hash'] ?? ''),
        'hwid_hash' => (string)($record['hwid_hash'] ?? ''),
        'mac_hash' => (string)($record['mac_hash'] ?? ''),
        'mac_preview' => (string)($record['mac_preview'] ?? ''),
        'first_seen_at' => (string)($record['first_seen_at'] ?? now_iso()),
        'last_seen_at' => (string)($record['last_seen_at'] ?? now_iso()),
        'last_ip' => (string)($record['last_ip'] ?? client_ip()),
        'client_ip_sent' => (string)($record['client_ip_sent'] ?? ''),
        'char' => (string)($record['char'] ?? ''),
        'emblem' => (string)($record['emblem'] ?? ''),
        'user_agent' => (string)($record['user_agent'] ?? ''),
    ];
}

function license_owner_name(array $license): string
{
    foreach ((array)($license['devices'] ?? []) as $device) {
        $char = trim((string)($device['char'] ?? ''));
        if ($char !== '') {
            return $char;
        }
    }

    $owner = trim((string)($license['owner'] ?? ''));
    if ($owner !== '' && strcasecmp($owner, 'Sem expirar') !== 0) {
        return $owner;
    }

    return '';
}

function find_license_by_device(array $db, string $deviceId): array
{
    foreach ($db['licenses'] ?? [] as $key => $license) {
        $devices = isset($license['devices']) && is_array($license['devices']) ? $license['devices'] : [];
        if (isset($devices[$deviceId])) {
            return ['key' => (string)$key, 'license' => $license];
        }
    }
    return [];
}

function pending_devices(): array
{
    if (use_mysql()) {
        mysql_create_schema();
        $rows = db()->query('SELECT * FROM `' . mysql_table('pending_devices') . '` ORDER BY `last_seen_at` DESC')->fetchAll();
        $devices = [];
        foreach ($rows as $row) {
            $devices[(string)$row['device_hash']] = [
                'device_hash' => (string)$row['device_hash'],
                'hwid_hash' => (string)$row['hwid_hash'],
                'mac_hash' => (string)$row['mac_hash'],
                'mac_preview' => (string)$row['mac_preview'],
                'requested_script' => (string)$row['requested_script'],
                'first_seen_at' => (string)$row['first_seen_at'],
                'last_seen_at' => (string)$row['last_seen_at'],
                'last_ip' => (string)$row['last_ip'],
                'client_ip_sent' => (string)$row['client_ip_sent'],
                'char' => (string)$row['char_name'],
                'emblem' => (string)$row['emblem'],
                'user_agent' => (string)$row['user_agent'],
                'requests_count' => (int)$row['requests_count'],
            ];
        }
        return $devices;
    }

    $data = read_json_file(PENDING_FILE, ['devices' => []]);
    return isset($data['devices']) && is_array($data['devices']) ? $data['devices'] : [];
}

function pending_device(string $deviceId): array
{
    $devices = pending_devices();
    return isset($devices[$deviceId]) && is_array($devices[$deviceId]) ? $devices[$deviceId] : [];
}

function upsert_pending_device(array $record): void
{
    $id = (string)$record['device_hash'];
    $existing = $id !== '' ? pending_device($id) : [];
    if ($existing) {
        $record['first_seen_at'] = $existing['first_seen_at'] ?? $record['first_seen_at'];
        $record['requested_script'] = script_list_to_text(merge_script_lists($existing['requested_script'] ?? '', $record['requested_script'] ?? ''));
        $record['char'] = merge_char_names((string)($existing['char'] ?? ''), (string)($record['char'] ?? ''));
        $record['requests_count'] = (int)($existing['requests_count'] ?? 0) + 1;
    }

    if (use_mysql()) {
        mysql_create_schema();
        $stmt = db()->prepare('INSERT INTO `' . mysql_table('pending_devices') . '` (`device_hash`, `hwid_hash`, `mac_hash`, `mac_preview`, `requested_script`, `first_seen_at`, `last_seen_at`, `last_ip`, `client_ip_sent`, `char_name`, `emblem`, `user_agent`, `requests_count`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1) ON DUPLICATE KEY UPDATE `hwid_hash` = VALUES(`hwid_hash`), `mac_hash` = VALUES(`mac_hash`), `mac_preview` = VALUES(`mac_preview`), `requested_script` = VALUES(`requested_script`), `last_seen_at` = VALUES(`last_seen_at`), `last_ip` = VALUES(`last_ip`), `client_ip_sent` = VALUES(`client_ip_sent`), `char_name` = VALUES(`char_name`), `emblem` = VALUES(`emblem`), `user_agent` = VALUES(`user_agent`), `requests_count` = `requests_count` + 1');
        $stmt->execute([
            (string)$record['device_hash'],
            (string)$record['hwid_hash'],
            (string)$record['mac_hash'],
            (string)$record['mac_preview'],
            (string)$record['requested_script'],
            (string)$record['first_seen_at'],
            (string)$record['last_seen_at'],
            (string)$record['last_ip'],
            (string)$record['client_ip_sent'],
            (string)$record['char'],
            (string)$record['emblem'],
            (string)$record['user_agent'],
        ]);
        return;
    }

    $devices = pending_devices();
    $devices[$id] = $record;
    write_json_file(PENDING_FILE, ['devices' => $devices]);
}

function delete_pending_device(string $deviceId): void
{
    if (use_mysql()) {
        mysql_create_schema();
        $stmt = db()->prepare('DELETE FROM `' . mysql_table('pending_devices') . '` WHERE `device_hash` = ?');
        $stmt->execute([$deviceId]);
        return;
    }

    $devices = pending_devices();
    unset($devices[$deviceId]);
    write_json_file(PENDING_FILE, ['devices' => $devices]);
}

function client_ip(): string
{
    foreach (['HTTP_CF_CONNECTING_IP', 'HTTP_X_FORWARDED_FOR', 'REMOTE_ADDR'] as $key) {
        $value = $_SERVER[$key] ?? '';
        if (!is_string($value) || $value === '') {
            continue;
        }
        $ip = trim(explode(',', $value)[0]);
        if (filter_var($ip, FILTER_VALIDATE_IP)) {
            return $ip;
        }
    }
    return '0.0.0.0';
}

function normalize_key(string $key): string
{
    $key = strtoupper(trim($key));
    return preg_replace('/[^A-Z0-9\-]/', '', $key) ?? '';
}

function normalize_script_name(string $name): string
{
    $name = strtolower(trim($name));
    if (!preg_match('/^[a-z0-9_\-]+$/', $name)) {
        return '';
    }
    return $name;
}

function script_path(string $name): string
{
    return SCRIPT_DIR . '/' . normalize_script_name($name) . '.lua';
}

function available_scripts(): array
{
    ensure_dirs();
    $list = [];
    foreach (glob(SCRIPT_DIR . '/*.lua') ?: [] as $file) {
        $list[] = basename($file, '.lua');
    }
    sort($list);
    return $list;
}

function random_license_key(): string
{
    $raw = strtoupper(bin2hex(random_bytes(9)));
    return 'JQM-' . substr($raw, 0, 4) . '-' . substr($raw, 4, 4) . '-' . substr($raw, 8, 4) . '-' . substr($raw, 12, 6);
}

function hash_value(string $value): string
{
    return hash('sha256', server_secret() . '|' . $value);
}

function device_fingerprint(string $hwid, string $mac): string
{
    $base = trim($hwid) !== '' ? $hwid : $mac;
    if (trim($base) === '') {
        $base = 'ip:' . client_ip();
    }
    return hash_value($base);
}

function mac_preview(string $mac): string
{
    $clean = strtoupper(preg_replace('/[^A-F0-9]/i', '', $mac) ?? '');
    if ($clean === '') {
        return '';
    }
    return substr($clean, -6);
}

function csv_to_list(string $value): array
{
    $parts = preg_split('/[\s,;|]+/', $value) ?: [];
    $out = [];
    foreach ($parts as $part) {
        $part = trim($part);
        if ($part !== '') {
            $out[] = $part;
        }
    }
    return array_values(array_unique($out));
}

function script_list_from_input($value): array
{
    $parts = [];
    if (is_array($value)) {
        foreach ($value as $item) {
            foreach (csv_to_list((string)$item) as $part) {
                $parts[] = $part;
            }
        }
    } else {
        $parts = csv_to_list((string)$value);
    }

    $out = [];
    foreach ($parts as $part) {
        if ($part === '*') {
            $out[] = '*';
            continue;
        }
        $script = normalize_script_name($part);
        if ($script !== '') {
            $out[] = $script;
        }
    }
    return array_values(array_unique($out));
}

function script_list_to_text(array $scripts): string
{
    return implode(',', array_values(array_unique(array_map('strval', $scripts))));
}

function merge_script_lists($current, $incoming): array
{
    $currentList = script_list_from_input($current);
    $incomingList = script_list_from_input($incoming);
    if (in_array('*', $currentList, true) || in_array('*', $incomingList, true)) {
        return ['*'];
    }
    return array_values(array_unique(array_merge($currentList, $incomingList)));
}

function license_allows_script(array $license, string $script): bool
{
    $allowed = $license['allowed_scripts'] ?? [];
    if (!is_array($allowed)) {
        return false;
    }
    return in_array('*', $allowed, true) || in_array($script, $allowed, true);
}

function public_script_list(): array
{
    $scripts = [];
    foreach (available_scripts() as $script) {
        $scripts[] = [
            'name' => $script,
            'label' => ucwords(str_replace(['_', '-'], ' ', $script)),
        ];
    }
    return $scripts;
}

function license_is_expired(array $license): bool
{
    $expires = trim((string)($license['expires_at'] ?? ''));
    if ($expires === '') {
        return false;
    }
    return strtotime($expires . ' 23:59:59 UTC') < time();
}

function protect_lua(string $source, array $watermark): string
{
    $commentValue = static function ($value): string {
        $value = (string)$value;
        $value = preg_replace('/\s+/', ' ', $value) ?? $value;
        return trim($value);
    };

    $header = [
        '-- Jequi Multi Assessoria protected payload',
        '-- license=' . $commentValue($watermark['license'] ?? ''),
        '-- owner=' . $commentValue($watermark['owner'] ?? ''),
        '-- issued=' . now_iso(),
    ];

    $bytes = unpack('C*', $source);
    $chunks = [];
    $chunk = '';
    $count = 0;
    foreach ($bytes as $byte) {
        $chunk .= '\\' . str_pad((string)$byte, 3, '0', STR_PAD_LEFT);
        $count++;
        if ($count >= 240) {
            $chunks[] = $chunk;
            $chunk = '';
            $count = 0;
        }
    }
    if ($chunk !== '') {
        $chunks[] = $chunk;
    }

    $lines = $header;
    $lines[] = 'local _p={';
    foreach ($chunks as $part) {
        $lines[] = '  "' . $part . '",';
    }
    $lines[] = '}';
    $lines[] = 'local _s=table.concat(_p)';
    $lines[] = 'local _l=loadstring or load';
    $lines[] = 'if not _l then error("loader indisponivel") end';
    $lines[] = 'local _f,_e=_l(_s,"@protected.lua")';
    $lines[] = 'if not _f then error(_e) end';
    $lines[] = 'return _f()';
    return implode("\n", $lines) . "\n";
}

function require_install(): void
{
    if (!is_installed()) {
        header('Location: install.php');
        exit;
    }
}

function start_admin_session(): void
{
    if (session_status() !== PHP_SESSION_ACTIVE) {
        session_name('jqm_license_admin');
        $secure = !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off';
        if (defined('PHP_VERSION_ID') && PHP_VERSION_ID >= 70300) {
            session_set_cookie_params([
                'lifetime' => 0,
                'path' => '',
                'domain' => '',
                'secure' => $secure,
                'httponly' => true,
                'samesite' => 'Lax',
            ]);
        } else {
            session_set_cookie_params(0, '', '', $secure, true);
        }
        session_start();
    }
}

function csrf_token(): string
{
    start_admin_session();
    if (empty($_SESSION['csrf_token'])) {
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    }
    return (string)$_SESSION['csrf_token'];
}

function require_csrf(): void
{
    start_admin_session();
    $sent = (string)($_POST['csrf_token'] ?? '');
    $real = (string)($_SESSION['csrf_token'] ?? '');
    if ($sent === '' || $real === '' || !hash_equals($real, $sent)) {
        http_response_code(400);
        exit('Token de seguranca invalido.');
    }
}

function is_admin_logged(): bool
{
    start_admin_session();
    return !empty($_SESSION['admin_logged']);
}

function require_admin(): void
{
    require_install();
    if (!is_admin_logged()) {
        header('Location: admin.php?login=1');
        exit;
    }
}

function h(string $value): string
{
    return htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function json_response(array $payload, int $status = 200): void
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

function friendly_install_error(Throwable $e): string
{
    $message = $e->getMessage();
    if (stripos($message, 'could not find driver') !== false) {
        return 'O PHP da hospedagem nao esta com pdo_mysql habilitado. Ative o suporte a MySQL/PDO no painel da hospedagem.';
    }
    if (stripos($message, 'Access denied') !== false && stripos($message, 'database') !== false) {
        return 'O MySQL conectou, mas o usuario do banco nao tem permissao no database configurado. No painel da Locaweb, associe o usuario ao banco e libere permissao para criar/alterar tabelas.';
    }
    if (stripos($message, 'Unknown database') !== false) {
        return 'Banco de dados nao encontrado. Confira o nome exato do database no painel da Locaweb.';
    }
    if (stripos($message, 'SQLSTATE') !== false) {
        return 'Erro no MySQL: ' . $message;
    }
    return 'Erro ao instalar: ' . $message;
}
