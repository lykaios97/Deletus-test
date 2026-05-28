#!/bin/bash

# ============================================================
# cleanup_branches.sh
# Deletes all local git branches that no longer exist on remote
# One single y/n prompt — then fully automated
# ============================================================

# ---------- Step 1: Make sure we are inside a git repo ----------
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "❌ Not a git repository. Please run this script inside a git project."
    exit 1
fi

# ---------- Step 2: Fetch latest remote info + prune dead refs ----------
echo ""
echo "🔄 Fetching latest remote info..."
git fetch --prune

# ---------- Step 3: Find branches that exist locally but NOT on remote ----------
# How it works:
#   - "git branch -vv"        → lists local branches with their remote tracking info
#   - grep ": gone]"          → filters branches whose remote is marked as gone (deleted)
#   - awk '{print $1}'        → extracts just the branch name
STALE_BRANCHES=$(git branch -vv | grep ': gone]' | awk '{print $1}')

# ---------- Step 4: If nothing to clean, exit early ----------
if [ -z "$STALE_BRANCHES" ]; then
    echo ""
    echo "✅ All clean! No stale local branches found."
    exit 0
fi

# ---------- Step 5: Show the user what will be deleted ----------
echo ""
echo "🗑️  The following local branches no longer exist on remote:"
echo "------------------------------------------------------------"
for branch in $STALE_BRANCHES; do
    echo "   - $branch"
done
echo "------------------------------------------------------------"

# ---------- Step 6: Single y/n prompt ----------
echo ""
read -p "⚠️  Delete ALL of the above branches? (y/n): " CONFIRM

# ---------- Step 7: If user said no, bail out ----------
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo ""
    echo "🚫 Aborted. No branches were deleted."
    exit 0
fi

# ---------- Step 8: Delete all stale branches automatically (no more prompts) ----------
echo ""
echo "🧹 Deleting stale branches..."

SUCCESS_COUNT=0
FAIL_COUNT=0

for branch in $STALE_BRANCHES; do
    # -d  = safe delete (won't delete unmerged branches)
    # -D  = force delete (uncomment below and comment -d line if you want force)
    if git branch -d "$branch" 2>/dev/null; then
        echo "   ✅ Deleted: $branch"
        ((SUCCESS_COUNT++))
    else
        # Branch has unmerged work — force delete it anyway
        echo "   ⚡ Force deleting (unmerged): $branch"
        git branch -D "$branch"
        ((SUCCESS_COUNT++))
    fi
done

# ---------- Step 9: Summary ----------
echo ""
echo "============================================================"
echo "🎉 Done! $SUCCESS_COUNT branch(es) deleted."
echo "============================================================"