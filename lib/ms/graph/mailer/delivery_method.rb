# frozen_string_literal: true

module MsGraphMailer
  class DeliveryMethod
    include Dry::Monads[:result]

    # PidTagInReplyToId (0x1042) / PidTagInternetReferences (0x1039)
    IN_REPLY_TO_PROPERTY_ID = 'String 0x1042'
    REFERENCES_PROPERTY_ID = 'String 0x1039'

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
        attachments: build_attachments(mail),
        singleValueExtendedProperties: build_threading_properties(mail)
      }.tap do |msg|
        %i[toRecipients ccRecipients bccRecipients replyTo attachments singleValueExtendedProperties].each do |field|
          msg.delete(field) if msg[field].blank?
        end
      end
    end

    # Graph's sendMail only accepts x-* custom headers via
    # internetMessageHeaders, so the standard threading headers
    # (In-Reply-To/References) would silently get lost. Mapping them to their
    # MAPI extended properties makes Exchange emit them on the wire, keeping
    # replies threaded in the recipient's client.
    def build_threading_properties(mail)
      properties = []

      in_reply_to = format_message_ids(mail.in_reply_to)
      references = format_message_ids(mail.references)

      properties << { id: IN_REPLY_TO_PROPERTY_ID, value: in_reply_to } if in_reply_to
      properties << { id: REFERENCES_PROPERTY_ID, value: references } if references
      properties
    end

    # The mail gem parses message-id fields to bare ids (no angle brackets);
    # the RFC 5322 header format Exchange writes needs them re-added.
    def format_message_ids(ids)
      formatted = Array(ids).compact.map(&:to_s).reject(&:empty?).map do |id|
        id.start_with?('<') ? id : "<#{id}>"
      end
      return nil if formatted.empty?

      formatted.join(' ')
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
