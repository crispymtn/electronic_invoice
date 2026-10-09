# frozen_string_literal: true

module ElectronicInvoice
  # Reads received e-invoices: ZUGFeRD / Factur-X PDFs, CII XMLs (ZUGFeRD 2.x, Factur-X, XRechnung CII) and UBL XMLs
  # (XRechnung UBL, PEPPOL BIS)
  module Reader
    class << self
      # input: path, IO or String with the PDF or XML content
      def read(input)
        data = load(input)
        from_xml(pdf?(data) ? PdfExtractor.extract(data) : data)
      end

      def from_xml(xml)
        Parser.parse(load(xml))
      end

      # The invoice XML embedded in a ZUGFeRD / Factur-X PDF
      def extract_xml(pdf)
        data = load(pdf)
        raise ParseError, "The input is no PDF" unless pdf?(data)

        PdfExtractor.extract(data)
      end

      private

      def load(input)
        case input
        when Pathname then File.binread(input)
        when String then content?(input) ? input : File.binread(input)
        else
          raise ArgumentError, "Expected a path, IO or String, got #{input.class}" unless input.respond_to?(:read)

          input.binmode if input.respond_to?(:binmode)
          input.read
        end
      rescue Errno::ENOENT, Errno::EISDIR, Errno::EACCES => e
        raise Error, "The file could not be read: #{e.message}"
      end

      # XML or PDF content, a path otherwise
      def content?(string)
        pdf?(string) || string.b.lstrip.delete_prefix("\xEF\xBB\xBF".b).start_with?("<")
      end

      # The PDF header has to be within the first 1024 bytes
      def pdf?(data)
        data.byteslice(0, 1024).b.include?("%PDF-")
      end
    end
  end

  def self.read(input)
    Reader.read(input)
  end
end
