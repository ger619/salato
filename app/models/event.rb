class Event < ApplicationRecord
  belongs_to :user

  has_many :ticket_types, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :tickets, dependent: :destroy

  # Required for the tier rows in the event form to save. Without this the
  # form fields aren't even named ticket_types_attributes.
  accepts_nested_attributes_for :ticket_types,
                                allow_destroy: true,
                                reject_if: ->(attrs) { attrs['name'].blank? && attrs['price'].blank? }

  SLUG_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

  before_validation :assign_slug

  validates :name, presence: true, length: { maximum: 120 }
  validates :description, length: { maximum: 280 }
  validates :start_at, presence: true
  validates :slug,
            presence: true,
            uniqueness: { case_sensitive: false },
            format: { with: SLUG_FORMAT, message: 'can only use lowercase letters, numbers and dashes' }
  validate :end_after_start
  validate :at_least_one_ticket_type

  scope :live, -> { where(active: true) }
  scope :upcoming, -> { where(start_at: Time.current..).order(:start_at) }

  def to_param
    slug
  end

  private

  def assign_slug
    self.slug = (slug.presence || name).to_s.parameterize
    return if slug.blank?

    # Only de-duplicate for records that haven't been published yet.
    return if persisted?

    base = slug
    suffix = 2
    while Event.where(slug: slug).exists?
      self.slug = "#{base}-#{suffix}"
      suffix += 1
    end
  end

  def end_after_start
    return if end_at.blank? || start_at.blank?

    errors.add(:end_at, 'must come after the start time') if end_at < start_at
  end

  def at_least_one_ticket_type
    remaining = ticket_types.reject(&:marked_for_destruction?)
    return if remaining.any?

    errors.add(:base, 'Add at least one ticket type before publishing')
  end
end
