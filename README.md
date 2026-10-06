# ElectronicInvoice

ElectronicInvoice is a Ruby gem to generate electronic invoices as UN/CEFACT CII XML following EN 16931. It supports

- **ZUGFeRD / Factur-X** (profile EN 16931, default) – XML part only, embedding into a PDF/A-3 is not covered
- **XRechnung 3.0** (`standard: :xrechnung`), required for invoices to German public authorities

All amounts are given in cents. The totals of the invoice are calculated from the line items and charges; `net_total` and `gross_total` are optional and checked against the calculated totals if given.

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
    country_code: "DE",
    vat_id: "DE123456789"
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
      unit: "HOUR",
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
  currency_code: "EUR"
)
```

### XRechnung

Set `standard: :xrechnung` to generate an XRechnung 3.0 invoice. In addition to the EN 16931 requirements the following fields are mandatory:

- `buyer_reference` (Leitweg-ID) or `buyer[:electronic_invoicing_identifier]`
- `seller[:contact_name]`, `seller[:phone]` and `seller[:email]`
- `seller[:electronic_address]` and `buyer[:electronic_address]`
- `kind` must be one of `INVOICE`, `CREDIT_NOTE`, `CORRECTION` or `PART_INVOICE`
- Card payments (`CREDITCARD`) need the `card_number` (last digits only)

```ruby
invoice = ElectronicInvoice::Invoice.new(
  standard: :xrechnung,
  buyer_reference: "04011000-12345-34",
  seller: {
    # ...
    contact_name: "Jane Doe",
    phone: "+49 30 123456",
    email: "billing@seller.example",
    electronic_address: "invoice@seller.example"
  },
  buyer: {
    # ...
    electronic_address: "invoice@buyer.example"
  },
  # ...
)
```

### Additional features

```ruby
ElectronicInvoice::Invoice.new(
  # ...
  # Separate delivery address (defaults to the buyer)
  ship_to: { name: "Warehouse", street: "Dock", number: "7", zip_code: "20457", town: "Hamburg", country_code: "DE" },
  # Document level charges, e.g. freight (reason_code from UNTDID 7161, tax is calculated if not given)
  charges: [{ amount: 1500, reason: "Shipping", reason_code: "FC", tax_rate: 0.19, tax_category: "S" }],
  # Prepayments already received, e.g. for a final invoice after advance invoices
  prepaid_amount: 50000,
  # Cash discounts, written in the XRechnung Skonto format into the payment terms
  cash_discounts: [{ days: 14, rate: 0.02 }, { days: 7, rate: 0.03, basis_amount: 100000 }],
  # SEPA direct debit
  payment_type: "SEPA_DEBIT",
  mandate_reference: "MANDATE-1",
  creditor_reference_id: "DE98ZZZ09999999999",
  debtor_iban: "DE02120300000000202051"
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
<rsm:CrossIndustryInvoice xmlns:rsm="urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100" xmlns:qdt="urn:un:unece:uncefact:data:standard:QualifiedDataType:100" xmlns:ram="urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:udt="urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100">
  <rsm:ExchangedDocumentContext>
    <ram:GuidelineSpecifiedDocumentContextParameter>
      <ram:ID>urn:cen.eu:en16931:2017</ram:ID>
    </ram:GuidelineSpecifiedDocumentContextParameter>
  </rsm:ExchangedDocumentContext>
  <rsm:ExchangedDocument>
    <ram:ID>INV-12345</ram:ID>
    <ram:TypeCode>380</ram:TypeCode>
    <ram:IssueDateTime>
      <udt:DateTimeString format="102">20261001</udt:DateTimeString>
    </ram:IssueDateTime>
  </rsm:ExchangedDocument>
  <rsm:SupplyChainTradeTransaction>
    <ram:IncludedSupplyChainTradeLineItem>
      <ram:AssociatedDocumentLineDocument>
        <ram:LineID>1</ram:LineID>
      </ram:AssociatedDocumentLineDocument>
      <ram:SpecifiedTradeProduct>
        <ram:Name>Product 1</ram:Name>
      </ram:SpecifiedTradeProduct>
      <ram:SpecifiedLineTradeAgreement>
        <ram:GrossPriceProductTradePrice>
          <ram:ChargeAmount>1.0000</ram:ChargeAmount>
        </ram:GrossPriceProductTradePrice>
        <ram:NetPriceProductTradePrice>
          <ram:ChargeAmount>1.0000</ram:ChargeAmount>
        </ram:NetPriceProductTradePrice>
      </ram:SpecifiedLineTradeAgreement>
      <ram:SpecifiedLineTradeDelivery>
        <ram:BilledQuantity unitCode="HUR">10.0000</ram:BilledQuantity>
      </ram:SpecifiedLineTradeDelivery>
      <ram:SpecifiedLineTradeSettlement>
        <ram:ApplicableTradeTax>
          <ram:TypeCode>VAT</ram:TypeCode>
          <ram:CategoryCode>S</ram:CategoryCode>
          <ram:RateApplicablePercent>19.00</ram:RateApplicablePercent>
        </ram:ApplicableTradeTax>
        <ram:SpecifiedTradeSettlementLineMonetarySummation>
          <ram:LineTotalAmount>10.00</ram:LineTotalAmount>
        </ram:SpecifiedTradeSettlementLineMonetarySummation>
      </ram:SpecifiedLineTradeSettlement>
    </ram:IncludedSupplyChainTradeLineItem>
    <ram:ApplicableHeaderTradeAgreement>
      <ram:SellerTradeParty>
        <ram:Name>Seller Company</ram:Name>
        <ram:PostalTradeAddress>
          <ram:PostcodeCode>12345</ram:PostcodeCode>
          <ram:LineOne>Seller Street 1</ram:LineOne>
          <ram:CityName>Seller Town</ram:CityName>
          <ram:CountryID>DE</ram:CountryID>
        </ram:PostalTradeAddress>
        <ram:SpecifiedTaxRegistration>
          <ram:ID schemeID="VA">DE123456789</ram:ID>
        </ram:SpecifiedTaxRegistration>
      </ram:SellerTradeParty>
      <ram:BuyerTradeParty>
        <ram:Name>Buyer Company</ram:Name>
        <ram:PostalTradeAddress>
          <ram:PostcodeCode>54321</ram:PostcodeCode>
          <ram:LineOne>Buyer Street 2</ram:LineOne>
          <ram:CityName>Buyer Town</ram:CityName>
          <ram:CountryID>DE</ram:CountryID>
        </ram:PostalTradeAddress>
      </ram:BuyerTradeParty>
    </ram:ApplicableHeaderTradeAgreement>
    <ram:ApplicableHeaderTradeDelivery>
      <ram:ShipToTradeParty>
        <ram:Name>Buyer Company</ram:Name>
        <ram:PostalTradeAddress>
          <ram:PostcodeCode>54321</ram:PostcodeCode>
          <ram:LineOne>Buyer Street 2</ram:LineOne>
          <ram:CityName>Buyer Town</ram:CityName>
          <ram:CountryID>DE</ram:CountryID>
        </ram:PostalTradeAddress>
      </ram:ShipToTradeParty>
      <ram:ActualDeliverySupplyChainEvent>
        <ram:OccurrenceDateTime>
          <udt:DateTimeString format="102">20260926</udt:DateTimeString>
        </ram:OccurrenceDateTime>
      </ram:ActualDeliverySupplyChainEvent>
    </ram:ApplicableHeaderTradeDelivery>
    <ram:ApplicableHeaderTradeSettlement>
      <ram:InvoiceCurrencyCode>EUR</ram:InvoiceCurrencyCode>
      <ram:SpecifiedTradeSettlementPaymentMeans>
        <ram:TypeCode>58</ram:TypeCode>
        <ram:Information>SEPA Credit Transfer</ram:Information>
        <ram:PayeePartyCreditorFinancialAccount>
          <ram:IBANID>DE89370400440532013000</ram:IBANID>
          <ram:AccountName>Seller Company</ram:AccountName>
        </ram:PayeePartyCreditorFinancialAccount>
      </ram:SpecifiedTradeSettlementPaymentMeans>
      <ram:ApplicableTradeTax>
        <ram:CalculatedAmount>1.90</ram:CalculatedAmount>
        <ram:TypeCode>VAT</ram:TypeCode>
        <ram:BasisAmount>10.00</ram:BasisAmount>
        <ram:CategoryCode>S</ram:CategoryCode>
        <ram:RateApplicablePercent>19.00</ram:RateApplicablePercent>
      </ram:ApplicableTradeTax>
      <ram:SpecifiedTradePaymentTerms>
        <ram:Description>30 days net</ram:Description>
        <ram:DueDateDateTime>
          <udt:DateTimeString format="102">20261031</udt:DateTimeString>
        </ram:DueDateDateTime>
      </ram:SpecifiedTradePaymentTerms>
      <ram:SpecifiedTradeSettlementHeaderMonetarySummation>
        <ram:LineTotalAmount>10.00</ram:LineTotalAmount>
        <ram:ChargeTotalAmount>0.00</ram:ChargeTotalAmount>
        <ram:AllowanceTotalAmount>0.00</ram:AllowanceTotalAmount>
        <ram:TaxBasisTotalAmount>10.00</ram:TaxBasisTotalAmount>
        <ram:TaxTotalAmount currencyID="EUR">1.90</ram:TaxTotalAmount>
        <ram:GrandTotalAmount>11.90</ram:GrandTotalAmount>
        <ram:TotalPrepaidAmount>0.00</ram:TotalPrepaidAmount>
        <ram:DuePayableAmount>11.90</ram:DuePayableAmount>
      </ram:SpecifiedTradeSettlementHeaderMonetarySummation>
    </ram:ApplicableHeaderTradeSettlement>
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
- `net_total`: The net total amount of the invoice (optional, checked against the calculated total).
- `gross_total`: The gross total amount of the invoice (optional, checked against the calculated total).
- `tax_category`: Deprecated, the tax categories are taken from the line items.
- `tax_exemption_reason`: Overrides the default exemption reason for non standard tax categories (e.g. reverse charge).
- `standard`: `:zugferd` (default) or `:xrechnung`.
- `buyer_reference`: A reference identifier for the buyer (Leitweg-ID for XRechnung).
- `seller`: A hash containing seller details (see TradeParty attributes).
- `buyer`: A hash containing buyer details (see TradeParty attributes).
- `line_items`: An array of line items (see LineItem attributes).
- `currency_code`: The currency code (e.g., "EUR").
- `payment_terms`: The payment terms (e.g., "30 days net").
- `payment_type`: The type of payment (e.g., "SEPA_CREDIT").
- `payment_information`: Information about the payment.
- `iban`: The IBAN of the seller, required for credit transfers (`SEPA_CREDIT`, `CREDIT_TRANSFER`).
- `mandate_reference`, `creditor_reference_id`, `debtor_iban`: SEPA mandate reference, creditor identifier and IBAN of the buyer, required for `SEPA_DEBIT`.
- `card_number`, `card_holder`: Last digits of the card and the card holder for `CREDITCARD`.
- `ship_to`: A hash containing the delivery address (see TradeParty attributes), defaults to the buyer.
- `charges`: An array of document level charges (see Charge attributes).
- `prepaid_amount`: The amount already paid.
- `cash_discounts`: An array of cash discounts with `days`, `rate` (fraction, e.g. 0.02) and optional `basis_amount`.
- `preceding_invoice_reference`: A reference to the preceding invoice, if applicable.
- `preceding_invoice_date`: The date of the preceding invoice, if applicable.
- `regulatory_information`: Regulatory information related to the invoice.
- `header_text`: Header text for the invoice.
- `footer_text`: Footer text for the invoice.

### TradeParty

- `reference`: A reference identifier for the trade party.
- `name`: The name of the trade party.
- `email`: The contact email address of the trade party.
- `contact_name`: The contact person of the trade party.
- `phone`: The contact phone number of the trade party.
- `electronic_address`: The electronic address (email) of the trade party, required for XRechnung.
- `street`: The street address of the trade party.
- `number`: The street number of the trade party.
- `addition`: Additional address information.
- `zip_code`: The postal code of the trade party.
- `town`: The town/city of the trade party.
- `country_code`: The country code of the trade party.
- `vat_id`: The VAT ID of the trade party. The seller needs a VAT ID or tax ID, reverse charge requires the VAT ID of both parties.
- `tax_id`: The tax ID (Steuernummer) of the seller.
- `registration_number`: The legal registration number of the trade party, e.g. the commercial register number.
- `electronic_invoicing_identifier`: The electronic invoicing identifier.

### LineItem

- `description`: A description of the line item.
- `qty`: The quantity of the line item.
- `unit`: The unit of measure, either a key of `UNIT_CODES` (e.g. "HOUR") or a UN/ECE Rec 20 code (e.g. "C62").
- `net`: The net amount for the line item.
- `net_total`: The net total amount for the line item, has to match `qty * net`.
- `gross_total`: The gross total amount for the line item.
- `tax_rate`: The tax rate for the line item.
- `tax_category`: The tax category, either a key of `TAX_CATEGORY_CODES` (e.g. "REVERSECHARGE") or the code (e.g. "AE").
- `tax`: The tax amount for the line item.
- `discount`: The discount for the line item as fraction (e.g. 0.1 for 10%).
- `discounted_net_total`: The discounted net total amount for the line item.
- `discount_reason`: The reason for the discount.
- `currency_code`: The currency code for the line item.

### Charge

- `amount`: The amount of the charge.
- `reason`: The reason for the charge, required if no `reason_code` is given.
- `reason_code`: The UNTDID 7161 reason code (e.g. "FC" for freight).
- `tax_rate`: The tax rate for the charge.
- `tax_category`: The tax category for the charge.
- `tax`: The tax amount, calculated from `amount` and `tax_rate` if not given.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To check the generated XML against the official rules, download the [KoSIT validator](https://github.com/itplr-kosit/validator/releases) and the [XRechnung validator configuration](https://github.com/itplr-kosit/validator-configuration-xrechnung/releases) and run

```bash
KOSIT_VALIDATOR=path/to/validator-standalone.jar KOSIT_CONFIG=path/to/configuration bundle exec rake validate
```

This generates sample invoices for all supported features as ZUGFeRD and XRechnung (see `test/validation/scenarios.rb`) and validates them. Java is required.

To install this gem onto your local machine, run `bundle exec rake install`. The gem is not published to a gem server, it is used via git.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/crispymtn/electronic_invoice. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/crispymtn/electronic_invoice/blob/master/CODE_OF_CONDUCT.md).


## Code of Conduct

Everyone interacting in the ElectronicInvoice project"s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/crispymtn/electronic_invoice/blob/master/CODE_OF_CONDUCT.md).
