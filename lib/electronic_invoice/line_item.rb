# frozen_string_literal: true

module ElectronicInvoice
  class LineItem
    include ActiveModel::Model

    attr_accessor :description, :qty, :unit, :net, :net_total, :gross_total, :tax_rate, :tax_category, :tax,
      :discount, :discounted_net_total, :discount_reason, :currency_code

    validates :description, :qty, :unit, :net, :net_total, :gross_total, :tax_rate, :tax_category, :tax,
      :currency_code, presence: true

    validates :discount_reason, presence: true, if: :discounted?

    def discounted?
      discount.to_d.positive?
    end

    def discount_amount
      net_total - discounted_net_total
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
          xml["ram"].BilledQuantity(unitCode: UNIT_CODES[unit.upcase.to_sym] || "H87" ) do
            xml.text(ElectronicInvoice::Helpers.format_value(net.negative? ? qty * -1 : qty, digits: 4))
          end
        end

        # Line item tax
        xml["ram"].SpecifiedLineTradeSettlement do
          xml["ram"].ApplicableTradeTax do
            xml["ram"].TypeCode "VAT"
            xml["ram"].CategoryCode TAX_CATEGORY_CODES[tax_category.upcase.to_sym] || "S"

            xml["ram"].RateApplicablePercent ElectronicInvoice::Helpers.format_value(tax_rate * 100)
          end

          # Line item total
          xml["ram"].SpecifiedTradeSettlementLineMonetarySummation do
            ElectronicInvoice::Helpers.currency_element(xml, "ram", "LineTotalAmount", net * qty, currency_code, digits: 2)
          end
        end
      end
    end
  end
end
