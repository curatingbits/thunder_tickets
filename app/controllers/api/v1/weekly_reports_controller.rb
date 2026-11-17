module Api
  module V1
    # GET /api/v1/weekly_report?week=YYYY-MM-DD (any day of the week; default
    # this week). Read-only; any workstation token may read it.
    class WeeklyReportsController < BaseController
      def show
        season = Season.find_by(is_current: true)
        return render_error(:not_found, "no_season", "No current season.") unless season

        week = params[:week].present? ? Date.iso8601(params[:week]) : Date.current
        render json: Reports::WeeklyJson.call(Reports::Weekly.new(season, week: [ week, Date.current ].min))
      rescue Date::Error
        render_error(:unprocessable_entity, "invalid", "week must be a date (YYYY-MM-DD)")
      end
    end
  end
end
