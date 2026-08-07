"""
PT签到自动打开脚本
每天早上8:00由 WorkBuddy 自动化任务调用
功能：读取 Edge 书签中 收藏夹栏 > 集锦 > PT签到 文件夹下的所有网址，在新窗口中全部打开
"""

import json
import subprocess
import sys
import os

BOOKMARKS_PATH = os.path.join(
    os.environ.get("LOCALAPPDATA", ""),
    "Microsoft", "Edge", "User Data", "Default", "Bookmarks"
)

TARGET_FOLDER_CHAIN = ["集锦", "PT签到"]  # 收藏夹栏 > 集锦 > PT签到


def find_folder(node, folder_names, index=0):
    """递归查找文件夹链"""
    if index >= len(folder_names):
        return node
    if node.get("type") != "folder":
        return None
    for child in node.get("children", []):
        if child.get("type") == "folder" and child.get("name") == folder_names[index]:
            return find_folder(child, folder_names, index + 1)
    return None


def collect_urls(node):
    """收集文件夹下所有书签的 URL"""
    urls = []
    if node.get("type") == "folder":
        for child in node.get("children", []):
            urls.extend(collect_urls(child))
    elif node.get("type") == "url":
        url = node.get("url", "")
        if url and not url.startswith("chrome") and not url.startswith("javascript"):
            urls.append(url)
    return urls


def main():
    # 读取书签文件
    if not os.path.exists(BOOKMARKS_PATH):
        print(f"ERROR: 书签文件不存在: {BOOKMARKS_PATH}")
        sys.exit(1)

    with open(BOOKMARKS_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)

    # 在收藏夹栏 (bookmark_bar) 下查找 集锦 > PT签到
    bookmark_bar = data.get("roots", {}).get("bookmark_bar", {})
    target_folder = find_folder(bookmark_bar, TARGET_FOLDER_CHAIN)

    if target_folder is None:
        print("ERROR: 未找到 收藏夹栏 > 集锦 > PT签到 文件夹")
        sys.exit(1)

    urls = collect_urls(target_folder)

    if not urls:
        print("WARNING: PT签到 文件夹下没有找到任何网址")
        sys.exit(0)

    print(f"找到 {len(urls)} 个 PT 签到网址:")
    for i, url in enumerate(urls, 1):
        print(f"  {i}. {url}")

    # 用 Edge 在新窗口中打开所有网址
    # 直接调用 msedge.exe，避免 cmd.exe 解析 URL 中的 & 等特殊字符
    msedge_path = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
    if not os.path.exists(msedge_path):
        msedge_path = r"C:\Program Files\Microsoft\Edge\Application\msedge.exe"
    cmd = [msedge_path, "--new-window"] + urls
    subprocess.run(cmd, shell=False)
    print(f"\n已在新窗口中打开全部 {len(urls)} 个 PT 签到页面")


if __name__ == "__main__":
    main()
