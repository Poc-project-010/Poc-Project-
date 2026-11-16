public with sharing class RazorpayService {

    public class LinkResult {
        public Boolean success = false;
        public String linkId;
        public String shortUrl;
        public String error;
    }

    public static LinkResult createPaymentLink(
        Id paymentId, Decimal amount, String name,
        String phone, String email, String description, Boolean upiOnly
    ) {
        LinkResult result = new LinkResult();
        if (amount == null || amount <= 0) {
            result.error = 'Amount must be greater than zero';
            return result;
        }

        Map<String, Object> customer = new Map<String, Object>{
            'name' => name, 'contact' => phone, 'email' => email
        };
        Map<String, Object> payload = new Map<String, Object>{
            'amount'       => (amount * 100).setScale(0).longValue(), // paise
            'currency'     => 'INR',
            'description'  => description,
            'reference_id' => String.valueOf(paymentId),
            'customer'     => customer,
            'notify'       => new Map<String, Object>{ 'sms' => false, 'email' => false },
            'notes'        => new Map<String, Object>{ 'payment_id' => String.valueOf(paymentId) }
        };
        if (upiOnly == true) {
            payload.put('upi_link', true);
        }
        payload.put('expire_by', (DateTime.now().addDays(2).getTime() / 1000)); // epoch seconds

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:RazorPayNamedCredentials/v1/payment_links');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(payload));

        try {
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                Map<String, Object> body =
                    (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                result.success  = true;
                result.linkId   = (String) body.get('id');
                result.shortUrl = (String) body.get('short_url');
            } else {
                result.error = res.getStatusCode() + ': ' + res.getBody();
            }
        } catch (Exception e) {
            result.error = e.getMessage();
        }
        return result;
    }
}