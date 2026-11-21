require "test_helper"

# What Duggan's computer sees of Update prices: claim a request, read it, and
# say when it couldn't start one.
class Api::V1::ResearchRequestsApiTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.zone.local(2026, 11, 21, 14)
    _, @raw = ApiToken.generate!(name: "research", scopes: [ "market:write" ])
  end

  def auth(raw = @raw)
    { "Authorization" => "Bearer #{raw}" }
  end

  def claim(client = "quattro-requests")
    post claim_api_v1_research_requests_path, params: { client_id: client }, headers: auth, as: :json
    response.parsed_body
  end

  test "it takes the research token" do
    post claim_api_v1_research_requests_path, params: { client_id: "x" }, as: :json
    assert_response :unauthorized

    _, settlements = ApiToken.generate!(name: "settlements", scopes: [ "settlements:write" ])
    post claim_api_v1_research_requests_path, params: { client_id: "x" }, headers: auth(settlements), as: :json
    assert_response :forbidden
  end

  test "claim hands over a waiting request once, with what to read and the run key" do
    assert_equal({ "request" => nil, "waiting" => "nothing is waiting" }, claim)

    request = ResearchRequest.request!(user: users(:admin), scope: "soon")
    body = claim
    assert_response :success
    assert_equal({ "id" => request.id, "scope" => "soon", "scope_label" => "Next 7 days", "within_days" => 7,
                   "run_key" => "tm-req-#{request.id}", "state" => "starting", "requested_by" => users(:admin).name },
                 body["request"].slice("id", "scope", "scope_label", "within_days", "run_key", "state", "requested_by"))
    assert_nil claim["request"]
  end

  test "the skill reads its request, and the run it starts with the run key carries it along" do
    request = ResearchRequest.request!(user: users(:admin), scope: "all")
    claim
    get api_v1_research_request_path(request), headers: auth
    assert_equal [ "all", nil, "starting", nil ], response.parsed_body.values_at("scope", "within_days", "state", "settled_at")

    post api_v1_import_runs_path, params: { kind: "market_research", source: "ticketmaster_browser", key: request.run_key,
                                            client_id: "skill", agent_version: "test" }, headers: auth, as: :json
    assert_response :created
    get api_v1_research_request_path(request), headers: auth
    assert_equal "running", response.parsed_body["state"]

    patch api_v1_import_run_path(ImportRun.find_by!(key: request.run_key)),
          params: { client_id: "skill", status: "completed", targeted: 0 }, headers: auth, as: :json
    get api_v1_research_request_path(request), headers: auth
    assert_equal "finished", response.parsed_body["state"]
    assert_equal Time.current.iso8601, response.parsed_body["settled_at"]
  end

  test "the computer reports a request it couldn't start: only failed, only by the client that claimed it" do
    request = ResearchRequest.request!(user: users(:admin), scope: "soon")
    claim("quattro-requests")

    patch api_v1_research_request_path(request), params: { client_id: "someone-else", status: "failed" }, headers: auth, as: :json
    assert_response :conflict
    patch api_v1_research_request_path(request), params: { client_id: "quattro-requests", status: "claimed" }, headers: auth, as: :json
    assert_response :unprocessable_entity

    patch api_v1_research_request_path(request), params: { client_id: "quattro-requests", status: "failed",
                                                           error: "research-window: Hyprland isn't running" }, headers: auth, as: :json
    assert_response :success
    assert_equal [ "failed", "failed" ], response.parsed_body.values_at("status", "state")
    assert_equal "research-window: Hyprland isn't running", request.reload.error

    patch api_v1_research_request_path(request), params: { client_id: "quattro-requests", status: "failed" }, headers: auth, as: :json
    assert_response :conflict
  end
end
