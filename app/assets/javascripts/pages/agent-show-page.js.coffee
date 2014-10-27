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
      $("#logs .logs .show-log-details").each ->
        $button = $(this)
        $button.on 'click', (e) ->
          e.preventDefault()
          $("body").append """
            <div class="modal fade" tabindex="-1" id='dynamic-modal' role="dialog" aria-labelledby="dynamic-modal-label" aria-hidden="true">
              <div class="modal-dialog modal-lg">
                <div class="modal-content">
                  <div class="modal-header">
                    <button type="button" class="close" data-dismiss="modal"><span aria-hidden="true">&times;</span><span class="sr-only">Close</span></button>
                    <h4 class="modal-title" id="dynamic-modal-label"></h4>
                  </div>
                  <div class="modal-body"><pre></pre></div>
                </div>
              </div>
            </div>
          """
          $('#dynamic-modal').find('.modal-title').text $button.data('modal-title')
          $('#dynamic-modal').find('.modal-body pre').text $button.data('modal-content')
          $('#dynamic-modal').modal('show').on 'hidden.bs.modal', -> $('#dynamic-modal').remove()

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

