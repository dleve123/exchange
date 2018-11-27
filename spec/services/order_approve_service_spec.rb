require 'rails_helper'

describe OrderApproveService, type: :services do
  include_context 'use stripe mock'
  let(:order) { Fabricate(:order, external_charge_id: captured_charge.id, state: Order::SUBMITTED) }
  let!(:line_items) { [Fabricate(:line_item, order: order, artwork_id: 'a-1', list_price_cents: 123_00), Fabricate(:line_item, order: order, artwork_id: 'a-2', edition_set_id: 'es-1', quantity: 2, list_price_cents: 124_00)] }
  let(:user_id) { 'user-id' }
  let(:service) { OrderApproveService.new(order, user_id) }

  describe '#process!' do
    context 'with failed stripe capture' do
      before do
        StripeMock.prepare_card_error(:card_declined, :capture_charge)
      end
      it 'adds failed transaction' do
        expect { service.process! }.to raise_error(Errors::ProcessingError).and change(order.transactions, :count).by(1)
        expect(order.transactions.first.status).to eq Transaction::FAILURE
        expect(order.transactions.first.failure_code).to eq 'card_declined'
        expect(order.transactions.first.failure_message).to eq 'The card was declined'
      end
      it 'keeps order in submitted state' do
        expect { service.process! }.to raise_error(Errors::ProcessingError)
        expect(order.reload.state).to eq Order::SUBMITTED
      end
      it 'does not queue any followup job' do
        expect(PostOrderNotificationJob).not_to receive(:perform_later)
        expect(OrderFollowUpJob).not_to receive(:set)
        expect(RecordSalesTaxJob).not_to receive(:perform_later)
      end
    end
    context 'with failed transaction appending' do
      xit 'goes to failed approve state' do
      end
    end
    context 'with failed approve!' do
      xit 'goes to pending approve state' do
      end
    end
    context 'with failed post_process' do
      it 'is in approved state' do
        allow(PostOrderNotificationJob).to receive(:perform_later).and_raise('Perform what later?!')
        expect { service.process! }.to raise_error(RuntimeError).and change(order.transactions, :count).by(1)
        expect(order.reload.state).to eq Order::APPROVED
      end
    end
    context 'with a successful order approval' do
      before do
        ActiveJob::Base.queue_adapter = :test
        expect { service.process! }.to change(order.transactions, :count).by(1)
      end
      it 'adds successful transaction' do
        expect(order.transactions.last.status).to eq Transaction::SUCCESS
      end
      it 'queues PostOrderNotificationJob' do
        expect(PostOrderNotificationJob).to have_been_enqueued.with(order.id, Order::APPROVED, user_id)
      end
      it 'queues OrderFollowUpJob' do
        expect(OrderFollowUpJob).to have_been_enqueued.with(order.id, Order::APPROVED)
      end
      it 'enqueues a RecordSalesTaxJob for each line item' do
        line_items.each { |li| expect(RecordSalesTaxJob).to have_been_enqueued.with(li.id) }
      end
    end
  end
end
