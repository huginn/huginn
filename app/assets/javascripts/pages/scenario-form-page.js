this.ScenarioFormPage = class ScenarioFormPage {
  constructor() {
    this.enabledSelect2();
  }

  format(icon) {
    if (!icon.element) return icon.text;

    return [
      ...$(document.createElement('i')).addClass(`fa-solid ${icon.element.dataset.icon}`),
      document.createTextNode(` ${icon.text}`),
    ];
  }

  enabledSelect2() {
    return $(".select2-fontawesome-icon").select2({
      width: "100%",
      templateResult: this.format,
      templateSelection: this.format,
    });
  }
};

$(() =>
  Utils.registerPage(ScenarioFormPage, { forPathsMatching: /^scenarios/ })
);
