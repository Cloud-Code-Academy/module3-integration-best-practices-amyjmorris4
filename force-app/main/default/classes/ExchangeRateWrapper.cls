/**
 * @description Wrapper class to deserialize the JSON response from the Exchange Rate API
 * Students will implement the properties and methods to process the data
 */
public class ExchangeRateWrapper {
    
    // Properties to match the JSON structure of the API response
    public String base_code;
    public Long time_last_update_unix;
    public Map<String, Decimal> conversion_rates;
    
    /**
     * @description Converts the wrapper data to a list of Exchange_Rate__c records
     * @return List<Exchange_Rate__c> The list of exchange rate records
     */
    public List<Exchange_Rate__c> toExchangeRates() {
        List<Exchange_Rate__c> exchangeRates = new List<Exchange_Rate__c>();
        
        if (conversion_rates != null) {
            for (String targetCurrency : conversion_rates.keySet()) {
                Exchange_Rate__c rate = new Exchange_Rate__c();
                rate.Base_Currency__c = base_code;
                rate.Target_Currency__c = targetCurrency;
                rate.Rate__c = conversion_rates.get(targetCurrency);
                rate.Last_Updated__c = Datetime.now();
                rate.External_Id__c = base_code + '_' + targetCurrency;
                
                exchangeRates.add(rate);
            }
        }
        
        return exchangeRates;
    }
    
    /**
     * @description Static method to parse the JSON response into the wrapper class
     * @param jsonResponse The JSON response from the API
     * @return ExchangeRateWrapper The parsed wrapper instance
     */
    public static ExchangeRateWrapper parse(String jsonResponse) {
        return (ExchangeRateWrapper) JSON.deserialize(jsonResponse, ExchangeRateWrapper.class);
    }
}