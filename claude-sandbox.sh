claude-sandbox() {
    local compose_file="$HOME/Others/programs/claude-sandbox/docker-compose.yml"

    local env_claude_dir=""
    local env_settings=""
    local env_credentials=""
    local env_skills=""
    local env_commands=""
    local env_agents=""
    local env_hooks=""

    local mnt_claude_dir=""
    local mnt_settings=""
    local mnt_credentials=""
    local mnt_skills=""
    local mnt_commands=""
    local mnt_agents=""
    local mnt_hooks=""

    local -a docker_args=()
    local -a env_args=()
    local -a cmd_args=()
    
    # -czf - must come first for strict tar implementations
    local -a tar_args=("-czf" "-")
    local -a tar_inputs=()
    local gnu_tar=0
    
    # 1. Robust GNU tar detection (checking both stdout/stderr on the first line)
    if tar --version 2>&1 | head -n 1 | grep -qi 'gnu tar'; then
        gnu_tar=1
    fi

    local type field value
    local src env_val mnt_val
    local sandbox_b64=""
    local name dummy

    get_env_value() {
        case "$1" in
            settings) echo "$env_settings" ;;
            credentials) echo "$env_credentials" ;;
            skills) echo "$env_skills" ;;
            commands) echo "$env_commands" ;;
            agents) echo "$env_agents" ;;
            hooks) echo "$env_hooks" ;;
        esac
    }

    get_mnt_value() {
        case "$1" in
            settings) echo "$mnt_settings" ;;
            credentials) echo "$mnt_credentials" ;;
            skills) echo "$mnt_skills" ;;
            commands) echo "$mnt_commands" ;;
            agents) echo "$mnt_agents" ;;
            hooks) echo "$mnt_hooks" ;;
        esac
    }

    add_to_tar() {
        local src_path="$1"
        local dest_path="$2"
        
        local parent base esc_base
        
        parent="$(cd "$(dirname "$src_path")" 2>/dev/null && pwd)" || return 1
        base="$(basename "$src_path")"

        # Escape standard BRE special characters in basename
        esc_base="$base"
        esc_base="${esc_base//\\/\\\\}"
        esc_base="${esc_base//./\\.}"
        esc_base="${esc_base//\*/\\*}"
        esc_base="${esc_base//\[/\\[}"
        esc_base="${esc_base//\]/\\]}"
        esc_base="${esc_base//^/\\^}"
        esc_base="${esc_base//\$/\\\$}"
        
        
        if [[ "$gnu_tar" -eq 1 ]]; then
            tar_args+=("--transform=s|^${esc_base}|${dest_path}|")
        else
            tar_args+=("-s" "|^${esc_base}|${dest_path}|")
        fi
        
        # -C and the base must remain paired sequentially so that 
        # multiple directories don't overwrite each other's working path.
        tar_inputs+=(
            "-C" 
            "$parent" 
            "$base"
        )
    }

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help)
                cat <<'EOF'
Usage:
  claude-sandbox [OPTIONS] [CLAUDE_ARGS...]

Sandbox options:

  --sandbox-env-claude-dir PATH
  --sandbox-mnt-claude-dir PATH

  --sandbox-env-settings PATH
  --sandbox-mnt-settings PATH

  --sandbox-env-credentials PATH
  --sandbox-mnt-credentials PATH

  --sandbox-env-skills PATH
  --sandbox-mnt-skills PATH

  --sandbox-env-commands PATH
  --sandbox-mnt-commands PATH

  --sandbox-env-agents PATH
  --sandbox-mnt-agents PATH

  --sandbox-env-hooks PATH
  --sandbox-mnt-hooks PATH

Other arguments are passed to Claude CLI.
EOF
                return 0
                ;;

            --sandbox-env-*)
                type="env"
                field="${1#--sandbox-env-}"
                ;;

            --sandbox-mnt-*)
                type="mnt"
                field="${1#--sandbox-mnt-}"
                ;;

            --sandbox-*)
                shift
                [[ $# -gt 0 ]] && shift
                continue
                ;;

            *)
                cmd_args+=("$1")
                shift
                continue
                ;;
        esac

        field="${field//-/_}"

        if [[ $# -lt 2 ]]; then
            echo "Error: $1 requires a value" >&2
            return 1
        fi

        value="$2"

        case "$type:$field" in
            env:claude_dir) env_claude_dir="$value" ;;
            env:settings) env_settings="$value" ;;
            env:credentials) env_credentials="$value" ;;
            env:skills) env_skills="$value" ;;
            env:commands) env_commands="$value" ;;
            env:agents) env_agents="$value" ;;
            env:hooks) env_hooks="$value" ;;

            mnt:claude_dir) mnt_claude_dir="$value" ;;
            mnt:settings) mnt_settings="$value" ;;
            mnt:credentials) mnt_credentials="$value" ;;
            mnt:skills) mnt_skills="$value" ;;
            mnt:commands) mnt_commands="$value" ;;
            mnt:agents) mnt_agents="$value" ;;
            mnt:hooks) mnt_hooks="$value" ;;
        esac

        shift 2
    done

    # Conflict checks
    if [[ -n "$env_claude_dir" && -n "$mnt_claude_dir" ]]; then
        echo "Error: claude_dir cannot use env and mount together" >&2
        return 1
    fi

    for src in settings credentials skills commands agents hooks; do
        env_val="$(get_env_value "$src")"
        mnt_val="$(get_mnt_value "$src")"

        if [[ -n "$env_val" && -n "$mnt_val" ]]; then
            echo "Error: $src cannot use env and mount together" >&2
            return 1
        fi
    done

    if [[ -n "$env_claude_dir" || -n "$mnt_claude_dir" ]]; then
        for src in settings credentials skills commands agents hooks; do
            env_val="$(get_env_value "$src")"
            mnt_val="$(get_mnt_value "$src")"

            if [[ -n "$env_val" || -n "$mnt_val" ]]; then
                echo "Error: claude_dir cannot be combined with individual options" >&2
                return 1
            fi
        done
    fi

    # Validate paths
    for src in \
        "$env_claude_dir" "$env_settings" "$env_credentials" \
        "$env_skills" "$env_commands" "$env_agents" "$env_hooks" \
        "$mnt_claude_dir" "$mnt_settings" "$mnt_credentials" \
        "$mnt_skills" "$mnt_commands" "$mnt_agents" "$mnt_hooks"
    do
        if [[ -n "$src" && ! -e "$src" ]]; then
            echo "Error: '$src' does not exist" >&2
            return 1
        fi
    done

    # Prepare streaming transformations 
    if [[ -n "$env_claude_dir" ]]; then
        add_to_tar "$env_claude_dir" ".claude"
    else
        [[ -n "$env_settings" ]] &&         add_to_tar "$env_settings" ".claude/settings.json"
        [[ -n "$env_credentials" ]] && add_to_tar "$env_credentials" ".claude/.credentials.json"
        [[ -n "$env_skills" ]] && add_to_tar "$env_skills" ".claude/skills"
        [[ -n "$env_commands" ]] && add_to_tar "$env_commands" ".claude/commands"
        [[ -n "$env_agents" ]] && add_to_tar "$env_agents" ".claude/agents"
        [[ -n "$env_hooks" ]] && add_to_tar "$env_hooks" ".claude/hooks"
    fi

    # Package cleanly into memory
    if [[ ${#tar_inputs[@]} -gt 0 ]]; then
        sandbox_b64=$(
            tar "${tar_args[@]}" "${tar_inputs[@]}" 2>/dev/null |
            base64 |
            tr -d '\n\r'
        )
    fi

    # Mounts
    [[ -n "$mnt_claude_dir" ]] &&
        docker_args+=("-v" "$mnt_claude_dir:/home/ubuntu/.claude")

    [[ -n "$mnt_settings" ]] &&
        docker_args+=("-v" "$mnt_settings:/home/ubuntu/.claude/settings.json:ro")

    [[ -n "$mnt_credentials" ]] &&
        docker_args+=("-v" "$mnt_credentials:/home/ubuntu/.claude/.credentials.json:ro")

    [[ -n "$mnt_skills" ]] &&
        docker_args+=("-v" "$mnt_skills:/home/ubuntu/.claude/skills:ro")

    [[ -n "$mnt_commands" ]] &&
        docker_args+=("-v" "$mnt_commands:/home/ubuntu/.claude/commands:ro")

    [[ -n "$mnt_agents" ]] &&
        docker_args+=("-v" "$mnt_agents:/home/ubuntu/.claude/agents:ro")

    [[ -n "$mnt_hooks" ]] &&
        docker_args+=("-v" "$mnt_hooks:/home/ubuntu/.claude/hooks:ro")

    # Forward environment safely without special shell variables
    while IFS='=' read -r name dummy; do
        case "$name" in
            ANTHROPIC_*|CLAUDE_*)
                env_args+=("-e" "$name")
                ;;
        esac
    done < <(env)

    [[ -n "$sandbox_b64" ]] &&
        env_args+=(
            "-e"
            "SANDBOX_CLAUDE_B64=$sandbox_b64"
        )
        
    # Safely clear scoped functions to avoid lingering in the current user session
    unset -f get_env_value 2>/dev/null
    unset -f get_mnt_value 2>/dev/null
    unset -f add_to_tar 2>/dev/null

    docker compose \
        -f "$compose_file" \
        run \
        --rm \
        "${env_args[@]}" \
        "${docker_args[@]}" \
        -v .:/workspace \
        claude-sandbox \
        claude "${cmd_args[@]}"
}
