require 'delegate'

class Decorator < SimpleDelegator
  def class
    __getobj__.class
  end
end

class FormConfigurableAgentPresenter < Decorator
  def initialize(agent, view)
    @agent = agent
    @view = view
    super(agent)
  end

  def option_field_for(attribute)
    data = @agent.form_configurable_fields[attribute]
    value = @agent.options[attribute.to_s] || @agent.default_options[attribute.to_s]
    html_options = {role: (data[:roles] + ['form-configurable']).join(' '), data: {attribute: attribute}}

    case data[:type]
    when :text
      @view.text_area_tag "agent[options][#{attribute}]", value, html_options.merge(class: 'form-control', rows: 3)
    when :boolean
      @view.content_tag 'div' do
        @view.concat(@view.content_tag('label', class: 'radio-inline') do
          @view.concat @view.radio_button_tag "agent[options][#{attribute}_radio]", 'true', @agent.send(:boolify, value) == true, html_options
          @view.concat "True"
        end)
        @view.concat(@view.content_tag('label', class: 'radio-inline') do
          @view.concat @view.radio_button_tag "agent[options][#{attribute}_radio]", 'false', @agent.send(:boolify, value) == false, html_options
          @view.concat "False"
        end)
        @view.concat(@view.content_tag('label', class: 'radio-inline') do
          @view.concat @view.radio_button_tag "agent[options][#{attribute}_radio]", 'manual', @agent.send(:boolify, value) == nil, html_options
          @view.concat "Manual Input"
        end)
        @view.concat(@view.text_field_tag "agent[options][#{attribute}]", value, html_options.merge(:class => "form-control #{@agent.send(:boolify, value) != nil ? 'hidden' : ''}"))
      end
    when :array, :string
      @view.text_field_tag "agent[options][#{attribute}]", value, html_options.merge(:class => 'form-control')
    end
  end
end