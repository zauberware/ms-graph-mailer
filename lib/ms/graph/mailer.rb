# frozen_string_literal: true

require 'action_mailer'
require 'faraday'
require 'dry/monads'
require 'json'
require 'base64'
require 'cgi'

require_relative 'mailer/version'
require_relative 'mailer/token_service'
require_relative 'mailer/delivery_method'

module MsGraphMailer
  class Error < StandardError; end
  class AuthenticationError < Error; end
  class DeliveryError < Error; end
  class ConfigurationError < Error; end

  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration)
    end
  end

  class Configuration
    attr_accessor :tenant_id, :client_id, :client_secret, :logger

    def initialize
      @tenant_id = nil
      @client_id = nil
      @client_secret = nil
      @logger = nil
    end

    def valid?
      tenant_id.present? && client_id.present? && client_secret.present?
    end
  end
end

# Register the delivery method with ActionMailer
ActionMailer::Base.add_delivery_method(
  :microsoft_graph,
  MsGraphMailer::DeliveryMethod
)
