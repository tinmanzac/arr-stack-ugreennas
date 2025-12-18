#!/bin/bash
# Hardcoded domain/hostname detection
# Scans ALL tracked files in repo (not just staged) for security
# Reads domain from .env or .env.nas.backup, hostname from .claude/config.local.md

check_hardcoded_domain() {
    local warnings=0
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || repo_root="."

    local env_file="$repo_root/.env"
    local env_backup="$repo_root/.env.nas.backup"
    local config_local="$repo_root/.claude/config.local.md"

    # Use .env.nas.backup as fallback for local development
    local secrets_file=""
    if [[ -f "$env_file" ]]; then
        secrets_file="$env_file"
    elif [[ -f "$env_backup" ]]; then
        secrets_file="$env_backup"
    fi

    # Try to find NAS hostname from config.local.md
    local nas_hostname=""
    if [[ -f "$config_local" ]]; then
        nas_hostname=$(grep -oE '[a-zA-Z0-9_-]+\.local' "$config_local" 2>/dev/null | head -1 | sed 's/\.local$//')
    fi

    # Extract domain from secrets file
    local domain=""
    if [[ -n "$secrets_file" ]]; then
        domain=$(grep -E '^DOMAIN=' "$secrets_file" 2>/dev/null | cut -d= -f2 | tr -d '"' | tr -d "'")
    fi

    # Check both staged files AND all tracked files in the repo
    # This ensures we catch issues even if commits slipped through before
    local staged_files
    staged_files=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -v '^\.env$')

    local all_tracked_files
    all_tracked_files=$(git ls-files 2>/dev/null | grep -v '^\.env$')

    # Combine and deduplicate
    local files_to_check
    files_to_check=$(echo -e "$staged_files\n$all_tracked_files" | sort -u | grep -v '^$')

    if [[ -z "$files_to_check" ]]; then
        return 0
    fi

    # Check for domain if configured
    if [[ -n "$domain" && "$domain" != "yourdomain.com" ]]; then
        local files_with_domain=""
        for file in $files_to_check; do
            # Get file content (read actual file, not just staged version)
            local content
            content=$(cat "$file" 2>/dev/null) || continue

            # Skip binary files
            case "$file" in
                *.png|*.jpg|*.gif|*.ico|*.woff|*.ttf|*.svg) continue ;;
            esac

            # Check for domain (case insensitive)
            if echo "$content" | grep -qi "$domain" 2>/dev/null; then
                local count
                count=$(echo "$content" | grep -ci "$domain" 2>/dev/null || echo 0)
                files_with_domain+="      - $file ($count occurrences)"$'\n'
                ((warnings++))
            fi
        done

        if [[ -n "$files_with_domain" ]]; then
            echo "    WARNING: Your domain '$domain' is hardcoded in tracked files:"
            echo "$files_with_domain"
            echo "    Note: Some files (like Traefik dynamic configs) can't use \${DOMAIN}"
            echo "          Review to ensure this is intentional."
        fi
    else
        if [[ -z "$secrets_file" ]]; then
            echo "    SKIP: No .env or .env.nas.backup (can't determine domain)"
        else
            echo "    SKIP: No custom domain in $secrets_file"
        fi
    fi

    # Check for NAS hostname (BLOCKS - this should never be committed)
    if [[ -n "$nas_hostname" ]]; then
        local files_with_hostname=""
        local hostname_errors=0
        for file in $files_to_check; do
            local content
            content=$(cat "$file" 2>/dev/null) || continue

            # Skip binary files
            case "$file" in
                *.png|*.jpg|*.gif|*.ico|*.woff|*.ttf|*.svg) continue ;;
            esac

            # Check for hostname (case insensitive)
            if echo "$content" | grep -qi "$nas_hostname" 2>/dev/null; then
                local count
                count=$(echo "$content" | grep -ci "$nas_hostname" 2>/dev/null || echo 0)
                files_with_hostname+="      - $file ($count occurrences)"$'\n'
                ((hostname_errors++))
            fi
        done

        if [[ -n "$files_with_hostname" ]]; then
            echo "    ERROR: NAS hostname '$nas_hostname' found in tracked files:"
            echo "$files_with_hostname"
            echo "    This is private info and should not be committed."
            return 1
        fi
    fi

    # Output OK if we checked something and found no issues
    if [[ $warnings -eq 0 && -n "$domain" && "$domain" != "yourdomain.com" ]]; then
        echo "    OK: No hardcoded domain/hostname found"
    fi

    return 0
}
