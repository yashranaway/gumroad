# frozen_string_literal: true

class BundleSearchProductsService
  include SearchProducts

  PER_PAGE = 10

  def initialize(bundle:, seller:, query: nil, page: 1, all: false)
    @bundle = bundle
    @seller = seller
    @query = query
    @page = page.to_i
    @all = all
  end

  def call
    options = {
      query: @query,
      from: @all ? 0 : (@page - 1) * PER_PAGE,
      sort: ProductSortKey::FEATURED,
      user_id: @seller.id,
      is_subscription: false,
      is_bundle: false,
      is_alive: true,
      is_call: false,
      exclude_ids: [@bundle.id],
    }
    options[:size] = PER_PAGE unless @all

    result = search_products(options)
    products = result[:products].map { BundlePresenter.bundle_product(product: _1) }

    {
      products: products,
      has_more: !@all && products.length >= PER_PAGE,
      page: @page
    }
  end
end
