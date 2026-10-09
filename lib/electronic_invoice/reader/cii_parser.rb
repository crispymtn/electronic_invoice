# frozen_string_literal: true

module ElectronicInvoice
  module Reader
    # Reads a UN/CEFACT Cross Industry Invoice (ZUGFeRD 2.x, Factur-X, XRechnung CII) into a Received::Invoice
    class CiiParser < Parser
      NS = CII_NAMESPACES

      def parse
        root = document.root
        document_node = at(root, "rsm:ExchangedDocument")
        transaction = at(root, "rsm:SupplyChainTradeTransaction")
        agreement = at(transaction, "ram:ApplicableHeaderTradeAgreement")
        delivery = at(transaction, "ram:ApplicableHeaderTradeDelivery")
        settlement = at(transaction, "ram:ApplicableHeaderTradeSettlement")

        currency_code = text(settlement, "ram:InvoiceCurrencyCode")
        guideline_id = text(root, "rsm:ExchangedDocumentContext/ram:GuidelineSpecifiedDocumentContextParameter/ram:ID")

        invoice = Received::Invoice.new(
          number: text(document_node, "ram:ID"),
          type_code: text(document_node, "ram:TypeCode"),
          issue_date: date(document_node, "ram:IssueDateTime/udt:DateTimeString"),
          currency_code: currency_code,
          tax_currency_code: text(settlement, "ram:TaxCurrencyCode"),
          profile: profile(guideline_id),
          guideline_id: guideline_id,
          business_process: text(root, "rsm:ExchangedDocumentContext/ram:BusinessProcessSpecifiedDocumentContextParameter/ram:ID"),
          buyer_reference: text(agreement, "ram:BuyerReference"),
          order_reference: text(agreement, "ram:BuyerOrderReferencedDocument/ram:IssuerAssignedID"),
          contract_reference: text(agreement, "ram:ContractReferencedDocument/ram:IssuerAssignedID"),
          payment_reference: text(settlement, "ram:PaymentReference"),
          preceding_invoices: all(settlement, "ram:InvoiceReferencedDocument").map do
            { number: text(_1, "ram:IssuerAssignedID"), date: date(_1, "ram:FormattedIssueDateTime/qdt:DateTimeString") }
          end,
          notes: all(document_node, "ram:IncludedNote").map do
            { subject_code: text(_1, "ram:SubjectCode"), text: text(_1, "ram:Content") }
          end,
          seller: party(at(agreement, "ram:SellerTradeParty")),
          buyer: party(at(agreement, "ram:BuyerTradeParty")),
          payee: party(at(settlement, "ram:PayeeTradeParty")),
          ship_to: party(at(delivery, "ram:ShipToTradeParty")),
          delivery_date: date(delivery, "ram:ActualDeliverySupplyChainEvent/ram:OccurrenceDateTime/udt:DateTimeString"),
          billing_period: period(at(settlement, "ram:BillingSpecifiedPeriod")),
          line_items: all(transaction, "ram:IncludedSupplyChainTradeLineItem").map { line_item(_1) },
          allowances_charges: all(settlement, "ram:SpecifiedTradeAllowanceCharge").map { allowance_charge(_1) } +
            all(settlement, "ram:SpecifiedLogisticsServiceCharge").map { logistics_service_charge(_1) },
          tax_breakdown: all(settlement, "ram:ApplicableTradeTax").map { tax_breakdown(_1) },
          payment_means: payment_means(settlement),
          payment_terms: payment_terms(settlement),
          totals: totals(at(settlement, "ram:SpecifiedTradeSettlementHeaderMonetarySummation"), currency_code),
          syntax: :cii,
          raw_xml: @xml
        )

        check_mandatory(invoice)
        invoice
      end

      private

      def party(node)
        return unless node

        tax_registrations = all(node, "ram:SpecifiedTaxRegistration/ram:ID").to_h { [_1["schemeID"], _1.text.strip] }
        address = at(node, "ram:PostalTradeAddress")
        contact = at(node, "ram:DefinedTradeContact")
        electronic_address = at(node, "ram:URIUniversalCommunication/ram:URIID")

        Received::Party.new(
          name: text(node, "ram:Name"),
          trading_name: text(node, "ram:SpecifiedLegalOrganization/ram:TradingBusinessName"),
          description: text(node, "ram:Description"),
          ids: all(node, "ram:ID | ram:GlobalID").map { { id: _1.text.strip, scheme: _1["schemeID"] } },
          vat_id: tax_registrations["VA"],
          tax_id: tax_registrations["FC"],
          registration_number: text(node, "ram:SpecifiedLegalOrganization/ram:ID"),
          electronic_address: electronic_address&.text&.strip,
          electronic_address_scheme: electronic_address&.[]("schemeID"),
          # Contact point (BT-41, BT-56), a person or department
          contact_name: text(contact, "ram:PersonName") || text(contact, "ram:DepartmentName"),
          phone: text(contact, "ram:TelephoneUniversalCommunication/ram:CompleteNumber"),
          email: text(contact, "ram:EmailURIUniversalCommunication/ram:URIID"),
          street: text(address, "ram:LineOne"),
          line2: text(address, "ram:LineTwo"),
          line3: text(address, "ram:LineThree"),
          zip_code: text(address, "ram:PostcodeCode"),
          town: text(address, "ram:CityName"),
          country_code: text(address, "ram:CountryID"),
          subdivision: text(address, "ram:CountrySubDivisionName")
        )
      end

      def line_item(node)
        product = at(node, "ram:SpecifiedTradeProduct")
        agreement = at(node, "ram:SpecifiedLineTradeAgreement")
        settlement = at(node, "ram:SpecifiedLineTradeSettlement")
        quantity = at(node, "ram:SpecifiedLineTradeDelivery/ram:BilledQuantity")

        Received::LineItem.new(
          id: text(node, "ram:AssociatedDocumentLineDocument/ram:LineID"),
          name: text(product, "ram:Name"),
          description: text(product, "ram:Description"),
          seller_item_id: text(product, "ram:SellerAssignedID"),
          buyer_item_id: text(product, "ram:BuyerAssignedID"),
          standard_item_id: text(product, "ram:GlobalID"),
          notes: all(node, "ram:AssociatedDocumentLineDocument/ram:IncludedNote/ram:Content").map { _1.text.strip },
          quantity: decimal(quantity),
          unit_code: quantity&.[]("unitCode"),
          net_price: decimal(at(agreement, "ram:NetPriceProductTradePrice/ram:ChargeAmount")),
          gross_price: decimal(at(agreement, "ram:GrossPriceProductTradePrice/ram:ChargeAmount")),
          price_basis_quantity: decimal(at(agreement, "ram:NetPriceProductTradePrice/ram:BasisQuantity")) ||
            decimal(at(agreement, "ram:GrossPriceProductTradePrice/ram:BasisQuantity")),
          tax_category: text(settlement, "ram:ApplicableTradeTax/ram:CategoryCode"),
          tax_rate: decimal(at(settlement, "ram:ApplicableTradeTax/ram:RateApplicablePercent")),
          net_total: decimal(at(settlement, "ram:SpecifiedTradeSettlementLineMonetarySummation/ram:LineTotalAmount")),
          allowances_charges: all(settlement, "ram:SpecifiedTradeAllowanceCharge").map { allowance_charge(_1) },
          billing_period: period(at(settlement, "ram:BillingSpecifiedPeriod"))
        )
      end

      def allowance_charge(node)
        Received::AllowanceCharge.new(
          charge: text(node, "ram:ChargeIndicator/udt:Indicator") == "true",
          amount: decimal(at(node, "ram:ActualAmount")),
          base_amount: decimal(at(node, "ram:BasisAmount")),
          percent: decimal(at(node, "ram:CalculationPercent")),
          reason: text(node, "ram:Reason"),
          reason_code: text(node, "ram:ReasonCode"),
          tax_category: text(node, "ram:CategoryTradeTax/ram:CategoryCode"),
          tax_rate: decimal(at(node, "ram:CategoryTradeTax/ram:RateApplicablePercent"))
        )
      end

      # Service charge of the EXTENDED profile, counted as document level charge
      def logistics_service_charge(node)
        Received::AllowanceCharge.new(
          charge: true,
          amount: decimal(at(node, "ram:AppliedAmount")),
          reason: text(node, "ram:Description"),
          tax_category: text(node, "ram:AppliedTradeTax/ram:CategoryCode"),
          tax_rate: decimal(at(node, "ram:AppliedTradeTax/ram:RateApplicablePercent"))
        )
      end

      def tax_breakdown(node)
        Received::TaxBreakdown.new(
          category: text(node, "ram:CategoryCode"),
          rate: decimal(at(node, "ram:RateApplicablePercent")),
          basis_amount: decimal(at(node, "ram:BasisAmount")),
          tax_amount: decimal(at(node, "ram:CalculatedAmount")),
          exemption_reason: text(node, "ram:ExemptionReason"),
          exemption_reason_code: text(node, "ram:ExemptionReasonCode")
        )
      end

      # Mandate reference (BT-89) and creditor identifier (BT-90) are given once for the document
      def payment_means(settlement)
        mandate_reference = text(settlement, "ram:SpecifiedTradePaymentTerms/ram:DirectDebitMandateID")
        creditor_reference_id = text(settlement, "ram:CreditorReferenceID")

        all(settlement, "ram:SpecifiedTradeSettlementPaymentMeans").map do |node|
          type_code = text(node, "ram:TypeCode")
          debtor_iban = text(node, "ram:PayerPartyDebtorFinancialAccount/ram:IBANID")
          direct_debit = debtor_iban.present? || DIRECT_DEBIT_PAYMENT_CODES.include?(type_code)

          Received::PaymentMeans.new(
            type_code: type_code,
            information: text(node, "ram:Information"),
            iban: text(node, "ram:PayeePartyCreditorFinancialAccount/ram:IBANID") ||
              text(node, "ram:PayeePartyCreditorFinancialAccount/ram:ProprietaryID"),
            bic: text(node, "ram:PayeeSpecifiedCreditorFinancialInstitution/ram:BICID"),
            account_name: text(node, "ram:PayeePartyCreditorFinancialAccount/ram:AccountName"),
            mandate_reference: (mandate_reference if direct_debit),
            creditor_reference_id: (creditor_reference_id if direct_debit),
            debtor_iban: debtor_iban,
            card_number: text(node, "ram:ApplicableTradeSettlementFinancialCard/ram:ID"),
            card_holder: text(node, "ram:ApplicableTradeSettlementFinancialCard/ram:CardholderName")
          )
        end
      end

      # EN 16931 allows one description and due date, EXTENDED several payment terms, which are combined
      def payment_terms(settlement)
        nodes = all(settlement, "ram:SpecifiedTradePaymentTerms")
        return if nodes.empty?

        Received::PaymentTerms.new(
          description: nodes.filter_map { text(_1, "ram:Description") }.join("\n").presence,
          due_date: nodes.lazy.filter_map { date(_1, "ram:DueDateDateTime/udt:DateTimeString") }.first,
          discount_terms: nodes.flat_map { all(_1, "ram:ApplicableTradePaymentDiscountTerms") }.map do
            {
              days: decimal(at(_1, "ram:BasisPeriodMeasure"))&.to_i,
              percent: decimal(at(_1, "ram:CalculationPercent")),
              basis_amount: decimal(at(_1, "ram:BasisAmount"))
            }
          end
        )
      end

      def totals(node, currency_code)
        # The tax total can be given twice, in invoice and in tax currency (BT-110, BT-111)
        tax_total = all(node, "ram:TaxTotalAmount").find { _1["currencyID"].blank? || _1["currencyID"] == currency_code }

        Received::Totals.new(
          line_total: decimal(at(node, "ram:LineTotalAmount")),
          allowance_total: decimal(at(node, "ram:AllowanceTotalAmount")),
          charge_total: decimal(at(node, "ram:ChargeTotalAmount")),
          tax_basis_total: decimal(at(node, "ram:TaxBasisTotalAmount")),
          tax_total: decimal(tax_total),
          grand_total: decimal(at(node, "ram:GrandTotalAmount")),
          prepaid: decimal(at(node, "ram:TotalPrepaidAmount")),
          rounding: decimal(at(node, "ram:RoundingAmount")),
          due_payable: decimal(at(node, "ram:DuePayableAmount"))
        )
      end

      def period(node)
        return unless node

        { start: date(node, "ram:StartDateTime/udt:DateTimeString"), end: date(node, "ram:EndDateTime/udt:DateTimeString") }
      end

      # Format 102 (YYYYMMDD), 610 (YYYYMM) and 616 (YYYYWW)
      def date(node, path)
        element = at(node, path)
        value = element&.text&.strip
        return if value.blank?

        case element["format"].presence || "102"
        when "102" then Date.strptime(value, "%Y%m%d")
        when "610" then Date.strptime(value, "%Y%m")
        when "616" then Date.commercial(value[0, 4].to_i, value[4, 2].to_i)
        else raise ParseError, "Unsupported date format #{element["format"]}"
        end
      rescue Date::Error
        raise ParseError, "#{element.parent.name} is not a valid date: #{value}"
      end
    end
  end
end
