class PaymentsController < ApplicationController
  before_action :authenticate_user!
  before_filter :require_permission
  
  skip_before_filter :authenticate_user!, only: [:payment_notify]
  skip_before_filter :require_permission, only: [:payment_notify]
  skip_before_filter :verify_authenticity_token, only: [:payment_notify]

  def index

    @monthlys = User.pro_only.monthly
    @yearlys =  User.pro_only.yearly

    @monthly_recurring = 0
    @monthlys.each do |user|
      @monthly_recurring += user.payments.last.amount
    end

    @annual_recurring = 0
    @yearlys.each do |user|
      @annual_recurring += user.payments.last.amount
    end

    @mrr = @monthly_recurring.to_i + (@annual_recurring.to_i/12)

    @payments = Payment.includes(:user).all.order("date DESC, id DESC")
  end

  def new
    @payment = Payment.new
  end

  def create

    if params[:user_email].present?
      user = User.find_by(email: params[:user_email].downcase)
      params[:payment][:user_id] = user.id if user.present?
    end

    @payment = Payment.create(payment_params)

    if @payment.save
      if user.present? && params["send_thanks"] == 1
        UserMailer.thanks_for_paying(user).deliver_later
        flash[:notice] = "Payment added successfully & thanks was sent!"
      else
        flash[:notice] = "Payment added successfully!"
      end
      user.update(user_params) if user.present? && user_params[:plan].present?
      redirect_to payments_path
    else
      render 'new'
    end
  end

  def edit
    @payment = Payment.find(params[:id])
  end

  def update
    @payment = Payment.find(params[:id])
    if params[:user_email].present?
      user = User.find_by(email: params[:user_email])
      params[:payment][:user_id] = user.id if user.present?
    end

    if @payment.update(payment_params)
      user.update(user_params) if user.present? && user_params[:plan].present?
      flash[:notice] = "Payment successfully updated!"
      redirect_to payments_path
    else
      render 'edit'
    end
  end

  def destroy
    @payment = Payment.find(params[:id])
    @payment.destroy
    flash[:notice] = 'Payment deleted successfully.'
    redirect_to payments_path
  end

  def payment_notify
    plan = 'Free'

    # check for GUMROAD
    if params[:email].present? && params[:seller_id].gsub("==","") == ENV['GUMROAD_SELLER_ID'] && params[:product_id].gsub("==","") == ENV['GUMROAD_PRODUCT_ID']
      user = User.find_by(gumroad_id: params[:purchaser_id])
      user = User.find_by(email: params[:email]) if user.blank?
      paid = params[:price].to_f / 100
      if params[:recurrence].present?
        frequency = params[:recurrence].titleize
      else
        frequency = paid.to_i > 10 ? 'Yearly' : 'Monthly'
      end
      if user.present? && user.payments.count > 0 && Payment.where(user_id: user.id).last.date.to_date === Time.now.to_date
        #duplicate, don't send
      elsif user.present?
        payment = Payment.create(user_id: user.id, comments: "Gumroad #{frequency} from #{user.email}", date: "#{Time.now.strftime("%Y-%m-%d")}", amount: paid )
        UserMailer.thanks_for_paying(user).deliver_later if user.payments.count == 1
      end
      plan = "PRO #{frequency} Gumroad"
      gumroad_id = params[:purchaser_id]

      UserMailer.no_user_here(params[:email], 'Gumroad').deliver_later if user.blank?

    # check for Paypal
    elsif params[:item_name].present? && params[:item_name].include?('Dabble Me') && params[:payment_status].present? && params[:payment_status] == "Completed" && params[:receiver_id] == ENV['PAYPAL_SELLER_ID']

      user_key = params[:item_name].gsub('Dabble Me PRO for ','') if params[:item_name].present?
      user = User.find_by(user_key: user_key)

      paid = params[:mc_gross]
      frequency = paid.to_i > 10 ? 'Yearly' : 'Monthly'

      if user.present? && user.payments.count > 0 && Payment.where(user_id: user.id).last.date.to_date === Time.now.to_date
        # duplicate, don't
      elsif user.present?
        payment = Payment.create(user_id: user.id, comments: "Paypal #{frequency} from #{params[:payer_email]}", date: "#{Time.now.strftime("%Y-%m-%d")}", amount: paid )
        UserMailer.thanks_for_paying(user).deliver_later if user.payments.count == 1
      end
      plan = "PRO #{frequency} PayPal"
      gumroad_id = user.gumroad_id if user.present?
      UserMailer.no_user_here(params[:payer_email], 'PayPal').deliver_later if user.blank?
    end

    user.update(plan: plan, gumroad_id: gumroad_id) if user.present?
    head :ok, content_type: 'text/html'
  end

  private
    def payment_params
      params.require(:payment).permit(:amount, :date, :user_id,  :comments)
    end

    def user_params
      params.permit(:plan)
    end 

    def require_permission
      unless current_user.is_admin?
        flash[:alert] = 'Not authorized'
        redirect_to past_entries_path
      end
    end
end
