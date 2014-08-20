module MarkdownHelper

  def markdown(text)
    Kramdown::Document.new(text, :auto_ids => false).to_html.html_safe
  end

end
