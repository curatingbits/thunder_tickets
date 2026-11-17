# The log of research (and later payment) runs: what ran, when, how far it
# got, and any errors.
class ImportRunsController < ApplicationController
  def index
    @runs = ImportRun.recent_first.limit(50)
    @snapshot_counts = MarketSnapshot.where(import_run_id: @runs.map(&:id)).group(:import_run_id).count
  end

  def show
    @run = ImportRun.find(params[:id])
    @snapshots = @run.market_snapshots.includes(game: :opponent).order(:days_to_game)
  end
end
