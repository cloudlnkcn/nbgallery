# Controller for execution environments
class EnvironmentsController < ApplicationController
  before_action :verify_login
  before_action :set_environment, only: [:show, :update, :destroy, :edit]

  # GET /environments
  def index
    respond_to do |format|
      format.html do
        # Show all the user's environments
        @environments = Environment.where(user: @user)
      end
      format.json do
        # If one of them is marked default, just return that one.
        # Otherwise return them all so the GUI can prompt to select one.
        default = Environment.where(user: @user, default: true).first
        @environments = default ? [default] : Environment.where(user: @user)
      end
    end
  end

  # GET /environments/:name
  def show
  end

  # GET /environments/new
  def new
    @environment = Environment.new
    @url = url_for(controller: 'environments')
    @type = 'POST'
    respond_to do |format|
      format.html {render 'modal', layout: false}
    end
  end

  # GET /environments/:name/edit
  def edit
    @url = url_for(controller: 'environments') + '/' + @environment.name
    @type = 'PATCH'
    respond_to do |format|
      format.html {render 'modal', layout: false}
    end
  end

  # POST /environments
  def create
    @environment = Environment.find_or_initialize_by(user: @user, name: params[:name].strip)
    handle_create_or_update
  end

  # PATCH /environments/:name
  def update
    handle_create_or_update
  end

  # DELETE /environments/:name
  def destroy
    @environment.destroy
    head :no_content
  end

  private

  # Common code for create and update
  def handle_create_or_update
    @environment.name = params[:name].strip unless params[:name].blank?
    @environment.url = params[:url].strip unless params[:url].blank?
    @environment.default = params[:default].to_bool

    if @environment.save
      if @environment.default
        # Set all other environments to non-default
        Environment
          .where('user_id = ? AND id != ?', @user.id, @environment.id)
          .update_all(default: false)
      end
      head :no_content
    else
      render json: @environment.errors, status: :unprocessable_entity
    end
  end

  # Set the environment object to use
  def set_environment
    @environment = Environment.find_by!(user: @user, name: params[:id])
  end
end