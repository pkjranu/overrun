@isTest
private class StaffingRiskServiceTest {

    // ---- Test data helpers ----
    // Each test method calls these to build its own isolated records —
    // nothing here is shared across test methods via @TestSetup.

    private static Consultant__c createConsultant(String name, String skill, String level, Decimal rate) {
        Consultant__c c = new Consultant__c(
            Name = name,
            Skill__c = skill,
            Level__c = level,
            Rate__c = rate
        );
        insert c;
        return c;
    }

    private static Project__c createProject(String name, Date endDate) {
        Project__c p = new Project__c(
            Name = name,
            End_Date__c = endDate
        );
        insert p;
        return p;
    }

    private static Assignment__c createAssignment(String name, Id consultantId, Id projectId, Decimal allocation, Date startDate, Date endDate) {
        Assignment__c a = new Assignment__c(
            Name = name,
            Consultant__c = consultantId,
            Project__c = projectId,
            Allocation__c = allocation,
            Start_Date__c = startDate,
            End_Date__c = endDate
        );
        insert a;
        return a;
    }

    private static Opportunity createOpportunity(String name, String stageName, Date closeDate, String skillNeeded, Date startNeeded, String assumedLevel, Decimal targetMargin) {
        Opportunity opp = new Opportunity(
            Name = name,
            StageName = stageName,
            CloseDate = closeDate,
            Skill_Needed__c = skillNeeded,
            Start_Needed__c = startNeeded,
            Assumed_Level__c = assumedLevel,
            Target_Margin__c = targetMargin
        );
        insert opp;
        return opp;
    }

    private static StaffingRiskService.Result runForOpportunity(Id opportunityId) {
        StaffingRiskService.Request req = new StaffingRiskService.Request();
        req.opportunityId = opportunityId;

        Test.startTest();
        List<StaffingRiskService.Result> results = StaffingRiskService.getStaffingRiskReport(
            new List<StaffingRiskService.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected exactly one result for a single opportunity');
        return results[0];
    }

    // ---- 1. Happy path: consultant rolls off another project before the need date ----
    @isTest
    static void testHappyPath_ConsultantRollsOffInTime() {
        Date today = Date.today();

        Consultant__c consultant = createConsultant('Priya Rollout', 'Data Integration', 'Mid', 120);
        Project__c project = createProject('Legacy Migration', today.addDays(5));
        createAssignment('Priya - Legacy Migration', consultant.Id, project.Id, 100, today.addDays(-30), today.addDays(5));

        Opportunity opp = createOpportunity(
            'New Logo Alpha', 'Proposal/Price Quote', today.addDays(20),
            'Data Integration', today.addDays(10), 'Mid', 30
        );

        StaffingRiskService.Result r = runForOpportunity(opp.Id);

        System.assertEquals('Happy', r.outcomeType, 'A consultant rolling off before the need date should be a Happy outcome');
        System.assertEquals(false, r.requiresApproval, 'Happy outcomes must not require approval');
        System.assertEquals('Priya Rollout', r.recommendedConsultant);
        System.assert(r.summary.contains('Priya Rollout'), 'Summary should name the recommended consultant');
        System.assert(r.summary.contains('rolls off'), 'Summary should explain the roll-off reasoning');
    }

    // ---- 2. Happy path: consultant on the bench (no assignments at all) ----
    @isTest
    static void testHappyPath_ConsultantOnBench() {
        Date today = Date.today();

        Consultant__c consultant = createConsultant('Sam Bench', 'Cloud Migration', 'Mid', 110);
        // Deliberately no Assignment__c records for this consultant.

        Opportunity opp = createOpportunity(
            'New Logo Beta', 'Proposal/Price Quote', today.addDays(25),
            'Cloud Migration', today.addDays(15), 'Mid', 30
        );

        StaffingRiskService.Result r = runForOpportunity(opp.Id);

        System.assertEquals('Happy', r.outcomeType, 'An unassigned consultant with the right skill should be a Happy outcome');
        System.assertEquals(false, r.requiresApproval, 'Happy outcomes must not require approval');
        System.assertEquals('Sam Bench', r.recommendedConsultant);
        System.assert(r.summary.contains('unassigned'), 'Summary should explain the consultant is unassigned');
    }

    // ---- 3. Risk path: only match would be pushed past the allocation ceiling ----
    @isTest
    static void testRiskPath_Overallocation() {
        Date today = Date.today();

        // Mid-level consultant so this scenario isolates the overallocation trigger
        // from the margin-mismatch trigger (covered separately below).
        Consultant__c consultant = createConsultant('Dana Busy', 'Data Cloud Integration Architect', 'Mid', 150);
        Project__c project = createProject('Ongoing Build', today.addDays(90));
        createAssignment('Dana - Ongoing Build', consultant.Id, project.Id, 80, today.addDays(-10), today.addDays(90));

        Opportunity opp = createOpportunity(
            'New Logo Gamma', 'Proposal/Price Quote', today.addDays(20),
            'Data Cloud Integration Architect', today.addDays(10), 'Mid', 30
        );

        StaffingRiskService.Result r = runForOpportunity(opp.Id);

        System.assertEquals('Risk', r.outcomeType, 'A match that would be pushed past the allocation ceiling should be a Risk outcome');
        System.assertEquals(true, r.requiresApproval, 'Risk outcomes must require approval');
        System.assertEquals('Dana Busy', r.recommendedConsultant);
        System.assert(r.summary.contains('80%'), 'Summary should state current allocation');
        System.assert(r.summary.contains('180%'), 'Summary should state projected allocation');
        System.assert(r.summary.contains('human approval'), 'Summary should flag the human-approval requirement');
    }

    // ---- 3b. Risk path: allocation stays within ceiling, but level/margin mismatch trips risk ----
    @isTest
    static void testRiskPath_MarginMismatch() {
        Date today = Date.today();

        // Low allocation (10%) keeps projected allocation at exactly 110%, which is
        // NOT over the ceiling (ALLOCATION_CEILING check is strictly greater-than) —
        // this isolates the margin-mismatch trigger from the overallocation trigger.
        Consultant__c consultant = createConsultant('Efrem Senior', 'Data Cloud Integration Architect', 'Senior', 220);
        Project__c project = createProject('Small Build', today.addDays(90));
        createAssignment('Efrem - Small Build', consultant.Id, project.Id, 10, today.addDays(-10), today.addDays(90));

        Opportunity opp = createOpportunity(
            'New Logo Delta', 'Proposal/Price Quote', today.addDays(20),
            'Data Cloud Integration Architect', today.addDays(10), 'Mid', 30
        );

        StaffingRiskService.Result r = runForOpportunity(opp.Id);

        System.assertEquals('Risk', r.outcomeType, 'A Senior-only match against a Mid-priced deal should be a Risk outcome');
        System.assertEquals(true, r.requiresApproval, 'Risk outcomes must require approval');
        System.assertEquals('Efrem Senior', r.recommendedConsultant);
        System.assert(r.summary.contains('margin'), 'Summary should explain the margin mismatch');
        System.assert(!r.summary.contains('180%'), 'This scenario should not also describe an overallocation push');
    }

    // ---- 4. Gap path: no consultant has the required skill at all ----
    @isTest
    static void testGapPath_NoConsultantHasRequiredSkill() {
        Date today = Date.today();

        // Deliberately no Consultant__c records with this skill in this test's data.
        Opportunity opp = createOpportunity(
            'New Logo Epsilon', 'Proposal/Price Quote', today.addDays(20),
            'Data Cloud Integration Architect', today.addDays(10), 'Mid', 30
        );

        StaffingRiskService.Result r = runForOpportunity(opp.Id);

        System.assertEquals('Gap', r.outcomeType, 'No internal skill match should be a Gap outcome');
        System.assertEquals(false, r.requiresApproval, 'Gap outcomes must not require approval');
        System.assertEquals('', r.recommendedConsultant);
        System.assert(r.summary.contains('No internal consultant'), 'Summary should explain there is no internal match');
    }

    // ---- Happy path: best-available match is already partially allocated,
    //      but adding this deal stays within the allocation ceiling and
    //      doesn't trip the level/margin mismatch ----
    @isTest
    static void testHappyPath_AvailableWithinCapacityAndMargin() {
        Date today = Date.today();

        // 5% allocation projects to 105%, under the 110% ceiling; Mid-level
        // consultant against a Mid-assumed deal avoids the margin mismatch too.
        Consultant__c consultant = createConsultant('Nia Available', 'Data Cloud Integration Architect', 'Mid', 140);
        Project__c project = createProject('Steady Support', today.addDays(90));
        createAssignment('Nia - Steady Support', consultant.Id, project.Id, 5, today.addDays(-10), today.addDays(90));

        Opportunity opp = createOpportunity(
            'New Logo Iota', 'Proposal/Price Quote', today.addDays(20),
            'Data Cloud Integration Architect', today.addDays(10), 'Mid', 30
        );

        StaffingRiskService.Result r = runForOpportunity(opp.Id);

        System.assertEquals('Happy', r.outcomeType, 'A low-allocation match within the ceiling and margin should be a Happy outcome');
        System.assertEquals(false, r.requiresApproval, 'Happy outcomes must not require approval');
        System.assertEquals('Nia Available', r.recommendedConsultant);
        System.assert(r.summary.contains('5%'), 'Summary should state current allocation');
        System.assert(r.summary.contains('without exceeding capacity or margin targets'), 'Summary should confirm no risk was found');
    }

    // ---- Bulk query: no opportunityId supplied should only pick up open,
    //      near-term opportunities that actually need staffing, and should
    //      fold them into a single combined Result ----
    @isTest
    static void testBulkQuery_FiltersToOpenOpportunitiesNeedingStaffing() {
        Date today = Date.today();

        Opportunity validOpp = createOpportunity(
            'New Logo Zeta', 'Proposal/Price Quote', today.addDays(20),
            'Cloud Migration', today.addDays(10), 'Mid', 30
        );

        // Missing Skill_Needed__c — should be excluded by the query filter.
        Opportunity missingSkillOpp = new Opportunity(
            Name = 'New Logo Eta',
            StageName = 'Proposal/Price Quote',
            CloseDate = today.addDays(20),
            Start_Needed__c = today.addDays(10),
            Assumed_Level__c = 'Mid',
            Target_Margin__c = 30
        );
        insert missingSkillOpp;

        // Already closed — should be excluded by the IsClosed = false filter.
        Opportunity closedOpp = createOpportunity(
            'New Logo Theta', 'Closed Won', today.addDays(-1),
            'Cloud Migration', today.addDays(-5), 'Mid', 30
        );

        Test.startTest();
        List<StaffingRiskService.Result> results = StaffingRiskService.getStaffingRiskReport(
            new List<StaffingRiskService.Request>()
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'The bulk case should always fold into exactly one combined Result');
        System.assertEquals('All Active Deals', results[0].dealName);
        System.assert(results[0].summary.contains(validOpp.Name), 'Combined summary should mention the matching deal');
        System.assert(!results[0].summary.contains(missingSkillOpp.Name), 'Combined summary should not mention a deal missing Skill_Needed__c');
        System.assert(!results[0].summary.contains(closedOpp.Name), 'Combined summary should not mention an already-closed deal');
    }

    // ---- Bulk query: zero matching opportunities should return an empty list,
    //      not a fabricated combined Result -- the agent narrates "no deals" off
    //      an empty list, per the .agent instructions ----
    @isTest
    static void testBulkQuery_ZeroOpportunities_ReturnsEmptyList() {
        // Deliberately no Opportunity records inserted at all.
        Test.startTest();
        List<StaffingRiskService.Result> results = StaffingRiskService.getStaffingRiskReport(
            new List<StaffingRiskService.Request>()
        );
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Zero matching opportunities should produce an empty list, not a combined Result');
    }

    // ---- Bulk query: deals with different outcomes should combine into a
    //      single 'Mixed' Result, requiring approval if any deal does, and
    //      narrating each deal's own reasoning ----
    @isTest
    static void testBulkQuery_CombinesMixedOutcomesIntoOneResult() {
        Date today = Date.today();

        // Deal 1: Happy — consultant rolls off in time.
        Consultant__c happyConsultant = createConsultant('Priya Rollout', 'Data Integration', 'Mid', 120);
        Project__c happyProject = createProject('Legacy Migration', today.addDays(5));
        createAssignment('Priya - Legacy Migration', happyConsultant.Id, happyProject.Id, 100, today.addDays(-30), today.addDays(5));
        Opportunity happyOpp = createOpportunity(
            'New Logo Alpha', 'Proposal/Price Quote', today.addDays(20),
            'Data Integration', today.addDays(10), 'Mid', 30
        );

        // Deal 2: Risk — only match would be overallocated.
        Consultant__c riskConsultant = createConsultant('Dana Busy', 'Data Cloud Integration Architect', 'Mid', 150);
        Project__c riskProject = createProject('Ongoing Build', today.addDays(90));
        createAssignment('Dana - Ongoing Build', riskConsultant.Id, riskProject.Id, 80, today.addDays(-10), today.addDays(90));
        Opportunity riskOpp = createOpportunity(
            'New Logo Gamma', 'Proposal/Price Quote', today.addDays(21),
            'Data Cloud Integration Architect', today.addDays(10), 'Mid', 30
        );

        // Deal 3: Gap — no consultant has the required skill (no Cloud Migration
        // consultant exists in this test's data).
        Opportunity gapOpp = createOpportunity(
            'New Logo Epsilon', 'Proposal/Price Quote', today.addDays(22),
            'Cloud Migration', today.addDays(10), 'Mid', 30
        );

        Test.startTest();
        List<StaffingRiskService.Result> results = StaffingRiskService.getStaffingRiskReport(
            new List<StaffingRiskService.Request>()
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Three deals with mixed outcomes should still fold into one combined Result');
        StaffingRiskService.Result combined = results[0];

        System.assertEquals('All Active Deals', combined.dealName);
        System.assertEquals('Mixed', combined.outcomeType, 'Different outcome types across deals should combine to Mixed');
        System.assertEquals(true, combined.requiresApproval, 'Combined result must require approval if ANY deal does');
        System.assertEquals('', combined.recommendedConsultant, 'Combined result should not name a single consultant');

        System.assert(combined.summary.contains(happyOpp.Name) && combined.summary.contains('Happy'), 'Summary should narrate the Happy deal');
        System.assert(combined.summary.contains(riskOpp.Name) && combined.summary.contains('Risk'), 'Summary should narrate the Risk deal');
        System.assert(combined.summary.contains(gapOpp.Name) && combined.summary.contains('Gap'), 'Summary should narrate the Gap deal');
    }

    // ---- Bulk query: deals that all share the same outcome type should
    //      combine to that shared outcome, not 'Mixed' ----
    @isTest
    static void testBulkQuery_SameOutcomeAcrossDeals_UsesSharedOutcome() {
        Date today = Date.today();

        // Two deals, neither with any consultant of the required skill -> both Gap.
        // No Consultant__c records are inserted in this test at all.
        Opportunity gapOpp1 = createOpportunity(
            'New Logo Kappa', 'Proposal/Price Quote', today.addDays(20),
            'Data Integration', today.addDays(10), 'Mid', 30
        );
        Opportunity gapOpp2 = createOpportunity(
            'New Logo Lambda', 'Proposal/Price Quote', today.addDays(21),
            'Cloud Migration', today.addDays(10), 'Mid', 30
        );

        Test.startTest();
        List<StaffingRiskService.Result> results = StaffingRiskService.getStaffingRiskReport(
            new List<StaffingRiskService.Request>()
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Gap', results[0].outcomeType, 'When every deal shares the same outcome, the combined outcome should not be Mixed');
        System.assertEquals(false, results[0].requiresApproval, 'Gap-only outcomes should not require approval');
        System.assert(results[0].summary.contains(gapOpp1.Name));
        System.assert(results[0].summary.contains(gapOpp2.Name));
    }
}
