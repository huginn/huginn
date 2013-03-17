class SystemMailer < ActionMailer::Base
  default from: HUGINN_CONFIG[:email_from_address] 

  def send_message(options)
    @lines = options[:lines]
    @headline = options[:headline]
    mail :to => options[:to], :subject => options[:subject]
  end
end
