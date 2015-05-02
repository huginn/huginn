#= require ace/ace
#= require ace/mode-javascript.js
#= require ace/mode-markdown.js
#= require_self

# This is not included in the core application.js bundle.

$ ->
  editor = ace.edit("ace-credential-value")
  editor.getSession().setTabSize(2)
  editor.getSession().setUseSoftTabs(true)
  editor.getSession().setUseWrapMode(false)
  editor.setTheme("ace/theme/chrome")

  setMode = ->
    mode = $("#user_credential_mode").val()
    if mode == 'java_script'
      editor.getSession().setMode("ace/mode/javascript")
    else if mode == 'coffee'
      editor.getSession().setMode("ace/mode/coffee")
    else
      editor.getSession().setMode("ace/mode/text")

  setMode()
  $("#user_credential_mode").on 'change', setMode

  $textarea = $('#user_credential_credential_value').hide()
  editor.getSession().setValue($textarea.val())

  $textarea.closest('form').on 'submit', ->
    $textarea.val(editor.getSession().getValue())
