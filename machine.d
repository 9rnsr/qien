/**
This module provides interpreter implementation.

VM
	instr_xxx() = add xxx instruction
	interpret() = run interpreter
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

//struct DefInstr
alias DefInstr_!() DefInstr;
template DefInstr_()
{
	// non operation
	struct nop
	{
		enum gen = q{ [b2w(ope, 0,0,0)] };
		enum run = q{};
		enum str = q{ "" };
	}
	// halt program
	struct hlt
	{
		enum gen = q{ [b2w(ope, 0,0,0)] };
		enum run = q{ pc = code.length; };
		enum str = q{ "" };
	}

	// +,-,*,/
	template INSTR_RRR(string op)
	{
		enum gen = q{ [b2w(ope, cast(ubyte)a[0], cast(ubyte)a[1], cast(ubyte)a[2])] };
		enum run = mixin(expand!q{
	//		std.stdio.writefln("r%s=%s, r%s=%s, r%s=%s",
	//			x.SRC , registers[x.SRC ],
	//			x.SRC2, registers[x.SRC2],
	//			x.DST , registers[x.DST ]);
			registers[x.DST] = registers[x.SRC] $op registers[x.SRC2]; });
		enum str = mixin(expand!q{ format("r%s $op r%s -> r%s", x.SRC, x.SRC2, x.DST) });
	}
	struct add{ mixin INSTR_RRR!("+"); }
	struct sub{ mixin INSTR_RRR!("-"); }
	struct mul{ mixin INSTR_RRR!("*"); }
	struct div{ mixin INSTR_RRR!("/"); }

	// reg -> reg
	struct mov
	{
		enum gen = q{ [b2w(ope, cast(ubyte)a[0], 0, cast(ubyte)a[1])] };
		enum run = q{
				if (x.DST == SP.num)
				{
					sp = registers[x.SRC];	// change stack size
					debug(machine) printStack();
				}
				else
					registers[x.DST] = registers[x.SRC];
				debug(machine) printRegs();
				};
		enum str = q{ format("r%s -> r%s", x.SRC, x.DST) };
	}
	
	// [reg] -> reg
	struct get
	{
		enum gen = q{ [b2w(ope, cast(ubyte)a[0], 0, cast(ubyte)a[1])] };
		enum run = q{ registers[x.DST] = heap_mem(registers[x.SRC]); };
		enum str = q{ format("[r%s] -> r%s", x.SRC, x.DST) };
	}
	// reg -> [reg]
	struct set
	{
		enum gen = q{ [b2w(ope, cast(ubyte)a[0], 0, cast(ubyte)a[1])] };
		enum run = q{ heap_mem(registers[x.DST]) = registers[x.SRC];
			debug(machine){
				if ((registers[x.DST] & 0xFFFFFFFF_00000000) == 0)
					printStack();
			}
		};
		enum str = q{ format("r%s -> [r%s]", x.SRC, x.DST) };
	}
	
	// reg -> stack_top
	struct pushs
	{
		enum gen = q{ [b2w(ope, cast(ubyte)a[0], 0,0)] };
		enum run = q{ stack.put(registers[x.SRC]); 
				debug(machine) printStack();
		};
		enum str = q{ format("r%s -> [sp++]", x.SRC) };
	}
	// stack_top -> reg
	struct pop
	{
		enum gen = q{ [b2w(ope, 0,0, cast(ubyte)a[0])] };
		enum run = q{ if (sp == 0) error("stack underflow");
					  registers[x.DST] = stack.pop(); 
				debug(machine) printStack();
		};
		enum str = q{ format("[--sp] -> r%s", x.DST) };
	}
	
	// laod Fixnum/Flonum/Address -> reg
	struct imm
	{
		enum gen = q{ [b2w(ope, 0,0, cast(ubyte)a[1]), a[0]] };
		enum run = q{ registers[x.DST] = code[pc++]; };
		enum str = q{ format("#%s -> r%s", code[pc++], x.DST) };
	}
	
	// reg -> pc
	struct call
	{
		enum gen = q{ [b2w(ope, cast(ubyte)a[0], 0,0)] };
		enum run = q{
			std.stdio.writefln("> %s", __LINE__);
		//	debug(machine) std.stdio.writefln("> map %s -> %08X",
		//			registers[x.SRC], cast(size_t)label_to_pc[cast(size_t)registers[x.SRC]]);
			stack[cp] = pc;
			ep = cp + ContSize;
		//	pc = cast(size_t)registers[x.SRC];
			pc = cast(size_t)label_to_pc[cast(size_t)registers[x.SRC]];	// TODO: call hack
			debug(machine) printStack();
			debug(machine) printRegs();
		};
		enum str = q{ format("r%s", x.SRC) };
	}
	// (Address) -> pc
	struct ret
	{
		enum gen = q{ [b2w(ope, 0,0,0)] };
		enum run = q{
			debug(machine) printRegs();
			ep = stack[cp+1];
			pc = cast(size_t)stack[cp+0];
			sp = cp;
			if (ep != 0)	//todo
				cp = cp - (heap_mem(ep+1) + ContSize);
			debug(machine) printStack();
		};
		enum str = q{ format("") };
	}
	// 
	struct pushc	// push continuation
	{
		enum gen = q{ [b2w(ope, 0,0,0)] };
		enum run = q{
			cp = sp;
			stack.put(0xBEEF);	// ret pc (filled by call)
			stack.put(ep);		// ret ep
			debug(machine) printStack();
		};
		enum str = q{ format("") };
	}
	// ep -> stack
	struct pushe	// push environment
	{
		enum gen = q{ [b2w(ope, 0,0,0)] };
		enum run = q{
			assert(0);
			debug(machine) printStack();
		};
		enum str = q{ format("") };
	}
	
	// for heap_test, don't determin to keep this instruction
	// [0 .. len].ptr -> reg
	struct alloc
	{
		enum gen = q{ [b2w(ope, cast(ubyte)a[0], 0, cast(ubyte)a[1])] };
		enum run = q{ registers[x.DST] = heap_alloc(cast(size_t)registers[x.SRC]); };
		enum str = q{ format("[0 .. %s].ptr -> r%s", x.SRC, x.DST) };
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
	@property ulong sp() { return registers[SP.num] = stack.length; }
	
	@property void cp(ulong n){ registers[CP.num] = n; }
	@property void ep(ulong n){ registers[FP.num] = n; }
	@property void sp(ulong n){ stack.length = n; }
	

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

		foreach (num, pc; label_to_pc)
		{
			std.stdio.writefln("label_to_pc : %s -> %08X", num, pc);
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
			
			MapInstr x; x.word = code[pc++];
			switch (x.OPE)
			{
			mixin(mixinAllInstr!(GenInstrPrint));
			default:
				assert(0);
			}
			
			std.stdio.writefln("%08X : %s", pc, msg);
		}
	}
	
	template GenInstrInterp(string name)
	{
		enum GenInstrInterp = mixin(expand!q{
			case InstrOp.$name:
				debug(machine)
				{
					auto pc_ = pc;
					std.stdio.writefln("%08X : %-6s%-32s[SRC] = %s, [SRC2] = %s, [DST] = %s",
						pc_, "$name", ${ mixin("DefInstr.$name.str") },
						registers[x.SRC], registers[x.SRC2], registers[x.DST]);
					pc = pc_;
				}
				${ mixin("DefInstr.$name.run") }
				break;
		});
	}
	/// 
	void run()
	{
		print();
		std.stdio.writefln("--");
		
		void printStack()
		{
			debug(machine) std.stdio.writefln("%49sstack = %s", "", stack);
		}
		void printRegs()
		{
			debug(machine) std.stdio.writefln("%49s regs = ep:%08X, cp:%08X, sp:%08X", "", ep, cp, sp);
		}
		
		pc = 0;
		cp = 0;
		ep = 2;
		stack.put(code.length);	// outermost old_pc
		stack.put(0);			// outermost old_ep
		stack.put(0);			// outermost env->up  ( = void)
		stack.put(0xBEEF);		// outermost env->size(placholder)
		
		debug(machine) printRegs();
		debug(machine) printStack();
		
		heap_alloc(0);
		assert(heap.length == 1);	// stack == idx0を確保
		
		while (pc < code.length)
		{
			MapInstr x; x.word = code[pc++];
			switch (x.OPE)
			{
			mixin(mixinAllInstr!(GenInstrInterp));
			default:	assert(0);
			}
		}
		
		debug(machine) std.stdio.writefln("RV:r%s = %s(%s)",
							RV.num, registers[RV.num], cast(long)registers[RV.num]);
	}
}

unittest
{
	scope(success) std.stdio.writefln("unittest@%s:%s passed", __FILE__, __LINE__);
	scope(failure) std.stdio.writefln("unittest@%s:%s failed", __FILE__, __LINE__);
	
	alias Instruction I;
	
	{
		auto m = new Machine();
		m.code ~= I.instr_nop();
		m.code ~= I.instr_hlt();
		m.run();
	}
	
	void instr_test3(string instr)(ulong lhs, ulong rhs, ulong expect)
	{
		auto m = new Machine();
		m.code ~= I.instr_imm(lhs, 0);
		m.code ~= I.instr_imm(rhs, 1);
		mixin("m.code ~= I.instr_"~instr~"(0, 1, 2);");
	//	std.stdio.writefln("code = %(%02X %)", cast(ubyte[])m.code);
		m.run();
		assert(m.registers[2] == expect, instr);
	}
	instr_test3!"add"(10, 20, 30);
	instr_test3!"sub"(20, 10, 10);
	instr_test3!"mul"(10,  2, 20);
	instr_test3!"div"(10,  2,  5);
	
	{	auto m = new Machine();
		m.code ~= I.instr_imm(100, 0);
		m.code ~= I.instr_imm(999, 1);
		m.code ~= I.instr_mov(0, 1);
		m.run();
		assert(m.registers[1] == 100);
	}
	{	auto m = new Machine();
		m.code ~= I.instr_imm(100, 0);
		m.code ~= I.instr_pushs(0);
		m.code ~= I.instr_pop(1);
		m.run();
		assert(m.registers[1] == 100);
	}
	{	auto m = new Machine();
		m.code ~= I.instr_imm(4, 0);		// r0 <- fn addr(4word)
		m.code ~= I.instr_call(0);			// call
		m.code ~= I.instr_hlt();			// hlt
	 // 4word <- imm(2) + call(1) + hlt(1)
		m.code ~= I.instr_imm(10, 1);		// #10 -> r1
		m.code ~= I.instr_imm(20, 2);		// @20 -> r2
		m.code ~= I.instr_mul(1, 2, 3);		// r1 * r2 -> r3
		m.code ~= I.instr_ret();			// ret
		m.run();
		assert(m.registers[0] == 4);
		assert(m.registers[1] == 10);
		assert(m.registers[2] == 20);
		assert(m.registers[3] == 200);
	}

	// hep allocation and pointer access
	{	auto m = new Machine();
		m.code ~= I.instr_imm(10, 0);		// length = 10 -> r0
		m.code ~= I.instr_alloc(0, 1);		// [0 .. r0].ptr -> r1
		
		m.code ~= I.instr_imm(10, 0);		// #10 -> r0
		m.code ~= I.instr_set(0, 1);		// r0 -> [r1]
		m.code ~= I.instr_get(1, 2);		// [r1] -> r2	result -> r2
		
		m.code ~= I.instr_imm(1, 0);		// ptr offset = 1
		m.code ~= I.instr_add(0, 1, 1);		// r0(+1) + r1(ptr) _> r1(ptr+1)
		
		m.code ~= I.instr_imm(20, 0);		// #20 -> r0
		m.code ~= I.instr_set(0, 1);		// r0 -> [r1]
		m.code ~= I.instr_get(1, 3);		// [r1] -> r3	result -> r3
		m.run();
		auto ptr = m.registers[1];
		assert((ptr & 0xFFFF_FFFF) == 1);	// ptr offset == 1
		ptr -= 1;
		assert(m.registers[2] == 10);
		assert(m.registers[3] == 20);
		assert(m.heap_mem(ptr+0) == 10);
		assert(m.heap_mem(ptr+1) == 20);
	}

	// stack underflow
	{	auto m = new Machine();
		m.code ~= I.instr_imm(1, 0), m.code ~= I.instr_pop(1);	// #1 -> r0, [--sp] -> r1
		m.code ~= I.instr_imm(2, 0), m.code ~= I.instr_pop(1);	// #2 -> r0, [--sp] -> r1
		m.code ~= I.instr_imm(3, 0), m.code ~= I.instr_pop(1);	// #3 -> r0, [--sp] -> r1
		m.code ~= I.instr_imm(4, 0), m.code ~= I.instr_pop(1);	// #4 -> r0, [--sp] -> r1
		m.code ~= I.instr_imm(5, 0), m.code ~= I.instr_pop(1);	// #5 -> r0,([--sp] -> r1)
		m.code ~= I.instr_imm(6, 0);
		bool catched = false;
		try{
			m.run();
		}catch(Exception e){	// RuntimeException
			assert(m.registers[0] == 5);
			catched = true;
		}
		assert(catched, format("catched = %s", catched));
	}
}



/+
import sym;
import frame;
import assem;
import xtk.tagunion;
import std.string;
import debugs;
private import xtk.format : format;

debug = machine;

alias long Word;
alias ulong Ptr;

/**
*	LDA		[@src]		-> $dst		[op:8][dest:8][----:8][src :8]
	LDB		[ep+n]		-> $dst		[op:8][dest:8][disp:8][base:8]
	LDI		#imm		-> $dst		[op:8][dest:8][-----------:16] [imm :64]
	
	STA		$src		-> @addr	[op:8][src :8][-----------:16] [addr:64]
	STB		$src		-> [ep+n]	[op:8][base:8][disp:8][src :8]
	
	MOV		$src		-> $dst		[op:8][dest:8][----:8][src :8]
	ADD		$src ? $acc	-> $dst		[op:8][dest:8][acc :8][src :8]
	SUB		<<same>>
	MUL		<<same>>
	DIV		<<same>>
*/
class Instruction
{
	union Fmt
	{
		ubyte ope;
		struct L { ubyte ope; ubyte dst; short           disp; }	L l;
		struct S { ubyte ope; ubyte src; short           disp; }	S s;	// alignment fix
		struct A { ubyte ope; ubyte dst; ubyte acc; ubyte src; }	A a;
		uint data;
	}
	enum Op : ubyte
	{
		NOP	= 0x00,	HLT	= 0x01,
		LDA	= 0x10,	LDB	= 0x11,	LDI	= 0x12,		POP	= 0x13,
		STA	= 0x20,	STB	= 0x21,					PUSH= 0x23,
		
		MOV	= 0x30,	ADD	= 0x31,	SUB	= 0x32,	MUL	= 0x33,	DIV	= 0x34,
		
		CALL		= 0x40,
		RET			= 0x41,
		PUSH_CONT	= 0x42,
		PUSH_ENV	= 0x43,
		ENTER		= 0x44,
	}

	Fmt i;
	union { ulong adr;	long imm; }
	
	this(Fmt.L ld, uint adr)	{ i.l = ld, this.adr = adr; }
	this(Fmt.L ld)				{ i.l = ld; }
	this(Fmt.L ld, long imm)	{ i.l = ld, this.imm = imm; }
	
	this(Fmt.S st, uint adr)	{ i.s = st, this.adr = adr; }
	this(Fmt.S st)				{ i.s = st; }
	
	this(Fmt.S st, long imm)	{ i.s = st, this.imm = imm; }
	this(Fmt.A ac)				{ i.a = ac; }
	
	static LDA(Temp adr, Temp dst) { return new Instruction(Fmt.A(Op.LDA, R(dst), 0, R(adr))); }
	static LDI(long imm, Temp dst) { return new Instruction(Fmt.L(Op.LDI, R(dst), 0              ), imm); }
	static POP(Temp dst)           { return new Instruction(Fmt.L(Op.POP, R(dst), 0)); }
	
	static STA(Temp src, uint adr) { return new Instruction(Fmt.S(Op.STA,  R(src), 0), adr); }
	static PUSH(Temp src)          { return new Instruction(Fmt.S(Op.PUSH, R(src), 0)); }
	
	static LDB(Temp bas, Temp dsp, Temp dst) { return new Instruction(Fmt.A(Op.LDB, R(dst), R(dsp), R(bas))); }
	static STB(Temp src, Temp bas, Temp dsp) { return new Instruction(Fmt.A(Op.STB, R(bas), R(dsp), R(src))); }

	static MOV(Temp src,           Temp dst) { return new Instruction(Fmt.A(Op.MOV, R(dst), 0,      R(src))); }
	static ADD(Temp src, Temp acc, Temp dst) { return new Instruction(Fmt.A(Op.ADD, R(dst), R(acc), R(src))); }
	static SUB(Temp src, Temp acc, Temp dst) { return new Instruction(Fmt.A(Op.SUB, R(dst), R(acc), R(src))); }
	static MUL(Temp src, Temp acc, Temp dst) { return new Instruction(Fmt.A(Op.MUL, R(dst), R(acc), R(src))); }
	static DIV(Temp src, Temp acc, Temp dst) { return new Instruction(Fmt.A(Op.DIV, R(dst), R(acc), R(src))); }
	
	static CALL(Temp adr)	{ return new Instruction(Fmt.A(Op.CALL, 0,0,R(adr))); }
	static RET()			{ return new Instruction(Fmt.A(Op.RET,       0,0,0)); }
	static PUSH_CONT()		{ return new Instruction(Fmt.A(Op.PUSH_CONT, 0,0,0)); }
	static PUSH_ENV()		{ return new Instruction(Fmt.A(Op.PUSH_ENV,  0,0,0)); }
	static ENTER(size_t n)	{ return new Instruction(Fmt.L(Op.ENTER, 0,cast(short)n)); }
	
	private static ubyte R(in Temp t)
	{
		return cast(ubyte)t.num;	// todo
	}

	string toString()
	{
		final switch (i.ope) with (Op)
		{
		case NOP:	return "NOP";
		case HLT:	return "HLT";
		
		case LDA:	return format("LDA [@%X] -> R%s"	, i.a.src, i.a.dst);
		case LDB:	return format("LDB [R%s+R%s] -> R%s", i.a.src, i.a.acc, i.a.dst);
		case LDI:	return format("LDI #%s -> R%s", imm	, i.l.dst);
		case POP:	return format("POP [--sp] -> R%s"	, i.l.dst);
		
		case STA:	return format("STA R%s -> @%X"		, i.s.src, adr);
		case STB:	return format("STB R%s -> [R%s+R%s]", i.a.src, i.a.dst, i.a.acc);
		case PUSH:	return format("PUSH R%s -> [sp++]"	, i.s.src);
		
		case MOV:	return format("MOV R%s -> R%s"		, i.a.src,          i.a.dst);
		case ADD:	return format("ADD R%s + R%s -> R%s", i.a.src, i.a.acc, i.a.dst);
		case SUB:	return format("SUB R%s - R%s -> R%s", i.a.src, i.a.acc, i.a.dst);
		case MUL:	return format("MUL R%s * R%s -> R%s", i.a.src, i.a.acc, i.a.dst);
		case DIV:	return format("DIV R%s / R%s -> R%s", i.a.src, i.a.acc, i.a.dst);
		
		case PUSH_CONT:	return "PUSH_CONT";
		case PUSH_ENV:	return "PUSH_ENV";
		case CALL:		return format("CALL R%s", i.a.src);
		case RET:		return "RET";
		case ENTER:		return format("ENTER %s", i.l.disp);
		}
	}
	
	const(uint[]) assemble() const
	{
		final switch (i.ope) with (Op)
		{
		case NOP:	return [cast(uint)NOP << 24];
		case HLT:	return [cast(uint)HLT << 24];
		
		case LDA:	return [i.data];
		case LDB:	return [i.data];
		case LDI:	return [i.data] ~ (cast(uint*)(&imm))[0 ..  long.sizeof/uint.sizeof];
		case POP:	return [i.data];
		
		case STA:	return [i.data] ~ (cast(uint*)(&adr))[0 .. ulong.sizeof/uint.sizeof];
		case STB:	return [i.data];
		case PUSH:	return [i.data];
		
		case MOV:	return [i.data];
		case ADD:	return [i.data];
		case SUB:	return [i.data];
		case MUL:	return [i.data];
		case DIV:	return [i.data];
		
		case PUSH_CONT:	return [i.data];
		case PUSH_ENV:	return [i.data];
		case CALL:		return [i.data];
		case RET:		return [i.data];
		case ENTER:		return [i.data];
		}
	}
}

class Machine
{
private:
	const(uint)[]	code;
	long[]			stack;
	long[256]		regs;	// todo
	size_t			pc;
	ref ulong		cp() @property { return *cast(ulong*)&regs[CP.num]; };
	ref ulong		ep() @property { return *cast(ulong*)&regs[FP.num]; }	// one of the normal registers
	ref ulong		sp() @property { return *cast(ulong*)&regs[SP.num]; };
	
	ref ulong		cp(ulong n) @property { return cp() = n, cp(); };
	ref ulong		ep(ulong n) @property { return ep() = n, ep(); }
	ref ulong		sp(ulong n) @property { return stack.length = cast(size_t)n, sp() = n, sp(); }
	Heap			heap;
	
	size_t cp_t()	{ return cast(size_t)cp; }
	size_t ep_t()	{ return cast(size_t)ep; }
	size_t sp_t()	{ return cast(size_t)sp; }
	
	size_t[uint]	label_to_pc;
	
	enum ContSize = 2;	// ret_pc + ret_ep

public:
	this(Instr[] instr)
	{
		foreach (i; instr)
		{
			Label lbl;
			Instruction mi;
			match(i,
				Instr.OPE[&mi, $],{
					debug(machine) debugout("addInstruction %08X : %s", code.length, mi);
					code ~= mi.assemble();
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
	private this(in uint[] c)
	{
		code = c;
	}

	void run()
	{
		debug(machine) debugout("========");
		debug(machine) debugout("run = ");

		void printStack()
		{
			debug(machine) debugout("   stack = %(%04X %)", stack);
		}
		void printRegs()
		{
			debug(machine) debugout("    regs = ep:%08X, cp:%08X, sp:%08X", ep, cp, sp);
		}
		
		heap = new Heap();
		
		pc = 0;
		cp = 0;
		ep = 2;
		sp = 4;
		stack[0] = code.length;	// outermost old_pc
		stack[1] = 0;			// outermost old_ep
		stack[2] = 0;			// outermost env->up  ( = void)
		stack[3] = 0xBEEF;		// outermost env->size(placholder)
		
		//debug(machine) debugout("code = %(%08X %)", code);
		
		printRegs();
		printStack();
		
		while (pc < code.length)
		{
			auto save_pc = pc;
			
			Instruction.Fmt i;
			i.data = code[pc++];
			
			long getImm()
			{
				assert(pc + long.sizeof/uint.sizeof <= code.length);
				long imm = *cast(long*)(&code[pc]);
				pc += long.sizeof/uint.sizeof;
				return imm;
			}
			ulong getAddr()
			{
				return cast(ulong)getImm();
			}
			
			switch (i.ope) with (Instruction.Op)
			{
			case NOP:
				break;
			default:
			case HLT:
				debug(machine) debugout("%08x : HLT", save_pc);
				pc = code.length;
				break;
			
			case LDA:
				//auto adr = getAddr();
				debug(machine) debugout("%08x : LDA [@ R%s:%s]:%s -> R%s:%s",
						save_pc, 
						i.a.src, regs[i.a.src],
						memory(regs[i.a.src])[0],
						i.a.dst, regs[i.a.dst]);
				
				regs[i.a.dst] = memory(regs[i.a.src])[0];
				break;
			case LDB:
				debug(machine) debugout("%08x : LDB [R%s:%s + R%s:%s]:%s -> R%s:%s",
						save_pc, 
						i.a.src, regs[i.a.src],
						i.a.acc, regs[i.a.acc],
						stack[cast(size_t)(regs[i.a.src] + regs[i.a.acc])],
						i.a.dst, regs[i.a.dst]);
				regs[i.a.dst] = stack[cast(size_t)(regs[i.a.src] + regs[i.a.acc])];
				break;
			case LDI:
				auto imm = getImm();
				debug(machine) debugout("%08x : LDI #%s -> R%s:%s",
						save_pc,
						imm,
						i.l.dst, regs[i.l.dst]);
				regs[i.l.dst] = imm;
				break;
			case POP:
				debug(machine) debugout("%08x : POP [--sp] -> R%s:%s",
						save_pc,
						i.l.dst, regs[i.l.dst]);
				regs[i.l.dst] = stack[$-1];
				stack.length = stack.length - 1;
				
				printStack();
				break;
			
			case STA:
				auto adr = getAddr();
				assert(0);
				break;
			case STB:
				debug(machine) debugout("%08x : STB R%s:%s -> [R%s:%s + R%s:%s]",
						save_pc,
						i.a.src, regs[i.a.src],
						i.a.dst, regs[i.a.dst],
						i.a.acc, regs[i.a.acc]);
				stack[cast(size_t)(regs[i.a.dst] + regs[i.a.acc])] = regs[i.a.src];
				
				printStack();
				break;
			case PUSH:
				debug(machine) debugout("%08x : PUSH R%s:%s -> [sp++]",
						save_pc,
						i.s.src, regs[i.s.src]);
				stack.length = stack.length + 1;
				stack[$-1] = regs[i.s.src];
				
				printStack();
				break;
			
			case MOV:
				debug(machine) debugout("%08x : MOV R%s:%s -> R%s:%s",
						save_pc,
						i.a.src, regs[i.a.src],
						i.a.dst, regs[i.a.dst]);
				if (i.a.dst == SP.num)
					sp = regs[i.a.src], printStack();	// change stack size
				else
					regs[i.a.dst] = regs[i.a.src];
				break;
			case ADD:
				debug(machine) debugout("%08x : ADD R%s:%s + R%s:%s-> R%s:%s",
						save_pc,
						i.a.src, regs[i.a.src],
						i.a.acc, regs[i.a.acc],
						i.a.dst, regs[i.a.dst]);
				regs[i.a.dst] = regs[i.a.src] + regs[i.a.acc];
				break;
			case SUB:
				debug(machine) debugout("%08x : SUB R%s:%s - R%s:%s-> R%s:%s",
						save_pc,
						i.a.src, regs[i.a.src],
						i.a.acc, regs[i.a.acc],
						i.a.dst, regs[i.a.dst]);
				regs[i.a.dst] = regs[i.a.src] - regs[i.a.acc];
				break;
			case MUL:
				debug(machine) debugout("%08x : MUL R%s:%s * R%s:%s-> R%s:%s",
						save_pc,
						i.a.src, regs[i.a.src],
						i.a.acc, regs[i.a.acc],
						i.a.dst, regs[i.a.dst]);
				regs[i.a.dst] = regs[i.a.src] * regs[i.a.acc];
				break;
			case DIV:
				debug(machine) debugout("%08x : DIV R%s:%s / R%s:%s-> R%s:%s",
						save_pc,
						i.a.src, regs[i.a.src],
						i.a.acc, regs[i.a.acc],
						i.a.dst, regs[i.a.dst]);
				regs[i.a.dst] = regs[i.a.src] / regs[i.a.acc];
				break;
			
			case CALL:
				//auto adr = getAddr();
				debug(machine) debugout("%08X : CALL R%s:%s (pc=%08X)",
						save_pc,
						i.a.src, regs[i.a.src],
						label_to_pc[cast(size_t)regs[i.a.src]]);
				
				stack[cp_t] = cast(Word)pc;	// fill ret_pc
				ep = cp + ContSize;
				pc = label_to_pc[cast(size_t)regs[i.a.src]];
				
				printStack();
				printRegs();
				break;
			case RET:
				printRegs();
				debug(machine) debugout("%08X : RET (ret_pc=%08X, ret_ep=%08X)",
						save_pc,
						stack[cp_t+0],
						stack[cp_t+1]);
				
				ep = stack[cp_t+1];
				pc = cast(size_t)stack[cp_t+0];
				sp = cp;
				if (ep != 0)	//todo
					cp = cp - (memory(ep)[1] + ContSize);
				
				printStack();
				break;
			case PUSH_CONT:
				debug(machine) debugout("%08X : PUSH_CONT",
						save_pc);
				
				cp = sp;
				stack ~= 0xBEEF;	// ret_pc(filled by CALL)
				stack ~= ep;		// ret_ep
				
				printStack();
				break;
			case PUSH_ENV:
				debug(machine) debugout("%08X : PUSH_ENV",
						save_pc);
				
				auto cont_ep = &(ep());
				auto env_top = *cont_ep;
				while (env_top != 0)
				{
					if (Heap.isHeapPtr(env_top))
						break;
					auto size = cast(size_t)stack[cast(size_t)env_top + 1];
					auto env = stack[cast(size_t)env_top .. cast(size_t)env_top+size];
					auto ptr = heap.alloc(env.length);
					auto mem = heap.memory(ptr);
					mem[] = env[];
					*cont_ep = ptr;
					
					cont_ep = cast(Ptr*)&mem[0];
					env_top = *cont_ep;
				}
				
				printStack();
				break;
			case ENTER:
				debug(machine) debugout("%08X : ENTER %s",
						save_pc,
						i.l.disp);
				
				stack.length = stack.length + i.l.disp;
				
				printStack();
				break;
			}
		}
		
		debug(machine) debugout("RV[R%s] = %s", RV.num, regs[RV.num]);	// debug, print RV
	}

private:
	/// 
	void error(string msg)
	{
		class RuntimeException : Exception
		{
			this()
			{
				super(format("RuntimeError[%08X] : %s", pc, msg));
			}
		}

		throw new RuntimeException();
	}

	Word[] memory(Ptr ptr)
	{
		if (Heap.isHeapPtr(ptr))
			return heap.memory(ptr);
		else
			return stack[cast(size_t)ptr .. $];
	}

	class Heap
	{
		Word[][Ptr] chunklist;
		Ptr[] freeids;
		enum HeapMask = 0x8000_0000_0000_0000;
		
		static bool isHeapPtr(Ptr ptr) pure
		{
			return (ptr & HeapMask) != 0;
		}
		
		Ptr alloc(size_t n)
		out(ptr){ assert(isHeapPtr(ptr)); }
		body{
			Ptr id;
			if (freeids.length)
				id = freeids[0], freeids = freeids[1..$];
			else
				id = chunklist.length;
			
			if (id>=HeapMask) error("heap overflow");
			
			auto chunk = chunklist[id] = new Word[n];
			
			return cast(Ptr)(id | HeapMask);
		}
		Word[] memory(Ptr ptr)
		in{ assert(isHeapPtr(ptr)); }
		body{
			auto id = cast(Ptr)(ptr & ~HeapMask);
			if (auto pmem = id in chunklist)
			{
				return *pmem;
			}
			else
			{
				error("invalid pointer");
				assert(0);
			}
		}
		void free(Ptr ptr)
		in{ assert(isHeapPtr(ptr)); }
		body{
			auto id = cast(Ptr)(ptr & ~HeapMask);
			if (auto pmem = id in chunklist)
			{
				chunklist.remove(id);
				delete *pmem;
			}
			else
			{
				error("invalid pointer");
				assert(0);
			}
		}
		
	}
}
+/