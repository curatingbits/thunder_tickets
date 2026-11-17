module Api
  module V1
    # JSON API for the workstation skills. Deliberately not
    # ApplicationController: no session, no cookies, no login redirect, and no
    # CSRF (there's no cookie to forge). Just a bearer token, checked against
    # its stored digest, with scopes.
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      MAX_BODY = 1.megabyte
      # Rails.cache is a null store in tests, which would make every limit a no-op.
      RATE_STORE = Rails.env.test? ? ActiveSupport::Cache::MemoryStore.new : Rails.cache

      before_action :reject_oversized_body
      before_action :authenticate!
      rate_limit to: 120, within: 1.minute, by: -> { current_api_token.id }, store: RATE_STORE,
                 with: -> { render_error(:too_many_requests, "rate_limited", "Too many requests; slow down.") }

      rescue_from ActiveRecord::RecordNotFound do |error|
        render_error(:not_found, "not_found", error.message)
      end
      rescue_from ActionController::ParameterMissing do |error|
        render_error(:unprocessable_entity, "invalid", error.message)
      end

      attr_reader :current_api_token

      private

      def authenticate!
        @current_api_token = authenticate_with_http_token { |raw, _options| ApiToken.authenticate(raw) }
        render_error(:unauthorized, "unauthorized", "Missing, revoked or unknown API token.") unless @current_api_token
      end

      def require_scope!(scope)
        return if current_api_token.allows?(scope)

        render_error(:forbidden, "forbidden", "This token doesn't have the #{scope} scope.")
      end

      def reject_oversized_body
        return unless request.content_length.to_i > MAX_BODY

        render_error(:payload_too_large, "too_large", "Request body is over 1 MB.")
      end

      def render_error(status, code, message)
        render json: { error: { code: code, message: message } }, status: status
      end

      def snapshot_json(snapshot)
        {
          id: snapshot.id, game_id: snapshot.game_id, captured_at: snapshot.captured_at.iso8601,
          days_to_game: snapshot.days_to_game, captured: snapshot.captured_count,
          comparables: { tier1: snapshot.tier1_count, tier2: snapshot.tier2_count, tier3: snapshot.tier3_count },
          section: { count: snapshot.section_count, min: snapshot.section_min&.to_f, median: snapshot.section_median&.to_f,
                     max: snapshot.section_max&.to_f },
          prices_all_in: { competitive: snapshot.competitive_price&.to_f, market: snapshot.market_value&.to_f,
                           premium: snapshot.premium_price&.to_f },
          recommended: { strategy: snapshot.recommended_strategy, list_price: snapshot.recommended_list_price&.to_f },
          buyer_fee_multiplier: snapshot.buyer_fee_multiplier.to_f, fee_verified: snapshot.fee_verified,
          confidence: snapshot.confidence_now, confidence_label: snapshot.confidence_label,
          assessment: snapshot.assessment, change_pct: snapshot.market_value_change_pct&.to_f,
          rationale: snapshot.rationale
        }
      end
    end
  end
end
