class DocsetPage < ActiveRecord::Base
  belongs_to :docset
  has_many :docset_chunks, dependent: :destroy

  validates :path, presence: true
  validates :path, uniqueness: { scope: :docset_id }
end
