\# Overrun — Plan



Status: Phase 0 complete (setup). Fill this in during Phase 1 before building

anything. This file is the single source of truth Claude Code should read

before making design decisions — keep it current as the plan evolves.



\## 1. The problem (from our story pass)

Professional services delivery managers can't see the compound risk of a deal

closing, a consultant about to be over-allocated, and a project margin about

to erode — because Sales, Resourcing, and Finance data live in separate

systems/objects with no shared view. The overrun becomes visible to the

client before anyone internally caught it.



Reference stats to cite in the demo (SPI Research, via prior research):

\- Industry median billable utilization: 66.4% (2025, lowest on record)

\- Median non-billable admin time: 35% of consultant hours

\- Overallocation risk example: a senior consultant at 140% with no early warning



\## 2. Personas

\- Primary: Delivery Manager (talks to the orchestrator agent)

\- Secondary: Resourcing/Staffing lead, Finance/Ops lead



\## 3. The compound-signal scenario (the demo's hero moment — LOCKED)



\*\*Company:\*\* Arihant Consulting

\*\*Persona:\*\* Priya, Delivery Manager



\*\*The trigger query (demo opener):\*\*

"Give me a staffing risk check across active deals this week."



\*\*The agent's decision hierarchy (applied to every deal, in order):\*\*

1\. Is there a consultant rolling off another project whose timeline and

&#x20;  skills line up? → Happy path.

2\. If not, is there anyone on the bench (already unassigned) with the

&#x20;  right skills? → Still a happy path, weaker signal.

3\. If not, would assigning the best available match push them past a safe

&#x20;  allocation ceiling, AND does that also threaten the deal's margin? →

&#x20;  Risk path.

4\. If nobody internally fits at all, what's the realistic external

&#x20;  recruiting lead time, and does it fit the deal's timeline? → Gap path.



The demo shows the agent running this hierarchy across three simultaneous

deals in ONE response — not three separate isolated Q\&As. This is what

proves it's reasoning, not a scripted single-answer lookup.



\### Path 1 — Happy Path: "Marcus and Whitfield"

\- Deal: Whitfield Manufacturing, $180K expansion, 90% probability, closing

&#x20; this week.

\- Need: Senior data-integration consultant, start in \~2 weeks.

\- Signal: Marcus rolls off Project Kestrel 2 days before Whitfield needs

&#x20; him — exact skill match, nobody had connected the two facts because

&#x20; Kestrel's timeline lives in Resourcing, Whitfield's deal lives in Sales.

\- Agent output: clean match identified, recommend assigning Marcus,

&#x20; timeline confirmed to work.



\### Path 2 — Risk Path: "The overloaded save"

\- Deal: Dunmore Logistics, $95K contract renewal, cloud-migration

&#x20; specialist needed, starting in 5 days.

\- Signal: Only qualified consultant, Aisha, is already at 90% allocation

&#x20; across two other projects. No one is rolling off in time. Assigning her

&#x20; pushes her to 130% allocation.

\- Compounding signal: Dunmore's pricing was set assuming a mid-level

&#x20; consultant's rate, not Aisha's senior rate — staffing her drops the

&#x20; project's margin from the 30% target to roughly 19%.

\- Agent output: flags BOTH the overallocation risk and the margin risk

&#x20; together (not separately), recommends a specific action — a two-week

&#x20; phased start so Aisha finishes current work first, OR renegotiating

&#x20; scope/pricing with the client. Requires human approval before any

&#x20; staffing change is actually made (see CLAUDE.md — no consequential

&#x20; action without human sign-off).



\### Path 3 — Gap Path: "The honest no"

\- Deal: Castellan Retail, $220K new-logo opportunity, requires a niche

&#x20; certified Data Cloud integration architect skill.

\- Signal: Agent checks rolling-off staff (none match), checks the bench

&#x20; (none match) — genuinely no internal fit.

\- Agent output: honest, specific answer — "No internal match. Typical

&#x20; hiring lead time for this skill is approximately 5 weeks, which is

&#x20; after the deal's required start date. Recommend either delaying kickoff

&#x20; by 3 weeks or engaging a subcontractor for this engagement." This is

&#x20; NOT a refusal — it's a fully-reasoned answer that happens to conclude

&#x20; "we don't have it," with a concrete next step attached.



\### Why all three matter together

Path 3 especially demonstrates multi-step reasoning (checked everything,

here's exactly what's missing) rather than a simple "I don't know." Showing

all three in one query response — three different deals, three different

correct outcomes — is the strongest possible proof this is genuine agentic

reasoning, not a single scripted trick.



\## 4. Data model

\- \[ ] Opportunity / pipeline data (deal, close date, required skills/role)

\- \[ ] Consultant allocation data (current assignments, % allocated, skills)

\- \[ ] Project margin/finance data (rate, cost, target margin, utilization)

\- \[ ] Unified/joined view — how does CRM Analytics bring these together?



\## 5. Agent architecture

\- Orchestrator: "Delivery Lead Agent" — the one the delivery manager talks to

\- Specialist agents/subagents:

&#x20; - Pipeline Agent

&#x20; - Resourcing Agent

&#x20; - Finance Agent

\- No standalone "Analytics Agent" — CRM Analytics grounds all three specialist

&#x20; agents directly.

\- Agent Script deterministic rule: never recommend staffing above a defined

&#x20; allocation ceiling (e.g., 110%) without explicit human override.

\- Human-approval checkpoint before any consequential action.



\## 6. CRM Analytics

\- Datasets: \[ TODO ]

\- Recipes: \[ TODO ]

\- Dashboard(s) for the "before" visual in the demo: \[ TODO ]



\## 7. Tableau Next (narrow, one sentence only — do not over-build)

\[ TODO: one line, e.g., "capacity risk this week" as a Pulse-style proactive

alert — referenced, not built as a parallel system. ]



\## 8. Demo script outline

\- Hook: Priya, Monday morning, one question — "Give me a staffing risk

&#x20; check across active deals this week."

\- Business pain: today this requires manually cross-referencing Sales

&#x20; pipeline, Resourcing schedules, and Finance margin data across separate

&#x20; systems — nobody does this proactively, so it's found too late.

\- Compound-signal reveal (the wow moment): agent returns all three deals

&#x20; in one response — Whitfield (clean match, Marcus), Dunmore (risk

&#x20; flagged: overallocation + margin erosion, together), Castellan (honest

&#x20; gap: no internal fit, 5-week hiring lead time, concrete alternative).

\- Human approval step: for the Dunmore risk-path recommendation, a human

&#x20; (Priya) approves the phased-start action before anything executes —

&#x20; agent drafts, human decides.

\- Impact/outcome (projected, credible, tied to SPI Research stats):

&#x20; industry median utilization sits at 66.4%; this pattern is designed to

&#x20; catch the exact compounding risk (overallocation + margin erosion)

&#x20; that manual, siloed tracking misses until it's client-visible.

\- Close: callback to the opening question — one query, three deals, three

&#x20; correctly different outcomes, no dashboard shows this today.



\## 9. Open questions / risks

\- \[ ]

