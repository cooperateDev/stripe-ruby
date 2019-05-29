# frozen_string_literal: true

module Stripe
  class Subscription < APIResource
    extend Stripe::APIOperations::Create
    include Stripe::APIOperations::Delete
    extend Stripe::APIOperations::List
    include Stripe::APIOperations::Save

    OBJECT_NAME = "subscription".freeze

    custom_method :delete_discount, http_verb: :delete, http_path: "discount"

    save_nested_resource :source

    def delete_discount
      _, opts = request(:delete, discount_url)
      initialize_from({ discount: nil }, opts, true)
    end

    private def discount_url
      resource_url + "/discount"
    end
  end
end
