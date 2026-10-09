# frozen_string_literal: true

module ElectronicInvoice
  module Reader
    # Base of the CII and UBL parsers, picks the parser by the root element of the XML
    class Parser
      def self.parse(xml)
        document = Nokogiri::XML(xml) { |config| config.strict.nonet }
        root = document.root
        raise ParseError, "The XML is empty" unless root

        parser_for(root).new(xml, document).parse
      rescue Nokogiri::XML::SyntaxError => e
        raise ParseError, "The XML could not be parsed: #{e.message}"
      end

      def self.parser_for(root)
        namespace = root.namespace&.href.to_s

        if root.name == "CrossIndustryInvoice" && namespace == CII_NAMESPACES["rsm"]
          CiiParser
        elsif UBL_NAMESPACES[root.name] && namespace == UBL_NAMESPACES[root.name]
          UblParser
        elsif root.name == "CrossIndustryDocument"
          raise UnsupportedFormatError, "ZUGFeRD 1.0 (CrossIndustryDocument) is not supported, it is no e-invoice according to EN 16931"
        else
          raise UnsupportedFormatError, "#{root.name} (#{namespace.presence || "no namespace"}) is no CII or UBL invoice"
        end
      end

      def initialize(xml, document)
        @xml = xml
        @document = document
      end

      private

      attr_reader :document

      def check_mandatory(invoice)
        missing = {
          "invoice number (BT-1)" => invoice.number,
          "issue date (BT-2)" => invoice.issue_date,
          "invoice type code (BT-3)" => invoice.type_code,
          "currency code (BT-5)" => invoice.currency_code,
          "seller name (BT-27)" => invoice.seller&.name,
          "buyer name (BT-44)" => invoice.buyer&.name,
          "grand total (BT-112)" => invoice.totals&.grand_total
        }.select { |_, value| value.nil? }.keys

        raise ParseError, "Missing mandatory elements: #{missing.join(", ")}" if missing.any?
      end

      def profile(guideline_id)
        return :unknown if guideline_id.nil?

        PROFILE_PATTERNS.find { |pattern, _| guideline_id.match?(pattern) }&.last || :unknown
      end

      def at(node, path)
        node&.at_xpath(path, self.class::NS)
      end

      def all(node, path)
        node ? node.xpath(path, self.class::NS).to_a : []
      end

      def text(node, path)
        at(node, path)&.text&.strip.presence
      end

      def decimal(node)
        value = node&.text&.strip
        return if value.blank?

        BigDecimal(value)
      rescue ArgumentError
        raise ParseError, "#{node.name} is not a valid number: #{value}"
      end
    end
  end
end
