@isTest
public class RepeatDefectCheckerTest {
    // Defect_Score__c is a formula — use Severity__c to drive it: Critical=40, High=25, Medium=10, Low=5

    static Structure__c makeStructure() {
        Structure__c s = new Structure__c();
        insert s;
        return s;
    }

    static Inspection__c makeInspection(Id structureId) {
        Inspection__c i = new Inspection__c(
            Structure__c = structureId,
            Inspection_Date__c = Date.today(),
            Overall_Result__c = 'Pass'
        );
        insert i;
        return i;
    }

    @isTest
    static void testReturnsTrueWhenUnresolvedRepeatExists() {
        Structure__c s = makeStructure();
        Inspection__c oldInsp = makeInspection(s.Id);
        Inspection__c newInsp = makeInspection(s.Id);

        insert new Defect_Finding__c(
            Inspection__c = oldInsp.Id, Structure__c = s.Id,
            Defect_Type__c = 'Lean', Severity__c = 'High', Status__c = 'Open'
        );

        Defect_Finding__c currentDefect = new Defect_Finding__c(
            Inspection__c = newInsp.Id, Structure__c = s.Id,
            Defect_Type__c = 'Lean', Severity__c = 'Medium', Status__c = 'Open'
        );
        insert currentDefect;

        Test.startTest();
        Boolean result = RepeatDefectChecker.hasUnresolvedRepeatDefect(s.Id, new List<Defect_Finding__c>{ currentDefect });
        Test.stopTest();

        Assert.isTrue(result, 'Should return true when an unresolved defect of the same type exists on the structure');
    }

    @isTest
    static void testReturnsFalseWhenNoPriorDefectsExist() {
        Structure__c s = makeStructure();
        Inspection__c insp = makeInspection(s.Id);

        Defect_Finding__c df = new Defect_Finding__c(
            Inspection__c = insp.Id, Structure__c = s.Id,
            Defect_Type__c = 'Lean', Severity__c = 'Medium', Status__c = 'Open'
        );
        insert df;

        Test.startTest();
        Boolean result = RepeatDefectChecker.hasUnresolvedRepeatDefect(s.Id, new List<Defect_Finding__c>{ df });
        Test.stopTest();

        Assert.isFalse(result, 'Should return false when no prior defects exist on the structure');
    }

    @isTest
    static void testReturnsFalseWhenPriorDefectIsResolved() {
        Structure__c s = makeStructure();
        Inspection__c oldInsp = makeInspection(s.Id);
        Inspection__c newInsp = makeInspection(s.Id);

        insert new Defect_Finding__c(
            Inspection__c = oldInsp.Id, Structure__c = s.Id,
            Defect_Type__c = 'Lean', Severity__c = 'Critical', Status__c = 'Resolved'
        );

        Defect_Finding__c currentDefect = new Defect_Finding__c(
            Inspection__c = newInsp.Id, Structure__c = s.Id,
            Defect_Type__c = 'Lean', Severity__c = 'Medium', Status__c = 'Open'
        );
        insert currentDefect;

        Test.startTest();
        Boolean result = RepeatDefectChecker.hasUnresolvedRepeatDefect(s.Id, new List<Defect_Finding__c>{ currentDefect });
        Test.stopTest();

        Assert.isFalse(result, 'A resolved prior defect should not count as a repeat');
    }

    @isTest
    static void testReturnsFalseForEmptyDefectList() {
        Structure__c s = makeStructure();

        Test.startTest();
        Boolean result = RepeatDefectChecker.hasUnresolvedRepeatDefect(s.Id, new List<Defect_Finding__c>());
        Test.stopTest();

        Assert.isFalse(result, 'Empty current defect list should always return false');
    }

    @isTest
    static void testReturnsFalseWhenDefectTypeIsNull() {
        Structure__c s = makeStructure();
        Inspection__c insp = makeInspection(s.Id);

        Defect_Finding__c df = new Defect_Finding__c(
            Inspection__c = insp.Id, Structure__c = s.Id,
            Severity__c = 'Medium', Status__c = 'Open'
        );
        insert df;

        Test.startTest();
        Boolean result = RepeatDefectChecker.hasUnresolvedRepeatDefect(s.Id, new List<Defect_Finding__c>{ df });
        Test.stopTest();

        Assert.isFalse(result, 'Null Defect_Type__c should not match any prior defect');
    }

    @isTest
    static void testReturnsFalseWhenDifferentDefectType() {
        Structure__c s = makeStructure();
        Inspection__c oldInsp = makeInspection(s.Id);
        Inspection__c newInsp = makeInspection(s.Id);

        insert new Defect_Finding__c(
            Inspection__c = oldInsp.Id, Structure__c = s.Id,
            Defect_Type__c = 'Corrosion', Severity__c = 'High', Status__c = 'Open'
        );

        Defect_Finding__c currentDefect = new Defect_Finding__c(
            Inspection__c = newInsp.Id, Structure__c = s.Id,
            Defect_Type__c = 'Lean', Severity__c = 'Medium', Status__c = 'Open'
        );
        insert currentDefect;

        Test.startTest();
        Boolean result = RepeatDefectChecker.hasUnresolvedRepeatDefect(s.Id, new List<Defect_Finding__c>{ currentDefect });
        Test.stopTest();

        Assert.isFalse(result, 'A prior defect of a different type should not count as a repeat');
    }
}
