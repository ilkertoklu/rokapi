json.error t("plans.wall.exhausted", date: refill_date(Current.user))
json.plan Current.user.monthly_plan.key
json.usage_left_percentage Current.user.usage_left_percentage
json.refills_at Current.user.usage_refills_at
