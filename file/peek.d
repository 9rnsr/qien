module file.peek;

public import file.file : FilePos;
import file.file;
import std.typecons;
import std.stdio : writef, writefln;


struct PeekSource
{
	FilePos_TextFile_Source src;
	alias Tuple!(FilePos, char) Pair;
	
	Pair[]	cache = null;
	size_t	cache_pos = 0;
	bool	m_eof = true;
	
	this(string fname){
	//	writefln("PeekSource ctor");
		src = FilePos_TextFile_Source(fname);
		
		Pair p;
		if( (p = src.read()), p.field[1] != EOF ){
			cache = [p];
			cache_pos = 0;
			m_eof = false;
		}
	}
	~this(){
	//	writefln("PeekSource dtor");
	}
	
	FilePos fpos() const	{ return current.field[0]; }
	char    top() const		{ return current.field[1]; }
	
	ref const(Pair) current() const{
		if( cache.length <= cache_pos ) throw new Exception("");
		
		return cache[cache_pos];
	}
	bool eof() const{
		return m_eof;
	}
	
	bool revertable() const{
		return 0 < cache_pos;
	}
	
	void forward(){
		if( m_eof ) return;
		
		cache_pos += 1;
		if( cache.length <= cache_pos ){	//cache払拭
			Pair p;
			if( (p = src.read()), p.field[1] != EOF ){
				cache ~= p;
			}else{
				m_eof = true;
			}
		}
	}
	
	void revert(){
		cache_pos = 0;
	}
	
	void commit(){
		if( eof ) return;
		
		cache = cache[cache_pos .. $];
		cache_pos = 0;
	}
	
}

bool match(PeekSource src, string pattern)
{
	if( src.revertable ) throw new Exception("match must start from non-rollbackable state");
	
	foreach( c; pattern ){
		if( src.eof || src.top != c ){
			return src.revert(), false;
		}
		src.forward();
	}
	return src.commit(), true;
}



/+unittest
{
	auto input = PeekSource(makecode("String", "Buffer"));
	
	test_scope("PeekSource#next",
	{
		//test of next
		assert(input.toppos == FilePos(1,1));
		assert(input.topc == 'S');
		input.forward();
		assert(input.topc == 't');
		assert(input.toppos == FilePos(1,2));
	//	assert(input.store.length == 1);
		input.forward();
		assert(input.topc == 'r');
		assert(input.toppos == FilePos(1,3));
	//	assert(input.store.length == 2);
		
		{
			auto input2 = PeekSource(makecode("a"));
			input2.forward();
			assert(input2.topc == 0xff);
			assert(input2.eof == true);
			input2.revert();
			assert(input2.topc == 'a');
			assert(input2.eof == false);
			input2.forward();
			assert(input2.topc == 0xff);
			assert(input2.eof == true);
		}
		{
			auto input2 = PeekSource(makecode("0]"));
			assert(input2.topc == '0');
			input2.forward();
			input2.revert();
			input2.forward();
			assert(input2.topc == ']');
			assert(input2.eof == false);
		}
		
		//test of commit
		input.commit();
		assert(input.topc == 'r');
		assert(input.toppos == FilePos(1,3));
	//	assert(input.store.length == 0);
		
		//test of over newline
		input.forward();	//topc==i
		input.forward();	//topc==n
		input.forward();	//topc==g
		input.forward();	//topc==\n
		assert(input.topc == '\n');
		assert(input.toppos == FilePos(1,7));
		input.forward();	//topc==B
		assert(input.topc == 'B');
		assert(input.toppos == FilePos(2,1));
		
		//test of revert
		input.commit();
	//	assert(input.store.length == 0);
		input.forward();	//topc==u
		input.forward();	//topc==f
		input.forward();	//topc==f
		assert(input.topc == 'f');
		assert(input.toppos == FilePos(2,4));
	//	assert(input.store.length == 3);
		input.revert();
		assert(input.topc == 'B');
		assert(input.toppos == FilePos(2,1));
	//	assert(input.store.length == 0);
		input.forward();
		assert(input.topc == 'u');
		assert(input.toppos == FilePos(2,2));
	//	assert(input.store.length == 1);
		
		//test of eof
		input = PeekSource(makecode("end"));
		assert(input.eof == false);
		input.forward();
		input.forward();
		input.commit();
		assert(input.eof == false);
		input.forward();
		assert(input.eof == true);
		assert(input.topc == char.init);
		input.revert();
		assert(input.eof == false);
		assert(input.topc == 'd');
		
		input = PeekSource(makecode(""));
		assert(input.eof == true);
		assert(input.topc == char.init);
		input.forward();
		assert(input.eof == true);
		
		//test of skip-whitespace
		input = PeekSource(makecode("S  0"));
		input.skip_whitespace();
		assert(input.topc == 'S');
		
		input.forward();
		input.skip_whitespace();
		assert(input.topc == '0');
		
		//test of synchronous source-stream/position
		input = PeekSource(makecode("abcdefgh"));
		assert(input.position == 0);
		
		input.forward();	//topc == 'b'
		assert(input.position == 1);
		
		input.commit();
		assert(input.position == 1);
		
		input.forward();	//topc == 'c'
		assert(input.position == 2);
		
		input.revert();
		assert(input.position == 1);
		input.forward();	//topc == 'c'
		assert(input.position == 2);
		assert(input.topc == 'c');
	});
	test_scope("PeekSource#match",
	{
		with( PeekSource(makecode("//comment")) ){
			assert(match("//"));
			assert(topc == 'c');
			assert(position == 2);
		}
		with( PeekSource(makecode("/*comment")) ){
			assert(!match("//"));
			assert(topc == '/');
			assert(position == 0);
		}
		with( PeekSource(makecode("//")) ){
			assert(match("//"));
			assert(eof);
			assert(position == 2);
		}
		with( PeekSource(makecode("/")) ){
			assert(!match("//"));
			assert(topc == '/');
			assert(position == 0);
		}
		with( PeekSource(makecode("")) ){
			assert(!match("//"));
			assert(eof);
			assert(position == 0);
		}
	});
}+/
