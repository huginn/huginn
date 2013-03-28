class SystemMailer < ActionMailer::Base
  default from: ENV['EMAIL_FROM_ADDRESS']

  def send_message(options)
    @lines = options[:lines]
    @headline = options[:headline]
    mail :to => options[:to], :subject => options[:subject]
  end
end
