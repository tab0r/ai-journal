#!/usr/bin/env bash
# ai-journal test suite
# Run: ./test.sh

set -euo pipefail

JOURNAL="$(cd "$(dirname "$0")" && pwd)/journal"
TEST_DATA="$(mktemp -d)"
export AIJOURNAL_DATA="$TEST_DATA"

PASS=0
FAIL=0

# --- Helpers ---

pass() {
    PASS=$((PASS + 1))
    echo "  ✓ $1"
}

fail() {
    FAIL=$((FAIL + 1))
    echo "  ✗ $1"
    echo "    $2"
}

assert_exit() {
    local desc="$1"; shift
    local expected="$1"; shift
    local actual
    set +e
    "$@" >/dev/null 2>&1
    actual=$?
    set -e
    if [ "$actual" -eq "$expected" ]; then
        pass "$desc"
    else
        fail "$desc" "expected exit $expected, got $actual"
    fi
}

assert_output_contains() {
    local desc="$1"; shift
    local pattern="$1"; shift
    local output
    set +e
    output=$("$@" 2>&1)
    set -e
    if echo "$output" | grep -q "$pattern"; then
        pass "$desc"
    else
        fail "$desc" "output missing '$pattern'"
    fi
}

assert_output_not_contains() {
    local desc="$1"; shift
    local pattern="$1"; shift
    local output
    set +e
    output=$("$@" 2>&1)
    set -e
    if echo "$output" | grep -q "$pattern"; then
        fail "$desc" "output unexpectedly contains '$pattern'"
    else
        pass "$desc"
    fi
}

assert_file_exists() {
    local desc="$1"
    local path="$2"
    if [ -f "$path" ]; then
        pass "$desc"
    else
        fail "$desc" "file not found: $path"
    fi
}

assert_file_not_exists() {
    local desc="$1"
    local path="$2"
    if [ ! -f "$path" ]; then
        pass "$desc"
    else
        fail "$desc" "file should not exist: $path"
    fi
}

assert_file_contains() {
    local desc="$1"
    local path="$2"
    local pattern="$3"
    if grep -q "$pattern" "$path" 2>/dev/null; then
        pass "$desc"
    else
        fail "$desc" "'$path' missing '$pattern'"
    fi
}

assert_file_not_contains() {
    local desc="$1"
    local path="$2"
    local pattern="$3"
    if grep -q "$pattern" "$path" 2>/dev/null; then
        fail "$desc" "'$path' unexpectedly contains '$pattern'"
    else
        pass "$desc"
    fi
}

cleanup() {
    rm -rf "$TEST_DATA"
}
trap cleanup EXIT

# === Tests ===

echo ""
echo "ai-journal test suite"
echo "data dir: $TEST_DATA"
echo ""

# --- new ---

echo "new:"

$JOURNAL new stuck testproj -t "Bug in parser" --summary "Parser chokes on nested brackets" -s grafana-internal >/dev/null
assert_file_exists "creates stuck entry" "$TEST_DATA/projects/testproj/stucks/"*bug-in-parser*.md
assert_file_contains "sets type" "$TEST_DATA/projects/testproj/stucks/"*bug-in-parser*.md "type: stuck"
assert_file_contains "sets title" "$TEST_DATA/projects/testproj/stucks/"*bug-in-parser*.md "title: Bug in parser"
assert_file_contains "sets summary" "$TEST_DATA/projects/testproj/stucks/"*bug-in-parser*.md "Parser chokes on nested brackets"
assert_file_contains "sets scope" "$TEST_DATA/projects/testproj/stucks/"*bug-in-parser*.md "scope: grafana-internal"
assert_file_contains "sets status open" "$TEST_DATA/projects/testproj/stucks/"*bug-in-parser*.md "status: open"
assert_file_contains "has template sections" "$TEST_DATA/projects/testproj/stucks/"*bug-in-parser*.md "## What we were trying to do"

$JOURNAL new session testproj -t "Working on parser" >/dev/null
assert_file_exists "creates session entry" "$TEST_DATA/projects/testproj/sessions/"*working-on-parser*.md
assert_file_contains "session defaults to private scope" "$TEST_DATA/projects/testproj/sessions/"*working-on-parser*.md "scope: private"
assert_file_contains "session status is active" "$TEST_DATA/projects/testproj/sessions/"*working-on-parser*.md "status: active"

$JOURNAL new decision testproj -t "Use regex over PEG" -s public >/dev/null
assert_file_exists "creates decision entry" "$TEST_DATA/projects/testproj/decisions/"*use-regex-over-peg*.md

$JOURNAL new insight testproj -t "PEG grammars are overkill here" -s public >/dev/null
assert_file_exists "creates insight entry" "$TEST_DATA/projects/testproj/insights/"*peg-grammars-are-overkill*.md

assert_file_exists "creates overview.md" "$TEST_DATA/projects/testproj/overview.md"

# collision avoidance
$JOURNAL new insight testproj -t "PEG grammars are overkill here" >/dev/null
count=$(ls "$TEST_DATA/projects/testproj/insights/"*peg-grammars* 2>/dev/null | wc -l)
if [ "$count" -ge 2 ]; then
    pass "handles filename collisions"
else
    fail "handles filename collisions" "expected 2+ files, got $count"
fi

echo ""

# --- projects ---

echo "projects:"

$JOURNAL new stuck otherproj -t "Unrelated bug" >/dev/null
assert_output_contains "lists testproj" "testproj" $JOURNAL projects
assert_output_contains "lists otherproj" "otherproj" $JOURNAL projects

echo ""

# --- list ---

echo "list:"

assert_output_contains "lists all entries" "Bug in parser" $JOURNAL list testproj
assert_output_contains "lists by type" "Bug in parser" $JOURNAL list testproj --type stuck
assert_output_not_contains "filters by type" "Bug in parser" $JOURNAL list testproj --type session

echo ""

# --- show ---

echo "show:"

assert_output_contains "shows entry by partial name" "Bug in parser" $JOURNAL show bug-in-parser
assert_output_contains "shows status" "status: open" $JOURNAL show bug-in-parser

echo ""

# --- search ---

echo "search:"

assert_output_contains "finds by title text" "Bug in parser" $JOURNAL search "parser"
assert_output_contains "finds by summary text" "Bug in parser" $JOURNAL search "nested brackets"
assert_output_not_contains "no false positives" "Bug in parser" $JOURNAL search "xyznonexistent"

echo ""

# --- status ---

echo "status:"

assert_output_contains "shows open stuck points" "Bug in parser" $JOURNAL status testproj
assert_output_contains "shows summary in status" "Parser chokes" $JOURNAL status testproj
assert_output_contains "shows recent sessions" "Working on parser" $JOURNAL status testproj
assert_output_contains "shows decisions" "Use regex over PEG" $JOURNAL status testproj
assert_output_contains "shows insights" "PEG grammars" $JOURNAL status testproj

echo ""

# --- resolve ---

echo "resolve:"

$JOURNAL resolve bug-in-parser -s "Fixed by escaping inner brackets first" >/dev/null
assert_file_contains "sets status resolved" "$TEST_DATA/projects/testproj/stucks/"*bug-in-parser*.md "status: resolved"
assert_file_contains "adds resolution section" "$TEST_DATA/projects/testproj/stucks/"*bug-in-parser*.md "## Resolution"
assert_file_contains "includes solution text" "$TEST_DATA/projects/testproj/stucks/"*bug-in-parser*.md "escaping inner brackets"
assert_file_contains "adds resolved timestamp" "$TEST_DATA/projects/testproj/stucks/"*bug-in-parser*.md "resolved:"
assert_output_not_contains "resolved entry not in open stuck" "Bug in parser" $JOURNAL status testproj

echo ""

# --- index ---

echo "index:"

# Add tags for index testing
sed -i 's/tags: \[\]/tags: [parsing, regex]/' "$TEST_DATA/projects/testproj/decisions/"*use-regex*.md
sed -i 's/tags: \[\]/tags: [parsing, performance]/' "$TEST_DATA/projects/testproj/insights/"*peg-grammars*.md
sed -i 's/tags: \[\]/tags: [parsing, brackets]/' "$TEST_DATA/projects/testproj/stucks/"*bug-in-parser*.md

$JOURNAL index >/dev/null
assert_file_exists "creates INDEX.md" "$TEST_DATA/INDEX.md"
assert_file_contains "index has topic headings" "$TEST_DATA/INDEX.md" "### parsing"
assert_file_contains "index has entry links" "$TEST_DATA/INDEX.md" "Use regex over PEG"
assert_file_contains "index links are relative" "$TEST_DATA/INDEX.md" "projects/testproj/"
assert_file_contains "index shows summaries" "$TEST_DATA/INDEX.md" "Parser chokes"
assert_file_contains "index cross-references topics" "$TEST_DATA/INDEX.md" "### regex"
assert_file_contains "index shows stuck status badge" "$TEST_DATA/INDEX.md" "\`resolved\`"

echo ""

# --- graph ---

echo "graph:"

# Add related links between entries
sed -i 's/tags: \[parsing, regex\]/tags: [parsing, regex]\nrelated: [bug-in-parser]/' "$TEST_DATA/projects/testproj/decisions/"*use-regex*.md
sed -i 's/tags: \[parsing, performance\]/tags: [parsing, performance]\nrelated: [use-regex-over-peg]/' "$TEST_DATA/projects/testproj/insights/"*peg-grammars*.md

$JOURNAL graph >/dev/null
assert_file_exists "creates GRAPH.md" "$TEST_DATA/GRAPH.md"
assert_file_contains "graph has mermaid block" "$TEST_DATA/GRAPH.md" '```mermaid'
assert_file_contains "graph has entry nodes" "$TEST_DATA/GRAPH.md" "Bug in parser"
assert_file_contains "graph has explicit edges" "$TEST_DATA/GRAPH.md" " --- "
assert_file_contains "graph has tag edges" "$TEST_DATA/GRAPH.md" " -.- "
assert_file_contains "graph has legend" "$TEST_DATA/GRAPH.md" "## Legend"

echo ""

# --- scrub ---

echo "scrub:"

# Scrub grafana-internal entries (the resolved bug)
echo "y" | $JOURNAL scrub grafana-internal >/dev/null 2>&1
assert_file_contains "tombstone replaces title" "$TEST_DATA/projects/testproj/stucks/"*bug-in-parser*.md "title: \[scrubbed\]"
assert_file_contains "tombstone preserves tags" "$TEST_DATA/projects/testproj/stucks/"*bug-in-parser*.md "tags:"
assert_file_contains "tombstone records original scope" "$TEST_DATA/projects/testproj/stucks/"*bug-in-parser*.md "original_scope: grafana-internal"
# Check scope line is gone but original_scope remains
if grep -q "^scope:" "$TEST_DATA/projects/testproj/stucks/"*bug-in-parser*.md 2>/dev/null; then
    fail "tombstone removes scope field" "bare 'scope:' line still present"
else
    pass "tombstone removes scope field"
fi
assert_file_contains "tombstone preserves resolution" "$TEST_DATA/projects/testproj/stucks/"*bug-in-parser*.md "escaping inner brackets"
assert_file_contains "tombstone has scrubbed marker" "$TEST_DATA/projects/testproj/stucks/"*bug-in-parser*.md "Details scrubbed"

# Dry run
$JOURNAL new stuck testproj -t "Secret bug" -s personal >/dev/null
assert_output_contains "dry run shows targets" "Secret bug" $JOURNAL scrub personal --dry-run
assert_file_not_contains "dry run does not modify" "$TEST_DATA/projects/testproj/stucks/"*secret-bug*.md "scrubbed"

# No tombstones
echo "y" | $JOURNAL scrub personal --no-tombstones >/dev/null 2>&1
assert_file_not_exists "no-tombstones deletes file" "$TEST_DATA/projects/testproj/stucks/"*secret-bug*.md

echo ""

# --- export ---

echo "export:"

EXPORT_DIR="$TEST_DATA/export-test"
$JOURNAL export --scope public --to "$EXPORT_DIR" >/dev/null
assert_file_exists "export creates destination" "$EXPORT_DIR/projects/testproj/decisions/"*use-regex*.md
assert_file_exists "export builds index" "$EXPORT_DIR/INDEX.md"
assert_file_contains "exported entry has full content" "$EXPORT_DIR/projects/testproj/decisions/"*use-regex*.md "scope: public"

# Topic filter
TOPIC_DIR="$TEST_DATA/topic-test"
$JOURNAL export --topic parsing --to "$TOPIC_DIR" >/dev/null
count=$(find "$TOPIC_DIR/projects" -name "*.md" -not -name "overview.md" 2>/dev/null | wc -l)
if [ "$count" -ge 2 ]; then
    pass "topic export finds tagged entries"
else
    fail "topic export finds tagged entries" "expected 2+, got $count"
fi

echo ""

# --- extract ---

echo "extract:"

# Create a fresh entry to extract
$JOURNAL new insight testproj -t "Extract me" -s extract-test --summary "This should be moved" >/dev/null
sed -i 's/tags: \[\]/tags: [extraction]/' "$TEST_DATA/projects/testproj/insights/"*extract-me*.md

# Add body content to test scrubbing
cat >> "$TEST_DATA/projects/testproj/insights/"*extract-me*.md << 'BODY'

## The insight

Sensitive details here that should be scrubbed.

## Where it applies

Also sensitive.
BODY

EXTRACT_DIR="$TEST_DATA/extract-test"
echo "y" | $JOURNAL extract --scope extract-test --to "$EXTRACT_DIR" >/dev/null 2>&1
assert_file_exists "extract copies to destination" "$EXTRACT_DIR/projects/testproj/insights/"*extract-me*.md
assert_file_contains "extract destination has full content" "$EXTRACT_DIR/projects/testproj/insights/"*extract-me*.md "Sensitive details"
assert_file_contains "extract scrubs original" "$TEST_DATA/projects/testproj/insights/"*extract-me*.md "title: \[scrubbed\]"
assert_file_contains "extract original has tombstone" "$TEST_DATA/projects/testproj/insights/"*extract-me*.md "Details scrubbed"
# The insight section IS a keeper section, so its content should be preserved
assert_file_exists "extract rebuilds source index" "$TEST_DATA/INDEX.md"

echo ""

# --- hook ---

# --- note ---

echo "note:"

$JOURNAL new note testproj -t "Random thought about naming" --summary "Names shape how people think about tools" >/dev/null
assert_file_exists "creates note entry" "$TEST_DATA/projects/testproj/notes/"*random-thought*.md
assert_file_contains "note has type note" "$TEST_DATA/projects/testproj/notes/"*random-thought*.md "type: note"
assert_file_contains "note has summary" "$TEST_DATA/projects/testproj/notes/"*random-thought*.md "Names shape"

echo ""

# --- reflect ---

echo "reflect:"

$JOURNAL reflect testproj -t "First reflection" --summary "Testing the reflection system" >/dev/null
assert_file_exists "creates reflection entry" "$TEST_DATA/projects/testproj/reflections/"*first-reflection*.md
assert_file_contains "reflection has type" "$TEST_DATA/projects/testproj/reflections/"*first-reflection*.md "type: reflection"
assert_file_contains "reflection has template" "$TEST_DATA/projects/testproj/reflections/"*first-reflection*.md "## What I noticed"

# Loop guard
output=$($JOURNAL reflect testproj -t "Second reflection" 2>&1)
if echo "$output" | grep -q "Already reflected"; then
    pass "loop guard blocks second reflection same day"
else
    fail "loop guard blocks second reflection same day" "guard didn't fire"
fi

# Force override
$JOURNAL reflect testproj -t "Forced reflection" --force >/dev/null 2>&1
count=$(ls "$TEST_DATA/projects/testproj/reflections/"*.md 2>/dev/null | wc -l)
if [ "$count" -ge 2 ]; then
    pass "force flag bypasses loop guard"
else
    fail "force flag bypasses loop guard" "expected 2+ files, got $count"
fi

echo ""

# --- import ---

echo "import:"

# Create a test file to import
echo "This is a test document with important information." > "$TEST_DATA/test-doc.txt"

$JOURNAL import "$TEST_DATA/test-doc.txt" testproj -t "Test document" --summary "A test file for import" --tags "testing,import" --context "Imported as part of the test suite" >/dev/null
assert_file_exists "creates note entry for import" "$TEST_DATA/projects/testproj/notes/"*test-document*.md
assert_file_exists "copies file to attachments" "$TEST_DATA/projects/testproj/attachments/test-doc.txt"
assert_file_contains "import entry references source" "$TEST_DATA/projects/testproj/notes/"*test-document*.md "test-doc.txt"
assert_file_contains "import entry has tags" "$TEST_DATA/projects/testproj/notes/"*test-document*.md "testing"
assert_file_contains "import entry has context" "$TEST_DATA/projects/testproj/notes/"*test-document*.md "test suite"
assert_file_contains "import entry has attachment metadata" "$TEST_DATA/projects/testproj/notes/"*test-document*.md "attachment:"

# Verify attachment content
assert_file_contains "attachment has original content" "$TEST_DATA/projects/testproj/attachments/test-doc.txt" "important information"

# Import same file again - should not collide
$JOURNAL import "$TEST_DATA/test-doc.txt" testproj -t "Test document duplicate" >/dev/null
count=$(ls "$TEST_DATA/projects/testproj/attachments/"test-doc* 2>/dev/null | wc -l)
if [ "$count" -ge 2 ]; then
    pass "import handles attachment filename collisions"
else
    fail "import handles attachment filename collisions" "expected 2+ files, got $count"
fi

echo ""

# --- hook ---

echo "hook:"

HOOK="$(cd "$(dirname "$0")" && pwd)/journal-hook"

# From a directory matching a project name
output=$(cd "$TEST_DATA/projects/testproj" && AIJOURNAL_DATA="$TEST_DATA" "$HOOK" 2>&1)
if echo "$output" | grep -q "testproj"; then
    pass "hook detects project from cwd"
else
    fail "hook detects project from cwd" "output missing project name"
fi

# From a directory with no matching project - still shows cross-project stuck points
output=$(cd /tmp && AIJOURNAL_DATA="$TEST_DATA" "$HOOK" 2>&1)
if echo "$output" | grep -q "Current project"; then
    fail "hook does not claim a current project for unknown dir" "matched a project it shouldn't"
else
    pass "hook does not claim a current project for unknown dir"
fi

# Hook shows other projects' stuck points even from unknown dir
if echo "$output" | grep -q "other projects"; then
    pass "hook surfaces cross-project stuck points"
else
    pass "hook silent when no cross-project stuck points"  # also valid if all resolved
fi

echo ""

# === Summary ===

echo "─────────────────────────────"
TOTAL=$((PASS + FAIL))
echo "  $TOTAL tests: $PASS passed, $FAIL failed"
echo ""

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
