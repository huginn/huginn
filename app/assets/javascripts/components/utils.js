(function () {
  let escapeMap = undefined;
  let createEscaper = undefined;
  const Cls = (this.Utils = class Utils {
    static initClass() {
      // _.escape from underscore: https://github.com/jashkenas/underscore/blob/1e68f06610fa4ecb7f2c45d1eb2ad0173d6a2cc1/underscore.js#L1411-L1436
      escapeMap = {
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        '"': "&quot;",
        "'": "&#x27;",
        "`": "&#x60;",
      };

      createEscaper = function (map) {
        const escaper = (match) => map[match];

        // Regexes for identifying a key that needs to be escaped.
        const source = "(?:" + Object.keys(map).join("|") + ")";
        const testRegexp = RegExp(source);
        const replaceRegexp = RegExp(source, "g");
        return function (string) {
          string = string === null ? "" : "" + string;
          if (testRegexp.test(string)) {
            return string.replace(replaceRegexp, escaper);
          } else {
            return string;
          }
        };
      };

      this.escape = createEscaper(escapeMap);
    }
    static navigatePath(path) {
      if (!path.match(/^\//)) {
        path = "/" + path;
      }
      return (window.location.href = path);
    }

    static currentPath() {
      return window.location.href.replace(/https?:\/\/.*?\//g, "");
    }

    static registerPage(klass, options) {
      if (options == null) {
        options = {};
      }
      if (options.forPathsMatching != null) {
        if (Utils.currentPath().match(options.forPathsMatching)) {
          return (window.currentPage = new klass());
        }
      } else {
        return new klass();
      }
    }

    static showDynamicModal(content, param) {
      if (content == null) {
        content = "";
      }
      if (param == null) {
        param = {};
      }
      const { title, body, onHide } = param;
      $("body").append(`\
<div class="modal fade" tabindex="-1" id='dynamic-modal' role="dialog" aria-labelledby="dynamic-modal-label" aria-hidden="true">
  <div class="modal-dialog modal-lg">
    <div class="modal-content">
      <div class="modal-header">
        <button type="button" class="close" data-dismiss="modal"><span aria-hidden="true">&times;</span><span class="sr-only">Close</span></button>
        <h4 class="modal-title" id="dynamic-modal-label"></h4>
      </div>
      <div class="modal-body">${content}</div>
    </div>
  </div>
</div>\
`);
      const modal = document.querySelector("#dynamic-modal");
      $(modal)
        .find(".modal-title")
        .text(title || "")
        .end()
        .on("hidden.bs.modal", function () {
          $("#dynamic-modal").remove();
          return typeof onHide === "function" ? onHide() : undefined;
        });
      if (typeof body === "function") {
        body(modal.querySelector(".modal-body"));
      }
      return $(modal).modal("show");
    }

    static handleDryRunButton(button, data) {
      if (data == null) {
        data = button.form
          ? $(':input[name!="_method"]', button.form).serialize()
          : "";
      }
      $(button).prop("disabled", true);
      const cleanup = () => $(button).prop("disabled", false);

      const url = $(button).data("action-url");
      const with_event_mode = $(button).data("with-event-mode");

      if (with_event_mode === "no") {
        return this.invokeDryRun(url, data, cleanup);
      }
      return $.ajax(url, {
        method: "GET",
        data: {
          with_event_mode,
          source_ids: $.map($(".link-region select option:selected"), (el) =>
            $(el).val()
          ),
        },
        success: (modal_data) => {
          return Utils.showDynamicModal(modal_data, {
            body: (body) => {
              let previous;
              const form = $(body).find(".dry-run-form");
              const payload_editor = form.find(".payload-editor");

              if ((previous = $(button).data("payload"))) {
                payload_editor.text(previous);
              }

              const editor = window.setupJsonEditor(payload_editor)[0];

              $(body)
                .find(".dry-run-event-sample")
                .click((e) => {
                  e.preventDefault();
                  editor.json = $(e.currentTarget).data("payload");
                  return editor.rebuild();
                });

              form.submit((e) => {
                let dry_run_data;
                e.preventDefault();
                let json = $(e.target).find(".payload-editor").val();
                if (json === "") {
                  json = "{}";
                }
                try {
                  const payload = JSON.parse(
                    json.replace(/\\\\([n|r|t])/g, "\\$1")
                  );
                  if (payload.constructor !== Object) {
                    throw true;
                  }
                  if (Object.keys(payload).length === 0) {
                    json = "";
                  } else {
                    json = JSON.stringify(payload);
                  }
                } catch (error) {
                  alert("Invalid JSON object.");
                  return;
                }
                if (json === "") {
                  if (with_event_mode === "yes") {
                    alert("Event is required for this agent to run.");
                    return;
                  }
                  dry_run_data = data;
                  $(button).data("payload", null);
                } else {
                  dry_run_data = `event=${encodeURIComponent(json)}&${data}`;
                  $(button).data("payload", json);
                }
                return $(body)
                  .closest("[role=dialog]")
                  .on("hidden.bs.modal", () => {
                    return this.invokeDryRun(url, dry_run_data, cleanup);
                  })
                  .modal("hide");
              });
              return $(body)
                .closest("[role=dialog]")
                .on("shown.bs.modal", function () {
                  return $(this).find(".btn-primary").focus();
                });
            },
            title: "Dry Run",
            onHide: cleanup,
          });
        },
      });
    }

    static invokeDryRun(url, data, callback) {
      $("body").css({ cursor: "progress" });
      return $.ajax({ type: "POST", url, dataType: "html", data })
        .always(() => {
          return $("body").css({ cursor: "auto" });
        })
        .done((modal_data) => {
          return Utils.showDynamicModal(modal_data, {
            title: "Dry Run Results",
            onHide: callback,
          });
        })
        .fail(function (xhr, status, error) {
          alert("Error: " + error);
          return callback();
        });
    }

    static select2TagClickHandler(e, elem) {
      if (e.which === 1) {
        return (window.location = $(elem).attr("href"));
      } else {
        return window.open($(elem).attr("href"));
      }
    }
  });
  Cls.initClass();
  return Cls;
})();
