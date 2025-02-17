require "test_helper"

class TradePartyTest < Minitest::Test
  def setup
    @trade_party = ElectronicInvoice::TradeParty.new(
      reference: "12345",
      name: "Test Company",
      email: "test@example.com",
      street: "Test Street",
      number: "42",
      addition: "Apt 1",
      zip_code: "12345",
      town: "Test Town",
      country_code: "DE",
      vat_id: "DE123456789",
      tax_id: "123456789"
    )
  end

  def test_valid_trade_party
    assert @trade_party.valid?
  end

  def test_invalid_without_name
    @trade_party.name = nil
    refute @trade_party.valid?
    assert_includes @trade_party.errors[:name], "can't be blank"
  end

  def test_to_xml
    xml = Nokogiri::XML::Builder.new do |xml|
      xml.root("xmlns:ram" => "urn:ram:namespace") do
        @trade_party.to_xml(xml)
      end
    end.to_xml

    assert_includes xml, '<ram:ID>12345</ram:ID>'
    assert_includes xml, '<ram:Name>Test Company</ram:Name>'
    assert_includes xml, '<ram:URIID>test@example.com</ram:URIID>'
    assert_includes xml, '<ram:LineOne>Test Street 42</ram:LineOne>'
    assert_includes xml, '<ram:PostcodeCode>12345</ram:PostcodeCode>'
    assert_includes xml, '<ram:CityName>Test Town</ram:CityName>'
    assert_includes xml, '<ram:CountryID>DE</ram:CountryID>'
    assert_includes xml, '<ram:ID schemeID="VA">DE123456789</ram:ID>'
    assert_includes xml, '<ram:ID schemeID="FC">123456789</ram:ID>'
  end
end
