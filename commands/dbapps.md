---
description: Create a React + FastAPI app with MUI, Framer Motion, and Databricks deployment
---

Create a new React + FastAPI application with the following structure and features:

## Project Structure
Create a project with separate frontend and backend folders:
- `frontend/` - React application with TypeScript, MUI, and Framer Motion
- `backend/` - FastAPI application that serves static files in production
- `build.py` - Build script to compile everything for Databricks deployment
- `app.yaml` - Databricks app configuration

## Frontend Requirements
Create a React application in the `frontend/` folder with:

1. **Dependencies**: Install React, TypeScript, MUI (@mui/material, @mui/icons-material, @emotion/react, @emotion/styled), and Framer Motion

2. **App Structure**:
   - Top AppBar with title, menu button, and API Docs link
     - Title should use flexGrow: 1 to push docs link to the right
     - API Docs button with Api icon that links to `/docs` (opens in new tab)
   - Retractable Drawer navigation on the left side that:
     - Starts in expanded mode showing text labels
     - Can be minimized to icon-only mode
     - Has smooth transitions using Framer Motion
   - Main content area that adjusts based on drawer state
   - Include sample navigation items (Dashboard, Analytics, Reports, Settings)

3. **Styling**: Use MUI theming with a modern color scheme

4. **Build Configuration**: Configure Vite to output static files to `frontend/dist` with proper base path

## Backend Requirements
Create a FastAPI application in the `backend/` folder with:

1. **Dependencies**: FastAPI, uvicorn, python-dotenv

2. **Features**:
   - Health check endpoint at `/api/health`
   - Sample data endpoint at `/api/data`
   - Static file serving from `../frontend/dist` directory
   - CORS middleware configured for local development
   - Catch-all route to serve React app for client-side routing

3. **Structure**:
   - `main.py` - Main FastAPI application
   - `requirements.txt` - Python dependencies
   - `.env` - Environment configuration

## Build Script
Create `build.py` that:
- Installs frontend dependencies
- Builds the React app to static files
- Ensures backend has required dependencies
- Prepares the project for Databricks deployment

## Deployment Script
Create `deploy_to_databricks.py` based on the template at `~/.claude/commands/deploy_to_databricks_template.py` with the following features:

### Core Functionality
- **CLI Check**: Verifies Databricks CLI is installed and configured
- **Scope Management**: Lists available secret scopes, allows selection or creation of new scopes
- **Secrets Management**: Handles databricks-token, databricks-api-url, openai-api-key, anthropic-api-key, and session-secret
- **Build Pipeline**: Builds frontend, copies static files, packages backend
- **Workspace Import**: Imports packaged app to Databricks workspace
- **App Deployment**: Creates and deploys app with proper configuration
- **Hard Redeploy**: Option to delete existing app, wait for deletion, then redeploy fresh

### Key Classes
- `SecretConfig`: Configuration for a secret (key, value, description)
- `ScopeInfo`: Information about a Databricks scope (name, owner, created_at, secret_count)
- `DatabricksDeployer`: Main deployment orchestration class

### Main Methods
- `check_databricks_cli()`: Check if CLI is installed and configured
- `list_scopes()`: List all available secret scopes with secret counts
- `select_scope()`: Interactive scope selection (supports number or name)
- `create_scope()`: Create a new secret scope
- `get_secret_values()`: Prompt for secret values (with hidden input for tokens)
- `add_secrets_to_scope()`: Add all secrets to selected scope
- `build_frontend()`: Build React app using npm run build
- `copy_static_files()`: Copy frontend/dist to backend/static
- `package_backend()`: Package backend excluding unnecessary files (venv, __pycache__, tests, etc.)
- `import_to_workspace()`: Import to Databricks workspace using `databricks workspace import-dir`
- `deploy_app()`: Deploy using `databricks apps deploy`
- `hard_redeploy()`: Complete redeploy workflow with deletion and waiting
- `wait_for_app_deletion()`: Wait for app deletion to complete (5 min timeout)
- `get_app_info()`: Get and display app information and URL
- `cleanup()`: Clean up temporary files

### Command Line Arguments
- `--app-name`: App name (default from project)
- `--app-folder`: Workspace folder path
- `--hard-redeploy`: Enable hard redeploy mode

### Usage Examples
```bash
# Normal deployment
python deploy_to_databricks.py

# Hard redeploy (delete and redeploy)
python deploy_to_databricks.py --hard-redeploy

# Custom app name and folder
python deploy_to_databricks.py --app-name my-app --app-folder /Workspace/Users/user@example.com/my-app
```

### Important Notes
- Excludes patterns: venv, __pycache__, test files, .env templates, build artifacts
- Generates random session-secret automatically using secrets.token_urlsafe(32)
- Creates minimal app.yaml with command: ["uvicorn", "app:app"]
- Provides interactive scope selection showing first 20 scopes
- Uses emoji indicators for status (🔍 checking, ✅ success, ❌ error, ⚠️ warning, etc.)
- Handles keyboard interrupts gracefully
- Validates connection before deployment
- Shows app URL and status after deployment

## Databricks Configuration
Create `app.yaml` with:
- Command to run the FastAPI server (uvicorn app:app --host 0.0.0.0 --port 8000)
- Environment variables section with:
  - ENV=production
  - PORT=8000
  - DEBUG=False
- Resource requirements (cpu: "1", memory: "2Gi")
- App description

## Development Setup
Include instructions for:
- Local development (frontend on port 5173, backend on port 8000)
- Building for production using `python build.py`
- Deploying to Databricks using `python deploy.py` (handles CLI setup automatically)

Ensure all files are properly configured with TypeScript types, proper imports, and production-ready code. Include a comprehensive README.md with setup and deployment instructions.
