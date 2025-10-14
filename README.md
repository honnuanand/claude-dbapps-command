# Claude Code `/dbapps` Command

A powerful Claude Code slash command that generates production-ready React + FastAPI applications with automated Databricks deployment.

## What is this?

This repository contains a custom slash command for [Claude Code](https://claude.ai/claude-code) that:

- Creates a full-stack React + FastAPI application
- Includes TypeScript, Material-UI, and Framer Motion
- Provides automated build and deployment scripts
- Deploys to Databricks Apps with one command
- Auto-detects workspace info and user credentials

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

## Uninstalling

To remove the command:

```bash
rm ~/.claude/commands/dbapps.md
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
