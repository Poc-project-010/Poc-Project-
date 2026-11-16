@RestResource(urlMapping='/razorpay/webhooks/v1/*')
global without sharing class RazorpayWebhook {
    String RazorpayWebhookSecret = 'RAZORPAYSECERT';
    
    @HttpPost
    global static void handle() {
        RestRequest req  = RestContext.request;
        RestResponse res = RestContext.response;
        String body = req.requestBody.toString();
        
        // 1. Verify signature
        String signature;
        for (String h : req.headers.keySet()) {
            if (h.equalsIgnoreCase('X-Razorpay-Signature')) signature = req.headers.get(h);
        }
        Blob mac = Crypto.generateMac('hmacSHA256',
                                      Blob.valueOf(body), Blob.valueOf(Label.RazorpayWebhookSecret));
        if (signature == null || EncodingUtil.convertToHex(mac) != signature) {
            res.statusCode = 401;
            return;
        }
        
        // 2. Route by events
        Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(body);
        String event = (String) root.get('event');
        Map<String, Object> payload = (Map<String, Object>) root.get('payload');
        
        try {
            if (event == 'payment_link.paid') {
                handlePaid(payload);
            } else if (event == 'payment_link.expired' || event == 'payment_link.cancelled') {
                handleLinkClosed(payload);
            } else if (event == 'refund.processed') {
                handleRefund(payload);
            } else if(event == 'payment.failed'){
                handleFailed(payload);
            }else if (event == 'refund.processed') {
                handleRefundResult(payload, true);
            } else if (event == 'refund.failed') {
                handleRefundResult(payload, false);
            }
            
            res.statusCode = 200;
        } catch (Exception e) {
            System.debug('Razorpay webhook error: ' + e.getMessage());
            res.statusCode = 500; // Razorpay will retry
        }
    }
    
    private static Map<String, Object> entity(Map<String, Object> payload, String key) {
        Map<String, Object> wrapper = (Map<String, Object>) payload.get(key);
        return wrapper == null ? null : (Map<String, Object>) wrapper.get('entity');
    }
    
    private static void handlePaid(Map<String, Object> payload) {
        Map<String, Object> link = entity(payload, 'payment_link');
        Map<String, Object> pay  = entity(payload, 'payment');
        
        List<Payment__c> found = [
            SELECT Id, Status__c FROM Payment__c
            WHERE Id = :(String) link.get('reference_id') LIMIT 1
        ];
        if (found.isEmpty() || found[0].Status__c == 'Success') return; // idempotent
        
        Long createdAt = Long.valueOf(String.valueOf(pay.get('created_at')));
        found[0].Status__c            = 'Success';
        found[0].Gateway_Payment_ID__c = (String) pay.get('id');
        found[0].Payment_Date__c       = DateTime.newInstance(createdAt * 1000L).date();
        update found[0];
    }
    
    private static void handleLinkClosed(Map<String, Object> payload) {
        Map<String, Object> link = entity(payload, 'payment_link');
        List<Payment__c> found = [
            SELECT Id, Status__c FROM Payment__c
            WHERE Gateway_Payment_ID__c = :(String) link.get('id') LIMIT 1
        ];
        if (!found.isEmpty() && found[0].Status__c == 'Pending') {
            found[0].Status__c = 'Failed';
            update found[0];
        }
    }
    
    private static void handleRefund(Map<String, Object> payload) {
        Map<String, Object> refund = entity(payload, 'refund');
        List<Payment__c> found = [
            SELECT Id FROM Payment__c
            WHERE Gateway_Payment_ID__c = :(String) refund.get('payment_id') LIMIT 1
        ];
        if (!found.isEmpty()) {
            found[0].Status__c = 'Refunded';
            update found[0];
        }
        
    }
    private static void handleFailed(Map<String, Object> payload) {
        Map<String, Object> pay = entity(payload, 'payment');
        Map<String, Object> notes = (Map<String, Object>) pay.get('notes');
        if (notes == null || notes.get('payment_id') == null) return;
        
        List<Payment__c> found = [
            SELECT Id, Status__c FROM Payment__c
            WHERE Id = :(String) notes.get('payment_id') LIMIT 1
        ];
        if (!found.isEmpty() && found[0].Status__c == 'Pending') {
            found[0].Error_Message__c = (String) pay.get('error_description');
            update found[0];
        }
    }
    private static void handleRefundResult(Map<String, Object> payload, Boolean ok) {
    Map<String, Object> refund = entity(payload, 'refund');

    List<Payment__c> found = [
        SELECT Id, Amount__c, Booking__c FROM Payment__c
        WHERE Gateway_Payment_ID__c = :(String) refund.get('payment_id') LIMIT 1
    ];
    if (found.isEmpty()) return;

    Payment__c p = found[0];
    Decimal refunded = Decimal.valueOf(String.valueOf(refund.get('amount'))).divide(100, 2);

    if (ok && refunded >= p.Amount__c) {
        p.Status__c = 'Refunded'; // only for full refunds
        update p;
    }
    update new Booking__c(
        Id = p.Booking__c,
        Refund_Status__c = ok ? 'Processed' : 'Failed'
    );
}
}