# Create random key based on the OPENSHIFT_SECRET_TOKEN

def initialize_secret(name,default)
  # Only generate token based if we're running on OPENSHIFT
  if secret = get_env_secret
    # Create seed for random function from secret and name
    seed = [secret,name.to_s].join('-')
    # Generate hash from seed
    hash = Digest::SHA512.hexdigest(seed)
    # Set token, ensuring it is the same length as the default
    hash[0,default.length]
  else
    Rails.logger.warn "Unable to get OPENSHIFT_SECRET_TOKEN, using default"
    default
  end
end

def get_env_secret
  ENV['OPENSHIFT_SECRET_TOKEN'] || generate_secret_token
end

def generate_secret_token
  Rails.logger.debug "No secret token environment variable set"
  (name,uuid) = ENV.values_at('OPENSHIFT_APP_NAME','OPENSHIFT_APP_UUID')
  if name && uuid
    Rails.logger.debug "Running on Openshift, creating OPENSHIFT_SECRET_TOKEN"
    Digest::SHA256.hexdigest([name,uuid].join('-'))
  else
    nil
  end
end
