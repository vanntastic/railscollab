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

module MessagesHelper
  def page_title
    case action_name
      when 'category' then :category_messages.l_with_args(:category => @category.name)
      else super
    end
  end

  def current_tab
    :messages
  end

  def current_crumb
    case action_name
      when 'index' then :messages
      when 'new', 'create' then :add_message
      when 'edit', 'update' then :edit_message
      when 'show' then @message.title
      else super
    end
  end

  def extra_crumbs
    crumbs = []
    crumbs << {:title => :messages, :url => messages_path} unless action_name == 'index'
    crumbs << {:title => @message.project_message_category.name, :url => posts_category_path(:id => @message.category_id)} if action_name == 'show'
    crumbs
  end

  def page_actions
    @page_actions = []
    
    if ProjectMessage.can_be_created_by(@logged_user, @active_project)
      @page_actions << {:title => :add_message, :url => (@category.nil? ? 
    	  								  new_message_path : new_message_path(:category_id => @category.id))} if action_name == 'index'
    end
    
    @page_actions
  end

  def additional_stylesheets
    ['project/messages']
  end
end
