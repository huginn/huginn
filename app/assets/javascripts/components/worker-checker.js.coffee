$ ->
  firstEventCount = null
  previousJobs = null

  if $(".job-indicator").length
    check = ->
      $.getJSON "/worker_status", (json) ->
        for method in ['pending', 'awaiting_retry', 'recent_failures']
          count = json[method]
          elem = $(".job-indicator[role=#{method}]")
          if count > 0
            tooltipOptions = {
              title: "#{count} jobs #{method.split('_').join(' ')}"
              delay: 0
              placement: "bottom"
              trigger: "hover"
            }
            if elem.is(":visible")
              elem.tooltip('destroy').tooltip(tooltipOptions).find(".number").text(count)
            else
              elem.tooltip('destroy').tooltip(tooltipOptions).fadeIn().find(".number").text(count)
          else
            if elem.is(":visible")
              elem.tooltip('destroy').fadeOut()

        firstEventCount = json.event_count unless firstEventCount?
        if firstEventCount? && json.event_count > firstEventCount
          $("#event-indicator").tooltip('destroy').
                                tooltip(title: "Click to reload", delay: 0, placement: "bottom", trigger: "hover").
                                fadeIn().
                                find(".number").
                                text(json.event_count - firstEventCount)
        else
          $("#event-indicator").tooltip('destroy').fadeOut()

        currentJobs = [json.pending, json.awaiting_retry, json.recent_failures]
        if document.location.pathname == '/jobs' && $(".modal[aria-hidden=false]").length == 0 && previousJobs? && previousJobs.join(',') != currentJobs.join(',')
          $.get '/jobs', (data) =>
            $("#main-content").html(data)
        previousJobs = currentJobs

        window.workerCheckTimeout = setTimeout check, 2000

    check()

  $("#event-indicator a").on "click", (e) ->
    e.preventDefault()
    window.location.reload()