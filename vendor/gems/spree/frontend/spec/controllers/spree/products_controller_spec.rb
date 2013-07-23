require 'spec_helper'

describe Spree::ProductsController do
  let!(:product) { create(:product, :available_on => 1.year.from_now) }

  # Regression test for #1390
  it "allows admins to view non-active products" do
    controller.stub :spree_current_user => mock_model(Spree.user_class, :has_spree_role? => true, :last_incomplete_spree_order => nil, :spree_api_key => 'fake')
    spree_get :show, :id => product.to_param
    response.status.should == 200
  end

  it "cannot view non-active products" do
    spree_get :show, :id => product.to_param
    response.status.should == 404
  end

  it "should provide the current user to the searcher class" do
    user = mock_model(Spree.user_class, :last_incomplete_spree_order => nil, :spree_api_key => 'fake')
    controller.stub :spree_current_user => user
    Spree::Config.searcher_class.any_instance.should_receive(:current_user=).with(user)
    spree_get :index
    response.status.should == 200
  end

  # Regression test for #2249
  it "doesn't error when given an invalid referer" do
    current_user = mock_model(Spree.user_class, :has_spree_role? => true, :last_incomplete_spree_order => nil, :generate_spree_api_key! => nil)
    controller.stub :spree_current_user => current_user
    request.env['HTTP_REFERER'] = "not|a$url"
    # previously this would raise URI::InvalidURIError
    lambda { spree_get :show, :id => product.to_param }.should_not raise_error
  end

  # Regression tests for #2308 & Spree::Core::ControllerHelpers::SSL
  context "force_ssl enabled" do
    after do
      Rails.application.config.force_ssl = false
      reset_spree_preferences
      load "spree/base_controller.rb"
    end

    before do
      Rails.application.config.force_ssl = true
      reset_spree_preferences do |config|
        config.allow_ssl_in_development_and_test = true
      end
      load "spree/base_controller.rb"
    end

    context "receives a non SSL request" do
      it "should redirect to https" do
        controller.should_receive(:redirect_to).with(hash_including(:protocol => 'https://'))
        spree_get :index
        request.protocol.should eql('http://')
      end
    end

    context "receive a SSL request" do
      before do
        request.env['HTTPS'] = 'on'
      end

      it "should not redirect to http" do
        controller.should_not_receive(:redirect_to)
        spree_get :index
        request.protocol.should eql('https://')
      end
    end
  end

  context "redirect_https_to_http enabled" do
    before do
      reset_spree_preferences do |config|
        config.allow_ssl_in_development_and_test = true
        config.redirect_https_to_http = true
      end
    end

    context "receives a non SSL request" do
      it "should not redirect" do
        controller.should_not_receive(:redirect_to)
        spree_get :index
        request.protocol.should eql('http://')
      end
    end

    context "receives a SSL request" do
      before do
        request.env['HTTPS'] = 'on'
      end

      it "should redirect to http" do
        controller.should_receive(:redirect_to).with(hash_including(:protocol => 'http://'))
        spree_get :index
        request.protocol.should eql('https://')
      end
    end
  end
end
