# conduct

**Run Claude Code / Codex in parallel, each in its own isolated git worktree — from the terminal.**

`conduct` is a small, dependency-light shell tool that reproduces the core workflow of
[Conductor](https://www.conductor.build) (the desktop app) without a GUI. Type
`conduct` inside any git repo and it will:

1. **`git fetch origin`** and branch a fresh **git worktree** off the latest default branch,
2. name the worktree after a random **city** (e.g. `lisbon`, `kyoto`) and create a `conduct/<city>` branch,
3. run your **setup** command (install deps, copy `.env`, …) in that worktree,
4. start your **dev server in the background** on its own dedicated **port** (so worktrees never collide),
5. drop you into **Claude Code** (or **Codex** with `--codex`) in the foreground.

Open a second terminal, run `conduct` again, and you get a *second* worktree on a
*different* port with a *different* branch — running side by side, fully isolated. When
the agent exits, `conduct` offers a teardown menu (keep / stop / open PR / remove).

---

## Table of contents

- [Why](#why)
- [Concepts](#concepts)
- [Install](#install)
- [Quick start](#quick-start)
- [Commands](#commands)
- [Configuration (`.conduct.conf`)](#configuration-conductconf)
- [How it works](#how-it-works)
- [Directory layout](#directory-layout)
- [Requirements](#requirements)
- [Troubleshooting](#troubleshooting)
- [Distribution via Homebrew (future)](#distribution-via-homebrew-future)
- [Limitations & notes](#limitations--notes)

---

## Why

When you run several AI coding agents at once, they fight over the same working tree,
the same branch, and the same dev-server port. Conductor solves this with isolated
**workspaces**; `conduct` does the same thing with plain **git worktrees** and a few
conventions, so you can stay in your terminal and use whatever agent CLI you like.

Each session is one worktree = one branch = one task = (eventually) one PR.

## Concepts

| Concept | What it means in `conduct` |
|---|---|
| **Worktree** | A second working copy of your repo, created with `git worktree`, living under `~/conduct/worktrees/<repo>/<city>`. It shares git history with your main checkout but has its own files and branch. |
| **City name** | A human-friendly random label for each worktree (from `cities.txt`). Used as the directory name and in the branch `conduct/<city>`. |
| **Port block** | Each worktree gets a base port (`3000`, `3010`, `3020`, …). A 10-port block is reserved per worktree so apps that use several ports don't overlap. Exposed as `$CONDUCT_PORT`. |
| **Lifecycle hooks** | `setup` (run once), `run` (the background dev server), `archive` (cleanup on removal) — defined per-repo in `.conduct.conf`. Mirrors Conductor's setup/run/archive. |
| **State** | Per-worktree metadata (port, server PID, branch, paths) stored under `~/conduct/state/`. |

## Install

From this folder:

```sh
bash ~/conduct/install.sh
```

That symlinks `conduct` into `~/.local/bin` and, if needed, adds that directory to
your shell's `PATH` (idempotent — safe to re-run). Then either open a new terminal or
`source ~/.zshrc`, and check:

```sh
conduct help
```

> The installer never uses `sudo`. It prefers `~/.local/bin`; it only touches
> `/usr/local/bin` if that already exists and is writable and `~/.local/bin` doesn't.

## Quick start

```sh
cd ~/my-next-app
conduct                 # first run prompts you to create .conduct.conf
```

On the **first run in a repo**, `conduct` detects your package manager and offers
sensible defaults (e.g. `npm install` + `npm run dev -- --port $CONDUCT_PORT`), or lets
you type custom commands. After that:

```sh
conduct                 # new worktree session (Claude Code)
conduct --codex         # ...launch Codex instead
conduct lisbon          # reattach to an existing worktree
conduct list            # see everything that's running
```

## Commands

```
conduct [--codex] [city]   start a new worktree session, or reattach to <city>
conduct list | ls          list active worktrees (repo · city · branch · port · server)
conduct logs <city>        tail a worktree's dev-server log
conduct stop <city>        stop a worktree's dev server (keep the worktree)
conduct finish [city]      push the branch and open a PR with `gh`
conduct rm <city>          archive: run cleanup hook, stop server, remove worktree + branch
conduct --config           edit this repo's .conduct.conf in $EDITOR
conduct help               full help
```

**Flag:** `--codex` launches Codex instead of Claude Code (works with both the default
"new" and reattach forms).

**Teardown menu.** Because you're normally *inside* the agent (not at a shell), when the
agent exits `conduct` shows:

```
Agent exited — myapp/lisbon  (server up on :3000)
  [k] keep running   (reattach: conduct lisbon)
  [s] stop server, keep worktree
  [p] create PR (gh) and keep worktree
  [r] remove worktree + branch
  [q] quit, change nothing
```

You can also just ask the agent itself to commit, push, and open the PR before you exit.

## Configuration (`.conduct.conf`)

Lives in the **repo root**, created interactively on first run. It's a plain shell file:

```sh
CONDUCT_SETUP='npm install'                          # runs once in the new worktree
CONDUCT_RUN='npm run dev -- --port $CONDUCT_PORT'    # the background dev server
CONDUCT_ARCHIVE=''                                   # optional cleanup on `conduct rm`
CONDUCT_COPY_FILES='.env .env.local'                 # untracked files to copy from the main repo
```

Commands run via `bash -c`, with these variables exported:

| Variable | Meaning |
|---|---|
| `CONDUCT_PORT` | the worktree's allocated base port (a 10-port block is reserved) |
| `PORT` | alias of `CONDUCT_PORT`, for tools that read `PORT` |
| `CONDUCT_WORKTREE_PATH` | absolute path of the worktree |
| `CONDUCT_REPO_PATH` | absolute path of the original repo (copy `.env` from here) |
| `CONDUCT_WORKTREE_NAME` | the city name |

> Single-quote the values so `$CONDUCT_PORT` is expanded at **run time**, not when the
> file is sourced.

Commit `.conduct.conf` to share it with your team (Conductor-style), or add it to
`.gitignore` to keep it personal. Edit anytime with `conduct --config`.

## How it works

1. **Repo context** — `conduct` resolves the repo root, name, and default branch
   (`origin/HEAD`, falling back to `main`/`master`).
2. **Fetch & branch** — `git fetch origin`, then `git worktree add -b conduct/<city>
   <path> origin/<default>`, so each worktree starts from the latest remote without
   touching your current checkout. (No remote? It branches from local `HEAD`.)
3. **Port allocation** — scans the lowest free base port (≥ `3000`, step 10), skipping
   any port already recorded in state **and** any port currently bound. The port is
   written to state *immediately* (before the slow setup) so a concurrent `conduct`
   can't grab the same one.
4. **Copy untracked files** — `CONDUCT_COPY_FILES` are copied from the main repo (git
   doesn't track them, so worktrees don't get them automatically).
5. **Setup** — `CONDUCT_SETUP` runs (blocking) in the worktree.
6. **Run** — `CONDUCT_RUN` starts in the background via `nohup`, output redirected to
   `~/conduct/logs/<repo>/<city>/dev.log`; the PID is saved to state.
7. **Agent** — `conduct` `cd`s into the worktree and launches `claude`/`codex` in the
   foreground.
8. **Teardown** — on agent exit, the menu (above) runs `stop` / `finish` / `rm` as you choose.

State files are tiny sourced shell snippets (`ST_PORT=…`, `ST_PID=…`, …). "Is the
server up?" is just `kill -0 $PID`. Stopping a server kills the process tree and frees
the port.

## Directory layout

```
~/conduct/                         # program + data live together by default
  conduct                          # the script (program asset)
  cities.txt                       # worktree name pool (program asset)
  install.sh
  README.md
  worktrees/<repo>/<city>/         # the git worktrees           (runtime data)
  logs/<repo>/<city>/dev.log       # background dev-server output (runtime data)
  state/<repo>/<city>.env          # port / pid / branch metadata (runtime data)
```

**Environment overrides:**

| Variable | Default | Purpose |
|---|---|---|
| `CONDUCT_HOME` | `~/conduct` | root of the runtime **data** dirs (worktrees/logs/state) |
| `CONDUCT_BASE_PORT` | `3000` | first port to try when allocating |
| `CONDUCT_CITIES` | next to the script | path to the city-name list |

> The script finds `cities.txt` **relative to itself** (following symlinks), so the
> program assets and the `CONDUCT_HOME` data dir can live in different places — which is
> exactly what packaged installs (e.g. Homebrew) need.

## Requirements

- **Required:** `git`, `bash`.
- **The agent:** `claude` (Claude Code) and/or `codex` on your `PATH`.
- **Recommended:** `lsof` (more reliable port-in-use detection), `gh` (for `conduct finish`).
- Whatever your project's dev server needs (Node, etc.).

Works on macOS's default `bash` 3.2 and on modern `bash`.

## Troubleshooting

- **Dev server didn't start / page won't load** — check the log:
  `conduct logs <city>`. Common causes: setup failed (missing deps), or the run command
  is wrong for your project.
- **`'claude' not found`** — install the agent CLI, or `cd` into the printed worktree
  path and run it yourself.
- **`conduct finish` fails** — it needs a GitHub `origin` remote and the `gh` CLI
  authenticated (`gh auth login`).
- **Port looks "wrong"** — `conduct` skips ports already bound by *other* apps, so you
  may see `3010` even for the first worktree if something else holds `3000`.
- **Stale entry in `conduct list`** — if a worktree dir was deleted by hand, run
  `conduct rm <city>` to clear its state, then `git worktree prune` in the main repo.

## Distribution via Homebrew (future)

This is a notes-to-self section for packaging `conduct` so others can
`brew install` it. It is **not set up yet** — it requires pushing the repo to GitHub
first.

**The model: a "tap" + a formula.** Homebrew installs from *formulae* (Ruby files). For
a personal project you publish them in your own **tap** — a public GitHub repo named
`homebrew-<name>` (the `homebrew-` prefix is mandatory and dropped in commands).

**Steps:**

1. **Push `conduct` to GitHub**, e.g. `github.com/<you>/conduct`, and cut a tagged
   release (e.g. `v0.1.0`). Homebrew installs from a release tarball + its SHA-256:
   ```sh
   curl -L https://github.com/<you>/conduct/archive/refs/tags/v0.1.0.tar.gz | shasum -a 256
   ```
2. **Create the tap repo** `github.com/<you>/homebrew-conduct` with a `Formula/`
   directory.
3. **Write the formula** `Formula/conduct.rb`. Because `conduct` is a script (not a
   compiled program), `install` just copies files into the Cellar. Install `conduct`
   into `libexec` alongside `cities.txt` so the script's self-relative asset lookup
   works, then symlink the executable into `bin`:
   ```ruby
   class Conduct < Formula
     desc "Run Claude Code / Codex in parallel git worktrees from the terminal"
     homepage "https://github.com/<you>/conduct"
     url "https://github.com/<you>/conduct/archive/refs/tags/v0.1.0.tar.gz"
     sha256 "<paste-the-sha-from-step-1>"
     license "MIT"

     def install
       libexec.install "conduct", "cities.txt"
       bin.install_symlink libexec/"conduct"
     end

     test do
       assert_match "conduct", shell_output("#{bin}/conduct help")
     end
   end
   ```
   This works precisely because the script resolves `cities.txt` next to itself
   (`SCRIPT_DIR/cities.txt`) while keeping `CONDUCT_HOME` (worktrees/logs/state) in the
   user's home — program assets and user data stay cleanly separated.
4. **Users install with:**
   ```sh
   brew tap <you>/conduct
   brew install conduct
   # or in one line:
   brew install <you>/conduct/conduct
   ```
5. **Updates:** bump `url`/`sha256` (and `version` if needed) in the formula on each new
   release tag; users get it via `brew upgrade`.

**Optional later:** add a `bin/conduct` wrapper, a man page (`man.install`), or shell
completions; submit to `homebrew-core` only if it gets popular (it has stricter rules —
notability, no HEAD-only, must be stable). A personal tap is the right home for now.

## Limitations & notes

- The dev server is started with `nohup` and survives after the agent exits (so you can
  reattach), but it is **not** a daemon — it stops on reboot, on `conduct stop`/`rm`, or
  if you kill the process. Reattaching with `conduct <city>` restarts a dead server.
- New worktrees branch from `origin/<default>` after a fetch. With no `origin` remote,
  they branch from local `HEAD` (you'll see a warning).
- Concurrency: the port is reserved in state right after allocation, so the only race is
  two `conduct` invocations firing in the same instant — a window of milliseconds. The
  normal "start one, then open another terminal" flow is fully safe.
- `conduct` shells out to your configured commands with `bash -c`; treat `.conduct.conf`
  as trusted (it runs whatever it contains).
