class @ScenarioShowPage
  constructor:() ->
    $('#disable_all').on "click", @modalbody()
    $('#enable_all').on "click", @modaltext()

  modalbody:() ->
    $('.modal-body').text 'Would you like to disable all agents?'
    $('#disabledfield').val 'true'

  modaltext:() ->
    $('.modal-body').text 'Would you like to enable all agents?'
    $('#disabledfield').val 'false'

$ ->
  Utils.registerPage(ScenarioShowPage, forPathsMatching: /^scenarios/)