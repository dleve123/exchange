require 'rails_helper'

RSpec.describe PostOrderNotificationJob, type: :job do
  let(:order) { Fabricate(:order) }
  it 'finds the order and posts the event' do
    action = Order::SUBMITTED
    expect(Artsy::EventService).to receive(:post_event).with(topic: 'commerce', event: instance_of(OrderEvent))
    PostOrderNotificationJob.new.perform(order.id, action, order.buyer_id)
  end
end
