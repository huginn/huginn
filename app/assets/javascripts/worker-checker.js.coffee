$ ->
  firstEventCount = null

  if $("#job-indicator").length
    check = ->
      $.getJSON "/worker_status", (json) ->
        firstEventCount = json.event_count unless firstEventCount?

        if json.pending? && json.pending > 0
          tooltipOptions = {
            title: "#{json.pending} pending, #{json.awaiting_retry} awaiting retry, and #{json.recent_failures} recent failures"
            delay: 0
            placement: "bottom"
            trigger: "hover"
          }
          $("#job-indicator").tooltip('destroy').tooltip(tooltipOptions).fadeIn().find(".number").text(json.pending)
        else
          $("#job-indicator:visible").tooltip('destroy').fadeOut()

        if firstEventCount? && json.event_count > firstEventCount
          $("#event-indicator").tooltip('destroy').
                                tooltip(title: "Click to reload", delay: 0, placement: "bottom", trigger: "hover").
                                fadeIn().
                                find(".number").
                                text(json.event_count - firstEventCount)
        else
          $("#event-indicator").tooltip('destroy').fadeOut()

        window.workerCheckTimeout = setTimeout check, 2000

    check()

  $("#event-indicator a").on "click", (e) ->
    e.preventDefault()
    window.location.reload()