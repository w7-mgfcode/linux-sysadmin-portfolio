-- Create database and tables
CREATE DATABASE IF NOT EXISTS lampdb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE lampdb;

-- Sample table for demo
CREATE TABLE IF NOT EXISTS server_stats (
    id INT AUTO_INCREMENT PRIMARY KEY,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    metric_name VARCHAR(100) NOT NULL,
    metric_value VARCHAR(255),
    INDEX idx_timestamp (timestamp),
    INDEX idx_metric (metric_name)
) ENGINE=InnoDB;

-- Insert sample data
INSERT INTO server_stats (metric_name, metric_value) VALUES
('uptime', '3600'),
('cpu_usage', '15.3'),
('memory_used', '45.2'),
('disk_used', '62.8'),
('active_connections', '12');

-- Grant privileges (already handled by MYSQL_USER env, but explicit)
GRANT ALL PRIVILEGES ON lampdb.* TO 'lampuser'@'%';
FLUSH PRIVILEGES;
