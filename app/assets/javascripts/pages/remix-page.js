(function() {
  'use strict';

  // Simple markdown renderer using marked.js (loaded via CDN in the view)
  function renderMarkdown(text) {
    if (!text) return '';
    if (typeof marked !== 'undefined' && typeof DOMPurify !== 'undefined') {
      try {
        var html = marked.parse(text, { breaks: true, gfm: true });
        return DOMPurify.sanitize(html);
      } catch(e) {
        return escapeHtml(text).replace(/\n/g, '<br>');
      }
    }
    return escapeHtml(text).replace(/\n/g, '<br>');
  }

  function escapeHtml(str) {
    var div = document.createElement('div');
    div.appendChild(document.createTextNode(str));
    return div.innerHTML;
  }

  function formatElapsed(ms) {
    var secs = Math.floor(ms / 1000);
    if (secs < 60) return secs + 's';
    var mins = Math.floor(secs / 60);
    secs = secs % 60;
    return mins + 'm ' + secs + 's';
  }

  // Streaming phases
  var PHASE = {
    IDLE: 'idle',
    CONNECTING: 'connecting',
    THINKING: 'thinking',
    GENERATING: 'generating',
    TOOL_CALLING: 'tool_calling',
    TOOL_EXECUTING: 'tool_executing'
  };

  var PHASE_LABELS = {};
  PHASE_LABELS[PHASE.CONNECTING] = 'Connecting...';
  PHASE_LABELS[PHASE.THINKING] = 'Thinking...';
  PHASE_LABELS[PHASE.GENERATING] = 'Generating...';
  PHASE_LABELS[PHASE.TOOL_CALLING] = 'Preparing tool call...';
  PHASE_LABELS[PHASE.TOOL_EXECUTING] = 'Running tool...';

  var RemixPage = {
    abortController: null,
    phase: PHASE.IDLE,
    streamStartTime: null,
    elapsedTimer: null,

    init: function() {
      this.container = document.querySelector('.remix-chat-container');
      if (!this.container) return;

      this.messagesEl = document.getElementById('messages');
      this.inputEl = document.getElementById('message-input');
      this.sendBtn = document.getElementById('send-button');
      this.stopBtn = document.getElementById('stop-button');
      this.statusBar = document.getElementById('status-bar');
      this.statusText = document.getElementById('status-text');
      this.statusElapsed = document.getElementById('status-elapsed');
      this.streamUrl = this.container.dataset.streamUrl;
      this.remixId = this.container.dataset.remixId;
      this.statusUrl = this.container.dataset.statusUrl;
      this.csrfToken = this.container.dataset.csrfToken;

      this.bindEvents();
      this.renderExistingMarkdown();
      this.scrollToBottom();
      this.focusInput();

      // If the conversation is still being processed (e.g. user navigated
      // away and came back), show the thinking indicator and poll for
      // completion.
      if (this.container.dataset.processing === 'true') {
        this.showProcessingState();
      }
    },

    bindEvents: function() {
      var self = this;

      this.sendBtn.addEventListener('click', function(e) {
        e.preventDefault();
        self.sendMessage();
      });

      this.stopBtn.addEventListener('click', function(e) {
        e.preventDefault();
        self.stopStreaming();
      });

      this.inputEl.addEventListener('keydown', function(e) {
        if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
          e.preventDefault();
          self.sendMessage();
        }
      });

      this.inputEl.addEventListener('input', function() {
        this.style.height = 'auto';
        this.style.height = Math.min(this.scrollHeight, 200) + 'px';
      });
    },

    // Render markdown for messages already on the page (loaded from DB)
    renderExistingMarkdown: function() {
      var contentEls = this.messagesEl.querySelectorAll('.remix-message-assistant .remix-message-content .md-content');
      for (var i = 0; i < contentEls.length; i++) {
        var raw = contentEls[i].getAttribute('data-raw');
        if (raw) {
          contentEls[i].innerHTML = renderMarkdown(raw);
        }
      }
    },

    // --- Phase & Status Management ---

    setPhase: function(phase, detail) {
      this.phase = phase;

      if (phase === PHASE.IDLE) {
        this.statusBar.classList.remove('active');
        this.stopElapsedTimer();
        return;
      }

      var label = PHASE_LABELS[phase] || phase;
      if (detail) label = detail;
      this.statusText.textContent = label;
      this.statusBar.classList.add('active');
    },

    startElapsedTimer: function() {
      var self = this;
      this.streamStartTime = Date.now();
      this.statusElapsed.textContent = '0s';
      this.elapsedTimer = setInterval(function() {
        if (self.streamStartTime) {
          self.statusElapsed.textContent = formatElapsed(Date.now() - self.streamStartTime);
        }
      }, 1000);
    },

    stopElapsedTimer: function() {
      if (this.elapsedTimer) {
        clearInterval(this.elapsedTimer);
        this.elapsedTimer = null;
      }
      this.streamStartTime = null;
      this.statusElapsed.textContent = '';
    },

    // --- Thinking Indicator ---

    showThinkingIndicator: function() {
      // Create assistant message with thinking dots if not already present
      if (!this.currentAssistantEl) {
        this.currentAssistantEl = this.createAssistantMessage();
      }
      // Add thinking indicator inside the content area
      this.removeThinkingIndicator();
      var indicator = document.createElement('div');
      indicator.className = 'remix-thinking-indicator';
      indicator.innerHTML = '<span class="dot"></span><span class="dot"></span><span class="dot"></span>';
      this.currentContentEl.appendChild(indicator);
      this.scrollToBottom();
    },

    removeThinkingIndicator: function() {
      if (this.currentAssistantEl) {
        var indicator = this.currentAssistantEl.querySelector('.remix-thinking-indicator');
        if (indicator) indicator.remove();
      }
    },

    // --- Send & Stream ---

    sendMessage: function() {
      var content = this.inputEl.value.trim();
      if (!content) return;

      // Remove welcome message
      var welcome = document.getElementById('welcome-message');
      if (welcome) welcome.remove();

      // Append user message
      this.appendUserMessage(content);
      this.inputEl.value = '';
      this.inputEl.style.height = 'auto';

      // Disable send, show stop
      this.setStreamingState(true);

      // Start streaming
      this.startStreaming(content);
    },

    setStreamingState: function(streaming) {
      this.sendBtn.style.display = streaming ? 'none' : '';
      this.stopBtn.style.display = streaming ? '' : 'none';
      this.inputEl.disabled = streaming;
      if (!streaming) this.focusInput();
    },

    stopStreaming: function() {
      if (this.abortController) {
        this.abortController.abort();
        this.abortController = null;
      }
      this.onStreamEnd();
    },

    startStreaming: function(content) {
      var self = this;
      this.abortController = new AbortController();

      // Reset streaming state
      this.currentAssistantEl = null;
      this.currentContentEl = null;
      this.currentRawContent = '';
      this.currentToolCallsEl = null;
      this.seenToolNames = {};

      // Start with "Thinking" phase immediately — the user has sent a message
      // and the system is working. We skip "Connecting" since it's invisible
      // (the HTTP connection is established almost instantly for local/fast servers).
      this.setPhase(PHASE.THINKING);
      this.startElapsedTimer();
      this.showThinkingIndicator();

      fetch(this.streamUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({ content: content }),
        signal: this.abortController.signal
      }).then(function(response) {
        if (!response.ok) {
          // Server error (e.g. 504 gateway timeout) — fall back to non-streaming
          throw { name: 'StreamFailed', status: response.status };
        }

        var reader = response.body.getReader();
        var decoder = new TextDecoder();
        var buffer = '';

        function processChunk() {
          return reader.read().then(function(result) {
            if (result.done) {
              self.onStreamEnd();
              return;
            }

            buffer += decoder.decode(result.value, { stream: true });

            // Process complete SSE events
            var events = buffer.split('\n\n');
            buffer = events.pop(); // keep incomplete last chunk

            events.forEach(function(eventStr) {
              eventStr = eventStr.trim();
              if (!eventStr) return;

              // Handle multi-line data
              var lines = eventStr.split('\n');
              var data = '';
              lines.forEach(function(line) {
                if (line.indexOf('data: ') === 0) {
                  data += line.substring(6);
                }
              });

              if (!data) return;

              try {
                var event = JSON.parse(data);
                self.handleSSEEvent(event);
              } catch(e) {
                // skip malformed
              }
            });

            return processChunk();
          });
        }

        return processChunk();
      }).catch(function(err) {
        if (err.name === 'AbortError') {
          self.appendSystemNote('Streaming stopped by user.');
        } else {
          self.appendErrorMessage('Connection error: ' + (err.message || 'status ' + err.status));
        }
        self.onStreamEnd();
      });
    },

    handleSSEEvent: function(event) {
      switch (event.type) {
        case 'stream_open':
          // Server confirmed the stream is alive. We are already in THINKING
          // phase (set when the message was sent), so nothing to do here.
          break;

        case 'content_delta':
          this.onContentDelta(event.text);
          break;

        case 'tool_call_delta':
          this.onToolCallDelta(event);
          break;

        case 'assistant_saved':
          // Mark current message as persisted
          if (this.currentAssistantEl) {
            this.currentAssistantEl.setAttribute('data-message-id', event.message_id);
          }
          break;

        case 'tool_execution_start':
          this.setPhase(PHASE.TOOL_EXECUTING, 'Running ' + event.count + ' tool' + (event.count > 1 ? 's' : '') + '...');
          break;

        case 'tool_start':
          this.onToolStart(event);
          this.setPhase(PHASE.TOOL_EXECUTING, 'Running: ' + event.name + '...');
          break;

        case 'tool_result':
          this.onToolResult(event);
          break;

        case 'next_iteration':
          // Final render of current content before resetting
          if (this.currentContentEl && this.currentRawContent) {
            this.currentContentEl.innerHTML = renderMarkdown(this.currentRawContent);
          }
          // New LLM turn — reset assistant message, show thinking
          this.currentAssistantEl = null;
          this.currentContentEl = null;
          this.currentRawContent = '';
          this.currentToolCallsEl = null;
          this.seenToolNames = {};
          this._renderPending = false;
          this.setPhase(PHASE.THINKING, 'Thinking... (turn ' + event.iteration + ')');
          this.showThinkingIndicator();
          break;

        case 'compaction':
          this.onCompaction(event);
          break;

        case 'confirmation_required':
          this.showConfirmationButtons(event);
          break;

        case 'title_updated':
          this.onTitleUpdated(event.title);
          break;

        case 'error':
          this.appendErrorMessage(event.error);
          break;

        case 'stream_end':
          // handled by onStreamEnd
          break;
      }
    },

    onContentDelta: function(text) {
      // First content delta — transition from thinking to generating
      if (this.phase === PHASE.THINKING || this.phase === PHASE.CONNECTING) {
        this.setPhase(PHASE.GENERATING);
        this.removeThinkingIndicator();
      }

      if (!this.currentAssistantEl) {
        this.currentAssistantEl = this.createAssistantMessage();
      }

      this.currentRawContent += text;

      // Throttle markdown rendering to avoid blocking the main thread.
      // Re-render at most every 80ms during streaming; the final render
      // happens in onStreamEnd / next_iteration.
      if (!this._renderPending) {
        this._renderPending = true;
        var self = this;
        requestAnimationFrame(function() {
          self.currentContentEl.innerHTML = renderMarkdown(self.currentRawContent);
          self._renderPending = false;
          self.scrollToBottom();
        });
      }
    },

    onCompaction: function(event) {
      // Context was too long — the orchestrator is retrying with fewer messages
      this.removeThinkingIndicator();
      this.setPhase(PHASE.THINKING, 'Compacting context (attempt ' + event.attempt + ', ' + event.remaining + ' messages kept)...');
      this.appendSystemNote(
        'Context too long — compacting: dropped ' + event.dropped +
        ' older messages, ' + event.remaining + ' remaining. Retrying...'
      );
      this.showThinkingIndicator();
    },

    onToolCallDelta: function(event) {
      if (this.phase === PHASE.THINKING || this.phase === PHASE.GENERATING) {
        this.setPhase(PHASE.TOOL_CALLING);
        this.removeThinkingIndicator();
      }

      if (!this.currentAssistantEl) {
        this.currentAssistantEl = this.createAssistantMessage();
      }

      if (!this.currentToolCallsEl) {
        this.currentToolCallsEl = document.createElement('div');
        this.currentToolCallsEl.className = 'tool-calls';
        this.currentAssistantEl.querySelector('.remix-message-content').appendChild(this.currentToolCallsEl);
      }

      // Show unique tool names
      if (event.name && !this.seenToolNames[event.name]) {
        this.seenToolNames[event.name] = true;
        var callEl = document.createElement('div');
        callEl.className = 'tool-call';
        callEl.innerHTML = '<i class="fa fa-wrench"></i> Calling: <code>' + escapeHtml(event.name) + '</code>' +
                           ' <span class="tool-spinner"></span>';
        this.currentToolCallsEl.appendChild(callEl);
        this.setPhase(PHASE.TOOL_CALLING, 'Calling: ' + event.name + '...');
        this.scrollToBottom();
      }
    },

    onToolStart: function(event) {
      var el = document.createElement('div');
      el.className = 'remix-message remix-message-tool';
      el.id = 'tool-' + event.id;
      el.innerHTML =
        '<div class="remix-message-header"><strong><i class="fa fa-cog fa-spin"></i> Tool: ' +
        escapeHtml(event.name) + '</strong></div>' +
        '<div class="remix-message-content"><em class="tool-spinner-text">Executing...</em></div>';
      this.messagesEl.appendChild(el);
      this.scrollToBottom();
    },

    onToolResult: function(event) {
      var el = document.getElementById('tool-' + event.id);
      if (!el) {
        el = document.createElement('div');
        el.className = 'remix-message remix-message-tool';
        this.messagesEl.appendChild(el);
      }

      var result = event.result;
      var html = '<div class="remix-message-header"><strong><i class="fa fa-cog"></i> Tool: ' +
                 escapeHtml(event.name) + '</strong></div><div class="remix-message-content">';

      if (result.pending_confirmation) {
        html += '<div class="alert alert-warning" id="confirmation-' + escapeHtml(result.tool_call_id) + '">' +
                '<p><strong>Confirmation Required:</strong> ' + escapeHtml(result.message) + '</p>' +
                '<div class="confirmation-buttons">' +
                  '<button class="btn btn-danger btn-sm" onclick="RemixPage.confirmAction(\'' + escapeHtml(result.tool_call_id) + '\')">Confirm</button> ' +
                  '<button class="btn btn-default btn-sm" onclick="RemixPage.cancelAction(\'' + escapeHtml(result.tool_call_id) + '\')">Cancel</button>' +
                '</div></div>';
      } else if (result.error) {
        html += '<div class="alert alert-danger"><strong>Error:</strong> ' + escapeHtml(result.error) + '</div>';
      } else if (result.success) {
        html += '<div class="tool-result success"><span class="result-icon">&#10003;</span> ' +
                escapeHtml(result.message) + '</div>';
      } else {
        html += '<details><summary>Tool Result</summary>' +
                '<pre><code>' + escapeHtml(JSON.stringify(result, null, 2)) + '</code></pre></details>';
      }

      html += '</div>';
      el.innerHTML = html;

      // Remove spinner from tool calls list
      var spinners = this.messagesEl.querySelectorAll('.tool-spinner');
      for (var i = 0; i < spinners.length; i++) spinners[i].remove();

      this.scrollToBottom();
    },

    showConfirmationButtons: function(event) {
      // The confirmation_required event may arrive after or instead of the tool_result.
      // Check if we already rendered buttons in onToolResult (via pending_confirmation in tool_result).
      var existingEl = document.getElementById('confirmation-' + event.tool_call_id);
      if (existingEl) return; // Already rendered inline

      // Render a standalone confirmation block
      var el = document.createElement('div');
      el.className = 'remix-message remix-message-tool';
      el.innerHTML =
        '<div class="remix-message-content">' +
          '<div class="alert alert-warning" id="confirmation-' + escapeHtml(event.tool_call_id) + '">' +
            '<p><strong>Confirmation Required:</strong> ' + escapeHtml(event.message) + '</p>' +
            '<div class="confirmation-buttons">' +
              '<button class="btn btn-danger btn-sm" onclick="RemixPage.confirmAction(\'' + escapeHtml(event.tool_call_id) + '\')">Confirm</button> ' +
              '<button class="btn btn-default btn-sm" onclick="RemixPage.cancelAction(\'' + escapeHtml(event.tool_call_id) + '\')">Cancel</button>' +
            '</div>' +
          '</div>' +
        '</div>';
      this.messagesEl.appendChild(el);
      this.scrollToBottom();
    },

    confirmAction: function(toolCallId) {
      var self = this;
      var el = document.getElementById('confirmation-' + toolCallId);
      if (el) {
        var btns = el.querySelector('.confirmation-buttons');
        if (btns) btns.innerHTML = '<em>Confirming...</em>';
      }

      var url = '/remixes/' + this.remixId + '/confirm_action';
      fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken,
          'Accept': 'application/json'
        },
        body: JSON.stringify({ tool_call_id: toolCallId })
      }).then(function(response) {
        return response.json();
      }).then(function(data) {
        if (el) {
          if (data.success) {
            el.className = 'alert alert-success';
            el.innerHTML = '<span class="result-icon">&#10003;</span> ' + escapeHtml(data.message || 'Action confirmed and executed.');
          } else {
            el.className = 'alert alert-danger';
            el.innerHTML = '<strong>Error:</strong> ' + escapeHtml(data.error || 'Action failed.');
          }
        }
        // Append any assistant follow-up message
        if (data.assistant_message) {
          self.appendAssistantMessage(data.assistant_message);
        }
        self.scrollToBottom();
      }).catch(function(err) {
        if (el) {
          el.className = 'alert alert-danger';
          el.innerHTML = '<strong>Error:</strong> ' + escapeHtml(err.message);
        }
      });
    },

    cancelAction: function(toolCallId) {
      var self = this;
      var el = document.getElementById('confirmation-' + toolCallId);
      if (el) {
        var btns = el.querySelector('.confirmation-buttons');
        if (btns) btns.innerHTML = '<em>Cancelling...</em>';
      }

      var url = '/remixes/' + this.remixId + '/cancel_action';
      fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken,
          'Accept': 'application/json'
        },
        body: JSON.stringify({ tool_call_id: toolCallId })
      }).then(function(response) {
        return response.json();
      }).then(function(data) {
        if (el) {
          el.className = 'alert alert-info';
          el.innerHTML = 'Operation cancelled.';
        }
        self.scrollToBottom();
      }).catch(function(err) {
        if (el) {
          el.className = 'alert alert-danger';
          el.innerHTML = '<strong>Error:</strong> ' + escapeHtml(err.message);
        }
      });
    },

    appendAssistantMessage: function(content) {
      var el = document.createElement('div');
      el.className = 'remix-message remix-message-assistant';
      el.innerHTML =
        '<div class="remix-message-header">' +
          '<strong><i class="fa fa-wand-magic-sparkles"></i> Remix</strong>' +
          '<span class="timestamp">' + this.currentTime() + '</span>' +
        '</div>' +
        '<div class="remix-message-content"><div class="md-content">' + renderMarkdown(content) + '</div></div>';
      this.messagesEl.appendChild(el);
      this.scrollToBottom();
    },

    // Show thinking state when navigating to a conversation that is still
    // being processed by another request. Polls the status endpoint and
    // reloads the page once processing completes.
    showProcessingState: function() {
      var self = this;
      this.setStreamingState(true);
      this.setPhase(PHASE.THINKING);
      this.showThinkingIndicator();
      this.startElapsedTimer();

      this._processingPoll = setInterval(function() {
        fetch(self.statusUrl, {
          headers: { 'Accept': 'application/json' }
        }).then(function(r) { return r.json(); })
          .then(function(data) {
            if (!data.processing) {
              clearInterval(self._processingPoll);
              self._processingPoll = null;
              // Reload to show the completed messages
              window.location.reload();
            }
          })
          .catch(function() {
            // Ignore poll errors — will retry on next interval
          });
      }, 3000); // poll every 3 seconds
    },

    onTitleUpdated: function(title) {
      // Update page heading
      var h2 = document.querySelector('.page-header h2');
      if (h2) {
        h2.innerHTML = '<i class="fa fa-wand-magic-sparkles"></i> ' + escapeHtml(title);
      }
      // Update browser tab
      document.title = title + ' - Huginn';
    },

    onStreamEnd: function() {
      this.removeThinkingIndicator();
      this.setPhase(PHASE.IDLE);
      this.setStreamingState(false);
      this.abortController = null;
      this._renderPending = false;

      // Final markdown render to ensure all content is displayed
      if (this.currentContentEl && this.currentRawContent) {
        this.currentContentEl.innerHTML = renderMarkdown(this.currentRawContent);
      }

      // Remove any remaining spinners
      var spinners = this.messagesEl.querySelectorAll('.tool-spinner, .tool-spinner-text');
      for (var i = 0; i < spinners.length; i++) spinners[i].remove();
    },

    // DOM helpers

    createAssistantMessage: function() {
      var el = document.createElement('div');
      el.className = 'remix-message remix-message-assistant';
      el.innerHTML =
        '<div class="remix-message-header">' +
          '<strong><i class="fa fa-wand-magic-sparkles"></i> Remix</strong>' +
          '<span class="timestamp">' + this.currentTime() + '</span>' +
        '</div>' +
        '<div class="remix-message-content"><div class="md-content"></div></div>';
      this.messagesEl.appendChild(el);
      this.currentContentEl = el.querySelector('.md-content');
      this.scrollToBottom();
      return el;
    },

    appendUserMessage: function(text) {
      var el = document.createElement('div');
      el.className = 'remix-message remix-message-user';
      el.innerHTML =
        '<div class="remix-message-header">' +
          '<strong><i class="fa fa-user"></i> You</strong>' +
          '<span class="timestamp">' + this.currentTime() + '</span>' +
        '</div>' +
        '<div class="remix-message-content">' + renderMarkdown(text) + '</div>';
      this.messagesEl.appendChild(el);
      this.scrollToBottom();
    },

    appendSystemNote: function(text) {
      var el = document.createElement('div');
      el.className = 'remix-system-note';
      el.textContent = text;
      this.messagesEl.appendChild(el);
      this.scrollToBottom();
    },

    appendErrorMessage: function(text) {
      var el = document.createElement('div');
      el.className = 'remix-message remix-message-error';
      el.innerHTML = '<div class="alert alert-danger"><strong>Error:</strong> ' + escapeHtml(text) + '</div>';
      this.messagesEl.appendChild(el);
      this.scrollToBottom();
    },

    scrollToBottom: function() {
      if (this.messagesEl) {
        this.messagesEl.scrollTop = this.messagesEl.scrollHeight;
      }
    },

    focusInput: function() {
      if (this.inputEl) this.inputEl.focus();
    },

    currentTime: function() {
      var now = new Date();
      return String(now.getHours()).padStart(2, '0') + ':' + String(now.getMinutes()).padStart(2, '0');
    }
  };

  // Expose on window so inline onclick handlers can call confirm/cancel
  window.RemixPage = RemixPage;

  // Initialize on page load
  document.addEventListener('DOMContentLoaded', function() {
    RemixPage.init();
  });
  document.addEventListener('turbolinks:load', function() {
    RemixPage.init();
  });
})();
