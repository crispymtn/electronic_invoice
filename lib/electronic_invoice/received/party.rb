# frozen_string_literal: true

module ElectronicInvoice
  module Received
    # Seller, buyer, payee or delivery party of a received invoice
    #
    # ids: identifiers with their scheme (BT-29, BT-46, BT-60, BT-71), e.g. [{ id: "4000001123452", scheme: "0088" }],
    # the scheme is nil for identifiers without scheme
    Party = Struct.new(:name, :trading_name, :description, :ids, :vat_id, :tax_id, :registration_number,
      :electronic_address, :electronic_address_scheme, :contact_name, :phone, :email, :street, :line2, :line3,
      :zip_code, :town, :country_code, :subdivision, keyword_init: true)
  end
end
