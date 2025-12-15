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

      response = connection(token_result.value!).post("users/#{CGI.escape(sender_email)}/sendMail") do |req|
        req.headers['Content-Type'] = 'application/json'
        req.body = message_payload.to_json
      end

      unless response.status == 202
        error_body = begin
          JSON.parse(response.body)
        rescue StandardError
          {}
        end
        error_msg = error_body.dig('error', 'message') || 'Unknown error'
        logger.error("[MsGraphMailer] sendMail failed: [status: #{response.status}] - [body: #{response.body}]")
        raise DeliveryError, "Microsoft Graph sendEmail failed with status #{response.status}: #{error_msg}"
      end

      logger.info('[MsGraphMailer] Email sent successfully via Microsoft Graph')
      response
    rescue Faraday::Error => e
      logger.error("[MsGraphMailer] Network error: #{e.message}")
      raise DeliveryError, "Network error sending email: #{e.message}"
    end

    private

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
