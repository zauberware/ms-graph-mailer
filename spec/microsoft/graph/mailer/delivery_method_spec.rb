# frozen_string_literal: true

require 'spec_helper'
require 'ms/graph/mailer'

RSpec.describe MsGraphMailer::DeliveryMethod do
  subject(:delivery_method) { described_class.new({}) }

  let(:send_url) { 'https://graph.microsoft.com/v1.0/users/sender%40example.com/sendMail' }
  let(:mail) do
    Mail.new do
      from 'sender@example.com'
      to 'recipient@example.com'
      subject 'Hello'
      body 'Body'
    end
  end
  let(:logger) { instance_double(Logger, info: nil, error: nil) }

  before do
    MsGraphMailer.configure do |config|
      config.tenant_id = 'tenant'
      config.client_id = 'client'
      config.client_secret = 'secret'
      config.logger = logger
    end
    token_service = instance_double(MsGraphMailer::TokenService, call: Dry::Monads::Success('token'))
    allow(MsGraphMailer::TokenService).to receive(:new).and_return(token_service)
  end

  def capture_error
    delivery_method.deliver!(mail)
    raise 'expected DeliveryError'
  rescue MsGraphMailer::DeliveryError => e
    e
  end

  context 'when Graph accepts the message' do
    before { stub_request(:post, send_url).to_return(status: 202, headers: { 'request-id' => 'req-1' }) }

    it 'sends a client-request-id with the request' do
      delivery_method.deliver!(mail)

      expect(
        a_request(:post, send_url).with(headers: { 'client-request-id' => /\A[0-9a-f-]{36}\z/,
                                                   'return-client-request-id' => 'true' })
      ).to have_been_made.once
    end
  end

  context 'when Graph throttles with CommandConcurrencyLimitReached' do
    before do
      stub_request(:post, send_url).to_return(
        status: 503,
        headers: { 'request-id' => 'req-503', 'Retry-After' => '7' },
        body: { error: { code: 'CommandConcurrencyLimitReached',
                         message: 'Command Concurrency Limit Reached' } }.to_json
      )
    end

    it 'raises a throttled DeliveryError with the response details' do
      error = capture_error

      expect(error).to have_attributes(
        message: 'Microsoft Graph sendEmail failed with status 503: Command Concurrency Limit Reached',
        status: 503,
        code: 'CommandConcurrencyLimitReached',
        retry_after: 7,
        request_id: 'req-503',
        client_request_id: be_present
      )
      expect(error).to be_throttled
      expect(error).not_to be_outcome_unknown
    end
  end

  context 'when Graph throttles with 429 and no body' do
    before { stub_request(:post, send_url).to_return(status: 429, body: '') }

    it 'is throttled and keeps the legacy message' do
      error = capture_error

      expect(error.message).to eq('Microsoft Graph sendEmail failed with status 429: Unknown error')
      expect(error).to be_throttled
      expect(error.retry_after).to be_nil
    end
  end

  context 'when the gateway times out' do
    before { stub_request(:post, send_url).to_return(status: 504, body: '') }

    it 'reports an unknown outcome and is not throttled' do
      error = capture_error

      expect(error).to be_outcome_unknown
      expect(error).not_to be_throttled
    end
  end

  context 'when the recipient is invalid' do
    before do
      stub_request(:post, send_url).to_return(
        status: 400,
        body: { error: { code: 'ErrorInvalidRecipients', message: 'At least one recipient is not valid.' } }.to_json
      )
    end

    it 'is neither throttled nor of unknown outcome' do
      error = capture_error

      expect(error.code).to eq('ErrorInvalidRecipients')
      expect(error).not_to be_throttled
      expect(error).not_to be_outcome_unknown
    end
  end

  context 'when the request times out' do
    before { stub_request(:post, send_url).to_timeout }

    it 'raises a DeliveryError with an unknown outcome' do
      error = capture_error

      expect(error.message).to start_with('Network error sending email:')
      expect(error).to be_outcome_unknown
      expect(error).not_to be_throttled
      expect(error.client_request_id).to be_present
    end
  end
end

RSpec.describe MsGraphMailer::DeliveryError do
  describe '.parse_retry_after' do
    let(:now) { Time.utc(2026, 11, 6, 12, 0, 0) }

    it 'parses delta-seconds' do
      expect(described_class.parse_retry_after('30', now: now)).to eq(30)
    end

    it 'parses an HTTP date' do
      expect(described_class.parse_retry_after('Fri, 06 Nov 2026 12:00:45 GMT', now: now)).to eq(45)
    end

    it 'never returns a negative delay' do
      expect(described_class.parse_retry_after('Fri, 06 Nov 2026 11:59:00 GMT', now: now)).to eq(0)
    end

    it 'returns nil for blank or garbage values' do
      expect(described_class.parse_retry_after(nil, now: now)).to be_nil
      expect(described_class.parse_retry_after('soon', now: now)).to be_nil
    end
  end
end
