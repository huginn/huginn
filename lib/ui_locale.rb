# Checks the UI locale selected through the LOCALE environment variable.
module UiLocale
  module_function

  def ensure_available!(locale = I18n.default_locale)
    return if I18n.available_locales.include?(locale.to_sym)

    raise ArgumentError,
          "LOCALE is set to #{locale.to_s.inspect}, but no translations are available for it " \
          "(available locales: #{I18n.available_locales.join(', ')}).  " \
          "Install a translation gem that provides it through ADDITIONAL_GEMS."
  end
end
