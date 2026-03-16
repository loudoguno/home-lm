# Module 1: Install & Explore micasa

**Time**: ~30 minutes
**Goal**: Get micasa running with seed data and learn the TUI navigation

---

## Exercise 1.1: Build from Source

```bash
# Clone the repo
git clone https://github.com/cpcloud/micasa.git
cd micasa

# Look at the Go module to understand dependencies
cat go.mod | head -30

# Build the binary
go build -o micasa ./cmd/micasa

# Verify it built
./micasa --help
```

**Questions to answer**:
- What version of Go is required?
- How many direct dependencies does micasa have?
- What CLI framework is used? (Hint: look at `cmd/micasa/`)

---

## Exercise 1.2: Run with Seed Data

```bash
# Run with generated seed data
./micasa --seed

# The TUI should launch with pre-populated data
```

**Navigation cheat sheet**:
| Key | Action |
|-----|--------|
| `Tab` / `Shift+Tab` | Switch between entity tabs |
| `j` / `k` or `↑` / `↓` | Navigate rows |
| `h` / `l` or `←` / `→` | Navigate columns |
| `Enter` | Open detail view / drill into |
| `Escape` | Go back |
| `a` | Add new item |
| `e` | Edit selected item |
| `d` | Delete selected item |
| `D` | Open dashboard |
| `@` | Open chat (NL queries) |
| `/` | Search |
| `?` | Help |
| `q` | Quit |

---

## Exercise 1.3: Explore Each Entity Tab

Work through each tab and note:

1. **Appliances** — What fields are tracked? (model, serial, warranty, purchase info?)
2. **Maintenance** — How are maintenance items linked to appliances? What scheduling options exist?
3. **Projects** — What are the project status options? How does the lifecycle work?
4. **Vendors** — What contact fields are stored?
5. **Incidents** — What severity levels exist? How are they linked to appliances/vendors?
6. **Service Log** — How does this relate to maintenance items?

**Take notes** — you'll compare this data model to Home LM's entity types in Module 7.

---

## Exercise 1.4: Find the Database File

```bash
# micasa stores everything in a single SQLite file
# Find it (it's in an XDG-standard location)
find ~/.local/share -name "*.db" 2>/dev/null | grep micasa

# Or check the config
./micasa config show
```

**Question**: Where is the database file stored? What XDG directory standard does it follow?

---

## Exercise 1.5: Explore the Database Directly

```bash
# Open the database with sqlite3
sqlite3 ~/.local/share/micasa/micasa.db

# List all tables
.tables

# Look at the schema
.schema appliances
.schema maintenance_items
.schema projects
.schema documents

# Count records in each table
SELECT 'appliances' as t, count(*) as n FROM appliances
UNION ALL SELECT 'maintenance_items', count(*) FROM maintenance_items
UNION ALL SELECT 'projects', count(*) FROM projects
UNION ALL SELECT 'vendors', count(*) FROM vendors
UNION ALL SELECT 'incidents', count(*) FROM incidents
UNION ALL SELECT 'documents', count(*) FROM documents;

# Check for soft-deleted records
SELECT count(*) FROM appliances WHERE deleted_at IS NOT NULL;

# Exit
.quit
```

---

## Exercise 1.6: Backup and Restore

```bash
# Create a backup
./micasa backup backup-test.db

# Verify the backup
sqlite3 backup-test.db "PRAGMA integrity_check;"

# Compare sizes
ls -la ~/.local/share/micasa/micasa.db backup-test.db
```

**Key insight**: The entire application state — data, documents, settings — lives in one file. This is micasa's core architectural invariant.

---

## Checkpoint

Before moving on, you should be able to answer:

- [ ] How do you build and run micasa?
- [ ] What are the main entity types and how do they relate?
- [ ] Where is the database stored?
- [ ] How does backup work?
- [ ] What does the TUI navigation feel like?

---

Next: [Module 2: Data Model Deep Dive →](./02-data-model.md)
