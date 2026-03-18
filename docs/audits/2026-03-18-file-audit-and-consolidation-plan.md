# KY House File Audit & Consolidation Plan

**Date:** 2026-03-18
**Machines scanned:** mx3 (M3 Max MacBook Pro), next-mbp (Always-On Mac, KY house)
**Total files found:** 2,625
**Dashboard:** `~/ky/ky-network/ky-files-dashboard.html` (interactive HTML with search/filter)

---

## Executive Summary

A fine-tooth-comb scan of both machines revealed 2,625 KY house-related files spread across 11 source directories and 16 categories. The data is rich but heavily fragmented — logging happens in 4 places, recurring tasks live in 3, and asset/inventory data spans 4 separate systems. The largest content island is 2,222 files in Dropbox on next-mbp that are completely disconnected from everything on mx3.

Three active projects exist that overlap in purpose:
1. **HomeLM** (this repo) — the aspirational AI-powered knowledge graph
2. **KY Knowledge Base** (`ky-network/knowledge-base/`) — operational markdown knowledge base
3. **Amazon Order Knowledge Graph** (`~/aia/`) — Obsidian vault of 1800+ purchase items

Additionally, **micasa** (https://github.com/cpcloud/micasa) was evaluated as a potential complementary tool for maintenance scheduling and appliance tracking.

---

## Inventory by Machine

### mx3 — 219 files

| Source | Files | Content |
|--------|-------|---------|
| `~/ky/ky-network/` | 146 | Knowledge base (13 MD files), Amazon CSVs (119 orders), session logs, dashboard, configs |
| `~/aia/amazon-order-knowledge-graph-and-genmoji/` | 55 | Obsidian vault with products, categories, vendors, dashboards, processing scripts |
| `~/code/vibe-ideas/.../KY House Projects/` | 35 | Captain's Log, Repeating Tasks, House TODO, Smart Home Dashboard, Networking Project |
| `~/Documents/LDB/` | 31 | Smart home inventory (374-line device catalog), journals, home dashboard, TODO |
| `~/code/home-lm/` | 14 | Research docs (landscape analysis, block structures, KG+LLM integration, HA integrations, tech stack) |
| `~/tgatl/` | 3 | HomeLM concept writeup for content library |
| `~/code/vibe-ideas/.../HomeLM/` | 2 | Project notes in Obsidian |
| `~/vaults/ky-vault/` | 2 | Minimal vault (Inbox.md only) |

### next-mbp — 2,406 files

| Source | Files | Content |
|--------|-------|---------|
| `~/Dropbox/KY House Shared Dropbox/` | 2,222 | House docs, chimney leak videos, electrical PDFs, sewer docs, nature videos, project photos (portico, brick path, dock, pressure washing, decluttering), Airbnb guest docs |
| `~/ky/ky-network/` | 146 | Synced copy of knowledge base (same as mx3 via NAS) |
| `~/Dropbox/KY AirBnB/` | 103 | Brandi task lists (xlsx), opening/closing checklists, listing photos, guest printouts, compliance/licensing/tax docs, rental spreadsheet |
| `~/Dropbox/KY-House/` | 12 | Roof replacement project (estimates, sketches, photos, video) |
| `~/vaults/ky-vault/` | 2 | Minimal vault (Inbox.md only) |

### Duplicates — 130 files

Mostly Amazon delivery photos (UUID-named JPEGs) that exist in both the ky-network repo's `purchases/_source/` and the Amazon Order KG project. Also includes session logs that are synced via the NAS git repo.

---

## Fragmentation Analysis

### Logging (4 locations)

| Source | Location | Machine | Type |
|--------|----------|---------|------|
| Captain's Log | `~/code/vibe-ideas/.../📓 KY House Captains Log.md` | mx3 | Narrative project log |
| Session Logs | `~/ky/ky-network/logs/` | both | Per-session technical logs |
| LDB Journals | `~/Documents/LDB/JOURNALS/` | mx3 | 50+ date-based daily notes |
| CHANGELOG | `~/ky/ky-network/CHANGELOG.md` | both | Git work summaries |

### Recurring Tasks (3 locations)

| Source | Location | Machine |
|--------|----------|---------|
| KY House Repeating Tasks | `~/code/vibe-ideas/.../🔁 KY House Repeating Tasks.md` | mx3 |
| BRANDY_TASKS.md | `~/ky/ky-network/knowledge-base/docs/` | both |
| AirBnB Checklists | `~/Dropbox/KY AirBnB/AirBnB/Lists/` (xlsx) | next-mbp |

### Asset/Inventory Data (4 locations)

| Source | Location | Machine | Content |
|--------|----------|---------|---------|
| Knowledge Base inventory | `knowledge-base/inventory/` | both | 13 structured MD files (smart home, appliances, network) |
| LDB Smart Home Inventory | `~/Documents/LDB/export smart home inventory.md` | mx3 | 374-line comprehensive device catalog |
| Amazon Order KG | `~/aia/amazon-order-knowledge-graph-and-genmoji/` | mx3 | 1800+ purchase items in Obsidian vault |
| Raw Amazon Orders | `knowledge-base/purchases/_source/` | both | 119 orders (CSV), unprocessed |

---

## micasa Evaluation

**Repository:** https://github.com/cpcloud/micasa
**Tech:** Go + Charmbracelet TUI + SQLite + GORM + Ollama LLM
**Stars:** 1,117 | **License:** Apache 2.0

### Strengths
- Excellent appliance tracking (purchase dates, warranties, costs, linked maintenance, OCR document extraction)
- Good maintenance scheduling (interval-based, auto-computed due dates, dashboard with overdue/upcoming)
- Project management with vendor quotes and budget tracking
- Incident tracking with severity levels
- Single SQLite file — elegant and portable
- LLM chat over SQL (supports Ollama, Anthropic, OpenAI, etc.)

### Gaps vs. HomeLM Vision
- No knowledge graph (flat relational model, no graph traversal)
- No spatial model (no rooms, zones, floors, area hierarchy)
- No daily house log / journal concept
- No people/household model (vendors only)
- No notifications or calendar integration
- TUI only — no web interface, no API, no mobile
- Single-user, no collaboration or sync
- Go-only ecosystem, no plugin system

### Verdict
Complementary, not competing. micasa excels at the maintenance/vendor/appliance tracking layer. HomeLM's value is in the knowledge graph, daily logging, spatial model, and AI-powered querying that micasa doesn't attempt.

---

## Recommended Consolidation Plan

### Phase 1 — Consolidate Text Content (immediate)
- Merge the LDB smart home inventory (374 lines) into `knowledge-base/inventory/smart-home/` files
- Move Captain's Log and Repeating Tasks from vibe-ideas into `knowledge-base/docs/`
- Process the 119 raw Amazon orders into inventory (data model decision pending since January)

### Phase 2 — Bridge the Dropbox Gap (immediate)
The 2,222 files on next-mbp in `Dropbox/KY House Shared Dropbox/` need to be accessible from mx3.
- **Option A:** Enable Dropbox on mx3 (instant sync, simplest)
- **Option B:** Copy important docs (PDFs, xlsx, docx) into `knowledge-base/docs/` in git
- **Option C:** Leave on next-mbp, create `knowledge-base/docs/DROPBOX_INDEX.md` manifest

**Recommendation:** Option A + C — sync Dropbox and add an index.

### Phase 3 — Decide the Tool Story
Three options:
1. **micasa for maintenance + HomeLM for everything else** — micasa as maintenance engine, HomeLM as knowledge graph
2. **All-in HomeLM** — Skip micasa, build everything in SvelteKit/PostgreSQL
3. **Knowledge base + micasa, defer HomeLM** — Markdown KB for knowledge/logs, micasa for scheduling, defer the full app

**Recommendation:** Option 3 for now. The markdown KB is working, micasa fills the scheduling gap, and HomeLM's graph features aren't needed until there are enough connected entities to justify graph queries.

### Phase 4 — Add Missing Models to Knowledge Base
Regardless of tooling:
- `knowledge-base/areas/` — Rooms, zones, outdoor spaces with relationships
- `knowledge-base/people/` — Family, Brandy, contractors, neighbors
- `knowledge-base/logs/` — Consolidated daily logging location

---

## Key Files Reference

| File | Path | Purpose |
|------|------|---------|
| Interactive Dashboard | `~/ky/ky-network/ky-files-dashboard.html` | Searchable/filterable view of all 2,625 files |
| This Report | `~/code/home-lm/docs/audits/2026-03-18-file-audit-and-consolidation-plan.md` | Full audit findings |
| Knowledge Base | `~/ky/ky-network/knowledge-base/` | Current operational KB |
| HomeLM Research | `~/code/home-lm/docs/research/` | Architecture and integration research |
| Amazon Raw Data | `~/ky/ky-network/knowledge-base/purchases/_source/` | 119 orders awaiting processing |
| Amazon KG | `~/aia/amazon-order-knowledge-graph-and-genmoji/` | 1800+ items in Obsidian vault |
