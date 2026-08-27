class User < ApplicationRecord
  rolify
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :invitable, :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  has_many :events, dependent: :restrict_with_error
  attr_accessor :role

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
end
