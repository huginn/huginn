class @ScenarioShowPage
  constructor:() ->
    @changemodaltext()

  changemodaltext: () ->
    $('#disable_all').click ->
      $('.modal-body').text 'Would you like to disable all agents?'
      $('#disabledfield').val 1
    $('#enable_all').click ->
      $('.modal-body').text 'Would you like to enable all agents?'
      $('#disabledfield').val 0

$ ->
  Utils.registerPage(ScenarioShowPage, forPathsMatching: /^scenarios/)

