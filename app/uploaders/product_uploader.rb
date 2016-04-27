require 'carrierwave/processing/mini_magick'

class ProductUploader < CarrierWave::Uploader::Base

  # Include RMagick or MiniMagick support:
  # include CarrierWave::RMagick
  include CarrierWave::MiniMagick

  # Choose what kind of storage to use for r3rthis uploader:
  storage :grid_fs
  
 process :convert => 'jpg'
  # storage :fog

  # Override the directory where uploaded files will be stored.
  # This is a sensible default for uploaders that are meant to be mounted:
  def store_dir
    "#{model.class.to_s.underscore}/#{model.id}"
  end

  # Provide a default URL as a default if there hasn't been a file uploaded:
  # def default_url
  #   "/images/fallback/" + [version_name, "default.png"].compact.join('_')
  # end

  # Process files as they are uploaded:
  process :resize_to_fit => [1024, 1280]
  #
  # def scale(width, height)
  #   # do something
  # end

  # Create different versions of your uploaded files:
  # version :thumb do
  #   process :scale => [50, 50]
  # end
  
  version :mini do
    process :resize_to_fit => [40, 50]
  end
  
  version :small do
    process :resize_to_fit => [140, 175]
  end
  
  version :product do
    process :resize_to_fit => [400, 500]
  end
  
  version :list_thumb do 
    process :resize_to_fit => [208, 260]
  end
  
  version :large do
    process :resize_to_fit => [800, 1000]
  end
 

  version :email do
     process :resize_to_fit => [674,318]
  end

  version :mini_thumb do
    process :resize_to_fit => [18, 18]
  end
 
  # Add a white list of extensions which are allowed to be uploaded.
  # For images you might use something like this:
   def extension_white_list
     %w(jpg jpeg gif png)
   end

  # Override the filename of the uploaded files:
  # Avoid using model.id or version_name here, see uploader/store.rb for details.



  def filename
    @name ||= "#{secure_token}.#{extension}" if original_filename.present?
  end

  protected
  def secure_token
    var = :"@#{mounted_as}_secure_token"
    model.instance_variable_get(var) or model.instance_variable_set(var, SecureRandom.uuid)
  end
  
  def extension
    'jpg'
  end
end

