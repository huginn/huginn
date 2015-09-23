require 'huginn_agent'

HuginnAgent.hack_huginn_to_accept_me

HuginnAgent.types.each { |t| t.emit }
