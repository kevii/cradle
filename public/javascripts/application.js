// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults
function addField(field, prefix, name_prefix) {
		if(!document.getElementById) return; //Prevent older browsers from getting any further.
	var insert_field = document.getElementById(field);
	var all_inputs = insert_field.getElementsByTagName("input"); //Get all the input fields in the given area.
	//Find the count of the last element of the list. It will be in the format '<field><number>'. If the 
	//  prefix given in the argument is 'level' the last id will be 'level4'.
	var last_item = all_inputs.length - 1;
	var last = all_inputs[last_item].id;
	var count = Number(last.split(prefix)[1]) + 1;

	if(document.createElement) { //W3C Dom method.
		var input = document.createElement("input");
		input.id = prefix+count;
		input.name = name_prefix+"["+prefix+count+"]";
		input.type = "text"; //Type of field - can be any valid input type like text,file,checkbox etc.
		input.style.width = "18%";
		input.className = 'text-field';
		var span = document.createElement("span");
		span.style.paddingLeft = "10px";
		span.style.paddingRight = "10px";
		span.appendChild(input);
		insert_field.appendChild(span);
		var para = document.createElement("p");
		if (count%4==0) insert_field.appendChild(para);
	} else { //Older Method
		insert_field.innerHTML += "<input name='"+(prefix+count)+"' id='"+(prefix+count)+"' type='text' />";
		insert_field.innerHTML += "<span style='width:2%;'></span>";
	}
}
