require 'date'
require 'cgi'
module Agents
  class CodeAgent < Agent
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
      var pd = JSON.stringify({hello: "doctor", dil: "chori"});
      create_event(pd);
    }
    H
    end
    def execute_js
      context = V8::Context.new
      context.eval(example_js)
      context.eval(options['code']) # should override the run function.
      #
      context["create_event"] = lambda {|payload| create_event :payload => {:no => "true"}}
      context.eval("a = new Agent(1,1,1,1)")
      context.eval("a.run();")
      context["create_event"] = lambda {|x,y| puts x; puts y; create_event payload: JSON.parse(y)}
      #cxt["create_event"] = lambda {|this, payload| puts a.inspect}

    end
  end
end
