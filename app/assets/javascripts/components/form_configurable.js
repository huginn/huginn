$(function () {
  const getFormData = function (elem) {
    const form_data = $("#edit_agent, #new_agent").serializeObject();
    const attribute = $(elem).data("attribute");
    form_data["attribute"] = attribute;
    delete form_data["_method"];
    return form_data;
  };

  return (window.initializeFormCompletable = function () {
    $("input[role~=validatable], select[role~=validatable]").on(
      "change",
      (e) => {
        const form_data = getFormData(e.currentTarget);
        const form_group = $(e.currentTarget).closest(".form-group");
        return $.ajax("/agents/validate", {
          type: "POST",
          data: form_data,
          success: (data) => {
            form_group.addClass("has-feedback").removeClass("has-error");
            form_group.find("span").addClass("hidden");
            form_group.find(".glyphicon-ok").removeClass("hidden");
          },
          error: (data) => {
            form_group.addClass("has-feedback").addClass("has-error");
            form_group.find("span").addClass("hidden");
            form_group.find(".glyphicon-remove").removeClass("hidden");
          },
        });
      }
    );

    $("input[role~=validatable], select[role~=validatable]").trigger("change");

    $.each($("select[role~=completable]"), (i, select) => {
      const $select = $(select);
      const value = $select.data("value");

      const setValue = (value) => {
        if (
          $select
            .find("option")
            .toArray()
            .some((option) => option.value == value)
        ) {
          $select.val(value).trigger("change");
        } else {
          $select
            .append(new Option(value, value, true, true))
            .trigger("change");
        }
      };

      if ($select.data("cacheResponse")) {
        const loadData = (data) => {
          $select.select2({ data: data, tags: true });
          setValue(value);
        };

        $.ajax("/agents/complete", {
          type: "POST",
          data: getFormData(select),
          success: (data) => loadData(data),
          error: (data) =>
            loadData([{ id: undefined, text: "Error loading data." }]),
        });
      } else {
        $select.select2({
          ajax: {
            url: "/agents/complete",
            type: "POST",
            data: (params) => getFormData(select),
            processResults: (data) => ({ results: data }),
          },
          tags: true,
        });
        setValue(value);
      }
    });

    $("input[type=radio][role~=form-configurable]").change(function (e) {
      const input = $(e.currentTarget)
        .parents()
        .siblings(
          `input[data-attribute=${$(e.currentTarget).data("attribute")}]`
        );
      if ($(e.currentTarget).val() === "manual") {
        input.removeClass("hidden");
      } else {
        input.val($(e.currentTarget).val());
        input.addClass("hidden");
      }
    });
  });
});
