module Offers
  class AcceptService
    def initialize(offer:, order:, user_id:)
      @offer = offer
      @order = order
      @user_id = user_id
    end

    def process!
      validate_is_last_offer!

      order.approve!

      publish_order_approved
      instrument_order_approved
    end

    private

    attr_reader :order, :offer, :user_id

    def validate_is_last_offer!
      raise Errors::ValidationError.new(:not_last_offer, offer) unless offer.last_offer?
    end

    def publish_order_approved
      PostOrderNotificationJob.perform_later(order.id, Order::APPROVED, user_id)
    end

    def instrument_order_approved
      Exchange.dogstatsd.increment 'order.approve'
    end
  end
end
