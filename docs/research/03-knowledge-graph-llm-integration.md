# Knowledge Graph + LLM Integration

How to effectively combine knowledge graphs with Large Language Models for data entry and querying.

---

## Core Approaches

### 1. Microsoft GraphRAG

The pioneering approach for knowledge graph + RAG integration.

**How it works:**
1. LLM automatically extracts knowledge graph from documents
2. Detects "communities" of related nodes hierarchically
3. Pre-generates community summaries
4. Query modes:
   - **Global Search**: Holistic questions using community summaries
   - **Local Search**: Entity-specific queries via neighbor traversal
   - **DRIFT Search**: Combines both approaches

**GitHub**: [microsoft/graphrag](https://github.com/microsoft/graphrag)

**For Home LM**: GraphRAG's community detection could help answer questions like "What are all the issues we've had with the plumbing system?" by aggregating related entities.

### 2. Neo4j + LLM Graph Builder

Transforms unstructured data into knowledge graphs using multiple LLM backends.

**Capabilities:**
- Supports PDFs, documents, images, web pages
- Creates lexical graph (documents + chunks) AND entity graph
- Multiple RAG approaches: GraphRAG, Vector, Text2Cypher
- Works with OpenAI, Claude, Llama3, Qwen via Ollama

**GitHub**: [neo4j-labs/llm-graph-builder](https://github.com/neo4j-labs/llm-graph-builder)

### 3. LlamaIndex Knowledge Graph RAG

Two main modes:
1. **Build KG from documents**: `KnowledgeGraphIndex`
2. **Query existing KG**: `KnowledgeGraphRAGQueryEngine`

The `GraphRAGExtractor` extracts (subject, relation, object) triples with metadata.

---

## Entity Extraction Approaches

### LLM-Based (Higher Quality, Slower)

| Model | Size | Quality | Notes |
|-------|------|---------|-------|
| Llama 3.1 70B+ | Large | Excellent | Best for complex extraction |
| Mistral 7B | Small | Good | Requires text chunking |
| Qwen 2.5 | Medium | Good | Strong at structured output |

**Local setup with Ollama:**
```bash
ollama pull llama3.2
ollama pull mistral
```

### Non-LLM (Faster, Cheaper)

**GLiNER** - Generalist Model for Named Entity Recognition
- Lightweight, no API calls needed
- Outperforms ChatGPT in zero-shot NER benchmarks
- [spaCy wrapper available](https://github.com/theirstory/gliner-spacy)

```bash
pip install gliner-spacy
```

**ReLiK** - Retrieve and LinK (ACL 2024)
- State-of-the-art Entity Linking + Relation Extraction
- **40x faster** than competitors
- Single forward pass

**Recommendation for Home LM**:
- Use GLiNER for fast entity detection (AREA, ASSET, PERSON, PROJECT)
- Use local LLM (Mistral 7B) for relation extraction and disambiguation

---

## Entity Extraction Pipeline

### Step 1: Parse Input Text

```
User input: "Contractor Bob fixed the dishwasher in the kitchen yesterday"
```

### Step 2: Entity Detection (GLiNER)

```python
from gliner import GLiNER

model = GLiNER.from_pretrained("urchade/gliner_large-v2.1")
entities = model.predict_entities(
    text,
    labels=["PERSON", "ASSET", "AREA", "DATE"]
)
# Result: [
#   ("Contractor Bob", "PERSON"),
#   ("dishwasher", "ASSET"),
#   ("kitchen", "AREA"),
#   ("yesterday", "DATE")
# ]
```

### Step 3: Entity Resolution (Match to Existing)

```python
# Check if entities match existing pages
existing_people = get_pages_by_type("PERSON")
# ["PERSON/Bob Smith", "PERSON/Bob Contractor", "PERSON/Alice"]

# Fuzzy match "Contractor Bob" -> "PERSON/Bob Contractor"
matched_entity = fuzzy_match("Contractor Bob", existing_people)
```

### Step 4: Link Suggestion

```
Suggested entry:
[[PERSON/Bob Contractor]] fixed the [[ASSET/Kitchen Dishwasher]]
in the [[AREA/Kitchen]] on [[2026-01-08]].

[Accept] [Edit] [Create new entities]
```

---

## Semantic Search Architecture

### Vector Embeddings

Store embeddings for all blocks using pgvector:

```sql
-- Add embedding column
ALTER TABLE blocks ADD COLUMN embedding vector(1536);

-- Create index for fast similarity search
CREATE INDEX ON blocks USING ivfflat (embedding vector_cosine_ops);
```

### Embedding Generation

```python
import ollama

def generate_embedding(text: str) -> list[float]:
    response = ollama.embeddings(
        model='nomic-embed-text',
        prompt=text
    )
    return response['embedding']
```

### Query Flow

1. User asks: "What problems have we had with the hot tub?"
2. Generate query embedding
3. Find similar blocks via pgvector
4. Also traverse graph for [[ASSET/Hot Tub]] references
5. Combine and rank results
6. Feed to LLM for natural language response

```python
# Hybrid search: semantic + graph traversal
semantic_results = vector_search(query_embedding, limit=10)
graph_results = get_blocks_referencing("ASSET/Hot Tub")
combined = merge_and_rank(semantic_results, graph_results)
```

---

## Natural Language Querying

### Text2Cypher (for Graph Databases)

Convert natural language to Cypher queries:

```
User: "Which contractors have worked on plumbing?"

Generated Cypher:
MATCH (p:PERSON)-[:WORKED_ON]->(proj:PROJECT)
WHERE proj.category = 'plumbing'
RETURN p.name, proj.name
```

**Limitations:**
- Struggles with complex syntax
- Needs schema context in prompt
- Best with large models (GPT-4, Claude, Llama 70B+)

### RAG Approach (Recommended for Home LM)

Instead of generating queries, use RAG:

1. **Retrieve**: Find relevant blocks via semantic + graph search
2. **Augment**: Add retrieved context to LLM prompt
3. **Generate**: LLM produces natural language answer

```python
def answer_question(question: str) -> str:
    # Retrieve relevant context
    context = hybrid_search(question)

    # Generate answer
    prompt = f"""Based on the following house knowledge base entries:

{context}

Answer this question: {question}

If the information isn't in the knowledge base, say so."""

    return ollama.generate(model='llama3.2', prompt=prompt)
```

---

## Voice-to-Knowledge-Graph

### WhisperNER (September 2024)

Joint speech transcription + entity recognition:
- 20% improvement in entity accuracy vs pipeline
- Zero-shot learning for new entity types

**GitHub**: [aiola-lab/whisper-ner](https://github.com/aiola-lab/whisper-ner)

### Recommended Pipeline

```
Audio Input
    ↓
faster-whisper (speech-to-text)
    ↓
GLiNER (entity extraction)
    ↓
Entity Resolution (match existing)
    ↓
LLM (disambiguation, relation extraction)
    ↓
Knowledge Graph Update
```

---

## Recommended Open Source Projects

| Project | Purpose | GitHub |
|---------|---------|--------|
| **Microsoft GraphRAG** | Graph-based RAG | [microsoft/graphrag](https://github.com/microsoft/graphrag) |
| **Cognee** | Memory layer for AI | [topoteretes/cognee](https://github.com/topoteretes/cognee) |
| **Neo4j LLM Graph Builder** | Document → Graph | [neo4j-labs/llm-graph-builder](https://github.com/neo4j-labs/llm-graph-builder) |
| **iText2KG** | Handles LLM hallucination | [AuvaLab/itext2kg](https://github.com/AuvaLab/itext2kg) |
| **Reor** | Local AI PKM | [reorproject/reor](https://github.com/reorproject/reor) |
| **graphrag-local-ollama** | GraphRAG with Ollama | [TheAiSingularity/graphrag-local-ollama](https://github.com/TheAiSingularity/graphrag-local-ollama) |

---

## Home LM Implementation Plan

### Phase 1: Basic Entity Extraction

1. Set up GLiNER for entity detection
2. Define entity types: AREA, ASSET, PERSON, PROJECT, TASK
3. Build entity resolution (fuzzy matching to existing pages)
4. Suggest wiki-links in real-time as user types

### Phase 2: Semantic Search

1. Generate embeddings with Ollama (nomic-embed-text)
2. Store in pgvector
3. Implement hybrid search (semantic + graph)
4. Build simple query interface

### Phase 3: Natural Language Q&A

1. Implement RAG pipeline with local LLM
2. Graph traversal for entity-specific queries
3. Conversational interface for follow-up questions

### Phase 4: Advanced GraphRAG

1. Implement community detection
2. Generate and store community summaries
3. Enable global reasoning across entire knowledge base

---

## Sources

- Microsoft GraphRAG: https://github.com/microsoft/graphrag
- GraphRAG Paper: https://arxiv.org/abs/2404.16130
- Neo4j LLM Graph Builder: https://neo4j.com/labs/genai-ecosystem/llm-graph-builder/
- GLiNER: https://github.com/urchade/GLiNER
- ReLiK: https://github.com/SapienzaNLP/relik
- WhisperNER: https://github.com/aiola-lab/whisper-ner
- Cognee: https://github.com/topoteretes/cognee
