module Api
  module V1
    # What's owed and what needs review, plus the date range the settlement
    # skill should fetch from the finance app.
    class SettlementSummariesController < BaseController
      before_action { require_scope!("settlements:write") unless current_api_token.allows?("read") }

      def show
        render json: Settlements::ApiJson.call
      end
    end
  end
end
