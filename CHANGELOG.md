## [Unreleased]
## [2.1.1] - 2026-10-07
- Validate the delivery address only if `ship_to` is given, errors of the buyer were reported twice otherwise

## [2.1.0] - 2026-10-06
- Make the house number optional, it can also be part of the street
- Add keys to all custom error messages so applications can translate them (English defaults, no translations in the gem)
- Report errors of trade parties, line items and charges as "Line item 1: ..." on base

## [2.0.0] - 2026-10-06
Breaking: the totals are now calculated from the line items. Given `net_total` / `gross_total` and the `net_total` of the line items have to match, otherwise an error is raised.

- Add XRechnung 3.0 support (`standard: :xrechnung`) incl. validation of the BR-DE rules
- Add `contact_name`, `phone` and `electronic_address` to trade parties
- Take the tax categories from the line items and group taxes by category and rate
- Add exemption reason and VATEX code for non standard tax categories (reverse charge, exempt, export, intra-community, not subject to VAT)
- Omit the VAT rate for category O on line level and require a rate of 0 for zero rated categories
- Fix order of BillingSpecifiedPeriod and SpecifiedTradeAllowanceCharge
- Fix crash and wrong basis/percentage for document level discounts
- Fix unit codes for bottle, carton and can (XBO, XCT, XCA) and allow UN/ECE codes as unit
- Only output name and address for the ship to party, tax number only for the seller
- Validate currency, invoice type, payment type, seller tax registration and IBAN for SEPA credit transfers
- Include errors of trade parties and line items in the raised error message
- Calculate all totals from the line items and charges (BR-CO-10 - BR-CO-16)
- Add document level charges, prepaid amount, cash discounts (Skonto), SEPA direct debit, card payments and a separate delivery address
- Add the seller/buyer registration number (SpecifiedLegalOrganization)
- Add the business process for XRechnung (PEPPOL-EN16931-R001)
- Omit the VAT IDs for invoices not subject to VAT (BR-O-02) and do not allow mixing category O with others
- Validate IBAN checksums, country and currency codes
- Do not output empty elements
- Add `rake validate` to check sample invoices with the KoSIT validator
## [1.0.2] - 2025-04-07
- Fix rounding issue with taxes
## [1.0.1] - 2025-03-10
- Fix typo payment_information
- Fix order of PostalTradeAddress
- Include the IncludedNote for regulatory information only if it is available

## [1.0.0] - 2025-02-12

- Initial release
