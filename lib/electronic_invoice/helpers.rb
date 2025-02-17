# frozen_string_literal: true

module ElectronicInvoice
  module Helpers
    class << self
      def format_value(value, digits: 2)
        format("%0.#{digits}f", value.to_d)
      end

      def currency_element(xml, namespace, name, amount, currency, add_currency: false, digits: 2)
        attrs = {}

        if add_currency
          attrs[:currencyID] = currency
        end

        xml[namespace].send(name, attrs) do
          xml.text(format("%0.#{digits}f", amount.to_d / 100))
        end
      end
    end
  end
end
