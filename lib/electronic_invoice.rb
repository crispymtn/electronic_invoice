# frozen_string_literal: true

require "bigdecimal"
require "bigdecimal/util"
require "date"
require "pathname"
require "stringio"
require "nokogiri"
require "pdf-reader"
require "active_model"
require_relative "electronic_invoice/version"
require_relative "electronic_invoice/constants"
require_relative "electronic_invoice/code_lists"
require_relative "electronic_invoice/helpers"
require_relative "electronic_invoice/taxable"
require_relative "electronic_invoice/invoice"
require_relative "electronic_invoice/trade_party"
require_relative "electronic_invoice/line_item"
require_relative "electronic_invoice/charge"

module ElectronicInvoice
  class Error < StandardError; end

  # The document could not be read, e.g. malformed XML or a missing mandatory element
  class ParseError < Error; end

  # The document is no CII or UBL invoice, e.g. ZUGFeRD 1.0
  class UnsupportedFormatError < Error; end

  # The PDF does not contain an embedded invoice XML
  class NoInvoiceFoundError < Error; end
end

require_relative "electronic_invoice/received/party"
require_relative "electronic_invoice/received/line_item"
require_relative "electronic_invoice/received/allowance_charge"
require_relative "electronic_invoice/received/tax_breakdown"
require_relative "electronic_invoice/received/payment_means"
require_relative "electronic_invoice/received/payment_terms"
require_relative "electronic_invoice/received/totals"
require_relative "electronic_invoice/received/invoice"
require_relative "electronic_invoice/reader/pdf_extractor"
require_relative "electronic_invoice/reader/parser"
require_relative "electronic_invoice/reader/cii_parser"
require_relative "electronic_invoice/reader/ubl_parser"
require_relative "electronic_invoice/reader"
