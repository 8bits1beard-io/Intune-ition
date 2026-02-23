# Tool Manual Template

Use this template for new tools to keep documentation consistent across the repository.

## Overview

Brief description of what the tool does and what it exports.

**Version:** x.y.z  
**Author:** Name  
**Last Updated:** YYYY-MM-DD

---

## Quick Start

```powershell
.\Tool-Name.ps1 -All -OutputPath ".\Exports-$(Get-Date -Format 'ddMMMyyyy')"
```

---

## Requirements

- PowerShell 5.1 or higher
- `Microsoft.Graph.Authentication` module
- Required Microsoft Graph permissions for this tool

---

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `-Example` | String | No | Example parameter |

---

## Inputs and Outputs

### Inputs
- Parameters for name filtering, CSV input, or `-All`
- Optional CSV file with a tool-specific column

### Outputs
- One Markdown file per item
- A README index file for the export folder

---

## Data Sensitivity

Exports include raw JSON and resolved group names. Some items may include sensitive values. Treat exported files as sensitive data and store them appropriately.

---

## Authentication

Describe the Graph scopes and sign-in flow.

---

## Types Supported

List supported policy/app types or platforms as applicable.

---

## Output Format

Describe the directory structure and file contents.

---

## API Endpoints

List discovery, assignments, and settings endpoints.

---

## Examples

Provide common usage examples.

---

## Troubleshooting

List common issues and fixes.

---

## How It Works

Summarize major steps of the script.

---

## Limitations

Call out API beta usage, scale considerations, or known gaps.

---

## Technical Details

Caching, pagination, and formatting details.

---

## Changelog

Version history entries.

