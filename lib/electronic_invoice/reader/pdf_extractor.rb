# frozen_string_literal: true

module ElectronicInvoice
  module Reader
    # Extracts the invoice XML embedded in a ZUGFeRD / Factur-X PDF (PDF/A-3)
    class PdfExtractor
      # Limits the depth of the embedded files name tree, protects against reference loops
      MAX_NAME_TREE_DEPTH = 32

      def self.extract(data)
        new(data).extract
      end

      def initialize(data)
        @data = data
      end

      def extract
        files = embedded_files

        file = files.find { |name, _| EMBEDDED_XML_FILENAMES.any? { name.casecmp?(_1) } } ||
          files.find { |name, content| name.downcase.end_with?(".xml") && content.match?(/CrossIndustryInvoice|ubl:schema:xsd:(Invoice|CreditNote)-2/) }

        unless file
          names = files.map(&:first)
          raise NoInvoiceFoundError, "The PDF contains no e-invoice XML" +
            (names.any? ? " (embedded files: #{names.join(", ")})" : "")
        end

        file.last
      rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError, PDF::Reader::EncryptedPDFError => e
        raise ParseError, "The PDF could not be read: #{e.message}"
      end

      private

      def objects
        @objects ||= PDF::Reader.new(StringIO.new(@data)).objects
      end

      # [[name, content]] of the files in the EmbeddedFiles name tree and the associated files (AF) of the catalog
      def embedded_files
        catalog = deref(objects.trailer[:Root])
        return [] unless catalog.is_a?(Hash)

        specs = []
        names = deref(catalog[:Names])
        collect_name_tree(deref(names[:EmbeddedFiles]), specs) if names.is_a?(Hash)
        specs.concat(Array(deref(catalog[:AF])).map { deref(_1) })

        specs.filter_map { file_from_spec(_1) }.uniq(&:first)
      end

      def collect_name_tree(node, specs, depth = 0)
        return unless node.is_a?(Hash) && depth < MAX_NAME_TREE_DEPTH

        Array(deref(node[:Names])).each_slice(2) { |_, spec| specs << deref(spec) }
        Array(deref(node[:Kids])).each { collect_name_tree(deref(_1), specs, depth + 1) }
      end

      def file_from_spec(spec)
        return unless spec.is_a?(Hash)

        ef = deref(spec[:EF])
        stream = deref(ef[:UF] || ef[:F]) if ef.is_a?(Hash)
        return unless stream.is_a?(PDF::Reader::Stream)

        [pdf_string(deref(spec[:UF] || spec[:F])), stream.unfiltered_data]
      end

      # PDF text strings are PDFDocEncoding or UTF-16BE with byte order mark
      def pdf_string(value)
        string = value.to_s.b
        if string.start_with?("\xFE\xFF".b)
          string[2..].force_encoding("UTF-16BE").encode("UTF-8", invalid: :replace, undef: :replace)
        else
          string.force_encoding("UTF-8").scrub
        end
      end

      def deref(value)
        objects.deref(value)
      end
    end
  end
end
