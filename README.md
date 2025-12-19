# Databricks Claude Code Commands

A collection of powerful Claude Code slash commands for building and deploying Databricks applications.

## What is this?

This repository contains custom slash commands for [Claude Code](https://claude.ai/claude-code) that help you:

| Command | Description |
|---------|-------------|
| `/dbapps` | Create a full-stack React + FastAPI application with Databricks deployment |
| `/dbtestrunner` | Add an in-app test runner framework to your Databricks App |
| `/dbaiassistant` | Add a Genie-powered AI assistant with natural language SQL queries |
| `/dbgeniespaces` | Analyze Unity Catalog schemas and create comprehensive Genie spaces |

All commands work together - you can use `/dbapps` to create an app, `/dbtestrunner` to add tests, and `/dbaiassistant` + `/dbgeniespaces` to add AI-powered data exploration.

## Features

### Frontend
- **React 18** with TypeScript
- **Material-UI (MUI) v5** component library
- **Framer Motion** for smooth animations
- Retractable drawer navigation with smooth transitions
- Vite for fast development and building

### Backend
- **FastAPI** with async support
- Health check and data endpoints
- Static file serving for React app
- CORS middleware for local development

### Deployment
- **Automated build script** (`build.py`)
- **Databricks deployment script** (`deploy_to_databricks.py`) with:
  - Auto-detection of workspace URL and user email
  - CLI verification and setup guidance
  - Scope management for secrets
  - Hard redeploy option
  - Smart file syncing (only requirements.txt, no venv)
- **Production-ready** app.yaml configuration

## Installation

### Prerequisites

- Claude Code installed on your machine
- Git

### Quick Install

1. Clone this repository:
   ```bash
   git clone <repository-url>
   cd claude-dbapps-command
   ```

2. Run the installation script:

   **On macOS/Linux:**
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

   **On Windows (or any OS with Python):**
   ```bash
   python install.py
   ```

3. The command is now installed! 🎉

### What the installer does

The installer copies these files to `~/.claude/commands/`:
- `dbapps.md` - The slash command definition
- `deploy_to_databricks_template.py` - The deployment script template

## Usage

### Creating a New App

1. Open Claude Code in any directory
2. Type `/dbapps` and press Enter
3. Claude will create a complete application with:
   - `frontend/` - React application
   - `backend/` - FastAPI application
   - `build.py` - Build script
   - `deploy_to_databricks.py` - Deployment script
   - `README.md` - Comprehensive documentation
   - `.gitignore` - Sensible defaults

### Local Development

**Frontend:**
```bash
cd frontend
npm install
npm run dev
```
Runs on http://localhost:5173

**Backend:**
```bash
cd backend
pip install -r requirements.txt
python app.py
```
Runs on http://localhost:8000

### Building for Production

```bash
python build.py
```

This will:
1. Install frontend dependencies
2. Build React to static files
3. Copy static files to backend
4. Install backend dependencies
5. Verify the build

### Deploying to Databricks

**Prerequisites:**
- Databricks CLI installed: `pip install databricks-cli`
- Databricks CLI configured: `databricks configure --token`

**Standard Deployment:**
```bash
python deploy_to_databricks.py
```

The script will:
- Auto-detect workspace URL and user email
- Build the frontend
- Package the backend
- Import to Databricks workspace
- Deploy the app
- Show the app URL

**Hard Redeploy:**
```bash
python deploy_to_databricks.py --hard-redeploy
```

Deletes the existing app and deploys fresh (useful for fixing stuck deployments).

**Custom App Name:**
```bash
python deploy_to_databricks.py --app-name my-custom-app
```

## Project Structure

Generated projects have this structure:

```
my-app/
├── frontend/
│   ├── src/
│   │   ├── App.tsx          # Main application
│   │   ├── main.tsx         # Entry point
│   │   └── vite-env.d.ts    # Vite types
│   ├── package.json
│   ├── tsconfig.json
│   ├── vite.config.ts
│   └── index.html
├── backend/
│   ├── app.py               # FastAPI application
│   ├── requirements.txt     # Python dependencies
│   ├── .env                 # Environment variables
│   └── app.yaml            # Databricks config
├── build.py                 # Build script
├── deploy_to_databricks.py  # Deployment script
├── app.yaml                 # Root Databricks config
├── README.md                # Project documentation
└── .gitignore               # Git ignore rules
```

## Deployment Script Features

The generated `deploy_to_databricks.py` script includes:

### Auto-Detection
- Automatically detects workspace URL from Databricks CLI config
- Detects user email and constructs workspace path
- No need to manually specify `--app-folder` in most cases

### Smart File Syncing
- Only syncs necessary files (source code, requirements.txt, static files)
- Excludes: venv, __pycache__, tests, logs, node_modules
- Databricks installs dependencies from requirements.txt automatically

### Deployment Options
- `--app-name`: Custom app name (default: directory name)
- `--app-folder`: Custom workspace folder (auto-detected by default)
- `--hard-redeploy`: Delete and redeploy (waits for deletion to complete)

### Error Handling
- Verifies Databricks CLI installation and configuration
- Provides helpful error messages
- Cleans up temporary files automatically

---

## `/dbaiassistant` Command

Add a Genie-powered AI assistant to your Databricks App. This command provides comprehensive instructions for building a natural language interface to your data.

### What it creates

- **Frontend Components**: `GenieChatCore.tsx`, `FloatingAIAssistant.tsx`, `AINotificationBadge.tsx`
- **Backend Routers**: `genie.py` for Genie API integration
- **Async Processing**: Queue-based system for long-running AI queries
- **Auto-preload**: Background insight generation for instant responses

### Features

- Natural language SQL queries via Databricks Genie
- Async request processing with notification badges
- Floating chat assistant with expand/collapse
- Performance card insights with AI analysis
- Visualization-ready responses (line charts, bar charts, tables)

### Usage

1. First create your app with `/dbapps`
2. Create Genie spaces with `/dbgeniespaces`
3. Run `/dbaiassistant` to add the AI assistant components
4. Configure your Genie space ID in the app

---

## `/dbgeniespaces` Command

Analyze Unity Catalog schemas and create comprehensive Databricks Genie spaces. This command automates the entire Genie space creation workflow.

### Quick Start

Point Claude at a schema and let it analyze and create spaces:

```
/dbgeniespaces

Analyze catalog.my_schema and create appropriate Genie spaces
```

### Features

- **Schema Analysis**: Automatically discovers tables and columns
- **Domain Grouping**: Groups related tables (sales_, hr_, finance_, etc.)
- **Visualization Questions**: Generates questions optimized for charts:
  - Line charts (date columns + metrics)
  - Bar charts (category columns + aggregates)
  - Pie charts (percentage breakdowns)
  - KPI displays (single-value metrics)
- **Multi-Space Creation**: Creates separate spaces per domain
- **Permission Setup**: Configures service principal access

### Interactive Discovery

The command guides you through:

1. Connect to your Databricks workspace
2. Explore available catalogs and schemas
3. Analyze table structures and relationships
4. Identify visualization-friendly columns
5. Generate curated questions
6. Create and configure Genie spaces

### Example Output

For a schema with sales and HR tables:

- **Sales Analytics Space**: Questions for revenue trends, product performance, regional breakdowns
- **HR Analytics Space**: Questions for headcount, hiring velocity, turnover analysis

---

## Uninstalling

To remove all commands:

```bash
rm ~/.claude/commands/dbapps.md
rm ~/.claude/commands/dbtestrunner.md
rm ~/.claude/commands/dbaiassistant.md
rm ~/.claude/commands/dbgeniespaces.md
rm ~/.claude/commands/deploy_to_databricks_template.py
```

## Updating

To update to the latest version, you have two options:

**Option 1: Automatic update (recommended)**
```bash
cd claude-dbapps-command
./install.sh --update      # macOS/Linux
# or
python install.py --update  # Any OS
```

The `--update` flag will:
1. Pull the latest changes from GitHub
2. Install the updated command files

**Option 2: Manual update**
```bash
cd claude-dbapps-command
git pull
./install.sh  # or python install.py
```

## Troubleshooting

### "Command not found" in Claude Code

- Make sure you ran the install script
- Restart Claude Code
- Check that files exist in `~/.claude/commands/`

### Deployment fails with "Folder Users is protected"

The deployment script now auto-detects your workspace path. If it still fails:
```bash
python deploy_to_databricks.py --app-folder "/Workspace/Users/your.email@company.com/app-name"
```

### "databricks command not found"

Install the Databricks CLI:
```bash
pip install databricks-cli
databricks configure --token
```

### Frontend build fails

Install Node.js 18+ and run:
```bash
cd frontend
rm -rf node_modules package-lock.json
npm install
```

## Technology Stack

- **Frontend**: React 18, TypeScript, Material-UI v5, Framer Motion, Vite
- **Backend**: FastAPI, Uvicorn, Python 3.9+
- **Deployment**: Databricks Apps, Databricks CLI
- **Build Tools**: Python, npm

## Contributing

This is a personal utility command. Feel free to fork and customize for your needs!

## License

MIT License - Feel free to use and modify as needed.

## Credits

Built with Claude Code 🤖

---

## Example Session

```bash
# Clone and install
git clone <repository-url>
cd claude-dbapps-command
./install.sh

# Create a new app
cd ~/projects
# In Claude Code, type: /dbapps
# Claude creates the app structure

# Develop locally
cd my-app/frontend && npm install && npm run dev

# Deploy to Databricks
cd my-app
python deploy_to_databricks.py

# App is live! 🚀
# https://my-app-123456789.aws.databricksapps.com
```

## What's Next?

After installation, try creating your first app:
1. Open Claude Code
2. Type `/dbapps`
3. Watch Claude build your app!

Happy coding! 🎉
