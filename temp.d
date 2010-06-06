module temp;

import sym;
import std.conv;


Temp newTemp(){
	return new Temp();
}
Temp newTemp(string name){
	return new Temp(name);
}

class Temp
{
	static uniq_temp_count = 0;
	
	int num;
	string name;
	this(){
		num = uniq_temp_count++;
	}
	this(string s){
		this();
		name = s;
	}
	
	string toString(){
		if( name ) return "$"~to!string(num)~":"~name;
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
