#!/bin/bash
#
# Installation script for /dbapps Claude Code slash command
# This script copies the command files to ~/.claude/commands/
#

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}Installing /dbapps command for Claude Code${NC}"
echo -e "${BLUE}=====================================${NC}\n"

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
COMMANDS_DIR="$HOME/.claude/commands"

# Create .claude/commands directory if it doesn't exist
if [ ! -d "$COMMANDS_DIR" ]; then
    echo -e "${YELLOW}Creating $COMMANDS_DIR...${NC}"
    mkdir -p "$COMMANDS_DIR"
fi

# Copy command files
echo -e "${BLUE}Copying command files...${NC}"

if [ -f "$SCRIPT_DIR/commands/dbapps.md" ]; then
    cp "$SCRIPT_DIR/commands/dbapps.md" "$COMMANDS_DIR/"
    echo -e "${GREEN}✓ Installed dbapps.md${NC}"
else
    echo -e "${YELLOW}⚠ Warning: dbapps.md not found${NC}"
fi

if [ -f "$SCRIPT_DIR/commands/deploy_to_databricks_template.py" ]; then
    cp "$SCRIPT_DIR/commands/deploy_to_databricks_template.py" "$COMMANDS_DIR/"
    echo -e "${GREEN}✓ Installed deploy_to_databricks_template.py${NC}"
else
    echo -e "${YELLOW}⚠ Warning: deploy_to_databricks_template.py not found${NC}"
fi

echo -e "\n${GREEN}=====================================${NC}"
echo -e "${GREEN}Installation complete!${NC}"
echo -e "${GREEN}=====================================${NC}\n"

echo -e "${BLUE}The /dbapps command is now available in Claude Code!${NC}\n"

echo -e "${BLUE}Usage:${NC}"
echo -e "  1. Open Claude Code in any directory"
echo -e "  2. Type: ${GREEN}/dbapps${NC}"
echo -e "  3. Claude will create a React + FastAPI app with Databricks deployment\n"

echo -e "${BLUE}Files installed to:${NC}"
echo -e "  $COMMANDS_DIR/dbapps.md"
echo -e "  $COMMANDS_DIR/deploy_to_databricks_template.py\n"
