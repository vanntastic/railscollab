#==
# RailsCollab
# Copyright (C) 2007 - 2009 James S Urquhart
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

module FilesHelper
  def page_title
    case action_name
      when 'index' then @current_folder.nil? ? :files.l : :folder_name.l_with_args(:folder => @current_folder.name)
      when 'new', 'create' then :add_file.l
      when 'edit', 'update' then :edit_file.l
      else super
    end
  end

  def current_tab
    :files
  end

  def current_crumb
    case action_name
      when 'index' then :files
      when 'attach' then :attach_files
      when 'new', 'create' then :add_file
      when 'edit', 'update' then :edit_file
      when 'show' then @file.filename
      else super
    end
  end

  def extra_crumbs
    crumbs = []
    crumbs << {:title => :files, :url => "/project/#{@active_project.id}/files"} unless action_name == 'index'
    crumbs << {:title => @folder.name, :url => @folder.object_url} if !@folder.nil? and action_name == 'show'
    crumbs
  end

  def additional_stylesheets
    case action_name
      when 'attach' then ['project/attach_files']
      else ['project/files']
    end
  end
end
