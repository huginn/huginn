server ENV['CAPISTRANO_DEPLOY_SERVER'],
  user: ENV['CAPISTRANO_DEPLOY_USER'] || 'huginn',
  port: ENV['CAPISTRANO_DEPLOY_PORT'] || 22,
  roles: %w{app db web}
