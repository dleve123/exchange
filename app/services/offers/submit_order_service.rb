module Offers
  class SubmitOrderService
    attr_reader :order, :offer
    def initialize(offer, by: nil)
      @offer = offer
      @order = @offer.order
      @by = by
    end

    def process!
      pre_process!
      @order.submit! do
        @offer.update!(submitted_at: Time.now.utc)
        @order.line_items.first.update!(sales_tax_cents: @offer.tax_total_cents, should_remit_sales_tax: @offer.should_remit_sales_tax)
        @order.update!(last_offer: @offer, shipping_total_cents: @offer.shipping_total_cents, tax_total_cents: @offer.tax_total_cents)
        OrderTotalUpdaterService.new(@order, @partner[:effective_commission_rate]).update_totals!
      end
      post_process
    end

    private

    def pre_process!
      assert_can_submit!

      @order.line_items.map do |li|
        artwork = GravityService.get_artwork(li[:artwork_id])
        if artwork[:current_version_id] != li[:artwork_version_id]
          Exchange.dogstatsd.increment 'submit.artwork_version_mismatch'
          raise Errors::ProcessingError, :artwork_version_mismatch
        end
      end
      @credit_card = GravityService.get_credit_card(@order.credit_card_id)
      assert_credit_card!
      @partner = GravityService.fetch_partner(@order.seller_id)
      assert_partner!
    end

    def post_process
      Exchange.dogstatsd.increment 'order.submit'
      PostOrderNotificationJob.perform_later(@order.id, Order::SUBMITTED, @by)
      OrderFollowUpJob.set(wait_until: @order.state_expires_at).perform_later(@order.id, @order.state)
      ReminderFollowUpJob.set(wait_until: @order.state_expires_at - 2.hours).perform_later(@order.id, @order.state)
    end

    def assert_can_submit!
      raise Errors::ValidationError, :cant_submit unless @order.mode == Order::OFFER
      raise Errors::ValidationError, :missing_required_info unless @order.can_submit?
      raise Errors::ValidationError, :invalid_offer if @offer.submitted?
    end

    def assert_credit_card!
      raise Errors::ValidationError.new(:credit_card_missing_external_id, credit_card_id: @credit_card[:id]) if @credit_card[:external_id].blank?
      raise Errors::ValidationError.new(:credit_card_missing_customer, credit_card_id: @credit_card[:id]) if @credit_card.dig(:customer_account, :external_id).blank?
      raise Errors::ValidationError.new(:credit_card_deactivated, credit_card_id: @credit_card[:id]) unless @credit_card[:deactivated_at].nil?
    end

    def assert_partner!
      raise Errors::ValidationError.new(:missing_commission_rate, partner_id: @partner[:id]) if @partner[:effective_commission_rate].blank?
    end
  end
end
