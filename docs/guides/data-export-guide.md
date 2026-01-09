# Data Export Guide

How to export your existing data from Notion, Roam Research, Apple Notes, and other sources for import into Home LM.

---

## Notion Export

### Method 1: Full Workspace Export (Recommended)

1. Go to **Settings & Members** → **Settings**
2. Scroll down to **Export all workspace content**
3. Choose export format:
   - **Markdown & CSV** (recommended for Home LM)
   - Include subpages: Yes
   - Create folders for subpages: Yes
4. Click **Export** and wait for the email with download link

### What You'll Get

```
Export-xxxxx/
├── Database Name/
│   ├── Item 1.md
│   ├── Item 2.md
│   └── Database Name.csv  # Metadata for all items
├── Page Name.md
└── Another Page/
    └── Nested Page.md
```

### Notion-Specific Considerations

- **Databases**: Export as CSV + individual markdown files
- **Relations**: Exported as text (page titles), not links
- **Properties**: Preserved in CSV, not in markdown frontmatter
- **Images**: Downloaded and linked relatively (good!)
- **Embedded content**: May lose formatting

### Recommended Properties to Preserve

When preparing Notion for export, ensure these properties exist:

| Entity Type | Key Properties |
|-------------|---------------|
| Areas/Rooms | Name, Floor, Square Footage |
| Assets | Name, Location, Purchase Date, Model Number, Serial Number |
| People | Name, Role (family/contractor/neighbor), Contact Info |
| Projects | Name, Status, Target Date, Related Areas |
| Tasks | Name, Status, Due Date, Related Project |

---

## Roam Research Export

### Method 1: JSON Export (Recommended)

1. Click the **...** menu (top right)
2. **Export All**
3. Choose **JSON** format
4. Download the zip file

### JSON Structure

```json
{
  "title": "Page Title",
  "uid": "abc123def",
  "children": [
    {
      "string": "Block content with [[links]]",
      "uid": "ghi456jkl",
      "create-time": 1641234567890,
      "edit-time": 1641234567890,
      "children": [...]
    }
  ]
}
```

### What's Preserved

- **Block hierarchy**: Full parent-child structure
- **UIDs**: Can maintain references
- **Wiki-links**: `[[Page Name]]` syntax
- **Block references**: `((block-uid))` syntax
- **Timestamps**: Create and edit times
- **Attributes**: `Attribute:: Value` syntax

### Method 2: Markdown Export (Alternative)

1. Same menu → **Export All** → **Markdown**
2. Produces flat markdown files with indented bullets

**Pros**: Human-readable
**Cons**: Loses block UIDs, harder to maintain references

---

## Apple Notes Export

Apple Notes doesn't have a native bulk export. Options:

### Method 1: Exporter App (Recommended)

Use **Exporter** app from Mac App Store ($9.99):
1. Select notes/folders to export
2. Choose Markdown format
3. Export with attachments

### Method 2: AppleScript + Automator

```applescript
tell application "Notes"
    repeat with theNote in notes of folder "House"
        set noteName to name of theNote
        set noteBody to body of theNote
        -- Save to file...
    end repeat
end tell
```

### Method 3: Manual Copy-Paste

For small collections, copy content manually into markdown files.

### What You'll Get

- Plain text content
- Attachments as separate files
- No linking structure (Apple Notes doesn't have wiki-links)

---

## Other Sources

### Obsidian

Already markdown! Just copy the vault folder.

### Logseq

Already markdown/org files. Copy the `pages/` and `journals/` directories.

### Evernote

1. File → Export Notes → **ENEX format**
2. Use a converter like [evernote2md](https://github.com/wormi4ok/evernote2md)

### Google Keep

1. Use Google Takeout
2. Export as JSON
3. Convert with [keep-to-md](https://github.com/vHanda/google-keep-exporter)

---

## Data Preparation Recommendations

Before exporting, organize your data to make import easier:

### 1. Establish Naming Conventions

Use prefixes for entity types:
- `AREA/Kitchen`, `AREA/Master Bedroom`
- `ASSET/Dyson Vacuum`, `ASSET/Hot Tub`
- `PERSON/John Contractor`, `PERSON/Neighbor Sue`
- `PROJECT/Bathroom Renovation`

### 2. Capture Key Metadata

For each asset, try to record:
```markdown
---
type: ASSET
location: AREA/Kitchen
purchase_date: 2024-06-15
model: DC50
serial: ABC123XYZ
---
```

### 3. Date Your Entries

If you have historical information, include dates:
```markdown
## 2024-06-15
Bought new Dyson vacuum, stored in [[AREA/Utility Closet]]
```

### 4. Link Related Items

Even in preparation, start using wiki-link syntax:
- "The [[ASSET/Hot Tub]] is located in the [[AREA/Back Deck]]"
- "[[PERSON/Plumber Joe]] fixed the issue on [[2024-03-20]]"

---

## Export Format Preferences

For Home LM import, prefer:

1. **Markdown** - Human readable, easy to parse
2. **JSON** - Preserves structure, good for Roam
3. **CSV** - Good for database/property data

### Ideal Export Package

```
exports/
├── notion/
│   ├── assets.csv
│   ├── areas.csv
│   ├── people.csv
│   └── pages/
│       └── *.md
├── roam/
│   └── export.json
├── apple-notes/
│   └── *.md
└── photos/
    ├── receipts/
    └── documentation/
```

---

## Import Process (Coming Soon)

Home LM will support:

1. **Bulk markdown import** - Parse wiki-links, extract entities
2. **CSV import** - Map columns to entity properties
3. **Roam JSON import** - Preserve block structure and UIDs
4. **AI-assisted entity extraction** - Auto-detect AREA, ASSET, PERSON mentions

The import process will:
1. Parse all files
2. Extract wiki-links and create entity pages
3. Build the reference graph
4. Generate embeddings for semantic search
5. Present conflicts/duplicates for resolution

---

## Questions?

As you export, document:
- What information is most important?
- What patterns do you already use?
- What's missing that you wish you had captured?

This will help shape the Home LM data model.
