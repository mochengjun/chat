package handler

import (
	"net/http"

	"sec-chat/push-service/internal/service"

	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
)

// PushHandler 推送处理器
type PushHandler struct {
	service     *service.PushService
	redisClient *redis.Client
}

// NewPushHandler 创建推送处理器实例
func NewPushHandler(service *service.PushService, redisClient *redis.Client) *PushHandler {
	return &PushHandler{
		service:     service,
		redisClient: redisClient,
	}
}

// SendPushNotification 发送推送通知
func (h *PushHandler) SendPushNotification(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"message": "push notification sent"})
}

// RegisterDeviceToken 注册设备Token
func (h *PushHandler) RegisterDeviceToken(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"message": "device token registered"})
}

// UnregisterDeviceToken 注销设备Token
func (h *PushHandler) UnregisterDeviceToken(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"message": "device token unregistered"})
}
