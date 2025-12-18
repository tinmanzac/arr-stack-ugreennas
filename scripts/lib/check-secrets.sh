#!/bin/bash
# Secret detection for pre-commit hook
# Scans ALL tracked files in repo (not just staged) for security

check_secrets() {
    local errors=0

    # Check both staged files AND all tracked files in the repo
    # This ensures we catch secrets even if commits slipped through before
    local staged_files
    staged_files=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null)

    local all_tracked_files
    all_tracked_files=$(git ls-files 2>/dev/null)

    # Combine and deduplicate
    local files_to_check
    files_to_check=$(echo -e "$staged_files\n$all_tracked_files" | sort -u | grep -v '^$')

    if [[ -z "$files_to_check" ]]; then
        return 0
    fi

    for file in $files_to_check; do
        # Skip binary files, .env, and the check scripts themselves (contain example patterns)
        case "$file" in
            *.png|*.jpg|*.gif|*.ico|*.woff|*.woff2|*.ttf|*.eot) continue ;;
            .env) continue ;;  # .env should be gitignored anyway
            scripts/lib/check-*.sh) continue ;;  # These contain example patterns
            *.md) continue ;;  # Documentation may contain examples
        esac

        # Get file content (read actual file, not just staged version)
        local content
        content=$(cat "$file" 2>/dev/null) || continue

        # Pattern 1: WireGuard private key (44-char base64 ending in =)
        # Real: oK7kZv8RGqDN2P0LT0w9D4xXU7MkL5R3tN6Y8W2B1C4=
        # Placeholder: your_wireguard_private_key_here
        if echo "$content" | grep -qE '(WIREGUARD_PRIVATE_KEY|PRIVATE_KEY)=[A-Za-z0-9+/]{40,}=' 2>/dev/null; then
            # Check it's not a placeholder
            local match
            match=$(echo "$content" | grep -oE '(WIREGUARD_PRIVATE_KEY|PRIVATE_KEY)=[A-Za-z0-9+/]{40,}=')
            if ! echo "$match" | grep -qiE '(your|here|example|placeholder|xxx)'; then
                echo "    ERROR: Possible WireGuard private key in $file"
                ((errors++))
            fi
        fi

        # Pattern 2: Cloudflare API token (alphanumeric, 35-45 chars)
        if echo "$content" | grep -qE 'CF_DNS_API_TOKEN=[A-Za-z0-9_-]{35,45}$' 2>/dev/null; then
            local match
            match=$(echo "$content" | grep -oE 'CF_DNS_API_TOKEN=[A-Za-z0-9_-]{35,45}$')
            if ! echo "$match" | grep -qiE '(your|here|example|placeholder|xxx|token)'; then
                echo "    ERROR: Possible Cloudflare API token in $file"
                ((errors++))
            fi
        fi

        # Pattern 3: Cloudflare tunnel token (JWT format)
        if echo "$content" | grep -qE 'TUNNEL_TOKEN=eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+' 2>/dev/null; then
            echo "    ERROR: Possible Cloudflare tunnel token in $file"
            ((errors++))
        fi

        # Pattern 4: Real bcrypt hashes (60 chars after $2a$XX$ or $2y$XX$)
        # Real: $2a$12$KxRq9R3vIJh4eAbCdEfGh.IJkLmNoPqRsTuVwXyZ01234567890
        # Placeholder: $2a$12$your_bcrypt_hash_here
        if echo "$content" | grep -qE '\$2[aby]\$[0-9]{2}\$[A-Za-z0-9./]{50,}' 2>/dev/null; then
            local match
            match=$(echo "$content" | grep -oE '\$2[aby]\$[0-9]{2}\$[A-Za-z0-9./]{50,}')
            if ! echo "$match" | grep -qiE '(your|here|example|placeholder)'; then
                echo "    ERROR: Possible bcrypt password hash in $file"
                ((errors++))
            fi
        fi

        # Pattern 5: PEM private key blocks
        if echo "$content" | grep -qE '^-----BEGIN (RSA |EC |OPENSSH |DSA |)PRIVATE KEY-----' 2>/dev/null; then
            echo "    ERROR: Private key block detected in $file"
            ((errors++))
        fi

        # Pattern 6: Generic high-entropy secrets (long base64 in value position)
        # Catches: SECRET=aGVsbG8gd29ybGQgdGhpcyBpcyBhIHRlc3Q=
        if echo "$content" | grep -qE '(PASSWORD|SECRET|API_KEY)=[A-Za-z0-9+/=]{30,}$' 2>/dev/null; then
            local match
            match=$(echo "$content" | grep -oE '(PASSWORD|SECRET|API_KEY)=[A-Za-z0-9+/=]{30,}$')
            if ! echo "$match" | grep -qiE '(your|here|example|placeholder|xxx)'; then
                echo "    WARNING: Possible secret value in $file"
                ((errors++))
            fi
        fi
    done

    return $errors
}
