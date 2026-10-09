# frozen_string_literal: true

module ElectronicInvoice
  module Received
    # Invoice line (BG-25). Amounts and quantities are BigDecimals, tax_rate is given in percent (19 = 19 %).
    #
    # billing_period: { start: Date, end: Date } or nil
    LineItem = Struct.new(:id, :name, :description, :seller_item_id, :buyer_item_id, :standard_item_id, :notes,
      :quantity, :unit_code, :net_price, :gross_price, :price_basis_quantity, :tax_category, :tax_rate, :net_total,
      :allowances_charges, :billing_period, keyword_init: true)
  end
end
