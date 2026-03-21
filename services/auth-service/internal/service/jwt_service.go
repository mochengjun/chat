package service

import (
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// JWTService JWT服务接口
type JWTService interface {
	// GenerateAccessToken 生成Access Token
	GenerateAccessToken(userID, username, deviceID string, expiry time.Time) (string, error)
	
	// ParseAccessToken 解析Access Token
	ParseAccessToken(tokenString string) (*Claims, error)
}

type jwtService struct {
	secret []byte
	issuer string
}

// NewJWTService 创建JWT服务实例
func NewJWTService(secret, issuer string) JWTService {
	return &jwtService{
		secret: []byte(secret),
		issuer: issuer,
	}
}

// GenerateAccessToken 生成Access Token
func (s *jwtService) GenerateAccessToken(userID, username, deviceID string, expiry time.Time) (string, error) {
	now := time.Now()
	
	claims := &Claims{
		UserID:   userID,
		Username: username,
		DeviceID: deviceID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(expiry),
			IssuedAt:  jwt.NewNumericDate(now),
			NotBefore: jwt.NewNumericDate(now),
			Issuer:    s.issuer,
			Subject:   userID,
		},
	}
	
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(s.secret)
}

// ParseAccessToken 解析Access Token
func (s *jwtService) ParseAccessToken(tokenString string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return s.secret, nil
	})
	
	if err != nil {
		if errors.Is(err, jwt.ErrTokenExpired) {
			return nil, ErrTokenExpired
		}
		return nil, ErrTokenInvalid
	}
	
	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, ErrTokenInvalid
	}
	
	return claims, nil
}
