# frozen_string_literal: true

module ElectronicInvoice
  TAX_CATEGORY_CODES = {
    STANDARDRATE: "S",
    REVERSECHARGE: "AE",
    TAXEXEMPT: "E",
    ZERORATEDGOODS: "Z",
    UNTAXED: "O",
    INTRACOMMUNITY: "K",
    EXPORT: "G"
  }

  PAYMENT_CODES = {
    BANKACCOUNT: "42",
    CREDIT_TRANSFER: "30",
    NOTSPECIFIED: "1",
    AUTOMATICCLEARING: "3",
    CASH: "10",
    CHECK: "20",
    DEBITADVICE: "31",
    CREDITCARD: "48",
    DEBIT: "49",
    SEPA_CREDIT: "58",
    SEPA_DEBIT: "59",
    COMPENSATION: "97"
  }

  CREDIT_TRANSFER_PAYMENT_CODES = %w[30 58]
  CARD_PAYMENT_CODES = %w[48 54 55]
  DIRECT_DEBIT_PAYMENT_CODES = %w[59]

  # Default exemption reasons and VATEX codes per tax category code (BR-AE-10, BR-E-10, BR-G-10, BR-IC-10, BR-O-10)
  TAX_EXEMPTION_REASONS = {
    "AE" => { reason: "Reverse Charge", code: "VATEX-EU-AE" },
    "E" => { reason: "Tax exempt" },
    "K" => { reason: "Intra-community transaction", code: "VATEX-EU-IC" },
    "G" => { reason: "Export outside the EU", code: "VATEX-EU-G" },
    "O" => { reason: "Not subject to VAT", code: "VATEX-EU-O" }
  }

  # Categories that must use a VAT rate of 0 (BR-Z-05, BR-E-05, BR-AE-05, BR-IC-05, BR-G-05)
  ZERO_RATE_TAX_CATEGORY_CODES = %w[Z E AE K G]

  # Categories that must not carry a VAT rate at all (BR-O-05)
  RATELESS_TAX_CATEGORY_CODES = %w[O]

  GUIDELINES = {
    zugferd: "urn:cen.eu:en16931:2017",
    xrechnung: "urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0"
  }

  # Namespaces of the UN/CEFACT Cross Industry Invoice (D16B)
  CII_NAMESPACES = {
    "rsm" => "urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100",
    "ram" => "urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100",
    "qdt" => "urn:un:unece:uncefact:data:standard:QualifiedDataType:100",
    "udt" => "urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100"
  }

  # Namespaces of UBL 2.1 invoices and credit notes
  UBL_NAMESPACES = {
    "Invoice" => "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2",
    "CreditNote" => "urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2",
    "cac" => "urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2",
    "cbc" => "urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2"
  }

  # Profiles by guideline (BT-24), checked in this order. Covers ZUGFeRD 2.x, Factur-X and XRechnung.
  PROFILE_PATTERNS = [
    [/xrechnung/i, :xrechnung],
    [/extended/i, :extended],
    [/basicwl/i, :basic_wl],
    [/minimum/i, :minimum],
    [/basic\z/i, :basic],
    [/\Aurn:cen\.eu:en16931:2017\z/, :en16931],
    # Other core invoice usage specifications (CIUS) of EN 16931
    [/\Aurn:cen\.eu:en16931:2017#compliant#/, :en16931]
  ]

  # Profiles that are e-invoices according to § 14 UStG (MINIMUM and BASIC WL do not cover EN 16931)
  E_INVOICE_PROFILES = %i[basic en16931 extended xrechnung]

  # Names of the invoice XML embedded in a ZUGFeRD / Factur-X PDF
  EMBEDDED_XML_FILENAMES = %w[factur-x.xml zugferd-invoice.xml xrechnung.xml]

  # Business process (BT-23) required by XRechnung (PEPPOL-EN16931-R001)
  XRECHNUNG_BUSINESS_PROCESS = "urn:fdc:peppol.eu:2017:poacc:billing:01:1.0"

  # Invoice type codes allowed by XRechnung (BR-DE-17)
  XRECHNUNG_TYPE_CODES = %w[326 380 384 389 381 875 876 877]

  UNIT_CODES = {
    ONE: "C62",
    PIECE: "H87",
    DAY: "DAY",
    HECTARE: "HAR",
    HOUR: "HUR",
    MONTH: "MON",
    KILOGRAM: "KGM",
    KILOMETER: "KMT",
    KILOWATTHOUR: "KWH",
    FIXEDRATE: "LS",
    LITRE: "LTR",
    MINUTE: "MIN",
    SQUAREMILLIMETER: "MMK",
    MILLIMETER: "MMT",
    SQUAREMETER: "MTK",
    CUBICMETER: "MTQ",
    METER: "MTR",
    PRODUCTCOUNT: "NAR",
    PRODUCTPAIR: "NPR",
    PERCENT: "P1",
    SET: "SET",
    TON: "TNE",
    WEEK: "WEE",
    BOTTLE: "XBO",
    CARTON: "XCT",
    CAN: "XCA",
    SHEET: "XST",
    REAM: "RM",
    ROLL: "XRO"
  }

  INVOICE_TYPES = {
    INVOICE: {
      code: "380",
      name: "Rechnung"
    },
    CREDIT_NOTE: {
      code: "381",
      name: "Gutschrift"
    },
    CORRECTION: {
      code: "384",
      name: "Korrekturrechnung"
    },
    PART_INVOICE: {
      code: "326",
      name: "Teilrechnung"
    },
    REVERSED_INVOICE: {
      code: "457",
      name: "Stornorechnung"
    }
  }

  class << self
    def tax_category_code(category)
      return if category.blank?

      key = category.to_s.upcase
      TAX_CATEGORY_CODES[key.to_sym] || (TAX_CATEGORY_CODES.value?(key) ? key : nil)
    end

    # A name of UNIT_CODES or any UN/ECE Rec 20/21 code, H87 (piece) otherwise
    def unit_code(unit)
      key = unit.to_s.upcase
      UNIT_CODES[key.to_sym] || (UNIT_CODE_LIST.include?(key) ? key : "H87")
    end
  end
end
