json.customer_id @customer.id
json.success_path subscriptions_welcome_path

json.plans Plan.paid do |plan|
  json.key plan.key
  json.name plan.name
  json.adventures plan.adventures
  json.product_id plan.store_product.id
  json.current plan == Current.user.monthly_plan
end
