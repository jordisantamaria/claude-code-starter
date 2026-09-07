#!/bin/sh

# Get current branch name
CURRENT=$(git branch --show-current)

# 1. List candidate branches
# Remove origin/ prefix, exclude self, unique list
CANDIDATES=$(git branch -a --format='%(refname:short)' | \
    sed 's/^origin\///' | \
    grep -E '^(main|master|develop|release/.*|task/.*|issue/.*|feature/.*)$' | \
    grep -Fvx "$CURRENT" | \
    sort -u)

# Fallback to main/master if no candidates
if [ -z "$CANDIDATES" ]; then
    if git rev-parse --verify main >/dev/null 2>&1; then
        echo "main"
    else
        echo "master"
    fi
    exit 0
fi

# 2. Calculate distance to each candidate
RES=$(for b in $CANDIDATES; do
    MB=$(git merge-base "$b" HEAD 2>/dev/null)
    if [ -n "$MB" ]; then
        echo "$(git rev-list --count "$MB..HEAD") $b"
    fi
done | sort -n)

# Fallback if no distances calculated
if [ -z "$RES" ]; then
    if git rev-parse --verify main >/dev/null 2>&1; then
        echo "main"
    else
        echo "master"
    fi
    exit 0
fi

# 3. Pick shortest distance
MIN_DIST=$(echo "$RES" | head -n 1 | awk '{print $1}')
BEST_MATCHES=$(echo "$RES" | awk -v d="$MIN_DIST" '$1 == d {print $2}')
MATCH_COUNT=$(echo "$BEST_MATCHES" | wc -l | tr -d ' ')

if [ "$MATCH_COUNT" -eq 1 ]; then
    echo "$BEST_MATCHES"
else
    echo "CONFIRM: $(echo "$BEST_MATCHES" | xargs | sed 's/ /, /g')"
fi
