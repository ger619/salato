module Onboarding
  class ClientsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_client, only: %i[show edit update]

    def index
      @clients = Client.order(created_at: :desc)

      if params[:q].present?
        @clients = @clients.where(
          'name ILIKE :q OR email ILIKE :q OR phone ILIKE :q',
          q: "%#{params[:q]}%"
        )
      end

      @per_page = 10
      @page = [params[:page].to_i, 1].max
      @total_count = @clients.count
      @total_pages = (@total_count / @per_page.to_f).ceil
      @clients = @clients.offset((@page - 1) * @per_page).limit(@per_page)
    end

    def show; end

    def new
      @client = Client.new
    end

    def edit; end

    def create
      @client = Client.new(client_params)

      if @client.save
        redirect_to onboarding_client_path(@client), notice: 'Client added.'
      else
        render :new, status: 422
      end
    end

    def update
      if @client.update(client_params)
        redirect_to onboarding_client_path(@client), notice: 'Client updated.'
      else
        render :edit, status: 422
      end
    end

    private

    def set_client
      @client = Client.find(params[:id])
    end

    def client_params
      params.require(:client).permit(:name, :email, :phone, :address, :city, :country, :description,
                                     :paystack_subaccount_code, :registration_number, :settlement_bank, :tax_pin)
    end
  end
end
