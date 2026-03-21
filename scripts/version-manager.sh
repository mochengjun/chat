#!/bin/bash
# ============================================================
# 版本管理脚本
# 用于统一管理项目各组件的版本号
# ============================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# 版本文件路径
FLUTTER_PUBSPEC="$PROJECT_ROOT/apps/flutter_app/pubspec.yaml"
WEB_PACKAGE="$PROJECT_ROOT/web-client/package.json"
AUTH_SERVICE_VERSION="$PROJECT_ROOT/services/auth-service/internal/version/version.go"

# 帮助信息
show_help() {
    echo "用法: $0 <命令> [选项]"
    echo ""
    echo "命令:"
    echo "  current           显示当前版本号"
    echo "  bump <类型>       递增版本号 (major|minor|patch)"
    echo "  set <版本号>      设置指定版本号"
    echo "  sync              同步所有组件版本号"
    echo "  validate          验证版本号一致性"
    echo "  changelog         生成变更日志"
    echo ""
    echo "选项:"
    echo "  -h, --help        显示帮助信息"
    echo "  -c, --component   指定组件 (flutter|web|auth|all)"
    echo "  -v, --verbose     显示详细输出"
    echo ""
    echo "示例:"
    echo "  $0 current                    # 显示当前版本"
    echo "  $0 bump minor                 # 次版本号递增"
    echo "  $0 set v1.2.0                 # 设置版本为 v1.2.0"
    echo "  $0 bump patch -c flutter      # 仅更新 Flutter 版本"
}

# 解析语义化版本号
parse_version() {
    local version=$1
    # 移除 v 前缀
    version=${version#v}
    # 移除预发布后缀
    version=${version%%-*}
    
    IFS='.' read -r major minor patch <<< "$version"
    echo "$major $minor $patch"
}

# 获取 Flutter 版本
get_flutter_version() {
    if [ -f "$FLUTTER_PUBSPEC" ]; then
        grep -E "^version:" "$FLUTTER_PUBSPEC" | sed 's/version: //' | cut -d'+' -f1
    else
        echo "未找到"
    fi
}

# 获取 Web 客户端版本
get_web_version() {
    if [ -f "$WEB_PACKAGE" ]; then
        grep -E '"version"' "$WEB_PACKAGE" | sed 's/.*"version": *"\([^"]*\)".*/\1/'
    else
        echo "未找到"
    fi
}

# 获取 Auth Service 版本
get_auth_version() {
    if [ -f "$AUTH_SERVICE_VERSION" ]; then
        grep -E 'Version\s*=' "$AUTH_SERVICE_VERSION" | sed 's/.*Version\s*=\s*"\([^"]*\)".*/\1/'
    else
        echo "未找到"
    fi
}

# 显示当前版本
show_current_version() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}当前版本信息${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    local flutter_ver web_ver auth_ver
    
    flutter_ver=$(get_flutter_version)
    web_ver=$(get_web_version)
    auth_ver=$(get_auth_version)
    
    echo -e "Flutter App:      ${GREEN}$flutter_ver${NC}"
    echo -e "Web Client:       ${GREEN}$web_ver${NC}"
    echo -e "Auth Service:     ${GREEN}$auth_ver${NC}"
    echo ""
}

# 更新 Flutter 版本
update_flutter_version() {
    local version=$1
    local build_number=$2
    
    if [ -f "$FLUTTER_PUBSPEC" ]; then
        # 获取当前构建号
        if [ -z "$build_number" ]; then
            local current_ver
            current_ver=$(grep -E "^version:" "$FLUTTER_PUBSPEC" | sed 's/version: //')
            build_number=$(echo "$current_ver" | cut -d'+' -f2)
            if [ -z "$build_number" ] || [ "$build_number" = "$current_ver" ]; then
                build_number=1
            else
                build_number=$((build_number + 1))
            fi
        fi
        
        # 更新版本号
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/^version:.*/version: ${version}+${build_number}/" "$FLUTTER_PUBSPEC"
        else
            sed -i "s/^version:.*/version: ${version}+${build_number}/" "$FLUTTER_PUBSPEC"
        fi
        
        echo -e "${GREEN}✓ Flutter 版本已更新: ${version}+${build_number}${NC}"
    else
        echo -e "${YELLOW}! 未找到 Flutter pubspec.yaml${NC}"
    fi
}

# 更新 Web 客户端版本
update_web_version() {
    local version=$1
    
    if [ -f "$WEB_PACKAGE" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/\"version\": *\"[^\"]*\"/\"version\": \"${version}\"/" "$WEB_PACKAGE"
        else
            sed -i "s/\"version\": *\"[^\"]*\"/\"version\": \"${version}\"/" "$WEB_PACKAGE"
        fi
        
        echo -e "${GREEN}✓ Web Client 版本已更新: ${version}${NC}"
    else
        echo -e "${YELLOW}! 未找到 Web package.json${NC}"
    fi
}

# 更新 Auth Service 版本
update_auth_version() {
    local version=$1
    
    if [ -f "$AUTH_SERVICE_VERSION" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/Version\s*=\s*\"[^\"]*\"/Version = \"${version}\"/" "$AUTH_SERVICE_VERSION"
        else
            sed -i "s/Version\s*=\s*\"[^\"]*\"/Version = \"${version}\"/" "$AUTH_SERVICE_VERSION"
        fi
        
        echo -e "${GREEN}✓ Auth Service 版本已更新: ${version}${NC}"
    else
        echo -e "${YELLOW}! 未找到 version.go，将创建新文件${NC}"
        mkdir -p "$(dirname "$AUTH_SERVICE_VERSION")"
        cat > "$AUTH_SERVICE_VERSION" << EOF
package version

var (
    Version   = "${version}"
    GitCommit = ""
    BuildTime = ""
)
EOF
        echo -e "${GREEN}✓ 已创建 version.go: ${version}${NC}"
    fi
}

# 递增版本号
bump_version() {
    local bump_type=$1
    local component=${2:-all}
    
    # 获取当前版本
    local current_version
    current_version=$(get_flutter_version)
    
    if [ "$current_version" = "未找到" ]; then
        current_version="0.0.0"
    fi
    
    # 解析版本号
    read -r major minor patch <<< "$(parse_version "$current_version")"
    
    # 根据类型递增
    case $bump_type in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            echo -e "${RED}错误: 未知的递增类型 '$bump_type'${NC}"
            echo "可用类型: major, minor, patch"
            exit 1
            ;;
    esac
    
    local new_version="${major}.${minor}.${patch}"
    
    echo -e "${BLUE}版本递增: ${current_version} -> ${new_version}${NC}"
    
    # 更新版本
    case $component in
        flutter)
            update_flutter_version "$new_version"
            ;;
        web)
            update_web_version "$new_version"
            ;;
        auth)
            update_auth_version "$new_version"
            ;;
        all)
            update_flutter_version "$new_version"
            update_web_version "$new_version"
            update_auth_version "$new_version"
            ;;
        *)
            echo -e "${RED}错误: 未知的组件 '$component'${NC}"
            echo "可用组件: flutter, web, auth, all"
            exit 1
            ;;
    esac
}

# 设置指定版本号
set_version() {
    local version=$1
    local component=${2:-all}
    
    # 移除 v 前缀
    version=${version#v}
    
    # 验证版本号格式
    if ! [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
        echo -e "${RED}错误: 版本号格式无效 '$version'${NC}"
        echo "正确格式: X.Y.Z 或 X.Y.Z-预发布标识"
        echo "示例: 1.0.0, 1.0.0-beta.1"
        exit 1
    fi
    
    echo -e "${BLUE}设置版本: ${version}${NC}"
    
    # 更新版本
    case $component in
        flutter)
            update_flutter_version "$version"
            ;;
        web)
            update_web_version "$version"
            ;;
        auth)
            update_auth_version "$version"
            ;;
        all)
            update_flutter_version "$version"
            update_web_version "$version"
            update_auth_version "$version"
            ;;
        *)
            echo -e "${RED}错误: 未知的组件 '$component'${NC}"
            exit 1
            ;;
    esac
}

# 验证版本号一致性
validate_versions() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}版本一致性验证${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    local flutter_ver web_ver auth_ver
    flutter_ver=$(get_flutter_version)
    web_ver=$(get_web_version)
    auth_ver=$(get_auth_version)
    
    # 移除构建号
    flutter_ver=${flutter_ver%%+*}
    
    local consistent=true
    
    if [ "$flutter_ver" != "$web_ver" ]; then
        echo -e "${YELLOW}! Flutter ($flutter_ver) 与 Web ($web_ver) 版本不一致${NC}"
        consistent=false
    fi
    
    if [ "$flutter_ver" != "$auth_ver" ]; then
        echo -e "${YELLOW}! Flutter ($flutter_ver) 与 Auth ($auth_ver) 版本不一致${NC}"
        consistent=false
    fi
    
    if [ "$web_ver" != "$auth_ver" ]; then
        echo -e "${YELLOW}! Web ($web_ver) 与 Auth ($auth_ver) 版本不一致${NC}"
        consistent=false
    fi
    
    if [ "$consistent" = true ]; then
        echo -e "${GREEN}✓ 所有组件版本一致: ${flutter_ver}${NC}"
    else
        echo ""
        echo -e "${YELLOW}建议运行 '$0 sync' 同步版本号${NC}"
    fi
}

# 同步版本号
sync_versions() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}同步版本号${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    local flutter_ver
    flutter_ver=$(get_flutter_version)
    flutter_ver=${flutter_ver%%+*}
    
    echo -e "使用 Flutter 版本作为基准: ${flutter_ver}"
    
    update_web_version "$flutter_ver"
    update_auth_version "$flutter_ver"
    
    echo ""
    echo -e "${GREEN}✓ 版本同步完成${NC}"
    show_current_version
}

# 生成变更日志
generate_changelog() {
    local version=$1
    
    if [ -z "$version" ]; then
        version=$(get_flutter_version)
        version=${version%%+*}
    fi
    
    echo -e "${BLUE}生成变更日志: ${version}${NC}"
    
    # 获取上一个标签
    local prev_tag
    prev_tag=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")
    
    local changelog_file="$PROJECT_ROOT/CHANGELOG.md"
    local temp_file=$(mktemp)
    
    # 写入新版本记录
    {
        echo "## [$version] - $(date +%Y-%m-%d)"
        echo ""
        
        if [ -n "$prev_tag" ]; then
            echo "### 变更"
            git log --pretty=format:"- %s" "$prev_tag"..HEAD | head -20
            echo ""
        fi
        
        echo ""
    } > "$temp_file"
    
    # 合并到现有 CHANGELOG
    if [ -f "$changelog_file" ]; then
        # 在 Unreleased 后插入新版本
        if grep -q "## \[Unreleased\]" "$changelog_file"; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' '/## \[Unreleased\]/r '"$temp_file" "$changelog_file"
            else
                sed -i '/## \[Unreleased\]/r '"$temp_file" "$changelog_file"
            fi
        else
            # 在文件开头插入
            {
                cat "$temp_file"
                cat "$changelog_file"
            } > "${changelog_file}.new"
            mv "${changelog_file}.new" "$changelog_file"
        fi
    else
        {
            echo "# Changelog"
            echo ""
            echo "## [Unreleased]"
            echo ""
            cat "$temp_file"
        } > "$changelog_file"
    fi
    
    rm "$temp_file"
    
    echo -e "${GREEN}✓ 变更日志已生成${NC}"
}

# 解析命令行参数
COMMAND=""
COMPONENT="all"
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--component)
            COMPONENT="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        current|bump|set|sync|validate|changelog)
            COMMAND="$1"
            shift
            ;;
        *)
            # 参数值
            if [ -z "$COMMAND_ARG" ]; then
                COMMAND_ARG="$1"
            fi
            shift
            ;;
    esac
done

# 执行命令
case $COMMAND in
    current)
        show_current_version
        ;;
    bump)
        if [ -z "$COMMAND_ARG" ]; then
            echo -e "${RED}错误: 请指定递增类型 (major|minor|patch)${NC}"
            exit 1
        fi
        bump_version "$COMMAND_ARG" "$COMPONENT"
        ;;
    set)
        if [ -z "$COMMAND_ARG" ]; then
            echo -e "${RED}错误: 请指定版本号${NC}"
            exit 1
        fi
        set_version "$COMMAND_ARG" "$COMPONENT"
        ;;
    sync)
        sync_versions
        ;;
    validate)
        validate_versions
        ;;
    changelog)
        generate_changelog "$COMMAND_ARG"
        ;;
    "")
        show_help
        ;;
    *)
        echo -e "${RED}错误: 未知命令 '$COMMAND'${NC}"
        show_help
        exit 1
        ;;
esac
