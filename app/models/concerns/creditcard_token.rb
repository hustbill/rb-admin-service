require 'openssl'
require 'base64'
module Concerns
  module CreditcardToken
    class Blowfish
      def self.cipher(mode, key, data)
        cipher = OpenSSL::Cipher::Cipher.new('bf-cbc').send(mode)
        cipher.key = Digest::SHA256.digest(key)
        cipher.update(data) << cipher.final
      end

      def self.encrypt(key, data)
        Base64.encode64(cipher(:encrypt, key, data)).chomp
      end

      def self.decrypt(key, text)
        cipher(:decrypt, key, Base64.decode64(text))
      end
    end

    def get_encrypted_number_and_verification_value(number, verification_value)
      Blowfish.encrypt('encrypt-key@@', "#{number}=#{verification_value}")    
    end

    def get_decrypted_number(encrypted_number_with_verification_value)
      get_decrypted_number_and_verification_value(encrypted_number_with_verification_value)[0]
    end

    def get_verification_value(encrypted_number_with_verification_value)    
      get_decrypted_number_and_verification_value(encrypted_number_with_verification_value)[1]
    end

    def get_decrypted_number_and_verification_value(encrypted_number_with_verification_value)
      Blowfish.decrypt('encrypt-key@@', encrypted_number_with_verification_value).split("=")
    end

    def get_encrypted_token(token)    
      Blowfish.encrypt('encrypt-key@@', token)
    end

    def get_decrypted_token(encrypted_token)
      Blowfish.decrypt('encrypt-key@@', encrypted_token)
    end
  end
end
