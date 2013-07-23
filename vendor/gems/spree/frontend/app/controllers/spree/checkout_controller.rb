module Spree
  # This is somewhat contrary to standard REST convention since there is not
  # actually a Checkout object. There's enough distinct logic specific to
  # checkout which has nothing to do with updating an order that this approach
  # is waranted.
  class CheckoutController < Spree::StoreController
    ssl_required

    before_filter :load_order

    before_filter :ensure_order_not_completed
    before_filter :ensure_checkout_allowed
    before_filter :ensure_sufficient_stock_lines
    before_filter :ensure_valid_state

    before_filter :associate_user
    before_filter :check_authorization
    before_filter :apply_coupon_code

    helper 'spree/orders'

    rescue_from Spree::Core::GatewayError, :with => :rescue_from_spree_gateway_error

    # Updates the order and advances to the next state (when possible.)
    def update
      if @order.update_attributes(object_params)
        fire_event('spree.checkout.update')

        unless @order.next
          flash[:error] = @order.errors[:base].join("\n")
          redirect_to checkout_state_path(@order.state) and return
        end

        if @order.completed?
          session[:order_id] = nil
          flash.notice = Spree.t(:order_processed_successfully)
          flash[:commerce_tracking] = "nothing special"
          redirect_to completion_route
        else
          redirect_to checkout_state_path(@order.state)
        end
      else
        render :edit
      end
    end

    private
      def ensure_valid_state
        unless skip_state_validation?
          if (params[:state] && !@order.has_checkout_step?(params[:state])) ||
             (!params[:state] && !@order.has_checkout_step?(@order.state))
            @order.state = 'cart'
            redirect_to checkout_state_path(@order.checkout_steps.first)
          end
        end
      end

      # Should be overriden if you have areas of your checkout that don't match
      # up to a step within checkout_steps, such as a registration step
      def skip_state_validation?
        false
      end

      def load_order
        @order = current_order
        redirect_to spree.cart_path and return unless @order

        if params[:state]
          redirect_to checkout_state_path(@order.state) if @order.can_go_to_state?(params[:state]) && !skip_state_validation?
          @order.state = params[:state]
        end
        setup_for_current_state
      end

      def ensure_checkout_allowed
        unless @order.checkout_allowed?
          redirect_to spree.cart_path
        end
      end

      def ensure_order_not_completed
        redirect_to spree.cart_path if @order.completed?
      end

      def ensure_sufficient_stock_lines
        if @order.insufficient_stock_lines.present?
          flash[:error] = Spree.t(:inventory_error_flash_for_insufficient_quantity)
          redirect_to spree.cart_path
        end
      end

      # Provides a route to redirect after order completion
      def completion_route
        spree.order_path(@order)
      end

      # For payment step, filter order parameters to produce the expected nested
      # attributes for a single payment and its source, discarding attributes
      # for payment methods other than the one selected
      def object_params
        # respond_to check is necessary due to issue described in #2910
        if @order.has_checkout_step?("payment") && @order.payment?
          if params[:payment_source].present?
            source_params = params.delete(:payment_source)[params[:order][:payments_attributes].first[:payment_method_id].underscore]

            if source_params
              params[:order][:payments_attributes].first[:source_attributes] = source_params
            end
          end

          if (params[:order][:payments_attributes])
            params[:order][:payments_attributes].first[:amount] = @order.total
          end
        end
        params[:order]
      end

      def setup_for_current_state
        method_name = :"before_#{@order.state}"
        send(method_name) if respond_to?(method_name, true)
      end

      def before_address
        @order.bill_address ||= Address.default
        @order.ship_address ||= Address.default
      end

      def before_delivery
        return if params[:order].present?

        packages = @order.shipments.map { |s| s.to_package }
        @differentiator = Spree::Stock::Differentiator.new(@order, packages)
      end

      def before_payment
        packages = @order.shipments.map { |s| s.to_package }
        @differentiator = Spree::Stock::Differentiator.new(@order, packages)
        @differentiator.missing.each do |variant, quantity|
          @order.contents.remove(variant, quantity)
        end
      end

      def rescue_from_spree_gateway_error
        flash[:error] = Spree.t(:spree_gateway_error_flash_for_checkout)
        render :edit
      end

      def check_authorization
        authorize!(:edit, current_order, session[:access_token])
      end

      def apply_coupon_code
        if params[:order] && params[:order][:coupon_code]
          @order.coupon_code = params[:order][:coupon_code] 

          coupon_result = Spree::Promo::CouponApplicator.new(@order).apply
          if coupon_result[:coupon_applied?]
            flash[:success] = coupon_result[:success] if coupon_result[:success].present?
          else
            flash[:error] = coupon_result[:error]
            respond_with(@order) { |format| format.html { render :edit } } and return
          end
        end
      end
  end
end
