package service

import (
	"gorm.io/gorm"
)

// AdminService 管理服务
type AdminService struct {
	db *gorm.DB
}

// NewAdminService 创建管理服务实例
func NewAdminService(db *gorm.DB) *AdminService {
	return &AdminService{db: db}
}
