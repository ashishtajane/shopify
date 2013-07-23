require 'spec_helper'

module Spree
  describe Api::StockMovementsController do
    render_views

    let!(:stock_location) { create(:stock_location_with_items) }
    let!(:stock_item) { stock_location.stock_items.order(:id).first }
    let!(:stock_movement) { create(:stock_movement, stock_item: stock_item) }
    let!(:attributes) { [:id, :quantity, :stock_item_id] }

    before do
      stub_authentication!
    end

    it 'gets list of stock movements' do
      api_get :index, stock_location_id: stock_location.to_param
      json_response['stock_movements'].first.should have_attributes(attributes)
      json_response['stock_movements'].first['stock_item']['count_on_hand'].should eq 11
    end

    it 'requires a stock_location_id to be passed as a parameter' do
      api_get :index
      json_response['error'].should =~ /stock_location_id parameter must be provided/
      response.status.should == 422
    end

    it 'can control the page size through a parameter' do
      create(:stock_movement, stock_item: stock_item)
      api_get :index, stock_location_id: stock_location.to_param, per_page: 1
      json_response['count'].should == 1
      json_response['current_page'].should == 1
      json_response['pages'].should == 2
    end

    it 'can query the results through a paramter' do
      expected_result = create(:stock_movement, :received, quantity: 10, stock_item: stock_item)
      api_get :index, stock_location_id: stock_location.to_param, q: { quantity_eq: '10' }
      json_response['count'].should == 1
    end

    it 'gets a stock movement' do
      api_get :show, stock_location_id: stock_location.to_param, id: stock_movement.to_param
      json_response.should have_attributes(attributes)
      json_response['stock_item_id'].should eq stock_movement.stock_item_id
    end

    context 'as an admin' do
      sign_in_as_admin!

      it 'can create a new stock movement' do
        params = {
          stock_location_id: stock_location.to_param,
          stock_movement: {
            stock_item_id: stock_item.to_param
          }
        }

        api_post :create, params
        response.status.should == 201
        json_response.should have_attributes(attributes)
      end
    end
  end
end

