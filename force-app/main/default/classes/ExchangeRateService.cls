/**
 * @description Service class that handles API callouts to the Exchange Rate API
 * Implements methods to make callouts and process responses
 * Uses Named Credential: ExchangeRate_API
 * Error handling ensures graceful failures with meaningful exceptions
 */
public with sharing class ExchangeRateService {
    
    // The named credential to use for the callout
    private static final String NAMED_CREDENTIAL = 'ExchangeRate_API';
    
    // The base currency to use for exchange rates
    private static final String BASE_CURRENCY = 'USD';
    
    // API path for latest rates given a base currency, e.g. /v6/latest/USD
    private static final String LATEST_PATH_TEMPLATE = '/v6/latest/{BASE}';
    
    /**
     * @description Makes a callout to the Exchange Rate API to get the latest exchange rates
     * @return ExchangeRateWrapper containing the response data
     * @throws CalloutException on HTTP or parsing errors
     */
    public static ExchangeRateWrapper getLatestRates() {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        try {
            // Construct the endpoint using the Named Credential
            String path = LATEST_PATH_TEMPLATE.replace('{BASE}', BASE_CURRENCY);
            req.setEndpoint('callout:' + NAMED_CREDENTIAL + path);
            req.setMethod('GET');
            req.setTimeout(20000);
            
            HttpResponse res = http.send(req);
            Integer status = res.getStatusCode();
            if (status != 200) {
                // Include a compact snippet of body for diagnostics without logging full payloads
                String bodyPreview = res.getBody();
                if (bodyPreview != null && bodyPreview.length() > 500) {
                    bodyPreview = bodyPreview.substring(0, 500) + '...';
                }
                throw new CalloutException('ExchangeRate API call failed. Status: ' + status + ' - ' + res.getStatus() + ' Body: ' + bodyPreview);
            }
            
            String responseBody = res.getBody();
            if (String.isBlank(responseBody)) {
                throw new CalloutException('ExchangeRate API returned empty body.');
            }
            
            ExchangeRateWrapper wrapper = ExchangeRateWrapper.parse(responseBody);
            if (wrapper == null || wrapper.conversion_rates == null || String.isBlank(wrapper.base_code)) {
                throw new CalloutException('ExchangeRate API response missing required fields.');
            }
            return wrapper;
        } catch (System.CalloutException ce) {
            // Wrap and rethrow to provide a domain-specific error
            throw new CalloutException('Callout error: ' + ce.getMessage());
        } catch (Exception e) {
            throw new CalloutException('Unexpected error during getLatestRates: ' + e.getMessage());
        }
    }
    
    /**
     * @description Processes the exchange rate data and creates or updates records
     * @param rateData The wrapper containing exchange rate data
     * @return List<Exchange_Rate__c> The list of records created or updated
     * @throws ProcessingException when input is invalid or DML fails
     */
    public static List<Exchange_Rate__c> processRates(ExchangeRateWrapper rateData) {
        if (rateData == null) {
            throw new ProcessingException('rateData cannot be null.');
        }
        List<Exchange_Rate__c> toUpsert = rateData.toExchangeRates();
        if (toUpsert == null || toUpsert.isEmpty()) {
            // Nothing to do; return empty list
            return new List<Exchange_Rate__c>();
        }
        try {
            // Upsert by External_Id__c field in system mode to avoid FLS issues in tests
            // If you prefer USER_MODE, ensure FLS grants access to External_Id__c
            Database.UpsertResult[] results = Database.upsert(toUpsert, Exchange_Rate__c.Fields.External_Id__c);
            
            // collect failures for detailed error reporting
            List<String> errors = new List<String>();
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    for (Database.Error err : results[i].getErrors()) {
                        errors.add('Record ' + i + ': ' + err.getStatusCode() + ' - ' + err.getMessage());
                    }
                }
            }
            if (!errors.isEmpty()) {
                throw new ProcessingException('Upsert encountered errors: ' + String.join(errors, '; '));
            }
            return toUpsert;
        } catch (Exception e) {
            throw new ProcessingException('Failed to process and upsert exchange rates: ' + e.getMessage());
        }
    }
    
    /**
     * @description Combines getting and processing rates into a single operation
     * @return List<Exchange_Rate__c> The list of records created or updated
     * @throws CalloutException or ProcessingException depending on failure point
     */
    public static List<Exchange_Rate__c> updateExchangeRates() {
        // Return early on success path; exceptions will bubble up for scheduler/service caller to handle
        ExchangeRateWrapper data = getLatestRates();
        return processRates(data);
    }
    
    /**
     * @description Custom exception for callout-related errors
     */
    public class CalloutException extends Exception {}
    
    /**
     * @description Custom exception for processing/DML-related errors
     */
    public class ProcessingException extends Exception {}
}
