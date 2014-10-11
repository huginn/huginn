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
    html_options = {role: data[:roles].join(' '), data: {attribute: attribute}}

    case data[:type]
    when :text
      @view.text_area_tag "agent[options][#{attribute}]", value, html_options.merge(class: 'form-control', rows: 3)
    when :boolean
      @view.content_tag 'div' do
        @view.concat(@view.content_tag('label', class: 'radio-inline') do
          @view.concat @view.radio_button_tag "agent[options][#{attribute}]", 'true', @agent.send(:boolify, value), html_options
          @view.concat "Yes"
        end)
        @view.concat(@view.content_tag('label', class: 'radio-inline') do
          @view.concat @view.radio_button_tag "agent[options][#{attribute}]", 'false', !@agent.send(:boolify, value), html_options
          @view.concat "No"
        end)
      end
    when :array
      @view.select_tag("agent[options][#{attribute}]", @view.options_for_select(data[:values], value), html_options.merge(class: "form-control"))
    when :string
      @view.text_field_tag "agent[options][#{attribute}]", value, html_options.merge(:class => 'form-control')
    end
  end
end