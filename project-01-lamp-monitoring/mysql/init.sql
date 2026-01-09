-- Initial database setup for LAMP Stack
-- Creates sample tables and data for demonstration

USE lampdb;

-- Create a sample users table
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_username (username),
    INDEX idx_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create a sample logs table for application logging
CREATE TABLE IF NOT EXISTS app_logs (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    level ENUM('DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL') NOT NULL,
    message TEXT NOT NULL,
    user_id INT NULL,
    ip_address VARCHAR(45) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_level (level),
    INDEX idx_created_at (created_at),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create server stats table for dashboard metrics
CREATE TABLE IF NOT EXISTS server_stats (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    metric_name VARCHAR(100) NOT NULL,
    metric_value VARCHAR(255) NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_timestamp (timestamp),
    INDEX idx_metric_name (metric_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert sample data
INSERT IGNORE INTO users (username, email) VALUES
    ('admin', 'admin@example.com'),
    ('demo', 'demo@example.com'),
    ('testuser', 'test@example.com');

-- Insert sample log entries
INSERT INTO app_logs (level, message, user_id, ip_address) VALUES
    ('INFO', 'Application started successfully', NULL, '127.0.0.1'),
    ('INFO', 'User logged in', 1, '192.168.1.100'),
    ('WARNING', 'Failed login attempt', NULL, '192.168.1.200'),
    ('ERROR', 'Database connection timeout', NULL, '127.0.0.1'),
    ('INFO', 'User created successfully', 2, '192.168.1.100');

-- Insert sample server statistics
INSERT INTO server_stats (metric_name, metric_value) VALUES
    ('CPU Usage', '45%'),
    ('Memory Usage', '2.1 GB / 8 GB'),
    ('Disk Usage', '35 GB / 100 GB'),
    ('Active Connections', '12'),
    ('Uptime', '5 days, 3 hours');
