#!/bin/bash
# ============================================================
# WorkBuddy 多设备配置同步脚本
# 用法：bash ~/.workbuddy-sync/sync.sh [push|pull]
# ============================================================

set -e

WORKBUDDY_DIR="$HOME/.workbuddy"
SYNC_DIR="$HOME/.workbuddy-sync"

# 需要同步的文件/目录列表
SYNC_ITEMS=(
  "skills"
  "scripts"
  "SOUL.md"
  "IDENTITY.md"
  "USER.md"
  "BOOTSTRAP.md"
  "settings.json"
  ".mcp.json"
  "MEMORY.md"
)

echo "========================================"
echo "  WorkBuddy 配置同步工具"
echo "========================================"

ACTION="${1:-push}"

if [ "$ACTION" = "push" ]; then
  echo ""
  echo "[1/4] 从 $WORKBUDDY_DIR 复制配置文件到同步目录..."
  for item in "${SYNC_ITEMS[@]}"; do
    src="$WORKBUDDY_DIR/$item"
    dst="$SYNC_DIR/$item"
    if [ -e "$src" ]; then
      if [ -d "$src" ]; then
        mkdir -p "$dst"
        cp -r "$src"/* "$dst/" 2>/dev/null || true
      else
        cp "$src" "$dst" 2>/dev/null || true
      fi
      echo "  ✅ $item"
    else
      echo "  ⏭️  $item (不存在，跳过)"
    fi
  done

  echo ""
  echo "[2/4] 检查变更..."

  cd "$SYNC_DIR"

  # 检查是否有变更（兼容首次提交的情况）
  HAS_COMMITS=$(git rev-parse HEAD 2>/dev/null && echo "yes" || echo "no")
  if [ "$HAS_COMMITS" = "yes" ]; then
    if git diff --quiet && git diff --cached --quiet; then
      echo "  📦 没有新的变更，无需推送。"
      exit 0
    fi
  fi

  echo "[3/4] 提交变更..."
  git add -A
  TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
  git commit -m "sync: $TIMESTAMP — $(hostname)" || echo "  (无变更可提交)"

  echo "[4/4] 推送到远程仓库..."
  if git remote get-url origin &>/dev/null; then
    git push origin main 2>&1 || echo "  ⚠️ 推送失败，请检查网络和仓库权限。"
    echo ""
    echo "🎉 同步完成！配置已推送到远程仓库。"
  else
    echo ""
    echo "⚠️  未配置远程仓库。请先运行："
    echo "   cd ~/.workbuddy-sync"
    echo "   git remote add origin <你的GitHub私有仓库地址>"
    echo "   git push -u origin main"
  fi

elif [ "$ACTION" = "pull" ]; then
  echo ""
  echo "[1/3] 从远程仓库拉取最新配置..."
  cd "$SYNC_DIR"

  if ! git remote get-url origin &>/dev/null; then
    echo "❌ 未配置远程仓库。请先添加远程仓库地址。"
    exit 1
  fi

  git pull origin main 2>&1

  echo ""
  echo "[2/3] 还原配置文件到 $WORKBUDDY_DIR ..."
  for item in "${SYNC_ITEMS[@]}"; do
    src="$SYNC_DIR/$item"
    dst="$WORKBUDDY_DIR/$item"
    if [ -e "$src" ]; then
      if [ -d "$src" ]; then
        mkdir -p "$dst"
        cp -r "$src"/* "$dst/" 2>/dev/null || true
      else
        cp "$src" "$dst" 2>/dev/null || true
      fi
      echo "  ✅ $item"
    else
      echo "  ⏭️  $item (不存在，跳过)"
    fi
  done

  echo ""
  echo "[3/3] 完成！"
  echo ""
  echo "🎉 配置已从远程仓库还原。请重启 WorkBuddy 使配置生效。"

else
  echo ""
  echo "用法: bash ~/.workbuddy-sync/sync.sh [push|pull]"
  echo ""
  echo "  push  — 将本机配置推送到 GitHub（默认）"
  echo "  pull  — 从 GitHub 拉取配置到本机"
  exit 1
fi

echo ""
