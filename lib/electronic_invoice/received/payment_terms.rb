# frozen_string_literal: true

module ElectronicInvoice
  module Received
    # Cash discount in the XRechnung Skonto format (BR-DE-18)
    SKONTO_PATTERN = /#SKONTO#TAGE=(\d+)#PROZENT=(-?\d+(?:\.\d+)?)#(?:BASISBETRAG=(-?\d+(?:\.\d+)?)#)?/

    # Payment terms (BT-20) and due date (BT-9)
    #
    # discount_terms: structured cash discounts of the EXTENDED profile (ApplicableTradePaymentDiscountTerms)
    PaymentTerms = Struct.new(:description, :due_date, :discount_terms, keyword_init: true) do
      # Cash discounts given in the Skonto format, e.g. "#SKONTO#TAGE=14#PROZENT=2.00#", or as discount terms:
      # [{ days: 14, percent: 2.0, basis_amount: nil }], percent and basis_amount as BigDecimals
      def cash_discounts
        skonto = description.to_s.scan(SKONTO_PATTERN).map do |days, percent, basis_amount|
          { days: days.to_i, percent: BigDecimal(percent), basis_amount: basis_amount && BigDecimal(basis_amount) }
        end

        skonto + Array(discount_terms)
      end

      # The description without the Skonto lines
      def text
        description.to_s.gsub(SKONTO_PATTERN, "").strip.presence
      end
    end
  end
end
