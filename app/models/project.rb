#==
# RailsCollab
# Copyright (C) 2007 - 2009 James S Urquhart
# Portions Copyright (C) René Scheibe
# Portions Copyright (C) Ariejan de Vroom
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#++

class Project < ActiveRecord::Base
	include ActionController::UrlWriter
	
	belongs_to :completed_by, :class_name => 'User', :foreign_key => 'completed_by_id'
	belongs_to :created_by, :class_name => 'User', :foreign_key => 'created_by_id'
	belongs_to :updated_by, :class_name => 'User', :foreign_key => 'updated_by_id'
	
	has_many :project_users
	has_many :users, :through=> :project_users
	
	has_many :project_times, :dependent => :destroy do
		def public(reload=false)
			# Grab public logs only
			@public_project_times = nil if reload
			@public_project_times ||= find(:all, :conditions => ['is_private = ?', false])
		end
    end
	has_many :tags, :as => :rel_object # Dependent objects sould destroy all of these for us
	
	has_many :project_milestones, :dependent => :destroy do
		def public(reload=false)
			# Grab public logs only
			@public_project_milestones = nil if reload
			@public_project_milestones ||= find(:all, :conditions => ['is_private = ?', false])
		end
	
		def open(include_private=true, reload=false)
			# Grab open milestones only
			ProjectMilestone.priv_scope(include_private) do
			  find(:all, :conditions => 'project_milestones.completed_on IS NULL', :order => 'project_milestones.due_date ASC')
			end
		end
		
		def late(include_private=true, reload=false)
			ProjectMilestone.priv_scope(include_private) do
			  find(:all, :conditions => ['due_date < ? AND completed_on IS NULL', Date.today])
			end
		end
		
		def todays(include_private=true, reload=false)
			ProjectMilestone.priv_scope(include_private) do
			  find(:all, :conditions => ['completed_on IS NULL AND (due_date >= ? AND due_date < ?)', Date.today, Date.today+1])
			end
		end
		
		def upcoming(include_private=true, reload=false)
			ProjectMilestone.priv_scope(include_private) do
			  find(:all, :conditions => ['completed_on IS NULL AND due_date >= ?', Date.today+1])
			end
		end
		
		def completed(include_private=true, reload=false)
			ProjectMilestone.priv_scope(include_private) do 
			  find(:all, :conditions => 'completed_on IS NOT NULL')
			end
		end
	end
	
	has_many :project_task_lists, :order => "#{self.connection.quote_column_name 'order'} DESC", :dependent => :destroy do
		def public(reload=false)
			# Grab public logs only
			@public_project_task_lists = nil if reload
			@public_project_task_lists ||= find(:all, :conditions => ['is_private = ?', false])
		end
		
		def open(include_private = true, reload=false)
			ProjectTaskList.priv_scope(include_private) do
			  # Grab open task lists only
			  find(:all, :conditions => 'project_task_lists.completed_on IS NULL')
			end
		end
		
		def completed(include_private = true, reload=false)
			ProjectTaskList.priv_scope(include_private) do
			  # Grab completed task lists only
			  find(:all, :conditions => 'project_task_lists.completed_on IS NOT NULL')
			end
		end
	end
        has_many :project_tasks, :through => :project_task_lists
	
	has_many :project_folders, :dependent => :destroy
	has_many :project_files, :dependent => :destroy do
		def important(include_private = true, reload=false)
			ProjectFile.priv_scope(include_private) do
			  find(:all, :conditions => ['is_important = ?', true])
			end
		end
	end
  has_many :project_messages, :order => 'created_on DESC', :dependent => :destroy do
    def important(include_private = true, reload=false)
      ProjectMessage.priv_scope(include_private) do
        find(:all, :conditions => ['is_important = ?', true])
      end
    end
    
    def public(conditions={}, reload=false)
      @public_project_messages = nil if reload
      @public_project_messages ||= find(:all, :conditions => ['is_private = ?', false])
    end
  end
	has_many :project_message_categories, :dependent => :destroy
	
	has_many :application_logs, :order => 'created_on DESC, id DESC', :dependent => :destroy do
		def public(reload=false)
			# Grab public logs only
			@public_application_logs = nil if reload
			@public_application_logs ||= find(:all, :conditions => ['is_private = ?', false])
		end
	end
	
  has_many :wiki_pages, :dependent => :destroy
	
	has_and_belongs_to_many :companies, :join_table => :project_companies
	
	before_create  :process_params
	after_create   :process_create
	before_update  :process_update_params
	before_destroy :process_destroy
	 
	def process_params
	  write_attribute("completed_on", nil)
	end
	
	def process_create
	  ApplicationLog.new_log(self, self.created_by, :add, true)
	end
	
	def process_update_params
	  if @update_completed.nil?
		ApplicationLog::new_log(self, self.updated_by, :edit, true)
	  else
		write_attribute("completed_on", @update_completed ? Time.now.utc : nil)
		self.completed_by = @update_completed_user
		ApplicationLog::new_log(self, @update_completed_user, @update_completed ? :close : :open, true)
	  end
	end
	
	def process_destroy
	  ActiveRecord::Base.connection.execute("DELETE FROM project_users WHERE project_id = #{self.id}")
	  ApplicationLog.new_log(self, self.updated_by, :delete, true)
	end
	
	def object_name
		self.name
	end
	
	def object_url
		url_for hash_for_project_path(:only_path => true, :id => self.id)
	end
	
	def tasks_by_user(user, completed=false)
		self.project_tasks.all(:conditions => ["((assigned_to_company_id = ? OR assigned_to_user_id = ?) OR (assigned_to_company_id = 0 OR assigned_to_user_id = 0)) AND project_tasks.completed_on #{completed ? 'IS NOT' : 'IS'} NULL", user.company_id, user.id])
	end
	
	def is_active?
	    return self.completed_on == nil
	end
	
  def milestones_by_user(user, completed=false)
    ProjectMilestone.find(:all, :conditions => ["project_id = #{self.id} AND ((assigned_to_company_id = ? OR assigned_to_user_id = ?) OR (assigned_to_company_id = 0 OR assigned_to_user_id = 0)) AND completed_on #{completed ? 'IS NOT' : 'IS'} NULL", user.company_id, user.id])
  end

  def has_member(user)
    return ProjectUser.find(:first, :conditions => "project_id = #{self.id} AND user_id = #{user.id}", :select => 'user_id')
  end

  def set_completed(value, user=nil)
    @update_completed = value
    @update_completed_user = user
  end

  def search(query, is_private, options={}, tag_search=false)
    self.class.search(query, is_private, [self], options, tag_search)
  end

  def self.search_for_user(query, user, options={}, tag_search=false)
    self.search(query, !user.member_of_owner?, user.active_projects, options, tag_search)
  end

  def self.search(query, is_private, projects, options={}, tag_search=false)
    results = []
    return results, 0 unless AppConfig.search_enabled

    project_ids = projects.collect { |project| project.id }.join('|')
    real_query = if is_private
      "is_private:false project_id:\"#{project_ids}\" #{query}"
    else
      "project_id:\"#{project_ids}\" #{query}"
    end

    results = if tag_search
      Tag.find_with_ferret(real_query, options)
    else
      ActsAsFerret::find(real_query, :shared, options)
    end

    return results, results.total_hits
  end
	
	# Core Permissions
	
	def self.can_be_created_by(user)
	 return (user.member_of_owner? and user.is_admin)
	end
	
	def can_be_edited_by(user)
	 return (user.member_of_owner? and user.is_admin)
	end
	
	def can_be_deleted_by(user)
	 return (user.member_of_owner? and user.is_admin)
	end
	
	def can_be_seen_by(user)
	 return (self.has_member(user) or (user.member_of_owner? and user.is_admin))
	end
	
	# Specific Permissions
	
	def can_be_managed_by(user)
	 return (user.member_of_owner? and user.is_admin)
	end
	
	def company_can_be_removed_by(company, user)
	 return false if company.is_owner?
	 return (user.member_of_owner? and user.is_admin)
	end
	
	def user_can_be_removed_by(user_remove, user)
	 return false if user_remove.owner_of_owner?
	 return (user.member_of_owner? and user.is_admin)
	end
	
	def status_can_be_changed_by(user)
	 return self.can_be_edited_by(user)
	end
	
	# Helpers
	
	def self.select_list
	 Project.find(:all).collect do |project|
	   [project.name, project.id]
	 end
	end
	
	# Accesibility
	
	attr_accessible :name, :description, :priority, :show_description_in_overview
	
	# Validation
	
	validates_presence_of :name
end
