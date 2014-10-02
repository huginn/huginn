class @AgentShowPage
  constructor: ->
    $(".agent-show #show-tabs a[href='#logs'], #logs .refresh").on "click", @fetchLogs
    $(".agent-show #logs .clear").on "click", @clearLogs

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

$ ->
  Utils.registerPage(AgentShowPage, forPathsMatching: /^agents\/\d+/)

