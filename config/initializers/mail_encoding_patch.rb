module Mail
  class Ruby19
    class ImprovedEncoder < BestEffortCharsetEncoder
      def pick_encoding(charset)
        case charset
        when /\Aiso-2022-jp\z/i
          Encoding::CP50220
        when /\Ashift_jis\z/i
          Encoding::Windows_31J
        else
          super
        end
      end
    end

    self.charset_encoder = ImprovedEncoder.new
  end
end
