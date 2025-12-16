---
description: Add an in-app Test Runner framework to a Databricks App (React + FastAPI)
---

Add an in-app Test Runner framework to a Databricks App that runs within the app's SSO boundaries.

## Overview
This command creates an in-app test runner that:
- Runs directly in the browser within Databricks SSO authentication
- Tests API endpoints, data connectivity, and feature availability
- Provides real-time progress feedback with pass/fail results
- Exports test reports as JSON for documentation/CI
- Works in both localhost and deployed Databricks environments

## Why In-App Testing?
Unlike external test frameworks (pytest, Playwright), this runner:
- Executes within the authenticated Databricks session
- Tests the actual production endpoints with real OAuth tokens
- Validates connectivity to Unity Catalog, LakeBase, SQL Warehouse
- Can be accessed by users/admins to verify system health
- No separate test infrastructure required

## Directory Structure
Create the following structure in `frontend/src/testing/`:

```
frontend/src/testing/
├── index.ts              # Module exports
├── TestRunner.tsx        # Main React UI component
├── types.ts              # TypeScript interfaces
├── utils/
│   ├── testExecutor.ts   # Test execution engine
│   └── assertions.ts     # Assertion utilities
└── tests/
    ├── index.ts          # Test category exports
    ├── health.tests.ts   # Health/connectivity tests
    ├── dashboard.tests.ts
    └── [feature].tests.ts
```

## Core Files

### 1. types.ts - TypeScript Interfaces

```typescript
export type TestStatus = 'pending' | 'running' | 'passed' | 'failed' | 'skipped';

export interface TestResult {
  id: string;
  category: string;
  name: string;
  description: string;
  status: TestStatus;
  duration?: number;
  error?: string;
  details?: string;
}

export interface TestReport {
  runId: string;
  timestamp: string;
  environment: string;
  user?: string;
  summary: {
    total: number;
    passed: number;
    failed: number;
    skipped: number;
    duration: number;
  };
  results: TestResult[];
}

export interface Test {
  name: string;
  description: string;
  fn: () => Promise<void>;
}

export interface TestCategory {
  name: string;
  description: string;
  tests: Test[];
}
```

### 2. utils/assertions.ts - Assertion Utilities

```typescript
export const assert = {
  isTrue: (value: unknown, message?: string) => {
    if (!value) {
      throw new Error(message || `Expected true but got ${value}`);
    }
  },

  equals: (actual: unknown, expected: unknown, message?: string) => {
    if (actual !== expected) {
      throw new Error(message || `Expected ${expected} but got ${actual}`);
    }
  },

  hasProperty: (obj: Record<string, unknown> | null | undefined, property: string, message?: string) => {
    if (!obj || !(property in obj)) {
      throw new Error(message || `Object does not have property '${property}'`);
    }
  },

  isArray: (value: unknown, message?: string) => {
    if (!Array.isArray(value)) {
      throw new Error(message || `Expected array but got ${typeof value}`);
    }
  },

  arrayMinLength: (arr: unknown[], minLength: number, message?: string) => {
    if (arr.length < minLength) {
      throw new Error(message || `Expected array length >= ${minLength} but got ${arr.length}`);
    }
  },

  statusCode: (actual: number, expected: number, message?: string) => {
    if (actual !== expected) {
      throw new Error(message || `Expected status ${expected} but got ${actual}`);
    }
  },

  statusCodeIn: (actual: number, expectedCodes: number[], message?: string) => {
    if (!expectedCodes.includes(actual)) {
      throw new Error(message || `Expected status in [${expectedCodes.join(', ')}] but got ${actual}`);
    }
  },

  greaterThan: (actual: number, expected: number, message?: string) => {
    if (actual <= expected) {
      throw new Error(message || `Expected ${actual} to be greater than ${expected}`);
    }
  },
};
```

### 3. utils/testExecutor.ts - Test Execution Engine

```typescript
import { TestResult, TestCategory, TestReport } from '../types';

export class TestExecutor {
  private results: TestResult[] = [];
  private onProgress?: (result: TestResult) => void;
  private onComplete?: (report: TestReport) => void;
  private startTime: number = 0;
  private shouldStop: boolean = false;
  private runId: string = '';

  constructor(
    private categories: TestCategory[],
    callbacks?: {
      onProgress?: (result: TestResult) => void;
      onComplete?: (report: TestReport) => void;
    }
  ) {
    this.onProgress = callbacks?.onProgress;
    this.onComplete = callbacks?.onComplete;
  }

  async runAll(): Promise<TestReport> {
    this.results = [];
    this.shouldStop = false;
    this.startTime = Date.now();
    this.runId = `test-run-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

    for (const category of this.categories) {
      if (this.shouldStop) break;

      for (const test of category.tests) {
        if (this.shouldStop) break;

        const result = await this.runTest(category.name, test.name, test.description, test.fn);
        this.results.push(result);

        if (this.onProgress) {
          this.onProgress(result);
        }
      }
    }

    const report = this.generateReport();
    if (this.onComplete) {
      this.onComplete(report);
    }
    return report;
  }

  async runTest(
    category: string,
    name: string,
    description: string,
    testFn: () => Promise<void>
  ): Promise<TestResult> {
    const testId = `${category}-${name}`.toLowerCase().replace(/\s+/g, '-');
    const testStartTime = Date.now();

    const result: TestResult = {
      id: testId,
      category,
      name,
      description,
      status: 'running',
    };

    try {
      await testFn();
      result.status = 'passed';
      result.duration = Date.now() - testStartTime;
    } catch (error: unknown) {
      result.status = 'failed';
      result.duration = Date.now() - testStartTime;
      result.error = error instanceof Error ? error.message : String(error);
    }

    return result;
  }

  stop(): void {
    this.shouldStop = true;
  }

  private generateReport(): TestReport {
    const totalDuration = Date.now() - this.startTime;
    return {
      runId: this.runId,
      timestamp: new Date().toISOString(),
      environment: window.location.hostname.includes('databricks') ? 'databricks' : 'localhost',
      summary: {
        total: this.results.length,
        passed: this.results.filter(r => r.status === 'passed').length,
        failed: this.results.filter(r => r.status === 'failed').length,
        skipped: this.results.filter(r => r.status === 'skipped').length,
        duration: totalDuration,
      },
      results: this.results,
    };
  }
}
```

### 4. TestRunner.tsx - Main React Component

```typescript
import { useState } from 'react';
import {
  Box, Paper, Typography, Button, LinearProgress, List, ListItem,
  ListItemText, ListItemIcon, Chip, Alert, IconButton, Collapse,
  Divider, Card, CardContent,
} from '@mui/material';
import {
  PlayArrow, Stop, CheckCircle, Error, Pending,
  ExpandMore, ExpandLess, Download, ContentCopy,
} from '@mui/icons-material';
import { TestExecutor } from './utils/testExecutor';
import { TestResult, TestReport, TestStatus, TestCategory } from './types';
import { allTests } from './tests';

const TestRunner: React.FC = () => {
  const [isRunning, setIsRunning] = useState(false);
  const [results, setResults] = useState<TestResult[]>([]);
  const [report, setReport] = useState<TestReport | null>(null);
  const [executor, setExecutor] = useState<TestExecutor | null>(null);
  const [expandedCategories, setExpandedCategories] = useState<Set<string>>(
    new Set(allTests.map(c => c.name))
  );

  const totalTests = allTests.reduce((sum, cat) => sum + cat.tests.length, 0);
  const completedTests = results.filter(r => r.status !== 'pending' && r.status !== 'running').length;
  const progress = totalTests > 0 ? (completedTests / totalTests) * 100 : 0;

  const handleRunTests = () => {
    setIsRunning(true);
    setResults([]);
    setReport(null);

    const newExecutor = new TestExecutor(allTests, {
      onProgress: (result) => setResults((prev) => [...prev, result]),
      onComplete: (finalReport) => {
        setReport(finalReport);
        setIsRunning(false);
      },
    });

    setExecutor(newExecutor);
    newExecutor.runAll();
  };

  const handleStopTests = () => {
    executor?.stop();
    setIsRunning(false);
  };

  const exportReport = () => {
    if (!report) return;
    const blob = new Blob([JSON.stringify(report, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `test-report-${report.runId}.json`;
    a.click();
    URL.revokeObjectURL(url);
  };

  // ... render UI with progress bar, category expansion, results list
  return (
    <Box sx={{ p: 3 }}>
      {/* Header with Run/Stop buttons */}
      {/* Progress bar when running */}
      {/* Summary cards (total, passed, failed) */}
      {/* Collapsible test categories with results */}
    </Box>
  );
};

export default TestRunner;
```

### 5. tests/health.tests.ts - Example Test Category

```typescript
import { TestCategory } from '../types';
import { assert } from '../utils/assertions';
import api from '../../services/api';

export const healthTests: TestCategory = {
  name: 'Health & Connectivity',
  description: 'Tests for API health, database connectivity, and service status',
  tests: [
    {
      name: 'API Health Check',
      description: 'Verify the backend API is reachable',
      fn: async () => {
        const response = await api.get('/health');
        assert.statusCodeIn(response.status, [200, 204], 'Health endpoint should return 200 or 204');
      },
    },
    {
      name: 'Quick Status Check',
      description: 'Check system dependencies (Warehouse, UC, LakeBase)',
      fn: async () => {
        const response = await api.get('/api/health/quick');
        assert.statusCode(response.status, 200);
        assert.hasProperty(response.data, 'overall');
        assert.hasProperty(response.data, 'warehouse');
        assert.hasProperty(response.data, 'lakebase');

        if (response.data.overall !== 'healthy') {
          console.log(`WARNING: System is ${response.data.overall}`);
        }
      },
    },
    {
      name: 'Database Connectivity',
      description: 'Verify LakeBase connection works',
      fn: async () => {
        const response = await api.get('/api/v1/data/alerts?limit=1');
        assert.statusCode(response.status, 200);
        assert.isArray(response.data);
      },
    },
  ],
};
```

### 6. tests/index.ts - Export All Test Categories

```typescript
import { healthTests } from './health.tests';
import { dashboardTests } from './dashboard.tests';
import { dataTests } from './data.tests';

export const allTests = [
  healthTests,
  dashboardTests,
  dataTests,
];

export { healthTests, dashboardTests, dataTests };
```

### 7. index.ts - Module Exports

```typescript
export { default as TestRunner } from './TestRunner';
export { TestExecutor } from './utils/testExecutor';
export { assert } from './utils/assertions';
export { allTests } from './tests';
export * from './types';
```

## Integration with Navigation

**ASK THE USER** where they want the Test Runner link placed:
- In the main navigation drawer/sidebar
- On the login/landing page
- In a settings/admin section
- Hidden (accessible via direct URL only)

Example integration patterns:

```typescript
// Option 1: In NavigationDrawer.tsx (sidebar navigation)
{
  name: 'Test Runner',
  path: '/test-runner',
  icon: <BugReport />,
  component: TestRunner
}

// Option 2: In App.tsx routes (always add the route)
<Route path="/test-runner" element={<TestRunner />} />

// Option 3: As a link on login page
<Link to="/test-runner">System Health Check</Link>
```

## Test Categories to Create

The in-app Test Runner supports two types of tests:

### 1. API Tests (Backend Validation)
Tests that validate FastAPI endpoints, data connectivity, and backend services:

```typescript
// tests/api.tests.ts
export const apiTests: TestCategory = {
  name: 'API Endpoints',
  description: 'Backend API endpoint validation',
  tests: [
    {
      name: 'GET /api/v1/data/alerts',
      description: 'Fetch alerts with pagination',
      fn: async () => {
        const response = await api.get('/api/v1/data/alerts?limit=10&offset=0');
        assert.statusCode(response.status, 200);
        assert.isArray(response.data);
        assert.hasProperty(response.data[0], 'id');
      },
    },
    {
      name: 'POST /api/v1/data/alerts',
      description: 'Create a new alert',
      fn: async () => {
        const response = await api.post('/api/v1/data/alerts', {
          title: 'Test Alert',
          severity: 'low',
        });
        assert.statusCode(response.status, 201);
        assert.hasProperty(response.data, 'id');
      },
    },
    {
      name: 'Query with filters',
      description: 'Test filtering and search',
      fn: async () => {
        const response = await api.get('/api/v1/data/alerts?severity=high&status=open');
        assert.statusCode(response.status, 200);
        response.data.forEach((alert: any) => {
          assert.equals(alert.severity, 'high');
        });
      },
    },
  ],
};
```

### 2. UI/Playwright-style Tests (Frontend Validation)
Tests that validate UI components, navigation, and user interactions:

```typescript
// tests/ui-pages.tests.ts
export const uiPagesTests: TestCategory = {
  name: 'UI Pages & Navigation',
  description: 'Frontend page rendering and navigation tests',
  tests: [
    {
      name: 'Dashboard renders',
      description: 'Verify dashboard page loads with data',
      fn: async () => {
        // Navigate to dashboard (if using React Router)
        window.history.pushState({}, '', '/dashboard');

        // Wait for data to load
        await new Promise(resolve => setTimeout(resolve, 1000));

        // Check for expected elements
        const dashboard = document.querySelector('[data-testid="dashboard"]');
        assert.isTrue(!!dashboard, 'Dashboard container should exist');

        const widgets = document.querySelectorAll('[data-testid="widget"]');
        assert.greaterThan(widgets.length, 0, 'Should have at least one widget');
      },
    },
    {
      name: 'Navigation works',
      description: 'Test sidebar navigation links',
      fn: async () => {
        const navItems = document.querySelectorAll('[data-testid="nav-item"]');
        assert.greaterThan(navItems.length, 0, 'Should have navigation items');

        // Click first nav item and verify URL changes
        (navItems[0] as HTMLElement).click();
        await new Promise(resolve => setTimeout(resolve, 500));

        assert.isTrue(window.location.pathname !== '/', 'URL should change after navigation');
      },
    },
    {
      name: 'Data table loads',
      description: 'Verify data table renders with rows',
      fn: async () => {
        window.history.pushState({}, '', '/data-viewer');
        await new Promise(resolve => setTimeout(resolve, 1500));

        const rows = document.querySelectorAll('table tbody tr');
        assert.greaterThan(rows.length, 0, 'Table should have data rows');
      },
    },
  ],
};
```

### 3. Integration Tests (API + UI)
Tests that validate end-to-end workflows:

```typescript
// tests/integration.tests.ts
export const integrationTests: TestCategory = {
  name: 'Integration Tests',
  description: 'End-to-end workflow validation',
  tests: [
    {
      name: 'Create and view alert',
      description: 'Create alert via API, verify it appears in UI',
      fn: async () => {
        // Create via API
        const createResponse = await api.post('/api/v1/data/alerts', {
          title: `Integration Test ${Date.now()}`,
          severity: 'medium',
        });
        assert.statusCode(createResponse.status, 201);
        const alertId = createResponse.data.id;

        // Navigate to alerts page
        window.history.pushState({}, '', '/alerts');
        await new Promise(resolve => setTimeout(resolve, 1500));

        // Verify alert appears in table
        const alertRow = document.querySelector(`[data-alert-id="${alertId}"]`);
        assert.isTrue(!!alertRow, 'New alert should appear in table');

        // Cleanup - delete the test alert
        await api.delete(`/api/v1/data/alerts/${alertId}`);
      },
    },
  ],
};
```

### Recommended Test Categories

Based on your app features, create these test categories:

| Category | Type | Tests |
|----------|------|-------|
| **Health & Connectivity** | API | Health endpoints, database, service dependencies |
| **Authentication** | API | OAuth token validation, user context, permissions |
| **Data Endpoints** | API | CRUD operations, pagination, filtering, search |
| **UI Pages** | UI | Page rendering, component visibility, loading states |
| **Navigation** | UI | Sidebar links, routing, breadcrumbs |
| **Dashboard Widgets** | API+UI | Widget data loading, chart rendering |
| **Data Tables** | API+UI | Table rendering, sorting, filtering |
| **Forms** | UI | Input validation, submission, error display |
| **Feature-specific** | API+UI | Genie chat, Agents, custom features |

## Key Features

### Real-time Progress
- Tests run sequentially with live status updates
- Progress bar shows completion percentage
- Results appear as each test completes

### Category Grouping
- Tests organized by functional area
- Collapsible sections for easy navigation
- Run individual categories or all tests

### Report Export
- JSON report with full results
- Copy to clipboard support
- Includes environment, timing, errors

### Error Handling
- Graceful handling of service unavailability
- Detailed error messages with stack traces
- Non-blocking failures (one test failure doesn't stop others)

## Usage Pattern for Tests

```typescript
// Pattern: Test with graceful degradation
{
  name: 'External Service Check',
  description: 'Check optional service availability',
  fn: async () => {
    try {
      const response = await api.get('/api/v1/service/health');
      assert.statusCode(response.status, 200);
    } catch (error: unknown) {
      const axiosError = error as { response?: { status: number } };
      // Service not configured is acceptable
      if (axiosError.response?.status === 503) {
        console.log('Service not configured (expected)');
        return; // Pass the test
      }
      throw error; // Re-throw unexpected errors
    }
  },
},
```

## Important Notes

- Tests run in the browser with full SSO context
- Uses the app's configured API client (axios instance)
- Works in both local dev and deployed Databricks environments
- Keep tests fast (< 5 seconds each for good UX)
- Use console.log for debug output visible in browser console
- Export reports for CI/CD integration or documentation
