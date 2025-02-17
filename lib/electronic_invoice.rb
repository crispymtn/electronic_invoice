# frozen_string_literal: true

require "nokogiri"
require "active_model"
require_relative "electronic_invoice/version"
require_relative "electronic_invoice/constants"
require_relative "electronic_invoice/helpers"
require_relative "electronic_invoice/invoice"
require_relative "electronic_invoice/trade_party"
require_relative "electronic_invoice/line_item"

module ElectronicInvoice
  class Error < StandardError; end
end
