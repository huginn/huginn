this.ScenarioShowPage = class ScenarioShowPage {
  constructor() {
    this.changeModalText();
  }

  changeModalText() {
    $("#disable-all").click(function () {
      $("#enable-disable-agents .modal-body").text(
        "Would you like to disable all agents?"
      );
      return $("#scenario-disabled-value").val("true");
    });
    return $("#enable-all").click(function () {
      $("#enable-disable-agents .modal-body").text(
        "Would you like to enable all agents?"
      );
      return $("#scenario-disabled-value").val("false");
    });
  }
};

$(() =>
  Utils.registerPage(ScenarioShowPage, { forPathsMatching: /^scenarios/ })
);
