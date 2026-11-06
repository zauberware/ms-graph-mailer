# frozen_string_literal: true

require 'time'

module MsGraphMailer
  class Error < StandardError; end
  class AuthenticationError < Error; end
  class ConfigurationError < Error; end

  # Raised when Microsoft Graph does not accept a sendMail request.
  #
  # Besides the message (kept stable for callers that persist or match it),
  # the error exposes the response details a caller needs to decide whether a
  # retry is safe:
  #
  # - throttled?        Graph rejected the request (429, or 503 such as
  #                     "CommandConcurrencyLimitReached"). Nothing was sent;
  #                     retry after #retry_after seconds.
  # - outcome_unknown?  Gateway errors and network failures/timeouts. The
  #                     mail may or may not have been sent — retrying blindly
  #                     risks a duplicate.
  class DeliveryError < Error
    THROTTLED_STATUSES = [429, 503].freeze

    attr_reader :status, :code, :retry_after, :request_id, :client_request_id

    def initialize(message = nil, status: nil, code: nil, retry_after: nil, request_id: nil, # rubocop:disable Metrics/ParameterLists
                   client_request_id: nil, network_error: false)
      super(message)
      @status = status
      @code = code
      @retry_after = retry_after
      @request_id = request_id
      @client_request_id = client_request_id
      @network_error = network_error
    end

    def throttled?
      THROTTLED_STATUSES.include?(status)
    end

    def outcome_unknown?
      return true if @network_error
      return false if status.nil? || throttled?

      status >= 500
    end

    # Retry-After is either delta-seconds or an HTTP date (RFC 9110 §10.2.3).
    # Returns whole seconds, or nil when the header is absent or unparsable.
    def self.parse_retry_after(value, now: Time.now)
      return nil if value.nil? || value.to_s.strip.empty?

      raw = value.to_s.strip
      return raw.to_i if raw.match?(/\A\d+\z/)

      [(Time.httpdate(raw) - now).ceil, 0].max
    rescue ArgumentError
      nil
    end
  end
end
