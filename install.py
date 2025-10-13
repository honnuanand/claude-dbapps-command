#!/usr/bin/env python3
"""
Installation script for /dbapps Claude Code slash command
This script copies the command files to ~/.claude/commands/
Cross-platform compatible (Windows, macOS, Linux)
"""

import os
import sys
import shutil
from pathlib import Path

# ANSI color codes
GREEN = '\033[0;32m'
BLUE = '\033[0;34m'
YELLOW = '\033[1;33m'
NC = '\033[0m'  # No Color

def print_colored(text, color):
    """Print colored text if terminal supports it"""
    if sys.platform != 'win32' or os.getenv('TERM'):
        print(f"{color}{text}{NC}")
    else:
        print(text)

def main():
    print_colored("=" * 45, BLUE)
    print_colored("Installing /dbapps command for Claude Code", BLUE)
    print_colored("=" * 45, BLUE)
    print()

    # Get the directory where this script is located
    script_dir = Path(__file__).parent
    commands_src = script_dir / "commands"
    commands_dst = Path.home() / ".claude" / "commands"

    # Create .claude/commands directory if it doesn't exist
    if not commands_dst.exists():
        print_colored(f"Creating {commands_dst}...", YELLOW)
        commands_dst.mkdir(parents=True, exist_ok=True)

    # Copy command files
    print_colored("Copying command files...", BLUE)

    files_to_copy = [
        "dbapps.md",
        "deploy_to_databricks_template.py"
    ]

    success_count = 0
    for filename in files_to_copy:
        src_file = commands_src / filename
        dst_file = commands_dst / filename

        if src_file.exists():
            shutil.copy2(src_file, dst_file)
            print_colored(f"✓ Installed {filename}", GREEN)
            success_count += 1
        else:
            print_colored(f"⚠ Warning: {filename} not found", YELLOW)

    print()
    print_colored("=" * 45, GREEN)
    print_colored("Installation complete!", GREEN)
    print_colored("=" * 45, GREEN)
    print()

    print_colored("The /dbapps command is now available in Claude Code!", BLUE)
    print()

    print_colored("Usage:", BLUE)
    print("  1. Open Claude Code in any directory")
    print_colored("  2. Type: /dbapps", GREEN)
    print("  3. Claude will create a React + FastAPI app with Databricks deployment")
    print()

    print_colored("Files installed to:", BLUE)
    for filename in files_to_copy:
        print(f"  {commands_dst / filename}")
    print()

    print_colored(f"✓ Successfully installed {success_count} file(s)", GREEN)

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print_colored(f"❌ Error: {e}", YELLOW)
        sys.exit(1)
