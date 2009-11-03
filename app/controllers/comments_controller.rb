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

class CommentsController < ApplicationController

  layout 'project_website'

  before_filter :process_session
  before_filter :obtain_comment, :except => [:index, :new, :create]
  after_filter  :user_track, :only => [:index, :show]
  
  COMMENT_ROUTE_MAP = {
    :message_id => :ProjectMessage,
    :milestone_id => :ProjectMilestone,
    :file_id => :ProjectFile,
    :task_id => :ProjectTask,
    :task_list_id => :ProjectTaskList
  }
  
  # GET /comments
  # GET /comments.xml
  def index
    # Grab related object class + id
    object_class, object_id = find_comment_object
    if object_class.nil?
      error_status(true, :invalid_request)
      redirect_back_or_default :controller => 'dashboard', :action => 'index'
      return
    end
    
    # Find object
    @commented_object = object_class.find(object_id)
    return error_status(true, :invalid_object) if @commented_object.nil?
    
    # Check permissions
    return error_status(true, :insufficient_permissions) unless (@commented_object.can_be_seen_by(@logged_user))
    
    @comments = @logged_user.member_of_owner? ? @commented_object.comments : @commented_object.comments.public
    
    respond_to do |format|
      format.html {}
      format.xml { render :xml => @comments.to_xml(:root => 'comments', 
                                                   :only => [:id,
                                                             :text,
                                                             :author_name, 
                                                             :created_by_id, 
                                                             :created_on, 
                                                             :is_anonymous, 
                                                             :is_private,
                                                             :attached_files_count]) }
    end
  end

  # GET /comments/1
  # GET /comments/1.xml
  def show
    return error_status(true, :insufficient_permissions) unless (@comment.comment_can_be_seen_by(@logged_user))
    
    respond_to do |format|
      format.html {}
      format.xml {
        fields = @logged_user.is_admin? ? [] : [:author_email, :author_homepage]
        render :xml => @comment.to_xml(:root => 'comment', :except => fields) 
      }
    end
  end

  # GET /comments/new
  # GET /comments/new.xml
  def new
    # Grab related object class + id
    object_class, object_id = find_comment_object
    if object_class.nil?
      error_status(true, :invalid_request)
      redirect_back_or_default :controller => 'dashboard', :action => 'index'
      return
    end
    
    # Find object
    @commented_object = object_class.find(object_id)
    return error_status(true, :invalid_object) if @commented_object.nil?
    
    # Check permissions
    return error_status(true, :insufficient_permissions) unless (@commented_object.comment_can_be_added_by(@logged_user))

    unless @commented_object.comment_can_be_added_by(@logged_user)
      error_status(true, :insufficient_permissions)
      redirect_back_or_default @commented_object.object_url
      return
    end

    @comment = Comment.new()
    @comment.rel_object = @commented_object
    
    respond_to do |format|
      format.html {
        @active_project = @commented_object.project
        @active_projects = @logged_user.active_projects
      }
      format.xml  { render :xml => @comment.to_xml(:root => 'comment') }
    end
  end

  # GET /comments/1/edit
  def edit
    return error_status(true, :insufficient_permissions) unless @comment.can_be_edited_by(@logged_user)
    
    @commented_object = @comment.rel_object
	  @active_project = @commented_object.project
  end

  # POST /comments
  # POST /comments.xml
  def create
    # Grab related object class + id
    object_class, object_id = find_comment_object
    if object_class.nil?
      error_status(true, :invalid_request)
      redirect_back_or_default :controller => 'dashboard', :action => 'index'
      return
    end
    
    # Find object
    @commented_object = object_class.find(object_id)
    return error_status(true, :invalid_object) if @commented_object.nil?
    
    # Check permissions
    return error_status(true, :insufficient_permissions) unless (@commented_object.comment_can_be_added_by(@logged_user))

    unless @commented_object.comment_can_be_added_by(@logged_user)
      error_status(true, :insufficient_permissions)
      redirect_back_or_default @commented_object.object_url
      return
    end

    @comment = Comment.new()
    @comment.rel_object = @commented_object
    
    saved = false
    estatus = :success_added_comment
    
    Comment.transaction do
      comment_attribs = params[:comment]

      @comment.attributes = comment_attribs
      @comment.rel_object = @commented_object
      @comment.created_by = @logged_user
      @comment.author_homepage = request.remote_ip
      
      saved = @comment.save
      
      if saved
        # Notify everyone
        @commented_object.send_comment_notifications(@comment)

        # Subscribe if ProjectMessage
        @commented_object.ensure_subscribed(@logged_user) if @commented_object.class == ProjectMessage

        if (!params[:uploaded_files].nil? and ProjectFile.handle_files(params[:uploaded_files], @comment, @logged_user, @comment.is_private) != params[:uploaded_files].length)
          estatus = :success_added_comment_error_files
        end
      end
    end
    
    respond_to do |format|
      if saved
        format.html {
          error_status(false, estatus)
          redirect_back_or_default(@comment.object_url)
        }
        format.js {}
        format.xml  { render :xml => @comment.to_xml(:root => 'comment'), :status => :created, :location => @comment.object_url }
      else
        format.html { render :action => "new" }
        format.js {}
        format.xml  { render :xml => @comment.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /comments/1
  # PUT /comments/1.xml
  def update
    return error_status(true, :insufficient_permissions) unless (@comment.can_be_edited_by(@logged_user))

    @commented_object = @comment.rel_object
  	@active_project = @commented_object.project

  	saved = false
  	estatus = :success_edited_comment

    Comment.transaction do
      comment_attribs = params[:comment]

      @comment.attributes = comment_attribs
      @comment.updated_by = @logged_user
      
      saved = @comment.save
      estatus
      if saved
        if (!params[:uploaded_files].nil? and ProjectFile.handle_files(params[:uploaded_files], @comment, @logged_user, @comment.is_private) != params[:uploaded_files].length)
          estatus = :success_edited_comment_error_files
        end
      end
    end

    respond_to do |format|
      if saved
        format.html {
          error_status(false, estatus)
          redirect_back_or_default(@commented_object.object_url)
        }
        format.js {}
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.js {}
        format.xml  { render :xml => @comment.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /comments/1
  # DELETE /comments/1.xml
  def destroy
    return error_status(true, :insufficient_permissions) unless (@comment.can_be_deleted_by(@logged_user))
    
    @comment.updated_by = @logged_user
    @comment.destroy
    
    respond_to do |format|
      format.html {
        error_status(false, :success_deleted_comment)
        redirect_back_or_default(project_path(:id => @active_project.id))
      }
      format.js {}
      format.xml  { head :ok }
    end
  end

private

  def find_comment_object
    COMMENT_ROUTE_MAP.keys.each do |key|
      value = params[key]
      if !value.nil?
        return Kernel.const_get(COMMENT_ROUTE_MAP[key]) || nil, params[key].to_i
      end
    end
    
    return nil, nil
  end
  
  def obtain_comment
    @active_projects = @logged_user.active_projects

    begin
      @comment = Comment.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      error_status(true, :invalid_comment)
      redirect_back_or_default project_path(:id => @active_project.id)
      return false
    end

    true
  end

end
