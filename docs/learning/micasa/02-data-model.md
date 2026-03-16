# Module 2: Data Model Deep Dive

**Time**: ~45 minutes
**Goal**: Understand micasa's schema design, GORM patterns, and how entities relate

---

## Exercise 2.1: Read the Models

Open `internal/data/models.go` and study the GORM struct definitions.

```bash
# From the micasa repo root
cat internal/data/models.go
```

**Map the relationships**:

```
HouseProfile (singleton)
    │
    ├── Appliance
    │   ├── MaintenanceItem
    │   │   └── ServiceLogEntry → Vendor
    │   └── Incident → Vendor (optional)
    │
    ├── Project
    │   └── Quote → Vendor
    │
    ├── Vendor
    │
    └── Document (polymorphic → any entity)
```

**Questions**:
1. How does micasa store monetary values? (Hint: look for cost fields)
2. What type is used for soft deletes?
3. How does the polymorphic Document association work?
4. What GORM tags are used for relationships (`HasMany`, `BelongsTo`, `ForeignKey`)?

---

## Exercise 2.2: Understand the Enum Pattern

```bash
# Look for iota-based enums
grep -n "iota" internal/data/models.go
```

Study how micasa defines typed enums:

```go
// Example pattern (find the actual code):
type ProjectStatus int

const (
    ProjectStatusPlanned ProjectStatus = iota
    ProjectStatusUnderway
    // ...
)
```

**Questions**:
1. What project statuses exist?
2. What incident severities exist?
3. What schedule types exist for maintenance?
4. Why does AGENTS.md ban switching on bare integers?

---

## Exercise 2.3: Explore the Store Layer

```bash
# Read the store implementation
cat internal/data/store.go
```

**Key patterns to identify**:

1. **Generic CRUD helpers** — Find `listQuery[T]()`, `getByID[T]()`, `findOrCreate[T]()`
2. **Soft delete with audit** — Find `DeletionRecord` and `LastDeletion()`
3. **Dependency checking** — Find `checkDependencies()` and `checkParentsAlive()`
4. **Preloading** — How does micasa load related entities? (Look for `.Preload()` calls)

**Exercise**: Trace what happens when you delete an appliance:
- What dependencies are checked?
- What gets soft-deleted?
- What DeletionRecord is created?
- Can you restore it?

---

## Exercise 2.4: Full-Text Search

```bash
cat internal/data/fts.go
```

**Questions**:
1. Which FTS version is used (FTS4 or FTS5)?
2. What content is indexed?
3. What ranking algorithm is used?
4. How is stemming configured?

**Try it in SQLite**:

```sql
-- Open the database
sqlite3 ~/.local/share/micasa/micasa.db

-- Check the FTS table
.schema documents_fts

-- Try a search
SELECT * FROM documents_fts WHERE documents_fts MATCH 'filter';
```

---

## Exercise 2.5: The Defense-in-Depth Query System

This is one of micasa's best patterns. Read it carefully:

```bash
cat internal/data/query.go
```

**Identify the 5 layers of SQL injection protection**:

1. **Prefix check** — only SELECT allowed
2. **Semicolon rejection** — prevents query chaining
3. **Keyword blocklist** — blocks INSERT, UPDATE, DELETE, DROP, etc.
4. **EXPLAIN opcode inspection** — validates the query plan at the bytecode level
5. **Timeout** — 10-second execution limit

**Question**: Why is the EXPLAIN opcode inspection layer necessary when the keyword blocklist already exists?

**Answer hint**: Think about SQL features like CTEs, subqueries, and triggers that could execute writes even in a SELECT.

---

## Exercise 2.6: Money Handling

```bash
# Find how currency is handled
grep -rn "cents\|Currency\|FormatMoney\|safeconv" internal/data/ internal/locale/
```

**Key design decisions**:
- All costs stored as `int64` cents (not float64 dollars)
- `safeconv.Int()` for safe integer narrowing
- `Currency` interface handles locale-aware formatting

**Question**: What bugs could occur if money were stored as float64? (Try: `0.1 + 0.2` in any language)

---

## Exercise 2.7: Compare with Home LM's Schema

Open Home LM's schema side by side:

```bash
# Home LM's schema
cat /path/to/home-lm/scripts/init.sql
```

**Compare**:

| Aspect | micasa | Home LM |
|--------|--------|---------|
| Storage | SQLite single file | PostgreSQL + pgvector |
| Entity model | Fixed tables per entity | Unified blocks table with entity_type |
| Relationships | GORM foreign keys | Wiki-link refs table |
| Documents | BLOBs in SQLite | TBD |
| Full-text search | FTS5 | PostgreSQL GIN + tsvector |
| Vector search | None | pgvector |
| Soft deletes | GORM DeletedAt | TBD |
| Money | Integer cents | TBD |

**Reflection questions**:
1. What are the tradeoffs of micasa's table-per-entity vs. Home LM's unified blocks?
2. Which approach is better for freeform content? For structured queries?
3. How would you add vector search to micasa's architecture?
4. Should Home LM adopt integer cents for money?

---

## Checkpoint

- [ ] Can you draw the entity relationship diagram from memory?
- [ ] Do you understand the GORM patterns (soft delete, polymorphic, preload)?
- [ ] Can you explain the 5-layer query defense?
- [ ] Do you understand why money is stored as cents?

---

Next: [Module 3: LLM Integration →](./03-llm-integration.md)
