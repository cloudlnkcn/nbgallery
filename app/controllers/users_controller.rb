# User controller
class UsersController < ApplicationController
  before_action :verify_admin, except: [:show, :groups, :index, :edit, :update]
  before_action :set_viewed_user, except: [:index, :new, :create]

  # GET /users
  def index
    @users = User.all
    respond_to do |format|
      format.html do
        verify_admin
      end
      format.json {render json: @users.pluck(:email).to_json}
    end
  end

  # GET /users/:email
  def show
    @notebooks = query_notebooks.where(owner: @viewed_user)
    respond_to do |format|
      format.html
      format.json {render 'notebooks/index'}
    end
  end

  # GET /users/:email/groups
  def groups
    @groups = @viewed_user.groups_with_notebooks
  end

  # GET /users/:email/detail
  def detail
    @recent_updates = @viewed_user.clicks
      .includes(:notebook)
      .where(action: ['created notebook', 'updated notebook'])
      .order(updated_at: :desc)
      .take(20)
    @recent_actions = @viewed_user.clicks
      .includes(:notebook)
      .where.not(action: 'agreed to terms')
      .order(updated_at: :desc)
      .take(20)
    @similar_users = @viewed_user.user_similarities
      .includes(:other_user)
      .order(score: :desc)
      .take(20)
    @suggested_notebooks = @viewed_user.suggested_notebooks
      .includes(:notebook)
      .select([
        'suggested_notebooks.*',
        SuggestedNotebook.reasons_sql,
        SuggestedNotebook.score_sql
      ].join(', '))
      .group(:notebook_id)
      .order('score DESC')
      .take(20)
    groups = @viewed_user.suggested_groups
      .includes(:group)
      .map {|group| [group.group.id, group.group]}
      .to_h
    @suggested_groups = Notebook
      .where(owner: groups.values)
      .group(:owner_id)
      .count
      .map {|id, count| [groups[id], count]}
      .sort_by {|_group, count| -count + rand}
      .take(20)
    @suggested_tags = Tag
      .where(tag: @viewed_user.suggested_tags.pluck(:tag))
      .group(:tag)
      .count
      .sort_by {|_tag, count| -count + rand}
      .take(20)
  end

  # GET /users/new
  def new
    @viewed_user = User.new
  end

  def edit
  end

  # POST /users
  def create
    @viewed_user = User.new(user_params)

    respond_to do |format|
      if @viewed_user.save
        format.html {redirect_to @viewed_user, notice: 'User was successfully created.'}
        format.json {render :show, status: :created, location: @viewed_user}
      else
        format.html {render :new}
        format.json {render json: @viewed_user.errors, status: :unprocessable_entity}
      end
    end
  end

  # PATCH/PUT /users/:email
  def update
    if @user.id == @viewed_user.id || @user.admin?
      respond_to do |format|
        if @viewed_user.update(user_params)
          format.html {redirect_to @viewed_user, notice: 'User was successfully updated.'}
          format.json {render :show, status: :ok, location: @viewed_user}
        else
          format.html {render :edit}
          format.json {render json: @viewed_user.errors, status: :unprocessable_entity}
        end
      end
    end
  end

  # DELETE /users/:email
  def destroy
    @viewed_user.destroy
    respond_to do |format|
      format.html {redirect_to users_url, notice: 'User was successfully destroyed.'}
      format.json {head :no_content}
    end
  end

  # GET/PATCH /users/:id/finish_signup
  def finish_signup
    # authorize! :update, @user 
    if request.patch? && params[:user] #&& params[:user][:email]
      if @user.update(user_params)
        @user.skip_reconfirmation!
        #sign_in(@user, :bypass => true)
        redirect_to @user, notice: 'Your profile was successfully updated.'
      else
        @show_errors = true
      end
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_viewed_user
    @viewed_user = User.find_by_email(params[:id]) || User.find_by_user_name(params[:id]) || User.find(params[:id])
    puts @viewed_user
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def user_params
    general_fields = [:email, :user_name, :first_name, :last_name, :org, :admin]
    admin_fields = [:email, :user_name, :first_name, :last_name, :org]
    fields = @user.admin? ? admin_fields : general_fields
    params.require(:user).permit(*fields)
  end
end