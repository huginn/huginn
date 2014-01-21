//alert("i get included");
function remove_fields(link){
  $(link).prev().val("1");
  alert($(link).prev().val())
  $(link).parent(".fields").hide();
}
