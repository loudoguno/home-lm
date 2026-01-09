# Home LM

> An AI-native knowledge graph for physical spaces - a "second brain" for your house

## Vision

Home LM is a self-hosted knowledge management system designed specifically for managing everything about a physical property: assets, areas, people, events, maintenance, and the relationships between them all.

**The Problem**: Existing tools (Notion, Roam, property management software) either:
- Lack true knowledge graph capabilities (Notion)
- Lack AI-assisted entity extraction (Roam, Logseq)
- Ignore the daily note context workflow (property management tools)
- Are cloud-only with privacy concerns (most)

**The Solution**: A system where you write natural daily log entries like:

```
[[PERSON/Contractor A]] stopped by today to give a bid on redoing the
concrete in the [[AREA/Laundry Room]], [[AREA/Library]], and [[AREA/Playroom]].
After moving the [[ASSET/Grand Piano]] in the Library to get a better estimate,
he mentioned we had mold by the baseboards...
```

And the AI:
1. **Auto-extracts entities** from natural language input
2. **Suggests wiki-links** to existing entities
3. **Builds the knowledge graph** incrementally over time
4. **Answers natural language queries** like "What problems have we had with the hot tub?"

## Core Entity Types

| Type | Prefix | Description |
|------|--------|-------------|
| Journals | `[[2026-01-09]]` | Daily note pages - the primary input interface |
| Areas | `[[AREA/Kitchen]]` | Rooms, closets, yards - containers for assets |
| Assets | `[[ASSET/Dyson Vacuum]]` | Appliances, tools, furniture with tracking |
| Tasks | `[[TASK/...]]` | Individual to-dos |
| Projects | `[[PROJECT/...]]` | Multi-task initiatives with finish lines |
| People | `[[PERSON/...]]` | Family, contractors, neighbors |
| Notes | `[[NOTE/...]]` | Ideas, goals, observations |

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      USER INTERFACES                         │
├─────────────────────────────────────────────────────────────┤
│  Web UI (SvelteKit)  │  Voice Interface  │  Mobile (future) │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      AI LAYER                                │
├─────────────────────────────────────────────────────────────┤
│  Entity Extraction  │  Link Suggestion  │  Query Answering  │
│  (GLiNER + Ollama)  │  (Local LLM)      │  (RAG + GraphRAG) │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      DATA LAYER                              │
├─────────────────────────────────────────────────────────────┤
│  Block Storage    │  Knowledge Graph  │  Vector Embeddings  │
│  (PostgreSQL)     │  (PostgreSQL)     │  (pgvector)         │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   EXTERNAL INTEGRATIONS                      │
├─────────────────────────────────────────────────────────────┤
│  Weather Station  │  Home Assistant  │  Calendar/Reminders  │
│  (Ambient API)    │  (REST API)      │  (future)            │
└─────────────────────────────────────────────────────────────┘
```

## Tech Stack

| Component | Choice | Rationale |
|-----------|--------|-----------|
| **Web Framework** | SvelteKit | Smaller bundle, faster TtI, native WebSockets |
| **Database** | PostgreSQL + pgvector | Unified blocks + vectors + full-text search |
| **Local LLM** | Ollama | Easy model management, OpenAI-compatible API |
| **Entity Extraction** | GLiNER + ReLiK | Fast, local, no LLM calls needed |
| **Vector Search** | pgvector | 2.5ms queries, integrated with PostgreSQL |
| **Voice (future)** | faster-whisper | Local speech-to-text |
| **Deployment** | Docker + Caddy | Simple LAN hosting |

## Project Status

**Phase**: Research & Architecture Planning

See `/docs/research/` for detailed findings on:
- Existing PKM + AI tools landscape
- Block-based data structures (Roam/Logseq architecture)
- Knowledge graph + LLM integration patterns
- Home automation integrations
- Self-hosted tech stack recommendations

## Roadmap

### Phase 1: Core Data Model
- [ ] Define block schema (blocks, references, properties)
- [ ] Implement Daily Note Page (DNP) pattern
- [ ] Wiki-link parsing and bidirectional reference tracking
- [ ] Basic web UI for note entry

### Phase 2: AI Integration
- [ ] Local LLM setup with Ollama
- [ ] Entity extraction from natural language
- [ ] Link suggestion based on existing entities
- [ ] Embedding generation for blocks

### Phase 3: Querying
- [ ] Full-text search
- [ ] Semantic search via embeddings
- [ ] Natural language query interface
- [ ] GraphRAG for cross-document reasoning

### Phase 4: External Integrations
- [ ] Weather station API integration
- [ ] Home Assistant webhook receiver
- [ ] Grafana dashboards for time-series correlation

### Phase 5: Voice Interface
- [ ] Speech-to-text via faster-whisper
- [ ] Voice-based entry logging
- [ ] Text-to-speech responses

## Getting Started

```bash
# Clone the repository
git clone https://github.com/yourusername/home-lm
cd home-lm

# Start with Docker Compose (coming soon)
docker compose up -d

# Access at http://localhost:3000 or http://home-lm.local
```

## Related Projects

Projects that influenced Home LM's design:

- [Logseq](https://github.com/logseq/logseq) - Open-source block-based outliner
- [Microsoft GraphRAG](https://github.com/microsoft/graphrag) - Graph-based RAG approach
- [WhyHow Knowledge Graph Studio](https://github.com/whyhow-ai/knowledge-graph-studio) - LLM-ready knowledge graphs
- [Cognee](https://github.com/topoteretes/cognee) - Memory layer for AI agents
- [Reor](https://github.com/reorproject/reor) - Private AI PKM with local LLMs

## License

MIT
