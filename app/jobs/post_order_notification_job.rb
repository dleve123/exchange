class PostOrderNotificationJob < ApplicationJob
  queue_as :default

  def perform(order_id, action, user_id = nil)
    order = Order.find(order_id)
    OrderEvent.post(order, action, user_id)
  end
end
