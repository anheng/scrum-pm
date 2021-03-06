require 'redmine'
require 'dispatcher'
require 'form_helper_extensions'
require 'gchart'
require "mini_magick"
require "hooks"

Dispatcher.to_prepare ':redmine_sprints' do

  require_dependency 'version'
  Version.send( :include, RedmineSprints::Patches::VersionPatch )

  require_dependency 'issue'
  Issue.send( :include, RedmineSprints::Patches::IssuePatch)

end

unless Redmine::Plugin.registered_plugins.keys.include?(:redmine_sprints)
  Redmine::Plugin.register :redmine_sprints do
    name 'Redmine Scrum Sprints plugin'
    author 'Software Project- Marcin Jedras'
    description 'This is Redmine plugin for scrum software development'
    version '0.1.6'

    settings(:partial => 'redmine_sprints_settings/index')

    project_module :sprints do
      permission :view_sprints, {:sprints => [:index, :show]}
      permission :manage_sprints_and_user_stories, {:sprints => [:create, :new, :edit, :update, :assign_us, :assign_to_milestone, :destroy], :user_stories => [:new, :create, :edit, :update, :destroy, :change_status, :update_user_story_status]}
      permission :manage_tasks, {:issue_sprints => [:new, :create, :status_change, :update_task, :status_delete]}
    end

    Redmine::MenuManager.map :project_menu do |menu|
      menu.push :dashboard, { :controller => 'sprints', :action => 'show', :id => :show }, :caption => :label_dashboard, :after => :activity, :param => :project_id
      menu.push :backlog, { :controller => 'sprints', :action => 'index' }, :caption => :label_backlog, :after => :activity, :param => :project_id
    end
  end
end
