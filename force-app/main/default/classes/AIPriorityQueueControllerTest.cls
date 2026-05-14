@isTest
public class AIPriorityQueueControllerTest {

    @TestSetup
    static void setup() {
        Circuit__c circuit = new Circuit__c(Name = 'Test Circuit', HFTD_Zone__c = 'Non-HFTD');
        insert circuit;

        Structure__c s1 = new Structure__c(Circuit__c = circuit.Id);
        Structure__c s2 = new Structure__c(Circuit__c = circuit.Id);
        Structure__c s3 = new Structure__c(Circuit__c = circuit.Id);
        insert new List<Structure__c>{ s1, s2, s3 };

        // Total_Risk_Score is a formula (sum of component scores), so drive it via Defect_Score
        // wrs1: Total=80 → Tier=Critical → AI_Composite = 80 + 20 = 100
        // wrs2: Total=30 → Tier=Low     → AI_Composite = 30 + 5  = 35
        // wrs3: Total=10 → Tier=Low     → AI_Composite = 10 + 5  = 15 (will be Resolved)
        Wildfire_Risk_Score__c wrs1 = new Wildfire_Risk_Score__c(
            Structure__c = s1.Id, Calculation_Date__c = Date.today(),
            Defect_Score__c = 80, Age_Score__c = 0, HFTD_Zone_Score__c = 0,
            Clearance_Score__c = 0, Vegetation_Score__c = 0
        );
        Wildfire_Risk_Score__c wrs2 = new Wildfire_Risk_Score__c(
            Structure__c = s2.Id, Calculation_Date__c = Date.today(),
            Defect_Score__c = 30, Age_Score__c = 0, HFTD_Zone_Score__c = 0,
            Clearance_Score__c = 0, Vegetation_Score__c = 0
        );
        Wildfire_Risk_Score__c wrs3 = new Wildfire_Risk_Score__c(
            Structure__c = s3.Id, Calculation_Date__c = Date.today(),
            Defect_Score__c = 10, Age_Score__c = 0, HFTD_Zone_Score__c = 0,
            Clearance_Score__c = 0, Vegetation_Score__c = 0
        );
        insert new List<Wildfire_Risk_Score__c>{ wrs1, wrs2, wrs3 };

        AI_Priority_Queue__c q1 = new AI_Priority_Queue__c(
            Structure__c = s1.Id, Wildfire_Risk_Score__c = wrs1.Id,
            Priority_Rank__c = 1, Queue_Status__c = 'Active'
        );
        AI_Priority_Queue__c q2 = new AI_Priority_Queue__c(
            Structure__c = s2.Id, Wildfire_Risk_Score__c = wrs2.Id,
            Priority_Rank__c = 2, Queue_Status__c = 'Active'
        );
        AI_Priority_Queue__c q3 = new AI_Priority_Queue__c(
            Structure__c = s3.Id, Wildfire_Risk_Score__c = wrs3.Id,
            Priority_Rank__c = 3, Queue_Status__c = 'Resolved'
        );
        insert new List<AI_Priority_Queue__c>{ q1, q2, q3 };
    }

    @isTest
    static void testReturnsOnlyActiveRecords() {
        Test.startTest();
        List<AI_Priority_Queue__c> result = AIPriorityQueueController.getAIPriorityQueue(10);
        Test.stopTest();

        Assert.areEqual(2, result.size(), 'Should return only Active queue records');
        for (AI_Priority_Queue__c item : result) {
            Assert.areEqual('Active', item.Queue_Status__c);
        }
    }

    @isTest
    static void testOrderedByScoreDescending() {
        Test.startTest();
        List<AI_Priority_Queue__c> result = AIPriorityQueueController.getAIPriorityQueue(10);
        Test.stopTest();

        Assert.areEqual(2, result.size());
        Assert.isTrue(
            result[0].AI_Composite_Score__c >= result[1].AI_Composite_Score__c,
            'Results should be ordered by AI_Composite_Score__c descending'
        );
    }

    @isTest
    static void testRespectsMaxRecordsLimit() {
        Test.startTest();
        List<AI_Priority_Queue__c> result = AIPriorityQueueController.getAIPriorityQueue(1);
        Test.stopTest();

        Assert.areEqual(1, result.size(), 'Should return at most maxRecords records');
    }

    @isTest
    static void testReturnsEmptyListWhenNoActiveRecords() {
        delete [SELECT Id FROM AI_Priority_Queue__c WHERE Queue_Status__c = 'Active'];

        Test.startTest();
        List<AI_Priority_Queue__c> result = AIPriorityQueueController.getAIPriorityQueue(10);
        Test.stopTest();

        Assert.areEqual(0, result.size(), 'Should return empty list when no Active records exist');
    }

    @isTest
    static void testRelatedFieldsArePopulated() {
        Test.startTest();
        List<AI_Priority_Queue__c> result = AIPriorityQueueController.getAIPriorityQueue(10);
        Test.stopTest();

        Assert.isNotNull(result[0].Structure__c, 'Structure lookup should be populated');
        Assert.isNotNull(result[0].Wildfire_Risk_Score__c, 'Wildfire Risk Score lookup should be populated');
    }
}
