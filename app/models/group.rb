class Group < ActiveRecord::Base
 
    has_many :memberships, :dependent => :destroy
    has_many :users, :through => :memberships
    belongs_to :space
    
    validates_presence_of :name
    
    def validate
      for user in users
        unless user.stages.include?(space)
          errors.add(:users, "not belongs to the space of the group")
        end
      end
      
    end
    
    after_create { |group| 
      if group.reload_mail_list_server_because_of_environment
      request_update_at_jungla
        group.mail_list_archive
        `scp #{ group.temp_file } vcc@jungla.dit.upm.es:/users/jungla/vcc/listas/automaticas/vcc-#{ group.email_group_name}`
        #`cp #{ group.temp_file } /home/ivanrojo/Escritorio/listas/automaticas/vcc-#{ group.email_group_name}`
      end
    }
    
    after_destroy { |group|
      if group.reload_mail_list_server_because_of_environment
        request_update_at_jungla
        `ssh vcc@jungla.dit.upm.es rm /users/jungla/vcc/listas/automaticas/vcc-#{ group.email_group_name }`
        #`rm /home/ivanrojo/Escritorio/listas/automaticas/vcc-#{ group.email_group_name }`
      end
    }
    
    before_update { |group|
      if group.reload_mail_list_server_because_of_environment
        `ssh vcc@jungla.dit.upm.es rm /users/jungla/vcc/listas/automaticas/vcc-#{ group.email_group_name }`
        #`rm /home/ivanrojo/Escritorio/listas/automaticas/vcc-#{ group.email_group_name }`
      end 
    }
    
    after_update { |group|
      if group.reload_mail_list_server_because_of_environment
        request_update_at_jungla
        group.mail_list_archive
        `scp #{ group.temp_file } vcc@jungla.dit.upm.es:/users/jungla/vcc/listas/automaticas/vcc-#{ group.email_group_name}`
      #`cp #{ group.temp_file } /home/ivanrojo/Escritorio/listas/automaticas/vcc-#{ group.email_group_name}`
      end
    }
       
    # Do not reload mail list server if not in production mode, it could cause server overload
    def reload_mail_list_server_because_of_environment
      RAILS_ENV == "production"
    end
    
    def self.request_update_at_jungla
      `ssh vcc@jungla.dit.upm.es touch /users/jungla/vcc/listas/automaticas/vcc-ACTUALIZAR`
    end
    
    # Transforms the list of users in the group into a string for the mail list server
    def mail_list
       str =""
       self.users.each do |person|
       str << "#{person.login}  <#{person.email}> \n"
       end
       str
   end
   
   def mail_list_archive
     doc = "#{self.mail_list}"
     File.open(temp_file, 'w') {|f| f.write(doc) }
   end
   
   def email_group_name
     self.name.gsub(/ /, "_")
   end

   def self.atom_parser(data)
    
    e = Atom::Entry.parse(data)


    group = {}
    group[:name] = e.title.to_s
    
    group[:user_ids] = []

    e.get_elems(e.to_xml, "http://sir.dit.upm.es/schema", "entryLink").each do |times|

      user = User.find_by_login(times.attribute('login').to_s)
      group[:user_ids] << user.id      
    end
    
    resultado = {}
    
    resultado[:group] = group
    
    return resultado     
  end   


  def temp_file
     @temp_file ||= "/tmp/sir-grupostemp-#{ rand }"
  end

end
