# app/models/user.rb
class User < ApplicationRecord
  rolify

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :invitable, :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :lockable, :timeoutable, :trackable # , :confirmable

  belongs_to :client, optional: true
  accepts_nested_attributes_for :client
  has_one_attached :id_photo

  attr_accessor :role

  has_many :events, dependent: :restrict_with_error # events they own
  has_and_belongs_to_many :staffed_events,
                          class_name: 'Event',
                          join_table: :events_users # events they work the door on

  validates :first_name, :last_name, presence: true

  after_create :assign_default_role

  ROLES = %w[admin organiser scanner].freeze

  # Who each role may invite. An organiser can't mint an admin, and a scanner
  # can't invite at all.
  ASSIGNABLE_ROLES = {
    'admin' => %w[admin organiser scanner],
    'organiser' => %w[organiser scanner],
    'scanner' => []
  }.freeze

  def organiser? = has_role?(:organiser)
  def admin? = has_role?(:admin)
  def scanner? = has_role?(:scanner)

  def assignable_roles
    roles.pluck(:name)
      .flat_map { |name| ASSIGNABLE_ROLES.fetch(name, []) }
      .uniq
      .sort_by { |name| ROLES.index(name) }
  end

  def can_invite?
    assignable_roles.any?
  end

  def full_name
    [first_name, last_name].compact_blank.join(' ').presence
  end

  def onboarding_complete?
    return true if admin? || scanner?

    client.present?
  end

  def toggle_boolean(attribute)
    update(attribute => !self[attribute])
  end

  private

  # Devise sends its mail inline (deliver_now) by default. That means an
  # invitation is delivered inside the web request: a slow or failing SMTP
  # call blocks the response, and because raise_delivery_errors is on in
  # production a transient Resend error would 500 the invite AND leave an
  # invited user row behind with no email ever sent.
  #
  # Push it onto the "mailers" Sidekiq queue instead, so delivery is retried
  # on failure and the request returns immediately. Safe for :invitable —
  # devise_invitable saves the record before calling deliver_invitation, so
  # the row is committed by the time the job picks it up, and the raw
  # invitation token travels with the job arguments.
  def send_devise_notification(notification, *)
    devise_mailer.send(notification, self, *).deliver_later
  end

  def assign_default_role
    return if invited_by_id.present? # invited users get their role from the inviter

    add_role(:organiser)
  end
end
