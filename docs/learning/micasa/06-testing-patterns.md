# Module 6: Testing Patterns

**Time**: ~30 minutes
**Goal**: Understand micasa's testing philosophy, the template database pattern, and how to apply these to a web project

---

## Exercise 6.1: Run the Test Suite

```bash
cd micasa

# Run all tests with shuffled execution
go test -shuffle=on ./...

# Run with verbose output for a specific package
go test -v -shuffle=on ./internal/data/...

# Run with a specific seed for reproducibility
MICASA_TEST_SEED=12345 go test -shuffle=on ./...
```

**Observe**:
- How long does the suite take?
- Are there any skipped tests? Why?
- What seed is logged to stderr?

---

## Exercise 6.2: The Template Database Pattern

This is micasa's key testing optimization. Find it:

```bash
# Look for TestMain in test files
grep -rn "TestMain" internal/data/ internal/app/
```

**The pattern**:

```go
// In TestMain (runs once before all tests):
func TestMain(m *testing.M) {
    // 1. Create a fresh SQLite database
    // 2. Run all migrations
    // 3. Seed with test data
    // 4. Serialize to bytes (templateBytes)
    // This takes ~150ms

    os.Exit(m.Run())
}

// In each test:
func TestSomething(t *testing.T) {
    // Copy from templateBytes (~1ms)
    // instead of re-migrating (~150ms)
    store := newTestStore(t)
    // ... test against real SQLite
}
```

**Why this matters**: With ~100+ tests, the difference between 150ms and 1ms per test setup adds up:
- Without template: 100 tests × 150ms = **15 seconds** just for setup
- With template: 100 tests × 1ms = **0.1 seconds**

**Web equivalent** (PostgreSQL):

```sql
-- Create template database once
CREATE DATABASE test_template;
-- Run migrations and seed

-- Per test: copy the template (~5ms vs ~500ms for migrate+seed)
CREATE DATABASE test_run_1 TEMPLATE test_template;
```

---

## Exercise 6.3: Test Factory Functions

```bash
# Find test setup functions
grep -n "newTestModel\|newTestStore\|newTestModelWithStore" internal/app/*_test.go internal/data/*_test.go | head -20
```

**Study `newTestModelWithStore()`**:
- Creates a temp directory with SQLite from template bytes
- Configures `data.Store` with currency, document limits
- Seeds a house profile
- Creates a `Model` with sensible viewport dimensions (120×40)

**Question**: Why does the test model use fixed viewport dimensions? (Hint: think about rendering assertions)

---

## Exercise 6.4: TUI Testing via Key Simulation

```bash
# Find key simulation tests
grep -rn "sendKey\|tea.KeyMsg" internal/app/*_test.go | head -20
```

micasa tests the TUI by **simulating actual keypresses**, not by calling internal APIs:

```go
// Example pattern (find the actual code):
func TestAddAppliance(t *testing.T) {
    m := newTestModel(t)
    // Navigate to appliances tab
    m = sendKey(m, tea.KeyMsg{Type: tea.KeyTab})
    // Press 'a' to add
    m = sendKey(m, tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'a'}})
    // Fill form fields...
    // Submit
    m = sendKey(m, tea.KeyMsg{Type: tea.KeyEnter})
    // Assert the new appliance exists
}
```

**Why this approach**: Testing through the UI layer catches bugs that unit testing internal functions would miss (state machine transitions, mode switching, overlay interactions).

**Web equivalent**: End-to-end testing with Playwright or Cypress:
```javascript
test('add appliance', async ({ page }) => {
  await page.click('[data-tab="appliances"]');
  await page.click('[data-action="add"]');
  await page.fill('[name="model"]', 'Dyson V15');
  await page.click('[type="submit"]');
  await expect(page.locator('text=Dyson V15')).toBeVisible();
});
```

---

## Exercise 6.5: Conditional Test Skipping

```bash
grep -rn "skipOrFatalCI" internal/ | head -10
```

**The pattern**:
- When external tools (tesseract, pdftotext) are absent **locally** → skip the test
- When absent **in CI** → fail the test

This prevents false negatives during local development while maintaining strictness in CI.

**Web equivalent**:
```javascript
const skipIfNoOllama = () => {
  if (!process.env.CI && !isOllamaRunning()) {
    return test.skip;
  }
};
```

---

## Exercise 6.6: LLM Client Testing

```bash
# Count test functions in the LLM client
grep -c "func Test" internal/llm/*_test.go
```

micasa has ~70 test functions for the LLM client alone, covering:

- **Initialization** — provider detection, URL validation, API key handling
- **Streaming** — chunk delivery, buffering, completion signals
- **Cancellation** — mid-stream cancellation handling
- **Errors** — timeout, auth failure, rate limiting, model not found
- **Network** — connection refused, mid-stream disconnection

**Key testing tools**:
- `synctest` — controlled async behavior
- `net.Pipe` — deterministic network simulation (no real HTTP)

**Question**: Why test with `net.Pipe` instead of a mock HTTP server? (Answer: deterministic timing, no port conflicts, tests run in parallel safely)

---

## Exercise 6.7: Design a Test Strategy for Home LM

Based on micasa's patterns, design a test strategy for Home LM:

| Layer | micasa Approach | Home LM Approach |
|-------|----------------|------------------|
| Database | Template SQLite bytes | PostgreSQL template databases |
| Data layer | Integration tests (real DB, no mocks) | Integration tests (real PostgreSQL) |
| UI | Key simulation (Bubble Tea) | Playwright/Cypress e2e tests |
| LLM client | `net.Pipe` + `synctest` | Mock HTTP server or recorded responses |
| Extraction | Conditional skip (local) / fail (CI) | Same pattern + Docker for dependencies |
| Entity CRUD | Per-handler test files | Per-endpoint test files |

**Principles to adopt**:
1. Test against real databases, not mocks
2. Use template databases for fast test setup
3. Test through the user interface where possible
4. Make external tool tests conditional locally, strict in CI
5. Use reproducible random seeds

---

## Checkpoint

- [ ] Can you explain the template database pattern and its performance benefit?
- [ ] Do you understand why TUI tests use key simulation instead of unit testing internals?
- [ ] Can you explain the conditional skip pattern?
- [ ] Can you design a test strategy for a web-based alternative?

---

Next: [Module 7: Architecture Comparison →](./07-architecture-comparison.md)
