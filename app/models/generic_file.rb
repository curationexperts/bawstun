require 'fileutils'

class GenericFile < ActiveFedora::Base
  include Sufia::GenericFile
  include Open3
  include GenericFileConcerns::Ftp
  include PbcoreExport

  has_metadata 'ffprobe', type: FfmpegDatastream
  has_metadata 'descMetadata', type: MediaAnnotationDatastream
  has_file_datastream "content", type: FileContentDatastream, control_group: 'E'

  has_attributes :has_location, :program_title, :series_title, :item_title,
              :episode_title, :has_event, :event_location, :production_location, :filming_event,
              :production_event, :date_portrayed, :has_event_attributes, :source, :source_reference,
              :rights_holder, :rights_summary, :release_date, :review_date,:aspect_ratio,
              :frame_rate, :cc, :physical_location, :nola_code, :tape_id, :barcode, :notes, 
              :originating_department,
              :creator_attributes, :contributor_attributes, :publisher_attributes, 
              :has_location_attributes, :description_attributes, :title_attributes, 
              :identifier_attributes, datastream: 'descMetadata', multiple: true

  has_attributes :unarranged, :applied_template_id, datastream: 'properties', multiple: false

  attr_accessible  :part_of, :contributor_attributes, :creator_attributes, :title_attributes,
        :description_attributes, :publisher_attributes, :date_created, :date_uploaded,
        :date_modified, :subject, :language, :rights, :resource_type, :identifier, :event_location,
        :production_location, :date_portrayed, :source, :source_reference, :rights_holder,
        :rights_summary, :release_date, :review_date, :aspect_ratio, :frame_rate, :cc,
        :physical_location, :metadata_filename, :identifier_attributes, :notes,
        :originating_department, :tag, :related_url, :permissions

  before_destroy :remove_content


  def metadata_filename
    descMetadata.filename
  end

  def metadata_filename= val
    descMetadata.filename= val
  end

  def [](key)
    if key == :metadata_filename
      metadata_filename
    else
      super
    end
  end
  def []=(key, value)
    if key == :metadata_filename
      self.metadata_filename = value
    else
      super
    end
  end

  def remove_content
    content.run_callbacks :destroy 
  end

  # overriding this method to initialize more complex RDF assertions (b-nodes)
  def initialize_fields
    publisher.build if publisher.empty?
    contributor.build if contributor.empty?
    creator.build if creator.empty?
    identifier.build if identifier.empty?
    description.build if description.empty?
    super
  end

  
  def remove_blank_assertions
    publisher.select { |p| p.name.first == '' && p.role.first == ''}.each(&:destroy)
    contributor.select { |p| p.name.first == '' && p.role.first == ''}.each(&:destroy)
    creator.select { |p| p.name.first == '' && p.role.first == ''}.each(&:destroy)
    # events (filming events and production events specifically) must have locations
    has_event.each do |event|
      event.has_location.each do |location|
        location.destroy if location.location_name.first == ''
      end
    end
    description.select { |p| p.value.first == '' && p.type.first == ''}.each(&:destroy)
    title.select { |p| p.value.first == '' && p.title_type.first == ''}.each(&:destroy)
    super
  end

  # Overridden to write the file into the external store instead of a datastream
  def add_file(file, dsid, file_name) 
    return add_external_file(file, dsid, file_name) if dsid == 'content'
    super
  end

  def add_external_file(file, dsid, file_name)
    path = File.join(directory, file_name)
    if file.respond_to? :read
      File.open(path, 'wb') do |f| 
        f.write file.read 
      end
    else
      # it's a filename.
      FileUtils.move(file, path)
    end
    
    content.dsLocation = URI.escape("file://#{path}")
    mime = MIME::Types.type_for(path).first
    content.mimeType = mime.content_type if mime # mime can't always be detected by filename
    title = self.title.build(value: file_name, title_type: 'Program')
    self.label = file_name
    save!
  end

  # Overridden to check that mxf actually has video tracks 
  def video?
    if mime_type == 'application/mxf'
      ffprobe.codec_type.any? {|type| type == 'video'}
    else
      super
    end
  end

  # If the mxf has no video tracks return true   
  def audio?
    if mime_type == 'application/mxf'
      !ffprobe.codec_type.any? {|type| type == 'video'}
    else
      super
    end
  end

  # Overridden to load the original image from an external datastream
  def load_image_transformer
    Magick::ImageList.new(content.filename)
  end

  def directory
    dir_parts = noid.scan(/.{1,2}/)
    dir = File.join(Rails.configuration.external_store_base, dir_parts)
    FileUtils.mkdir_p(dir) unless Dir.exists?(dir)
    dir
  end  

  def log_events
    TrackingEvent.where(pid: pid)
  end

  def views
    log_events.where(event: 'view')
  end

  def downloads
    log_events.where(event: 'download')
  end

  def terms_for_editing
    terms_for_display -
     [:part_of, :date_modified, :date_uploaded, :format] # I'm not sure why resource_type would be excluded#, :resource_type]
  end

  def terms_for_display
    [ :part_of, :contributor, :creator, :title, :description, :event_location, :production_location,
      :date_portrayed, :source, :source_reference, :rights_holder, :rights_summary, :publisher,
      :date_created, :release_date, :review_date, :aspect_ratio, :frame_rate, :cc,
      :physical_location, :identifier, :metadata_filename, :notes, :originating_department, 
      :date_uploaded, :date_modified, :subject, :language, :rights, :resource_type, :tag,
      :related_url]
  end
  
  ## Extract the metadata from the content datastream and record it in the characterization datastream
  def characterize
    fits_xml, ffprobe_xml = self.content.extract_metadata
    self.characterization.ng_xml = fits_xml
    fix_mxf_characterization!
    self.ffprobe.ng_xml = ffprobe_xml if ffprobe_xml
    self.append_metadata
    self.filename = self.label
    save unless self.new_object?
  end

  # Override so that we use the creator= method (which makes a Person node) and don't
  # just append to the RDF node.
  def append_metadata
    terms = self.characterization_terms
    Sufia.config.fits_to_desc_mapping.each_pair do |k, v|
      self.send("#{v}=", terms[k]) if terms.has_key?(k)
    end
  end


  # The present version of fits.sh (0.6.1) doesn't set a mime-type for MXF files
  # this method rectifies that until a fixed version of fits.sh is released.
  def fix_mxf_characterization!
    self.characterization.mime_type = 'application/mxf' if mime_type == 'application/octet-stream' && format_label == ["Material Exchange Format"]
  end

  ### Map  location[].locationName -> based_near[]
  def based_near
    descMetadata.has_location #.map(&:location_name).flatten
  end


  # Necessary because parts of sufia call creator= with a string.
  ### Map creator[] -> creator[].name
  # @param [Array,String] creator_properties a list of hashes with role and name or just names
  def creator=(args)
    unless args.is_a?(String) || args.is_a?(Array)
      raise ArgumentError, "You must provide a string or an array.  You provided #{args.inspect}"
    end
    args = Array(args)
    if args.first.is_a?(String)
      return if args == [''] 
      args.each do |creator_name|
        self.creator_attributes = [{name: creator_name, role: "Uploader"}]
      end
    else
      descMetadata.creator = args
    end
  end

  # Necessary because parts of sufia call title= with a string.
  ### Map title[] -> title[].value
  # @param [Array,String] title_properties a list of hashes with type and value
  def title=(args)
    unless args.is_a?(String) || args.is_a?(Array)
      raise ArgumentError, "You must provide a string or an array.  You provided #{args.inspect}"
    end
    args = Array(args)
    if args.first.is_a?(String)
      return if args == [''] 
      args.each do |title_name|
        self.title_attributes = [{value: title_name, title_type: "Program"}]
      end
    else
      descMetadata.title=args
    end
  end

  # normally if you want to remove exising nested params you pass:
  #   {:_delete => true, :id => '_:g1231011230128'}
  # since the editor doesn't know about that, we just delete
  # all nested objects if they will be replaced.
  def destroy_existing_nested_nodes(params)
    self.creator.each { |c| c.destroy } if params[:creator_attributes]
    self.contributor.each { |c| c.destroy } if params[:contributor_attributes]
    self.producer.each { |c| c.destroy } if params[:producer_attributes]
    self.publisher.each { |c| c.destroy } if params[:publisher_attributes]
    self.title.each { |c| c.destroy } if params[:title_attributes]
    self.event.each { |c| c.destroy } if params[:event_attributes]
    self.description.each { |c| c.destroy } if params[:description_attributes]
  end

  def to_s
    val = [program_title.first, series_title.first].compact.join(' | ')
    val.empty? ? label : val 
  end

end
