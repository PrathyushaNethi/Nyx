public class WildfireRiskScoreCalculator {

    public static void calculateRiskScores(List<Id> inspectionIds) {

        List<Inspection__c> inspections = [
            SELECT Id,
                   Structure__c,
                   Inspection_Date__c,
                   Wind_Speed__c,
                   Weather_Conditions__c,
                   Structure__r.Install_Date__c,
                   Structure__r.Circuit__r.HFTD_Zone__c,
                   (SELECT Id, Severity__c, Defect_Score__c,
                           Defect_Type__c, Status__c
                    FROM Defect_Findings__r),
                   (SELECT Id, Line_Contact__c,
                           Observation_Score__c,
                           Encroachment_Level__c
                    FROM Vegetation_Observations__r)
            FROM Inspection__c
            WHERE Id IN :inspectionIds
        ];

        // ── Pre-scan: collect all defect types per inspection for bulk repeat-defect lookup ──
        Map<Id, Set<String>> inspDefectTypes = new Map<Id, Set<String>>();
        Set<Id> structuresWithDefects = new Set<Id>();
        Set<String> allDefectTypes = new Set<String>();

        for (Inspection__c insp : inspections) {
            Set<String> types = new Set<String>();
            for (Defect_Finding__c df : insp.Defect_Findings__r) {
                if (df.Defect_Type__c != null) {
                    types.add(df.Defect_Type__c);
                    allDefectTypes.add(df.Defect_Type__c);
                }
            }
            if (!types.isEmpty()) {
                inspDefectTypes.put(insp.Id, types);
                structuresWithDefects.add(insp.Structure__c);
            }
        }

        // ── One bulk SOQL for all previous unresolved defects (replaces N SOQLs in loop) ──
        Set<String> repeatKeys = new Set<String>(); // structureId|defectType
        if (!structuresWithDefects.isEmpty()) {
            for (Defect_Finding__c df : [
                SELECT Structure__c, Defect_Type__c
                FROM Defect_Finding__c
                WHERE Structure__c IN :structuresWithDefects
                AND Status__c != 'Resolved'
                AND Defect_Type__c IN :allDefectTypes
                AND Inspection__c NOT IN :inspectionIds
            ]) {
                repeatKeys.add(df.Structure__c + '|' + df.Defect_Type__c);
            }
        }

        List<Wildfire_Risk_Score__c> scoresToInsert = new List<Wildfire_Risk_Score__c>();
        List<Structure__c> structuresToUpdate = new List<Structure__c>();

        for (Inspection__c insp : inspections) {

            Wildfire_Risk_Score__c riskScore = new Wildfire_Risk_Score__c();
            riskScore.Structure__c = insp.Structure__c;
            riskScore.Calculation_Date__c = Date.today();

            // ── Rule 1: Instant Critical — Vegetation Line Contact ──
            Boolean lineContact = false;
            for (Vegetation_Observation__c vo : insp.Vegetation_Observations__r) {
                if (vo.Line_Contact__c) { lineContact = true; break; }
            }

            if (lineContact) {
                riskScore.Defect_Score__c     = 100;
                riskScore.Age_Score__c        = 0;
                riskScore.HFTD_Zone_Score__c  = 0;
                riskScore.Clearance_Score__c  = 0;
                riskScore.Vegetation_Score__c = 0;
                scoresToInsert.add(riskScore);
                continue;
            }

            // ── Rule 2: Defect Score ──
            Decimal defectScore = 0;
            for (Defect_Finding__c df : insp.Defect_Findings__r) {
                defectScore += df.Defect_Score__c != null ? df.Defect_Score__c : 0;
            }
            defectScore = Math.min(defectScore, 100);

            // ── Rule 3: Age Score ──
            Decimal ageScore = 0;
            if (insp.Structure__r.Install_Date__c != null) {
                Integer ageYears = insp.Structure__r.Install_Date__c.daysBetween(Date.today()) / 365;
                if      (ageYears > 55) ageScore = 20;
                else if (ageYears > 40) ageScore = 15;
                else if (ageYears > 25) ageScore = 10;
                else if (ageYears > 15) ageScore = 5;
            }

            // ── Rule 4: HFTD Zone Score ──
            Decimal hftdScore = 0;
            if (insp.Structure__r.Circuit__r != null) {
                String hftdZone = insp.Structure__r.Circuit__r.HFTD_Zone__c;
                if      (hftdZone == 'Tier 3') hftdScore = 30;
                else if (hftdZone == 'Tier 2') hftdScore = 20;
            }

            // ── Rule 5: Clearance Score — handled by Flow ──
            Decimal clearanceScore = 0;

            // ── Rule 6: Vegetation Score ──
            Decimal vegScore = 0;
            for (Vegetation_Observation__c vo : insp.Vegetation_Observations__r) {
                vegScore += vo.Observation_Score__c != null ? vo.Observation_Score__c : 0;
            }
            vegScore = Math.min(vegScore, 30);

            // ── Rule 7: Wind Score ──
            Decimal windScore = 0;
            if      (insp.Wind_Speed__c == 'Extreme')  windScore = 10;
            else if (insp.Wind_Speed__c == 'High')     windScore = 7;
            else if (insp.Wind_Speed__c == 'Moderate') windScore = 3;
            if (insp.Weather_Conditions__c != null) {
                String weather = insp.Weather_Conditions__c.toLowerCase();
                if (weather.contains('wind') || weather.contains('gusty')) {
                    windScore = Math.max(windScore, 5);
                }
            }

            // ── Rule 8: Repeat Defect Penalty — in-memory lookup, no SOQL in loop ──
            Decimal repeatPenalty = 0;
            if (inspDefectTypes.containsKey(insp.Id)) {
                for (String defectType : inspDefectTypes.get(insp.Id)) {
                    if (repeatKeys.contains(insp.Structure__c + '|' + defectType)) {
                        repeatPenalty = 15;
                        break;
                    }
                }
            }

            riskScore.Defect_Score__c     = Math.min(defectScore + repeatPenalty, 100);
            riskScore.Age_Score__c        = ageScore + windScore;
            riskScore.HFTD_Zone_Score__c  = hftdScore;
            riskScore.Clearance_Score__c  = clearanceScore;
            riskScore.Vegetation_Score__c = vegScore;

            scoresToInsert.add(riskScore);

            structuresToUpdate.add(new Structure__c(
                Id = insp.Structure__c,
                Last_Inspection_Date__c = insp.Inspection_Date__c
            ));
        }

        if (!scoresToInsert.isEmpty()) {
            insert scoresToInsert;
            syncAIPriorityQueue(scoresToInsert);
        }

        if (!structuresToUpdate.isEmpty()) {
            update structuresToUpdate;
        }
    }

    private static void syncAIPriorityQueue(List<Wildfire_Risk_Score__c> insertedScores) {
        Map<Id, Wildfire_Risk_Score__c> structureToScore = new Map<Id, Wildfire_Risk_Score__c>();
        for (Wildfire_Risk_Score__c wrs : insertedScores) {
            structureToScore.put(wrs.Structure__c, wrs);
        }

        Map<Id, AI_Priority_Queue__c> existingQueue = new Map<Id, AI_Priority_Queue__c>();
        for (AI_Priority_Queue__c q : [
            SELECT Id, Structure__c
            FROM AI_Priority_Queue__c
            WHERE Structure__c IN :structureToScore.keySet()
            AND Queue_Status__c = 'Active'
        ]) {
            existingQueue.put(q.Structure__c, q);
        }

        List<AI_Priority_Queue__c> queueToUpsert = new List<AI_Priority_Queue__c>();
        for (Id structureId : structureToScore.keySet()) {
            Wildfire_Risk_Score__c wrs = structureToScore.get(structureId);

            Decimal totalScore = nvl(wrs.Defect_Score__c)
                + nvl(wrs.Age_Score__c)
                + nvl(wrs.HFTD_Zone_Score__c)
                + nvl(wrs.Clearance_Score__c)
                + nvl(wrs.Vegetation_Score__c);

            String action;
            if      (totalScore >= 80) action = 'Immediate Replace';
            else if (totalScore >= 60) action = 'Schedule Repair';
            else if (totalScore >= 40) action = 'Re-inspect';
            else                       action = 'Monitor';

            AI_Priority_Queue__c q = existingQueue.containsKey(structureId)
                ? existingQueue.get(structureId)
                : new AI_Priority_Queue__c(Structure__c = structureId);

            q.Wildfire_Risk_Score__c = wrs.Id;
            q.Queue_Status__c        = 'Active';
            q.Recommended_Action__c  = action;
            q.Last_Updated__c        = DateTime.now();
            queueToUpsert.add(q);
        }
        upsert queueToUpsert;

        List<AI_Priority_Queue__c> allActive = [
            SELECT Id
            FROM AI_Priority_Queue__c
            WHERE Queue_Status__c = 'Active'
            ORDER BY AI_Composite_Score__c DESC NULLS LAST
        ];
        List<AI_Priority_Queue__c> toRank = new List<AI_Priority_Queue__c>();
        for (Integer i = 0; i < allActive.size(); i++) {
            toRank.add(new AI_Priority_Queue__c(Id = allActive[i].Id, Priority_Rank__c = i + 1));
        }
        if (!toRank.isEmpty()) {
            update toRank;
        }
    }

    private static Decimal nvl(Decimal val) {
        return val != null ? val : 0;
    }
}
