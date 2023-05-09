this.AgentShowPage = class AgentShowPage {
  constructor() {
    let tab;
    $(".agent-show #show-tabs a[href='#logs'], #logs .refresh").on(
      "click",
      this.fetchLogs
    );
    $(".agent-show #logs .clear").on("click", this.clearLogs);
    $(".agent-show #memory .clear").on("click", this.clearMemory);
    $("#toggle-memory").on("click", this.toggleMemory);

    // Trigger tabs when navigated to.
    if (
      (tab = __guard__(window.location.href.match(/tab=(\w+)\b/i), (x) => x[1]))
    ) {
      if (["details", "logs"].includes(tab)) {
        $(`.agent-show .nav-pills li a[href='#${tab}']`).click();
      }
    }
  }

  fetchLogs(e) {
    const agentId = $(e.target).closest("[data-agent-id]").data("agent-id");
    e.preventDefault();
    $("#logs .spinner").show();
    $("#logs .refresh, #logs .clear").hide();
    return $.get(`/agents/${agentId}/logs`, (html) => {
      $("#logs .logs").html(html);
      $("#logs .logs .show-log-details").each(function () {
        const $button = $(this);
        return $button.on("click", function (e) {
          e.preventDefault();
          return Utils.showDynamicModal("<pre></pre>", {
            title: $button.data("modal-title"),
            body(body) {
              return $(body).find("pre").text($button.data("modal-content"));
            },
          });
        });
      });

      return $("#logs .spinner")
        .stop(true, true)
        .fadeOut(() => $("#logs .refresh, #logs .clear").show());
    });
  }

  clearLogs(e) {
    if (confirm("Are you sure you want to clear all logs for this Agent?")) {
      const agentId = $(e.target).closest("[data-agent-id]").data("agent-id");
      e.preventDefault();
      $("#logs .spinner").show();
      $("#logs .refresh, #logs .clear").hide();
      return $.post(
        `/agents/${agentId}/logs/clear`,
        { _method: "DELETE" },
        (html) => {
          $("#logs .logs").html(html);
          $("#show-tabs li a.recent-errors").removeClass("recent-errors");
          return $("#logs .spinner")
            .stop(true, true)
            .fadeOut(() => $("#logs .refresh, #logs .clear").show());
        }
      );
    }
  }

  toggleMemory(e) {
    e.preventDefault();
    if ($("pre.memory").hasClass("hidden")) {
      $("pre.memory").removeClass("hidden");
      return $("#toggle-memory").text("Hide");
    } else {
      $("pre.memory").addClass("hidden");
      return $("#toggle-memory").text("Show");
    }
  }

  clearMemory(e) {
    if (
      confirm(
        "Are you sure you want to completely clear the memory of this Agent?"
      )
    ) {
      const agentId = $(e.target).closest("[data-agent-id]").data("agent-id");
      e.preventDefault();
      $("#memory .spinner").css({ display: "inline-block" });
      $("#memory .clear").hide();
      return $.post(`/agents/${agentId}/memory`, { _method: "DELETE" })
        .done(() =>
          $("#memory .spinner").fadeOut(() =>
            $("#memory + .memory").text("{\n}\n")
          )
        )
        .fail(() =>
          $("#memory .spinner").fadeOut(() =>
            $("#memory .clear").css({ display: "inline-block" })
          )
        );
    }
  }
};

$(() =>
  Utils.registerPage(AgentShowPage, { forPathsMatching: /^agents\/\d+/ })
);

function __guard__(value, transform) {
  return typeof value !== "undefined" && value !== null
    ? transform(value)
    : undefined;
}
