# TODO move this method to HttpAuth initializer
# Returns an array containing the vhost 'CoSign service' value and URL
Sufia.config do |config|
  config.id_namespace = "sufia"
  config.fits_path = Rails.env.production? ? '/home/ubuntu/fits-0.6.1/fits.sh' : "fits.sh"
  config.fits_to_desc_mapping= {
      :file_title => :title,
      :file_author => :creator
    }

  config.max_days_between_audits = 7

  config.google_analytics_id = 'UA-37306938-1'

      config.cc_licenses = {
      'Attribution 3.0 United States' => 'http://creativecommons.org/licenses/by/3.0/us/',
      'Attribution-ShareAlike 3.0 United States' => 'http://creativecommons.org/licenses/by-sa/3.0/us/',
      'Attribution-NonCommercial 3.0 United States' => 'http://creativecommons.org/licenses/by-nc/3.0/us/',
      'Attribution-NoDerivs 3.0 United States' => 'http://creativecommons.org/licenses/by-nd/3.0/us/',
      'Attribution-NonCommercial-NoDerivs 3.0 United States' => 'http://creativecommons.org/licenses/by-nc-nd/3.0/us/',
      'Attribution-NonCommercial-ShareAlike 3.0 United States' => 'http://creativecommons.org/licenses/by-nc-sa/3.0/us/',
      'Public Domain Mark 1.0' => 'http://creativecommons.org/publicdomain/mark/1.0/',
      'CC0 1.0 Universal' => 'http://creativecommons.org/publicdomain/zero/1.0/',
      'All rights reserved' => 'All rights reserved'
    }

    config.cc_licenses_reverse = Hash[*config.cc_licenses.to_a.flatten.reverse]

    config.resource_types = {
      "Article" => "Article",
      "Audio" => "Audio",
      "Book" => "Book",
      "Capstone Project" => "Capstone Project",
      "Conference Proceeding" => "Conference Proceeding",
      "Dataset" => "Dataset",
      "Dissertation" => "Dissertation",
      "Image" => "Image",
      "Journal" => "Journal",
      "Map or Cartographic Material" => "Map or Cartographic Material",
      "Masters Thesis" => "Masters Thesis",
      "Part of Book" => "Part of Book",
      "Poster" => "Poster",
      "Presentation" => "Presentation",
      "Project" => "Project",
      "Report" => "Report",
      "Research Paper" => "Research Paper",
      "Software or Program Code" => "Software or Program Code",
      "Video" => "Video",
      "Other" => "Other",
    }


    config.permission_levels = {
      "Choose Access"=>"none",
      "View/Download" => "read",
      "Edit" => "edit"
    }

    config.owner_permission_levels = {
      "Edit" => "edit"
    }

    config.temp_file_base = '/opt/bawstun_tmp' if Rails.env.production?

    config.enable_ffmpeg = true

end


