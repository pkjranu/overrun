/*
  StaffingRiskService.cls

  Implements the staffing decision hierarchy for the "Overrun" project.
  For each near-term Opportunity needing a skill, checks in order:
    1. A consultant rolling off another project in time (Happy path)
    2. A consultant already on the bench, unassigned (Happy path)
    3. The best available consultant, but would be overallocated and/or
       break the deal's margin target (Risk path)
    4. No internal match at all (Gap path)

  This is exposed as an Invocable Method so it can be called directly as
  an Agentforce Action. It is deliberately deterministic (no LLM judgment
  here) — the agent's job is to narrate this output and manage the
  human-approval step before any consequential action executes.
*/
public with sharing class StaffingRiskService {

    // ---- Input ----
    public class Request {
        @InvocableVariable(label='Opportunity Id (optional)' description='Leave blank to check all open, near-term opportunities that need staffing.')
        public String opportunityId;
    }

    // ---- Output ----
    public class Result {
        @InvocableVariable(label='Deal Name')
        public String dealName;

        @InvocableVariable(label='Outcome Type')
        public String outcomeType; // 'Happy', 'Risk', or 'Gap'

        @InvocableVariable(label='Summary')
        public String summary; // human-readable explanation for the agent to narrate

        @InvocableVariable(label='Recommended Consultant')
        public String recommendedConsultant; // may be blank for Gap outcomes

        @InvocableVariable(label='Requires Human Approval')
        public Boolean requiresApproval; // true for Risk path recommendations
    }

    private static final Integer ALLOCATION_CEILING = 110; // percent
    private static final Integer FULL_TIME_NEED = 100;     // assumed % need per new assignment

    @InvocableMethod(label='Get Staffing Risk Report' description='Runs the staffing decision hierarchy across near-term opportunities that need staffing.')
    public static List<Result> getStaffingRiskReport(List<Request> requests) {
        Request req = requests.isEmpty() ? new Request() : requests[0];

        if (String.isNotBlank(req.opportunityId)) {
            List<Opportunity> opps = [
                SELECT Id, Name, Amount, CloseDate, Probability,
                       Skill_Needed__c, Start_Needed__c, Target_Margin__c, Assumed_Level__c
                FROM Opportunity
                WHERE Id = :req.opportunityId
                LIMIT 1
            ];

            List<Result> results = new List<Result>();
            for (Opportunity opp : opps) {
                results.add(evaluateOpportunity(opp));
            }
            return results;
        }

        // Bulk case (no opportunityId): the Agentforce Action platform only exposes
        // singular scalar outputs, not lists, so every matching deal is evaluated
        // individually and then folded into ONE combined Result the agent can narrate.
        List<Opportunity> allOpps = [
            SELECT Id, Name, Amount, CloseDate, Probability,
                   Skill_Needed__c, Start_Needed__c, Target_Margin__c, Assumed_Level__c
            FROM Opportunity
            WHERE IsClosed = false
              AND Skill_Needed__c != null
              AND Start_Needed__c != null
            ORDER BY CloseDate ASC
            LIMIT 20
        ];

        if (allOpps.isEmpty()) {
            return new List<Result>();
        }

        List<Result> perDeal = new List<Result>();
        for (Opportunity opp : allOpps) {
            perDeal.add(evaluateOpportunity(opp));
        }

        return new List<Result>{ combineResults(perDeal) };
    }

    private static Result combineResults(List<Result> perDeal) {
        Set<String> outcomeTypes = new Set<String>();
        Boolean anyRequiresApproval = false;
        List<String> paragraphs = new List<String>();

        for (Result r : perDeal) {
            outcomeTypes.add(r.outcomeType);
            if (r.requiresApproval) {
                anyRequiresApproval = true;
            }
            paragraphs.add(r.dealName + ': ' + r.outcomeType + ' — ' + r.summary);
        }

        Result combined = new Result();
        combined.dealName = 'All Active Deals';
        combined.outcomeType = outcomeTypes.size() == 1 ? new List<String>(outcomeTypes)[0] : 'Mixed';
        combined.summary = String.join(paragraphs, '\n\n');
        combined.recommendedConsultant = '';
        combined.requiresApproval = anyRequiresApproval;
        return combined;
    }

    private static Result evaluateOpportunity(Opportunity opp) {
        Result r = new Result();
        r.dealName = opp.Name;
        r.requiresApproval = false;

        List<Consultant__c> candidates = [
            SELECT Id, Name, Skill__c, Level__c, Rate__c
            FROM Consultant__c
            WHERE Skill__c = :opp.Skill_Needed__c
        ];

        if (candidates.isEmpty()) {
            r.outcomeType = 'Gap';
            r.summary = 'No internal consultant has the required skill (' + opp.Skill_Needed__c +
                        '). Recommend checking external recruiting lead time or a subcontractor for this engagement.';
            r.recommendedConsultant = '';
            return r;
        }

        Set<Id> candidateIds = new Set<Id>();
        for (Consultant__c c : candidates) {
            candidateIds.add(c.Id);
        }

        Map<Id, List<Assignment__c>> assignmentsByConsultant = new Map<Id, List<Assignment__c>>();
        for (Assignment__c a : [
            SELECT Consultant__c, Allocation__c, Start_Date__c, End_Date__c
            FROM Assignment__c
            WHERE Consultant__c IN :candidateIds
              AND (End_Date__c = null OR End_Date__c >= TODAY)
        ]) {
            if (!assignmentsByConsultant.containsKey(a.Consultant__c)) {
                assignmentsByConsultant.put(a.Consultant__c, new List<Assignment__c>());
            }
            assignmentsByConsultant.get(a.Consultant__c).add(a);
        }

        for (Consultant__c c : candidates) {
            List<Assignment__c> assignments = assignmentsByConsultant.get(c.Id);
            if (assignments == null) continue;

            for (Assignment__c a : assignments) {
                if (a.End_Date__c != null && a.End_Date__c <= opp.Start_Needed__c) {
                    r.outcomeType = 'Happy';
                    r.recommendedConsultant = c.Name;
                    r.summary = c.Name + ' rolls off their current project on ' +
                                a.End_Date__c.format() + ', before ' + opp.Name +
                                ' needs staffing on ' + opp.Start_Needed__c.format() +
                                '. Exact skill match. Recommend assigning ' + c.Name + '.';
                    return r;
                }
            }
        }

        for (Consultant__c c : candidates) {
            if (!assignmentsByConsultant.containsKey(c.Id) || assignmentsByConsultant.get(c.Id).isEmpty()) {
                r.outcomeType = 'Happy';
                r.recommendedConsultant = c.Name;
                r.summary = c.Name + ' is currently unassigned and has the required skill. Recommend assigning ' + c.Name + '.';
                return r;
            }
        }

        Consultant__c bestCandidate = null;
        Decimal lowestAllocation = null;

        for (Consultant__c c : candidates) {
            Decimal totalAllocation = 0;
            for (Assignment__c a : assignmentsByConsultant.get(c.Id)) {
                totalAllocation += (a.Allocation__c == null ? 0 : a.Allocation__c);
            }
            if (lowestAllocation == null || totalAllocation < lowestAllocation) {
                lowestAllocation = totalAllocation;
                bestCandidate = c;
            }
        }

        Decimal projectedAllocation = lowestAllocation + FULL_TIME_NEED;
        Boolean overallocationRisk = projectedAllocation > ALLOCATION_CEILING;

        Boolean marginRisk = (bestCandidate.Level__c == 'Senior' &&
                               opp.Assumed_Level__c == 'Mid');

        if (overallocationRisk || marginRisk) {
            r.outcomeType = 'Risk';
            r.recommendedConsultant = bestCandidate.Name;
            r.requiresApproval = true;

            String summary = 'The only realistic match, ' + bestCandidate.Name + ', is already at ' +
                              lowestAllocation.setScale(0) + '% allocation.';
            if (overallocationRisk) {
                summary += ' Assigning them to ' + opp.Name + ' would push them to ' +
                           projectedAllocation.setScale(0) + '%.';
            }
            if (marginRisk) {
                summary += ' In addition, this deal was priced assuming a Mid-level consultant, but ' +
                           bestCandidate.Name + ' is Senior-rate — staffing them would likely drop the ' +
                           'project below its ' + (opp.Target_Margin__c == null ? '30' : String.valueOf(opp.Target_Margin__c)) +
                           '% target margin.';
            }
            summary += ' Recommend a phased start so ' + bestCandidate.Name +
                       ' finishes current work first, or renegotiating scope/pricing with the client. Requires human approval before staffing.';
            r.summary = summary;
            return r;
        }

        r.outcomeType = 'Happy';
        r.recommendedConsultant = bestCandidate.Name;
        r.summary = bestCandidate.Name + ' is available at ' + lowestAllocation.setScale(0) +
                    '% allocation and can be assigned without exceeding capacity or margin targets.';
        return r;
    }
}
