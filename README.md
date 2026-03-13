# ai-journal

Shared memory between two minds.

## What This Is

When you work closely with an AI, you build up context together - ideas, decisions, dead ends, breakthroughs. Then the conversation ends, and it's all gone. Next time you start from zero.

**ai-journal** is persistent memory that both of you can read and write. It's not a chat log. It's a structured, browsable record of what you've thought about together - organized by topic, searchable, and designed to survive the gaps between conversations.

It works for code. It works for everything else too.

## How It Works

- **Plain markdown files** with YAML frontmatter. No database, no server. Files ARE the interface.
- **A single-file CLI** (`journal`) for browsing, searching, and creating entries.
- **AI-writable**: Your AI assistant reads and writes entries directly as files.
- **Human-browsable**: Open them in any editor, browse on GitHub, or use the CLI.
- **Scoped and scrubable**: Tag entries by sensitivity. Scrub what needs to go, keep the lessons.

## Entry Types

| | |
|---|---|
| **session** | What happened in a conversation - progress, findings, where we left off |
| **decision** | A choice that was made, alternatives considered, and why |
| **insight** | Something learned - about code, a problem, an idea, anything |
| **stuck** | Something unresolved - what's happening, what's been tried, what might work |
| **note** | Freeform - thoughts, references, anything that doesn't fit the above |

The **stuck** entry is the key innovation. When you hit a wall and need to walk away, the AI writes down everything it knows about the problem *before* context is lost. Next session, it reads those stuck points first.

## Quick Start

```bash
# Clone and set up
git clone https://github.com/tab0r/ai-journal.git ~/Code/ai-journal
ln -s ~/Code/ai-journal/journal ~/.local/bin/journal

# See what's going on
journal status myproject

# Search across everything
journal search "threshold"

# Create entries
journal new session myproject -t "Brainstorming session"
journal new note myproject -t "Random thought about X"

# Import a file
journal import ~/Documents/research-paper.pdf myproject --summary "Key reference for the approach we're taking"

# Scrub sensitive entries when needed (keeps conclusions, strips details)
journal scrub work-internal
```

## File Structure

```
data/
└── projects/
    └── my-project/
        ├── overview.md
        ├── sessions/
        ├── decisions/
        ├── insights/
        ├── stucks/
        ├── notes/
        └── attachments/
```

Your journal data lives in `data/` which is gitignored. The repo contains only the tool.

## Entry Format

```markdown
---
type: stuck
title: Can't figure out the right framing for this essay
project: writing
created: 2026-03-13T22:15:00
summary: The introduction promises something the conclusion doesn't deliver. Tried three restructurings.
tags: [writing, structure, essays]
scope: private
status: open
---

## What we were trying to do
...

## What's happening
...

## What we tried
...

## Remaining ideas
...
```

## Scrubbing and Privacy

Entries have a `scope` field (default: `private`). When you need to remove entries of a given scope:

```bash
journal scrub work-internal         # tombstones: keeps conclusions, strips details
journal scrub personal --no-tombstones  # full delete, no trace
```

Scrubbing works like human memory - you forget the painful debugging session, but you remember "don't use advisory locks with connection pools." The lesson survives even when the experience doesn't.

## Export and Extract

Pull entries into a focused sub-journal:

```bash
journal export --topic writing --to ~/writing-journal    # copy
journal extract --scope old-job --to ~/backup            # move (scrubs originals)
```

## Claude Code Integration

A `SessionStart` hook (`journal-hook`) automatically loads relevant journal context when a conversation begins. The AI sees open stuck points, recent sessions, and key decisions without being asked.

## Future Plans

- Export to Standard Notes
- Knowledge graph visualization
- Cross-project pattern detection

## License

MIT
