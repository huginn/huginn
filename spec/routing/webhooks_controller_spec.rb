require 'rails_helper'

describe "routing for web requests", :type => :routing do
  it "routes to handle_request" do
    resulting_params = { :user_id => "6", :agent_id => "2", :secret => "foobar" }
    expect(get("/users/6/web_requests/2/foobar")).to route_to("web_requests#handle_request", resulting_params)
    expect(post("/users/6/web_requests/2/foobar")).to route_to("web_requests#handle_request", resulting_params)
    expect(put("/users/6/web_requests/2/foobar")).to route_to("web_requests#handle_request", resulting_params)
    expect(delete("/users/6/web_requests/2/foobar")).to route_to("web_requests#handle_request", resulting_params)
  end

  it "supports the legacy /webhooks/ route" do
    expect(post("/users/6/webhooks/2/foobar")).to route_to("web_requests#handle_request", :user_id => "6", :agent_id => "2", :secret => "foobar")
  end

  it "routes with format" do
    expect(get("/users/6/web_requests/2/foobar.json")).to route_to("web_requests#handle_request",
                                                           { :user_id => "6", :agent_id => "2", :secret => "foobar", :format => "json" })

    expect(get("/users/6/web_requests/2/foobar.atom")).to route_to("web_requests#handle_request",
                                                           { :user_id => "6", :agent_id => "2", :secret => "foobar", :format => "atom" })
  end
end
