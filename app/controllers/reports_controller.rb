# The weekly report: one week rebuilt from stored history.
class ReportsController < ApplicationController
  def weekly
    @season = current_season
    return redirect_to root_path, alert: "No current season" unless @season

    week = params[:week].present? ? Date.iso8601(params[:week]) : Date.current
    return redirect_to weekly_report_path if week > Date.current

    @report = Reports::Weekly.new(@season, week: week)
  rescue Date::Error
    redirect_to weekly_report_path, alert: "That isn't a date."
  end
end
