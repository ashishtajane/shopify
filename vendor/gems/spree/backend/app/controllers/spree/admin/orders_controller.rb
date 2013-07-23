module Spree
  module Admin
    class OrdersController < Spree::Admin::BaseController
      require 'spree/core/gateway_error'
      before_filter :initialize_order_events
      before_filter :load_order, :only => [:edit, :update, :fire, :resend, :open_adjustments, :close_adjustments]

      respond_to :html

      def index
        params[:q] ||= {}
        params[:q][:completed_at_not_null] ||= '1' if Spree::Config[:show_only_complete_orders_by_default]
        @show_only_completed = params[:q][:completed_at_not_null].present?
        params[:q][:s] ||= @show_only_completed ? 'completed_at desc' : 'created_at desc'

        # As date params are deleted if @show_only_completed, store
        # the original date so we can restore them into the params
        # after the search
        created_at_gt = params[:q][:created_at_gt]
        created_at_lt = params[:q][:created_at_lt]

        params[:q].delete(:inventory_units_shipment_id_null) if params[:q][:inventory_units_shipment_id_null] == "0"

        if !params[:q][:created_at_gt].blank?
          params[:q][:created_at_gt] = Time.zone.parse(params[:q][:created_at_gt]).beginning_of_day rescue ""
        end

        if !params[:q][:created_at_lt].blank?
          params[:q][:created_at_lt] = Time.zone.parse(params[:q][:created_at_lt]).end_of_day rescue ""
        end

        if @show_only_completed
          params[:q][:completed_at_gt] = params[:q].delete(:created_at_gt)
          params[:q][:completed_at_lt] = params[:q].delete(:created_at_lt)
        end

        @search = Order.accessible_by(current_ability, :index).ransack(params[:q])
        @orders = @search.result.includes([:user, :shipments, :payments]).
          page(params[:page]).
          per(params[:per_page] || Spree::Config[:orders_per_page])

        # Restore dates
        params[:q][:created_at_gt] = created_at_gt
        params[:q][:created_at_lt] = created_at_lt
      end

      def new
        @order = Order.create
        redirect_to edit_admin_order_url(@order)
      end

      def edit
        @order.shipments.map &:refresh_rates
        # Transition as far as we can go
        while @order.next; end
        # The payment step shows an error of 'No pending payments'
        # Clearing the errors from the order object will stop this error
        # appearing on the edit page where we don't want it to.
        @order.errors.clear
      end

      def update
        return_path = nil
        if @order.update_attributes(params[:order]) && @order.line_items.present?
          @order.update!
          unless @order.complete?
            # Jump to next step if order is not complete.
            return_path = admin_order_customer_path(@order)
          else
            # Otherwise, go back to first page since all necessary information has been filled out.
            return_path = admin_order_path(@order)
          end
        else
          @order.errors.add(:line_items, Spree.t('errors.messages.blank')) if @order.line_items.empty?
        end

        if return_path
          redirect_to return_path
        else
          render :action => :edit
        end
      end

      def fire
        # TODO - possible security check here but right now any admin can before any transition (and the state machine
        # itself will make sure transitions are not applied in the wrong state)
        event = params[:e]
        if @order.send("#{event}")
          flash[:success] = Spree.t(:order_updated)
        else
          flash[:error] = Spree.t(:cannot_perform_operation)
        end
      rescue Spree::Core::GatewayError => ge
        flash[:error] = "#{ge.message}"
      ensure
        redirect_to :back
      end

      def resend
        OrderMailer.confirm_email(@order.id, true).deliver
        flash[:success] = Spree.t(:order_email_resent)

        redirect_to :back
      end

      def open_adjustments
        adjustments = @order.adjustments.where(:state => 'closed')
        adjustments.update_all(:state => 'open')
        flash[:success] = Spree.t(:all_adjustments_opened)

        respond_with(@order) { |format| format.html { redirect_to :back } }
      end

      def close_adjustments
        adjustments = @order.adjustments.where(:state => 'open')
        adjustments.update_all(:state => 'closed')
        flash[:success] = Spree.t(:all_adjustments_closed)

        respond_with(@order) { |format| format.html { redirect_to :back } }
      end

      private

        def load_order
          @order = Order.find_by_number!(params[:id], :include => :adjustments) if params[:id]
          authorize! action, @order
        end

        # Used for extensions which need to provide their own custom event links on the order details view.
        def initialize_order_events
          @order_events = %w{cancel resume}
        end

        def model_class
          Spree::Order
        end
    end
  end
end
