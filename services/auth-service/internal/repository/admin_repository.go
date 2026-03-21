package repository

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
)

// AuditAction 审计操作类型
type AuditAction string

const (
	AuditActionUserCreate    AuditAction = "user_create"
	AuditActionUserUpdate    AuditAction = "user_update"
	AuditActionUserDelete    AuditAction = "user_delete"
	AuditActionUserLogin     AuditAction = "user_login"
	AuditActionUserLogout    AuditAction = "user_logout"
	AuditActionRoomCreate    AuditAction = "room_create"
	AuditActionRoomUpdate    AuditAction = "room_update"
	AuditActionRoomDelete    AuditAction = "room_delete"
	AuditActionMemberAdd     AuditAction = "member_add"
	AuditActionMemberRemove  AuditAction = "member_remove"
	AuditActionMemberRole    AuditAction = "member_role"
	AuditActionMessageDelete AuditAction = "message_delete"
	AuditActionSettingUpdate AuditAction = "setting_update"
	AuditActionSettingDelete AuditAction = "setting_delete"
	AuditActionAdminAction   AuditAction = "admin_action"
)

// AuditLog 审计日志
type AuditLog struct {
	ID         uint        `gorm:"primaryKey" json:"id"`
	Action     AuditAction `gorm:"size:50;not null;index" json:"action"`
	ActorID    string      `gorm:"size:36;index" json:"actor_id"`
	ActorName  string      `gorm:"size:100" json:"actor_name"`
	TargetType string      `gorm:"size:50" json:"target_type,omitempty"`
	TargetID   string      `gorm:"size:36" json:"target_id,omitempty"`
	TargetName string      `gorm:"size:255" json:"target_name,omitempty"`
	Details    string      `gorm:"type:text" json:"details,omitempty"`
	IPAddress  string      `gorm:"size:45" json:"ip_address,omitempty"`
	UserAgent  string      `gorm:"size:500" json:"user_agent,omitempty"`
	CreatedAt  time.Time   `gorm:"index" json:"created_at"`
}

// SystemSetting 系统设置
type SystemSetting struct {
	ID          uint      `gorm:"primaryKey" json:"id"`
	Key         string    `gorm:"size:100;uniqueIndex;not null" json:"key"`
	Value       string    `gorm:"type:text" json:"value"`
	Description string    `gorm:"size:500" json:"description,omitempty"`
	UpdatedAt   time.Time `json:"updated_at"`
	UpdatedBy   string    `gorm:"size:36" json:"updated_by,omitempty"`
}

// AdminRole 管理员角色
type AdminRole string

const (
	AdminRoleSuperAdmin AdminRole = "super_admin"
	AdminRoleAdmin      AdminRole = "admin"
	AdminRoleOperator   AdminRole = "operator"
	AdminRoleViewer     AdminRole = "viewer"
)

// AdminUser 管理员用户（扩展 User）
type AdminUser struct {
	UserID    string    `gorm:"primaryKey;size:36" json:"user_id"`
	Role      AdminRole `gorm:"size:20;not null;default:viewer" json:"role"`
	CreatedAt time.Time `json:"created_at"`
	CreatedBy string    `gorm:"size:36" json:"created_by,omitempty"`
}

// UserStats 用户统计
type UserStats struct {
	TotalUsers       int64 `json:"total_users"`
	ActiveUsers      int64 `json:"active_users"`
	InactiveUsers    int64 `json:"inactive_users"`
	NewUsersToday    int64 `json:"new_users_today"`
	NewUsersThisWeek int64 `json:"new_users_this_week"`
}

// RoomStats 房间统计
type RoomStats struct {
	TotalRooms       int64 `json:"total_rooms"`
	DirectRooms      int64 `json:"direct_rooms"`
	GroupRooms       int64 `json:"group_rooms"`
	ChannelRooms     int64 `json:"channel_rooms"`
	NewRoomsToday    int64 `json:"new_rooms_today"`
	NewRoomsThisWeek int64 `json:"new_rooms_this_week"`
}

// MessageStats 消息统计
type MessageStats struct {
	TotalMessages    int64 `json:"total_messages"`
	MessagesToday    int64 `json:"messages_today"`
	MessagesThisWeek int64 `json:"messages_this_week"`
	TextMessages     int64 `json:"text_messages"`
	MediaMessages    int64 `json:"media_messages"`
	DeletedMessages  int64 `json:"deleted_messages"`
}

// SystemStats 系统统计
type SystemStats struct {
	Users    UserStats    `json:"users"`
	Rooms    RoomStats    `json:"rooms"`
	Messages MessageStats `json:"messages"`
}

// AdminRepository 管理员仓库接口
type AdminRepository interface {
	// 用户管理
	GetUsers(ctx context.Context, page, pageSize int, search string, activeOnly bool) ([]*User, int64, error)
	GetUserByID(ctx context.Context, userID string) (*User, error)
	UpdateUserStatus(ctx context.Context, userID string, isActive bool) error
	ResetUserPassword(ctx context.Context, userID string, passwordHash string) error
	DeleteUser(ctx context.Context, userID string) error

	// 管理员管理
	GetAdminUsers(ctx context.Context) ([]*AdminUser, error)
	GetAdminUser(ctx context.Context, userID string) (*AdminUser, error)
	CreateAdminUser(ctx context.Context, admin *AdminUser) error
	UpdateAdminRole(ctx context.Context, userID string, role AdminRole) error
	DeleteAdminUser(ctx context.Context, userID string) error
	IsAdmin(ctx context.Context, userID string) (bool, AdminRole, error)

	// 房间管理
	GetRooms(ctx context.Context, page, pageSize int, search string, roomType string) ([]*Room, int64, error)
	GetRoomByID(ctx context.Context, roomID string) (*Room, error)
	DeleteRoom(ctx context.Context, roomID string) error
	GetRoomMembersAdmin(ctx context.Context, roomID string) ([]*RoomMember, error)

	// 审计日志
	CreateAuditLog(ctx context.Context, log *AuditLog) error
	GetAuditLogs(ctx context.Context, page, pageSize int, action string, actorID string, startTime, endTime *time.Time) ([]*AuditLog, int64, error)

	// 系统设置
	GetSettings(ctx context.Context) ([]*SystemSetting, error)
	GetSetting(ctx context.Context, key string) (*SystemSetting, error)
	UpdateSetting(ctx context.Context, setting *SystemSetting) error
	DeleteSetting(ctx context.Context, key string) error

	// 统计
	GetUserStats(ctx context.Context) (*UserStats, error)
	GetRoomStats(ctx context.Context) (*RoomStats, error)
	GetMessageStats(ctx context.Context) (*MessageStats, error)
}

// adminRepository 管理员仓库实现
type adminRepository struct {
	db *gorm.DB
}

// NewAdminRepository 创建管理员仓库实例
func NewAdminRepository(db *gorm.DB) AdminRepository {
	return &adminRepository{db: db}
}

// ====== 用户管理 ======

func (r *adminRepository) GetUsers(ctx context.Context, page, pageSize int, search string, activeOnly bool) ([]*User, int64, error) {
	var users []*User
	var total int64

	query := r.db.WithContext(ctx).Model(&User{})

	if search != "" {
		query = query.Where("username LIKE ? OR display_name LIKE ? OR email LIKE ?",
			"%"+search+"%", "%"+search+"%", "%"+search+"%")
	}

	if activeOnly {
		query = query.Where("is_active = ?", true)
	}

	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * pageSize
	err := query.Order("created_at DESC").Offset(offset).Limit(pageSize).Find(&users).Error

	return users, total, err
}

func (r *adminRepository) GetUserByID(ctx context.Context, userID string) (*User, error) {
	var user User
	err := r.db.WithContext(ctx).First(&user, "user_id = ?", userID).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &user, nil
}

func (r *adminRepository) UpdateUserStatus(ctx context.Context, userID string, isActive bool) error {
	return r.db.WithContext(ctx).Model(&User{}).Where("user_id = ?", userID).Update("is_active", isActive).Error
}

func (r *adminRepository) ResetUserPassword(ctx context.Context, userID string, passwordHash string) error {
	return r.db.WithContext(ctx).Model(&User{}).Where("user_id = ?", userID).Update("password_hash", passwordHash).Error
}

func (r *adminRepository) DeleteUser(ctx context.Context, userID string) error {
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		// 删除用户的所有房间成员记录
		if err := tx.Delete(&RoomMember{}, "user_id = ?", userID).Error; err != nil {
			return err
		}
		// 删除用户的设备记录
		if err := tx.Delete(&Device{}, "user_id = ?", userID).Error; err != nil {
			return err
		}
		// 删除用户的 Token
		if err := tx.Delete(&RefreshToken{}, "user_id = ?", userID).Error; err != nil {
			return err
		}
		// 删除用户
		return tx.Delete(&User{}, "user_id = ?", userID).Error
	})
}

// ====== 管理员管理 ======

func (r *adminRepository) GetAdminUsers(ctx context.Context) ([]*AdminUser, error) {
	var admins []*AdminUser
	err := r.db.WithContext(ctx).Find(&admins).Error
	return admins, err
}

func (r *adminRepository) GetAdminUser(ctx context.Context, userID string) (*AdminUser, error) {
	var admin AdminUser
	err := r.db.WithContext(ctx).First(&admin, "user_id = ?", userID).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &admin, nil
}

func (r *adminRepository) CreateAdminUser(ctx context.Context, admin *AdminUser) error {
	return r.db.WithContext(ctx).Create(admin).Error
}

func (r *adminRepository) UpdateAdminRole(ctx context.Context, userID string, role AdminRole) error {
	return r.db.WithContext(ctx).Model(&AdminUser{}).Where("user_id = ?", userID).Update("role", role).Error
}

func (r *adminRepository) DeleteAdminUser(ctx context.Context, userID string) error {
	return r.db.WithContext(ctx).Delete(&AdminUser{}, "user_id = ?", userID).Error
}

func (r *adminRepository) IsAdmin(ctx context.Context, userID string) (bool, AdminRole, error) {
	var admin AdminUser
	err := r.db.WithContext(ctx).First(&admin, "user_id = ?", userID).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return false, "", nil
		}
		return false, "", err
	}
	return true, admin.Role, nil
}

// ====== 房间管理 ======

func (r *adminRepository) GetRooms(ctx context.Context, page, pageSize int, search string, roomType string) ([]*Room, int64, error) {
	var rooms []*Room
	var total int64

	query := r.db.WithContext(ctx).Model(&Room{})

	if search != "" {
		query = query.Where("name LIKE ? OR description LIKE ?", "%"+search+"%", "%"+search+"%")
	}

	if roomType != "" {
		query = query.Where("type = ?", roomType)
	}

	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * pageSize
	err := query.Order("created_at DESC").Offset(offset).Limit(pageSize).Find(&rooms).Error

	return rooms, total, err
}

func (r *adminRepository) GetRoomByID(ctx context.Context, roomID string) (*Room, error) {
	var room Room
	err := r.db.WithContext(ctx).First(&room, "id = ?", roomID).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &room, nil
}

func (r *adminRepository) DeleteRoom(ctx context.Context, roomID string) error {
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		// 删除消息
		if err := tx.Delete(&Message{}, "room_id = ?", roomID).Error; err != nil {
			return err
		}
		// 删除已读回执
		if err := tx.Delete(&ReadReceipt{}, "room_id = ?", roomID).Error; err != nil {
			return err
		}
		// 删除成员
		if err := tx.Delete(&RoomMember{}, "room_id = ?", roomID).Error; err != nil {
			return err
		}
		// 删除房间
		return tx.Delete(&Room{}, "id = ?", roomID).Error
	})
}

func (r *adminRepository) GetRoomMembersAdmin(ctx context.Context, roomID string) ([]*RoomMember, error) {
	var members []*RoomMember
	err := r.db.WithContext(ctx).Preload("User").Where("room_id = ?", roomID).Find(&members).Error
	return members, err
}

// ====== 审计日志 ======

func (r *adminRepository) CreateAuditLog(ctx context.Context, log *AuditLog) error {
	return r.db.WithContext(ctx).Create(log).Error
}

func (r *adminRepository) GetAuditLogs(ctx context.Context, page, pageSize int, action string, actorID string, startTime, endTime *time.Time) ([]*AuditLog, int64, error) {
	var logs []*AuditLog
	var total int64

	query := r.db.WithContext(ctx).Model(&AuditLog{})

	if action != "" {
		query = query.Where("action = ?", action)
	}
	if actorID != "" {
		query = query.Where("actor_id = ?", actorID)
	}
	if startTime != nil {
		query = query.Where("created_at >= ?", startTime)
	}
	if endTime != nil {
		query = query.Where("created_at <= ?", endTime)
	}

	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * pageSize
	err := query.Order("created_at DESC").Offset(offset).Limit(pageSize).Find(&logs).Error

	return logs, total, err
}

// ====== 系统设置 ======

func (r *adminRepository) GetSettings(ctx context.Context) ([]*SystemSetting, error) {
	var settings []*SystemSetting
	err := r.db.WithContext(ctx).Find(&settings).Error
	return settings, err
}

func (r *adminRepository) GetSetting(ctx context.Context, key string) (*SystemSetting, error) {
	var setting SystemSetting
	err := r.db.WithContext(ctx).First(&setting, "`key` = ?", key).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &setting, nil
}

func (r *adminRepository) UpdateSetting(ctx context.Context, setting *SystemSetting) error {
	return r.db.WithContext(ctx).Save(setting).Error
}

func (r *adminRepository) DeleteSetting(ctx context.Context, key string) error {
	result := r.db.WithContext(ctx).Delete(&SystemSetting{}, "`key` = ?", key)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

// ====== 统计 ======

func (r *adminRepository) GetUserStats(ctx context.Context) (*UserStats, error) {
	var stats UserStats
	now := time.Now()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	weekAgo := today.AddDate(0, 0, -7)

	db := r.db.WithContext(ctx)
	if err := db.Model(&User{}).Count(&stats.TotalUsers).Error; err != nil {
		return nil, err
	}
	if err := db.Model(&User{}).Where("is_active = ?", true).Count(&stats.ActiveUsers).Error; err != nil {
		return nil, err
	}
	if err := db.Model(&User{}).Where("is_active = ?", false).Count(&stats.InactiveUsers).Error; err != nil {
		return nil, err
	}
	if err := db.Model(&User{}).Where("created_at >= ?", today).Count(&stats.NewUsersToday).Error; err != nil {
		return nil, err
	}
	if err := db.Model(&User{}).Where("created_at >= ?", weekAgo).Count(&stats.NewUsersThisWeek).Error; err != nil {
		return nil, err
	}

	return &stats, nil
}

func (r *adminRepository) GetRoomStats(ctx context.Context) (*RoomStats, error) {
	var stats RoomStats
	now := time.Now()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	weekAgo := today.AddDate(0, 0, -7)

	db := r.db.WithContext(ctx)
	if err := db.Model(&Room{}).Count(&stats.TotalRooms).Error; err != nil {
		return nil, err
	}
	if err := db.Model(&Room{}).Where("type = ?", RoomTypeDirect).Count(&stats.DirectRooms).Error; err != nil {
		return nil, err
	}
	if err := db.Model(&Room{}).Where("type = ?", RoomTypeGroup).Count(&stats.GroupRooms).Error; err != nil {
		return nil, err
	}
	if err := db.Model(&Room{}).Where("type = ?", RoomTypeChannel).Count(&stats.ChannelRooms).Error; err != nil {
		return nil, err
	}
	if err := db.Model(&Room{}).Where("created_at >= ?", today).Count(&stats.NewRoomsToday).Error; err != nil {
		return nil, err
	}
	if err := db.Model(&Room{}).Where("created_at >= ?", weekAgo).Count(&stats.NewRoomsThisWeek).Error; err != nil {
		return nil, err
	}

	return &stats, nil
}

func (r *adminRepository) GetMessageStats(ctx context.Context) (*MessageStats, error) {
	var stats MessageStats
	now := time.Now()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	weekAgo := today.AddDate(0, 0, -7)

	db := r.db.WithContext(ctx)
	if err := db.Model(&Message{}).Count(&stats.TotalMessages).Error; err != nil {
		return nil, err
	}
	if err := db.Model(&Message{}).Where("created_at >= ?", today).Count(&stats.MessagesToday).Error; err != nil {
		return nil, err
	}
	if err := db.Model(&Message{}).Where("created_at >= ?", weekAgo).Count(&stats.MessagesThisWeek).Error; err != nil {
		return nil, err
	}
	if err := db.Model(&Message{}).Where("type = ?", MessageTypeText).Count(&stats.TextMessages).Error; err != nil {
		return nil, err
	}
	if err := db.Model(&Message{}).Where("type IN ?", []MessageType{MessageTypeImage, MessageTypeVideo, MessageTypeAudio, MessageTypeFile}).Count(&stats.MediaMessages).Error; err != nil {
		return nil, err
	}
	if err := db.Model(&Message{}).Where("is_deleted = ?", true).Count(&stats.DeletedMessages).Error; err != nil {
		return nil, err
	}

	return &stats, nil
}
