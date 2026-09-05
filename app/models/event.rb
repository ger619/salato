class Event < ApplicationRecord
  belongs_to :user
  # Every event belongs to the client that owns it. Organisers inherit their
  # own client automatically; admins pick one in the form. Optional so events
  # created before the column existed still load.
  belongs_to :client, optional: true
  delegate :paystack_subaccount_code, to: :client, prefix: true, allow_nil: true

  has_many :ticket_types, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :tickets, dependent: :destroy
  has_and_belongs_to_many :users, join_table: :events_users

  # The poster. Without this declaration `event.poster` doesn't exist, the
  # form field has nothing to write to, and the file is dropped on submit.
  has_one_attached :poster

  # Set to "1" by the Remove button in the poster band.
  attr_accessor :remove_poster

  POSTER_TYPES = %w[image/png image/jpeg image/webp].freeze
  POSTER_MAX_BYTES = 5.megabytes

  # Required for the tier rows in the event form to save. Without this the
  # form fields aren't even named ticket_types_attributes.
  accepts_nested_attributes_for :ticket_types,
                                allow_destroy: true,
                                reject_if: ->(attrs) { attrs['name'].blank? && attrs['price'].blank? }

  SLUG_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

  before_validation :assign_slug
  before_validation :inherit_client_from_creator, on: :create

  validates :name, presence: true, length: { maximum: 120 }
  validates :description, length: { maximum: 280 }
  validates :start_at, presence: true
  validates :slug,
            presence: true,
            uniqueness: { case_sensitive: false },
            format: { with: SLUG_FORMAT, message: 'can only use lowercase letters, numbers and dashes' }
  validate :end_after_start
  validate :at_least_one_ticket_type
  validate :poster_is_a_usable_image

  before_save :note_poster_purge
  after_save :purge_poster_if_noted

  scope :live, -> { where(active: true) }
  scope :upcoming, -> { where(start_at: Time.current..).order(:start_at) }

  def to_param
    slug
  end

  # True only when the poster can actually be turned into a URL. On a form
  # that failed validation the attachment exists in memory but its blob has
  # no id yet, and url_for would raise.
  def poster_previewable?
    poster.attached? && poster.blob&.persisted?
  end

  # Falls back to the original when image_processing isn't available for this
  # format, so a missing variant processor never takes down the page.
  def poster_variant(**)
    return nil unless poster_previewable?

    poster.variable? ? poster.variant(**) : poster
  end

  CHECK_IN_OPENS_BEFORE = 10.hours # doors open
  CHECK_IN_CLOSES_AFTER = 10.hours # grace period once it's over

  def check_in_opens_at
    start_at && (start_at - CHECK_IN_OPENS_BEFORE)
  end

  def check_in_closes_at
    return unless start_at

    try(:end_at) || (start_at + CHECK_IN_CLOSES_AFTER)
  end

  def check_in_open?(at = Time.current)
    return false unless check_in_opens_at

    at.between?(check_in_opens_at, check_in_closes_at)
  end

  private

  def inherit_client_from_creator
    self.client_id ||= user&.client_id
  end

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

  def poster_is_a_usable_image
    return unless poster.attached?

    blob = poster.blob
    return if blob.blank?

    errors.add(:poster, 'must be a JPG, PNG or WebP image') unless POSTER_TYPES.include?(blob.content_type)

    return unless blob.byte_size.to_i > POSTER_MAX_BYTES

    errors.add(:poster, "must be smaller than #{POSTER_MAX_BYTES / 1.megabyte} MB")
  end

  def note_poster_purge
    @purge_poster = ActiveModel::Type::Boolean.new.cast(remove_poster).present? &&
                    poster.attached? &&
                    attachment_changes['poster'].blank?
    true
  end

  def purge_poster_if_noted
    return unless @purge_poster

    @purge_poster = false
    poster.purge_later
  end
end
