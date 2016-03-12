class @AgentShowPage
  constructor: ->
    $(".agent-show #show-tabs a[href='#logs'], #logs .refresh").on "click", @fetchLogs
    $(".agent-show #logs .clear").on "click", @clearLogs
    $(".agent-show #memory .clear").on "click", @clearMemory
    $('#toggle-memory').on "click", @toggleMemory

    # Trigger tabs when navigated to.
    if tab = window.location.href.match(/tab=(\w+)\b/i)?[1]
      if tab in ["details", "logs"]
        $(".agent-show .nav-pills li a[href='##{tab}']").click()

  fetchLogs: (e) ->
    agentId = $(e.target).closest("[data-agent-id]").data("agent-id")
    e.preventDefault()
    $("#logs .spinner").show()
    $("#logs .refresh, #logs .clear").hide()
    $.get "/agents/#{agentId}/logs", (html) =>
      $("#logs .logs").html html
      $("#logs .logs .show-log-details").each ->
        $button = $(this)
        $button.on 'click', (e) ->
          e.preventDefault()
          Utils.showDynamicModal '<pre></pre>',
            title: $button.data('modal-title'),
            body: (body) ->
              $(body).find('pre').text $button.data('modal-content')

      $("#logs .spinner").stop(true, true).fadeOut ->
        $("#logs .refresh, #logs .clear").show()

  clearLogs: (e) ->
    if confirm("Are you sure you want to clear all logs for this Agent?")
      agentId = $(e.target).closest("[data-agent-id]").data("agent-id")
      e.preventDefault()
      $("#logs .spinner").show()
      $("#logs .refresh, #logs .clear").hide()
      $.post "/agents/#{agentId}/logs/clear", { "_method": "DELETE" }, (html) =>
        $("#logs .logs").html html
        $("#show-tabs li a.recent-errors").removeClass 'recent-errors'
        $("#logs .spinner").stop(true, true).fadeOut ->
          $("#logs .refresh, #logs .clear").show()

  toggleMemory: (e) ->
    e.preventDefault()
    if $('pre.memory').hasClass('hidden')
      $('pre.memory').removeClass 'hidden'
      $('#toggle-memory').text('Hide')
    else
      $('pre.memory').addClass 'hidden'
      $('#toggle-memory').text('Show')

  clearMemory: (e) ->
    if confirm("Are you sure you want to completely clear the memory of this Agent?")
      agentId = $(e.target).closest("[data-agent-id]").data("agent-id")
      e.preventDefault()
      $("#memory .spinner").css(display: 'inline-block')
      $("#memory .clear").hide()
      $.post "/agents/#{agentId}/memory", { "_method": "DELETE" }
        .done ->
          $("#memory .spinner").fadeOut ->
            $("#memory + .memory").text "{\n}\n"
        .fail ->
          $("#memory .spinner").fadeOut ->
            $("#memory .clear").css(display: 'inline-block')

$ ->
  Utils.registerPage(AgentShowPage, forPathsMatching: /^agents\/\d+/)
  
