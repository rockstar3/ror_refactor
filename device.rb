# == Schema Information
#
# Table name: devices
#
#  id            :integer          not null, primary key
#  user_id       :integer
#  token         :string(255)
#  device_type   :string(255)
#  name          :string(255)
#  os            :string(255)
#  created_at    :datetime
#  updated_at    :datetime
#

class Device < ActiveRecord::Base

  belongs_to :user

  before_create :generate_access_token

  validates :device_type, :name, :os, presence: true

  private

  def generate_access_token
    begin
      self.token = SecureRandom.hex
    end while self.class.exists?(token: token)
  end

end