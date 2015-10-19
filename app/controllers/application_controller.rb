class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  before_filter :js_action

  before_action :authenticate_user!, only: :admin
  before_filter :configure_permitted_parameters, if: :devise_controller?

  def admin
    if current_user && current_user.is_admin?
      if params[:entries] == 'all'
        if params[:user_id].present?
          user = User.find(params[:user_id])
          @entries = user.entries.includes(:inspiration)
        else
          @entries = Entry.includes(:inspiration).all
        end

        if params[:photos].present?
          @entries = Kaminari.paginate_array(@entries.only_images.order('id DESC')).page(params[:page]).per(params[:per])
        else
          @entries = Kaminari.paginate_array(@entries.order('id DESC')).page(params[:page]).per(params[:per])
        end

        if user.present?
          @title = "ADMIN ENTRIES for <a href='/admin?email=#{user.email}'>#{user.email}</a>"
        else
          @title = 'ADMIN ENTRIES for ALL USERS'
        end
        render 'entries/index'
      else
        if params[:email].present?
          @users = User.where("email LIKE '%#{params[:email]}%'")
        elsif params[:user_key].present?
          @users = User.where("user_key LIKE '%#{params[:user_key]}%'")
        else
          @users = User.all
        end
        @user_list = @users.order('id DESC').page(params[:page]).per(params[:per])
        @entries = Entry.all
        render 'admin/index'
      end
    else
      flash[:alert] = 'Not authorized'
      redirect_to past_entries_path
    end
  end

  def redirect_back_or_to(default)
    redirect_to session.delete(:return_to) || default
  end

  def store_location
    session[:return_to] = request.referrer
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.for(:sign_up) do |u|
      u.permit(:first_name, :last_name, :email, :password, :password_confirmation)
    end
    devise_parameter_sanitizer.for(:account_update) do |u|
      u.permit(:first_name, :last_name, :email, :password, :password_confirmation,  { frequency: [] }, :send_past_entry, :send_time, :send_timezone, :current_password)
    end
  end

  def js_action
    @js_action = [controller_path.camelize.gsub('::', '_'), action_name].join('_')
  end
end
