module machine;

import sym;
import assem;
import std.stdio;
import std.string;

alias long Word;
alias ulong Ptr;

/**
*	LDA		@addr		-> $dst		[op:8][dst:8][---------:16] [addr:64]
	LDB		[fp+n]		-> $dst		[op:8][dst:8][     disp:16]
	LDI		#imm		-> $dst		[op:8][dst:8][---------:16] [imm :64]
	
	STA		$src		-> @addr	[op:8][---------:16][src:8] [addr:64]
	STB		$src		-> [fp+n]	[op:8][     disp:16][src:8]
	
	MOV		$src		-> $dst		[op:8][dst:8][---:8][src:8]
	ADD		$src ? $acc	-> $dst		[op:8][dst:8][acc:8][src:8]
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
		struct S { ubyte ope; short disp;           ubyte src; }	S s;
		struct A { ubyte ope; ubyte dst; ubyte acc; ubyte src; }	A a;
		uint data;
	}
	enum Op : ubyte
	{
		NOP	= 0x00,	HLT	= 0x01,
		LDA	= 0x10,	LDB	= 0x11,	LDI	= 0x12,		POP	= 0x13,
		STA	= 0x20,	STB	= 0x21,					PUSH= 0x23,
		
		MOV	= 0x30,	ADD	= 0x31,	SUB	= 0x32,	MUL	= 0x33,	DIV	= 0x34,
		
		PUSH_CONT,
		PUSH_ENV,
		CALL,
		RET,
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
	
	static LDA(uint adr, Temp dst) { return new Instruction(Fmt.L(Op.LDA, R(dst), 0              ), adr); }
	static LDB(int disp, Temp dst) { return new Instruction(Fmt.L(Op.LDB, R(dst), cast(short)disp)     ); }
	static LDI(long imm, Temp dst) { return new Instruction(Fmt.L(Op.LDI, R(dst), 0              ), imm); }
	static POP(Temp dst)           { return new Instruction(Fmt.L(Op.POP, R(dst), 0)); }
	
	static STA(Temp src, uint adr) { return new Instruction(Fmt.S(Op.STA, 0,               R(src)), adr); }
	static STB(Temp src, int disp) { return new Instruction(Fmt.S(Op.STB, cast(short)disp, R(src))     ); }
	static PUSH(Temp src)          { return new Instruction(Fmt.S(Op.PUSH, 0, R(src))); }
	
	static MOV(Temp src,           Temp dst) { return new Instruction(Fmt.A(Op.MOV, R(dst), 0,      R(src))); }
	static ADD(Temp src, Temp acc, Temp dst) { return new Instruction(Fmt.A(Op.ADD, R(dst), R(acc), R(src))); }
	static SUB(Temp src, Temp acc, Temp dst) { return new Instruction(Fmt.A(Op.SUB, R(dst), R(acc), R(src))); }
	static MUL(Temp src, Temp acc, Temp dst) { return new Instruction(Fmt.A(Op.MUL, R(dst), R(acc), R(src))); }
	static DIV(Temp src, Temp acc, Temp dst) { return new Instruction(Fmt.A(Op.DIV, R(dst), R(acc), R(src))); }
	
	static PUSH_CONT()		{ return new Instruction(Fmt.A(Op.PUSH_CONT, 0,0,0)); }
	static PUSH_ENV()		{ return new Instruction(Fmt.A(Op.PUSH_CONT, 0,0,0)); }
	static CALL(uint adr)	{ return new Instruction(Fmt.L(Op.PUSH_CONT, 0,0), adr); }
	static RET()			{ return new Instruction(Fmt.A(Op.PUSH_CONT, 0,0,0)); }
	
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
		
		case LDA:	return format("LDA R%s <- @%X",      i.l.dst, adr);
		case LDB:	return format("LDB R%s <- [fp%s%s]", i.l.dst, i.l.disp<0?"":"+", i.l.disp);
		case LDI:	return format("LDI R%s <- #%s",      i.l.dst, imm);
		case POP:	return format("POP R%s <- [--sp]",   i.l.dst);
		
		case STA:	return format("STA R%s -> @%X",      i.s.src, adr);
		case STB:	return format("STB R%s -> [fp%s%s]", i.s.src, i.s.disp<0?"":"+", i.s.disp);
		case PUSH:	return format("PUSH R%s -> [sp++]",  i.s.src);
		
		case MOV:	return format("MOV R%s -> R%s",       i.a.src,          i.a.dst);
		case ADD:	return format("ADD R%s + R%s -> R%s", i.a.src, i.a.acc, i.a.dst);
		case SUB:	return format("SUB R%s - R%s -> R%s", i.a.src, i.a.acc, i.a.dst);
		case MUL:	return format("MUL R%s * R%s -> R%s", i.a.src, i.a.acc, i.a.dst);
		case DIV:	return format("DIV R%s / R%s -> R%s", i.a.src, i.a.acc, i.a.dst);
		
		case PUSH_CONT:	return "PUSH_CONT";
		case PUSH_ENV:	return "PUSH_ENV";
		case CALL:		return format("CALL @%X", adr);
		case RET:		return "RET";
		}
	}
	
	const(uint[]) assemble() const
	{
		final switch (i.ope) with (Op)
		{
		case NOP:	return [cast(uint)NOP << 24];
		case HLT:	return [cast(uint)HLT << 24];
		
		case LDA:	return [i.data] ~ (cast(uint*)(&adr))[0 .. ulong.sizeof/uint.sizeof];
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
		case CALL:		return [i.data] ~ (cast(uint*)(&adr))[0 .. ulong.sizeof/uint.sizeof];
		case RET:		return [i.data];
		}
	}
}

class Machine
{
private:
	const(uint)[]	code;
	long[]			stack;
	long[256]		regs;
	size_t			fp;
	size_t			sp() @property { return stack.length; };
	size_t			pc;
	size_t			ep;
	size_t			cp;
	Heap			heap;
	
	enum ContSize = 2;	// ret_pc + ret_ep

public:
	this(Instruction[] instr=null)
	{
		addInstructions(instr);
	}

	private this(in uint[] c)
	{
		code = c;
	}
	
	void assemble(void delegate(void delegate(Instruction[]) send) dg)
	{
		dg(&addInstructions);
	}

/+	private void setStack(uint ofs, long val)
	{
		if (stack.length <= ofs)
			stack.length *= 2;
		stack[ofs] = val;
	}+/

	void run()
	{
		pc = 0;
		heap = new Heap();
		
		//debug writefln("%(%08X %)", code);
		
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
				writefln("%08x : HLT", save_pc);
				pc = code.length;
				break;
			
			case LDA:
				auto adr = getAddr();
				writefln("%08x : LDA @%X:%s -> R%s:%s",
						save_pc, 
						adr, "--",
						i.l.dst, regs[i.l.dst]);
				assert(0);	//memory[adr] = stack[fp + i.l.disp;
				break;
			case LDB:
				writefln("%08x : LDB [fp%s%s]:%s -> R%s:%s",
						save_pc, 
						i.l.disp<0?"":"+", i.l.disp, stack[fp + i.l.disp],
						i.l.dst, regs[i.l.dst]);
				regs[i.l.dst] = stack[fp + i.l.disp];
				break;
			case LDI:
				auto imm = getImm();
				writefln("%08x : LDI imm:%s -> R%s:%s",
						save_pc,
						imm,
						i.l.dst, regs[i.l.dst]);
				regs[i.l.dst] = imm;
				break;
			case POP:
				writefln("%08x : POP [--sp] -> R%s:%s",
						save_pc,
						i.l.dst, regs[i.l.dst]);
				regs[i.l.dst] = stack[$-1];
				stack.length = stack.length - 1;
				break;
			
			case STA:
				auto adr = getAddr();
				assert(0);
				break;
			case STB:
				writefln("%08x : STB R%s:%s -> [fp%s%s]",
						save_pc,
						i.s.src, regs[i.s.src],
						i.s.disp<0?"":"+", i.s.disp);
				stack[i.s.disp] = regs[i.s.src];
				break;
			case PUSH:
				writefln("%08x : PUSH R%s:%s -> [sp++]",
						save_pc,
						i.s.src, regs[i.s.src]);
				stack.length = stack.length + 1;
				stack[$-1] = regs[i.s.src];
				break;
			
			case MOV:
				writefln("%08x : MOV R%s:%s -> R%s:%s",
						save_pc,
						i.a.src, regs[i.a.src],
						i.a.dst, regs[i.a.dst]);
				regs[i.a.dst] = regs[i.a.src];
				break;
			case ADD:
				writefln("%08x : ADD R%s:%s + R%s:%s-> %s(%s)",
						save_pc,
						i.a.src, regs[i.a.src],
						i.a.acc, regs[i.a.acc],
						i.a.dst, regs[i.a.dst]);
				regs[i.a.dst] = regs[i.a.src] + regs[i.a.acc];
				break;
			case SUB:
				writefln("%08x : SUB R%s:%s - R%s:%s-> R%s:%s",
						save_pc,
						i.a.src, regs[i.a.src],
						i.a.acc, regs[i.a.acc],
						i.a.dst, regs[i.a.dst]);
				regs[i.a.dst] = regs[i.a.src] - regs[i.a.acc];
				break;
			case MUL:
				writefln("%08x : MUL R%s:%s * R%s:%s-> R%s:%s",
						save_pc,
						i.a.src, regs[i.a.src],
						i.a.acc, regs[i.a.acc],
						i.a.dst, regs[i.a.dst]);
				regs[i.a.dst] = regs[i.a.src] * regs[i.a.acc];
				break;
			case DIV:
				writefln("%08x : DIV R%s:%s / R%s:%s-> R%s:%s",
						save_pc,
						i.a.src, regs[i.a.src],
						i.a.acc, regs[i.a.acc],
						i.a.dst, regs[i.a.dst]);
				regs[i.a.dst] = regs[i.a.src] / regs[i.a.acc];
				break;
			
			case PUSH_CONT:
				writefln("%08X : PUSH_CONT",
						save_pc);
				
				cp = sp;
				stack ~= 0;			// ret_pc(filled by CALL)
				stack ~= ep;		// ret_ep
				break;
			case PUSH_ENV:
				Ptr ep_tmp = ep;
				auto cont_ep = &ep_tmp;
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
				ep = cast(size_t)ep_tmp;
				break;
			case CALL:
				auto adr = getAddr();
				writefln("%08X : CALL @%X",
						save_pc,
						adr);
				
				stack[cp] = cast(Word)pc;	// fill ret_pc
				ep = cp + ContSize;
				pc = cast(size_t)adr;
				break;
			case RET:
				writefln("%08X : RET",
						save_pc);
				
				ep = cast(size_t)stack[cp+1];
				pc = cast(size_t)stack[cp+0];
				stack.length = cp ;
				cp = cp - cast(size_t)(memory(ep)[1] + ContSize);
				break;
			}
		}
	}

private:
	void addInstructions(Instruction[] instr)
	{
		foreach (i; instr)
		{
			writefln("addInstructions : %s", i);
			code ~= i.assemble();
		}
	}

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
