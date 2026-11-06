# frozen_string_literal: true

require 'spec_helper'
require 'ms/graph/mailer'

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
