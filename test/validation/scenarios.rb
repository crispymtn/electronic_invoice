# frozen_string_literal: true

# Generates sample invoices covering the supported features as ZUGFeRD and XRechnung.
# Used by `rake validate` to check them with the KoSIT validator.
require "date"
require "fileutils"
require "electronic_invoice"

OUT = ARGV.fetch(0)
FileUtils.mkdir_p(OUT)
Dir.glob("#{OUT}/*.xml").each { File.delete(_1) }

item = { description: "Beratung", qty: 10, unit: "HOUR", net: 10000.0, net_total: 100000.0, gross_total: 119000.0, tax_rate: 0.19,
  tax_category: "S", tax: 19000.0, discount: 0.0, discounted_net_total: 100000.0, discount_reason: nil, currency_code: "EUR" }
base = { number: "RE-2026-1", kind: "INVOICE", invoice_date: Date.new(2026, 10, 1), due_date: Date.new(2026, 10, 31), delivery_date: Date.new(2026, 9, 25),
  payment_terms: "Zahlbar innerhalb von 30 Tagen", payment_type: "SEPA_CREDIT", payment_information: "Überweisung",
  iban: "DE89370400440532013000", currency_code: "EUR", buyer_reference: "04011000-12345-34",
  seller: { name: "Seller GmbH", street: "Hauptstr.", number: "1", zip_code: "10115", town: "Berlin", country_code: "DE", vat_id: "DE123456789",
    tax_id: "12/345/67890", email: "billing@seller.example", contact_name: "Max Muster", phone: "+49 30 123456",
    electronic_address: "invoice@seller.example", registration_number: "HRB 12345 B" },
  buyer: { name: "Buyer AG", street: "Marktplatz", number: "2", zip_code: "20095", town: "Hamburg", country_code: "DE", vat_id: "DE987654321",
    electronic_address: "invoice@buyer.example" },
  line_items: [item], regulatory_information: "Geschäftsführer: Max Muster, Amtsgericht Charlottenburg HRB 12345 B" }
fr_buyer = base[:buyer].merge(country_code: "FR", vat_id: "FR12345678901", zip_code: "75001", town: "Paris")
us_buyer = base[:buyer].merge(country_code: "US", vat_id: nil, zip_code: "10001", town: "New York")
zero = ->(cat) { item.merge(tax_category: cat, tax_rate: 0, tax: 0, gross_total: 100000.0) }

cases = {
  "basic" => {},
  "discount_period" => { delivery_date_until: Date.new(2026, 9, 30),
    line_items: [item.merge(discount: 0.1, discounted_net_total: 90000.0, tax: 17100.0, discount_reason: "Rabatt"),
                 item.merge(description: "Support", discount: 0.1, discounted_net_total: 90000.0, tax: 17100.0, discount_reason: "Rabatt")] },
  "mixed_rates" => { line_items: [item, item.merge(description: "Buch", unit: "PIECE", qty: 1, net: 2000.0, net_total: 2000.0, tax_rate: 0.07, tax: 140.0, gross_total: 2140.0)] },
  "fractional" => { line_items: [item.merge(qty: 3, net: 3333.333, net_total: 10000.0, tax: 1900.0, gross_total: 11900.0)] },
  "negative_line" => { line_items: [item, item.merge(description: "Gutschrift Position", qty: 1, net: -5000.0, net_total: -5000.0, tax: -950.0, gross_total: -5950.0)] },
  "reverse_charge" => { buyer: fr_buyer, line_items: [zero.("AE")] },
  "intra_community" => { buyer: fr_buyer, line_items: [zero.("K")] },
  "export" => { buyer: us_buyer, line_items: [zero.("G")] },
  "exempt" => { line_items: [zero.("E")], tax_exemption_reason: "Steuerfrei nach § 4 Nr. 14 UStG" },
  "zero_rated" => { line_items: [zero.("Z")] },
  "untaxed" => { line_items: [zero.("O")] },
  "credit_note" => { kind: "CREDIT_NOTE", preceding_invoice_reference: "RE-2026-0", preceding_invoice_date: Date.new(2026, 9, 1) },
  "correction" => { kind: "CORRECTION", preceding_invoice_reference: "RE-2026-0", preceding_invoice_date: Date.new(2026, 9, 1) },
  "charges_prepaid" => { charges: [{ amount: 1500, reason: "Versandkosten", reason_code: "FC", tax_rate: 0.19, tax_category: "S" }], prepaid_amount: 50000 },
  "skonto" => { cash_discounts: [{ days: 14, rate: 0.02 }, { days: 7, rate: 0.03, basis_amount: 100000 }] },
  "direct_debit" => { payment_type: "SEPA_DEBIT", mandate_reference: "MANDAT-1", creditor_reference_id: "DE98ZZZ09999999999", debtor_iban: "DE02120300000000202051" },
  "card" => { payment_type: "CREDITCARD", card_number: "1234", card_holder: "Erika Muster", iban: nil },
  "no_house_number" => { buyer: base[:buyer].except(:number).merge(street: "Emmerich-Josef-Straße 1a") },
  "ship_to" => { ship_to: { name: "Lager Nord", street: "Hafenweg", number: "7", zip_code: "20457", town: "Hamburg", country_code: "DE" } },
}

cases.each do |name, attrs|
  %i[zugferd xrechnung].each do |standard|
    invoice = ElectronicInvoice::Invoice.new(base.merge(attrs).merge(standard: standard))
    File.write(File.join(OUT, "#{standard}-#{name}.xml"), invoice.to_xml)
  rescue ElectronicInvoice::Error => e
    abort "#{standard}-#{name}: #{e.message}"
  end
end
