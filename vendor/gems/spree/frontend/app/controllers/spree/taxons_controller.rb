module Spree
  class TaxonsController < Spree::StoreController
    rescue_from ActiveRecord::RecordNotFound, :with => :render_404
    helper 'spree/products'

    respond_to :html

    def show
      @taxon = Taxon.find_by_permalink!(params[:id])
      return unless @taxon

      @searcher = Spree::Config.searcher_class.new(params.merge(:taxon => @taxon.id))
      @searcher.current_user = try_spree_current_user
      @searcher.current_currency = current_currency
      @products = @searcher.retrieve_products
    end

    private

    def accurate_title
      if @taxon
        @taxon.seo_title
      else
        super
      end
    end

  end
end
