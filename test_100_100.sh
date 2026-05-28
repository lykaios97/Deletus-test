#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# ============================================================
# generate_test_branches.sh
# Creates 100 "stale" + 100 "active" branches for testing
# Fixed: lock file cleanup, proper tmp file commit flow
# ============================================================

STALE_COUNT=100
ACTIVE_COUNT=100
BASE_BRANCH=""   # will be auto-detected

# ---------- Step 1: Safety check — must be inside a git repo ----------
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "❌ Not a git repo. Please run inside a git project."
    exit 1
fi

# ---------- Step 2: Make sure we have a remote called "origin" ----------
if ! git remote get-url origin > /dev/null 2>&1; then
    echo "❌ No remote named 'origin' found."
    exit 1
fi

# ---------- Step 3: Ensure the working tree is clean ----------
if [ -n "$(git status --porcelain)" ]; then
    echo "❌ Working tree is not clean. Please commit or stash changes before generating test branches."
    git status --short
    exit 1
fi

# ---------- Step 4: Remember which branch we started on ----------
BASE_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo ""
echo "📍 Base branch: $BASE_BRANCH"

# ---------- Step 5: Clean up any stale .lock files from previous runs ----------
# Lock files are left behind when a previous run crashed or was interrupted
clean_lock_files() {
    find "$(git rev-parse --git-dir)" -name "*.lock" -delete 2>/dev/null
    echo "🔓 Cleared any stale .lock files"
}
clean_lock_files

echo ""
echo "🚀 Starting test branch generation..."
echo "   Stale branches : $STALE_COUNT"
echo "   Active branches: $ACTIVE_COUNT"
echo ""

# ============================================================
# HELPER: safely switch back to base branch
# Stashes any uncommitted changes before switching to avoid
# the "changes would be overwritten by checkout" error
# ============================================================
safe_checkout_base() {
    git checkout "$BASE_BRANCH" --quiet
    clean_lock_files
}

# ============================================================
# HELPER: create a unique dummy commit on the current branch
# Uses branch name + index to guarantee unique content
# ============================================================
make_dummy_commit() {
    local branch_name=$1
    local index=$2

    # Use a unique filename per branch to avoid cross-branch conflicts
    local tmp_file=".test_marker_${index}.tmp"

    echo "branch: $branch_name | created: $(date)" > "$tmp_file"
    git add "$tmp_file" > /dev/null 2>&1
    git commit -m "test commit for $branch_name" --quiet
}

# ============================================================
# PART A — Create STALE branches
# Push to remote, then delete the remote copy after verification.
# This makes local branches stale while allowing you to inspect them on GitHub first.
# ============================================================
echo "📤 Creating $STALE_COUNT stale branches..."

for i in $(seq 1 $STALE_COUNT); do
    BRANCH_NAME="stale/test-branch-$i"

    # Skip if branch already exists locally
    if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
        echo "   ⏭️  Already exists, skipping: $BRANCH_NAME"
        continue
    fi

    # Create new branch from base
    git checkout -b "$BRANCH_NAME" --quiet

    # Commit a unique file on this branch
    make_dummy_commit "$BRANCH_NAME" "$i"

    # Push to remote to establish tracking reference
    git push origin "$BRANCH_NAME" --quiet

    # Safely return to base branch for the next loop
    safe_checkout_base

    echo "   ✅ Created remote branch: $BRANCH_NAME"
done

echo ""
echo "✅ Created all stale candidate branches on remote."
echo "   You can verify them in GitHub now before they are deleted."
echo "   Remote branch list will refresh after the next step."
read -p "Press ENTER to delete the remote copies and make these branches stale locally... " _

echo ""
echo "🗑️ Deleting the remote copies for stale branches..."

for i in $(seq 1 $STALE_COUNT); do
    BRANCH_NAME="stale/test-branch-$i"

    if ! git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
        echo "   ⚠️  Local branch missing, skipping: $BRANCH_NAME"
        continue
    fi

    git push origin --delete "$BRANCH_NAME" --quiet || true
    git fetch origin --prune --quiet
    echo "   ✅ Remote deleted: $BRANCH_NAME"
done

echo ""

# ============================================================
# PART B — Create ACTIVE branches
# Push and keep on remote — cleanup script must NOT touch these
# ============================================================
echo "📌 Creating $ACTIVE_COUNT active branches..."

for i in $(seq 1 $ACTIVE_COUNT); do
    BRANCH_NAME="active/test-branch-$i"

    # Skip if branch already exists locally
    if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
        echo "   ⏭️  Already exists, skipping: $BRANCH_NAME"
        continue
    fi

    # Create new branch from base
    git checkout -b "$BRANCH_NAME" --quiet

    # Commit a unique file on this branch
    make_dummy_commit "$BRANCH_NAME" "$i"

    # Push and KEEP on remote
    git push origin "$BRANCH_NAME" --quiet

    # Update local remote-tracking refs for this branch
    git fetch origin --quiet

    # Safely return to base branch
    safe_checkout_base

    echo "   📌 Active: $BRANCH_NAME"
done

# ---------- Clean up all temp marker files from working tree ----------
git checkout "$BASE_BRANCH" --quiet
rm -f .test_marker_*.tmp

# ---------- Summary ----------
echo ""
echo "============================================================"
echo "🎉 Done!"
echo "   Stale  branches: $STALE_COUNT  → cleanup script WILL delete"
echo "   Active branches: $ACTIVE_COUNT → cleanup script will IGNORE"
echo ""
echo "▶  Now run: ./cleanup_branches.sh"
echo "============================================================"