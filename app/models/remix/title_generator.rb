module Remix
  class TitleGenerator
    include RemixOpenaiConcern

    MAX_TITLE_LENGTH = 60

    def initialize(remix_conversation)
      @remix = remix_conversation
    end

    # Returns a short title summarizing the conversation so far.
    # Only generates a title when the current title is still the default.
    def generate
      return nil unless should_generate?

      user_messages = @remix.messages
                            .where(role: 'user')
                            .order(:created_at)
                            .limit(3)
                            .pluck(:content)
                            .compact

      assistant_messages = @remix.messages
                                 .where(role: 'assistant')
                                 .order(:created_at)
                                 .limit(2)
                                 .pluck(:content)
                                 .compact

      return nil if user_messages.empty?

      prompt_messages = [
        {
          role: 'system',
          content: 'Generate a very short title (max 6 words) summarizing this conversation. ' \
                   'Reply with ONLY the title text, no quotes, no punctuation at the end.'
        },
        {
          role: 'user',
          content: build_summary(user_messages, assistant_messages)
        }
      ]

      begin
        response = openai_chat_completion(messages: prompt_messages)
        raw = response.dig('choices', 0, 'message', 'content').to_s.strip

        # Clean up: remove quotes, limit length
        title = raw.gsub(/\A["']|["']\z/, '').strip
        title = title[0, MAX_TITLE_LENGTH] if title.length > MAX_TITLE_LENGTH
        title = title.presence || "Conversation"

        @remix.update!(title: title)
        title
      rescue => e
        Rails.logger.warn("Remix title generation failed: #{e.message}")
        nil
      end
    end

    private

    def should_generate?
      @remix.title == 'New Conversation' &&
        @remix.messages.where(role: 'user').exists? &&
        @remix.messages.where(role: 'assistant').exists?
    end

    def build_summary(user_messages, assistant_messages)
      parts = []
      user_messages.each_with_index do |msg, i|
        parts << "User: #{msg.truncate(200)}"
        if assistant_messages[i]
          parts << "Assistant: #{assistant_messages[i].truncate(200)}"
        end
      end
      parts.join("\n")
    end
  end
end
