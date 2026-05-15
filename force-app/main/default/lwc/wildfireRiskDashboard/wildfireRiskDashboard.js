import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getDashboardData from '@salesforce/apex/WildfireRiskDashboardController.getDashboardData';

export default class WildfireRiskDashboard extends LightningElement {
    @track isLoading = true;
    @track dashboardData = {};

    wiredResult;

    @wire(getDashboardData)
    wiredData(result) {
        this.wiredResult = result;
        if (result.data) {
            this.dashboardData = result.data;
            this.isLoading = false;
        } else if (result.error) {
            this.isLoading = false;
        }
    }

    get criticalCount() { return this.dashboardData.criticalCount || 0; }
    get highCount()     { return this.dashboardData.highCount || 0; }
    get mediumCount()   { return this.dashboardData.mediumCount || 0; }
    get lowCount()      { return this.dashboardData.lowCount || 0; }
    get totalStructures() { return this.dashboardData.totalStructures || 0; }
    get openWorkOrders()  { return this.dashboardData.openWorkOrders || 0; }
    get overdueInspections() { return this.dashboardData.overdueInspections || 0; }
    get vegetationContacts() { return this.dashboardData.vegetationContacts || 0; }

    get criticalPercent() { return this.getPercent(this.criticalCount); }
    get highPercent()     { return this.getPercent(this.highCount); }
    get mediumPercent()   { return this.getPercent(this.mediumCount); }
    get lowPercent()      { return this.getPercent(this.lowCount); }

    get criticalBarStyle() { return `width: ${this.criticalPercent}%`; }
    get highBarStyle()     { return `width: ${this.highPercent}%`; }
    get mediumBarStyle()   { return `width: ${this.mediumPercent}%`; }
    get lowBarStyle()      { return `width: ${this.lowPercent}%`; }

    getPercent(count) {
        if (!this.totalStructures) return 0;
        return Math.round((count / this.totalStructures) * 100);
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredResult);
    }
}