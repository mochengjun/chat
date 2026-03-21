"""
智能编译缓存工具 - 配置管理模块
"""
import os
import json
from pathlib import Path
from typing import Dict, Any, Optional


class CacheConfig:
    """缓存配置管理类"""
    
    DEFAULT_CONFIG = {
        "cache_dir": ".cache",
        "flutter": {
            "enabled": True,
            "pub_cache": True,
            "gradle_cache": True,
            "mirrors": {
                "pub": "https://pub.flutter-io.cn",
                "storage": "https://storage.flutter-io.cn"
            }
        },
        "go": {
            "enabled": True,
            "mod_cache": True,
            "proxy": "https://goproxy.cn,https://goproxy.io,direct",
            "version": "1.23"
        },
        "nodejs": {
            "enabled": True,
            "npm_cache": True,
            "registry": "https://registry.npmmirror.com"
        },
        "offline_mode": False,
        "max_cache_size_gb": 10,
        "cache_expiry_days": 30,
        "verbose": False
    }
    
    def __init__(self, project_root: Path):
        self.project_root = Path(project_root)
        self.config_file = self.project_root / "cache-config.json"
        self.config = self._load_config()
        
    def _load_config(self) -> Dict[str, Any]:
        """加载配置文件"""
        if self.config_file.exists():
            try:
                with open(self.config_file, 'r', encoding='utf-8') as f:
                    user_config = json.load(f)
                # 合并用户配置和默认配置
                return self._merge_config(self.DEFAULT_CONFIG.copy(), user_config)
            except Exception as e:
                print(f"警告: 加载配置文件失败: {e}, 使用默认配置")
                return self.DEFAULT_CONFIG.copy()
        return self.DEFAULT_CONFIG.copy()
    
    def _merge_config(self, base: Dict, override: Dict) -> Dict:
        """递归合并配置"""
        result = base.copy()
        for key, value in override.items():
            if key in result and isinstance(result[key], dict) and isinstance(value, dict):
                result[key] = self._merge_config(result[key], value)
            else:
                result[key] = value
        return result
    
    def get_cache_dir(self) -> Path:
        """获取缓存目录路径"""
        # 环境变量优先级最高
        cache_dir = os.environ.get('CACHE_DIR')
        if cache_dir:
            return Path(cache_dir)
        
        # 配置文件中的路径
        cache_path = self.config.get('cache_dir', '.cache')
        
        # 如果是相对路径,相对于项目根目录
        if not os.path.isabs(cache_path):
            cache_path = self.project_root / cache_path
        else:
            cache_path = Path(cache_path)
            
        return cache_path
    
    def is_enabled(self, tech_stack: str) -> bool:
        """检查技术栈是否启用"""
        return self.config.get(tech_stack, {}).get('enabled', False)
    
    def get(self, key: str, default: Any = None) -> Any:
        """获取配置值"""
        keys = key.split('.')
        value = self.config
        for k in keys:
            if isinstance(value, dict):
                value = value.get(k)
                if value is None:
                    return default
            else:
                return default
        return value
    
    def set(self, key: str, value: Any):
        """设置配置值"""
        keys = key.split('.')
        config = self.config
        for k in keys[:-1]:
            if k not in config:
                config[k] = {}
            config = config[k]
        config[keys[-1]] = value
    
    def save(self):
        """保存配置到文件"""
        with open(self.config_file, 'w', encoding='utf-8') as f:
            json.dump(self.config, f, indent=2, ensure_ascii=False)
    
    def is_offline_mode(self) -> bool:
        """检查是否为离线模式"""
        # 环境变量优先
        if os.environ.get('OFFLINE_MODE', '').lower() in ('true', '1', 'yes'):
            return True
        return self.config.get('offline_mode', False)
    
    def is_verbose(self) -> bool:
        """检查是否为详细模式"""
        return self.config.get('verbose', False)
    
    def get_flutter_config(self) -> Dict[str, Any]:
        """获取Flutter配置"""
        return self.config.get('flutter', {})
    
    def get_go_config(self) -> Dict[str, Any]:
        """获取Go配置"""
        return self.config.get('go', {})
    
    def get_nodejs_config(self) -> Dict[str, Any]:
        """获取Node.js配置"""
        return self.config.get('nodejs', {})
    
    def get_max_cache_size_bytes(self) -> int:
        """获取最大缓存大小(字节)"""
        return self.config.get('max_cache_size_gb', 10) * 1024 * 1024 * 1024
    
    def get_cache_expiry_seconds(self) -> int:
        """获取缓存过期时间(秒)"""
        return self.config.get('cache_expiry_days', 30) * 24 * 60 * 60
