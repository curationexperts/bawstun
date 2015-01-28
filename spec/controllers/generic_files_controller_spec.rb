require 'spec_helper'

describe GenericFilesController, type: :controller do
  before do
    @user = FactoryGirl.create(:user)
    sign_in @user
    @routes = Sufia::Engine.routes
  end
  describe "#show" do
    before do
      @file = GenericFile.new(title_attributes: [value: 'The title', title_type: 'Program'])
      @file.apply_depositor_metadata(@user.user_key)
      @file.save!
    end
    it "should log views" do
      @file.views.size.should == 0
      get :show, id: @file
      response.should be_successful
      @file.views.size.should == 1
    end

    it "should show xml" do
      get :show, id: @file, format: 'xml'
      response.should be_successful
      Nokogiri::XML(response.body).xpath('/pbcoreDescriptionDocument/pbcoreTitle').text.should == 'The title'
    end
  end

  describe "#create" do
    before do
      GenericFile.delete_all
      @mock_upload_directory = 'spec/mock_upload_directory'
      Dir.mkdir @mock_upload_directory unless File.exists? @mock_upload_directory
      FileUtils.copy('spec/fixtures/world.png', @mock_upload_directory)
      FileUtils.copy('spec/fixtures/sheepb.jpg', @mock_upload_directory)
      FileUtils.cp_r('spec/fixtures/import', @mock_upload_directory)
      @user.update_attribute(:directory, @mock_upload_directory)
    end
    after do
      FileContentDatastream.any_instance.stub(:live?).and_return(true)
      GenericFile.destroy_all
    end
    it "should ingest files from the filesystem" do
      #TODO this test is very slow because it kicks off CharacterizeJob.
      
      # s1 = stub()
      # s2 = stub()
      # CharacterizeJob.should_receive(:new).and_return(s1, s2)
      # Sufia.queue.should_receive(:push).with(s1)
      # Sufia.queue.should_receive(:push).with(s2)

      lambda { post :create, local_file: ["world.png", "sheepb.jpg"], batch_id: "xw42n7934"}.should change(GenericFile, :count).by(2)
      response.should redirect_to Sufia::Engine.routes.url_helpers.batch_edit_path('xw42n7934')
      # These files should have been moved out of the upload directory
      File.exist?("#{@mock_upload_directory}/sheepb.jpg").should be_false
      File.exist?("#{@mock_upload_directory}/world.png").should be_false
      # And into the storage directory
      files = GenericFile.find(Solrizer.solr_name("is_part_of",:symbol) => 'info:fedora/sufia:xw42n7934')
      files.each do |gf|
        File.exist?(gf.content.filename).should be_true
        gf.thumbnail.mimeType.should == 'image/png'
      end
      files.first.label.should == 'world.png'
      files.first.unarranged.should == false
      files.last.label.should == 'sheepb.jpg'
    end
    it "should ingest directories from the filesystem" do
      #TODO this test is very slow because it kicks off CharacterizeJob.
      lambda { post :create, local_file: ["world.png", "import"], batch_id: "xw42n7934"}.should change(GenericFile, :count).by(4)
      response.should redirect_to Sufia::Engine.routes.url_helpers.batch_edit_path('xw42n7934')
      # These files should have been moved out of the upload directory
      File.exist?("#{@mock_upload_directory}/import/manifests/manifest-broadway-or-bust.txt").should be_false
      File.exist?("#{@mock_upload_directory}/import/manifests/manifest-nova-smartest-machine-1.txt").should be_false
      File.exist?("#{@mock_upload_directory}/import/metadata/broadway_or_bust.pbcore.xml").should be_false
      File.exist?("#{@mock_upload_directory}/world.png").should be_false
      # And into the storage directory
      files = GenericFile.find(Solrizer.solr_name("is_part_of",:symbol) => 'info:fedora/sufia:xw42n7934')
      files.each do |gf|
        File.exist?(gf.content.filename).should be_true
      end
      files.first.label.should == 'world.png'
      files.first.unarranged.should be_true
      files.first.thumbnail.mimeType.should == 'image/png'
      files.last.relative_path.should == 'import/metadata/broadway_or_bust.pbcore.xml'
      files.last.unarranged.should be_true
      files.last.label.should == 'broadway_or_bust.pbcore.xml'
    end
    it "should ingest uploaded files"
  end

  describe "#edit" do
    before do
      @file = GenericFile.new.tap do |f|
        f.apply_depositor_metadata(@user.user_key)
        f.creator = "Samantha"
        f.title = "A good day"
        f.save!
      end
    end
    it "should be successful" do
      get :edit, id: @file
      response.should be_successful
    end
  end


  describe "#update" do
    before do
      @file = GenericFile.new
      @file.apply_depositor_metadata(@user.user_key)
      @file.creator = "Samantha"
      @file.title = "A good day"
      @file.save!
    end
    it "should update the creator and location" do
      #TODO we can't just do: @file.descMetadata.creator = [], because that will leave an orphan person
      # this works: @file.descMetadata.creator.each { |c| c.destroy }
      post :update, id: @file, generic_file: {
           title_attributes: {'0' => {"value" => "Frontline", "title_type"=>"Series"}, '1' => {"value"=>"How did this happen?", "title_type"=>"Program"}},
           creator_attributes: {'0' => {"name" => "Frank", "role"=>"Producer"}, '1' => {"name"=>"Dave", "role"=>"Director"}},
           description_attributes: {'0' => {"value"=> "it's a documentary show", "type" => 'summary'}},
           subject: ['Racecars'],
           'event_location' => ['france', 'portugual'],
           'production_location' => ['Boston', 'Minneapolis'],
           date_portrayed: ['12/24/1913'],
           language: ['french', 'english'],
           resource_type: ["Article", "Audio", "Book"],
           source: ['Some shady looking character'],
           source_reference: ['Less shady guy'],
           rights_holder: ['WGBH', 'WNYC'],
           rights_summary: ["Don't copy me bro"],
           release_date: ['12/15/2012'],
           review_date: ['1/18/2013'],
           aspect_ratio: ['4:3'],
           frame_rate: ['25'],
           cc: ['English', 'French'], 
           physical_location: ['Down in the vault'], 
           identifier_attributes: {'0' =>{"value" => "123-456789", "identifier_type"=>"NOLA_CODE"},
                                   '1' =>{"value" => "777", "identifier_type"=>"ITEM_IDENTIFIER"},
                                   '2' =>{"value" => "929343", "identifier_type"=>"PO_REFERENCE"}},
           metadata_filename: ['a_movie.mov'],
           notes: ['foo bar'],
           originating_department: ['Accounts receivable']
          }
      response.should redirect_to(Sufia::Engine.routes.url_helpers.edit_generic_file_path(@file))
      @file.reload
      @file.title[0].title_type.should == ['Series']
      @file.title[0].value.should == ['Frontline']
      @file.title[1].value.should == ['How did this happen?']
      @file.title[1].title_type.should == ['Program']
      @file.subject.should == ["Racecars"]
      @file.description[0].value.should == ["it's a documentary show"]
      @file.description[0].type.should == ['summary']
      @file.event_location.should == ['france', 'portugual']
      @file.production_location.should == ['Boston', 'Minneapolis']
      @file.date_portrayed.should == ['12/24/1913']
      @file.language.should == ['french', 'english']
      @file.resource_type.should == [ "Article", "Audio", "Book"]      
      @file.source.should == ['Some shady looking character']
      @file.source_reference.should == ['Less shady guy']
      @file.rights_holder.should == [ "WGBH", 'WNYC']      
      @file.rights_summary.should == ["Don't copy me bro"]
      @file.creator[0].name.should == ['Frank']
      @file.creator[0].role.should == ['Producer']
      @file.creator[1].name.should == ['Dave']
      @file.creator[1].role.should == ['Director']
      @file.release_date.should == ['12/15/2012']
      @file.review_date.should == ['1/18/2013']
      @file.aspect_ratio.should == ['4:3']
      @file.frame_rate.should == ['25']
      @file.cc.should == ['English', 'French']
      @file.physical_location.should == ['Down in the vault']
      @file.nola_code.should == ['123-456789']
      @file.tape_id.should == ['777']
      @file.barcode.should == ['929343']
      @file.metadata_filename.should == ['a_movie.mov']
      @file.notes.should == ['foo bar']
      @file.originating_department = ['Accounts receivable']
    end

    it "should remove blank assertions" do
      post :update, id: @file, generic_file: {
        "publisher_attributes"=>{"0"=>{"name"=>"", "role"=>""}, "1"=>{"name"=>"Test", "role"=>""},
                                 "2"=>{"name"=>"", "role"=>"Foo"}, "3"=>{"name"=>"", "role"=>""}},
        "description_attributes"=>{"0"=>{"value"=>"", "type"=>""}, "1"=>{"value"=>"Justin's desc", "type"=>""}, 
                                   "2"=>{"value"=>"", "type"=>"valuable"}},
        'event_location' => ['', 'Brazil'],
        'production_location' => ['', 'Cuba']
      }
      response.should redirect_to(Sufia::Engine.routes.url_helpers.edit_generic_file_path(@file))
      @file.reload
      @file.publisher.size.should == 2
      @file.publisher[0].name.should == ['Test']
      @file.publisher[1].role.should == ['Foo']
      @file.description.size.should == 2
      @file.description[0].value.should == ["Justin's desc"]
      @file.description[1].type.should == ['valuable']
      @file.event_location.should == ['Brazil']
      @file.production_location.should == ['Cuba']


    end
  end
end
