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

module RedminePeople
  module Patches
    module NotifiablePatch
      def self.included(base)
        base.extend(ClassMethods)
        base.class_eval do
          unloadable
          class << self
              alias_method_chain :all, :crm_invoice
          end
        end
      end


      module ClassMethods
        # include ContactsHelper

        def all_with_crm_invoice
          notifications = all_without_crm
          notifications << Redmine::Notifiable.new('invoice_comment_added')
          notifications
        end

      end

    end
  end
end

unless Redmine::Notifiable.included_modules.include?(RedminePeople::Patches::NotifiablePatch)
  Redmine::Notifiable.send(:include, RedminePeople::Patches::NotifiablePatch)
end
