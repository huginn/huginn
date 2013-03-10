class SystemMailer < ActionMailer::Base
  default from: "huginn@your-google-apps-domain.com"

  def send_message(options)
    @lines = options[:lines]
    @headline = options[:headline]
    mail :to => options[:to], :subject => options[:subject]
  end
end
