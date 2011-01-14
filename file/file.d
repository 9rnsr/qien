module file.file;

import win32.windows;
import std.typecons;
//import std.stdio;
import std.string;


enum EOF = char.init;
enum LF = '\n';


struct TextFile_Source
{
private:
	HANDLE hFile;
	char pushback = char.init;

public:
	this(string fname){
	//	writefln("TextFile_Source ctor");
		
		int share = FILE_SHARE_READ | FILE_SHARE_WRITE;
		int access = GENERIC_READ;
		int createMode = OPEN_EXISTING;
		hFile = CreateFileW(std.utf.toUTF16z(fname), access, share, null, createMode, 0, null);
	}
	~this(){
		CloseHandle(hFile);
		hFile = null;
	//	writefln("TextFile_Source dtor");
	}
	
	char read(){
		char ch;
		if( pushback != char.init ){
			ch = pushback;
			pushback = char.init;
		}else{
			size_t size;
			if( ReadFile(hFile, &ch, char.sizeof, &size, null) == 0 ){
				throw new Exception("read error");
			}
			if( size == 0 ){
				ch = EOF;
			}else{
				if( ch == '\r' ){
					auto ch2 = read();
					if( ch2 == '\n' ){
						ch = '\n';
					}else{
						pushback = ch2;
					}
				}
			}
		}
		return ch;
	}
}


struct FilePos
{
	ulong line = 0;
	ulong column = 0;
	
	this(ulong ln, ulong col){
		line = ln;
		column = col;
	}
	
	string toString(){
		return (cast(const(FilePos))this).toString();
	}
	string toString() const{
		return format("[%s:%s]", line+1, column+1);
	}
}


struct FilePos_TextFile_Source
{
private:
	TextFile_Source src;
	FilePos pos;

public:
	this(string fname){
	//	writefln("FilePos_TextFile_Source ctor");
		src = TextFile_Source(fname);
	}
	~this(){
	//	writefln("FilePos_TextFile_Source dtor");
	}
	
	Tuple!(FilePos, char) read(){
		char ch;
		auto cur_pos = pos;
		
		if( (ch = src.read()) != EOF ){
			if( ch == LF ){
				pos.line += 1;
				pos.column = 0;
			}else{
				pos.column += 1;
			}
		}else{
			pos.column += 1;
		}
		
		return tuple(cur_pos, ch);
	}
}
