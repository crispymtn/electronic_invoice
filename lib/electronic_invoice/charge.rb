# frozen_string_literal: true

module ElectronicInvoice
  # Document level charge (BG-21), e.g. freight or packaging. Amounts are given in cents.
  class Charge
    include ActiveModel::Model
    include ElectronicInvoice::Taxable

    # reason_code: UNTDID 7161 code (e.g. "FC" for freight), tax: optional, calculated from amount and tax_rate otherwise
    attr_accessor :amount, :reason, :reason_code, :tax_rate, :tax_category, :tax

    validates :amount, :tax_rate, :tax_category, presence: true
    validates :reason, presence: true, if: -> { reason_code.blank? }

    def amount_cents
      ElectronicInvoice::Helpers.cents(amount)
    end

    def tax_amount
      tax.nil? ? amount.to_d * tax_rate.to_d : tax.to_d
    end

    def to_xml(xml, currency_code)
      xml["ram"].SpecifiedTradeAllowanceCharge do
        xml["ram"].ChargeIndicator do
          xml["udt"].Indicator "true"
        end

        ElectronicInvoice::Helpers.currency_element(xml, "ram", "ActualAmount", amount_cents, currency_code)
        xml["ram"].ReasonCode reason_code if reason_code.present?
        xml["ram"].Reason reason if reason.present?

        xml["ram"].CategoryTradeTax do
          ElectronicInvoice::Helpers.tax_category_elements(xml, tax_category_code, tax_rate)
        end
      end
    end
  end
end
