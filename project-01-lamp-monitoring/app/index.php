<?php
// Database connection
$host = getenv('MYSQL_HOST') ?: 'mysql';
$db   = getenv('MYSQL_DATABASE') ?: 'lampdb';
$user = getenv('MYSQL_USER') ?: 'lampuser';
$pass = getenv('MYSQL_PASSWORD') ?: '';

try {
    $pdo = new PDO("mysql:host=$host;dbname=$db;charset=utf8mb4", $user, $pass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $db_status = 'Connected';
    $db_color = 'green';
} catch (PDOException $e) {
    $db_status = 'Error: ' . $e->getMessage();
    $db_color = 'red';
}

// Get server stats from database
$stats = [];
if (isset($pdo)) {
    $stmt = $pdo->query("SELECT metric_name, metric_value FROM server_stats ORDER BY timestamp DESC LIMIT 5");
    $stats = $stmt->fetchAll(PDO::FETCH_KEY_PAIR);
}

// PHP Info
$php_version = phpversion();
$server_software = $_SERVER['SERVER_SOFTWARE'] ?? 'Unknown';
$server_name = gethostname();

// Recent logs (if available)
$log_file = '/var/log/nginx/access.log';
$recent_logs = [];
if (file_exists($log_file) && is_readable($log_file)) {
    $recent_logs = array_slice(file($log_file), -10);
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LAMP Stack Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            min-height: 100vh;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        h1 {
            color: white;
            text-align: center;
            margin-bottom: 30px;
            font-size: 2.5em;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
        }
        .card {
            background: white;
            border-radius: 10px;
            padding: 20px;
            box-shadow: 0 10px 20px rgba(0,0,0,0.1);
        }
        .card h2 {
            color: #667eea;
            margin-bottom: 15px;
            border-bottom: 2px solid #667eea;
            padding-bottom: 10px;
        }
        .status {
            display: inline-block;
            padding: 5px 15px;
            border-radius: 20px;
            font-weight: bold;
            color: white;
        }
        .status.green { background: #10b981; }
        .status.red { background: #ef4444; }
        .status.yellow { background: #f59e0b; }
        .stat-row {
            display: flex;
            justify-content: space-between;
            padding: 10px 0;
            border-bottom: 1px solid #e5e7eb;
        }
        .stat-row:last-child { border-bottom: none; }
        .stat-label { font-weight: 600; color: #6b7280; }
        .stat-value { color: #111827; }
        .logs {
            background: #1f2937;
            color: #10b981;
            padding: 15px;
            border-radius: 5px;
            font-family: 'Courier New', monospace;
            font-size: 12px;
            max-height: 300px;
            overflow-y: auto;
            white-space: pre-wrap;
        }
        .footer {
            text-align: center;
            color: white;
            margin-top: 30px;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🖥️ LAMP Stack Dashboard</h1>

        <div class="grid">
            <!-- System Status -->
            <div class="card">
                <h2>System Status</h2>
                <div class="stat-row">
                    <span class="stat-label">Database:</span>
                    <span class="status <?= $db_color ?>"><?= $db_status ?></span>
                </div>
                <div class="stat-row">
                    <span class="stat-label">PHP Version:</span>
                    <span class="stat-value"><?= $php_version ?></span>
                </div>
                <div class="stat-row">
                    <span class="stat-label">Server:</span>
                    <span class="stat-value"><?= $server_name ?></span>
                </div>
                <div class="stat-row">
                    <span class="stat-label">Web Server:</span>
                    <span class="stat-value"><?= $server_software ?></span>
                </div>
            </div>

            <!-- Server Metrics -->
            <div class="card">
                <h2>Server Metrics</h2>
                <?php if (!empty($stats)): ?>
                    <?php foreach ($stats as $metric => $value): ?>
                        <div class="stat-row">
                            <span class="stat-label"><?= htmlspecialchars($metric) ?>:</span>
                            <span class="stat-value"><?= htmlspecialchars($value) ?></span>
                        </div>
                    <?php endforeach; ?>
                <?php else: ?>
                    <p>No metrics available</p>
                <?php endif; ?>
            </div>

            <!-- Scripts Info -->
            <div class="card">
                <h2>Monitoring Scripts</h2>
                <div class="stat-row">
                    <span class="stat-label">Log Analyzer:</span>
                    <span class="status green">Available</span>
                </div>
                <div class="stat-row">
                    <span class="stat-label">Health Check:</span>
                    <span class="status green">Available</span>
                </div>
                <div class="stat-row">
                    <span class="stat-label">Backup System:</span>
                    <span class="status green">Available</span>
                </div>
            </div>
        </div>

        <!-- Recent Access Logs -->
        <?php if (!empty($recent_logs)): ?>
        <div class="card">
            <h2>Recent Access Logs (Last 10)</h2>
            <div class="logs"><?php
                foreach ($recent_logs as $log) {
                    echo htmlspecialchars($log);
                }
            ?></div>
        </div>
        <?php endif; ?>

        <div class="footer">
            <p>Linux System Administrator Portfolio - Project 01: LAMP Stack with Monitoring</p>
            <p>GitHub: <a href="#" style="color: white;">@yourusername</a></p>
        </div>
    </div>
</body>
</html>
