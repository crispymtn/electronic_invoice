# frozen_string_literal: true

module ElectronicInvoice
  module Received
    # Payment instructions (BG-16): credit transfer (BG-17), card (BG-18) or direct debit (BG-19)
    #
    # iban: IBAN or proprietary account identifier of the payee (BT-84), the mandate reference (BT-89) and
    # creditor identifier (BT-90) are only set for direct debits
    PaymentMeans = Struct.new(:type_code, :information, :iban, :bic, :account_name, :mandate_reference,
      :creditor_reference_id, :debtor_iban, :card_number, :card_holder, keyword_init: true) do
      def credit_transfer?
        CREDIT_TRANSFER_PAYMENT_CODES.include?(type_code)
      end

      def direct_debit?
        DIRECT_DEBIT_PAYMENT_CODES.include?(type_code)
      end

      def card_payment?
        CARD_PAYMENT_CODES.include?(type_code)
      end
    end
  end
end
