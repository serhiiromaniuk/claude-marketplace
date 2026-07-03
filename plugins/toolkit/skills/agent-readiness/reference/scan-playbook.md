# Scan playbook (read-only)

The `agent-readiness` analogue of `assessment-report/reference/discovery-playbook.md`.
Detect each pillar's signals in a target repo **without mutating anything**. Record the
evidence (the file/line you saw) and a confidence flag per pillar. This is Mode 1's data-gathering step.

## Golden rules
- **Read-only.** `find`, `ls`, `grep`, `cat`, `git log/status`. No writes, no installs, no running the repo's code.
- **Cite evidence.** For each pillar, note the concrete file(s) that raised its level. No file → the pillar isn't Verified.
- **Assign confidence honestly.** 🟢 Verified = you read the file. 🟡 Inferred = it exists but you didn't confirm it's wired into the loop. ⚪ Assumed = you couldn't inspect (say why).
- **Detect across conventions.** Agent tooling shows up under different names — check all common ones before scoring a pillar 0.

## Orientation (run first)
```bash
cd <repo>
git rev-parse --short HEAD 2>/dev/null; git branch --show-current 2>/dev/null   # for score.json state
git status --short                                                              # clean tree?
find . -maxdepth 2 -type d -not -path '*/.git*' -not -path '*/node_modules*' \
  -not -path '*/.venv*' | sort                                                  # top-level shape
ls -a                                                                           # dotfiles (.claude, .cursor, AGENTS.md…)
```

## Per-pillar probes

**P1 Rules & context**
```bash
ls CLAUDE.md AGENTS.md GEMINI.md .cursorrules .cursor/rules 2>/dev/null
grep -rilE 'golden rule|never violate|must not|invariant|override this' CLAUDE.md AGENTS.md 2>/dev/null   # invariants + supremacy clause
grep -rilE 'architecture|boundary|only in|must live' CLAUDE.md AGENTS.md 2>/dev/null                     # boundaries
ls WORKFLOW.md CONTRIBUTING.md 2>/dev/null                                                                # worked example
```
Level up when invariants are explicit (→3) and there's a supremacy clause + worked example the loop cites (→4).

**P2 Filesystem-as-memory**
```bash
find . -type d \( -name tasks -o -name plans -o -name '.agent*' \) -not -path '*/.git*' 2>/dev/null
ls tasks/INDEX.md tasks/_template 2>/dev/null                                    # ledger + template
find tasks -maxdepth 2 -iname 'BRIEF*' -o -iname 'PLAN*' -o -iname 'LOG*' -o -iname 'OUTCOME*' 2>/dev/null
grep -rilE 'append-only|do not edit|never edit a previous|immutable' tasks 2>/dev/null   # discipline
```
Structured task folders + index → 3; add `_template` + append-only/immutable-plan discipline → 4.

**P3 Long-running loop**
```bash
find . -type d \( -name ralph -o -name loop -o -name agent-loop \) -not -path '*/.git*' 2>/dev/null
ls ralph/PROMPT.md ralph/STATE.md ralph/loop.sh loop/*.sh 2>/dev/null
grep -rilE 'max.?iterations|--max-iter|iteration cap' . --include='*.sh' 2>/dev/null   # bounded harness
grep -rhoE '<<[A-Z]+:[A-Z_]+>>' . 2>/dev/null | sort -u                                # marker protocol
ls .claude/commands/*loop* 2>/dev/null                                                 # /ralph-loop plugin or a loop-step command
```
Invariant prompt + bounded harness + markers → 3; add a live state pointer + one-increment discipline → 4.

**P4 Verification gates**
```bash
ls Makefile justfile Taskfile.yml package.json 2>/dev/null
grep -nE '^check:|^test:|^lint:|"test"|"lint"' Makefile package.json 2>/dev/null       # single entrypoint
grep -rilE 'make check|coverage|acceptance|never (lower|weaken)|threshold' CLAUDE.md AGENTS.md ralph 2>/dev/null
find . -path '*/.github/workflows/*.yml' 2>/dev/null                                   # CI gate
```
Single sanctioned entrypoint + steps name a check → 3; add hard un-lowerable thresholds + gate-failed protocol → 4.

**P5 Role-specialized subagents**
```bash
ls .claude/agents/ .cursor/skills* 2>/dev/null
for f in .claude/agents/*.md; do echo "== $f"; sed -n '1,6p' "$f"; done 2>/dev/null    # roles + tool/model scoping
grep -rilE 'planner|reviewer|verifier|researcher|adversarial' .claude/agents 2>/dev/null
```
Several roles with tool scoping → 3; adversarial reviewer + model-per-role + invoked by the loop → 4.

**P6 Autonomy boundaries**
```bash
grep -rilE 'human.?only|never (flip|push --force|deploy)|do not cross|hand (back|to a human)|permission' \
  CLAUDE.md AGENTS.md ralph .claude 2>/dev/null
ls .claude/settings*.json 2>/dev/null                                                  # permission scoping
grep -rhoE '<<[A-Z]+:(BLOCKED|READY_FOR_LIVE|DONE)>>' . 2>/dev/null | sort -u           # handback markers
```
Explicit human-only list + loop halts and hands back → 3; add permission scoping + blocked/handback markers → 4.

**P7 Change hygiene**
```bash
ls .gitignore .gitmessage 2>/dev/null
grep -rilE 'conventional commit|feat\(|type\(scope\)|no ticket' CLAUDE.md AGENTS.md .gitmessage 2>/dev/null
grep -rilE 'scan.*(secret|staged)|forbidden path|do not commit|\.env' CLAUDE.md AGENTS.md ralph 2>/dev/null
git log --oneline -15 2>/dev/null                                                       # do commits actually follow the convention?
git tag 2>/dev/null                                                                     # milestone tags
```
Conventional commits + secret/forbidden-path scan + clean-tree rule → 3; add gate-tied milestone tagging encoded in the loop → 4.

## Absence handling
A pillar that scans clean across **all** its conventions is a legitimate **0** — record it as
Verified-absent (you looked and it's not there), not Assumed. Only use ⚪ Assumed when you were
genuinely unable to inspect (e.g. no read access to a submodule).

## Integrity statement (put in the report)
State plainly: the scan was read-only — no file created, modified, or run; no secrets read.
It's true and it builds trust, exactly as in the `assessment-report` discovery playbook.
