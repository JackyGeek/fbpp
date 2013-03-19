class Lecturer < ActiveRecord::Base
  belongs_to :user
  belongs_to :departament
  attr_accessible :degree, :user_id, :departament_id

  DEGREELIST = {
  }

  # Возвращает данные преподавателя по ID пользователя
  def self.get_by_uid(user)
    Lecturer.where(:user_id => user.id).first
  end
end
