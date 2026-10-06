# frozen_string_literal: true

module ElectronicInvoice
  module Helpers
    class << self
      def format_value(value, digits: 2)
        format("%0.#{digits}f", value.to_d.round(digits))
      end

      def currency_element(xml, namespace, name, amount, currency, add_currency: false, digits: 2)
        attrs = {}

        if add_currency
          attrs[:currencyID] = currency
        end

        xml[namespace].send(name, attrs) do
          xml.text(format_value(amount.to_d / 100, digits: digits))
        end
      end

      # Amounts are given in cents, rounded to whole cents
      def cents(amount)
        amount.to_d.round
      end

      # TypeCode, CategoryCode and RateApplicablePercent of a VAT category (BG-30, BG-21/BG-20 tax)
      def tax_category_elements(xml, category_code, tax_rate)
        xml["ram"].TypeCode "VAT"
        xml["ram"].CategoryCode category_code

        unless RATELESS_TAX_CATEGORY_CODES.include?(category_code)
          xml["ram"].RateApplicablePercent format_value(tax_rate.to_d * 100)
        end
      end

      def normalize_iban(iban)
        iban.to_s.delete(" ").upcase
      end

      # ISO 13616 checksum
      def valid_iban?(iban)
        iban = normalize_iban(iban)
        return false unless iban.match?(/\A[A-Z]{2}\d{2}[A-Z0-9]{11,30}\z/)

        (iban[4..] + iban[0, 4]).gsub(/[A-Z]/) { (_1.ord - 55).to_s }.to_i % 97 == 1
      end
    end
  end
end
