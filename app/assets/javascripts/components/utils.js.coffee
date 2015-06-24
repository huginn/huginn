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
    $('body').css(cursor: 'progress')
    $.ajax type: 'POST', url: $(button).data('action-url'), dataType: 'json', data: data
      .always =>
        $('body').css(cursor: 'auto')
      .done (json) =>
        Utils.showDynamicModal """
          <h5>Log</h5>
          <pre class="agent-dry-run-log"></pre>
          <h5>Events</h5>
          <pre class="agent-dry-run-events"></pre>
          <h5>Memory</h5>
          <pre class="agent-dry-run-memory"></pre>
          """,
          body: (body) ->
            $(body).
              find('.agent-dry-run-log').text(json.log).end().
              find('.agent-dry-run-events').text(json.events).end().
              find('.agent-dry-run-memory').text(json.memory)
          title: 'Dry Run Results',
          onHide: -> $(button).prop('disabled', false)
      .fail (xhr, status, error) ->
        alert('Error: ' + error)
        $(button).prop('disabled', false)
