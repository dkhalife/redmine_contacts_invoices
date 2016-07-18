# This file is a part of Redmine Invoices (redmine_contacts_invoices) plugin,
# invoicing plugin for Redmine
#
# Copyright (C) 2011-2016 Kirill Bezrukov
# http://www.redminecrm.com/
#
# redmine_contacts_invoices is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# redmine_contacts_invoices is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with redmine_contacts_invoices.  If not, see <http://www.gnu.org/licenses/>.

class Expense < ActiveRecord::Base
  unloadable
  include Redmine::SafeAttributes

  attr_accessible :expense_date, :price, :currency, :description, :status_id,
                  :contact_id, :custom_field_values, :project_id, :assigned_to_id, :is_billable

  belongs_to :contact
  belongs_to :project
  belongs_to :author, :class_name => "User", :foreign_key => "author_id"
  belongs_to :assigned_to, :class_name => "User", :foreign_key => "assigned_to_id"

  scope :by_project, lambda {|project_id| where("#{Expense.table_name}.project_id = ?", project_id) }
  scope :visible, lambda {|*args| eager_load(:project).where(Project.allowed_to_condition(args.first || User.current, :view_expenses)) }


  acts_as_event :datetime => :created_at,
                :url => Proc.new {|o| {:controller => 'expenses', :action => 'edit', :id => o}},
                :type => 'icon-expense',
                :title => Proc.new {|o| "#{l(:label_expense_created)} #{o.description} - #{o.price.to_s}" },
                :description => Proc.new {|o| [o.expense_date, o.description.to_s, o.contact.blank? ? "" : o.contact.name,  o.price.to_s].join(' ') }

  if ActiveRecord::VERSION::MAJOR >= 4
    acts_as_activity_provider :type => 'expenses',
                                :permission => :view_expenses,
                                :timestamp => "#{table_name}.created_at",
                                :author_key => :author_id,
                                :scope => joins(:project)

    acts_as_searchable :columns => ["#{table_name}.description"],
                       :project_key => "#{Project.table_name}.id",
                       :scope => joins([:project]).order("#{table_name}.expense_date"),
                       :permission => :view_expenses,
                       # sort by id so that limited eager loading doesn't break with postgresql
                       :date_column => "created_at"
  else
    acts_as_activity_provider :type => 'expenses',
                              :permission => :view_expenses,
                              :timestamp => "#{table_name}.created_at",
                              :author_key => :author_id,
                              :find_options => {:include => :project}

    acts_as_searchable :columns => ["#{table_name}.description"],
                       :date_column => "#{table_name}.created_at",
                       :include => [:project],
                       :project_key => "#{Project.table_name}.id",
                       :permission => :view_expenses,
                       # sort by id so that limited eager loading doesn't break with postgresql
                       :order_column => "#{table_name}.expense_date"
  end

  acts_as_customizable
  acts_as_attachable
  acts_as_priceable

  DRAFT_EXPENSE = 1
  NEW_EXPENSE = 2
  BILLED_EXPENSE = 3
  PAID_EXPENSE = 4

  STATUSES_STRINGS = {
    DRAFT_EXPENSE  => l(:label_expense_status_draft),
    NEW_EXPENSE    => l(:label_expense_status_new),
    BILLED_EXPENSE => l(:label_expense_status_billed),
    PAID_EXPENSE   => l(:label_expense_status_paid)
  }

  validates_presence_of :price, :expense_date
  validates_numericality_of :price, :tax, :allow_nil => true

  safe_attributes 'expense_date',
    'price',
    'currency',
    'description',
    'status_id',
    'contact_id',
    'custom_field_values',
    'project_id',
    'assigned_to_id',
    'is_billable'

  def visible?(usr=nil)
    (usr || User.current).allowed_to?(:view_expenses, self.project)
  end

  def editable_by?(usr, prj=nil)
    prj ||= self.project
    usr && (usr.allowed_to?(:edit_expenses, prj) || (self.author == usr && usr.allowed_to?(:edit_own_expenses, prj)))
    # usr && usr.logged? && (usr.allowed_to?(:edit_notes, project) || (self.author == usr && usr.allowed_to?(:edit_own_notes, project)))
  end

  def destroyable_by?(usr, prj=nil)
    prj ||= self.project
    usr && (usr.allowed_to?(:delete_expenses, prj) || (self.author == usr && usr.allowed_to?(:edit_own_expenses, prj)))
  end

  def status
    case self.status_id
    when DRAFT_EXPENSE
      l(:label_expense_status_draft)
    when NEW_EXPENSE
      l(:label_expense_status_new)
    when BILLED_EXPENSE
      l(:label_expense_status_billed)
    when PAID_EXPENSE
      l(:label_expense_status_paid)
    end
  end

  def price=(pr)
    super pr.to_s.gsub(' ','').gsub(/,/,'.').to_f
  end

  def is_draft
    status_id == DRAFT_EXPENSE || status_id.blank?
  end

  def is_open
    status_id != PAID_EXPENSE
  end

  def is_billed
    status_id == BILLED_EXPENSE
  end

  def editable?(usr=nil)
    @editable ||= editable_by?(usr)
  end

  def contact_country
    self.try(:contact).try(:address).try(:country)
  end

  def contact_city
    self.try(:contact).try(:address).try(:city)
  end

  def self.allowed_target_projects(user=User.current)
    Project.where(Project.allowed_to_condition(user, :edit_expenses))
  end

  def self.sum_by_period(peroid, project, contact_id=nil)
    from, to = RedmineContacts::DateUtils.retrieve_date_range(peroid)
    scope = Expense.where({})
    scope = scope.visible
    scope = scope.by_project(project.id) if project
    scope = scope.where("#{Expense.table_name}.expense_date BETWEEN ? AND ?", from, to)
    scope = scope.where("#{Expense.table_name}.contact_id = ?", contact_id) unless contact_id.blank?
    scope.group(:currency).sum(:price)
  end

  def self.sum_by_status(status_id, project, contact_id=nil)
    scope = Expense.where({})
    scope = scope.visible
    scope = scope.by_project(project.id) if project
    scope = scope.where("#{Expense.table_name}.status_id = ?", status_id)
    scope = scope.where("#{Expense.table_name}.contact_id = ?", contact_id) unless contact_id.blank?
    [scope.group(:currency).sum(:price), scope.count(:price)]
  end

end
