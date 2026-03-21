"""
缓存索引和历史记录管理模块
"""
import json
import os
from pathlib import Path
from typing import Dict, List, Optional, Any
from datetime import datetime
import hashlib


class CacheIndex:
    """缓存索引和历史记录管理器"""
    
    def __init__(self, cache_dir: Path):
        self.cache_dir = Path(cache_dir)
        self.index_file = self.cache_dir / "index.json"
        self.history_file = self.cache_dir / "history.json"
        
        # 确保缓存目录存在
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        
        # 加载索引
        self.index = self._load_index()
        self.history = self._load_history()
    
    def _load_index(self) -> Dict:
        """加载缓存索引"""
        if self.index_file.exists():
            try:
                with open(self.index_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except Exception as e:
                print(f"加载缓存索引失败: {e}")
        return {
            "version": "1.0",
            "created": datetime.now().isoformat(),
            "last_updated": datetime.now().isoformat(),
            "flutter": {},
            "go": {},
            "nodejs": {}
        }
    
    def _load_history(self) -> List[Dict]:
        """加载历史记录"""
        if self.history_file.exists():
            try:
                with open(self.history_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except Exception as e:
                print(f"加载历史记录失败: {e}")
        return []
    
    def save(self):
        """保存索引和历史记录"""
        # 更新时间戳
        self.index["last_updated"] = datetime.now().isoformat()
        
        # 保存索引
        with open(self.index_file, 'w', encoding='utf-8') as f:
            json.dump(self.index, f, indent=2, ensure_ascii=False)
        
        # 保存历史记录(最近1000条)
        with open(self.history_file, 'w', encoding='utf-8') as f:
            json.dump(self.history[-1000:], f, indent=2, ensure_ascii=False)
    
    def add_flutter_package(self, package_name: str, version: str, 
                           source: str = "pub.dev", metadata: Optional[Dict] = None):
        """添加 Flutter 包索引"""
        key = f"{package_name}@{version}"
        self.index["flutter"][key] = {
            "name": package_name,
            "version": version,
            "source": source,
            "cached_at": datetime.now().isoformat(),
            "metadata": metadata or {}
        }
        
        # 添加历史记录
        self._add_history("flutter", "add", package_name, version, source)
    
    def add_go_module(self, module_path: str, version: str, 
                     source: str = "proxy.golang.org", metadata: Optional[Dict] = None):
        """添加 Go 模块索引"""
        key = f"{module_path}@{version}"
        self.index["go"][key] = {
            "path": module_path,
            "version": version,
            "source": source,
            "cached_at": datetime.now().isoformat(),
            "metadata": metadata or {}
        }
        
        # 添加历史记录
        self._add_history("go", "add", module_path, version, source)
    
    def add_nodejs_package(self, package_name: str, version: str, 
                          source: str = "npmjs.com", metadata: Optional[Dict] = None):
        """添加 Node.js 包索引"""
        key = f"{package_name}@{version}"
        self.index["nodejs"][key] = {
            "name": package_name,
            "version": version,
            "source": source,
            "cached_at": datetime.now().isoformat(),
            "metadata": metadata or {}
        }
        
        # 添加历史记录
        self._add_history("nodejs", "add", package_name, version, source)
    
    def _add_history(self, tech_stack: str, action: str, package: str, 
                    version: str, source: str, details: Optional[Dict] = None):
        """添加历史记录"""
        record = {
            "timestamp": datetime.now().isoformat(),
            "tech_stack": tech_stack,
            "action": action,
            "package": package,
            "version": version,
            "source": source,
            "details": details or {}
        }
        self.history.append(record)
    
    def get_flutter_package(self, package_name: str, version: str) -> Optional[Dict]:
        """获取 Flutter 包信息"""
        key = f"{package_name}@{version}"
        return self.index["flutter"].get(key)
    
    def get_go_module(self, module_path: str, version: str) -> Optional[Dict]:
        """获取 Go 模块信息"""
        key = f"{module_path}@{version}"
        return self.index["go"].get(key)
    
    def get_nodejs_package(self, package_name: str, version: str) -> Optional[Dict]:
        """获取 Node.js 包信息"""
        key = f"{package_name}@{version}"
        return self.index["nodejs"].get(key)
    
    def find_cached_versions(self, tech_stack: str, package_name: str) -> List[str]:
        """查找已缓存的包版本"""
        versions = []
        prefix = f"{package_name}@"
        
        for key in self.index.get(tech_stack, {}).keys():
            if key.startswith(prefix):
                version = key[len(prefix):]
                versions.append(version)
        
        return sorted(versions, reverse=True)
    
    def remove_entry(self, tech_stack: str, package: str, version: str):
        """移除索引条目"""
        key = f"{package}@{version}"
        if key in self.index.get(tech_stack, {}):
            del self.index[tech_stack][key]
            self._add_history(tech_stack, "remove", package, version, "")
    
    def get_stats(self) -> Dict:
        """获取统计信息"""
        return {
            "flutter_packages": len(self.index["flutter"]),
            "go_modules": len(self.index["go"]),
            "nodejs_packages": len(self.index["nodejs"]),
            "total_entries": sum([
                len(self.index["flutter"]),
                len(self.index["go"]),
                len(self.index["nodejs"])
            ]),
            "history_records": len(self.history),
            "created": self.index.get("created"),
            "last_updated": self.index.get("last_updated")
        }
    
    def get_recent_history(self, limit: int = 20) -> List[Dict]:
        """获取最近的历史记录"""
        return self.history[-limit:]
    
    def get_project_dependencies(self, project_path: str) -> Dict[str, List[str]]:
        """获取项目的依赖列表"""
        dependencies = {
            "flutter": [],
            "go": [],
            "nodejs": []
        }
        
        # 根据项目路径查找相关依赖
        for record in reversed(self.history):
            if "project_path" in record.get("details", {}):
                if record["details"]["project_path"] == project_path:
                    pkg = f"{record['package']}@{record['version']}"
                    if pkg not in dependencies[record["tech_stack"]]:
                        dependencies[record["tech_stack"]].append(pkg)
        
        return dependencies
    
    def find_shared_dependencies(self) -> Dict[str, List[Dict]]:
        """查找项目间共享的依赖"""
        # 统计每个包被引用的次数
        package_usage = {}
        
        for tech_stack in ["flutter", "go", "nodejs"]:
            for key, entry in self.index.get(tech_stack, {}).items():
                package = entry.get("name") or entry.get("path")
                if package:
                    if package not in package_usage:
                        package_usage[package] = {
                            "tech_stack": tech_stack,
                            "versions": set(),
                            "count": 0
                        }
                    package_usage[package]["versions"].add(entry.get("version"))
                    package_usage[package]["count"] += 1
        
        # 筛选出被多个项目使用的包
        shared = {}
        for package, info in package_usage.items():
            if len(info["versions"]) > 1 or info["count"] > 1:
                shared[package] = {
                    "tech_stack": info["tech_stack"],
                    "versions": list(info["versions"]),
                    "usage_count": info["count"]
                }
        
        return shared
    
    def cleanup_old_entries(self, days: int = 30):
        """清理过期的索引条目"""
        cutoff_time = datetime.now().timestamp() - (days * 86400)
        cleaned = 0
        
        for tech_stack in ["flutter", "go", "nodejs"]:
            to_remove = []
            for key, entry in self.index.get(tech_stack, {}).items():
                cached_at = entry.get("cached_at")
                if cached_at:
                    try:
                        cache_time = datetime.fromisoformat(cached_at).timestamp()
                        if cache_time < cutoff_time:
                            to_remove.append(key)
                    except Exception:
                        pass
            
            for key in to_remove:
                del self.index[tech_stack][key]
                cleaned += 1
        
        if cleaned > 0:
            self._add_history("system", "cleanup", "", "", "", {"removed_count": cleaned})
        
        return cleaned
    
    def export_index(self, output_file: Path):
        """导出索引到文件"""
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump({
                "index": self.index,
                "stats": self.get_stats()
            }, f, indent=2, ensure_ascii=False)
    
    def import_index(self, input_file: Path, merge: bool = True):
        """从文件导入索引"""
        with open(input_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        if merge:
            # 合并索引
            for tech_stack in ["flutter", "go", "nodejs"]:
                if tech_stack in data.get("index", {}):
                    self.index[tech_stack].update(data["index"][tech_stack])
        else:
            # 替换索引
            self.index = data.get("index", self.index)
        
        self.save()
