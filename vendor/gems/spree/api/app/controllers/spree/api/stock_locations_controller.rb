module Spree
  module Api
    class StockLocationsController < Spree::Api::BaseController
      def index
        @stock_locations = StockLocation.order('name ASC').ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
        respond_with(@stock_locations)
      end

      def show
        respond_with(stock_location)
      end

      def create
        authorize! :create, StockLocation
        @stock_location = StockLocation.new(params[:stock_location])
        if @stock_location.save
          respond_with(@stock_location, status: 201, default_template: :show)
        else
          invalid_resource!(@stock_location)
        end
      end

      def update
        authorize! :update, StockLocation
        if stock_location.update_attributes(params[:stock_location])
          respond_with(stock_location, status: 200, default_template: :show)
        else
          invalid_resource!(stock_location)
        end
      end

      def destroy
        authorize! :delete, StockLocation
        stock_location.destroy
        respond_with(stock_location, :status => 204)
      end

      private

      def stock_location
        @stock_location ||= StockLocation.find(params[:id])
      end
    end
  end
end
