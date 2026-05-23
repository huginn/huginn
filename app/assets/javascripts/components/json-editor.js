(function () {
  function whenJsonEditorReady() {
    if (typeof window.createVanillaJSONEditor === "function") {
      return Promise.resolve(window.createVanillaJSONEditor);
    }

    if (window.vanillaJsonEditorReadyPromise == null) {
      window.vanillaJsonEditorReadyPromise = new Promise((resolve) => {
        window.addEventListener(
          "vanilla-jsoneditor:ready",
          () => resolve(window.createVanillaJSONEditor),
          { once: true },
        );
      });
    }

    return window.vanillaJsonEditorReadyPromise;
  }

  function normalizedValue(value) {
    return typeof value === "string" ? value.trim() : "";
  }

  function contentToTextareaValue(content) {
    if (content == null) {
      return "";
    }

    if (content.json !== undefined) {
      return JSON.stringify(content.json, null, 2);
    }

    return content.text || "";
  }

  function textContent(text) {
    return { text: text == null ? "" : String(text) };
  }

  function jsonContent(json) {
    return { json };
  }

  function tryParseJson(text) {
    try {
      return JSON.parse(text);
    } catch (_error) {
      return undefined;
    }
  }

  function createElement(tag, attrs) {
    return Object.assign(document.createElement(tag), attrs);
  }

  class PlainJsonEditor {
    constructor(source) {
      this.source = source;
      this.content = this.initialContent(source.value);
      this.status =
        this.content.text !== undefined ? "Invalid JSON" : "Valid JSON";
    }

    setValue(value) {
      this.source.value = value;
    }

    initialContent(value) {
      const text = normalizedValue(value);
      if (text === "") return jsonContent({});

      const parsed = tryParseJson(text);
      return parsed === undefined ? textContent(value) : jsonContent(parsed);
    }

    currentJson() {
      if (this.content.json !== undefined) {
        return this.content.json;
      }

      return tryParseJson(this.content.text);
    }

    updateContent(content) {
      this.content = content;
      this.setValue(contentToTextareaValue(content));
      this.status = content.text !== undefined ? "Invalid JSON" : "Valid JSON";
    }

    rebuild() {
      if (this.json === undefined) return;

      const nextContent =
        typeof this.json === "string"
          ? this.initialContent(this.json)
          : jsonContent(this.json);

      this.updateContent(nextContent);
    }
  }

  class VanillaJsonEditor extends PlainJsonEditor {
    constructor(source) {
      super(source);
      this.mode = this.content.text !== undefined ? "text" : "tree";
      this.pendingMode = this.mode;
      this.shell = null;
      this.toolbar = null;
      this.statusEl = null;
      this.host = null;
      this.resizeHandle = null;
      this.treeButton = null;
      this.textButton = null;
      this.formatButton = null;
      this.expandButton = null;
      this.backdrop = null;
      this.fullscreen = false;
      this.editor = null;
      this.escapeHandler = (event) => {
        if (event.key === "Escape" && this.fullscreen) {
          this.setFullscreen(false);
        }
      };

      whenJsonEditorReady().then((createJSONEditor) =>
        this.mount(createJSONEditor),
      );
    }

    mount(createJSONEditor) {
      if (this.editor) return;

      this.shell = createElement("div", { className: "json-editor-shell" });
      this.toolbar = createElement("div", { className: "json-editor-toolbar" });
      this.statusEl = createElement("span", { className: "json-editor-status" });
      this.host = createElement("div", { className: "json-editor-host" });
      this.resizeHandle = createElement("div", { className: "json-editor-resize" });
      const buttons = createElement("div", { className: "json-editor-actions" });

      this.treeButton = this.createModeButton("Tree", () =>
        this.setMode("tree"),
      );
      this.textButton = this.createModeButton("Text", () =>
        this.setMode("text"),
      );

      this.formatButton = createElement("button", {
        type: "button",
        className: "btn btn-default btn-xs",
        textContent: "Format",
      });
      this.formatButton.addEventListener("click", () => this.format());

      this.expandButton = createElement("button", {
        type: "button",
        className: "btn btn-default btn-xs json-editor-expand",
        title: "Toggle fullscreen",
        innerHTML: '<span class="glyphicon glyphicon-resize-full"></span>',
      });
      this.expandButton.addEventListener("click", () =>
        this.setFullscreen(!this.fullscreen),
      );

      buttons.append(
        this.treeButton,
        this.textButton,
        this.formatButton,
        this.expandButton,
      );
      this.toolbar.append(this.statusEl, buttons);
      this.host.style.height = `${this.editorHeight()}px`;
      this.shell.append(this.toolbar, this.host, this.resizeHandle);
      this.bindResizeHandle();

      this.source.after(this.shell);
      this.source.style.display = "none";

      this.editor = createJSONEditor({
        target: this.host,
        props: {
          content: this.contentForMode(this.content, this.mode),
          mode: this.mode,
          indentation: 2,
          tabSize: 2,
          mainMenuBar: false,
          navigationBar: false,
          statusBar: false,
          askToFormat: false,
          onChange: (updatedContent, _previousContent, status) => {
            this.content = updatedContent;
            this.status = status.contentErrors ? "Invalid JSON" : "Valid JSON";
            this.syncSource();
            this.updateStatus();
          },
          onChangeMode: (mode) => {
            this.mode = mode;
            this.updateModeButtons();
          },
        },
      });

      this.syncSource();
      this.updateModeButtons();
      this.updateStatus();
      this.rebuild();
    }

    createModeButton(label, onClick) {
      const button = createElement("button", {
        type: "button",
        className: "btn btn-default btn-xs json-editor-mode",
        textContent: label,
      });
      button.addEventListener("click", onClick);
      return button;
    }

    editorHeight() {
      const lineHeight = 20;
      const viewportCap = Math.floor(window.innerHeight * 0.8);
      const baseHeight =
        Number(this.source.dataset.height) ||
        (Number(this.source.getAttribute("rows")) || 12) * lineHeight;
      const contentLines = contentToTextareaValue(this.content).split("\n").length;
      const contentHeight = (contentLines + 1) * lineHeight;
      return Math.min(viewportCap, Math.max(200, baseHeight, contentHeight));
    }

    contentForMode(content, mode) {
      if (mode === "text") {
        return content.text !== undefined
          ? content
          : textContent(JSON.stringify(content.json, null, 2));
      }

      if (content.json !== undefined) {
        return content;
      }

      const parsed = tryParseJson(content.text);
      return parsed === undefined ? jsonContent({}) : jsonContent(parsed);
    }

    syncSource() {
      this.setValue(contentToTextareaValue(this.content));
    }

    updateStatus() {
      if (this.statusEl == null) return;

      const invalid = this.status === "Invalid JSON";
      this.shell.classList.toggle("has-error", invalid);
      this.statusEl.classList.toggle("is-error", invalid);
      this.statusEl.textContent = this.status;
    }

    updateModeButtons() {
      if (this.treeButton == null || this.textButton == null) return;

      this.treeButton.classList.toggle("active", this.mode === "tree");
      this.textButton.classList.toggle("active", this.mode === "text");
    }

    setMode(mode) {
      this.pendingMode = mode;
      if (!this.editor) return;

      let nextContent = this.content;
      if (mode === "tree" && nextContent.text !== undefined) {
        const parsed = tryParseJson(nextContent.text);
        if (parsed === undefined) {
          this.status = "Invalid JSON";
          this.updateStatus();
          return;
        }
        nextContent = jsonContent(parsed);
      }

      this.content = nextContent;
      this.mode = mode;
      this.editor.updateProps({
        content: this.contentForMode(nextContent, mode),
        mode,
      });
      this.syncSource();
      this.updateModeButtons();
      this.updateStatus();
    }

    bindResizeHandle() {
      const minHeight = 200;
      const handle = this.resizeHandle;

      const onPointerMove = (event) => {
        const rect = this.host.getBoundingClientRect();
        const next = Math.max(minHeight, event.clientY - rect.top);
        this.host.style.height = `${next}px`;
      };

      const onPointerUp = (event) => {
        handle.releasePointerCapture(event.pointerId);
        handle.removeEventListener("pointermove", onPointerMove);
        handle.removeEventListener("pointerup", onPointerUp);
        handle.removeEventListener("pointercancel", onPointerUp);
      };

      handle.addEventListener("pointerdown", (event) => {
        if (this.fullscreen) return;

        event.preventDefault();
        handle.setPointerCapture(event.pointerId);
        handle.addEventListener("pointermove", onPointerMove);
        handle.addEventListener("pointerup", onPointerUp);
        handle.addEventListener("pointercancel", onPointerUp);
      });
    }

    setFullscreen(on) {
      if (this.shell == null) return;

      this.fullscreen = !!on;
      this.shell.classList.toggle("is-fullscreen", this.fullscreen);

      if (this.fullscreen) {
        if (this.backdrop == null) {
          this.backdrop = createElement("div", {
            className: "json-editor-fullscreen-backdrop",
          });
          this.backdrop.addEventListener("click", () =>
            this.setFullscreen(false),
          );
        }
        document.body.classList.add("json-editor-fullscreen-open");
        document.body.append(this.backdrop);
        document.addEventListener("keydown", this.escapeHandler);
        this.expandButton.innerHTML =
          '<span class="glyphicon glyphicon-resize-small"></span>';
      } else {
        if (this.backdrop != null) {
          this.backdrop.remove();
        }
        document.body.classList.remove("json-editor-fullscreen-open");
        document.removeEventListener("keydown", this.escapeHandler);
        this.expandButton.innerHTML =
          '<span class="glyphicon glyphicon-resize-full"></span>';
      }
    }

    format() {
      const json = this.currentJson();
      if (json === undefined) {
        this.status = "Invalid JSON";
        this.updateStatus();
        return;
      }

      const nextContent =
        this.mode === "text"
          ? textContent(JSON.stringify(json, null, 2))
          : jsonContent(json);

      this.content = nextContent;
      this.status = "Valid JSON";
      if (this.editor) {
        this.editor.updateProps({
          content: nextContent,
          mode: this.mode,
        });
      }
      this.syncSource();
      this.updateStatus();
    }

    rebuild() {
      if (this.json === undefined) return;

      const nextContent =
        typeof this.json === "string"
          ? this.initialContent(this.json)
          : jsonContent(this.json);

      try {
        this.content = nextContent;
        this.status =
          nextContent.text !== undefined ? "Invalid JSON" : "Valid JSON";
        if (this.editor) {
          const mode =
            nextContent.text !== undefined ? "text" : this.pendingMode;
          this.mode = mode;
          this.editor.updateProps({
            content: this.contentForMode(nextContent, mode),
            mode,
          });
          this.updateModeButtons();
        }
        this.syncSource();
        this.updateStatus();
      } catch (_error) {
        this.status = "Invalid JSON";
        this.updateStatus();
      }
    }
  }

  const instances = new WeakMap();

  function toElementArray(input) {
    if (input == null) {
      return Array.from(
        document.querySelectorAll(".live-json-editor, .payload-editor"),
      );
    }
    if (input instanceof Element) {
      return [input];
    }
    if (input.jquery) {
      return input.toArray();
    }
    return Array.from(input);
  }

  window.setupJsonEditor = function (editorsInput) {
    const elements = toElementArray(editorsInput);

    return elements.map((element) => {
      let instance = instances.get(element);
      if (!instance) {
        instance = new VanillaJsonEditor(element);
        instances.set(element, instance);
      }
      return instance;
    });
  };

  document.addEventListener("DOMContentLoaded", () => {
    window.jsonEditor = window.setupJsonEditor()[0];
  });
})();
