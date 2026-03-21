package config

import (
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"log"
	"os"
	"strings"
	"sync"
	"time"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
)

// OAuthProvider OAuth提供商类型
type OAuthProvider string

const (
	OAuthProviderGoogle OAuthProvider = "google"
	OAuthProviderGitHub OAuthProvider = "github"
)

// OAuthConfig OAuth配置结构
type OAuthConfig struct {
	// Google OAuth 配置
	GoogleClientID     string
	GoogleClientSecret string
	GoogleRedirectURL  string

	// OAuth 行为配置
	StateExpiry        time.Duration // State参数过期时间
	AutoCreateUser     bool          // 是否自动创建用户
	AllowedDomains     []string      // 允许的企业邮箱域名
	AllowAllDomains    bool          // 是否允许所有域名

	// 安全配置
	ForceHTTPS     bool
	CookieSecure   bool
	CookieSameSite string
}

// GoogleOAuth2Config 返回配置好的Google OAuth2配置
func (c *OAuthConfig) GoogleOAuth2Config() *oauth2.Config {
	return &oauth2.Config{
		ClientID:     c.GoogleClientID,
		ClientSecret: c.GoogleClientSecret,
		RedirectURL:  c.GoogleRedirectURL,
		Scopes: []string{
			"https://www.googleapis.com/auth/userinfo.email",
			"https://www.googleapis.com/auth/userinfo.profile",
			"openid",
		},
		Endpoint: google.Endpoint,
	}
}

// IsConfigured 检查Google OAuth是否已配置
func (c *OAuthConfig) IsConfigured() bool {
	return c.GoogleClientID != "" && c.GoogleClientSecret != "" && c.GoogleRedirectURL != ""
}

// IsEmailAllowed 检查邮箱是否在允许的域名列表中
func (c *OAuthConfig) IsEmailAllowed(email string) bool {
	// 如果允许所有域名，直接返回true
	if c.AllowAllDomains {
		return true
	}

	// 解析邮箱域名
	parts := strings.Split(email, "@")
	if len(parts) != 2 {
		return false
	}

	domain := strings.ToLower(strings.TrimSpace(parts[1]))

	// 检查是否在允许列表中
	for _, allowedDomain := range c.AllowedDomains {
		if strings.ToLower(strings.TrimSpace(allowedDomain)) == domain {
			return true
		}
	}

	return false
}

// GenerateState 生成随机的state参数
func GenerateState() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", fmt.Errorf("failed to generate random state: %w", err)
	}
	return base64.URLEncoding.EncodeToString(b), nil
}

// OAuth配置单例
var (
	oauthConfig     *OAuthConfig
	oauthConfigOnce sync.Once
)

// GetOAuthConfig 获取OAuth配置单例
func GetOAuthConfig() *OAuthConfig {
	oauthConfigOnce.Do(func() {
		oauthConfig = loadOAuthConfigFromEnv()
	})
	return oauthConfig
}

// loadOAuthConfigFromEnv 从环境变量加载OAuth配置
func loadOAuthConfigFromEnv() *OAuthConfig {
	cfg := &OAuthConfig{
		// Google OAuth 凭据
		GoogleClientID:     getEnvOrDefault("GOOGLE_CLIENT_ID", ""),
		GoogleClientSecret: getEnvOrDefault("GOOGLE_CLIENT_SECRET", ""),
		GoogleRedirectURL:  getEnvOrDefault("GOOGLE_REDIRECT_URL", ""),

		// OAuth 行为配置
		StateExpiry:    parseDuration(getEnvOrDefault("OAUTH_STATE_EXPIRY", "300s")),
		AutoCreateUser: getEnvOrDefault("OAUTH_AUTO_CREATE_USER", "true") == "true",

		// 安全配置
		ForceHTTPS:     getEnvOrDefault("FORCE_HTTPS", "false") == "true",
		CookieSecure:   getEnvOrDefault("COOKIE_SECURE", "false") == "true",
		CookieSameSite: getEnvOrDefault("COOKIE_SAME_SITE", "Lax"),
	}

	// 解析允许的域名列表
	allowedDomainsStr := getEnvOrDefault("OAUTH_ALLOWED_DOMAINS", "")
	if allowedDomainsStr != "" {
		cfg.AllowedDomains = strings.Split(allowedDomainsStr, ",")
		// 清理空格
		for i := range cfg.AllowedDomains {
			cfg.AllowedDomains[i] = strings.TrimSpace(cfg.AllowedDomains[i])
		}
		cfg.AllowAllDomains = false
	} else {
		// 未配置允许域名列表时，允许所有域名
		cfg.AllowAllDomains = true
	}

	// 验证配置
	if cfg.IsConfigured() {
		log.Println("OAuth Configuration loaded successfully")
		log.Printf("  - Client ID: %s...", maskString(cfg.GoogleClientID, 10))
		log.Printf("  - Redirect URL: %s", cfg.GoogleRedirectURL)
		log.Printf("  - Auto Create User: %v", cfg.AutoCreateUser)
		if len(cfg.AllowedDomains) > 0 {
			log.Printf("  - Allowed Domains: %v", cfg.AllowedDomains)
		} else {
			log.Println("  - Allowed Domains: All domains")
		}
	} else {
		log.Println("OAuth not configured. Set GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, and GOOGLE_REDIRECT_URL to enable OAuth login.")
	}

	return cfg
}

// getEnvOrDefault 获取环境变量或返回默认值
func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// parseDuration 解析持续时间字符串
func parseDuration(s string) time.Duration {
	d, err := time.ParseDuration(s)
	if err != nil {
		// 尝试作为秒数解析
		var seconds int
		if _, err := fmt.Sscanf(s, "%d", &seconds); err == nil {
			return time.Duration(seconds) * time.Second
		}
		log.Printf("Warning: invalid duration format '%s', using default 5 minutes", s)
		return 5 * time.Minute
	}
	return d
}

// maskString 掩码字符串，只显示前n个字符
func maskString(s string, showLen int) string {
	if len(s) <= showLen {
		return s
	}
	return s[:showLen] + "..."
}

// OAuthStateData OAuth State数据结构
type OAuthStateData struct {
	State     string
	CreatedAt time.Time
	ExpiresAt time.Time
}

// NewOAuthStateData 创建新的OAuth State数据
func NewOAuthStateData(state string, expiry time.Duration) *OAuthStateData {
	now := time.Now()
	return &OAuthStateData{
		State:     state,
		CreatedAt: now,
		ExpiresAt: now.Add(expiry),
	}
}

// IsExpired 检查State是否已过期
func (s *OAuthStateData) IsExpired() bool {
	return time.Now().After(s.ExpiresAt)
}

// Validate 验证OAuth配置是否正确
func (c *OAuthConfig) Validate() error {
	if c.GoogleClientID == "" {
		return fmt.Errorf("GOOGLE_CLIENT_ID is required")
	}
	if c.GoogleClientSecret == "" {
		return fmt.Errorf("GOOGLE_CLIENT_SECRET is required")
	}
	if c.GoogleRedirectURL == "" {
		return fmt.Errorf("GOOGLE_REDIRECT_URL is required")
	}

	// 验证Redirect URL格式
	if !strings.HasPrefix(c.GoogleRedirectURL, "http://") && !strings.HasPrefix(c.GoogleRedirectURL, "https://") {
		return fmt.Errorf("GOOGLE_REDIRECT_URL must start with http:// or https://")
	}

	// 生产环境检查
	if c.ForceHTTPS {
		if !strings.HasPrefix(c.GoogleRedirectURL, "https://") {
			return fmt.Errorf("GOOGLE_REDIRECT_URL must use HTTPS in production (FORCE_HTTPS=true)")
		}
	}

	return nil
}

// GetCookieConfig 获取Cookie配置
func (c *OAuthConfig) GetCookieConfig() (secure bool, sameSite string) {
	return c.CookieSecure, c.CookieSameSite
}

// ValidateOAuthCallback 验证OAuth回调参数
func ValidateOAuthCallback(code, state string) error {
	if code == "" {
		return fmt.Errorf("authorization code is required")
	}
	if state == "" {
		return fmt.Errorf("state parameter is required")
	}
	if len(state) < 16 {
		return fmt.Errorf("invalid state parameter length")
	}
	return nil
}
