$ ->
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
        (returnedResults[$(input).data('attribute')] || {text: 'Options', children: [{id: undefined, text: 'loading ...'}]}),
        {
          text: 'Current',
          children: [id: $(input).val(), text: $(input).val()]
        },
        {
          text: 'Custom',
          children: [id: 'manualInput', text: 'manual input']
        },
      ]

    $("input[role~=validatable], select[role~=validatable]").on 'change', (e) =>
      form_data = getFormData(e.currentTarget)
      form_group = $(e.currentTarget).closest('.form-group')
      $.ajax '/agents/validate',
        type: 'POST',
        data: form_data
        success: (data) ->
          form_group.addClass('has-feedback').removeClass('has-error')
          form_group.find('span').addClass('hidden')
          form_group.find('.glyphicon-ok').removeClass('hidden')
          returnedResults = {}
        error: (data) ->
          form_group.addClass('has-feedback').addClass('has-error')
          form_group.find('span').addClass('hidden')
          form_group.find('.glyphicon-remove').removeClass('hidden')
          returnedResults = {}

    $("input[role~=validatable], select[role~=validatable]").trigger('change')

    $.each $("input[role~=completable]"), (i, input) ->
      $(input).select2(
        data: ->
          completableDefaultOptions(input)
      ).on("change", (e) ->
        if e.added && e.added.id == 'manualInput'
          $(e.currentTarget).select2("destroy")
          $(e.currentTarget).val(e.removed.id)
      )

    updateDropdownData = (form_data, element, data) ->
      returnedResults[form_data.attribute] = {text: 'Options', children: data}
      $(element).trigger('change')
      $("input[role~=completable]").off 'select2-opening', select2OpeningCallback
      $(element).select2('open')
      $("input[role~=completable]").on 'select2-opening', select2OpeningCallback

    select2OpeningCallback = (e) ->
      form_data = getFormData(e.currentTarget)
      delete returnedResults[form_data.attribute] if returnedResults[form_data.attribute] && !$(e.currentTarget).data('cacheResponse')
      return if returnedResults[form_data.attribute]

      $.ajax '/agents/complete',
        type: 'POST',
        data: form_data
        success: (data) ->
          updateDropdownData(form_data, e.currentTarget, data)
        error: (data) ->
          updateDropdownData(form_data, e.currentTarget, [{id: undefined, text: 'Error loading data.'}])

    $("input[role~=completable]").on 'select2-opening', select2OpeningCallback

    $("input[type=radio][role~=form-configurable]").change (e) ->
      input = $(e.currentTarget).parents().siblings("input[data-attribute=#{$(e.currentTarget).data('attribute')}]")
      if $(e.currentTarget).val() == 'manual'
        input.removeClass('hidden')
      else
        input.val($(e.currentTarget).val())
        input.addClass('hidden')
