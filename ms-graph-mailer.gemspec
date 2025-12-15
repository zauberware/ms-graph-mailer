# frozen_string_literal: true

require_relative 'lib/ms/graph/mailer/version'

Gem::Specification.new do |spec|
  spec.name = 'ms-graph-mailer'
  spec.version = MsGraphMailer::VERSION
  spec.authors = ['Zauberware Technologies GmbH']
  spec.email = ['tech@zauberware.com']

  spec.summary = 'ActionMailer delivery method for Microsoft Graph API'
  spec.description = 'A custom delivery method for ActionMailer that sends emails ' \
                     'via Microsoft Graph API using OAuth 2.0 client credentials flow'
  spec.homepage = 'https://github.com/zauberware/ms-graph-mailer'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.glob('{lib}/**/*') + %w[README.md LICENSE.txt CHANGELOG.md]
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'actionmailer', '>= 6.0'
  spec.add_dependency 'activesupport', '>= 6.0'
  spec.add_dependency 'dry-monads', '~> 1.0'
  spec.add_dependency 'faraday', '~> 2.0'

  # Development dependencies
  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 1.0'
  spec.add_development_dependency 'rubocop-rake', '~> 0.6'
  spec.add_development_dependency 'rubocop-rspec', '~> 2.0'
  spec.add_development_dependency 'webmock', '~> 3.0'
end
