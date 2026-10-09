# frozen_string_literal: true

module ElectronicInvoice
  module Received
    # Allowance (charge: false) or charge (charge: true) on document (BG-20, BG-21) or line level (BG-27, BG-28).
    # Amounts are BigDecimals, percent and tax_rate are given in percent.
    AllowanceCharge = Struct.new(:charge, :amount, :base_amount, :percent, :reason, :reason_code, :tax_category,
      :tax_rate, keyword_init: true) do
      def charge?
        charge == true
      end

      def allowance?
        !charge?
      end
    end
  end
end
