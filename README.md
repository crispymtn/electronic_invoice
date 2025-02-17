# ElectronicInvoice

ElectronicInvoice is a Ruby gem to generate XML invoices following the ZUGFeRD standard.

## Installation

Add this line to your application"s Gemfile:

```ruby
gem "electronic_invoice"
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install electronic_invoice
```

## Usage

To use the ElectronicInvoice gem, first require it in your Ruby script:

```ruby
require "electronic_invoice"
```

Then, you can create and manage invoices as follows:

```ruby
invoice = ElectronicInvoice::Invoice.new(
  number: "INV-12345",
  kind: "INVOICE",
  invoice_date: Date.today,
  due_date: Date.today + 30,
  delivery_date: Date.today - 5,
  net_total: 1000.0,
  payment_terms: "30 days net",
  payment_type: "SEPA_CREDIT",
  payment_information: "SEPA Credit Transfer",
  iban: "DE89370400440532013000",
  gross_total: 1190.0,
  seller: {
    name: "Seller Company",
    street: "Seller Street",
    number: "1",
    zip_code: "12345",
    town: "Seller Town",
    country_code: "DE"
  },
  buyer: {
    name: "Buyer Company",
    street: "Buyer Street",
    number: "2",
    zip_code: "54321",
    town: "Buyer Town",
    country_code: "DE"
  },
  line_items: [
    {
      description: "Product 1",
      qty: 10,
      unit: "EA",
      net: 100.0,
      net_total: 1000.0,
      gross_total: 1190.0,
      tax_rate: 0.19,
      tax_category: "STANDARDRATE",
      tax: 190.0,
      discount: 0.0,
      discounted_net_total: 1000.0,
      discount_reason: nil,
      currency_code: "EUR"
    }
  ],
  currency_code: "EUR",
  tax_category: "STANDARDRATE"
)
```

## Generating XML

To generate the XML representation of the invoice, use the `to_xml` method:

```ruby
xml = invoice.to_xml
```

This will output the XML string for the invoice, which can then be sent to the appropriate recipient or stored as needed.

### Example XML Output

```xml
<rsm:CrossIndustryInvoice xmlns:rsm="urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100" xmlns:ram="urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100" xmlns:udt="urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100">
  <rsm:ExchangedDocumentContext>
    <ram:GuidelineSpecifiedDocumentContextParameter>
      <ram:ID>urn:cen.eu:en16931:2017</ram:ID>
    </ram:GuidelineSpecifiedDocumentContextParameter>
  </rsm:ExchangedDocumentContext>
  <rsm:ExchangedDocument>
    <ram:ID>INV-12345</ram:ID>
    <ram:TypeCode>380</ram:TypeCode>
    <ram:IssueDateTime>
      <udt:DateTimeString format="102">20231010</udt:DateTimeString>
    </ram:IssueDateTime>
  </rsm:ExchangedDocument>
  <rsm:SupplyChainTradeTransaction>
    <ram:ApplicableHeaderTradeAgreement>
      <ram:SellerTradeParty>
        <ram:Name>Seller Company</ram:Name>
        <ram:PostalTradeAddress>
          <ram:LineOne>Seller Street 1</ram:LineOne>
          <ram:PostcodeCode>12345</ram:PostcodeCode>
          <ram:CityName>Seller Town</ram:CityName>
          <ram:CountryID>DE</ram:CountryID>
        </ram:PostalTradeAddress>
      </ram:SellerTradeParty>
      <ram:BuyerTradeParty>
        <ram:Name>Buyer Company</ram:Name>
        <ram:PostalTradeAddress>
          <ram:LineOne>Buyer Street 2</ram:LineOne>
          <ram:PostcodeCode>54321</ram:PostcodeCode>
          <ram:CityName>Buyer Town</ram:CityName>
          <ram:CountryID>DE</ram:CountryID>
        </ram:PostalTradeAddress>
      </ram:BuyerTradeParty>
    </ram:ApplicableHeaderTradeAgreement>
    <ram:ApplicableHeaderTradeSettlement>
      <ram:PaymentReference>INV-12345</ram:PaymentReference>
      <ram:InvoiceCurrencyCode>EUR</ram:InvoiceCurrencyCode>
      <ram:SpecifiedTradeSettlementPaymentMeans>
        <ram:TypeCode>30</ram:TypeCode>
        <ram:Information>SEPA Credit Transfer</ram:Information>
        <ram:PayeePartyCreditorFinancialAccount>
          <ram:IBANID>DE89370400440532013000</ram:IBANID>
        </ram:PayeePartyCreditorFinancialAccount>
      </ram:SpecifiedTradeSettlementPaymentMeans>
      <ram:ApplicableTradeTax>
        <ram:TypeCode>VAT</ram:TypeCode>
        <ram:CategoryCode>S</ram:CategoryCode>
        <ram:RateApplicablePercent>19.00</ram:RateApplicablePercent>
      </ram:ApplicableTradeTax>
      <ram:SpecifiedTradeSettlementMonetarySummation>
        <ram:LineTotalAmount>1000.00</ram:LineTotalAmount>
        <ram:ChargeTotalAmount>0.00</ram:ChargeTotalAmount>
        <ram:AllowanceTotalAmount>0.00</ram:AllowanceTotalAmount>
        <ram:TaxBasisTotalAmount>1000.00</ram:TaxBasisTotalAmount>
        <ram:TaxTotalAmount currencyID="EUR">190.00</ram:TaxTotalAmount>
        <ram:GrandTotalAmount>1190.00</ram:GrandTotalAmount>
        <ram:DuePayableAmount>1190.00</ram:DuePayableAmount>
      </ram:SpecifiedTradeSettlementMonetarySummation>
    </ram:ApplicableHeaderTradeSettlement>
    <ram:IncludedSupplyChainTradeLineItem>
      <ram:AssociatedDocumentLineDocument>
        <ram:LineID>1</ram:LineID>
      </ram:AssociatedDocumentLineDocument>
      <ram:SpecifiedTradeProduct>
        <ram:Name>Product 1</ram:Name>
      </ram:SpecifiedTradeProduct>
      <ram:SpecifiedLineTradeAgreement>
        <ram:GrossPriceProductTradePrice>
          <ram:ChargeAmount>100.00</ram:ChargeAmount>
        </ram:GrossPriceProductTradePrice>
        <ram:NetPriceProductTradePrice>
          <ram:ChargeAmount>100.00</ram:ChargeAmount>
        </ram:NetPriceProductTradePrice>
      </ram:SpecifiedLineTradeAgreement>
      <ram:SpecifiedLineTradeDelivery>
        <ram:BilledQuantity unitCode="EA">10.0000</ram:BilledQuantity>
      </ram:SpecifiedLineTradeDelivery>
      <ram:SpecifiedLineTradeSettlement>
        <ram:ApplicableTradeTax>
          <ram:TypeCode>VAT</ram:TypeCode>
          <ram:CategoryCode>S</ram:CategoryCode>
          <ram:RateApplicablePercent>19.00</ram:RateApplicablePercent>
        </ram:ApplicableTradeTax>
        <ram:SpecifiedTradeSettlementMonetarySummation>
          <ram:LineTotalAmount>1000.00</ram:LineTotalAmount>
        </ram:SpecifiedTradeSettlementMonetarySummation>
      </ram:SpecifiedLineTradeSettlement>
    </ram:IncludedSupplyChainTradeLineItem>
  </rsm:SupplyChainTradeTransaction>
</rsm:CrossIndustryInvoice>
```

## Overview of Attributes

### Invoice

- `number`: The invoice number.
- `kind`: The type of invoice (e.g., "INVOICE").
- `invoice_date`: The date the invoice was issued.
- `due_date`: The date the invoice is due.
- `delivery_date`: The date the goods/services were delivered.
- `delivery_date_until`: The end date for the delivery period.
- `net_total`: The net total amount of the invoice.
- `gross_total`: The gross total amount of the invoice.
- `tax_category`: The tax category (e.g., "STANDARDRATE" or "S").
- `tax_exemption_reason`: The reason for tax exemption, if applicable.
- `buyer_reference`: A reference identifier for the buyer.
- `seller`: A hash containing seller details (see TradeParty attributes).
- `buyer`: A hash containing buyer details (see TradeParty attributes).
- `line_items`: An array of line items (see LineItem attributes).
- `currency_code`: The currency code (e.g., "EUR").
- `payment_terms`: The payment terms (e.g., "30 days net").
- `payment_type`: The type of payment (e.g., "SEPA_CREDIT").
- `payment_information`: Information about the payment.
- `iban`: The IBAN for the payment.
- `preceding_invoice_reference`: A reference to the preceding invoice, if applicable.
- `preceding_invoice_date`: The date of the preceding invoice, if applicable.
- `regulatory_information`: Regulatory information related to the invoice.
- `header_text`: Header text for the invoice.
- `footer_text`: Footer text for the invoice.

### TradeParty

- `reference`: A reference identifier for the trade party.
- `name`: The name of the trade party.
- `email`: The email address of the trade party.
- `street`: The street address of the trade party.
- `number`: The street number of the trade party.
- `addition`: Additional address information.
- `zip_code`: The postal code of the trade party.
- `town`: The town/city of the trade party.
- `country_code`: The country code of the trade party.
- `vat_id`: The VAT ID of the trade party.
- `tax_id`: The tax ID of the trade party.
- `registration_number`: The registration number of the trade party.
- `electronic_invoicing_identifier`: The electronic invoicing identifier.

### LineItem

- `description`: A description of the line item.
- `qty`: The quantity of the line item.
- `unit`: The unit of measure for the line item.
- `net`: The net amount for the line item.
- `net_total`: The net total amount for the line item.
- `gross_total`: The gross total amount for the line item.
- `tax_rate`: The tax rate for the line item.
- `tax_category`: The tax category for the line item.
- `tax`: The tax amount for the line item.
- `discount`: The discount amount for the line item.
- `discounted_net_total`: The discounted net total amount for the line item.
- `discount_reason`: The reason for the discount.
- `currency_code`: The currency code for the line item.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/crispymtn/electronic_invoice. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/crispymtn/electronic_invoice/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the ElectronicInvoice project"s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/crispymtn/electronic_invoice/blob/master/CODE_OF_CONDUCT.md).
