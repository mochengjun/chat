#!/bin/bash
# ============================================================
# 双仓库同步推送脚本
# 用于同步推送代码到 GitHub 和 Gitee
# ============================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
GITHUB_REMOTE="${GITHUB_REMOTE:-origin}"
GITEE_REMOTE="${GITEE_REMOTE:-gitee}"
GITHUB_REPO="${GITHUB_REPO:-mochengjun/sec-chat}"
GITEE_REPO="${GITEE_REPO:-mochengjun/sec-chat}"

# 帮助信息
show_help() {
    echo "用法: $0 [选项] [分支名]"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示帮助信息"
    echo "  -b, --branch        指定要同步的分支 (默认: 当前分支)"
    echo "  -t, --tags          同步所有标签"
    echo "  -a, --all           同步所有分支和标签"
    echo "  -s, --setup         配置双仓库远程地址"
    echo "  -v, --verbose       显示详细输出"
    echo "  --dry-run           仅显示将要执行的操作，不实际执行"
    echo ""
    echo "示例:"
    echo "  $0                  # 同步当前分支到两个仓库"
    echo "  $0 -b main          # 同步 main 分支"
    echo "  $0 -t               # 同步所有标签"
    echo "  $0 -a               # 同步所有分支和标签"
    echo "  $0 -s               # 配置双仓库远程地址"
    echo ""
    echo "远程仓库:"
    echo "  GitHub: https://github.com/${GITHUB_REPO}"
    echo "  Gitee:  https://gitee.com/${GITEE_REPO}"
}

# 获取当前分支
get_current_branch() {
    git branch --show-current 2>/dev/null || echo "HEAD"
}

# 检查远程仓库是否存在
check_remote() {
    local remote=$1
    if ! git remote | grep -q "^${remote}$"; then
        echo -e "${YELLOW}警告: 远程仓库 '${remote}' 不存在${NC}"
        return 1
    fi
    return 0
}

# 配置双仓库远程地址
setup_remotes() {
    echo -e "${BLUE}配置双仓库远程地址...${NC}"
    
    # 检查并配置 GitHub
    if check_remote "$GITHUB_REMOTE"; then
        echo -e "${GREEN}GitHub 远程仓库已配置${NC}"
    else
        echo "添加 GitHub 远程仓库..."
        git remote add "$GITHUB_REMOTE" "https://github.com/${GITHUB_REPO}.git"
    fi
    
    # 检查并配置 Gitee
    if check_remote "$GITEE_REMOTE"; then
        echo -e "${GREEN}Gitee 远程仓库已配置${NC}"
    else
        echo "添加 Gitee 远程仓库..."
        git remote add "$GITEE_REMOTE" "https://gitee.com/${GITEE_REPO}.git"
    fi
    
    # 显示配置结果
    echo ""
    echo -e "${GREEN}远程仓库配置完成:${NC}"
    git remote -v
}

# 推送分支到远程仓库
push_branch() {
    local remote=$1
    local branch=$2
    
    echo -e "${BLUE}推送分支 '${branch}' 到 ${remote}...${NC}"
    
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY-RUN] git push ${remote} ${branch}"
    else
        if git push "$remote" "$branch" 2>&1; then
            echo -e "${GREEN}✓ 成功推送到 ${remote}/${branch}${NC}"
        else
            echo -e "${RED}✗ 推送到 ${remote}/${branch} 失败${NC}"
            return 1
        fi
    fi
}

# 推送标签到远程仓库
push_tags() {
    local remote=$1
    
    echo -e "${BLUE}推送所有标签到 ${remote}...${NC}"
    
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY-RUN] git push ${remote} --tags"
    else
        if git push "$remote" --tags 2>&1; then
            echo -e "${GREEN}✓ 成功推送标签到 ${remote}${NC}"
        else
            echo -e "${YELLOW}! 推送标签到 ${remote} 时出现警告${NC}"
        fi
    fi
}

# 同步所有分支
push_all_branches() {
    local remote=$1
    
    echo -e "${BLUE}推送所有分支到 ${remote}...${NC}"
    
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY-RUN] git push ${remote} --all"
    else
        if git push "$remote" --all 2>&1; then
            echo -e "${GREEN}✓ 成功推送所有分支到 ${remote}${NC}"
        else
            echo -e "${RED}✗ 推送所有分支到 ${remote} 失败${NC}"
            return 1
        fi
    fi
}

# 主同步函数
sync() {
    local branch=$1
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}双仓库同步工具${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # 检查 Git 仓库
    if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        echo -e "${RED}错误: 当前目录不是 Git 仓库${NC}"
        exit 1
    fi
    
    # 检查远程仓库
    if ! check_remote "$GITHUB_REMOTE" || ! check_remote "$GITEE_REMOTE"; then
        echo -e "${YELLOW}请先运行 '$0 -s' 配置远程仓库${NC}"
        exit 1
    fi
    
    # 获取当前分支（如果未指定）
    if [ -z "$branch" ]; then
        branch=$(get_current_branch)
        echo -e "${BLUE}当前分支: ${branch}${NC}"
    fi
    
    local success_count=0
    local fail_count=0
    
    # 同步到 GitHub
    echo ""
    echo -e "${YELLOW}>>> GitHub (${GITHUB_REMOTE})${NC}"
    if [ "$SYNC_ALL" = "true" ]; then
        if push_all_branches "$GITHUB_REMOTE"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    else
        if push_branch "$GITHUB_REMOTE" "$branch"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    fi
    
    if [ "$SYNC_TAGS" = "true" ] || [ "$SYNC_ALL" = "true" ]; then
        if push_tags "$GITHUB_REMOTE"; then
            ((success_count++))
        fi
    fi
    
    # 同步到 Gitee
    echo ""
    echo -e "${YELLOW}>>> Gitee (${GITEE_REMOTE})${NC}"
    if [ "$SYNC_ALL" = "true" ]; then
        if push_all_branches "$GITEE_REMOTE"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    else
        if push_branch "$GITEE_REMOTE" "$branch"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    fi
    
    if [ "$SYNC_TAGS" = "true" ] || [ "$SYNC_ALL" = "true" ]; then
        if push_tags "$GITEE_REMOTE"; then
            ((success_count++))
        fi
    fi
    
    # 显示结果
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}同步结果${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    if [ $fail_count -eq 0 ]; then
        echo -e "${GREEN}✓ 同步成功！${NC}"
    else
        echo -e "${YELLOW}! 同步完成，但有 ${fail_count} 个操作失败${NC}"
    fi
    
    echo ""
    echo "仓库地址:"
    echo "  GitHub: https://github.com/${GITHUB_REPO}"
    echo "  Gitee:  https://gitee.com/${GITEE_REPO}"
    echo ""
}

# 解析命令行参数
DRY_RUN="false"
VERBOSE="false"
SYNC_TAGS="false"
SYNC_ALL="false"
SETUP_MODE="false"
BRANCH=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -b|--branch)
            BRANCH="$2"
            shift 2
            ;;
        -t|--tags)
            SYNC_TAGS="true"
            shift
            ;;
        -a|--all)
            SYNC_ALL="true"
            shift
            ;;
        -s|--setup)
            SETUP_MODE="true"
            shift
            ;;
        -v|--verbose)
            VERBOSE="true"
            shift
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        -*)
            echo -e "${RED}错误: 未知选项 '$1'${NC}"
            show_help
            exit 1
            ;;
        *)
            BRANCH="$1"
            shift
            ;;
    esac
done

# 执行操作
if [ "$SETUP_MODE" = "true" ]; then
    setup_remotes
else
    sync "$BRANCH"
fi
