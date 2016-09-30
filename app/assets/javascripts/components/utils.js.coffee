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
    $.ajax url,
      method: 'GET',
      data:
        with_event_mode: with_event_mode
        source_ids: $.map($(".link-region select option:selected"), (el) -> $(el).val() )
      success: (modal_data) =>
        Utils.showDynamicModal modal_data,
          body: (body) =>
            form = $(body).find('.dry-run-form')
            payload_editor = form.find('.payload-editor')

            if previous = $(button).data('payload')
              payload_editor.text(previous)

            editor = window.setupJsonEditor(payload_editor)[0]

            $(body).find('.dry-run-event-sample').click (e) =>
              e.preventDefault()
              editor.json = $(e.currentTarget).data('payload')
              editor.rebuild()

            form.submit (e) =>
              e.preventDefault()
              json = $(e.target).find('.payload-editor').val()
              json = '{}' if json == ''
              try
                payload = JSON.parse(json.replace(/\\\\([n|r|t])/g, "\\$1"))
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
    $.ajax type: 'POST', url: url, dataType: 'html', data: data
      .always =>
        $('body').css(cursor: 'auto')
      .done (modal_data) =>
        Utils.showDynamicModal modal_data,
          title: 'Dry Run Results',
          onHide: callback
      .fail (xhr, status, error) ->
        alert('Error: ' + error)
        callback()

  @select2TagClickHandler: (e, elem) ->
    if e.which == 1
      window.location = $(elem).attr('href')
    else
      window.open($(elem).attr('href'))

  # _.escape from underscore: https://github.com/jashkenas/underscore/blob/1e68f06610fa4ecb7f2c45d1eb2ad0173d6a2cc1/underscore.js#L1411-L1436
  escapeMap =
    '&': '&amp;'
    '<': '&lt;'
    '>': '&gt;'
    '"': '&quot;'
    '\'': '&#x27;'
    '`': '&#x60;'

  createEscaper = (map) ->
    escaper = (match) ->
      map[match]

    # Regexes for identifying a key that needs to be escaped.
    source = '(?:' + Object.keys(map).join('|') + ')'
    testRegexp = RegExp(source)
    replaceRegexp = RegExp(source, 'g')
    (string) ->
      string = if string == null then '' else '' + string
      if testRegexp.test(string) then string.replace(replaceRegexp, escaper) else string

  @escape = createEscaper(escapeMap)
