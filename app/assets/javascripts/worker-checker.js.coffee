$ ->
  if $("#job-indicator").length
    check = ->
      $.getJSON "/worker_status", (json) ->
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
        window.workerCheckTimeout = setTimeout check, 2000
    check()
