function remove_invoice_fields (link) {
	$(link).prev("input[type=hidden]").val("1");
  $(link).parents('.fields').hide();
  updateInvoiceTotal();
  reorderLines();
}

function add_invoice_fields (link, association, content) {
	var	new_id = new Date().getTime();
  var regexp = new RegExp("new_" + association, "g");
	var regexp = new RegExp("new_" + association, "g");
	$('#sortable tr').last().after(content.replace(regexp, new_id));
  updateInvoiceTotal();
  $('#sortable tr td.price').last().mouseenter( invoiceMenuShow ).mouseleave( invoiceMenuHide );
  $('#invoice_lines_attributes_' + new_id + '_description').focus();
}

function formatCurrency(num) {
    num = isNaN(num) || num === '' || num === null ? 0.00 : num;
    return parseFloat(num).toFixed(2);
}

function updateTotal(element) {
	row = $(element).parents('tr');
	amount_value = row.find('.price input').val() * row.find('.quantity input').val();
  row.find('.total').html(formatCurrency(amount_value));
	return false;
}

function activateTextAreaResize(element) {
  $(element).keyup(function() {
    while($(element).outerHeight() < element.scrollHeight + parseFloat($(element).css("borderTopWidth")) + parseFloat($(element).css("borderBottomWidth")) && $(element).outerHeight() < 300) {
          $(element).height($(element).height()+15);
    };
  });

}



function reorderLines() {
  $('tr.sortable-line:visible').each(function(i, elem){
    $(elem).find('input.position').val(i + 1);
  });
}

function updateInvoiceTotal(element) {

  var rows = $(".invoice-lines tr.line.fields:visible"); // skip the header row
  var amounts = $('.invoice-lines tr.line.fields:visible td.total');

  rows.each(function(index) {
    var qty_input = $("td.quantity input", this);
    var price_input = $("td.price input", this);
    var tax_gst_input = $("td.tax.gst input[type=\"text\"]", this);
    var tax_pst_input = $("td.tax.pst input[type=\"text\"]", this);

    var qty = qty_input.val();
    var price = price_input.val();
    var amount = price * qty;
    var tax_gst = amount / 100 * tax_gst_input.val();
    var tax_pst = amount / 100 * tax_pst_input.val();
    var subtotal = amount;
    amount += tax_gst;
    amount += tax_pst;
	
    $(this).children("td.total").html(amount.toFixed(2))

  });

  var amttoal = 0;
  var vattotal = 0;
  var total = 0;

  amounts.each(function(){
      amttoal += parseFloat($(this).html())
  });

  $('#total_amount').html(amttoal.toFixed(2));

}

function invoiceMenuHide() {
  $('.invoice-menu').hide();
}

function invoiceMenuShow() {
  $(this).parent().find('.invoice-menu').css('display', 'inline-block')
}

function copyPriceToAll(element){
  $('td.price input').val($(element).closest('td.price').find('input').val());
  updateInvoiceTotal();
  return false;
}

$(function() {
  if ($('.invoice-lines').length)
  {

    var fixHelper = function(e, ui) {
      ui.children().each(function() {
        $(this).width($(this).width());
      });
      return ui;
    };

    $('.invoice-lines tbody#sortable').sortable({
      axis: 'y',
      opacity: 0.7,
      helper: fixHelper,
      stop: function(e,ui){reorderLines()}
    });

  }
});

