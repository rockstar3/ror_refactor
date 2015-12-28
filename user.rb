# == Schema Information
#
# Table name: users
#
#  id                              :integer          not null, primary key
#  email                           :string(255)      not null
#  crypted_password                :string(255)      not null
#  salt                            :string(255)      not null
#  created_at                      :datetime
#  updated_at                      :datetime
#  admin                           :boolean          default(FALSE)
#  stripe_id                       :string(255)
#  last4                           :string(255)
#  name                            :string(255)
#

class User < ActiveRecord::Base
  

  ### invalid email -  kschn()*@gmail.com ; email’s is only allow character, digit, underscore and dash
  ### invalid email - kschn..2015@gmail.com ; double dots "." are not allow
  ### invalid email - kschn.@gmail.com – email’s last character can not end with dot "."
  ### validates_format_of :email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i

  ### this regex fix above issue
  validates_format_of :email, :with => /\A([\w+\-].?)+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i
  
  validates_numericality_of :device_limit
  validates_numericality_of :event_limit
  validates_numericality_of :discount
  validates :name, presence: true
  validate :validate_operator
  validate :password_valid

  has_many :devices, dependent: :destroy

  def update_card token
    unless stripe_id.present?
      customer = Stripe::Customer.create(email: email, description: "ID " + id.to_s)
      self.stripe_id = cus['id']      
    else
      customer = Stripe::Customer.retrieve(stripe_id)
    end
    card = customer.cards.create({ card: token })
    customer.default_card = card.id
    customer.save    
    self.last4 = card[:last4]
    self.save
  end

  def add_new_device(device_attrs)
    User.transaction do
      begin
        if self.devices.count >= self.device_limit
          raise Exceptions::DeviceLimitReached.new("device_limit_reached")
        end
        device = self.devices.build(device_attrs)
        self.touch # force parent object to update its lock version
        device.save! # as child object creation in has_mamy association skips 
                     # locking mechanism. 
                     # This line also raises RecordInvalid exception if 
                     # device_attrs are not valid
        return device
      rescue ActiveRecord::StaleObjectError
        self.reload!
        retry
      end
    end
  end

  private
  ### validate_operator should be a private or protected method
  def validate_operator
    if device_limit.to_i < 0
      errors.add(:device_limit, 'Device limit count is invalid')
      return
    end
    if event_limit.to_i < 0
      errors.add(:event_limit, 'Event limit count is invalid')
      return
    end
    if discount.to_i < 0 or discount.to_i > 100
      errors.add(:discount, 'Discount is invalid')
      return
    end
  end
  
  def password_valid
    unless password.nil?
      unless password.empty? || password.length < 9
        true
      else
        errors.add(:password, 'is invalid')
      end
    end
  end
end