class SystemMailer < ActionMailer::Base
  default :from => ENV['EMAIL_FROM_ADDRESS'].presence || 'you@example.com'

  def self.agent
    return @@agent
  end

  def send_message(options)
    if options[:agent].present?
      @@agent = options[:agent]
    end
    @groups = options[:groups]
    @headline = options[:headline]
    @body = options[:body]
    mail :to => options[:to], :subject => options[:subject]
  end
end

=begin
http://stackoverflow.com/questions/2823748/how-do-i-add-information-to-an-exception-message-in-ruby
https://simonecarletti.com/blog/2009/11/re-raise-a-ruby-exception-in-a-rails-rescue_from-statement/

      EOFError,
      IOError,
      TimeoutError,
      Errno::ECONNRESET,
      Errno::ECONNABORTED,
      Errno::EPIPE,
      Errno::ETIMEDOUT,
      Net::SMTPAuthenticationError,
      Net::SMTPServerBusy,
      Net::SMTPSyntaxError,
      Net::SMTPUnknownError,
      OpenSSL::SSL::SSLError

=end

ActionMailer::DeliveryJob.rescue_from(StandardError) do |exception|
  if !exception.message.start_with?('+++')
    Rails.logger.info "Intercepted ActionMailer::DeliveryJob error: #{exception.message}"
    SystemMailer.agent.log("Mailing error: #{exception.message}") if !SystemMailer.agent.nil?
    raise $!, "+++#{$!}", $!.backtrace
  end
end

