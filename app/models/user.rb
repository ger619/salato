class User < ApplicationRecord
  rolify
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :invitable, :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  belongs_to :client, optional: true

  has_many :events, dependent: :restrict_with_error # events they own
  has_and_belongs_to_many :staffed_events,
                          class_name: 'Event',
                          join_table: :events_users # events they work the door on
  attr_accessor :role

  def organiser? = has_role?(:organiser)

  ROLES = %w[admin organiser scanner].freeze

  # Who each role may invite. An organiser can't mint an admin, and a scanner
  # can't invite at all.
  ASSIGNABLE_ROLES = {
    'admin' => %w[admin organiser scanner],
    'organiser' => %w[organiser scanner],
    'scanner' => []
  }.freeze

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
    !organiser? || client.present?
  end
end
