# frozen_string_literal: true

# Generates sample invoices covering the supported features as ZUGFeRD and XRechnung.
# Used by `rake validate` to check them with the KoSIT validator.
require "fileutils"
require "electronic_invoice"
require_relative "scenario_data"

OUT = ARGV.fetch(0)
FileUtils.mkdir_p(OUT)
Dir.glob("#{OUT}/*.xml").each { File.delete(_1) }

ValidationScenarios.each do |name, standard, invoice|
  File.write(File.join(OUT, "#{standard}-#{name}.xml"), invoice.to_xml)
rescue ElectronicInvoice::Error => e
  abort "#{standard}-#{name}: #{e.message}"
end
