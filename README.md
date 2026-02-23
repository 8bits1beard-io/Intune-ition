# Intune-ition

Documentation repository for Walmart's Microsoft Intune configuration artifacts. Contains point-in-time exports of device management policies, settings, assignments, and application details.

## Overview

This repository serves as a centralized archive for Intune configuration documentation. Each dated export folder contains a README index plus individual Markdown files for each exported item.

## Repository Structure

```
Intune-ition/
├── docs/                           # Tool manuals
├── Configuration-Harvester.ps1     # Configuration profile export tool
├── Application-Stall.ps1           # Application export tool
├── Baseline-Seed.ps1               # Security baseline export tool (in development)
├── Compliance-Fence.ps1            # Compliance policy export tool
├── 17FEB2026/                      # Example export snapshot
│   ├── README.md                   # Collection metadata & index
│   ├── Profile1.md                 # Individual item docs
│   └── ...
└── README.md
```

## Export Tools

| Tool | Description | Manual |
|------|-------------|--------|
| `Configuration-Harvester.ps1` | Export Intune configuration profiles | `docs/Configuration-Harvester.md` |
| `Application-Stall.ps1` | Export Intune applications | `docs/Application-Stall.md` |
| `Compliance-Fence.ps1` | Export Intune compliance policies | `docs/Compliance-Fence.md` |
| `Baseline-Seed.ps1` | Export Intune security baselines (in development) | `docs/Baseline-Seed.md` |

## Requirements (High Level)

- PowerShell 5.1 or higher
- `Microsoft.Graph.Authentication` module
- Entra ID account with permissions for the specific tool

## Permissions Summary

| Tool | Required Permission | Optional Permission |
|------|---------------------|---------------------|
| Configuration-Harvester | `DeviceManagementConfiguration.Read.All` | None |
| Application-Stall | `DeviceManagementApps.Read.All` | None |
| Compliance-Fence | `DeviceManagementConfiguration.Read.All` | `DeviceManagementRBAC.Read.All` |
| Baseline-Seed | `DeviceManagementConfiguration.Read.All` | None |

## Data Sensitivity

Exports include raw JSON and resolved group names. Some profiles and apps can include secrets or sensitive values (certificates, OMA-URI values, install commands). Treat exported files as sensitive data and store them appropriately.

## Documentation

Each tool has a dedicated manual with usage and implementation details:
- `docs/Configuration-Harvester.md`
- `docs/Application-Stall.md`
- `docs/Compliance-Fence.md`
- `docs/Baseline-Seed.md` (in development)

## Contributing

Contact the Windows Engineering team for questions or to contribute.

## Author

**Joshua Walderbach** (j0w03ow)
Windows Engineering Team

---

### Found this helpful?

If these tools saved you time or made your work easier, consider giving a **Badge** to recognize the effort!

[Badgify](https://internal.walmart.com/content/badgify/home/badgify.html)

---

## License

Internal Walmart use only.
