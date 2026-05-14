trigger InspectionTrigger on Inspection__c (after insert, after update) {
    
    Set<Id> inspectionIds = new Set<Id>();
    
    for (Inspection__c insp : Trigger.new) {
        // Only calculate if Overall Result is set
        if (insp.Overall_Result__c != null) {
            inspectionIds.add(insp.Id);
        }
    }
    
    if (!inspectionIds.isEmpty()) {
        WildfireRiskScoreCalculator.calculateRiskScores(
            new List<Id>(inspectionIds)
        );
    }
}