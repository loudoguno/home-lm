# Learn micasa: Project-Based Learning Guide

A hands-on learning path to understand micasa's architecture, patterns, and design decisions. Work through these exercises to build familiarity with the codebase before adapting patterns for Home LM.

## Prerequisites

- Go 1.25+ installed
- Git
- A terminal you're comfortable in
- Optional: Ollama (for LLM exercises)
- Optional: Nix (micasa uses nix for dev environment)

## Learning Path

| # | Module | Time | Focus |
|---|--------|------|-------|
| 1 | [Install & Explore](./01-install-and-explore.md) | 30 min | Get micasa running, seed data, navigate the TUI |
| 2 | [Data Model Deep Dive](./02-data-model.md) | 45 min | Explore the SQLite schema, relationships, and GORM patterns |
| 3 | [LLM Integration](./03-llm-integration.md) | 60 min | Set up Ollama, try NL queries, study the prompt pipeline |
| 4 | [Document Extraction](./04-document-extraction.md) | 45 min | Attach documents, trace the 3-stage extraction pipeline |
| 5 | [TUI Architecture](./05-tui-architecture.md) | 45 min | Understand Bubble Tea MVU, handlers, overlays |
| 6 | [Testing Patterns](./06-testing-patterns.md) | 30 min | Run the test suite, study the template DB pattern |
| 7 | [Architecture Comparison](./07-architecture-comparison.md) | 60 min | Map micasa patterns to Home LM's web architecture |

## Quick Start

```bash
# Clone the repo
git clone https://github.com/cpcloud/micasa.git
cd micasa

# Option A: Using Nix (recommended if you have it)
nix develop

# Option B: Using Go directly
go build -o micasa ./cmd/micasa

# Run with seed data
./micasa --seed
```

## Repository Structure (Key Files)

```
micasa/
├── cmd/micasa/          # CLI entry point
├── internal/
│   ├── app/             # TUI application (70+ files)
│   │   ├── model.go     # Main model (all state)
│   │   ├── handlers.go  # Entity handler interface
│   │   ├── forms.go     # Form definitions
│   │   ├── chat.go      # Chat overlay (NL→SQL)
│   │   └── styles.go    # Colorblind-safe styling
│   ├── data/            # Data layer (42 files)
│   │   ├── models.go    # GORM models (schema)
│   │   ├── store.go     # CRUD operations
│   │   ├── query.go     # SQL validation (5-layer defense)
│   │   └── fts.go       # Full-text search
│   ├── llm/             # LLM abstraction
│   │   ├── client.go    # Multi-provider client
│   │   └── prompt.go    # Prompt construction
│   ├── extract/         # Document extraction
│   │   ├── pipeline.go  # 3-stage orchestration
│   │   ├── shadow.go    # Shadow DB for batch ops
│   │   └── fkgraph.go   # FK topological sort
│   ├── config/          # TOML + env var config
│   └── ollama/          # Ollama-specific utilities
├── AGENTS.md            # Development philosophy
└── go.mod               # Dependencies
```
