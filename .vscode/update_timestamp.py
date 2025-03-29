import re
import sys
import subprocess
from datetime import datetime
from typing import Tuple
from pathlib import Path

def get_git_user_info() -> Tuple[str, str]:
    """获取 Git 配置的用户名和邮箱

    Returns:
        Tuple[str, str]: 用户名和邮箱的元组
    """
    def _get_git_config(key: str) -> str:
        try:
            return subprocess.check_output(
                ["git", "config", key],
                stderr=subprocess.DEVNULL,
                text=True,
                timeout=2  # 添加超时防止挂起
            ).strip()
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
            return None

    name = _get_git_config("user.name") or "Unknown User"
    email = _get_git_config("user.email") or "no-email@example.com"

    if name == "Unknown User":
        print("Warning: Git user config not found, using fallback values")

    return name, email

def update_timestamp(file_path: str) -> bool:
    """更新文件的时间戳和修改者信息

    Args:
        file_path (str): 要更新的文件路径

    Returns:
        bool: 更新是否成功
    """
    try:
        # 转换为 Path 对象以更好地处理文件路径
        path = Path(file_path)
        if not path.is_file():
            raise FileNotFoundError(f"{file_path} is not a valid file")

        # 获取当前时间和用户信息
        current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        user_name, user_email = get_git_user_info()
        modified_by = f"{user_name} <{user_email}>"

        # 使用上下文管理器读取和写入文件
        content = path.read_text(encoding='utf-8').splitlines(keepends=True)

        # 使用列表推导式更新内容
        updated_content = [
            (re.sub(r'(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})', current_time, line)
             if 'Last Modified:' in line else
             re.sub(r'(Modified   By:  ).*', rf'\1{modified_by}', line)
             if 'Modified   By:' in line else line)
            for line in content
        ]

        # 写回文件
        path.write_text(''.join(updated_content), encoding='utf-8')
        return True

    except Exception as e:
        print(f"Error updating file: {str(e)}")
        return False

def main() -> None:
    """主函数"""
    if len(sys.argv) < 2:
        print("Usage: python update_timestamp.py <file_path>")
        sys.exit(1)

    target_file = sys.argv[1]
    if update_timestamp(target_file):
        print(f"Successfully updated timestamp in {target_file}")
    else:
        sys.exit(1)

if __name__ == "__main__":
    main()
