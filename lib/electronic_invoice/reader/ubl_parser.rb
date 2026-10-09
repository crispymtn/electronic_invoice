# frozen_string_literal: true

module ElectronicInvoice
  module Reader
    # Reads a UBL 2.1 Invoice or CreditNote (XRechnung UBL, PEPPOL BIS) into a Received::Invoice
    class UblParser < Parser
      NS = UBL_NAMESPACES

      # Notes may carry their subject code (BT-21) as "#ADU#text"
      NOTE_PATTERN = /\A#([A-Z]{3})#(.*)\z/m

      def parse
        root = document.root
        credit_note = root.name == "CreditNote"
        currency_code = text(root, "cbc:DocumentCurrencyCode")
        guideline_id = text(root, "cbc:CustomizationID")

        invoice = Received::Invoice.new(
          number: text(root, "cbc:ID"),
          type_code: text(root, credit_note ? "cbc:CreditNoteTypeCode" : "cbc:InvoiceTypeCode"),
          issue_date: date(root, "cbc:IssueDate"),
          currency_code: currency_code,
          tax_currency_code: text(root, "cbc:TaxCurrencyCode"),
          profile: profile(guideline_id),
          guideline_id: guideline_id,
          business_process: text(root, "cbc:ProfileID"),
          buyer_reference: text(root, "cbc:BuyerReference"),
          order_reference: text(root, "cac:OrderReference/cbc:ID"),
          contract_reference: text(root, "cac:ContractDocumentReference/cbc:ID"),
          payment_reference: text(root, "cac:PaymentMeans/cbc:PaymentID"),
          preceding_invoices: all(root, "cac:BillingReference/cac:InvoiceDocumentReference").map do
            { number: text(_1, "cbc:ID"), date: date(_1, "cbc:IssueDate") }
          end,
          notes: all(root, "cbc:Note").map { note(_1.text.strip) },
          seller: party(at(root, "cac:AccountingSupplierParty/cac:Party")),
          buyer: party(at(root, "cac:AccountingCustomerParty/cac:Party")),
          payee: party(at(root, "cac:PayeeParty")),
          ship_to: ship_to(at(root, "cac:Delivery")),
          delivery_date: date(root, "cac:Delivery/cbc:ActualDeliveryDate"),
          billing_period: period(at(root, "cac:InvoicePeriod")),
          line_items: all(root, credit_note ? "cac:CreditNoteLine" : "cac:InvoiceLine").map { line_item(_1) },
          allowances_charges: all(root, "cac:AllowanceCharge").map { allowance_charge(_1) },
          tax_breakdown: all(root, "cac:TaxTotal/cac:TaxSubtotal").map { tax_breakdown(_1) },
          payment_means: payment_means(root),
          payment_terms: payment_terms(root),
          totals: totals(root, currency_code),
          syntax: :ubl,
          raw_xml: @xml
        )

        check_mandatory(invoice)
        invoice
      end

      private

      def note(content)
        match = content.match(NOTE_PATTERN)
        match ? { subject_code: match[1], text: match[2].strip } : { subject_code: nil, text: content }
      end

      # The legal name (BT-27, BT-44) or the trading name (BT-28, BT-45, payee BT-59)
      def party(node)
        return unless node

        tax_schemes = all(node, "cac:PartyTaxScheme")
        vat = tax_schemes.find { text(_1, "cac:TaxScheme/cbc:ID") == "VAT" }
        tax = tax_schemes.find { text(_1, "cac:TaxScheme/cbc:ID") != "VAT" }
        trading_name = text(node, "cac:PartyName/cbc:Name")
        contact = at(node, "cac:Contact")
        electronic_address = at(node, "cbc:EndpointID")

        Received::Party.new(
          name: text(node, "cac:PartyLegalEntity/cbc:RegistrationName") || trading_name,
          trading_name: (trading_name if text(node, "cac:PartyLegalEntity/cbc:RegistrationName")),
          description: text(node, "cac:PartyLegalEntity/cbc:CompanyLegalForm"),
          # The bank assigned creditor identifier (BT-90) is a payment information
          ids: all(node, "cac:PartyIdentification/cbc:ID[not(@schemeID = 'SEPA')]").map { { id: _1.text.strip, scheme: _1["schemeID"] } },
          vat_id: text(vat, "cbc:CompanyID"),
          tax_id: text(tax, "cbc:CompanyID"),
          registration_number: text(node, "cac:PartyLegalEntity/cbc:CompanyID"),
          electronic_address: electronic_address&.text&.strip,
          electronic_address_scheme: electronic_address&.[]("schemeID"),
          contact_name: text(contact, "cbc:Name"),
          phone: text(contact, "cbc:Telephone"),
          email: text(contact, "cbc:ElectronicMail"),
          **address(at(node, "cac:PostalAddress"))
        )
      end

      # Deliver to (BG-13): name, location identifier and address
      def ship_to(delivery)
        location = at(delivery, "cac:DeliveryLocation")
        name = text(delivery, "cac:DeliveryParty/cac:PartyName/cbc:Name")
        return unless name || location

        Received::Party.new(
          name: name,
          ids: all(location, "cbc:ID").map { { id: _1.text.strip, scheme: _1["schemeID"] } },
          **address(at(location, "cac:Address"))
        )
      end

      def address(node)
        {
          street: text(node, "cbc:StreetName"),
          line2: text(node, "cbc:AdditionalStreetName"),
          line3: text(node, "cac:AddressLine/cbc:Line"),
          zip_code: text(node, "cbc:PostalZone"),
          town: text(node, "cbc:CityName"),
          country_code: text(node, "cac:Country/cbc:IdentificationCode"),
          subdivision: text(node, "cbc:CountrySubentity")
        }
      end

      def line_item(node)
        item = at(node, "cac:Item")
        price = at(node, "cac:Price")
        quantity = at(node, "cbc:InvoicedQuantity | cbc:CreditedQuantity")

        Received::LineItem.new(
          id: text(node, "cbc:ID"),
          name: text(item, "cbc:Name"),
          description: text(item, "cbc:Description"),
          seller_item_id: text(item, "cac:SellersItemIdentification/cbc:ID"),
          buyer_item_id: text(item, "cac:BuyersItemIdentification/cbc:ID"),
          standard_item_id: text(item, "cac:StandardItemIdentification/cbc:ID"),
          notes: all(node, "cbc:Note").map { _1.text.strip },
          quantity: decimal(quantity),
          unit_code: quantity&.[]("unitCode"),
          net_price: decimal(at(price, "cbc:PriceAmount")),
          gross_price: decimal(at(price, "cac:AllowanceCharge/cbc:BaseAmount")),
          price_basis_quantity: decimal(at(price, "cbc:BaseQuantity")),
          tax_category: text(item, "cac:ClassifiedTaxCategory/cbc:ID"),
          tax_rate: decimal(at(item, "cac:ClassifiedTaxCategory/cbc:Percent")),
          net_total: decimal(at(node, "cbc:LineExtensionAmount")),
          allowances_charges: all(node, "cac:AllowanceCharge").map { allowance_charge(_1) },
          billing_period: period(at(node, "cac:InvoicePeriod"))
        )
      end

      def allowance_charge(node)
        Received::AllowanceCharge.new(
          charge: text(node, "cbc:ChargeIndicator") == "true",
          amount: decimal(at(node, "cbc:Amount")),
          base_amount: decimal(at(node, "cbc:BaseAmount")),
          percent: decimal(at(node, "cbc:MultiplierFactorNumeric")),
          reason: text(node, "cbc:AllowanceChargeReason"),
          reason_code: text(node, "cbc:AllowanceChargeReasonCode"),
          tax_category: text(node, "cac:TaxCategory/cbc:ID"),
          tax_rate: decimal(at(node, "cac:TaxCategory/cbc:Percent"))
        )
      end

      def tax_breakdown(node)
        Received::TaxBreakdown.new(
          category: text(node, "cac:TaxCategory/cbc:ID"),
          rate: decimal(at(node, "cac:TaxCategory/cbc:Percent")),
          basis_amount: decimal(at(node, "cbc:TaxableAmount")),
          tax_amount: decimal(at(node, "cbc:TaxAmount")),
          exemption_reason: text(node, "cac:TaxCategory/cbc:TaxExemptionReason"),
          exemption_reason_code: text(node, "cac:TaxCategory/cbc:TaxExemptionReasonCode")
        )
      end

      # The creditor identifier (BT-90) is given as identifier with scheme SEPA of the seller or payee
      def payment_means(root)
        creditor_reference_id = text(root, "cac:AccountingSupplierParty/cac:Party/cac:PartyIdentification/cbc:ID[@schemeID = 'SEPA'] | cac:PayeeParty/cac:PartyIdentification/cbc:ID[@schemeID = 'SEPA']")

        all(root, "cac:PaymentMeans").map do |node|
          type_code = text(node, "cbc:PaymentMeansCode")
          mandate = at(node, "cac:PaymentMandate")
          direct_debit = mandate.present? || DIRECT_DEBIT_PAYMENT_CODES.include?(type_code)

          Received::PaymentMeans.new(
            type_code: type_code,
            information: at(node, "cbc:PaymentMeansCode")&.[]("name"),
            iban: text(node, "cac:PayeeFinancialAccount/cbc:ID"),
            bic: text(node, "cac:PayeeFinancialAccount/cac:FinancialInstitutionBranch/cbc:ID"),
            account_name: text(node, "cac:PayeeFinancialAccount/cbc:Name"),
            mandate_reference: text(mandate, "cbc:ID"),
            creditor_reference_id: (creditor_reference_id if direct_debit),
            debtor_iban: text(mandate, "cac:PayerFinancialAccount/cbc:ID"),
            card_number: text(node, "cac:CardAccount/cbc:PrimaryAccountNumberID"),
            card_holder: text(node, "cac:CardAccount/cbc:HolderName")
          )
        end
      end

      # The due date is cbc:DueDate in invoices and PaymentDueDate in credit notes
      def payment_terms(root)
        description = all(root, "cac:PaymentTerms/cbc:Note").filter_map { _1.text.strip.presence }.join("\n").presence
        due_date = date(root, "cbc:DueDate") || date(root, "cac:PaymentMeans/cbc:PaymentDueDate")
        return unless description || due_date

        Received::PaymentTerms.new(description: description, due_date: due_date, discount_terms: [])
      end

      def totals(root, currency_code)
        node = at(root, "cac:LegalMonetaryTotal")
        # The tax total can be given twice, in invoice and in tax currency (BT-110, BT-111)
        tax_total = all(root, "cac:TaxTotal/cbc:TaxAmount").find { _1["currencyID"].blank? || _1["currencyID"] == currency_code }

        Received::Totals.new(
          line_total: decimal(at(node, "cbc:LineExtensionAmount")),
          allowance_total: decimal(at(node, "cbc:AllowanceTotalAmount")),
          charge_total: decimal(at(node, "cbc:ChargeTotalAmount")),
          tax_basis_total: decimal(at(node, "cbc:TaxExclusiveAmount")),
          tax_total: decimal(tax_total),
          grand_total: decimal(at(node, "cbc:TaxInclusiveAmount")),
          prepaid: decimal(at(node, "cbc:PrepaidAmount")),
          rounding: decimal(at(node, "cbc:PayableRoundingAmount")),
          due_payable: decimal(at(node, "cbc:PayableAmount"))
        )
      end

      def period(node)
        return unless node

        { start: date(node, "cbc:StartDate"), end: date(node, "cbc:EndDate") }
      end

      # xs:date, YYYY-MM-DD with optional time zone
      def date(node, path)
        value = at(node, path)&.text&.strip
        return if value.blank?

        Date.strptime(value[0, 10], "%Y-%m-%d")
      rescue Date::Error
        raise ParseError, "#{path.split("/").last} is not a valid date: #{value}"
      end
    end
  end
end
