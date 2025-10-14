# Instructions for Claude Code

## About This Repository

This repository contains the `/dbapps` slash command for Claude Code. It generates React + FastAPI applications with Databricks deployment support.

## Installing the Command

When the user wants to install or update the `/dbapps` command, run:

```bash
python install.py
```

or

```bash
./install.sh
```

This will copy the command files to `~/.claude/commands/`.

## DO NOT Modify Generated Apps Here

This repository contains the **command template** that generates applications.

If the user wants to work on an app that was created using `/dbapps`, they should:
1. Open that app's directory (not this one)
2. That app will have its own `.claude/instructions.md` with deployment instructions

## Updating the Command

If the user wants to update the `/dbapps` command:
1. Edit `commands/dbapps.md` - the command definition
2. Edit `commands/deploy_to_databricks_template.py` - the deployment script template
3. Test changes by running `python install.py` to update local command
4. Commit and push changes to GitHub

## Repository Structure

- `commands/dbapps.md` - The slash command definition
- `commands/deploy_to_databricks_template.py` - Deployment script template
- `install.sh` - Bash installer (macOS/Linux)
- `install.py` - Python installer (cross-platform)
- `README.md` - Documentation

## Publishing Changes

After making changes:

```bash
git add -A
git commit -m "Your message"
git push
```

The command is at: https://github.com/honnuanand/claude-dbapps-command
