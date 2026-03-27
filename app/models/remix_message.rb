class RemixMessage < ActiveRecord::Base
  belongs_to :remix, class_name: 'RemixConversation', foreign_key: 'remix_id'

  validates :role, presence: true, inclusion: { in: %w[user assistant system tool] }

  def to_api_format
    case role
    when 'tool'
      { role: 'tool', tool_call_id: tool_call_id, content: content.to_s }
    when 'assistant'
      msg = { role: 'assistant', content: content }
      if tool_calls.present?
        # Defensive: ensure tool_calls is an Array (JSON column should handle
        # this, but some adapters may return a String)
        tc = tool_calls
        tc = JSON.parse(tc) if tc.is_a?(String)
        msg[:tool_calls] = tc
      end
      msg
    else
      { role: role, content: content }
    end
  end
end
