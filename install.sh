#!/bin/bash
#
# Installation script for Databricks Claude Code slash commands:
#   - /dbapps - Create React + FastAPI apps with Databricks deployment
#   - /dbtestrunner - Add in-app test runner framework
#   - /dbaiassistant - Add Genie-powered AI assistant
#   - /dbgeniespaces - Analyze schemas and create Genie spaces
#
# This script copies the command files to ~/.claude/commands/
#

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
UPDATE_MODE=false
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --update|-u) UPDATE_MODE=true ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --update, -u    Pull latest changes from GitHub before installing"
            echo "  --help, -h      Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0              # Install the command"
            echo "  $0 --update     # Update from GitHub, then install"
            exit 0
            ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
COMMANDS_DIR="$HOME/.claude/commands"

echo -e "${BLUE}=============================================${NC}"
if [ "$UPDATE_MODE" = true ]; then
    echo -e "${BLUE}Updating and Installing Databricks App commands${NC}"
else
    echo -e "${BLUE}Installing Databricks App commands for Claude Code${NC}"
fi
echo -e "${BLUE}=============================================${NC}\n"

# Update from repo if requested
if [ "$UPDATE_MODE" = true ]; then
    echo -e "${BLUE}🔄 Updating from GitHub repository...${NC}\n"

    # Check if this is a git repository
    if git -C "$SCRIPT_DIR" rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${BLUE}Pulling latest changes...${NC}"
        cd "$SCRIPT_DIR"
        if git pull; then
            echo -e "${GREEN}✓ Successfully updated from GitHub${NC}\n"
        else
            echo -e "${YELLOW}❌ Failed to update from GitHub${NC}\n"
        fi
    else
        echo -e "${YELLOW}⚠ Warning: Not a git repository. Skipping update.${NC}"
        echo -e "${YELLOW}  To enable updates, clone from GitHub:${NC}"
        echo -e "  git clone https://github.com/honnuanand/claude-dbapps-command.git\n"
    fi
fi

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

if [ -f "$SCRIPT_DIR/commands/dbtestrunner.md" ]; then
    cp "$SCRIPT_DIR/commands/dbtestrunner.md" "$COMMANDS_DIR/"
    echo -e "${GREEN}✓ Installed dbtestrunner.md${NC}"
else
    echo -e "${YELLOW}⚠ Warning: dbtestrunner.md not found${NC}"
fi

if [ -f "$SCRIPT_DIR/commands/dbaiassistant.md" ]; then
    cp "$SCRIPT_DIR/commands/dbaiassistant.md" "$COMMANDS_DIR/"
    echo -e "${GREEN}✓ Installed dbaiassistant.md${NC}"
else
    echo -e "${YELLOW}⚠ Warning: dbaiassistant.md not found${NC}"
fi

if [ -f "$SCRIPT_DIR/commands/dbgeniespaces.md" ]; then
    cp "$SCRIPT_DIR/commands/dbgeniespaces.md" "$COMMANDS_DIR/"
    echo -e "${GREEN}✓ Installed dbgeniespaces.md${NC}"
else
    echo -e "${YELLOW}⚠ Warning: dbgeniespaces.md not found${NC}"
fi

echo -e "\n${GREEN}=============================================${NC}"
echo -e "${GREEN}Installation complete!${NC}"
echo -e "${GREEN}=============================================${NC}\n"

echo -e "${BLUE}The following commands are now available in Claude Code:${NC}\n"

echo -e "${BLUE}Commands:${NC}"
echo -e "  ${GREEN}/dbapps${NC}        - Create a React + FastAPI app with Databricks deployment"
echo -e "  ${GREEN}/dbtestrunner${NC}  - Add an in-app Test Runner framework to a Databricks App"
echo -e "  ${GREEN}/dbaiassistant${NC} - Add a Genie-powered AI assistant to your Databricks App"
echo -e "  ${GREEN}/dbgeniespaces${NC} - Analyze schemas and create comprehensive Genie spaces\n"

echo -e "${BLUE}Usage:${NC}"
echo -e "  1. Open Claude Code in any directory"
echo -e "  2. Type: ${GREEN}/dbapps${NC} to create a new Databricks App"
echo -e "  3. Type: ${GREEN}/dbtestrunner${NC} to add an in-app test runner"
echo -e "  4. Type: ${GREEN}/dbaiassistant${NC} to add a Genie-powered AI assistant"
echo -e "  5. Type: ${GREEN}/dbgeniespaces${NC} to analyze and create Genie spaces\n"

echo -e "${BLUE}Files installed to:${NC}"
echo -e "  $COMMANDS_DIR/dbapps.md"
echo -e "  $COMMANDS_DIR/dbtestrunner.md"
echo -e "  $COMMANDS_DIR/dbaiassistant.md"
echo -e "  $COMMANDS_DIR/dbgeniespaces.md"
echo -e "  $COMMANDS_DIR/deploy_to_databricks_template.py\n"
