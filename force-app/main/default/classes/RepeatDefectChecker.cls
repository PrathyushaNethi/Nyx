public class RepeatDefectChecker {

    public static Boolean hasUnresolvedRepeatDefect(
        Id structureId, 
        List<Defect_Finding__c> currentDefects
    ) {
        // Get defect types from current inspection
        Set<String> currentDefectTypes = new Set<String>();
        for (Defect_Finding__c df : currentDefects) {
            if (df.Defect_Type__c != null) {
                currentDefectTypes.add(df.Defect_Type__c);
            }
        }

        if (currentDefectTypes.isEmpty()) return false;

        // Query previous unresolved defects on same structure
        List<Defect_Finding__c> previousDefects = [
            SELECT Id, Defect_Type__c, Status__c
            FROM Defect_Finding__c
            WHERE Structure__c = :structureId
            AND Status__c != 'Resolved'
            AND Defect_Type__c IN :currentDefectTypes
            AND Id NOT IN :currentDefects
            LIMIT 1
        ];

        return !previousDefects.isEmpty();
    }
}