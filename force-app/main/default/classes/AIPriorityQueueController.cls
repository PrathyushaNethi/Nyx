public with sharing class AIPriorityQueueController {

    @AuraEnabled(cacheable=true)
    public static List<AI_Priority_Queue__c> getAIPriorityQueue(Integer maxRecords) {
        return [
            SELECT Id,
                   Name,
                   Priority_Rank__c,
                   AI_Composite_Score__c,
                   Recommended_Action__c,
                   Queue_Status__c,
                   Days_Since_Inspection__c,
                   Overdue_Inspection__c,
                   Structure__c,
                   Structure__r.Name,
                   Structure__r.Location__c,
                   Structure__r.Condition_Rating__c,
                   Structure__r.Last_Inspection_Date__c,
                   Wildfire_Risk_Score__c,
                   Wildfire_Risk_Score__r.Risk_Tier__c,
                   Wildfire_Risk_Score__r.Total_Risk_Score__c
            FROM AI_Priority_Queue__c
            WHERE Queue_Status__c = 'Active'
            ORDER BY AI_Composite_Score__c DESC NULLS LAST
            LIMIT :maxRecords
        ];
    }
}