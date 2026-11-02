PurchaseKit.configure do |config|
  config.api_key = Rails.application.credentials.dig(:purchasekit, :api_key)
  config.app_id = Rails.application.credentials.dig(:purchasekit, :app_id)
  config.webhook_secret = Rails.application.credentials.dig(:purchasekit, :webhook_secret)

  config.demo_mode = config.api_key.blank? && !Rails.env.production?
  config.demo_products = Rails.application.config_for(:store_products).to_h do |_, ids|
    [ ids[:purchasekit], { apple_product_id: ids[:apple], google_product_id: ids[:google] } ]
  end
end
