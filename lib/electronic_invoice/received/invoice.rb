# frozen_string_literal: true

module ElectronicInvoice
  module Received
    # An invoice read from a CII or UBL XML or a ZUGFeRD / Factur-X PDF.
    # Amounts are BigDecimals in the invoice currency, rates in percent, dates are Dates.
    #
    # syntax: :cii or :ubl
    # profile: :minimum, :basic_wl, :basic, :en16931, :extended, :xrechnung or :unknown
    # notes: [{ subject_code: "REG", text: "..." }]
    # preceding_invoices: [{ number: "RE-1", date: Date }]
    # billing_period: { start: Date, end: Date } or nil
    Invoice = Struct.new(:number, :type_code, :issue_date, :currency_code, :tax_currency_code, :profile,
      :guideline_id, :business_process, :buyer_reference, :order_reference, :contract_reference, :payment_reference,
      :preceding_invoices, :notes, :seller, :buyer, :payee, :ship_to, :delivery_date, :billing_period, :line_items,
      :allowances_charges, :tax_breakdown, :payment_means, :payment_terms, :totals, :syntax, :raw_xml, keyword_init: true) do
      # Whether the profile meets EN 16931, i.e. the invoice is an e-invoice according to § 14 UStG
      def e_invoice?
        E_INVOICE_PROFILES.include?(profile)
      end

      def due_date
        payment_terms&.due_date
      end

      def allowances
        allowances_charges.select(&:allowance?)
      end

      def charges
        allowances_charges.select(&:charge?)
      end

      # Differences between the totals and the amounts they are calculated from (BR-CO-10 - BR-CO-16).
      # Received invoices are read even if they are inconsistent, check this before booking them.
      def arithmetic_warnings
        warnings = []
        check = lambda do |rule, label, expected, actual|
          next if actual.nil? && expected.zero?
          next if actual.to_d.round(2) == expected.round(2)

          warnings << "#{rule}: #{label} is #{format_amount(actual)}, expected #{format_amount(expected)}"
        end

        check.("BR-CO-10", "line total", line_items.sum(BigDecimal("0")) { _1.net_total.to_d }, totals.line_total)
        check.("BR-CO-11", "allowance total", allowances.sum(BigDecimal("0")) { _1.amount.to_d }, totals.allowance_total)
        check.("BR-CO-12", "charge total", charges.sum(BigDecimal("0")) { _1.amount.to_d }, totals.charge_total)
        check.("BR-CO-13", "tax basis total",
          totals.line_total.to_d - totals.allowance_total.to_d + totals.charge_total.to_d, totals.tax_basis_total)
        check.("BR-CO-14", "tax total", tax_breakdown.sum(BigDecimal("0")) { _1.tax_amount.to_d }, totals.tax_total)
        check.("BR-CO-15", "grand total", totals.tax_basis_total.to_d + totals.tax_total.to_d, totals.grand_total)
        check.("BR-CO-16", "due payable amount",
          totals.grand_total.to_d - totals.prepaid.to_d + totals.rounding.to_d, totals.due_payable)

        warnings
      end

      private

      def format_amount(amount)
        amount.nil? ? "missing" : ElectronicInvoice::Helpers.format_value(amount)
      end
    end
  end
end
