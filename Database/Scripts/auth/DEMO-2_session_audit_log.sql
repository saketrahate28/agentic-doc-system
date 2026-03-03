-- DEMO-2: Add session tracking table for audit logs
-- Story: DEMO-2 Add session tracking table for audit logs
-- Author: saketrahate28
-- Date: 2026-03-03

-- Create the session audit log table
CREATE TABLE IF NOT EXISTS session_audit_log (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT NOT NULL,
    session_token   VARCHAR(255) NOT NULL,
    ip_address      VARCHAR(45),
    user_agent      VARCHAR(500),
    action          ENUM('LOGIN', 'LOGOUT', 'REFRESH', 'EXPIRED') NOT NULL,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_created_at (created_at),
    INDEX idx_action (action)
);

-- Add column to track active sessions count per user
ALTER TABLE users 
    ADD COLUMN IF NOT EXISTS active_sessions INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS last_login_at DATETIME NULL,
    ADD COLUMN IF NOT EXISTS last_ip_address VARCHAR(45) NULL;

-- Stored procedure to clean expired sessions (older than 24 hrs)
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS cleanup_expired_sessions()
BEGIN
    DELETE FROM session_audit_log
    WHERE action = 'EXPIRED'
      AND created_at < NOW() - INTERVAL 24 HOUR;
    
    -- Update active session counts
    UPDATE users u
    SET active_sessions = (
        SELECT COUNT(*) FROM session_audit_log s
        WHERE s.user_id = u.id AND s.action = 'LOGIN'
          AND s.created_at > NOW() - INTERVAL 24 HOUR
    );
END //
DELIMITER ;
