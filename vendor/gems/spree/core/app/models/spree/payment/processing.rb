module Spree
  class Payment < ActiveRecord::Base
    module Processing
      def process!
        if payment_method && payment_method.source_required?
          if source
            if !processing?
              if payment_method.supports?(source)
                if payment_method.auto_capture?
                  purchase!
                else
                  authorize!
                end
              else
                invalidate!
                raise Core::GatewayError.new(I18n.t(:payment_method_not_supported))
              end
            end
          else
            raise Core::GatewayError.new(Spree.t(:payment_processing_failed))
          end
        end
      end

      def authorize!
        started_processing!
        gateway_action(source, :authorize, :pend)
      end

      def purchase!
        started_processing!
        gateway_action(source, :purchase, :complete)
      end

      def capture!
        return true if completed?
        started_processing!
        protect_from_connection_error do
          check_environment

          if payment_method.payment_profiles_supported?
            # Gateways supporting payment profiles will need access to credit card object because this stores the payment profile information
            # so supply the authorization itself as well as the credit card, rather than just the authorization code
            response = payment_method.capture(self, source, gateway_options)
          else
            # Standard ActiveMerchant capture usage
            response = payment_method.capture(money.money.cents,
                                              response_code,
                                              gateway_options)
          end

          handle_response(response, :complete, :failure)
        end
      end

      def void_transaction!
        return true if void?
        protect_from_connection_error do
          check_environment

          if payment_method.payment_profiles_supported?
            # Gateways supporting payment profiles will need access to credit card object because this stores the payment profile information
            # so supply the authorization itself as well as the credit card, rather than just the authorization code
            response = payment_method.void(self.response_code, source, gateway_options)
          else
            # Standard ActiveMerchant void usage
            response = payment_method.void(self.response_code, gateway_options)
          end
          record_response(response)

          if response.success?
            self.response_code = response.authorization
            self.void
          else
            gateway_error(response)
          end
        end
      end
    end

    def credit!(credit_amount=nil)
      protect_from_connection_error do
        check_environment

        credit_amount ||= credit_allowed >= order.outstanding_balance.abs ? order.outstanding_balance.abs : credit_allowed.abs
        credit_amount = credit_amount.to_f

        if payment_method.payment_profiles_supported?
          response = payment_method.credit((credit_amount * 100).round, source, response_code, gateway_options)
        else
          response = payment_method.credit((credit_amount * 100).round, response_code, gateway_options)
        end

        record_response(response)

        if response.success?
          self.class.create({ :order => order,
                              :source => self,
                              :payment_method => payment_method,
                              :amount => credit_amount.abs * -1,
                              :response_code => response.authorization,
                              :state => 'completed' }, :without_protection => true)
        else
          gateway_error(response)
        end
      end
    end

    def partial_credit(amount)
      return if amount > credit_allowed
      started_processing!
      credit!(amount)
    end

    def gateway_options
      options = { :email    => order.email,
                  :customer => order.email,
                  :ip       => order.last_ip_address,
                  # Need to pass in a unique identifier here to make some
                  # payment gateways happy.
                  #
                  # For more information, please see Spree::Payment#set_unique_identifier
                  :order_id => gateway_order_id }

      options.merge!({ :shipping => order.ship_total * 100,
                       :tax      => order.tax_total * 100,
                       :subtotal => order.item_total * 100,
                       :discount => order.promo_total * 100,
                       :currency => currency })

      options.merge!({ :billing_address  => order.bill_address.try(:active_merchant_hash),
                      :shipping_address => order.ship_address.try(:active_merchant_hash) })

      options
    end

    private

    def gateway_action(source, action, success_state)
      protect_from_connection_error do
        check_environment

        response = payment_method.send(action, (amount * 100).round,
                                       source,
                                       gateway_options)
        handle_response(response, success_state, :failure)
      end
    end

    def handle_response(response, success_state, failure_state)
      record_response(response)

      if response.success?
        unless response.authorization.nil?
          self.response_code = response.authorization
          self.avs_response = response.avs_result['code']

          if response.cvv_result
            self.cvv_response_code = response.cvv_result['code']
            self.cvv_response_message = response.cvv_result['message']
          end
        end
        self.send("#{success_state}!")
      else
        self.send(failure_state)
        gateway_error(response)
      end
    end

    def record_response(response)
      log_entries.create({:details => response.to_yaml}, :without_protection => true)
    end

    def protect_from_connection_error
      begin
        yield
      rescue ActiveMerchant::ConnectionError => e
        gateway_error(e)
      end
    end

    def gateway_error(error)
      if error.is_a? ActiveMerchant::Billing::Response
        text = error.params['message'] || error.params['response_reason_text'] || error.message
      elsif error.is_a? ActiveMerchant::ConnectionError
        text = Spree.t(:unable_to_connect_to_gateway)
      else
        text = error.to_s
      end
      logger.error(Spree.t(:gateway_error))
      logger.error("  #{error.to_yaml}")
      raise Core::GatewayError.new(text)
    end

    # Saftey check to make sure we're not accidentally performing operations on a live gateway.
    # Ex. When testing in staging environment with a copy of production data.
    def check_environment
      return if payment_method.environment == Rails.env
      message = Spree.t(:gateway_config_unavailable) + " - #{Rails.env}"
      raise Core::GatewayError.new(message)
    end

    # The unique identifier to be passed in to the payment gateway
    def gateway_order_id
      "#{order.number}-#{self.identifier}"
    end
  end
end
