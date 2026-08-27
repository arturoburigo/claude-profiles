# Onboarding

This file is meant to be read and executed by an agent (Claude Code itself),
not just a human. If you're an agent reading this because someone asked you
to set up their `claude-profiles` repo, follow the steps below in order.

## 1. Check dependencies

Confirm `git`, `jq`, and `awk` are on `PATH`. If any is missing, tell the
user what to install (`brew install jq` on macOS, the distro's package
manager on Linux) and stop — don't try to install things for them.

## 2. Set up secrets

Check whether `.env` exists at the repo root.
- If not, copy `.env.example` to `.env` and ask the user for the real
  values (currently just `SOURCEBOT_TOKEN`) — or confirm they want to leave
  it blank if they don't use that integration.

## 3. Run the installer

```bash
./install.sh
```

This is idempotent — safe to run again later. It will:
- seed a default `personal` profile if `profiles.d/` is empty
- symlink `shared/CLAUDE.md` and `shared/statusline-command.sh` into `~/.claude/`
- symlink every skill under `shared/skills/` into `~/.claude/skills/`
- merge `env.SOURCEBOT_TOKEN` and `statusLine` from `settings.json.example` + `.env` into `~/.claude/settings.json` (other existing keys — hooks, permissions, enabledPlugins — are preserved, not replaced)
- mirror all of the above into every other profile's config dir (e.g. `~/.claude-work`)
- install/update the `claude()` function in `~/.zshrc` and `~/.bashrc`

If any of those targets already have real (non-symlink) content, `install.sh`
backs it up next to itself (`<file>.bak.<timestamp>`) before replacing it —
tell the user where the backups landed.

## 4. Verify

- Open a new shell (or `exec $SHELL`).
- Run `claude --version` — should work with no `CLAUDE_CONFIG_DIR` set.
- Check the statusline shows the profile's label and color.

## 5. Adding more accounts later

The `new-profile` skill is already installed after step 3 — from now on,
whenever the user asks to add another account ("create a new Claude
profile", "I need a second account configured", etc.), that skill runs the
interview and wires it up. You don't need to repeat these steps by hand.
