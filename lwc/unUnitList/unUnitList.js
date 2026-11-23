import { LightningElement, api, track } from 'lwc';

export default class UnUnitList extends LightningElement {
    @api units = [];
    @track activeBhk = 'ALL';

    get bhkTabs() {
        if (!this.units) return [];
        const counts = { 'ALL': this.units.length, '1 BHK': 0, '2 BHK': 0, '3 BHK': 0 };

        this.units.forEach(u => {
            if (u.bhk && counts[u.bhk] !== undefined) {
                counts[u.bhk]++;
            }
        });

        const tabs = [
            { label: 'All Units', value: 'ALL', count: counts['ALL'] },
            { label: '1 BHK', value: '1 BHK', count: counts['1 BHK'] },
            { label: '2 BHK', value: '2 BHK', count: counts['2 BHK'] },
            { label: '3 BHK', value: '3 BHK', count: counts['3 BHK'] }
        ];

        return tabs.map(t => ({
            ...t,
            cssClass: this.activeBhk === t.value ? 'un-bhk-tab is-active' : 'un-bhk-tab'
        }));
    }

    get filteredUnits() {
        if (!this.units) return [];
        if (this.activeBhk === 'ALL') {
            return this.units;
        }
        return this.units.filter(u => u.bhk === this.activeBhk);
    }

    get hasFilteredUnits() {
        return this.filteredUnits && this.filteredUnits.length > 0;
    }

    handleTabSelect(event) {
        this.activeBhk = event.currentTarget.dataset.bhk;
    }

    handleUnitEnquire(event) {
        this.dispatchEvent(new CustomEvent('unitenquire', {
            detail: event.detail,
            bubbles: true,
            composed: true
        }));
    }
}