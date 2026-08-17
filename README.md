# commit-slot

### Give every commit a realistic time slot. Automatically.

`commit-slot` is a tiny shell utility that turns timestamp management into a one-command workflow.

It generates the **next Git commit timestamp**, keeps timestamps moving forward, adds a small randomized gap, and avoids a configurable time window.

No manual date arithmetic. No timestamp juggling. Just:

```bash
commit-slot
git commit -m "your change"
```

---

## ✨ The idea

Normally, Git commits happen at whatever time you happen to run `git commit`.

`commit-slot` gives your commits a controlled timeline instead:

```text
                 commit-slot
                      │
                      ▼
        ┌──────────────────────────┐
        │ Latest known timestamp   │
        │           +              │
        │ Random 5–7 minute gap    │
        └────────────┬─────────────┘
                     │
                     ▼
              Next available slot
                     │
                     ▼
        GIT_AUTHOR_DATE
        GIT_COMMITTER_DATE
                     │
                     ▼
              git commit
```

### Example

Instead of:

```text
10:01  commit A
10:01  commit B
10:01  commit C
10:02  commit D
```

you get:

```text
09:42  commit A
        │
        └── +6 min
             ▼
09:48  commit B
        │
        └── +5 min
             ▼
09:53  commit C
        │
        └── +7 min
             ▼
10:00  commit D
```

The exact gap is randomized within your configured range.

---

## 🚀 One command. That's it.

Once installed as an alias:

```bash
commit-slot
```

generates and exports the next timestamp into:

```text
GIT_AUTHOR_DATE
GIT_COMMITTER_DATE
```

So your normal Git workflow stays unchanged:

```bash
commit-slot
git add .
git commit -m "Add feature"
```

Git sees the generated timestamp automatically.

---

## 🧠 Smart timestamp progression

`commit-slot` doesn't blindly use the current clock.

It considers the most recent timestamp from:

```text
                 ┌──────────────────┐
                 │ Today's midnight │
                 └────────┬─────────┘
                          │
                 ┌────────▼─────────┐
                 │ Latest Git commit│
                 └────────┬─────────┘
                          │
                 ┌────────▼─────────┐
                 │ Saved slot       │
                 └────────┬─────────┘
                          │
                          ▼
                  MAXIMUM timestamp
                          │
                       + 5–7 min
                          │
                          ▼
                    Next slot
```

This means repeated calls continue moving forward instead of accidentally generating timestamps earlier than an existing commit.

The generated slot is also persisted in `commit-slot.cfg`.

---

## ⏰ Configurable time window

By default:

```text
Timezone : Asia/Kolkata
Restricted window : 09:00 → 18:00
Gap : 5 → 7 minutes
```

The script avoids generating timestamps inside the restricted window.

For example:

```text
08:54
  │
  └── +7 min
       ▼
09:01  ✗ restricted
       │
       └── jump to 18:00
                    │
                    └── +6 min
                         ▼
18:06  ✓ valid slot
```

The configuration lives directly at the top of the script, making it easy to adapt.

---

## 🛠 Commands

```text
commit-slot init
```

Enable `commit-slot` for the current repository.

Creates:

```text
commit-slot.cfg
```

and automatically adds it to `.gitignore`.

---

```text
commit-slot
```

Generate the next timestamp and export it to the current shell.

Example:

```text
commit-slot: 2026-08-17T18:07:00+0530
```

---

```text
commit-slot status
```

See what's happening:

```text
commit-slot: enabled
timezone:    Asia/Kolkata
restricted:  09:00-18:00
interval:    5-7 minutes
slot:        2026-08-17T18:07:00+0530
last commit: 2026-08-17T18:01:00+0530
```

---

```text
commit-slot reset
```

Forget the persisted timestamp and start a fresh sequence.

---

## 🔒 Built for repeated use

`commit-slot` includes a lightweight lock so two processes don't try to generate the next slot simultaneously.

The timestamp state is also updated atomically.

```text
Process A ──┐
            ├── 🔒 commit-slot ──► next slot
Process B ──┘          │
                       └── safely persisted
```

So the little script has some surprisingly serious bookkeeping underneath the hood.

---

## ⚡ Setup

Source the script into your shell and expose it as an alias/function so `commit-slot` becomes available as a command.

For example:

```bash
alias commit-slot='source /path/to/commit-slot'
```

Then:

```bash
cd my-project

commit-slot init
commit-slot
git commit -m "Add feature"
```

From that point on, the workflow is delightfully boring:

```text
commit-slot → git commit → repeat
```

---

## 🎯 Why commit-slot?

**Tiny.** One shell script.

**Fast.** No dependencies, database, daemon, or service.

**Persistent.** Remembers the last generated slot.

**Randomized.** Consecutive timestamps aren't mechanically identical.

**Git-native.** Uses Git's standard `GIT_AUTHOR_DATE` and `GIT_COMMITTER_DATE`.

**Repository-aware.** Automatically works relative to the current Git repository.

**Cross-platform date handling.** Supports both GNU `date` and BSD/macOS `date`.

**Safe.** Uses locking and atomic state updates.

---

> ### `commit-slot`
>
> **Turn commit timestamps into a schedule, not a scramble.**
>
> ```text
>        ┌─────────────┐
>        │ commit-slot │
>        └──────┬──────┘
>               │
>        ┌──────▼──────┐
>        │ next slot   │
>        └──────┬──────┘
>               │
>        ┌──────▼──────┐
>        │  git commit │
>        └─────────────┘
> ```
>
> **One command. Predictable progression. Zero timestamp babysitting.**
