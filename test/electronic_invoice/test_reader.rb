require "test_helper"
require_relative "../validation/scenario_data"

class ReaderTest < Minitest::Test
  FIXTURES = File.expand_path("../fixtures", __dir__)

  def fixture(name)
    File.join(FIXTURES, name)
  end

  def amount(cents)
    cents.to_d / 100
  end

  # Every generated sample invoice is read back with the same content
  def test_round_trip_of_generated_invoices
    ValidationScenarios.each do |name, standard, invoice|
      read = ElectronicInvoice::Reader.from_xml(invoice.to_xml)
      label = "#{standard}-#{name}"

      assert_equal invoice.number, read.number, label
      assert_equal invoice.type_code, read.type_code, label
      assert_equal invoice.invoice_date, read.issue_date, label
      assert_equal invoice.delivery_date, read.delivery_date, label
      assert_equal invoice.due_date, read.due_date, label
      assert_equal "EUR", read.currency_code, label
      assert_equal (standard == :xrechnung ? :xrechnung : :en16931), read.profile, label
      assert read.e_invoice?, label

      assert_equal invoice.seller_trade_party.name, read.seller.name, label
      assert_equal invoice.seller_trade_party.tax_id, read.seller.tax_id, label
      assert_equal invoice.buyer_trade_party.name, read.buyer.name, label
      assert_equal invoice.buyer_trade_party.country_code, read.buyer.country_code, label

      assert_equal invoice.invoice_line_items.size, read.line_items.size, label
      invoice.invoice_line_items.zip(read.line_items).each do |item, line|
        assert_equal item.description, line.name, label
        assert_equal amount(item.line_total), line.net_total, label
        assert_equal item.tax_category_code, line.tax_category, label
        assert_equal ElectronicInvoice.unit_code(item.unit), line.unit_code, label
      end

      assert_equal amount(invoice.line_total_amount), read.totals.line_total, label
      assert_equal amount(invoice.allowance_total_amount), read.totals.allowance_total, label
      assert_equal amount(invoice.charge_total_amount), read.totals.charge_total, label
      assert_equal amount(invoice.tax_basis_total_amount), read.totals.tax_basis_total, label
      assert_equal amount(invoice.tax_total_amount), read.totals.tax_total, label
      assert_equal amount(invoice.grand_total_amount), read.totals.grand_total, label
      assert_equal amount(invoice.due_payable_amount), read.totals.due_payable, label
      assert_equal invoice.tax_breakdown.size, read.tax_breakdown.size, label

      assert_equal [invoice.payment_code], read.payment_means.map(&:type_code), label
      assert_empty read.arithmetic_warnings, label
    end
  end

  def scenario(name, standard = :xrechnung)
    ValidationScenarios.each.find { |n, s, _| n == name && s == standard }.last
  end

  def read_scenario(name, standard = :xrechnung)
    ElectronicInvoice::Reader.from_xml(scenario(name, standard).to_xml)
  end

  def test_reads_parties
    invoice = read_scenario("basic")

    assert_equal "DE123456789", invoice.seller.vat_id
    assert_equal "HRB 12345 B", invoice.seller.registration_number
    assert_equal "Max Muster", invoice.seller.contact_name
    assert_equal "+49 30 123456", invoice.seller.phone
    assert_equal "billing@seller.example", invoice.seller.email
    assert_equal "invoice@seller.example", invoice.seller.electronic_address
    assert_equal "EM", invoice.seller.electronic_address_scheme
    assert_equal "Hauptstr. 1", invoice.seller.street
    assert_equal "10115", invoice.seller.zip_code
    assert_equal "Berlin", invoice.seller.town
    assert_equal "04011000-12345-34", invoice.buyer_reference
    assert_equal ElectronicInvoice::XRECHNUNG_BUSINESS_PROCESS, invoice.business_process
    assert_equal [{ subject_code: "REG", text: "Geschäftsführer: Max Muster, Amtsgericht Charlottenburg HRB 12345 B" }],
      invoice.notes
  end

  def test_reads_credit_transfer
    payment = read_scenario("basic").payment_means.first

    assert payment.credit_transfer?
    assert_equal "DE89370400440532013000", payment.iban
    assert_equal "Seller GmbH", payment.account_name
    assert_equal "Überweisung", payment.information
  end

  def test_reads_direct_debit
    payment = read_scenario("direct_debit").payment_means.first

    assert payment.direct_debit?
    assert_equal "MANDAT-1", payment.mandate_reference
    assert_equal "DE98ZZZ09999999999", payment.creditor_reference_id
    assert_equal "DE02120300000000202051", payment.debtor_iban
  end

  def test_reads_card_payment
    payment = read_scenario("card").payment_means.first

    assert payment.card_payment?
    assert_equal "1234", payment.card_number
    assert_equal "Erika Muster", payment.card_holder
  end

  def test_reads_cash_discounts
    terms = read_scenario("skonto").payment_terms

    assert_equal [{ days: 14, percent: BigDecimal("2"), basis_amount: nil },
      { days: 7, percent: BigDecimal("3"), basis_amount: BigDecimal("1000") }], terms.cash_discounts
    assert_equal "Zahlbar innerhalb von 30 Tagen", terms.text
  end

  def test_reads_allowances_charges_and_billing_period
    invoice = read_scenario("discount_period")
    allowance = invoice.allowances.first

    assert_equal BigDecimal("200"), allowance.amount
    assert_equal BigDecimal("2000"), allowance.base_amount
    assert_equal BigDecimal("10"), allowance.percent
    assert_equal "Rabatt", allowance.reason
    assert_equal({ start: Date.new(2026, 9, 25), end: Date.new(2026, 9, 30) }, invoice.billing_period)

    charge = read_scenario("charges_prepaid").charges.first
    assert_equal BigDecimal("15"), charge.amount
    assert_equal "FC", charge.reason_code
    assert_equal "S", charge.tax_category
    assert_equal BigDecimal("19"), charge.tax_rate
  end

  def test_reads_tax_exemption
    tax = read_scenario("reverse_charge").tax_breakdown.first

    assert_equal "AE", tax.category
    assert_equal BigDecimal("0"), tax.rate
    assert_equal "VATEX-EU-AE", tax.exemption_reason_code
    assert_equal "Reverse Charge", tax.exemption_reason
  end

  def test_reads_preceding_invoice_and_ship_to
    assert_equal [{ number: "RE-2026-0", date: Date.new(2026, 9, 1) }], read_scenario("credit_note").preceding_invoices

    ship_to = read_scenario("ship_to").ship_to
    assert_equal "Lager Nord", ship_to.name
    assert_equal "Hafenweg 7", ship_to.street
  end

  def test_reads_xrechnung_cii_sample
    invoice = ElectronicInvoice.read(fixture("xrechnung_cii.xml"))

    assert_equal :xrechnung, invoice.profile
    assert_equal "123456XX", invoice.number
    assert_equal Date.new(2016, 4, 4), invoice.issue_date
    assert_equal "[Seller trading name]", invoice.seller.trading_name
    assert_equal [{ id: "[Buyer identifier]", scheme: nil }], invoice.buyer.ids
    assert_equal "DE79000000001234567890", invoice.payment_means.first.iban
    assert_equal BigDecimal("336.9"), invoice.totals.grand_total

    line = invoice.line_items.first
    assert_equal "246", line.seller_item_id
    assert_equal "Zeitschrift Inland", line.description
    assert_equal "XPP", line.unit_code
    assert_equal BigDecimal("7"), line.tax_rate
    assert_equal({ start: Date.new(2016, 1, 1), end: Date.new(2016, 12, 31) }, line.billing_period)
    assert_equal 1, line.notes.size
    assert_empty invoice.arithmetic_warnings
  end

  def test_reads_extended_sample
    invoice = ElectronicInvoice.read(fixture("factur-x_extended.xml"))

    assert_equal :extended, invoice.profile
    assert invoice.e_invoice?
    assert_equal 5, invoice.line_items.size
    assert_equal ["Transportkosten: Frachbetrag"], invoice.charges.map(&:reason)
    assert_equal [{ days: 10, percent: BigDecimal("2"), basis_amount: nil }], invoice.payment_terms.cash_discounts
    assert_empty invoice.arithmetic_warnings
  end

  def test_profiles
    profile = lambda do |guideline|
      xml = File.read(fixture("xrechnung_cii.xml")).sub(/urn:cen[^<]*/, guideline)
      ElectronicInvoice::Reader.from_xml(xml).profile
    end

    assert_equal :minimum, profile.("urn:factur-x.eu:1p0:minimum")
    assert_equal :basic_wl, profile.("urn:factur-x.eu:1p0:basicwl")
    assert_equal :basic, profile.("urn:cen.eu:en16931:2017#compliant#urn:factur-x.eu:1p0:basic")
    assert_equal :en16931, profile.("urn:cen.eu:en16931:2017")
    assert_equal :extended, profile.("urn:cen.eu:en16931:2017#conformant#urn:factur-x.eu:1p0:extended")
    assert_equal :xrechnung, profile.("urn:cen.eu:en16931:2017#compliant#urn:xoev-de:kosit:standard:xrechnung_2.3")
    assert_equal :unknown, profile.("urn:example:custom")
  end

  def test_minimum_and_basic_wl_are_no_e_invoices
    xml = File.read(fixture("xrechnung_cii.xml")).sub(/urn:cen[^<]*/, "urn:factur-x.eu:1p0:basicwl")

    refute ElectronicInvoice::Reader.from_xml(xml).e_invoice?
  end

  def test_arithmetic_warnings
    xml = File.read(fixture("xrechnung_cii.xml")).sub("<ram:GrandTotalAmount>336.9<", "<ram:GrandTotalAmount>340.00<")
    warnings = ElectronicInvoice::Reader.from_xml(xml).arithmetic_warnings

    assert_equal ["BR-CO-15: grand total is 340.00, expected 336.90",
      "BR-CO-16: due payable amount is 336.90, expected 340.00"], warnings
  end

  def test_reads_ubl_invoice
    invoice = ElectronicInvoice.read(fixture("kosit/01.01a-INVOICE_ubl.xml"))

    assert_equal :ubl, invoice.syntax
    assert_equal :xrechnung, invoice.profile
    assert_equal ElectronicInvoice::XRECHNUNG_BUSINESS_PROCESS, invoice.business_process
    assert_equal "123456XX", invoice.number
    assert_equal "380", invoice.type_code
    assert_equal Date.new(2016, 4, 4), invoice.issue_date
    assert_equal [{ subject_code: "ADU", text: "Es gelten unsere Allgem. Geschäftsbedingungen, die Sie unter […] finden." }], invoice.notes
    assert_equal "04011000-12345-03", invoice.buyer_reference

    seller = invoice.seller
    assert_equal "[Seller name]", seller.name
    assert_equal "[Seller trading name]", seller.trading_name
    assert_equal "DE 123456789", seller.vat_id
    assert_equal "[HRA-Eintrag]", seller.registration_number
    assert_equal "seller@email.de", seller.electronic_address
    assert_equal "EM", seller.electronic_address_scheme
    assert_equal "nicht vorhanden", seller.contact_name
    assert_equal "[Seller address line 1]", seller.street
    assert_equal "12345", seller.zip_code
    assert_equal "DE", seller.country_code
    assert_equal [{ id: "[Buyer identifier]", scheme: nil }], invoice.buyer.ids

    line = invoice.line_items.first
    assert_equal "Zeitschrift [...]", line.id
    assert_equal "Zeitschrift Inland", line.description
    assert_equal "246", line.seller_item_id
    assert_equal BigDecimal("1"), line.quantity
    assert_equal "XPP", line.unit_code
    assert_equal BigDecimal("288.79"), line.net_price
    assert_equal BigDecimal("7"), line.tax_rate
    assert_equal({ start: Date.new(2016, 1, 1), end: Date.new(2016, 12, 31) }, line.billing_period)

    assert_equal "DE79000000001234567890", invoice.payment_means.first.iban
    assert invoice.payment_means.first.credit_transfer?
    assert_equal "Zahlbar sofort ohne Abzug.", invoice.payment_terms.description
    assert_equal [BigDecimal("22.04")], invoice.tax_breakdown.map(&:tax_amount)
    assert_equal BigDecimal("336.9"), invoice.totals.grand_total
    assert_equal BigDecimal("22.04"), invoice.totals.tax_total
    assert_empty invoice.arithmetic_warnings
  end

  def test_reads_ubl_credit_note
    xml = File.read(fixture("kosit/01.01a-INVOICE_ubl.xml"))
      .gsub("ubl:Invoice", "ubl:CreditNote").sub("xsd:Invoice-2", "xsd:CreditNote-2")
      .gsub("InvoiceTypeCode>380", "CreditNoteTypeCode>381").sub("</cbc:InvoiceTypeCode>", "</cbc:CreditNoteTypeCode>")
      .gsub("cac:InvoiceLine", "cac:CreditNoteLine").gsub("cbc:InvoicedQuantity", "cbc:CreditedQuantity")
    invoice = ElectronicInvoice::Reader.from_xml(xml)

    assert_equal "381", invoice.type_code
    assert_equal 2, invoice.line_items.size
    assert_equal BigDecimal("1"), invoice.line_items.first.quantity
    assert_equal BigDecimal("336.9"), invoice.totals.due_payable
  end

  def test_reads_ubl_skonto_and_direct_debit
    invoice = ElectronicInvoice.read(fixture("kosit/01.10a-INVOICE_ubl.xml"))

    assert_equal [7, 14, 30], invoice.payment_terms.cash_discounts.map { _1[:days] }
  end

  # The KoSIT testsuite contains every case as CII and UBL, both have to be read with the same totals
  def test_ubl_and_cii_cases_of_the_testsuite_match
    pairs = Dir[fixture("kosit/*_ubl.xml")].filter_map do |ubl|
      cii = ubl.sub("_ubl.xml", "_uncefact.xml")
      [ubl, cii] if File.exist?(cii)
    end
    assert_operator pairs.size, :>=, 30

    pairs.each do |ubl_file, cii_file|
      ubl = ElectronicInvoice.read(ubl_file)
      cii = ElectronicInvoice.read(cii_file)
      label = File.basename(ubl_file)

      %i[number type_code issue_date currency_code profile buyer_reference due_date delivery_date billing_period].each do |attribute|
        assert_equal cii.public_send(attribute), ubl.public_send(attribute), "#{label} #{attribute}"
      end
      assert_equal cii.totals.to_h.transform_values(&:to_d), ubl.totals.to_h.transform_values(&:to_d), label
      assert_equal cii.line_items.map { [_1.net_total, _1.quantity, _1.unit_code, _1.tax_category, _1.tax_rate] },
        ubl.line_items.map { [_1.net_total, _1.quantity, _1.unit_code, _1.tax_category, _1.tax_rate] }, label
      assert_equal cii.tax_breakdown.map { [_1.category, _1.rate, _1.basis_amount, _1.tax_amount] },
        ubl.tax_breakdown.map { [_1.category, _1.rate, _1.basis_amount, _1.tax_amount] }, label
      assert_equal cii.allowances_charges.map { [_1.charge, _1.amount, _1.tax_category] },
        ubl.allowances_charges.map { [_1.charge, _1.amount, _1.tax_category] }, label
      assert_equal cii.payment_means.map { [_1.type_code, _1.iban, _1.mandate_reference, _1.debtor_iban, _1.card_number] },
        ubl.payment_means.map { [_1.type_code, _1.iban, _1.mandate_reference, _1.debtor_iban, _1.card_number] }, label
    end
  end

  def test_reads_all_ubl_cases_of_the_testsuite
    Dir[fixture("kosit/*_ubl.xml")].each do |file|
      invoice = ElectronicInvoice.read(file)

      assert_equal :ubl, invoice.syntax, file
    end
  end

  def test_rejects_other_xml
    error = assert_raises(ElectronicInvoice::UnsupportedFormatError) { ElectronicInvoice::Reader.from_xml("<Order xmlns=\"urn:example\"/>") }

    assert_equal "Order (urn:example) is no CII or UBL invoice", error.message
  end

  def test_rejects_zugferd_1
    error = assert_raises(ElectronicInvoice::UnsupportedFormatError) { ElectronicInvoice.read(fixture("zugferd_1.xml")) }

    assert_includes error.message, "ZUGFeRD 1.0"
  end

  def test_rejects_malformed_xml
    assert_raises(ElectronicInvoice::ParseError) { ElectronicInvoice::Reader.from_xml("<rsm:CrossIndustryInvoice>") }
  end

  def test_rejects_missing_mandatory_elements
    xml = File.read(fixture("xrechnung_cii.xml")).sub("<ram:ID>123456XX</ram:ID>", "")
    error = assert_raises(ElectronicInvoice::ParseError) { ElectronicInvoice::Reader.from_xml(xml) }

    assert_equal "Missing mandatory elements: invoice number (BT-1)", error.message
  end

  def test_rejects_invalid_values
    xml = File.read(fixture("xrechnung_cii.xml"))

    assert_raises(ElectronicInvoice::ParseError) { ElectronicInvoice::Reader.from_xml(xml.sub(">336.9<", ">33x<")) }
    assert_raises(ElectronicInvoice::ParseError) { ElectronicInvoice::Reader.from_xml(xml.sub(">20160404<", ">20161304<")) }
  end

  def test_does_not_resolve_external_entities
    xml = File.read(fixture("xrechnung_cii.xml"))
      .sub("<rsm:CrossIndustryInvoice", %(<!DOCTYPE rsm:CrossIndustryInvoice [<!ENTITY xxe SYSTEM "file://#{__FILE__}">]>\n<rsm:CrossIndustryInvoice))
      .sub("<ram:ID>123456XX</ram:ID>", "<ram:ID>123456XX&xxe;</ram:ID>")

    invoice = ElectronicInvoice::Reader.from_xml(xml)

    assert_equal "123456XX", invoice.number
  end

  def test_rejects_missing_file
    assert_raises(ElectronicInvoice::Error) { ElectronicInvoice.read(fixture("missing.xml")) }
  end
end
