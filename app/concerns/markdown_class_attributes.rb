module MarkdownClassAttributes
  extend ActiveSupport::Concern

  module ClassMethods
    def markdown_class_attributes(*attributes)
      attributes.each do |attribute|
        class_eval <<-RUBY
          def html_#{attribute}
            html = Kramdown::Document.new(#{attribute}, auto_ids: false).to_html
            tags = Rails::HTML5::SafeListSanitizer.allowed_tags + %w[table thead tbody tr th td]
            attributes = Rails::HTML5::SafeListSanitizer.allowed_attributes + %w[class]
            Rails::HTML5::SafeListSanitizer.new.sanitize(html, tags: tags, attributes: attributes).html_safe
          end

          def #{attribute}
            if self.class.#{attribute}.is_a?(Proc)
              Utils.unindent(self.instance_eval(&self.class.#{attribute}) || "No #{attribute} has been set.")
            else
              Utils.unindent(self.class.#{attribute} || "No #{attribute} has been set.")
            end
          end

          def self.#{attribute}(value = nil, &block)
            if block
              @#{attribute} = block
            elsif value
              @#{attribute} = value
            end
            @#{attribute}
          end
        RUBY
      end
    end
  end
end
