\# Overrun — Project Guide for Claude Code



\## What this is

"Overrun" is an Agentforce + CRM Analytics submission for the #AgentforceInAction

Challenge. A delivery-manager-facing multi-agent system for a professional

services firm that detects a compound business risk: a deal about to close

(Sales), a consultant about to be over-allocated (Resourcing), and a project

margin about to erode (Finance) — three signals that live in separate silos

and are never joined until the overrun is already client-visible.



Full context lives in docs/PLAN.md — read it before making architectural

decisions.



\## Org

\- Default org alias: overrun-dev (Agentforce Developer Edition, includes Data 360)

\- No production org. No real customer data or PII, ever — synthetic data only

&#x20; (contest rule: real PII causes automatic disqualification).



\## Conventions

\- Use the simplest possible approach. Do not add abstractions, design patterns,

&#x20; or extra layers "for flexibility" unless explicitly asked. This is a contest

&#x20; demo, not an enterprise platform.

\- Apex: bulkified, `with sharing`, test classes required (aim for meaningful

&#x20; coverage, not just the 75% minimum for its own sake).

\- Naming: prefix custom objects/fields with nothing special — keep API names

&#x20; readable (e.g., Consultant\_Allocation\_\_c, not Cons\_Alloc\_\_c).

\- Flows: only where genuinely deterministic logic belongs (e.g., allocation

&#x20; ceiling enforcement). Reasoning/judgment belongs in the agent, not a Flow.

\- Agent Script: agents live under force-app/main/default/aiAuthoringBundles/.

&#x20; Treat this like any other metadata — version it, review diffs on it.

\- CRM Analytics assets (recipes, dataflows, dashboards, XMD) are committed as

&#x20; artifacts for backup/history but are NOT continuously round-tripped. After

&#x20; any deploy touching Wave metadata, manually re-run the recipe in the org and

&#x20; note that step in the PR description.



\## Verification loop — run before saying a task is done

\- `sf code-analyzer run` — static analysis (Apex/Flow/security)

\- `sf apex run test --result-format human` — Apex tests

\- `sf agent test run` — agent behavior tests (once agent tests exist)

\- `sf agent preview start --authoring-bundle <bundle-name> --simulate-actions`

&#x20; — manual smoke test of the agent



If a tool can close its own feedback loop (run a test, see it fail, fix it,

re-run), let it — don't just claim something works without checking.



\## Do NOT

\- Do not deploy to any org other than overrun-dev without being asked.

\- Do not invent business requirements not in docs/PLAN.md — ask instead of

&#x20; assuming.

\- Do not let an agent take a consequential action (staffing assignment,

&#x20; discount approval) without a human-approval step — this is a hard

&#x20; requirement of the design, not a preference.

