# Module 4: Document Extraction Pipeline

**Time**: ~45 minutes
**Goal**: Understand the 3-stage extraction pipeline, OCR, LLM structuring, and the shadow database pattern

---

## Exercise 4.1: Prerequisites

```bash
# Check if extraction tools are installed
which pdftotext  # from poppler-utils
which tesseract  # OCR engine
which pdftocairo # PDF to image (poppler-utils)

# Install if needed (Debian/Ubuntu)
sudo apt install poppler-utils tesseract-ocr

# Or on macOS
brew install poppler tesseract
```

---

## Exercise 4.2: Attach a Document via the TUI

1. Navigate to any entity (appliance, project, vendor)
2. Open the detail view (Enter)
3. Navigate to the Documents section
4. Press `a` to add a new document
5. Select a PDF or image file

**Observe**: Watch the extraction progress. micasa shows per-stage progress (text extraction → OCR → LLM structuring).

---

## Exercise 4.3: Read the Pipeline Code

```bash
cat internal/extract/pipeline.go
```

**Trace the 3 stages**:

### Stage 1: Text Extraction

```bash
cat internal/extract/text.go
cat internal/extract/extractor.go
```

- `PlainTextExtractor` — handles text/* MIME types
- `PDFTextExtractor` — shells out to `pdftotext` with 30-second timeout
- `IsScanned()` — detects empty text indicating a scanned document

**Question**: Why does it shell out to `pdftotext` instead of using a Go library?

### Stage 2: OCR

```bash
cat internal/extract/ocr.go
```

**Key patterns**:
- `PDFOCRExtractor` — rasterizes PDF → PNG via `pdftocairo`, pipes to `tesseract`
- `ImageOCRExtractor` — runs tesseract directly on image bytes
- Parallel processing capped at CPU count (semaphore pattern)
- `SpatialTextFromTSV()` — converts tesseract TSV to spatial layout with bounding boxes

**Exercise**: Find the confidence threshold. What happens if OCR confidence is below the threshold?

**Question**: Why does micasa preserve spatial layout (bounding boxes) in OCR output? How does this help the LLM?

### Stage 3: LLM Structuring

```bash
cat internal/extract/llmextract.go
cat internal/extract/operations.go
```

**Identify**:
1. How is the extraction prompt constructed?
2. What rules are given to the LLM? (Find the 12 rules)
3. What worked examples are included? (invoice, manual, inspection report)
4. How is JSON Schema used to constrain LLM output?
5. How are operations validated after extraction?

---

## Exercise 4.4: The Shadow Database (Key Pattern)

This is micasa's most architecturally interesting pattern:

```bash
cat internal/extract/shadow.go
```

**The problem**: When the LLM extracts structured data from a document, it may generate multiple related operations — e.g., "create a vendor, then create a quote referencing that vendor." The quote needs the vendor's ID, but the vendor doesn't exist yet.

**The solution**:

```
1. Create an in-memory SQLite database (shadow)
2. Seed auto-increment IDs from real DB max values
   (ensures disjoint ID ranges)
3. Insert creates into shadow tables sequentially
   (record auto-increment IDs as they're assigned)
4. On commit:
   a. Read rows from shadow tables
   b. Remap FK columns from shadow IDs → real IDs using idMap
   c. Write to real database in a transaction
```

**Exercise**: Trace through the code and answer:
1. How does `NewShadowDB()` initialize the in-memory database?
2. How does `Stage()` track assigned IDs?
3. How does `Commit()` remap foreign keys?
4. How are polymorphic document relationships handled? (Find `remapDocumentEntity()`)

---

## Exercise 4.5: FK Graph (Topological Sort)

```bash
cat internal/extract/fkgraph.go
```

This uses **Kahn's algorithm** to ensure tables are committed in FK-dependency order (parents before children).

**Questions**:
1. Why is topological sort necessary? What would break without it?
2. How are polymorphic relationships handled in the graph?
3. Why does the graph computation panic on startup if cycles exist?

---

## Exercise 4.6: Graceful Degradation

The pipeline is designed to degrade gracefully at each stage:

```bash
# Find how failures are handled
grep -n "err\|Error\|failure\|degrade" internal/extract/pipeline.go
```

**Map the degradation path**:
- If `pdftotext` is not installed → skip text extraction, try OCR
- If `tesseract` is not installed → skip OCR, proceed with whatever text was extracted
- If Ollama is not available → skip LLM structuring, save document with raw text only
- If LLM output is invalid JSON → log error, save document without structured data

**Question**: Why is graceful degradation important? What would a user experience if the pipeline simply failed?

---

## Exercise 4.7: Map to Home LM

**Reflection**:

1. **Document storage**: micasa stores documents as BLOBs in SQLite. Home LM uses PostgreSQL. Should documents be BLOBs or object storage (S3/MinIO)?

2. **Extraction workers**: micasa runs extraction synchronously. A web app should use an async job queue. What's the architecture? (WebSocket for progress updates?)

3. **Tool dependencies**: micasa shells out to pdftotext/tesseract. A web service could use:
   - pdf.js for client-side PDF rendering
   - server-side Go/Python PDF libraries
   - Cloud OCR APIs (Google Vision, AWS Textract)

4. **Shadow database in PostgreSQL**: The shadow DB pattern is SQLite-specific. In PostgreSQL, what alternatives exist?
   - Staging tables with deferred FK constraints
   - CTEs with `RETURNING` clauses
   - Transaction savepoints

5. **Home LM-specific extraction**: What would extraction look like for journal entries vs. documents? Could the same pipeline extract entities from daily notes?

---

## Checkpoint

- [ ] Can you explain each stage of the extraction pipeline?
- [ ] Do you understand the shadow database pattern?
- [ ] Can you explain why topological sort is needed for FK resolution?
- [ ] Do you understand how graceful degradation works?
- [ ] Can you design an equivalent pipeline for a web application?

---

Next: [Module 5: TUI Architecture →](./05-tui-architecture.md)
