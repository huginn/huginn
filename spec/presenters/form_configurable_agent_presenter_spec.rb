require 'rails_helper'

describe FormConfigurableAgentPresenter do
  include RSpecHtmlMatchers
  class FormConfigurableAgentPresenterAgent < Agent
    include FormConfigurable

    form_configurable :string, roles: :validatable
    form_configurable :number, type: :number, html_options: { min: 0 }
    form_configurable :text, type: :text, roles: :completable
    form_configurable :boolean, type: :boolean
    form_configurable :array, type: :array, values: [1, 2, 3]
    form_configurable :json, type: :json
  end

  before(:all) do
    @presenter = FormConfigurableAgentPresenter.new(FormConfigurableAgentPresenterAgent.new,
                                                    ActionController::Base.new.view_context)
  end

  it "works for the type :string" do
    expect(@presenter.option_field_for(:string)).to(
      have_tag(
        'input',
        with: {
          'data-attribute': 'string',
          role: 'validatable form-configurable',
          type: 'text',
          name: 'agent[options][string]'
        }
      )
    )
  end

  it "works for the type :number" do
    expect(@presenter.option_field_for(:number)).to(
      have_tag(
        'input',
        with: {
          'data-attribute': 'number',
          role: 'form-configurable',
          type: 'number',
          name: 'agent[options][number]',
          min: '0',
        }
      )
    )
  end

  it "works for the type :text" do
    expect(@presenter.option_field_for(:text)).to(
      have_tag(
        'textarea',
        with: {
          'data-attribute': 'text',
          role: 'completable form-configurable',
          name: 'agent[options][text]'
        }
      )
    )
  end

  it "works for the type :boolean" do
    expect(@presenter.option_field_for(:boolean)).to(
      have_tag(
        'input',
        with: {
          'data-attribute': 'boolean',
          role: 'form-configurable',
          name: 'agent[options][boolean_radio]',
          type: 'radio'
        }
      )
    )
  end

  it "works for the type :array" do
    expect(@presenter.option_field_for(:array)).to(
      have_tag(
        'select',
        with: {
          'data-attribute': 'array',
          role: 'completable form-configurable',
          name: 'agent[options][array]'
        }
      )
    )
  end

  it "works for the type :json" do
    expect(@presenter.option_field_for(:json)).to(
      have_tag(
        'textarea',
        with: {
          'data-attribute': 'json',
          role: 'form-configurable',
          name: 'agent[options][json]',
          class: 'live-json-editor',
        }
      )
    )
  end
end
