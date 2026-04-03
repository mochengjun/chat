package middleware

import "strings"

// MaskUserID 脱敏用户ID，只显示前4后4位
// 如果长度 <= 8，返回 "****"
func MaskUserID(userID string) string {
	if len(userID) <= 8 {
		return "****"
	}
	return userID[:4] + "****" + userID[len(userID)-4:]
}

// MaskToken 脱敏Token，只显示前8位
func MaskToken(token string) string {
	if len(token) <= 8 {
		return "****"
	}
	return token[:8] + "****"
}

// MaskEmail 脱敏邮箱地址
// user@example.com -> u***@example.com
func MaskEmail(email string) string {
	atIdx := strings.Index(email, "@")
	if atIdx <= 0 {
		return "****"
	}
	if atIdx == 1 {
		return "*" + email[atIdx:]
	}
	return string(email[0]) + "***" + email[atIdx:]
}

// MaskOrigin 脱敏Origin，保留协议和域名，隐藏端口
func MaskOrigin(origin string) string {
	if origin == "" {
		return "<empty>"
	}
	return origin // Origin 本身不是敏感信息，保留完整输出
}
