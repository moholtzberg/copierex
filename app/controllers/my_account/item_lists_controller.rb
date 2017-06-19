class MyAccount::ItemListsController < ApplicationController
  layout 'shop'
  before_filter :find_cart, only: :show

  def new
    authorize! :create, ItemList
    @item_list = ItemList.new(item_list_params.to_h.merge(user_id: current_user.id))
  end

  def create
    authorize! :create, ItemList
    @item_list = ItemList.create(item_list_params.merge(user_id: current_user.id))
  end

  def show
    @item_list = ItemList.find(params[:id])
    authorize! :read, @item_list
  end

  def destroy
    @item_list = ItemList.find(params[:id])
    authorize! :destroy, @item_list
    @item_list.destroy
  end

  def index
    authorize! :read, ItemList
    @item_lists = current_user.item_lists
  end

  def find_cart
    if !cookies.permanent.signed[:cart_id].blank? and cookies.permanent.signed[:cart_id].is_a? Numeric
      unless !Cart.find_by(:id => cookies.permanent.signed[:cart_id]).nil?
        cookies.permanent.signed[:cart_id] = Cart.create.id
      end
    else
      cookies.permanent.signed[:cart_id] = Cart.create.id
    end
    @cart = Cart.find_by(:id => cookies.permanent.signed[:cart_id])
  end

  def item_list_params
    params.require(:item_list).permit(:name, item_item_lists_attributes: [:item_id]) if params[:item_list].present?
  end

end
