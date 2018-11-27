require 'rails_helper'

describe Offers::AcceptService, type: :services do
  describe '#process!' do
    subject(:call_service) do
      described_class.new(
        offer: offer,
        order: order,
        user_id: current_user_id
      ).process!
    end
    let!(:order) { Fabricate(:order, state: Order::SUBMITTED) }
    let!(:offer) { Fabricate(:offer, order: order) }
    let(:current_user_id) { 'user-id-123' }

    before do
      # last_offer is set in Orders::InitialOffer. "Stubbing" out the
      # dependent behavior of this class to by setting last_offer directly
      order.update!(last_offer: offer)
    end

    context 'with a approve-able order' do
      it 'updates the state of the order' do
        expect do
          call_service
        end.to change { order.state }.from(Order::SUBMITTED).to(Order::APPROVED)
      end

      it 'instruments an approved order' do
        dd_statsd = stub_ddstatsd_instance
        allow(dd_statsd).to receive(:increment).with('order.approve')

        call_service

        expect(dd_statsd).to have_received(:increment).with('order.approve')
      end

      it 'queues a PostOrderNotificationJob with the current user id with the approved action' do
        allow(PostOrderNotificationJob).to receive(:perform_later)

        call_service

        expect(PostOrderNotificationJob).to have_received(:perform_later)
          .with(order.id, Order::APPROVED, current_user_id)
      end
    end

    context "when we can't approve the order" do
      let(:order) { Fabricate(:order, state: Order::PENDING) }
      let(:offer) { Fabricate(:offer, order: order) }

      it "doesn't instrument" do
        dd_statsd = stub_ddstatsd_instance
        allow(dd_statsd).to receive(:increment).with('order.approve')

        expect { call_service }.to raise_error(Errors::ValidationError)

        expect(dd_statsd).to_not have_received(:increment)
      end

      it 'does not a queue a PostOrderNotificationJob' do
        allow(PostOrderNotificationJob).to receive(:perform_later)

        expect { call_service }.to raise_error(Errors::ValidationError)

        expect(PostOrderNotificationJob).to_not have_received(:perform_later)
          .with(order.id, Order::APPROVED, current_user_id)
      end
    end

    context 'attempting to accept not the last offer' do
      let!(:another_offer) { Fabricate(:offer, order: order) }

      before do
        # last_offer is set in Orders::InitialOffer. "Stubbing" out the
        # dependent behavior of this class to by setting last_offer directly
        order.update!(last_offer: another_offer)
      end

      it 'raises a validation error' do
        expect { call_service }
          .to raise_error(Errors::ValidationError)
      end

      it 'does not approve the order' do
        expect { call_service }.to raise_error(Errors::ValidationError)

        expect(order.reload.state).to eq(Order::SUBMITTED)
      end

      it 'does not instrument' do
        dd_statsd = stub_ddstatsd_instance
        allow(dd_statsd).to receive(:increment).with('order.approve')

        expect { call_service }.to raise_error(Errors::ValidationError)

        expect(dd_statsd).to_not have_received(:increment)
      end

      it 'does not a queue a PostOrderNotificationJob' do
        allow(PostOrderNotificationJob).to receive(:perform_later)

        expect { call_service }.to raise_error(Errors::ValidationError)

        expect(PostOrderNotificationJob).to_not have_received(:perform_later)
          .with(order.id, Order::APPROVED, current_user_id)
      end
    end
  end

  def stub_ddstatsd_instance
    dd_statsd = double(Datadog::Statsd)
    allow(Exchange).to receive(:dogstatsd).and_return(dd_statsd)

    dd_statsd
  end
end
