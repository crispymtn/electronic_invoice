# frozen_string_literal: true

module ElectronicInvoice
  class Invoice
    include ActiveModel::Model

    # tax_category is kept for backwards compatibility, the tax categories are taken from the line items.
    attr_accessor :number, :kind, :invoice_date, :due_date, :delivery_date, :delivery_date_until, :net_total,
    :gross_total, :tax_category, :tax_exemption_reason, :buyer_reference, :seller, :buyer, :line_items, :currency_code,
    :payment_terms, :payment_type, :payment_information, :iban, :preceding_invoice_reference, :preceding_invoice_date,
    :regulatory_information, :header_text, :footer_text, :ship_to, :charges, :prepaid_amount, :cash_discounts,
    :mandate_reference, :creditor_reference_id, :debtor_iban, :card_number, :card_holder

    # :zugferd (default, EN16931 profile) or :xrechnung (XRechnung 3.0)
    attr_writer :standard

    validates :number, :invoice_date, :due_date, :delivery_date, :seller, :buyer, :payment_terms,
      :payment_type, :payment_information, :currency_code, presence: true
    validates :currency_code, inclusion: { in: CURRENCY_CODES, message: "is not a valid ISO 4217 currency code" },
      allow_blank: true
    validates :preceding_invoice_date, presence: true, if: -> { preceding_invoice_reference.present? }
    validates :iban, presence: true, if: -> { CREDIT_TRANSFER_PAYMENT_CODES.include?(payment_code) }
    validates :mandate_reference, :creditor_reference_id, :debtor_iban, presence: true, if: :direct_debit?

    validate :validate_line_items_presence
    validate :validate_codes
    validate :validate_ibans
    validate :validate_cash_discounts
    validate :validate_tax_registrations
    validate :validate_not_subject_to_vat
    validate :validate_totals
    validate :validate_xrechnung, if: :xrechnung?

    def seller_trade_party
      @seller_trade_party ||= ElectronicInvoice::TradeParty.new(seller)
    end

    def buyer_trade_party
      @buyer_trade_party ||= ElectronicInvoice::TradeParty.new(buyer)
    end

    # Delivery address, defaults to the buyer
    def ship_to_trade_party
      @ship_to_trade_party ||= ship_to.present? ? ElectronicInvoice::TradeParty.new(ship_to) : buyer_trade_party
    end

    def invoice_line_items
      @invoice_line_items ||= Array(line_items.presence).map { ElectronicInvoice::LineItem.new(_1) }
    end

    def invoice_charges
      @invoice_charges ||= Array(charges.presence).map { ElectronicInvoice::Charge.new(_1) }
    end

    def standard
      (@standard.presence || :zugferd).to_sym
    end

    def xrechnung?
      standard == :xrechnung
    end

    def type_code
      INVOICE_TYPES.dig(kind.to_s.upcase.to_sym, :code)
    end

    def payment_code
      PAYMENT_CODES[payment_type.to_s.upcase.to_sym]
    end

    def direct_debit?
      DIRECT_DEBIT_PAYMENT_CODES.include?(payment_code)
    end

    def card_payment?
      CARD_PAYMENT_CODES.include?(payment_code)
    end

    # Totals in cents, calculated from the line items and charges (BG-22)
    def line_total_amount
      invoice_line_items.sum(&:line_total)
    end

    def allowance_total_amount
      invoice_line_items.sum(&:allowance_amount)
    end

    def charge_total_amount
      invoice_charges.sum(&:amount_cents)
    end

    def tax_basis_total_amount
      line_total_amount - allowance_total_amount + charge_total_amount
    end

    def tax_total_amount
      tax_breakdown.sum { _1[:tax] }
    end

    def grand_total_amount
      tax_basis_total_amount + tax_total_amount
    end

    def prepaid_total_amount
      ElectronicInvoice::Helpers.cents(prepaid_amount)
    end

    def due_payable_amount
      grand_total_amount - prepaid_total_amount
    end

    # VAT breakdown (BG-23) per tax category and rate
    def tax_breakdown
      (invoice_line_items + invoice_charges).map(&:tax_key).uniq.map do |key|
        lines = invoice_line_items.select { _1.tax_key == key }
        charges = invoice_charges.select { _1.tax_key == key }

        {
          category_code: key[0],
          tax_rate: key[1],
          basis: lines.sum(&:taxable_amount) + charges.sum(&:amount_cents),
          tax: (lines.sum { _1.tax.to_d } + charges.sum(&:tax_amount)).round
        }
      end
    end

    def all_valid?
      valid? & invoice_line_items.map(&:valid?).all? & invoice_charges.map(&:valid?).all? &
        seller_trade_party.valid? & buyer_trade_party.valid? & ship_to_trade_party.valid?
    end

    def to_xml
      unless all_valid?
        associated_errors
        raise ElectronicInvoice::Error, errors.full_messages.join(", ")
      end

      builder = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
        xml["rsm"].send(:CrossIndustryInvoice, namespace) do
          xml["rsm"].send(:ExchangedDocumentContext) do
            if xrechnung?
              xml["ram"].BusinessProcessSpecifiedDocumentContextParameter do
                xml["ram"].ID XRECHNUNG_BUSINESS_PROCESS
              end
            end

            xml["ram"].GuidelineSpecifiedDocumentContextParameter do
              xml["ram"].ID GUIDELINES.fetch(standard)
            end
          end

          xml["rsm"].ExchangedDocument do
            xml["ram"].ID number
            xml["ram"].TypeCode type_code
            xml["ram"].IssueDateTime do
              xml["udt"].DateTimeString(format: "102") do
                xml.text(invoice_date.to_date.strftime("%Y%m%d"))
              end
            end

            # Mandatory information on the invoicing party
            if regulatory_information.present?
              xml["ram"].IncludedNote do
                xml["ram"].Content regulatory_information
                xml["ram"].SubjectCode "REG"
              end
            end

            # Header and footer text
            if header_text.present?
              xml["ram"].IncludedNote do
                xml["ram"].Content header_text
                xml["ram"].SubjectCode "SUR"
              end
            end

            if footer_text.present?
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
              if (reference = buyer_trade_party.electronic_invoicing_identifier.presence || buyer_reference.presence)
                xml["ram"].BuyerReference do
                  xml.text(reference)
                end
              end

              xml["ram"].SellerTradeParty do
                # Seller
                seller_trade_party.to_xml(xml, role: :seller, include_vat_id: !not_subject_to_vat?)
              end

              xml["ram"].BuyerTradeParty do
                # Buyer
                buyer_trade_party.to_xml(xml, role: :buyer, include_vat_id: !not_subject_to_vat?)
              end
            end

            xml["ram"].ApplicableHeaderTradeDelivery do
              # Delivery address
              xml["ram"].ShipToTradeParty do
                ship_to_trade_party.to_xml(xml, role: :ship_to)
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

            xml["ram"].ApplicableHeaderTradeSettlement do
              # Bank assigned creditor identifier (BT-90)
              xml["ram"].CreditorReferenceID creditor_reference_id if direct_debit?

              # Currency
              xml["ram"].InvoiceCurrencyCode currency_code

              xml["ram"].SpecifiedTradeSettlementPaymentMeans do
                xml["ram"].TypeCode payment_code
                xml["ram"].Information payment_information

                # Payment card (BG-18)
                if card_payment? && card_number.present?
                  xml["ram"].ApplicableTradeSettlementFinancialCard do
                    xml["ram"].ID card_number
                    xml["ram"].CardholderName card_holder if card_holder.present?
                  end
                end

                # Direct debit (BG-19)
                if direct_debit?
                  xml["ram"].PayerPartyDebtorFinancialAccount do
                    xml["ram"].IBANID ElectronicInvoice::Helpers.normalize_iban(debtor_iban)
                  end
                # Credit transfer (BG-17)
                elsif iban.present? && !card_payment?
                  xml["ram"].PayeePartyCreditorFinancialAccount do
                    xml["ram"].IBANID ElectronicInvoice::Helpers.normalize_iban(iban)
                    xml["ram"].AccountName seller_trade_party.name
                  end
                end
              end

              # Taxes
              tax_breakdown.each do |entry|
                category_code = entry[:category_code]

                xml["ram"].ApplicableTradeTax do
                  ElectronicInvoice::Helpers.currency_element(xml, "ram", "CalculatedAmount", entry[:tax], currency_code)
                  xml["ram"].TypeCode "VAT"

                  exemption = TAX_EXEMPTION_REASONS[category_code]
                  if exemption
                    xml["ram"].ExemptionReason tax_exemption_reason.presence || exemption[:reason]
                  end

                  ElectronicInvoice::Helpers.currency_element(xml, "ram", "BasisAmount", entry[:basis], currency_code)
                  xml["ram"].CategoryCode category_code

                  if exemption&.dig(:code)
                    xml["ram"].ExemptionReasonCode exemption[:code]
                  end

                  # The breakdown always carries a rate (BR-DE-14), 0 for categories without rate
                  xml["ram"].RateApplicablePercent ElectronicInvoice::Helpers.format_value(entry[:tax_rate] * 100)
                end
              end

              # Billing period
              if delivery_date_until.present?
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

              # Discounts
              invoice_line_items.select(&:discounted?).group_by(&:tax_key).each do |(category_code, tax_rate), items|
                basis = items.sum(&:line_total)
                amount = items.sum(&:allowance_amount)

                xml["ram"].SpecifiedTradeAllowanceCharge do
                  xml["ram"].ChargeIndicator do
                    xml["udt"].Indicator "false"
                  end

                  # The percentage is only given if it matches the amount (PEPPOL-EN16931-R040)
                  discounts = items.map { _1.discount.to_d }.uniq
                  if discounts.one? && ((basis * discounts.first).round - amount).abs <= 2
                    xml["ram"].CalculationPercent ElectronicInvoice::Helpers.format_value(discounts.first * 100)
                  end

                  ElectronicInvoice::Helpers.currency_element(xml, "ram", "BasisAmount", basis, currency_code)
                  ElectronicInvoice::Helpers.currency_element(xml, "ram", "ActualAmount", amount, currency_code)

                  xml["ram"].Reason items.map(&:discount_reason).uniq.join(", ")

                  xml["ram"].CategoryTradeTax do
                    ElectronicInvoice::Helpers.tax_category_elements(xml, category_code, tax_rate)
                  end
                end
              end

              # Charges
              invoice_charges.each do |charge|
                charge.to_xml(xml, currency_code)
              end

              # Payment terms
              xml["ram"].SpecifiedTradePaymentTerms do
                xml["ram"].Description payment_terms_description
                xml["ram"].DueDateDateTime do
                  xml["udt"].DateTimeString(format: "102") do
                    xml.text(due_date.to_date.strftime("%Y%m%d"))
                  end
                end
                xml["ram"].DirectDebitMandateID mandate_reference if direct_debit?
              end

              # Totals
              xml["ram"].SpecifiedTradeSettlementHeaderMonetarySummation do
                ElectronicInvoice::Helpers.currency_element(xml, "ram", "LineTotalAmount", line_total_amount, currency_code)
                ElectronicInvoice::Helpers.currency_element(xml, "ram", "ChargeTotalAmount", charge_total_amount, currency_code)
                ElectronicInvoice::Helpers.currency_element(xml, "ram", "AllowanceTotalAmount", allowance_total_amount, currency_code)
                ElectronicInvoice::Helpers.currency_element(xml, "ram", "TaxBasisTotalAmount", tax_basis_total_amount, currency_code)
                ElectronicInvoice::Helpers.currency_element(xml, "ram", "TaxTotalAmount", tax_total_amount, currency_code, add_currency: true)
                ElectronicInvoice::Helpers.currency_element(xml, "ram", "GrandTotalAmount", grand_total_amount, currency_code)
                ElectronicInvoice::Helpers.currency_element(xml, "ram", "TotalPrepaidAmount", prepaid_total_amount, currency_code)
                ElectronicInvoice::Helpers.currency_element(xml, "ram", "DuePayableAmount", due_payable_amount, currency_code)
              end

              # Reference to the original invoice in case of a reversal or credit note
              if preceding_invoice_reference.present?
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

    def not_subject_to_vat?
      invoice_line_items.any? { _1.tax_category_code == "O" }
    end

    # Payment terms with the cash discounts in the XRechnung Skonto format (BR-DE-18)
    def payment_terms_description
      skonto = Array(cash_discounts).map do |discount|
        discount = discount.to_h.symbolize_keys
        line = "#SKONTO#TAGE=#{discount[:days].to_i}#PROZENT=#{ElectronicInvoice::Helpers.format_value(discount[:rate].to_d * 100)}#"
        line += "BASISBETRAG=#{ElectronicInvoice::Helpers.format_value(discount[:basis_amount].to_d / 100)}#" if discount[:basis_amount].present?
        line
      end

      # Every Skonto line has to be terminated by a line break
      skonto.empty? ? payment_terms : "#{[payment_terms, *skonto].join("\n")}\n"
    end

    def associated_errors
      errors.add(:seller, seller_trade_party.errors.full_messages.join(", ")) unless seller_trade_party.valid?
      errors.add(:buyer, buyer_trade_party.errors.full_messages.join(", ")) unless buyer_trade_party.valid?
      errors.add(:ship_to, ship_to_trade_party.errors.full_messages.join(", ")) unless ship_to_trade_party.valid?
      invoice_line_items.map.with_index(1) do|li, i|
        errors.add("Line item #{i}", li.errors.full_messages.join(", ")) unless li.valid?
      end
      invoice_charges.map.with_index(1) do |charge, i|
        errors.add("Charge #{i}", charge.errors.full_messages.join(", ")) unless charge.valid?
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
      errors.add(:line_items, "must contain at least one item") if line_items.blank?
    end

    def validate_codes
      errors.add(:kind, "is not a known invoice type") unless type_code
      errors.add(:payment_type, "is not a known payment type") if payment_type.present? && !payment_code
      errors.add(:standard, "must be one of #{GUIDELINES.keys.join(", ")}") unless GUIDELINES.key?(standard)
    end

    # BR-DE-19, BR-DE-20
    def validate_ibans
      errors.add(:iban, "is not a valid IBAN") if iban.present? && !ElectronicInvoice::Helpers.valid_iban?(iban)
      errors.add(:debtor_iban, "is not a valid IBAN") if debtor_iban.present? && !ElectronicInvoice::Helpers.valid_iban?(debtor_iban)
    end

    def validate_cash_discounts
      Array(cash_discounts).each do |discount|
        discount = discount.to_h.symbolize_keys
        unless discount[:days].to_i.positive? && discount[:rate].to_d.positive?
          errors.add(:cash_discounts, "need positive days and rate")
        end
      end
    end

    # BR-S-02, BR-Z-02, BR-E-02, BR-AE-02/03, BR-IC-02/03, BR-G-02
    def validate_tax_registrations
      return if seller.blank?

      codes = (invoice_line_items + invoice_charges).map(&:tax_category_code).compact.uniq

      if (codes & %w[AE K G]).any?
        errors.add(:seller, "VAT ID is required for tax categories AE, K and G") if seller_trade_party.vat_id.blank?
      elsif (codes & %w[S Z E]).any?
        errors.add(:seller, "VAT ID or tax ID is required") if seller_trade_party.vat_id.blank? && seller_trade_party.tax_id.blank?
      end

      return if buyer.blank?

      if codes.include?("AE") && buyer_trade_party.vat_id.blank? && buyer_trade_party.registration_number.blank?
        errors.add(:buyer, "VAT ID or registration number is required for tax category AE")
      end

      if codes.include?("K") && buyer_trade_party.vat_id.blank?
        errors.add(:buyer, "VAT ID is required for tax category K")
      end
    end

    # BR-O-11 - BR-O-14
    def validate_not_subject_to_vat
      codes = (invoice_line_items + invoice_charges).map(&:tax_category_code).compact.uniq

      if codes.include?("O") && codes.size > 1
        errors.add(:line_items, "must not combine tax category O with other tax categories")
      end
    end

    # The totals are calculated from the line items. Given totals have to match (BR-CO-10 - BR-CO-16).
    def validate_totals
      return unless invoice_line_items.all?(&:valid?) && invoice_charges.all?(&:valid?)

      if net_total.present? && ElectronicInvoice::Helpers.cents(net_total) != tax_basis_total_amount
        errors.add(:net_total, "does not match the calculated total of #{ElectronicInvoice::Helpers.format_value(tax_basis_total_amount.to_d / 100)}")
      end

      if gross_total.present? && ElectronicInvoice::Helpers.cents(gross_total) != grand_total_amount
        errors.add(:gross_total, "does not match the calculated total of #{ElectronicInvoice::Helpers.format_value(grand_total_amount.to_d / 100)}")
      end
    end

    # XRechnung 3.0 specific business rules (BR-DE-*)
    def validate_xrechnung
      if buyer_reference.blank? && buyer_trade_party.electronic_invoicing_identifier.blank?
        errors.add(:buyer_reference, "(Leitweg-ID) is required for XRechnung")
      end

      if type_code && !XRECHNUNG_TYPE_CODES.include?(type_code)
        errors.add(:kind, "is not allowed for XRechnung")
      end

      if type_code == INVOICE_TYPES[:CORRECTION][:code] && preceding_invoice_reference.blank?
        errors.add(:preceding_invoice_reference, "is required for corrections")
      end

      if seller.present?
        %i[contact_name phone email electronic_address].each do |attribute|
          errors.add(:seller, "#{attribute} is required for XRechnung") if seller_trade_party.public_send(attribute).blank?
        end

        # BR-DE-27, BR-DE-28
        if seller_trade_party.phone.present? && seller_trade_party.phone.to_s.scan(/\d/).size < 3
          errors.add(:seller, "phone must contain at least three digits")
        end

        if seller_trade_party.email.present? && !seller_trade_party.email.to_s.strip.match?(/\A[^@\s]+@([^@.\s]+\.)+[^@.\s]+\z/)
          errors.add(:seller, "email is not a valid email address")
        end
      end

      if buyer.present? && buyer_trade_party.electronic_address.blank?
        errors.add(:buyer, "electronic_address is required for XRechnung")
      end

      if card_payment? && card_number.blank?
        errors.add(:card_number, "is required for card payments in XRechnung")
      end
    end
  end
end
