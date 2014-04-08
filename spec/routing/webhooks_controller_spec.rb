require 'spec_helper'

describe "routing for web requests" do
  it "routes to handle_request" do
    resulting_params = { :user_id => "6", :agent_id => "2", :secret => "foobar" }
    get("/users/6/web_requests/2/foobar").should route_to("web_requests#handle_request", resulting_params)
    post("/users/6/web_requests/2/foobar").should route_to("web_requests#handle_request", resulting_params)
    put("/users/6/web_requests/2/foobar").should route_to("web_requests#handle_request", resulting_params)
    delete("/users/6/web_requests/2/foobar").should route_to("web_requests#handle_request", resulting_params)
  end

  it "supports the legacy /webhooks/ route" do
    post("/users/6/webhooks/2/foobar").should route_to("web_requests#handle_request", :user_id => "6", :agent_id => "2", :secret => "foobar")
  end

  it "routes with format" do
    get("/users/6/web_requests/2/foobar.json").should route_to("web_requests#handle_request",
                                                           { :user_id => "6", :agent_id => "2", :secret => "foobar", :format => "json" })

    get("/users/6/web_requests/2/foobar.atom").should route_to("web_requests#handle_request",
                                                           { :user_id => "6", :agent_id => "2", :secret => "foobar", :format => "atom" })
  end
end
