# frozen_string_literal: true

require 'action_mailer'
require 'faraday'
require 'dry/monads'
require 'json'
require 'base64'
require 'cgi'
require 'securerandom'

require_relative 'mailer/version'
require_relative 'mailer/errors'
require_relative 'mailer/token_service'
require_relative 'mailer/delivery_method'

module MsGraphMailer
  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration)
    end
  end

  class Configuration
    # open_timeout / timeout (seconds) apply to the sendMail request. nil keeps
    # the HTTP adapter's defaults.
    attr_accessor :tenant_id, :client_id, :client_secret, :logger, :open_timeout, :timeout

    def initialize
      @tenant_id = nil
      @client_id = nil
      @client_secret = nil
      @logger = nil
      @open_timeout = nil
      @timeout = nil
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
