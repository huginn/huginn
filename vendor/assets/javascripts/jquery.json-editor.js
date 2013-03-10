/*
  Copyright (c) 2013, Andrew Cantino
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




  You will probably need to tell the editor where to find its add and delete images.  In your
  code before you make the editor, do something like this:
     JSONEditor.prototype.ADD_IMG = '/javascripts/jsoneditor/add.png';
     JSONEditor.prototype.DELETE_IMG = '/javascripts/jsoneditor/delete.png';

  You can enable or disable visual truncation in the structure editor with the following:
    myEditor.doTruncation(false);
    myEditor.doTruncation(true); // The default

  You can show a 'w'ipe button that does a more aggressive delete by calling showWipe(true|false) or by passing in 'showWipe: true'.
*/


function JSONEditorBase(options) {
  if (!options) options = {};
  this.builderShowing = true;
  this.ADD_IMG = options.ADD_IMG || 'lib/images/add.png';
  this.DELETE_IMG = options.DELETE_IMG || 'lib/images/delete.png';
  this.functionButtonsEnabled = false;
  this._doTruncation = true;
  this._showWipe = options.showWipe;
}

function JSONEditor(wrapped, width, height) {
  this.history = [];
  this.historyPointer = -1;
  if (wrapped == null || (wrapped.get && wrapped.get(0) == null)) throw "Must provide an element to wrap.";
  var width = width || 600;
  var height = height || 300;
  this.wrapped = $(wrapped);

  this.wrapped.wrap('<div class="json-editor"></div>');
  this.container = $(this.wrapped.parent());
  this.container.width(width).height(height);
  this.wrapped.width(width).height(height);
  this.wrapped.hide();
  this.container.css("position", "relative");
  this.doAutoFocus = false;
  this.editingUnfocused();

  this.rebuild();
  var self = this;
  this.container.focus(function(){
  	$(this).children('textarea').height(self.container.height() - self.functionButtons.height() - 5);
  	$(this).children('.builder').height(self.container.height() - self.functionButtons.height() - 10);
  });

  return this;
}
JSONEditor.prototype = new JSONEditorBase();

JSONEditor.prototype.braceUI = function(key, struct) {
  var self = this;
  return $('<a class="icon" href="#"><strong>{</strong></a>').click(function(e) {
    struct[key] = { "??": struct[key] };
    self.doAutoFocus = true;
    self.rebuild();
    return false;
  });
};

JSONEditor.prototype.bracketUI = function(key, struct) {
  var self = this;
  return $('<a class="icon" href="#"><strong>[</a>').click(function(e) {
    struct[key] = [ struct[key] ];
    self.doAutoFocus = true;
    self.rebuild();
    return false;
  });
};

JSONEditor.prototype.deleteUI = function(key, struct, fullDelete) {
  var self = this;
  return $('<a class="icon" href="#" title="delete"><img src="' + this.DELETE_IMG + '" border=0/></a>').click(function(e) {
    if (!fullDelete) {
      var didSomething = false;
      if (struct[key] instanceof Array) {
        if(struct[key].length > 0) {
          struct[key] = struct[key][0];
          didSomething = true;
        }
      } else if (struct[key] instanceof Object) {
        for (var i in struct[key]) {
          struct[key] = struct[key][i];
          didSomething = true;
          break;
        }
      }
      if (didSomething) {
        self.rebuild();
        return false;
      }
    }
    if (struct instanceof Array) {
      struct.splice(key, 1);
    } else {
      delete struct[key];
    }
    self.rebuild();
    return false;
  });
};

JSONEditor.prototype.wipeUI = function(key, struct) {
  var self = this;
  return $('<a class="icon" href="#" title="wipe"><strong>W</strong></a>').click(function(e) {
    if (struct instanceof Array) {
      struct.splice(key, 1);
    } else {
      delete struct[key];
    }
    self.rebuild();
    return false;
  });
};

JSONEditor.prototype.addUI = function(struct) {
  var self = this;
  return $('<a class="icon" href="#" title="add"><img src="' + this.ADD_IMG + '" border=0/></a>').click(function(e) {
    if (struct instanceof Array) {
      struct.push('??');
    } else {
      struct['??'] = '??';
    }
    self.doAutoFocus = true;
    self.rebuild();
    return false;
  });
};

JSONEditor.prototype.undo = function() {
  if (this.saveStateIfTextChanged()) {
    if (this.historyPointer > 0) this.historyPointer -= 1;
    this.restore();
  }
};

JSONEditor.prototype.redo = function() {
  if (this.historyPointer + 1 < this.history.length) {
    if (this.saveStateIfTextChanged()) {
      this.historyPointer += 1;
      this.restore();
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
  this.wrapped.show();
};

JSONEditor.prototype.toggleBuilder = function() {
    if(this.builderShowing){
      this.showText();
      this.builderShowing = !this.builderShowing;
    } else {
      if (this.showBuilder()) {
        this.builderShowing = !this.builderShowing;
      }
    }
};

JSONEditor.prototype.showFunctionButtons = function(insider) {
  if (!insider) this.functionButtonsEnabled = true;
  if (this.functionButtonsEnabled) if (!this.functionButtons) {
    this.functionButtons = $('<div class="function_buttons"></div>');
    var self = this;
    this.functionButtons.append($('<a href="#" style="padding-right: 10px;"></a>').click(function() {
      self.undo();
      return false;
    }).text('Undo')).append($('<a href="#" style="padding-right: 10px;"></a>').click(function() {
      self.redo();
      return false;
    }).text('Redo')).append($('<a id="toggle_view" href="#" style="padding-right: 10px;"></a>').click(function() {
      self.toggleBuilder();
      return false;
    }).text('Toggle View').css("float", "right"));
    this.container.prepend(this.functionButtons);
    this.container.height(this.container.height() + this.functionButtons.height() + 5);
  }
  if (this.functionButtons) {
    this.wrapped.css('top', this.functionButtons.height() + 5 + 'px');
    this.builder.css('top', this.functionButtons.height() + 5 + 'px');
  }
};

JSONEditor.prototype.saveStateIfTextChanged = function() {
  if (JSON.stringify(this.json, null, 2) != this.wrapped.get(0).value) {
    if (this.checkJsonInText()) {
      this.saveState(true);
    } else {
      if (confirm("The current JSON is malformed.  If you continue, the current JSON will not be saved.  Do you wish to continue?")) {
        this.historyPointer += 1;
        return true;
      } else {
        return false;
      }
    }
  }
  return true;
};

JSONEditor.prototype.restore = function() {
  if (this.history[this.historyPointer]) {
    this.wrapped.get(0).value = this.history[this.historyPointer];
    this.rebuild(true);
  }
};

JSONEditor.prototype.saveState = function(skipStoreText) {
  if (this.json) {
    if (!skipStoreText) this.storeToText();
    var text = this.wrapped.get(0).value;
    if (this.history[this.historyPointer] != text) {
      this.historyTruncate();
      this.history.push(text);
      this.historyPointer += 1;
    }
  }
};

JSONEditor.prototype.fireChange = function() {
  $(this.wrapped).trigger('change');
};

JSONEditor.prototype.historyTruncate = function() {
  if (this.historyPointer + 1 < this.history.length) {
    this.history.splice(this.historyPointer + 1, this.history.length - this.historyPointer);
  }
};

JSONEditor.prototype.storeToText = function() {
  this.wrapped.get(0).value = JSON.stringify(this.json, null, 2);
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
  if (!this.json) this.setJsonFromText();
  var changed = this.haveThingsChanged();
  if (this.json && !doNotRefreshText) {
    this.saveState();
  }
  this.cleanBuilder();
  this.setJsonFromText();
  this.alreadyFocused = false;
  var elem = this.build(this.json, this.builder, null, null, this.json);

  this.recoverScrollPosition();

  // Auto-focus to edit '??' keys and values.
  if (elem) if (elem.text() == '??' && !this.alreadyFocused && this.doAutoFocus) {
    this.alreadyFocused = true;
    this.doAutoFocus = false;

    elem = elem.find('.editable');
    elem.click();
    elem.find('input').focus().select();
    //still missing a proper scrolling into the selected input
  }

  if (changed) this.fireChange();
};

JSONEditor.prototype.haveThingsChanged = function() {
  return (this.json && JSON.stringify(this.json, null, 2) != this.wrapped.get(0).value);
}

JSONEditor.prototype.saveScrollPosition = function() {
  this.oldScrollHeight = this.builder.scrollTop();
};

JSONEditor.prototype.recoverScrollPosition = function() {
  this.builder.scrollTop(this.oldScrollHeight);
};

JSONEditor.prototype.setJsonFromText = function() {
  if (this.wrapped.get(0).value.length == 0) this.wrapped.get(0).value = "{}";
  try {
    this.wrapped.get(0).value = this.wrapped.get(0).value.replace(/((^|[^\\])(\\\\)*)\\n/g, '$1\\\\n').replace(/((^|[^\\])(\\\\)*)\\t/g, '$1\\\\t');
    this.json = JSON.parse(this.wrapped.get(0).value);
  } catch(e) {
    alert("Got bad JSON from text.");
  }
};

JSONEditor.prototype.checkJsonInText = function() {
  try {
    JSON.parse(this.wrapped.get(0).value);
    return true;
  } catch(e) {
    return false;
  }
};

JSONEditor.prototype.logJSON = function() {
  console.log(JSON.stringify(this.json, null, 2));
};

JSONEditor.prototype.cleanBuilder = function() {
  if (!this.builder) {
    this.builder = $('<div class="builder"></div>');
    this.container.append(this.builder);
  }
  this.saveScrollPosition();
  this.builder.text('');

  this.builder.css("position", "absolute").css("top", 0).css("left", 0);
  this.builder.width(this.wrapped.width()).height(this.wrapped.height());
  this.wrapped.css("position", "absolute").css("top", 0).css("left", 0);
  this.showFunctionButtons("defined");
};

JSONEditor.prototype.updateStruct = function(struct, key, val, kind, selectionStart, selectionEnd) {
  if(kind == 'key') {
    if (selectionStart && selectionEnd) val = key.substring(0, selectionStart) + val + key.substring(selectionEnd, key.length);
    struct[val] = struct[key];

    		//order keys
		var orderrest = 0;
		$.each(struct, function (index, value) {
			//re set rest of the keys
			if(orderrest & index != val) {
				var tempval = struct[index];
				delete struct[index];
				struct[index] = tempval;
			}
			if(key == index) {
				orderrest = 1;
			}
		});
		// end of order keys

    if (key != val) delete struct[key];
  } else {
    if (selectionStart && selectionEnd) val = struct[key].substring(0, selectionStart) + val + struct[key].substring(selectionEnd, struct[key].length);
    struct[key] = val;
  }
};

JSONEditor.prototype.getValFromStruct = function(struct, key, kind) {
  if(kind == 'key') {
    return key;
  } else {
    return struct[key];
  }
};

JSONEditor.prototype.doTruncation = function(trueOrFalse) {
  if (this._doTruncation != trueOrFalse) {
    this._doTruncation = trueOrFalse;
    this.rebuild();
  }
};

JSONEditor.prototype.showWipe = function(trueOrFalse) {
  if (this._showWipe != trueOrFalse) {
    this._showWipe = trueOrFalse;
    this.rebuild();
  }
};

JSONEditor.prototype.truncate = function(text, length) {
  if (text.length == 0) return '-empty-';
  if(this._doTruncation && text.length > (length || 30)) return(text.substring(0, (length || 30)) + '...');
  return text;
};

JSONEditor.prototype.replaceLastSelectedFieldIfRecent = function(text) {
  if (this.lastEditingUnfocusedTime > (new Date()).getTime() - 200) { // Short delay for unfocus to occur.
    this.setLastEditingFocus(text);
    this.rebuild();
  }
};

JSONEditor.prototype.editingUnfocused = function(elem, struct, key, root, kind) {
  var self = this;

  var selectionStart = elem && elem.target.selectionStart;
  var selectionEnd = elem && elem.target.selectionEnd;

  this.setLastEditingFocus = function(text) {
    self.updateStruct(struct, key, text, kind, selectionStart, selectionEnd);
    self.json = root; // Because self.json is a new reference due to rebuild.
  };
  this.lastEditingUnfocusedTime = (new Date()).getTime();
};

JSONEditor.prototype.edit = function(e, key, struct, root, kind){
  var self = this;
  var form = $("<form></form>").css('display', 'inline');
  var input = document.createElement("INPUT");
  input.value = this.getValFromStruct(struct, key, kind);
  //alert(this.getValFromStruct(struct, key, kind));
  input.className = 'edit_field';
  var onblur = function(elem) {
    var val = input.value;
    self.updateStruct(struct, key, val, kind);
    self.editingUnfocused(elem, struct, (kind == 'key' ? val : key), root, kind);
    e.text(self.truncate(val));
    e.get(0).editing = false;
    if (key != val) self.rebuild();
    return false;
  };
  $(input).blur(onblur);
  $(input).keydown(function(e) {
    if (e.keyCode == 9 || e.keyCode == 13) { // Tab and enter
      self.doAutoFocus = true;
      onblur(e);
      return false;
    }
  });
  $(form).submit(function(e) { self.doAutoFocus = true; onblur(e); return false;}).append(input);
  $(e).html(form);
  input.focus();
};

JSONEditor.prototype.editable = function(text, key, struct, root, kind) {
  var self = this;
  var elem = $('<span class="editable" href="#"></span>').text(this.truncate(text)).click(function(e) {
    if (!this.editing) {
      this.editing = true;
      self.edit($(this), key, struct, root, kind);
    }
    return true;
  });

  return elem;
}

JSONEditor.prototype.build = function(json, node, parent, key, root) {
  var elem = null;
  if(json instanceof Array){
    var bq = $(document.createElement("BLOCKQUOTE"));
    bq.append($('<div class="brackets">[</div>'));

    bq.prepend(this.addUI(json));
    if (parent) {
      if (this._showWipe) bq.prepend(this.wipeUI(key, parent));
    	bq.prepend(this.deleteUI(key, parent));
    }

    for(var i = 0; i < json.length; i++) {
      var innerbq = $(document.createElement("BLOCKQUOTE"));
      var newElem = this.build(json[i], innerbq, json, i, root);
      if (newElem) if (newElem.text() == "??") elem = newElem;
      bq.append(innerbq);
    }

    bq.append($('<div class="brackets">]</div>'));
    node.append(bq);
  } else if (json instanceof Object) {
    var bq = $(document.createElement("BLOCKQUOTE"));
    bq.append($('<div class="bracers">{</div>'));

    for(var i in json){
      var innerbq = $(document.createElement("BLOCKQUOTE"));
      var newElem = this.editable(i.toString(), i.toString(), json, root, 'key').wrap('<span class="key"></b>').parent();
      innerbq.append(newElem);
      if (newElem) if (newElem.text() == "??") elem = newElem;
      if (typeof json[i] != 'string') {
        innerbq.prepend(this.braceUI(i, json));
        innerbq.prepend(this.bracketUI(i, json));
        if (this._showWipe) innerbq.prepend(this.wipeUI(i, json));
        innerbq.prepend(this.deleteUI(i, json, true));
      }
      innerbq.append($('<span class="colon">: </span>'));
      newElem = this.build(json[i], innerbq, json, i, root);
      if (newElem) if (newElem.text() == "??") elem = newElem;
      bq.append(innerbq);
    }

    bq.prepend(this.addUI(json));
    if (parent) {
      if (this._showWipe) bq.prepend(this.wipeUI(key, parent));
    	bq.prepend(this.deleteUI(key, parent));
    }

    bq.append($('<div class="bracers">}</div>'));
    node.append(bq);
  } else {
    elem = this.editable(json.toString(), key, parent, root, 'value').wrap('<span class="val"></span>').parent();
    node.append(elem);
    node.prepend(this.braceUI(key, parent));
    node.prepend(this.bracketUI(key, parent));
    if (parent) {
      if (this._showWipe) node.prepend(this.wipeUI(key, parent));
    	node.prepend(this.deleteUI(key, parent));
    }

  }
  return elem;
};
