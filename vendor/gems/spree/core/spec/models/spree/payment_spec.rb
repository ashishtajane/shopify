require 'spec_helper'

describe Spree::Payment do
  let(:order) do
    order = Spree::Order.new(:bill_address => Spree::Address.new,
                             :ship_address => Spree::Address.new)
  end

  let(:gateway) do
    gateway = Spree::Gateway::Bogus.new({:environment => 'test', :active => true}, :without_protection => true)
    gateway.stub :source_required => true
    gateway
  end

  let(:card) do
    mock_model(Spree::CreditCard, :number => "4111111111111111",
                                  :has_payment_profile? => true)
  end

  let(:payment) do
    payment = Spree::Payment.new
    payment.source = card
    payment.order = order
    payment.payment_method = gateway
    payment
  end

  let(:amount_in_cents) { payment.amount.to_f * 100 }

  let!(:success_response) do
    double('success_response', :success? => true,
                             :authorization => '123',
                             :avs_result => { 'code' => 'avs-code' },
                             :cvv_result => { 'code' => 'cvv-code', 'message' => "CVV Result"})
  end

  let(:failed_response) { double('gateway_response', :success? => false) }

  before(:each) do
    # So it doesn't create log entries every time a processing method is called
    payment.log_entries.stub(:create)
  end

  context 'validations' do
    it "returns useful error messages when source is invalid" do
      payment.source = Spree::CreditCard.new
      payment.should_not be_valid
      cc_errors = payment.errors['Credit Card']
      cc_errors.should include("Number can't be blank")
      cc_errors.should include("Month is not a number")
      cc_errors.should include("Year is not a number")
      cc_errors.should include("Verification Value can't be blank")
    end
  end

  # Regression test for https://github.com/spree/spree/pull/2224
  context 'failure' do

    it 'should transition to failed from pending state' do
      payment.state = 'pending'
      payment.failure
      payment.state.should eql('failed')
    end

    it 'should transition to failed from processing state' do
      payment.state = 'processing'
      payment.failure
      payment.state.should eql('failed')
    end

  end

  context 'invalidate' do
    it 'should transition from checkout to invalid' do
      payment.state = 'checkout'
      payment.invalidate
      payment.state.should eq('invalid')
    end
  end

  context "processing" do
    before do
      payment.stub(:update_order)
      payment.stub(:create_payment_profile)
    end

    context "#process!" do
      it "should purchase if with auto_capture" do
        payment.payment_method.should_receive(:auto_capture?).and_return(true)
        payment.should_receive(:purchase!)
        payment.process!
      end

      it "should authorize without auto_capture" do
        payment.payment_method.should_receive(:auto_capture?).and_return(false)
        payment.should_receive(:authorize!)
        payment.process!
      end

      it "should make the state 'processing'" do
        payment.should_receive(:started_processing!)
        payment.process!
      end

      it "should invalidate if payment method doesnt support source" do
        payment.payment_method.should_receive(:supports?).with(payment.source).and_return(false)
        expect { payment.process!}.to raise_error(Spree::Core::GatewayError)
        payment.state.should eq('invalid')
      end

    end

    context "#authorize" do
      it "should call authorize on the gateway with the payment amount" do
        payment.payment_method.should_receive(:authorize).with(amount_in_cents,
                                                               card,
                                                               anything).and_return(success_response)
        payment.authorize!
      end

      it "should call authorize on the gateway with the currency code" do
        payment.stub :currency => 'GBP'
        payment.payment_method.should_receive(:authorize).with(amount_in_cents,
                                                               card,
                                                               hash_including({:currency => "GBP"})).and_return(success_response)
        payment.authorize!
      end

      it "should log the response" do
        payment.log_entries.should_receive(:create).with({:details => anything}, {:without_protection => true})
        payment.authorize!
      end

      context "when gateway does not match the environment" do
        it "should raise an exception" do
          gateway.stub :environment => "foo"
          expect { payment.authorize! }.to raise_error(Spree::Core::GatewayError)
        end
      end

      context "if successful" do
        before do
          payment.payment_method.should_receive(:authorize).with(amount_in_cents,
                                                                 card,
                                                                 anything).and_return(success_response)
        end

        it "should store the response_code, avs_response and cvv_response fields" do
          payment.authorize!
          payment.response_code.should == '123'
          payment.avs_response.should == 'avs-code'
          payment.cvv_response_code.should == 'cvv-code'
          payment.cvv_response_message.should == 'CVV Result'
        end

        it "should make payment pending" do
          payment.should_receive(:pend!)
          payment.authorize!
        end
      end

      context "if unsuccessful" do
        it "should mark payment as failed" do
          gateway.stub(:authorize).and_return(failed_response)
          payment.should_receive(:failure)
          payment.should_not_receive(:pend)
          lambda {
            payment.authorize!
          }.should raise_error(Spree::Core::GatewayError)
        end
      end
    end

    context "purchase" do
      it "should call purchase on the gateway with the payment amount" do
        gateway.should_receive(:purchase).with(amount_in_cents, card, anything).and_return(success_response)
        payment.purchase!
      end

      it "should log the response" do
        payment.log_entries.should_receive(:create).with({:details => anything}, {:without_protection => true})
        payment.purchase!
      end

      context "when gateway does not match the environment" do
        it "should raise an exception" do
          gateway.stub :environment => "foo"
          expect { payment.purchase!  }.to raise_error(Spree::Core::GatewayError)
        end
      end

      context "if successful" do
        before do
          payment.payment_method.should_receive(:purchase).with(amount_in_cents,
                                                                card,
                                                                anything).and_return(success_response)
        end

        it "should store the response_code and avs_response" do
          payment.purchase!
          payment.response_code.should == '123'
          payment.avs_response.should == 'avs-code'
        end

        it "should make payment complete" do
          payment.should_receive(:complete!)
          payment.purchase!
        end
      end

      context "if unsuccessful" do
        it "should make payment failed" do
          gateway.stub(:purchase).and_return(failed_response)
          payment.should_receive(:failure)
          payment.should_not_receive(:pend)
          expect { payment.purchase! }.to raise_error(Spree::Core::GatewayError)
        end
      end
    end

    context "#capture" do
      before do
        payment.stub(:complete).and_return(true)
      end

      context "when payment is pending" do
        before do
          payment.state = 'pending'
        end

        context "if successful" do
          before do
            payment.payment_method.should_receive(:capture).with(payment, card, anything).and_return(success_response)
          end

          it "should make payment complete" do
            payment.should_receive(:complete)
            payment.capture!
          end

          it "should store the response_code" do
            gateway.stub :capture => success_response
            payment.capture!
            payment.response_code.should == '123'
          end
        end

        context "if unsuccessful" do
          it "should not make payment complete" do
            gateway.stub :capture => failed_response
            payment.should_receive(:failure)
            payment.should_not_receive(:complete)
            expect { payment.capture! }.to raise_error(Spree::Core::GatewayError)
          end
        end
      end

      # Regression test for #2119
      context "when payment is completed" do
        before do
          payment.state = 'completed'
        end

        it "should do nothing" do
          payment.should_not_receive(:complete)
          payment.payment_method.should_not_receive(:capture)
          payment.log_entries.should_not_receive(:create)
          payment.capture!
        end
      end
    end

    context "#void" do
      before do
        payment.response_code = '123'
        payment.state = 'pending'
      end

      context "when profiles are supported" do
        it "should call payment_gateway.void with the payment's response_code" do
          gateway.stub :payment_profiles_supported? => true
          gateway.should_receive(:void).with('123', card, anything).and_return(success_response)
          payment.void_transaction!
        end
      end

      context "when profiles are not supported" do
        it "should call payment_gateway.void with the payment's response_code" do
          gateway.stub :payment_profiles_supported? => false
          gateway.should_receive(:void).with('123', anything).and_return(success_response)
          payment.void_transaction!
        end
      end

      it "should log the response" do
        payment.log_entries.should_receive(:create).with({:details => anything}, {:without_protection => true})
        payment.void_transaction!
      end

      context "when gateway does not match the environment" do
        it "should raise an exception" do
          gateway.stub :environment => "foo"
          expect { payment.void_transaction! }.to raise_error(Spree::Core::GatewayError)
        end
      end

      context "if successful" do
        it "should update the response_code with the authorization from the gateway" do
          # Change it to something different
          payment.response_code = 'abc'
          payment.void_transaction!
          payment.response_code.should == '12345'
        end
      end

      context "if unsuccessful" do
        it "should not void the payment" do
          gateway.stub :void => failed_response
          payment.should_not_receive(:void)
          expect { payment.void_transaction! }.to raise_error(Spree::Core::GatewayError)
        end
      end

      # Regression test for #2119
      context "if payment is already voided" do
        before do
          payment.state = 'void'
        end

        it "should not void the payment" do
          payment.payment_method.should_not_receive(:void)
          payment.void_transaction!
        end
      end
    end

    context "#credit" do
      before do
        payment.state = 'complete'
        payment.response_code = '123'
      end

      context "when outstanding_balance is less than payment amount" do
        before do
          payment.order.stub :outstanding_balance => 10
          payment.stub :credit_allowed => 1000
        end

        it "should call credit on the gateway with the credit amount and response_code" do
          gateway.should_receive(:credit).with(1000, card, '123', anything).and_return(success_response)
          payment.credit!
        end
      end

      context "when outstanding_balance is equal to payment amount" do
        before do
          payment.order.stub :outstanding_balance => payment.amount
        end

        it "should call credit on the gateway with the credit amount and response_code" do
          gateway.should_receive(:credit).with(amount_in_cents, card, '123', anything).and_return(success_response)
          payment.credit!
        end
      end

      context "when outstanding_balance is greater than payment amount" do
        before do
          payment.order.stub :outstanding_balance => 101
        end

        it "should call credit on the gateway with the original payment amount and response_code" do
          gateway.should_receive(:credit).with(amount_in_cents.to_f, card, '123', anything).and_return(success_response)
          payment.credit!
        end
      end

      it "should log the response" do
        payment.log_entries.should_receive(:create).with({:details => anything}, {:without_protection => true})
        payment.credit!
      end

      context "when gateway does not match the environment" do
        it "should raise an exception" do
          gateway.stub :environment => "foo"
          lambda { payment.credit! }.should raise_error(Spree::Core::GatewayError)
        end
      end

      context "when response is successful" do
        it "should create an offsetting payment" do
          Spree::Payment.should_receive(:create)
          payment.credit!
        end

        it "resulting payment should have correct values" do
          payment.order.stub :outstanding_balance => 100
          payment.stub :credit_allowed => 10

          offsetting_payment = payment.credit!
          offsetting_payment.amount.to_f.should == -10
          offsetting_payment.should be_completed
          offsetting_payment.response_code.should == '12345'
          offsetting_payment.source.should == payment
        end
      end
    end
  end

  context "when response is unsuccessful" do
    it "should not create a payment" do
      gateway.stub :credit => failed_response
      Spree::Payment.should_not_receive(:create)
      expect { payment.credit! }.to raise_error(Spree::Core::GatewayError)
    end
  end

  context "when already processing" do
    it "should return nil without trying to process the source" do
      payment.state = 'processing'

      payment.should_not_receive(:authorize!)
      payment.should_not_receive(:purchase!)
      payment.process!.should be_nil
    end
  end

  context "with source required" do
    context "raises an error if no source is specified" do
      before do
        payment.source = nil
      end

      specify do
        expect { payment.process! }.to raise_error(Spree::Core::GatewayError, Spree.t(:payment_processing_failed))
      end
    end
  end

  context "with source optional" do
    context "raises no error if source is not specified" do
      before do
        payment.source = nil
        payment.payment_method.stub(:source_required? => false)
      end

      specify do
        expect { payment.process! }.not_to raise_error
      end
    end
  end

  context "#credit_allowed" do
    it "is the difference between offsets total and payment amount" do
      payment.amount = 100
      payment.stub(:offsets_total).and_return(0)
      payment.credit_allowed.should == 100
      payment.stub(:offsets_total).and_return(80)
      payment.credit_allowed.should == 20
    end
  end

  context "#can_credit?" do
    it "is true if credit_allowed > 0" do
      payment.stub(:credit_allowed).and_return(100)
      payment.can_credit?.should be_true
    end
    it "is false if credit_allowed is 0" do
      payment.stub(:credit_allowed).and_return(0)
      payment.can_credit?.should be_false
    end
  end

  context "#credit" do
    context "when amount <= credit_allowed" do
      it "makes the state processing" do
        payment.state = 'completed'
        payment.stub(:credit_allowed).and_return(10)
        payment.partial_credit(10)
        payment.should be_processing
      end
      it "calls credit on the source with the payment and amount" do
        payment.state = 'completed'
        payment.stub(:credit_allowed).and_return(10)
        payment.should_receive(:credit!).with(10)
        payment.partial_credit(10)
      end
    end
    context "when amount > credit_allowed" do
      it "should not call credit on the source" do
        payment.state = 'completed'
        payment.stub(:credit_allowed).and_return(10)
        payment.partial_credit(20)
        payment.should be_completed
      end
    end
  end

  context "#save" do
    it "should call order#update!" do
      payment = Spree::Payment.create({:amount => 100, :order => order}, :without_protection => true)
      order.should_receive(:update!)
      payment.save
    end

    context "when profiles are supported" do
      before do
        gateway.stub :payment_profiles_supported? => true
        payment.source.stub :has_payment_profile? => false
      end


      context "when there is an error connecting to the gateway" do
        it "should call gateway_error " do
          gateway.should_receive(:create_profile).and_raise(ActiveMerchant::ConnectionError)
          lambda { Spree::Payment.create({:amount => 100, :order => order, :source => card, :payment_method => gateway}, :without_protection => true) }.should raise_error(Spree::Core::GatewayError)
        end
      end

      context "when successfully connecting to the gateway" do
        it "should create a payment profile" do
          payment.payment_method.should_receive :create_profile
          payment = Spree::Payment.create({:amount => 100, :order => order, :source => card, :payment_method => gateway}, :without_protection => true)
        end
      end


    end

    context "when profiles are not supported" do
      before { gateway.stub :payment_profiles_supported? => false }

      it "should not create a payment profile" do
        gateway.should_not_receive :create_profile
        payment = Spree::Payment.create({:amount => 100, :order => order, :source => card, :payment_method => gateway}, :without_protection => true)
      end
    end
  end

  context "#build_source" do
    it "should build the payment's source" do
      params = { :amount => 100, :payment_method => gateway,
        :source_attributes => {
          :year => 1.month.from_now.year,
          :month =>1.month.from_now.month,
          :number => '1234567890123',
          :verification_value => '123'
        }
      }

      payment = Spree::Payment.new(params, :without_protection => true)
      payment.should be_valid
      payment.source.should_not be_nil
    end

    it "errors when payment source not valid" do
      params = { :amount => 100, :payment_method => gateway,
        :source_attributes => {:year=>"2012", :month =>"1" }}

      payment = Spree::Payment.new(params, :without_protection => true)
      payment.should_not be_valid
      payment.source.should_not be_nil
      payment.source.should have(1).error_on(:number)
      payment.source.should have(1).error_on(:verification_value)
    end
  end

  context "#currency" do
    before { order.stub(:currency) { "ABC" } }
    it "returns the order currency" do
      payment.currency.should == "ABC"
    end
  end

  context "#display_amount" do
    it "returns a Spree::Money for this amount" do
      payment.display_amount.should == Spree::Money.new(payment.amount)
    end
  end

  # Regression test for #2216
  context "#gateway_options" do
    before { order.stub(:last_ip_address => "192.168.1.1") }

    it "contains an IP" do
      payment.gateway_options[:ip].should == order.last_ip_address
    end
  end

  # Regression test for #1998
  context "#set_unique_identifier" do
    it "sets a unique identifier on create" do
      payment.run_callbacks(:save)
      payment.identifier.should_not be_blank
    end
  end
end
