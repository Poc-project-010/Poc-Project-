import { LightningElement, track } from 'lwc';
import URBANNEST_LOGO from '@salesforce/resourceUrl/UrbanNest_Logo';

export default class UnFooter extends LightningElement {
    @track isLogoFallback = false;
    logoUrl = URBANNEST_LOGO;

    handleLogoError() {
        this.isLogoFallback = true;
    }

    get currentYear() {
        return new Date().getFullYear();
    }
}