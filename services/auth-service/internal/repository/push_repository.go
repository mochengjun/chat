package repository

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
)

// PushPlatform 推送平台类型
type PushPlatform string

const (
	PushPlatformFCM  PushPlatform = "fcm"  // Firebase Cloud Messaging (Android)
	PushPlatformAPNs PushPlatform = "apns" // Apple Push Notification service (iOS)
	PushPlatformWeb  PushPlatform = "web"  // Web Push
)

// PushToken 推送设备 Token
type PushToken struct {
	ID        uint         `gorm:"primaryKey" json:"id"`
	UserID    string       `gorm:"size:36;not null;index" json:"user_id"`
	DeviceID  string       `gorm:"size:36;not null;index" json:"device_id"`
	Platform  PushPlatform `gorm:"size:20;not null" json:"platform"`
	Token     string       `gorm:"size:500;not null;uniqueIndex" json:"token"`
	IsActive  bool         `gorm:"default:true" json:"is_active"`
	CreatedAt time.Time    `json:"created_at"`
	UpdatedAt time.Time    `json:"updated_at"`
}

// PushNotificationType 推送通知类型
type PushNotificationType string

const (
	PushTypeNewMessage   PushNotificationType = "new_message"
	PushTypeMention      PushNotificationType = "mention"
	PushTypeRoomInvite   PushNotificationType = "room_invite"
	PushTypeSystemAlert  PushNotificationType = "system_alert"
	PushTypeCallIncoming PushNotificationType = "call_incoming"
	PushTypeCallMissed   PushNotificationType = "call_missed"
)

// PushStatus 推送状态
type PushStatus string

const (
	PushStatusPending   PushStatus = "pending"
	PushStatusSent      PushStatus = "sent"
	PushStatusDelivered PushStatus = "delivered"
	PushStatusFailed    PushStatus = "failed"
)

// PushNotification 推送通知记录
type PushNotification struct {
	ID           uint                 `gorm:"primaryKey" json:"id"`
	UserID       string               `gorm:"size:36;not null;index" json:"user_id"`
	DeviceID     string               `gorm:"size:36" json:"device_id,omitempty"`
	Type         PushNotificationType `gorm:"size:30;not null" json:"type"`
	Title        string               `gorm:"size:200" json:"title"`
	Body         string               `gorm:"size:1000" json:"body"`
	Data         string               `gorm:"type:text" json:"data,omitempty"` // JSON payload
	ImageURL     string               `gorm:"size:500" json:"image_url,omitempty"`
	Status       PushStatus           `gorm:"size:20;not null;default:pending" json:"status"`
	Platform     PushPlatform         `gorm:"size:20" json:"platform,omitempty"`
	MessageID    string               `gorm:"size:100" json:"message_id,omitempty"` // 平台返回的消息ID
	ErrorMessage string               `gorm:"size:500" json:"error_message,omitempty"`
	SentAt       *time.Time           `json:"sent_at,omitempty"`
	CreatedAt    time.Time            `json:"created_at"`
}

// UserPushSettings 用户推送设置
type UserPushSettings struct {
	UserID          string    `gorm:"primaryKey;size:36" json:"user_id"`
	EnablePush      bool      `gorm:"default:true" json:"enable_push"`
	EnableSound     bool      `gorm:"default:true" json:"enable_sound"`
	EnableVibration bool      `gorm:"default:true" json:"enable_vibration"`
	EnablePreview   bool      `gorm:"default:true" json:"enable_preview"`     // 是否显示消息预览
	QuietHoursStart *int      `json:"quiet_hours_start,omitempty"`            // 免打扰开始时间 (0-23)
	QuietHoursEnd   *int      `json:"quiet_hours_end,omitempty"`              // 免打扰结束时间 (0-23)
	MutedRooms      string    `gorm:"type:text" json:"muted_rooms,omitempty"` // JSON array of room IDs
	UpdatedAt       time.Time `json:"updated_at"`
}

// PushRepository 推送仓库接口
type PushRepository interface {
	// Token 管理
	SaveToken(ctx context.Context, token *PushToken) error
	GetTokenByDevice(ctx context.Context, userID, deviceID string) (*PushToken, error)
	GetTokensByUser(ctx context.Context, userID string) ([]*PushToken, error)
	GetActiveTokensByUser(ctx context.Context, userID string) ([]*PushToken, error)
	DeactivateToken(ctx context.Context, token string) error
	DeactivateUserTokens(ctx context.Context, userID string) error
	DeleteToken(ctx context.Context, token string) error

	// 推送记录
	CreateNotification(ctx context.Context, notification *PushNotification) error
	UpdateNotificationStatus(ctx context.Context, id uint, status PushStatus, messageID, errorMsg string) error
	GetPendingNotifications(ctx context.Context, limit int) ([]*PushNotification, error)
	GetUserNotifications(ctx context.Context, userID string, page, pageSize int) ([]*PushNotification, int64, error)

	// 用户设置
	GetUserSettings(ctx context.Context, userID string) (*UserPushSettings, error)
	SaveUserSettings(ctx context.Context, settings *UserPushSettings) error
}

// pushRepository 推送仓库实现
type pushRepository struct {
	db *gorm.DB
}

// NewPushRepository 创建推送仓库实例
func NewPushRepository(db *gorm.DB) PushRepository {
	return &pushRepository{db: db}
}

// ====== Token 管理 ======

func (r *pushRepository) SaveToken(ctx context.Context, token *PushToken) error {
	// 使用 upsert 逻辑：如果 token 已存在则更新
	existing := &PushToken{}
	result := r.db.WithContext(ctx).Where("token = ?", token.Token).First(existing)

	if errors.Is(result.Error, gorm.ErrRecordNotFound) {
		// 新 token，直接创建
		return r.db.WithContext(ctx).Create(token).Error
	}

	// 已存在，更新信息
	return r.db.WithContext(ctx).Model(existing).Updates(map[string]interface{}{
		"user_id":    token.UserID,
		"device_id":  token.DeviceID,
		"platform":   token.Platform,
		"is_active":  true,
		"updated_at": time.Now(),
	}).Error
}

func (r *pushRepository) GetTokenByDevice(ctx context.Context, userID, deviceID string) (*PushToken, error) {
	var token PushToken
	err := r.db.WithContext(ctx).Where("user_id = ? AND device_id = ? AND is_active = ?", userID, deviceID, true).First(&token).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &token, nil
}

func (r *pushRepository) GetTokensByUser(ctx context.Context, userID string) ([]*PushToken, error) {
	var tokens []*PushToken
	err := r.db.WithContext(ctx).Where("user_id = ?", userID).Find(&tokens).Error
	return tokens, err
}

func (r *pushRepository) GetActiveTokensByUser(ctx context.Context, userID string) ([]*PushToken, error) {
	var tokens []*PushToken
	err := r.db.WithContext(ctx).Where("user_id = ? AND is_active = ?", userID, true).Find(&tokens).Error
	return tokens, err
}

func (r *pushRepository) DeactivateToken(ctx context.Context, token string) error {
	return r.db.WithContext(ctx).Model(&PushToken{}).Where("token = ?", token).Update("is_active", false).Error
}

func (r *pushRepository) DeactivateUserTokens(ctx context.Context, userID string) error {
	return r.db.WithContext(ctx).Model(&PushToken{}).Where("user_id = ?", userID).Update("is_active", false).Error
}

func (r *pushRepository) DeleteToken(ctx context.Context, token string) error {
	return r.db.WithContext(ctx).Delete(&PushToken{}, "token = ?", token).Error
}

// ====== 推送记录 ======

func (r *pushRepository) CreateNotification(ctx context.Context, notification *PushNotification) error {
	return r.db.WithContext(ctx).Create(notification).Error
}

func (r *pushRepository) UpdateNotificationStatus(ctx context.Context, id uint, status PushStatus, messageID, errorMsg string) error {
	updates := map[string]interface{}{
		"status": status,
	}

	if messageID != "" {
		updates["message_id"] = messageID
	}
	if errorMsg != "" {
		updates["error_message"] = errorMsg
	}
	if status == PushStatusSent || status == PushStatusDelivered {
		now := time.Now()
		updates["sent_at"] = &now
	}

	return r.db.WithContext(ctx).Model(&PushNotification{}).Where("id = ?", id).Updates(updates).Error
}

func (r *pushRepository) GetPendingNotifications(ctx context.Context, limit int) ([]*PushNotification, error) {
	var notifications []*PushNotification
	err := r.db.WithContext(ctx).Where("status = ?", PushStatusPending).
		Order("created_at ASC").
		Limit(limit).
		Find(&notifications).Error
	return notifications, err
}

func (r *pushRepository) GetUserNotifications(ctx context.Context, userID string, page, pageSize int) ([]*PushNotification, int64, error) {
	var notifications []*PushNotification
	var total int64

	if err := r.db.WithContext(ctx).Model(&PushNotification{}).Where("user_id = ?", userID).Count(&total).Error; err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * pageSize
	err := r.db.WithContext(ctx).Where("user_id = ?", userID).
		Order("created_at DESC").
		Offset(offset).
		Limit(pageSize).
		Find(&notifications).Error

	return notifications, total, err
}

// ====== 用户设置 ======

func (r *pushRepository) GetUserSettings(ctx context.Context, userID string) (*UserPushSettings, error) {
	var settings UserPushSettings
	err := r.db.WithContext(ctx).First(&settings, "user_id = ?", userID).Error

	if errors.Is(err, gorm.ErrRecordNotFound) {
		// 返回默认设置
		return &UserPushSettings{
			UserID:          userID,
			EnablePush:      true,
			EnableSound:     true,
			EnableVibration: true,
			EnablePreview:   true,
		}, nil
	}

	return &settings, err
}

func (r *pushRepository) SaveUserSettings(ctx context.Context, settings *UserPushSettings) error {
	settings.UpdatedAt = time.Now()
	return r.db.WithContext(ctx).Save(settings).Error
}
