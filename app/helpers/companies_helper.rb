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

module CompaniesHelper
  def page_title
    case action_name
      when 'show' then :company_card.l_with_args(:company => @company.name)
      else super
    end
  end

  def current_tab
    :people
  end

  def current_crumb
    case action_name
      when 'new', 'create' then :add_client
      when 'show' then @company.name
      when 'edit', 'update' then @company.is_owner? ? :edit_company : :edit_client
      else super
    end
  end

  def extra_crumbs
    crumbs = [{:title => :people, :url => '/administration/people'}]
    crumbs << {:title => @company.name, :url => company_path(:id => @company.id)} if action_name == 'permissions'
    crumbs
  end
end
