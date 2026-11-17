module Api
  module V1
    # Venmo payments read from the finance app, posted by the settlement skill.
    # Idempotent by key: the same key again returns the stored summary.
    class PaymentImportsController < BaseController
      before_action { require_scope!("settlements:write") }
      rate_limit to: 20, within: 1.hour, by: -> { current_api_token.id }, store: RATE_STORE, name: "payment_imports",
                 with: -> { render_error(:too_many_requests, "rate_limited", "Too many imports this hour.") }

      def create
        key = params.require(:key)
        if (existing = ImportRun.find_by(key: key))
          return render_error(:conflict, "conflict", "key #{key} belongs to another kind of run") unless existing.kind == "payment_sync"

          return render json: summary_json(existing).merge(replayed: true)
        end

        transactions = params.require(:transactions).map do |tx|
          tx.permit(:id, :plaid_transaction_id, :date, :amount, :name, :pending, :account).to_h
        end
        window = params[:window].respond_to?(:permit) ? params[:window].permit(:from, :to).to_h : nil
        run = ImportRun.start!(kind: "payment_sync", source: params[:source].presence || "finance_api", key: key,
                               client_id: "api-#{current_api_token.id}", api_token: current_api_token).first
        begin
          summary = Settlements::Importer.new(run: run, transactions: transactions, window: window,
                                              complete: ActiveModel::Type::Boolean.new.cast(params[:complete]),
                                              api_token: current_api_token).call
          run.update!(status: "completed", finished_at: Time.current, stats: summary.to_h)
        rescue ArgumentError, KeyError, Date::Error, ActiveRecord::RecordInvalid => e
          run.update!(status: "failed", finished_at: Time.current)
          run.log_error!(e.message.first(500))
          return render_error(:unprocessable_entity, "invalid", e.message)
        end
        render json: summary_json(run).merge(replayed: false), status: :created
      rescue ImportRun::Conflict => e
        render_error(:conflict, "conflict", e.message)
      end

      private

      def summary_json(run)
        { id: run.id, key: run.key, status: run.status, stats: run.stats, settlement: Settlements::ApiJson.call }
      end
    end
  end
end
