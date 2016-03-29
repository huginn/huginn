class @Utils
  @navigatePath: (path) ->
    path = "/" + path unless path.match(/^\//)
    window.location.href = path

  @currentPath: ->
    window.location.href.replace(/https?:\/\/.*?\//g, '')

  @registerPage: (klass, options = {}) ->
    if options.forPathsMatching?
      if Utils.currentPath().match(options.forPathsMatching)
        window.currentPage = new klass()
    else
      new klass()

  @showDynamicModal: (content = '', { title, body, onHide } = {}) ->
    $("body").append """
      <div class="modal fade" tabindex="-1" id='dynamic-modal' role="dialog" aria-labelledby="dynamic-modal-label" aria-hidden="true">
        <div class="modal-dialog modal-lg">
          <div class="modal-content">
            <div class="modal-header">
              <button type="button" class="close" data-dismiss="modal"><span aria-hidden="true">&times;</span><span class="sr-only">Close</span></button>
              <h4 class="modal-title" id="dynamic-modal-label"></h4>
            </div>
            <div class="modal-body">#{content}</div>
          </div>
        </div>
      </div>
      """
    modal = document.querySelector('#dynamic-modal')
    $(modal).find('.modal-title').text(title || '').end().on 'hidden.bs.modal', ->
      $('#dynamic-modal').remove()
      onHide?()
    body?(modal.querySelector('.modal-body'))
    $(modal).modal('show')

  @handleDryRunButton: (button, data = if button.form then $(':input[name!="_method"]', button.form).serialize() else '') ->
    $(button).prop('disabled', true)
    cleanup = -> $(button).prop('disabled', false)

    url = $(button).data('action-url')
    with_event_mode = $(button).data('with-event-mode')

    if with_event_mode is 'no'
      return @invokeDryRun(url, data, cleanup)

    Utils.showDynamicModal """
      <h5>Event to send#{if with_event_mode is 'maybe' then ' (Optional)' else ''}</h5>
      <form class="dry-run-form" method="post">
        <div class="form-group">
          <textarea rows="10" name="event" class="payload-editor" data-height="200">
            {}
          </textarea>
        </div>
        <div class="form-group">
          <input value="Dry Run" class="btn btn-primary" type="submit" />
        </div>
      </form>
      """,
      body: (body) =>
        form = $(body).find('.dry-run-form')
        payload_editor = form.find('.payload-editor')
        if previous = $(button).data('payload')
          payload_editor.text(previous)
        window.setupJsonEditor(payload_editor)
        form.submit (e) =>
          e.preventDefault()
          json = $(e.target).find('.payload-editor').val()
          json = '{}' if json == ''
          try
            payload = JSON.parse(json)
            throw true unless payload.constructor is Object
            if Object.keys(payload).length == 0
              json = ''
            else
              json = JSON.stringify(payload)
          catch
            alert 'Invalid JSON object.'
            return
          if json == ''
            if with_event_mode is 'yes'
              alert 'Event is required for this agent to run.'
              return
            dry_run_data = data
            $(button).data('payload', null)
          else
            dry_run_data = "event=#{encodeURIComponent(json)}&#{data}"
            $(button).data('payload', json)
          $(body).closest('[role=dialog]').on 'hidden.bs.modal', =>
            @invokeDryRun(url, dry_run_data, cleanup)
          .modal('hide')
        $(body).closest('[role=dialog]').on 'shown.bs.modal', ->
          $(this).find('.btn-primary').focus()
      title: 'Dry Run'
      onHide: cleanup

  @invokeDryRun: (url, data, callback) ->
    $('body').css(cursor: 'progress')
    $.ajax type: 'POST', url: url, dataType: 'json', data: data
      .always =>
        $('body').css(cursor: 'auto')
      .done (json) =>
        Utils.showDynamicModal """
          <!-- Nav tabs -->
          <ul id="resultTabs" class="nav nav-tabs agent-dry-run-tabs" role="tablist">
            <li role="presentation"><a href="#tabEvents" aria-controls="tabEvents" role="tab" data-toggle="tab">Events</a></li>
            <li role="presentation"><a href="#tabLog" aria-controls="tabLog" role="tab" data-toggle="tab">Log</a></li>
            <li role="presentation"><a href="#tabMemory" aria-controls="tabMemory" role="tab" data-toggle="tab">Memory</a></li>
          </ul>
          <!-- Tab panes -->
          <div class="tab-content">
            <div role="tabpanel" class="tab-pane" id="tabEvents">
              <pre class="agent-dry-run-events"></pre>
            </div>
            <div role="tabpanel" class="tab-pane" id="tabLog">
              <pre><small class="agent-dry-run-log"></small></pre>
            </div>
            <div role="tabpanel" class="tab-pane" id="tabMemory">
              <pre class="agent-dry-run-memory"></pre>
            </div>
          </div>
          """,
          body: (body) ->
            $(body).
              find('.agent-dry-run-log').text(json.log).end().
              find('.agent-dry-run-events').text(json.events).end().
              find('.agent-dry-run-memory').text(json.memory)
            active = if json.events.match(/^\[?\s*\]?$/) then 'tabLog' else 'tabEvents'
            $('#resultTabs a[href="#' + active + '"]').tab('show')
          title: 'Dry Run Results',
          onHide: callback
      .fail (xhr, status, error) ->
        alert('Error: ' + error)
        callback()
