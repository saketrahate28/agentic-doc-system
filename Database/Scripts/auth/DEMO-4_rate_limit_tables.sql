-- DEMO-4: Rate limiting tables
-- Tracks rate limit violations for audit purposes

CREATE TABLE IF NOT EXISTS rate_limit_violations (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    user_id     INT,
    ip_address  VARCHAR(45) NOT NULL,
    endpoint    VARCHAR(255) NOT NULL,
    violated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    INDEX idx_ip (ip_address),
    INDEX idx_endpoint (endpoint)
);

-- Add rate limit config table for dynamic limits per endpoint
CREATE TABLE IF NOT EXISTS rate_limit_config (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    endpoint        VARCHAR(255) NOT NULL UNIQUE,
    max_requests    INT NOT NULL DEFAULT 10,
    window_seconds  INT NOT NULL DEFAULT 60,
    updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Seed default configs
INSERT INTO rate_limit_config (endpoint, max_requests, window_seconds) VALUES
    ('/api/auth/login',         5,  60),
    ('/api/auth/refresh',       20, 60),
    ('/api/auth/reset-password', 3, 300)
ON DUPLICATE KEY UPDATE max_requests=VALUES(max_requests);
