class @AgentEditPage
  constructor: ->
    $("#agent_source_ids").on "change", @showEventDescriptions
    @showCorrectRegionsOnStartup()
    $("form.agent-form").on "submit", => @updateFromEditors()

    $("#agent_name").each ->
      # Select the number suffix if this is a cloned agent.
      if matches = this.value.match(/ \(\d+\)$/)
        this.focus()
        if this.selectionStart?
          this.selectionStart = matches.index
          this.selectionEnd = this.value.length

    # The type selector is only available on the new agent form.
    if $("#agent_type").length
      $("#agent_type").on "change", => @handleTypeChange(false)
      $("#agent_type").select2 matcher: (term, text, opt) ->
        text.toUpperCase().indexOf(term.toUpperCase()) >= 0 or ( opt.data("description") and atob(opt.data("description")).toUpperCase().indexOf(term.toUpperCase()) >= 0)
      $("#agent_type").on "select2-highlight", (e) => 
        $(".description").html(atob($(e.choice.element).data("description"))).show()
      $("#agent_type").on "select2-close", (e) => 
        description = $($("#agent_type").select2("data").element).data("description") or ''
        $(".description").html(atob(description))
      @handleTypeChange(true)
    else
      @enableDryRunButton()
      @buildAce()

  handleTypeChange: (firstTime) ->
    $(".event-descriptions").html("").hide()
    type = $('#agent_type').val()

    if type == 'Agent'
      $(".agent-settings").hide()
      $(".description").hide()
    else
      $(".agent-settings").show()
      $("#agent-spinner").fadeIn()
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

        unless firstTime
          $('.oauthable-form').html(json.oauthable) if json.oauthable?
          $('.agent-options').html(json.form_options) if json.form_options?
          window.jsonEditor = setupJsonEditor()[0]

        @enableDryRunButton()
        @buildAce()

        window.initializeFormCompletable()

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

  buildAce: ->
    $(".ace-editor").each ->
      unless $(this).data('initialized')
        $(this).data('initialized', true)
        $source = $($(this).data('source')).hide()
        editor = ace.edit(this)
        $(this).data('ace-editor', editor)
        session = editor.getSession()
        session.setTabSize(2)
        session.setUseSoftTabs(true)
        session.setUseWrapMode(false)
        editor.setTheme("ace/theme/chrome")

        setSyntax = ->
          switch $("[name='agent[options][language]']").val()
            when 'JavaScript' then session.setMode("ace/mode/javascript")
            when 'CoffeeScript' then session.setMode("ace/mode/coffee")
            else session.setMode("ace/mode/text")

        $("[name='agent[options][language]']").on 'change', setSyntax
        setSyntax()

        session.setValue($source.val())

  updateFromEditors: ->
    $(".ace-editor").each ->
      $source = $($(this).data('source'))
      $source.val($(this).data('ace-editor').getSession().getValue())

  enableDryRunButton: ->
    $(".agent-dry-run-button").prop('disabled', false).off().on "click", @invokeDryRun

  disableDryRunButton: ->
    $(".agent-dry-run-button").prop('disabled', true)

  invokeDryRun: (e) =>
    e.preventDefault()
    @updateFromEditors()
    Utils.handleDryRunButton(e.target)

$ ->
  Utils.registerPage(AgentEditPage, forPathsMatching: /^agents/)
