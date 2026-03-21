package repository

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
)

// RoomType 房间类型
type RoomType string

const (
	RoomTypeDirect  RoomType = "direct"
	RoomTypeGroup   RoomType = "group"
	RoomTypeChannel RoomType = "channel"
)

// MemberRole 成员角色
type MemberRole string

const (
	MemberRoleOwner     MemberRole = "owner"
	MemberRoleAdmin     MemberRole = "admin"
	MemberRoleModerator MemberRole = "moderator"
	MemberRoleMember    MemberRole = "member"
)

// MessageType 消息类型
type MessageType string

const (
	MessageTypeText   MessageType = "text"
	MessageTypeImage  MessageType = "image"
	MessageTypeVideo  MessageType = "video"
	MessageTypeAudio  MessageType = "audio"
	MessageTypeFile   MessageType = "file"
	MessageTypeSystem MessageType = "system"
)

// MessageStatus 消息状态
type MessageStatus string

const (
	MessageStatusSending   MessageStatus = "sending"
	MessageStatusSent      MessageStatus = "sent"
	MessageStatusDelivered MessageStatus = "delivered"
	MessageStatusRead      MessageStatus = "read"
	MessageStatusFailed    MessageStatus = "failed"
)

// Room 聊天房间
type Room struct {
	ID             string    `gorm:"primaryKey;size:36" json:"id"`
	Name           string    `gorm:"size:255;not null" json:"name"`
	Description    string    `gorm:"size:1000" json:"description,omitempty"`
	AvatarURL      string    `gorm:"size:500" json:"avatar_url,omitempty"`
	Type           RoomType  `gorm:"size:20;not null;default:group" json:"type"`
	CreatorID      string    `gorm:"size:36" json:"creator_id"`
	RetentionHours *int      `json:"retention_hours,omitempty"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}

// RoomMember 房间成员
type RoomMember struct {
	ID        string     `gorm:"primaryKey;size:36" json:"id"`
	RoomID    string     `gorm:"size:36;not null;index:idx_room_member" json:"room_id"`
	UserID    string     `gorm:"size:36;not null;index:idx_room_member" json:"user_id"`
	Role      MemberRole `gorm:"size:20;not null;default:member" json:"role"`
	IsMuted   bool       `gorm:"default:false" json:"is_muted"`
	IsPinned  bool       `gorm:"default:false" json:"is_pinned"`
	JoinedAt  time.Time  `json:"joined_at"`
	UpdatedAt time.Time  `json:"updated_at"`

	// 关联
	Room *Room `gorm:"foreignKey:RoomID" json:"room,omitempty"`
	User *User `gorm:"foreignKey:UserID" json:"user,omitempty"`
}

// Message 消息
type Message struct {
	ID           string        `gorm:"primaryKey;size:36" json:"id"`
	RoomID       string        `gorm:"size:36;not null;index:idx_message_room" json:"room_id"`
	SenderID     string        `gorm:"size:36;not null" json:"sender_id"`
	Content      string        `gorm:"type:text" json:"content"`
	Type         MessageType   `gorm:"size:20;not null;default:text" json:"type"`
	Status       MessageStatus `gorm:"size:20;not null;default:sent" json:"status"`
	MediaURL     string        `gorm:"size:500" json:"media_url,omitempty"`
	ThumbnailURL string        `gorm:"size:500" json:"thumbnail_url,omitempty"`
	MediaSize    *int64        `json:"media_size,omitempty"`
	MimeType     string        `gorm:"size:100" json:"mime_type,omitempty"`
	ReplyToID    string        `gorm:"size:36" json:"reply_to_id,omitempty"`
	IsDeleted    bool          `gorm:"default:false" json:"is_deleted"`
	CreatedAt    time.Time     `gorm:"index:idx_message_created" json:"created_at"`
	EditedAt     *time.Time    `json:"edited_at,omitempty"`

	// 定时撤回相关字段
	AutoDeleteAfter *int       `json:"auto_delete_after,omitempty"`                                   // 撤回时间（分钟）：1, 5, 60, 1440
	AutoDeleteAt    *time.Time `gorm:"index:idx_message_auto_delete" json:"auto_delete_at,omitempty"` // 消息自动删除的绝对时间

	// 关联
	Room   *Room `gorm:"foreignKey:RoomID" json:"room,omitempty"`
	Sender *User `gorm:"foreignKey:SenderID" json:"sender,omitempty"`
}

// ReadReceipt 已读回执
type ReadReceipt struct {
	ID            string    `gorm:"primaryKey;size:36" json:"id"`
	RoomID        string    `gorm:"size:36;not null;index:idx_read_receipt" json:"room_id"`
	UserID        string    `gorm:"size:36;not null;index:idx_read_receipt" json:"user_id"`
	LastMessageID string    `gorm:"size:36" json:"last_message_id"`
	ReadAt        time.Time `json:"read_at"`
}

// ChatRepository 聊天仓库接口
type ChatRepository interface {
	// Room 相关
	CreateRoom(ctx context.Context, room *Room) error
	GetRoom(ctx context.Context, roomID string) (*Room, error)
	UpdateRoom(ctx context.Context, room *Room) error
	DeleteRoom(ctx context.Context, roomID string) error
	GetUserRooms(ctx context.Context, userID string) ([]*Room, error)
	GetPublicRooms(ctx context.Context, query string) ([]*Room, error)

	// Member 相关
	AddMember(ctx context.Context, member *RoomMember) error
	GetMember(ctx context.Context, roomID, userID string) (*RoomMember, error)
	UpdateMember(ctx context.Context, member *RoomMember) error
	RemoveMember(ctx context.Context, roomID, userID string) error
	GetRoomMembers(ctx context.Context, roomID string) ([]*RoomMember, error)
	IsMember(ctx context.Context, roomID, userID string) (bool, error)

	// Message 相关
	CreateMessage(ctx context.Context, message *Message) error
	GetMessage(ctx context.Context, messageID string) (*Message, error)
	GetMessages(ctx context.Context, roomID string, limit int, beforeID string) ([]*Message, error)
	UpdateMessage(ctx context.Context, message *Message) error
	DeleteMessage(ctx context.Context, messageID string) error
	GetUnreadCount(ctx context.Context, roomID, userID string) (int64, error)

	// ReadReceipt 相关
	UpdateReadReceipt(ctx context.Context, receipt *ReadReceipt) error
	GetReadReceipt(ctx context.Context, roomID, userID string) (*ReadReceipt, error)
	GetRoomReadReceipts(ctx context.Context, roomID string) ([]*ReadReceipt, error)
}

// chatRepository 聊天仓库实现
type chatRepository struct {
	db *gorm.DB
}

// NewChatRepository 创建聊天仓库实例
func NewChatRepository(db *gorm.DB) ChatRepository {
	return &chatRepository{db: db}
}

// === Room 相关 ===

func (r *chatRepository) CreateRoom(ctx context.Context, room *Room) error {
	return r.db.WithContext(ctx).Create(room).Error
}

func (r *chatRepository) GetRoom(ctx context.Context, roomID string) (*Room, error) {
	var room Room
	if err := r.db.WithContext(ctx).First(&room, "id = ?", roomID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &room, nil
}

func (r *chatRepository) UpdateRoom(ctx context.Context, room *Room) error {
	return r.db.WithContext(ctx).Save(room).Error
}

func (r *chatRepository) DeleteRoom(ctx context.Context, roomID string) error {
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		// 删除已读回执
		if err := tx.Delete(&ReadReceipt{}, "room_id = ?", roomID).Error; err != nil {
			return err
		}
		// 删除消息
		if err := tx.Delete(&Message{}, "room_id = ?", roomID).Error; err != nil {
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

func (r *chatRepository) GetUserRooms(ctx context.Context, userID string) ([]*Room, error) {
	var rooms []*Room
	err := r.db.WithContext(ctx).
		Joins("JOIN room_members ON room_members.room_id = rooms.id").
		Where("room_members.user_id = ?", userID).
		Order("rooms.updated_at DESC").
		Find(&rooms).Error
	return rooms, err
}

// === Member 相关 ===

func (r *chatRepository) AddMember(ctx context.Context, member *RoomMember) error {
	return r.db.WithContext(ctx).Create(member).Error
}

func (r *chatRepository) GetMember(ctx context.Context, roomID, userID string) (*RoomMember, error) {
	var member RoomMember
	if err := r.db.WithContext(ctx).First(&member, "room_id = ? AND user_id = ?", roomID, userID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &member, nil
}

func (r *chatRepository) UpdateMember(ctx context.Context, member *RoomMember) error {
	return r.db.WithContext(ctx).Save(member).Error
}

func (r *chatRepository) RemoveMember(ctx context.Context, roomID, userID string) error {
	return r.db.WithContext(ctx).Delete(&RoomMember{}, "room_id = ? AND user_id = ?", roomID, userID).Error
}

func (r *chatRepository) GetRoomMembers(ctx context.Context, roomID string) ([]*RoomMember, error) {
	var members []*RoomMember
	err := r.db.WithContext(ctx).Preload("User").Where("room_id = ?", roomID).Find(&members).Error
	return members, err
}

func (r *chatRepository) IsMember(ctx context.Context, roomID, userID string) (bool, error) {
	var count int64
	err := r.db.WithContext(ctx).Model(&RoomMember{}).Where("room_id = ? AND user_id = ?", roomID, userID).Count(&count).Error
	return count > 0, err
}

// === Message 相关 ===

func (r *chatRepository) CreateMessage(ctx context.Context, message *Message) error {
	return r.db.WithContext(ctx).Create(message).Error
}

func (r *chatRepository) GetMessage(ctx context.Context, messageID string) (*Message, error) {
	var message Message
	if err := r.db.WithContext(ctx).Preload("Sender").First(&message, "id = ?", messageID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &message, nil
}

func (r *chatRepository) GetMessages(ctx context.Context, roomID string, limit int, beforeID string) ([]*Message, error) {
	var messages []*Message
	query := r.db.WithContext(ctx).Preload("Sender").Where("room_id = ? AND is_deleted = ?", roomID, false)

	if beforeID != "" {
		var beforeMsg Message
		if err := r.db.WithContext(ctx).Select("created_at").First(&beforeMsg, "id = ?", beforeID).Error; err == nil {
			query = query.Where("created_at < ?", beforeMsg.CreatedAt)
		}
	}

	err := query.Order("created_at DESC").Limit(limit).Find(&messages).Error
	return messages, err
}

func (r *chatRepository) UpdateMessage(ctx context.Context, message *Message) error {
	return r.db.WithContext(ctx).Save(message).Error
}

func (r *chatRepository) DeleteMessage(ctx context.Context, messageID string) error {
	return r.db.WithContext(ctx).Model(&Message{}).Where("id = ?", messageID).Update("is_deleted", true).Error
}

func (r *chatRepository) GetUnreadCount(ctx context.Context, roomID, userID string) (int64, error) {
	var receipt ReadReceipt
	var count int64

	if err := r.db.WithContext(ctx).First(&receipt, "room_id = ? AND user_id = ?", roomID, userID).Error; err != nil {
		// 没有已读记录，返回所有消息数
		if err := r.db.WithContext(ctx).Model(&Message{}).Where("room_id = ? AND is_deleted = ?", roomID, false).Count(&count).Error; err != nil {
			return 0, err
		}
		return count, nil
	}

	// 统计已读之后的消息数
	if err := r.db.WithContext(ctx).Model(&Message{}).
		Where("room_id = ? AND is_deleted = ? AND created_at > ?", roomID, false, receipt.ReadAt).
		Count(&count).Error; err != nil {
		return 0, err
	}
	return count, nil
}

// === ReadReceipt 相关 ===

func (r *chatRepository) UpdateReadReceipt(ctx context.Context, receipt *ReadReceipt) error {
	return r.db.WithContext(ctx).Save(receipt).Error
}

func (r *chatRepository) GetReadReceipt(ctx context.Context, roomID, userID string) (*ReadReceipt, error) {
	var receipt ReadReceipt
	if err := r.db.WithContext(ctx).First(&receipt, "room_id = ? AND user_id = ?", roomID, userID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &receipt, nil
}

// GetRoomReadReceipts 获取房间内所有用户的已读回执
func (r *chatRepository) GetRoomReadReceipts(ctx context.Context, roomID string) ([]*ReadReceipt, error) {
	var receipts []*ReadReceipt
	err := r.db.WithContext(ctx).Where("room_id = ?", roomID).Find(&receipts).Error
	return receipts, err
}

// GetPublicRooms 获取公开房间列表
func (r *chatRepository) GetPublicRooms(ctx context.Context, query string) ([]*Room, error) {
	var rooms []*Room
	q := r.db.WithContext(ctx).Where("type IN ?", []RoomType{RoomTypeGroup, RoomTypeChannel})
	if query != "" {
		q = q.Where("name LIKE ?", "%"+query+"%")
	}
	err := q.Order("created_at DESC").Limit(50).Find(&rooms).Error
	return rooms, err
}
