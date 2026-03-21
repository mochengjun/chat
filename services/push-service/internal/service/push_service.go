package service

import (
	firebase "firebase.google.com/go/v4"
)

// PushService 推送服务
type PushService struct {
	apnsKeyPath        string
	apnsKeyID          string
	apnsTeamID         string
	fcmCredentialsPath string
	fcmApp             *firebase.App
}

// NewPushService 创建推送服务实例
func NewPushService(apnsKeyPath, apnsKeyID, apnsTeamID, fcmCredentialsPath string) *PushService {
	return &PushService{
		apnsKeyPath:        apnsKeyPath,
		apnsKeyID:          apnsKeyID,
		apnsTeamID:         apnsTeamID,
		fcmCredentialsPath: fcmCredentialsPath,
	}
}
