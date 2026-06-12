module FileHandling
  extend ActiveSupport::Concern

  def get_file_pointer(file)
    { file_pointer: signed_file_pointer(file:, agent_id: id) }
  end

  def has_file_pointer?(event)
    event.payload['file_pointer'] &&
      event.payload['file_pointer']['file'] &&
      event.payload['file_pointer']['agent_id']
  end

  def get_io(event)
    return nil unless has_file_pointer?(event)

    file_pointer = event.payload['file_pointer']
    return nil if require_signed_file_pointer? && !valid_file_pointer_signature?(file_pointer)

    event.user.agents.find(file_pointer['agent_id']).get_io(file_pointer['file'])
  end

  def get_upload_io(event)
    io = get_io(event) or return

    Faraday::UploadIO.new(
      io,
      MIME::Types.type_for(File.basename(event.payload['file_pointer']['file'])).first.try(:content_type)
    )
  end

  def validate_require_signed_file_pointer_options!
    return unless option_provided?(options['require_signed_file_pointer'])

    if boolify(options['require_signed_file_pointer']).nil?
      errors.add(:base, "if provided, require_signed_file_pointer must be a boolean value")
    end
  end

  def emitting_file_handling_agent_description
    @emitting_file_handling_agent_description ||=
      "This agent only emits a 'file pointer', not the data inside the files, the following agents can consume the created events: `#{receiving_file_handling_agents.join('`, `')}`. Read more about the concept in the [wiki](https://github.com/huginn/huginn/wiki/How-Huginn-works-with-files)."
  end

  def receiving_file_handling_agent_description
    @receiving_file_handling_agent_description ||=
      "This agent can consume a 'file pointer' event from the following agents with no additional configuration: `#{emitting_file_handling_agents.join('`, `')}`. Set `require_signed_file_pointer` to `true` to treat file pointers that were not signed by a file-handling agent as invalid. Read more about the concept in the [wiki](https://github.com/huginn/huginn/wiki/How-Huginn-works-with-files)."
  end

  private

  def signed_file_pointer(**pointer)
    pointer.merge(signature: sign_file_pointer(pointer))
  end

  def sign_file_pointer(pointer)
    file_pointer_verifier.generate(file_pointer_signature_payload(pointer))
  end

  def valid_file_pointer_signature?(pointer)
    signature = pointer['signature'].presence or return false

    begin
      file_pointer_verifier.verify(signature) == file_pointer_signature_payload(pointer)
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      false
    end
  end

  def file_pointer_signature_payload(pointer)
    pointer.with_indifferent_access.slice('agent_id', 'file')
  end

  def file_pointer_verifier
    ActiveSupport::MessageVerifier.new(
      Rails.application.secret_key_base,
      digest: 'SHA256',
      serializer: JSON,
      url_safe: true
    )
  end

  def require_signed_file_pointer?
    boolify(options['require_signed_file_pointer'])
  end

  def emitting_file_handling_agents
    emitting_file_handling_agents = file_handling_agents.select { |a| a.emits_file_pointer? }
    emitting_file_handling_agents.map { |a| a.to_s.demodulize }
  end

  def receiving_file_handling_agents
    receiving_file_handling_agents = file_handling_agents.select { |a| a.consumes_file_pointer? }
    receiving_file_handling_agents.map { |a| a.to_s.demodulize }
  end

  def file_handling_agents
    @file_handling_agents ||= Agent.types.select{ |c| c.included_modules.include?(FileHandling) }.map { |d| d.name.constantize }
  end

  module ClassMethods
    def emits_file_pointer!
      @emits_file_pointer = true
    end

    def emits_file_pointer?
      !!@emits_file_pointer
    end

    def consumes_file_pointer!
      @consumes_file_pointer = true
    end

    def consumes_file_pointer?
      !!@consumes_file_pointer
    end
  end
end
