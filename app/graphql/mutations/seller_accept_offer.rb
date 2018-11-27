class Mutations::SellerAcceptOffer < Mutations::BaseMutation
  null true

  argument :offer_id, ID, required: true

  field :order_or_error, Mutations::OrderOrFailureUnionType, 'A union of success/failure', null: false

  def resolve(offer_id:)
    offer = Offer.find(offer_id)
    order = offer.order

    authorize_seller_request!(order)

    Offers::AcceptService.new(
      offer: offer,
      order: order,
      user_id: current_user_id
    ).process!

    { order_or_error: { order: order.reload } }
  rescue Errors::ApplicationError => e
    { order_or_error: { error: Types::ApplicationErrorType.from_application(e) } }
  end

  private

  def current_user_id
    context[:current_user]['id']
  end
end
