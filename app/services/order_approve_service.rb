class OrderApproveService
  attr_reader :order
  def initialize(order, by = nil)
    @order = order
    @by = by
    @transaction = nil
  end

  def process!
    @order.approve! do
      @transaction = PaymentService.capture_charge(@order.external_charge_id)
      raise Errors::ProcessingError.new(:capture_failed, @transaction.failure_data) if @transaction.failed?
    end
    post_process
  ensure
    @order.transactions << @transaction if @transaction.present?
  end

  private

  def post_process
    record_stats
    @order.line_items.each { |li| RecordSalesTaxJob.perform_later(li.id) }
    PostOrderNotificationJob.perform_later(@order.id, Order::APPROVED, @by)
    OrderFollowUpJob.set(wait_until: @order.state_expires_at).perform_later(@order.id, @order.state)
    ReminderFollowUpJob.set(wait_until: @order.state_expires_at - 2.hours).perform_later(@order.id, @order.state)
  end

  def record_stats
    Exchange.dogstatsd.increment 'order.approve'
    Exchange.dogstatsd.count('order.money_collected', @order.buyer_total_cents)
    Exchange.dogstatsd.count('order.commission_collected', @order.commission_fee_cents)
  end
end
