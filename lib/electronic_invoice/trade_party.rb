# frozen_string_literal: true

module ElectronicInvoice
  class TradeParty
    include ActiveModel::Model

    attr_accessor :reference, :name, :email, :street, :number, :addition, :zip_code, :town, :country_code, :vat_id,
      :tax_id, :registration_number, :electronic_invoicing_identifier

    validates :name, :street, :number, :zip_code, :town, :country_code, presence: true

    def to_xml(xml)
      # Buyer number
      xml["ram"].ID reference if reference
      # Name
      xml["ram"].Name name

      # Email
      if email
        xml["ram"].DefinedTradeContact do
          xml["ram"].EmailURIUniversalCommunication do
            xml["ram"].URIID email
          end
        end
      end

      # Address
      xml["ram"].PostalTradeAddress do
        xml["ram"].PostcodeCode zip_code
        xml["ram"].LineOne "#{street} #{number}"
        xml["ram"].LineTwo addition if addition
        xml["ram"].CityName town
        xml["ram"].CountryID country_code
      end

      # Tax number
      if tax_id
        xml["ram"].SpecifiedTaxRegistration do
          xml["ram"].ID(schemeID: "FC") do
            xml.text(tax_id)
          end
        end
      end

      # VAT ID
      if vat_id
        xml["ram"].SpecifiedTaxRegistration do
          xml["ram"].ID(schemeID: "VA") do
            xml.text(vat_id.upcase)
          end
        end
      end
    end
  end
end
