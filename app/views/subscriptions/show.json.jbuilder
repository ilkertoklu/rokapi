plan = Current.user.monthly_plan

json.plan plan.key
json.plan_name plan.name
json.status subscription_status(@subscription)
json.store @subscription&.data.to_h["store"]
json.current_period_end @subscription&.current_period_end
json.manage_url(@subscription && manage_subscription_url(@subscription))
json.usage_left_percentage Current.user.usage_left_percentage
json.usage_refills_at Current.user.usage_refills_at
