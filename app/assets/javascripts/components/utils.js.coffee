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
