# frozen_string_literal: true

module MsGraphMailer
  class DeliveryMethod
    include Dry::Monads[:result]

    attr_reader :settings

    # INFO: settings is passed from config.action_mailer.<environment>
    def initialize(settings)
      @settings = settings
      validate_configuration!
    end

    def deliver!(mail)
      sender_email = extract_sender_email(mail)
      raise DeliveryError, 'No sender email (From) specified in the email.' if sender_email.blank?

      token_result = TokenService.new.call

      if token_result.failure?
        logger.error("Failed to get Graph token: #{token_result.failure}")
        raise AuthenticationError, "Unable to authenticate with Microsoft Graph: #{token_result.failure}"
      end

      message_payload = {
        message: build_message_payload(mail, sender_email),
        saveToSentItems: true
      }

      # Sent with the request and echoed back by Graph, so a failure can be
      # traced with Microsoft even when no response arrives (timeouts).
      client_request_id = SecureRandom.uuid

      response = connection(token_result.value!).post("users/#{CGI.escape(sender_email)}/sendMail") do |req|
        req.headers['Content-Type'] = 'application/json'
        req.headers['client-request-id'] = client_request_id
        req.headers['return-client-request-id'] = 'true'
        req.body = message_payload.to_json
      end

      raise build_delivery_error(response, client_request_id) unless response.status == 202

      logger.info('[MsGraphMailer] Email sent successfully via Microsoft Graph ' \
                  "[request-id: #{response.headers['request-id']}] [client-request-id: #{client_request_id}]")
      response
    rescue Faraday::Error => e
      logger.error("[MsGraphMailer] Network error: #{e.message} [client-request-id: #{client_request_id}]")
      raise DeliveryError.new("Network error sending email: #{e.message}",
                              client_request_id: client_request_id, network_error: true)
    end

    private

    def build_delivery_error(response, client_request_id)
      error = parse_error_body(response.body)
      request_id = response.headers['request-id']
      retry_after = DeliveryError.parse_retry_after(response.headers['Retry-After'])

      logger.error("[MsGraphMailer] sendMail failed: [status: #{response.status}] [code: #{error['code']}] " \
                   "[request-id: #{request_id}] [client-request-id: #{client_request_id}] " \
                   "[retry-after: #{retry_after.inspect}] - [body: #{response.body}]")

      DeliveryError.new(
        "Microsoft Graph sendEmail failed with status #{response.status}: #{error['message'] || 'Unknown error'}",
        status: response.status,
        code: error['code'],
        retry_after: retry_after,
        request_id: request_id,
        client_request_id: client_request_id
      )
    end

    def parse_error_body(body)
      parsed = JSON.parse(body.to_s)
      parsed.is_a?(Hash) && parsed['error'].is_a?(Hash) ? parsed['error'] : {}
    rescue JSON::ParserError
      {}
    end

    def validate_configuration!
      config = MsGraphMailer.configuration
      return if config&.valid?

      raise ConfigurationError,
            'MsGraphMailer is not properly configured. Please configure tenant_id, client_id, and client_secret.'
    end

    def extract_sender_email(mail)
      Array(mail.from).first.to_s.strip
    end

    def build_message_payload(mail, sender_email)
      {
        subject: mail.subject.to_s,
        body: build_body(mail),
        from: {
          emailAddress: { address: sender_email }
        },
        toRecipients: build_recipients(mail.to),
        ccRecipients: build_recipients(mail.cc),
        bccRecipients: build_recipients(mail.bcc),
        replyTo: build_recipients(mail.reply_to),
        attachments: build_attachments(mail)
      }.tap do |msg|
        %i[toRecipients ccRecipients bccRecipients replyTo attachments].each do |field|
          msg.delete(field) if msg[field].blank?
        end
      end
    end

    def build_body(mail)
      if mail.multipart?
        html_part = mail.html_part
        text_part = mail.text_part

        if html_part
          {
            contentType: 'HTML',
            content: html_part.body.decoded
          }
        elsif text_part
          {
            contentType: 'Text',
            content: text_part.body.decoded
          }
        else
          {
            contentType: 'Text',
            content: ''
          }
        end
      else
        {
          contentType: mail.content_type&.start_with?('text/html') ? 'HTML' : 'Text',
          content: mail.body.decoded
        }
      end
    end

    def build_recipients(addresses)
      Array(addresses).reject(&:blank?).map do |address|
        { emailAddress: { address: address.to_s.strip } }
      end
    end

    def build_attachments(mail)
      mail.attachments.map do |attachment|
        {
          '@odata.type': '#microsoft.graph.fileAttachment',
          name: attachment.filename.to_s,
          contentType: attachment.mime_type.to_s,
          contentBytes: Base64.strict_encode64(attachment.body.decoded)
        }
      end
    end

    def connection(access_token)
      @connection ||= Faraday.new(url: 'https://graph.microsoft.com/v1.0/') do |f|
        f.headers['Authorization'] = "Bearer #{access_token}"
        f.options.open_timeout = MsGraphMailer.configuration&.open_timeout
        f.options.timeout = MsGraphMailer.configuration&.timeout
        f.adapter Faraday.default_adapter
        # SSL verification configuration
        f.ssl.verify = ssl_verify?
      end
    end

    def ssl_verify?
      # Allow disabling SSL verification via settings
      settings[:ssl_verify].nil? || settings[:ssl_verify]
    end

    def logger
      MsGraphMailer.configuration&.logger || Logger.new($stdout)
    end
  end
end
