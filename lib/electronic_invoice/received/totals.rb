# frozen_string_literal: true

module ElectronicInvoice
  module Received
    # Document totals (BG-22) as BigDecimals, nil if not given
    Totals = Struct.new(:line_total, :allowance_total, :charge_total, :tax_basis_total, :tax_total, :grand_total,
      :prepaid, :rounding, :due_payable, keyword_init: true)
  end
end
