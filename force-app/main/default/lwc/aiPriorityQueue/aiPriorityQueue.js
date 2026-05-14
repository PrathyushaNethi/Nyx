import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getAIPriorityQueue from '@salesforce/apex/AIPriorityQueueController.getAIPriorityQueue';

const MAX_SCORE = 220;

const RISK_TIER_CONFIG = {
    Critical: { badgeClass: 'nyx-badge-critical', rankClass: 'nyx-rank-badge nyx-rank-critical', scoreBarClass: 'nyx-score-fill nyx-score-critical' },
    High:     { badgeClass: 'nyx-badge-high',     rankClass: 'nyx-rank-badge nyx-rank-high',     scoreBarClass: 'nyx-score-fill nyx-score-high' },
    Medium:   { badgeClass: 'nyx-badge-medium',   rankClass: 'nyx-rank-badge nyx-rank-medium',   scoreBarClass: 'nyx-score-fill nyx-score-medium' },
    Low:      { badgeClass: 'nyx-badge-low',       rankClass: 'nyx-rank-badge nyx-rank-low',     scoreBarClass: 'nyx-score-fill nyx-score-low' }
};

export default class AiPriorityQueue extends NavigationMixin(LightningElement) {
    @api title = 'AI Priority Queue';
    @api maxRecords = 10;

    @track priorityQueue = [];
    @track isLoading = true;
    @track hasError = false;
    @track errorMessage = '';

    wiredResult;

    @wire(getAIPriorityQueue, { maxRecords: '$maxRecords' })
    wiredQueue(result) {
        this.wiredResult = result;
        this.isLoading = true;
        if (result.data) {
            this.priorityQueue = result.data.map(item => this.enrichItem(item));
            this.hasError = false;
            this.isLoading = false;
        } else if (result.error) {
            this.hasError = true;
            this.errorMessage = result.error.body
                ? result.error.body.message
                : 'An error occurred loading the priority queue.';
            this.isLoading = false;
        }
    }

    enrichItem(item) {
        const score = item.AI_Composite_Score__c || 0;
        const scorePercent = Math.min(Math.round((score / MAX_SCORE) * 100), 100);

        let riskTier = 'Low';
        if (score >= 80)      riskTier = 'Critical';
        else if (score >= 60) riskTier = 'High';
        else if (score >= 40) riskTier = 'Medium';

        const config = RISK_TIER_CONFIG[riskTier] || RISK_TIER_CONFIG.Low;

        return {
            Id: item.Id,
            rank: item.Priority_Rank__c ? `#${item.Priority_Rank__c}` : '-',
            structureName: item.Structure__r ? item.Structure__r.Name : 'Unknown Structure',
            location: item.Structure__r ? (item.Structure__r.Location__c || 'No location') : 'No location',
            lastInspected: item.Days_Since_Inspection__c ? `${item.Days_Since_Inspection__c} days ago` : 'Never inspected',
            overdueInspection: item.Overdue_Inspection__c,
            score: Math.round(score),
            recommendedAction: item.Recommended_Action__c || 'No action',
            riskTier,
            badgeClass: config.badgeClass,
            rankClass: config.rankClass,
            scoreBarClass: config.scoreBarClass,
            scoreBarWidth: `width: ${scorePercent}%`
        };
    }

    get badgeLabel() {
        return `${this.priorityQueue.length} structures`;
    }

    get isEmpty() {
        return !this.isLoading && !this.hasError && this.priorityQueue.length === 0;
    }

    get hasData() {
        return !this.isLoading && !this.hasError && this.priorityQueue.length > 0;
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredResult).then(() => {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Refreshed',
                message: 'AI Priority Queue has been updated.',
                variant: 'success'
            }));
        });
    }

    handleItemClick(event) {
        const recordId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                actionName: 'view'
            }
        });
    }
}