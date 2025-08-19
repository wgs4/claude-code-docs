#!/bin/bash
set -euo pipefail

# Claude Code Documentation Helper Script v0.3.3
# This script handles all /docs command functionality  
# Installation path: ~/.claude-code-docs/claude-docs-helper.sh

# Script version
SCRIPT_VERSION="0.3.3"

# Fixed installation path (no need for placeholder replacement)
DOCS_PATH="$HOME/.claude-code-docs"
MANIFEST="$DOCS_PATH/docs/docs_manifest.json"

# No colors since they don't work in terminal anyway

# Enhanced sanitize function to prevent command injection
sanitize_input() {
    # Remove ALL shell metacharacters and control characters
    # Only allow alphanumeric, spaces, hyphens, underscores, periods, commas, apostrophes, and question marks
    echo "$1" | sed 's/[^a-zA-Z0-9 _.,'\''?-]//g' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//'
}

# Function to print documentation header
print_doc_header() {
    echo "📚 COMMUNITY MIRROR: https://github.com/wgs4/claude-code-docs"
    echo "📖 OFFICIAL DOCS: https://docs.anthropic.com/en/docs/claude-code"
    echo ""
}


# Function to auto-update docs if needed
auto_update() {
    cd "$DOCS_PATH" 2>/dev/null || return 1
    
    # Get current branch
    local BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    
    # Quick fetch to check for updates (fast)
    if ! git fetch --quiet origin "$BRANCH" 2>/dev/null; then
        # Current branch doesn't exist on origin, try main
        if ! git fetch --quiet origin main 2>/dev/null; then
            # Fetch failed - can't sync
            return 2
        fi
        # Use main branch for comparison
        BRANCH="main"
    fi
    
    local LOCAL=$(git rev-parse HEAD 2>/dev/null)
    local REMOTE=$(git rev-parse origin/"$BRANCH" 2>/dev/null)
    
    # Check if we're behind remote (important: not ahead)
    local BEHIND=$(git rev-list HEAD..origin/"$BRANCH" --count 2>/dev/null || echo "0")
    
    if [[ "$LOCAL" != "$REMOTE" ]] && [[ "$BEHIND" -gt 0 ]]; then
        # We're behind - safe to pull
        echo "🔄 Updating documentation..." >&2
        git pull --quiet origin "$BRANCH" 2>&1 | grep -v "Merge made by" || true
        
        # Check if installer needs updating
        local INSTALLER_VERSION=$SCRIPT_VERSION
        local VERSION_INT=$(echo "$INSTALLER_VERSION" | sed 's/^0\.//')
        
        if [[ $VERSION_INT -ge 3 ]]; then
            echo "🔧 Updating Claude Code Docs installer..." >&2
            ./install.sh >/dev/null 2>&1
        fi
    fi
    
    return 0  # Success (either updated or already up-to-date)
}

# Function to show documentation sync status
show_freshness() {
    print_doc_header
    
    # Read manifest
    if [[ ! -f "$MANIFEST" ]]; then
        echo "❌ Error: Documentation not found at ~/.claude-code-docs"
        echo "Please reinstall with:"
        echo "curl -fsSL https://raw.githubusercontent.com/wgs4/claude-code-docs/main/install.sh | bash"
        exit 1
    fi
    
    # Try to sync with GitHub
    auto_update
    local sync_status=$?
    
    if [[ $sync_status -eq 2 ]]; then
        echo "⚠️  Could not sync with GitHub (using local cache)"
        echo "Check your internet connection or GitHub access"
    else
        # Check if we're ahead or behind
        cd "$DOCS_PATH" 2>/dev/null || exit 1
        local BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
        # If current branch doesn't exist on origin, compare to main
        local COMPARE_BRANCH="$BRANCH"
        if ! git rev-parse --verify origin/"$BRANCH" >/dev/null 2>&1; then
            COMPARE_BRANCH="main"
        fi
        local AHEAD=$(git rev-list origin/"$COMPARE_BRANCH"..HEAD --count 2>/dev/null || echo "0")
        local BEHIND=$(git rev-list HEAD..origin/"$COMPARE_BRANCH" --count 2>/dev/null || echo "0")
        
        if [[ "$AHEAD" -gt 0 ]]; then
            echo "⚠️  Local version is ahead of GitHub by $AHEAD commit(s)"
        elif [[ "$BEHIND" -gt 0 ]]; then
            echo "⚠️  Local version is behind GitHub by $BEHIND commit(s)"
        else
            echo "✅ You have the latest documentation"
        fi
    fi
    
    # Show current branch and version
    cd "$DOCS_PATH" 2>/dev/null || exit 1
    local BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    echo "📍 Branch: ${BRANCH}"
    echo "📦 Version: ${SCRIPT_VERSION}"
}

# Function to read documentation
read_doc() {
    local topic=$(sanitize_input "$1")
    
    # Strip .md extension if user included it (they're being helpful!)
    topic="${topic%.md}"
    
    local doc_path="$DOCS_PATH/docs/${topic}.md"
    
    if [[ -f "$doc_path" ]]; then
        print_doc_header
        
        # Quick check if we're up to date (0.37s)
        cd "$DOCS_PATH" 2>/dev/null || exit 1
        local BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
        local VERSION=$SCRIPT_VERSION
        
        # Do the fetch to check status
        local COMPARE_BRANCH="$BRANCH"
        if ! git fetch --quiet origin "$BRANCH" 2>/dev/null; then
            # Try main if current branch doesn't exist on origin
            if git fetch --quiet origin main 2>/dev/null; then
                COMPARE_BRANCH="main"
            else
                echo "⚠️  Could not check GitHub for updates - using cached docs (v$VERSION, $BRANCH)"
                echo ""
                cat "$doc_path"
                echo ""
                echo "📖 Official page: https://docs.anthropic.com/en/docs/claude-code/$topic"
                return
            fi
        fi
        
        local LOCAL=$(git rev-parse HEAD 2>/dev/null)
        local REMOTE=$(git rev-parse origin/"$COMPARE_BRANCH" 2>/dev/null)
        local BEHIND=$(git rev-list HEAD..origin/"$COMPARE_BRANCH" --count 2>/dev/null || echo "0")
        
        if [[ "$LOCAL" != "$REMOTE" ]] && [[ "$BEHIND" -gt 0 ]]; then
            # We're behind - safe to update
            echo "🔄 Updating to latest documentation..."
            git pull --quiet origin "$COMPARE_BRANCH" 2>&1 | grep -v "Merge made by" || true
            
            # Check if installer needs updating
            local INSTALLER_VERSION=$SCRIPT_VERSION
            local VERSION_INT=$(echo "$INSTALLER_VERSION" | sed 's/^0\.//')
            
            if [[ $VERSION_INT -ge 3 ]]; then
                ./install.sh >/dev/null 2>&1
            fi
            echo "✅ Updated to latest (v$VERSION, $BRANCH)"
        else
            local AHEAD=$(git rev-list origin/"$COMPARE_BRANCH"..HEAD --count 2>/dev/null || echo "0")
            if [[ "$AHEAD" -gt 0 ]]; then
                echo "⚠️  Using local development version (v$VERSION, $BRANCH, +$AHEAD commits)"
            else
                echo "✅ You have the latest docs (v$VERSION, $BRANCH)"
            fi
        fi
        echo ""
        
        cat "$doc_path"
        echo ""
        if [[ "$topic" == "changelog" ]]; then
            echo "📖 Official source: https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md"
        else
            echo "📖 Official page: https://docs.anthropic.com/en/docs/claude-code/$topic"
        fi
    else
        # Always show search interface - never error messages
        print_doc_header
        echo "🔍 Searching for: $topic"
        echo ""
        
        # Try to extract keywords from the topic
        local keywords=$(echo "$topic" | grep -o '[a-zA-Z0-9_-]\+' | grep -v -E '^(tell|me|about|explain|what|is|are|how|do|to|show|find|search|the|for|in)$' | tr '\n' ' ')
        
        if [[ -n "$keywords" ]]; then
            # Search for matching topics - escape the pattern
            local escaped_keywords=$(echo "$keywords" | sed 's/[[\.*^$()+?{|]/\\&/g')
            local matches=$(ls "$DOCS_PATH/docs" | grep '\.md$' | sed 's/\.md$//' | grep -i -E "$(echo "$escaped_keywords" | tr ' ' '|')" | sort)
            
            if [[ -n "$matches" ]]; then
                echo "Found these related topics:"
                echo "$matches" | sed 's/^/  • /' 
                echo ""
                echo "Try: /docs <topic> to read a specific document"
            else
                echo "No exact matches found. Here are all available topics:"
                ls "$DOCS_PATH/docs" | grep '\.md$' | sed 's/\.md$//' | sort | column -c 80
            fi
        else
            echo "Available topics:"
            ls "$DOCS_PATH/docs" | grep '\.md$' | sed 's/\.md$//' | sort | column -c 80
        fi
        echo ""
        echo "💡 Tip: Use grep to search across all docs: cd ~/.claude-code-docs && grep -r 'search term' docs/"
    fi
}

# Function to list available documentation
list_docs() {
    print_doc_header
    
    # Auto-update to ensure fresh list
    auto_update
    
    echo "Available documentation topics:"
    echo ""
    ls "$DOCS_PATH/docs" | grep '\.md$' | sed 's/\.md$//' | sort | column -c 80
    echo ""
    echo "Usage: /docs <topic> or /docs -t to check freshness"
}

# Function for hook check (auto-update)
hook_check() {
    # This is now just a passthrough since auto_update handles everything
    # Note: We could potentially start a background fetch here for parallelization,
    # but since git fetch only takes ~0.37s, the complexity isn't worth it
    exit 0
}

# Function to show what's new (simplified version)
whats_new() {
    # Temporarily disable strict error handling for this function
    set +e
    
    print_doc_header
    
    # Auto-update first (synchronous - we need latest git history)
    auto_update || true  # Don't fail if auto-update fails
    
    cd "$DOCS_PATH" 2>/dev/null || {
        echo "❌ Error: Could not access documentation directory"
        return 1
    }
    
    echo "📚 Recent documentation updates:"
    echo ""
    
    # Get recent commits (simplified - just show all doc commits)
    local count=0
    
    # Show recent commits
    while IFS= read -r commit_line && [[ $count -lt 5 ]]; do
        local hash=$(echo "$commit_line" | cut -d' ' -f1)
        local date=$(git show -s --format=%cr "$hash" 2>/dev/null || echo "unknown")
        
        echo "• $date:"
        echo "  📎 https://github.com/wgs4/claude-code-docs/commit/$hash"
        
        # Show which docs changed
        local changed_docs=$(git diff-tree --no-commit-id --name-only -r "$hash" -- docs/*.md 2>/dev/null | sed 's|docs/||' | sed 's|\.md$||' | head -5)
        if [[ -n "$changed_docs" ]]; then
            echo "$changed_docs" | while read -r doc; do
                [[ -n "$doc" ]] && echo "  📄 $doc: https://docs.anthropic.com/en/docs/claude-code/$doc"
            done
        fi
        echo ""
        ((count++))
    done < <(git log --oneline -10 -- docs/*.md 2>/dev/null | grep -v "Merge" || true)
    
    if [[ $count -eq 0 ]]; then
        echo "No recent documentation updates found."
        echo ""
    fi
    
    echo "📎 Full changelog: https://github.com/wgs4/claude-code-docs/commits/main/docs"
    echo "📚 COMMUNITY MIRROR - NOT AFFILIATED WITH ANTHROPIC"
    
    # Re-enable strict error handling
    set -e
    
    # Ensure we always exit successfully
    return 0
}

# Function for uninstall
uninstall() {
    print_doc_header
    echo "To uninstall Claude Code Documentation Mirror"
    echo "==========================================="
    echo ""
    
    echo "This will remove:"
    echo "  • The /docs command from ~/.claude/commands/docs.md"
    echo "  • The auto-update hook from ~/.claude/settings.json"
    echo "  • The installation directory ~/.claude-code-docs"
    echo ""
    
    echo "Run this command in your terminal:"
    echo ""
    echo "  ~/.claude-code-docs/uninstall.sh"
    echo ""
    echo "Or to skip confirmation:"
    echo "  echo 'y' | ~/.claude-code-docs/uninstall.sh"
    echo ""
}

# Store original arguments for flag checking
FULL_ARGS="$*"

# Check if arguments start with -t flag (before sanitization)
if [[ "$FULL_ARGS" =~ ^-t([[:space:]]+(.*))?$ ]]; then
    show_freshness
    remaining_args="${BASH_REMATCH[2]}"
    if [[ "$remaining_args" =~ ^what.?s?[[:space:]]?new.*$ ]]; then
        echo ""
        whats_new
    elif [[ -n "$remaining_args" ]]; then
        echo ""
        read_doc "$(sanitize_input "$remaining_args")"
    fi
    exit 0
elif [[ "$FULL_ARGS" =~ ^--check([[:space:]]+(.*))?$ ]]; then
    show_freshness
    remaining_args="${BASH_REMATCH[2]}"
    if [[ "$remaining_args" =~ ^what.?s?[[:space:]]?new.*$ ]]; then
        echo ""
        whats_new
    elif [[ -n "$remaining_args" ]]; then
        echo ""
        read_doc "$(sanitize_input "$remaining_args")"
    fi
    exit 0
fi

# Main command handling
case "${1:-}" in
    -t|--check)
        show_freshness
        # Check if remaining args form "what's new"
        shift
        remaining_args="$*"
        if [[ "$remaining_args" =~ ^what.?s?[[:space:]]?new.*$ ]]; then
            echo ""
            whats_new
        elif [[ -n "$remaining_args" ]]; then
            echo ""
            read_doc "$(sanitize_input "$remaining_args")"
        fi
        ;;
    hook-check)
        hook_check
        ;;
    uninstall)
        uninstall
        ;;
    whats-new|whats|what)
        # Handle various forms of "what's new"
        shift
        remaining="$*"
        if [[ "$remaining" =~ new ]] || [[ "$FULL_ARGS" =~ what.*new ]]; then
            whats_new
        else
            # Just "what" without "new" - treat as doc lookup
            read_doc "$(sanitize_input "$1")"
        fi
        ;;
    "")
        list_docs
        ;;
    *)
        # Check if the full arguments match "what's new" pattern
        if [[ "$FULL_ARGS" =~ what.*new ]]; then
            whats_new
        else
            # Default: read documentation
            read_doc "$(sanitize_input "$1")"
        fi
        ;;
esac

# Ensure script always exits successfully
exit 0