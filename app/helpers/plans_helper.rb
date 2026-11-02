module PlansHelper
  def refill_date(user)
    date = user.usage_refills_at.to_date
    t("plans.refill_date", day: date.day, month: t("plans.refill_months")[date.month])
  end
end
