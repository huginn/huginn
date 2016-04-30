class @AgentIndexPage
  constructor: ->
    $(".visibility-enabler").on 'click', @toggleDisabledAgentVisibility

  toggleDisabledAgentVisibility: (e) ->
    e.preventDefault()
    $("tr > td.agent-unavailable").parents("tr").toggle()

$ ->
  Utils.registerPage(AgentIndexPage, forPathsMatching: /^agents#?$/)
