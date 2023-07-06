this.ScenarioFormPage = class ScenarioFormPage {
  constructor() {
    this.enabledSelect2();
  }

  format(icon) {
    const originalOption = icon.element;
    return (
      '<i class="fa ' + $(originalOption).data("icon") + '"></i> ' + icon.text
    );
  }

  enabledSelect2() {
    return $(".select2-fountawesome-icon").select2({
      width: "100%",
      formatResult: this.format,
    });
  }
};

$(() =>
  Utils.registerPage(ScenarioFormPage, { forPathsMatching: /^scenarios/ })
);
