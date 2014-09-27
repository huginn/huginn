class @AgentEditPage
  constructor: ->
    $("#agent_source_ids").on "change", @showEventDescriptions
    @showCorrectRegionsOnStartup()

    # The type selector is only available on the new agent form.
    if $("#agent_type").length
      $("#agent_type").on "change", => @handleTypeChange(false)
      @handleTypeChange(true)

  handleTypeChange: (firstTime) ->
    $(".event-descriptions").html("").hide()
    type = $('#agent_type').val()

    if type == 'Agent'
      $(".agent-settings").hide()
      $(".description").hide()
    else
      $(".agent-settings").show()
      $("#agent-spinner").fadeIn()
      $("#agent_source_ids").select2("val", {})
      $(".model-errors").hide() unless firstTime
      $.getJSON "/agents/type_details", { type: type }, (json) =>
        if json.can_be_scheduled
          if firstTime
            @showSchedule()
          else
            @showSchedule(json.default_schedule)
        else
          @hideSchedule()

        if json.can_receive_events
          @showLinks()
        else
          @hideLinks()

        if json.can_control_other_agents
          @showControlLinks()
        else
          @hideControlLinks()

        if json.can_create_events
          @showEventCreation()
        else
          @hideEventCreation()

        $(".description").show().html(json.description_html) if json.description_html?

        $('.oauthable-form').html(json.form) if json.form?

        unless firstTime
          window.jsonEditor.json = json.options
          window.jsonEditor.rebuild()

        $("#agent-spinner").stop(true, true).fadeOut();

  hideSchedule: ->
    $(".schedule-region .can-be-scheduled").hide()
    $(".schedule-region .cannot-be-scheduled").show()

  showSchedule: (defaultSchedule = null) ->
    if defaultSchedule?
      $(".schedule-region select").val(defaultSchedule).change()
    $(".schedule-region .can-be-scheduled").show()
    $(".schedule-region .cannot-be-scheduled").hide()

  hideLinks: ->
    $(".link-region .select2-container").hide()
    $(".link-region .propagate-immediately").hide()
    $(".link-region .cannot-receive-events").show()

  showLinks: ->
    $(".link-region .select2-container").show()
    $(".link-region .propagate-immediately").show()
    $(".link-region .cannot-receive-events").hide()
    @showEventDescriptions()

  hideControlLinks: ->
    $(".control-link-region").hide()

  showControlLinks: ->
    $(".control-link-region").show()

  hideEventCreation: ->
    $(".event-related-region").hide()

  showEventCreation: ->
    $(".event-related-region").show()

  showEventDescriptions: ->
    if $("#agent_source_ids").val()
      $.getJSON "/agents/event_descriptions", { ids: $("#agent_source_ids").val().join(",") }, (json) =>
        if json.description_html?
          $(".event-descriptions").show().html(json.description_html)
        else
          $(".event-descriptions").hide()
    else
      $(".event-descriptions").html("").hide()

  showCorrectRegionsOnStartup: ->
    if $(".schedule-region")
      if $(".schedule-region").data("can-be-scheduled") == true
        @showSchedule()
      else
        @hideSchedule()

    if $(".link-region")
      if $(".link-region").data("can-receive-events") == true
        @showLinks()
      else
        @hideLinks()

    if $(".control-link-region")
      if $(".control-link-region").data("can-control-other-agents") == true
        @showControlLinks()
      else
        @hideControlLinks()

    if $(".event-related-region")
      if $(".event-related-region").data("can-create-events") == true
        @showEventCreation()
      else
        @hideEventCreation()

$ ->
  Utils.registerPage(AgentEditPage, forPathsMatching: /^agents/)
