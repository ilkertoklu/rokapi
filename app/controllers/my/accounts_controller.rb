class My::AccountsController < ApplicationController
  def show
  end

  def destroy
    if confirmed?
      Current.user.destroy!
      cookies.delete :session_id

      respond_to do |format|
        format.html { redirect_to welcome_path, notice: t(".deleted") }
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.html { redirect_to my_account_path, alert: t(".unconfirmed", word: confirmation_word) }
        format.json { render json: { confirmation: t(".unconfirmed", word: confirmation_word) }, status: :unprocessable_entity }
      end
    end
  end

  private
    def confirmed?
      comparable(params[:confirmation]) == comparable(confirmation_word)
    end

    def comparable(word)
      I18n.transliterate(word.to_s.strip).upcase
    end

    def confirmation_word
      t("my.accounts.confirmation_word")
    end
end
