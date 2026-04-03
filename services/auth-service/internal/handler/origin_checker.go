package handler

import (
	"log"
	"net/http"
	"os"
	"strings"
)

// CheckWebSocketOrigin 检查 WebSocket 连接的 Origin 是否允许
// 供 websocket_handler 和 signaling_handler 共用
func CheckWebSocketOrigin(r *http.Request) bool {
	origin := r.Header.Get("Origin")

	// 空 Origin 处理：仅在开发环境允许（通过环境变量控制）
	if origin == "" || origin == "null" {
		allowEmpty := os.Getenv("WS_ALLOW_EMPTY_ORIGIN")
		if allowEmpty == "true" {
			log.Printf("WebSocket: empty/null origin allowed (dev mode)")
			return true
		}
		log.Printf("WebSocket: rejected empty/null origin")
		return false
	}

	// 从环境变量读取允许的域名列表
	allowedOriginsStr := os.Getenv("ALLOWED_ORIGINS")
	if allowedOriginsStr == "" {
		allowedOriginsStr = "http://localhost:3000,http://localhost:5173"
	}
	allowedOrigins := strings.Split(allowedOriginsStr, ",")
	for _, allowed := range allowedOrigins {
		if origin == strings.TrimSpace(allowed) {
			return true
		}
	}
	log.Printf("WebSocket: rejected origin %s", origin)
	return false
}
