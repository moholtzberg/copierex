class SandboxEmailInterceptor
  def self.delivering_email(message)
    message.to = ['moholtzberg@gmail.com']
    message.bcc = nil
    message.subject = "TEST EMAIL --> #{message.subject}"
  end
end