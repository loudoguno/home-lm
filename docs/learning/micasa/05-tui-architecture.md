# Module 5: TUI Architecture

**Time**: ~45 minutes
**Goal**: Understand Bubble Tea's MVU pattern, the handler system, and how it maps to web architecture

---

## Exercise 5.1: Understand the Elm Architecture (MVU)

Bubble Tea implements the **Elm Architecture** (Model-View-Update):

```
     ┌──────────────────────────────────────────────┐
     │                                              │
     ▼                                              │
┌─────────┐    ┌──────────┐    ┌──────────┐        │
│  Model   │───▶│   View   │───▶│ Terminal │        │
│  (state) │    │ (render) │    │ (output) │        │
└─────────┘    └──────────┘    └──────────┘        │
     ▲                                              │
     │                                              │
┌──────────┐    ┌──────────┐    ┌──────────┐       │
│  Update  │◀───│ Message  │◀───│  Input   │───────┘
│ (reduce) │    │  (event) │    │ (keypress)│
└──────────┘    └──────────┘    └──────────┘
```

**Key concepts**:
- **Model**: Single source of truth (one big struct)
- **Update**: Pure function: `(Model, Msg) → (Model, Cmd)` — handles messages, returns new state
- **View**: Pure function: `Model → string` — renders the current state
- **Cmd**: Side effects (I/O, timers) that produce Messages

```bash
# Read the main model
head -100 internal/app/model.go
```

**Question**: How does this compare to React's state management? To Svelte's stores?

---

## Exercise 5.2: The Handler Pattern

```bash
cat internal/app/handlers.go
```

The `TabHandler` interface defines operations for each entity type:

```go
type TabHandler interface {
    Load()           // Fetch data for the tab
    Delete()         // Soft-delete selected item
    Restore()        // Undo last deletion
    StartAddForm()   // Open form for new item
    StartEditForm()  // Open form for editing
    InlineEdit()     // Quick single-field edit
    SubmitForm()     // Process form submission
    SyncFixedValues() // Update computed fields
}
```

**8 implementations**: project, quote, maintenance, appliance, incident, vendor, serviceLog, document.

**Exercise**: Pick one handler (e.g., appliance) and trace:
1. How does `Load()` fetch appliances with their relationships?
2. How does `StartAddForm()` construct the form fields?
3. How does `SubmitForm()` validate and save?
4. How does the `scopedHandler` wrapper work for detail-view sub-tables?

**Web equivalent**: This maps directly to API route handlers or service classes:

| TUI Handler | Web Equivalent |
|-------------|----------------|
| `TabHandler` interface | API controller interface / service interface |
| `Load()` | `GET /api/appliances` |
| `Delete()` | `DELETE /api/appliances/:id` |
| `StartAddForm()` | Form component schema |
| `SubmitForm()` | `POST /api/appliances` or `PUT /api/appliances/:id` |

---

## Exercise 5.3: Modes and Overlays

```bash
# Find the mode definitions
grep -n "type Mode\|Normal\|Edit\|Form" internal/app/model.go | head -20

# Find overlay types
grep -n "Overlay\|overlay" internal/app/model.go | head -30
```

**Three modes**: Normal (vim navigation), Edit (cell editing), Form (data entry)

**Nine overlays**: dashboard, calendar, notes, operations tree, column finder, document search, extraction status, chat, help

**Exercise**: Trace what happens when you press `@` (open chat):
1. How is the overlay activated?
2. How does `dispatchOverlay()` route messages to the chat overlay?
3. How does `hasActiveOverlay()` prevent background key handling?
4. How does the overlay render on top of the base view?

**Web equivalent**: Overlays map to modals/dialogs. The overlay dispatch maps to route-based rendering or portal-based modal management.

---

## Exercise 5.4: The Detail Drilldown Stack

```bash
grep -n "detailRoutes\|drilldown\|detail" internal/app/model.go | head -20
```

micasa supports navigation like: **Appliance → Maintenance → Service Log**

This works via a **stack**:
1. `detailRoutes` maps `(TabKind, columnTitle)` pairs to detail definitions
2. Opening a drilldown pushes onto the stack
3. Pressing Escape pops the stack

**Web equivalent**: This maps to nested URL routes:
- `/appliances/:id` → detail view
- `/appliances/:id/maintenance` → filtered maintenance list
- `/appliances/:id/maintenance/:mid/service-log` → service log entries

---

## Exercise 5.5: Styling System

```bash
cat internal/app/styles.go
```

**Key patterns**:
- `appStyles` singleton initialized via `DefaultStyles()`
- Wong colorblind-safe palette
- `lipgloss.AdaptiveColor` for light/dark terminal detection
- Semantic method names: `Error()`, `Money()`, `WarrantyExpired()`
- 39 consolidated styles (reduced from 93 by deduplication)

**Question**: Why is a colorblind-safe palette important for an accessibility-conscious app? What's the Wong palette?

**Web equivalent**: CSS custom properties with a semantic token system:
```css
:root {
  --color-error: ...;
  --color-money: ...;
  --color-warranty-expired: ...;
}
```

---

## Exercise 5.6: Streaming Bridge

```bash
grep -n "waitForStream" internal/app/chat.go
```

micasa bridges Go channels with Bubble Tea's message-passing:

```go
// Generic bridge: blocks on channel, wraps value as tea.Msg
func waitForStream[T any](ch <-chan T) tea.Cmd {
    return func() tea.Msg {
        val, ok := <-ch
        if !ok { return streamDone{} }
        return streamChunk[T]{val}
    }
}
```

**Web equivalent**: Server-Sent Events (SSE) or WebSocket:

```javascript
// SSE approach
const source = new EventSource('/api/chat/stream');
source.onmessage = (event) => {
  const chunk = JSON.parse(event.data);
  updateUI(chunk);
};
```

---

## Exercise 5.7: Architecture Mapping Summary

| micasa TUI | Web (SvelteKit) Equivalent |
|------------|---------------------------|
| Bubble Tea Model | Svelte stores / component state |
| Update function | Event handlers / actions |
| View function | Svelte components |
| tea.Cmd (side effects) | `load` functions / API calls |
| tea.Msg (events) | Custom events / store updates |
| TabHandler interface | API route handlers + service layer |
| Overlay stack | Modal/dialog components |
| Detail drilldown stack | Nested URL routes with breadcrumbs |
| `waitForStream` channel | Server-Sent Events / WebSocket |
| `lipgloss.AdaptiveColor` | CSS `prefers-color-scheme` |
| FTS5 search | PostgreSQL `to_tsvector` + GIN index |
| Key bindings | Keyboard shortcuts (Mousetrap.js or similar) |

---

## Checkpoint

- [ ] Can you explain the Model-View-Update architecture?
- [ ] Do you understand the handler-per-entity pattern?
- [ ] Can you trace a complete user interaction (keypress → state update → re-render)?
- [ ] Can you map each TUI pattern to its web equivalent?

---

Next: [Module 6: Testing Patterns →](./06-testing-patterns.md)
