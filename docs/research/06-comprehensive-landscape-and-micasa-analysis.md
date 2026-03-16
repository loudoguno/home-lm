# Comprehensive Landscape Analysis: Home Knowledge Management, Automation, and AI

> Research conducted March 2026. This document expands on `01-landscape-analysis.md` with a deep competitive landscape survey and a detailed technical analysis of [micasa](https://github.com/cpcloud/micasa), the most relevant open-source project in this space.

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [The Problem Space](#the-problem-space)
3. [micasa: Deep Technical Analysis](#micasa-deep-technical-analysis)
4. [Knowledge Management Tools](#knowledge-management-tools)
5. [Home Automation Platforms](#home-automation-platforms)
6. [Property Management & Inventory Tools](#property-management--inventory-tools)
7. [AI-Powered Emerging Players](#ai-powered-emerging-players)
8. [Open-Source Foundations](#open-source-foundations)
9. [Cross-Cutting Themes](#cross-cutting-themes)
10. [Comparison Matrix](#comparison-matrix)
11. [Implications for Home LM](#implications-for-home-lm)
12. [Sources](#sources)

---

## Executive Summary

After surveying **30+ tools** across knowledge management, home automation, property management, and AI-powered home tools, the landscape breaks down into four quadrants:

```
                        Structured Data
                             |
        micasa               |           Notion / Airtable
        HomeBox              |           HomeZada / Buildium
        Baserow              |
                             |
  Self-Hosted ---------------+--------------- Cloud
                             |
        Obsidian             |           Capacities
        Logseq               |           Dib / HomeLedger
        Anytype              |           Mem.ai
                             |
                        Freeform / Notes
```

**No existing tool combines all of**: freeform journal input, AI entity extraction, knowledge graph, smart home integration, and self-hosting. This is the gap Home LM fills.

The most relevant project is **micasa** — a mature (1,100+ commits, 158 releases) Go/SQLite TUI app for home management. It validates the problem space and offers excellent patterns to learn from, but targets a fundamentally different user (structured data entry via forms vs. freeform journaling with AI extraction).

---

## The Problem Space

Homeowners need to track an interconnected web of information:

- **Assets**: Appliances, systems, furniture — with manuals, warranties, purchase info, serial numbers
- **Maintenance**: Recurring schedules, service history, costs, vendor relationships
- **Projects**: Renovations, improvements — with quotes, budgets, timelines, contractor contacts
- **Incidents**: Problems that arise — linked to assets, areas, weather events, service responses
- **Documents**: Manuals, invoices, permits, insurance policies, inspection reports
- **Observations**: Daily notes, seasonal patterns, things noticed that don't fit a form

The existing tool landscape forces users to choose between:

1. **Structured tools** (micasa, HomeZada, Buildium) — great for forms and queries, bad for freeform capture
2. **Freeform tools** (Obsidian, Logseq, Notion) — great for notes, weak on structured home data
3. **Automation platforms** (Home Assistant, OpenHAB) — great for device data, no knowledge management
4. **AI-powered tools** (Dib, HomeLedger) — promising but cloud-only and closed-source

Home LM's thesis: **start with freeform journal entries, use AI to extract structure, build a knowledge graph that connects everything, and integrate with smart home systems for sensor correlation**.

---

## micasa: Deep Technical Analysis

### Overview

| | |
|---|---|
| **Repository** | https://github.com/cpcloud/micasa |
| **Language** | Go 1.25+ (zero CGO) |
| **Database** | SQLite (single file, WAL mode) |
| **UI** | Terminal (Charmbracelet: bubbletea, bubbles, lipgloss, huh, glamour) |
| **LLM** | Optional, 10 providers via `any-llm-go` |
| **License** | Apache 2.0 |
| **Maturity** | 1,098 commits, 158 releases, 1.1k stars |
| **Author** | Phillip Cloud (cpcloud) |

### What It Solves

micasa is a "personal database for everything about maintaining a physical property." It tracks maintenance schedules, renovation projects, appliance inventories, vendor contacts, incidents, quotes, and documents — all in a single SQLite file with a VisiData-inspired terminal UI.

**Important**: Despite the name, micasa is **not** a home automation/IoT platform. It does not control devices. It is a home *management data tracker* with an optional AI query layer.

### Data Model

The schema centers on these entities:

| Entity | Key Fields | Relationships |
|--------|-----------|---------------|
| **HouseProfile** | Address, foundation, wiring, roof, utilities, insurance, HOA | Singleton root |
| **Project** | Status lifecycle (planned→underway→delayed→completed→cancelled), budget, dates | Has many Quotes, Documents |
| **Quote** | Labor/materials/other cost breakdown (stored as integer cents) | Belongs to Project + Vendor |
| **Vendor** | Name, contact, specialties | Has many Quotes, ServiceLogEntries |
| **MaintenanceItem** | Interval (months), season, schedule type | Belongs to Category + Appliance |
| **Appliance** | Model, serial, warranty dates, purchase cost | Has many MaintenanceItems, Incidents |
| **Incident** | Severity (low/medium/high/urgent), status | Optional Appliance + Vendor links |
| **ServiceLogEntry** | Cost, date serviced | Belongs to MaintenanceItem + Vendor |
| **Document** | Content BLOB, MIME type, SHA256, extracted text, OCR text | Polymorphic to any entity |
| **Setting** | Key-value store | App preferences, chat history |

**Key design decisions**:
- Money stored as **integer cents** (int64) — avoids floating-point rounding
- **Soft deletes** with `DeletionRecord` audit trail and undo support
- **Polymorphic document attachment** — one Document table serves all entities via EntityKind + EntityID
- **Full-text search** via SQLite FTS5 with BM25 ranking and porter stemming
- **Code-generated metadata** — `go:generate` produces column definitions used by extraction and UI

### LLM Integration: The NL→SQL Pipeline

micasa's AI integration is the most instructive pattern for Home LM:

**Two-stage query pipeline**:

```
User question: "What did I spend on plumbing last year?"
         │
         ▼
┌─────────────────────────────────────────┐
│ Stage 1: SQL Generation                  │
│ - System prompt with: current date,      │
│   full DDL schema, entity relationships, │
│   column value hints, 13 few-shot SQL    │
│   examples                               │
│ - LLM outputs: raw SELECT statement      │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ SQL Execution                            │
│ - 5-layer defense: prefix check,         │
│   semicolon rejection, keyword blocklist,│
│   EXPLAIN opcode inspection, timeout     │
│ - Results capped at 200 rows             │
│ - Pipe-delimited output (token-efficient)│
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ Stage 2: Summary Generation              │
│ - Original question + SQL + results      │
│ - LLM generates natural language answer  │
└─────────────────────────────────────────┘
         │
         ▼
Fallback: If SQL generation fails,
single-stage with full DataDump()
```

**Key prompt engineering decisions**:
- Schema DDL is included directly (the LLM "sees" the database structure)
- Column value hints show distinct values from key columns for entity name matching
- Few-shot examples explicitly disambiguate cost semantics (quotes vs. actual spending vs. maintenance costs)
- `dateContext()` provides current date so the LLM can handle "this year" / "last month"
- Results rendered as pipe-delimited text rather than JSON (better LLM comprehension per token)

**Error handling** converts provider errors into actionable user messages:
- Timeout → suggests increasing timeout
- Connection refused → suggests `ollama serve` for Ollama
- Auth failure → directs to API key configuration
- Rate limiting → suggests waiting
- Model not found → suggests `ollama pull`

### Document Extraction: 3-Stage Pipeline

```
Document input (PDF, image, text)
         │
         ▼
┌─────────────────────────┐
│ Stage 1: Text Extraction │  PlainTextExtractor, PDFTextExtractor
│ - MIME-type matched      │  (shells out to pdftotext)
│ - Detects scanned docs   │
└─────────────────────────┘
         │
         ▼
┌─────────────────────────┐
│ Stage 2: OCR             │  Tesseract via pdftocairo → PNG → TSV
│ - Parallel per page      │  Spatial layout with bounding boxes
│ - Confidence threshold   │  Capped at CPU count (semaphore)
└─────────────────────────┘
         │
         ▼
┌─────────────────────────┐
│ Stage 3: LLM Structuring │  Schema context + existing entities
│ - JSON Schema constrained │  + 12 extraction rules + 3 worked
│ - Typed operations        │  examples (invoice, manual, report)
│ - Shadow database for     │
│   cross-reference         │
│   resolution              │
└─────────────────────────┘
```

**The Shadow Database pattern** (most architecturally interesting):
When an LLM generates batch operations with cross-references (e.g., "create vendor, then create quote referencing that vendor"):
1. An in-memory SQLite database is created with extraction-relevant tables
2. Auto-increment IDs are seeded from the real database's max values
3. Creates are inserted sequentially into shadow tables, recording IDs
4. On commit, shadow rows are remapped from shadow IDs to real IDs using an `idMap`
5. FK dependencies are resolved via topological sort (Kahn's algorithm)

Each stage **degrades gracefully** — failures are captured in results rather than crashing the pipeline.

### TUI Architecture

- **Elm architecture** (Model-View-Update) via Bubble Tea
- **Handler-per-entity pattern** — `TabHandler` interface with 8 implementations, adding a new entity type means implementing one interface
- **Three modes**: Normal (vim navigation), Edit (cell editing), Form (full-screen data entry)
- **9 overlay types** rendered atop the base view (dashboard, calendar, chat, help, etc.)
- **Detail drilldown stack** for navigation like Appliance → Maintenance → Service Log
- **Wong colorblind-safe palette** via `lipgloss.AdaptiveColor` for light/dark terminals

### Development Philosophy (from AGENTS.md)

Key principles worth adopting:
1. **LLM features are optional enhancements** — never required for core functionality
2. **Resist configuration; prefer sensible defaults and auto-detection**
3. **Actionable error messages** — include failure, cause, and remediation
4. **Silence indicates success** — no empty-state placeholders
5. **Every `ORDER BY` needs tiebreakers** (typically `id DESC`)
6. **Tests simulate real user interaction** — no mocking the data layer, test via actual keypresses
7. **Template database pattern for tests** — pre-migrated, seeded DB copied per test (~1ms vs ~150ms)

### Testing Patterns

- Integration tests against real SQLite (no mocks for data layer)
- `MICASA_TEST_SEED` for reproducible randomized tests
- `skipOrFatalCI()` — skips when external tools are absent locally, fails in CI
- ~70 test functions in the LLM client alone covering streaming, cancellation, errors, timeouts, mid-stream disconnections

### What to Steal

1. **NL→SQL→NL pipeline** — complement Home LM's RAG with this for structured queries
2. **5-layer SQL injection defense** — essential if exposing NL-to-SQL
3. **Document extraction pipeline with graceful degradation** — adopt the 3-stage pattern
4. **Shadow database for batch LLM operations** — solve cross-referencing elegantly
5. **Handler-per-entity pattern** — clean code organization for multiple entity types
6. **Cost semantics in prompts** — teach the LLM domain-specific cost distinctions
7. **Template database for fast tests** — use PostgreSQL template databases
8. **Single-command backup** from day one

### What Not to Copy

- **Form-based data entry** — Home LM's journal-first UX is the differentiator
- **Single-file SQLite** — PostgreSQL + pgvector is right for AI-native features
- **TUI** — web UI is needed for richer interactions (graph visualization, voice, real-time suggestions)
- **Local-only operation** — Home LM needs to integrate with Home Assistant, weather APIs, InfluxDB

---

## Knowledge Management Tools

### Obsidian

| | |
|---|---|
| **Type** | Local-first markdown knowledge base |
| **Self-hostable** | Yes (local files, sync via Syncthing/Git) |
| **Graph view** | Yes (built-in) |
| **AI** | Via plugins (Copilot, Smart Connections) — supports local LLMs |
| **Structured data** | Via Dataview plugin (SQL-like queries over YAML frontmatter) |
| **Price** | Free (personal + commercial) |

**Strengths for home management**: 2,700+ plugins. Dataview can generate maintenance dashboards from frontmatter metadata. Complete data ownership (plain markdown files). Canvas for floor plans. Free.

**Weaknesses**: Structured data requires plugin configuration. No true relational database. Steep learning curve for Dataview. No built-in collaboration.

### Logseq

| | |
|---|---|
| **Type** | Open-source block-based outliner |
| **Self-hostable** | Yes (local files; sync backend not self-hostable) |
| **Graph view** | Yes |
| **AI** | Via plugins (Copilot, Composer, Ollama-Logseq) — less mature than Obsidian |
| **Structured data** | Weak in stable version; DB version (alpha) introduces Classes/Types |
| **Price** | Free, open source (AGPL-3.0) |

**Strengths**: Block-level referencing (more granular than Obsidian). Built-in task management (TODO/DOING/DONE). Daily journal is excellent for maintenance logging. Free and open source.

**Weaknesses**: DB version with proper structured data still in alpha. Datalog queries have a steep learning curve. Mobile sync is a pain point. Performance degrades with large vaults.

### Notion

| | |
|---|---|
| **Type** | Cloud-based all-in-one workspace |
| **Self-hostable** | No (Enterprise on-prem only) |
| **Graph view** | No |
| **AI** | Deep native (multi-model agents, GPT-5/Claude/o3) |
| **Structured data** | Excellent — native relational databases with multiple views |
| **Price** | Free (limited) → $20/user/mo for Business with AI |

**Strengths**: Most powerful structured data of any note-taking tool. Multiple database views (table, board, calendar, timeline, gallery). AI agents can automate tasks across databases. Rich home management template marketplace. Best collaboration.

**Weaknesses**: Not self-hostable. No E2E encryption. Requires internet. Vendor lock-in (export loses relations). Expensive. No graph view.

### Anytype

| | |
|---|---|
| **Type** | Local-first, E2E encrypted, P2P knowledge management |
| **Self-hostable** | Yes (full self-host via Docker) |
| **Graph view** | Yes |
| **AI** | Local API for local LLMs (2026) — most privacy-respecting model |
| **Structured data** | Strong — Object-Type-Relation model (closest to an ontology) |
| **Price** | Free with self-hosting; $5-20/mo for managed infrastructure |

**Strengths**: Object-Type-Relation model is the most semantically rich. E2E encryption protects sensitive home data. Self-hostable eliminates paid plans. P2P sync between devices. Sovereign Collaboration for family sharing.

**Weaknesses**: Steepest learning curve. Younger product, smaller community. No web version. Minimal plugin ecosystem. Source-available (not truly open source).

### Capacities

| | |
|---|---|
| **Type** | Cloud-based object-oriented note-taking |
| **Self-hostable** | No |
| **Graph view** | No (planned) |
| **AI** | Built-in (GPT-4.1); agentic chat on roadmap |
| **Structured data** | Moderate — custom object types with properties |
| **Price** | Free (basic) → $9.99/mo (Pro with AI) |

**Strengths**: Object-type model maps naturally to home entities. AI auto-fill reduces data entry. Clean UI. Good mobile app. GDPR-compliant (German company). Daily notes with object tagging.

**Weaknesses**: Not self-hostable. No graph view. No plugin system. Less powerful than Notion for structured data. No local LLM support.

---

## Home Automation Platforms

### Home Assistant

| | |
|---|---|
| **Type** | Open-source home automation hub |
| **Self-hostable** | Yes (the only way to run it) |
| **AI/LLM** | Best-in-class: Assist (voice), MCP server/client, AI Tasks, 10+ LLM providers, local Ollama |
| **Historical data** | 3-tier: raw states (10d) → 5-min stats → hourly long-term (indefinite) |
| **Integrations** | 2,800+ |

**AI integration detail**:
- **Assist**: Built-in intent-based voice control, no cloud required (Piper TTS, local STT)
- **LLM Conversation Agents**: Plug in any LLM (OpenAI, Anthropic, Ollama, OpenRouter) as a conversation backend
- **MCP Server**: Expose your home to Claude Desktop or any MCP client (~1.2% of installs)
- **MCP Client**: Connect HA to external MCP servers for memory, web search, etc.
- **AI Tasks (2025.8)**: Trigger AI completions from automations
- **Streaming TTS**: 10x latency reduction for voice responses

**Home knowledge base potential**: Historical data on every sensor/device. Energy dashboard with cost tracking. Logbook for chronological events. MCP enables external LLMs to query home state. To-do lists, shopping lists, calendars provide non-device data.

**Weaknesses**: Steep learning curve. Database grows without careful filtering. No knowledge management (notes, documents, inventory). Running local LLMs needs significant hardware.

### OpenHAB

| | |
|---|---|
| **Type** | Open-source Java-based home automation |
| **Self-hostable** | Yes |
| **AI/LLM** | Minimal (community Gemini integration via MQTT) |
| **Historical data** | Excellent — pluggable persistence (rrd4j, InfluxDB, JDBC, MongoDB) |
| **Integrations** | 400+ |

**Strengths**: Extremely modular (OSGi). Robust persistence with multiple backends. Strong configuration-as-code. Mature (founded 2010).

**Weaknesses**: No meaningful AI/LLM integration (far behind Home Assistant). Steeper learning curve. Smaller community. Java runtime is heavy. Webhook support is immature.

### Homey

Consumer-friendly hub with 50,000+ device support, visual automation builder (Homey Flow), and energy monitoring. New self-hosted server option (late 2025). **No AI/LLM integration**. Insights data resolution degrades over time. Cannot import historical data.

### SmartThings / Hive

**SmartThings**: Major consumer platform but **only 7 days of event retention** and **no data export**. No AI/LLM integration. Cloud-dependent. The Groovy shutdown (2023) broke most community data logging.

**Hive**: UK-focused heating control. **No public API**. Has remotely disabled products (cameras, sensors). Cloud-first, API-hostile architecture. Declining.

### Dashboard Tools (Homer, Heimdall, Organizr)

These are **link aggregators**, not platforms. They organize bookmarks to self-hosted services in a single page. No data storage, no AI, no knowledge management capability. Useful as a "front door" but not relevant to the core problem.

---

## Property Management & Inventory Tools

### Commercial Property Management (Buildium, AppFolio)

These are enterprise platforms for landlords/property managers, but their patterns inform consumer tools:

**Buildium** (Lumina AI):
- AI Bill Scan extracts invoice data automatically
- AI Summarization reduces task review time by 83%
- Work order lifecycle: create → assign → track → complete → bill
- Pricing: $58-400/month (per-unit scaling)

**AppFolio** (Realm-X):
- Most AI-forward platform: agentic AI for leasing and maintenance
- AI handles intake, triage, vendor coordination, feedback
- 80% rating for autonomous task execution
- "AI handles it, human oversees" model

**Lessons**: Work order lifecycle is a proven pattern. AI bill scan and summarization are high-value features. Agentic AI for maintenance triage is the gold standard.

### Consumer Home Management

**HomeZada**: All-in-one (inventory, maintenance, finances). Treats home as financial asset. Account transfer to new homeowner. AI features nascent. Cloud-only. $99-189/year.

**Centriq** (SHUT DOWN Jan 2025): Photo-based product identification → manuals, recalls, parts. Loved by users. Failed financially. All data deleted. **Cautionary tale about cloud-only home data with no export**.

**Encircle Home Inventory** (SHUTTING DOWN): Room-by-room inventory for insurance. Pivoting entirely to B2B insurance/restoration. Another consumer home tool failure.

**HomeLedger** (2024): AI scheduling based on actual assets and seasons. Digital binder with searchable documents. AI helper "Joe." Partnered with Thumbtack. iOS/Android apps. Cloud-based.

### Inventory Tools

**Sortly**: Visual inventory management with barcode/QR scanning. Business-focused, expensive for personal use. No AI, no maintenance scheduling. Cloud-only.

**Airtable**: Flexible relational database with spreadsheet UX. AI add-on ($6/seat/mo). Rich templates. Cloud-only, expensive at scale ($20-45/seat/mo). Hard caps on records and automation runs.

**Baserow**: Open-source Airtable alternative. **Self-hostable with unlimited rows**. AI fields and Kuma AI assistant. Home Assistant integration. REST API. MIT-licensed core. Free self-hosted tier. Strongest "build your own" foundation.

---

## AI-Powered Emerging Players

### Dib (dib.io) — Most relevant new entrant

Direct successor to Centriq. The closest existing product to an "AI-native home management" tool:

- **AI Chat**: Natural language queries about home items (warranty status, filter types, purchase dates)
- **Smart Photo Add**: Photograph a label/receipt → AI extracts brand, model, serial number
- **Conversational Manuals**: Ask "How do I reset the ice maker?" instead of reading 200-page PDFs (RAG over product manuals)
- **AI Document Processing**: Upload photo → AI extracts key information
- **Proactive Reminders**: Learns appliances, reminds about filter changes, warranty expirations

Pricing: Free (unlimited items) → $120/year for AI features. Cloud-only, closed-source.

### Vendoroo — AI Maintenance Coordinator

AI-powered work order lifecycle for property managers: triage, troubleshooting, vendor selection, scheduling, completion verification. 80% reduction in maintenance tasks. $3/door/month.

### Kukun — Predictive Maintenance

IoT sensors + AI for predictive home maintenance. "Agentic AI" concept: leak detected while away → AI shuts off water valve and contacts plumber automatically.

### Mezo — Maintenance AI

Virtual assistant "Max" with 3-minute average diagnosis time. Automated workflows for property managers.

---

## Open-Source Foundations

### HomeBox — Most relevant OSS project

Self-hosted home inventory (Go + SQLite + embedded web UI):
- Hierarchical locations, multi-label tagging
- Warranty and document tracking
- Purchase price/date, maintenance log per item
- Auto-generated QR codes (print and scan)
- CSV import, multi-tenant, full-text search
- Docker deployment, < 50MB memory

**No AI, no maintenance scheduling (only logging), no document intelligence**. The gap is clear.

### Baserow

Open-source Airtable. Self-hostable, unlimited rows, REST API, Home Assistant integration, AI fields. Could serve as a backend for structured home data. But it's a generic database tool — needs home-specific logic on top.

---

## Cross-Cutting Themes

### 1. Consumer home management tools struggle to survive

Centriq (dead), Encircle (dead), and many others have failed. Homeowners are reluctant to pay ongoing subscriptions for home management. Open-source and self-hosted models may be more sustainable.

### 2. AI is the differentiator

Dib, AppFolio, Buildium, and Vendoroo prove that AI features (document extraction, conversational manuals, predictive maintenance, automated triage) create real value and willingness to pay.

### 3. The "scan and identify" pattern works

Centriq proved it, Dib continues it. Photographing a product label and having AI extract brand/model/serial/manual is a killer feature.

### 4. Self-hosted options exist but lack AI

HomeBox is excellent for inventory but has zero intelligence. Baserow is powerful but generic. micasa has optional AI but is TUI-only. The gap is a **self-hosted, AI-powered, web-based home knowledge management platform**.

### 5. Data portability is existential

Both Centriq and Encircle's shutdowns left users scrambling. Any serious home management tool must treat data portability as a first-class feature. SQLite (micasa, HomeBox) and PostgreSQL backup are proven patterns.

### 6. Home Assistant is the integration backbone

With MCP server/client support, 2,800+ integrations, and the best AI/LLM story in home automation, Home Assistant is the hub everything should connect to — not replace.

### 7. The NL→SQL pipeline complements RAG

micasa's two-stage pipeline (generate SQL → execute → summarize) is more reliable than RAG for structured queries ("How much did I spend on plumbing?"). Home LM should offer both: RAG for freeform knowledge queries, NL→SQL for structured data queries.

---

## Comparison Matrix

### Knowledge Management

| Feature | Obsidian | Logseq | Notion | Anytype | Capacities | Home LM |
|---------|----------|--------|--------|---------|------------|---------|
| Self-hostable | Yes (files) | Partial | No | Yes | No | **Yes** |
| Graph view | Yes | Yes | No | Yes | No | **Yes** |
| E2E encryption | N/A (local) | N/A (local) | No | Yes | No | N/A (local) |
| Structured data | Plugin | Weak | Strong | Strong | Moderate | **AI-extracted** |
| AI integration | Plugins | Plugins | Deep native | Local API | Built-in | **Core** |
| Entity extraction | No | No | No | No | No | **Yes** |
| Open source | No | Yes | No | Source-available | No | **Yes** |
| Home-specific | No | No | Templates | No | No | **Purpose-built** |

### Home Management

| Feature | micasa | HomeBox | HomeZada | Dib | Baserow | Home LM |
|---------|--------|---------|----------|-----|---------|---------|
| Self-hosted | Yes | Yes | No | No | Yes | **Yes** |
| AI powered | Optional | No | Nascent | Yes | Basic | **Core** |
| Document extraction | 3-stage pipeline | No | No | AI-powered | No | **Planned** |
| NL queries | NL→SQL | No | No | AI chat | No | **RAG + NL→SQL** |
| Maintenance scheduling | Yes | Log only | Yes | Reminders | No | **Yes** |
| Knowledge graph | No | No | No | No | No | **Yes** |
| Smart home integration | No | No | No | No | HA integration | **Yes** |
| Journal-first UX | No | No | No | No | No | **Yes** |
| Voice interface | No | No | No | No | No | **Planned** |

---

## Implications for Home LM

### Strategic Positioning

```
Home LM = Obsidian's wiki-linking
        + micasa's home domain model
        + Dib's AI document intelligence
        + Home Assistant's sensor integration
        + Self-hosted, open-source, privacy-first
```

### Patterns to Adopt from micasa

1. **NL→SQL→NL pipeline** for structured queries (complement RAG)
2. **5-layer SQL injection defense** for user-facing NL→SQL
3. **3-stage document extraction** with graceful degradation
4. **Shadow database pattern** for batch LLM operations
5. **Entity handler pattern** for clean code organization
6. **Domain-specific cost semantics** in LLM prompts
7. **Template database for fast tests**
8. **Single-command backup** from day one
9. **Soft deletes with audit trail**
10. **Money as integer cents**

### Patterns to Adopt from the Broader Landscape

1. **"Scan and identify" UX** from Centriq/Dib — photograph a label, AI extracts everything
2. **Conversational manuals** from Dib — RAG over product documentation
3. **MCP integration** from Home Assistant — expose Home LM as an MCP server
4. **Agentic maintenance triage** from AppFolio/Vendoroo — AI handles routine decisions
5. **Object-Type-Relation model** from Anytype — inform entity type design
6. **Baserow's template system** — distributable home management schemas

### Differentiators No One Else Has

1. **Journal-first UX with AI entity extraction** — write naturally, structure emerges
2. **Knowledge graph with bidirectional links and GraphRAG** — connect everything
3. **Smart home event integration** — correlate observations with sensor data
4. **Time-series correlation** — "When did it last flood?" + actual rainfall data
5. **Voice interface** for hands-free entry while working on the house
6. **Self-hosted + AI-native** — the gap no one fills

### Risks to Mitigate

1. **Consumer sustainability** — Centriq and Encircle failed. Open-source + self-hosted avoids this, but needs a compelling UX to drive adoption
2. **AI reliability** — micasa's "LLM is optional" principle is wise. Core features must work without AI
3. **Complexity** — Anytype's steep learning curve is a warning. The journal-first UX must feel effortless
4. **Data portability** — support Markdown export, standard formats, and easy backup from day one

---

## Sources

### micasa
- [GitHub Repository](https://github.com/cpcloud/micasa)
- [Documentation Site](https://micasa.dev)

### Knowledge Management
- [Obsidian](https://obsidian.md) | [Copilot Plugin](https://www.obsidiancopilot.com/en)
- [Logseq](https://logseq.com) | [DB Version FAQ](https://discuss.logseq.com/t/logseq-db-unofficial-faq/32508)
- [Notion AI](https://www.notion.com/product/ai) | [3.0 Release](https://www.notion.com/releases/2025-09-18)
- [Anytype](https://anytype.io) | [Self-Hosting Docs](https://doc.anytype.io/anytype-docs/advanced/data-and-security/self-hosting/self-hosted)
- [Capacities](https://capacities.io) | [Roadmap](https://capacities.io/roadmap/whats-next)

### Home Automation
- [Home Assistant AI Blog](https://www.home-assistant.io/blog/2025/09/11/ai-in-home-assistant/)
- [HA MCP Server](https://www.home-assistant.io/integrations/mcp_server/)
- [HA Summer of AI (2025.8)](https://www.home-assistant.io/blog/2025/08/06/release-20258/)
- [OpenHAB](https://v50.openhab.org/) | [InfluxDB Persistence](https://www.openhab.org/addons/persistence/influxdb/)
- [Homey Self-Hosted](https://technewscentury.co.uk/2025/12/17/homey-launches-self-hosted-server-for-power-users/)

### Property Management
- [HomeZada](https://www.homezada.com/)
- [Centriq Shutdown / Dib Alternative](https://dib.io/blog/centriq-shutting-down-alternative)
- [Dib](https://dib.io/)
- [HomeLedger](https://www.homeledger.app/)
- [Buildium Lumina AI](https://www.buildium.com/features/ai-property-management-software/)
- [AppFolio Realm-X](https://www.appfolio.com/performance-platform)
- [Vendoroo](https://vendoroo.ai/)

### Open Source
- [HomeBox](https://github.com/sysadminsmedia/homebox)
- [Baserow](https://github.com/baserow/baserow)
- [home-llm (HA local LLM)](https://github.com/acon96/home-llm)

### Industry Analysis
- [Best Home Management Platforms 2026 (Domidocs)](https://domidocs.com/homeowner-library/the-best-all-in-one-home-management-platforms-of-2026/)
- [Open Source LLMs for Smart Home](https://www.siliconflow.com/articles/en/best-open-source-LLM-for-Smart-Home)
