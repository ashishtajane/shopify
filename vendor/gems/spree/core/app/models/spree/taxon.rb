module Spree
  class Taxon < ActiveRecord::Base
    acts_as_nested_set dependent: :destroy

    belongs_to :taxonomy, class_name: 'Spree::Taxonomy'
    has_many :classifications, dependent: :delete_all
    has_many :products, through: :classifications

    before_create :set_permalink

    attr_accessible :name, :parent_id, :position, :icon, :description, :permalink, :taxonomy_id,
                    :meta_description, :meta_keywords, :meta_title

    validates :name, presence: true

    has_attached_file :icon,
      styles: { mini: '32x32>', normal: '128x128>' },
      default_style: :mini,
      url: '/spree/taxons/:id/:style/:basename.:extension',
      path: ':rails_root/public/spree/taxons/:id/:style/:basename.:extension',
      default_url: '/assets/default_taxon.png'

    include Spree::Core::S3Support
    supports_s3 :icon

    include Spree::Core::ProductFilters  # for detailed defs of filters

    # indicate which filters should be used for a taxon
    # this method should be customized to your own site
    def applicable_filters
      fs = []
      # fs << ProductFilters.taxons_below(self)
      ## unless it's a root taxon? left open for demo purposes

      fs << Spree::Core::ProductFilters.price_filter if Spree::Core::ProductFilters.respond_to?(:price_filter)
      fs << Spree::Core::ProductFilters.brand_filter if Spree::Core::ProductFilters.respond_to?(:brand_filter)
      fs
    end

    # Return meta_title if set otherwise generates from root name and/or taxon name
    def seo_title
      if meta_title
        meta_title
      else
        root? ? name : "#{root.name} - #{name}"
      end
    end

    # Creates permalink based on Stringex's .to_url method
    def set_permalink
      if parent.present?
        self.permalink = [parent.permalink, (permalink.blank? ? name.to_url : permalink.split('/').last)].join('/')
      else
        self.permalink = name.to_url if permalink.blank?
      end
    end

    # For #2759
    def to_param
      permalink
    end

    def active_products
      scope = products.active
      scope
    end

    def pretty_name
      ancestor_chain = self.ancestors.inject("") do |name, ancestor|
        name += "#{ancestor.name} -> "
      end
      ancestor_chain + "#{name}"
    end

  end
end
