module Api
  module V1
    # One game's scan inside a research run. Idempotent: the same scan again
    # returns the stored snapshot (200); a different one is refused (409).
    class MarketScansController < BaseController
      before_action { require_scope!("market:write") }

      def create
        run = ImportRun.market_research.find(params[:import_run_id])
        client_id = params.require(:client_id)
        return render_error(:conflict, "not_holder", "run #{run.key} isn't running or is held by another client") unless run.held_by?(client_id)

        game = Game.find(params.require(:game_id))
        result = Market::ScanIngest.new(run: run, game: game, payload: scan_params).call
        run.renew!(client_id)
        render json: snapshot_json(result.snapshot).merge(replayed: result.replayed), status: result.replayed ? :ok : :created
      rescue Market::ScanIngest::Conflict => e
        render_error(:conflict, "conflict", e.message)
      rescue Market::ScanIngest::Invalid => e
        render_error(:unprocessable_entity, "invalid", e.message)
      end

      private

      def scan_params
        params.permit(:event_id, :event_url, :event_title, :event_date, :event_total_listings, :scroll_complete,
                      :captured_at, :quantity_filter, listings: [ :position, :section, :row, :price, :ticket_type, :raw_label ])
              .to_h
      end
    end
  end
end
