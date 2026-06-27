-- ============================================================================
-- Mail Server Database Schema
-- Project 02: Dockerized Mail Server
--
-- Loaded automatically by the MySQL image from /docker-entrypoint-initdb.d/
-- on first initialization of an empty data volume. Defines the virtual
-- mailbox schema used by Postfix (lookup maps) and Dovecot (auth/userdb).
--
-- NOTE: `enabled` columns on virtual_domains and virtual_aliases are required
-- by the Postfix MySQL maps (`... WHERE name=%s AND enabled=1`); they extend
-- the base schema documented in docs/ARCHITECTURE.md.
-- ============================================================================

CREATE DATABASE IF NOT EXISTS mailserver
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE mailserver;

-- ----------------------------------------------------------------------------
-- Virtual domains
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS virtual_domains (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    enabled TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- Virtual users (mailboxes)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS virtual_users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    domain_id INT NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    quota_mb INT DEFAULT 1024,
    enabled TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (domain_id) REFERENCES virtual_domains(id) ON DELETE CASCADE,
    INDEX idx_email (email),
    INDEX idx_domain (domain_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- Virtual aliases (forwarding)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS virtual_aliases (
    id INT AUTO_INCREMENT PRIMARY KEY,
    domain_id INT NOT NULL,
    source VARCHAR(255) NOT NULL,
    destination VARCHAR(255) NOT NULL,
    enabled TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (domain_id) REFERENCES virtual_domains(id) ON DELETE CASCADE,
    INDEX idx_source (source)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- Mailbox usage (populated by monitoring; read by the dashboard)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mailbox_usage (
    email VARCHAR(255) PRIMARY KEY,
    usage_mb DECIMAL(10,2) DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (email) REFERENCES virtual_users(email) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- Seed the primary domain so the server accepts mail out of the box.
-- Users/aliases are created via scripts/user-management.sh.
-- ----------------------------------------------------------------------------
INSERT IGNORE INTO virtual_domains (name) VALUES ('example.com');
