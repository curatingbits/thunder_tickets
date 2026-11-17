class GamesController < ApplicationController
  before_action :set_game, only: [ :show, :edit, :update ]

  def index
    @season = viewed_season
    @seasons = Season.order(year: :desc)
    @games = @season ? @season.games.includes(:opponent, :tickets, :listings, :listing_events).order(:game_date) : Game.none

    # Filter by status
    case params[:filter]
    when "sold"
      @games = @games.fully_sold
    when "unsold"
      @games = @games.left_joins(:tickets).where(tickets: { id: nil })
    when "upcoming"
      @games = @games.upcoming
    when "past"
      @games = @games.past
    when "attention"
      # Same rule as the dashboard's attention list: the next week's games
      # that still have seats to sell.
      @games = @games.where(game_date: Date.current..(Date.current + Attention::Feed::WINDOW_DAYS))
                     .where.not(id: Game.fully_sold.select(:id))
    end
  end

  def show
    # A game carries its own season, so past-season games render correctly
    # even when the session is pointed at the current year.
    @season = @game.season
    ActiveRecord::Associations::Preloader.new(records: [ @game ], associations: [ :tickets, :listings, { listing_events: :user } ]).call
    @available_seats = (1..@season.num_seats).to_a - @game.tickets.pluck(:seat_number)
    @buyers = Buyer.by_name
  end

  def new
    @game = current_season.games.build(game_type: "playoff")
    @teams = Team.order(:name)
  end

  def create
    @game = current_season.games.build(game_params)
    # Auto-assign next game number for playoffs
    @game.game_number = current_season.games.maximum(:game_number).to_i + 1

    if @game.save
      game_type_label = @game.nba_cup? ? "NBA Cup" : @game.game_type.titleize
      redirect_to @game, notice: "#{game_type_label} game added successfully"
    else
      @teams = Team.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @teams = Team.order(:name)
  end

  def update
    if @game.update(game_params)
      redirect_to @game, notice: "Game updated successfully"
    else
      @teams = Team.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_game
    @game = Game.find(params[:id])
  end

  def game_params
    params.require(:game).permit(:game_date, :opponent_id, :cost_per_ticket, :parking_cost, :game_type, :playoff_round, :receipt_image)
  end
end
