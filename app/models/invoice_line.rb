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

class InvoiceLine < ActiveRecord::Base
  unloadable
  include Redmine::SafeAttributes

  attr_accessible :description, :price, :quantity, :tax, :units, :position, :invoice_id, :discount, :custom_field_values

  belongs_to :invoice

  validates_presence_of :description, :if => Proc.new { |line| line.product_id.blank? }
  validates_presence_of :price, :quantity
  validates_numericality_of :price, :quantity

  delegate :currency, :to => :invoice, :allow_nil => true

  after_save :save_invoice_amount
  after_destroy :save_invoice_amount_destroy

  acts_as_list :scope => :invoice
  acts_as_priceable :price, :total, :tax_amount
  acts_as_customizable

  safe_attributes 'custom_field_values'

  def total
    self.price.to_f * self.quantity.to_f * (1 - self.discount.to_f/100)
  end

  def tax_amount
    (ContactsSetting.tax_exclusive? ? self.tax_exclusive : self.tax_inclusive)
  end

  def price=(pr)
    super pr.to_s.gsub(/,/,'.')
  end

  def quantity=(q)
    super q.to_s.gsub(/,/,'.')
  end

  def tax_to_s
    tax ? "#{"%.2f" % tax.to_f}%": ""
  end

  def discount_to_s
    discount ? "#{"%.2f" % discount.to_f}%": ""
  end

  def tax_inclusive
    total * (1 - (1/(1+tax.to_f/100)))
  end

  def tax_exclusive
    total * tax.to_f/100
  end

  def line_description
    description
  end

  private

  def save_invoice_amount
    self.invoice.calculate_amount
    # self.invoice.save unless self.invoice.new_record?
  end

  def save_invoice_amount_destroy
    self.invoice.lines.delete(self)
    self.invoice.calculate_amount
    self.invoice.save unless self.invoice.new_record?
  end

end
