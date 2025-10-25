class Team < ApplicationRecord
  has_many :games, foreign_key: :opponent_id

  validates :name, presence: true, uniqueness: true
  validates :abbreviation, presence: true
end
