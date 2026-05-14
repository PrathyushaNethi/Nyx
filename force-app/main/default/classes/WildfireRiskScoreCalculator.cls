public class WildfireRiskScoreCalculator {

    public static void calculateRiskScores(List<Id> inspectionIds) {
        
        // Query inspections with all related data
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

        List<Wildfire_Risk_Score__c> scoresToInsert = new List<Wildfire_Risk_Score__c>();
        List<Structure__c> structuresToUpdate = new List<Structure__c>();

        for (Inspection__c insp : inspections) {

            Wildfire_Risk_Score__c riskScore = new Wildfire_Risk_Score__c();
            riskScore.Structure__c = insp.Structure__c;
            riskScore.Calculation_Date__c = Date.today();

            // ── Rule 1: Instant Critical — Vegetation Line Contact ──
            Boolean lineContact = false;
            for (Vegetation_Observation__c vo : insp.Vegetation_Observations__r) {
                if (vo.Line_Contact__c) {
                    lineContact = true;
                    break;
                }
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
            Set<String> currentDefectTypes = new Set<String>();
            for (Defect_Finding__c df : insp.Defect_Findings__r) {
                defectScore += df.Defect_Score__c != null ? df.Defect_Score__c : 0;
                if (df.Defect_Type__c != null) {
                    currentDefectTypes.add(df.Defect_Type__c);
                }
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
                else                    ageScore = 0;
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

            // ── Rule 8: Repeat Defect Penalty ──
            Decimal repeatPenalty = 0;
            if (!currentDefectTypes.isEmpty()) {
                List<Defect_Finding__c> previousDefects = [
                    SELECT Id FROM Defect_Finding__c
                    WHERE Structure__c = :insp.Structure__c
                    AND Status__c != 'Resolved'
                    AND Defect_Type__c IN :currentDefectTypes
                    AND Inspection__c != :insp.Id
                    LIMIT 1
                ];
                if (!previousDefects.isEmpty()) {
                    repeatPenalty = 15;
                }
            }

            // ── Set all scores ──
            riskScore.Defect_Score__c     = Math.min(defectScore + repeatPenalty, 100);
            riskScore.Age_Score__c        = ageScore + windScore;
            riskScore.HFTD_Zone_Score__c  = hftdScore;
            riskScore.Clearance_Score__c  = clearanceScore;
            riskScore.Vegetation_Score__c = vegScore;

            scoresToInsert.add(riskScore);

            // ── Update Last Inspection Date on Structure ──
            structuresToUpdate.add(new Structure__c(
                Id = insp.Structure__c,
                Last_Inspection_Date__c = insp.Inspection_Date__c
            ));
        }

        if (!scoresToInsert.isEmpty()) {
            insert scoresToInsert;
        }

        if (!structuresToUpdate.isEmpty()) {
            update structuresToUpdate;
        }
    }
}