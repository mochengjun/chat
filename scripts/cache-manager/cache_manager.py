#!/usr/bin/env python3
"""
智能编译缓存工具 - 主程序
企业级安全聊天应用依赖项缓存管理系统

使用方法:
    python cache_manager.py check [--project {flutter,go,nodejs,all}]
    python cache_manager.py sync [--project {flutter,go,nodejs,all}] [--offline]
    python cache_manager.py clean [--project {flutter,go,nodejs,all}] [--older-than DAYS]
    python cache_manager.py stats
"""

import os
import sys
import argparse
from pathlib import Path
from typing import Optional

# 添加当前目录到 Python 路径
sys.path.insert(0, str(Path(__file__).parent))

from cache_config import CacheConfig
from flutter_cache import FlutterCacheManager
from go_cache import GoCacheManager
from nodejs_cache import NodeJSCacheManager
from cache_index import CacheIndex


class CacheManager:
    """智能编译缓存管理器"""
    
    def __init__(self, project_root: Optional[Path] = None):
        # 确定项目根目录
        if project_root:
            self.project_root = Path(project_root)
        else:
            # 从脚本位置推断项目根目录
            self.project_root = Path(__file__).parent.parent.parent
        
        # 加载配置
        self.config = CacheConfig(self.project_root)
        
        # 获取缓存目录
        self.cache_dir = self.config.get_cache_dir()
        print(f"缓存目录: {self.cache_dir}")
        
        # 初始化缓存管理器
        self.flutter_manager = None
        self.go_manager = None
        self.nodejs_manager = None
        self.index = None
        
        self._init_managers()
    
    def _init_managers(self):
        """初始化各个技术栈的缓存管理器"""
        # 初始化索引
        self.index = CacheIndex(self.cache_dir)
        
        # Flutter
        if self.config.is_enabled('flutter'):
            self.flutter_manager = FlutterCacheManager(
                self.project_root,
                self.cache_dir,
                self.config.get_flutter_config()
            )
        
        # Go
        if self.config.is_enabled('go'):
            self.go_manager = GoCacheManager(
                self.project_root,
                self.cache_dir,
                self.config.get_go_config()
            )
        
        # Node.js
        if self.config.is_enabled('nodejs'):
            self.nodejs_manager = NodeJSCacheManager(
                self.project_root,
                self.cache_dir,
                self.config.get_nodejs_config()
            )
    
    def check(self, project: str = "all", verbose: bool = False):
        """检查缓存状态"""
        print("\n" + "="*60)
        print("缓存状态检查")
        print("="*60 + "\n")
        
        results = {}
        
        # Flutter
        if project in ["flutter", "all"] and self.flutter_manager:
            print("[Flutter] 检查依赖缓存...")
            stats = self.flutter_manager.get_stats()
            results['flutter'] = stats
            
            print(f"  Pubspec 文件数: {stats['pubspec_files']}")
            print(f"  总依赖数: {stats['total_dependencies']}")
            print(f"  已缓存: {stats['cached_dependencies']}")
            print(f"  缺失: {stats['missing_dependencies']}")
            print(f"  缓存大小: {stats['cache_size_mb']:.2f} MB")
            
            if verbose and stats['missing_packages']:
                print("  缺失的包:")
                for pkg in stats['missing_packages']:
                    print(f"    - {pkg}")
            print()
        
        # Go
        if project in ["go", "all"] and self.go_manager:
            print("[Go] 检查模块缓存...")
            stats = self.go_manager.get_stats()
            results['go'] = stats
            
            print(f"  go.mod 文件数: {stats['go_mod_files']}")
            print(f"  总依赖数: {stats['total_dependencies']}")
            print(f"  已缓存: {stats['cached_dependencies']}")
            print(f"  缺失: {stats['missing_dependencies']}")
            print(f"  缓存大小: {stats['cache_size_mb']:.2f} MB")
            
            if verbose and stats['missing_packages']:
                print("  缺失的模块:")
                for mod in stats['missing_packages']:
                    print(f"    - {mod}")
            print()
        
        # Node.js
        if project in ["nodejs", "all"] and self.nodejs_manager:
            print("[Node.js] 检查包缓存...")
            stats = self.nodejs_manager.get_stats()
            results['nodejs'] = stats
            
            print(f"  package.json 文件数: {stats['package_files']}")
            print(f"  总依赖数: {stats['total_dependencies']}")
            print(f"  已缓存: {stats['cached_dependencies']}")
            print(f"  缺失: {stats['missing_dependencies']}")
            print(f"  缓存大小: {stats['cache_size_mb']:.2f} MB")
            
            if verbose and stats['missing_packages']:
                print("  缺失的包:")
                for pkg in stats['missing_packages']:
                    print(f"    - {pkg}")
            print()
        
        return results
    
    def sync(self, project: str = "all", offline: bool = False, force: bool = False):
        """同步依赖到缓存"""
        offline = offline or self.config.is_offline_mode()
        
        print("\n" + "="*60)
        print(f"同步依赖缓存 {'[离线模式]' if offline else '[在线模式]'}")
        print("="*60 + "\n")
        
        results = {
            'success': 0,
            'failed': 0,
            'skipped': 0
        }
        
        # Flutter
        if project in ["flutter", "all"] and self.flutter_manager:
            print("[Flutter] 同步依赖...")
            pubspec_files = self.flutter_manager.find_pubspec_files()
            
            for pubspec_file in pubspec_files:
                # 检查是否需要同步
                if not force:
                    cached, total, missing = self.flutter_manager.check_cached_packages(pubspec_file)
                    if not missing:
                        print(f"  跳过 (已缓存): {pubspec_file.relative_to(self.project_root)}")
                        results['skipped'] += 1
                        continue
                
                success = self.flutter_manager.sync_dependencies(pubspec_file, offline)
                if success:
                    results['success'] += 1
                    # 更新索引
                    pubspec = self.flutter_manager.parse_pubspec(pubspec_file)
                    for pkg_name, pkg_version in pubspec.get('dependencies', {}).items():
                        self.index.add_flutter_package(pkg_name, pkg_version)
                else:
                    results['failed'] += 1
            print()
        
        # Go
        if project in ["go", "all"] and self.go_manager:
            print("[Go] 同步模块...")
            go_mod_files = self.go_manager.find_go_mod_files()
            
            for go_mod_file in go_mod_files:
                # 检查是否需要同步
                if not force:
                    cached, total, missing = self.go_manager.check_cached_modules(go_mod_file)
                    if not missing:
                        print(f"  跳过 (已缓存): {go_mod_file.relative_to(self.project_root)}")
                        results['skipped'] += 1
                        continue
                
                success = self.go_manager.sync_dependencies(go_mod_file, offline)
                if success:
                    results['success'] += 1
                    # 更新索引
                    modules = self.go_manager.parse_go_mod(go_mod_file)
                    for dep in modules.get('dependencies', []):
                        self.index.add_go_module(dep['module'], dep['version'])
                else:
                    results['failed'] += 1
            print()
        
        # Node.js
        if project in ["nodejs", "all"] and self.nodejs_manager:
            print("[Node.js] 同步包...")
            package_files = self.nodejs_manager.find_package_json_files()
            
            for package_file in package_files:
                # 检查是否需要同步
                if not force:
                    cached, total, missing = self.nodejs_manager.check_cached_packages(package_file)
                    if not missing:
                        print(f"  跳过 (已缓存): {package_file.relative_to(self.project_root)}")
                        results['skipped'] += 1
                        continue
                
                success = self.nodejs_manager.sync_dependencies(package_file, offline)
                if success:
                    results['success'] += 1
                    # 更新索引
                    package_data = self.nodejs_manager.parse_package_json(package_file)
                    for pkg_name, pkg_version in package_data.get('dependencies', {}).items():
                        self.index.add_nodejs_package(pkg_name, pkg_version)
                else:
                    results['failed'] += 1
            print()
        
        # 保存索引
        self.index.save()
        
        print("同步结果:")
        print(f"  成功: {results['success']}")
        print(f"  失败: {results['failed']}")
        print(f"  跳过: {results['skipped']}")
        
        return results
    
    def clean(self, project: str = "all", older_than_days: Optional[int] = None):
        """清理缓存"""
        print("\n" + "="*60)
        print("清理缓存")
        print("="*60 + "\n")
        
        # Flutter
        if project in ["flutter", "all"] and self.flutter_manager:
            print("[Flutter] 清理缓存...")
            self.flutter_manager.clean_cache(older_than_days)
            print()
        
        # Go
        if project in ["go", "all"] and self.go_manager:
            print("[Go] 清理缓存...")
            self.go_manager.clean_cache(older_than_days)
            print()
        
        # Node.js
        if project in ["nodejs", "all"] and self.nodejs_manager:
            print("[Node.js] 清理缓存...")
            self.nodejs_manager.clean_cache(older_than_days)
            print()
        
        # 清理索引
        if older_than_days:
            cleaned = self.index.cleanup_old_entries(older_than_days)
            print(f"[索引] 清理了 {cleaned} 条过期记录")
        
        self.index.save()
        print("缓存清理完成")
    
    def stats(self):
        """显示缓存统计信息"""
        print("\n" + "="*60)
        print("缓存统计信息")
        print("="*60 + "\n")

        # 实际缓存统计（扫描缓存目录）
        print("[实际缓存统计]")

        total_size = 0

        # Flutter 统计
        if self.flutter_manager:
            flutter_stats = self.flutter_manager.get_stats()
            flutter_size = self.flutter_manager.get_cache_size()
            flutter_packages = self.flutter_manager.get_cached_package_count()
            total_size += flutter_size

            print(f"  [Flutter]")
            print(f"    已缓存包数: {flutter_packages}")
            print(f"    项目依赖数: {flutter_stats['cached_dependencies']}/{flutter_stats['total_dependencies']}")
            print(f"    缓存大小: {flutter_size / (1024*1024):.2f} MB")

        # Go 统计
        if self.go_manager:
            go_stats = self.go_manager.get_stats()
            go_size = self.go_manager.get_cache_size()
            go_modules = self.go_manager.get_cached_module_count()
            total_size += go_size

            print(f"  [Go]")
            print(f"    已缓存模块数: {go_modules}")
            print(f"    缓存大小: {go_size / (1024*1024):.2f} MB")

        # Node.js 统计
        if self.nodejs_manager:
            nodejs_stats = self.nodejs_manager.get_stats()
            nodejs_size = self.nodejs_manager.get_cache_size()
            nodejs_packages = self.nodejs_manager.get_cached_package_count()
            total_size += nodejs_size

            print(f"  [Node.js]")
            print(f"    已缓存包数: {nodejs_packages}")
            print(f"    缓存大小: {nodejs_size / (1024*1024):.2f} MB")

        print()
        print(f"  总缓存大小: {total_size / (1024*1024):.2f} MB ({total_size / (1024*1024*1024):.2f} GB)")

        # 缓存索引统计（仅作为参考）
        print()
        print("[缓存索引]")
        index_stats = self.index.get_stats()
        print(f"  索引条目数: {index_stats['total_entries']}")
        print(f"  历史记录数: {index_stats['history_records']}")
        print(f"  最后更新: {index_stats['last_updated']}")

        # 共享依赖
        shared = self.index.find_shared_dependencies()
        if shared:
            print()
            print("[共享依赖] 跨项目共享的依赖:")
            for package, info in list(shared.items())[:10]:
                print(f"  {package} ({info['tech_stack']}): {info['usage_count']} 次使用")

        # 最近历史
        if self.index.get_recent_history(1):
            print()
            print("[最近活动]")
            for record in self.index.get_recent_history(5):
                action = record['action']
                pkg = record.get('package', '')
                version = record.get('version', '')
                timestamp = record['timestamp']
                print(f"  [{timestamp}] {record['tech_stack']}: {action} {pkg}@{version}")


def main():
    """主函数"""
    parser = argparse.ArgumentParser(
        description="智能编译缓存工具",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  %(prog)s check                    # 检查所有项目的缓存状态
  %(prog)s check --project flutter  # 只检查 Flutter 项目
  %(prog)s sync --offline           # 离线模式同步所有依赖
  %(prog)s clean --older-than 30    # 清理30天前的缓存
  %(prog)s stats                    # 显示缓存统计信息
        """
    )
    
    subparsers = parser.add_subparsers(dest='command', help='可用命令')
    
    # check 命令
    check_parser = subparsers.add_parser('check', help='检查缓存状态')
    check_parser.add_argument('--project', choices=['flutter', 'go', 'nodejs', 'all'],
                             default='all', help='指定项目类型')
    check_parser.add_argument('--verbose', '-v', action='store_true',
                             help='显示详细信息')
    
    # sync 命令
    sync_parser = subparsers.add_parser('sync', help='同步依赖到缓存')
    sync_parser.add_argument('--project', choices=['flutter', 'go', 'nodejs', 'all'],
                            default='all', help='指定项目类型')
    sync_parser.add_argument('--offline', action='store_true',
                            help='离线模式')
    sync_parser.add_argument('--force', action='store_true',
                            help='强制重新下载')
    
    # clean 命令
    clean_parser = subparsers.add_parser('clean', help='清理缓存')
    clean_parser.add_argument('--project', choices=['flutter', 'go', 'nodejs', 'all'],
                             default='all', help='指定项目类型')
    clean_parser.add_argument('--older-than', type=int,
                             help='清理超过指定天数的缓存')
    
    # stats 命令
    subparsers.add_parser('stats', help='显示缓存统计信息')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    # 创建缓存管理器
    manager = CacheManager()
    
    # 执行命令
    if args.command == 'check':
        manager.check(args.project, args.verbose)
    elif args.command == 'sync':
        manager.sync(args.project, args.offline, args.force)
    elif args.command == 'clean':
        manager.clean(args.project, args.older_than)
    elif args.command == 'stats':
        manager.stats()


if __name__ == '__main__':
    main()
