require 'spec_helper'

describe Mdm::Module::Ancestor do
  subject(:ancestor) do
    FactoryGirl.build(:mdm_module_ancestor)
  end

  it_should_behave_like 'Metasploit::Model::Module::Ancestor' do
    def attribute_type(attribute)
      column = ancestor_class.columns_hash.fetch(attribute.to_s)

      column.type
    end

    let(:ancestor_class) do
      described_class
    end

    let(:ancestor_factory) do
      :mdm_module_ancestor
    end

    let(:path_factory) do
      :mdm_module_path
    end
  end

  context 'associations' do
    it { should have_many(:descendants).class_name('Mdm::Module::Class').through(:relationships) }
    it { should belong_to(:parent_path).class_name('Mdm::Module::Path') }
    it { should have_many(:relationships).class_name('Mdm::Module::Relationship').dependent(:destroy) }
  end

  context 'database' do
    context 'columns' do
      it { should have_db_column(:full_name).of_type(:text).with_options(:null => false) }
      it { should have_db_column(:handler_type).of_type(:string).with_options(:null => true) }
      it { should have_db_column(:module_type).of_type(:string).with_options(:null => false) }
      it { should have_db_column(:real_path).of_type(:text).with_options(:null => false) }
      it { should have_db_column(:real_path_modified_at).of_type(:datetime).with_options(:null => false) }
      it { should have_db_column(:real_path_sha1_hex_digest).of_type(:string).with_options(:limit => 40, :null => false) }
      it { should have_db_column(:reference_name).of_type(:text).with_options(:null => false) }
    end

    context 'indices' do
      context 'foreign key' do
        it { should have_db_index(:parent_path_id) }
      end

      context 'unique' do
        subject(:ancestor) do
          described_class.new
        end

        it 'should have unique index on full_name to represent that Msf::ModuleManager only allows one module with a given full_name' do
          ancestor.should have_db_index(:full_name).unique(true)
        end

        it 'should have unique index on (module_type, reference_name) to present that Msf::ModuleSet and Msf::PayloadSet only allow one module with a given reference_name' do
          ancestor.should have_db_index([:module_type, :reference_name]).unique(true)
        end

        it 'should have unique index on real_path because only one file can have a given path' do
          ancestor.should have_db_index(:real_path).unique(true)
        end

        it 'should have unique index on real_path_sha1_hex_digest so renames can be detected' do
          ancestor.should have_db_index(:real_path_sha1_hex_digest).unique(true)
        end
      end
    end
  end

  context 'factories' do
    context 'mdm_module_ancestor' do
      subject(:mdm_module_ancestor) do
        FactoryGirl.build(:mdm_module_ancestor)
      end

      it { should be_valid }
    end

    context 'payload_mdm_module_ancestor' do
      subject(:payload_mdm_module_ancestor) do
        FactoryGirl.build(:payload_mdm_module_ancestor)
      end

      it { should be_valid }

      its(:module_type) { should == 'payload' }
      its(:derived_payload_type) { should_not be_nil }
    end

    context 'single_payload_mdm_module_ancestor' do
      subject(:single_payload_mdm_module_ancestor) do
        FactoryGirl.build(:single_payload_mdm_module_ancestor)
      end

      it { should be_valid }

      its(:module_type) { should == 'payload' }
      its(:derived_payload_type) { should == 'single' }
    end

    context 'stage_payload_mdm_module_ancestor' do
      subject(:stage_payload_mdm_module_ancestor) do
        FactoryGirl.build(:stage_payload_mdm_module_ancestor)
      end

      it { should be_valid }

      its(:module_type) { should == 'payload' }
      its(:derived_payload_type) { should == 'stage' }
    end

    context 'stager_payload_mdm_module_ancestor' do
      subject(:stager_payload_mdm_module_ancestor) do
        FactoryGirl.build(:stager_payload_mdm_module_ancestor)
      end

      it { should be_valid }

      its(:module_type) { should == 'payload' }
      its(:derived_payload_type) { should == 'stager' }
    end
  end

  context 'validations' do
    context 'full_name' do
      # can't use validate_uniqueness_of(:full_name) because of null value in module_type
      context 'validates uniqueness' do
        let!(:original_ancestor) do
          FactoryGirl.create(:mdm_module_ancestor)
        end

        context 'with same full_name' do
          let(:same_full_name_ancestor) do
            FactoryGirl.build(
                :mdm_module_ancestor,
                # set module_type and reference_name as full_name is derived from them
                :module_type => original_ancestor.module_type,
                :reference_name => original_ancestor.reference_name
            )
          end

          it 'should record error on full_name' do
            same_full_name_ancestor.should_not be_valid
            same_full_name_ancestor.errors[:full_name].should include('has already been taken')
          end
        end
      end
    end

    context 'real_path' do
      # can't use validate_uniqueness_of(:real_path) because of null full_name
      context 'validate uniqueness' do
        let!(:original_ancestor) do
          FactoryGirl.create(:mdm_module_ancestor)
        end

        context 'with same real_path' do
          let(:same_real_path_ancestor) do
            FactoryGirl.build(
                :mdm_module_ancestor,
                # real_path is derived from parent_path, module_type, and reference_name, so set copy those attributes
                # to get the same real_path.
                :module_type => original_ancestor.module_type,
                :parent_path => original_ancestor.parent_path,
            ).tap do |ancestor|
              # At least one attribute needs to be set outside the call to build because the factory will attempt to
              # created the derived_real_path and throw a Metasploit::Model::Spec::PathnameCollision.
              ancestor.reference_name = original_ancestor.reference_name
            end
          end

          it 'should record error on real_path' do
            same_real_path_ancestor.should_not be_valid
            same_real_path_ancestor.errors[:real_path].should include('has already been taken')
          end
        end
      end
    end

    context 'real_path_sha1_hex_digest' do
      context 'validates uniqueness' do
        let!(:original_ancestor) do
          FactoryGirl.create(:mdm_module_ancestor)
        end

        context 'with same real_path_sha1_hex_digest' do
          let(:same_real_path_sha1_hex_digest_ancestor) do
            FactoryGirl.build(
                :mdm_module_ancestor,
                # real_path_sha1_hex_digest is derived, but not validated (as it would take too long)
                # so it can just be set directly
                :real_path_sha1_hex_digest => original_ancestor.real_path_sha1_hex_digest
            )
          end

          it 'should record error on real_path_sha1_hex_digest' do
            same_real_path_sha1_hex_digest_ancestor.should_not be_valid
            same_real_path_sha1_hex_digest_ancestor.errors[:real_path_sha1_hex_digest].should include('has already been taken')
          end
        end
      end
    end

    context 'reference_name' do
      context 'validates uniqueness scoped to module_type' do
        let(:new_ancestor) do
          FactoryGirl.build(
              :mdm_module_ancestor,
              :module_type => new_module_type,
              :reference_name => new_reference_name
          )
        end

        let(:original_module_type) do
          # don't use payload so sequence can be used to generate reference_name
          FactoryGirl.generate :metasploit_model_non_payload_module_type
        end

        let(:original_reference_name) do
          FactoryGirl.generate :metasploit_model_module_ancestor_non_payload_reference_name
        end

        let!(:original_ancestor) do
          FactoryGirl.create(
              :mdm_module_ancestor,
              :module_type => original_module_type,
              :reference_name => original_reference_name
          )
        end

        context 'with same module_type' do
          let(:new_module_type) do
            original_module_type
          end

          context 'with same reference_name' do
            let(:new_reference_name) do
              original_reference_name
            end

            it 'should record error on reference_name' do
              new_ancestor.should_not be_valid
              new_ancestor.errors[:reference_name].should include(I18n.translate!('activerecord.errors.messages.taken'))
            end
          end
        end

        context 'without same module_type' do
          let(:new_module_type) do
            # don't use payload so sequence can be used to generate reference_name
            FactoryGirl.generate :metasploit_model_non_payload_module_type
          end

          context 'with same reference_name' do
            let(:new_reference_name) do
              original_reference_name
            end

            it 'should not record error on reference_name' do
              new_ancestor.valid?

              new_ancestor.errors[:reference_name].should be_empty
            end
          end
        end
      end
    end
  end
end