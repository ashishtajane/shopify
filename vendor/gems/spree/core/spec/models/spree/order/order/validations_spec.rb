require 'spec_helper'

module Spree
  describe Spree::Order do
    context "validations" do
      # Regression test for #2214
      it "does not return two error messages when email is blank" do
        order = Spree::Order.new
        order.stub(:require_email => true)
        order.valid?
        order.errors[:email].should == ["can't be blank"]
      end
    end
  end
end
