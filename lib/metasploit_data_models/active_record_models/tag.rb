module MetasploitDataModels::ActiveRecordModels::Tag
  def self.included(base)
    base.class_eval {
      include Msf::DBManager::DBSave

      has_and_belongs_to_many :hosts, :join_table => :hosts_tags, :class_name => "Mdm::Host"
      belongs_to :user, :class_name => "Mdm::User"

      validates :name, :presence => true, :format => {
          :with => /^[A-Za-z0-9\x2e\x2d_]+$/, :message => "name must be alphanumeric, dots, dashes, or underscores"
      }
      validates :desc, :length => {:maximum => 8191, :message => "desc must be less than 8k."}

      def to_s
        name
      end
    }
  end
end
