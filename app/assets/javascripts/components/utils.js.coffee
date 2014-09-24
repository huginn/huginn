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
