require 'spec_helper'
require_relative '../../../../db/migrate/20131223032112_switch_to_json_serialization'

RSpec.describe 'SwitchToJsonSerialization migration security' do
  let(:migration) { SwitchToJsonSerialization.new }
  let(:connection) { ActiveRecord::Base.connection }

  before do
    allow(ActiveRecord::Base).to receive(:connection).and_return(connection)
  end

  # Security invariant: SQL queries must be constructed safely regardless of input
  it 'maintains SQL injection safety when quote_table_name receives adversarial inputs' do
    adversarial_payloads = [
      # Exact exploit case: SQL injection payload
      "events\") OR 1=1; --",
      # Boundary case: extreme length with special characters
      "a" * 1000 + "'\"\\;--",
      # Valid input (normal table name)
      "agents"
    ]

    adversarial_payloads.each do |payload|
      # The security property: quote_table_name must sanitize all inputs
      quoted = connection.quote_table_name(payload)
      
      # What must always be true: quoted output should not contain unescaped SQL syntax
      expect(quoted).not_to match(/\A\s*OR\s+1=1/i)
      expect(quoted).not_to match(/;\s*--/)
      expect(quoted).not_to include(payload) unless payload == "agents"  # Only valid input passes through unchanged
      
      # Additional safety check: quoted string should be wrapped in quotes or brackets
      expect(quoted).to satisfy { |q| q.start_with?('"') || q.start_with?('[') || q.start_with?('`') }
    end
  end
end