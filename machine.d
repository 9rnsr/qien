module machine;

import sym;
import assem;
import std.stdio;
import std.string;

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
union Instr
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
	LDA	= 0x10,	LDB	= 0x11,	LDI	= 0x12,
	STA	= 0x20,	STB	= 0x21,
	MOV	= 0x30,	ADD	= 0x31,	SUB	= 0x32,	MUL	= 0x33,	DIV	= 0x34,
}

class Instruction
{
	Instr i;
	union { ulong adr;	long imm; }
	
	this(Instr.L ld, uint adr)	{ i.l = ld, this.adr = adr; }
	this(Instr.L ld)			{ i.l = ld; }
	this(Instr.L ld, long imm)	{ i.l = ld, this.imm = imm; }
	
	this(Instr.S st, uint adr)	{ i.s = st, this.adr = adr; }
	this(Instr.S st)			{ i.s = st; }
	
	this(Instr.S st, long imm)	{ i.s = st, this.imm = imm; }
	this(Instr.A ac)			{ i.a = ac; }
	
	static LDA(uint adr, Temp dst) { return new Instruction(Instr.L(Op.LDA, R(dst), 0              ), adr); }
	static LDB(int disp, Temp dst) { return new Instruction(Instr.L(Op.LDB, R(dst), cast(short)disp)     ); }
	static LDI(long imm, Temp dst) { return new Instruction(Instr.L(Op.LDI, R(dst), 0              ), imm); }
	
	static STA(Temp src, uint adr) { return new Instruction(Instr.S(Op.STA, 0,               R(src)), adr); }
	static STB(Temp src, int disp) { return new Instruction(Instr.S(Op.STB, cast(short)disp, R(src))     ); }
	
	static MOV(Temp src,           Temp dst) { return new Instruction(Instr.A(Op.MOV, R(dst), 0,      R(src))); }
	static ADD(Temp src, Temp acc, Temp dst) { return new Instruction(Instr.A(Op.ADD, R(dst), R(acc), R(src))); }
	static SUB(Temp src, Temp acc, Temp dst) { return new Instruction(Instr.A(Op.SUB, R(dst), R(acc), R(src))); }
	static MUL(Temp src, Temp acc, Temp dst) { return new Instruction(Instr.A(Op.MUL, R(dst), R(acc), R(src))); }
	static DIV(Temp src, Temp acc, Temp dst) { return new Instruction(Instr.A(Op.DIV, R(dst), R(acc), R(src))); }
	
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
		
		case STA:	return format("STA R%s -> @%X",      i.s.src, adr);
		case STB:	return format("STB R%s -> [fp%s%s]", i.s.src, i.s.disp<0?"":"+", i.s.disp);
		
		case MOV:	return format("MOV R%s -> R%s",       i.a.src,          i.a.dst);
		case ADD:	return format("ADD R%s + R%s -> R%s", i.a.src, i.a.acc, i.a.dst);
		case SUB:	return format("SUB R%s - R%s -> R%s", i.a.src, i.a.acc, i.a.dst);
		case MUL:	return format("MUL R%s * R%s -> R%s", i.a.src, i.a.acc, i.a.dst);
		case DIV:	return format("DIV R%s / R%s -> R%s", i.a.src, i.a.acc, i.a.dst);
		}
	}
	
	const(uint[]) assemble() const
	{
		final switch (i.ope) with (Op)
		{
		case NOP:	return [cast(uint)NOP << 24];
		case HLT:	return [cast(uint)HLT << 24];
		
		case LDA:	return [i.data] ~ (cast(uint*)(&adr))[0 .. ulong.sizeof];
		case LDB:	return [i.data];
		case LDI:	return [i.data] ~ (cast(uint*)(&imm))[0 ..  long.sizeof];
		
		case STA:	return [i.data] ~ (cast(uint*)(&adr))[0 .. ulong.sizeof];
		case STB:	return [i.data];
		
		case MOV:	return [i.data];
		case ADD:	return [i.data];
		case SUB:	return [i.data];
		case MUL:	return [i.data];
		case DIV:	return [i.data];
		}
	}
}

class Machine
{
private:
	const(uint)[]	code;
	long[]			stack;
	long[256]		regs;
	uint			frame_ptr;

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

	void setStack(uint ofs, long val)
	{
		if (stack.length <= ofs)
			stack.length *= 2;
		stack[ofs] = val;
	}

	void run()
	{
		size_t pc = 0;
		
		while (pc < code.length)
		{
			auto save_pc = pc;
			
			Instr i;
			i.data = code[pc++];
			
			long getImm()
			{
				assert(pc + long.sizeof <= code.length);
				long imm = *cast(long*)(&code[pc]);
				pc += long.sizeof;
				return imm;
			}
			ulong getAddr()
			{
				return cast(ulong)getImm();
			}
			
			switch (i.ope) with (Op)
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
				assert(0);	//memory[adr] = stack[frame_ptr + i.l.disp;
				break;
			case LDB:
				writefln("%08x : LDB [fp%s%s]:%s -> R%s:%s",
						save_pc, 
						i.l.disp<0?"":"+", i.l.disp, stack[frame_ptr + i.l.disp],
						i.l.dst, regs[i.l.dst]);
				regs[i.l.dst] = stack[frame_ptr + i.l.disp];
				break;
			case LDI:
				auto imm = getImm();
				writefln("%08x : LDI imm:%s -> R%s:%s",
						save_pc,
						imm,
						i.l.dst, regs[i.l.dst]);
				regs[i.l.dst] = imm;
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
}

/+
alias ubyte Word;

ubyte[] reg(ubyte lhs, ubyte op2, ubyte dst)
{
	return [lhs, op2, dst];
}

ubyte[] reg(ubyte lhs, ubyte dst)
{
	return [lhs, 0, dst];
}

class Instruction
{
	Word[] instr;
	this(Word[] instr)
	{
		this.instr = instr;
	}
	
	static Instruction MOV(ubyte[] regs)
	{
		return new Instruction([cast(ubyte)Op.MOV] ~ regs);
	}
	static Instruction MOV2I(long imm, ubyte[] regs)
	{
		return new Instruction([cast(ubyte)Op.MOV2I] ~ regs ~ (cast(Word*)(&imm))[0 .. long.sizeof]);
	}
	static Instruction ADD(ubyte[] regs)
	{
		return new Instruction([cast(ubyte)Op.ADD] ~ regs);
	}
	static Instruction ADD3I(long imm, ubyte[] regs)
	{
		return new Instruction([cast(ubyte)Op.ADD3I] ~ regs ~ (cast(Word*)(&imm))[0 .. long.sizeof]);
	}
	
	const(Word[]) instruction() @property
	{
		return instr;
	}
	alias instruction this;
}
alias Instruction I;

const(Word)[] makeCode(const(Word[])[] code ...)
{
	const(Word)[] result;
	foreach (f; code)
		result ~= f;
	return result;
}

unittest
{
	auto m = new Machine(makeCode(
		I.MOV2I(10, reg(0, 0)),
		I.MOV2I(20, reg(1, 1)),
		I.ADD(reg(0, 1, 0))
	));
	m.run();
	assert(m.regs[0] == 30L);
	assert(m.regs[1] == 20L);
	
}
//void main(){}
+/
