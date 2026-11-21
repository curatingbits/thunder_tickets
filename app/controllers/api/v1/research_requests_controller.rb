module Api
  module V1
    # Update prices requests, for Duggan's computer. bin/research-requests
    # claims the oldest waiting one and starts the research for it; the skill
    # reads it to learn which games to read and the run key to use; and the
    # computer reports a request it couldn't start.
    class ResearchRequestsController < BaseController
      before_action { require_scope!("market:write") }
      before_action :set_research_request, only: [ :show, :update ]

      # Always 200: { request: {...} } to start, or { request: null, waiting: "why" }.
      def claim
        research_request, reason = ResearchRequest.claim!(client_id: params.require(:client_id).to_s.first(100))
        render json: { request: research_request && request_json(research_request), waiting: reason }
      end

      def show
        render json: request_json(@research_request)
      end

      # Only to say it failed, and only by the client that claimed it.
      def update
        unless params.require(:status) == "failed"
          return render_error(:unprocessable_entity, "invalid", "status can only be failed")
        end
        unless @research_request.client_id.present? && @research_request.client_id == params.require(:client_id)
          return render_error(:conflict, "not_holder", "this request was claimed by another client")
        end

        @research_request.fail!(params[:error].presence || "Duggan's computer couldn't start the research.")
        render json: request_json(@research_request)
      rescue ResearchRequest::Refused => e
        render_error(:conflict, "conflict", e.message)
      end

      private

      def set_research_request
        @research_request = ResearchRequest.find(params[:id])
      end

      def request_json(research_request)
        now = Time.current
        {
          id: research_request.id, scope: research_request.scope, scope_label: research_request.scope_label,
          within_days: research_request.within_days, run_key: research_request.run_key,
          status: research_request.status, state: research_request.state(now),
          requested_by: research_request.user.name, requested_at: research_request.created_at.iso8601,
          claimed_at: research_request.claimed_at&.iso8601, settled_at: research_request.settled_at(now)&.iso8601,
          error: research_request.error
        }
      end
    end
  end
end
