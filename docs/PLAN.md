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



\## 3. The compound-signal scenario (the demo's hero moment — define precisely)

\[ TODO: write the exact scenario — e.g., "Can we staff the Acme deal closing

Friday?" → agent finds the best-fit consultant is already at 95% allocation

across two other projects, would cross 130% if assigned, and the resulting

margin would drop below the firm's threshold. ]



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

\- Hook:

\- Business pain:

\- Compound-signal reveal (the wow moment):

\- Human approval step:

\- Impact/outcome (projected, credible, tied to the SPI stats above):

\- Close:



\## 9. Open questions / risks

\- \[ ]

