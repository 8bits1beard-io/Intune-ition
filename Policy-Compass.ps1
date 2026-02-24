<#
.SYNOPSIS
    Export applied Group Policy (AD and Local) information from a Windows computer.

.DESCRIPTION
    Collects applied Group Policy details for the local device, including AD-linked
    GPOs and Local Group Policy (LGPO). Generates a JSON report plus a Markdown
    summary showing which policies are applied, the settings they configure
    (including registry-related settings when available), and the OU/Scope of
    Management where policies are linked.

.PARAMETER OutputPath
    Required. Output directory for JSON and Markdown files. Will be created if it doesn't exist.

.PARAMETER Scope
    Which policy scope(s) to include. Default is Both.
    Options: Computer, User, Both

.PARAMETER IncludeRawGpoXml
    Include raw GPO report XML for each GPO in the JSON output.

.EXAMPLE
    .\Policy-Compass.ps1 -OutputPath ".\GPO-$(Get-Date -Format 'ddMMMyyyy')"
    Collects computer + user policy data and exports JSON + Markdown.

.EXAMPLE
    .\Policy-Compass.ps1 -Scope Computer -OutputPath "C:\Exports\GPO"
    Collects only computer policy data.

.NOTES
    File Name      : Policy-Compass.ps1
    Author         : Joshua Walderbach (j0w03ow)
    Prerequisite   : RSAT GroupPolicy module (recommended)
    Requires       : PowerShell 5.1 or higher
    Version        : 1.0.0
    Date           : 2026-02-24

.LINK
    https://learn.microsoft.com/en-us/powershell/module/grouppolicy/

.OUTPUTS
    One JSON report, one Markdown report, plus a README.md index file.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$OutputPath,

    [Parameter()]
    [ValidateSet('Computer', 'User', 'Both')]
    [string]$Scope = 'Both',

    [Parameter()]
    [switch]$IncludeRawGpoXml
)

$ErrorActionPreference = 'Stop'

# Validate and create output path if needed
if (-not (Test-Path $OutputPath)) {
    Write-Host "Creating output folder: $OutputPath" -ForegroundColor Yellow
    try {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        Write-Host "  ✓ Output folder created" -ForegroundColor Green
    } catch {
        Write-Error "Failed to create output folder: $_"
        exit 1
    }
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Group Policy Collection (Policy-Compass)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Environment checks
$hasGroupPolicy = [bool](Get-Module -ListAvailable -Name GroupPolicy)
$hasActiveDirectory = [bool](Get-Module -ListAvailable -Name ActiveDirectory)

Write-Host "[1/5] Checking environment..." -ForegroundColor Yellow
$gpStatus = if ($hasGroupPolicy) { 'Found' } else { 'Not Found' }
$adStatus = if ($hasActiveDirectory) { 'Found' } else { 'Not Found' }
Write-Host "  GroupPolicy module: $gpStatus" -ForegroundColor Gray
Write-Host "  ActiveDirectory module: $adStatus" -ForegroundColor Gray

# Collect basic device info
$computerSystem = Get-CimInstance Win32_ComputerSystem
$os = Get-CimInstance Win32_OperatingSystem
$deviceName = $env:COMPUTERNAME
$domain = $computerSystem.Domain
$partOfDomain = $computerSystem.PartOfDomain
$currentUser = $env:USERNAME

$collectionDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$collectionDateISO = Get-Date -Format "o"

# Helper: safe file name
function Get-SafeFileName {
    param([string]$Name)
    $invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
    $sanitized = $Name -replace "[$([regex]::Escape($invalidChars))]", '_'
    $sanitized = $sanitized -replace '\s+', '_'
    $sanitized = $sanitized -replace '[\[\]]', '_'
    return $sanitized
}

# Helper: get child node text by names
function Get-ChildText {
    param(
        [Parameter(Mandatory=$true)] $Node,
        [Parameter(Mandatory=$true)] [string[]]$Names
    )

    foreach ($name in $Names) {
        $child = $Node.SelectSingleNode("*[local-name()='$name']")
        if ($child -and $child.InnerText) {
            return $child.InnerText
        }
    }
    return $null
}

# Helper: convert XML node to ordered hashtable
function Convert-XmlNodeToHashtable {
    param([Parameter(Mandatory=$true)] $Node)

    $obj = [ordered]@{}
    foreach ($child in $Node.ChildNodes) {
        if ($child.NodeType -eq 'Element') {
            $obj[$child.LocalName] = $child.InnerText
        }
    }
    return $obj
}

# Helper: sanitize Markdown table cells
function Format-MdCell {
    param(
        [string]$Value,
        [int]$MaxLength = 160
    )

    if ($null -eq $Value) { return "" }
    $text = "$Value"
    $text = $text -replace '\r?\n', ' '
    $text = $text -replace '\|', '\\|'
    if ($text.Length -gt $MaxLength) {
        $text = $text.Substring(0, $MaxLength - 3) + "..."
    }
    return $text
}

# Generate RSOP XML
Write-Host "" 
Write-Host "[2/5] Collecting RSOP data..." -ForegroundColor Yellow
$rsopXmlPath = Join-Path $OutputPath "RSOP.xml"
$rsopXml = $null
$rsopMethod = $null

try {
    if ($hasGroupPolicy) {
        Get-GPResultantSetOfPolicy -ReportType Xml -Path $rsopXmlPath -ErrorAction Stop
        $rsopMethod = "Get-GPResultantSetOfPolicy"
    } else {
        gpresult /X $rsopXmlPath /F | Out-Null
        $rsopMethod = "gpresult"
    }

    $rsopXml = [xml](Get-Content -LiteralPath $rsopXmlPath -ErrorAction Stop)
    Write-Host "  ✓ RSOP collected ($rsopMethod)" -ForegroundColor Green
} catch {
    Write-Warning "Failed to collect RSOP data: $_"
}

# Get applied GPOs from RSOP
function Get-AppliedGposFromRsop {
    param(
        [Parameter(Mandatory=$true)] [xml]$Xml,
        [Parameter(Mandatory=$true)] [ValidateSet('Computer','User')] [string]$Scope
    )

    $scopeNode = if ($Scope -eq 'Computer') { 'ComputerResults' } else { 'UserResults' }
    $gpoNodes = $Xml.SelectNodes("//*[local-name()='$scopeNode']//*[local-name()='AppliedGPOs']/*[local-name()='GPO']")

    $gpos = @()
    foreach ($node in $gpoNodes) {
        $raw = Convert-XmlNodeToHashtable -Node $node
        $gpos += [ordered]@{
            name = (@($raw.Name, $raw.DisplayName) | Where-Object { $_ } | Select-Object -First 1)
            id = (@($raw.GUID, $raw.Guid, $raw.ID, $raw.Id) | Where-Object { $_ } | Select-Object -First 1)
            link = (@($raw.Link, $raw.SOM, $raw.SOMPath) | Where-Object { $_ } | Select-Object -First 1)
            enabled = (@($raw.Enabled, $raw.GpoEnabled, $raw.GPOEnabled) | Where-Object { $_ } | Select-Object -First 1)
            enforced = (@($raw.Enforced, $raw.NoOverride) | Where-Object { $_ } | Select-Object -First 1)
            filterAllowed = (@($raw.FilterAllowed, $raw.SecurityFiltering) | Where-Object { $_ } | Select-Object -First 1)
            wmiFilter = (@($raw.WMIFilter, $raw.WmiFilter) | Where-Object { $_ } | Select-Object -First 1)
            order = (@($raw.LinkOrder, $raw.Order) | Where-Object { $_ } | Select-Object -First 1)
            scope = $Scope
            raw = $raw
        }
    }

    return $gpos
}

$appliedComputerGpos = @()
$appliedUserGpos = @()
if ($rsopXml) {
    if ($Scope -in @('Computer','Both')) {
        $appliedComputerGpos = Get-AppliedGposFromRsop -Xml $rsopXml -Scope Computer
    }
    if ($Scope -in @('User','Both')) {
        $appliedUserGpos = Get-AppliedGposFromRsop -Xml $rsopXml -Scope User
    }
}

# AD OU information
$adComputerInfo = $null
$gpInheritance = $null
if ($partOfDomain -and $hasActiveDirectory) {
    Write-Host "" 
    Write-Host "[3/5] Resolving OU and inheritance..." -ForegroundColor Yellow
    try {
        $adComputerInfo = Get-ADComputer -Identity $deviceName -Properties DistinguishedName
        if ($adComputerInfo -and $adComputerInfo.DistinguishedName -and $hasGroupPolicy) {
            $gpInheritance = Get-GPInheritance -Target $adComputerInfo.DistinguishedName
        }
        Write-Host "  ✓ OU data collected" -ForegroundColor Green
    } catch {
        Write-Warning "Failed to resolve OU / inheritance: $_"
    }
}

# Build OU mapping for GPO links
$ouLinks = @()
if ($gpInheritance -and $gpInheritance.GpoLinks) {
    foreach ($link in $gpInheritance.GpoLinks) {
        $ouLinks += [ordered]@{
            scope = $gpInheritance.Target
            gpoName = $link.DisplayName
            gpoId = $link.GpoId
            enabled = $link.Enabled
            enforced = $link.Enforced
            order = $link.Order
        }
    }
}

# Get detailed GPO reports (best-effort)
Write-Host "" 
Write-Host "[4/5] Collecting GPO details..." -ForegroundColor Yellow
$gpoDetails = @()
$gpoErrors = @()

function Get-GpoReportDetails {
    param(
        [Parameter(Mandatory=$true)] [string]$GpoGuid,
        [Parameter(Mandatory=$true)] [string]$Scope
    )

    $reportXmlText = Get-GPOReport -Guid $GpoGuid -ReportType Xml
    $reportXml = [xml]$reportXmlText

    # Policy settings
    $policyNodes = $reportXml.SelectNodes("//*[local-name()='Policy']")
    $policies = @()
    foreach ($policy in $policyNodes) {
        $policies += [ordered]@{
            name = Get-ChildText -Node $policy -Names @('Name')
            state = Get-ChildText -Node $policy -Names @('State')
            category = Get-ChildText -Node $policy -Names @('Category')
            supported = Get-ChildText -Node $policy -Names @('Supported')
            explain = Get-ChildText -Node $policy -Names @('Explain')
        }
    }

    # Registry settings (policies + preferences)
    $registryNodes = $reportXml.SelectNodes("//*[local-name()='Registry'] | //*[local-name()='RegistrySetting']")
    $registry = @()
    foreach ($reg in $registryNodes) {
        $registry += [ordered]@{
            key = Get-ChildText -Node $reg -Names @('Key', 'KeyName')
            valueName = Get-ChildText -Node $reg -Names @('ValueName', 'Name')
            type = Get-ChildText -Node $reg -Names @('Type', 'ValueType')
            value = Get-ChildText -Node $reg -Names @('Value', 'Data')
            action = Get-ChildText -Node $reg -Names @('Action')
        }
    }

    $gpoMeta = $reportXml.SelectSingleNode("//*[local-name()='GPO']")
    $gpoName = if ($gpoMeta) { Get-ChildText -Node $gpoMeta -Names @('Name', 'DisplayName') } else { $null }

    $detail = [ordered]@{
        id = $GpoGuid
        name = $gpoName
        scope = $Scope
        policyCount = $policies.Count
        registryCount = $registry.Count
        policies = $policies
        registryEntries = $registry
    }

    if ($IncludeRawGpoXml) {
        $detail.rawGpoReportXml = $reportXmlText
    }

    return $detail
}

if ($hasGroupPolicy -and $partOfDomain) {
    $allApplied = @()
    if ($Scope -in @('Computer','Both')) { $allApplied += $appliedComputerGpos }
    if ($Scope -in @('User','Both')) { $allApplied += $appliedUserGpos }

    $seen = @{}
    foreach ($gpo in $allApplied) {
        if (-not $gpo.id) { continue }
        if ($gpo.id -notmatch '^[{(]?[0-9a-fA-F-]{36}[)}]?$') { continue }
        if ($seen.ContainsKey($gpo.id)) { continue }
        $seen[$gpo.id] = $true

        try {
            $detail = Get-GpoReportDetails -GpoGuid $gpo.id -Scope $gpo.scope
            if (-not $detail.name) { $detail.name = $gpo.name }
            $gpoDetails += $detail
        } catch {
            $gpoErrors += "Failed to collect report for $($gpo.name) [$($gpo.id)]: $_"
        }
    }
} else {
    if (-not $hasGroupPolicy) {
        $gpoErrors += "GroupPolicy module not found. Skipped per-GPO report collection."
    }
    if (-not $partOfDomain) {
        $gpoErrors += "Device is not domain-joined. Skipped domain GPO report collection."
    }
}

Write-Host "  ✓ GPO detail collection complete" -ForegroundColor Green

# Build final report object
$report = [ordered]@{
    metadata = [ordered]@{
        exportDate = $collectionDateISO
        exportTool = "Policy-Compass"
        version = "1.0.0"
        collectedBy = $currentUser
        rsopMethod = $rsopMethod
    }
    device = [ordered]@{
        name = $deviceName
        domain = $domain
        partOfDomain = $partOfDomain
        osCaption = $os.Caption
        osVersion = $os.Version
        osBuild = $os.BuildNumber
        loggedOnUser = $computerSystem.UserName
    }
    scope = $Scope
    organizationalUnit = [ordered]@{
        distinguishedName = if ($adComputerInfo) { $adComputerInfo.DistinguishedName } else { $null }
        ouPath = if ($adComputerInfo -and $adComputerInfo.DistinguishedName) {
            ($adComputerInfo.DistinguishedName -split ',', 2)[1]
        } else { $null }
        inheritanceLinks = $ouLinks
    }
    appliedGpos = [ordered]@{
        computer = $appliedComputerGpos
        user = $appliedUserGpos
    }
    gpoDetails = $gpoDetails
    errors = $gpoErrors
}

# Export JSON
Write-Host "" 
Write-Host "[5/5] Writing output files..." -ForegroundColor Yellow

$baseName = Get-SafeFileName -Name "Policy-Compass_${deviceName}_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
$jsonPath = Join-Path $OutputPath "$baseName.json"
$mdPath = Join-Path $OutputPath "$baseName.md"

$report | ConvertTo-Json -Depth 20 | Out-File -LiteralPath $jsonPath -Encoding UTF8

# Build Markdown summary
$md = @()
$md += "# Group Policy Report - $deviceName"
$md += ""
$md += "## Collection Information"
$md += ""
$md += "| Property | Value |"
$md += "|----------|-------|"
$md += "| **Collected By** | $currentUser |"
$md += "| **Collection Date** | $collectionDate |"
$md += "| **Collection Method** | $rsopMethod |"
$md += "| **Script** | Policy-Compass.ps1 |"
$md += "| **Scope** | $Scope |"
$md += "| **Domain Joined** | $partOfDomain |"
$md += "| **Domain** | $domain |"
$md += ""

$md += "## Device Information"
$md += ""
$md += "| Property | Value |"
$md += "|----------|-------|"
$md += "| **Computer Name** | $deviceName |"
$md += "| **OS** | $($os.Caption) |"
$md += "| **Version** | $($os.Version) |"
$md += "| **Build** | $($os.BuildNumber) |"
$md += "| **Logged On User** | $($computerSystem.UserName) |"
$md += ""

$md += "## OU / Scope of Management"
$md += ""
if ($adComputerInfo -and $adComputerInfo.DistinguishedName) {
    $md += "| Property | Value |"
    $md += "|----------|-------|"
    $md += "| **Distinguished Name** | $($adComputerInfo.DistinguishedName) |"
    $md += "| **OU Path** | $(($adComputerInfo.DistinguishedName -split ',', 2)[1]) |"
    $md += ""

    if ($ouLinks.Count -gt 0) {
        $md += "### Linked GPOs (Inheritance)"
        $md += ""
        $md += "| GPO Name | GPO ID | Enabled | Enforced | Link Order |"
        $md += "|----------|--------|---------|----------|------------|"
        foreach ($link in $ouLinks) {
            $md += "| $(Format-MdCell $link.gpoName) | ``$($link.gpoId)`` | $(Format-MdCell $link.enabled) | $(Format-MdCell $link.enforced) | $(Format-MdCell $link.order) |"
        }
        $md += ""
    } else {
        $md += "*No OU inheritance data available.*"
        $md += ""
    }
} else {
    $md += "*OU data not available (ActiveDirectory module missing or device not domain-joined).*"
    $md += ""
}

# Applied GPOs
if ($Scope -in @('Computer','Both')) {
    $md += "## Applied GPOs (Computer)"
    $md += ""
    if ($appliedComputerGpos.Count -gt 0) {
        $md += "| GPO Name | GPO ID | Link/SOM | Enforced | Filter | Order |"
        $md += "|----------|--------|----------|----------|--------|-------|"
        foreach ($gpo in $appliedComputerGpos) {
            $md += "| $(Format-MdCell $gpo.name) | ``$($gpo.id)`` | $(Format-MdCell $gpo.link) | $(Format-MdCell $gpo.enforced) | $(Format-MdCell $gpo.filterAllowed) | $(Format-MdCell $gpo.order) |"
        }
        $md += ""
    } else {
        $md += "*No computer GPOs found in RSOP.*"
        $md += ""
    }
}

if ($Scope -in @('User','Both')) {
    $md += "## Applied GPOs (User)"
    $md += ""
    if ($appliedUserGpos.Count -gt 0) {
        $md += "| GPO Name | GPO ID | Link/SOM | Enforced | Filter | Order |"
        $md += "|----------|--------|----------|----------|--------|-------|"
        foreach ($gpo in $appliedUserGpos) {
            $md += "| $(Format-MdCell $gpo.name) | ``$($gpo.id)`` | $(Format-MdCell $gpo.link) | $(Format-MdCell $gpo.enforced) | $(Format-MdCell $gpo.filterAllowed) | $(Format-MdCell $gpo.order) |"
        }
        $md += ""
    } else {
        $md += "*No user GPOs found in RSOP.*"
        $md += ""
    }
}

# GPO Detail Summary
$md += "## GPO Detail Summary"
$md += ""
if ($gpoDetails.Count -gt 0) {
    $md += "| GPO Name | GPO ID | Policy Count | Registry Entries |"
    $md += "|----------|--------|--------------|------------------|"
    foreach ($detail in ($gpoDetails | Sort-Object name)) {
        $md += "| $(Format-MdCell $detail.name) | ``$($detail.id)`` | $($detail.policyCount) | $($detail.registryCount) |"
    }
    $md += ""

    foreach ($detail in ($gpoDetails | Sort-Object name)) {
        $md += "<details>"
        $md += "<summary>$(Format-MdCell $detail.name) ($($detail.id))</summary>"
        $md += ""

        if ($detail.policies.Count -gt 0) {
            $md += "### Policy Settings"
            $md += ""
            $md += "| Name | State | Category |"
            $md += "|------|-------|----------|"
            foreach ($pol in $detail.policies) {
                $polName = if ($pol.name) { $pol.name } else { "(Unnamed)" }
                $polState = if ($pol.state) { $pol.state } else { "" }
                $polCategory = if ($pol.category) { $pol.category } else { "" }
                $md += "| $(Format-MdCell $polName) | $(Format-MdCell $polState) | $(Format-MdCell $polCategory) |"
            }
            $md += ""
        }

        if ($detail.registryEntries.Count -gt 0) {
            $md += "### Registry Entries"
            $md += ""
            $md += "| Key | Value Name | Type | Value | Action |"
            $md += "|-----|------------|------|-------|--------|"
            foreach ($reg in $detail.registryEntries) {
                $regKey = if ($reg.key) { $reg.key } else { "" }
                $regName = if ($reg.valueName) { $reg.valueName } else { "" }
                $regType = if ($reg.type) { $reg.type } else { "" }
                $regValue = if ($reg.value) { $reg.value } else { "" }
                $regAction = if ($reg.action) { $reg.action } else { "" }
                $md += "| $(Format-MdCell $regKey) | $(Format-MdCell $regName) | $(Format-MdCell $regType) | $(Format-MdCell $regValue) | $(Format-MdCell $regAction) |"
            }
            $md += ""
        }

        if ($detail.policies.Count -eq 0 -and $detail.registryEntries.Count -eq 0) {
            $md += "*No detailed settings were parsed from the GPO report.*"
            $md += ""
        }

        $md += "</details>"
        $md += ""
    }
} else {
    $md += "*No GPO detail data available (module missing or report collection failed).*"
    $md += ""
}

# Errors
if ($gpoErrors.Count -gt 0) {
    $md += "## Notes and Warnings"
    $md += ""
    foreach ($err in $gpoErrors) {
        $md += "- $err"
    }
    $md += ""
}

$md += "---"
$md += ""
$md += "*Collected: $collectionDate by $currentUser*"

$md -join "`n" | Out-File -LiteralPath $mdPath -Encoding UTF8

# Create README
$readme = @()
$readme += "# Group Policy Export"
$readme += ""
$readme += "## Collection Information"
$readme += ""
$readme += "| Property | Value |"
$readme += "|----------|-------|"
$readme += "| **Collected By** | $currentUser |"
$readme += "| **Collection Date** | $collectionDate |"
$readme += "| **Collection Method** | $rsopMethod |"
$readme += "| **Script** | Policy-Compass.ps1 |"
$readme += "| **Computer** | $deviceName |"
$readme += "| **Domain** | $domain |"
$readme += ""
$readme += "## Files"
$readme += ""
$readme += "| File | Description |"
$readme += "|------|-------------|"
$readme += "| $([IO.Path]::GetFileName($mdPath)) | Markdown summary |"
$readme += "| $([IO.Path]::GetFileName($jsonPath)) | JSON report |"
$readme += ""
$readme += "---"
$readme += ""
$readme += "*Generated automatically by Policy-Compass.ps1*"

$readmePath = Join-Path $OutputPath "README.md"
$readme -join "`n" | Out-File -LiteralPath $readmePath -Encoding UTF8

Write-Host "  ✓ JSON report: $jsonPath" -ForegroundColor Green
Write-Host "  ✓ Markdown report: $mdPath" -ForegroundColor Green
Write-Host "  ✓ README index: $readmePath" -ForegroundColor Green

Write-Host "" 
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  Export Complete" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
