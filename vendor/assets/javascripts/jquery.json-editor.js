
/*
  Copyright (c) 2014, Andrew Cantino
  Copyright (c) 2009, Andrew Cantino & Kyle Maxwell

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.




  You will probably need to tell the editor where to find its 'add' and 'delete' images.  In your
  code, before you make the editor, do something like this:
     JSONEditor.prototype.ADD_IMG = '/javascripts/jsoneditor/add.png';
     JSONEditor.prototype.DELETE_IMG = '/javascripts/jsoneditor/delete.png';

  You can enable or disable visual truncation in the structure editor with the following:
    myEditor.doTruncation(false);
    myEditor.doTruncation(true); // The default

  You can show a 'w'ipe button that does a more aggressive delete by calling showWipe(true|false) or by passing in 'showWipe: true'.
*/


(function() {

  window.JSONEditor = (function() {

    function JSONEditor(wrapped, options) {
      if (options == null) {
        options = {};
      }
      this.builderShowing = true;
      this.ADD_IMG || (this.ADD_IMG = options.ADD_IMG || 'lib/images/add.png');
      this.DELETE_IMG || (this.DELETE_IMG = options.DELETE_IMG || 'lib/images/delete.png');
      this.functionButtonsEnabled = false;
      this._doTruncation = true;
      this._showWipe = options.showWipe;
      this.history = [];
      this.historyPointer = -1;
      if (wrapped === null || (wrapped.get && wrapped.get(0) === null)) {
        throw "Must provide an element to wrap.";
      }
      this.wrapped = $(wrapped);
      this.wrapped.wrap('<div class="json-editor"></div>');
      this.container = $(this.wrapped.parent());
      this.wrapped.hide();
      this.container.css("position", "relative");
      this.doAutoFocus = false;
      this.editingUnfocused();
      this.rebuild();
    }

    JSONEditor.prototype.braceUI = function(key, struct) {
      var _this = this;
      return $('<a class="icon" href="#"><strong>{</strong></a>').click(function(e) {
        e.preventDefault();
        struct[key] = {
          "??": struct[key]
        };
        _this.doAutoFocus = true;
        return _this.rebuild();
      });
    };

    JSONEditor.prototype.bracketUI = function(key, struct) {
      var _this = this;
      return $('<a class="icon" href="#"><strong>[</a>').click(function(e) {
        e.preventDefault();
        struct[key] = [struct[key]];
        _this.doAutoFocus = true;
        return _this.rebuild();
      });
    };

    JSONEditor.prototype.deleteUI = function(key, struct, fullDelete) {
      var _this = this;
      return $("<a class='icon' href='#' title='delete'><img src='" + this.DELETE_IMG + "' border=0 /></a>").click(function(e) {
        var didSomething, subkey, subval, _ref;
        e.preventDefault();
        if (!fullDelete) {
          didSomething = false;
          if (struct[key] instanceof Array) {
            if (struct[key].length > 0) {
              struct[key] = struct[key][0];
              didSomething = true;
            }
          } else if (struct[key] instanceof Object) {
            _ref = struct[key];
            for (subkey in _ref) {
              subval = _ref[subkey];
              struct[key] = struct[key][subkey];
              didSomething = true;
              break;
            }
          }
          if (didSomething) {
            _this.rebuild();
            return;
          }
        }
        if (struct instanceof Array) {
          struct.splice(key, 1);
        } else {
          delete struct[key];
        }
        return _this.rebuild();
      });
    };

    JSONEditor.prototype.wipeUI = function(key, struct) {
      var _this = this;
      return $('<a class="icon" href="#" title="wipe"><strong>W</strong></a>').click(function(e) {
        e.preventDefault();
        if (struct instanceof Array) {
          struct.splice(key, 1);
        } else {
          delete struct[key];
        }
        return _this.rebuild();
      });
    };

    JSONEditor.prototype.addUI = function(struct) {
      var _this = this;
      return $("<a class='icon' href='#' title='add'><img src='" + this.ADD_IMG + "' border=0/></a>").click(function(e) {
        e.preventDefault();
        if (struct instanceof Array) {
          struct.push('??');
        } else {
          struct['??'] = '??';
        }
        _this.doAutoFocus = true;
        return _this.rebuild();
      });
    };

    JSONEditor.prototype.undo = function() {
      if (this.saveStateIfTextChanged()) {
        if (this.historyPointer > 0) {
          this.historyPointer -= 1;
        }
        return this.restore();
      }
    };

    JSONEditor.prototype.redo = function() {
      if (this.historyPointer + 1 < this.history.length) {
        if (this.saveStateIfTextChanged()) {
          this.historyPointer += 1;
          return this.restore();
        }
      }
    };

    JSONEditor.prototype.showBuilder = function() {
      if (this.checkJsonInText()) {
        this.setJsonFromText();
        this.rebuild();
        this.wrapped.hide();
        this.builder.show();
        return true;
      } else {
        alert("Sorry, there appears to be an error in your JSON input.  Please fix it before continuing.");
        return false;
      }
    };

    JSONEditor.prototype.showText = function() {
      this.builder.hide();
      return this.wrapped.show();
    };

    JSONEditor.prototype.toggleBuilder = function() {
      if (this.builderShowing) {
        this.showText();
        return this.builderShowing = !this.builderShowing;
      } else {
        if (this.showBuilder()) {
          return this.builderShowing = !this.builderShowing;
        }
      }
    };

    JSONEditor.prototype.showFunctionButtons = function(insider) {
      var _this = this;
      if (!insider) {
        this.functionButtonsEnabled = true;
      }
      if (this.functionButtonsEnabled && !this.functionButtons) {
        this.functionButtons = $('<div class="function_buttons"></div>');
        this.functionButtons.append($('<a href="#" style="padding-right: 10px;">Undo</a>').click(function(e) {
          e.preventDefault();
          return _this.undo();
        }));
        this.functionButtons.append($('<a href="#" style="padding-right: 10px;">Redo</a>').click(function(e) {
          e.preventDefault();
          return _this.redo();
        }));
        this.functionButtons.append($('<a id="toggle_view" href="#" style="padding-right: 10px; float: right;">Toggle View</a>').click(function(e) {
          e.preventDefault();
          return _this.toggleBuilder();
        }));
        return this.container.prepend(this.functionButtons);
      }
    };

    JSONEditor.prototype.saveStateIfTextChanged = function() {
      if (JSON.stringify(this.json, null, 2) !== this.wrapped.get(0).value) {
        if (this.checkJsonInText()) {
          this.saveState(true);
        } else {
          if (confirm("The current JSON is malformed.  If you continue, the current JSON will not be saved.  Do you wish to continue?")) {
            this.historyPointer += 1;
            true;
          } else {
            false;
          }
        }
      }
      return true;
    };

    JSONEditor.prototype.restore = function() {
      if (this.history[this.historyPointer]) {
        this.wrapped.get(0).value = this.history[this.historyPointer];
        return this.rebuild(true);
      }
    };

    JSONEditor.prototype.saveState = function(skipStoreText) {
      var text;
      if (this.json) {
        if (!skipStoreText) {
          this.storeToText();
        }
        text = this.wrapped.get(0).value;
        if (this.history[this.historyPointer] !== text) {
          this.historyTruncate();
          this.history.push(text);
          return this.historyPointer += 1;
        }
      }
    };

    JSONEditor.prototype.fireChange = function() {
      return $(this.wrapped).trigger('change');
    };

    JSONEditor.prototype.historyTruncate = function() {
      if (this.historyPointer + 1 < this.history.length) {
        return this.history.splice(this.historyPointer + 1, this.history.length - this.historyPointer);
      }
    };

    JSONEditor.prototype.storeToText = function() {
      return this.wrapped.get(0).value = JSON.stringify(this.json, null, 2);
    };

    JSONEditor.prototype.getJSONText = function() {
      this.rebuild();
      return this.wrapped.get(0).value;
    };

    JSONEditor.prototype.getJSON = function() {
      this.rebuild();
      return this.json;
    };

    JSONEditor.prototype.rebuild = function(doNotRefreshText) {
      var changed, elem;
      if (!this.json) {
        this.setJsonFromText();
      }
      changed = this.haveThingsChanged();
      if (this.json && !doNotRefreshText) {
        this.saveState();
      }
      this.cleanBuilder();
      this.setJsonFromText();
      this.alreadyFocused = false;
      elem = this.build(this.json, this.builder, null, null, this.json);
      this.recoverScrollPosition();
      if (elem && elem.text() === '??' && !this.alreadyFocused && this.doAutoFocus) {
        this.alreadyFocused = true;
        this.doAutoFocus = false;
        elem = elem.find('.editable');
        elem.click();
        elem.find('input').focus().select();
      }
      if (changed) {
        return this.fireChange();
      }
    };

    JSONEditor.prototype.haveThingsChanged = function() {
      return this.json && JSON.stringify(this.json, null, 2) !== this.wrapped.get(0).value;
    };

    JSONEditor.prototype.saveScrollPosition = function() {
      return this.oldScrollHeight = this.builder.scrollTop();
    };

    JSONEditor.prototype.recoverScrollPosition = function() {
      return this.builder.scrollTop(this.oldScrollHeight);
    };

    JSONEditor.prototype.setJsonFromText = function() {
      if (this.wrapped.get(0).value.length === 0) {
        this.wrapped.get(0).value = "{}";
      }
      try {
        this.wrapped.get(0).value = this.wrapped.get(0).value.replace(/((^|[^\\])(\\\\)*)\\n/g, '$1\\\\n').replace(/((^|[^\\])(\\\\)*)\\t/g, '$1\\\\t');
        return this.json = JSON.parse(this.wrapped.get(0).value);
      } catch (e) {
        return alert("Got bad JSON from text.");
      }
    };

    JSONEditor.prototype.checkJsonInText = function() {
      try {
        JSON.parse(this.wrapped.get(0).value);
        return true;
      } catch (e) {
        return false;
      }
    };

    JSONEditor.prototype.logJSON = function() {
      return console.log(JSON.stringify(this.json, null, 2));
    };

    JSONEditor.prototype.cleanBuilder = function() {
      if (!this.builder) {
        this.builder = $('<div class="builder"></div>');
        this.container.append(this.builder);
      }
      this.saveScrollPosition();
      this.builder.text('');
      return this.showFunctionButtons("defined");
    };

    JSONEditor.prototype.updateStruct = function(struct, key, val, kind, selectionStart, selectionEnd) {
      var orderrest;
      if (kind === 'key') {
        if (selectionStart && selectionEnd) {
          val = key.substring(0, selectionStart) + val + key.substring(selectionEnd, key.length);
        }
        struct[val] = struct[key];
        orderrest = 0;
        $.each(struct, function(index, value) {
          var tempval;
          if (orderrest & index !== val) {
            tempval = struct[index];
            delete struct[index];
            struct[index] = tempval;
          }
          if (key === index) {
            return orderrest = 1;
          }
        });
        if (key !== val) {
          return delete struct[key];
        }
      } else {
        if (selectionStart && selectionEnd) {
          val = struct[key].substring(0, selectionStart) + val + struct[key].substring(selectionEnd, struct[key].length);
        }
        return struct[key] = val;
      }
    };

    JSONEditor.prototype.getValFromStruct = function(struct, key, kind) {
      if (kind === 'key') {
        return key;
      } else {
        return struct[key];
      }
    };

    JSONEditor.prototype.doTruncation = function(trueOrFalse) {
      if (this._doTruncation !== trueOrFalse) {
        this._doTruncation = trueOrFalse;
        return this.rebuild();
      }
    };

    JSONEditor.prototype.showWipe = function(trueOrFalse) {
      if (this._showWipe !== trueOrFalse) {
        this._showWipe = trueOrFalse;
        return this.rebuild();
      }
    };

    JSONEditor.prototype.truncate = function(text, length) {
      if (text.length === 0) {
        return '-empty-';
      }
      if (this._doTruncation && text.length > (length || 30)) {
        return text.substring(0, length || 30) + '...';
      }
      return text;
    };

    JSONEditor.prototype.replaceLastSelectedFieldIfRecent = function(text) {
      if (this.lastEditingUnfocusedTime > (new Date()).getTime() - 200) {
        this.setLastEditingFocus(text);
        return this.rebuild();
      }
    };

    JSONEditor.prototype.editingUnfocused = function(elem, struct, key, root, kind) {
      var selectionEnd, selectionStart,
        _this = this;
      selectionStart = elem != null ? elem.selectionStart : void 0;
      selectionEnd = elem != null ? elem.selectionEnd : void 0;
      this.setLastEditingFocus = function(text) {
        _this.updateStruct(struct, key, text, kind, selectionStart, selectionEnd);
        return _this.json = root;
      };
      return this.lastEditingUnfocusedTime = (new Date()).getTime();
    };

    JSONEditor.prototype.edit = function($elem, key, struct, root, kind) {
      var $input, blurHandler, form,
        _this = this;
      form = $("<form></form>").css('display', 'inline');
      $input = $("<input />");
      $input.val(this.getValFromStruct(struct, key, kind));
      $input.addClass('edit_field');
      blurHandler = function() {
        var val, _ref;
        val = $input.val();
        _this.updateStruct(struct, key, val, kind);
        _this.editingUnfocused($elem, struct, (_ref = kind === 'key') != null ? _ref : {
          val: key
        }, root, kind);
        $elem.text(_this.truncate(val));
        $elem.get(0).editing = false;
        if (key !== val) {
          return _this.rebuild();
        }
      };
      $input.blur(blurHandler);
      $input.keydown(function(e) {
        if (e.keyCode === 9 || e.keyCode === 13) {
          _this.doAutoFocus = true;
          return blurHandler();
        }
      });
      $(form).append($input).submit(function(e) {
        e.preventDefault();
        _this.doAutoFocus = true;
        return blurHandler();
      });
      $elem.html(form);
      return $input.focus();
    };

    JSONEditor.prototype.editable = function(text, key, struct, root, kind) {
      var elem, self;
      self = this;
      elem = $('<span class="editable" href="#"></span>').text(this.truncate(text)).click(function(e) {
        if (!this.editing) {
          this.editing = true;
          self.edit($(this), key, struct, root, kind);
        }
        return true;
      });
      return elem;
    };

    JSONEditor.prototype.build = function(json, node, parent, key, root) {
      var bq, elem, i, innerbq, jsonkey, jsonvalue, newElem, _i, _ref;
      elem = null;
      if (json instanceof Array) {
        bq = $(document.createElement("BLOCKQUOTE"));
        bq.append($('<div class="brackets">[</div>'));
        bq.prepend(this.addUI(json));
        if (parent) {
          if (this._showWipe) {
            bq.prepend(this.wipeUI(key, parent));
          }
          bq.prepend(this.deleteUI(key, parent));
        }
        for (i = _i = 0, _ref = json.length; 0 <= _ref ? _i < _ref : _i > _ref; i = 0 <= _ref ? ++_i : --_i) {
          innerbq = $(document.createElement("BLOCKQUOTE"));
          newElem = this.build(json[i], innerbq, json, i, root);
          if (newElem && newElem.text() === "??") {
            elem = newElem;
          }
          bq.append(innerbq);
        }
        bq.append($('<div class="brackets">]</div>'));
        node.append(bq);
      } else if (json instanceof Object) {
        bq = $(document.createElement("BLOCKQUOTE"));
        bq.append($('<div class="bracers">{</div>'));
        for (jsonkey in json) {
          jsonvalue = json[jsonkey];
          innerbq = $(document.createElement("BLOCKQUOTE"));
          newElem = this.editable(jsonkey.toString(), jsonkey.toString(), json, root, 'key').wrap('<span class="key"></b>').parent();
          innerbq.append(newElem);
          if (newElem && newElem.text() === "??") {
            elem = newElem;
          }
          if (typeof jsonvalue !== 'string') {
            innerbq.prepend(this.braceUI(jsonkey, json));
            innerbq.prepend(this.bracketUI(jsonkey, json));
            if (this._showWipe) {
              innerbq.prepend(this.wipeUI(jsonkey, json));
            }
            innerbq.prepend(this.deleteUI(jsonkey, json, true));
          }
          innerbq.append($('<span class="colon">: </span>'));
          newElem = this.build(jsonvalue, innerbq, json, jsonkey, root);
          if (!elem && newElem && newElem.text() === "??") {
            elem = newElem;
          }
          bq.append(innerbq);
        }
        bq.prepend(this.addUI(json));
        if (parent) {
          if (this._showWipe) {
            bq.prepend(this.wipeUI(key, parent));
          }
          bq.prepend(this.deleteUI(key, parent));
        }
        bq.append($('<div class="bracers">}</div>'));
        node.append(bq);
      } else {
        if (json === null) {
          json = '';
        }
        elem = this.editable(json.toString(), key, parent, root, 'value').wrap('<span class="val"></span>').parent();
        node.append(elem);
        node.prepend(this.braceUI(key, parent));
        node.prepend(this.bracketUI(key, parent));
        if (parent) {
          if (this._showWipe) {
            node.prepend(this.wipeUI(key, parent));
          }
          node.prepend(this.deleteUI(key, parent));
        }
      }
      return elem;
    };

    return JSONEditor;

  })();

}).call(this);
