# Be sure to restart your server when you modify this file.

Rails.application.config.assets.enabled = true
Rails.application.config.assets.initialize_on_precompile = false

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# Font Awesome (from npm)
fa_path = Rails.root.join("node_modules/@fortawesome/fontawesome-free")
Rails.application.config.assets.paths << fa_path.join("css").to_s
Rails.application.config.assets.paths << fa_path.join("webfonts").to_s

Rails.application.config.assets.precompile += %w[
  fa-solid-900.woff2
  fa-regular-400.woff2
  fa-brands-400.woff2
]
