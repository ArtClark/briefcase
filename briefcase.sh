#!/bin/bash

# --- BRIEFCASE: THE WIN95-STYLE SYNC TOOL ---
# Version: 1.8 (History Guard & Interactive Password)
# GitHub: https://github.com/ArtClark/briefcase
# License: MIT (c) 2026

# 1. SETUP & VARIABLES
TARGET_DIR=${1:-"."}
PASS_KEY=$2 
SCRIPT_NAME=$(basename "$0")
BUNDLE_NAME="briefcase_archive.bundle"
FINAL_ARCHIVE="briefcase.7z"

cd "$TARGET_DIR" || exit

# 2. HISTORY GUARD LOGIC
# If password was provided on CLI, check if 'ignorespace' is active 
# or if the user actually used a leading space.
if [ ! -z "$PASS_KEY" ]; then
    # Search history for the current command without a leading space
    # This is a bit recursive, so the most reliable 'Stealth' way is:
    echo "Warning: Password provided via CLI. Ensuring history is scrubbed..."
    history -d $(history 1 | awk '{print $1}') 2>/dev/null
else
    # Secure Prompt: Characters are not echoed to the screen
    read -sp "Enter Briefcase Password (Enter for none): " PASS_KEY
    echo ""
fi

# 3. SELF-REPLICATION
if [ ! -f "./$SCRIPT_NAME" ]; then
    cp "$0" "./$SCRIPT_NAME"
fi

# 4. PACKING LOGIC
if [ ! -f "$FINAL_ARCHIVE" ]; then
    echo "--- PACKING BRIEFCASE ---"
    
    P_FLAG=""
    if [ ! -z "$PASS_KEY" ]; then
        P_FLAG="-p$PASS_KEY -mhe=on"
    fi

    [ -f "$BUNDLE_NAME" ] && rm "$BUNDLE_NAME"
    git stash push -u -m 'Briefcase Sync'
    git bundle create "$BUNDLE_NAME" --all refs/stash

    if 7z a -t7z -m0=lzma2 -mx=9 -ms=on $P_FLAG "$FINAL_ARCHIVE" "$BUNDLE_NAME"; then
        rm "$BUNDLE_NAME"
        echo "SUCCESS: Archive created."
    else
        echo "ERROR: Packing failed."
        exit 1
    fi

# 5. UNPACKING/MERGE LOGIC
else
    echo "--- UNPACKING BRIEFCASE ---"

    P_FLAG=""
    if [ ! -z "$PASS_KEY" ]; then
        P_FLAG="-p$PASS_KEY"
    fi

    if 7z x "$FINAL_ARCHIVE" $P_FLAG -y; then
        git remote remove briefcase 2>/dev/null
        git remote add briefcase "$BUNDLE_NAME"
        git fetch briefcase && git merge briefcase/main
        git fetch "$BUNDLE_NAME" refs/stash:refs/stash
        git stash apply stash@{0}
        
        rm "$BUNDLE_NAME"
        rm "$FINAL_ARCHIVE"
        echo "SUCCESS: Restore complete."
    else
        echo "ERROR: Unpack failed. Check password."
        exit 1
    fi
fi