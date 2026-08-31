# cachy-orphan

A safer, interactive replacement for `pacman -Qtd` on Arch/CachyOS. Reviews
orphaned packages one at a time, shows you why removal might (or might not)
be safe, and keeps lightweight records so removals can be undone later.

Pacman remains the source of truth for installed/orphan state — this tool
only tracks its own decisions (kept, removed) alongside it.

## Installation

Copy `cachy-orphan` to `~/.local/bin`

>[!NOTE]
> You may need to add `~/.local/bin` to your shells path

## Usage

```bash
cachy-orphan                 # interactively review current orphans
```

For each orphan you'll see version, repo, install reason, reverse
dependencies (via `pactree`), and recent `pacman.log` history, then choose:

| Key | Action |
|-----|--------|
| `S` | Skip — do nothing, ask again next time |
| `K` | Keep — mark explicit + remember permanently, never flagged again |
| `R` | Remove — optional Snapper snapshot, shows the transaction, asks to confirm |
| `Q` | Quit the session |

## Commands

```bash
cachy-orphan --keep <pkg>              # mark as explicit + kept
cachy-orphan --unkeep <pkg>            # reverse --keep (does not remove pkg)
cachy-orphan --remove <pkg>            # remove a single orphan directly

cachy-orphan --list-kept [FILTER]
cachy-orphan --list-removed [FILTER]

cachy-orphan --restore                 # restore the most recent removal batch
cachy-orphan --restore <pkg>           # restore one package
cachy-orphan --restore --all
cachy-orphan --restore --last <N|DUR>
cachy-orphan --restore --date YYYY-MM-DD

cachy-orphan --cleanup                 # purge expired removal records now
cachy-orphan --help
```

`FILTER` (for `--list-kept` / `--list-removed` / `--restore`):
`<pkg>` · `--all` (removed only) · `--last N` · `--last <duration>` · `--date YYYY-MM-DD`

Lists are always newest-first.

## Kept vs. removed

- **Kept** (`~/.local/share/cachy-orphan/kept/`) — permanent until you run
  `--unkeep`. Marks the package explicit in pacman so it stops appearing as
  an orphan.
- **Removed** (`~/.local/share/cachy-orphan/removed/`) — a restoration
  record, one file per package, auto-expires after `REMOVED_RETENTION`
  (default 90 days). Restoring reinstalls whatever version is currently in
  the repos, not necessarily the exact removed version.

If a package listed via `--restore` is already installed (e.g. you
reinstalled it manually), the tool tells you and offers to just drop the
stale record instead of touching pacman.

## Configuration

First run creates `~/.config/cachy-orphan/config` with the defaults below.
Edit it to change behaviour — it's never overwritten once it exists.

```bash
REMOVED_RETENTION="90d"       # how long removal records stay restorable
DEFAULT_LIST_RANGE="21d"      # default window for `--list-removed`
RESTORE_GROUP_WINDOW="30m"    # grouping window for bare `--restore`
AUTOMATIC_CLEANUP="true"      # purge expired records on every run
```

Duration format: a number + `s`/`m`/`h`/`d`/`w` (seconds/minutes/hours/days/weeks).

## Safety notes

- Nothing is removed or restored without an explicit confirmation prompt.
- Failed pacman operations never create or delete records.
- Snapper snapshot offer only appears if Snapper + a `root` config are detected.
- Requires `sudo` for `--keep`, `--unkeep`, `--remove`, and `--restore`.
