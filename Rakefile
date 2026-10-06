# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create

task default: :test

desc "Validate sample invoices with the KoSIT validator " \
  "(KOSIT_VALIDATOR=validator-standalone.jar KOSIT_CONFIG=xrechnung-validator-configuration-dir [JAVA=java])"
task :validate do
  jar = ENV.fetch("KOSIT_VALIDATOR") { abort "Set KOSIT_VALIDATOR to the KoSIT validator standalone jar" }
  config = ENV.fetch("KOSIT_CONFIG") { abort "Set KOSIT_CONFIG to the unpacked XRechnung validator configuration" }
  out = File.expand_path("tmp/validation", __dir__)

  ruby "-Ilib", "test/validation/scenarios.rb", out
  sh ENV.fetch("JAVA", "java"), "-jar", File.expand_path(jar), "-s", File.join(config, "scenarios.xml"), "-r", config,
    "-o", File.join(out, "reports"), *Dir["#{out}/*.xml"].sort
end
