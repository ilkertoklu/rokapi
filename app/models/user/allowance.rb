module User::Allowance
  extend ActiveSupport::Concern

  included do
    validates :plan, inclusion: { in: Plan.keys }
  end

  def monthly_plan
    Plan.fetch(plan)
  end

  def scenes_played_this_month
    created_scenes.where(created_at: usage_period).count
  end

  def usage_left_percentage
    scenes_left = (monthly_plan.scenes - scenes_played_this_month).clamp(0..)
    (scenes_left * 100.0 / monthly_plan.scenes).ceil
  end

  def out_of_usage?
    usage_left_percentage.zero?
  end

  def usage_refills_at
    usage_period.end
  end

  private
    def usage_period
      months = (Time.current.year - created_at.year) * 12 + Time.current.month - created_at.month
      months -= 1 if created_at + months.months > Time.current

      (created_at + months.months)...(created_at + (months + 1).months)
    end
end
