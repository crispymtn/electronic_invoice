require "test_helper"

class LineItemTest < Minitest::Test
  def setup
    @line_item = ElectronicInvoice::LineItem.new(
      description: "Test Product",
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
    )
  end

  def test_valid_line_item
    assert @line_item.valid?
  end

  def test_invalid_without_description
    @line_item.description = nil
    refute @line_item.valid?
    assert_includes @line_item.errors[:description], "can't be blank"
  end

  def test_unit_codes
    assert_equal "XBO", ElectronicInvoice.unit_code("bottle")
    assert_equal "C62", ElectronicInvoice.unit_code("C62")
    assert_equal "EA", ElectronicInvoice.unit_code("EA")
    assert_equal "XST", ElectronicInvoice.unit_code("SHEET")
    assert_equal "RM", ElectronicInvoice.unit_code("ream")
    assert_equal "XRO", ElectronicInvoice.unit_code("ROLL")
    assert_equal "XPK", ElectronicInvoice.unit_code("XPK")
    assert_equal "H87", ElectronicInvoice.unit_code("UNKNOWN")
  end

  def test_zero_rate_categories_require_zero_rate
    @line_item.tax_category = "REVERSECHARGE"
    refute @line_item.valid?
    assert_includes @line_item.errors[:tax_rate], "must be 0 for tax category AE"
  end

  def test_unknown_tax_category
    @line_item.tax_category = "FOO"
    refute @line_item.valid?
    assert_includes @line_item.errors[:tax_category], "is not a known tax category"
  end

  def test_discounted?
    @line_item.discount = 10.0
    assert @line_item.discounted?
  end

  def test_discount_amount
    @line_item.discounted_net_total = 900.0
    assert_equal 100.0, @line_item.discount_amount
  end

  def test_to_xml
    xml = Nokogiri::XML::Builder.new do |xml|
      xml.root("xmlns:ram" => "urn:ram:namespace") do
        @line_item.to_xml(xml, 1)
      end
    end.to_xml

    assert_includes xml, '<ram:LineID>1</ram:LineID>'
    assert_includes xml, '<ram:Name>Test Product</ram:Name>'
    assert_includes xml, '<ram:ChargeAmount>1.0000</ram:ChargeAmount>'
    assert_includes xml, '<ram:BilledQuantity unitCode="EA">10.0000</ram:BilledQuantity>'
    assert_includes xml, '<ram:TypeCode>VAT</ram:TypeCode>'
    assert_includes xml, '<ram:CategoryCode>S</ram:CategoryCode>'
    assert_includes xml, '<ram:RateApplicablePercent>19.00</ram:RateApplicablePercent>'
    assert_includes xml, '<ram:LineTotalAmount>10.00</ram:LineTotalAmount>'
  end
end
