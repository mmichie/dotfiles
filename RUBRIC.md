# Dotfiles Quality Rubric

A scoring framework for evaluating this repo — and for deciding what to improve
next. Tailored to a Nix-managed, multi-host, test-gated dotfiles setup.

## How to use it

1. Score each dimension **0–4** using the level descriptors.
2. Multiply by the dimension **weight**, sum, divide by 4 → a 0–100 score.
3. Add the **Novelty & Craft** bonus (0–5) on top.
4. The level descriptors double as a backlog: the gap between your current level
   and the next one *is* the next concrete improvement.

Re-score before a big refactor, after onboarding a new host, or quarterly.

### Scale (applies to every dimension)

| Level | Name        | Meaning |
|------:|-------------|---------|
| 0 | Absent      | Not addressed. |
| 1 | Ad hoc      | Exists, but manual, fragile, or undocumented. |
| 2 | Functional  | Works and has some structure; notable gaps remain. |
| 3 | Robust      | Systematic, documented, mostly automated. |
| 4 | Exemplary   | Automated, enforced, self-verifying — a pattern worth copying. |

### Dimensions at a glance

| # | Dimension | Weight | The question it answers |
|---|-----------|-------:|-------------------------|
| 1 | Correctness | 12 | Does it do what I intend, with no broken states? |
| 2 | Reproducibility & Dependability | 14 | Same result on every machine; can I always roll back? |
| 3 | Testability & Verification | 12 | Can a change be proven safe before it ships? |
| 4 | Performance & Optimization | 10 | Is it fast, and does it stay fast? |
| 5 | Maintainability & Modularity | 12 | How cheap is it to understand and change? |
| 6 | Portability & Multi-host | 10 | Does it span macOS / Linux / NixOS and work vs. personal? |
| 7 | Security & Secrets | 10 | Are secrets handled safely and never leaked? |
| 8 | Onboarding & Ease of Use | 8 | How fast from bare metal to working, day to day? |
| 9 | Productivity & Ergonomics | 8 | Does it actually make me faster? |
| 10 | Observability & Debuggability | 4 | Can I see what changed and diagnose what broke? |
| — | Novelty & Craft (bonus) | +5 | Does it do something genuinely clever or elegant? |

Weights sum to 100; adjust them to your priorities — they encode *your* values,
not a universal truth.

---

## 1. Correctness — weight 12

**Does the configuration produce the behavior I intend, with no half-applied or
broken intermediate states?**

- **2 — Functional:** `switch` applies cleanly; obvious breakage is caught by
  hand after the fact.
- **3 — Robust:** Builds are validated before activation (`just dry-run`,
  `nix flake check`); switches are atomic so there is no half-applied state;
  config intent is asserted by tests, not just "it launched."
- **4 — Exemplary:** Intent is encoded as executable checks at multiple tiers —
  syntax, parse, behavior — and they run automatically before code can land.
  Subtle correctness traps (e.g. the global `zshenv` PATH rewrite neutralized by
  `__NIX*_SET_ENVIRONMENT_DONE` guards) are documented *and* regression-tested.

**Signals in this repo:** `tests/test_syntax.zsh`, `tests/test_parse_env.zsh`,
`tests/test_regressions.zsh`, `tests/test_nvim.zsh` (behavioral boot probe),
atomic `darwin-rebuild`/`nixos-rebuild` activation, `nix flake check`.

**How to measure:** `just check && just test`. Count classes of bug a green run
rules out. Ask: "what could break silently that *no* test would catch?"

---

## 2. Reproducibility & Dependability — weight 14

**Will the same inputs produce the same machine — and when something goes wrong,
can I always get back to a known-good state?**

- **2 — Functional:** Declarative config exists; versions mostly pinned; rollback
  is possible but manual and rarely rehearsed.
- **3 — Robust:** All inputs pinned in `flake.lock`; activation is atomic with
  generation rollback; a backup path for the irreplaceable bits exists.
- **4 — Exemplary:** Fully hermetic, pinned, and *rehearsed* recovery: every
  flake input pinned and updated deliberately (`just update` shows the diff);
  the root-of-trust (sops age key) and identity material are captured by
  `just secrets-backup` with a documented restore (`just secrets-restore`);
  rebuilds are byte-reproducible from a clean checkout on any covered host.

**Signals in this repo:** `flake.lock` with `follows` dedup, `inputs.self.submodules`,
`just update` diff output, generation rollback via Nix, `just secrets-backup`/
`-restore` (age key leads — it's the decryption root of trust), `just gc`.

**How to measure:** From a clean clone on a second machine, can you reach an
identical working state using only the repo + `backup.tar.gz`? Time it. Anything
that requires undocumented manual steps drops you a level.

---

## 3. Testability & Verification — weight 12

**Can a change be demonstrated safe before it reaches a machine I rely on?**

- **2 — Functional:** Some tests exist; run manually and occasionally.
- **3 — Robust:** A real suite covering the high-risk surfaces, runnable with one
  command and wired into a pre-commit hook.
- **4 — Exemplary:** Layered gates matched to risk — fast unit/parse checks on
  pre-commit, slower behavioral checks on pre-push, full hermetic build in CI
  across every target OS — with each file isolated in its own process and hangs
  converted to failures. New risk surfaces get a test as a reflex.

**Signals in this repo:** 14 files / ~1.3k LOC under `tests/`; `tests/run.zsh`
(per-file process isolation, `timeout 120` guard); lefthook `zsh-tests`/
`secret-scan` pre-commit + `nvim-tests` pre-push; CI matrix (ubuntu + macos) plus
a hermetic `checks.<system>.zsh-config` derivation; `tests/lib.zsh` +
`tests/test_helpers.zsh` harness.

**How to measure:** `just test` and read the file list. For each risky subsystem
(zsh startup, secrets, tmux, nvim, keybindings, performance) ask: is there a test,
and at which gate does it fire? Untested risky surfaces cap this at 3.

---

## 4. Performance & Optimization — weight 10

**Is interactive use fast, and is that speed defended against regression?**

- **2 — Functional:** Feels fast enough; no measurement.
- **3 — Robust:** Startup is measured and tuned (cached tool-init instead of
  `eval $(tool init)` per shell; compiled completion dump).
- **4 — Exemplary:** A numeric budget is *enforced* with structural,
  machine-independent regression tests, plus profiling tooling for diagnosis;
  cold vs. warm paths are both characterized.

**Signals in this repo:** `just profile` (median vs. 100ms budget, fails over),
`just profile-deep` (zprof), `just profile-cold` (hermetic fresh-HOME sandbox),
`tests/test_performance.zsh` + `tests/test_startup.zsh` (gate the structure that
keeps it fast — `_refresh_cache` mtime invalidation, zcompiled dumps, compinit
`-C` fast path), `typeset -U path` dedup.

**How to measure:** `just profile` and `just profile-cold`. A budget that's
merely *documented* but not test-enforced is level 3, not 4.

---

## 5. Maintainability & Modularity — weight 12

**How cheaply can a newcomer (or future you) understand and change this?**

- **2 — Functional:** Organized into files; some duplication; structure mostly
  implicit.
- **3 — Robust:** Clear module boundaries, a host-construction abstraction,
  consistent conventions, formatting and linting enforced.
- **4 — Exemplary:** Adding a host is one constructor call + a thin hardware
  file; load order is self-evident from naming; cross-cutting concerns live in
  one place; non-obvious decisions carry a *why* comment; lint/format are
  automated gates, not etiquette.

**Signals in this repo:** `lib/mkHost.nix` (`mkDarwinHost`/`mkNixosHost`/
`mkHomeConfig`); `hostclass/` (darwin/linux workstation classes); numbered zsh
modules `00-platform` … `80-ssh` (prefix = load order, no orchestrator);
`modules/home/` split (`packages-core` vs `packages-dev`, `options`, `lib`);
lefthook `nix-fmt`/`statix`/`shfmt`; dense *why*-comments (e.g. the `just hooks`
`--force` rationale, the CI `--all-systems` note).

**How to measure:** Add a throwaway host or zsh module. Count files touched and
concepts you had to learn. The fewer, the higher the score.

---

## 6. Portability & Multi-host — weight 10

**Does one codebase serve every machine and context without forking?**

- **2 — Functional:** Works on the primary OS; other platforms drift or are
  stale.
- **3 — Robust:** Multiple OSes share a common core with platform-specific
  layers; per-host differences are parameterized.
- **4 — Exemplary:** macOS, NixOS, and standalone Linux all build from shared
  modules; per-host and work-vs-personal variation is a flag, not a fork; foreign
  targets are buildable/verifiable from the primary host.

**Signals in this repo:** `darwinConfigurations` (3 hosts) + `nixosConfigurations`
+ `homeConfigurations`; `my.isWork` flag for work machines; `home/shared.nix`
shared core; `just vm-build`/`vm-switch` (build/apply NixOS from macOS); CI builds
both ubuntu and macos; `systems`/`forAllSystems` in `flake.nix`.

**How to measure:** Count targets that build green from one `nix flake check`.
A platform that only "works on my machine" without a buildable config is a gap.

---

## 7. Security & Secrets — weight 10

**Are secrets encrypted at rest, never committed in clear, and recoverable?**

- **2 — Functional:** Secrets kept out of the repo by convention; relies on
  remembering not to commit them.
- **3 — Robust:** Secrets encrypted (sops/age) and decrypted at activation;
  sensitive dirs get correct perms on restore.
- **4 — Exemplary:** Encryption + an automated **leak gate** that blocks commits
  containing secrets, a clear root-of-trust with documented backup/restore, and
  least-exposure handling (no secret values echoed to logs/stdout).

**Signals in this repo:** `sops-nix` input + `modules/home/secrets*.nix`;
`tests/secret-scan.zsh` wired as a lefthook pre-commit command; `tests/test_secrets.zsh`;
`.sops.yaml`; age key as documented root-of-trust in `just secrets-backup`;
perm-hardening in `secrets-restore` (`chmod 700/600`).

**How to measure:** Try to commit a fake secret — the pre-commit `secret-scan`
should reject it. Confirm no recipe or test prints secret *values*.

---

## 8. Onboarding & Ease of Use — weight 8

**How fast from bare metal to a working environment, and how low-friction day to
day?**

- **2 — Functional:** A README with the key commands; some implicit steps.
- **3 — Robust:** One-line bootstrap, a task runner that hides command detail,
  preview-before-apply.
- **4 — Exemplary:** Copy-pasteable bootstrap per platform; a single
  auto-detecting `switch`; `dry-run` preview; self-documenting task runner; docs
  that match reality (and a CI badge proving the docs' claims build).

**Signals in this repo:** `README.md` (quick-start per platform, status badge),
`CLAUDE.md`, `just switch` (auto-detects macOS/Linux/NixOS), `just dry-run`,
self-describing `justfile` recipes, Determinate Systems one-line installer.

**How to measure:** Hand the README to someone else (or a fresh VM). Count the
steps they get stuck on. Each undocumented stumble drops a level.

---

## 9. Productivity & Ergonomics — weight 8

**Beyond working, does the setup measurably accelerate real work?**

- **2 — Functional:** Standard tools installed; default ergonomics.
- **3 — Robust:** Curated modern CLI stack, history/search/navigation upgrades,
  a useful prompt, sensible aliases and keybindings.
- **4 — Exemplary:** The toolchain compounds — fuzzy history (atuin+fzf),
  smart-jump (zoxide), fast search (rg/fd), rich diffs (delta/difftastic), an
  informative low-latency prompt, plus mutable configs so iteration is instant.

**Signals in this repo:** `mkOutOfStoreSymlink` (edits take effect with no
rebuild — tight iteration loop); ~80 CLI tools in `packages-core.nix`; atuin,
fzf, zoxide, vivid, delta/difftastic; `chevron` prompt; `configs/zsh/.zsh/lib/`
aliases/keybindings/ls; `configs/aerospace`, `configs/karabiner`, `configs/tmux`.

**How to measure:** Subjective but real — list the 5 actions you do most and
whether the setup shaves time off each. Mutable-by-symlink iteration is a strong
level-4 signal.

---

## 10. Observability & Debuggability — weight 4

**When something changes or breaks, can I see exactly what and why?**

- **2 — Functional:** Re-run and eyeball the output.
- **3 — Robust:** Preview diffs before applying; profiling on demand.
- **4 — Exemplary:** What-changed is visible at every layer — closure diffs
  (`nvd diff`), input diffs (`just update`), startup profiling
  (`just profile-deep`), and a `nix repl` to introspect outputs live.

**Signals in this repo:** `just dry-run` (`darwin-rebuild build` + `nvd diff`),
`just update` (flake.lock input diff + package diff), `just profile-deep` (zprof),
`just repl` (flake outputs preloaded), `PROFILE_STARTUP` hook.

**How to measure:** After a change, can you produce a precise before/after at the
package, closure, and startup-cost level without ad-hoc scripting?

---

## Novelty & Craft — bonus, up to +5

**Does the repo solve a problem in a way that's genuinely clever, not just
competent?** Award points for ideas worth stealing.

Candidate examples already present:
- mtime-invalidated, zcompiled tool-init caches replacing per-shell
  `eval $(tool init)` — startup speed without staleness.
- Machine-independent performance *regression* tests that gate the structure
  behind the speed, so the budget survives even on slow CI hardware.
- The `__NIX*_SET_ENVIRONMENT_DONE` guard discovery — neutralizing the
  always-sourced global `zshenv` PATH rewrite that would otherwise swap pinned
  store inputs for host tools inside the test sandbox.
- Hermetic cold-vs-warm startup profiling in a fresh-`HOME` sandbox
  (`tests/profile-cold.zsh`).
- `secret-scan` and a behavioral `nvim` boot probe wired as commit/push gates —
  catching plugin drift that changes *no tracked file*.
- `just claude-update` vendoring upstream agents with an interactive diff.

**How to measure:** Would another engineer, seeing this, say "I'm copying that"?
Each distinct such idea is worth ~1 point.

---

## Scorecard template

| Dimension | Weight | Score (0–4) | Weighted |
|-----------|-------:|------------:|---------:|
| Correctness | 12 | | |
| Reproducibility & Dependability | 14 | | |
| Testability & Verification | 12 | | |
| Performance & Optimization | 10 | | |
| Maintainability & Modularity | 12 | | |
| Portability & Multi-host | 10 | | |
| Security & Secrets | 10 | | |
| Onboarding & Ease of Use | 8 | | |
| Productivity & Ergonomics | 8 | | |
| Observability & Debuggability | 4 | | |
| **Subtotal** | **100** | | **/ 4 = ___ / 100** |
| Novelty & Craft (bonus) | +5 | | |
| **Total** | | | **___ / 100 (+bonus)** |
