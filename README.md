# ai-journal

A persistent knowledge system for AI coding assistants and the humans who work with them.

## The Problem

When you're deep in a debugging session with an AI assistant and hit a wall, you often have to clear the conversation and start over. By then you're tired, the context is gone, and you can't quite describe what you were stuck on. The AI starts from scratch every time.

**ai-journal** fixes this. It's a structured, file-based journal that AI assistants write to during conversations - capturing sessions, decisions, insights, and most importantly, **stuck points** - so the next conversation can pick up where the last one left off.

## How It Works

- **Plain markdown files** with YAML frontmatter. No database, no server. Files ARE the interface.
- **A single-file CLI** (`journal`) for browsing, searching, and creating entries.
- **AI-writable**: Assistants like Claude Code can read/write entries directly as files.
- **Human-browsable**: Open the files in any editor, or use the CLI for quick lookups.

## Entry Types

| | |
|---|---|
| **session** | What happened in a conversation - progress, findings, where we left off |
| **decision** | A choice that was made, alternatives considered, and why |
| **insight** | Something learned about the codebase or project |
| **stuck** | A problem we couldn't solve - symptoms, attempts, remaining hypotheses |

The **stuck** entry is the key innovation. When you hit a wall, the AI writes down everything it knows about the problem *before* you clear context. Next session, it reads those stuck points first.

## Quick Start

```bash
# Clone and set up
git clone https://github.com/tab0r/ai-journal.git ~/Code/ai-journal
ln -s ~/Code/ai-journal/journal ~/.local/bin/journal

# See what's going on
journal status myproject
journal list myproject --type stuck

# Search across everything
journal search "race condition"

# Create a new entry
journal new session myproject
```

## File Structure

```
data/
└── projects/
    └── my-project/
        ├── overview.md
        ├── sessions/
        │   └── 2026-03-13-debugging-auth.md
        ├── decisions/
        │   └── 2026-03-13-chose-jwt.md
        ├── insights/
        │   └── connection-pool-limit.md
        └── stuck/
            └── 2026-03-13-race-condition.md
```

Your actual journal data lives in `data/` which is gitignored - the repo only contains the tool itself.

## Entry Format

```markdown
---
type: stuck
title: Race condition in background worker
project: tapedeck
created: 2026-03-13T22:15:00
summary: Workers grab the same job simultaneously. Advisory locks don't help due to connection pool rotation.
tags: [concurrency, worker, postgres]
scope: private
status: open
---

## What we were trying to do
...

## Symptoms
...

## What we tried
...

## Remaining hypotheses
...
```

## Future Plans

- Export to Standard Notes
- Knowledge graph visualization
- Cross-project pattern detection

## License

MIT
