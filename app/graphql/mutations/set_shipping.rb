class Mutations::SetShipping < Mutations::BaseMutation
  null true

  argument :id, ID, required: true
  argument :fulfillment_type, Types::OrderFulfillmentTypeEnum, required: true
  argument :shipping, Inputs::ShippingAttributes, required: false

  field :order_or_error, Mutations::OrderOrFailureUnionType, 'A union of success/failure', null: false

  def resolve(id:, fulfillment_type:, shipping: {})
    order = Order.find(id)
    validate_buyer_request!(order)
    OrderShippingService.new(order, fulfillment_type: fulfillment_type, shipping: shipping).process!
    {
      order_or_error: { order: order.reload }
    }
  rescue Errors::ApplicationError => e
    { order_or_error: { error: Types::ApplicationErrorType.from_application(e) } }
  end
end
