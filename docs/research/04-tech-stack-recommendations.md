# Technology Stack Recommendations

Recommended stack for building Home LM as a self-hosted, LAN-accessible knowledge management system.

---

## Recommended Stack

| Layer | Choice | Rationale |
|-------|--------|-----------|
| **Web Framework** | SvelteKit | Smaller bundles, faster TtI, native WebSockets |
| **Database** | PostgreSQL + pgvector | Unified blocks + vectors + FTS in one DB |
| **Local LLM** | Ollama | Easy model management, OpenAI-compatible API |
| **Entity Extraction** | GLiNER | Fast, local, no LLM calls needed |
| **Real-time** | PostgreSQL LISTEN/NOTIFY + WebSockets | No additional infrastructure |
| **Deployment** | Docker + Caddy | Simple LAN hosting with auto-HTTPS |

---

## Web Framework: SvelteKit

### Why SvelteKit over Next.js

| Aspect | SvelteKit | Next.js |
|--------|-----------|---------|
| **Bundle Size** | 20-40 KB | ~70 KB |
| **Runtime** | Direct DOM, no vDOM | React vDOM overhead |
| **Learning Curve** | Standard HTML/CSS/JS | Requires React expertise |
| **Real-time** | Native WebSocket support | Requires Socket.IO or similar |

**For Home LM**:
- Content-heavy pages (daily notes, block lists) benefit from smaller bundles
- Real-time updates for live graph view
- Solo developer can move faster without deep React knowledge

### When to use Next.js instead

- Existing React expertise
- Need React component ecosystem (rich text editors, etc.)
- Team prefers React patterns

---

## Database: PostgreSQL + pgvector

### Why PostgreSQL over SQLite

| Aspect | PostgreSQL | SQLite |
|--------|------------|--------|
| **Concurrent writes** | Excellent | Limited (single writer) |
| **Full-text search** | Advanced (GIN, GiST) | FTS5 (good but simpler) |
| **Vector search** | pgvector (integrated) | Requires separate DB |
| **Scalability** | Horizontal possible | Vertical only |

**For Home LM**:
- pgvector query: ~2.5ms (vs ChromaDB's 4.5ms)
- Single database for blocks + embeddings + search
- LISTEN/NOTIFY enables real-time updates

### Schema Design

```sql
-- Core blocks table
CREATE TABLE blocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id UUID REFERENCES blocks(id),
  page_id UUID REFERENCES blocks(id),
  content TEXT,
  name TEXT,  -- For pages only
  entity_type TEXT,  -- AREA, ASSET, PERSON, etc.
  is_journal BOOLEAN DEFAULT FALSE,
  journal_date DATE,
  properties JSONB DEFAULT '{}',
  embedding vector(1536),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_blocks_page ON blocks(page_id);
CREATE INDEX idx_blocks_parent ON blocks(parent_id);
CREATE INDEX idx_blocks_entity ON blocks(entity_type) WHERE entity_type IS NOT NULL;
CREATE INDEX idx_blocks_journal ON blocks(journal_date) WHERE is_journal;
CREATE INDEX idx_blocks_fts ON blocks USING GIN(to_tsvector('english', content));
CREATE INDEX idx_blocks_vector ON blocks USING ivfflat(embedding vector_cosine_ops);

-- References table for wiki-links
CREATE TABLE refs (
  source_id UUID REFERENCES blocks(id) ON DELETE CASCADE,
  target_id UUID REFERENCES blocks(id) ON DELETE CASCADE,
  PRIMARY KEY (source_id, target_id)
);
CREATE INDEX idx_refs_target ON refs(target_id);
```

### Alternative: SQLite + ChromaDB (Simpler)

For prototyping or single-user:

```
SQLite (blocks, refs) + ChromaDB (embeddings)
```

**Pros**: Simpler setup, no server process
**Cons**: Two databases to sync, ChromaDB 2x slower

---

## Local LLM: Ollama

### Why Ollama

- **Ease of use**: `ollama pull llama3.2` and you're running
- **Model switching**: Change models without server restart
- **OpenAI-compatible API**: Easy to swap for cloud if needed
- **Good enough**: 1-3 req/sec sufficient for single-user

### Recommended Models

| Use Case | Model | Size | Notes |
|----------|-------|------|-------|
| **Embeddings** | nomic-embed-text | 274MB | Fast, good quality |
| **Chat/RAG** | llama3.2 | 2GB | Best balance |
| **Entity extraction** | mistral | 4GB | Good at structured output |
| **Code assistance** | deepseek-coder | 1.3GB | If you want code help |

### When to use alternatives

| Scenario | Alternative | Why |
|----------|-------------|-----|
| Limited VRAM | llama.cpp | Better CPU/GPU mixed inference |
| Multi-user production | vLLM | 35x higher throughput |
| Maximum control | llama.cpp | Pure C++, no dependencies |

---

## Entity Extraction: GLiNER

### Why GLiNER over LLM-based extraction

| Aspect | GLiNER | LLM (Mistral 7B) |
|--------|--------|------------------|
| **Speed** | ~50ms | ~500-2000ms |
| **Cost** | Free (local) | GPU/CPU time |
| **Accuracy** | Excellent for NER | Better for relations |
| **Zero-shot** | Yes | Yes |

### Usage

```python
from gliner import GLiNER

model = GLiNER.from_pretrained("urchade/gliner_large-v2.1")

# Define your entity types
labels = ["AREA", "ASSET", "PERSON", "PROJECT", "DATE"]

# Extract from user input
entities = model.predict_entities(
    "Bob the contractor fixed the dishwasher in the kitchen",
    labels
)
# [("Bob the contractor", "PERSON"), ("dishwasher", "ASSET"), ("kitchen", "AREA")]
```

### Hybrid Approach (Recommended)

1. **GLiNER** for fast entity detection (real-time as user types)
2. **LLM** for disambiguation and relation extraction (on save)

---

## Real-time: PostgreSQL LISTEN/NOTIFY

### How it works

```sql
-- When a block is updated
CREATE OR REPLACE FUNCTION notify_block_change()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM pg_notify('block_changes', json_build_object(
    'action', TG_OP,
    'id', NEW.id
  )::text);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER block_change_trigger
AFTER INSERT OR UPDATE ON blocks
FOR EACH ROW EXECUTE FUNCTION notify_block_change();
```

### SvelteKit WebSocket handler

```typescript
// src/hooks.server.ts
import { Client } from 'pg';

export const handle = async ({ event, resolve }) => {
  const client = new Client(DATABASE_URL);
  await client.connect();
  await client.query('LISTEN block_changes');

  client.on('notification', (msg) => {
    // Broadcast to connected WebSocket clients
    broadcastToClients(JSON.parse(msg.payload));
  });

  return resolve(event);
};
```

---

## Deployment: Docker + Caddy

### docker-compose.yml

```yaml
version: '3.8'

services:
  app:
    build: .
    environment:
      DATABASE_URL: postgres://homelm:password@postgres/homelm
      OLLAMA_HOST: http://ollama:11434
    depends_on:
      - postgres
      - ollama
    ports:
      - "3000:3000"

  postgres:
    image: pgvector/pgvector:pg16
    environment:
      POSTGRES_DB: homelm
      POSTGRES_USER: homelm
      POSTGRES_PASSWORD: password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  ollama:
    image: ollama/ollama
    volumes:
      - ollama_data:/root/.ollama
    deploy:
      resources:
        reservations:
          devices:
            - capabilities: [gpu]
    ports:
      - "11434:11434"

  caddy:
    image: caddy:2
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data

volumes:
  postgres_data:
  ollama_data:
  caddy_data:
```

### Caddyfile (for LAN access)

```
homelm.local {
    reverse_proxy app:3000
    tls internal  # Self-signed for LAN
}
```

### LAN DNS Setup

Option 1: Pi-hole or local DNS
```
homelm.local -> 192.168.1.100
```

Option 2: Edit /etc/hosts on each device
```
192.168.1.100 homelm.local
```

---

## Development Workflow

### Phase 1: Local Development

```bash
# Start PostgreSQL + Ollama with Docker
docker compose up postgres ollama -d

# Run SvelteKit in dev mode
npm run dev
```

### Phase 2: Testing Production Build

```bash
# Full stack
docker compose up -d

# Access at http://localhost:3000
```

### Phase 3: Deploy to LAN Server

```bash
# On your server (Mac Mini, NUC, etc.)
git clone <repo>
docker compose up -d

# Access at http://homelm.local
```

---

## Hardware Recommendations

### Minimum (Raspberry Pi 4 8GB)

- Works for single user
- Slower LLM inference
- May need external GPU for good performance

### Recommended (Mini PC)

| Component | Spec |
|-----------|------|
| CPU | Intel N100 or better |
| RAM | 16GB |
| Storage | 256GB SSD |
| GPU | Optional (CPU inference OK for small models) |

**Examples**: Beelink Mini S12, Intel NUC

### Ideal (With GPU)

| Component | Spec |
|-----------|------|
| CPU | Any modern |
| RAM | 32GB |
| GPU | RTX 3060 12GB or better |
| Storage | 512GB SSD |

Enables larger models (Llama 70B) and faster inference.

---

## Cost Estimates

| Setup | Hardware | Notes |
|-------|----------|-------|
| **Minimal** | $0 | Use existing Mac |
| **Dedicated Mini PC** | $200-400 | Beelink/NUC |
| **With GPU** | $500-1000 | Used RTX 3060 |
| **Full Setup** | $400-600 | Mini PC + voice hardware |

---

## Next Steps

1. **Clone repo, run `docker compose up`**
2. **Start with PostgreSQL + basic SvelteKit UI**
3. **Add Ollama for embeddings**
4. **Implement entity extraction with GLiNER**
5. **Build the daily note interface**
6. **Add real-time updates**
7. **Deploy to LAN server**

---

## Sources

- SvelteKit vs Next.js: https://betterstack.com/community/guides/scaling-nodejs/sveltekit-vs-nextjs/
- PostgreSQL vs SQLite: https://betterstack.com/community/guides/databases/postgresql-vs-sqlite/
- Ollama vs alternatives: https://www.houseoffoss.com/post/ollama-vs-llama-cpp-vs-vllm-local-llm-deployment-in-2025
- pgvector benchmarks: https://liveblocks.io/blog/whats-the-best-vector-database-for-building-ai-products
- Caddy reverse proxy: https://www.virtualizationhowto.com/2025/09/caddy-reverse-proxy-in-2025
