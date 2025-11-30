<?php
/**
 * Mail Server Dashboard - Real-time Monitoring Interface
 *
 * Purpose:
 *   Interactive dashboard providing live metrics, service health monitoring,
 *   mail queue statistics, mailbox usage, and recent mail logs.
 *
 * Skills Demonstrated:
 *   - PHP 8.2 with modern syntax
 *   - MySQL PDO with prepared statements
 *   - JSON parsing from script reports
 *   - Service health checking
 *   - Responsive HTML/CSS design
 *   - JavaScript auto-refresh
 *   - Security best practices (SQL injection prevention)
 *
 * Author: Linux Sysadmin Portfolio
 * License: MIT
 */

// Configuration
$config = [
    'mysql_host' => getenv('MYSQL_HOST') ?: 'mysql',
    'mysql_db' => getenv('MYSQL_DATABASE') ?: 'mailserver',
    'mysql_user' => getenv('MYSQL_USER') ?: 'mailreader',
    'mysql_pass' => getenv('MYSQL_PASSWORD') ?: '',
    'report_dir' => getenv('REPORT_DIR') ?: '/var/reports',
    'log_file' => '/var/log/mail/mail.log',
];

// Database connection
function getDBConnection($config) {
    try {
        $dsn = "mysql:host={$config['mysql_host']};dbname={$config['mysql_db']};charset=utf8mb4";
        $pdo = new PDO($dsn, $config['mysql_user'], $config['mysql_pass'], [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]);
        return $pdo;
    } catch (PDOException $e) {
        return null;
    }
}

// Service health checks
function checkServiceHealth() {
    $services = [
        'mysql' => ['host' => 'mysql', 'port' => 3306],
        'postfix' => ['host' => 'postfix', 'port' => 25],
        'dovecot' => ['host' => 'dovecot', 'port' => 143],
        'spamassassin' => ['host' => 'spamassassin', 'port' => 783],
    ];

    $health = [];
    foreach ($services as $name => $service) {
        $fp = @fsockopen($service['host'], $service['port'], $errno, $errstr, 2);
        $health[$name] = [
            'status' => $fp !== false ? 'healthy' : 'down',
            'port' => $service['port']
        ];
        if ($fp) {
            fclose($fp);
        }
    }
    return $health;
}

// Get mail queue statistics from JSON report
function getQueueStats($config) {
    $reportFile = "{$config['report_dir']}/mail-queue-latest.json";
    if (file_exists($reportFile)) {
        $data = json_decode(file_get_contents($reportFile), true);
        return $data['queue'] ?? null;
    }
    return null;
}

// Get spam statistics from JSON report
function getSpamStats($config) {
    $reportFile = "{$config['report_dir']}/spam-report-latest.json";
    if (file_exists($reportFile)) {
        $data = json_decode(file_get_contents($reportFile), true);
        return $data['summary'] ?? null;
    }
    return null;
}

// Get mailbox usage from database
function getMailboxUsage($pdo) {
    if (!$pdo) return [];

    try {
        $stmt = $pdo->query("
            SELECT
                u.email,
                d.name as domain,
                u.quota_mb,
                COALESCE(m.usage_mb, 0) as usage_mb,
                ROUND((COALESCE(m.usage_mb, 0) / u.quota_mb) * 100, 1) as usage_percent,
                u.enabled
            FROM virtual_users u
            JOIN virtual_domains d ON u.domain_id = d.id
            LEFT JOIN mailbox_usage m ON u.email = m.email
            ORDER BY usage_percent DESC
            LIMIT 10
        ");
        return $stmt->fetchAll();
    } catch (PDOException $e) {
        return [];
    }
}

// Get domain statistics
function getDomainStats($pdo) {
    if (!$pdo) return [];

    try {
        $stmt = $pdo->query("
            SELECT
                d.name as domain,
                COUNT(DISTINCT u.id) as users,
                COUNT(DISTINCT a.id) as aliases
            FROM virtual_domains d
            LEFT JOIN virtual_users u ON d.id = u.domain_id AND u.enabled = 1
            LEFT JOIN virtual_aliases a ON d.id = a.domain_id
            GROUP BY d.id, d.name
            ORDER BY users DESC
        ");
        return $stmt->fetchAll();
    } catch (PDOException $e) {
        return [];
    }
}

// Get recent mail logs
function getRecentLogs($config, $lines = 20) {
    $logFile = $config['log_file'];
    if (!file_exists($logFile)) {
        return ['Log file not found'];
    }

    $output = [];
    exec("tail -n {$lines} {$logFile} 2>&1", $output);
    return $output;
}

// Main data collection
$pdo = getDBConnection($config);
$health = checkServiceHealth();
$queueStats = getQueueStats($config);
$spamStats = getSpamStats($config);
$mailboxes = getMailboxUsage($pdo);
$domains = getDomainStats($pdo);
$recentLogs = getRecentLogs($config);

// Helper functions for display
function statusBadge($status) {
    $class = $status === 'healthy' ? 'status-healthy' : 'status-down';
    $text = $status === 'healthy' ? 'Healthy' : 'Down';
    return "<span class='status-badge {$class}'>{$text}</span>";
}

function formatBytes($bytes) {
    $units = ['B', 'KB', 'MB', 'GB'];
    $bytes = max($bytes, 0);
    $pow = floor(($bytes ? log($bytes) : 0) / log(1024));
    $pow = min($pow, count($units) - 1);
    $bytes /= (1 << (10 * $pow));
    return round($bytes, 2) . ' ' . $units[$pow];
}

function progressBar($percent, $label = '') {
    $color = $percent < 70 ? 'green' : ($percent < 90 ? 'yellow' : 'red');
    return "
        <div class='progress-bar'>
            <div class='progress-fill progress-{$color}' style='width: {$percent}%'></div>
            <span class='progress-label'>{$label}</span>
        </div>
    ";
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Mail Server Dashboard</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div class="container">
        <header>
            <h1>📧 Mail Server Dashboard</h1>
            <div class="header-info">
                <span>Last Updated: <?= date('Y-m-d H:i:s') ?></span>
                <span id="auto-refresh">Auto-refresh: <strong>ON</strong></span>
            </div>
        </header>

        <!-- Service Health Grid -->
        <section class="grid">
            <div class="card">
                <h2>Service Health</h2>
                <div class="service-list">
                    <?php foreach ($health as $name => $info): ?>
                        <div class="service-item">
                            <span class="service-name"><?= ucfirst($name) ?></span>
                            <?= statusBadge($info['status']) ?>
                            <span class="service-port">Port: <?= $info['port'] ?></span>
                        </div>
                    <?php endforeach; ?>
                </div>
            </div>

            <!-- Mail Queue Stats -->
            <div class="card">
                <h2>Mail Queue</h2>
                <?php if ($queueStats): ?>
                    <div class="stat-grid">
                        <div class="stat-item">
                            <div class="stat-value"><?= $queueStats['total'] ?? 0 ?></div>
                            <div class="stat-label">Total</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-value"><?= $queueStats['active'] ?? 0 ?></div>
                            <div class="stat-label">Active</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-value"><?= $queueStats['deferred'] ?? 0 ?></div>
                            <div class="stat-label">Deferred</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-value"><?= $queueStats['hold'] ?? 0 ?></div>
                            <div class="stat-label">Hold</div>
                        </div>
                    </div>
                    <div class="queue-details">
                        <p>Oldest: <?= $queueStats['oldest_hours'] ?? 0 ?> hours</p>
                        <p>Size: <?= isset($queueStats['size_mb']) ? round($queueStats['size_mb'], 2) . ' MB' : 'N/A' ?></p>
                    </div>
                <?php else: ?>
                    <p class="no-data">No queue data available</p>
                <?php endif; ?>
            </div>

            <!-- Spam Statistics -->
            <div class="card">
                <h2>Spam Detection</h2>
                <?php if ($spamStats): ?>
                    <div class="stat-grid">
                        <div class="stat-item">
                            <div class="stat-value"><?= $spamStats['total_messages'] ?? 0 ?></div>
                            <div class="stat-label">Total Messages</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-value stat-danger"><?= $spamStats['spam_detected'] ?? 0 ?></div>
                            <div class="stat-label">Spam Detected</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-value stat-success"><?= $spamStats['ham_detected'] ?? 0 ?></div>
                            <div class="stat-label">Ham (Clean)</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-value"><?= $spamStats['spam_rate'] ?? 0 ?>%</div>
                            <div class="stat-label">Spam Rate</div>
                        </div>
                    </div>
                <?php else: ?>
                    <p class="no-data">No spam data available</p>
                <?php endif; ?>
            </div>

            <!-- Domain Statistics -->
            <div class="card">
                <h2>Domains</h2>
                <?php if (!empty($domains)): ?>
                    <table class="data-table">
                        <thead>
                            <tr>
                                <th>Domain</th>
                                <th>Users</th>
                                <th>Aliases</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php foreach ($domains as $domain): ?>
                                <tr>
                                    <td><?= htmlspecialchars($domain['domain']) ?></td>
                                    <td><?= $domain['users'] ?></td>
                                    <td><?= $domain['aliases'] ?></td>
                                </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                <?php else: ?>
                    <p class="no-data">No domains configured</p>
                <?php endif; ?>
            </div>
        </section>

        <!-- Mailbox Usage Table -->
        <section class="card full-width">
            <h2>Mailbox Usage (Top 10)</h2>
            <?php if (!empty($mailboxes)): ?>
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>Email</th>
                            <th>Domain</th>
                            <th>Usage</th>
                            <th>Quota</th>
                            <th>Percentage</th>
                            <th>Status</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($mailboxes as $box): ?>
                            <tr>
                                <td><?= htmlspecialchars($box['email']) ?></td>
                                <td><?= htmlspecialchars($box['domain']) ?></td>
                                <td><?= round($box['usage_mb'], 2) ?> MB</td>
                                <td><?= $box['quota_mb'] ?> MB</td>
                                <td>
                                    <?= progressBar($box['usage_percent'], $box['usage_percent'] . '%') ?>
                                </td>
                                <td>
                                    <?= $box['enabled'] ? '<span class="status-badge status-healthy">Active</span>' : '<span class="status-badge status-down">Disabled</span>' ?>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            <?php else: ?>
                <p class="no-data">No mailboxes configured</p>
            <?php endif; ?>
        </section>

        <!-- Recent Mail Logs -->
        <section class="card full-width">
            <h2>Recent Mail Logs (Last 20 lines)</h2>
            <div class="log-viewer">
                <?php foreach ($recentLogs as $line): ?>
                    <div class="log-line"><?= htmlspecialchars($line) ?></div>
                <?php endforeach; ?>
            </div>
        </section>

        <footer>
            <p>Mail Server Dashboard | Linux Sysadmin Portfolio</p>
            <p>
                <a href="http://localhost:8025" target="_blank">Roundcube Webmail</a> |
                <a href="#" onclick="toggleAutoRefresh(); return false;">Toggle Auto-Refresh</a>
            </p>
        </footer>
    </div>

    <script src="script.js"></script>
</body>
</html>
