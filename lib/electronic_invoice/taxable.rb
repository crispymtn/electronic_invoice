# frozen_string_literal: true

module ElectronicInvoice
  # Shared tax category handling of line items and charges
  module Taxable
    extend ActiveSupport::Concern

    included do
      validate :validate_tax_category
    end

    def tax_category_code
      ElectronicInvoice.tax_category_code(tax_category)
    end

    # Key of the VAT breakdown (BG-23) this item belongs to
    def tax_key
      [tax_category_code, tax_rate.to_d]
    end

    private

    def validate_tax_category
      return if tax_category.blank?

      if tax_category_code.nil?
        errors.add(:tax_category, :unknown_tax_category, message: "is not a known tax category")
      elsif (ZERO_RATE_TAX_CATEGORY_CODES + RATELESS_TAX_CATEGORY_CODES).include?(tax_category_code) && tax_rate.to_d.nonzero?
        errors.add(:tax_rate, :must_be_zero, category: tax_category_code, message: "must be 0 for tax category %{category}")
      end
    end
  end
end
