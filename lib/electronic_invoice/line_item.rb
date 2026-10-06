# frozen_string_literal: true

module ElectronicInvoice
  class LineItem
    include ActiveModel::Model
    include ElectronicInvoice::Taxable

    attr_accessor :description, :qty, :unit, :net, :net_total, :gross_total, :tax_rate, :tax_category, :tax,
      :discount, :discounted_net_total, :discount_reason, :currency_code

    validates :description, :qty, :unit, :net, :net_total, :gross_total, :tax_rate, :tax_category, :tax,
      :currency_code, presence: true

    validates :discount_reason, presence: true, if: :discounted?
    validate :validate_net_total

    def discounted?
      discount.to_d.positive?
    end

    def discount_amount
      net_total - discounted_net_total
    end

    # Invoice line net amount (BT-131) in cents
    def line_total
      ElectronicInvoice::Helpers.cents(net.to_d * qty.to_d)
    end

    # Discount of this line, given as document level allowance, in cents
    def allowance_amount
      discounted? ? ElectronicInvoice::Helpers.cents(discount_amount) : 0
    end

    def taxable_amount
      line_total - allowance_amount
    end

    def to_xml(xml, line_item_index)
      xml["ram"].IncludedSupplyChainTradeLineItem do
        xml["ram"].AssociatedDocumentLineDocument do
          xml["ram"].LineID line_item_index
        end

        #  Line item description
        xml["ram"].SpecifiedTradeProduct do
          xml["ram"].Name description
        end

        # Line item price
        xml["ram"].SpecifiedLineTradeAgreement do
          xml["ram"].GrossPriceProductTradePrice do
            ElectronicInvoice::Helpers.currency_element(xml, "ram", "ChargeAmount", net.negative? ? net * -1 : net, currency_code, digits: 4)
          end
          xml["ram"].NetPriceProductTradePrice do
            ElectronicInvoice::Helpers.currency_element(xml, "ram", "ChargeAmount", net.negative? ? net * -1 : net, currency_code, digits: 4)
          end
        end

        # Line item quantity
        xml["ram"].SpecifiedLineTradeDelivery do
          xml["ram"].BilledQuantity(unitCode: ElectronicInvoice.unit_code(unit)) do
            xml.text(ElectronicInvoice::Helpers.format_value(net.negative? ? qty * -1 : qty, digits: 4))
          end
        end

        # Line item tax
        xml["ram"].SpecifiedLineTradeSettlement do
          xml["ram"].ApplicableTradeTax do
            ElectronicInvoice::Helpers.tax_category_elements(xml, tax_category_code, tax_rate)
          end

          # Line item total
          xml["ram"].SpecifiedTradeSettlementLineMonetarySummation do
            ElectronicInvoice::Helpers.currency_element(xml, "ram", "LineTotalAmount", line_total, currency_code)
          end
        end
      end
    end

    private

    def validate_net_total
      return if net.blank? || qty.blank? || net_total.blank?

      if (ElectronicInvoice::Helpers.cents(net_total) - line_total).abs > 1
        errors.add(:net_total, :qty_mismatch, message: "does not match qty * net")
      end
    end
  end
end
