# frozen_string_literal: true

module ElectronicInvoice
  class Invoice
    include ActiveModel::Model

    attr_reader :seller_trade_party, :buyer_trade_party, :invoice_line_items

    attr_accessor :number, :kind, :invoice_date, :due_date, :delivery_date, :delivery_date_until, :net_total,
    :gross_total, :tax_category, :tax_exemption_reason, :buyer_reference, :seller, :buyer, :line_items, :currency_code,
    :payment_terms, :payment_type, :payment_information, :iban, :preceding_invoice_reference, :preceding_invoice_date,
    :regulatory_information, :header_text, :footer_text

    validates :number, :invoice_date, :due_date, :delivery_date, :seller, :buyer, :payment_terms,
      :payment_type, :payment_information, presence: true
    validates :preceding_invoice_date, presence: true, if: -> { preceding_invoice_reference.present? }

    validate :validate_line_items_presence

    def seller_trade_party
      @seller_trade_party ||= ElectronicInvoice::TradeParty.new(seller)
    end

    def buyer_trade_party
      buyer_trade_party ||= ElectronicInvoice::TradeParty.new(buyer)
    end

    def invoice_line_items
      @invoice_line_items ||= line_items.map { ElectronicInvoice::LineItem.new(_1)}
    end

    def all_valid?
      valid? && invoice_line_items.all?(&:valid?) && seller_trade_party.valid? && buyer_trade_party.valid?

    end

    def to_xml
      associated_errors AND raise ElectronicInvoice::Error, errors.full_messages.join(", ") unless all_valid?

      builder = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
        xml["rsm"].send(:CrossIndustryInvoice, namespace) do
          xml["rsm"].send(:ExchangedDocumentContext) do
            xml["ram"].GuidelineSpecifiedDocumentContextParameter do
              xml["ram"].ID "urn:cen.eu:en16931:2017"
            end
          end

          xml["rsm"].ExchangedDocument do
            xml["ram"].ID number
            xml["ram"].TypeCode INVOICE_TYPES[kind.upcase.to_sym][:code]
            xml["ram"].IssueDateTime do
              xml["udt"].DateTimeString(format: "102") do
                xml.text(invoice_date.to_date.strftime("%Y%m%d"))
              end
            end

            # Mandatory information on the invoicing party
            xml["ram"].IncludedNote do
              xml["ram"].Content regulatory_information
              xml["ram"].SubjectCode "REG"
            end

            # Header and footer text
            if header_text
              xml["ram"].IncludedNote do
                xml["ram"].Content header_text
                xml["ram"].SubjectCode "SUR"
              end
            end

            if footer_text
              xml["ram"].IncludedNote do
                xml["ram"].Content footer_text
                xml["ram"].SubjectCode "SUR"
              end
            end
          end

          xml["rsm"].SupplyChainTradeTransaction do
            # Line items
            invoice_line_items.each_with_index do |item, i|
              item.to_xml(xml, i + 1)
            end

            xml["ram"].ApplicableHeaderTradeAgreement do
              if buyer_trade_party.electronic_invoicing_identifier
                xml["ram"].BuyerReference do
                  xml.text(buyer_trade_party.electronic_invoicing_identifier)
                end
              elsif buyer_reference
                xml["ram"].BuyerReference do
                  xml.text(buyer_reference)
                end
              end

              xml["ram"].SellerTradeParty do
                # Seller
                seller_trade_party.to_xml(xml)
              end

              xml["ram"].BuyerTradeParty do
                # Buyer
                buyer_trade_party.to_xml(xml)
              end
            end

            xml["ram"].ApplicableHeaderTradeDelivery do
              # Delivery address
              xml["ram"].ShipToTradeParty do
                buyer_trade_party.to_xml(xml)
              end

              # Delivery_date
              xml["ram"].ActualDeliverySupplyChainEvent do
                xml["ram"].OccurrenceDateTime do
                  xml["udt"].DateTimeString(format: "102") do
                    xml.text(delivery_date.to_date.strftime("%Y%m%d"))
                  end
                end
              end
            end

            # Currency
            xml["ram"].ApplicableHeaderTradeSettlement do
              xml["ram"].InvoiceCurrencyCode currency_code
              xml["ram"].SpecifiedTradeSettlementPaymentMeans do
                xml["ram"].TypeCode PAYMENT_CODES[payment_type.upcase.to_sym]
                xml["ram"].Information payment_information
                if iban
                  xml["ram"].PayeePartyCreditorFinancialAccount do
                    xml["ram"].IBANID iban
                    xml["ram"].AccountName seller_trade_party.name
                  end
                end
              end

              # Taxes
              invoice_line_items.group_by(&:tax_rate).each do |tax_rate, items|
                xml["ram"].ApplicableTradeTax do
                  ElectronicInvoice::Helpers.currency_element(xml, "ram", "CalculatedAmount", items.sum(&:tax), currency_code)
                  xml["ram"].TypeCode "VAT"

                  if exemption_reason = tax_exemption_reason || TAX_EXEMPTION_REASONS[TAX_CATEGORY_CODES[tax_category.upcase.to_sym] || "S"]
                    xml["ram"].ExemptionReason exemption_reason
                  end

                  ElectronicInvoice::Helpers.currency_element(xml, "ram", "BasisAmount", items.sum(&:discounted_net_total), currency_code)
                  xml["ram"].CategoryCode TAX_CATEGORY_CODES[tax_category.upcase.to_sym] || "S"

                  xml["ram"].RateApplicablePercent ElectronicInvoice::Helpers.format_value(tax_rate * 100)
                end
              end

              # Discounts
              invoice_line_items.select(&:discounted?).group_by(&:tax_rate).each do |tax_rate, items|
                xml["ram"].SpecifiedTradeAllowanceCharge do
                  xml["ram"].ChargeIndicator do
                    xml["udt"].Indicator "false"
                  end

                  xml["ram"].CalculationPercent ElectronicInvoice::Helpers.format_value(items.sum(&:discount) * 100)

                  ElectronicInvoice::Helpers.currency_element(xml, "ram", "BasisAmount", items.sum(&:net), currency_code)
                  ElectronicInvoice::Helpers.currency_element(xml, "ram", "ActualAmount", items.sum(&:discount_amount), currency_code)

                  xml["ram"].Reason items.pluck(:discount_reason).join(", ")

                  xml["ram"].CategoryTradeTax do
                    xml["ram"].TypeCode "VAT"
                    xml["ram"].CategoryCode TAX_CATEGORY_CODES[tax_category.upcase.to_sym] || "S"
                    xml["ram"].RateApplicablePercent ElectronicInvoice::Helpers.format_value(tax_rate * 100)
                  end
                end
              end

              # Billing period
              if delivery_date_until
                xml["ram"].BillingSpecifiedPeriod do
                  xml["ram"].StartDateTime do
                    xml["udt"].DateTimeString(format: "102") do
                      xml.text(delivery_date.to_date.strftime("%Y%m%d"))
                    end
                  end
                  xml["ram"].EndDateTime do
                    xml["udt"].DateTimeString(format: "102") do
                      xml.text(delivery_date_until.to_date.strftime("%Y%m%d"))
                    end
                  end
                end
              end

              # Payment terms
              xml["ram"].SpecifiedTradePaymentTerms do
                xml["ram"].Description payment_terms
                xml["ram"].DueDateDateTime do
                  xml["udt"].DateTimeString(format: "102") do
                    xml.text(due_date.to_date.strftime("%Y%m%d"))
                  end
                end
              end

              # Totals
              xml["ram"].SpecifiedTradeSettlementHeaderMonetarySummation do
                ElectronicInvoice::Helpers.currency_element(xml, "ram", "LineTotalAmount", invoice_line_items.sum(&:net_total), currency_code)
                ElectronicInvoice::Helpers.currency_element(xml, "ram", "ChargeTotalAmount", 0, currency_code)
                ElectronicInvoice::Helpers.currency_element(xml, "ram", "AllowanceTotalAmount", invoice_line_items.sum(&:discount_amount), currency_code)
                ElectronicInvoice::Helpers.currency_element(xml, "ram", "TaxBasisTotalAmount", net_total, currency_code)
                ElectronicInvoice::Helpers.currency_element(xml, "ram", "TaxTotalAmount", invoice_line_items.sum(&:tax), currency_code, add_currency: true)
                ElectronicInvoice::Helpers.currency_element(xml, "ram", "GrandTotalAmount", gross_total, currency_code)
                ElectronicInvoice::Helpers.currency_element(xml, "ram", "TotalPrepaidAmount", 0, currency_code)
                ElectronicInvoice::Helpers.currency_element(xml, "ram", "DuePayableAmount", gross_total, currency_code)
              end

              # Reference to the original invoice in case of a reversal or credit note
              if preceding_invoice_reference
                xml["ram"].InvoiceReferencedDocument do
                  xml["ram"].IssuerAssignedID preceding_invoice_reference
                  xml["ram"].FormattedIssueDateTime do
                    xml["qdt"].DateTimeString(format: "102") do
                      xml.text(preceding_invoice_date.to_date.strftime("%Y%m%d"))
                    end
                  end
                end
              end
            end
          end
        end
      end

      builder.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
    end

    private

    def associated_errors
      errors.add(:seller, seller_trade_party.errors.full_messages.join(", ")) unless seller_trade_party.valid?
      errors.add(:buyer, buyer_trade_party.errors.full_messages.join(", ")) unless buyer_trade_party.valid?
      invoice_line_items.map.with_index(1) do|li, i|
        errors.add("Line item #{i}", li.errors.full_messages.join(", ")) unless li.valid?
      end
    end

    def namespace
      {
        "xmlns:rsm" => "urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100",
        "xmlns:qdt" => "urn:un:unece:uncefact:data:standard:QualifiedDataType:100",
        "xmlns:ram" => "urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100",
        "xmlns:xs"  => "http://www.w3.org/2001/XMLSchema",
        "xmlns:udt" => "urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100"
      }
    end

    def validate_line_items_presence
      errors.add(:line_items, "must contain at least one item") if line_items.empty?
    end
  end
end
