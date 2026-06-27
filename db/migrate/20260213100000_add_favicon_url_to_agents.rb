class AddFaviconUrlToAgents < ActiveRecord::Migration[7.0]
  def up
    add_column :agents, :favicon_url, :string

    # Populate favicon_url for existing agents that have a favicon_url_option
    Agent.find_each do |agent|
      url_option_key = agent.class.favicon_url_option
      next unless url_option_key

      raw_url = agent.options[url_option_key]
      raw_url = raw_url.first if raw_url.is_a?(Array)
      raw_url = raw_url.to_s.strip

      favicon = if raw_url.present?
        begin
          domain = URI.parse(raw_url).host
          domain.present? ? "https://www.google.com/s2/favicons?domain=#{domain}&sz=16" : 'none'
        rescue URI::InvalidURIError
          'none'
        end
      else
        'none'
      end

      agent.update_column(:favicon_url, favicon)
    end
  end

  def down
    remove_column :agents, :favicon_url
  end
end
