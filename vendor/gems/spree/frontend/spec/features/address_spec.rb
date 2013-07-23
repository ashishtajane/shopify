require 'spec_helper'

describe "Address" do
  let!(:product) { create(:product, :name => "RoR Mug") }
  let!(:order) { create(:order_with_totals, :state => 'cart') }

  stub_authorization!

  after do
    Capybara.ignore_hidden_elements = true
  end

  before do
    Capybara.ignore_hidden_elements = false

    visit spree.root_path

    click_link "RoR Mug"
    click_button "add-to-cart-button"

    address = "order_bill_address_attributes"
    @country_css = "#{address}_country_id"
    @state_select_css = "##{address}_state_id"
    @state_name_css = "##{address}_state_name"
  end

  context "country requires state", :js => true, :focus => true do
    let!(:canada) { create(:country, :name => "Canada", :states_required => true, :iso => "CA") }

    context "but has no state" do
      it "shows the state input field" do
        click_button "Checkout"

        select canada.name, :from => @country_css
        page.should have_selector(@state_select_css, visible: false)
        page.should have_selector(@state_name_css, visible: true)
        find(@state_name_css)['class'].should_not =~ /hidden/
        find(@state_name_css)['class'].should =~ /required/
        find(@state_select_css)['class'].should_not =~ /required/
        page.should_not have_selector("input#{@state_name_css}[disabled]")
      end
    end

    context "and has state" do
      before { create(:state, :name => "Ontario", :country => canada) }

      it "shows the state collection selection" do
        click_button "Checkout"

        select canada.name, :from => @country_css
        page.should have_selector(@state_select_css, visible: true)
        page.should have_selector(@state_name_css, visible: false)
        find(@state_select_css)['class'].should =~ /required/
        find(@state_name_css)['class'].should_not =~ /required/
      end
    end

    context "user changes to country without states required" do
      let!(:france) { create(:country, :name => "France", :states_required => false, :iso => "FRA") }

      it "clears the state name" do
        click_button "Checkout"
        select canada.name, :from => @country_css
        page.find(@state_name_css).set("Toscana")

        select france.name, :from => @country_css
        page.find(@state_name_css).should have_content('')
        find(@state_name_css)['class'].should_not =~ /hidden/
        find(@state_name_css)['class'].should_not =~ /required/
        find(@state_select_css)['class'].should_not =~ /required/
      end
    end
  end

  context "country does not require state", :js => true do
    let!(:france) { create(:country, :name => "France", :states_required => false, :iso => "FRA") }

    it "shows a disabled state input field" do
       click_button "Checkout"

       select france.name, :from => @country_css
       page.should have_selector(@state_select_css, visible: false)
       page.should have_selector(@state_name_css, visible: false)
    end
  end
end
