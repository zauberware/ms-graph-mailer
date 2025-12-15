# frozen_string_literal: true

module MsGraphMailer
  class TokenService
    include Dry::Monads[:result]

    def call
      fetch_token
    end

    private

    def cached_token
      logger.info('Checking for cached Microsoft Graph token...')
      token = Rails.cache.read('microsoft_graph_token')
      if token.present?
        logger.info('Found valid cached Microsoft Graph token.')
      else
        logger.info('No valid cached Microsoft Graph token found.')
      end
      token
    end

    def fetch_token
      validate_configuration!
      token = cached_token
      return Success(token) if token.present?

      scope = 'https://graph.microsoft.com/.default'

      logger.info("Attempting to fetch Microsoft Graph token for tenant: #{config.tenant_id}...")

      response = connection.post("#{config.tenant_id}/oauth2/v2.0/token") do |req|
        req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
        req.body = {
          client_id: config.client_id,
          client_secret: config.client_secret,
          grant_type: 'client_credentials',
          scope: scope
        }
      end

      logger.info("Graph token response status: #{response.status}")

      body = JSON.parse(response.body)

      if response.success? && body['access_token'].present?
        access_token = body['access_token']
        expires_in = body['expires_in'] || 3600 # Default to 1 hour
        Rails.cache.write('microsoft_graph_token', access_token, expires_in: expires_in - 300)

        logger.info("Successfully obtained and cached Graph token (expires in #{expires_in}s)")
        Success(access_token)
      else
        error_msg = body['error_description'] || body['error'] || 'Unknown error'
        logger.error("Failed to fetch Graph token - Status: #{response.status}, Error: #{error_msg}")
        logger.error("Full response body: #{body}")
        Failure("Failed to fetch Graph token: #{error_msg}")
      end
    rescue JSON::ParserError => e
      logger.error("JSON parse error for Graph token response: #{e.message}")
      logger.error("Response body: #{response&.body}")
      Failure("Invalid response format: #{e.message}")
    rescue Faraday::Error => e
      logger.error("Faraday error fetching Graph token: #{e.message}")
      Failure("Network error fetching Graph token: #{e.message}")
    rescue StandardError => e
      logger.error("Unexpected error fetching Graph token: #{e.message}")
      Failure("Unexpected error: #{e.message}")
    end

    def validate_configuration!
      return if config&.valid?

      raise ConfigurationError,
            'MsGraphMailer is not properly configured. Please configure tenant_id, client_id, and client_secret.'
    end

    def connection
      @connection ||= Faraday.new(url: 'https://login.microsoftonline.com') do |f|
        f.request :url_encoded
        f.adapter Faraday.default_adapter
        f.ssl.verify = ssl_verify?
      end
    end

    def ssl_verify?
      # Default to true in production environments
      return false if defined?(Rails) && Rails.env.development?

      true
    end

    def config
      MsGraphMailer.configuration
    end

    def logger
      config&.logger || Logger.new($stdout)
    end
  end
end
