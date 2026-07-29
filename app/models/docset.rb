class Docset < ActiveRecord::Base
  has_many :docset_pages, dependent: :destroy
  has_many :docset_chunks, dependent: :destroy

  STATUSES = %w[pending downloading extracting indexing ready error].freeze
  SOURCES = %w[official user_contributed custom openapi].freeze

  validates :name, presence: true, uniqueness: true
  validates :display_name, presence: true
  validates :identifier, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :source, presence: true, inclusion: { in: SOURCES }

  scope :ready, -> { where(status: 'ready') }
  scope :by_name, ->(q) { where("#{table_name}.display_name LIKE ?", "%#{q}%") }

  def ready?
    status == 'ready'
  end

  def installing?
    %w[pending downloading extracting indexing].include?(status)
  end

  def error?
    status == 'error'
  end
end
