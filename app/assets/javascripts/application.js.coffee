#= require jquery
#= require jquery_ujs
#= require typeahead.bundle
#= require bootstrap
#= require select2
#= require json2
#= require jquery.json-editor
#= require jquery.serializeObject
#= require latlon_and_geo
#= require spectrum
#= require_tree ./components
#= require_tree ./pages
#= require_self

format = (icon) ->
  originalOption = icon.element
  '<i class="fa ' + $(originalOption).data('icon') + '"></i> ' + icon.text

$(document).ready ->
  $('.js-example-basic-single').select2
    width: '100%'
    formatResult: format
