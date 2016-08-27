module ServiceOptionProviders
  class ThirtySevenSignalsOptionProvider
    def options(omniauth)
      {user_id: omniauth['extra']['accounts'][0]['id'], name: omniauth['info']['name']}
    end
  end
end
