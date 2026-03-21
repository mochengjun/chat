package service

import (
	"context"
	"errors"
	"sync"
	"time"

	"sec-chat/auth-service/internal/repository"

	"github.com/google/uuid"
)

// UserPresenceTracker 用户在线状态追踪接口
type UserPresenceTracker interface {
	// IsUserOnline 检查用户是否在线
	IsUserOnline(userID string) bool
	// GetOnlineUserIDs 批量查询在线用户，返回在线的用户ID集合
	GetOnlineUserIDs(userIDs []string) map[string]bool
}

var (
	ErrRoomNotFound     = errors.New("room not found")
	ErrNotRoomMember    = errors.New("not a member of this room")
	ErrNoPermission     = errors.New("no permission for this action")
	ErrMessageNotFound  = errors.New("message not found")
	ErrCannotLeaveOwner = errors.New("owner cannot leave room")
	ErrAlreadyMember    = errors.New("already a member")
)

// RoomResponse 房间响应
type RoomResponse struct {
	ID             string              `json:"id"`
	Name           string              `json:"name"`
	Description    string              `json:"description,omitempty"`
	AvatarURL      string              `json:"avatar_url,omitempty"`
	Type           repository.RoomType `json:"type"`
	CreatorID      string              `json:"creator_id"`
	RetentionHours *int                `json:"retention_hours,omitempty"`
	UnreadCount    int64               `json:"unread_count"`
	LastMessage    *MessageResponse    `json:"last_message,omitempty"`
	Members        []*MemberResponse   `json:"members,omitempty"`
	IsMuted        bool                `json:"is_muted"`
	IsPinned       bool                `json:"is_pinned"`
	IsMember       bool                `json:"is_member,omitempty"`
	MemberCount    int                 `json:"member_count,omitempty"`
	CreatedAt      time.Time           `json:"created_at"`
	UpdatedAt      time.Time           `json:"updated_at"`
}

// MemberResponse 成员响应
type MemberResponse struct {
	UserID      string                `json:"user_id"`
	DisplayName string                `json:"display_name"`
	AvatarURL   string                `json:"avatar_url,omitempty"`
	Role        repository.MemberRole `json:"role"`
	JoinedAt    time.Time             `json:"joined_at"`
	IsOnline    bool                  `json:"is_online"`
}

// MessageResponse 消息响应
type MessageResponse struct {
	ID              string                   `json:"id"`
	RoomID          string                   `json:"room_id"`
	SenderID        string                   `json:"sender_id"`
	SenderName      string                   `json:"sender_name"`
	SenderAvatar    string                   `json:"sender_avatar,omitempty"`
	Content         string                   `json:"content"`
	Type            repository.MessageType   `json:"type"`
	Status          repository.MessageStatus `json:"status"`
	MediaURL        string                   `json:"media_url,omitempty"`
	ThumbnailURL    string                   `json:"thumbnail_url,omitempty"`
	MediaSize       *int64                   `json:"media_size,omitempty"`
	MimeType        string                   `json:"mime_type,omitempty"`
	ReplyToID       string                   `json:"reply_to_id,omitempty"`
	IsDeleted       bool                     `json:"is_deleted"`
	CreatedAt       time.Time                `json:"created_at"`
	EditedAt        *time.Time               `json:"edited_at,omitempty"`
	AutoDeleteAfter *int                     `json:"auto_delete_after,omitempty"` // 撤回时间（分钟）
	AutoDeleteAt    *time.Time               `json:"auto_delete_at,omitempty"`    // 消息自动删除的绝对时间
}

// CreateRoomRequest 创建房间请求
type CreateRoomRequest struct {
	Name           string              `json:"name" binding:"required"`
	Description    string              `json:"description"`
	Type           repository.RoomType `json:"type"`
	MemberIDs      []string            `json:"member_ids"`
	RetentionHours *int                `json:"retention_hours"`
}

// SendMessageRequest 发送消息请求
type SendMessageRequest struct {
	Content         string                 `json:"content" binding:"required"`
	Type            repository.MessageType `json:"type"`
	ReplyToID       string                 `json:"reply_to_id"`
	AutoDeleteAfter *int                   `json:"auto_delete_after"` // 撤回时间（分钟）：1, 5, 60, 1440
	MediaURL        string                 `json:"media_url"`
	ThumbnailURL    string                 `json:"thumbnail_url"`
	MediaSize       *int64                 `json:"media_size"`
	MimeType        string                 `json:"mime_type"`
}

// UserSearchResult 用户搜索结果
type UserSearchResult struct {
	UserID      string `json:"user_id"`
	Username    string `json:"username"`
	DisplayName string `json:"display_name"`
	AvatarURL   string `json:"avatar_url,omitempty"`
	Email       string `json:"email,omitempty"`
	IsActive    bool   `json:"is_active"`
}

// UserOnlineStatus 用户在线状态响应
type UserOnlineStatus struct {
	UserID     string     `json:"user_id"`
	IsOnline   bool       `json:"is_online"`
	LastSeenAt *time.Time `json:"last_seen_at,omitempty"`
}

// ChatService 聊天服务接口
type ChatService interface {
	// Room
	CreateRoom(ctx context.Context, userID string, req *CreateRoomRequest) (*RoomResponse, error)
	GetRoom(ctx context.Context, userID, roomID string) (*RoomResponse, error)
	GetUserRooms(ctx context.Context, userID string) ([]*RoomResponse, error)
	GetPublicRooms(ctx context.Context, userID string, query string) ([]*RoomResponse, error)
	UpdateRoom(ctx context.Context, userID, roomID string, name, description string, retentionHours *int) (*RoomResponse, error)
	LeaveRoom(ctx context.Context, userID, roomID string) error
	MuteRoom(ctx context.Context, userID, roomID string, muted bool) error
	PinRoom(ctx context.Context, userID, roomID string, pinned bool) error

	// Member
	AddMembers(ctx context.Context, userID, roomID string, memberIDs []string) error
	RemoveMember(ctx context.Context, userID, roomID, targetUserID string) error
	UpdateMemberRole(ctx context.Context, userID, roomID, targetUserID string, role repository.MemberRole) error
	GetRoomMembers(ctx context.Context, userID, roomID string) ([]*MemberResponse, error)

	// User
	SearchUsers(ctx context.Context, query string, limit int) ([]*UserSearchResult, error)

	// Online Status
	SetPresenceTracker(tracker UserPresenceTracker)
	SetUserOnline(userID string)
	SetUserOffline(userID string)
	GetUserOnlineStatus(userID string) *UserOnlineStatus
	GetBatchOnlineStatus(userIDs []string) []*UserOnlineStatus

	// Message
	SendMessage(ctx context.Context, userID, roomID string, req *SendMessageRequest) (*MessageResponse, error)
	GetMessages(ctx context.Context, userID, roomID string, limit int, beforeID string) ([]*MessageResponse, error)
	DeleteMessage(ctx context.Context, userID, roomID, messageID string) error
	DeleteMessageInternal(ctx context.Context, messageID string) error // 内部删除，不验证权限
	MarkAsRead(ctx context.Context, userID, roomID string) error
}

// chatService 聊天服务实现
type chatService struct {
	chatRepo        repository.ChatRepository
	userRepo        repository.UserRepository
	presenceTracker UserPresenceTracker
	lastSeenMap     map[string]time.Time // userID -> last seen time
	lastSeenMu      sync.RWMutex
}

// NewChatService 创建聊天服务实例
func NewChatService(chatRepo repository.ChatRepository, userRepo repository.UserRepository) ChatService {
	return &chatService{
		chatRepo:    chatRepo,
		userRepo:    userRepo,
		lastSeenMap: make(map[string]time.Time),
	}
}

// === Room 相关 ===

func (s *chatService) CreateRoom(ctx context.Context, userID string, req *CreateRoomRequest) (*RoomResponse, error) {
	roomID := uuid.New().String()
	now := time.Now()

	roomType := req.Type
	if roomType == "" {
		roomType = repository.RoomTypeGroup
	}

	room := &repository.Room{
		ID:             roomID,
		Name:           req.Name,
		Description:    req.Description,
		Type:           roomType,
		CreatorID:      userID,
		RetentionHours: req.RetentionHours,
		CreatedAt:      now,
		UpdatedAt:      now,
	}

	if err := s.chatRepo.CreateRoom(ctx, room); err != nil {
		return nil, err
	}

	// 添加创建者为 Owner
	ownerMember := &repository.RoomMember{
		ID:        uuid.New().String(),
		RoomID:    roomID,
		UserID:    userID,
		Role:      repository.MemberRoleOwner,
		JoinedAt:  now,
		UpdatedAt: now,
	}
	if err := s.chatRepo.AddMember(ctx, ownerMember); err != nil {
		return nil, err
	}

	// 添加其他成员
	for _, memberID := range req.MemberIDs {
		if memberID == userID {
			continue
		}
		member := &repository.RoomMember{
			ID:        uuid.New().String(),
			RoomID:    roomID,
			UserID:    memberID,
			Role:      repository.MemberRoleMember,
			JoinedAt:  now,
			UpdatedAt: now,
		}
		s.chatRepo.AddMember(ctx, member)
	}

	return s.buildRoomResponse(ctx, room, userID)
}

func (s *chatService) GetRoom(ctx context.Context, userID, roomID string) (*RoomResponse, error) {
	isMember, err := s.chatRepo.IsMember(ctx, roomID, userID)
	if err != nil {
		return nil, err
	}
	if !isMember {
		return nil, ErrNotRoomMember
	}

	room, err := s.chatRepo.GetRoom(ctx, roomID)
	if err != nil {
		return nil, ErrRoomNotFound
	}

	return s.buildRoomResponse(ctx, room, userID)
}

func (s *chatService) GetUserRooms(ctx context.Context, userID string) ([]*RoomResponse, error) {
	rooms, err := s.chatRepo.GetUserRooms(ctx, userID)
	if err != nil {
		return nil, err
	}

	responses := make([]*RoomResponse, 0, len(rooms))
	for _, room := range rooms {
		resp, err := s.buildRoomResponse(ctx, room, userID)
		if err == nil {
			responses = append(responses, resp)
		}
	}
	return responses, nil
}

func (s *chatService) UpdateRoom(ctx context.Context, userID, roomID string, name, description string, retentionHours *int) (*RoomResponse, error) {
	if err := s.checkPermission(ctx, roomID, userID, repository.MemberRoleAdmin); err != nil {
		return nil, err
	}

	room, err := s.chatRepo.GetRoom(ctx, roomID)
	if err != nil {
		return nil, ErrRoomNotFound
	}

	if name != "" {
		room.Name = name
	}
	if description != "" {
		room.Description = description
	}
	if retentionHours != nil {
		room.RetentionHours = retentionHours
	}
	room.UpdatedAt = time.Now()

	if err := s.chatRepo.UpdateRoom(ctx, room); err != nil {
		return nil, err
	}

	return s.buildRoomResponse(ctx, room, userID)
}

func (s *chatService) LeaveRoom(ctx context.Context, userID, roomID string) error {
	member, err := s.chatRepo.GetMember(ctx, roomID, userID)
	if err != nil {
		return ErrNotRoomMember
	}

	if member == nil {
		return ErrNotRoomMember
	}

	if member.Role == repository.MemberRoleOwner {
		return ErrCannotLeaveOwner
	}

	return s.chatRepo.RemoveMember(ctx, roomID, userID)
}

func (s *chatService) MuteRoom(ctx context.Context, userID, roomID string, muted bool) error {
	member, err := s.chatRepo.GetMember(ctx, roomID, userID)
	if err != nil {
		return ErrNotRoomMember
	}

	if member == nil {
		return ErrNotRoomMember
	}

	member.IsMuted = muted
	member.UpdatedAt = time.Now()
	return s.chatRepo.UpdateMember(ctx, member)
}

func (s *chatService) PinRoom(ctx context.Context, userID, roomID string, pinned bool) error {
	member, err := s.chatRepo.GetMember(ctx, roomID, userID)
	if err != nil {
		return ErrNotRoomMember
	}

	if member == nil {
		return ErrNotRoomMember
	}

	member.IsPinned = pinned
	member.UpdatedAt = time.Now()
	return s.chatRepo.UpdateMember(ctx, member)
}

// === Member 相关 ===

func (s *chatService) AddMembers(ctx context.Context, userID, roomID string, memberIDs []string) error {
	if err := s.checkPermission(ctx, roomID, userID, repository.MemberRoleAdmin); err != nil {
		return err
	}

	now := time.Now()
	for _, memberID := range memberIDs {
		exists, _ := s.chatRepo.IsMember(ctx, roomID, memberID)
		if exists {
			continue
		}

		member := &repository.RoomMember{
			ID:        uuid.New().String(),
			RoomID:    roomID,
			UserID:    memberID,
			Role:      repository.MemberRoleMember,
			JoinedAt:  now,
			UpdatedAt: now,
		}
		s.chatRepo.AddMember(ctx, member)
	}
	return nil
}

func (s *chatService) RemoveMember(ctx context.Context, userID, roomID, targetUserID string) error {
	if err := s.checkPermission(ctx, roomID, userID, repository.MemberRoleModerator); err != nil {
		return err
	}

	targetMember, err := s.chatRepo.GetMember(ctx, roomID, targetUserID)
	if err != nil {
		return ErrNotRoomMember
	}

	if targetMember == nil {
		return ErrNotRoomMember
	}

	// 不能移除 Owner
	if targetMember.Role == repository.MemberRoleOwner {
		return ErrNoPermission
	}

	// 检查是否有权限移除目标成员
	actorMember, _ := s.chatRepo.GetMember(ctx, roomID, userID)
	if actorMember == nil || !canManageRole(actorMember.Role, targetMember.Role) {
		return ErrNoPermission
	}

	return s.chatRepo.RemoveMember(ctx, roomID, targetUserID)
}

func (s *chatService) UpdateMemberRole(ctx context.Context, userID, roomID, targetUserID string, role repository.MemberRole) error {
	if err := s.checkPermission(ctx, roomID, userID, repository.MemberRoleAdmin); err != nil {
		return err
	}

	actorMember, _ := s.chatRepo.GetMember(ctx, roomID, userID)
	targetMember, err := s.chatRepo.GetMember(ctx, roomID, targetUserID)
	if err != nil {
		return ErrNotRoomMember
	}

	if targetMember == nil {
		return ErrNotRoomMember
	}

	// 不能修改 Owner 角色
	if targetMember.Role == repository.MemberRoleOwner || role == repository.MemberRoleOwner {
		return ErrNoPermission
	}

	// 检查是否有权限设置目标角色
	if actorMember == nil || !canSetRole(actorMember.Role, role) {
		return ErrNoPermission
	}

	targetMember.Role = role
	targetMember.UpdatedAt = time.Now()
	return s.chatRepo.UpdateMember(ctx, targetMember)
}

func (s *chatService) GetRoomMembers(ctx context.Context, userID, roomID string) ([]*MemberResponse, error) {
	isMember, err := s.chatRepo.IsMember(ctx, roomID, userID)
	if err != nil || !isMember {
		return nil, ErrNotRoomMember
	}

	members, err := s.chatRepo.GetRoomMembers(ctx, roomID)
	if err != nil {
		return nil, err
	}

	responses := make([]*MemberResponse, 0, len(members))
	// 批量获取在线状态
	memberIDs := make([]string, 0, len(members))
	for _, m := range members {
		memberIDs = append(memberIDs, m.UserID)
	}
	onlineMap := s.getOnlineMap(memberIDs)

	for _, m := range members {
		displayName := ""
		avatarURL := ""
		if m.User != nil {
			if m.User.DisplayName != nil {
				displayName = *m.User.DisplayName
			} else {
				displayName = m.User.Username
			}
			if m.User.AvatarURL != nil {
				avatarURL = *m.User.AvatarURL
			}
		}

		responses = append(responses, &MemberResponse{
			UserID:      m.UserID,
			DisplayName: displayName,
			AvatarURL:   avatarURL,
			Role:        m.Role,
			JoinedAt:    m.JoinedAt,
			IsOnline:    onlineMap[m.UserID],
		})
	}
	return responses, nil
}

// === Message 相关 ===

func (s *chatService) SendMessage(ctx context.Context, userID, roomID string, req *SendMessageRequest) (*MessageResponse, error) {
	isMember, err := s.chatRepo.IsMember(ctx, roomID, userID)
	if err != nil || !isMember {
		return nil, ErrNotRoomMember
	}

	msgType := req.Type
	if msgType == "" {
		msgType = repository.MessageTypeText
	}

	now := time.Now()

	// 计算自动删除时间
	var autoDeleteAfter *int
	var autoDeleteAt *time.Time
	if req.AutoDeleteAfter != nil {
		// 验证允许的撤回时间值：1, 5, 60, 1440 分钟
		allowedValues := map[int]bool{1: true, 5: true, 60: true, 1440: true}
		if allowedValues[*req.AutoDeleteAfter] {
			autoDeleteAfter = req.AutoDeleteAfter
			deleteTime := now.Add(time.Duration(*req.AutoDeleteAfter) * time.Minute)
			autoDeleteAt = &deleteTime
		}
	}

	message := &repository.Message{
		ID:              uuid.New().String(),
		RoomID:          roomID,
		SenderID:        userID,
		Content:         req.Content,
		Type:            msgType,
		Status:          repository.MessageStatusSent,
		MediaURL:        req.MediaURL,
		ThumbnailURL:    req.ThumbnailURL,
		MediaSize:       req.MediaSize,
		MimeType:        req.MimeType,
		ReplyToID:       req.ReplyToID,
		CreatedAt:       now,
		AutoDeleteAfter: autoDeleteAfter,
		AutoDeleteAt:    autoDeleteAt,
	}

	if err := s.chatRepo.CreateMessage(ctx, message); err != nil {
		return nil, err
	}

	// 获取发送者信息
	user, _ := s.userRepo.GetByID(ctx, userID)
	senderName := ""
	senderAvatar := ""
	if user != nil {
		if user.DisplayName != nil {
			senderName = *user.DisplayName
		} else {
			senderName = user.Username
		}
		if user.AvatarURL != nil {
			senderAvatar = *user.AvatarURL
		}
	}

	return &MessageResponse{
		ID:              message.ID,
		RoomID:          message.RoomID,
		SenderID:        message.SenderID,
		SenderName:      senderName,
		SenderAvatar:    senderAvatar,
		Content:         message.Content,
		Type:            message.Type,
		Status:          message.Status,
		MediaURL:        message.MediaURL,
		ThumbnailURL:    message.ThumbnailURL,
		MediaSize:       message.MediaSize,
		MimeType:        message.MimeType,
		ReplyToID:       message.ReplyToID,
		IsDeleted:       message.IsDeleted,
		CreatedAt:       message.CreatedAt,
		AutoDeleteAfter: message.AutoDeleteAfter,
		AutoDeleteAt:    message.AutoDeleteAt,
	}, nil
}

func (s *chatService) GetMessages(ctx context.Context, userID, roomID string, limit int, beforeID string) ([]*MessageResponse, error) {
	isMember, err := s.chatRepo.IsMember(ctx, roomID, userID)
	if err != nil || !isMember {
		return nil, ErrNotRoomMember
	}

	if limit <= 0 || limit > 100 {
		limit = 50
	}

	messages, err := s.chatRepo.GetMessages(ctx, roomID, limit, beforeID)
	if err != nil {
		return nil, err
	}

	// 获取房间内所有用户的已读回执，用于计算消息状态
	readReceipts, _ := s.chatRepo.GetRoomReadReceipts(ctx, roomID)
	// 构建其他用户的已读时间映射（排除当前用户）
	otherUsersReadAt := make(map[string]time.Time)
	for _, r := range readReceipts {
		if r.UserID != userID {
			otherUsersReadAt[r.UserID] = r.ReadAt
		}
	}

	responses := make([]*MessageResponse, 0, len(messages))
	for _, msg := range messages {
		senderName := ""
		senderAvatar := ""
		if msg.Sender != nil {
			if msg.Sender.DisplayName != nil {
				senderName = *msg.Sender.DisplayName
			} else {
				senderName = msg.Sender.Username
			}
			if msg.Sender.AvatarURL != nil {
				senderAvatar = *msg.Sender.AvatarURL
			}
		}

		// 计算消息状态：如果是当前用户发送的消息，检查其他用户是否已读
		status := msg.Status
		if msg.SenderID == userID && status == repository.MessageStatusSent {
			// 检查是否有其他用户已读这条消息
			for _, readAt := range otherUsersReadAt {
				// 如果对方的已读时间 >= 消息创建时间，则消息已被阅读
				if !readAt.Before(msg.CreatedAt) {
					status = repository.MessageStatusRead
					break
				}
			}
		}

		responses = append(responses, &MessageResponse{
			ID:              msg.ID,
			RoomID:          msg.RoomID,
			SenderID:        msg.SenderID,
			SenderName:      senderName,
			SenderAvatar:    senderAvatar,
			Content:         msg.Content,
			Type:            msg.Type,
			Status:          status,
			MediaURL:        msg.MediaURL,
			ThumbnailURL:    msg.ThumbnailURL,
			MediaSize:       msg.MediaSize,
			MimeType:        msg.MimeType,
			ReplyToID:       msg.ReplyToID,
			IsDeleted:       msg.IsDeleted,
			CreatedAt:       msg.CreatedAt,
			EditedAt:        msg.EditedAt,
			AutoDeleteAfter: msg.AutoDeleteAfter,
			AutoDeleteAt:    msg.AutoDeleteAt,
		})
	}
	return responses, nil
}

func (s *chatService) DeleteMessage(ctx context.Context, userID, roomID, messageID string) error {
	isMember, err := s.chatRepo.IsMember(ctx, roomID, userID)
	if err != nil || !isMember {
		return ErrNotRoomMember
	}

	message, err := s.chatRepo.GetMessage(ctx, messageID)
	if err != nil {
		return ErrMessageNotFound
	}

	if message == nil {
		return ErrMessageNotFound
	}

	// 只有发送者或管理员可以删除
	if message.SenderID != userID {
		if err := s.checkPermission(ctx, roomID, userID, repository.MemberRoleModerator); err != nil {
			return ErrNoPermission
		}
	}

	return s.chatRepo.DeleteMessage(ctx, messageID)
}

// DeleteMessageInternal 内部删除消息（不验证权限，供 cleanup-service 调用）
func (s *chatService) DeleteMessageInternal(ctx context.Context, messageID string) error {
	return s.chatRepo.DeleteMessage(ctx, messageID)
}

func (s *chatService) MarkAsRead(ctx context.Context, userID, roomID string) error {
	isMember, err := s.chatRepo.IsMember(ctx, roomID, userID)
	if err != nil || !isMember {
		return ErrNotRoomMember
	}

	receipt := &repository.ReadReceipt{
		ID:     uuid.New().String(),
		RoomID: roomID,
		UserID: userID,
		ReadAt: time.Now(),
	}

	return s.chatRepo.UpdateReadReceipt(ctx, receipt)
}

// === Helper 函数 ===

func (s *chatService) checkPermission(ctx context.Context, roomID, userID string, minRole repository.MemberRole) error {
	member, err := s.chatRepo.GetMember(ctx, roomID, userID)
	if err != nil {
		return ErrNotRoomMember
	}

	if member == nil {
		return ErrNotRoomMember
	}

	roleLevel := map[repository.MemberRole]int{
		repository.MemberRoleOwner:     4,
		repository.MemberRoleAdmin:     3,
		repository.MemberRoleModerator: 2,
		repository.MemberRoleMember:    1,
	}

	if roleLevel[member.Role] < roleLevel[minRole] {
		return ErrNoPermission
	}
	return nil
}

func canManageRole(actorRole, targetRole repository.MemberRole) bool {
	roleLevel := map[repository.MemberRole]int{
		repository.MemberRoleOwner:     4,
		repository.MemberRoleAdmin:     3,
		repository.MemberRoleModerator: 2,
		repository.MemberRoleMember:    1,
	}
	return roleLevel[actorRole] > roleLevel[targetRole]
}

func canSetRole(actorRole, targetRole repository.MemberRole) bool {
	roleLevel := map[repository.MemberRole]int{
		repository.MemberRoleOwner:     4,
		repository.MemberRoleAdmin:     3,
		repository.MemberRoleModerator: 2,
		repository.MemberRoleMember:    1,
	}
	return roleLevel[actorRole] > roleLevel[targetRole]
}

func (s *chatService) buildRoomResponse(ctx context.Context, room *repository.Room, userID string) (*RoomResponse, error) {
	// 获取未读数
	unreadCount, _ := s.chatRepo.GetUnreadCount(ctx, room.ID, userID)

	// 获取成员信息
	member, _ := s.chatRepo.GetMember(ctx, room.ID, userID)
	isMuted := false
	isPinned := false
	if member != nil {
		isMuted = member.IsMuted
		isPinned = member.IsPinned
	}

	// 获取最后一条消息
	messages, _ := s.chatRepo.GetMessages(ctx, room.ID, 1, "")
	var lastMessage *MessageResponse
	if len(messages) > 0 {
		msg := messages[0]
		senderName := ""
		if msg.Sender != nil {
			if msg.Sender.DisplayName != nil {
				senderName = *msg.Sender.DisplayName
			} else {
				senderName = msg.Sender.Username
			}
		}
		lastMessage = &MessageResponse{
			ID:         msg.ID,
			RoomID:     msg.RoomID,
			SenderID:   msg.SenderID,
			SenderName: senderName,
			Content:    msg.Content,
			Type:       msg.Type,
			CreatedAt:  msg.CreatedAt,
		}
	}

	// 获取房间所有成员
	members, _ := s.chatRepo.GetRoomMembers(ctx, room.ID)
	memberResponses := make([]*MemberResponse, 0, len(members))
	// 批量获取在线状态
	memberIDs := make([]string, 0, len(members))
	for _, m := range members {
		memberIDs = append(memberIDs, m.UserID)
	}
	onlineMap := s.getOnlineMap(memberIDs)

	for _, m := range members {
		displayName := m.UserID // 默认使用UserID
		avatarURL := ""
		if m.User != nil {
			displayName = m.User.Username
			if m.User.DisplayName != nil {
				displayName = *m.User.DisplayName
			}
			if m.User.AvatarURL != nil {
				avatarURL = *m.User.AvatarURL
			}
		}
		memberResponses = append(memberResponses, &MemberResponse{
			UserID:      m.UserID,
			DisplayName: displayName,
			AvatarURL:   avatarURL,
			Role:        m.Role,
			JoinedAt:    m.JoinedAt,
			IsOnline:    onlineMap[m.UserID],
		})
	}

	return &RoomResponse{
		ID:             room.ID,
		Name:           room.Name,
		Description:    room.Description,
		AvatarURL:      room.AvatarURL,
		Type:           room.Type,
		CreatorID:      room.CreatorID,
		RetentionHours: room.RetentionHours,
		UnreadCount:    unreadCount,
		LastMessage:    lastMessage,
		Members:        memberResponses,
		IsMuted:        isMuted,
		IsPinned:       isPinned,
		CreatedAt:      room.CreatedAt,
		UpdatedAt:      room.UpdatedAt,
	}, nil
}

// === User 搜索 ===

func (s *chatService) SearchUsers(ctx context.Context, query string, limit int) ([]*UserSearchResult, error) {
	if limit <= 0 || limit > 50 {
		limit = 20
	}

	users, err := s.userRepo.SearchUsers(ctx, query, limit)
	if err != nil {
		return nil, err
	}

	results := make([]*UserSearchResult, 0, len(users))
	for _, user := range users {
		displayName := user.Username
		if user.DisplayName != nil {
			displayName = *user.DisplayName
		}
		avatarURL := ""
		if user.AvatarURL != nil {
			avatarURL = *user.AvatarURL
		}
		email := ""
		if user.Email != nil {
			email = *user.Email
		}

		results = append(results, &UserSearchResult{
			UserID:      user.UserID,
			Username:    user.Username,
			DisplayName: displayName,
			AvatarURL:   avatarURL,
			Email:       email,
			IsActive:    user.IsActive,
		})
	}
	return results, nil
}

// === Online Status 在线状态相关 ===

// SetPresenceTracker 设置在线状态追踪器（用于延迟注入，避免循环依赖）
func (s *chatService) SetPresenceTracker(tracker UserPresenceTracker) {
	s.presenceTracker = tracker
}

// SetUserOnline 标记用户上线
func (s *chatService) SetUserOnline(userID string) {
	s.lastSeenMu.Lock()
	s.lastSeenMap[userID] = time.Now()
	s.lastSeenMu.Unlock()
}

// SetUserOffline 标记用户下线，记录最后在线时间
func (s *chatService) SetUserOffline(userID string) {
	s.lastSeenMu.Lock()
	s.lastSeenMap[userID] = time.Now()
	s.lastSeenMu.Unlock()
}

// GetUserOnlineStatus 获取单个用户在线状态
func (s *chatService) GetUserOnlineStatus(userID string) *UserOnlineStatus {
	isOnline := false
	if s.presenceTracker != nil {
		isOnline = s.presenceTracker.IsUserOnline(userID)
	}

	status := &UserOnlineStatus{
		UserID:   userID,
		IsOnline: isOnline,
	}

	if !isOnline {
		s.lastSeenMu.RLock()
		if lastSeen, ok := s.lastSeenMap[userID]; ok {
			status.LastSeenAt = &lastSeen
		}
		s.lastSeenMu.RUnlock()
	}

	return status
}

// GetBatchOnlineStatus 批量获取用户在线状态
func (s *chatService) GetBatchOnlineStatus(userIDs []string) []*UserOnlineStatus {
	onlineMap := s.getOnlineMap(userIDs)

	statuses := make([]*UserOnlineStatus, 0, len(userIDs))
	s.lastSeenMu.RLock()
	defer s.lastSeenMu.RUnlock()

	for _, uid := range userIDs {
		status := &UserOnlineStatus{
			UserID:   uid,
			IsOnline: onlineMap[uid],
		}
		if !onlineMap[uid] {
			if lastSeen, ok := s.lastSeenMap[uid]; ok {
				status.LastSeenAt = &lastSeen
			}
		}
		statuses = append(statuses, status)
	}
	return statuses
}

// getOnlineMap 内部辅助方法：批量获取在线状态map
func (s *chatService) getOnlineMap(userIDs []string) map[string]bool {
	if s.presenceTracker != nil {
		return s.presenceTracker.GetOnlineUserIDs(userIDs)
	}
	// 没有 tracker 时全部返回 false
	result := make(map[string]bool, len(userIDs))
	for _, uid := range userIDs {
		result[uid] = false
	}
	return result
}

// GetPublicRooms 获取公开房间列表
func (s *chatService) GetPublicRooms(ctx context.Context, userID string, query string) ([]*RoomResponse, error) {
	rooms, err := s.chatRepo.GetPublicRooms(ctx, query)
	if err != nil {
		return nil, err
	}

	responses := make([]*RoomResponse, 0, len(rooms))
	for _, room := range rooms {
		// 对于公开房间列表，不需要严格检查用户是否是成员
		// 因为我们只关心房间是否公开可加入
		isMember := false
		if userID != "" {
			isMember, _ = s.chatRepo.IsMember(ctx, room.ID, userID)
		}

		members, _ := s.chatRepo.GetRoomMembers(ctx, room.ID)
		memberCount := len(members)

		responses = append(responses, &RoomResponse{
			ID:          room.ID,
			Name:        room.Name,
			Description: room.Description,
			Type:        room.Type,
			CreatorID:   room.CreatorID,
			IsMember:    isMember,
			MemberCount: memberCount,
			CreatedAt:   room.CreatedAt,
			UpdatedAt:   room.UpdatedAt,
		})
	}
	return responses, nil
}
