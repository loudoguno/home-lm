# Landscape Analysis: PKM + AI Tools

## Executive Summary

After comprehensive research (January 2026), **no existing tool truly nails the home knowledge base use case**. The market is fragmented between:

1. **AI-enhanced note tools** (Notion AI, Mem.ai) - good AI, weak knowledge graphs
2. **Block-based outliners** (Roam, Logseq) - great structure, minimal AI
3. **Property management tools** - ignore daily note workflow
4. **Knowledge graph tools** (Neo4j) - powerful but enterprise-focused

---

## Tool Comparison Matrix

| Tool | Entity Extraction | Semantic Search | Wiki-Links | Self-Hosted | Open Source |
|------|------------------|-----------------|------------|-------------|-------------|
| **Notion AI** | Excellent | Good | Database relations only | No | No |
| **Tana** | Manual only | Good | Native (supertags) | No | No |
| **Obsidian** | Needs plugins | Needs plugins | Yes | Yes | Yes |
| **Logseq** | Needs plugins | Needs plugins | Yes | Yes | Yes |
| **Roam Research** | Minimal | Minimal | Yes | No | No |
| **Mem.ai** | Auto-suggested | Good | Auto-suggested | No | No |
| **Capacities** | Manual | Good | Object-based | No | No |
| **Anytype** | Minimal | Minimal | Yes | Yes | Yes |

---

## Detailed Analysis

### Tier 1: Commercial AI-First Tools

#### Notion AI (3.0 with Agents - Sept 2025)
- **AI**: Multi-model (GPT-5, Claude Opus 4.5, o3), agents for automation
- **Knowledge Graph**: Limited - databases with relations, not true graph
- **Home Management Fit**: MEDIUM
- **Limitations**: Cloud-only, expensive, no true bidirectional linking

#### Tana
- **AI**: Integrated for supertags and automations
- **Knowledge Graph**: NATIVE - built as living network with supertags
- **Home Management Fit**: HIGH (supertags could model rooms/assets)
- **Limitations**: Proprietary, cloud-dependent, steep learning curve

#### Mem.ai
- **AI**: Automatic organization and connection suggestion
- **Knowledge Graph**: Implicit (auto-connections)
- **Home Management Fit**: LOW - designed for creative work, not structured tracking

### Tier 2: Block-Based Outliners

#### Roam Research
- **Architecture**: Block-based, bidirectional linking, Datomic backend
- **AI**: Minimal
- **Home Management Fit**: MEDIUM
- **Limitations**: Cloud-only, expensive ($180/year), limited AI

#### Logseq (Open Source)
- **Architecture**: Block-based, DataScript, markdown files
- **AI**: Minimal (community plugins)
- **Home Management Fit**: HIGH as foundation
- **Strengths**: Open source, local-first, free

#### Obsidian
- **Architecture**: File-based markdown, plugin ecosystem
- **AI**: 50+ community AI plugins (half run locally)
- **Home Management Fit**: HIGH with plugins
- **Strengths**: 2000+ plugins, complete data ownership

### Tier 3: Open Source Knowledge Graph Tools

#### Neo4j LLM Knowledge Graph Builder
- **Architecture**: Graph database + GraphRAG
- **AI**: Works with any LLM including local Ollama
- **Home Management Fit**: HIGH POTENTIAL
- **Limitations**: Steep learning curve, enterprise-focused

#### WhyHow Knowledge Graph Studio (MIT)
- **Architecture**: MongoDB backend, LLM-ready
- **Home Management Fit**: HIGH POTENTIAL
- **Strengths**: Built specifically for LLM integration

---

## The Gap

What Home LM needs to provide that doesn't exist:

1. **Daily note input with wiki-linking** ✓ (Obsidian/Roam/Logseq)
2. **AI-assisted entity extraction** ✗ (No tool does this well)
3. **Semantic search across home knowledge** ✗ (Requires custom RAG)
4. **Asset tracking with room associations** ✗ (PM tools separate from notes)
5. **Open-source + self-hosted** ✓ (Logseq, Obsidian)
6. **Natural language querying** ✗ (Requires custom LLM integration)

---

## Recommendation

Build on **Logseq's data model** (open source, block-based, DataScript) with:
- Custom AI layer for entity extraction (GLiNER + local LLM)
- pgvector for semantic search
- Custom entity types (AREA, ASSET, PERSON, PROJECT)
- Natural language query interface

Alternatively, build from scratch with:
- SvelteKit for UI
- PostgreSQL for blocks + pgvector for embeddings
- Ollama for local LLM
- GLiNER for fast entity extraction

---

## Sources

- Notion 3.0 release: https://www.notion.com/releases/2025-09-18
- Tana supertags: https://tana.inc
- Logseq architecture: https://github.com/logseq/logseq
- Neo4j LLM Graph Builder: https://neo4j.com/labs/genai-ecosystem/llm-graph-builder/
- WhyHow Studio: https://github.com/whyhow-ai/knowledge-graph-studio
