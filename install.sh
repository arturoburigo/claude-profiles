#!/usr/bin/env bash
# Installs/updates this repo's shared Claude Code config (CLAUDE.md,
# statusline-command.sh, skills) and regenerates the `claude` account-switch
# shell function from profiles.d/*.conf. Safe to re-run — every step is
# idempotent and existing real files are backed up before being replaced.
set -Eeuo pipefail

readonly REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BASE_DIR="$HOME/.claude"
readonly PROFILES_DIR="$REPO_DIR/profiles.d"
readonly SHELL_BLOCK_BEGIN="# >>> claude-profiles >>>"
readonly SHELL_BLOCK_END="# <<< claude-profiles <<<"

log() { printf '%s\n' "$1"; }

require_dependency() {
	command -v "$1" >/dev/null 2>&1 || {
		echo "error: '$1' is required but not found in PATH." >&2
		exit 1
	}
}

# Symlinks source_path -> target_path. Backs up whatever already exists at
# target_path (real file or a symlink pointing somewhere else) instead of
# clobbering it, so a first run never loses existing config.
link_shared_item() {
	local source_path="$1" target_path="$2"

	if [ -L "$target_path" ] && [ "$(readlink "$target_path")" = "$source_path" ]; then
		log "  already linked: $target_path"
		return 0
	fi

	if [ -e "$target_path" ] || [ -L "$target_path" ]; then
		local backup_path="${target_path}.bak.$(date +%Y%m%d%H%M%S)"
		mv "$target_path" "$backup_path"
		log "  backed up existing $target_path -> $backup_path"
	fi

	mkdir -p "$(dirname "$target_path")"
	ln -s "$source_path" "$target_path"
	log "  linked $target_path -> $source_path"
}

link_shared_files() {
	log "Linking shared config into $BASE_DIR..."
	link_shared_item "$REPO_DIR/shared/CLAUDE.md" "$BASE_DIR/CLAUDE.md"
	link_shared_item "$REPO_DIR/shared/statusline-command.sh" "$BASE_DIR/statusline-command.sh"

	local skill_dir
	for skill_dir in "$REPO_DIR"/shared/skills/*/; do
		[ -d "$skill_dir" ] || continue
		local skill_name
		skill_name="$(basename "$skill_dir")"
		link_shared_item "${skill_dir%/}" "$BASE_DIR/skills/$skill_name"
	done
}

# Profiles other than the default one (e.g. ~/.claude-betha) don't hold their
# own copy of the shared files — they mirror BASE_DIR, one hop away, the same
# way this was done by hand before this repo existed. Runs after
# render_settings_json so BASE_DIR/settings.json already exists to mirror.
mirror_shared_files_into_other_profiles() {
	local conf_file
	for conf_file in "$PROFILES_DIR"/*.conf; do
		[ -f "$conf_file" ] || continue
		local PROFILE_CONFIG_DIR=""
		# shellcheck source=/dev/null
		source "$conf_file"
		[ -z "$PROFILE_CONFIG_DIR" ] && continue
		[ "$PROFILE_CONFIG_DIR" = "$BASE_DIR" ] && continue

		log "Mirroring shared config into $PROFILE_CONFIG_DIR..."
		mkdir -p "$PROFILE_CONFIG_DIR"
		link_shared_item "$BASE_DIR/CLAUDE.md" "$PROFILE_CONFIG_DIR/CLAUDE.md"
		link_shared_item "$BASE_DIR/statusline-command.sh" "$PROFILE_CONFIG_DIR/statusline-command.sh"
		link_shared_item "$BASE_DIR/skills" "$PROFILE_CONFIG_DIR/skills"
		link_shared_item "$BASE_DIR/settings.json" "$PROFILE_CONFIG_DIR/settings.json"
	done
}

# settings.json can hold secrets (e.g. SOURCEBOT_TOKEN) and, on a machine
# with an existing Claude Code setup, real content this repo doesn't manage
# (hooks, permissions, enabledPlugins). So this MERGES the managed keys
# (env.SOURCEBOT_TOKEN, statusLine) from settings.json.example + .env into
# whatever is already at BASE_DIR/settings.json, instead of replacing it —
# and it's never symlinked, so the real file never touches git.
render_settings_json() {
	log "Rendering settings.json..."
	local env_file="$REPO_DIR/.env"

	if [ ! -f "$env_file" ]; then
		cp "$REPO_DIR/.env.example" "$env_file"
		log "  created $env_file from template — fill in your real values and re-run install.sh"
		return 0
	fi

	set -a
	# shellcheck source=/dev/null
	source "$env_file"
	set +a

	local target="$BASE_DIR/settings.json"
	local existing_json="{}"
	if [ -f "$target" ]; then
		existing_json="$(cat "$target")"
		cp "$target" "${target}.bak.$(date +%Y%m%d%H%M%S)"
	fi

	echo "$existing_json" | jq \
		--arg token "${SOURCEBOT_TOKEN:-}" \
		'.env.SOURCEBOT_TOKEN = $token
		 | .statusLine = {"type": "command", "command": "~/.claude/statusline-command.sh"}' \
		>"$target"
	log "  merged env.SOURCEBOT_TOKEN and statusLine into $target (other existing keys preserved)"
}

# profiles.d/*.conf is machine-local (gitignored) — a fresh clone starts
# empty. Seed it with a single default profile so `claude` works right away.
bootstrap_default_profile() {
	mkdir -p "$PROFILES_DIR"
	if ! ls "$PROFILES_DIR"/*.conf >/dev/null 2>&1; then
		cp "$REPO_DIR/profiles.d/personal.conf.example" "$PROFILES_DIR/personal.conf"
		log "  created $PROFILES_DIR/personal.conf from template"
	fi
}

# Builds the invocation for one profile: which env var override (if any) and
# extra flags it needs. Setting CLAUDE_CONFIG_DIR explicitly to ~/.claude
# would log out the account that already lives there and create a stub — so
# a profile pointed at ~/.claude must instead run with CLAUDE_CONFIG_DIR
# unset via `env -u`.
build_profile_invocation() {
	local config_dir="$1" extra_flags="$2"
	local flags=""
	[ -n "$extra_flags" ] && flags=" $extra_flags"

	if [ "$config_dir" = "$HOME/.claude" ]; then
		printf 'command env -u CLAUDE_CONFIG_DIR claude%s' "$flags"
	else
		printf 'CLAUDE_CONFIG_DIR=%q command claude%s' "$config_dir" "$flags"
	fi
}

generate_shell_function_block() {
	local case_body="" default_case_line=""
	local conf_file

	for conf_file in "$PROFILES_DIR"/*.conf; do
		[ -f "$conf_file" ] || continue

		local PROFILE_COMMAND="" PROFILE_CONFIG_DIR="" PROFILE_IS_DEFAULT="false" PROFILE_EXTRA_CLAUDE_FLAGS=""
		# shellcheck source=/dev/null
		source "$conf_file"

		local invocation
		invocation="$(build_profile_invocation "$PROFILE_CONFIG_DIR" "$PROFILE_EXTRA_CLAUDE_FLAGS")"

		case_body+=$(printf '\t%s) shift; %s "$@" ;;\n' "$PROFILE_COMMAND" "$invocation")
		case_body+=$'\n'

		if [ "$PROFILE_IS_DEFAULT" = "true" ]; then
			default_case_line=$(printf '\t*)        %s "$@" ;;' "$invocation")
		fi
	done

	cat <<SCRIPT
$SHELL_BLOCK_BEGIN
# Generated by install.sh from profiles.d/*.conf — do not edit by hand.
claude() {
	case "\$1" in
${case_body}${default_case_line}
	esac
}
$SHELL_BLOCK_END
SCRIPT
}

# Replaces the block between the markers (if present) and appends the fresh
# one — safe to run repeatedly without duplicating or losing the rest of the
# rc file's content.
update_shell_rc_block() {
	local rc_file="$1" new_block="$2"
	[ -f "$rc_file" ] || return 0

	cp "$rc_file" "${rc_file}.bak.$(date +%Y%m%d%H%M%S)"

	local tmp_file
	tmp_file=$(mktemp)
	if grep -qF "$SHELL_BLOCK_BEGIN" "$rc_file"; then
		awk -v begin="$SHELL_BLOCK_BEGIN" -v end="$SHELL_BLOCK_END" '
			$0 == begin {skip=1}
			!skip {print}
			$0 == end {skip=0}
		' "$rc_file" >"$tmp_file"
	else
		cp "$rc_file" "$tmp_file"
	fi

	{
		cat "$tmp_file"
		echo
		printf '%s\n' "$new_block"
	} >"$rc_file"
	rm -f "$tmp_file"
	log "  updated $rc_file"
}

install_shell_function() {
	log "Updating the claude() shell function..."
	local block
	block="$(generate_shell_function_block)"
	update_shell_rc_block "$HOME/.zshrc" "$block"
	update_shell_rc_block "$HOME/.bashrc" "$block"
}

main() {
	require_dependency jq
	require_dependency git
	require_dependency awk

	bootstrap_default_profile
	link_shared_files
	render_settings_json
	mirror_shared_files_into_other_profiles
	install_shell_function

	log ""
	log "Done. Open a new shell (or run 'exec \$SHELL') to pick up the claude() function."
}

main
