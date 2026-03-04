---
name: disk-usage
description: Finds the biggest files and directories on disk, shows a full breakdown, and identifies cleanup opportunities. Use when the user asks about disk space, storage usage, what's taking up space, or needs to free up disk.
---

# Disk Usage Audit (macOS only)

Scan the entire disk to find where space is going and surface cleanup opportunities.

## Step 1: Get disk overview

Run these in parallel:

```bash
diskutil apfs list 2>/dev/null | head -30
```

```bash
df -h /
```

Extract: total capacity, used, free, and the Data volume consumed size from APFS output.

## Step 2: Top-level breakdown of the Data volume

```bash
du -sh /System/Volumes/Data/*/ 2>/dev/null | sort -hr | head -15
```

This shows where the bulk lives: Users, Library, Applications, private, opt, etc.

## Step 3: Break down the home directory

Run these in parallel:

```bash
du -sh ~/*/ 2>/dev/null | sort -hr | head -20
```

```bash
du -sh ~/.*/ 2>/dev/null | sort -hr | head -20
```

## Step 4: Drill into the big ones

For each directory over 10G from Step 3 (directories below this rarely warrant drilling), drill one level deeper with `du -sh <dir>/*/ 2>/dev/null | sort -hr | head -15`. Run these in parallel as needed.

If any `du` command hangs for more than 10 seconds, kill it and skip that path — it is likely a network mount.

Always drill into `~/Library` regardless of size, using these in parallel:

```bash
du -sh ~/Library/*/ 2>/dev/null | sort -hr | head -15
```

```bash
du -sh ~/Library/Caches/*/ 2>/dev/null | sort -hr | head -15
```

```bash
for d in ~/Library/Application\ Support/*/; do du -sh "$d" 2>/dev/null; done | sort -hr | head -20
```

```bash
du -sh ~/Library/Containers/*/ 2>/dev/null | sort -hr | head -10
```

```bash
du -sh ~/Library/Developer/*/ 2>/dev/null | sort -hr | head -10
```

For each `~/Library/Application Support` subdirectory over 1G, drill one level deeper:

```bash
for d in ~/Library/Application\ Support/<subdir>/*/; do du -sh "$d" 2>/dev/null; done | sort -hr | head -10
```

Run these in parallel as needed.

## Step 5: Find large individual files

Files over 200M are meaningful space hogs; the 100M threshold for media/archives catches bulky downloads without noise.

```bash
find ~ -type f -size +200M -not -path "*/.Trash/*" -not -path "*/.git/*" -not -path "*/node_modules/*" -exec ls -lh {} \; 2>/dev/null | sort -k5 -hr | head -30
```

```bash
find ~ -type f -size +100M \( -name "*.mp3" -o -name "*.mp4" -o -name "*.mov" -o -name "*.avi" -o -name "*.mkv" -o -name "*.wav" -o -name "*.flac" -o -name "*.m4a" -o -name "*.dmg" -o -name "*.pkg" -o -name "*.zip" -o -name "*.tar" -o -name "*.tar.gz" -o -name "*.iso" -o -name "*.rar" -o -name "*.7z" \) -exec ls -lh {} \; 2>/dev/null | sort -k5 -hr | head -20
```

## Step 6: Dev environment scans

Run these in parallel:

```bash
# node_modules hogs
find ~ -maxdepth 5 -name node_modules -type d -prune -exec du -sh {} \; 2>/dev/null | sort -hr | head -15
```

```bash
# Large .git directories
find ~ -maxdepth 5 -name .git -type d -prune -exec du -sh {} \; 2>/dev/null | sort -hr | head -15
```

```bash
# Docker (if installed)
docker system df 2>/dev/null
```

```bash
# Homebrew cache
du -sh "$(brew --cache 2>/dev/null)" 2>/dev/null
brew cleanup --dry-run 2>/dev/null | tail -5
```

```bash
# Nix store (if present)
du -sh /nix/store 2>/dev/null
```

```bash
# Language version managers — these accumulate old versions quietly
du -sh ~/.rvm 2>/dev/null
du -sh ~/.rbenv/versions/*/ 2>/dev/null
du -sh ~/.pyenv/versions/*/ 2>/dev/null
du -sh ~/.nvm/versions/*/ 2>/dev/null
du -sh ~/.volta 2>/dev/null
du -sh ~/.rustup/toolchains/*/ 2>/dev/null
du -sh ~/.sdkman/candidates/*/ 2>/dev/null
du -sh ~/.jenv/versions/*/ 2>/dev/null
du -sh ~/.goenv/versions/*/ 2>/dev/null
du -sh ~/.asdf/installs/*/ 2>/dev/null
```

## Step 7: Check for Time Machine snapshots and purgeable space

```bash
tmutil listlocalsnapshots / 2>/dev/null
tmutil listlocalsnapshots /System/Volumes/Data 2>/dev/null
```

## Step 8: Present the report

Display a **summary table** showing:

| Location | Size | What |
|---|---|---|
| (each major directory) | (size) | (short description) |

Then a **cleanup opportunities** section listing actionable items with estimated savings, sorted by size descending.

For each opportunity, provide the exact cleanup command. Use these references:

| Opportunity | Command |
|---|---|
| Xcode DerivedData | `trash ~/Library/Developer/Xcode/DerivedData` |
| Old Xcode simulators | `xcrun simctl delete unavailable` |
| Homebrew cache | `brew cleanup --prune=all` |
| npm cache | `npm cache clean --force` |
| yarn cache | `yarn cache clean` |
| pnpm cache | `pnpm store prune` |
| Docker unused data | `docker system prune -a` |
| Specific node_modules | `trash <path>/node_modules` (can reinstall with `npm install`) |
| Nix garbage collection | `nix-collect-garbage -d` |
| Playwright browsers | `npx playwright install --dry-run` then `trash ~/Library/Caches/ms-playwright` |
| Cypress cache | `trash ~/Library/Caches/Cypress` |
| Old installer DMGs/ZIPs | `trash <path>` |
| Large media in Downloads | `trash <path>` |
| Local LLM models (Ollama) | `ollama rm <model>` or `trash ~/.ollama/models` |
| Local LLM models (Jan/LM Studio) | `trash ~/Library/Application\ Support/Jan/models` / `trash ~/.cache/lm-studio` |
| Old RVM rubies | `rvm remove <version>` or `trash ~/.rvm` |
| Old rbenv versions | `rbenv uninstall <version>` |
| Old pyenv versions | `pyenv uninstall <version>` |
| Old nvm versions | `nvm uninstall <version>` |
| Old Rust toolchains | `rustup toolchain uninstall <version>` |
| Old SDKMAN candidates | `sdk uninstall <candidate> <version>` |
| Old asdf versions | `asdf uninstall <plugin> <version>` |
| Volta cache | `trash ~/.volta/tools/image` |
| Time Machine local snapshots | `sudo tmutil deletelocalsnapshots <date>` |

Only list opportunities that were actually found in the scan. Do not list cleanup commands for things that don't exist or are already small.

IMPORTANT: Do NOT run any cleanup or deletion commands. Only present them to the user. This skill is read-only — it scans and reports, the user decides what to act on.
