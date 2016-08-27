module ServiceOptionProviders
  class DefaultServiceOptionProvider
    def options(omniauth)
      {name: omniauth['info']['nickname'] || omniauth['info']['name']}
    end
  end
end
