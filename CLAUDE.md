# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Intune-ition is a PowerShell-based export system for Microsoft Intune configurations. It queries the Microsoft Graph API and generates Markdown documentation files for configuration profiles, applications, compliance policies, and security baselines.

## Repository Structure

Four standalone PowerShell scripts, each following the same architectural pattern:

| Script | Exports | Primary Endpoints |
|--------|---------|-------------------|
| `Configuration-Harvester.ps1` | Configuration profiles | `deviceConfigurations`, `configurationPolicies`, `groupPolicyConfigurations`, `intents` |
| `Application-Stall.ps1` | Applications | `mobileApps` |
| `Compliance-Fence.ps1` | Compliance policies | `compliancePolicies`, `deviceCompliancePolicies` |
| `Baseline-Seed.ps1` | Security baselines (in development) | `templates`, `intents` |

Technical docs live in `/docs/<script-name>.md`.

## Execution

No build system. Scripts run directly in PowerShell 5.1+ with the `Microsoft.Graph.Authentication` module.

```powershell
# Full tenant export
.\Configuration-Harvester.ps1 -All -OutputPath ".\Output"

# Wildcard name patterns
.\Application-Stall.ps1 -AppNames "Chrome*,*Office*" -OutputPath ".\Apps"

# From CSV
.\Compliance-Fence.ps1 -CsvFile "policies.csv" -OutputPath ".\Compliance"

# Interactive (default - prompts for names)
.\Configuration-Harvester.ps1 -OutputPath ".\Output"
```

## Script Architecture Pattern

All four scripts follow an identical 5-stage pipeline:

1. **Module check** — Verify `Microsoft.Graph.Authentication` is installed
2. **Authentication** — `Connect-MgGraph` with read-only scopes
3. **Search** — Query Graph API endpoints, filter by name/wildcard/platform
4. **Collect** — Fetch assignments + settings per item, resolve group/filter IDs to names
5. **Export** — Write individual Markdown files + auto-generated `README.md` index

### Shared internal functions (duplicated in each script)

- `Invoke-GraphRequestWithPaging` — Handles `@odata.nextLink` pagination
- `Get-GroupDisplayName` / `Get-FilterDisplayName` — Resolve IDs to names with `$script:`-scoped hash table caching
- `Get-SafeFileName` — Sanitize names for filesystem use
- Type name mappers (`Get-ProfileTypeName`, `Get-AppTypeName`, etc.)

### Input parameter sets

Every script supports four mutually exclusive input modes:
- Named items (comma-separated, wildcard `*` supported)
- CSV file import (configurable column name)
- `-All` flag (full tenant)
- Interactive prompt (default)

### Key conventions

- **Read-only**: All scripts use `.Read.All` Graph permissions only
- **Caching**: Group names, filter names, and scope tags are cached in `$script:` hash tables to avoid redundant API calls
- **Profile source tracking**: Items are tagged with a `profileSource`/`appSource`/`policySource` property to identify their API origin
- **Output format**: Markdown with metadata header, assignments table, settings tables, and collapsible `<details>` blocks containing raw JSON
- **Console output**: Color-coded — Yellow=info, Green=success, Red=error, Cyan=section headers
- **Scope tag 0**: Always maps to "Default"

## License

PolyForm Noncommercial License 1.0.0
