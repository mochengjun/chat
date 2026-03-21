package repository

import (
	"context"
	"time"

	"gorm.io/gorm"
)

// OAuthProvider OAuth提供商类型
type OAuthProvider string

const (
	OAuthProviderGoogle OAuthProvider = "google"
	OAuthProviderGitHub OAuthProvider = "github"
)

// OAuthAccount OAuth账户关联模型
type OAuthAccount struct {
	ID           uint          `gorm:"primaryKey" json:"id"`
	UserID       string        `gorm:"column:user_id;size:255;index;not null" json:"user_id"`
	Provider     OAuthProvider `gorm:"column:provider;size:20;not null" json:"provider"`
	ProviderID   string        `gorm:"column:provider_id;size:100;not null" json:"provider_id"` // Google的用户ID
	Email        string        `gorm:"column:email;size:255" json:"email"`
	Name         string        `gorm:"column:name;size:255" json:"name"`
	Picture      string        `gorm:"column:picture;size:512" json:"picture"`
	AccessToken  string        `gorm:"column:access_token;type:text" json:"-"` // 加密存储
	RefreshToken string        `gorm:"column:refresh_token;type:text" json:"-"` // 加密存储
	TokenExpiry  *time.Time    `gorm:"column:token_expiry" json:"-"`
	CreatedAt    time.Time     `gorm:"column:created_at;autoCreateTime" json:"created_at"`
	UpdatedAt    time.Time     `gorm:"column:updated_at;autoUpdateTime" json:"updated_at"`
}

func (OAuthAccount) TableName() string {
	return "oauth_accounts"
}

// OAuthRepository OAuth仓库接口
type OAuthRepository interface {
	// 创建OAuth账户关联
	Create(ctx context.Context, account *OAuthAccount) error
	
	// 根据提供商和提供商用户ID获取OAuth账户
	GetByProviderID(ctx context.Context, provider OAuthProvider, providerID string) (*OAuthAccount, error)
	
	// 根据用户ID和提供商获取OAuth账户
	GetByUserIDAndProvider(ctx context.Context, userID string, provider OAuthProvider) (*OAuthAccount, error)
	
	// 获取用户的所有OAuth账户
	GetByUserID(ctx context.Context, userID string) ([]OAuthAccount, error)
	
	// 更新OAuth账户信息
	Update(ctx context.Context, account *OAuthAccount) error
	
	// 更新令牌
	UpdateTokens(ctx context.Context, id uint, accessToken, refreshToken string, expiry *time.Time) error
	
	// 删除OAuth账户关联
	Delete(ctx context.Context, id uint) error
	
	// 根据邮箱查找OAuth账户
	GetByEmail(ctx context.Context, provider OAuthProvider, email string) (*OAuthAccount, error)
}

type oauthRepository struct {
	db *gorm.DB
}

// NewOAuthRepository 创建OAuth仓库实例
func NewOAuthRepository(db *gorm.DB) OAuthRepository {
	return &oauthRepository{db: db}
}

func (r *oauthRepository) Create(ctx context.Context, account *OAuthAccount) error {
	return r.db.WithContext(ctx).Create(account).Error
}

func (r *oauthRepository) GetByProviderID(ctx context.Context, provider OAuthProvider, providerID string) (*OAuthAccount, error) {
	var account OAuthAccount
	err := r.db.WithContext(ctx).
		Where("provider = ? AND provider_id = ?", provider, providerID).
		First(&account).Error
	if err != nil {
		return nil, err
	}
	return &account, nil
}

func (r *oauthRepository) GetByUserIDAndProvider(ctx context.Context, userID string, provider OAuthProvider) (*OAuthAccount, error) {
	var account OAuthAccount
	err := r.db.WithContext(ctx).
		Where("user_id = ? AND provider = ?", userID, provider).
		First(&account).Error
	if err != nil {
		return nil, err
	}
	return &account, nil
}

func (r *oauthRepository) GetByUserID(ctx context.Context, userID string) ([]OAuthAccount, error) {
	var accounts []OAuthAccount
	err := r.db.WithContext(ctx).
		Where("user_id = ?", userID).
		Find(&accounts).Error
	if err != nil {
		return nil, err
	}
	return accounts, nil
}

func (r *oauthRepository) Update(ctx context.Context, account *OAuthAccount) error {
	return r.db.WithContext(ctx).Save(account).Error
}

func (r *oauthRepository) UpdateTokens(ctx context.Context, id uint, accessToken, refreshToken string, expiry *time.Time) error {
	updates := map[string]interface{}{
		"access_token":  accessToken,
		"refresh_token": refreshToken,
		"token_expiry":  expiry,
	}
	return r.db.WithContext(ctx).Model(&OAuthAccount{}).Where("id = ?", id).Updates(updates).Error
}

func (r *oauthRepository) Delete(ctx context.Context, id uint) error {
	return r.db.WithContext(ctx).Delete(&OAuthAccount{}, id).Error
}

func (r *oauthRepository) GetByEmail(ctx context.Context, provider OAuthProvider, email string) (*OAuthAccount, error) {
	var account OAuthAccount
	err := r.db.WithContext(ctx).
		Where("provider = ? AND email = ?", provider, email).
		First(&account).Error
	if err != nil {
		return nil, err
	}
	return &account, nil
}
