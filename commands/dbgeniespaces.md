# Databricks Genie Spaces Builder Guide

This guide helps you build comprehensive Genie Spaces through an interactive discovery process. Focus is on understanding user data, crafting visualization-ready questions, and scripted automation.

> **Note**: For UI integration (frontend components, backend routers), see the `/dbaiassistant` command which contains all UI implementation details.

---

## Quick Start: Auto-Analyze Schema and Create Spaces

If the user points you at a schema, run the **Auto-Analyze and Create** script below to:
1. Analyze all tables in the schema
2. Auto-group tables by naming patterns (prefixes like `sales_`, `hr_`, `ops_`)
3. Generate multiple themed Genie spaces
4. Create visualization-ready curated questions for each

```bash
# Quick command - analyze schema and generate space configs
python auto_create_spaces.py --catalog MY_CATALOG --schema MY_SCHEMA --warehouse-id WAREHOUSE_ID --profile PROFILE
```

See [Auto-Create Multiple Spaces from Schema](#auto-create-multiple-spaces-from-schema) section for the full script.

---

## Interactive Discovery Process

When a user wants to build a Genie Space, guide them through these questions:

### Step 1: Understand the Domain

Ask the user:
1. **What domain does this data cover?** (e.g., Sales, Operations, HR, Finance, Security)
2. **Who will use this Genie Space?** (Analysts, Executives, Operations staff)
3. **What decisions will they make with this data?**
4. **What are the 5-10 most common questions they ask today?**

### Step 2: Identify Unity Catalog Location

Ask the user:
1. **What catalog contains your data?**
2. **What schema(s) should be included?**
3. **Do you have a SQL warehouse ID, or should I help find one?**

Then run discovery:

```bash
# List catalogs
databricks unity-catalog catalogs list --profile $PROFILE

# List schemas in a catalog
databricks unity-catalog schemas list --catalog-name $CATALOG --profile $PROFILE

# List tables in a schema
databricks unity-catalog tables list --catalog-name $CATALOG --schema-name $SCHEMA --profile $PROFILE
```

### Step 3: Analyze Tables for Visualization Potential

For each table, analyze its structure to understand what visualizations are possible:

```bash
# Get table schema
databricks unity-catalog tables get --full-name $CATALOG.$SCHEMA.$TABLE --profile $PROFILE
```

**Identify column types for visualization:**

| Column Pattern | Visualization Potential |
|----------------|------------------------|
| date/timestamp columns | Line charts (trends over time) |
| category/type columns | Bar charts, Pie charts (group by) |
| numeric columns | Aggregations (SUM, AVG, COUNT) |
| geographic columns | Maps, Regional comparisons |
| status/state columns | Pie charts (distribution) |
| hierarchical columns | Drill-down bar charts |

---

## Table Analysis Script

Run this script to analyze tables and generate a report:

```python
#!/usr/bin/env python3
"""
Analyze Unity Catalog tables for Genie Space creation.
Identifies visualization opportunities and suggests sample questions.

Usage: python analyze_tables.py --catalog CATALOG --schema SCHEMA --profile PROFILE
"""

import subprocess
import json
import argparse
from typing import Dict, List, Any

def run_cli(args: List[str], profile: str) -> Dict:
    """Run Databricks CLI command."""
    cmd = ["databricks"] + args + ["--profile", profile, "--output", "json"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        return {"error": result.stderr}
    try:
        return json.loads(result.stdout)
    except:
        return {"output": result.stdout}

def analyze_column(col: Dict) -> Dict:
    """Analyze a column for visualization potential."""
    name = col.get("name", "").lower()
    dtype = col.get("type_name", "").upper()

    analysis = {
        "name": col.get("name"),
        "type": dtype,
        "viz_potential": [],
        "aggregations": [],
        "group_by": False,
    }

    # Date/time columns -> time series
    if dtype in ["DATE", "TIMESTAMP", "TIMESTAMP_NTZ"]:
        analysis["viz_potential"].append("line_chart")
        analysis["viz_potential"].append("trend_analysis")
        analysis["group_by"] = True

    # Numeric columns -> aggregations
    elif dtype in ["INT", "BIGINT", "DOUBLE", "FLOAT", "DECIMAL", "LONG"]:
        analysis["aggregations"] = ["SUM", "AVG", "MIN", "MAX", "COUNT"]
        analysis["viz_potential"].append("bar_chart")
        analysis["viz_potential"].append("kpi_card")

    # String columns -> grouping
    elif dtype in ["STRING", "VARCHAR"]:
        # Check for common categorical patterns
        if any(x in name for x in ["type", "category", "status", "state", "region",
                                    "department", "sector", "level", "tier"]):
            analysis["viz_potential"].append("pie_chart")
            analysis["viz_potential"].append("bar_chart")
            analysis["group_by"] = True
        elif any(x in name for x in ["name", "title", "description"]):
            analysis["viz_potential"].append("table_display")
        elif any(x in name for x in ["country", "state", "city", "region", "location"]):
            analysis["viz_potential"].append("map")
            analysis["viz_potential"].append("bar_chart")
            analysis["group_by"] = True

    return analysis

def suggest_questions(table_name: str, columns: List[Dict]) -> List[Dict]:
    """Generate sample questions based on column analysis."""
    questions = []

    # Find key columns
    date_cols = [c for c in columns if c.get("viz_potential") and "line_chart" in c["viz_potential"]]
    numeric_cols = [c for c in columns if c.get("aggregations")]
    category_cols = [c for c in columns if c.get("group_by") and "pie_chart" in c.get("viz_potential", [])]

    # Time series questions
    for date_col in date_cols[:1]:  # First date column
        for num_col in numeric_cols[:2]:  # First 2 numeric columns
            questions.append({
                "question": f"Show {num_col['name']} trends over time",
                "viz_type": "line_chart",
                "columns": [date_col['name'], num_col['name']],
                "sql_hint": f"SELECT {date_col['name']}, SUM({num_col['name']}) FROM {table_name} GROUP BY {date_col['name']} ORDER BY {date_col['name']}"
            })

    # Category breakdown questions
    for cat_col in category_cols[:2]:
        for num_col in numeric_cols[:1]:
            questions.append({
                "question": f"Compare {num_col['name']} by {cat_col['name']}",
                "viz_type": "bar_chart",
                "columns": [cat_col['name'], num_col['name']],
                "sql_hint": f"SELECT {cat_col['name']}, SUM({num_col['name']}) FROM {table_name} GROUP BY {cat_col['name']} ORDER BY 2 DESC"
            })
            questions.append({
                "question": f"Show distribution of {cat_col['name']}",
                "viz_type": "pie_chart",
                "columns": [cat_col['name']],
                "sql_hint": f"SELECT {cat_col['name']}, COUNT(*) FROM {table_name} GROUP BY {cat_col['name']}"
            })

    # Top N questions
    for num_col in numeric_cols[:2]:
        questions.append({
            "question": f"What are the top 10 by {num_col['name']}?",
            "viz_type": "bar_chart",
            "columns": [num_col['name']],
            "sql_hint": f"SELECT * FROM {table_name} ORDER BY {num_col['name']} DESC LIMIT 10"
        })

    # Aggregation questions
    for num_col in numeric_cols[:3]:
        questions.append({
            "question": f"What is the total {num_col['name']}?",
            "viz_type": "kpi_card",
            "columns": [num_col['name']],
            "sql_hint": f"SELECT SUM({num_col['name']}) as total_{num_col['name']} FROM {table_name}"
        })

    return questions

def analyze_table(catalog: str, schema: str, table: str, profile: str) -> Dict:
    """Analyze a single table."""
    full_name = f"{catalog}.{schema}.{table}"

    # Get table details
    result = run_cli(["unity-catalog", "tables", "get", "--full-name", full_name], profile)

    if "error" in result:
        return {"table": table, "error": result["error"]}

    columns = result.get("columns", [])
    analyzed_columns = [analyze_column(c) for c in columns]
    suggested_questions = suggest_questions(full_name, analyzed_columns)

    return {
        "table": table,
        "full_name": full_name,
        "column_count": len(columns),
        "columns": analyzed_columns,
        "suggested_questions": suggested_questions[:10],  # Top 10 questions
        "viz_summary": {
            "line_chart_ready": any("line_chart" in c.get("viz_potential", []) for c in analyzed_columns),
            "bar_chart_ready": any("bar_chart" in c.get("viz_potential", []) for c in analyzed_columns),
            "pie_chart_ready": any("pie_chart" in c.get("viz_potential", []) for c in analyzed_columns),
            "has_numeric": any(c.get("aggregations") for c in analyzed_columns),
            "has_categories": any(c.get("group_by") for c in analyzed_columns),
        }
    }

def main():
    parser = argparse.ArgumentParser(description="Analyze tables for Genie Space")
    parser.add_argument("--catalog", required=True, help="Unity Catalog name")
    parser.add_argument("--schema", required=True, help="Schema name")
    parser.add_argument("--profile", required=True, help="Databricks CLI profile")
    parser.add_argument("--output", default="table_analysis.json", help="Output file")
    args = parser.parse_args()

    # List tables
    tables_result = run_cli([
        "unity-catalog", "tables", "list",
        "--catalog-name", args.catalog,
        "--schema-name", args.schema
    ], args.profile)

    if "error" in tables_result:
        print(f"Error listing tables: {tables_result['error']}")
        return 1

    tables = [t.get("name") for t in tables_result.get("tables", [])]
    print(f"Found {len(tables)} tables in {args.catalog}.{args.schema}")

    # Analyze each table
    analysis = {
        "catalog": args.catalog,
        "schema": args.schema,
        "tables": []
    }

    for table in tables:
        print(f"  Analyzing: {table}...")
        table_analysis = analyze_table(args.catalog, args.schema, table, args.profile)
        analysis["tables"].append(table_analysis)

    # Write output
    with open(args.output, "w") as f:
        json.dump(analysis, f, indent=2)

    print(f"\nAnalysis saved to {args.output}")

    # Print summary
    print("\n" + "="*60)
    print("VISUALIZATION SUMMARY")
    print("="*60)
    for t in analysis["tables"]:
        viz = t.get("viz_summary", {})
        icons = []
        if viz.get("line_chart_ready"): icons.append("📈")
        if viz.get("bar_chart_ready"): icons.append("📊")
        if viz.get("pie_chart_ready"): icons.append("🥧")
        print(f"  {t['table']}: {' '.join(icons) or '📋 table only'}")

    # Print suggested questions
    print("\n" + "="*60)
    print("TOP SUGGESTED QUESTIONS")
    print("="*60)
    all_questions = []
    for t in analysis["tables"]:
        for q in t.get("suggested_questions", []):
            q["table"] = t["table"]
            all_questions.append(q)

    for q in all_questions[:15]:
        print(f"  [{q['viz_type']}] {q['question']}")

    return 0

if __name__ == "__main__":
    exit(main())
```

---

## Crafting Visualization-Ready Questions

### Question Patterns by Chart Type

#### Bar Charts (Comparisons)
Questions that compare categories produce bar-chart-ready data:

```
Pattern: "Show/Compare [METRIC] by [CATEGORY]"
SQL: SELECT category, SUM(metric) FROM table GROUP BY category ORDER BY 2 DESC

Examples:
- "Show spending by department"
- "Compare revenue by region"
- "What are the top 10 products by sales?"
- "Show apprehensions by border sector"
```

**Data shape needed:**
| category | value |
|----------|-------|
| Category A | 1234 |
| Category B | 987 |

#### Line Charts (Trends)
Questions about changes over time produce line-chart-ready data:

```
Pattern: "Show [METRIC] trends over [TIME_PERIOD]"
SQL: SELECT date_column, SUM(metric) FROM table GROUP BY date_column ORDER BY date_column

Examples:
- "Show monthly sales trends"
- "How has hiring changed over time?"
- "Display revenue trends by quarter"
- "Show apprehension trends for the past 12 months"
```

**Data shape needed:**
| date | value |
|------|-------|
| 2024-01 | 1234 |
| 2024-02 | 1456 |

#### Pie Charts (Distribution)
Questions about proportions produce pie-chart-ready data:

```
Pattern: "Show distribution/breakdown of [CATEGORY]"
SQL: SELECT category, COUNT(*) as count FROM table GROUP BY category

Examples:
- "Show breakdown of spending by category"
- "What is the distribution of employees by department?"
- "Show the percentage breakdown of incident types"
```

**Data shape needed:**
| category | count |
|----------|-------|
| Type A | 45 |
| Type B | 32 |
| Type C | 23 |

#### KPI Cards (Single Values)
Questions asking for totals or averages:

```
Pattern: "What is the total/average [METRIC]?"
SQL: SELECT SUM(metric) as total FROM table

Examples:
- "What is the total budget?"
- "What is the average processing time?"
- "How many open cases are there?"
```

---

## Writing Effective Instructions

### Instruction Template for Visualizations

```markdown
You are a [DOMAIN] analyst assistant.

## Available Tables

[For each table, describe:]
- table_name: What data it contains, key columns, relationships

## Key Business Metrics

[Define the metrics users care about:]
- Metric 1: Definition and how to calculate
- Metric 2: Definition and how to calculate

## Visualization Guidelines

When answering questions, format data for visualizations:

### For Comparisons (Bar Charts)
Return data with columns: [category_name, value]
- Sort by value descending for "top N" questions
- Sort by category alphabetically for complete lists
- Limit to 10-15 categories for readability

### For Trends (Line Charts)
Return data with columns: [date/period, value]
- Sort by date ascending
- Use consistent date granularity (daily, weekly, monthly)
- Include at least 6 data points for meaningful trends

### For Distributions (Pie Charts)
Return data with columns: [category, count/percentage]
- Limit to 6-8 slices maximum
- Group small categories into "Other" if needed
- Include percentage calculations when relevant

### For KPIs (Single Values)
Return a single aggregated value with clear labeling
- Format currency with $ and appropriate scale (K, M, B)
- Format percentages with % symbol
- Include comparison to target/previous period when available

## Common Question Patterns

[Map natural language to SQL patterns:]
- "top N by X" → ORDER BY X DESC LIMIT N
- "breakdown by X" → GROUP BY X
- "trends over time" → GROUP BY date ORDER BY date
- "total X" → SELECT SUM(X)
- "compare X to Y" → Include both in SELECT with GROUP BY

## Sample Questions

[Provide 5-7 curated questions covering different viz types:]
- [Bar] What are the top 10 departments by spending?
- [Line] Show monthly revenue trends for the past year
- [Pie] Show the breakdown of incidents by type
- [KPI] What is the total budget execution rate?
```

---

## Complete Space Creation Script

```python
#!/usr/bin/env python3
"""
Create a Genie Space with visualization-optimized configuration.

This script:
1. Analyzes tables for visualization potential
2. Generates comprehensive instructions
3. Creates curated questions for each chart type
4. Creates the Genie space via API

Usage:
    python create_genie_space.py --config space_config.json --profile PROFILE
"""

import json
import os
import subprocess
import sys
import tempfile
import argparse
from typing import Dict, List, Any

def run_cli(args: List[str], profile: str) -> Dict:
    """Run Databricks CLI command."""
    cmd = ["databricks"] + args + ["--profile", profile]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        return {"error": result.stderr}
    try:
        return json.loads(result.stdout)
    except:
        return {"output": result.stdout}

def analyze_tables_for_viz(catalog: str, schema: str, tables: List[str], profile: str) -> Dict:
    """Analyze tables and identify visualization opportunities."""
    analysis = {"tables": [], "viz_questions": {"bar": [], "line": [], "pie": [], "kpi": []}}

    for table in tables:
        full_name = f"{catalog}.{schema}.{table}"
        result = run_cli(["unity-catalog", "tables", "get", "--full-name", full_name, "--output", "json"], profile)

        if "error" in result:
            continue

        columns = result.get("columns", [])

        # Identify column types
        date_cols = [c["name"] for c in columns if c.get("type_name", "").upper() in ["DATE", "TIMESTAMP", "TIMESTAMP_NTZ"]]
        numeric_cols = [c["name"] for c in columns if c.get("type_name", "").upper() in ["INT", "BIGINT", "DOUBLE", "FLOAT", "DECIMAL", "LONG"]]
        category_cols = [c["name"] for c in columns if c.get("type_name", "").upper() in ["STRING", "VARCHAR"] and
                        any(x in c["name"].lower() for x in ["type", "category", "status", "region", "department", "sector"])]

        table_info = {
            "name": table,
            "full_name": full_name,
            "date_columns": date_cols,
            "numeric_columns": numeric_cols,
            "category_columns": category_cols,
        }
        analysis["tables"].append(table_info)

        # Generate visualization-ready questions
        for cat in category_cols[:2]:
            for num in numeric_cols[:2]:
                analysis["viz_questions"]["bar"].append(f"Show {num} by {cat} from {table}")
                analysis["viz_questions"]["pie"].append(f"Show distribution of {cat} in {table}")

        for date in date_cols[:1]:
            for num in numeric_cols[:2]:
                analysis["viz_questions"]["line"].append(f"Show {num} trends over time from {table}")

        for num in numeric_cols[:3]:
            analysis["viz_questions"]["kpi"].append(f"What is the total {num}?")

    return analysis

def generate_instructions(domain: str, tables_info: List[Dict], analysis: Dict) -> str:
    """Generate comprehensive instructions for the Genie space."""

    # Build table descriptions
    table_docs = []
    for t in tables_info:
        cols_summary = []
        if t.get("date_columns"):
            cols_summary.append(f"dates: {', '.join(t['date_columns'][:3])}")
        if t.get("numeric_columns"):
            cols_summary.append(f"metrics: {', '.join(t['numeric_columns'][:5])}")
        if t.get("category_columns"):
            cols_summary.append(f"categories: {', '.join(t['category_columns'][:3])}")

        table_docs.append(f"- {t['name']}: {'; '.join(cols_summary) or 'general data'}")

    instructions = f"""You are a {domain} analytics assistant.

## Available Tables

{chr(10).join(table_docs)}

## Visualization Guidelines

When users ask questions, structure your SQL to produce visualization-ready data:

### Bar Charts (Comparisons)
For questions like "show X by Y" or "compare X across Y":
- Return exactly 2 columns: [category, value]
- Sort by value DESC for "top N" questions
- Limit to 10-15 rows for readability
- Example: SELECT department, SUM(amount) FROM spending GROUP BY department ORDER BY 2 DESC LIMIT 10

### Line Charts (Trends)
For questions about "trends", "over time", "monthly/weekly":
- Return exactly 2 columns: [date/period, value]
- Sort by date ASC
- Use appropriate date truncation (DATE_TRUNC)
- Example: SELECT DATE_TRUNC('month', date) as month, SUM(value) FROM metrics GROUP BY 1 ORDER BY 1

### Pie Charts (Distribution)
For questions about "breakdown", "distribution", "percentage":
- Return exactly 2 columns: [category, count]
- Limit to 6-8 slices
- Group small values into "Other" if needed
- Example: SELECT type, COUNT(*) FROM incidents GROUP BY type

### KPI Cards (Single Values)
For questions about "total", "average", "how many":
- Return a single aggregated value
- Use clear column aliases
- Example: SELECT SUM(budget) as total_budget FROM allocations

## Response Formatting

1. Always explain what the data shows
2. Highlight key insights (highest/lowest values, trends)
3. Suggest follow-up questions for deeper analysis

## Domain-Specific Terms

[Add any domain-specific terminology or business logic here]
"""

    return instructions

def generate_curated_questions(analysis: Dict) -> List[str]:
    """Generate a diverse set of curated questions covering all viz types."""
    questions = []

    # Take 2-3 from each category for variety
    for viz_type, q_list in analysis["viz_questions"].items():
        questions.extend(q_list[:3])

    # Deduplicate and limit
    return list(dict.fromkeys(questions))[:10]

def build_serialized_space(catalog: str, schema: str, tables: List[str]) -> str:
    """Build the serialized_space JSON structure."""
    table_configs = [
        {"identifier": f"{catalog}.{schema}.{t}", "column_configs": []}
        for t in sorted(tables)
    ]

    return json.dumps({
        "version": 1,
        "data_sources": {"tables": table_configs}
    })

def create_genie_space(config: Dict, profile: str) -> Dict:
    """Create the Genie Space via Databricks API."""

    # Analyze tables
    print("Analyzing tables for visualization potential...")
    analysis = analyze_tables_for_viz(
        config["catalog"],
        config["schema"],
        config["tables"],
        profile
    )

    # Generate instructions
    print("Generating instructions...")
    instructions = generate_instructions(
        config["domain"],
        analysis["tables"],
        analysis
    )

    # Use provided curated questions or generate them
    curated_questions = config.get("curated_questions") or generate_curated_questions(analysis)

    # Build API payload
    payload = {
        "warehouse_id": config["warehouse_id"],
        "title": config["title"],
        "description": config["description"],
        "serialized_space": build_serialized_space(config["catalog"], config["schema"], config["tables"]),
        "instructions": instructions,
        "curated_questions": "\n".join([f"- {q}" for q in curated_questions])
    }

    # Write to temp file and create via API
    with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
        json.dump(payload, f)
        temp_file = f.name

    try:
        print("Creating Genie space...")
        result = subprocess.run(
            ["databricks", "api", "post", "/api/2.0/genie/spaces",
             "--json", f"@{temp_file}",
             "--profile", profile],
            capture_output=True, text=True
        )

        if result.returncode != 0:
            return {"error": result.stderr}

        response = json.loads(result.stdout)
        return {
            "space_id": response.get("space_id"),
            "title": config["title"],
            "curated_questions": curated_questions
        }
    finally:
        os.unlink(temp_file)

def main():
    parser = argparse.ArgumentParser(description="Create a visualization-optimized Genie Space")
    parser.add_argument("--config", required=True, help="Path to space configuration JSON")
    parser.add_argument("--profile", required=True, help="Databricks CLI profile")
    args = parser.parse_args()

    # Load config
    with open(args.config) as f:
        config = json.load(f)

    print("="*60)
    print(f"Creating Genie Space: {config['title']}")
    print("="*60)

    result = create_genie_space(config, args.profile)

    if "error" in result:
        print(f"\nFailed: {result['error']}")
        return 1

    print(f"\nSuccess!")
    print(f"Space ID: {result['space_id']}")
    print(f"\nCurated Questions:")
    for q in result['curated_questions']:
        print(f"  - {q}")

    print(f"\n" + "="*60)
    print("NEXT STEPS")
    print("="*60)
    print(f"""
1. Add to app.yaml:
   resources:
     - name: genie-space-{config['title'].lower().replace(' ', '-')}
       genie_space:
         space_id: {result['space_id']}
         permission: CAN_EDIT

2. Grant Service Principal permissions (see below)

3. For UI integration, see /dbaiassistant command
""")

    return 0

if __name__ == "__main__":
    exit(main())
```

**Sample config file (space_config.json):**

```json
{
  "title": "Sales Analytics",
  "description": "Query sales, orders, and revenue data with natural language",
  "domain": "Sales",
  "catalog": "my_catalog",
  "schema": "sales_data",
  "warehouse_id": "abc123def456",
  "tables": [
    "orders",
    "customers",
    "products",
    "sales_summary",
    "revenue_by_region"
  ],
  "curated_questions": [
    "What are the top 10 products by revenue?",
    "Show monthly sales trends for the past year",
    "Compare revenue by region as a bar chart",
    "What is the total revenue this quarter?",
    "Show the breakdown of orders by status",
    "Which customers have the highest order values?",
    "Show daily order trends for the past 30 days"
  ]
}
```

---

## Service Principal Permissions

After creating a space, grant the app's Service Principal access:

```bash
# 1. Grant Genie Space access
databricks permissions update genie-space/<SPACE_ID> \
  --json '{
    "access_control_list": [{
      "service_principal_name": "apps/<YOUR_APP_NAME>",
      "permission_level": "CAN_RUN"
    }]
  }' --profile $PROFILE

# 2. Grant SQL Warehouse access
databricks permissions update warehouses/<WAREHOUSE_ID> \
  --json '{
    "access_control_list": [{
      "service_principal_name": "apps/<YOUR_APP_NAME>",
      "permission_level": "CAN_USE"
    }]
  }' --profile $PROFILE

# 3. Grant Unity Catalog access (run in SQL)
# GRANT USE CATALOG ON CATALOG <catalog> TO `<sp-application-id>`;
# GRANT USE SCHEMA ON SCHEMA <catalog>.<schema> TO `<sp-application-id>`;
# GRANT SELECT ON SCHEMA <catalog>.<schema> TO `<sp-application-id>`;
```

---

## App.yaml Configuration

```yaml
resources:
  - name: genie-space-primary
    genie_space:
      space_id: <SPACE_ID>
      permission: CAN_EDIT

env:
  - name: GENIE_SPACE_ID
    value: "<SPACE_ID>"
```

---

## Batch Space Creation

Create multiple spaces at once:

```python
#!/usr/bin/env python3
"""Create multiple Genie spaces from a configuration file."""

import json
import sys
from create_genie_space import create_genie_space

SPACES = [
    {
        "title": "App - Sales Analytics",
        "description": "Sales, orders, and revenue data",
        "domain": "Sales",
        "catalog": "my_catalog",
        "schema": "sales",
        "warehouse_id": "abc123",
        "tables": ["orders", "customers", "products"]
    },
    {
        "title": "App - Operations Dashboard",
        "description": "KPIs and operational metrics",
        "domain": "Operations",
        "catalog": "my_catalog",
        "schema": "operations",
        "warehouse_id": "abc123",
        "tables": ["kpis", "alerts", "metrics"]
    }
]

def main():
    profile = sys.argv[1] if len(sys.argv) > 1 else "DEFAULT"

    results = []
    for config in SPACES:
        print(f"\nCreating: {config['title']}...")
        result = create_genie_space(config, profile)
        results.append(result)

    # Output app.yaml snippet
    print("\n" + "="*60)
    print("APP.YAML CONFIGURATION")
    print("="*60)
    print("resources:")
    for r in results:
        if "space_id" in r:
            key = r['title'].replace("App - ", "").lower().replace(" ", "-")
            print(f"  - name: genie-space-{key}")
            print(f"    genie_space:")
            print(f"      space_id: {r['space_id']}")
            print(f"      permission: CAN_EDIT")

if __name__ == "__main__":
    main()
```

---

## Auto-Create Multiple Spaces from Schema

This comprehensive script analyzes an entire schema and automatically creates multiple themed Genie spaces:

```python
#!/usr/bin/env python3
"""
Auto-Create Multiple Genie Spaces from Schema Analysis

This script:
1. Lists all tables in a schema
2. Analyzes table structures and identifies visualization potential
3. Auto-groups tables by naming patterns (prefixes, domains)
4. Generates themed Genie spaces with curated questions
5. Creates all spaces via Databricks API

Usage:
    python auto_create_spaces.py --catalog CATALOG --schema SCHEMA --warehouse-id WH_ID --profile PROFILE

Options:
    --dry-run       Show what would be created without actually creating
    --app-name      App name for Service Principal permissions
    --min-tables    Minimum tables per space (default: 2)
"""

import json
import os
import subprocess
import sys
import tempfile
import argparse
import re
from typing import Dict, List, Any, Tuple
from collections import defaultdict

# Common domain prefixes to group tables
DOMAIN_PREFIXES = {
    # Business domains
    "sales": ["sales_", "order_", "revenue_", "customer_"],
    "hr": ["hr_", "employee_", "personnel_", "hiring_", "staff_"],
    "finance": ["finance_", "budget_", "spending_", "cost_", "expense_", "payment_"],
    "operations": ["ops_", "operation_", "kpi_", "metric_", "dashboard_"],
    "inventory": ["inventory_", "stock_", "product_", "warehouse_"],
    "marketing": ["marketing_", "campaign_", "lead_", "conversion_"],

    # Technical domains
    "security": ["security_", "auth_", "access_", "audit_"],
    "compliance": ["compliance_", "audit_", "risk_", "policy_"],
    "analytics": ["analytics_", "report_", "summary_", "aggregate_"],

    # Government/Public Sector
    "border": ["border_", "apprehension_", "cbp_", "port_"],
    "ice": ["ice_", "detention_", "removal_", "deportation_"],
    "cyber": ["cyber_", "threat_", "incident_", "vulnerability_"],
    "personnel": ["personnel_", "staffing_", "vacancy_", "clearance_"],
}


def run_cli(args: List[str], profile: str) -> Dict:
    """Run Databricks CLI command."""
    cmd = ["databricks"] + args + ["--profile", profile, "--output", "json"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        return {"error": result.stderr}
    try:
        return json.loads(result.stdout)
    except:
        return {"output": result.stdout}


def get_all_tables(catalog: str, schema: str, profile: str) -> List[Dict]:
    """Get all tables in a schema with their column info."""
    tables_result = run_cli([
        "unity-catalog", "tables", "list",
        "--catalog-name", catalog,
        "--schema-name", schema
    ], profile)

    if "error" in tables_result:
        print(f"Error listing tables: {tables_result['error']}")
        return []

    tables = []
    for t in tables_result.get("tables", []):
        table_name = t.get("name")
        full_name = f"{catalog}.{schema}.{table_name}"

        # Get column details
        detail_result = run_cli([
            "unity-catalog", "tables", "get",
            "--full-name", full_name
        ], profile)

        if "error" not in detail_result:
            columns = detail_result.get("columns", [])
            tables.append({
                "name": table_name,
                "full_name": full_name,
                "columns": columns,
                "comment": t.get("comment", ""),
            })

    return tables


def analyze_column(col: Dict) -> Dict:
    """Analyze a column for visualization potential."""
    name = col.get("name", "").lower()
    dtype = col.get("type_name", "").upper()

    analysis = {
        "name": col.get("name"),
        "type": dtype,
        "is_date": dtype in ["DATE", "TIMESTAMP", "TIMESTAMP_NTZ"],
        "is_numeric": dtype in ["INT", "BIGINT", "DOUBLE", "FLOAT", "DECIMAL", "LONG"],
        "is_category": False,
        "viz_potential": [],
    }

    if analysis["is_date"]:
        analysis["viz_potential"].extend(["line_chart", "trend"])

    if analysis["is_numeric"]:
        analysis["viz_potential"].extend(["bar_chart", "kpi", "aggregation"])

    if dtype in ["STRING", "VARCHAR"]:
        if any(x in name for x in ["type", "category", "status", "state", "region",
                                    "department", "sector", "level", "tier", "country"]):
            analysis["is_category"] = True
            analysis["viz_potential"].extend(["pie_chart", "bar_chart", "group_by"])

    return analysis


def analyze_table(table: Dict) -> Dict:
    """Analyze a single table for visualization potential."""
    columns = [analyze_column(c) for c in table.get("columns", [])]

    date_cols = [c["name"] for c in columns if c["is_date"]]
    numeric_cols = [c["name"] for c in columns if c["is_numeric"]]
    category_cols = [c["name"] for c in columns if c["is_category"]]

    return {
        **table,
        "analyzed_columns": columns,
        "date_columns": date_cols,
        "numeric_columns": numeric_cols,
        "category_columns": category_cols,
        "viz_ready": {
            "line_chart": len(date_cols) > 0 and len(numeric_cols) > 0,
            "bar_chart": len(category_cols) > 0 and len(numeric_cols) > 0,
            "pie_chart": len(category_cols) > 0,
            "kpi": len(numeric_cols) > 0,
        }
    }


def group_tables_by_domain(tables: List[Dict]) -> Dict[str, List[Dict]]:
    """Group tables by domain based on naming patterns."""
    groups = defaultdict(list)
    ungrouped = []

    for table in tables:
        name = table["name"].lower()
        matched = False

        for domain, prefixes in DOMAIN_PREFIXES.items():
            for prefix in prefixes:
                if name.startswith(prefix) or f"_{prefix.rstrip('_')}_" in name:
                    groups[domain].append(table)
                    matched = True
                    break
            if matched:
                break

        if not matched:
            # Try to extract prefix from table name
            parts = name.split("_")
            if len(parts) > 1:
                prefix = parts[0]
                groups[f"custom_{prefix}"].append(table)
            else:
                ungrouped.append(table)

    # Add ungrouped tables to a "general" group
    if ungrouped:
        groups["general"].append(*ungrouped) if len(ungrouped) == 1 else groups["general"].extend(ungrouped)

    return dict(groups)


def generate_questions_for_table(table: Dict) -> List[Dict]:
    """Generate visualization-ready questions for a table."""
    questions = []
    name = table["name"]
    date_cols = table.get("date_columns", [])
    numeric_cols = table.get("numeric_columns", [])
    category_cols = table.get("category_columns", [])

    # Bar chart questions
    for cat in category_cols[:2]:
        for num in numeric_cols[:2]:
            questions.append({
                "text": f"Show {num.replace('_', ' ')} by {cat.replace('_', ' ')}",
                "viz_type": "bar_chart",
                "table": name,
            })

    # Line chart questions
    for date in date_cols[:1]:
        for num in numeric_cols[:2]:
            questions.append({
                "text": f"Show {num.replace('_', ' ')} trends over time",
                "viz_type": "line_chart",
                "table": name,
            })

    # Pie chart questions
    for cat in category_cols[:2]:
        questions.append({
            "text": f"Show distribution of {cat.replace('_', ' ')}",
            "viz_type": "pie_chart",
            "table": name,
        })

    # KPI questions
    for num in numeric_cols[:2]:
        questions.append({
            "text": f"What is the total {num.replace('_', ' ')}?",
            "viz_type": "kpi",
            "table": name,
        })

    # Top N questions
    if numeric_cols:
        questions.append({
            "text": f"What are the top 10 records by {numeric_cols[0].replace('_', ' ')}?",
            "viz_type": "bar_chart",
            "table": name,
        })

    return questions


def generate_space_config(
    domain: str,
    tables: List[Dict],
    catalog: str,
    schema: str,
    warehouse_id: str,
    app_prefix: str = "App"
) -> Dict:
    """Generate a complete Genie space configuration for a domain."""

    # Generate human-readable title
    title = f"{app_prefix} - {domain.replace('_', ' ').replace('custom ', '').title()} Analytics"

    # Generate description
    table_names = [t["name"] for t in tables]
    description = f"Query and analyze {domain.replace('_', ' ')} data including: {', '.join(table_names[:5])}"
    if len(table_names) > 5:
        description += f" and {len(table_names) - 5} more tables"

    # Collect all questions from tables
    all_questions = []
    for table in tables:
        all_questions.extend(generate_questions_for_table(table))

    # Select diverse questions (mix of viz types)
    curated_questions = []
    viz_types_used = set()
    for q in all_questions:
        if q["viz_type"] not in viz_types_used or len(curated_questions) < 10:
            curated_questions.append(q["text"])
            viz_types_used.add(q["viz_type"])
        if len(curated_questions) >= 10:
            break

    # Build table documentation for instructions
    table_docs = []
    for t in tables:
        cols_info = []
        if t.get("date_columns"):
            cols_info.append(f"dates: {', '.join(t['date_columns'][:3])}")
        if t.get("numeric_columns"):
            cols_info.append(f"metrics: {', '.join(t['numeric_columns'][:5])}")
        if t.get("category_columns"):
            cols_info.append(f"categories: {', '.join(t['category_columns'][:3])}")
        table_docs.append(f"- {t['name']}: {'; '.join(cols_info) or 'general data'}")

    # Generate instructions
    instructions = f"""You are a {domain.replace('_', ' ').title()} analytics assistant.

## Available Tables

{chr(10).join(table_docs)}

## Visualization Guidelines

Structure your SQL output to enable automatic visualization:

### Bar Charts (Comparisons)
For "show X by Y" or "compare" questions:
- Return 2 columns: [category, value]
- Sort by value DESC for rankings
- Limit to 10-15 rows

### Line Charts (Trends)
For "trends", "over time" questions:
- Return 2 columns: [date, value]
- Sort by date ASC
- Use DATE_TRUNC for grouping

### Pie Charts (Distribution)
For "breakdown", "distribution" questions:
- Return 2 columns: [category, count]
- Limit to 6-8 slices

### KPIs (Single Values)
For "total", "average", "count" questions:
- Return single aggregated value
- Use clear column aliases

## Tips
- Highlight key insights in your response
- Suggest follow-up questions for deeper analysis
"""

    return {
        "title": title,
        "description": description,
        "domain": domain,
        "catalog": catalog,
        "schema": schema,
        "warehouse_id": warehouse_id,
        "tables": [t["name"] for t in tables],
        "curated_questions": curated_questions,
        "instructions": instructions,
        "table_analysis": tables,
    }


def build_serialized_space(catalog: str, schema: str, tables: List[str]) -> str:
    """Build the serialized_space JSON structure."""
    table_configs = [
        {"identifier": f"{catalog}.{schema}.{t}", "column_configs": []}
        for t in sorted(tables)
    ]
    return json.dumps({"version": 1, "data_sources": {"tables": table_configs}})


def create_genie_space_api(config: Dict, profile: str) -> Dict:
    """Create a Genie space via Databricks API."""
    payload = {
        "warehouse_id": config["warehouse_id"],
        "title": config["title"],
        "description": config["description"],
        "serialized_space": build_serialized_space(
            config["catalog"], config["schema"], config["tables"]
        ),
        "instructions": config["instructions"],
        "curated_questions": "\n".join([f"- {q}" for q in config["curated_questions"]])
    }

    with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
        json.dump(payload, f)
        temp_file = f.name

    try:
        result = subprocess.run(
            ["databricks", "api", "post", "/api/2.0/genie/spaces",
             "--json", f"@{temp_file}",
             "--profile", profile],
            capture_output=True, text=True
        )

        if result.returncode != 0:
            return {"error": result.stderr, "title": config["title"]}

        response = json.loads(result.stdout)
        return {"space_id": response.get("space_id"), "title": config["title"]}
    finally:
        os.unlink(temp_file)


def main():
    parser = argparse.ArgumentParser(description="Auto-create Genie spaces from schema")
    parser.add_argument("--catalog", required=True, help="Unity Catalog name")
    parser.add_argument("--schema", required=True, help="Schema name")
    parser.add_argument("--warehouse-id", required=True, help="SQL Warehouse ID")
    parser.add_argument("--profile", required=True, help="Databricks CLI profile")
    parser.add_argument("--app-name", default="App", help="App name prefix for spaces")
    parser.add_argument("--min-tables", type=int, default=2, help="Min tables per space")
    parser.add_argument("--dry-run", action="store_true", help="Show plan without creating")
    parser.add_argument("--output", default="spaces_config.json", help="Output config file")
    args = parser.parse_args()

    print("=" * 70)
    print("AUTO-CREATE GENIE SPACES FROM SCHEMA")
    print("=" * 70)
    print(f"\nCatalog: {args.catalog}")
    print(f"Schema: {args.schema}")
    print(f"Warehouse: {args.warehouse_id}")

    # Step 1: Get all tables
    print("\n[1/5] Fetching tables...")
    tables = get_all_tables(args.catalog, args.schema, args.profile)
    print(f"      Found {len(tables)} tables")

    if not tables:
        print("No tables found. Exiting.")
        return 1

    # Step 2: Analyze tables
    print("\n[2/5] Analyzing table structures...")
    analyzed_tables = [analyze_table(t) for t in tables]

    viz_summary = {"line": 0, "bar": 0, "pie": 0, "kpi": 0}
    for t in analyzed_tables:
        if t["viz_ready"]["line_chart"]: viz_summary["line"] += 1
        if t["viz_ready"]["bar_chart"]: viz_summary["bar"] += 1
        if t["viz_ready"]["pie_chart"]: viz_summary["pie"] += 1
        if t["viz_ready"]["kpi"]: viz_summary["kpi"] += 1

    print(f"      Visualization ready: {viz_summary}")

    # Step 3: Group tables by domain
    print("\n[3/5] Grouping tables by domain...")
    groups = group_tables_by_domain(analyzed_tables)

    # Filter out small groups
    filtered_groups = {k: v for k, v in groups.items() if len(v) >= args.min_tables}
    small_groups = {k: v for k, v in groups.items() if len(v) < args.min_tables}

    # Merge small groups into "general" if needed
    if small_groups:
        general_tables = filtered_groups.get("general", [])
        for tables_list in small_groups.values():
            general_tables.extend(tables_list)
        if general_tables:
            filtered_groups["general"] = general_tables

    print(f"      Identified {len(filtered_groups)} domains:")
    for domain, tables_list in filtered_groups.items():
        print(f"        - {domain}: {len(tables_list)} tables")

    # Step 4: Generate space configs
    print("\n[4/5] Generating space configurations...")
    space_configs = []
    for domain, domain_tables in filtered_groups.items():
        config = generate_space_config(
            domain, domain_tables,
            args.catalog, args.schema,
            args.warehouse_id, args.app_name
        )
        space_configs.append(config)
        print(f"      - {config['title']}: {len(config['tables'])} tables, {len(config['curated_questions'])} questions")

    # Save configs
    with open(args.output, "w") as f:
        json.dump(space_configs, f, indent=2, default=str)
    print(f"\n      Saved configurations to {args.output}")

    if args.dry_run:
        print("\n[DRY RUN] Would create the following spaces:")
        for config in space_configs:
            print(f"\n  {config['title']}")
            print(f"    Tables: {', '.join(config['tables'][:5])}{'...' if len(config['tables']) > 5 else ''}")
            print(f"    Sample questions:")
            for q in config['curated_questions'][:3]:
                print(f"      - {q}")
        return 0

    # Step 5: Create spaces
    print("\n[5/5] Creating Genie spaces...")
    created = []
    failed = []

    for config in space_configs:
        print(f"      Creating: {config['title']}...")
        result = create_genie_space_api(config, args.profile)
        if "error" in result:
            failed.append(result)
            print(f"        FAILED: {result['error'][:80]}")
        else:
            created.append(result)
            print(f"        OK: {result['space_id']}")

    # Summary
    print("\n" + "=" * 70)
    print("RESULTS")
    print("=" * 70)

    print(f"\nCreated: {len(created)} spaces")
    for s in created:
        print(f"  - {s['title']}: {s['space_id']}")

    if failed:
        print(f"\nFailed: {len(failed)} spaces")
        for s in failed:
            print(f"  - {s['title']}")

    # Output configurations
    if created:
        print("\n" + "=" * 70)
        print("APP.YAML CONFIGURATION")
        print("=" * 70)
        print("\nresources:")
        for s in created:
            key = s['title'].replace(f"{args.app_name} - ", "").lower()
            key = re.sub(r'[^a-z0-9]+', '-', key).strip('-')
            print(f"  - name: genie-space-{key}")
            print(f"    genie_space:")
            print(f"      space_id: {s['space_id']}")
            print(f"      permission: CAN_EDIT")

        print("\n" + "=" * 70)
        print("BACKEND CONFIGURATION")
        print("=" * 70)
        print("\nGENIE_SPACES = {")
        for s in created:
            key = s['title'].replace(f"{args.app_name} - ", "").lower()
            key = re.sub(r'[^a-z0-9_]+', '_', key).strip('_')
            print(f'    "{key}": "{s["space_id"]}",')
        print("}")

        print("\n" + "=" * 70)
        print("SERVICE PRINCIPAL PERMISSIONS")
        print("=" * 70)
        print("\nRun these commands to grant permissions:\n")
        for s in created:
            print(f"# {s['title']}")
            print(f"databricks permissions update genie-space/{s['space_id']} \\")
            print(f"  --json '{{\"access_control_list\": [{{\"service_principal_name\": \"apps/YOUR_APP\", \"permission_level\": \"CAN_RUN\"}}]}}' \\")
            print(f"  --profile {args.profile}\n")

    print("\nFor UI integration, see /dbaiassistant command")
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
```

### Example Output

Running the script on a schema with 25 tables:

```
============================================================
AUTO-CREATE GENIE SPACES FROM SCHEMA
============================================================

Catalog: my_catalog
Schema: analytics_data

[1/5] Fetching tables...
      Found 25 tables

[2/5] Analyzing table structures...
      Visualization ready: {'line': 18, 'bar': 22, 'pie': 15, 'kpi': 25}

[3/5] Grouping tables by domain...
      Identified 5 domains:
        - sales: 8 tables
        - operations: 6 tables
        - hr: 5 tables
        - finance: 4 tables
        - general: 2 tables

[4/5] Generating space configurations...
      - App - Sales Analytics: 8 tables, 10 questions
      - App - Operations Analytics: 6 tables, 10 questions
      - App - Hr Analytics: 5 tables, 10 questions
      - App - Finance Analytics: 4 tables, 10 questions
      - App - General Analytics: 2 tables, 8 questions

[5/5] Creating Genie spaces...
      Creating: App - Sales Analytics...
        OK: 01f0abc123def456
      Creating: App - Operations Analytics...
        OK: 01f0abc123def457
      ...

============================================================
APP.YAML CONFIGURATION
============================================================

resources:
  - name: genie-space-sales-analytics
    genie_space:
      space_id: 01f0abc123def456
      permission: CAN_EDIT
  - name: genie-space-operations-analytics
    genie_space:
      space_id: 01f0abc123def457
      permission: CAN_EDIT
  ...
```

---

## UI Integration

For frontend components and backend routers to integrate Genie into your app, see the `/dbaiassistant` command which contains:

- `GenieChatCore` component implementation
- Backend Genie router (`/api/genie/*` endpoints)
- Space selector dropdown UI
- Result visualization (tables, charts)
- Conversation management

---

## Quick Reference

| Task | Command/Script |
|------|----------------|
| **Auto-create from schema** | `python auto_create_spaces.py --catalog X --schema Y --warehouse-id W --profile P` |
| Dry run (preview) | `python auto_create_spaces.py ... --dry-run` |
| List tables | `databricks unity-catalog tables list --catalog-name X --schema-name Y` |
| Analyze tables | `python analyze_tables.py --catalog X --schema Y --profile P` |
| Create single space | `python create_genie_space.py --config space.json --profile P` |
| List spaces | `databricks genie list-spaces --profile P` |
| Delete space | `databricks genie trash-space <SPACE_ID> --profile P` |
| Grant permissions | See Service Principal Permissions section |
| UI integration | See `/dbaiassistant` command |
