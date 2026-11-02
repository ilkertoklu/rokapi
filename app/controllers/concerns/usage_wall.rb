module UsageWall
  extend ActiveSupport::Concern

  included do
    before_action :stop_at_usage_wall, only: %i[new create]
  end

  private
    def stop_at_usage_wall
      if Current.user.out_of_usage?
        respond_to do |format|
          format.html { request.get? ? render("plans/wall") : redirect_to(action: :new) }
          format.json { render "plans/wall", status: :payment_required }
        end
      end
    end
end
