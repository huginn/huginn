class SystemMailer < ActionMailer::Base
  default :from => ENV['EMAIL_FROM_ADDRESS'].presence || 'you@example.com'

  def send_message(options)
    @groups = options[:groups]
    @headline = options[:headline]
    @body = options[:body]

    mail_options = { to: options[:to], subject: options[:subject] }
    mail_options[:from] = options[:from] if options[:from].present?

    template = options[:template] if options[:template].present?

    if options[:content_type].present?
      mail(mail_options) do |format|
        format.text if !template && options[:content_type] == "text/plain"
        format.html if !template && options[:content_type] == "text/html"
        format.text { render inline: template } if template && options[:content_type] == "text/plain"
        format.html { render inline: template } if template && options[:content_type] == "text/html"
      end
    else
      mail(mail_options)
    end
  end
end
