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
end
