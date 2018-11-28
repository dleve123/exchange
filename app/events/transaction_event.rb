class TransactionEvent < Events::BaseEvent
  TOPIC = 'commerce'.freeze
  ACTIONS = [
    CREATED = 'created'.freeze
  ].freeze

  def self.post(transaction, action, user_id)
    event = new(user: user_id, action: action, model: transaction)
    Artsy::EventService.post_event(topic: TOPIC, event: event)
  end

  def subject
    {
      id: @subject
    }
  end

  def properties
    order = @object.order
    {
      order: {
        id: order.id,
        mode: order.mode,
        buyer_id: order.buyer_id,
        buyer_total_cents: order.buyer_total_cents,
        buyer_type: order.buyer_type,
        code: order.code,
        created_at: order.created_at,
        currency_code: order.currency_code,
        fulfillment_type: order.fulfillment_type,
        items_total_cents: order.items_total_cents,
        line_items: order.line_items.map { |li| line_item_detail(li) },
        seller_id: order.seller_id,
        seller_type: order.seller_type,
        state: order.state,
        state_reason: order.state_reason,
        state_expires_at: order.state_expires_at,
        updated_at: order.updated_at
      },
      failure_code: @object.failure_code,
      failure_message: @object.failure_message,
      transaction_type: @object.transaction_type,
      status: @object.status
    }
  end

  def line_item_detail(line_item)
    {
      price_cents: line_item.list_price_cents,
      list_price_cents: line_item.list_price_cents,
      artwork_id: line_item.artwork_id,
      edition_set_id: line_item.edition_set_id,
      quantity: line_item.quantity,
      commission_fee_cents: line_item.commission_fee_cents
    }
  end
end
