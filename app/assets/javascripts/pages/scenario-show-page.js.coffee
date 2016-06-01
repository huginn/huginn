class @ScenarioShowPage
  constructor:() ->
    @changeModalText()

  changeModalText: () ->
    $('#disable-all').click ->
      $('#enable-disable-agents .modal-body').text 'Would you like to disable all agents?'
      $('#scenario-disabled-value').val 'true'
    $('#enable-all').click ->
      $('#enable-disable-agents .modal-body').text 'Would you like to enable all agents?'
      $('#scenario-disabled-value').val 'false'

$ ->
  Utils.registerPage(ScenarioShowPage, forPathsMatching: /^scenarios/)

