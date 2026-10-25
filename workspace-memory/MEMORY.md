# 项目记忆

## 多设备配置同步
- 同步仓库位置：`~/.workbuddy-sync/`
- 同步脚本：`~/.workbuddy-sync/sync.sh`，双通道（2026-10-25 升级）：
  - `cloud-push` / `cloud-pull` — 网盘通道（主力），中转目录 `~/OneDrive/WorkBuddySync/`，robocopy /MIR 镜像（排除 .git）
  - `push` / `pull` — GitHub 通道（备份），仓库 lx521q/workbuddy-backup
- 定时自动化：automation-1786069231416（每日 16:30 双通道推送，GitHub 失败不中断）
- 同步内容（2026-08-08 更新）：
  - 身份文件：SOUL.md、IDENTITY.md、USER.md、BOOTSTRAP.md
  - 配置文件：settings.json、.mcp.json
  - 对话记录：sessions/（会话JSON）、workbuddy.db（SQLite一致性快照，用Python backup API）
  - 文件历史：file-history/、artifact-index/
  - 扩展能力：skills/、scripts/
  - 工作区记忆：workspace-memory/（从 Claw/.workbuddy/memory/ 同步）
- 注意：pull/cloud-pull 前需关闭 WorkBuddy；WAL/SHM 文件不同步，启动时自动重建
- 技术要点：git-bash cp 在 OneDrive 目录会卡死，必须用 robocopy（退出码 0-7 均为成功）
