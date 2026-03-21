"""
Go 模块缓存管理模块
"""
import os
import json
import shutil
import subprocess
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from datetime import datetime


class GoCacheManager:
    """Go 模块缓存管理器"""
    
    def __init__(self, project_root: Path, cache_dir: Path, config: Dict):
        self.project_root = Path(project_root)
        self.cache_dir = Path(cache_dir)
        self.config = config
        self.go_cache = self.cache_dir / "go"
        self.mod_cache = self.go_cache / "mod-cache"
        
        # 确保缓存目录存在
        self.go_cache.mkdir(parents=True, exist_ok=True)
        self.mod_cache.mkdir(parents=True, exist_ok=True)
    
    def find_go_mod_files(self) -> List[Path]:
        """查找项目中所有的 go.mod 文件"""
        go_mod_files = []
        for root, dirs, files in os.walk(self.project_root):
            # 跳过缓存和构建目录
            dirs[:] = [d for d in dirs if d not in ['.cache', 'vendor', 'node_modules']]
            
            if 'go.mod' in files:
                go_mod_files.append(Path(root) / 'go.mod')
        return go_mod_files
    
    def parse_go_mod(self, go_mod_file: Path) -> Dict:
        """解析 go.mod 文件"""
        modules = {
            'module': None,
            'go_version': None,
            'dependencies': []
        }
        
        try:
            with open(go_mod_file, 'r', encoding='utf-8') as f:
                lines = f.readlines()
            
            in_require = False
            for line in lines:
                line = line.strip()
                
                # 解析 module 名称
                if line.startswith('module '):
                    modules['module'] = line.split(' ', 1)[1]
                
                # 解析 Go 版本
                elif line.startswith('go '):
                    modules['go_version'] = line.split(' ', 1)[1]
                
                # 解析 require 块
                elif line.startswith('require ('):
                    in_require = True
                elif line == ')':
                    in_require = False
                elif in_require or line.startswith('require '):
                    # 单行 require 或块内的依赖
                    if line.startswith('require '):
                        line = line.replace('require ', '').strip()
                    if line and not line.startswith('//'):
                        parts = line.split()
                        if len(parts) >= 2:
                            modules['dependencies'].append({
                                'module': parts[0],
                                'version': parts[1]
                            })
        except Exception as e:
            print(f"解析 {go_mod_file} 失败: {e}")
        
        return modules
    
    def get_system_gopath(self) -> Path:
        """获取系统默认的 GOPATH"""
        gopath = os.environ.get('GOPATH')
        if gopath:
            return Path(gopath)
        
        # 默认路径
        if os.name == 'nt':  # Windows
            return Path(os.environ.get('USERPROFILE', '')) / 'go'
        else:  # macOS / Linux
            return Path.home() / 'go'
    
    def get_system_mod_cache(self) -> Path:
        """获取系统默认的 Go 模块缓存路径"""
        gopath = self.get_system_gopath()
        return gopath / 'pkg' / 'mod'
    
    def check_cached_modules(self, go_mod_file: Path) -> Tuple[int, int, List[str]]:
        """
        检查 go.mod 中依赖的缓存状态
        返回: (已缓存数量, 总依赖数量, 缺失的模块列表)
        """
        modules = self.parse_go_mod(go_mod_file)
        dependencies = modules.get('dependencies', [])
        
        total = len(dependencies)
        cached = 0
        missing = []
        
        local_cache = self.mod_cache
        system_cache = self.get_system_mod_cache()
        
        for dep in dependencies:
            module_path = dep['module']
            version = dep['version']
            
            # 检查本地缓存
            local_cached = self._check_module_in_cache(module_path, version, local_cache)
            # 检查系统缓存
            system_cached = self._check_module_in_cache(module_path, version, system_cache)
            
            if local_cached or system_cached:
                cached += 1
            else:
                missing.append(f"{module_path}@{version}")
        
        return cached, total, missing
    
    def _check_module_in_cache(self, module_path: str, version: str, cache_path: Path) -> bool:
        """检查模块是否存在于缓存中"""
        if not cache_path.exists():
            return False
        
        # Go 模块缓存路径格式: cache_path/module_path@version
        # 模块路径中的大写字母会转换为小写,特殊字符编码
        
        # 简化检查: 查找包含模块名的目录
        module_name = module_path.split('/')[-1]
        for item in cache_path.rglob(f"*{module_name}*"):
            if item.is_dir() and version in item.name:
                return True
        
        return False
    
    def sync_dependencies(self, go_mod_file: Path, offline: bool = False) -> bool:
        """
        同步 go.mod 的依赖到本地缓存
        返回: 是否成功
        """
        go_mod_dir = go_mod_file.parent
        
        # 设置环境变量
        env = os.environ.copy()
        
        # 设置 GOPATH 指向本地缓存
        env['GOPATH'] = str(self.go_cache)
        
        # 设置 GOMODCACHE
        env['GOMODCACHE'] = str(self.mod_cache)
        
        # 配置代理
        proxy = self.config.get('proxy', 'https://goproxy.cn,direct')
        env['GOPROXY'] = proxy
        
        # 禁用校验和数据库(离线模式)
        if offline:
            env['GOPROXY'] = 'off'
            env['GOSUMDB'] = 'off'
        
        try:
            # 执行 go mod download
            cmd = ['go', 'mod', 'download']
            
            print(f"  执行: {' '.join(cmd)}")
            print(f"  工作目录: {go_mod_dir}")
            print(f"  GOPROXY: {env.get('GOPROXY')}")
            
            result = subprocess.run(
                cmd,
                cwd=go_mod_dir,
                env=env,
                capture_output=True,
                text=True,
                timeout=300  # 5分钟超时
            )
            
            if result.returncode == 0:
                print(f"  ✓ 模块同步成功: {go_mod_file.relative_to(self.project_root)}")
                return True
            else:
                print(f"  ✗ 模块同步失败: {go_mod_file.relative_to(self.project_root)}")
                if result.stderr:
                    print(f"    错误: {result.stderr}")
                
                # 如果离线模式失败,尝试从系统缓存复制
                if offline:
                    return self._copy_from_system_cache(go_mod_file, env)
                
                return False
                
        except subprocess.TimeoutExpired:
            print(f"  ✗ 模块同步超时: {go_mod_file.relative_to(self.project_root)}")
            return False
        except Exception as e:
            print(f"  ✗ 模块同步异常: {e}")
            return False
    
    def _copy_from_system_cache(self, go_mod_file: Path, env: Dict) -> bool:
        """从系统缓存复制模块"""
        print("  尝试从系统缓存复制...")
        
        system_cache = self.get_system_mod_cache()
        if not system_cache.exists():
            print("    系统缓存不存在")
            return False
        
        modules = self.parse_go_mod(go_mod_file)
        dependencies = modules.get('dependencies', [])
        
        copied_count = 0
        for dep in dependencies:
            module_path = dep['module']
            version = dep['version']
            
            # 在系统缓存中查找模块
            module_name = module_path.split('/')[-1]
            for src_dir in system_cache.rglob(f"*{module_name}*"):
                if src_dir.is_dir() and version in src_dir.name:
                    # 复制到本地缓存
                    relative_path = src_dir.relative_to(system_cache)
                    dst_dir = self.mod_cache / relative_path
                    
                    if not dst_dir.exists():
                        try:
                            shutil.copytree(src_dir, dst_dir)
                            print(f"    ✓ 复制: {module_path}@{version}")
                            copied_count += 1
                        except Exception as e:
                            print(f"    ✗ 复制失败: {e}")
        
        return copied_count > 0
    
    def vendor_dependencies(self, go_mod_file: Path) -> bool:
        """
        将依赖复制到 vendor 目录
        返回: 是否成功
        """
        go_mod_dir = go_mod_file.parent
        vendor_dir = go_mod_dir / 'vendor'
        
        # 设置环境变量
        env = os.environ.copy()
        env['GOPATH'] = str(self.go_cache)
        env['GOMODCACHE'] = str(self.mod_cache)
        env['GOPROXY'] = self.config.get('proxy', 'https://goproxy.cn,direct')
        
        try:
            cmd = ['go', 'mod', 'vendor']
            
            print(f"  执行: {' '.join(cmd)}")
            print(f"  工作目录: {go_mod_dir}")
            
            result = subprocess.run(
                cmd,
                cwd=go_mod_dir,
                env=env,
                capture_output=True,
                text=True,
                timeout=300
            )
            
            if result.returncode == 0:
                print(f"  ✓ vendor 创建成功: {vendor_dir}")
                return True
            else:
                print(f"  ✗ vendor 创建失败")
                if result.stderr:
                    print(f"    错误: {result.stderr}")
                return False
                
        except Exception as e:
            print(f"  ✗ vendor 创建异常: {e}")
            return False
    
    def clean_cache(self, older_than_days: Optional[int] = None):
        """清理缓存"""
        if older_than_days:
            cutoff_time = datetime.now().timestamp() - (older_than_days * 86400)
            
            for module_dir in self.mod_cache.rglob('*'):
                if module_dir.is_dir():
                    if module_dir.stat().st_mtime < cutoff_time:
                        print(f"  删除过期缓存: {module_dir.name}")
                        shutil.rmtree(module_dir)
        else:
            if self.mod_cache.exists():
                print(f"  清理 Go 模块缓存: {self.mod_cache}")
                shutil.rmtree(self.mod_cache)
                self.mod_cache.mkdir(parents=True, exist_ok=True)
    
    def get_cache_size(self) -> int:
        """获取缓存大小(字节) - 包括本地缓存和系统缓存"""
        total_size = 0

        # 统计本地缓存
        if self.mod_cache.exists():
            for file_path in self.mod_cache.rglob('*'):
                if file_path.is_file():
                    total_size += file_path.stat().st_size

        # 统计系统缓存
        system_cache = self.get_system_mod_cache()
        if system_cache.exists():
            for file_path in system_cache.rglob('*'):
                if file_path.is_file():
                    total_size += file_path.stat().st_size

        return total_size

    def get_cached_module_count(self) -> int:
        """获取已缓存的模块数量 - 包括本地缓存和系统缓存"""
        cached_modules = set()

        # 检查本地缓存
        if self.mod_cache.exists():
            for item in self.mod_cache.rglob('*'):
                if item.is_dir() and '@' in item.name:
                    cached_modules.add(item.name)

        # 检查系统缓存
        system_cache = self.get_system_mod_cache()
        if system_cache.exists():
            for item in system_cache.rglob('*'):
                if item.is_dir() and '@' in item.name:
                    cached_modules.add(item.name)

        return len(cached_modules)
    
    def get_stats(self) -> Dict:
        """获取缓存统计信息"""
        go_mod_files = self.find_go_mod_files()
        
        total_deps = 0
        cached_deps = 0
        all_missing = []
        
        for go_mod_file in go_mod_files:
            cached, total, missing = self.check_cached_modules(go_mod_file)
            total_deps += total
            cached_deps += cached
            all_missing.extend(missing)
        
        return {
            'go_mod_files': len(go_mod_files),
            'total_dependencies': total_deps,
            'cached_dependencies': cached_deps,
            'missing_dependencies': len(all_missing),
            'missing_packages': all_missing[:10],
            'cache_size_bytes': self.get_cache_size(),
            'cache_size_mb': round(self.get_cache_size() / (1024 * 1024), 2)
        }
