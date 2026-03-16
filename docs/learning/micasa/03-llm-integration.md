# Module 3: LLM Integration

**Time**: ~60 minutes
**Goal**: Understand the NL→SQL pipeline, prompt engineering, and multi-provider abstraction

---

## Exercise 3.1: Set Up Ollama

```bash
# Install Ollama (if not already installed)
curl -fsSL https://ollama.com/install.sh | sh

# Pull a model (qwen3 is micasa's default)
ollama pull qwen3

# Verify it's running
ollama list
```

---

## Exercise 3.2: Try Natural Language Queries

Launch micasa and press `@` to open the chat overlay:

```
Try these queries:
1. "What appliances do I have?"
2. "Which maintenance items are overdue?"
3. "How much have I spent on plumbing?"
4. "Show me all incidents from last year"
5. "What's the total cost of all projects?"
```

**Toggle SQL visibility** with `/sql` to see the generated SQL for each query.

**Observe**:
- Does the generated SQL look correct?
- How does it handle temporal queries ("last year", "overdue")?
- What happens when a query fails?

---

## Exercise 3.3: Study the Prompt Pipeline

```bash
# Read the prompt construction code
cat internal/llm/prompt.go
```

**Trace the two-stage pipeline**:

### Stage 1: `BuildSQLPrompt()`

Identify these components in the prompt:
1. **Date context** — `dateContext()` provides current date for temporal reasoning
2. **Schema DDL** — Full CREATE TABLE statements from `sqlite_master`
3. **Entity relationships** — FK descriptions in natural language
4. **Column hints** — Distinct values from key columns
5. **Few-shot examples** — Question→SQL pairs
6. **Cost semantics** — How does it distinguish quotes vs. actual costs vs. maintenance costs?

**Question**: Why does the prompt include column hints (distinct values)? What problem does this solve?

### Stage 2: `BuildSummaryPrompt()`

1. What inputs does it receive?
2. How are results formatted? (pipe-delimited vs. JSON — why?)
3. What instructions does it give the LLM for summarization?

### Fallback: `BuildSystemPrompt()`

1. When is this used?
2. What data does it include?
3. Why is this less reliable than the two-stage pipeline?

---

## Exercise 3.4: Study the Multi-Provider Client

```bash
cat internal/llm/client.go
```

**Key patterns**:

1. **Provider abstraction** — How does `any-llm-go` unify 10 different LLM APIs?
2. **Streaming** — Find `ChatStream()`. How does it return results? (channel of `StreamChunk`)
3. **Error handling** — Find `wrapError()`. How does it convert API errors to actionable messages?
4. **Provider detection** — Find `detectProvider()`. How does it infer the provider from a URL?
5. **Local vs. cloud** — How does it distinguish local (Ollama) from cloud (Anthropic) providers?

**Exercise**: Trace the flow for a chat query:
```
User types question
  → chat.go handles input
    → BuildSQLPrompt() constructs the prompt
      → ChatStream() calls the LLM
        → Response streamed back as chunks
          → SQL extracted via ExtractSQL()
            → ReadOnlyQuery() executes with 5-layer validation
              → BuildSummaryPrompt() constructs summary prompt
                → ChatStream() again for natural language answer
                  → Response displayed in chat overlay
```

---

## Exercise 3.5: SQL Extraction and Validation

```bash
# Study how SQL is extracted from LLM output
grep -n "ExtractSQL\|ReadOnlyQuery\|validateQuery" internal/llm/prompt.go internal/data/query.go
```

**Questions**:
1. How does `ExtractSQL()` handle markdown code fences in LLM output?
2. How does it handle trailing semicolons?
3. What happens if the LLM outputs multiple SQL statements?
4. Walk through each of the 5 validation layers in `ReadOnlyQuery()`:
   - What does EXPLAIN opcode inspection actually check?
   - Why is there a 200-row result cap?

---

## Exercise 3.6: Test with Different Models

```bash
# Pull a few models to compare
ollama pull llama3.2
ollama pull mistral
ollama pull codellama
```

In the chat overlay, use `/model` to switch models. Try the same queries with each:

**Compare**:
- Which model generates the most accurate SQL?
- Which handles temporal queries best?
- Which gives the best natural language summaries?
- How do response times compare?

---

## Exercise 3.7: Study the Slash Commands

In the chat overlay, try:
- `/models` — List available models
- `/model <name>` — Switch model (supports fuzzy matching)
- `/sql` — Toggle SQL visibility
- `/help` — Show help

```bash
# Find the implementation
grep -n "handleSlashCommand\|slashCommand" internal/app/chat.go
```

**Question**: How does model fuzzy matching work? How does it show local vs. remote indicators?

---

## Exercise 3.8: Map to Home LM

**Reflection**:

1. **NL→SQL vs. RAG**: micasa generates SQL against structured tables. Home LM uses RAG over knowledge graph embeddings. When would each approach be better?

2. **Prompt engineering**: micasa's prompts include full DDL and few-shot examples. How would you construct equivalent prompts for Home LM's block-based schema?

3. **Streaming**: micasa bridges Go channels with Bubble Tea. Home LM would use Server-Sent Events or WebSocket. What's the equivalent architecture?

4. **Multi-provider**: micasa uses `any-llm-go`. Home LM uses Ollama directly. Should Home LM also support multiple providers?

5. **Hybrid approach**: Could Home LM offer **both** RAG (for freeform queries like "What problems have we had with the hot tub?") and NL→SQL (for structured queries like "Total maintenance costs this year")?

---

## Checkpoint

- [ ] Can you explain the two-stage NL→SQL pipeline?
- [ ] Do you understand how prompts are constructed?
- [ ] Can you trace a query from user input to displayed answer?
- [ ] Do you understand the 5-layer SQL validation?
- [ ] Can you articulate when NL→SQL is better than RAG (and vice versa)?

---

Next: [Module 4: Document Extraction →](./04-document-extraction.md)
