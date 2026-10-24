this.AgentIndexPage = class AgentIndexPage {
  constructor() {
    const form = $(".agent-filter-form");
    form.find(".agent-filter-select").select2({
      width: "100%",
      templateResult: this.format,
      templateSelection: this.format,
    });
    form.on("change", "select, input[type=checkbox]", () =>
      form.trigger("submit"),
    );
    form.on("submit", () => {
      const scenario = form.find("[name=scenario_id]").val();
      if (scenario !== "none") return;
      form.find("[name=scenario_id]").prop("disabled", true);
      $("<input>")
        .attr({ type: "hidden", name: "without_scenario", value: "1" })
        .appendTo(form);
    });
  }

  format(item) {
    if (!item.element || item.element.tagName === "OPTGROUP") return item.text;
    const result = $("<span>").addClass("agent-filter-choice");
    if (item.id === "none") result.addClass("agent-filter-unassigned");
    const label = item.element.dataset.label;
    if (label)
      $("<span>").addClass("agent-filter-label").html(label).appendTo(result);
    else $("<span>").text(item.text).appendTo(result);
    const count = item.element.dataset.count;
    if (count !== undefined)
      $("<span>").addClass("agent-filter-count").text(count).appendTo(result);
    return result;
  }
};

$(() =>
  Utils.registerPage(AgentIndexPage, {
    forPathsMatching: /^agents\/?(?:[?#]|$)/,
  }),
);
