module ScenarioImportUrlFetching
  def fetch_url
    if data.blank? && url.present? && url =~ self.class::URL_REGEX
      self.data = SafeScenarioUrlFetcher.fetch(url)
    end
  rescue SafeScenarioUrlFetcher::Error => e
    errors.add(:url, e.message)
  end
end

Rails.application.config.to_prepare do
  require_dependency 'scenario_import'
  require_dependency 'safe_scenario_url_fetcher'

  ScenarioImport.prepend(ScenarioImportUrlFetching) unless ScenarioImport < ScenarioImportUrlFetching
end
