public with sharing class WildfireRiskDashboardController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getDashboardData() {
        Map<String, Integer> data = new Map<String, Integer>();

        // Risk tier counts from Wildfire Risk Score
        data.put('criticalCount', 0);
        data.put('highCount', 0);
        data.put('mediumCount', 0);
        data.put('lowCount', 0);

        for (AggregateResult ar : [
            SELECT Risk_Tier__c tier, COUNT(Id) cnt
            FROM Wildfire_Risk_Score__c
            GROUP BY Risk_Tier__c
        ]) {
            String tier = (String) ar.get('tier');
            Integer cnt = Integer.valueOf(ar.get('cnt'));
            if (tier == 'Critical')     data.put('criticalCount', cnt);
            else if (tier == 'High')    data.put('highCount', cnt);
            else if (tier == 'Medium')  data.put('mediumCount', cnt);
            else if (tier == 'Low')     data.put('lowCount', cnt);
        }

        // Total structures
        data.put('totalStructures', [SELECT COUNT() FROM Structure__c]);

        // Open work orders
        data.put('openWorkOrders', [
            SELECT COUNT() FROM Work_Order__c
            WHERE Status__c NOT IN ('Completed', 'Cancelled')
        ]);

        // Overdue inspections from AI Priority Queue
        data.put('overdueInspections', [
            SELECT COUNT() FROM AI_Priority_Queue__c
            WHERE Overdue_Inspection__c = true
            AND Queue_Status__c = 'Active'
        ]);

        // Vegetation contacts
        data.put('vegetationContacts', [
            SELECT COUNT() FROM Vegetation_Observation__c
            WHERE Line_Contact__c = true
        ]);

        return data;
    }
}