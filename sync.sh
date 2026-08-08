#!/bin/bash
# ============================================================
# WorkBuddy 多设备配置同步脚本
# 用法：bash ~/.workbuddy-sync/sync.sh [push|pull]
# ============================================================

set -e

WORKBUDDY_DIR="$HOME/.workbuddy"
SYNC_DIR="$HOME/.workbuddy-sync"
WORKSPACE_DIR="$HOME/WorkBuddy/Claw"

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
  "sessions"
  "file-history"
  "artifact-index"
)

# --------------------------------------------------
# 查找可用的 Python（用于 SQLite 一致性备份）
# --------------------------------------------------
find_python() {
  if command -v python3 &>/dev/null; then
    echo "python3"
  elif command -v python &>/dev/null; then
    echo "python"
  else
    local managed
    managed=$(ls "$HOME/.workbuddy/binaries/python/versions/"*/python.exe 2>/dev/null | head -1)
    if [ -n "$managed" ]; then
      echo "$managed"
    else
      echo ""
    fi
  fi
}

# --------------------------------------------------
# 使用 SQLite Backup API 创建一致性快照
# 避免直接复制正在使用的 WAL 模式数据库导致损坏
# --------------------------------------------------
backup_database() {
  local PYTHON
  PYTHON=$(find_python)
  if [ -z "$PYTHON" ]; then
    echo "  ⚠️ 未找到 Python，直接复制数据库（可能不一致）"
    cp "$WORKBUDDY_DIR/workbuddy.db" "$SYNC_DIR/workbuddy.db" 2>/dev/null || true
    return
  fi
  "$PYTHON" -c "
import sqlite3, sys, os
src_path = os.path.join(os.environ['HOME'], '.workbuddy', 'workbuddy.db')
dst_path = os.path.join(os.environ['HOME'], '.workbuddy-sync', 'workbuddy.db')
if not os.path.exists(src_path):
    print('  skip: workbuddy.db not found')
    sys.exit(0)
try:
    src = sqlite3.connect(src_path)
    dst = sqlite3.connect(dst_path)
    src.backup(dst)
    dst.close()
    src.close()
    print('ok')
except Exception as e:
    print(f'warn: SQLite backup failed ({e}), fallback to copy')
    import shutil
    shutil.copy2(src_path, dst_path)
" 2>&1 | while read -r line; do
    case "$line" in
      ok) echo "  ✅ workbuddy.db (SQLite 一致性快照)" ;;
      warn:*) echo "  ⚠️ $line" ;;
      skip:*) echo "  ⏭️  workbuddy.db (不存在，跳过)" ;;
      *) echo "  $line" ;;
    esac
  done
}

# --------------------------------------------------
# 同步工作区记忆（项目级 .workbuddy/memory/）
# --------------------------------------------------
sync_workspace_memory_push() {
  local src="$WORKSPACE_DIR/.workbuddy/memory"
  local dst="$SYNC_DIR/workspace-memory"
  if [ -d "$src" ]; then
    mkdir -p "$dst"
    cp -r "$src"/* "$dst/" 2>/dev/null || true
    echo "  ✅ workspace-memory (项目记忆)"
  else
    echo "  ⏭️  workspace-memory (不存在，跳过)"
  fi
}

sync_workspace_memory_pull() {
  local src="$SYNC_DIR/workspace-memory"
  local dst="$WORKSPACE_DIR/.workbuddy/memory"
  if [ -d "$src" ]; then
    mkdir -p "$dst"
    cp -r "$src"/* "$dst/" 2>/dev/null || true
    echo "  ✅ workspace-memory (项目记忆)"
  else
    echo "  ⏭️  workspace-memory (不存在，跳过)"
  fi
}

echo "========================================"
echo "  WorkBuddy 多端同步工具"
echo "========================================"

ACTION="${1:-push}"

if [ "$ACTION" = "push" ]; then
  echo ""
  echo "[1/5] 同步配置文件和对话数据..."
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
  echo "[2/5] 备份对话数据库..."
  backup_database

  echo ""
  echo "[3/5] 同步工作区记忆..."
  sync_workspace_memory_push

  echo ""
  echo "[4/5] 检查变更..."
  cd "$SYNC_DIR"

  HAS_COMMITS=$(git rev-parse HEAD 2>/dev/null && echo "yes" || echo "no")
  if [ "$HAS_COMMITS" = "yes" ]; then
    if git diff --quiet && git diff --cached --quiet; then
      echo "  📦 没有新的变更，无需推送。"
      exit 0
    fi
  fi

  echo "[5/5] 提交并推送..."
  git add -A
  TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
  git commit -m "sync: $TIMESTAMP - $(hostname)" || echo "  (无变更可提交)"

  if git remote get-url origin &>/dev/null; then
    git push origin main 2>&1 || echo "  ⚠️ 推送失败，请检查网络和仓库权限。"
    echo ""
    echo "🎉 同步完成！配置和对话数据已推送到远程仓库。"
  else
    echo ""
    echo "⚠️  未配置远程仓库。请先运行："
    echo "   cd ~/.workbuddy-sync"
    echo "   git remote add origin <你的GitHub私有仓库地址>"
    echo "   git push -u origin main"
  fi

elif [ "$ACTION" = "pull" ]; then
  echo ""
  echo "[1/4] 从远程仓库拉取最新数据..."
  cd "$SYNC_DIR"

  if ! git remote get-url origin &>/dev/null; then
    echo "❌ 未配置远程仓库。请先添加远程仓库地址。"
    exit 1
  fi

  git pull origin main 2>&1

  echo ""
  echo "[2/4] 还原配置文件和对话数据..."
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
  echo "[3/4] 还原对话数据库..."
  if [ -f "$SYNC_DIR/workbuddy.db" ]; then
    cp "$SYNC_DIR/workbuddy.db" "$WORKBUDDY_DIR/workbuddy.db" 2>/dev/null || true
    # 删除 WAL/SHM 临时文件，应用启动时会自动重建
    rm -f "$WORKBUDDY_DIR/workbuddy.db-wal" 2>/dev/null || true
    rm -f "$WORKBUDDY_DIR/workbuddy.db-shm" 2>/dev/null || true
    echo "  ✅ workbuddy.db (已还原，WAL 文件已清理)"
  else
    echo "  ⏭️  workbuddy.db (不存在，跳过)"
  fi

  echo ""
  echo "[4/4] 还原工作区记忆..."
  sync_workspace_memory_pull

  echo ""
  echo "🎉 同步完成！请重启 WorkBuddy 使所有数据生效。"

else
  echo ""
  echo "用法: bash ~/.workbuddy-sync/sync.sh [push|pull]"
  echo ""
  echo "  push  — 将本机数据推送到 GitHub（默认）"
  echo "  pull  — 从 GitHub 拉取数据到本机"
  echo ""
  echo "同步内容包括："
  echo "  - 身份文件 (SOUL/IDENTITY/USER/BOOTSTRAP)"
  echo "  - 配置文件 (settings.json, .mcp.json)"
  echo "  - 对话记录 (sessions/, workbuddy.db)"
  echo "  - 文件历史 (file-history/, artifact-index/)"
  echo "  - 技能和脚本 (skills/, scripts/)"
  echo "  - 工作区记忆 (workspace-memory/)"
  exit 1
fi

echo ""
