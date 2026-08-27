---
name: new-profile
description: Interactively creates a new Claude Code account profile — asks for a name, a short command, an optional emoji, and an optional hex color, then generates profiles.d/<name>.conf and re-runs install.sh. Trigger on requests like "create a new Claude profile", "add another Claude account", "guide me through setting up a profile", "I need a second account configured" — in any language, since intent matters more than exact wording.
---

# Create a new Claude Code account profile

This repo supports multiple named account profiles (e.g. `claude work`,
`claude personal`), each backed by its own `CLAUDE_CONFIG_DIR` and its own
label/color on the statusline. Adding one is a short interview.

## Interview

Ask ONE question at a time, in this exact order. Don't move to the next
question until the current one is answered.

### 1. Profile name
"What name do you want for this account?"
- Normalize: lowercase, spaces become hyphens.
- Reject if `profiles.d/<name>.conf` already exists — ask for a different name.

### 2. Command
"What short command should open this account? (`claude <that>`)"
- If they have no preference, suggest the first letter of the name.
- Recommend a single letter — it avoids colliding with real `claude` CLI
  subcommands (`mcp`, `config`, `doctor`, ...) without needing a reserved list.
- Reject if another `profiles.d/*.conf` already uses that `PROFILE_COMMAND`.

### 3. Emoji (optional)
"Want an emoji to identify this account on the statusline? You can skip this."
- If skipped, the label is just the plain name.

### 4. Color (optional)
"Want to give this account a specific hex color, or should I pick one that's
not already in use?"
- Accept the hex with or without a leading `#`.
- If they have no preference, pick the next unused color from the default
  palette below.

Default palette, in order — skip any hex already used by another profile:
`FF8700`, `005FD7`, `00AF5F`, `D75FD7`, `5FD7FF`, `D70000`.

## After collecting the answers

1. Write `profiles.d/<name>.conf`:
   ```bash
   PROFILE_NAME="<name>"
   PROFILE_COMMAND="<command>"
   PROFILE_CONFIG_DIR="$HOME/.claude-<name>"
   PROFILE_LABEL="<emoji> <Name>"   # or just "<Name>" if no emoji was given
   PROFILE_COLOR="<hex, no leading #>"
   PROFILE_IS_DEFAULT=false
   PROFILE_EXTRA_CLAUDE_FLAGS=""
   ```
2. Run `install.sh` from the repo root.
3. Confirm: `claude <command>` should now work. Mention what the statusline
   segment will look like (label + color) so they can sanity-check it.

Never set `PROFILE_IS_DEFAULT=true` on a new profile without the user
explicitly asking to change which account plain `claude` (no argument)
opens — that reassignment affects their existing default account.
