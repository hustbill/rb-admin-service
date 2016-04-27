require 'digest/sha1'
class Creditcard < ActiveRecord::Base
  include Concerns::CreditcardToken
  attr_accessor :number, :cvv, :unencrypted_token

  validates :month, :year, numericality: { only_integer: true }
  validates :issue_number, :token, presence: true
  before_validation :set_attributes

  def set_attributes
    set_issue_number
    set_encrypted_token
    set_last_digits
  end

  def set_issue_number
    self.issue_number = get_encrypted_number_and_verification_value('-', cvv) if cvv.present?
  end

  def set_encrypted_token
    self.token = get_encrypted_token(unencrypted_token.to_s) if unencrypted_token.present?
  end

  def set_last_digits
    if self.number.present?
      number = self.number.to_s.gsub(/\s/,'')
      self.last_digits = number.to_s.length <= 4 ? number : number.to_s[0,4] + '****' + number.to_s[-4..-1]
    end
  end
end
