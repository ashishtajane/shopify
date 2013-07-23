module Spree
	HomeController.class_eval do
		alias_method :orig_index, :index
		def index
			@sale_products = Product.joins(:variants_including_master).where('spree_variants.sale_price is not null').uniq
			orig_index
		end
	end
end