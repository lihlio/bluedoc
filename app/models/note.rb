class Note < ApplicationRecord
  include Slugable
  include Activityable
  include Smlable
  include Reactionable

  second_level_cache expires_in: 1.week

  validates :title, presence: true, length: { maximum: 255 }
  validates :slug, length: { maximum: 200 }, uniqueness: { scope: :user_id, case_sensitive: false }

  scope :recent, -> { order("id desc") }

  belongs_to :user
  has_many :comments, as: :commentable, dependent: :destroy

  depends_on :privacy, :publish, :body_touch, :versions

  def to_path(suffix = nil)
    "#{user.to_path}/notes/#{self.slug}#{suffix}"
  end

  # return next and prev of notes in same user
  # { next: Note, prev: Note }
  def prev_and_next_of_notes
    return @prev_and_next_of_notes if defined? @prev_and_next_of_notes
    result = { next: nil, prev: nil }
    recent_docs = self.user.notes.recent
    idx = recent_docs.find_index { |note| note.id == self.id }
    return nil if idx.nil?
    if idx < recent_docs.length
      result[:next] = recent_docs[idx + 1]
    end
    if idx > 0
      result[:prev] = recent_docs[idx - 1]
    end
    @prev_and_next_of_notes = result
    @prev_and_next_of_notes
  end

  class << self
    def create_new(user_id, slug: nil)
      note = Note.new
      note.format = "sml"
      note.user_id = user_id
      note.title = "New Note"
      note.slug = slug || BlueDoc::Slug.random(seed: 999999)
      note.save!
      note
    rescue ActiveRecord::RecordNotUnique
      slug = nil
      retry
    end
  end
end
