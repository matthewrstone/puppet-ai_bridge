# frozen_string_literal: true

source 'https://rubygems.org'

gem 'puppet', ENV.fetch('PUPPET_GEM_VERSION', '~> 8.0')
gem 'puppet-lint'
gem 'puppetlabs_spec_helper'
gem 'rspec-puppet'
gem 'metadata-json-lint', '~> 5.0'
gem 'bolt', '= 4.0.0' if ENV['BOLT_TESTS'] == 'true'
