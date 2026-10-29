# frozen_string_literal: true

require 'rspec-puppet'

fixture_path = File.expand_path(File.join(__FILE__, '..', 'fixtures'))

RSpec.configure do |c|
  c.module_path = File.join(fixture_path, 'modules')
  c.hiera_config = File.join(fixture_path, 'hiera.yaml')
  c.strict_variables = true
end
