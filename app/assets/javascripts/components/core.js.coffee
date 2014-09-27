$ ->
  # Flash
  if $(".flash").length
    setTimeout((-> $(".flash").slideUp(-> $(".flash").remove())), 5000)

  # Help popovers
  $('.hover-help').popover(trigger: 'hover', html: true)

  # Pressing '/' selects the search box.
  $("body").on "keypress", (e) ->
    if e.keyCode == 47 # The '/' key
      if e.target.nodeName == "BODY"
        e.preventDefault()
        $agentNavigate.focus()

  # Select2 Selects
  $(".select2").select2(width: 'resolve')

  # Helper for selecting text when clicked
  $('.selectable-text').each ->
    $(this).click ->
      range = document.createRange()
      range.setStartBefore(this.firstChild)
      range.setEndAfter(this.lastChild)
      sel = window.getSelection()
      sel.removeAllRanges();
      sel.addRange(range)

  # Agent navbar dropdown
  $('.navbar .dropdown.dropdown-hover').hover (-> $(this).addClass('open')), (-> $(this).removeClass('open'))