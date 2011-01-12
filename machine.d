module machine;

import sym;
import frame;
import assem;
import typecons.tagunion;
import std.string;
import debugs;

debug = machine;

alias long Word;
alias ulong Ptr;

/**
*	LDA		[@src]		-> $dst		[op:8][dst:8][---:8][src:8]
	LDB		[ep+n]		-> $dst		[op:8][dst:8][     disp:16]
	LDI		#imm		-> $dst		[op:8][dst:8][---------:16] [imm :64]
	
	STA		$src		-> @addr	[op:8][src:8][---------:16] [addr:64]
	STB		$src		-> [ep+n]	[op:8][src:8][     disp:16]
	
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
	static LDB(int disp, Temp dst) { return new Instruction(Fmt.L(Op.LDB, R(dst), cast(short)disp)     ); }
	static LDI(long imm, Temp dst) { return new Instruction(Fmt.L(Op.LDI, R(dst), 0              ), imm); }
	static POP(Temp dst)           { return new Instruction(Fmt.L(Op.POP, R(dst), 0)); }
	
	static STA(Temp src, uint adr) { return new Instruction(Fmt.S(Op.STA,  R(src), 0), adr); }
	static STB(Temp src, int disp) { return new Instruction(Fmt.S(Op.STB,  R(src), cast(short)disp)); }
	static PUSH(Temp src)          { return new Instruction(Fmt.S(Op.PUSH, R(src), 0)); }
	
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
		
		case LDA:	return format("LDA R%s <- [@%X]",    i.a.dst, i.a.src);
		case LDB:	return format("LDB R%s <- [ep%s%s]", i.l.dst, i.l.disp<0?"":"+", i.l.disp);
		case LDI:	return format("LDI R%s <- #%s",      i.l.dst, imm);
		case POP:	return format("POP R%s <- [--sp]",   i.l.dst);
		
		case STA:	return format("STA R%s -> @%X",      i.s.src, adr);
		case STB:	return format("STB R%s -> [ep%s%s]", i.s.src, i.s.disp<0?"":"+", i.s.disp);
		case PUSH:	return format("PUSH R%s -> [sp++]",  i.s.src);
		
		case MOV:	return format("MOV R%s -> R%s",       i.a.src,          i.a.dst);
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
	long[3+256]		regs;	// todo 3 == FP+RV+NIL
	size_t			sp() @property { return stack.length; };
	size_t			pc;
	ref ulong		ep() @property { return *cast(ulong*)&regs[FP.num]; }	// one of the normal registers
	ref ulong		ep(ulong n) @property { return ep() = n, ep(); }
	size_t			cp;
	Heap			heap;
	
	size_t[uint]	label_to_pc;
	
	enum ContSize = 2;	// ret_pc + ret_ep

public:
	this()
	{
	}

	private this(in uint[] c)
	{
		code = c;
	}
	
	void assemble(void delegate(void delegate(Frame, Instr[]) send) dg)
	{
		debug(machine) debugout("========");
		debug(machine) debugout("instr[] = ");
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
		
		stack.length = 4;
		stack[0] = code.length;	// outermost old_pc
		stack[1] = 0;			// outermost old_ep
		stack[2] = 0;			// outermost env->up  ( = void)
		stack[3] = 0xFFFF;		// outermost env->size(placholder)
		
		pc = 0;
		ep = 2;
		cp = 0;
		
		//debug(machine) debugout("code = %(%08X %)", code);
		
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
				debug(machine) debugout("%08x : LDA R%s:%s <- [@ R%s:%s]:%s",
						save_pc,
						i.a.dst, regs[i.a.dst], 
						i.a.src, regs[i.a.src], memory(regs[i.a.src])[0]);
				
				regs[i.a.dst] = memory(regs[i.a.src])[0];
				break;
			case LDB:
				debug(machine) debugout("%08x : LDB R%s:%s <- [ep:%s %s %s]:%s",
						save_pc,
						i.l.dst, regs[i.l.dst], 
						ep, i.l.disp<0?"":"+", i.l.disp, stack[cast(size_t)ep + i.l.disp]);
				regs[i.l.dst] = stack[cast(size_t)ep + i.l.disp];
				break;
			case LDI:
				auto imm = getImm();
				debug(machine) debugout("%08x : LDI R%s:%s <- imm:%s",
						save_pc,
						i.l.dst, regs[i.l.dst],
						imm);
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
				debug(machine) debugout("%08x : STB R%s:%s -> [ep:%s %s %s]",
						save_pc,
						i.s.src, regs[i.s.src],
						ep, i.s.disp<0?"":"+", i.s.disp);
				stack[cast(size_t)ep + i.s.disp] = regs[i.s.src];
				
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
				
				stack[cp] = cast(Word)pc;	// fill ret_pc
				ep = cp + ContSize;
				//pc = cast(size_t)regs[i.a.src];	//cast(size_t)adr;
				pc = label_to_pc[cast(size_t)regs[i.a.src]];
				
				printStack();
				printRegs();
				break;
			case RET:
				printRegs();
				debug(machine) debugout("%08X : RET (ret_pc=%08X, ret_ep=%08X)",
						save_pc,
						stack[cp+0],
						stack[cp+1]);
				
				ep = stack[cp+1];
				pc = cast(size_t)stack[cp+0];
				stack.length = cp;
				if (ep != 0)	//todo
					cp = cp - cast(size_t)(memory(ep)[1] + ContSize);
				
				printStack();
				break;
			case PUSH_CONT:
				debug(machine) debugout("%08X : PUSH_CONT",
						save_pc);
				
				cp = sp;
				stack ~= 0xDDDD;	// ret_pc(filled by CALL)
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
		
		debug(machine) debugout("RV[R%s] = %s", 1, regs[1]);	// debug, print RV
	}

private:
	void addInstructions(Frame frame, Instr[] instr)
	{
		label_to_pc[frame.name.num] = code.length;
		debug(machine) debugout("label to pc : %s(@%s) -> %08X",
			frame.name, frame.name.num, code.length);
		
		foreach (i; frame.procEntryExit3(instr))
		{
			debug(machine) debugout("addInstruction %08X : %s", code.length, i);
			Instruction mi;
			code ~= 
				match(i,
					Instr.OPE[&mi, $],{ return mi.assemble(); },
					Instr.LBL[&mi, $],{ return mi.assemble(); },
					Instr.MOV[&mi, $],{ return mi.assemble(); }
				);
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
