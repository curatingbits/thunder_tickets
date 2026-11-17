module Api
  module V1
    # Start/resume a run (POST), read its results (GET), finish it (PATCH).
    class ImportRunsController < BaseController
      SCOPE_BY_KIND = { "market_research" => "market:write", "payment_sync" => "settlements:write" }.freeze
      FINAL_STATUSES = %w[completed partial blocked failed].freeze

      before_action :set_run, only: [ :show, :update ]

      def create
        kind = params.require(:kind)
        scope = SCOPE_BY_KIND[kind] or return render_error(:unprocessable_entity, "invalid", "unknown kind #{kind}")
        return require_scope!(scope) unless current_api_token.allows?(scope)

        run, outcome = ImportRun.start!(
          kind: kind, source: params.require(:source), key: params.require(:key), client_id: params.require(:client_id),
          api_token: current_api_token, agent_version: params[:agent_version],
          params: params[:params].respond_to?(:to_unsafe_h) ? params[:params].to_unsafe_h : {}
        )
        render json: run_json(run), status: outcome == :created ? :created : :ok
      rescue ImportRun::Conflict => e
        render_error(:conflict, "conflict", e.message)
      rescue ActiveRecord::RecordInvalid => e
        render_error(:unprocessable_entity, "invalid", e.record.errors.full_messages.to_sentence)
      end

      def show
        render json: run_json(@run, results: true)
      end

      # Finish the run. Only the client holding it (or anyone once the lease
      # has lapsed) can.
      def update
        status = params.require(:status)
        unless FINAL_STATUSES.include?(status)
          return render_error(:unprocessable_entity, "invalid", "status must be one of #{FINAL_STATUSES.join(', ')}")
        end
        return render_error(:conflict, "not_holder", "this run is held by another client") unless @run.held_by?(params.require(:client_id))

        Array(params[:errors]).each { |message| @run.log_error!(message.to_s.first(500)) }
        @run.finish!(status, targeted: params[:targeted]&.to_i, notes: params[:notes].to_s.first(2000).presence)
        render json: run_json(@run, results: true)
      end

      private

      def set_run
        @run = ImportRun.find(params[:id])
        scope = SCOPE_BY_KIND.fetch(@run.kind)
        require_scope!(scope) unless current_api_token.allows?(scope)
      end

      def run_json(run, results: false)
        snapshots = run.market_snapshots.includes(game: :opponent).order(:captured_at)
        json = {
          id: run.id, key: run.key, kind: run.kind, status: run.status, started_at: run.started_at.iso8601,
          finished_at: run.finished_at&.iso8601, lease_owner: run.lease_owner, stats: run.stats,
          notes: run.notes, errors: run.error_log, scanned_game_ids: snapshots.map(&:game_id)
        }
        if results
          json[:results] = snapshots.map do |s|
            snapshot_json(s).merge(date: s.game.game_date.iso8601, opponent: s.game.opponent.name)
          end
        end
        json
      end
    end
  end
end
