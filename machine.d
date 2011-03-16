/**
This module provides interpreter implementation.

VM
	instr_xxx() = add xxx instruction
	interpret() = run interpreter

TODO:
    synchronization of sp (stack.length and registers[SP.num])
 */
module machine;

import sym;
import frame;
import assem;
import xtk.tagunion;

import xtk.format;
import xtk.meta, xtk.metastrings;
import std.array;

debug = machine;

// byte - word operations

ulong b2w(ubyte b0, ubyte b1, ubyte b2, ubyte b3)
{
	version (LittleEndian)
	{
		return (cast(ulong)(b0) <<  0)
		     | (cast(ulong)(b1) <<  8)
		     | (cast(ulong)(b2) << 16)
		     | (cast(ulong)(b3) << 24);
	}
	version (BigEndian)
	{
		return (cast(ulong)(b0) << 24)
		     | (cast(ulong)(b1) << 16)
		     | (cast(ulong)(b2) <<  8)
		     | (cast(ulong)(b3) <<  0);
	}
	
}
unittest
{
	version (LittleEndian)
	{
		auto w = b2w(1,2,3,4);
		assert(w == 0x00_00_00_00_04_03_02_01);
		auto b = (cast(ubyte*)&w)[0 .. ulong.sizeof];
		assert(b[0] == 1);
		assert(b[1] == 2);
		assert(b[2] == 3);
		assert(b[3] == 4);
	}
}
/+ulong f2w(double f)
{
	struct X{ union{ ulong w; double f; } }
	X x;
	x.f = f;
	return x.w;
}+/

// instruction generator

private
{
	enum
	{
		NONE		= 0x00,
		STACK		= 0x01,
		REG_SRC		= 0x02,
		REG_SRC2	= 0x04,
		REG_DST		= 0x08,
		REG_SP		= 0x10,
		REG_EP		= 0x20,
		REG_CP		= 0x40,
	}
}

//struct DefInstr
alias DefInstr_!() DefInstr;
template DefInstr_()
{
	// non operation
	struct nop
	{
		enum chg = NONE;
		enum gen = q{ [b2w(ope, 0,0,0)] };
		enum run = q{};
		enum str = q{ "" };
	}
	// halt program
	struct hlt
	{
		enum chg = NONE;
		enum gen = q{ [b2w(ope, 0,0,0)] };
		enum run = q{ pc = code.length; };
		enum str = q{ "" };
	}

	// +,-,*,/
	template INSTR_RRR(string op)
	{
		enum chg = REG_SRC | REG_SRC2 | (REG_DST | REG_SP);
		enum gen = q{ [b2w(ope, cast(ubyte)a[0], cast(ubyte)a[1], cast(ubyte)a[2])] };
		enum run = mixin(expand!q{ registers[x.DST] = registers[x.SRC] $op registers[x.SRC2]; });
		enum str = mixin(expand!q{ format("r%02s $op r%02s -> r%02s", x.SRC, x.SRC2, x.DST) });
	}
	struct add{ mixin INSTR_RRR!("+"); }
	struct sub{ mixin INSTR_RRR!("-"); }
	struct mul{ mixin INSTR_RRR!("*"); }
	struct div{ mixin INSTR_RRR!("/"); }

	// reg -> reg
	struct mov
	{
		enum chg = REG_SRC | (REG_DST | REG_SP);
		enum gen = q{ [b2w(ope, cast(ubyte)a[0], 0, cast(ubyte)a[1])] };
		enum run = q{ registers[x.DST] = registers[x.SRC]; };
		enum str = q{ format("r%02s -> r%02s", x.SRC, x.DST) };
	}
	
	// [reg] -> reg
	struct get
	{
		enum chg = REG_SRC | (REG_DST | REG_SP);
		enum gen = q{ [b2w(ope, cast(ubyte)a[0], 0, cast(ubyte)a[1])] };
		enum run = q{ registers[x.DST] = heap_mem(registers[x.SRC]); };
		enum str = q{ format("[r%02s] -> r%02s", x.SRC, x.DST) };
	}
	// reg -> [reg]
	struct set
	{
		enum chg = REG_SRC | REG_DST;
		enum gen = q{ [b2w(ope, cast(ubyte)a[0], 0, cast(ubyte)a[1])] };
		enum run = q{ heap_mem(registers[x.DST]) = registers[x.SRC];
			debug(machine)
			{
				if ((registers[x.DST] & 0xFFFFFFFF_00000000) == 0)
					chg2 |= STACK;
			}
		};
		enum str = q{ format("r%02s -> [r%02s]", x.SRC, x.DST) };
	}
	
	// reg -> stack_top
	struct pushs
	{
		enum chg = REG_SRC | REG_SP | STACK;
		enum gen = q{ [b2w(ope, cast(ubyte)a[0], 0,0)] };
		enum run = q{ stack.put(registers[x.SRC]); };
		enum str = q{ format("r%02s -> [sp++]", x.SRC) };
	}
	// stack_top -> reg
	struct pop
	{
		enum chg = (REG_DST | REG_SP) | STACK;
		enum gen = q{ [b2w(ope, 0,0, cast(ubyte)a[0])] };
		enum run = q{
			if (sp == 0) error("stack underflow");
			registers[x.DST] = stack.pop(); 
			registers[SP.num] = stack.length;
		};
		enum str = q{ format("[--sp] -> r%02s", x.DST) };
	}
	
	// laod Fixnum/Flonum/Address -> reg
	struct imm
	{
		enum chg = (REG_DST | REG_SP);
		enum gen = q{ [b2w(ope, 0,0, cast(ubyte)a[1]), a[0]] };
		enum run = q{ registers[x.DST] = code[pc++]; };
		enum str = q{ format("#%s -> r%02s", code[pc++], x.DST) };
	}
	
	// reg -> pc
	struct call
	{
		enum chg = REG_EP | /*ENV*/STACK;
		enum gen = q{ [b2w(ope, cast(ubyte)a[0], 0,0)] };
		enum run = q{
		//	debug(machine) std.stdio.writefln("> map %s -> %08X",
		//			registers[x.SRC], cast(size_t)label_to_pc[cast(size_t)registers[x.SRC]]);
			stack[cp] = pc;
			ep = cp + ContSize;
		//	pc = cast(size_t)registers[x.SRC];
			pc = cast(size_t)label_to_pc[cast(size_t)registers[x.SRC]];	// TODO: call hack
		};
		enum str = q{ format("r%02s", x.SRC) };
	}
	// (Address) -> pc
	struct ret
	{
		enum chg = REG_EP | REG_CP | REG_SP;
		enum gen = q{ [b2w(ope, 0,0,0)] };
		enum run = q{
			ep = stack[cp+1];
			pc = cast(size_t)stack[cp+0];
			sp = cp;
			if (ep != 0)	//todo
				cp = cp - (heap_mem(ep+1) + ContSize);
		};
		enum str = q{ format("") };
	}
	// 
	struct pushc	// push continuation
	{
		enum chg = REG_CP | REG_SP;
		enum gen = q{ [b2w(ope, 0,0,0)] };
		enum run = q{
			cp = sp;
			stack.put(0xBEEF);	// ret pc (filled by call)
			stack.put(ep);		// ret ep
		};
		enum str = q{ format("") };
	}
	// ep -> stack
	struct pushe	// push environment
	{
		enum chg = REG_EP;
		enum gen = q{ [b2w(ope, 0,0,0)] };
		enum run = q{
			// RVはcaller側からcallee側に直接渡る唯一のpointer
			// (Arguments are always passed through environment)
			auto rv = registers[RV.num];
			
			//epが指すenvもコピーしないと。
			auto pep = &registers[FP.num];
			while (true)
			{
				auto ep = *pep;
				if (!is_stack_pointing(ep))
					break;
				
				auto env_top = &heap_mem(ep);
				auto env_siz = cast(size_t) *(env_top + 1);
				auto env     = env_top[0 .. env_siz];
				
				auto heap_top = heap_alloc(env_siz);
				auto heap_env = (&heap_mem(heap_top))[0 .. env_siz];
				std.stdio.writefln(">>> env = %(%04X %)", env);
				
				heap_env[] = env[];
				
				std.stdio.writefln(">>> stack env = [%s .. %s], rv = %s", ep, ep + env_siz, rv);
				if (ep <= rv && rv < (ep + env_siz))
					registers[RV.num] = ((heap_top >> 32) << 32) + (rv - ep);
				
				// コピーしたenvを指しているcontを書き換える
				*(env_top + env_siz + 1) = heap_top;
				
				*pep = heap_top;	// slinkの書き換え
				
				if (env[0] == 0)	// specifies outermost frame
					break;
				
				pep = &heap_env[0];
			}
		};
		enum str = q{ format("") };
	}
	
	// for heap_test, don't determin to keep this instruction
	// [0 .. len].ptr -> reg
	struct alloc
	{
		enum chg = REG_SRC | REG_DST;
		enum gen = q{ [b2w(ope, cast(ubyte)a[0], 0, cast(ubyte)a[1])] };
		enum run = q{ registers[x.DST] = heap_alloc(cast(size_t)registers[x.SRC]); };
		enum str = q{ format("[0 .. %s].ptr -> r%02s", x.SRC, x.DST) };
	}
}
private
{
	union MapInstr
	{
		ulong word;
		struct{ ubyte OPE, SRC, SRC2, DST; ubyte[4] _unused; }
	}

	struct ArrayStack(E)
	{
		Appender!(E[]) app;
		@property size_t length(){ return app.data.length; }
		void push(E e){ app.put(e); }
		E pop(){ E e = app.data[$-1]; app.shrinkTo(app.data.length-1); return e; }
	}

	struct WorkStack
	{
		ulong[] arr;
		
		ref ulong opIndex(ulong n)			{ return arr[cast(size_t)n]; }
		void opIndexAssign(ulong v, ulong n){ arr[cast(size_t)n] = v; }
		void put(ulong e)					{ arr ~= e; }
		ulong pop()							{ auto e = arr[$-1]; arr = arr[0..$-1]; return e; }
		@property ulong length()			{ return arr.length; }
		@property void length(ulong n)		{ arr.length = cast(size_t)n; }
		string toString() const				{ return format("%(%04X %)", arr); }
	}

	template CheckValid(string name)
	{
		enum CheckValid = mixin(mixin(expand!q{ is(DefInstr.$name == struct) }));
	}
	alias Filter!(CheckValid, __traits(allMembers, DefInstr)) Names;
	template mixinAllInstr(alias Gen)
	{
		static if (is(CommonType!(staticMap!(Typeof, staticMap!(Gen, Names))) == string))
			enum mixinAllInstr = Join!("\n", staticMap!(Gen, Names));
		else
			mixin mixinAll!(staticMap!(Gen, Names));
	}
}


private
{
	template GenInstrOpeNum()
	{
		enum GenInstrOpeNum = "enum InstrOp : ubyte { " ~ Join!(", ", Names) ~ "}";
	}
	mixin(GenInstrOpeNum!());				// enum InstrOp : ubyte {}
}


abstract final class Instruction
{
	// void instr_xxx(...){}
	template GenInstrMaker(string name)
	{
		template GenInstrMaker(string name = name)
		{
			mixin(mixin(expand!
			q{
				static ulong[] instr_$name(ubyte ope = InstrOp.$name, A...)(A a)
				{
					return ${ mixin("DefInstr.$name.gen") };
				}
			}));
		}
	}
	mixin mixinAllInstr!(GenInstrMaker);
}


class Machine
{
private:
	enum CP_NUM = 256+0;
	enum EP_NUM = 256+1;
	enum ContSize = 2;	// ret_pc + ret_ep
	
	ulong[size_t]	label_to_pc;		// TODO: call hack
	
	ulong[256] registers;
	size_t pc;
	@property ulong cp() { return registers[CP.num]; }	// todo
	@property ulong ep() { return registers[FP.num]; }	// todo
	@property ulong sp() { return stack.length; }

	@property ulong rv() { return registers[RV.num]; }
	
	@property void cp(ulong n){ registers[CP.num] = n; }
	@property void ep(ulong n){ registers[FP.num] = n; }
	@property void sp(ulong n){ stack.length = /*registers[SP.num] = */n; }
	

	ulong[] code;
	WorkStack stack;

	ulong[][uint] heap;
	ArrayStack!uint free_idx;

	ulong heap_alloc(size_t len)	// 32bit length
	{
		uint idx = void;
		if (free_idx.length)
			idx = free_idx.pop();
		else
			idx = heap.length;
		heap[idx] = new ulong[len];
		return (cast(ulong)idx << 32);
	}
	ref ulong heap_mem(ulong pointer)
	{
		auto heapidx = cast(uint)(pointer >> 32);
		auto heapofs = cast(uint)(pointer);
		if (heapidx == 0)
			return stack[heapofs];
		else
			return heap[heapidx][heapofs];
	}
	bool is_stack_pointing(ulong pointer)
	{
		return cast(uint)(pointer >> 32) == 0;
	}

	/// 
	void error(string msg)
	{
		class RuntimeException : Exception
		{
			this(){ super(format("RuntimeError[%08X] : %s", pc, msg)); }
		}
		throw new RuntimeException();
	}

private:
	this()
	{
	}
public:
	this(Instr[] instr)
	{
		foreach (i; instr)
		{
			Label lbl;
			ulong[] mi;
			match(i,
				Instr.OPE[&mi, $],{
					code ~= mi;
				},
				Instr.LBL[&mi, &lbl],{
					label_to_pc[lbl.num] = code.length;
				},
				Instr.MOV[&mi, $],{
					assert(0);	// yet not supported
				},
				_, {
					assert(0);
				});
				
		}
	}

	template GenInstrPrint(string name)
	{
		enum GenInstrPrint = mixin(expand!q{
			case InstrOp.$name:
				msg = format("%-6s%s", "$name", ${ mixin("DefInstr.$name.str") });
				break;
		});
	}
	/// 
	void print()
	{
		size_t pc = 0;
		while (pc < code.length)
		{
			string msg;
			auto pc_ = pc;
			
			MapInstr x; x.word = code[pc++];
			switch (x.OPE)
			{
			mixin(mixinAllInstr!(GenInstrPrint));
			default:
				assert(0);
			}
			
			std.stdio.writefln("%08X : %s", pc_, msg);
		}
	}
	
	template GenInstrInterp(string name)
	{
		enum GenInstrInterp = mixin(expand!q{
			case InstrOp.$name:
			  debug(machine)
			  {
				enum chg = DefInstr.$name.chg;
				auto chg2 = chg;
				auto pc_ = pc;
				std.stdio.writefln("%08X : %-6s%s", instr_pc, "$name", ${ mixin("DefInstr.$name.str") });
				pc = pc_;
				
				static if (chg & REG_SRC)	auto old_src  = registers[x.SRC ];
				static if (chg & REG_SRC2)	auto old_src2 = registers[x.SRC2];
			  }
				
				${ mixin("DefInstr.$name.run") }
				
			  static if ((chg & (REG_DST | REG_SP)) == (REG_DST | REG_SP))
			  {
				if (x.DST == SP.num)
				{
					stack.length = registers[x.DST];	// change stack size
					debug(machine) chg2 |= STACK;
				}
			  }
			  else static if (chg & REG_SP)
			  {
				registers[SP.num] = stack.length;
				debug(machine) chg2 |= STACK;
			  }
			  debug(machine)
			  {
				std.stdio.writefln("");
				static if (chg & REG_SRC)	std.stdio.writefln(" old src = r%02s : %08X", x.SRC,  old_src);
				static if (chg & REG_SRC2)	std.stdio.writefln(" old src = r%02s : %08X", x.SRC2, old_src2);
				static if (chg & REG_DST)	std.stdio.writefln("     dst = r%02s : %08X", x.DST,  registers[x.DST]);
				static if (chg & REG_SP)	printSP();
				static if (chg & REG_EP)	printEP();
				static if (chg & REG_CP)	printCP();
				       if (chg2 & STACK)	printStack();
				std.stdio.writefln("");
			  }
				break;
		});
	}
	/// 
	ulong run()
	{
		print();
		std.stdio.writefln("--");
		
		pc = 0;
		cp = 0;
		ep = 2;
		stack.put(code.length);	// outermost old_pc
		stack.put(0);			// outermost old_ep
		stack.put(0);			// outermost env->up  ( = void)
		stack.put(0xBEEF);		// outermost env->size(placholder)
		registers[SP.num] = stack.length;
		
	  debug(machine)
	  {
		void printStack()	{ std.stdio.writefln("   stack = %s", stack); }
		void printSP()		{ std.stdio.writefln("      sp = r%02s : %08X", SP.num, sp); }
		void printEP()		{ std.stdio.writefln("      ep = r%02s : %08X", FP.num, ep); }
		void printCP()		{ std.stdio.writefln("      cp = r%02s : %08X", CP.num, cp); }
		
		foreach (num, pc; label_to_pc)
		{
			std.stdio.writefln("   label_to_pc : %s -> %08X", num, pc);
		}
		printSP();
		printEP();
		printCP();
		printStack();
		std.stdio.writefln("");
	  }
		
		heap_alloc(0);
		assert(heap.length == 1);	// stack == idx0を確保
		
		while (pc < code.length)
		{
		  debug(machine)
			auto instr_pc = pc;
			
			MapInstr x; x.word = code[pc++];
			switch (x.OPE)
			{
			mixin(mixinAllInstr!(GenInstrInterp));
			default:	assert(0);
			}
		}
		
	  debug(machine)
	  {
		std.stdio.writefln("RV:r%02s = %s(%s)",
							RV.num, registers[RV.num], cast(long)registers[RV.num]);
	  }
		
		return registers[RV.num];
	}
}

version(unittest)
{
	static this()
	{
		frame.initialize();		// CP,FP,RV,SP
	}
}
unittest
{
	alias Instruction I;
	
	{
		scope(success) std.stdio.writefln("unittest@%s:%s passed", __FILE__, __LINE__);
		scope(failure) std.stdio.writefln("unittest@%s:%s failed", __FILE__, __LINE__);
		
		auto m = new Machine();
		m.code ~= I.instr_nop();
		m.code ~= I.instr_hlt();
		m.run();
	}
	
	void instr_test3(string instr)(ulong lhs, ulong rhs, ulong expect)
	{
		auto m = new Machine();
		m.code ~= I.instr_imm(lhs, 10);
		m.code ~= I.instr_imm(rhs, 11);
		mixin("m.code ~= I.instr_"~instr~"(10, 11, 12);");
	//	std.stdio.writefln("code = %(%02X %)", cast(ubyte[])m.code);;
		m.run();
		assert(m.registers[12] == expect, instr);
	}
	instr_test3!"add"(10, 20, 30);
	instr_test3!"sub"(20, 10, 10);
	instr_test3!"mul"(10,  2, 20);
	instr_test3!"div"(10,  2,  5);
	
	{
		scope(success) std.stdio.writefln("unittest@%s:%s passed", __FILE__, __LINE__);
		scope(failure) std.stdio.writefln("unittest@%s:%s failed", __FILE__, __LINE__);
		
		auto m = new Machine();
		m.code ~= I.instr_imm(100, 10);
		m.code ~= I.instr_imm(999, 11);
		m.code ~= I.instr_mov(10, 11);
		m.run();
		assert(m.registers[11] == 100);
	}
	{
		scope(success) std.stdio.writefln("unittest@%s:%s passed", __FILE__, __LINE__);
		scope(failure) std.stdio.writefln("unittest@%s:%s failed", __FILE__, __LINE__);
		
		auto m = new Machine();
		m.code ~= I.instr_imm(100, 10);
		m.code ~= I.instr_pushs(10);
		m.code ~= I.instr_pop(11);
		m.run();
		assert(m.registers[11] == 100);
	}
	{
		scope(success) std.stdio.writefln("unittest@%s:%s passed", __FILE__, __LINE__);
		scope(failure) std.stdio.writefln("unittest@%s:%s failed", __FILE__, __LINE__);
		
		auto m = new Machine();
		m.code ~= I.instr_pushc();
		m.code ~= I.instr_pushs(FP.num);	// pushs ep (slink)
		m.code ~= I.instr_imm(0x2, 10);		
		m.code ~= I.instr_pushs(10);		// pushs #2 (frameSize, local variables count == 0)
		m.code ~= I.instr_imm(0xA, 10);		// fn label(#xA) -> r10
		m.code ~= I.instr_call(10);			// call
		m.code ~= I.instr_hlt();			// hlt
		
		m.label_to_pc[0xA] = m.code.length;	// add mapping
		
		m.code ~= I.instr_imm(0x0A, 11);	// #10 -> r11
		m.code ~= I.instr_imm(0x14, 12);	// @20 -> r12
		m.code ~= I.instr_mul(11, 12, 13);	// r11 * r12 -> r13
		m.code ~= I.instr_ret();			// ret
		m.run();
		assert(m.registers[11] == 10);
		assert(m.registers[12] == 20);
		assert(m.registers[13] == 200);
	}

	// hep allocation and pointer access
	{
		scope(success) std.stdio.writefln("unittest@%s:%s passed", __FILE__, __LINE__);
		scope(failure) std.stdio.writefln("unittest@%s:%s failed", __FILE__, __LINE__);
		
		auto m = new Machine();
		m.code ~= I.instr_imm(0xA, 10);		// length = 10 -> r10
		m.code ~= I.instr_alloc(10, 11);	// [0 .. r10].ptr -> r11
		
		m.code ~= I.instr_imm(0xA, 10);		// #10 -> r10
		m.code ~= I.instr_set(10, 11);		// r10 -> [r11]
		m.code ~= I.instr_get(11, 12);		// [r11] -> r12	result -> r12
		
		m.code ~= I.instr_imm(0x1, 10);		// ptr offset = 1
		m.code ~= I.instr_add(10, 11, 11);	// r10(+1) + r11(ptr) _> r11(ptr+1)
		
		m.code ~= I.instr_imm(0x14, 10);	// #20 -> r10
		m.code ~= I.instr_set(10, 11);		// r10 -> [r11]
		m.code ~= I.instr_get(11, 13);		// [r11] -> r13	result -> r13
		m.run();
		auto ptr = m.registers[11];
		assert((ptr & 0xFFFF_FFFF) == 1);	// ptr offset == 1
		ptr -= 1;
		assert(m.registers[12] == 10);
		assert(m.registers[13] == 20);
		assert(m.heap_mem(ptr+0) == 10);
		assert(m.heap_mem(ptr+1) == 20);
	}

	// stack underflow
	{
		scope(success) std.stdio.writefln("unittest@%s:%s passed", __FILE__, __LINE__);
		scope(failure) std.stdio.writefln("unittest@%s:%s failed", __FILE__, __LINE__);
		
		auto m = new Machine();
		m.code ~= I.instr_imm(0x1, 10), m.code ~= I.instr_pop(11);	// #1 -> r10, [--sp] -> r11
		m.code ~= I.instr_imm(0x2, 10), m.code ~= I.instr_pop(11);	// #2 -> r10, [--sp] -> r11
		m.code ~= I.instr_imm(0x3, 10), m.code ~= I.instr_pop(11);	// #3 -> r10, [--sp] -> r11
		m.code ~= I.instr_imm(0x4, 10), m.code ~= I.instr_pop(11);	// #4 -> r10, [--sp] -> r11
		m.code ~= I.instr_imm(0x5, 10), m.code ~= I.instr_pop(11);	// #5 -> r10,([--sp] -> r11)
		m.code ~= I.instr_imm(0x6, 10);
		bool catched = false;
		try{
			m.run();
		}catch(Exception e){	// RuntimeException
			assert(m.registers[10] == 5);
			catched = true;
		}
		assert(catched, format("catched = %s", catched));
	}
}
