class @UserCredentialPage
  constructor: ->
    editor = ace.edit("ace-credential-value")
    editor.getSession().setTabSize(2)
    editor.getSession().setUseSoftTabs(true)
    editor.getSession().setUseWrapMode(false)

    setMode = ->
      mode = $("#user_credential_mode").val()
      if mode == 'java_script'
        editor.getSession().setMode("ace/mode/javascript")
      else
        editor.getSession().setMode("ace/mode/text")

    setMode()
    $("#user_credential_mode").on 'change', setMode

    $textarea = $('#user_credential_credential_value').hide()
    editor.getSession().setValue($textarea.val())

    $textarea.closest('form').on 'submit', ->
      $textarea.val(editor.getSession().getValue())

$ ->
  Utils.registerPage(UserCredentialPage, forPathsMatching: /^user_credentials\/(\d+|new)/)
