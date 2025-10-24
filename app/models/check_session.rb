class CheckSession < ApplicationRecord
  has_many :check_results, dependent: :destroy

  validates :target_url, presence: true
end
