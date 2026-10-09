Rails.application.config.after_initialize do
  UiLocale.ensure_available!
end
