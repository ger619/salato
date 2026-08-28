# app/models/user.rb
class User < ApplicationRecord
  rolify

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :invitable, :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  belongs_to :client, optional: true
  accepts_nested_attributes_for :client

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

  private

  def assign_default_role
    return if invited_by_id.present? # invited users get their role from the inviter

    add_role(:organiser)
  end
end
