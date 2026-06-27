class RemixesController < ApplicationController
  include ActionController::Live

  skip_before_action :verify_authenticity_token, only: [:stream_message]
  before_action :authenticate_user!
  before_action :set_remix, only: [:show, :destroy, :message, :stream_message, :confirm_action, :cancel_action, :status]

  def index
    @remixes = current_user.remix_conversations.order(updated_at: :desc)
  end

  def show
    @messages = @remix.messages.order(:created_at)
  end

  def create
    @remix = current_user.remix_conversations.create!
    redirect_to remix_path(@remix)
  end

  def destroy
    @remix.destroy!
    redirect_to remixes_path, notice: 'Conversation deleted.'
  end

  # Non-streaming fallback for HTML form posts
  def message
    content = params[:content].to_s.strip

    if content.blank?
      respond_to do |format|
        format.json { render json: { success: false, error: 'Message content is required' }, status: :unprocessable_entity }
        format.html { redirect_to remix_path(@remix), alert: 'Please enter a message.' }
      end
      return
    end

    respond_to do |format|
      format.json do
        orchestrator = Remix::Orchestrator.new(@remix)
        @message = orchestrator.process_message(content)
        @messages = @remix.messages.order(:created_at)

        render json: {
          success: true,
          message: @message,
          messages: @messages.map { |m| message_to_json(m) }
        }
      rescue => e
        Rails.logger.error("Remix error: #{e.message}\n#{e.backtrace.first(10).join("\n")}")
        render json: { success: false, error: e.message }, status: :unprocessable_entity
      end

      format.html do
        orchestrator = Remix::Orchestrator.new(@remix)
        @message = orchestrator.process_message(content)
        redirect_to remix_path(@remix)
      rescue => e
        Rails.logger.error("Remix error: #{e.message}\n#{e.backtrace.first(10).join("\n")}")
        redirect_to remix_path(@remix), alert: "Error: #{e.message}"
      end
    end
  end

  # SSE streaming endpoint — called from JavaScript via POST with fetch()
  def stream_message
    content = params[:content].to_s.strip

    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['X-Accel-Buffering'] = 'no' # disable nginx buffering
    response.headers['Connection'] = 'keep-alive'

    if content.blank?
      response.stream.write "data: #{({ type: 'error', error: 'Message content is required' }).to_json}\n\n"
      response.stream.close
      return
    end

    # Mark the conversation as processing so other tabs/windows show a
    # thinking indicator if they navigate to this conversation.
    @remix.update_column(:processing, true)

    # Write an immediate event so the browser knows the connection is alive.
    # This prevents 504 Gateway Timeout from reverse proxies that require a
    # first byte within ~60 seconds.
    response.stream.write "data: #{({ type: 'stream_open' }).to_json}\n\n"

    # Start a heartbeat thread that sends SSE comments every 15 seconds.
    # SSE comments (lines starting with ":") are ignored by EventSource and
    # by our manual parser, but they keep the TCP connection alive through
    # proxies and load balancers.
    heartbeat_active = true
    heartbeat_thread = Thread.new do
      while heartbeat_active
        sleep 15
        begin
          response.stream.write ": heartbeat\n\n" if heartbeat_active
        rescue IOError, ActionController::Live::ClientDisconnected
          break
        end
      end
    end

    begin
      orchestrator = Remix::Orchestrator.new(@remix)
      orchestrator.process_message_streaming(content) do |sse_event|
        response.stream.write sse_event
      end
    rescue IOError, ActionController::Live::ClientDisconnected
      # Client disconnected — nothing to do
    rescue => e
      Rails.logger.error("Remix streaming error: #{e.message}\n#{e.backtrace.first(10).join("\n")}")
      begin
        response.stream.write "data: #{({ type: 'error', error: e.message }).to_json}\n\n"
      rescue IOError, ActionController::Live::ClientDisconnected
        # Client already gone
      end
    ensure
      heartbeat_active = false
      heartbeat_thread.kill rescue nil
      @remix.update_column(:processing, false) rescue nil
      response.stream.close rescue nil
    end
  end

  # Lightweight JSON endpoint to check if the conversation is still processing.
  # Used by the JS poller when the page loads mid-stream.
  def status
    render json: { processing: @remix.processing? }
  end

  def confirm_action
    tool_call_id = params[:tool_call_id]
    pending_message = @remix.messages.find_by(tool_call_id: tool_call_id)

    unless pending_message
      respond_to do |format|
        format.json { render json: { success: false, error: 'Pending action not found' }, status: :not_found }
        format.html { redirect_to remix_path(@remix), alert: 'Pending action not found.' }
      end
      return
    end

    result = JSON.parse(pending_message.content) rescue {}
    unless result['pending_confirmation']
      respond_to do |format|
        format.json { render json: { success: false, error: 'Action already processed' } }
        format.html { redirect_to remix_path(@remix) }
      end
      return
    end

    tool_class = Remix::ToolRegistry.find_tool(result['tool_name'])
    unless tool_class
      respond_to do |format|
        format.json { render json: { success: false, error: "Unknown tool: #{result['tool_name']}" } }
        format.html { redirect_to remix_path(@remix), alert: 'Unknown tool.' }
      end
      return
    end

    tool_params = result['params']
    tool_params = JSON.parse(tool_params) if tool_params.is_a?(String)

    # Execute the tool synchronously
    begin
      tool = tool_class.new(current_user)
      actual_result = tool.execute(tool_params)
      pending_message.update!(content: actual_result.to_json)

      log_tool_result(result['tool_name'], actual_result, error: false)
    rescue => e
      actual_result = { error: "Tool execution failed: #{e.message}" }
      pending_message.update!(content: actual_result.to_json)

      log_tool_result(result['tool_name'], actual_result, error: true)
    end

    begin
      orchestrator = Remix::Orchestrator.new(@remix)
      assistant_msg = orchestrator.continue_after_confirmation

      respond_to do |format|
        format.json do
          render json: {
            success: actual_result['success'],
            message: actual_result['message'] || 'Action executed.',
            assistant_message: assistant_msg&.content
          }
        end
        format.html { redirect_to remix_path(@remix) }
      end
    rescue => e
      respond_to do |format|
        format.json { render json: { success: false, error: e.message } }
        format.html { redirect_to remix_path(@remix), alert: "Error: #{e.message}" }
      end
    end
  end

  def cancel_action
    tool_call_id = params[:tool_call_id]
    pending_message = @remix.messages.find_by(tool_call_id: tool_call_id)

    if pending_message
      pending_message.update!(content: { cancelled: true, message: 'User cancelled operation' }.to_json)
      @remix.messages.create!(role: 'assistant', content: 'Operation cancelled by user.')
    end

    respond_to do |format|
      format.json { render json: { success: true, message: 'Operation cancelled.' } }
      format.html { redirect_to remix_path(@remix) }
    end
  end

  private

  def set_remix
    @remix = current_user.remix_conversations.find(params[:id])
  end

  def message_to_json(message)
    {
      id: message.id,
      role: message.role,
      content: message.content,
      tool_calls: message.tool_calls,
      tool_call_id: message.tool_call_id,
      tool_name: message.tool_name,
      created_at: message.created_at
    }
  end

  def log_tool_result(tool_name, result, error: false)
    level  = error ? 4 : 3
    status = error ? 'FAILED' : 'OK'
    msg    = "[Remix Tool] #{tool_name} #{status}"
    msg   += ": #{result[:error] || result['error']}" if error

    error ? Rails.logger.error(msg) : Rails.logger.info(msg)

    if (agent = current_user.agents.first)
      AgentLog.log_for_agent(agent, msg, level: level)
    end
  rescue => e
    Rails.logger.warn("Failed to log tool result for #{tool_name}: #{e.message}")
  end
end
