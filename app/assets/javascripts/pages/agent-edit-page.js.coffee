class @AgentEditPage
  constructor: ->
    $("#agent_source_ids").on "change", @showEventDescriptions
    @showCorrectRegionsOnStartup()
    $("form.agent-form").on "submit", => @updateFromEditors()

    # Validate agents_options Json on form submit
    $('form.agent-form').submit (e) ->
      if $('textarea#agent_options').length
        try
          JSON.parse $('#agent_options').val()
        catch err
          e.preventDefault()
          alert 'Sorry, there appears to be an error in your JSON input. Please fix it before continuing.'
          return false

      if $(".link-region").length && $(".link-region").data("can-receive-events") == false
        $(".link-region .select2-linked-tags option:selected").removeAttr('selected')

      if $(".control-link-region").length && $(".control-link-region").data("can-control-other-agents") == false
        $(".control-link-region .select2-linked-tags option:selected").removeAttr('selected')

      if $(".event-related-region").length && $(".event-related-region").data("can-create-events") == false
        $(".event-related-region .select2-linked-tags option:selected").removeAttr('selected')

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
      @handleTypeChange(true)

      # Update the dropdown to match agent description as well as agent name
      $('select#agent_type').select2
        width: 'resolve'
        formatResult: formatAgentForSelect
        escapeMarkup: (m) ->
          m
        matcher: (term, text, opt) ->
          description = opt.attr('title')
          text.toUpperCase().indexOf(term.toUpperCase()) >= 0 or description.toUpperCase().indexOf(term.toUpperCase()) >= 0

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
    $(".link-region").data("can-receive-events", false)

  showLinks: ->
    $(".link-region .select2-container").show()
    $(".link-region .propagate-immediately").show()
    $(".link-region .cannot-receive-events").hide()
    $(".link-region").data("can-receive-events", true)
    @showEventDescriptions()

  hideControlLinks: ->
    $(".control-link-region").hide()
    $(".control-link-region").data("can-control-other-agents", false)

  showControlLinks: ->
    $(".control-link-region").show()
    $(".control-link-region").data("can-control-other-agents", true)

  hideEventCreation: ->
    $(".event-related-region .select2-container").hide()
    $(".event-related-region .cannot-create-events").show()
    $(".event-related-region").data("can-create-events", false)

  showEventCreation: ->
    $(".event-related-region .select2-container").show()
    $(".event-related-region .cannot-create-events").hide()
    $(".event-related-region").data("can-create-events", true)

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
        $this = $(this)
        $this.data('initialized', true)
        $source = $($this.data('source')).hide()
        editor = ace.edit(this)
        $this.data('ace-editor', editor)
        session = editor.getSession()
        session.setTabSize(2)
        session.setUseSoftTabs(true)
        session.setUseWrapMode(false)

        setSyntax = ->
          if mode = $this.data('mode')
            session.setMode("ace/mode/" + mode)

          if theme = $this.data('theme')
            editor.setTheme("ace/theme/" + theme);

          if mode = $("[name='agent[options][language]']").val()
            switch mode
              when 'JavaScript' then session.setMode("ace/mode/javascript")
              when 'CoffeeScript' then session.setMode("ace/mode/coffee")
              else session.setMode("ace/mode/" + mode)

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
    Utils.handleDryRunButton(e.currentTarget)

  formatAgentForSelect = (agent) ->
    originalOption = agent.element
    description = agent.element[0].title
    '<strong>' + agent.text + '</strong><br/>' + description

$ ->
  Utils.registerPage(AgentEditPage, forPathsMatching: /^agents/)
