@isTest
public class WildfireRiskScoreCalculatorTest {
    // Defect_Score__c formula: Critical=40, High=25, Medium=10, Low=5
    // Observation_Score__c formula: Contact=40, Severe=30, Moderate=15, Minimal=5
    //
    // Inspections are inserted WITHOUT Overall_Result__c so the trigger does not fire
    // and interfere with the direct calculator calls under test.

    static Circuit__c makeCircuit(String hftdZone) {
        Circuit__c c = new Circuit__c(Name = 'Circuit-' + hftdZone, HFTD_Zone__c = hftdZone);
        insert c;
        return c;
    }

    static Structure__c makeStructure(Id circuitId, Date installDate) {
        Structure__c s = new Structure__c(Circuit__c = circuitId, Install_Date__c = installDate);
        insert s;
        return s;
    }

    static Inspection__c makeInspection(Id structureId, String windSpeed, String weather) {
        Inspection__c i = new Inspection__c(
            Structure__c = structureId,
            Inspection_Date__c = Date.today(),
            Wind_Speed__c = windSpeed,
            Weather_Conditions__c = weather
        );
        insert i;
        return i;
    }

    @isTest
    static void testLineContactSetsInstantCritical() {
        Structure__c s = makeStructure(makeCircuit('Non-HFTD').Id, Date.today().addYears(-10));
        Inspection__c insp = makeInspection(s.Id, 'Calm', null);
        insert new Vegetation_Observation__c(Inspection__c = insp.Id, Line_Contact__c = true, Encroachment_Level__c = 'Minimal');

        Test.startTest();
        WildfireRiskScoreCalculator.calculateRiskScores(new List<Id>{ insp.Id });
        Test.stopTest();

        Wildfire_Risk_Score__c score = [
            SELECT Defect_Score__c, Age_Score__c, HFTD_Zone_Score__c, Clearance_Score__c, Vegetation_Score__c
            FROM Wildfire_Risk_Score__c WHERE Structure__c = :s.Id LIMIT 1
        ];
        Assert.areEqual(100, score.Defect_Score__c, 'Line contact should set defect score to 100');
        Assert.areEqual(0, score.Age_Score__c, 'Line contact path should zero age score');
        Assert.areEqual(0, score.HFTD_Zone_Score__c, 'Line contact path should zero HFTD score');
        Assert.areEqual(0, score.Vegetation_Score__c, 'Line contact path should zero vegetation score');
    }

    @isTest
    static void testDefectScoreAggregatesAndCapsAt100() {
        Structure__c s = makeStructure(makeCircuit('Non-HFTD').Id, null);
        Inspection__c insp = makeInspection(s.Id, 'Calm', null);
        // 3 Critical defects: 40 + 40 + 40 = 120 → capped at 100
        insert new List<Defect_Finding__c>{
            new Defect_Finding__c(Inspection__c = insp.Id, Structure__c = s.Id, Defect_Type__c = 'Lean', Severity__c = 'Critical', Status__c = 'Open'),
            new Defect_Finding__c(Inspection__c = insp.Id, Structure__c = s.Id, Defect_Type__c = 'Corrosion', Severity__c = 'Critical', Status__c = 'Open'),
            new Defect_Finding__c(Inspection__c = insp.Id, Structure__c = s.Id, Defect_Type__c = 'Burn Mark', Severity__c = 'Critical', Status__c = 'Open')
        };

        Test.startTest();
        WildfireRiskScoreCalculator.calculateRiskScores(new List<Id>{ insp.Id });
        Test.stopTest();

        Wildfire_Risk_Score__c score = [SELECT Defect_Score__c FROM Wildfire_Risk_Score__c WHERE Structure__c = :s.Id LIMIT 1];
        Assert.areEqual(100, score.Defect_Score__c, 'Defect score should be capped at 100');
    }

    @isTest
    static void testAgeScore_over55Years() {
        Structure__c s = makeStructure(makeCircuit('Non-HFTD').Id, Date.today().addYears(-60));
        Inspection__c insp = makeInspection(s.Id, 'Calm', null);

        Test.startTest();
        WildfireRiskScoreCalculator.calculateRiskScores(new List<Id>{ insp.Id });
        Test.stopTest();

        Wildfire_Risk_Score__c score = [SELECT Age_Score__c FROM Wildfire_Risk_Score__c WHERE Structure__c = :s.Id LIMIT 1];
        Assert.areEqual(20, score.Age_Score__c, 'Structure over 55 years old should score 20');
    }

    @isTest
    static void testAgeScore_over40Years() {
        Structure__c s = makeStructure(makeCircuit('Non-HFTD').Id, Date.today().addYears(-45));
        Inspection__c insp = makeInspection(s.Id, 'Calm', null);

        Test.startTest();
        WildfireRiskScoreCalculator.calculateRiskScores(new List<Id>{ insp.Id });
        Test.stopTest();

        Wildfire_Risk_Score__c score = [SELECT Age_Score__c FROM Wildfire_Risk_Score__c WHERE Structure__c = :s.Id LIMIT 1];
        Assert.areEqual(15, score.Age_Score__c, 'Structure over 40 years old should score 15');
    }

    @isTest
    static void testAgeScore_over25Years() {
        Structure__c s = makeStructure(makeCircuit('Non-HFTD').Id, Date.today().addYears(-30));
        Inspection__c insp = makeInspection(s.Id, 'Calm', null);

        Test.startTest();
        WildfireRiskScoreCalculator.calculateRiskScores(new List<Id>{ insp.Id });
        Test.stopTest();

        Wildfire_Risk_Score__c score = [SELECT Age_Score__c FROM Wildfire_Risk_Score__c WHERE Structure__c = :s.Id LIMIT 1];
        Assert.areEqual(10, score.Age_Score__c, 'Structure over 25 years old should score 10');
    }

    @isTest
    static void testAgeScore_over15Years() {
        Structure__c s = makeStructure(makeCircuit('Non-HFTD').Id, Date.today().addYears(-20));
        Inspection__c insp = makeInspection(s.Id, 'Calm', null);

        Test.startTest();
        WildfireRiskScoreCalculator.calculateRiskScores(new List<Id>{ insp.Id });
        Test.stopTest();

        Wildfire_Risk_Score__c score = [SELECT Age_Score__c FROM Wildfire_Risk_Score__c WHERE Structure__c = :s.Id LIMIT 1];
        Assert.areEqual(5, score.Age_Score__c, 'Structure over 15 years old should score 5');
    }

    @isTest
    static void testHftdZoneTier3Scores30() {
        Structure__c s = makeStructure(makeCircuit('Tier 3').Id, null);
        Inspection__c insp = makeInspection(s.Id, 'Calm', null);

        Test.startTest();
        WildfireRiskScoreCalculator.calculateRiskScores(new List<Id>{ insp.Id });
        Test.stopTest();

        Wildfire_Risk_Score__c score = [SELECT HFTD_Zone_Score__c FROM Wildfire_Risk_Score__c WHERE Structure__c = :s.Id LIMIT 1];
        Assert.areEqual(30, score.HFTD_Zone_Score__c, 'Tier 3 HFTD zone should score 30');
    }

    @isTest
    static void testHftdZoneTier2Scores20() {
        Structure__c s = makeStructure(makeCircuit('Tier 2').Id, null);
        Inspection__c insp = makeInspection(s.Id, 'Calm', null);

        Test.startTest();
        WildfireRiskScoreCalculator.calculateRiskScores(new List<Id>{ insp.Id });
        Test.stopTest();

        Wildfire_Risk_Score__c score = [SELECT HFTD_Zone_Score__c FROM Wildfire_Risk_Score__c WHERE Structure__c = :s.Id LIMIT 1];
        Assert.areEqual(20, score.HFTD_Zone_Score__c, 'Tier 2 HFTD zone should score 20');
    }

    @isTest
    static void testNonHftdZoneScores0() {
        Structure__c s = makeStructure(makeCircuit('Non-HFTD').Id, null);
        Inspection__c insp = makeInspection(s.Id, 'Calm', null);

        Test.startTest();
        WildfireRiskScoreCalculator.calculateRiskScores(new List<Id>{ insp.Id });
        Test.stopTest();

        Wildfire_Risk_Score__c score = [SELECT HFTD_Zone_Score__c FROM Wildfire_Risk_Score__c WHERE Structure__c = :s.Id LIMIT 1];
        Assert.areEqual(0, score.HFTD_Zone_Score__c, 'Non-HFTD zone should score 0');
    }

    @isTest
    static void testVegetationScoreAggregatesAndCapsAt30() {
        Structure__c s = makeStructure(makeCircuit('Non-HFTD').Id, null);
        Inspection__c insp = makeInspection(s.Id, 'Calm', null);
        // 2 Contact observations: 40 + 40 = 80 → capped at 30
        insert new List<Vegetation_Observation__c>{
            new Vegetation_Observation__c(Inspection__c = insp.Id, Line_Contact__c = false, Encroachment_Level__c = 'Contact'),
            new Vegetation_Observation__c(Inspection__c = insp.Id, Line_Contact__c = false, Encroachment_Level__c = 'Contact')
        };

        Test.startTest();
        WildfireRiskScoreCalculator.calculateRiskScores(new List<Id>{ insp.Id });
        Test.stopTest();

        Wildfire_Risk_Score__c score = [SELECT Vegetation_Score__c FROM Wildfire_Risk_Score__c WHERE Structure__c = :s.Id LIMIT 1];
        Assert.areEqual(30, score.Vegetation_Score__c, 'Vegetation score should be capped at 30');
    }

    @isTest
    static void testWindScore_extreme() {
        Structure__c s = makeStructure(makeCircuit('Non-HFTD').Id, null);
        Inspection__c insp = makeInspection(s.Id, 'Extreme', null);

        Test.startTest();
        WildfireRiskScoreCalculator.calculateRiskScores(new List<Id>{ insp.Id });
        Test.stopTest();

        Wildfire_Risk_Score__c score = [SELECT Age_Score__c FROM Wildfire_Risk_Score__c WHERE Structure__c = :s.Id LIMIT 1];
        Assert.areEqual(10, score.Age_Score__c, 'Extreme wind should add 10 to age+wind score');
    }

    @isTest
    static void testWindScore_high() {
        Structure__c s = makeStructure(makeCircuit('Non-HFTD').Id, null);
        Inspection__c insp = makeInspection(s.Id, 'High', null);

        Test.startTest();
        WildfireRiskScoreCalculator.calculateRiskScores(new List<Id>{ insp.Id });
        Test.stopTest();

        Wildfire_Risk_Score__c score = [SELECT Age_Score__c FROM Wildfire_Risk_Score__c WHERE Structure__c = :s.Id LIMIT 1];
        Assert.areEqual(7, score.Age_Score__c, 'High wind should add 7 to age+wind score');
    }

    @isTest
    static void testWindScore_moderate() {
        Structure__c s = makeStructure(makeCircuit('Non-HFTD').Id, null);
        Inspection__c insp = makeInspection(s.Id, 'Moderate', null);

        Test.startTest();
        WildfireRiskScoreCalculator.calculateRiskScores(new List<Id>{ insp.Id });
        Test.stopTest();

        Wildfire_Risk_Score__c score = [SELECT Age_Score__c FROM Wildfire_Risk_Score__c WHERE Structure__c = :s.Id LIMIT 1];
        Assert.areEqual(3, score.Age_Score__c, 'Moderate wind should add 3 to age+wind score');
    }

    @isTest
    static void testRepeatDefectAdds15PenaltyToDefectScore() {
        Structure__c s = makeStructure(makeCircuit('Non-HFTD').Id, null);

        Inspection__c oldInsp = makeInspection(s.Id, 'Calm', null);
        insert new Defect_Finding__c(
            Inspection__c = oldInsp.Id, Structure__c = s.Id,
            Defect_Type__c = 'Lean', Severity__c = 'Medium', Status__c = 'Open'
        );

        Inspection__c newInsp = makeInspection(s.Id, 'Calm', null);
        insert new Defect_Finding__c(
            Inspection__c = newInsp.Id, Structure__c = s.Id,
            Defect_Type__c = 'Lean', Severity__c = 'Medium', Status__c = 'Open'
        );

        Test.startTest();
        WildfireRiskScoreCalculator.calculateRiskScores(new List<Id>{ newInsp.Id });
        Test.stopTest();

        // Medium severity → Defect_Score__c (formula) = 10; plus 15 repeat penalty = 25
        Wildfire_Risk_Score__c score = [SELECT Defect_Score__c FROM Wildfire_Risk_Score__c WHERE Structure__c = :s.Id LIMIT 1];
        Assert.areEqual(25, score.Defect_Score__c, 'Repeat defect should add 15 penalty (10 + 15 = 25)');
    }

    @isTest
    static void testNoRepeatPenaltyWhenPriorDefectResolved() {
        Structure__c s = makeStructure(makeCircuit('Non-HFTD').Id, null);

        Inspection__c oldInsp = makeInspection(s.Id, 'Calm', null);
        insert new Defect_Finding__c(
            Inspection__c = oldInsp.Id, Structure__c = s.Id,
            Defect_Type__c = 'Lean', Severity__c = 'Medium', Status__c = 'Resolved'
        );

        Inspection__c newInsp = makeInspection(s.Id, 'Calm', null);
        insert new Defect_Finding__c(
            Inspection__c = newInsp.Id, Structure__c = s.Id,
            Defect_Type__c = 'Lean', Severity__c = 'Medium', Status__c = 'Open'
        );

        Test.startTest();
        WildfireRiskScoreCalculator.calculateRiskScores(new List<Id>{ newInsp.Id });
        Test.stopTest();

        // Medium severity → Defect_Score__c (formula) = 10; no repeat penalty
        Wildfire_Risk_Score__c score = [SELECT Defect_Score__c FROM Wildfire_Risk_Score__c WHERE Structure__c = :s.Id LIMIT 1];
        Assert.areEqual(10, score.Defect_Score__c, 'Resolved prior defect should not trigger repeat penalty');
    }

    @isTest
    static void testUpdatesStructureLastInspectionDate() {
        Structure__c s = makeStructure(makeCircuit('Non-HFTD').Id, null);
        Inspection__c insp = makeInspection(s.Id, 'Calm', null);

        Test.startTest();
        WildfireRiskScoreCalculator.calculateRiskScores(new List<Id>{ insp.Id });
        Test.stopTest();

        Structure__c updated = [SELECT Last_Inspection_Date__c FROM Structure__c WHERE Id = :s.Id];
        Assert.areEqual(Date.today(), updated.Last_Inspection_Date__c, 'Last_Inspection_Date__c should be set on the Structure');
    }

    @isTest
    static void testCreatesAIPriorityQueueRecord() {
        Structure__c s = makeStructure(makeCircuit('Tier 3').Id, null);
        Inspection__c insp = makeInspection(s.Id, 'Extreme', null);

        Test.startTest();
        WildfireRiskScoreCalculator.calculateRiskScores(new List<Id>{ insp.Id });
        Test.stopTest();

        List<AI_Priority_Queue__c> queue = [
            SELECT Id, Structure__c, Queue_Status__c, Recommended_Action__c,
                   Priority_Rank__c, Wildfire_Risk_Score__c
            FROM AI_Priority_Queue__c
            WHERE Structure__c = :s.Id
        ];
        Assert.areEqual(1, queue.size(), 'Should create one AI Priority Queue record per structure');
        Assert.areEqual('Active', queue[0].Queue_Status__c);
        Assert.isNotNull(queue[0].Wildfire_Risk_Score__c, 'Should link the new Wildfire Risk Score');
        Assert.areEqual(1, queue[0].Priority_Rank__c, 'Only record should be ranked #1');
    }

    @isTest
    static void testUpdatesExistingQueueRecordNotInsertsDuplicate() {
        Structure__c s = makeStructure(makeCircuit('Non-HFTD').Id, null);

        Inspection__c insp1 = makeInspection(s.Id, 'Calm', null);
        WildfireRiskScoreCalculator.calculateRiskScores(new List<Id>{ insp1.Id });

        Inspection__c insp2 = makeInspection(s.Id, 'High', null);

        Test.startTest();
        WildfireRiskScoreCalculator.calculateRiskScores(new List<Id>{ insp2.Id });
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM AI_Priority_Queue__c WHERE Structure__c = :s.Id AND Queue_Status__c = 'Active'];
        Assert.areEqual(1, count, 'Re-running the calculator should update the existing queue record, not create a duplicate');
    }

    @isTest
    static void testRecommendedAction_immediateReplace_forCriticalScore() {
        // Tier 3 (30) + Extreme wind (10) = 40 total → Re-inspect
        // Need score >= 80 for Immediate Replace: use 3 Critical defects (40+40+40=120 → cap 100) + Tier 3 (30) = 100+30 = 130 → cap doesn't apply to total
        // Actually total = Defect(100) + Age(0) + HFTD(30) + Clearance(0) + Veg(0) = 130 → Immediate Replace
        Structure__c s = makeStructure(makeCircuit('Tier 3').Id, null);
        Inspection__c insp = makeInspection(s.Id, 'Calm', null);
        insert new List<Defect_Finding__c>{
            new Defect_Finding__c(Inspection__c = insp.Id, Structure__c = s.Id, Defect_Type__c = 'Lean', Severity__c = 'Critical', Status__c = 'Open'),
            new Defect_Finding__c(Inspection__c = insp.Id, Structure__c = s.Id, Defect_Type__c = 'Corrosion', Severity__c = 'Critical', Status__c = 'Open'),
            new Defect_Finding__c(Inspection__c = insp.Id, Structure__c = s.Id, Defect_Type__c = 'Burn Mark', Severity__c = 'Critical', Status__c = 'Open')
        };

        Test.startTest();
        WildfireRiskScoreCalculator.calculateRiskScores(new List<Id>{ insp.Id });
        Test.stopTest();

        AI_Priority_Queue__c q = [SELECT Recommended_Action__c FROM AI_Priority_Queue__c WHERE Structure__c = :s.Id LIMIT 1];
        Assert.areEqual('Immediate Replace', q.Recommended_Action__c, 'Total score >= 80 should recommend Immediate Replace');
    }

    @isTest
    static void testRecommendedAction_monitor_forLowScore() {
        Structure__c s = makeStructure(makeCircuit('Non-HFTD').Id, null);
        Inspection__c insp = makeInspection(s.Id, 'Calm', null);

        Test.startTest();
        WildfireRiskScoreCalculator.calculateRiskScores(new List<Id>{ insp.Id });
        Test.stopTest();

        AI_Priority_Queue__c q = [SELECT Recommended_Action__c FROM AI_Priority_Queue__c WHERE Structure__c = :s.Id LIMIT 1];
        Assert.areEqual('Monitor', q.Recommended_Action__c, 'Zero score should recommend Monitor');
    }

    @isTest
    static void testPriorityRankingAcrossMultipleStructures() {
        Circuit__c circuit = makeCircuit('Non-HFTD');
        Structure__c s1 = makeStructure(circuit.Id, null);
        Structure__c s2 = makeStructure(circuit.Id, Date.today().addYears(-60)); // age score 20
        Structure__c s3 = makeStructure(circuit.Id, null);

        Inspection__c i1 = makeInspection(s1.Id, 'Calm', null);
        Inspection__c i2 = makeInspection(s2.Id, 'Extreme', null); // age=20 + wind=10 = 30
        Inspection__c i3 = makeInspection(s3.Id, 'Calm', null);
        insert new Defect_Finding__c(Inspection__c = i3.Id, Structure__c = s3.Id, Defect_Type__c = 'Lean', Severity__c = 'Critical', Status__c = 'Open'); // defect=40

        Test.startTest();
        WildfireRiskScoreCalculator.calculateRiskScores(new List<Id>{ i1.Id, i2.Id, i3.Id });
        Test.stopTest();

        // s3: defect=40, s2: age+wind=30, s1: 0 → ranks: s3=#1, s2=#2, s1=#3
        // AI_Composite_Score adds tier bonus and days bonus on top, but relative order holds
        Map<Id, AI_Priority_Queue__c> queueMap = new Map<Id, AI_Priority_Queue__c>();
        for (AI_Priority_Queue__c q : [SELECT Structure__c, Priority_Rank__c FROM AI_Priority_Queue__c WHERE Queue_Status__c = 'Active']) {
            queueMap.put(q.Structure__c, q);
        }

        Assert.isTrue(queueMap.get(s3.Id).Priority_Rank__c < queueMap.get(s2.Id).Priority_Rank__c, 's3 (defect 40) should rank above s2 (age+wind 30)');
        Assert.isTrue(queueMap.get(s2.Id).Priority_Rank__c < queueMap.get(s1.Id).Priority_Rank__c, 's2 (age+wind 30) should rank above s1 (score 0)');
    }

    @isTest
    static void testBulkInspections_noGovernorLimits() {
        Circuit__c circuit = makeCircuit('Tier 3');

        List<Structure__c> structures = new List<Structure__c>();
        for (Integer i = 0; i < 50; i++) {
            structures.add(new Structure__c(Circuit__c = circuit.Id));
        }
        insert structures;

        // No Overall_Result__c → trigger does not fire, calculator called directly below
        List<Inspection__c> inspections = new List<Inspection__c>();
        for (Structure__c s : structures) {
            inspections.add(new Inspection__c(
                Structure__c = s.Id,
                Inspection_Date__c = Date.today()
            ));
        }
        insert inspections;

        List<Id> inspectionIds = new List<Id>(new Map<Id, Inspection__c>(inspections).keySet());

        Test.startTest();
        WildfireRiskScoreCalculator.calculateRiskScores(inspectionIds);
        Test.stopTest();

        Set<Id> structureIds = new Map<Id, Structure__c>(structures).keySet();
        Integer count = [SELECT COUNT() FROM Wildfire_Risk_Score__c WHERE Structure__c IN :structureIds];
        Assert.areEqual(50, count, 'A Wildfire Risk Score should be created for each inspection in bulk');
    }
}
