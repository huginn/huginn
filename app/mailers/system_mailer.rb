class SystemMailer < ActionMailer::Base
  default :from => ENV['EMAIL_FROM_ADDRESS'].presence || 'you@example.com'

  def send_message(options)
    @groups = options[:groups]
    @headline = options[:headline]
    @body = options[:body]
    mail :to => options[:to], :subject => options[:subject]
  end
end
