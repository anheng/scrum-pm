class UserStoriesController < ApplicationController
  unloadable
  before_filter :find_project, 
    :authorize, :only => [:new, :create, :edit, :update, :destroy, :change_status, :update_user_story_status]
  helper :sprints

  # GET /user_stories/new
  # GET /user_stories/new.xml
  def new
    @user_story = UserStory.new
    @user_story.project_id = @project.id
    unless params[:sprint_id].nil?
      sprint = Version.find(params[:sprint_id])
      unless sprint.nil?
        @user_story.version_id = sprint.id
      end
    else

    end
    render :partial => "user_stories/new", :locals => {:user_story => @user_story, :target => params[:target]}
  end

  # GET /user_stories/1/edit
  def edit
    @user_story = UserStory.find(params[:id])
    render :partial => "user_stories/edit", :locals => {:user_story => @user_story, :target => params[:target]}
  end

  def change_status
    @user_story = UserStory.find(params[:id])
    render :partial => "user_stories/edit_us_status", :locals => {:user_story => @user_story, :target => params[:target]}
  end

  # POST /user_stories
  # POST /user_stories.xml
  def create
    @user_story = UserStory.new(params[:user_story])
    @user_story.project_id = @project.id
    last_us =UserStory.find(:first, :conditions => ["project_id = ?",@project.id], :order => "us_number DESC")
    @user_story.us_number = last_us.nil? ? 1 : last_us.us_number + 1
    if @user_story.save
      assignment = create_assignment(@user_story.id,@user_story.user_stories_status.id)
      if assignment.save
        @issue_statuses = IssueStatus.find(:all)
        render :update do |p|
          if @user_story.sprint.nil?
            unassigned_us = UserStory.find(:all, :conditions => ["version_id is null and project_id = ?", @project.id])
            p.replace "no_US_0", "" if UserStory.find(:all, :conditions => ["version_id is null and project_id = ?",@project.id], :order => "priority ASC").size == 1
            p.insert_html :bottom, 'sprint_0', :partial => "user_stories/backlog_item", :locals => {:user_story => @user_story, :count => unassigned_us.size + 1}
            p["tab_us_#{@user_story.id}"].visual_effect :highlight, :duration => 2
          else
            if params[:target].blank?
              p.insert_html :bottom, "sprint_#{@user_story.version_id}", :partial => "user_stories/sprint_item", :locals => {:user_story => @user_story, :count => @user_story.sprint.user_stories.size + 1}
              p["tab_us_#{@user_story.id}"].visual_effect :highlight, :duration => 2
              p["no_US_#{@user_story.version_id}"].visual_effect :blind_up, :duration => 1
            else
              if params[:target].eql? "show"
                p.insert_html :bottom, "dashboard_main_table", :partial => "user_stories/us_for_show", :locals => {:user_story => @user_story, :count => (@user_story.sprint.user_stories.count + 1)}
              end
            end
          end        
        end
      else
        respond_to do |format|
          format.html { render :action => "new" }
          format.xml  { render :xml => @user_story.errors, :status => :unprocessable_entity }
        end
      end
    else
      respond_to do |format|
        format.html { render :action => "new" }
        format.xml  { render :xml => @user_story.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /user_stories/1
  # PUT /user_stories/1.xml
  def update
    @user_story = UserStory.find(params[:id])
    if @user_story.update_attributes(params[:user_story])
      @issue_statuses = IssueStatus.find(:all)
      render :update do |p|
        unless @user_story.sprint.nil?
          if params[:target].blank?
            p.replace "tab_us_#{@user_story.id}", :partial => "user_stories/sprint_item", :locals => {:user_story => @user_story, :count => @user_story.sprint.user_stories.index(@user_story)}
          else
            if params[:target].eql? "show"
              p.replace "tab_us_#{@user_story.id}", :partial => "user_stories/us_for_show", :locals => {:user_story => @user_story, :count => @user_story.sprint.user_stories.index(@user_story)}              
            end
          end
        else
          unassigned_us = UserStory.find(:all, :conditions => ["version_id is null and project_id = ?", @project.id])
          p.replace "tab_us_#{@user_story.id}", :partial => "user_stories/backlog_item", :locals => {:user_story => @user_story, :count => unassigned_us.size + 1}
          p["tab_us_#{@user_story.id}"].visual_effect :highlight, :duration => 2
        end
      end
    else
      respond_to do |format|
        format.html { render :action => "edit" }
        format.xml  { render :xml => @user_story.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /user_stories/1
  # DELETE /user_stories/1.xml
  def destroy
    sprint_id = -1
    @user_story = UserStory.find(params[:id])
    user_story_id = @user_story.id
    unless @user_story.sprint.nil?
      sprint_id = @user_story.version_id if @user_story.sprint.user_stories.size == 1
    else
      unassigned_us = UserStory.find(:all, :conditions => ["version_id is null and project_id = ?", @project.id])
      if unassigned_us.size == 1
        sprint_id = 0
      end
    end
    @user_story.destroy
    @issue_statuses = IssueStatus.find(:all)
    render :update do |p|
      p["tab_us_#{user_story_id}"].visual_effect :blind_up, :duration => 1
      if sprint_id != -1
        p.insert_html :bottom, "sprint_"+sprint_id.to_s, "<tr id=\"no_US_#{sprint_id.to_s}\"><td colspan=\"5\" class=\"no_US\">#{l('drag_user_story_here_to_assign_it_to_sprint')}</td></tr>"
        p["sprint_"+sprint_id.to_s].visual_effect :blind_down, :duration => 1
      end

    end
  end

  def update_user_story_status
    @user_story = UserStory.find(params[:user_story_id])
    update_date = DateTime.civil(params[:user_story]['updated_at(1i)'].to_i,
                           params[:user_story]['updated_at(2i)'].to_i,
                           params[:user_story]['updated_at(3i)'].to_i,
                           params[:user_story]['updated_at(4i)'].to_i,
                           params[:user_story]['updated_at(5i)'].to_i,
                           params[:user_story]['updated_at(6i)'].to_i)
    assignment = create_assignment(params[:user_story_id],params[:user_story][:user_stories_status_id],update_date)
    if assignment.save and @user_story.update_attributes(params[:user_story])
      @issue_statuses = IssueStatus.find(:all)
      render :update do |page|
        unless @user_story.sprint.nil?
          page.replace "tab_us_#{@user_story.id}", :partial => "user_stories/us_for_show", 
            :locals => {:user_story => @user_story, 
              :count => @user_story.sprint.user_stories.index(@user_story)}
        end
      end
    else
      render :update do |page|
        format.html { render :action => "change_status" }
        format.xml  { render :xml => @user_story.errors, :status => :unprocessable_entity }
      end
    end
  end

  private

  def find_project
    @project = Project.find(params[:project_id])
    @project_users = User.find(:all, :joins => :members, :conditions => ["members.project_id = ?", @project.id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def create_assignment(user_story_id, user_stories_status_id, date = nil)
    assignment = UserStoriesAssignment.new(:user_story_id => user_story_id,
                                           :user_stories_status_id => user_stories_status_id,
                                           :user_id => User.current.id,
                                           :update_date => date.nil? ? Date.current : date)
  end
end
