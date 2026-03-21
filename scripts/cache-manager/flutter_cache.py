"""
Flutter 依赖缓存管理模块
"""
import os
import json
import shutil
import subprocess
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from datetime import datetime


class FlutterCacheManager:
    """Flutter 依赖缓存管理器"""
    
    def __init__(self, project_root: Path, cache_dir: Path, config: Dict):
        self.project_root = Path(project_root)
        self.cache_dir = Path(cache_dir)
        self.config = config
        self.flutter_cache = self.cache_dir / "flutter"
        self.pub_cache = self.flutter_cache / "pub-cache"
        self.gradle_cache = self.flutter_cache / "gradle-cache"
        
        # 确保缓存目录存在
        self.flutter_cache.mkdir(parents=True, exist_ok=True)
        self.pub_cache.mkdir(parents=True, exist_ok=True)
        self.gradle_cache.mkdir(parents=True, exist_ok=True)
        
    def find_pubspec_files(self) -> List[Path]:
        """查找项目中所有的 pubspec.yaml 文件"""
        pubspec_files = []
        for root, dirs, files in os.walk(self.project_root):
            # 跳过缓存和构建目录
            dirs[:] = [d for d in dirs if d not in ['.cache', 'build', '.dart_tool', '.flutter-plugins']]
            
            if 'pubspec.yaml' in files:
                pubspec_files.append(Path(root) / 'pubspec.yaml')
        return pubspec_files
    
    def parse_pubspec(self, pubspec_file: Path) -> Dict:
        """解析 pubspec.yaml 文件"""
        try:
            import yaml
            with open(pubspec_file, 'r', encoding='utf-8') as f:
                return yaml.safe_load(f)
        except ImportError:
            # 如果没有安装 PyYAML,使用基本解析
            return self._parse_pubspec_basic(pubspec_file)
        except Exception as e:
            print(f"解析 {pubspec_file} 失败: {e}")
            return {}
    
    def _parse_pubspec_basic(self, pubspec_file: Path) -> Dict:
        """基本解析 pubspec.yaml (不需要 PyYAML)"""
        deps = {}
        dev_deps = {}
        try:
            with open(pubspec_file, 'r', encoding='utf-8') as f:
                lines = f.readlines()

            in_deps = False
            in_dev_deps = False
            current_indent = 0

            for i, line in enumerate(lines):
                stripped = line.strip()

                # 跳过空行和注释
                if not stripped or stripped.startswith('#'):
                    continue

                # 计算当前行的缩进级别
                indent = len(line) - len(line.lstrip())

                # 检测区块开始
                if stripped.startswith('dependencies:') and indent == 0:
                    in_deps = True
                    in_dev_deps = False
                    current_indent = indent
                    continue

                if stripped.startswith('dev_dependencies:') and indent == 0:
                    in_deps = False
                    in_dev_deps = True
                    current_indent = indent
                    continue

                # 检测其他顶级区块（结束依赖区块）
                if indent == 0 and stripped.endswith(':') and not stripped.startswith('#'):
                    if in_deps and not stripped.startswith('dependencies'):
                        in_deps = False
                    if in_dev_deps and not stripped.startswith('dev_dependencies'):
                        in_dev_deps = False
                    continue

                # 解析依赖项（必须是区块的直接子项，缩进为2或更多）
                if (in_deps or in_dev_deps) and ':' in stripped:
                    # 确保这是直接子项（比区块标题缩进多）
                    if indent > current_indent:
                        parts = stripped.split(':', 1)
                        if len(parts) == 2:
                            pkg_name = parts[0].strip()
                            pkg_version = parts[1].strip()
                            # 跳过 SDK 依赖（如 flutter sdk）
                            if pkg_name and pkg_name not in ['sdk', 'flutter_test', 'flutter_driver']:
                                if in_deps:
                                    deps[pkg_name] = pkg_version
                                else:
                                    dev_deps[pkg_name] = pkg_version

        except Exception as e:
            print(f"基本解析 {pubspec_file} 失败: {e}")

        return {'dependencies': deps, 'dev_dependencies': dev_deps}
    
    def get_system_pub_cache(self) -> Path:
        """获取系统默认的 Pub 缓存路径"""
        # 环境变量优先
        if 'PUB_CACHE' in os.environ:
            return Path(os.environ['PUB_CACHE'])
        
        # 根据操作系统确定默认路径
        if os.name == 'nt':  # Windows
            return Path(os.environ.get('LOCALAPPDATA', '')) / 'Pub' / 'Cache'
        else:  # macOS / Linux
            return Path.home() / '.pub-cache'
    
    def check_cached_packages(self, pubspec_file: Path) -> Tuple[int, int, List[str]]:
        """
        检查 pubspec.yaml 中依赖的缓存状态
        返回: (已缓存数量, 总依赖数量, 缺失的包列表)
        """
        pubspec = self.parse_pubspec(pubspec_file)
        if not pubspec:
            return 0, 0, []
        
        dependencies = pubspec.get('dependencies', {})
        dev_dependencies = pubspec.get('dev_dependencies', {})
        all_deps = {**dependencies, **dev_dependencies}
        
        # 排除 Flutter SDK 内置包
        excluded = {'flutter', 'flutter_test', 'flutter_driver'}
        all_deps = {k: v for k, v in all_deps.items() if k not in excluded}
        
        total = len(all_deps)
        cached = 0
        missing = []
        
        system_pub_cache = self.get_system_pub_cache()
        
        for pkg_name, pkg_version in all_deps.items():
            # 检查本地缓存
            local_cached = self._check_package_in_cache(pkg_name, pkg_version, self.pub_cache)
            # 检查系统缓存
            system_cached = self._check_package_in_cache(pkg_name, pkg_version, system_pub_cache)
            
            if local_cached or system_cached:
                cached += 1
            else:
                missing.append(f"{pkg_name}: {pkg_version}")
        
        return cached, total, missing
    
    def _check_package_in_cache(self, pkg_name: str, pkg_version: str, cache_path: Path) -> bool:
        """检查包是否存在于缓存中"""
        if not cache_path.exists():
            return False
        
        # 检查 hosted 目录
        hosted_dirs = [
            cache_path / "hosted" / "pub.dev",
            cache_path / "hosted" / "pub.flutter-io.cn",
            cache_path / "hosted" / "dart.pub.dev",
        ]
        
        for hosted_dir in hosted_dirs:
            if not hosted_dir.exists():
                continue
            
            # 包目录名格式: package_name-version
            for pkg_dir in hosted_dir.glob(f"{pkg_name}-*"):
                if pkg_dir.is_dir():
                    # 简化版本检查: 只要包名匹配就算缓存
                    return True
        
        return False
    
    def sync_dependencies(self, pubspec_file: Path, offline: bool = False) -> bool:
        """
        同步 pubspec.yaml 的依赖到本地缓存
        返回: 是否成功
        """
        pubspec_dir = pubspec_file.parent
        
        # 设置环境变量使用本地缓存
        env = os.environ.copy()
        env['PUB_CACHE'] = str(self.pub_cache)
        
        # 配置镜像
        mirrors = self.config.get('mirrors', {})
        if mirrors.get('pub'):
            env['PUB_HOSTED_URL'] = mirrors['pub']
        if mirrors.get('storage'):
            env['FLUTTER_STORAGE_BASE_URL'] = mirrors['storage']
        
        try:
            # 执行 flutter pub get
            cmd = ['flutter', 'pub', 'get']
            if offline:
                cmd.append('--offline')
            
            print(f"  执行: {' '.join(cmd)}")
            print(f"  工作目录: {pubspec_dir}")
            
            result = subprocess.run(
                cmd,
                cwd=pubspec_dir,
                env=env,
                capture_output=True,
                text=True,
                timeout=300  # 5分钟超时
            )
            
            if result.returncode == 0:
                print(f"  ✓ 依赖同步成功: {pubspec_file.relative_to(self.project_root)}")
                return True
            else:
                print(f"  ✗ 依赖同步失败: {pubspec_file.relative_to(self.project_root)}")
                if result.stderr:
                    print(f"    错误: {result.stderr}")
                return False
                
        except subprocess.TimeoutExpired:
            print(f"  ✗ 依赖同步超时: {pubspec_file.relative_to(self.project_root)}")
            return False
        except Exception as e:
            print(f"  ✗ 依赖同步异常: {e}")
            return False
    
    def cache_package(self, pkg_name: str, pkg_version: str) -> bool:
        """缓存指定的包"""
        print(f"缓存包: {pkg_name}@{pkg_version}")
        
        # 使用 flutter pub cache add 命令
        env = os.environ.copy()
        env['PUB_CACHE'] = str(self.pub_cache)
        
        try:
            cmd = ['flutter', 'pub', 'cache', 'add', pkg_name]
            if pkg_version and pkg_version != 'any':
                # 解析版本约束
                if pkg_version.startswith('^') or pkg_version.startswith('>='):
                    cmd.extend(['--version', pkg_version])
            
            result = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=60)
            return result.returncode == 0
        except Exception as e:
            print(f"缓存包失败: {e}")
            return False
    
    def clean_cache(self, older_than_days: Optional[int] = None):
        """清理缓存"""
        if older_than_days:
            # 清理过期的缓存
            cutoff_time = datetime.now().timestamp() - (older_than_days * 86400)
            
            for hosted_dir in [self.pub_cache / "hosted"]:
                if not hosted_dir.exists():
                    continue
                
                for pkg_dir in hosted_dir.rglob('*'):
                    if pkg_dir.is_dir():
                        # 检查目录修改时间
                        if pkg_dir.stat().st_mtime < cutoff_time:
                            print(f"  删除过期缓存: {pkg_dir.name}")
                            shutil.rmtree(pkg_dir)
        else:
            # 清理所有缓存
            if self.pub_cache.exists():
                print(f"  清理 Pub 缓存: {self.pub_cache}")
                shutil.rmtree(self.pub_cache)
                self.pub_cache.mkdir(parents=True, exist_ok=True)
            
            if self.gradle_cache.exists():
                print(f"  清理 Gradle 缓存: {self.gradle_cache}")
                shutil.rmtree(self.gradle_cache)
                self.gradle_cache.mkdir(parents=True, exist_ok=True)
    
    def get_cache_size(self) -> int:
        """获取缓存大小(字节) - 包括本地缓存和系统缓存"""
        total_size = 0

        # 统计本地缓存
        for cache_root in [self.pub_cache, self.gradle_cache]:
            if cache_root.exists():
                for file_path in cache_root.rglob('*'):
                    if file_path.is_file():
                        total_size += file_path.stat().st_size

        # 统计系统 Pub 缓存
        system_pub_cache = self.get_system_pub_cache()
        if system_pub_cache.exists():
            for file_path in system_pub_cache.rglob('*'):
                if file_path.is_file():
                    total_size += file_path.stat().st_size

        return total_size

    def get_cached_package_count(self) -> int:
        """获取已缓存的包数量 - 包括本地缓存和系统缓存"""
        cached_packages = set()

        # 检查本地缓存
        if self.pub_cache.exists():
            hosted_dir = self.pub_cache / "hosted"
            if hosted_dir.exists():
                for source_dir in hosted_dir.iterdir():
                    if source_dir.is_dir():
                        for pkg_dir in source_dir.iterdir():
                            if pkg_dir.is_dir():
                                cached_packages.add(pkg_dir.name)

        # 检查系统缓存
        system_pub_cache = self.get_system_pub_cache()
        if system_pub_cache.exists():
            hosted_dir = system_pub_cache / "hosted"
            if hosted_dir.exists():
                for source_dir in hosted_dir.iterdir():
                    if source_dir.is_dir():
                        for pkg_dir in source_dir.iterdir():
                            if pkg_dir.is_dir():
                                cached_packages.add(pkg_dir.name)

        return len(cached_packages)
    
    def get_stats(self) -> Dict:
        """获取缓存统计信息"""
        pubspec_files = self.find_pubspec_files()
        
        total_deps = 0
        cached_deps = 0
        all_missing = []
        
        for pubspec_file in pubspec_files:
            cached, total, missing = self.check_cached_packages(pubspec_file)
            total_deps += total
            cached_deps += cached
            all_missing.extend(missing)
        
        return {
            'pubspec_files': len(pubspec_files),
            'total_dependencies': total_deps,
            'cached_dependencies': cached_deps,
            'missing_dependencies': len(all_missing),
            'missing_packages': all_missing[:10],  # 只显示前10个
            'cache_size_bytes': self.get_cache_size(),
            'cache_size_mb': round(self.get_cache_size() / (1024 * 1024), 2)
        }
