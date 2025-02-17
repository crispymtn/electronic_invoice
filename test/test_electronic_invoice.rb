# frozen_string_literal: true

require "test_helper"

class TestElectronicInvoice < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::ElectronicInvoice::VERSION
  end
end
