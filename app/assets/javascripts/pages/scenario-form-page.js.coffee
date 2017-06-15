class @ScenarioFormPage
  constructor:() ->
    @enabledSelect2()

  format: (icon) ->
    originalOption = icon.element
    '<i class="fa ' + $(originalOption).data('icon') + '"></i> ' + icon.text

  enabledSelect2: () ->
    $('.select2-fountawesome-icon').select2
      width: '100%'
      formatResult: @format
      
$ ->
  Utils.registerPage(ScenarioFormPage, forPathsMatching: /^scenarios/)