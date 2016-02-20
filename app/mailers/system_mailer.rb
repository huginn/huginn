class SystemMailer < ActionMailer::Base
  default :from => ENV['EMAIL_FROM_ADDRESS'].presence || 'you@example.com'

  def send_message(options)
    @groups = options[:groups]
    @headline = options[:headline]
    @body = options[:body]

    mail_options = { to: options[:to], subject: options[:subject] }
    mail_options[:from] = options[:from] if options[:from].present?
    mail(mail_options)
  end
end
