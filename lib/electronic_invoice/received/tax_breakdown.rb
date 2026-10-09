# frozen_string_literal: true

module ElectronicInvoice
  module Received
    # VAT breakdown (BG-23), rate in percent
    TaxBreakdown = Struct.new(:category, :rate, :basis_amount, :tax_amount, :exemption_reason, :exemption_reason_code,
      keyword_init: true)
  end
end
