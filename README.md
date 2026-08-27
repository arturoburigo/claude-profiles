# claude-profiles

Multi-account setup for [Claude Code](https://claude.com/claude-code): switch
between named accounts (`claude work`, `claude personal`, ...) with one shell
function, each with its own color-coded label on the statusline — plus a
shared `CLAUDE.md` and statusline script kept in sync across every account.

## Why

Claude Code has no native multi-account support — logging in under a
different `CLAUDE_CONFIG_DIR` gets you a second account, but nothing wires up
switching between them or keeps your config in sync. This repo is that
wiring: one canonical copy of your shared config, symlinked into every
account's config directory, plus a generated shell function to jump between
them.

## Quickstart

```bash
git clone <this-repo> ~/claude-profiles
cd ~/claude-profiles
cp .env.example .env        # fill in SOURCEBOT_TOKEN or remove the line if unused
./install.sh
exec $SHELL                 # reload your shell to pick up the claude() function
```

The first run seeds a single `personal` profile pointed at `~/.claude` (see
`profiles.d/personal.conf.example`). From then on, `claude` opens that
account, and `claude p` does too, explicitly.

## Adding another account

Ask Claude Code itself — the `new-profile` skill (shipped in this repo and
installed by `install.sh`) walks you through it:

> me guide the creation of a new Claude profile

It asks for a name, a short command, an optional emoji, and an optional hex
color, then writes `profiles.d/<name>.conf` and re-runs `install.sh` for you.
See `ONBOARDING.md` for the full setup walkthrough.

## Layout

```
install.sh                       idempotent installer — safe to re-run anytime
shared/CLAUDE.md                 symlinked into every account's config dir
shared/statusline-command.sh     symlinked into every account's config dir
shared/skills/new-profile/       the interactive "add a profile" skill
profiles.d/*.conf.example        profile templates (real *.conf is gitignored)
settings.json.example            template — the real settings.json is generated,
                                  never committed (it can hold secrets)
.env.example                     secrets go here locally, never in git
```

## How switching works

`install.sh` generates a `claude()` shell function from `profiles.d/*.conf`
and installs it into `~/.zshrc`/`~/.bashrc` between marker comments, so
re-running it updates the function instead of duplicating it. Each profile
maps a short command to `CLAUDE_CONFIG_DIR=<its config dir> claude`; the
profile marked `PROFILE_IS_DEFAULT=true` is what plain `claude` (no command)
resolves to.

## Status

Private for now. The plan is to open this up once the templates are solid
enough for someone else to configure their own profiles without editing the
scripts.
