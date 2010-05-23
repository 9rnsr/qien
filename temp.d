module temp;

import sym;
import std.conv;


Temp newTemp(){
	return new Temp();
}

class Temp
{
	static uniq_temp_count = 0;
	
	int num;
	this(){
		num = uniq_temp_count++;
	}
	
	string toString(){
		return "$"~to!string(num);
	}
}

//class Label{}
alias Symbol Label;	//無名シンボル==ラベル

Label newLabel(){
	return Label();
}
Label namedLabel(string name){
	return Label(name);
}
