class SessionsController < ApplicationController

  before_filter :require_auth, :except => [:login, :profile]
  before_filter :require_not_auth, :only => :login

  # GET /login
  # Отоборажает форму авторизации пользователя
  #
  # POST /login
  # Пытается авторизировать пользователя на основе введённых данных
  def login
    # Если пришел GET-запрос - просто отображаем форму
    render 'login' and return if request.get?
    # Пытаемся авторизироваться на основе введённых данных
    login, password = params[:login], params[:password]
    # Если логин или пароль не совпали с правильными значениями
    unless user = User.authenticate(login, password) then
      redirect_to :login, notice: t('messages.bad_login') and return
    end
    # Если аккаунт пользователя удалён
    if user.removed then
      redirect_to :login, notice: t('messages.removed_account') and return
    end
    # Ели пользователь забанен
    if user.banned then
      redirect_to :login, :notice => t('messages.banned') and return
    end
    # В случае успешной авторизации запоминаем пользователя и перебрасываем
    # его на главную страницу
    session[:user_id] = user.id
    redirect_to :root
  end

  # GET /logout
  def logout
    clear_user_session
    redirect_to :root
  end

  # GET /profile/(login)
  # Отображает профиль указанного пользователя
  def profile
    redirect_to :login and return unless (params[:login] || logged?)
    login = params[:login] || logged_user.login
    @user = User.where(login: login).first!
  end

  # GET /my/options
  # POST /my/options
  # Отображает личный кабинет
  def options
    # Дополнительные опции доступны только для студентов и преподавателей
    unless User.in_user_group?(logged_user) then
      redirect_to :profile and return
    end
    if request.get? then
      render 'options' and return
    end
    if logged_user.student?
      obj = Student.find_by_user_id(logged_user.id)
      obj.course = params[:course]
      obj.specialty_id = params[:specialty]
    elsif logged_user.lecturer?
      obj = Lecturer.find_by_user_id(logged_user.id)
      obj.departament_id = params[:departament]
      obj.scientific_degree_id = params[:degree]
      # Сброс статуса подтверждения аккаунта, если преподаватель изменяет свои
      # персональные данные (для аккаунтов с подтверждённой личностью это не затрагивает)
      unless obj.real? then
        obj.confirm_level = Lecturer::CONFIRM_LEVELS[:unconfirmed]
      end
    end
    obj.user_id = logged_user.id
    if obj.save then
      redirect_to :profile
    else
      redirect_to :my_options, :notice => t('messages.invalid_operation')
    end
  end

  # GET /my/change_password
  # Отображает форму смены пароля
  #
  # PUT /my/change_password
  # Меняет пароль для авторизированного пользователя
  def change_password
    @user = User.find(logged_user.id)
    render :change_password and return if request.get?
    if request.put? then
      current_password = params[:current_password]
      # Если текущий пароль не совпадает с введённым
      unless User.authenticate(@user.login, current_password) then
        @user.errors[:base] << t('messages.invalid_current_password')
        render :change_password and return
      end
      # Обновляемые атрибуты
      attributes = { :password => params[:user][:password],
        :password_confirmation => params[:user][:password_confirmation] }
      # В случае успешного обновления пароля
      if @user.update_attributes(attributes) then
        redirect_to :profile
      else
        render :change_password
      end
    end
  end

  # DELETE /remove_account
  def remove
    if logged_user.admin? then
      redirect_to :root, :notice => t('messages.cant_delete_admin_account') and return
    end
    user = User.find(logged_user.id)
    # Удаление дополнительных данных
    if user.student? then
      Student.get_by_user(user).destroy
      # Comment.where(user_id: user.id)
    elsif user.lecturer? then
      Lecturer.get_by_user(user).destroy
    end
    user.update_attributes({ removed: true, account_type: nil })
    # Выход из системы
    clear_user_session
    redirect_to :root, :notice => t('messages.account_has_been_removed_succ')
  end

  def lecturer_comments
    #  Список комментариев для вывода
    @comments = Lecturer.find(params[:lid]).lecturer_comments.joins(:comment).order('comments.posttime DESC')
    @lecturer_id = params[:lid]
    render 'lecturer_comments'
  end

end