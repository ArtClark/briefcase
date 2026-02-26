#!/bin/bash

# --- BRIEFCASE: THE WIN95-STYLE SYNC TOOL ---
# Version: 1.9 (Sanitized & History Guard)
# GitHub: https://github.com/ArtClark/briefcase
# License: MIT (c) 2026

# 1. SETUP & VARIABLES
TARGET_DIR=${1:-"."}
PASS_KEY=$2 
SCRIPT_NAME=$(basename "$0")
BUNDLE_NAME="briefcase_archive.bundle"
FINAL_ARCHIVE="briefcase.7z"

cd "$TARGET_DIR" || exit

# 2. SANITIZATION (The "Ghost Cleaner")
# Purpose: Stop system junk from causing merge conflicts
if [ -d ".git" ]; then
    # Remove from tracking but keep on disk
    git rm --cached .DS_Store Thumbs.db desktop.ini 2>/dev/null
    
    # Ensure they stay ignored locally without touching .gitignore
    EXCLUDE=".git/info/exclude"
    for JUNK in ".DS_Store" "Thumbs.db" "desktop.ini" "briefcase.7z"; do
        grep -qq "$JUNK" "$EXCLUDE" || echo "$JUNK" >> "$EXCLUDE"
    done
fi

# 3. HISTORY GUARD
if [ ! -z "$PASS_KEY" ]; then
    history -d $(history 1 | awk '{print $1}') 2>/dev/null
else
    read -sp "Enter Briefcase Password (Enter for none): " PASS_KEY
    echo ""
fi

# 4. SELF-REPLICATION
[ ! -f "./$SCRIPT_NAME" ] && cp "$0" "./$SCRIPT_NAME"

# 5. PACKING LOGIC
if [ ! -f "$FINAL_ARCHIVE" ]; then
    echo "--- PACKING BRIEFCASE ---"
    
    P_FLAG=""
    [ ! -z "$PASS_KEY" ] && P_FLAG="-p$PASS_KEY -mhe=on"

    [ -f "$BUNDLE_NAME" ] && rm "$BUNDLE_NAME"
    
    # Verbose: explain the move
    echo "[Command] git stash push -u"
    git stash push -u -m "Briefcase Sync"

    git bundle create "$BUNDLE_NAME" --all refs/stash

    if 7z a -t7z -m0=lzma2 -mx=9 -ms=on $P_FLAG "$FINAL_ARCHIVE" "$BUNDLE_NAME"; then
        rm "$BUNDLE_NAME"
        echo "SUCCESS: Archive created."
    else
        echo "ERROR: Packing failed."
        exit 1
    fi

# 6. UNPACKING/MERGE LOGIC
else
    echo "--- UNPACKING BRIEFCASE ---"

    P_FLAG=""
    [ ! -z "$PASS_KEY" ] && P_FLAG="-p$PASS_KEY"

    if 7z x "$FINAL_ARCHIVE" $P_FLAG -y; then
        if [ ! -d ".git" ]; then
            git clone "$BUNDLE_NAME" .
        else
            git remote remove briefcase 2>/dev/null
            git remote add briefcase "$BUNDLE_NAME"
            git fetch briefcase
            
            # Merge with auto-resolve for the junk files we sanitized earlier
            git merge briefcase/main -m "Briefcase Auto-Merge" || {
                git checkout --ours .DS_Store Thumbs.db 2>/dev/null
                git add .DS_Store Thumbs.db 2>/dev/null
                git commit -m "chore: resolved system junk conflicts"
            }
        fi

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