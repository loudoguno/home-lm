# Module 7: Architecture Comparison

**Time**: ~60 minutes
**Goal**: Synthesize everything learned about micasa and map it to Home LM's web architecture

---

## Exercise 7.1: Side-by-Side Architecture

```
micasa (TUI)                          Home LM (Web)
─────────────────                     ─────────────────
Bubble Tea (Elm arch)                 SvelteKit
  model.go (all state)                  Svelte stores + page state
  Update() (message dispatch)           Event handlers + load()
  View() (terminal render)              Svelte components

SQLite (single file)                  PostgreSQL + pgvector
  GORM models                           Drizzle ORM
  FTS5                                  tsvector + GIN indexes
  WAL mode                              Connection pooling

Ollama (local)                        Ollama (local)
  any-llm-go (multi-provider)           OpenAI-compatible API
  NL→SQL pipeline                       RAG + NL→SQL hybrid

local filesystem                      Docker Compose
  XDG directories                       Caddy reverse proxy
  TOML config                           .env + DB settings
```

---

## Exercise 7.2: Data Model Translation

Translate micasa's entities into Home LM's block-based model:

### micasa's Approach (table-per-entity):
```sql
CREATE TABLE appliances (id, model, serial, ...);
CREATE TABLE maintenance_items (id, appliance_id, interval, ...);
CREATE TABLE service_log_entries (id, maintenance_item_id, cost, ...);
```

### Home LM's Approach (unified blocks):
```sql
CREATE TABLE blocks (
  id UUID, parent_id UUID, page_id UUID,
  content TEXT, name TEXT,
  entity_type ENUM('AREA','ASSET','PERSON','PROJECT','TASK','NOTE'),
  properties JSONB, ...
);
CREATE TABLE refs (source_id UUID, target_id UUID);
```

**Exercise**: Model a micasa appliance in Home LM's schema:

```
Page: [[ASSET/Dyson V15 Vacuum]]
  entity_type: ASSET
  properties: {
    "model": "Dyson V15 Detect",
    "serial": "ABC123",
    "purchase_date": "2024-06-15",
    "purchase_cost_cents": 74999,
    "warranty_expiry": "2026-06-15",
    "area": "[[AREA/Utility Closet]]"
  }

  Child blocks (maintenance log):
    - "Replaced HEPA filter" (2025-01-10)
    - "Cleaned brush bar, replaced battery" (2025-08-20)

  Refs:
    - refs(this_block, AREA/Utility Closet)
    - refs(this_block, PERSON/James @ Dyson Support)
```

**Questions**:
1. What are the tradeoffs of table-per-entity vs. unified blocks?
2. How does JSONB `properties` compare to dedicated columns?
3. How would you query "all assets with expired warranties" in each approach?
4. How would you handle micasa's cost-in-cents pattern in Home LM's JSONB?

---

## Exercise 7.3: Query Pipeline Translation

### micasa: NL→SQL

```
"How much did I spend on plumbing last year?"
  → LLM generates: SELECT SUM(cost) FROM service_log_entries
                    JOIN vendors ON ... WHERE specialty = 'plumbing'
                    AND serviced_at >= '2025-01-01'
  → Execute SQL → 2,450 (cents) → "$24.50"
  → LLM summarizes: "You spent $24.50 on plumbing services in 2025"
```

### Home LM: RAG + GraphRAG

```
"What problems have we had with the hot tub?"
  → Embed query → Vector search → Retrieve relevant blocks
  → Graph traversal → Find linked ASSET, AREA, PERSON blocks
  → LLM generates answer from retrieved context
```

### Hybrid approach for Home LM:

```
Query classification:
  ├── Structured query ("total cost of...", "how many...", "when was last...")
  │   └── NL→SQL pipeline (micasa-style)
  │
  └── Knowledge query ("what problems...", "tell me about...", "how does...")
      └── RAG + GraphRAG pipeline
```

**Exercise**: Design the query classifier. What heuristics would you use?

---

## Exercise 7.4: Feature Gap Analysis

What does micasa have that Home LM should adopt?

| Feature | micasa | Home LM Status | Priority |
|---------|--------|----------------|----------|
| Maintenance scheduling | Full (interval, season, schedule type) | Not started | High |
| Quote comparison | Labor/materials/other breakdown | Not planned | Medium |
| Document extraction | 3-stage pipeline | Not started | High |
| Vendor directory | Contact info, job history | Planned (PERSON entity) | Medium |
| Warranty tracking | Purchase date, expiry | In ASSET properties | Medium |
| Cost tracking | Integer cents, locale-aware | Not started | Medium |
| Backup | Single command | Docker volume backup | High |
| NL→SQL queries | Two-stage pipeline | Not started | High |
| SQL injection defense | 5-layer validation | Not started | High (if adding NL→SQL) |
| Soft deletes with audit | DeletionRecord table | Not started | Medium |

What does Home LM have that micasa doesn't?

| Feature | Home LM | micasa Status |
|---------|---------|---------------|
| Journal-first UX | Core concept | Not applicable |
| AI entity extraction | GLiNER + LLM | None |
| Knowledge graph | Bidirectional refs | None |
| Vector search (RAG) | pgvector | None |
| GraphRAG | Planned | None |
| Smart home integration | HA webhooks, weather API | None |
| Time-series correlation | InfluxDB planned | None |
| Voice interface | Planned | None |
| Graph visualization | Planned | None |
| Web UI | SvelteKit | TUI only |

---

## Exercise 7.5: Design a Hybrid Query System

Combine the best of both approaches:

```
┌─────────────────────────────────────────────────────────┐
│ User query: "How much did I spend on HVAC this year?"   │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
              ┌─────────────────────┐
              │  Query Classifier    │
              │  (lightweight LLM    │
              │   or rule-based)     │
              └─────────────────────┘
                    │           │
         structured │           │ knowledge
                    ▼           ▼
        ┌───────────────┐  ┌───────────────┐
        │ NL→SQL Pipeline│  │ RAG Pipeline   │
        │ (micasa-style) │  │ (Home LM-style)│
        └───────────────┘  └───────────────┘
                    │           │
                    ▼           ▼
              ┌─────────────────────┐
              │  Response Merger     │
              │  (combine structured │
              │   data + context)    │
              └─────────────────────┘
                         │
                         ▼
              ┌─────────────────────┐
              │  Natural Language    │
              │  Summary             │
              └─────────────────────┘
```

**Exercise**: Implement this design on paper:
1. What rules classify queries as "structured" vs. "knowledge"?
2. How does the NL→SQL pipeline access Home LM's block schema?
3. What SQL would answer "How much did I spend on HVAC?" against the blocks table?
4. What if the query needs both? ("What HVAC problems have we had, and how much did they cost?")

---

## Exercise 7.6: Extraction Pipeline for Web

Adapt micasa's extraction pipeline for Home LM:

### micasa (synchronous, local):
```
Upload file → Text extract → OCR → LLM structure → Save to DB
(all in one thread, blocking)
```

### Home LM (async, web):
```
Upload file → Save to object storage
  → Enqueue extraction job
    → Worker: Text extract → OCR → LLM structure
      → WebSocket: Send progress updates to client
        → Save extracted entities as blocks + refs
          → WebSocket: Notify completion
```

**Design questions**:
1. What job queue system? (pg-boss for PostgreSQL-native, BullMQ for Redis)
2. How to handle progress updates? (WebSocket per-user, or SSE?)
3. Where to store uploaded files? (PostgreSQL BYTEA like micasa, or S3/MinIO?)
4. How to handle the shadow database pattern in PostgreSQL?

---

## Exercise 7.7: Development Philosophy Comparison

| Principle | micasa | Home LM (proposed) |
|-----------|--------|---------------------|
| "LLM is optional" | Core invariant | Adopt: core features work without AI |
| "Single-file backup" | SQLite | Docker volume backup + pg_dump |
| "Resist configuration" | Sensible defaults | Adopt: auto-detect where possible |
| "Actionable errors" | Cause + remediation | Adopt |
| "Test through UI" | Key simulation | Playwright e2e |
| "Template DB for tests" | SQLite bytes | PostgreSQL TEMPLATE |
| "Typed enums" | Go iota | TypeScript union types |
| "Money as cents" | int64 | Consider adopting |
| "Colorblind-safe" | Wong palette | Adopt for web CSS |

---

## Final Reflection

Write a one-page summary answering:

1. **What is the single most valuable pattern from micasa for Home LM?**
   (Suggested: the NL→SQL pipeline with 5-layer validation)

2. **What is the biggest architectural difference and why?**
   (Suggested: freeform journal vs. structured forms — different UX philosophies)

3. **What would you build first based on this analysis?**
   (Suggested priority: journal entry → entity extraction → wiki-linking → NL→SQL → document extraction)

4. **What risk does micasa's existence create for Home LM?**
   (Suggested: minimal — different UX paradigm, different tech stack, complementary rather than competitive)

5. **What could you contribute back to micasa?**
   (Suggested: vector search / RAG capabilities, weather integration, Home Assistant integration)

---

## Checkpoint (Final)

- [ ] Can you map every micasa component to a Home LM equivalent?
- [ ] Can you design a hybrid query system (NL→SQL + RAG)?
- [ ] Can you adapt the extraction pipeline for async web architecture?
- [ ] Can you articulate why Home LM and micasa serve different users?
- [ ] Do you have a prioritized list of patterns to adopt?

---

## Congratulations!

You've completed the micasa learning path. You should now have:

1. A working micasa installation to reference
2. Deep understanding of its architecture and patterns
3. A clear map of what to adopt for Home LM
4. Hands-on experience with Go TUI, SQLite, and LLM integration patterns

**Next steps**:
- Start implementing the NL→SQL pipeline for Home LM (adapt `internal/llm/prompt.go`)
- Design the document extraction job queue
- Build the hybrid query classifier
- Add maintenance scheduling to Home LM's entity types
