#!/bin/bash
# ============================================================
# WorkBuddy 多端配置同步脚本（双通道版）
# 用法：bash ~/.workbuddy-sync/sync.sh [push|pull|cloud-push|cloud-pull]
#   push        — 推送到 GitHub（原有通道，保留作备份）
#   pull        — 从 GitHub 拉取
#   cloud-push  — 推送到网盘（OneDrive/iCloud，走本地同步客户端）
#   cloud-pull  — 从网盘拉取
# ============================================================

set -e

WORKBUDDY_DIR="$HOME/.workbuddy"
SYNC_DIR="$HOME/.workbuddy-sync"
WORKSPACE_DIR="$HOME/WorkBuddy/Claw"

# 网盘中转目录：优先 OneDrive，其次 iCloud 云盘
if [ -d "$HOME/OneDrive" ]; then
  NETDISK_DIR="$HOME/OneDrive/WorkBuddySync"
elif [ -d "$HOME/iCloudDrive" ]; then
  NETDISK_DIR="$HOME/iCloudDrive/WorkBuddySync"
else
  NETDISK_DIR=""
fi

# 夸克网盘备份目录（由夸克客户端的文件夹备份自动上传到云端）
QUARK_DIR="D:/Other/WorkBuddySync"
# 环境变量可覆盖拉取来源（家里电脑没有 OneDrive 时用）：WB_SYNC_SOURCE=夸克本地备份目录
WB_SYNC_SOURCE="${WB_SYNC_SOURCE:-}"

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
# SQLite 一致性快照（工作台 → SYNC_DIR）
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
    print('skip: workbuddy.db not found')
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
# 工作区记忆同步（项目级 .workbuddy/memory/）
# --------------------------------------------------
sync_workspace_memory() {
  local direction="$1"   # push: 工作区→SYNC_DIR  pull: SYNC_DIR→工作区
  local src dst
  if [ "$direction" = "push" ]; then
    src="$WORKSPACE_DIR/.workbuddy/memory"; dst="$SYNC_DIR/workspace-memory"
  else
    src="$SYNC_DIR/workspace-memory"; dst="$WORKSPACE_DIR/.workbuddy/memory"
  fi
  if [ -d "$src" ]; then
    mkdir -p "$dst"
    cp -r "$src"/* "$dst/" 2>/dev/null || true
    echo "  ✅ workspace-memory (项目记忆)"
  else
    echo "  ⏭️  workspace-memory (不存在，跳过)"
  fi
}

# --------------------------------------------------
# 阶段一：本机数据 → SYNC_DIR 中转站
# --------------------------------------------------
stage_data() {
  echo "[1/3] 同步配置文件和对话数据到中转站..."
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
  echo "[2/3] 备份对话数据库..."
  backup_database
  echo ""
  echo "[3/3] 同步工作区记忆..."
  sync_workspace_memory push
}

# --------------------------------------------------
# 阶段二：SYNC_DIR 中转站 → 本机（还原）
# --------------------------------------------------
restore_data() {
  echo "[1/3] 还原配置文件和对话数据..."
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
  echo "[2/3] 还原对话数据库..."
  if [ -f "$SYNC_DIR/workbuddy.db" ]; then
    cp "$SYNC_DIR/workbuddy.db" "$WORKBUDDY_DIR/workbuddy.db" 2>/dev/null || true
    rm -f "$WORKBUDDY_DIR/workbuddy.db-wal" 2>/dev/null || true
    rm -f "$WORKBUDDY_DIR/workbuddy.db-shm" 2>/dev/null || true
    echo "  ✅ workbuddy.db (已还原，WAL 文件已清理)"
  else
    echo "  ⏭️  workbuddy.db (不存在，跳过)"
  fi
  echo ""
  echo "[3/3] 还原工作区记忆..."
  sync_workspace_memory pull
}

# --------------------------------------------------
# 网盘镜像工具（robocopy：对 OneDrive 占位文件安全）
# 用法: mirror <源目录> <目标目录>
# --------------------------------------------------
mirror() {
  local src dst
  src=$(cygpath -w "$1"); dst=$(cygpath -w "$2")
  # 排除双向的 .git 目录，防止 MIR 模式上传/误删 git 仓库数据
  robocopy "$src" "$dst" //MIR //XD "$src\\.git" "$dst\\.git" //NFL //NDL //NJH //NP //R:2 //W:2 2>/dev/null
  local rc=$?
  # robocopy: 0-7 均为成功，>=8 才是失败
  if [ "$rc" -ge 8 ]; then
    echo "  ❌ robocopy 失败 (exit=$rc)"
    return 1
  fi
  return 0
}

echo "========================================"
echo "  WorkBuddy 多端同步工具（双通道）"
echo "========================================"

ACTION="${1:-push}"

case "$ACTION" in

# ============ GitHub 通道 ============
push)
  stage_data
  echo ""
  echo "[GitHub] 提交并推送..."
  cd "$SYNC_DIR"
  HAS_COMMITS=$(git rev-parse HEAD 2>/dev/null && echo "yes" || echo "no")
  if [ "$HAS_COMMITS" = "yes" ]; then
    if git diff --quiet && git diff --cached --quiet; then
      echo "  📦 没有新的变更，无需推送。"
      exit 0
    fi
  fi
  git add -A
  TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
  git commit -m "sync: $TIMESTAMP - $(hostname)" || echo "  (无变更可提交)"
  if git remote get-url origin &>/dev/null; then
    git push origin main 2>&1 || echo "  ⚠️ 推送失败，请检查网络和仓库权限。"
    echo ""
    echo "🎉 GitHub 推送完成！"
  else
    echo "⚠️  未配置远程仓库。"
  fi
  ;;

pull)
  cd "$SYNC_DIR"
  if ! git remote get-url origin &>/dev/null; then
    echo "❌ 未配置远程仓库。"
    exit 1
  fi
  echo "[0/3] 从远程仓库拉取最新数据..."
  git pull origin main 2>&1
  echo ""
  restore_data
  echo ""
  echo "🎉 GitHub 拉取完成！请重启 WorkBuddy 使所有数据生效。"
  ;;

# ============ 网盘通道 ============
cloud-push)
  if [ -z "$NETDISK_DIR" ]; then
    echo "❌ 未检测到 OneDrive 或 iCloud 云盘目录。"
    echo "   请先安装并登录其中一个网盘客户端。"
    exit 1
  fi
  echo "网盘中转目录：$NETDISK_DIR"
  echo ""
  stage_data
  echo ""
  echo "[网盘] 镜像到网盘同步目录（客户端会自动上传）..."
  if mirror "$SYNC_DIR" "$NETDISK_DIR"; then
    date "+%Y-%m-%d %H:%M:%S - $(hostname)" > "$NETDISK_DIR/.last-push"
    echo "  ✅ 已镜像，OneDrive/iCloud 客户端正在自动上传"
  else
    echo "  ⚠️ OneDrive 推送失败，请检查网盘客户端是否正常运行。"
  fi
  # 夸克网盘备份目录（存在则同步镜像，由夸克文件夹备份自动上云）
  if [ -d "$QUARK_DIR" ]; then
    echo "[夸克] 镜像到夸克备份目录 $QUARK_DIR ..."
    if mirror "$SYNC_DIR" "$QUARK_DIR"; then
      date "+%Y-%m-%d %H:%M:%S - $(hostname)" > "$QUARK_DIR/.last-push"
      echo "  ✅ 已镜像，夸克客户端文件夹备份将自动上传云端"
    else
      echo "  ⚠️ 夸克目录镜像失败。"
    fi
  fi
  echo ""
  echo "🎉 网盘推送完成！在另一台电脑上执行 cloud-pull 即可还原。"
  ;;

cloud-pull)
  # 拉取来源：环境变量 WB_SYNC_SOURCE 优先（家里电脑可指向夸克备份的本地目录）
  if [ -n "$WB_SYNC_SOURCE" ] && [ -d "$WB_SYNC_SOURCE" ]; then
    SOURCE_DIR="$WB_SYNC_SOURCE"
    echo "拉取来源（环境变量指定）：$SOURCE_DIR"
  elif [ -n "$NETDISK_DIR" ] && [ -d "$NETDISK_DIR" ] && [ -n "$(ls -A "$NETDISK_DIR" 2>/dev/null)" ]; then
    SOURCE_DIR="$NETDISK_DIR"
  elif [ -d "$QUARK_DIR" ] && [ -n "$(ls -A "$QUARK_DIR" 2>/dev/null)" ]; then
    SOURCE_DIR="$QUARK_DIR"
  else
    echo "❌ 未找到可用的同步来源（OneDrive/iCloud/夸克目录均为空）。"
    echo "   家里电脑请先让夸克客户端把 WorkBuddySync 文件夹同步下来，"
    echo "   然后执行：WB_SYNC_SOURCE=<夸克本地同步目录路径> bash sync.sh cloud-pull"
    exit 1
  fi
  if [ -f "$SOURCE_DIR/.last-push" ]; then
    echo "远端最后推送时间：$(cat "$SOURCE_DIR/.last-push")"
  fi
  echo ""
  echo "[0/3] 从来源目录拉取到中转站..."
  if mirror "$SOURCE_DIR" "$SYNC_DIR"; then
    echo "  ✅ 已拉取"
  else
    echo "  ⚠️ 拉取失败，请检查来源目录是否已同步完成。"
    exit 1
  fi
  echo ""
  restore_data
  echo ""
  echo "🎉 网盘拉取完成！请重启 WorkBuddy 使所有数据生效。"
  ;;

*)
  echo ""
  echo "用法: bash ~/.workbuddy-sync/sync.sh [push|pull|cloud-push|cloud-pull]"
  echo ""
  echo "  push        — 推送到 GitHub（保留作备份）"
  echo "  pull        — 从 GitHub 拉取"
  echo "  cloud-push  — 推送到网盘（OneDrive/iCloud，推荐）"
  echo "  cloud-pull  — 从网盘拉取"
  echo ""
  echo "同步内容包括："
  echo "  - 身份文件 (SOUL/IDENTITY/USER/BOOTSTRAP)"
  echo "  - 配置文件 (settings.json, .mcp.json)"
  echo "  - 对话记录 (sessions/, workbuddy.db)"
  echo "  - 文件历史 (file-history/, artifact-index/)"
  echo "  - 技能和脚本 (skills/, scripts/)"
  echo "  - 工作区记忆 (workspace-memory/)"
  exit 1
  ;;
esac

echo ""
