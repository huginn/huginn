$ ->
  $agentNavigate = $('#agent-navigate')

  # initialize typeahead listener
  $agentNavigate.bind "typeahead:selected", (event, object, name) ->
    item = object['value']
    $agentNavigate.typeahead('val', '')
    if window.agentPaths[item]
      $(".spinner").show()
      navigationData = window.agentPaths[item]
      if !(navigationData instanceof Object) || !navigationData.method || navigationData.method == 'GET'
        window.location = navigationData.url || navigationData
      else
        $.rails.handleMethod.apply $("<a href='#{navigationData.url}' data-method='#{navigationData.method}'></a>").appendTo($("body")).get(0)

  # substring matcher for typeahead
  substringMatcher = (strings) ->
    findMatches = (query, callback) ->
      matches = []
      substrRegex = new RegExp(query, "i")
      $.each strings, (i, str) ->
        matches.push value: str  if substrRegex.test(str)
      callback(matches.slice(0,6))

  $agentNavigate.typeahead
    minLength: 1,
    highlight: true,
  ,
    source: substringMatcher(window.agentNames)
