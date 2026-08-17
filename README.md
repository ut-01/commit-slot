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

## 📥 Install

Download the script into `~/scripts/`:

```bash
mkdir -p ~/scripts

curl -L \
  https://github.com/ut-01/commit-slot/raw/refs/heads/main/commit-slot.sh \
  -o ~/scripts/commit-slot.sh
```

Make it executable:

```bash
chmod +x ~/scripts/commit-slot.sh
```

Then expose it as a shell command:

```bash
alias commit-slot='source ~/scripts/commit-slot.sh'
```

Now from any Git repository:

```bash
commit-slot init
commit-slot
git commit -m "Add feature"
```

> **Tip:** Put the alias in your `~/.zshrc` or `~/.bashrc` to make `commit-slot` available in every new terminal.

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

The generated slot is persisted in `commit-slot.cfg`, so repeated calls continue moving forward.

---

## ⏰ Configurable time window

By default:

```text
Timezone : Asia/Kolkata
Restricted window : 09:00 → 18:00
Gap : 5 → 7 minutes
```

The script avoids generating timestamps inside the restricted window.

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

---

## 🛠 Commands

```text
commit-slot init       Enable commit-slot for this repository
commit-slot            Generate and export the next timestamp
commit-slot status     Show current slot information
commit-slot reset      Reset the persisted timestamp
commit-slot help       Show available commands
```

### Status example

```text
commit-slot: enabled
timezone:    Asia/Kolkata
restricted:  09:00-18:00
interval:    5-7 minutes
slot:        2026-08-17T18:07:00+0530
last commit: 2026-08-17T18:01:00+0530
```

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

---

## 🎯 Why commit-slot?

**Tiny.** One shell script.

**Fast.** No dependencies, database, daemon, or service.

**Persistent.** Remembers the last generated slot.

**Randomized.** Consecutive timestamps aren't mechanically identical.

**Git-native.** Uses Git's standard `GIT_AUTHOR_DATE` and `GIT_COMMITTER_DATE`.

**Repository-aware.** Works relative to the current Git repository.

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
