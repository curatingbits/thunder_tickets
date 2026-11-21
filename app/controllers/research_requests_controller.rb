# Update prices on the Pricing page: ask Duggan's computer to research
# Ticketmaster now (ResearchRequest), or cancel a request it hasn't picked up
# yet. Index is the research panel alone, which the page re-reads while an
# update waits or runs (research_panel_controller.js).
class ResearchRequestsController < ApplicationController
  def index
    return head :no_content unless current_season

    render_panel
  end

  def create
    ResearchRequest.request!(user: current_user, scope: params[:scope].to_s)
    respond
  rescue ResearchRequest::Refused => e
    respond(alert: e.message)
  end

  def cancel
    ResearchRequest.find(params[:id]).cancel!
    respond
  rescue ResearchRequest::Refused => e
    respond(alert: e.message)
  end

  private

  # In the panel's frame, show the panel again; anywhere else, the page.
  def respond(alert: nil)
    if !turbo_frame_request?
      redirect_to pricing_path, alert: alert
    elsif alert
      render_panel(alert: alert, status: :unprocessable_entity)
    else
      redirect_to research_requests_path, status: :see_other
    end
  end

  def render_panel(alert: nil, status: :ok)
    render partial: "research_requests/panel", status: status,
           locals: { panel: ResearchPanel.new(season: current_season), alert: alert }
  end
end
