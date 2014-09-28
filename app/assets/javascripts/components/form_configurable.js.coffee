$ ->
  $.fn.serializeObject = ->
    o = {}
    a = @serializeArray()
    $.each a, ->
      if o[@name] isnt `undefined`
        o[@name] = [o[@name]]  unless o[@name].push
        o[@name].push @value or ""
      else
        o[@name] = @value or ""
      return
    o

  getFormData = (elem) ->
    form_data = $("#edit_agent, #new_agent").serializeObject()
    attribute = $(elem).data('attribute')
    form_data['attribute'] = attribute
    delete form_data['_method']
    form_data

  window.initializeFormCompletable = ->
    returnedResults = {}
    completableDefaultOptions = (input) ->
      results: [
        (returnedResults[$(input).data('attribute')] || {text: 'Options', children: [{id: '', text: 'loading ...'}]})
        {
          text: 'Current',
          children: [id: $(input).val(), text: $(input).val()]
        },
        {
          text: 'Custom',
          children: [id: 'manualInput', text: 'manual input']
        },
      ]

    $("input[role=validatable], select[role=validatable]").on 'change', (e) =>
      form_data = getFormData(e.currentTarget)
      form_group = $(e.currentTarget).closest('.form-group')
      $.ajax '/agents/validate',
        type: 'POST',
        data: form_data
        success: (data) ->
          form_group.addClass('has-feedback').removeClass('has-error')
          form_group.find('span').addClass('hidden')
          form_group.find('.glyphicon-ok').removeClass('hidden')
        error: (data) ->
          form_group.addClass('has-feedback').addClass('has-error')
          form_group.find('span').addClass('hidden')
          form_group.find('.glyphicon-remove').removeClass('hidden')

    $("input[role=validatable], select[role=validatable]").trigger('change')

    $.each $("input[role~=completable]"), (i, input) ->
      $(input).select2
        data: ->
          completableDefaultOptions(input)

    $("input[role~=completable]").on 'select2-open', (e) ->
      form_data = getFormData(e.currentTarget)
      return if returnedResults[form_data.attribute]

      $.ajax '/agents/complete',
        type: 'POST',
        data: form_data
        success: (data) ->
          console.log data
          returnedResults[form_data.attribute] = {text: 'Options', children: $.map(data, (d) -> {id: d.value, text: d.name})}
          $(e.currentTarget).trigger('change')
          $(e.currentTarget).select2('open')