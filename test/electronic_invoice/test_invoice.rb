require "test_helper"

class InvoiceTest < Minitest::Test
  def setup
    @invoice = ElectronicInvoice::Invoice.new(
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
          unit: "EA",
          net: 100.0,
          net_total: 1000.0,
          gross_total: 1190.0,
          tax_rate: 0.19,
          tax_category: "S",
          tax: 190.0,
          discount: 0.0,
          discounted_net_total: 1000.0,
          discount_reason: nil,
          currency_code: "EUR"
        }
      ],
      currency_code: "EUR",
      tax_category: "STANDARDRATE",
    )
  end

  def test_valid_invoice
    assert @invoice.valid?
  end

  def test_invalid_without_number
    @invoice.number = nil
    refute @invoice.valid?
    assert_includes @invoice.errors[:number], "can't be blank"
  end

  def test_to_xml
    xml = @invoice.to_xml

    assert_includes xml, '<ram:ID>INV-12345</ram:ID>'
    assert_includes xml, "<ram:IssueDateTime><udt:DateTimeString format=\"102\">#{Date.today.strftime('%Y%m%d')}</udt:DateTimeString></ram:IssueDateTime>"
    assert_includes xml, '<ram:Name>Seller Company</ram:Name>'
    assert_includes xml, '<ram:Name>Buyer Company</ram:Name>'
    assert_includes xml, '<ram:Name>Product 1</ram:Name>'
    assert_includes xml, '<ram:LineTotalAmount>10.00</ram:LineTotalAmount>'
    assert_includes xml, '<ram:GrandTotalAmount>11.90</ram:GrandTotalAmount>'
    assert_includes xml, '<ram:InvoiceCurrencyCode>EUR</ram:InvoiceCurrencyCode>'
  end

  def test_to_xml_with_errors_on_invoice
    @invoice.number = nil
    assert_raises ElectronicInvoice::Error do
      @invoice.to_xml
    end

    assert_includes @invoice.errors[:number], "can't be blank"
  end

  def test_to_xml_with_errors_on_line_item
    @invoice.invoice_line_items.first.description = nil
    assert_raises ElectronicInvoice::Error do
      @invoice.to_xml
    end

    assert_includes @invoice.invoice_line_items.first.errors[:description], "can't be blank"
  end

  def test_to_xml_with_errors_on_seller
    @invoice.seller_trade_party.name = nil
    assert_raises ElectronicInvoice::Error do
      @invoice.to_xml
    end

    assert_includes @invoice.seller_trade_party.errors[:name], "can't be blank"
  end

  def test_to_xml_withhout_buyer
    @invoice.buyer = {}
    assert_raises ElectronicInvoice::Error do
      @invoice.to_xml
    end

    assert_includes @invoice.errors[:buyer], "can't be blank"
  end
  def test_to_xml_withhout_seller
    @invoice.seller = {}
    assert_raises ElectronicInvoice::Error do
      @invoice.to_xml
    end

    assert_includes @invoice.errors[:seller], "can't be blank"
  end
  def test_to_xml_withhout_line_items
    @invoice.line_items = {}
    assert_raises ElectronicInvoice::Error do
      @invoice.to_xml
    end

    assert_includes @invoice.errors[:line_items], "must contain at least one item"
  end

  def test_tax_category_taken_from_line_items
    xml = @invoice.to_xml

    assert_includes xml, '<ram:ID>urn:cen.eu:en16931:2017</ram:ID>'
    assert_includes xml, '<ram:CategoryCode>S</ram:CategoryCode>'
    refute_includes xml, '<ram:ExemptionReason>'
  end

  def test_requires_seller_tax_registration
    @invoice.seller = @invoice.seller.except(:vat_id)
    refute @invoice.valid?
    assert_includes @invoice.errors[:seller], "VAT ID or tax ID is required"
  end

  def test_requires_iban_for_sepa_credit_transfer
    @invoice.iban = nil
    refute @invoice.valid?
    assert_includes @invoice.errors[:iban], "can't be blank"
  end

  def test_reverse_charge
    @invoice.buyer = @invoice.buyer.merge(vat_id: "FR12345678901")
    @invoice.line_items = [@invoice.line_items.first.merge(tax_category: "REVERSECHARGE", tax_rate: 0, tax: 0, gross_total: 1000.0)]
    @invoice.gross_total = 1000.0

    doc = Nokogiri::XML(@invoice.to_xml)
    tax = doc.at_xpath("//ram:ApplicableHeaderTradeSettlement/ram:ApplicableTradeTax")

    assert_equal %w[CalculatedAmount TypeCode ExemptionReason BasisAmount CategoryCode ExemptionReasonCode RateApplicablePercent],
      tax.element_children.map(&:name)
    assert_equal "Reverse Charge", tax.at_xpath("ram:ExemptionReason").text
    assert_equal "VATEX-EU-AE", tax.at_xpath("ram:ExemptionReasonCode").text
    assert_equal "AE", tax.at_xpath("ram:CategoryCode").text
    assert_equal "0.00", tax.at_xpath("ram:RateApplicablePercent").text
  end

  def test_reverse_charge_requires_buyer_vat_id
    @invoice.line_items = [@invoice.line_items.first.merge(tax_category: "AE", tax_rate: 0, tax: 0)]
    refute @invoice.valid?
    assert_includes @invoice.errors[:buyer], "VAT ID or registration number is required for tax category AE"
  end

  def test_untaxed_has_no_rate
    @invoice.line_items = [@invoice.line_items.first.merge(tax_category: "UNTAXED", tax_rate: 0, tax: 0)]
    @invoice.gross_total = 1000.0
    doc = Nokogiri::XML(@invoice.to_xml)

    assert_nil doc.at_xpath("//ram:IncludedSupplyChainTradeLineItem//ram:RateApplicablePercent")
    assert_equal "0.00", doc.at_xpath("//ram:ApplicableHeaderTradeSettlement/ram:ApplicableTradeTax/ram:RateApplicablePercent").text
    assert_equal "VATEX-EU-O", doc.at_xpath("//ram:ExemptionReasonCode").text
    assert_nil doc.at_xpath("//ram:SellerTradeParty/ram:SpecifiedTaxRegistration")
  end

  def test_mixed_tax_rates
    @invoice.line_items = [
      @invoice.line_items.first,
      @invoice.line_items.first.merge(description: "Book", tax_rate: 0.07, tax: 70.0, gross_total: 1070.0)
    ]
    @invoice.net_total = 2000.0
    @invoice.gross_total = 2260.0

    doc = Nokogiri::XML(@invoice.to_xml)
    taxes = doc.xpath("//ram:ApplicableHeaderTradeSettlement/ram:ApplicableTradeTax")

    assert_equal %w[19.00 7.00], taxes.map { _1.at_xpath("ram:RateApplicablePercent").text }
    assert_equal %w[1.90 0.70], taxes.map { _1.at_xpath("ram:CalculatedAmount").text }
    assert_equal "2.60", doc.at_xpath("//ram:TaxTotalAmount").text
  end

  def test_billing_period_before_discounts
    @invoice.delivery_date_until = Date.today
    @invoice.net_total = 1800.0
    @invoice.gross_total = 2142.0
    @invoice.line_items = [
      @invoice.line_items.first.merge(discount: 0.1, discounted_net_total: 900.0, tax: 171.0, discount_reason: "Rabatt"),
      @invoice.line_items.first.merge(description: "Product 2", discount: 0.1, discounted_net_total: 900.0, tax: 171.0, discount_reason: "Rabatt")
    ]

    doc = Nokogiri::XML(@invoice.to_xml)
    names = doc.at_xpath("//ram:ApplicableHeaderTradeSettlement").element_children.map(&:name)

    assert_operator names.index("BillingSpecifiedPeriod"), :<, names.index("SpecifiedTradeAllowanceCharge")

    allowance = doc.at_xpath("//ram:SpecifiedTradeAllowanceCharge")
    assert_equal "10.00", allowance.at_xpath("ram:CalculationPercent").text
    assert_equal "20.00", allowance.at_xpath("ram:BasisAmount").text
    assert_equal "2.00", allowance.at_xpath("ram:ActualAmount").text
    assert_equal "Rabatt", allowance.at_xpath("ram:Reason").text
  end

  def test_ship_to_party_only_contains_name_and_address
    @invoice.buyer = @invoice.buyer.merge(email: "buyer@example.com", vat_id: "DE987654321")
    doc = Nokogiri::XML(@invoice.to_xml)

    assert_equal %w[Name PostalTradeAddress], doc.at_xpath("//ram:ShipToTradeParty").element_children.map(&:name)
  end

  def test_xrechnung_requires_mandatory_fields
    @invoice.standard = :xrechnung
    @invoice.kind = "REVERSED_INVOICE"
    refute @invoice.valid?

    assert_includes @invoice.errors[:buyer_reference], "(Leitweg-ID) is required for XRechnung"
    assert_includes @invoice.errors[:kind], "is not allowed for XRechnung"
    assert_includes @invoice.errors[:seller], "Contact name is required for XRechnung"
    assert_includes @invoice.errors[:seller], "Phone is required for XRechnung"
    assert_includes @invoice.errors[:seller], "Email is required for XRechnung"
    assert_includes @invoice.errors[:seller], "Electronic address is required for XRechnung"
    assert_includes @invoice.errors[:buyer], "Electronic address is required for XRechnung"
  end

  def test_xrechnung
    @invoice.standard = :xrechnung
    @invoice.buyer_reference = "04011000-12345-34"
    @invoice.seller = @invoice.seller.merge(contact_name: "Max Muster", phone: "+49 30 123456",
      email: "billing@seller.example", electronic_address: "invoice@seller.example")
    @invoice.buyer = @invoice.buyer.merge(electronic_address: "invoice@buyer.example")

    doc = Nokogiri::XML(@invoice.to_xml)

    assert_equal "urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0",
      doc.at_xpath("//ram:GuidelineSpecifiedDocumentContextParameter/ram:ID").text
    assert_equal "04011000-12345-34", doc.at_xpath("//ram:BuyerReference").text

    seller = doc.at_xpath("//ram:SellerTradeParty")
    assert_equal %w[Name DefinedTradeContact PostalTradeAddress URIUniversalCommunication SpecifiedTaxRegistration],
      seller.element_children.map(&:name)
    assert_equal %w[PersonName TelephoneUniversalCommunication EmailURIUniversalCommunication],
      seller.at_xpath("ram:DefinedTradeContact").element_children.map(&:name)
    assert_equal "EM", seller.at_xpath("ram:URIUniversalCommunication/ram:URIID")["schemeID"]
    assert_equal "invoice@buyer.example", doc.at_xpath("//ram:BuyerTradeParty/ram:URIUniversalCommunication/ram:URIID").text
  end

  def test_totals_are_calculated_from_line_items
    @invoice.line_items = [@invoice.line_items.first.merge(qty: 3, net: 33.333, net_total: 100.0, tax: 19.0, gross_total: 119.0)]
    @invoice.net_total = 100.0
    @invoice.gross_total = 119.0

    doc = Nokogiri::XML(@invoice.to_xml)

    assert_equal "1.00", doc.at_xpath("//ram:SpecifiedTradeSettlementLineMonetarySummation/ram:LineTotalAmount").text
    assert_equal "1.00", doc.at_xpath("//ram:TaxBasisTotalAmount").text
    assert_equal "1.19", doc.at_xpath("//ram:GrandTotalAmount").text
  end

  def test_given_totals_have_to_match
    @invoice.gross_total = 1191.0
    refute @invoice.valid?
    assert_includes @invoice.errors[:gross_total], "does not match the calculated total of 11.90"
  end

  def test_line_net_total_has_to_match_qty_and_price
    @invoice.invoice_line_items.first.net_total = 1100.0
    assert_raises(ElectronicInvoice::Error) { @invoice.to_xml }
    assert_includes @invoice.invoice_line_items.first.errors[:net_total], "does not match qty * net"
  end

  def test_charges_and_prepaid_amount
    @invoice.charges = [{ amount: 500, reason: "Versand", reason_code: "FC", tax_rate: 0.19, tax_category: "S" }]
    @invoice.prepaid_amount = 595
    @invoice.net_total = 1500.0
    @invoice.gross_total = 1785.0

    doc = Nokogiri::XML(@invoice.to_xml)
    charge = doc.at_xpath("//ram:SpecifiedTradeAllowanceCharge")

    assert_equal "true", charge.at_xpath("ram:ChargeIndicator/udt:Indicator").text
    assert_equal %w[ChargeIndicator ActualAmount ReasonCode Reason CategoryTradeTax], charge.element_children.map(&:name)
    assert_equal "15.00", doc.at_xpath("//ram:ApplicableHeaderTradeSettlement/ram:ApplicableTradeTax/ram:BasisAmount").text
    assert_equal "2.85", doc.at_xpath("//ram:TaxTotalAmount").text
    assert_equal "5.00", doc.at_xpath("//ram:ChargeTotalAmount").text
    assert_equal "5.95", doc.at_xpath("//ram:TotalPrepaidAmount").text
    assert_equal "11.90", doc.at_xpath("//ram:DuePayableAmount").text
  end

  def test_charge_requires_reason
    @invoice.charges = [{ amount: 500, tax_rate: 0.19, tax_category: "S" }]
    assert_raises(ElectronicInvoice::Error) { @invoice.to_xml }
    assert_includes @invoice.invoice_charges.first.errors[:reason], "can't be blank"
  end

  def test_cash_discounts
    @invoice.cash_discounts = [{ days: 14, rate: 0.02 }, { days: 7, rate: 0.03, basis_amount: 1000 }]

    description = Nokogiri::XML(@invoice.to_xml).at_xpath("//ram:SpecifiedTradePaymentTerms/ram:Description").text

    assert_equal "30 days net\n#SKONTO#TAGE=14#PROZENT=2.00#\n#SKONTO#TAGE=7#PROZENT=3.00#BASISBETRAG=10.00#\n", description
  end

  def test_direct_debit
    @invoice.payment_type = "SEPA_DEBIT"
    refute @invoice.valid?
    assert_includes @invoice.errors[:mandate_reference], "can't be blank"

    @invoice.mandate_reference = "MANDATE-1"
    @invoice.creditor_reference_id = "DE98ZZZ09999999999"
    @invoice.debtor_iban = "DE02 1203 0000 0000 2020 51"

    doc = Nokogiri::XML(@invoice.to_xml)

    assert_equal "DE98ZZZ09999999999", doc.at_xpath("//ram:ApplicableHeaderTradeSettlement").element_children.first.text
    assert_equal "DE02120300000000202051", doc.at_xpath("//ram:PayerPartyDebtorFinancialAccount/ram:IBANID").text
    assert_nil doc.at_xpath("//ram:PayeePartyCreditorFinancialAccount")
    assert_equal "MANDATE-1", doc.at_xpath("//ram:DirectDebitMandateID").text
  end

  def test_invalid_iban
    @invoice.iban = "DE89370400440532013001"
    refute @invoice.valid?
    assert_includes @invoice.errors[:iban], "is not a valid IBAN"
  end

  def test_card_payment
    @invoice.payment_type = "CREDITCARD"
    @invoice.card_number = "1234"
    @invoice.card_holder = "Max Muster"

    doc = Nokogiri::XML(@invoice.to_xml)

    assert_equal "1234", doc.at_xpath("//ram:ApplicableTradeSettlementFinancialCard/ram:ID").text
    assert_nil doc.at_xpath("//ram:PayeePartyCreditorFinancialAccount")
  end

  def test_separate_ship_to_address
    @invoice.ship_to = { name: "Warehouse", street: "Dock", number: "7", zip_code: "20457", town: "Hamburg", country_code: "DE" }

    doc = Nokogiri::XML(@invoice.to_xml)

    assert_equal "Warehouse", doc.at_xpath("//ram:ShipToTradeParty/ram:Name").text
    assert_equal "Buyer Company", doc.at_xpath("//ram:BuyerTradeParty/ram:Name").text
  end

  def test_registration_number
    @invoice.seller = @invoice.seller.merge(registration_number: "HRB 12345")

    doc = Nokogiri::XML(@invoice.to_xml)

    assert_equal "HRB 12345", doc.at_xpath("//ram:SellerTradeParty/ram:SpecifiedLegalOrganization/ram:ID").text
  end

  def test_untaxed_cannot_be_combined
    @invoice.line_items = [@invoice.line_items.first, @invoice.line_items.first.merge(tax_category: "O", tax_rate: 0, tax: 0)]
    refute @invoice.valid?
    assert_includes @invoice.errors[:line_items], "must not combine tax category O with other tax categories"
  end

  def test_invalid_codes
    @invoice.currency_code = "EURO"
    @invoice.seller = @invoice.seller.merge(country_code: "XX")
    refute @invoice.all_valid?
    assert_includes @invoice.errors[:currency_code], "is not a valid ISO 4217 currency code"
    assert_includes @invoice.seller_trade_party.errors[:country_code], "is not a valid ISO 3166-1 country code"
  end

  def test_house_number_is_optional
    @invoice.buyer = @invoice.buyer.except(:number).merge(street: "Emmerich-Josef-Straße 1a")

    doc = Nokogiri::XML(@invoice.to_xml)

    assert_equal "Emmerich-Josef-Straße 1a", doc.at_xpath("//ram:BuyerTradeParty/ram:PostalTradeAddress/ram:LineOne").text
  end

  def test_error_message_of_line_items
    @invoice.invoice_line_items.first.description = nil

    error = assert_raises(ElectronicInvoice::Error) { @invoice.to_xml }
    assert_includes error.message, "Line item 1: Description can't be blank"
  end

  def test_error_messages_can_be_translated_by_the_app
    available_locales = I18n.available_locales
    I18n.available_locales = available_locales | [:de]
    I18n.backend.store_translations(:de, activemodel: {
      attributes: { "electronic_invoice/invoice": { iban: "IBAN" } },
      errors: { models: { "electronic_invoice/invoice": { attributes: { iban: { invalid_iban: "ist keine gültige IBAN" } } } } }
    })
    @invoice.iban = "DE00123"

    I18n.with_locale(:de) do
      refute @invoice.valid?
      assert_includes @invoice.errors.full_messages, "IBAN ist keine gültige IBAN"
    end

    I18n.with_locale(:en) do
      refute @invoice.valid?
      assert_includes @invoice.errors[:iban], "is not a valid IBAN"
    end
  ensure
    I18n.available_locales = available_locales
  end

  def test_buyer_errors_are_reported_once_without_ship_to
    @invoice.buyer = @invoice.buyer.except(:town)

    error = assert_raises(ElectronicInvoice::Error) { @invoice.to_xml }
    assert_equal 1, error.message.scan("Town can't be blank").size
    assert_includes error.message, "Buyer: Town can't be blank"
  end

  def test_separate_ship_to_address_is_validated
    @invoice.ship_to = { name: "Warehouse", street: "Dock", zip_code: "20457", country_code: "DE" }

    error = assert_raises(ElectronicInvoice::Error) { @invoice.to_xml }
    assert_includes error.message, "Ship to: Town can't be blank"
  end
end
