$ ->
  sinceId = null
  previousJobs = null

  if $(".job-indicator").length
    check = ->
      query =
        if sinceId?
          '?since_id=' + sinceId
        else
          ''
      $.getJSON "/worker_status" + query, (json) ->
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

        if sinceId? && json.event_count > 0
          $("#event-indicator").tooltip('destroy').
                                tooltip(title: "Click to see the events", delay: 0, placement: "bottom", trigger: "hover").
                                find('a').attr(href: json.events_url).end().
                                fadeIn().
                                find(".number").
                                text(json.event_count)
        else
          $("#event-indicator").tooltip('destroy').fadeOut()

        sinceId ?= json.max_id
        currentJobs = [json.pending, json.awaiting_retry, json.recent_failures]
        if document.location.pathname == '/jobs' && $(".modal[aria-hidden=false]").length == 0 && previousJobs? && previousJobs.join(',') != currentJobs.join(',')
          if !document.location.search || document.location.search == '?page=1'
            $.get '/jobs', (data) =>
              $("#main-content").html(data)
        previousJobs = currentJobs

        window.workerCheckTimeout = setTimeout check, 2000

    check()
