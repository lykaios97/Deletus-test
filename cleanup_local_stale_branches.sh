#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# ============================================================
# cleanup_local_stale_branches.sh
# Deletes only local branches matching a pattern, without touching remote.
# Use this when you want to remove stale local test branches separately.
# ============================================================

PATTERN="stale/test-branch-*"
if [ "$#" -gt 0 ]; then
    PATTERN="$1"
fi

# ---------- Safety check — must be inside a git repo ----------
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "❌ Not a git repository. Run this script inside a Git repository."
    exit 1
fi

# ---------- Find matching local branches ----------
MATCHING_BRANCHES=()
while IFS= read -r branch; do
    branch="${branch#\* }"
    branch="${branch# }"
    [ -n "$branch" ] && MATCHING_BRANCHES+=("$branch")
done < <(git branch --list "$PATTERN" | sed 's/^..//')

if [ ${#MATCHING_BRANCHES[@]} -eq 0 ]; then
    echo "✅ No local branches found matching pattern: $PATTERN"
    exit 0
fi

# ---------- Show branches that will be deleted ----------
echo ""
echo "🗑️  Local branches matching '$PATTERN' to delete:"
echo "------------------------------------------------------------"
for branch in "${MATCHING_BRANCHES[@]}"; do
    echo "   - $branch"
done
echo "------------------------------------------------------------"

echo ""
read -r -p "⚠️  Delete the above local branches? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "🚫 Aborted. No branches were deleted."
    exit 0
fi

# ---------- Delete local branches ----------
SUCCESS=0
FAIL=0
for branch in "${MATCHING_BRANCHES[@]}"; do
    if git branch -d "$branch" > /dev/null 2>&1; then
        echo "   ✅ Deleted: $branch"
        ((SUCCESS++))
    else
        echo "   ⚡ Force deleting unmerged branch: $branch"
        if git branch -D "$branch" > /dev/null 2>&1; then
            echo "   ✅ Force deleted: $branch"
            ((SUCCESS++))
        else
            echo "   ❌ Failed to delete: $branch"
            ((FAIL++))
        fi
    fi
done

# ---------- Summary ----------
echo ""
echo "============================================================"
echo "🎉 Done. $SUCCESS deleted, $FAIL failed."
echo "============================================================"

echo "Tip: run this script with a different pattern to delete other local branches, e.g."
echo "   ./cleanup_local_stale_branches.sh active/test-branch-*"
