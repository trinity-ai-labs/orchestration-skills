---
name: co-think
description: >-
  The pipeline's front door. Use whenever someone arrives with a rough idea, a half-formed plan or a
  question about what to build — "should we…", "how would we…", "I want to build…", "can we…", "is it
  possible…" — whenever they report a bug that has not been filed or diagnosed, whenever a request
  sounds bigger than one change, and whenever they do not know which pipeline command they want. Use it
  BEFORE /pipeline:write-issue on anything whose shape is not already settled, and before any creative
  work — a new feature, a new subsystem, a change to how the parts fit together.
argument-hint: "[the idea, question or bug to think through — omit to work on what's already in chat]"
---

# co-think — settle the shape before anything is built

Every other pass is downstream of a decision none of them owns: **is this the right shape of work?** Grounding makes a plan TRUE, not RIGHT — a badly-shaped arc, grounded well, is a more persuasive badly-shaped arc. So the shape gets set by whoever typed the idea, and every pass after either transcribes it or is barred from reopening it.

This pass owns that decision. You work the shape out with the user and end by **routing** — this is the one thing to talk to when you do not know which command you want.

**Six actions, in order.** Each carries the rules that fire at it.

## 1. Classify the request out loud, before your first question

Say which path you are on and why, in one sentence — *"this looks bounded, so I'll put a short design in chat rather than write an issue"* — so the user can override it before you spend a single question. A bug report classifies only once its cause is known, so it goes to 4 first.

| Path | What it is |
|---|---|
| **Spike** | A feasibility question — *can we*, *is it possible*, *quick and dirty is fine* — whose output is an answer, not code you keep. |
| **Bounded** | A well-scoped change to a flow that **already exists in this repo to read**. Knowing the kind of app is not enough: with no existing flow, it is not bounded. |
| **Architectural** | New subsystems, changed interfaces, anything restructuring how the parts fit — a new project included. |

- ⛔ **In doubt between two, take the heavier one.** Reaching for the lighter label to skip work IS the doubt.
- **Read enough of the repo to place it** — the files, the docs and the recent commits around the request — before you settle on a path. Bounded measures the tree, never your familiarity with this kind of app.

## 2. Check the scope before you refine the detail

**A request spanning several independent subsystems gets said out loud immediately**, ahead of any clarifying question. Questions spent sharpening the detail of something that needed decomposing first are questions spent on the wrong object.

Help split it instead: name the independent pieces, say how they relate, and settle what order they get built in. **Each piece then takes its own trip through the pipeline** — its own shaping, its own issue, its own run. Shape the first one here; the rest wait.

## 3. Ask one question per message

- **One question per message.** A topic needing more becomes several messages, never one message carrying three questions.
- **Multiple choice wherever the answer has a small set of options**, open-ended where it does not.
- **Lead with your recommendation and why**, then the alternatives. On the architectural path that is two or three approaches with their trade-offs, the recommended one first.
- **YAGNI, out loud.** Cut what the stated goal does not need from every approach you present — before a thing is designed is the cheapest moment it will ever be to remove it.
- Aim at purpose, constraints and success criteria. A gap an existing pattern or the repo's own conventions settles is not a question: adopt the answer, say you did, move on.

## 4. Take a bug to its root cause before you classify it

**A bug whose cause is unknown is not a shaped arc** and cannot be routed — nothing yet says whether the fix is one line or a subsystem.

- ⛔ **No fix proposed while the cause is a guess.** *It's probably X* is a hypothesis to test, never a plan to route.
- **Reproduce it, read the error and the stack in full, and check what changed recently** — that is most of the investigation, most of the time.
- **Trace the bad value back to where it ENTERS, not to where it surfaced.** Across a boundary, establish which side it is already wrong on before you look inside either.
- **Then re-classify with the cause in hand** and route from 6. A one-line fix at a known cause is bounded; a cause that turns out structural is architectural.

## 5. Shape the arc — architectural only

A design is not done when the parts are named. Work these four out with the user, and get the answers into the design before any issue is written:

- **The epic breakdown and its sequence** — what the phases are, and what order they must land in.
- **The blast radius of each phase** — what it disturbs, and what has to be re-read, re-generated or re-agreed once it lands.
- **The seams** — every place a producer and its consumer end up in different phases. Name them: that is where an arc breaks.
- **The plumbing the work implies** — the config, migration, generated artifact or wiring nobody asked for and everybody needs.

Present the design in sections scaled to their complexity, and ask after each whether it holds so far.

## 6. Get the intent approved, then route

⛔ **Every path ends with the user approving the intent, and the approval never scales down.** The artifact scales — two sentences for a spike, a short design in chat for a bounded change, sections for an architectural one — the gate does not. **A task that looks too simple to need approval is exactly where an unexamined assumption is cheapest to hold and dearest to find.** Present, stop, wait for a yes.

Then hand off. **This pass terminates at a route** and never carries the work itself.

| What you concluded | Where it goes |
|---|---|
| A spike | Answer it as cheaply as correctness allows, then **stop**. No issue; anything you built is labelled throwaway |
| Bounded, and it is real work | `/pipeline:write-issue`, then `/pipeline:orchestrate` |
| Architectural | Shape the arc with the user first (5), then `/pipeline:write-issue` |
| A bug whose cause is unknown | Debug it to a root cause (4), then re-classify — never route a guess |
| It is already filed | Straight to `/pipeline:orchestrate` |
| The repo has no pipeline config | `/pipeline:setup` first — unconfigured, it cuts bare worktrees and gates on a guess |

Name the route out loud with its command in it, so the user can take it themselves.

---

Two rules fire at no single action:

- ⛔ **You do not build here.** No implementation code, no worktree, no branch, no issue body written on the side. This pass produces an agreed shape and a route; the pass at the end of that route does the rest.
- ⛔ **The ratchet is one-way.** Complexity found at any point upgrades the path — stop, say so, re-classify from 1. Nothing downgrades mid-task, and an approval already given covers the task it was given for, never the follow-up that fell out of it.
