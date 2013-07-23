module Spree
  module Admin
    module OrdersHelper
      # Renders all the extension partials that may have been specified in the extensions
      def event_links
        links = []
        @order_events.sort.each do |event|
          if @order.send("can_#{event}?")
            links << button_link_to(Spree.t(event), fire_admin_order_url(@order, :e => event),
                                    :method => :put,
                                    :icon => "icon-#{event}",
                                    :data => { :confirm => Spree.t(:order_sure_want_to, :event => Spree.t(event)) })
          end
        end
        links.join('&nbsp;').html_safe
      end

      def line_item_shipment_price(line_item, quantity)
        Spree::Money.new(line_item.price * quantity, { currency: line_item.currency })
      end
    end
  end
end
