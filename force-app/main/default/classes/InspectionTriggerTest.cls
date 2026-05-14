@isTest
public class InspectionTriggerTest {

    static Structure__c makeStructure() {
        Circuit__c c = new Circuit__c(Name = 'Trigger Test Circuit', HFTD_Zone__c = 'Non-HFTD');
        insert c;
        Structure__c s = new Structure__c(Circuit__c = c.Id);
        insert s;
        return s;
    }

    @isTest
    static void testInsertWithOverallResult_createsRiskScore() {
        Structure__c s = makeStructure();

        Test.startTest();
        insert new Inspection__c(
            Structure__c = s.Id,
            Inspection_Date__c = Date.today(),
            Overall_Result__c = 'Pass'
        );
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM Wildfire_Risk_Score__c WHERE Structure__c = :s.Id];
        Assert.areEqual(1, count, 'Inserting an Inspection with Overall_Result__c should create a Wildfire Risk Score');
    }

    @isTest
    static void testInsertWithoutOverallResult_doesNotCreateRiskScore() {
        Structure__c s = makeStructure();

        Test.startTest();
        insert new Inspection__c(
            Structure__c = s.Id,
            Inspection_Date__c = Date.today()
        );
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM Wildfire_Risk_Score__c WHERE Structure__c = :s.Id];
        Assert.areEqual(0, count, 'Inserting an Inspection without Overall_Result__c should not create a risk score');
    }

    @isTest
    static void testUpdateSettingOverallResult_createsRiskScore() {
        Structure__c s = makeStructure();

        Inspection__c insp = new Inspection__c(
            Structure__c = s.Id,
            Inspection_Date__c = Date.today()
        );
        insert insp;

        Test.startTest();
        insp.Overall_Result__c = 'Fail';
        update insp;
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM Wildfire_Risk_Score__c WHERE Structure__c = :s.Id];
        Assert.areEqual(1, count, 'Updating Overall_Result__c on an Inspection should create a Wildfire Risk Score');
    }

    @isTest
    static void testUpdateWithoutOverallResult_doesNotCreateRiskScore() {
        Structure__c s = makeStructure();

        Inspection__c insp = new Inspection__c(
            Structure__c = s.Id,
            Inspection_Date__c = Date.today()
        );
        insert insp;

        Test.startTest();
        insp.Weather_Conditions__c = 'Sunny';
        update insp;
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM Wildfire_Risk_Score__c WHERE Structure__c = :s.Id];
        Assert.areEqual(0, count, 'Updating non-result fields without Overall_Result__c should not create a risk score');
    }

    @isTest
    static void testBulkInsert_noGovernorLimits() {
        Circuit__c c = new Circuit__c(Name = 'Bulk Circuit', HFTD_Zone__c = 'Tier 2');
        insert c;

        List<Structure__c> structures = new List<Structure__c>();
        for (Integer i = 0; i < 50; i++) {
            structures.add(new Structure__c(Circuit__c = c.Id));
        }
        insert structures;

        List<Inspection__c> inspections = new List<Inspection__c>();
        for (Structure__c s : structures) {
            inspections.add(new Inspection__c(
                Structure__c = s.Id,
                Inspection_Date__c = Date.today(),
                Overall_Result__c = 'Pass'
            ));
        }

        Test.startTest();
        insert inspections;
        Test.stopTest();

        Set<Id> structureIds = new Map<Id, Structure__c>(structures).keySet();
        Integer count = [SELECT COUNT() FROM Wildfire_Risk_Score__c WHERE Structure__c IN :structureIds];
        Assert.areEqual(50, count, 'Bulk insert of 50 inspections should create 50 Wildfire Risk Scores');
    }
}
