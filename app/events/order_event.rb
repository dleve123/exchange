class OrderEvent < Events::BaseEvent
  TOPIC = 'commerce'.freeze
  PROPERTIES_ATTRS = %i[
    mode
    buyer_id
    buyer_type
    buyer_phone_number
    buyer_total_cents
    code
    commission_fee_cents
    created_at
    currency_code
    fulfillment_type
    items_total_cents
    seller_id
    seller_total_cents
    seller_type
    shipping_address_line1
    shipping_address_line2
    shipping_city
    shipping_country
    shipping_name
    shipping_postal_code
    shipping_region
    shipping_total_cents state
    state_reason
    state_expires_at
    tax_total_cents
    transaction_fee_cents
    updated_at
    total_list_price_cents
  ].freeze

  def self.post(order, action, user_id)
    event = new(user: user_id, action: action, model: order)
    Artsy::EventService.post_event(topic: TOPIC, event: event)
  end

  def subject
    {
      id: @subject
    }
  end

  def properties
    PROPERTIES_ATTRS.map { |att| [att, @object.send(att)] }.to_h.merge(line_items: line_items_details)
  end

  private

  def line_items_details
    @object.line_items.map { |li| line_item_detail(li) }
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
