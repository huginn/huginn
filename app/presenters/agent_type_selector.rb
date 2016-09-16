# Encapsulates the logic for an HTML agent type selector.
class AgentTypeSelector < Selector
  # user --- The user for whom the agent list should be generated.
  def initialize(user:, **args)
    super(args)
    @user = user
  end

  protected

  def choices
    [no_element_choice] + agent_choices
  end

  private

  attr_reader :user

  def agent_choices
    Agent.types.map { |type|
      [
        humanize_name(type.name),
        type,
        {title: html_description(type.name)}
      ]
    }.sort_by(&:first)
  end

  def html_description(name)
    description = Agent.build_for_type(name, user, {}).html_description
    short_description = description.lines.first.strip

    view.__send__(:h, short_description)
  end

  def humanize_name(name)
    name.gsub(/^.*::/, '').underscore.humanize.titleize
  end

  def no_element_choice
    ['Select an Agent Type', 'Agent', {title: ''}]
  end
end
