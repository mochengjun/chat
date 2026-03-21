"""
Node.js 依赖缓存管理模块
"""
import os
import json
import shutil
import subprocess
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from datetime import datetime


class NodeJSCacheManager:
    """Node.js 依赖缓存管理器"""
    
    def __init__(self, project_root: Path, cache_dir: Path, config: Dict):
        self.project_root = Path(project_root)
        self.cache_dir = Path(cache_dir)
        self.config = config
        self.nodejs_cache = self.cache_dir / "nodejs"
        self.npm_cache = self.nodejs_cache / "npm-cache"
        
        # 确保缓存目录存在
        self.nodejs_cache.mkdir(parents=True, exist_ok=True)
        self.npm_cache.mkdir(parents=True, exist_ok=True)
    
    def find_package_json_files(self) -> List[Path]:
        """查找项目中所有的 package.json 文件"""
        package_files = []
        for root, dirs, files in os.walk(self.project_root):
            # 跳过缓存和构建目录
            dirs[:] = [d for d in dirs if d not in ['.cache', 'node_modules', 'dist', 'build']]
            
            if 'package.json' in files:
                package_file = Path(root) / 'package.json'
                # 排除一些特殊的 package.json
                rel_path = package_file.relative_to(self.project_root)
                if '.vite' not in str(rel_path):  # 排除 Vite 自动生成的文件
                    package_files.append(package_file)
        return package_files
    
    def parse_package_json(self, package_file: Path) -> Dict:
        """解析 package.json 文件"""
        try:
            with open(package_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception as e:
            print(f"解析 {package_file} 失败: {e}")
            return {}
    
    def get_system_npm_cache(self) -> Path:
        """获取系统默认的 NPM 缓存路径"""
        # 环境变量优先
        if 'NPM_CONFIG_CACHE' in os.environ:
            return Path(os.environ['NPM_CONFIG_CACHE'])
        
        # 尝试从 npm config 获取
        try:
            result = subprocess.run(
                ['npm', 'config', 'get', 'cache'],
                capture_output=True,
                text=True,
                timeout=10
            )
            if result.returncode == 0:
                cache_path = result.stdout.strip()
                if cache_path and cache_path != 'undefined':
                    return Path(cache_path)
        except Exception:
            pass
        
        # 默认路径
        if os.name == 'nt':  # Windows
            return Path(os.environ.get('APPDATA', '')) / 'npm-cache'
        else:  # macOS / Linux
            return Path.home() / '.npm'
    
    def check_cached_packages(self, package_file: Path) -> Tuple[int, int, List[str]]:
        """
        检查 package.json 中依赖的缓存状态
        返回: (已缓存数量, 总依赖数量, 缺失的包列表)
        """
        package_data = self.parse_package_json(package_file)
        if not package_data:
            return 0, 0, []
        
        dependencies = package_data.get('dependencies', {})
        dev_dependencies = package_data.get('devDependencies', {})
        all_deps = {**dependencies, **dev_dependencies}
        
        total = len(all_deps)
        cached = 0
        missing = []
        
        local_cache = self.npm_cache
        system_cache = self.get_system_npm_cache()
        
        for pkg_name, pkg_version in all_deps.items():
            # 检查本地缓存
            local_cached = self._check_package_in_cache(pkg_name, pkg_version, local_cache)
            # 检查系统缓存
            system_cached = self._check_package_in_cache(pkg_name, pkg_version, system_cache)
            
            if local_cached or system_cached:
                cached += 1
            else:
                missing.append(f"{pkg_name}@{pkg_version}")
        
        return cached, total, missing
    
    def _check_package_in_cache(self, pkg_name: str, pkg_version: str, cache_path: Path) -> bool:
        """检查包是否存在于缓存中"""
        if not cache_path.exists():
            return False
        
        # NPM 缓存结构: cache_path/_cacache/
        # 使用 npm ls 命令检查会更准确
        
        # 简化检查: 检查缓存目录中是否有相关文件
        # NPM 缓存使用内容寻址,不容易直接检查
        
        # 检查 node_modules
        package_dir = cache_path.parent / 'node_modules' / pkg_name
        if package_dir.exists():
            # 检查版本
            pkg_json = package_dir / 'package.json'
            if pkg_json.exists():
                try:
                    with open(pkg_json, 'r', encoding='utf-8') as f:
                        pkg_data = json.load(f)
                        # 版本匹配检查
                        cached_version = pkg_data.get('version', '')
                        if self._version_matches(pkg_version, cached_version):
                            return True
                except Exception:
                    pass
        
        return False
    
    def _version_matches(self, version_range: str, actual_version: str) -> bool:
        """检查版本是否匹配版本范围"""
        # 简化版本匹配逻辑
        if version_range == 'latest' or version_range == '*':
            return True
        
        # 移除 ^ 或 ~ 前缀
        if version_range.startswith('^') or version_range.startswith('~'):
            min_version = version_range[1:]
            # 简单检查主版本号
            if actual_version.startswith(min_version.split('.')[0]):
                return True
        
        # 精确匹配
        if version_range == actual_version:
            return True
        
        return False
    
    def sync_dependencies(self, package_file: Path, offline: bool = False) -> bool:
        """
        同步 package.json 的依赖到本地缓存
        返回: 是否成功
        """
        package_dir = package_file.parent
        
        # 设置环境变量
        env = os.environ.copy()
        env['npm_config_cache'] = str(self.npm_cache)
        
        # 配置 registry
        registry = self.config.get('registry', 'https://registry.npmmirror.com')
        env['npm_config_registry'] = registry
        
        try:
            # 检查包管理器
            has_npm = shutil.which('npm') is not None
            has_yarn = shutil.which('yarn') is not None
            has_pnpm = shutil.which('pnpm') is not None
            
            # 优先使用 pnpm,然后 yarn,最后 npm
            if has_pnpm and (package_dir / 'pnpm-lock.yaml').exists():
                cmd = ['pnpm', 'install']
                if offline:
                    cmd.append('--offline')
            elif has_yarn and (package_dir / 'yarn.lock').exists():
                cmd = ['yarn', 'install']
                if offline:
                    cmd.append('--offline')
            elif has_npm:
                cmd = ['npm', 'install']
                if offline:
                    cmd.extend(['--offline', '--prefer-offline'])
            else:
                print("  ✗ 未找到包管理器 (npm/yarn/pnpm)")
                return False
            
            print(f"  执行: {' '.join(cmd)}")
            print(f"  工作目录: {package_dir}")
            print(f"  Registry: {registry}")
            
            result = subprocess.run(
                cmd,
                cwd=package_dir,
                env=env,
                capture_output=True,
                text=True,
                timeout=600  # 10分钟超时
            )
            
            if result.returncode == 0:
                print(f"  ✓ 依赖安装成功: {package_file.relative_to(self.project_root)}")
                
                # 复制 node_modules 到缓存(可选)
                self._cache_node_modules(package_dir)
                
                return True
            else:
                print(f"  ✗ 依赖安装失败: {package_file.relative_to(self.project_root)}")
                if result.stderr:
                    print(f"    错误: {result.stderr}")
                return False
                
        except subprocess.TimeoutExpired:
            print(f"  ✗ 依赖安装超时: {package_file.relative_to(self.project_root)}")
            return False
        except Exception as e:
            print(f"  ✗ 依赖安装异常: {e}")
            return False
    
    def _cache_node_modules(self, package_dir: Path):
        """缓存 node_modules 目录"""
        node_modules = package_dir / 'node_modules'
        if not node_modules.exists():
            return
        
        # 创建缓存中的 node_modules 链接
        cache_modules = self.nodejs_cache / 'node_modules'
        cache_modules.mkdir(parents=True, exist_ok=True)
        
        # 复制常用的包到缓存
        # 注意: 这里不复制全部,因为 node_modules 可能很大
        common_packages = ['react', 'react-dom', 'typescript', 'vite', 'webpack']
        
        for pkg in common_packages:
            src = node_modules / pkg
            dst = cache_modules / pkg
            if src.exists() and not dst.exists():
                try:
                    if src.is_symlink() or src.is_dir():
                        shutil.copytree(src, dst, symlinks=True, ignore=shutil.ignore_patterns('node_modules'))
                except Exception as e:
                    if self.config.get('verbose'):
                        print(f"    缓存 {pkg} 失败: {e}")
    
    def clean_cache(self, older_than_days: Optional[int] = None):
        """清理缓存"""
        if older_than_days:
            cutoff_time = datetime.now().timestamp() - (older_than_days * 86400)
            
            # NPM 缓存使用 _cacache 结构
            cacache_dir = self.npm_cache / '_cacache'
            if cacache_dir.exists():
                for content_dir in cacache_dir.rglob('*'):
                    if content_dir.is_file():
                        if content_dir.stat().st_mtime < cutoff_time:
                            content_dir.unlink()
        else:
            if self.npm_cache.exists():
                print(f"  清理 NPM 缓存: {self.npm_cache}")
                shutil.rmtree(self.npm_cache)
                self.npm_cache.mkdir(parents=True, exist_ok=True)
            
            cache_modules = self.nodejs_cache / 'node_modules'
            if cache_modules.exists():
                print(f"  清理缓存的 node_modules: {cache_modules}")
                shutil.rmtree(cache_modules)
    
    def get_cache_size(self) -> int:
        """获取缓存大小(字节) - 包括本地缓存和系统缓存"""
        total_size = 0

        # 统计本地缓存
        for cache_root in [self.npm_cache, self.nodejs_cache / 'node_modules']:
            if cache_root.exists():
                for file_path in cache_root.rglob('*'):
                    if file_path.is_file():
                        total_size += file_path.stat().st_size

        # 统计系统 NPM 缓存
        system_cache = self.get_system_npm_cache()
        if system_cache.exists():
            for file_path in system_cache.rglob('*'):
                if file_path.is_file():
                    total_size += file_path.stat().st_size

        return total_size

    def get_cached_package_count(self) -> int:
        """获取已缓存的包数量 - 包括本地缓存和系统缓存"""
        cached_packages = set()

        # 检查本地缓存的 node_modules
        cache_modules = self.nodejs_cache / 'node_modules'
        if cache_modules.exists():
            for item in cache_modules.iterdir():
                if item.is_dir() and not item.name.startswith('.'):
                    cached_packages.add(item.name)

        # 检查系统缓存（通过 _cacache 的内容哈希难以直接统计包数量，返回估算值）
        # NPM 缓存使用内容寻址，不易直接统计包数量

        return len(cached_packages)
    
    def get_stats(self) -> Dict:
        """获取缓存统计信息"""
        package_files = self.find_package_json_files()
        
        total_deps = 0
        cached_deps = 0
        all_missing = []
        
        for package_file in package_files:
            cached, total, missing = self.check_cached_packages(package_file)
            total_deps += total
            cached_deps += cached
            all_missing.extend(missing)
        
        return {
            'package_files': len(package_files),
            'total_dependencies': total_deps,
            'cached_dependencies': cached_deps,
            'missing_dependencies': len(all_missing),
            'missing_packages': all_missing[:10],
            'cache_size_bytes': self.get_cache_size(),
            'cache_size_mb': round(self.get_cache_size() / (1024 * 1024), 2)
        }
