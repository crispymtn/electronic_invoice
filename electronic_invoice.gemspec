# frozen_string_literal: true

require_relative "lib/electronic_invoice/version"

Gem::Specification.new do |spec|
  spec.name = "electronic_invoice"
  spec.version = ElectronicInvoice::VERSION
  spec.authors = ["Sascha Weidlich"]
  spec.email = ["sascha.weidlich@mac.com"]

  spec.summary = "Generate ZUGFeRD-compliant electronic invoices"
  spec.description = "A Ruby gem to generate XML invoices following the ZUGFeRD standard"
  spec.homepage = "https://github.com/crispymtn/electronic_invoice"
  spec.required_ruby_version = ">= 3.1.0"

  # Not published to a gem server, the gem is used via git. The invalid host prevents an accidental `rake release`.
  spec.metadata["allowed_push_host"] = "https://gems.invalid"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "nokogiri"
  spec.add_dependency "activemodel", "~> 8.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
