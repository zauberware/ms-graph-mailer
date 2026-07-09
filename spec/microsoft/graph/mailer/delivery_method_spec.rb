# frozen_string_literal: true

require 'spec_helper'
require 'ms/graph/mailer'
require 'mail'

RSpec.describe MsGraphMailer::DeliveryMethod do
  subject(:delivery_method) { described_class.new({}) }

  let(:token_service) { instance_double(MsGraphMailer::TokenService) }
  let(:send_mail_endpoint) { 'https://graph.microsoft.com/v1.0/users/sender%40example.com/sendMail' }

  before do
    MsGraphMailer.configure do |config|
      config.tenant_id = 'tenant-id'
      config.client_id = 'client-id'
      config.client_secret = 'client-secret'
      config.logger = Logger.new(File::NULL)
    end

    allow(MsGraphMailer::TokenService).to receive(:new).and_return(token_service)
    allow(token_service).to receive(:call).and_return(Dry::Monads::Success('access-token'))

    stub_request(:post, send_mail_endpoint).to_return(status: 202, body: '')
  end

  def build_mail(headers = {})
    mail = Mail.new do
      from 'sender@example.com'
      to 'recipient@example.com'
      subject 'Re: Hello'
      body 'Hi there'
    end
    headers.each { |name, value| mail[name] = value }
    mail
  end

  def sent_message_payload
    payload = nil
    expect(WebMock).to(have_requested(:post, send_mail_endpoint).with do |request|
      payload = JSON.parse(request.body)['message']
      true
    end)
    payload
  end

  describe '#deliver! threading headers' do
    it 'transmits In-Reply-To and References as MAPI extended properties' do
      mail = build_mail('In-Reply-To' => '<parent@example.com>',
                        'References' => '<root@example.com> <parent@example.com>')

      delivery_method.deliver!(mail)

      properties = sent_message_payload['singleValueExtendedProperties']
      expect(properties).to contain_exactly(
        { 'id' => 'String 0x1042', 'value' => '<parent@example.com>' },
        { 'id' => 'String 0x1039', 'value' => '<root@example.com> <parent@example.com>' }
      )
    end

    it 'wraps bare message ids in angle brackets' do
      mail = build_mail
      mail.in_reply_to = 'parent@example.com'

      delivery_method.deliver!(mail)

      properties = sent_message_payload['singleValueExtendedProperties']
      expect(properties).to contain_exactly(
        { 'id' => 'String 0x1042', 'value' => '<parent@example.com>' }
      )
    end

    it 'omits the extended properties when no threading headers are present' do
      delivery_method.deliver!(build_mail)

      expect(sent_message_payload).not_to have_key('singleValueExtendedProperties')
    end
  end

  describe '#deliver! basic payload' do
    it 'sends subject, body and recipients' do
      delivery_method.deliver!(build_mail)

      payload = sent_message_payload
      expect(payload['subject']).to eq('Re: Hello')
      expect(payload['body']).to include('content' => 'Hi there')
      expect(payload['toRecipients']).to eq([{ 'emailAddress' => { 'address' => 'recipient@example.com' } }])
    end
  end
end
