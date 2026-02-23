# Application-Stall - Technical Documentation

> ⚠️ **Uses Microsoft Graph `/beta` endpoints**. API shapes and behavior can change without notice.

## Overview

`Application-Stall.ps1` is a PowerShell script that exports Microsoft Intune applications to individual Markdown files. It queries the Intune mobile apps API via Microsoft Graph and generates human-readable documentation including deployment settings, assignments, and detection rules.

**Version:** 1.0.0  
**Author:** Joshua Walderbach (j0w03ow)  
**Last Updated:** 2025-02-17

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Requirements](#requirements)
3. [Parameters](#parameters)
4. [Inputs and Outputs](#inputs-and-outputs)
5. [Data Sensitivity](#data-sensitivity)
6. [Authentication](#authentication)
7. [Application Types](#application-types)
8. [Output Format](#output-format)
9. [API Endpoints](#api-endpoints)
10. [Examples](#examples)
11. [Troubleshooting](#troubleshooting)
12. [How It Works](#how-it-works)
13. [Limitations](#limitations)
14. [Technical Details](#technical-details)
15. [Changelog](#changelog)

---

## Requirements

### PowerShell Version
- PowerShell 5.1 or higher
- PowerShell 7.x recommended for best performance

### Required Modules
```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
```

### Entra ID Permissions
The authenticating user must have the following Microsoft Graph permission:
- `DeviceManagementApps.Read.All`

This permission is typically granted through one of these roles:
- Intune Administrator
- Global Reader
- Custom role with app management read access

---

## Quick Start

```powershell
.\Application-Stall.ps1 -All -Platform Windows -OutputPath ".\Apps-$(Get-Date -Format 'ddMMMyyyy')"
```

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `-AppNames` | String | No | Comma-separated app names with wildcard support |
| `-CsvFile` | String | No | Path to CSV file containing app names |
| `-CsvColumn` | String | No | CSV column name (default: "AppName") |
| `-OutputPath` | String | **Yes** | Output directory for Markdown files |
| `-All` | Switch | No | Export all applications in tenant |
| `-Platform` | String | No | Filter by platform (default: Windows) |

### Platform Values
- `Windows` - Windows applications only (default)
- `iOS` - iOS/iPadOS applications
- `Android` - Android applications
- `macOS` - macOS applications
- `All` - All platforms

### Parameter Sets

The script supports three mutually exclusive input methods:

1. **Names** - Specify app names directly via `-AppNames`
2. **Csv** - Import app names from a CSV file
3. **All** - Export all applications (no filtering)
4. **Default** - Interactive prompt for app names

---

## Inputs and Outputs

### Inputs
- Parameters for name filtering, CSV input, or `-All`
- Optional CSV file with an `AppName` column (or `-CsvColumn`)

### Outputs
- One Markdown file per application
- A README index file for the export folder

---

## Data Sensitivity

Exports include raw JSON and resolved group names. Some app entries can include installation commands or other sensitive deployment details. Treat exported files as sensitive data and store them appropriately.

---

## Authentication

The script uses interactive browser-based authentication via `Connect-MgGraph`. Upon execution:

1. A browser window opens for Azure AD sign-in
2. User authenticates with their Walmart credentials
3. Consent is requested for `DeviceManagementApps.Read.All` scope
4. Token is cached for the session

```powershell
Connect-MgGraph -Scopes "DeviceManagementApps.Read.All" -NoWelcome
```

The script automatically disconnects from Microsoft Graph upon completion.

---

## Application Types

The script supports all Intune mobile application types:

### Windows Applications
| Type | @odata.type | Description |
|------|-------------|-------------|
| Win32 LOB | `win32LobApp` | Traditional Win32 applications (.intunewin) |
| Win32 Catalog | `win32CatalogApp` | Enterprise App Catalog applications |
| WinGet | `winGetApp` | Windows Package Manager applications |
| MSI LOB | `windowsMobileMSI` | MSI installer packages |
| MSIX/APPX | `windowsUniversalAppX` | Modern Windows app packages |
| Microsoft 365 | `officeSuiteApp` | Microsoft 365 Apps for Enterprise |
| Edge | `windowsMicrosoftEdgeApp` | Microsoft Edge browser |
| Web App | `webApp` | Web links/shortcuts |

### iOS Applications
| Type | @odata.type | Description |
|------|-------------|-------------|
| Store App | `iosStoreApp` | App Store applications |
| VPP App | `iosVppApp` | Volume Purchase Program apps |
| LOB App | `iosLobApp` | Enterprise-signed IPA files |

### Android Applications
| Type | @odata.type | Description |
|------|-------------|-------------|
| Store App | `androidStoreApp` | Google Play applications |
| Managed Google Play | `managedAndroidStoreApp` | Managed Google Play apps |
| LOB App | `androidLobApp` | Enterprise APK files |

### macOS Applications
| Type | @odata.type | Description |
|------|-------------|-------------|
| LOB App | `macOSLobApp` | PKG/DMG installer files |
| DMG App | `macOSDmgApp` | DMG disk images |
| PKG App | `macOSPkgApp` | PKG installer packages |
| Microsoft 365 | `macOSOfficeSuiteApp` | Microsoft 365 for Mac |
| Edge | `macOSMicrosoftEdgeApp` | Microsoft Edge for Mac |

---

## Output Format

### Directory Structure
```
OutputPath/
├── README.md                    # Collection index and metadata
├── App_Name_1.md                # Individual app files
├── App_Name_2.md
└── ...
```

### README.md Contents
- Collection metadata (who, when, how)
- Search patterns used
- Platform filter applied
- Table of all exported applications with links
- API endpoints queried
- Permission requirements

### Individual Application Files

Each Markdown file contains:

#### Application Information Table
| Field | Description |
|-------|-------------|
| Name | Display name |
| Type | Application type (Win32, MSI, etc.) |
| App ID | Unique GUID |
| Publisher | Application publisher |
| Version | Application version |
| Created | Creation timestamp |
| Last Modified | Last modification timestamp |

#### Assignments Table
| Field | Description |
|-------|-------------|
| Target Type | group, allDevices, allUsers, exclusionGroup |
| Group Name | Resolved Azure AD group display name |
| Intent | required, available, uninstall |
| Filter | Assignment filter (if configured) |

#### Win32 App Details (when applicable)
- Install command
- Uninstall command
- Install behavior (system/user)
- Detection rules
- Requirement rules
- Return codes
- Dependencies and supersedence

#### Raw JSON
- Collapsible `<details>` section with full app JSON
- Complete application object for technical reference

---

## API Endpoints

### Application Discovery
```
GET https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?$top=999
```

### Assignments
```
GET https://graph.microsoft.com/beta/deviceAppManagement/mobileApps('{id}')/assignments
```

### Group Resolution
```
GET https://graph.microsoft.com/v1.0/groups/{groupId}
```

### Filter Resolution
```
GET https://graph.microsoft.com/beta/deviceManagement/assignmentFilters/{filterId}
```

---

## Examples

### Export All Windows Applications
```powershell
.\Application-Stall.ps1 -All -OutputPath "C:\Exports\Apps-FY2026"
```

### Export All Applications (All Platforms)
```powershell
.\Application-Stall.ps1 -All -Platform All -OutputPath ".\AllApps"
```

### Export Applications by Name Pattern
```powershell
# All 7-Zip apps
.\Application-Stall.ps1 -AppNames "7-Zip*" -OutputPath ".\7Zip"

# Multiple patterns
.\Application-Stall.ps1 -AppNames "Chrome*,Firefox*,Edge*" -OutputPath ".\Browsers"

# Specific application
.\Application-Stall.ps1 -AppNames "Microsoft 365 Apps for Enterprise" -OutputPath ".\M365"
```

### Export from CSV
```powershell
# CSV format: AppName column
.\Application-Stall.ps1 -CsvFile "apps.csv" -OutputPath ".\Apps"

# Custom column name
.\Application-Stall.ps1 -CsvFile "inventory.csv" -CsvColumn "ApplicationName" -OutputPath ".\Apps"
```

### Interactive Mode
```powershell
.\Application-Stall.ps1 -OutputPath ".\Exports"
# Prompts: Enter application names (comma-separated, wildcards supported):
# Input: *Adobe*,*Office*
```

### Export iOS Applications
```powershell
.\Application-Stall.ps1 -All -Platform iOS -OutputPath ".\iOS-Apps"
```

---

## Troubleshooting

### Common Issues

#### "No applications matched the provided names"
**Cause:** App names don't match or wildcards are incorrect.  
**Solution:** Use `*` wildcards, e.g., `*Chrome*` instead of `Chrome`.

#### "Failed to get assignments"
**Cause:** Permission issues or API throttling.  
**Solution:** Ensure user has `DeviceManagementApps.Read.All` permission. Wait and retry if throttled.

#### Platform filter not working as expected
**Cause:** Some apps span multiple platforms or have cross-platform types.  
**Solution:** Use `-Platform All` to capture all applications, then filter results manually.

#### Module Not Found
**Error:** `The term 'Connect-MgGraph' is not recognized`  
**Solution:**
```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force
```

---

## How It Works

- Connects to Microsoft Graph with `DeviceManagementApps.Read.All`
- Discovers applications across the `mobileApps` endpoint
- Filters by platform and display name patterns
- Fetches assignments and Win32 details when available
- Resolves group and filter names with caching
- Renders Markdown and an index README

---

## Limitations

- Uses Microsoft Graph `/beta` endpoints which can change without notice
- Some app types do not expose detection rules or requirements
- Large tenants can take significant time due to per-app detail requests

---

## Technical Details

### Platform Filtering

Applications are filtered by `@odata.type` patterns:

| Platform | Type Patterns |
|----------|---------------|
| Windows | `win32*`, `windowsMsi*`, `windowsUniversal*`, `officeSuite*`, `windowsMicrosoft*`, `winGet*` |
| iOS | `ios*` |
| Android | `android*`, `managedAndroid*` |
| macOS | `macOS*` |

### Pagination Handling

The script implements custom pagination for Graph API responses:
```powershell
function Invoke-GraphRequestWithPaging {
    # Handles @odata.nextLink for paginated results
    # Aggregates all pages into single collection
}
```

### Group Name Caching

Group IDs are resolved to display names and cached to minimize API calls:
```powershell
$script:groupNameCache = @{}  # Persists across app processing
$script:filterNameCache = @{} # Same for assignment filters
```

### Filename Sanitization

Application names are sanitized for filesystem compatibility:
- Invalid characters replaced with `_`
- Whitespace replaced with `_`
- Brackets `[]` replaced with `_` (PowerShell wildcard characters)
- Version numbers in filenames when available

---

## Changelog

### Version 1.0.0 (2025-02-17)
- Initial release
- Export all Intune application types
- Platform filtering (Windows, iOS, Android, macOS, All)
- `-All` parameter to export entire tenant
- Win32 app details (commands, detection rules, requirements)
- Group name and filter name resolution
- Individual Markdown files per application with README index
- Collapsible raw JSON sections
- Interactive mode with app name prompting
- CSV import support

---

## Author

**Joshua Walderbach** (j0w03ow)  
Windows Engineering Team

---

### Found this helpful?

If this tool saved you time or made your work easier, consider giving a **Badge** to recognize the effort!

[Badgify](https://internal.walmart.com/content/badgify/home/badgify.html)
