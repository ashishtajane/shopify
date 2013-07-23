module Spree
  class Product < ActiveRecord::Base
    cattr_accessor :search_scopes do
      []
    end

    def self.add_search_scope(name, &block)
      self.singleton_class.send(:define_method, name.to_sym, &block)
      search_scopes << name.to_sym
    end

    def self.simple_scopes
      [
        :ascend_by_updated_at,
        :descend_by_updated_at,
        :ascend_by_name,
        :descend_by_name
      ]
    end

    def self.add_simple_scopes(scopes)
      scopes.each do |name|
        # We should not define price scopes here, as they require something slightly different
        next if name.to_s.include?("master_price")
        parts = name.to_s.match(/(.*)_by_(.*)/)
        order_text = "#{Product.quoted_table_name}.#{parts[2]} #{parts[1] == 'ascend' ?  "ASC" : "DESC"}"
        self.scope(name.to_s, relation.order(order_text))
      end
    end

    add_simple_scopes simple_scopes

    add_search_scope :ascend_by_master_price do
      joins(:master => :default_price).order("#{price_table_name}.amount ASC")
    end

    add_search_scope :descend_by_master_price do
      joins(:master => :default_price).order("#{price_table_name}.amount DESC")
    end

    add_search_scope :price_between do |low, high|
      joins(:master => :default_price).where(Price.table_name => { :amount => low..high })
    end

    add_search_scope :master_price_lte do |price|
      joins(:master => :default_price).where("#{price_table_name}.amount <= ?", price)
    end

    add_search_scope :master_price_gte do |price|
      joins(:master => :default_price).where("#{price_table_name}.amount >= ?", price)
    end

    # This scope selects products in taxon AND all its descendants
    # If you need products only within one taxon use
    #
    #   Spree::Product.joins(:taxons).where(Taxon.table_name => { :id => taxon.id })
    #
    # If you're using count on the result of this scope, you must use the
    # `:distinct` option as well:
    #
    #   Spree::Product.in_taxon(taxon).count(:distinct => true)
    #
    # This is so that the count query is distinct'd:
    #
    #   SELECT COUNT(DISTINCT "spree_products"."id") ...
    #
    #   vs.
    #
    #   SELECT COUNT(*) ...
    add_search_scope :in_taxon do |taxon|
      if ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
        scope = select("DISTINCT ON (spree_products.id) spree_products.*")
      else
        scope = select("DISTINCT(spree_products.id), spree_products.*")
      end

      scope.joins(:taxons).
      where(Taxon.table_name => { :id => taxon.self_and_descendants.map(&:id) })
    end

    # This scope selects products in all taxons AND all its descendants
    # If you need products only within one taxon use
    #
    #   Spree::Product.taxons_id_eq([x,y])
    add_search_scope :in_taxons do |*taxons|
      taxons = get_taxons(taxons)
      taxons.first ? prepare_taxon_conditions(taxons) : scoped
    end

    # a scope that finds all products having property specified by name, object or id
    add_search_scope :with_property do |property|
      properties = Property.table_name
      conditions = case property
      when String   then { "#{properties}.name" => property }
      when Property then { "#{properties}.id" => property.id }
      else               { "#{properties}.id" => property.to_i }
      end

      joins(:properties).where(conditions)
    end

    # a simple test for product with a certain property-value pairing
    # note that it can test for properties with NULL values, but not for absent values
    add_search_scope :with_property_value do |property, value|
      properties = Spree::Property.table_name
      conditions = case property
      when String   then ["#{properties}.name = ?", property]
      when Property then ["#{properties}.id = ?", property.id]
      else               ["#{properties}.id = ?", property.to_i]
      end
      conditions = ["#{ProductProperty.table_name}.value = ? AND #{conditions[0]}", value, conditions[1]]

      joins(:properties).where(conditions)
    end

    add_search_scope :with_option do |option|
      option_types = OptionType.table_name
      conditions = case option
      when String     then { "#{option_types}.name" => option }
      when OptionType then { "#{option_types}.id" => option.id }
      else                 { "#{option_types}.id" => option.to_i }
      end

      joins(:option_types).where(conditions)
    end

    add_search_scope :with_option_value do |option, value|
      option_values = OptionValue.table_name
      option_type_id = case option
        when String then OptionType.find_by_name(option) || option.to_i
        when OptionType then option.id
        else option.to_i
      end

      conditions = "#{option_values}.name = ? AND #{option_values}.option_type_id = ?", value, option_type_id
      group("spree_products.id").joins(:variants_including_master => :option_values).where(conditions)
    end

    # Finds all products which have either:
    # 1) have an option value with the name matching the one given
    # 2) have a product property with a value matching the one given
    add_search_scope :with do |value|
      includes(:variants_including_master => :option_values).
      includes(:product_properties).
      where("#{OptionValue.table_name}.name = ? OR #{ProductProperty.table_name}.value = ?", value, value)
    end

    # Finds all products that have a name containing the given words.
    add_search_scope :in_name do |words|
      like_any([:name], prepare_words(words))
    end

    # Finds all products that have a name or meta_keywords containing the given words.
    add_search_scope :in_name_or_keywords do |words|
      like_any([:name, :meta_keywords], prepare_words(words))
    end

    # Finds all products that have a name, description, meta_description or meta_keywords containing the given keywords.
    add_search_scope :in_name_or_description do |words|
      like_any([:name, :description, :meta_description, :meta_keywords], prepare_words(words))
    end

    # Finds all products that have the ids matching the given collection of ids.
    # Alternatively, you could use find(collection_of_ids), but that would raise an exception if one product couldn't be found
    add_search_scope :with_ids do |*ids|
      where(:id => ids)
    end

    # Sorts products from most popular (popularity is extracted from how many
    # times use has put product in cart, not completed orders)
    #
    # there is alternative faster and more elegant solution, it has small drawback though,
    # it doesn stack with other scopes :/
    #
    # :joins => "LEFT OUTER JOIN (SELECT line_items.variant_id as vid, COUNT(*) as cnt FROM line_items GROUP BY line_items.variant_id) AS popularity_count ON variants.id = vid",
    # :order => 'COALESCE(cnt, 0) DESC'
    add_search_scope :descend_by_popularity do
      joins(:master).
      order(%Q{
           COALESCE((
             SELECT
               COUNT(#{LineItem.quoted_table_name}.id)
             FROM
               #{LineItem.quoted_table_name}
             JOIN
               #{Variant.quoted_table_name} AS popular_variants
             ON
               popular_variants.id = #{LineItem.quoted_table_name}.variant_id
             WHERE
               popular_variants.product_id = #{Product.quoted_table_name}.id
           ), 0) DESC
        })
    end

    add_search_scope :not_deleted do
      where("#{Product.quoted_table_name}.deleted_at IS NULL or #{Product.quoted_table_name}.deleted_at >= ?", Time.zone.now)
    end

    # Can't use add_search_scope for this as it needs a default argument
    def self.available(available_on = nil, currency = nil)
      scope = joins(:master => :prices).where("#{Product.quoted_table_name}.available_on <= ?", available_on || Time.now)
      unless Spree::Config.show_products_without_price
        scope = scope.where('spree_prices.currency' => currency || Spree::Config[:currency]).where('spree_prices.amount IS NOT NULL')
      end
      scope
    end
    search_scopes << :available

    def self.active(currency = nil)
      not_deleted.available(nil, currency)
    end
    search_scopes << :active

    add_search_scope :taxons_name_eq do |name|
      group("spree_products.id").joins(:taxons).where(Taxon.arel_table[:name].eq(name))
    end

    # This method needs to be defined *as a method*, otherwise it will cause the
    # problem shown in #1247.
    def self.group_by_products_id
      if (ActiveRecord::Base.connection.adapter_name == 'PostgreSQL')
        # Need to check, otherwise `column_names` will fail
        if table_exists?
          group(column_names.map { |col_name| "#{table_name}.#{col_name}"})
        end
      else
        group("#{self.quoted_table_name}.id")
      end
    end

    private

      def self.price_table_name
        Price.quoted_table_name
      end

      # specifically avoid having an order for taxon search (conflicts with main order)
      def self.prepare_taxon_conditions(taxons)
        ids = taxons.map { |taxon| taxon.self_and_descendants.pluck(:id) }.flatten.uniq
        joins(:taxons).where("#{Taxon.table_name}.id" => ids)
      end

      # Produce an array of keywords for use in scopes.
      # Always return array with at least an empty string to avoid SQL errors
      def self.prepare_words(words)
        return [''] if words.blank?
        a = words.split(/[,\s]/).map(&:strip)
        a.any? ? a : ['']
      end

      def self.get_taxons(*ids_or_records_or_names)
        taxons = Taxon.table_name
        ids_or_records_or_names.flatten.map { |t|
          case t
          when Integer then Taxon.find_by_id(t)
          when ActiveRecord::Base then t
          when String
            Taxon.find_by_name(t) ||
            Taxon.where("#{taxons}.permalink LIKE ? OR #{taxons}.permalink = ?", "%/#{t}/", "#{t}/").first
          end
        }.compact.flatten.uniq
      end
    end
end
