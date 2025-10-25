class BuyersController < ApplicationController
  before_action :set_buyer, only: [:show, :edit, :update, :destroy]

  def index
    @buyers = Buyer.by_name.includes(:tickets)
  end

  def show
    @tickets = @buyer.tickets.includes(:game).order("games.game_date DESC")
  end

  def new
    @buyer = Buyer.new
  end

  def create
    @buyer = Buyer.new(buyer_params.except(:inline))
    inline_creation = params[:buyer][:inline] == "true"

    if @buyer.save
      if inline_creation
        render json: {
          buyer: {
            id: @buyer.id,
            name: @buyer.name,
            email: @buyer.email
          }
        }
      else
        redirect_to @buyer, notice: "Buyer created successfully."
      end
    else
      if inline_creation
        render json: { errors: @buyer.errors.full_messages }, status: :unprocessable_entity
      else
        render :new, status: :unprocessable_entity
      end
    end
  end

  def edit
  end

  def update
    if @buyer.update(buyer_params)
      redirect_to @buyer, notice: "Buyer updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @buyer.destroy
    redirect_to buyers_path, notice: "Buyer deleted successfully."
  end

  private

  def set_buyer
    @buyer = Buyer.find(params[:id])
  end

  def buyer_params
    params.require(:buyer).permit(:name, :email, :notes, :inline)
  end
end
