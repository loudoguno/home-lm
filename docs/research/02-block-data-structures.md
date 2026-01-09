# Block-Based Data Structures

## Overview

Roam Research pioneered the "block" as the atomic unit of knowledge. Understanding this architecture is essential for Home LM.

---

## Roam Research Schema (Datomic)

Roam stores individual facts as "Datoms" with four elements: Entity ID, Attribute, Value, Transaction ID.

### Core Block Attributes

| Attribute | Description |
|-----------|-------------|
| `:block/uid` | Public 9-character reference |
| `:block/string` | Text content |
| `:block/page` | Reference to parent page |
| `:block/order` | Position among siblings |
| `:block/parents` | ALL ancestors (not just immediate) |
| `:block/children` | Immediate descendants only |
| `:node/title` | Page title (pages only) |
| `:create/time`, `:edit/time` | Timestamps |

**Key insight**: Roam stores ALL ancestors in `:block/parents` for efficient upward traversal.

---

## Logseq Schema (DataScript)

Logseq uses DataScript (ClojureScript Datomic implementation):

```clojure
:block/uuid           ;; unique identifier
:block/page           ;; parent page reference
:block/parent         ;; parent block reference
:block/content        ;; block text
:block/format         ;; markdown/org
:block/level          ;; nesting depth
:block/children       ;; child blocks
:block/refs           ;; referenced pages (forward links)
:block/path-refs      ;; all refs including ancestors
:block/properties     ;; custom properties
:block/marker         ;; task status (TODO, DONE)
:block/created-at     ;; timestamp
:block/last-modified-at
```

---

## Bidirectional Linking

### How Backlinks Work

**Approach 1: Store forward links, compute backlinks**

```clojure
;; Query: Find all blocks referencing page "X"
[:find (pull ?b [*])
 :where [?p :block/name "x"]
        [?b :block/refs ?p]]
```

**Approach 2: Explicit bidirectional storage**

Store both forward and reverse references at write time for faster reads.

### Reference Extraction

Logseq uses AST walking (`walk/postwalk`) to extract:
- `[[wiki-links]]`
- `#tags`
- `((block-references))`

---

## Daily Notes Pattern (DNP)

Daily notes are pages with date-formatted titles:
- `January 9th, 2026` (Roam)
- `2026-01-09` (Logseq)

### Temporal Queries

Dates become first-class entities. Special inputs in Logseq:

```clojure
:today, :yesterday, :tomorrow
:-7d, :+1m, :-2y  ;; relative dates
```

Example query - "What happened to Dyson Vacuum in 2025?":

```clojure
{:query [:find ?date ?content
         :in $ ?start ?end ?asset
         :where [?p :block/name ?asset]
                [?b :block/refs ?p]
                [?b :block/page ?j]
                [?j :block/journal-day ?date]
                [(>= ?date ?start)]
                [(<= ?date ?end)]
                [?b :block/content ?content]]
 :inputs [20250101 20251231 "asset/dyson-vacuum"]}
```

---

## Proposed Home LM Schema (PostgreSQL)

```sql
-- Unified blocks table (pages are blocks with name)
CREATE TABLE blocks (
  id TEXT PRIMARY KEY,
  uuid TEXT UNIQUE NOT NULL,
  parent_id TEXT REFERENCES blocks(id),
  page_id TEXT REFERENCES blocks(id),
  content TEXT,
  name TEXT,  -- Only for pages/entities
  entity_type TEXT,  -- AREA, ASSET, PERSON, PROJECT, etc.
  is_journal INTEGER DEFAULT 0,
  journal_date INTEGER,  -- YYYYMMDD format
  properties JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Block ordering within parent
CREATE TABLE block_order (
  parent_id TEXT REFERENCES blocks(id),
  child_id TEXT REFERENCES blocks(id),
  position INTEGER,
  PRIMARY KEY (parent_id, child_id)
);

-- Reference tracking (bidirectional links)
CREATE TABLE refs (
  source_block_id TEXT REFERENCES blocks(id),
  target_page_id TEXT REFERENCES blocks(id),
  PRIMARY KEY (source_block_id, target_page_id)
);
CREATE INDEX idx_refs_target ON refs(target_page_id);

-- Full-text search
CREATE INDEX idx_blocks_fts ON blocks
  USING GIN (to_tsvector('english', content));

-- Vector embeddings (pgvector)
ALTER TABLE blocks ADD COLUMN embedding vector(1536);
CREATE INDEX idx_blocks_embedding ON blocks
  USING ivfflat (embedding vector_cosine_ops);
```

---

## Query Examples

### "Show all mentions of [[ASSET/Dyson Vacuum]] across daily notes"

```sql
SELECT j.journal_date, b.content
FROM blocks b
JOIN refs r ON r.source_block_id = b.id
JOIN blocks p ON r.target_page_id = p.id
JOIN blocks j ON b.page_id = j.id
WHERE p.name = 'ASSET/Dyson Vacuum'
  AND j.is_journal = 1
ORDER BY j.journal_date DESC;
```

### "Show all ASSETS in AREA/Kitchen"

```sql
SELECT * FROM blocks
WHERE entity_type = 'ASSET'
  AND properties->>'location' = 'AREA/Kitchen';
```

### Semantic search - "problems with hot tub"

```sql
SELECT content, 1 - (embedding <=> $query_embedding) as similarity
FROM blocks
WHERE embedding IS NOT NULL
ORDER BY embedding <=> $query_embedding
LIMIT 10;
```

---

## Key Design Decisions for Home LM

1. **Unified blocks table** - Pages and blocks are the same entity (pages just have `name` field)
2. **Entity types via prefix** - `ASSET/`, `AREA/`, `PERSON/` for clear categorization
3. **JSONB properties** - Flexible metadata without schema changes
4. **Integrated vectors** - pgvector in same database avoids sync complexity
5. **Explicit refs table** - Faster backlink queries than computing on the fly

---

## Sources

- Roam Data Structure: https://www.zsolt.blog/2021/01/Roam-Data-Structure-Query.html
- Logseq Schema: https://gist.github.com/tiensonqin/9a40575827f8f63eec54432443ecb929
- Logseq DB Version: https://github.com/logseq/docs/blob/master/db-version.md
