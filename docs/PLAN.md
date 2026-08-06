# Overrun — Plan

Status: Phase 0 complete (setup). Fill this in during Phase 1 before building
anything. This file is the single source of truth Claude Code should read
before making design decisions — keep it current as the plan evolves.

## 1. The problem (from our story pass)
Professional services delivery managers can't see the compound risk of a deal
closing, a consultant about to be over-allocated, and a project margin about
to erode — because Sales, Resourcing, and Finance data live in separate
systems/objects with no shared view. The overrun becomes visible to the
client before anyone internally caught it.

Reference stats to cite in the demo (SPI Research, via prior research):
- Industry median billable utilization: 66.4% (2025, lowest on record)
- Median non-billable admin time: 35% of consultant hours
- Overallocation risk example: a senior consultant at 140% with no early warning

## 2. Personas
- Primary: Delivery Manager (talks to the orchestrator agent)
- Secondary: Resourcing/Staffing lead, Finance/Ops lead

## 3. The compound-signal scenario (the demo's hero moment — LOCKED)

**Company:** Arihant Consulting
**Persona:** Priya, Delivery Manager

**The trigger query (demo opener):**
"Give me a staffing risk check across active deals this week."

**The agent's decision hierarchy (applied to every deal, in order):**
1. Is there a consultant rolling off another project whose timeline and
   skills line up? → Happy path.
2. If not, is there anyone on the bench (already unassigned) with the
   right skills? → Still a happy path, weaker signal.
3. If not, would assigning the best available match push them past a safe
   allocation ceiling, AND does that also threaten the deal's margin? →
   Risk path.
4. If nobody internally fits at all, what's the realistic external
   recruiting lead time, and does it fit the deal's timeline? → Gap path.

The demo shows the agent running this hierarchy across three simultaneous
deals in ONE response — not three separate isolated Q&As. This is what
proves it's reasoning, not a scripted single-answer lookup.

### Path 1 — Happy Path: "Marcus and Bridgeway"
- Deal: Bridgeway, $180K expansion, 90% probability, closing this week.
- Need: Senior data-integration consultant, start in ~2 weeks.
- Signal: Marcus rolls off Project Kestrel 2 days before Bridgeway needs
  him — exact skill match, nobody had connected the two facts because
  Kestrel's timeline lives in Resourcing, Bridgeway's deal lives in Sales.
- Agent output: clean match identified, recommend assigning Marcus,
  timeline confirmed to work.

### Path 2 — Risk Path: "The overloaded save"
- Deal: Harlow, $95K contract renewal, cloud-migration specialist
  needed, starting in 5 days.
- Signal: Only qualified consultant, Aisha, is already at 90% allocation
  across two other projects. No one is rolling off in time. Assigning her
  pushes her to 130% allocation.
- Compounding signal: Harlow's pricing was set assuming a mid-level
  consultant's rate, not Aisha's senior rate — staffing her drops the
  project's margin from the 30% target to roughly 19%.
- Agent output: flags BOTH the overallocation risk and the margin risk
  together (not separately), recommends a specific action — a two-week
  phased start so Aisha finishes current work first, OR renegotiating
  scope/pricing with the client. Requires human approval before any
  staffing change is actually made (see CLAUDE.md — no consequential
  action without human sign-off).

### Path 3 — Gap Path: "The honest no"
- Deal: Corven, $220K new-logo opportunity, requires a niche
  certified Data Cloud integration architect skill.
- Signal: Agent checks rolling-off staff (none match), checks the bench
  (none match) — genuinely no internal fit.
- Agent output: honest, specific answer — "No internal match. Typical
  hiring lead time for this skill is approximately 5 weeks, which is
  after the deal's required start date. Recommend either delaying kickoff
  by 3 weeks or engaging a subcontractor for this engagement." This is
  NOT a refusal — it's a fully-reasoned answer that happens to conclude
  "we don't have it," with a concrete next step attached.

### Why all three matter together
Path 3 especially demonstrates multi-step reasoning (checked everything,
here's exactly what's missing) rather than a simple "I don't know." Showing
all three in one query response — three different deals, three different
correct outcomes — is the strongest possible proof this is genuine agentic
reasoning, not a single scripted trick.

## 4. Data model (LOCKED)

Client names simplified: Bridgeway, Harlow, Corven (no suffixes).

| Object | Fields |
|---|---|
| **Opportunity** (standard) | Amount, Probability, CloseDate, Account, `Skill_Needed__c`, `Start_Needed__c`, `Target_Margin__c`, `Assumed_Level__c` |
| **Consultant__c** (custom) | Name, `Skill__c`, `Level__c`, `Rate__c` |
| **Project__c** (custom) | Name, `End_Date__c`, `Account__c` (lookup) |
| **Assignment__c** (custom, junction) | `Consultant__c` (lookup), `Project__c` (lookup), `Allocation__c`, `Start_Date__c`, `End_Date__c` |

- Consultant's TOTAL allocation = sum of `Allocation__c` across their active
  Assignment__c rows. This is the mechanism behind the risk path (Aisha
  hitting 130%).
- Happy path (Marcus/Bridgeway) = query for consultants whose
  Assignment__c.End_Date__c falls before an Opportunity's Start_Needed__c,
  matching Skill__c.
- Gap path (Corven) = query returns zero Consultant__c matches for the
  required skill — a real empty result, not scripted.
- Decision: start with plain custom objects (fastest for a 4-week build).
  Sync to Data Cloud/Data 360 later if time allows, for the CRM Analytics
  grounding layer — not required to get the core demo working.
- CRM Analytics: one recipe joins Opportunity + Consultant__c +
  Assignment__c into a single unified dataset the agent reasons over.

## 5. Agent architecture (LOCKED)

**Topics:**
- Staffing_Risk_Check — primary topic; handles broad queries ("give me a
  staffing risk check across active deals") — runs the decision hierarchy
  across MULTIPLE deals at once, returns all outcomes in one response.
- Deal_Staffing_Lookup — handles single-deal ad hoc questions ("can we
  staff Bridgeway if it closes Friday?").
- Staffing_Action — handles approving a recommended action; this is the
  human-approval gate for the risk path.

**Actions:**
- Get_Staffing_Risk_Report (Apex invocable) — queries near-term
  Opportunities, runs the 4-step decision hierarchy against each, returns
  a structured list: deal name, outcome type (happy/risk/gap), details.
- Get_Deal_Staffing_Status (Apex invocable) — same logic, single-deal
  scope, for ad hoc questions.
- Propose_Staffing_Action — drafts a recommendation for the risk/gap
  path (phased start, subcontractor, delay). Returns a draft only, never
  executes.
- Confirm_Staffing_Action — only fires after explicit human confirmation
  in conversation. The only action that actually writes data (e.g.,
  updates an Assignment__c record).

**Design rationale:** the decision hierarchy (rolling-off match → bench
match → overallocation/margin check → recruiting gap check) is
deterministic business logic over structured data — lives in Apex, not
left to LLM natural-language reasoning. The agent's job is narrating the
Apex output clearly and managing the human-approval gate before any
consequential action executes (per CLAUDE.md's hard rule).

**No standalone "Analytics Agent"** — CRM Analytics grounds these topics
directly via the unified recipe (Opportunity + Consultant__c +
Assignment__c), consistent with the lesson from every prior idea in this
project.

## 6. CRM Analytics
- Datasets: [ TODO ]
- Recipes: [ TODO ]
- Dashboard(s) for the "before" visual in the demo: [ TODO ]
## 7. Tableau Next (narrow, one sentence only — do not over-build) — LOCKED, CORRECTED

Placement in demo: right after the "requires human approval" beat, ~15-20
seconds, one static slide, no live product screen (per Phase 5's original
reasoning — do not reverse this while filming, even if it feels thin).

FACT CHECK (corrected from an earlier draft that conflated products):
Tableau Pulse and Tableau Next are separate products. Pulse is a Tableau
Cloud feature (proactive metric pushes). Tableau Next is a distinct,
Tableau+-licensed, agentic analytics environment built on Data 360, with
its own components: Tableau Semantics (the semantic layer) and three
built-in agents — Data Pro (AI-assisted semantic model/data prep),
Concierge (conversational Q&A over the semantic model), and Inspector
(root-cause/anomaly detection). Do not reference Pulse in this project's
Tableau Next narration — different product, different licensing tier.

What "doing this in Tableau Next" would concretely mean for Overrun,
if ever built (not now, not required for this submission):
1. A Tableau Semantics model over the same four objects already in use
   (Opportunity, Consultant__c, Project__c, Assignment__c), republished
   as governed business metrics: "Staffing Risk Count," "Average
   Consultant Allocation %," "Deals Requiring Approval This Week."
2. Concierge would answer OPEN-ENDED exploratory questions the
   Agentforce agent was never built to handle — e.g. "what's our
   average allocation trend this quarter" or "which consultants are
   closest to the ceiling even without a deal attached yet." This is
   genuinely different work than StaffingRiskService's fixed
   decision hierarchy — ad-hoc browsing, not a proactive compound
   check with a specific Happy/Risk/Gap answer shape.

Honest division of labor (this is the actual differentiator to say out
loud, not a vague "Tableau Next adds AI insights" claim):
- Agentforce agent = decision-support layer. Fixed, proactive,
  compound-signal check, specific answer shape.
- Tableau Next Concierge = exploration layer. Open-ended, ad-hoc,
  complements but does not replicate the deterministic logic (rolling-
  off match -> bench match -> overallocation check -> margin check ->
  gap) unless that logic were separately rebuilt into the semantic
  model or a custom action there too.

Locked narration line for the demo:
"This staffing risk check runs today on the CRM Analytics investment
Arihant already has — no migration required. Tableau Next's Concierge
could eventually let the team explore this same underlying data with
open-ended questions — but the specific compound-signal decision logic
we built here is a purpose-made engine, not something any semantic
layer gives you out of the box."

## 8. Demo script outline
- Hook: Priya, Monday morning, one question — "Give me a staffing risk
  check across active deals this week."
- Business pain: today this requires manually cross-referencing Sales
  pipeline, Resourcing schedules, and Finance margin data across separate
  systems — nobody does this proactively, so it's found too late.
- Compound-signal reveal (the wow moment): agent returns all three deals
  in one response — Bridgeway (clean match, Marcus), Harlow (risk
  flagged: overallocation + margin erosion, together), Corven (honest
  gap: no internal fit, 5-week hiring lead time, concrete alternative).
  Client names: Bridgeway, Harlow, Corven — no suffixes, simple to
  say on camera.
- Human approval step: for the Harlow risk-path recommendation, a human
  (Priya) approves the phased-start action before anything executes —
  agent drafts, human decides.
- Impact/outcome (projected, credible, tied to SPI Research stats):
  industry median utilization sits at 66.4%; this pattern is designed to
  catch the exact compounding risk (overallocation + margin erosion)
  that manual, siloed tracking misses until it's client-visible.
- Close: callback to the opening question — one query, three deals, three
  correctly different outcomes, no dashboard shows this today.

## 9. Open questions / risks
- [ ]