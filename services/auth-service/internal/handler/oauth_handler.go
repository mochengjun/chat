package handler

import (
	"fmt"
	"log"
	"net/http"
	"net/url"

	"sec-chat/auth-service/internal/config"
	"sec-chat/auth-service/internal/repository"
	"sec-chat/auth-service/internal/service"

	"github.com/gin-gonic/gin"
)

// OAuthHandler OAuth处理器
type OAuthHandler struct {
	oauthService service.OAuthService
	config       *config.OAuthConfig
}

// NewOAuthHandler 创建OAuth处理器实例
func NewOAuthHandler(oauthService service.OAuthService, cfg *config.OAuthConfig) *OAuthHandler {
	return &OAuthHandler{
		oauthService: oauthService,
		config:       cfg,
	}
}

// GoogleLogin 发起Google OAuth登录
// @Summary 发起Google OAuth登录
// @Description 重定向到Google OAuth授权页面
// @Tags OAuth
// @Produce json
// @Success 302 {string} string "重定向到Google授权页面"
// @Router /api/v1/auth/oauth/google [get]
func (h *OAuthHandler) GoogleLogin(c *gin.Context) {
	// 检查OAuth是否配置
	if !h.config.IsConfigured() {
		c.JSON(http.StatusServiceUnavailable, gin.H{
			"error": "OAuth not configured",
		})
		return
	}
	
	// 生成state参数
	state, err := config.GenerateState()
	if err != nil {
		log.Printf("Failed to generate state: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "failed to initiate OAuth login",
		})
		return
	}
	
	// 存储state
	if err := h.oauthService.StoreState(state); err != nil {
		log.Printf("Failed to store state: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "failed to initiate OAuth login",
		})
		return
	}
	
	// 获取授权URL
	authURL := h.oauthService.GetAuthURL(state)
	
	log.Printf("Initiating Google OAuth login, state: %s", state)
	
	// 重定向到Google授权页面
	c.Redirect(http.StatusTemporaryRedirect, authURL)
}

// GoogleCallback 处理Google OAuth回调
// @Summary 处理Google OAuth回调
// @Description 处理Google OAuth授权回调，完成用户登录
// @Tags OAuth
// @Param code query string true "授权码"
// @Param state query string true "状态参数"
// @Success 302 {string} string "重定向到前端页面"
// @Failure 400 {object} map[string]string
// @Failure 401 {object} map[string]string
// @Router /api/v1/auth/oauth/google/callback [get]
func (h *OAuthHandler) GoogleCallback(c *gin.Context) {
	code := c.Query("code")
	state := c.Query("state")
	errorParam := c.Query("error")
	
	log.Printf("Google OAuth callback received - code: %d chars, state: %s", len(code), state)
	
	// 检查是否有错误
	if errorParam != "" {
		errorDesc := c.Query("error_description")
		log.Printf("OAuth error: %s - %s", errorParam, errorDesc)
		h.redirectWithError(c, errorParam, errorDesc)
		return
	}
	
	// 验证参数
	if err := config.ValidateOAuthCallback(code, state); err != nil {
		log.Printf("Invalid OAuth callback parameters: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "invalid OAuth callback parameters",
		})
		return
	}
	
	// 处理回调
	tokenResponse, err := h.oauthService.HandleCallback(c.Request.Context(), code, state)
	if err != nil {
		log.Printf("OAuth callback failed: %v", err)
		
		// 根据错误类型返回不同的状态码
		errorMessage := "OAuth login failed"
		
		switch err {
		case service.ErrOAuthStateInvalid, service.ErrOAuthStateExpired:
			errorMessage = "invalid or expired OAuth state"
		case service.ErrOAuthCodeInvalid:
			errorMessage = "invalid authorization code"
		case service.ErrOAuthEmailNotAllowed:
			errorMessage = "email domain not allowed"
		case service.ErrOAuthUserExists:
			errorMessage = "user already exists with different authentication method"
		case service.ErrOAuthNotConfigured:
			errorMessage = "OAuth not configured"
		}
		
		h.redirectWithError(c, "auth_failed", errorMessage)
		return
	}
	
	// 获取前端重定向URL
	frontendURL := h.getFrontendRedirectURL()
	
	// 设置Cookie（用于Web应用）
	h.setAuthCookies(c, tokenResponse)
	
	// 重定向到前端，带上token参数
	redirectURL := fmt.Sprintf("%s?access_token=%s&refresh_token=%s&expires_in=%d",
		frontendURL,
		tokenResponse.AccessToken,
		tokenResponse.RefreshToken,
		tokenResponse.ExpiresIn,
	)
	
	log.Printf("OAuth login successful, redirecting to frontend")
	
	c.Redirect(http.StatusTemporaryRedirect, redirectURL)
}

// GoogleLink 关联Google账户（需要已登录）
// @Summary 关联Google账户
// @Description 为当前用户关联Google账户
// @Tags OAuth
// @Security BearerAuth
// @Success 302 {string} string "重定向到Google授权页面"
// @Router /api/v1/auth/oauth/google/link [get]
func (h *OAuthHandler) GoogleLink(c *gin.Context) {
	// 检查用户是否已登录
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "authentication required",
		})
		return
	}
	
	// 生成state参数（包含用户ID）
	state, err := config.GenerateState()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "failed to initiate account linking",
		})
		return
	}
	
	// 存储state和用户ID的关联（简化版，生产环境应使用Redis）
	// TODO: 实现state与userID的关联存储
	
	// 存储state
	if err := h.oauthService.StoreState(state); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "failed to initiate account linking",
		})
		return
	}
	
	// 获取授权URL
	authURL := h.oauthService.GetAuthURL(state)
	
	log.Printf("Initiating Google OAuth linking for user: %s", userID)
	
	c.Redirect(http.StatusTemporaryRedirect, authURL)
}

// GetOAuthAccounts 获取用户的OAuth账户列表
// @Summary 获取OAuth账户列表
// @Description 获取当前用户关联的所有OAuth账户
// @Tags OAuth
// @Security BearerAuth
// @Success 200 {array} repository.OAuthAccount
// @Router /api/v1/auth/oauth/accounts [get]
func (h *OAuthHandler) GetOAuthAccounts(c *gin.Context) {
	userID, _ := c.Get("user_id")
	
	accounts, err := h.oauthService.GetOAuthAccounts(c.Request.Context(), userID.(string))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "failed to get OAuth accounts",
		})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{
		"accounts": accounts,
	})
}

// UnlinkOAuthAccount 解除OAuth账户关联
// @Summary 解除OAuth账户关联
// @Description 解除当前用户的指定OAuth账户关联
// @Tags OAuth
// @Security BearerAuth
// @Param provider path string true "OAuth提供商 (google, github)"
// @Success 200 {object} map[string]string
// @Router /api/v1/auth/oauth/accounts/{provider} [delete]
func (h *OAuthHandler) UnlinkOAuthAccount(c *gin.Context) {
	userID, _ := c.Get("user_id")
	provider := c.Param("provider")
	
	if provider != "google" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "unsupported OAuth provider",
		})
		return
	}
	
	err := h.oauthService.UnlinkOAuthAccount(c.Request.Context(), userID.(string), repository.OAuthProvider(provider))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "failed to unlink OAuth account",
		})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{
		"message": "OAuth account unlinked successfully",
	})
}

// setAuthCookies 设置认证Cookie
func (h *OAuthHandler) setAuthCookies(c *gin.Context, tokenResponse *service.TokenResponse) {
	secure, sameSite := h.config.GetCookieConfig()
	
	// 设置Access Token Cookie
	c.SetCookie(
		"access_token",
		tokenResponse.AccessToken,
		int(tokenResponse.ExpiresIn),
		"/",
		"",
		secure,
		true, // httpOnly
	)
	
	// 设置Refresh Token Cookie
	c.SetCookie(
		"refresh_token",
		tokenResponse.RefreshToken,
		7*24*3600, // 7天
		"/",
		"",
		secure,
		true,
	)
	
	// 设置SameSite属性
	c.SetSameSite(parseSameSite(sameSite))
}

// parseSameSite 解析SameSite配置
func parseSameSite(sameSite string) http.SameSite {
	switch sameSite {
	case "Strict":
		return http.SameSiteStrictMode
	case "None":
		return http.SameSiteNoneMode
	default:
		return http.SameSiteLaxMode
	}
}

// getFrontendRedirectURL 获取前端重定向URL
func (h *OAuthHandler) getFrontendRedirectURL() string {
	// 从配置或环境变量获取前端URL
	// 默认为开发环境URL
	return "http://localhost:3000/auth/callback"
}

// redirectWithError 重定向到前端并带上错误信息
func (h *OAuthHandler) redirectWithError(c *gin.Context, errorCode, errorDesc string) {
	frontendURL := h.getFrontendRedirectURL()
	
	redirectURL := fmt.Sprintf("%s?error=%s&error_description=%s",
		frontendURL,
		url.QueryEscape(errorCode),
		url.QueryEscape(errorDesc),
	)
	
	c.Redirect(http.StatusTemporaryRedirect, redirectURL)
}
