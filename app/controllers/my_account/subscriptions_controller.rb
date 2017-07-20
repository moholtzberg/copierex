class MyAccount::SubscriptionsController < ApplicationController
  respond_to :html, :json
  
  def index
    authorize! :read, Subscription
    @subscriptions =  Subscription.where(account: current_user.account, state: [:active, :paused])
  end

  def new
    authorize! :create, Subscription
    @subscription = Subscription.new(subscription_params)
  end

  def details
    authorize! :create, Subscription
    @subscription = Subscription.find(params[:id])
    @subscription.ship_to_address = Address.new
    @subscription.bill_to_address = Address.new
    @cards = current_user.account.main_service.credit_cards
    @payment = Payment.new
  end

  def update_details
    authorize! :create, Subscription
    @subscription = Subscription.find(params[:id])
    @subscription.ship_to_address = Address.find_or_create_by(subscription_params[:ship_to_address_attributes].merge(account_id: @subscription.account_id))
    @subscription.bill_to_address = Address.find_or_create_by(subscription_params[:bill_to_address_attributes].merge(account_id: @subscription.account_id))
    @subscription.payment_method = params[:payment_method]
    @subscription.set_address
    @order = @subscription.build_order
    @payment = @order.payments.new
    @payment.account = @subscription.account
    @payment.amount = @subscription.quantity * @subscription.item.prices.select{|p| p._type == 'Recurring'}[0].price
    if (params[:payment_method] == "terms" || params[:payment_method] == "check")
      @payment.payment_type = "CheckPayment"
      if @subscription.save && @order.save && @payment.save
        @subscription.activate
        OrderPaymentApplication.create(:order_id => @order.id, :payment_id => @payment.id, :applied_amount => @payment.amount)
        redirect_to my_account_path
      else
        render "details"
      end
    else
      @payment.payment_type = "CreditCardPayment"
      if params[:payment_method] == "credit_card"
        @card = CreditCard.store({
          cardholder_name: params[:cardholder_name],
          number: params[:credit_card_number],
          cvv: params[:card_security_code],
          expiration_month: params[:expiration_month],
          expiration_year: params[:expiration_year],
          customer_id: @subscription.account.main_service.service_id,
          account_payment_service_id: @subscription.account.main_service.id
        })
      else
        @card = CreditCard.find_by(account_payment_service_id: @subscription.account.main_service.id, service_card_id: params[:credit_card_token])
      end
      @payment.credit_card = @card
      @subscription.credit_card = @card
      @subscription.set_credit_card
      @cards = @subscription.account.main_service.credit_cards
      if @payment.authorize && @subscription.save && @order.save && @payment.save
        @subscription.activate
        OrderPaymentApplication.create(:order_id => @order.id, :payment_id => @payment.id, :applied_amount => @payment.amount)
        redirect_to my_account_path
      else
        render "details"
      end
    end
  end
  
  def create
    authorize! :create, Subscription
    @subscription = Subscription.create(subscription_params)
    flash[:error] = @subscription.errors.full_messages.join(', ') if @subscription.errors.any?
    respond_to do |format|
      format.html
      format.js
    end
  end
  
  def destroy
    authorize! :destroy, Subscription
    @subscription = Subscription.find_by(:id => params[:id])
    @account = @subscription.account
    @subscription.destroy!
    respond_to do |format|
      format.js
    end
  end
  
  private

  def subscription_params
    prms = params.require(:subscription).permit(:account_id, :item_id, :quantity, :frequency,
      ship_to_address_attributes: [:address_1, :address_2, :city, :state, :zip, :phone],
      bill_to_address_attributes: [:address_1, :address_2, :city, :state, :zip, :phone]
    )
    prms[:bill_to_address_attributes] = prms[:ship_to_address_attributes] if params[:use_ship_to_address]
    prms
  end
end