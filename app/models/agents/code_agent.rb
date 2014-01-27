require 'date'
require 'cgi'
module Agents
  class CodeAgent < Agent
    description <<-MD
      Here is an agent that gives you the ability to specify your own code. We have already provided you
      a javascript object that has read access to this agent's memory, events, options and the attributes of the agent.
      We also provide you with a method to create events on the server.
      You will be provided with an instance of the Agent object in javascript, with access to the above data.
      You can create events based on your own logic.
      Specifically, you have the following class

          function Agent(m, e, o, agent){
          this.memory = JSON.parse(m);
          this.events = JSON.parse(e);
          this.options = JSON.parse(o);
          this.agent = JSON.parse(agent);
          }
          Agent.prototype.print_memory = function(){
            return this.memory;
          }
          Agent.prototype.run = function(){
            //Implement me
            // Example create a new event with the following code:
            //var new_event = JSON.stringify({key1: "val1", key2: "val2"});
            //create_event(pd);
          }
      You need to provide the code for the Agent::run function. You code will override any methods already present in the Agent if it has to, and you can use other methods as well with access to the agent properties. You need to at least provide the implementation of Agent.prototype.run so that it can be called periodically, or it can execute when an event happens.

      We will yield control to your implementation in the following way:

          context.eval("a = new Agent(memory, events, options, agent)")
          context.eval("a.run();")

      You need to provide the run() implementation, as well as other methods it may need to interact with.

    MD
    def example_js
    <<-H
    function Agent(m, e, o, agent){
    this.memory = JSON.parse(m);
    this.events = JSON.parse(e);
    this.options = JSON.parse(o);
    this.agent = JSON.parse(agent);
    }
    Agent.prototype.print_memory = function(){
      return this.memory;
    }
    Agent.prototype.run = function(){
      //have access to this.memory, this.events, this.options, and this.agent;
      // do computation...
      //...
      var pd = JSON.stringify({memory: this.memory, events: this.events, options: this.options});
      create_event(pd);
    }
    H
    end

    def working?
      true
    end

    def execute_js
      context = V8::Context.new
      context.eval(example_js)
      context.eval(options['code']) # should override the run function.
      context["create_event"] = lambda {|x,y| puts x; puts y; create_event payload: JSON.parse(y)}
      a, m, e, o = [self.attributes.to_json, self.memory.to_json, self.events.to_json, self.options.to_json]
      string = "a = new Agent('#{m}','#{e}','#{o}','#{a}');"
      context.eval(string)
      context.eval("a.run();")
    end
  end
end
