class @ScenarioShowPage
  constructor:() ->
    @changeModaltext()

  changeModaltext: () ->
    $('#disable_all').click ->
      $('#enable-disable-agents .modal-body').text 'Would you like to disable all agents?'
      $('#scenario-disabled-value').val 1
    $('#enable_all').click ->
      $('#enable-disable-agents .modal-body').text 'Would you like to enable all agents?'
      $('#scenario-disabled-value').val 0

$ ->
  Utils.registerPage(ScenarioShowPage, forPathsMatching: /^scenarios/)

