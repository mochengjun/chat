package repository

import (
	"context"
	"database/sql"
	"time"

	_ "github.com/lib/pq"
)

// CleanupRepo 清理仓库接口
type CleanupRepo interface {
	Close() error
	GetRoomRetentionPolicies(ctx context.Context) ([]RoomRetentionPolicy, error)
	GetGlobalRetentionHours(ctx context.Context) (int, error)
	DeleteExpiredMessages(ctx context.Context, roomID string, beforeTime time.Time) (int64, error)
	DeleteExpiredMessagesGlobal(ctx context.Context, beforeTime time.Time, excludeRooms []string) (int64, error)
	DeleteExpiredMediaFiles(ctx context.Context, beforeTime time.Time) ([]string, error)
	DeleteOldAuditLogs(ctx context.Context, beforeTime time.Time) (int64, error)
	DeleteExpiredTokens(ctx context.Context) (int64, error)
	GetCleanupStats(ctx context.Context) (*CleanupStats, error)
	GetExpiredAutoDeleteMessages(ctx context.Context, limit int) ([]ExpiredAutoDeleteMessage, error)
}

// cleanupRepository 清理仓库实现
type cleanupRepository struct {
	db *sql.DB
}

// NewCleanupRepository 创建清理仓库实例
func NewCleanupRepository(databaseURL string) (CleanupRepo, error) {
	db, err := sql.Open("postgres", databaseURL)
	if err != nil {
		return nil, err
	}

	if err := db.Ping(); err != nil {
		return nil, err
	}

	return &cleanupRepository{db: db}, nil
}

func (r *cleanupRepository) Close() error {
	return r.db.Close()
}

// GetRoomRetentionPolicies 获取所有群组的消息保留策略
func (r *cleanupRepository) GetRoomRetentionPolicies(ctx context.Context) ([]RoomRetentionPolicy, error) {
	query := `
		SELECT room_id, retention_hours, enabled, created_at, updated_at
		FROM room_retention_policy
		WHERE enabled = true
	`

	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var policies []RoomRetentionPolicy
	for rows.Next() {
		var policy RoomRetentionPolicy
		err := rows.Scan(
			&policy.RoomID,
			&policy.RetentionHours,
			&policy.Enabled,
			&policy.CreatedAt,
			&policy.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		policies = append(policies, policy)
	}

	return policies, rows.Err()
}

// GetGlobalRetentionHours 获取全局默认保留时间
func (r *cleanupRepository) GetGlobalRetentionHours(ctx context.Context) (int, error) {
	query := `
		SELECT config_value
		FROM system_config
		WHERE config_key = 'default_retention_hours'
	`

	var hours int
	err := r.db.QueryRowContext(ctx, query).Scan(&hours)
	if err == sql.ErrNoRows {
		return 72, nil // 默认72小时
	}
	if err != nil {
		return 0, err
	}
	return hours, nil
}

// DeleteExpiredMessages 删除指定群组的过期消息
func (r *cleanupRepository) DeleteExpiredMessages(ctx context.Context, roomID string, beforeTime time.Time) (int64, error) {
	query := `
		DELETE FROM events
		WHERE room_id = $1
		AND origin_server_ts < $2
		AND type IN ('m.room.message', 'm.room.encrypted')
	`

	result, err := r.db.ExecContext(ctx, query, roomID, beforeTime.UnixMilli())
	if err != nil {
		return 0, err
	}

	return result.RowsAffected()
}

// DeleteExpiredMessagesGlobal 删除所有无特定策略群组的过期消息
func (r *cleanupRepository) DeleteExpiredMessagesGlobal(ctx context.Context, beforeTime time.Time, excludeRooms []string) (int64, error) {
	query := `
		DELETE FROM events
		WHERE origin_server_ts < $1
		AND type IN ('m.room.message', 'm.room.encrypted')
		AND ($2::text[] IS NULL OR room_id != ALL($2))
	`

	var excludeArray interface{}
	if len(excludeRooms) > 0 {
		excludeArray = excludeRooms
	}

	result, err := r.db.ExecContext(ctx, query, beforeTime.UnixMilli(), excludeArray)
	if err != nil {
		return 0, err
	}

	return result.RowsAffected()
}

// DeleteExpiredMediaFiles 删除过期的媒体文件记录
func (r *cleanupRepository) DeleteExpiredMediaFiles(ctx context.Context, beforeTime time.Time) ([]string, error) {
	// 先获取要删除的文件路径
	query := `
		SELECT storage_path
		FROM media_files
		WHERE expires_at IS NOT NULL
		AND expires_at < $1
	`

	rows, err := r.db.QueryContext(ctx, query, beforeTime)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var paths []string
	for rows.Next() {
		var path string
		if err := rows.Scan(&path); err != nil {
			return nil, err
		}
		paths = append(paths, path)
	}

	if err := rows.Err(); err != nil {
		return nil, err
	}

	// 删除记录
	deleteQuery := `
		DELETE FROM media_files
		WHERE expires_at IS NOT NULL
		AND expires_at < $1
	`
	_, err = r.db.ExecContext(ctx, deleteQuery, beforeTime)
	if err != nil {
		return nil, err
	}

	return paths, nil
}

// DeleteOldAuditLogs 删除旧的审计日志
func (r *cleanupRepository) DeleteOldAuditLogs(ctx context.Context, beforeTime time.Time) (int64, error) {
	query := `
		DELETE FROM audit_logs
		WHERE created_at < $1
	`

	result, err := r.db.ExecContext(ctx, query, beforeTime)
	if err != nil {
		return 0, err
	}

	return result.RowsAffected()
}

// DeleteExpiredTokens 删除过期的Token
func (r *cleanupRepository) DeleteExpiredTokens(ctx context.Context) (int64, error) {
	query := `
		DELETE FROM refresh_tokens
		WHERE expires_at < NOW()
		OR revoked = true
	`

	result, err := r.db.ExecContext(ctx, query)
	if err != nil {
		return 0, err
	}

	return result.RowsAffected()
}

// GetCleanupStats 获取清理统计
func (r *cleanupRepository) GetCleanupStats(ctx context.Context) (*CleanupStats, error) {
	stats := &CleanupStats{}

	// 统计过期消息数量
	msgQuery := `
		SELECT COUNT(*)
		FROM events
		WHERE type IN ('m.room.message', 'm.room.encrypted')
	`
	if err := r.db.QueryRowContext(ctx, msgQuery).Scan(&stats.TotalMessages); err != nil {
		return nil, err
	}

	// 统计媒体文件数量
	mediaQuery := `SELECT COUNT(*) FROM media_files`
	if err := r.db.QueryRowContext(ctx, mediaQuery).Scan(&stats.TotalMediaFiles); err != nil {
		return nil, err
	}

	// 统计审计日志数量
	logQuery := `SELECT COUNT(*) FROM audit_logs`
	if err := r.db.QueryRowContext(ctx, logQuery).Scan(&stats.TotalAuditLogs); err != nil {
		return nil, err
	}

	return stats, nil
}

// RoomRetentionPolicy 群组消息保留策略
type RoomRetentionPolicy struct {
	RoomID         string
	RetentionHours int
	Enabled        bool
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

// CleanupStats 清理统计
type CleanupStats struct {
	TotalMessages   int64
	TotalMediaFiles int64
	TotalAuditLogs  int64
}

// ExpiredAutoDeleteMessage 过期自动删除消息
type ExpiredAutoDeleteMessage struct {
	MessageID string
	RoomID    string
}

// GetExpiredAutoDeleteMessages 获取已过期的自动删除消息
func (r *cleanupRepository) GetExpiredAutoDeleteMessages(ctx context.Context, limit int) ([]ExpiredAutoDeleteMessage, error) {
	query := `
		SELECT id, room_id
		FROM messages
		WHERE auto_delete_at IS NOT NULL
		AND auto_delete_at <= NOW()
		AND is_deleted = false
		LIMIT $1
	`

	rows, err := r.db.QueryContext(ctx, query, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var messages []ExpiredAutoDeleteMessage
	for rows.Next() {
		var msg ExpiredAutoDeleteMessage
		if err := rows.Scan(&msg.MessageID, &msg.RoomID); err != nil {
			return nil, err
		}
		messages = append(messages, msg)
	}

	return messages, rows.Err()
}
