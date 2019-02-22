module FileHandling
  extend ActiveSupport::Concern

  def get_file_pointer(file)
    { file_pointer: { file: file, agent_id: id } }
  end

  def has_file_pointer?(event)
    event.payload['file_pointer'] &&
      event.payload['file_pointer']['file'] &&
      event.payload['file_pointer']['agent_id']
  end

  def get_io(event)
    return nil unless has_file_pointer?(event)
    event.user.agents.find(event.payload['file_pointer']['agent_id']).get_io(event.payload['file_pointer']['file'])
  end

  def get_upload_io(event)
    Faraday::UploadIO.new(get_io(event), MIME::Types.type_for(File.basename(event.payload['file_pointer']['file'])).first.try(:content_type))
  end

  def emitting_file_handling_agent_description
    @emitting_file_handling_agent_description ||=
      "This agent only emits a 'file pointer', not the data inside the files, the following agents can consume the created events: `#{receiving_file_handling_agents.join('`, `')}`. Read more about the concept in the [wiki](https://github.com/huginn/huginn/wiki/How-Huginn-works-with-files)."
  end

  def receiving_file_handling_agent_description
    @receiving_file_handling_agent_description ||=
      "This agent can consume a 'file pointer' event from the following agents with no additional configuration: `#{emitting_file_handling_agents.join('`, `')}`. Read more about the concept in the [wiki](https://github.com/huginn/huginn/wiki/How-Huginn-works-with-files)."
  end

  private

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
