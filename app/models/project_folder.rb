#==
# RailsCollab
# Copyright (C) 2007 - 2008 James S Urquhart
# Portions Copyright (C) René Scheibe
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

class ProjectFolder < ActiveRecord::Base
  include ActionController::UrlWriter

  belongs_to :project

  has_many :project_files, :foreign_key => 'folder_id'

  after_create  :process_create
  before_update :process_update_params
  before_destroy :process_destroy

  def process_create
    ApplicationLog.new_log(self, @created_by, :add, false) unless @created_by.nil?
  end

  def process_update_params
    ApplicationLog.new_log(self, @updated_by, :edit, false) unless @updated_by.nil?
  end

  def process_destroy
    ApplicationLog.new_log(self, @updated_by, :delete, false) unless @updated_by.nil?
  end
  
  def created_by=(user)
    @created_by = user
  end
  
  def updated_by=(user)
    @updated_by = user
  end

  def object_name
    self.name
  end

  def object_url
    url_for :only_path => true, :controller => 'folders', :action => 'files', :id => self.id, :active_project => self.project_id
  end

  # Core Permissions

  def self.can_be_created_by(user, project)
    project.is_active? and user.has_permission(project, :can_manage_files)
  end

  def can_be_edited_by(user)
    project.is_active? and user.has_permission(project, :can_manage_files)
  end

  def can_be_deleted_by(user)
    project.is_active? and user.has_permission(project, :can_manage_files)
  end

  def can_be_seen_by(user)
    project.has_member(user)
  end

  # Specific Permissions

  def can_be_managed_by(user)
    project.is_active? and user.has_permission(project, :can_manage_files)
  end

  # Helpers

  def self.select_list(project)
    [['None', 0]] + ProjectFolder.all(:conditions => ['project_id = ?', project.id], :select => 'id, name').collect do |folder|
      [folder.name, folder.id]
    end
  end

  # Accesibility

  attr_accessible :name

  # Validation

  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :project_id
end
