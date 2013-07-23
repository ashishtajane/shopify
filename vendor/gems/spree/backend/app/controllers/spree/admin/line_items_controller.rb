module Spree
  module Admin
    class LineItemsController < Spree::Admin::BaseController
      layout nil, :only => [:create, :destroy, :update]

      before_filter :load_order
      before_filter :load_line_item, :only => [:destroy, :update]

      respond_to :html, :js

      def create
        variant = Variant.find(params[:line_item][:variant_id])
        @line_item = @order.contents.add(variant, params[:line_item][:quantity].to_i)

        if @order.save
          render_order_form
        else
          respond_with(@line_item) do |format|
            format.js { render :action => 'create', :locals => { :order => @order.reload } }
          end
        end
      end

      def destroy
        @line_item.destroy
        render_order_form
      end

      def update
        @line_item.update_attributes(params[:line_item])
        render_order_form
      end

      private
        def render_order_form
          render :partial => 'spree/admin/orders/form', :locals => { :order => @order.reload }
        end

        def load_order
          @order = Order.find_by_number!(params[:order_id])
          authorize! action, @order
        end

        def load_line_item
          @line_item = @order.line_items.find(params[:id])
        end
    end
  end
end
