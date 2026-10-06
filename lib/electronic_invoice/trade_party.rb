# frozen_string_literal: true

module ElectronicInvoice
  class TradeParty
    include ActiveModel::Model

    attr_accessor :reference, :name, :email, :contact_name, :phone, :electronic_address, :street, :number, :addition,
      :zip_code, :town, :country_code, :vat_id, :tax_id, :registration_number, :electronic_invoicing_identifier

    validates :name, :street, :number, :zip_code, :town, :country_code, presence: true
    validates :country_code, inclusion: { in: COUNTRY_CODES, message: "is not a valid ISO 3166-1 country code" },
      allow_blank: true

    # role: :seller, :buyer or :ship_to (the ship to party only carries id, name and address)
    # include_vat_id: false omits the VAT ID, which must not be given for invoices not subject to VAT (BR-O-02)
    def to_xml(xml, role: :seller, include_vat_id: true)
      # Buyer number
      xml["ram"].ID reference if reference.present?
      # Name
      xml["ram"].Name name

      # Legal registration, e.g. commercial register number (BT-30, BT-47)
      if registration_number.present? && role != :ship_to
        xml["ram"].SpecifiedLegalOrganization do
          xml["ram"].ID registration_number
        end
      end

      # Contact
      if role != :ship_to && [contact_name, phone, email].any?(&:present?)
        xml["ram"].DefinedTradeContact do
          xml["ram"].PersonName contact_name if contact_name.present?

          if phone.present?
            xml["ram"].TelephoneUniversalCommunication do
              xml["ram"].CompleteNumber phone
            end
          end

          if email.present?
            xml["ram"].EmailURIUniversalCommunication do
              xml["ram"].URIID email
            end
          end
        end
      end

      # Address
      xml["ram"].PostalTradeAddress do
        xml["ram"].PostcodeCode zip_code
        xml["ram"].LineOne "#{street} #{number}"
        xml["ram"].LineTwo addition if addition.present?
        xml["ram"].CityName town
        xml["ram"].CountryID country_code
      end

      return if role == :ship_to

      # Electronic address
      if electronic_address.present?
        xml["ram"].URIUniversalCommunication do
          xml["ram"].URIID(schemeID: "EM") do
            xml.text(electronic_address)
          end
        end
      end

      # Tax number (only defined for the seller)
      if tax_id.present? && role == :seller
        xml["ram"].SpecifiedTaxRegistration do
          xml["ram"].ID(schemeID: "FC") do
            xml.text(tax_id)
          end
        end
      end

      # VAT ID
      if vat_id.present? && include_vat_id
        xml["ram"].SpecifiedTaxRegistration do
          xml["ram"].ID(schemeID: "VA") do
            xml.text(vat_id.upcase)
          end
        end
      end
    end
  end
end
