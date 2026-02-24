# Policy-Compass - Technical Documentation

## Overview

`Policy-Compass.ps1` collects applied Group Policy data from a Windows computer. It produces a JSON report and a Markdown summary showing:
- Applied GPOs (Computer and User scopes)
- OU and inheritance context (when AD/RSAT is available)
- Parsed GPO settings, including registry-related settings when exposed in the GPO report

**Version:** 1.0.0  
**Author:** Joshua Walderbach (j0w03ow)  
**Last Updated:** 2026-02-24

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Requirements](#requirements)
3. [Parameters](#parameters)
4. [Inputs and Outputs](#inputs-and-outputs)
5. [Data Sensitivity](#data-sensitivity)
6. [Output Format](#output-format)
7. [Examples](#examples)
8. [Troubleshooting](#troubleshooting)
9. [How It Works](#how-it-works)
10. [Limitations](#limitations)
11. [Changelog](#changelog)

---

## Quick Start

```powershell
.\Policy-Compass.ps1 -OutputPath ".\GPO-$(Get-Date -Format 'ddMMMyyyy')"
```

---

## Requirements

### PowerShell Version
- PowerShell 5.1 or higher

### Recommended Modules
Install RSAT components for richer output:
```powershell
Install-WindowsFeature GPMC
```

Or via Windows Features (RSAT):
- Group Policy Management
- Active Directory module (optional for OU resolution)

---

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `-OutputPath` | String | **Yes** | Output directory for JSON/Markdown |
| `-Scope` | String | No | `Computer`, `User`, or `Both` (default `Both`) |
| `-IncludeRawGpoXml` | Switch | No | Include raw GPO report XML in JSON |

---

## Inputs and Outputs

### Inputs
- Local device RSOP (via `Get-GPResultantSetOfPolicy` or `gpresult`)
- Domain GPO reports (via `Get-GPOReport`, when available)
- OU inheritance data (via `Get-GPInheritance`, when available)

### Outputs
- One JSON report file
- One Markdown summary file
- A README index file in the output folder

---

## Data Sensitivity

Group Policy reports can include:
- Security settings
- Registry paths and configured values
- OU location and domain metadata

Treat outputs as sensitive and store securely.

---

## Output Format

The JSON report includes:
- `metadata` (collection time, tool version, method)
- `device` (OS, domain, logged-on user)
- `organizationalUnit` (DN and inheritance links)
- `appliedGpos` (computer and user scope lists)
- `gpoDetails` (parsed policy and registry settings)

The Markdown file presents a human-readable summary with tables and expandable per-GPO details.

---

## Examples

```powershell
.\Policy-Compass.ps1 -OutputPath "C:\Exports\GPO"
```

```powershell
.\Policy-Compass.ps1 -Scope Computer -OutputPath ".\GPO-ComputerOnly"
```

```powershell
.\Policy-Compass.ps1 -IncludeRawGpoXml -OutputPath ".\GPO-Verbose"
```

---

## Troubleshooting

- **No GPO details**
  - Ensure the GroupPolicy module is installed (`GPMC`/RSAT).
  - Verify domain connectivity.

- **OU data missing**
  - Install the ActiveDirectory module (RSAT).
  - Confirm the computer is domain-joined.

- **RSOP collection failed**
  - Run PowerShell as Administrator.
  - Check that `gpresult` is available if GroupPolicy is missing.

---

## How It Works

1. Collects RSOP XML using `Get-GPResultantSetOfPolicy` (preferred) or `gpresult`.
2. Parses applied GPOs for computer and/or user scope.
3. Resolves OU and inheritance links (if AD module is available).
4. Pulls per-GPO XML reports and extracts policy and registry settings.
5. Writes JSON and Markdown output, plus a README index file.

---

## Limitations

- Registry entries are parsed from GPO report XML when available. Some settings may not be exposed or may appear as high-level policy names.
- User-scope GPOs are collected for the currently logged-on user.
- Non-domain-joined devices will only provide local policy details.

---

## Changelog

- **1.0.0** (2026-02-24) - Initial release of Policy-Compass.
