# Plan: Intune-ition Electron Desktop Dashboard

## Context

The Intune-ition suite has 4 PowerShell scripts that export Intune configurations to Markdown/JSON files. Currently they're CLI-only. The user wants an Electron desktop app that can run the scripts, browse results, compare snapshots over time, and search across all exports — a full dashboard experience.

## Technology Choices

| Layer | Choice | Rationale |
|-------|--------|-----------|
| Framework | **Electron + Vite** | Desktop app, local PS execution, fast dev |
| Frontend | **React + TypeScript** | Component-based UI for a complex dashboard |
| Styling | **Tailwind CSS** | Rapid styling, consistent design system |
| Markdown rendering | **react-markdown + rehype-raw** | Renders MD with embedded HTML (`<details>` blocks) |
| Search | **MiniSearch** | Lightweight in-memory full-text search, no server needed |
| Diff | **diff** (npm package) | Text diffing for snapshot comparison |
| State | **Zustand** | Lightweight, no boilerplate |
| Build | **electron-builder** | Standard Electron packaging |

## Project Structure

```
app/
├── package.json
├── electron.vite.config.ts
├── src/
│   ├── main/                    # Electron main process
│   │   ├── index.ts             # App entry, window creation
│   │   ├── ipc-handlers.ts      # IPC bridge (run scripts, read files, etc.)
│   │   ├── ps-runner.ts         # PowerShell child_process spawner + output parser
│   │   └── file-indexer.ts      # Scans workspace for exports, builds search index
│   ├── preload/
│   │   └── index.ts             # contextBridge API exposure
│   └── renderer/                # React app
│       ├── index.html
│       ├── main.tsx             # React entry
│       ├── App.tsx              # Root layout + routing
│       ├── stores/
│       │   ├── workspace-store.ts   # Workspace path, export history
│       │   └── run-store.ts         # Active runs, progress state
│       ├── components/
│       │   ├── Sidebar.tsx          # Navigation: Dashboard, Run, Browse, Compare
│       │   ├── RunConfigForm.tsx    # Script selector + parameter form
│       │   ├── RunProgress.tsx      # Live console output + progress bar
│       │   ├── ExportBrowser.tsx    # File tree of past exports
│       │   ├── MarkdownViewer.tsx   # Rendered MD with table support
│       │   ├── JsonViewer.tsx       # Pretty JSON viewer for import files
│       │   ├── SearchPanel.tsx      # Full-text search across all exports
│       │   ├── SnapshotDiff.tsx     # Side-by-side diff of two exports
│       │   └── DashboardHome.tsx    # Overview: recent runs, stats, quick actions
│       ├── lib/
│       │   ├── script-config.ts     # Script metadata (params, defaults, descriptions)
│       │   ├── output-parser.ts     # Parse PS console output → structured progress
│       │   └── search-engine.ts     # MiniSearch wrapper for indexing exports
│       └── styles/
│           └── globals.css          # Tailwind base + custom styles
```

## Key Screens

### 1. Dashboard Home
- Recent export runs with status (success/failed/running)
- Quick-action buttons: "Run Configuration-Harvester", "Run Application-Stall", etc.
- Stats: total exports, last run date, items per category
- Workspace folder selector

### 2. Run Export
- Script picker (4 cards, Baseline-Seed shown as "Coming Soon")
- Dynamic parameter form based on selected script:
  - Input mode toggle: All / Named Items / CSV File
  - Name patterns text field (comma-separated)
  - CSV file picker + column name
  - Platform dropdown (only for Application-Stall and Compliance-Fence)
  - Output path (auto-suggested: `workspace/YYYY-MM-DD_HH-mm/script-name/`)
- "Run" button → switches to live progress view

### 3. Run Progress
- Real-time console output panel (styled with colors matching PS output)
- Parsed progress: current stage (1-5), item counter, success/warning/error counts
- Stage progress bar
- "Open Output Folder" button on completion

### 4. Browse Exports
- Tree view: workspace → date folders → script outputs → individual files
- Click .md → rendered Markdown view
- Click .json → formatted JSON viewer with collapsible nodes
- README.md shown as folder summary

### 5. Search
- Full-text search bar across all exported Markdown/JSON files
- Results grouped by export run → file, with highlighted matches
- Click result → opens file in viewer at match location

### 6. Snapshot Comparison
- Pick two export runs (by date) for the same script type
- Shows: added items, removed items, changed items
- Click a changed item → side-by-side diff view of the Markdown content

## Data Flow

```
User clicks "Run" → renderer sends IPC 'run-script' with params
  → main process spawns: pwsh -File ./Script.ps1 -All -OutputPath ./out
  → stdout/stderr piped line-by-line via IPC 'script-output' to renderer
  → output-parser.ts extracts: stage, progress %, current item, status
  → RunProgress.tsx updates in real-time
  → On exit: IPC 'script-complete' with exit code
  → file-indexer.ts scans output folder, updates search index
  → ExportBrowser.tsx refreshes tree
```

## PowerShell Runner Design (`ps-runner.ts`)

```typescript
// Spawn PowerShell with script and args
// Use child_process.spawn('pwsh', ['-NoProfile', '-File', scriptPath, ...args])
// Fall back to 'powershell' if 'pwsh' not found
// Stream stdout line-by-line via IPC
// Parse ANSI-free output for progress tracking
// Handle exit codes: 0 = success, 1 = error
// Support cancellation via process.kill()
```

**Output parser** extracts structured data from console lines:
- `[N/5]` → stage number
- `[X/Y] ItemName...` → item progress
- `✓` → success event
- `WARNING:` → warning event
- `ERROR:` → error event

## Implementation Phases

### Phase 1: Scaffolding + Script Runner (Core)
Create the Electron + React + Vite project, implement the PS runner with IPC, build the RunConfigForm and RunProgress screens. This gets the core "run scripts from a GUI" working.

**Files:**
- `package.json`, `electron.vite.config.ts`, `tailwind.config.js`, `tsconfig.json`
- `src/main/index.ts`, `src/main/ipc-handlers.ts`, `src/main/ps-runner.ts`
- `src/preload/index.ts`
- `src/renderer/main.tsx`, `src/renderer/App.tsx`
- `src/renderer/components/Sidebar.tsx`, `RunConfigForm.tsx`, `RunProgress.tsx`
- `src/renderer/stores/run-store.ts`, `workspace-store.ts`
- `src/renderer/lib/script-config.ts`, `output-parser.ts`

### Phase 2: Browse + View
Add the export browser tree, Markdown viewer, JSON viewer. Wire up file reading via IPC.

**Files:**
- `src/renderer/components/ExportBrowser.tsx`, `MarkdownViewer.tsx`, `JsonViewer.tsx`
- `src/main/ipc-handlers.ts` (add file-reading handlers)

### Phase 3: Dashboard Home
Build the overview screen with recent runs, stats, and quick actions. Persist run history.

**Files:**
- `src/renderer/components/DashboardHome.tsx`
- `src/renderer/stores/workspace-store.ts` (add run history persistence)

### Phase 4: Search
Index all exported files, add full-text search UI.

**Files:**
- `src/main/file-indexer.ts`
- `src/renderer/lib/search-engine.ts`
- `src/renderer/components/SearchPanel.tsx`

### Phase 5: Snapshot Comparison
Diff engine for comparing exports across dates.

**Files:**
- `src/renderer/components/SnapshotDiff.tsx`

## Verification

1. **Script execution**: Run Configuration-Harvester.ps1 via the UI, confirm real-time output streaming and correct exit status
2. **Parameter handling**: Test All mode, named items with wildcards, CSV import, Platform dropdown
3. **Browse**: Open an existing export folder, navigate tree, click MD files and verify rendering (tables, `<details>` blocks, code fences)
4. **JSON viewer**: Open a companion .json file from Configuration-Harvester output
5. **Search**: Index a workspace, search for a profile name, verify results link to correct files
6. **Diff**: Run the same script twice, compare the two outputs, verify added/removed/changed detection
7. **Edge cases**: Baseline-Seed shown as disabled, cancelling a running export, empty workspace
