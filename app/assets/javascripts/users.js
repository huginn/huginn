//alert("i get included");
function remove_fields(link){
  $(link).prev().val("1");
  $(link).parent(".fields").hide();
}

function add_fields(link, association, content) {
  var new_id = new Date().getTime();
  var regexp = new RegExp("new_" + association, "g")
  $(link).parent().before(content.replace(regexp, new_id));
}


