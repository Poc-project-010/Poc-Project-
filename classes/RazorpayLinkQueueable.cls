public class RazorpayLinkQueueable implements Queueable, Database.AllowsCallouts {
    private Id paymentId;
    private String name, phone, email;
    private Boolean upiOnly;

    public RazorpayLinkQueueable(Id paymentId, String name, String phone,
                                 String email, Boolean upiOnly) {
        this.paymentId = paymentId; this.name = name;
        this.phone = phone; this.email = email; this.upiOnly = upiOnly;
    }

    public void execute(QueueableContext ctx) {
        Payment__c p = [SELECT Id, Amount__c, Payment_Type__c
                        FROM Payment__c WHERE Id = :paymentId];

        RazorpayService.LinkResult r = RazorpayService.createPaymentLink(
            p.Id, p.Amount__c, name, phone, email,
            'Property Booking - ' + p.Payment_Type__c, upiOnly
        );

        if (r.success) {
            p.Digital_Receipt_Link__c = r.linkId;
            p.Receipt_URL__c     = r.shortUrl;
        } else {
            p.Status__c        = 'Failed';
            p.Error_Message__c = r.error;
        }
        update p;
    }
}