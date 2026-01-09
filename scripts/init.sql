-- Home LM Database Schema
-- PostgreSQL with pgvector extension

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS vector;

-- Entity types enum
CREATE TYPE entity_type AS ENUM (
  'AREA',      -- Rooms, closets, yards
  'ASSET',     -- Appliances, tools, furniture
  'PERSON',    -- Family, contractors, neighbors
  'PROJECT',   -- Multi-task initiatives
  'TASK',      -- Individual to-dos
  'NOTE'       -- Ideas, goals, observations
);

-- Core blocks table (pages and blocks unified)
CREATE TABLE blocks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  -- Hierarchy
  parent_id UUID REFERENCES blocks(id) ON DELETE CASCADE,
  page_id UUID REFERENCES blocks(id) ON DELETE CASCADE,
  position INTEGER DEFAULT 0,

  -- Content
  content TEXT,
  name TEXT,  -- Only for pages (e.g., "ASSET/Dyson Vacuum")

  -- Entity metadata
  entity_type entity_type,
  properties JSONB DEFAULT '{}',

  -- Journal (daily notes)
  is_journal BOOLEAN DEFAULT FALSE,
  journal_date DATE,

  -- AI features
  embedding vector(1536),  -- For semantic search

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- References table (wiki-links)
CREATE TABLE refs (
  source_id UUID REFERENCES blocks(id) ON DELETE CASCADE,
  target_id UUID REFERENCES blocks(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (source_id, target_id)
);

-- Indexes for common queries
CREATE INDEX idx_blocks_page ON blocks(page_id);
CREATE INDEX idx_blocks_parent ON blocks(parent_id);
CREATE INDEX idx_blocks_entity ON blocks(entity_type) WHERE entity_type IS NOT NULL;
CREATE INDEX idx_blocks_journal ON blocks(journal_date) WHERE is_journal;
CREATE INDEX idx_blocks_name ON blocks(name) WHERE name IS NOT NULL;

-- Full-text search
CREATE INDEX idx_blocks_fts ON blocks USING GIN(to_tsvector('english', content));

-- Vector similarity search (for semantic queries)
CREATE INDEX idx_blocks_vector ON blocks USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);

-- Backlinks index
CREATE INDEX idx_refs_target ON refs(target_id);

-- Updated at trigger
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER blocks_updated_at
  BEFORE UPDATE ON blocks
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

-- Real-time notifications for block changes
CREATE OR REPLACE FUNCTION notify_block_change()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM pg_notify('block_changes', json_build_object(
    'action', TG_OP,
    'id', COALESCE(NEW.id, OLD.id),
    'page_id', COALESCE(NEW.page_id, OLD.page_id)
  )::text);
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER blocks_notify
  AFTER INSERT OR UPDATE OR DELETE ON blocks
  FOR EACH ROW
  EXECUTE FUNCTION notify_block_change();

-- Helper function: Get all backlinks for a page
CREATE OR REPLACE FUNCTION get_backlinks(target_name TEXT)
RETURNS TABLE (
  block_id UUID,
  content TEXT,
  page_name TEXT,
  journal_date DATE
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    b.id,
    b.content,
    p.name,
    p.journal_date
  FROM refs r
  JOIN blocks t ON r.target_id = t.id
  JOIN blocks b ON r.source_id = b.id
  JOIN blocks p ON b.page_id = p.id
  WHERE t.name = target_name
  ORDER BY p.journal_date DESC NULLS LAST, b.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Helper function: Semantic search
CREATE OR REPLACE FUNCTION semantic_search(
  query_embedding vector(1536),
  match_count INTEGER DEFAULT 10,
  match_threshold FLOAT DEFAULT 0.7
)
RETURNS TABLE (
  id UUID,
  content TEXT,
  page_name TEXT,
  similarity FLOAT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    b.id,
    b.content,
    p.name,
    1 - (b.embedding <=> query_embedding) as similarity
  FROM blocks b
  LEFT JOIN blocks p ON b.page_id = p.id
  WHERE b.embedding IS NOT NULL
    AND 1 - (b.embedding <=> query_embedding) > match_threshold
  ORDER BY b.embedding <=> query_embedding
  LIMIT match_count;
END;
$$ LANGUAGE plpgsql;

-- Sample data: Create today's daily note
INSERT INTO blocks (name, is_journal, journal_date, content)
VALUES (
  to_char(CURRENT_DATE, 'YYYY-MM-DD'),
  TRUE,
  CURRENT_DATE,
  'Welcome to Home LM! Start logging your house knowledge here.'
);
