require "test_helper"

class PdfExtractorTest < Minitest::Test
  PDF = File.expand_path("../fixtures/zugferd_en16931.pdf", __dir__)
  NO_ATTACHMENT = File.expand_path("../fixtures/no_attachment.pdf", __dir__)

  def test_reads_pdf_from_path_pathname_io_and_string
    [PDF, Pathname.new(PDF), File.open(PDF, "rb"), File.binread(PDF)].each do |input|
      invoice = ElectronicInvoice.read(input)

      assert_equal "471102", invoice.number
      assert_equal :en16931, invoice.profile
    ensure
      input.close if input.is_a?(File)
    end
  end

  def test_reads_content_of_the_sample
    invoice = ElectronicInvoice.read(PDF)

    assert_equal "Lieferant GmbH", invoice.seller.name
    assert_equal [{ id: "549910", scheme: nil }, { id: "4000001123452", scheme: "0088" }], invoice.seller.ids
    assert_equal "Kunden AG Mitte", invoice.buyer.name
    assert_equal ["Trennblätter A4", "Joghurt Banane"], invoice.line_items.map(&:name)
    assert_equal "4012345001235", invoice.line_items.first.standard_item_id
    assert_equal BigDecimal("20"), invoice.line_items.first.quantity
    assert_equal BigDecimal("9.9"), invoice.line_items.first.net_price
    assert_equal [BigDecimal("7"), BigDecimal("19")], invoice.tax_breakdown.map(&:rate)
    assert_equal BigDecimal("529.87"), invoice.totals.due_payable
    assert_empty invoice.arithmetic_warnings
  end

  def test_extracts_xml
    xml = ElectronicInvoice::Reader.extract_xml(PDF)

    assert_includes xml, "<rsm:CrossIndustryInvoice"
  end

  def test_pdf_without_invoice
    assert_raises(ElectronicInvoice::NoInvoiceFoundError) { ElectronicInvoice.read(NO_ATTACHMENT) }
  end

  def test_extract_xml_requires_a_pdf
    assert_raises(ElectronicInvoice::ParseError) { ElectronicInvoice::Reader.extract_xml("<xml/>") }
  end

  def test_malformed_pdf
    assert_raises(ElectronicInvoice::ParseError) { ElectronicInvoice.read("%PDF-1.7\ngarbage") }
  end
end
