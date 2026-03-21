package repository

import (
	"context"
	"database/sql"
	"time"

	_ "github.com/lib/pq"
)

// MediaRepo 媒体仓库接口
type MediaRepo interface {
	Close() error
	CreateMediaFile(ctx context.Context, file *MediaFile) error
	GetMediaFile(ctx context.Context, id string) (*MediaFile, error)
	IncrementDownloadCount(ctx context.Context, id string) error
	CreateAccessLog(ctx context.Context, log *MediaAccessLog) error
	GetAccessLogs(ctx context.Context, mediaID string, limit int) ([]MediaAccessLog, error)
	DeleteMediaFile(ctx context.Context, id string) error
	GetUserMediaFiles(ctx context.Context, userID string, limit, offset int) ([]MediaFile, error)
	UpdateMediaPermission(ctx context.Context, mediaID string, perm *MediaPermission) error
	GetMediaPermission(ctx context.Context, mediaID string) (*MediaPermission, error)
}

// mediaRepository 媒体仓库实现
type mediaRepository struct {
	db *sql.DB
}

// NewMediaRepository 创建媒体仓库实例
func NewMediaRepository(databaseURL string) (MediaRepo, error) {
	db, err := sql.Open("postgres", databaseURL)
	if err != nil {
		return nil, err
	}

	if err := db.Ping(); err != nil {
		return nil, err
	}

	return &mediaRepository{db: db}, nil
}

func (r *mediaRepository) Close() error {
	return r.db.Close()
}

// MediaFile 媒体文件
type MediaFile struct {
	ID            string     `json:"id"`
	FileName      string     `json:"file_name"`
	MimeType      string     `json:"mime_type"`
	Size          int64      `json:"size"`
	StoragePath   string     `json:"storage_path"`
	UploadedBy    string     `json:"uploaded_by"`
	RoomID        string     `json:"room_id,omitempty"`
	PasswordHash  string     `json:"-"`
	DownloadLimit int        `json:"download_limit,omitempty"`
	DownloadCount int        `json:"download_count"`
	ExpiresAt     *time.Time `json:"expires_at,omitempty"`
	CreatedAt     time.Time  `json:"created_at"`
	UpdatedAt     time.Time  `json:"updated_at"`
}

// MediaAccessLog 媒体访问日志
type MediaAccessLog struct {
	ID        string    `json:"id"`
	MediaID   string    `json:"media_id"`
	UserID    string    `json:"user_id"`
	Action    string    `json:"action"` // download, view, share
	IPAddress string    `json:"ip_address"`
	UserAgent string    `json:"user_agent"`
	CreatedAt time.Time `json:"created_at"`
}

// MediaPermission 媒体权限
type MediaPermission struct {
	MediaID        string `json:"media_id"`
	AllowDownload  bool   `json:"allow_download"`
	RequireAuth    bool   `json:"require_auth"`
	AllowedUserIDs string `json:"allowed_user_ids"` // JSON数组
}

// CreateMediaFile 创建媒体文件记录
func (r *mediaRepository) CreateMediaFile(ctx context.Context, file *MediaFile) error {
	query := `
		INSERT INTO media_files (
			id, file_name, mime_type, size, storage_path, uploaded_by,
			room_id, password_hash, download_limit, expires_at, created_at, updated_at
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, NOW(), NOW())
	`

	_, err := r.db.ExecContext(ctx, query,
		file.ID,
		file.FileName,
		file.MimeType,
		file.Size,
		file.StoragePath,
		file.UploadedBy,
		file.RoomID,
		file.PasswordHash,
		file.DownloadLimit,
		file.ExpiresAt,
	)
	return err
}

// GetMediaFile 获取媒体文件
func (r *mediaRepository) GetMediaFile(ctx context.Context, id string) (*MediaFile, error) {
	query := `
		SELECT id, file_name, mime_type, size, storage_path, uploaded_by,
			COALESCE(room_id, ''), password_hash, COALESCE(download_limit, 0),
			download_count, expires_at, created_at, updated_at
		FROM media_files
		WHERE id = $1
	`

	file := &MediaFile{}
	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&file.ID,
		&file.FileName,
		&file.MimeType,
		&file.Size,
		&file.StoragePath,
		&file.UploadedBy,
		&file.RoomID,
		&file.PasswordHash,
		&file.DownloadLimit,
		&file.DownloadCount,
		&file.ExpiresAt,
		&file.CreatedAt,
		&file.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return file, err
}

// IncrementDownloadCount 增加下载次数
func (r *mediaRepository) IncrementDownloadCount(ctx context.Context, id string) error {
	query := `
		UPDATE media_files
		SET download_count = download_count + 1, updated_at = NOW()
		WHERE id = $1
	`
	_, err := r.db.ExecContext(ctx, query, id)
	return err
}

// CreateAccessLog 创建访问日志
func (r *mediaRepository) CreateAccessLog(ctx context.Context, log *MediaAccessLog) error {
	query := `
		INSERT INTO media_access_logs (id, media_id, user_id, action, ip_address, user_agent, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, NOW())
	`
	_, err := r.db.ExecContext(ctx, query, log.ID, log.MediaID, log.UserID, log.Action, log.IPAddress, log.UserAgent)
	return err
}

// GetAccessLogs 获取访问日志
func (r *mediaRepository) GetAccessLogs(ctx context.Context, mediaID string, limit int) ([]MediaAccessLog, error) {
	query := `
		SELECT id, media_id, user_id, action, ip_address, user_agent, created_at
		FROM media_access_logs
		WHERE media_id = $1
		ORDER BY created_at DESC
		LIMIT $2
	`

	rows, err := r.db.QueryContext(ctx, query, mediaID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var logs []MediaAccessLog
	for rows.Next() {
		var log MediaAccessLog
		err := rows.Scan(&log.ID, &log.MediaID, &log.UserID, &log.Action, &log.IPAddress, &log.UserAgent, &log.CreatedAt)
		if err != nil {
			return nil, err
		}
		logs = append(logs, log)
	}

	return logs, rows.Err()
}

// DeleteMediaFile 删除媒体文件记录
func (r *mediaRepository) DeleteMediaFile(ctx context.Context, id string) error {
	query := `DELETE FROM media_files WHERE id = $1`
	_, err := r.db.ExecContext(ctx, query, id)
	return err
}

// GetUserMediaFiles 获取用户上传的文件
func (r *mediaRepository) GetUserMediaFiles(ctx context.Context, userID string, limit, offset int) ([]MediaFile, error) {
	query := `
		SELECT id, file_name, mime_type, size, storage_path, uploaded_by,
			COALESCE(room_id, ''), password_hash, COALESCE(download_limit, 0),
			download_count, expires_at, created_at, updated_at
		FROM media_files
		WHERE uploaded_by = $1
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`

	rows, err := r.db.QueryContext(ctx, query, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var files []MediaFile
	for rows.Next() {
		var file MediaFile
		err := rows.Scan(
			&file.ID, &file.FileName, &file.MimeType, &file.Size, &file.StoragePath,
			&file.UploadedBy, &file.RoomID, &file.PasswordHash, &file.DownloadLimit,
			&file.DownloadCount, &file.ExpiresAt, &file.CreatedAt, &file.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		files = append(files, file)
	}

	return files, rows.Err()
}

// UpdateMediaPermission 更新媒体权限
func (r *mediaRepository) UpdateMediaPermission(ctx context.Context, mediaID string, perm *MediaPermission) error {
	query := `
		INSERT INTO media_permissions (media_id, allow_download, require_auth, allowed_user_ids)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (media_id) DO UPDATE
		SET allow_download = EXCLUDED.allow_download,
			require_auth = EXCLUDED.require_auth,
			allowed_user_ids = EXCLUDED.allowed_user_ids
	`
	_, err := r.db.ExecContext(ctx, query, mediaID, perm.AllowDownload, perm.RequireAuth, perm.AllowedUserIDs)
	return err
}

// GetMediaPermission 获取媒体权限
func (r *mediaRepository) GetMediaPermission(ctx context.Context, mediaID string) (*MediaPermission, error) {
	query := `
		SELECT media_id, allow_download, require_auth, COALESCE(allowed_user_ids, '[]')
		FROM media_permissions
		WHERE media_id = $1
	`

	perm := &MediaPermission{}
	err := r.db.QueryRowContext(ctx, query, mediaID).Scan(&perm.MediaID, &perm.AllowDownload, &perm.RequireAuth, &perm.AllowedUserIDs)
	if err == sql.ErrNoRows {
		// 默认权限
		return &MediaPermission{
			MediaID:       mediaID,
			AllowDownload: true,
			RequireAuth:   true,
		}, nil
	}
	return perm, err
}
