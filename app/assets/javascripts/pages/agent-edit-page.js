(function () {
  let formatAgentForSelect = undefined;
  const Cls = (this.AgentEditPage = class AgentEditPage {
    static initClass() {
      formatAgentForSelect = function (agent) {
        const originalOption = agent.element;
        const description = agent.element[0].title;
        return "<strong>" + agent.text + "</strong><br/>" + description;
      };
    }
    constructor() {
      this.invokeDryRun = this.invokeDryRun.bind(this);
      $("#agent_source_ids").on("change", this.showEventDescriptions);
      this.showCorrectRegionsOnStartup();
      $("form.agent-form").on("submit", () => this.updateFromEditors());

      // Validate agents_options Json on form submit
      $("form.agent-form").submit(function (e) {
        for (const textarea of $("textarea.live-json-editor").toArray()) {
          try {
            JSON.parse($(textarea).val());
          } catch (err) {
            e.preventDefault();
            alert(
              "Sorry, there appears to be an error in your JSON input. Please fix it before continuing."
            );
            return false;
          }
        }

        if (
          $(".link-region").length &&
          $(".link-region").data("can-receive-events") === false
        ) {
          $(".link-region .select2-linked-tags option:selected").removeAttr(
            "selected"
          );
        }

        if (
          $(".control-link-region").length &&
          $(".control-link-region").data("can-control-other-agents") === false
        ) {
          $(
            ".control-link-region .select2-linked-tags option:selected"
          ).removeAttr("selected");
        }

        if (
          $(".event-related-region").length &&
          $(".event-related-region").data("can-create-events") === false
        ) {
          return $(
            ".event-related-region .select2-linked-tags option:selected"
          ).removeAttr("selected");
        }
      });

      $("#agent_name").each(function () {
        // Select the number suffix if this is a cloned agent.
        let matches;
        if ((matches = this.value.match(/ \(\d+\)$/))) {
          this.focus();
          if (this.selectionStart != null) {
            this.selectionStart = matches.index;
            return (this.selectionEnd = this.value.length);
          }
        }
      });

      // The type selector is only available on the new agent form.
      if ($("#agent_type").length) {
        $("#agent_type").on("change", () => this.handleTypeChange(false));
        this.handleTypeChange(true);

        // Update the dropdown to match agent description as well as agent name
        $("select#agent_type").select2({
          width: "resolve",
          formatResult: formatAgentForSelect,
          escapeMarkup: (m) => m,
          matcher: (params, data) => {
            const term = params.term;
            if (term == null) return data;
            const upperTerm = term.toUpperCase();
            return data.text.toUpperCase().indexOf(upperTerm) >= 0 ||
              data.title.toUpperCase().indexOf(upperTerm) >= 0
              ? data
              : null;
          },
        });
      } else {
        this.enableDryRunButton();
        this.buildAce();
      }
    }

    handleTypeChange(firstTime) {
      $(".event-descriptions").html("").hide();
      const type = $("#agent_type").val();

      if (type === "Agent") {
        $(".agent-settings").hide();
        return $(".description").hide();
      } else {
        $(".agent-settings").show();
        $("#agent-spinner").fadeIn();
        if (!firstTime) {
          $(".model-errors").hide();
        }
        return $.getJSON("/agents/type_details", { type }, (json) => {
          if (json.can_be_scheduled) {
            if (firstTime) {
              this.showSchedule();
            } else {
              this.showSchedule(json.default_schedule);
            }
          } else {
            this.hideSchedule();
          }

          if (json.can_receive_events) {
            this.showLinks();
          } else {
            this.hideLinks();
          }

          if (json.can_control_other_agents) {
            this.showControlLinks();
          } else {
            this.hideControlLinks();
          }

          if (json.can_create_events) {
            this.showEventCreation();
          } else {
            this.hideEventCreation();
          }

          if (json.description_html != null) {
            $(".description").show().html(json.description_html);
          }

          if (!firstTime) {
            if (json.oauthable != null) {
              $(".oauthable-form").html(json.oauthable);
            }
            if (json.form_options != null) {
              $(".agent-options").html(json.form_options);
            }
            window.jsonEditor = setupJsonEditor()[0];
          }

          this.enableDryRunButton();
          this.buildAce();

          window.initializeFormCompletable();

          return $("#agent-spinner").stop(true, true).fadeOut();
        });
      }
    }

    hideSchedule() {
      $(".schedule-region .can-be-scheduled").hide();
      return $(".schedule-region .cannot-be-scheduled").show();
    }

    showSchedule(defaultSchedule = null) {
      if (defaultSchedule != null) {
        $(".schedule-region select").val(defaultSchedule).change();
      }
      $(".schedule-region .can-be-scheduled").show();
      return $(".schedule-region .cannot-be-scheduled").hide();
    }

    hideLinks() {
      $(".link-region .select2-container").hide();
      $(".link-region .propagate-immediately").hide();
      $(".link-region .cannot-receive-events").show();
      return $(".link-region").data("can-receive-events", false);
    }

    showLinks() {
      $(".link-region .select2-container").show();
      $(".link-region .propagate-immediately").show();
      $(".link-region .cannot-receive-events").hide();
      $(".link-region").data("can-receive-events", true);
      return this.showEventDescriptions();
    }

    hideControlLinks() {
      $(".control-link-region").hide();
      return $(".control-link-region").data("can-control-other-agents", false);
    }

    showControlLinks() {
      $(".control-link-region").show();
      return $(".control-link-region").data("can-control-other-agents", true);
    }

    hideEventCreation() {
      $(".event-related-region .select2-container").hide();
      $(".event-related-region .cannot-create-events").show();
      return $(".event-related-region").data("can-create-events", false);
    }

    showEventCreation() {
      $(".event-related-region .select2-container").show();
      $(".event-related-region .cannot-create-events").hide();
      return $(".event-related-region").data("can-create-events", true);
    }

    showEventDescriptions() {
      if ($("#agent_source_ids").val()) {
        return $.getJSON(
          "/agents/event_descriptions",
          { ids: $("#agent_source_ids").val().join(",") },
          (json) => {
            if (json.description_html != null) {
              return $(".event-descriptions")
                .show()
                .html(json.description_html);
            } else {
              return $(".event-descriptions").hide();
            }
          }
        );
      } else {
        return $(".event-descriptions").html("").hide();
      }
    }

    showCorrectRegionsOnStartup() {
      if ($(".schedule-region")) {
        if ($(".schedule-region").data("can-be-scheduled") === true) {
          this.showSchedule();
        } else {
          this.hideSchedule();
        }
      }

      if ($(".link-region")) {
        if ($(".link-region").data("can-receive-events") === true) {
          this.showLinks();
        } else {
          this.hideLinks();
        }
      }

      if ($(".control-link-region")) {
        if (
          $(".control-link-region").data("can-control-other-agents") === true
        ) {
          this.showControlLinks();
        } else {
          this.hideControlLinks();
        }
      }

      if ($(".event-related-region")) {
        if ($(".event-related-region").data("can-create-events") === true) {
          return this.showEventCreation();
        } else {
          return this.hideEventCreation();
        }
      }
    }

    buildAce() {
      return $(".ace-editor").each(function () {
        if (!$(this).data("initialized")) {
          const $this = $(this);
          $this.data("initialized", true);
          const $source = $($this.data("source")).hide();
          const editor = ace.edit(this);
          $this.data("ace-editor", editor);
          const session = editor.getSession();
          session.setTabSize(2);
          session.setUseSoftTabs(true);
          session.setUseWrapMode(false);

          const setSyntax = function () {
            let mode, theme;
            if ((mode = $this.data("mode"))) {
              session.setMode("ace/mode/" + mode);
            }

            if ((theme = $this.data("theme"))) {
              editor.setTheme("ace/theme/" + theme);
            }

            if ((mode = $("[name='agent[options][language]']").val())) {
              switch (mode) {
                case "JavaScript":
                  return session.setMode("ace/mode/javascript");
                case "CoffeeScript":
                  return session.setMode("ace/mode/coffee");
                default:
                  return session.setMode("ace/mode/" + mode);
              }
            }
          };

          $("[name='agent[options][language]']").on("change", setSyntax);
          setSyntax();

          return session.setValue($source.val());
        }
      });
    }

    updateFromEditors() {
      return $(".ace-editor").each(function () {
        const $source = $($(this).data("source"));
        return $source.val($(this).data("ace-editor").getSession().getValue());
      });
    }

    enableDryRunButton() {
      return $(".agent-dry-run-button")
        .prop("disabled", false)
        .off()
        .on("click", this.invokeDryRun);
    }

    disableDryRunButton() {
      return $(".agent-dry-run-button").prop("disabled", true);
    }

    invokeDryRun(e) {
      e.preventDefault();
      this.updateFromEditors();
      return Utils.handleDryRunButton(e.currentTarget);
    }
  });
  Cls.initClass();
  return Cls;
})();

$(() => Utils.registerPage(AgentEditPage, { forPathsMatching: /^agents/ }));
