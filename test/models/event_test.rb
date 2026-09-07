require 'test_helper'

class EventTest < ActiveSupport::TestCase
  setup do
    @event = events(:one)
  end

  test 'sales are open before the event ends' do
    @event.start_at = 1.day.ago
    @event.end_at = 1.day.from_now

    assert_not @event.sales_closed?
    assert @event.selling?
  end

  test 'sales are closed once the current time is past end_at' do
    @event.start_at = 2.days.ago
    @event.end_at = 1.hour.ago

    assert @event.sales_closed?
    assert_not @event.selling?
  end

  test 'sales fall back to start_at when there is no end_at' do
    @event.end_at = nil
    @event.start_at = 1.hour.ago

    assert @event.sales_closed?

    @event.start_at = 1.hour.from_now

    assert_not @event.sales_closed?
  end

  test 'ended events are only listed for the organiser who created them' do
    past = events(:one)
    past.update_columns(start_at: 2.days.ago, end_at: 1.day.ago)

    live = events(:two)
    live.update_columns(start_at: 1.day.from_now, end_at: 2.days.from_now)

    assert_equal [live], Event.listable_for(nil).to_a
    assert_equal [live], Event.listable_for(users(:two)).to_a
    assert_equal [live, past].sort_by(&:id), Event.listable_for(users(:one)).sort_by(&:id)
  end

  test 'admins see ended events from every organiser' do
    events(:one).update_columns(start_at: 2.days.ago, end_at: 1.day.ago)

    admin = users(:two)
    admin.add_role(:admin)

    assert_includes Event.listable_for(admin), events(:one)
  end

  test 'sales_closed? accepts an explicit time' do
    @event.start_at = Time.zone.parse('2026-08-19 22:48:17')
    @event.end_at = Time.zone.parse('2026-08-20 22:48:17')

    assert_not @event.sales_closed?(@event.end_at)
    assert @event.sales_closed?(@event.end_at + 1.second)
  end
end
