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

  TAX_EXEMPTION_REASONS = {
    REVERSECHARGE: "Reverse Charge",
    INTRACOMMUNITY: "Intra-community transaction",
    EXPORT: "Export outside the EU"
  }

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
    BOTTLE: "BO",
    CARTON: "CT",
    CAN: "CA"
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
end
