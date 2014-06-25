module SpecHelpers
  def self.included(klass)
    klass.class_eval do 
      include BuildEvents
      include TwitterCredentials
    end
  end
end