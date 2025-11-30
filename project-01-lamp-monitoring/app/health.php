<?php
header('Content-Type: application/json');

$status = [
    'timestamp' => date('c'),
    'status' => 'healthy',
    'checks' => []
];

// Check MySQL
try {
    $host = getenv('MYSQL_HOST') ?: 'mysql';
    $db   = getenv('MYSQL_DATABASE') ?: 'lampdb';
    $user = getenv('MYSQL_USER') ?: 'lampuser';
    $pass = getenv('MYSQL_PASSWORD') ?: '';

    $pdo = new PDO("mysql:host=$host;dbname=$db", $user, $pass);
    $status['checks']['mysql'] = ['status' => 'ok', 'connection' => 'active'];
} catch (PDOException $e) {
    $status['checks']['mysql'] = ['status' => 'error', 'message' => $e->getMessage()];
    $status['status'] = 'unhealthy';
}

// Check PHP
$status['checks']['php'] = [
    'status' => 'ok',
    'version' => phpversion()
];

echo json_encode($status, JSON_PRETTY_PRINT);
