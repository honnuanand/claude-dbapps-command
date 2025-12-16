#!/usr/bin/env python3
"""
Installation script for /dbapps and /dbtestrunner Claude Code slash commands
This script copies the command files to ~/.claude/commands/
Cross-platform compatible (Windows, macOS, Linux)
"""

import os
import sys
import shutil
import subprocess
import argparse
from pathlib import Path

# ANSI color codes
GREEN = '\033[0;32m'
BLUE = '\033[0;34m'
YELLOW = '\033[1;33m'
NC = '\033[0m'  # No Color

def print_colored(text, color, end="\n"):
    """Print colored text if terminal supports it"""
    if sys.platform != 'win32' or os.getenv('TERM'):
        print(f"{color}{text}{NC}", end=end)
    else:
        print(text, end=end)

def update_from_repo(script_dir):
    """Pull latest changes from git repository"""
    print_colored("🔄 Updating from GitHub repository...", BLUE)
    print()

    try:
        # Check if this is a git repository
        result = subprocess.run(
            ["git", "rev-parse", "--git-dir"],
            cwd=script_dir,
            capture_output=True,
            text=True,
            check=False
        )

        if result.returncode != 0:
            print_colored("⚠ Warning: Not a git repository. Skipping update.", YELLOW)
            print_colored("  To enable updates, clone from GitHub:", YELLOW)
            print("  git clone https://github.com/honnuanand/claude-dbapps-command.git")
            print()
            return False

        # Pull latest changes
        print_colored("Pulling latest changes...", BLUE)
        result = subprocess.run(
            ["git", "pull"],
            cwd=script_dir,
            capture_output=True,
            text=True,
            check=False
        )

        if result.returncode == 0:
            print_colored("✓ Successfully updated from GitHub", GREEN)
            if "Already up to date" in result.stdout:
                print_colored("  Repository is already up to date", BLUE)
            print()
            return True
        else:
            print_colored(f"❌ Failed to update: {result.stderr}", YELLOW)
            return False

    except FileNotFoundError:
        print_colored("⚠ Warning: git command not found", YELLOW)
        print_colored("  Install git to enable automatic updates", YELLOW)
        print()
        return False

def install_files(script_dir):
    """Install command files to ~/.claude/commands/"""
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
        "dbtestrunner.md",
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

    print_colored("The following commands are now available in Claude Code!", BLUE)
    print()

    print_colored("Commands:", BLUE)
    print_colored("  /dbapps       ", GREEN, end="")
    print("- Create a React + FastAPI app with Databricks deployment")
    print_colored("  /dbtestrunner ", GREEN, end="")
    print("- Add an in-app Test Runner framework to a Databricks App")
    print()

    print_colored("Usage:", BLUE)
    print("  1. Open Claude Code in any directory")
    print_colored("  2. Type: /dbapps", GREEN, end="")
    print(" to create a new Databricks App")
    print_colored("  3. Type: /dbtestrunner", GREEN, end="")
    print(" to add an in-app test runner")
    print()

    print_colored("Files installed to:", BLUE)
    for filename in files_to_copy:
        print(f"  {commands_dst / filename}")
    print()

    print_colored(f"✓ Successfully installed {success_count} file(s)", GREEN)

def main():
    parser = argparse.ArgumentParser(
        description="Install /dbapps and /dbtestrunner commands for Claude Code",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python install.py           # Install the commands
  python install.py --update  # Update from GitHub, then install
        """
    )
    parser.add_argument(
        "--update",
        action="store_true",
        help="Pull latest changes from GitHub before installing"
    )

    args = parser.parse_args()

    print_colored("=" * 50, BLUE)
    if args.update:
        print_colored("Updating and Installing Databricks App commands", BLUE)
    else:
        print_colored("Installing Databricks App commands for Claude Code", BLUE)
    print_colored("=" * 50, BLUE)
    print()

    # Get the directory where this script is located
    script_dir = Path(__file__).parent

    # Update from repo if requested
    if args.update:
        update_from_repo(script_dir)

    # Install files
    install_files(script_dir)

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print_colored(f"❌ Error: {e}", YELLOW)
        sys.exit(1)
