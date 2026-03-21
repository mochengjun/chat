package service

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"sec-chat/auth-service/internal/config"
	"sec-chat/auth-service/internal/repository"

	"github.com/google/uuid"
	"golang.org/x/oauth2"
)

var (
	ErrOAuthNotConfigured   = errors.New("oauth not configured")
	ErrOAuthStateInvalid    = errors.New("invalid oauth state")
	ErrOAuthStateExpired    = errors.New("oauth state expired")
	ErrOAuthCodeInvalid     = errors.New("invalid oauth authorization code")
	ErrOAuthEmailNotAllowed = errors.New("email domain not allowed")
	ErrOAuthUserExists      = errors.New("user already exists with different auth method")
	ErrOAuthAccountLinked   = errors.New("oauth account already linked to another user")
)

// OAuthUserInfo OAuth用户信息
type OAuthUserInfo struct {
	ID            string `json:"id"`
	Email         string `json:"email"`
	VerifiedEmail bool   `json:"verified_email"`
	Name          string `json:"name"`
	GivenName     string `json:"given_name"`
	FamilyName    string `json:"family_name"`
	Picture       string `json:"picture"`
	Locale        string `json:"locale"`
}

// OAuthService OAuth服务接口
type OAuthService interface {
	// GetAuthURL 获取OAuth授权URL
	GetAuthURL(state string) string
	
	// HandleCallback 处理OAuth回调
	HandleCallback(ctx context.Context, code, state string) (*TokenResponse, error)
	
	// ValidateState 验证State参数
	ValidateState(state string) bool
	
	// StoreState 存储State参数
	StoreState(state string) error
	
	// GetUserInfo 获取OAuth用户信息
	GetUserInfo(accessToken string) (*OAuthUserInfo, error)
	
	// LinkOAuthAccount 关联OAuth账户到现有用户
	LinkOAuthAccount(ctx context.Context, userID string, userInfo *OAuthUserInfo, token *oauth2.Token) error
	
	// UnlinkOAuthAccount 解除OAuth账户关联
	UnlinkOAuthAccount(ctx context.Context, userID string, provider repository.OAuthProvider) error
	
	// GetOAuthAccounts 获取用户的OAuth账户列表
	GetOAuthAccounts(ctx context.Context, userID string) ([]repository.OAuthAccount, error)
}

type oauthService struct {
	config      *config.OAuthConfig
	userRepo    repository.UserRepository
	deviceRepo  repository.DeviceRepository
	tokenRepo   repository.TokenRepository
	oauthRepo   repository.OAuthRepository
	jwtService  JWTService
	stateStore  map[string]*config.OAuthStateData // 简化版，生产环境应使用Redis
}

// NewOAuthService 创建OAuth服务实例
func NewOAuthService(
	cfg *config.OAuthConfig,
	userRepo repository.UserRepository,
	deviceRepo repository.DeviceRepository,
	tokenRepo repository.TokenRepository,
	oauthRepo repository.OAuthRepository,
	jwtSecret string,
) OAuthService {
	return &oauthService{
		config:     cfg,
		userRepo:   userRepo,
		deviceRepo: deviceRepo,
		tokenRepo:  tokenRepo,
		oauthRepo:  oauthRepo,
		jwtService: NewJWTService(jwtSecret, "sec-chat-auth"),
		stateStore: make(map[string]*config.OAuthStateData),
	}
}

// GetAuthURL 获取OAuth授权URL
func (s *oauthService) GetAuthURL(state string) string {
	if !s.config.IsConfigured() {
		return ""
	}
	
	oauthConfig := s.config.GoogleOAuth2Config()
	return oauthConfig.AuthCodeURL(state, oauth2.AccessTypeOffline, oauth2.ApprovalForce)
}

// StoreState 存储State参数
func (s *oauthService) StoreState(state string) error {
	s.stateStore[state] = config.NewOAuthStateData(state, s.config.StateExpiry)
	
	// 清理过期的state（简化版，生产环境应由定时任务处理）
	go s.cleanupExpiredStates()
	
	return nil
}

// ValidateState 验证State参数
func (s *oauthService) ValidateState(state string) bool {
	stateData, exists := s.stateStore[state]
	if !exists {
		return false
	}
	
	// 检查是否过期
	if stateData.IsExpired() {
		delete(s.stateStore, state)
		return false
	}
	
	// 删除已使用的state（一次性使用）
	delete(s.stateStore, state)
	return true
}

// HandleCallback 处理OAuth回调
func (s *oauthService) HandleCallback(ctx context.Context, code, state string) (*TokenResponse, error) {
	// 检查OAuth是否配置
	if !s.config.IsConfigured() {
		return nil, ErrOAuthNotConfigured
	}
	
	// 验证State
	if !s.ValidateState(state) {
		return nil, ErrOAuthStateInvalid
	}
	
	// 使用授权码交换令牌
	oauthConfig := s.config.GoogleOAuth2Config()
	token, err := oauthConfig.Exchange(ctx, code)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrOAuthCodeInvalid, err)
	}
	
	// 获取用户信息
	userInfo, err := s.GetUserInfo(token.AccessToken)
	if err != nil {
		return nil, fmt.Errorf("failed to get user info: %w", err)
	}
	
	// 验证邮箱域名
	if !s.config.IsEmailAllowed(userInfo.Email) {
		return nil, ErrOAuthEmailNotAllowed
	}
	
	// 查找或创建用户
	user, err := s.findOrCreateUser(ctx, userInfo, token)
	if err != nil {
		return nil, err
	}
	
	// 创建设备记录
	deviceID := uuid.New().String()
	device := &repository.Device{
		DeviceID:   deviceID,
		UserID:     user.UserID,
		DeviceName: ptr("OAuth Login"),
		DeviceType: ptr("oauth"),
	}
	
	if err := s.deviceRepo.Create(ctx, device); err != nil {
		return nil, fmt.Errorf("failed to create device: %w", err)
	}
	
	// 生成JWT令牌
	return s.generateTokens(ctx, user, deviceID)
}

// GetUserInfo 获取OAuth用户信息
func (s *oauthService) GetUserInfo(accessToken string) (*OAuthUserInfo, error) {
	resp, err := http.Get("https://www.googleapis.com/oauth2/v2/userinfo?access_token=" + accessToken)
	if err != nil {
		return nil, fmt.Errorf("failed to get user info: %w", err)
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed to get user info: status %d", resp.StatusCode)
	}
	
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response body: %w", err)
	}
	
	var userInfo OAuthUserInfo
	if err := json.Unmarshal(body, &userInfo); err != nil {
		return nil, fmt.Errorf("failed to parse user info: %w", err)
	}
	
	return &userInfo, nil
}

// findOrCreateUser 查找或创建用户
func (s *oauthService) findOrCreateUser(ctx context.Context, userInfo *OAuthUserInfo, token *oauth2.Token) (*repository.User, error) {
	// 1. 先查找OAuth账户是否已关联
	oauthAccount, err := s.oauthRepo.GetByProviderID(ctx, repository.OAuthProviderGoogle, userInfo.ID)
	if err == nil {
		// OAuth账户已存在，获取用户
		user, err := s.userRepo.GetByID(ctx, oauthAccount.UserID)
		if err != nil {
			return nil, fmt.Errorf("failed to get user: %w", err)
		}
		
		// 更新令牌
		expiry := token.Expiry
		if err := s.oauthRepo.UpdateTokens(ctx, oauthAccount.ID, token.AccessToken, token.RefreshToken, &expiry); err != nil {
			// 记录错误但不中断流程
			fmt.Printf("Warning: failed to update oauth tokens: %v\n", err)
		}
		
		return user, nil
	}
	
	// 2. 查找是否有相同邮箱的用户
	if userInfo.Email != "" {
		existingUser, err := s.userRepo.GetByEmail(ctx, userInfo.Email)
		if err == nil {
			// 用户已存在
			if existingUser.AuthType != "oauth" && existingUser.PasswordHash != "" {
				// 用户使用密码注册，创建OAuth关联
				if s.config.AutoCreateUser {
					if err := s.createOAuthAccount(ctx, existingUser.UserID, userInfo, token); err != nil {
						return nil, err
					}
					return existingUser, nil
				}
				return nil, ErrOAuthUserExists
			}
			
			// 用户已经是OAuth用户，创建OAuth账户关联
			if err := s.createOAuthAccount(ctx, existingUser.UserID, userInfo, token); err != nil {
				return nil, err
			}
			return existingUser, nil
		}
	}
	
	// 3. 创建新用户
	if !s.config.AutoCreateUser {
		return nil, ErrUserNotFound
	}
	
	// 从邮箱提取用户名
	username := s.generateUsername(userInfo)
	
	userID := fmt.Sprintf("@%s:sec-chat.local", username)
	user := &repository.User{
		UserID:        userID,
		Username:      username,
		Email:         &userInfo.Email,
		DisplayName:   &userInfo.Name,
		AvatarURL:     &userInfo.Picture,
		IsActive:      true,
		AuthType:      "oauth",
		EmailVerified: userInfo.VerifiedEmail,
	}
	
	if err := s.userRepo.Create(ctx, user); err != nil {
		return nil, fmt.Errorf("failed to create user: %w", err)
	}
	
	// 创建OAuth账户关联
	if err := s.createOAuthAccount(ctx, user.UserID, userInfo, token); err != nil {
		return nil, err
	}
	
	return user, nil
}

// createOAuthAccount 创建OAuth账户关联
func (s *oauthService) createOAuthAccount(ctx context.Context, userID string, userInfo *OAuthUserInfo, token *oauth2.Token) error {
	account := &repository.OAuthAccount{
		UserID:       userID,
		Provider:     repository.OAuthProviderGoogle,
		ProviderID:   userInfo.ID,
		Email:        userInfo.Email,
		Name:         userInfo.Name,
		Picture:      userInfo.Picture,
		AccessToken:  token.AccessToken,
		RefreshToken: token.RefreshToken,
		TokenExpiry:  &token.Expiry,
	}
	
	return s.oauthRepo.Create(ctx, account)
}

// generateUsername 生成用户名
func (s *oauthService) generateUsername(userInfo *OAuthUserInfo) string {
	// 优先使用邮箱前缀
	if userInfo.Email != "" {
		parts := strings.Split(userInfo.Email, "@")
		username := parts[0]
		
		// 检查用户名是否已存在
		if _, err := s.userRepo.GetByUsername(context.Background(), username); err != nil {
			return username
		}
		
		// 添加随机后缀
		return username + "_" + uuid.New().String()[:8]
	}
	
	// 使用名字
	if userInfo.Name != "" {
		username := strings.ToLower(strings.ReplaceAll(userInfo.Name, " ", "_"))
		if _, err := s.userRepo.GetByUsername(context.Background(), username); err != nil {
			return username
		}
		return username + "_" + uuid.New().String()[:8]
	}
	
	// 使用Google ID
	return "user_" + userInfo.ID[:8]
}

// generateTokens 生成JWT令牌
func (s *oauthService) generateTokens(ctx context.Context, user *repository.User, deviceID string) (*TokenResponse, error) {
	now := time.Now()
	accessTokenExpiry := now.Add(time.Hour)
	refreshTokenExpiry := now.Add(7 * 24 * time.Hour)
	
	// 生成Access Token
	accessToken, err := s.jwtService.GenerateAccessToken(user.UserID, user.Username, deviceID, accessTokenExpiry)
	if err != nil {
		return nil, fmt.Errorf("failed to generate access token: %w", err)
	}
	
	// 生成Refresh Token
	refreshToken := uuid.New().String()
	refreshTokenHash := s.tokenRepo.HashToken(refreshToken)
	
	refreshTokenRecord := &repository.RefreshToken{
		TokenHash: refreshTokenHash,
		UserID:    user.UserID,
		DeviceID:  deviceID,
		ExpiresAt: refreshTokenExpiry,
	}
	
	if err := s.tokenRepo.SaveRefreshToken(ctx, refreshTokenRecord); err != nil {
		return nil, fmt.Errorf("failed to save refresh token: %w", err)
	}
	
	return &TokenResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    int64(time.Until(accessTokenExpiry).Seconds()),
		TokenType:    "Bearer",
	}, nil
}

// LinkOAuthAccount 关联OAuth账户到现有用户
func (s *oauthService) LinkOAuthAccount(ctx context.Context, userID string, userInfo *OAuthUserInfo, token *oauth2.Token) error {
	// 检查OAuth账户是否已关联到其他用户
	existingAccount, err := s.oauthRepo.GetByProviderID(ctx, repository.OAuthProviderGoogle, userInfo.ID)
	if err == nil && existingAccount.UserID != userID {
		return ErrOAuthAccountLinked
	}
	
	// 检查用户是否已关联该提供商
	_, err = s.oauthRepo.GetByUserIDAndProvider(ctx, userID, repository.OAuthProviderGoogle)
	if err == nil {
		return errors.New("oauth account already linked")
	}
	
	// 创建OAuth账户关联
	return s.createOAuthAccount(ctx, userID, userInfo, token)
}

// UnlinkOAuthAccount 解除OAuth账户关联
func (s *oauthService) UnlinkOAuthAccount(ctx context.Context, userID string, provider repository.OAuthProvider) error {
	account, err := s.oauthRepo.GetByUserIDAndProvider(ctx, userID, provider)
	if err != nil {
		return fmt.Errorf("oauth account not found: %w", err)
	}
	
	return s.oauthRepo.Delete(ctx, account.ID)
}

// GetOAuthAccounts 获取用户的OAuth账户列表
func (s *oauthService) GetOAuthAccounts(ctx context.Context, userID string) ([]repository.OAuthAccount, error) {
	return s.oauthRepo.GetByUserID(ctx, userID)
}

// cleanupExpiredStates 清理过期的State
func (s *oauthService) cleanupExpiredStates() {
	now := time.Now()
	for key, stateData := range s.stateStore {
		if stateData.ExpiresAt.Before(now) {
			delete(s.stateStore, key)
		}
	}
}

// ptr 返回字符串指针
func ptr(s string) *string {
	return &s
}
