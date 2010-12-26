module machine;

import sym;
import assem;
import std.stdio;
import std.string;

/**
	Instruction format
	
	[op:8] [op1:8, op2:8, dst:8] [imm:64]?
*/
enum Op : ubyte
{
	NOP		= 0x00,
	HLT		= 0x01,
	
	MOVR	= 0x10,
	MOVI	= 0x20,

	ADDR	= 0x30,		SUBR	= 0x31,		MULR	= 0x32,		DIVR	= 0x33,
	ADDI	= 0x40,		SUBI	= 0x41,		MULI	= 0x42,		DIVI	= 0x43,
}

class Instruction
{
	Op ope;
			Temp op1;
	union { Temp op2;	long imm; }
			Temp dst;
	
	this(Op ope, Temp op1, Temp op2, Temp dst)
	{
		this.ope = ope;
		this.op1 = op1;
		this.op2 = op2;
		this.dst = dst;
	}
	this(Op op, Temp op1, long imm, Temp dst)
	{
		this.ope = op;
		this.op1 = op1;
		this.imm = imm;
		this.dst = dst;
	}
	
	static MOVR(Temp op1,           Temp dst) { return new Instruction(Op.MOVR, op1, null, dst); }
	static MOVI(          long imm, Temp dst) { return new Instruction(Op.MOVI, null, imm, dst); }
	static ADDR(Temp op1, Temp op2, Temp dst) { return new Instruction(Op.ADDR, op1, op2, dst); }
	static SUBR(Temp op1, Temp op2, Temp dst) { return new Instruction(Op.SUBR, op1, op2, dst); }
	static MULR(Temp op1, Temp op2, Temp dst) { return new Instruction(Op.MULR, op1, op2, dst); }
	static DIVR(Temp op1, Temp op2, Temp dst) { return new Instruction(Op.DIVR, op1, op2, dst); }
	static ADDI(Temp op1, long imm, Temp dst) { return new Instruction(Op.ADDI, op1, imm, dst); }
	static SUBI(Temp op1, long imm, Temp dst) { return new Instruction(Op.SUBI, op1, imm, dst); }
	static MULI(Temp op1, long imm, Temp dst) { return new Instruction(Op.MULI, op1, imm, dst); }
	static DIVI(Temp op1, long imm, Temp dst) { return new Instruction(Op.DIVI, op1, imm, dst); }
	
	string toString()
	{
		final switch (ope) with (Op)
		{
		case NOP:	return "NOP";
		case HLT:	return "HLT";
		case MOVR:	return format("MOV  R%s -> R%s", op1, dst);
		case MOVI:	return format("MOVI #%s -> R%s", imm, dst);
		case ADDR:	return format("ADD  R%s + R%s -> R%s", op1, op2, dst);
		case SUBR:	return format("SUB  R%s - R%s -> R%s", op1, op2, dst);
		case MULR:	return format("MUL  R%s * R%s -> R%s", op1, op2, dst);
		case DIVR:	return format("DIV  R%s / R%s -> R%s", op1, op2, dst);
		case ADDI:	return format("ADDI R%s + #%s -> R%s", op1, imm, dst);
		case SUBI:	return format("SUBI R%s - #%s -> R%s", op1, imm, dst);
		case MULI:	return format("MULI R%s * #%s -> R%s", op1, imm, dst);
		case DIVI:	return format("DIVI R%s / #%s -> R%s", op1, imm, dst);
		}
	}
	
	const(ubyte[]) assemble() const
	{
		static ubyte R(const(Temp) t)
		{
			return cast(ubyte)t.num;	// todo
		}
		
		final switch (ope) with (Op)
		{
		case NOP:	return cast(ubyte[])[NOP,  0,      0,       0];
		case HLT:	return cast(ubyte[])[HLT,  0,      0,       0];
		case MOVR:	return cast(ubyte[])[MOVR, R(op1), 0,       R(dst)];
		case MOVI:	return cast(ubyte[])[MOVI, 0,      0,       R(dst)] ~ (cast(ubyte*)(&imm))[0 .. long.sizeof];
		case ADDR:	return cast(ubyte[])[ADDR, R(op1), R(op2), R(dst)];
		case SUBR:	return cast(ubyte[])[SUBR, R(op1), R(op2), R(dst)];
		case MULR:	return cast(ubyte[])[MULR, R(op1), R(op2), R(dst)];
		case DIVR:	return cast(ubyte[])[DIVR, R(op1), R(op2), R(dst)];
		case ADDI:	return cast(ubyte[])[ADDI, R(op1), 0,       R(dst)] ~ (cast(ubyte*)(&imm))[0 .. long.sizeof];
		case SUBI:	return cast(ubyte[])[SUBI, R(op1), 0,       R(dst)] ~ (cast(ubyte*)(&imm))[0 .. long.sizeof];
		case MULI:	return cast(ubyte[])[MULI, R(op1), 0,       R(dst)] ~ (cast(ubyte*)(&imm))[0 .. long.sizeof];
		case DIVI:	return cast(ubyte[])[DIVI, R(op1), 0,       R(dst)] ~ (cast(ubyte*)(&imm))[0 .. long.sizeof];
		}
	}
}

class Machine
{
private:
	const(ubyte)[] code;
	long[256] regs;

public:
	this(Instruction[] instr=null)
	{
		addInstructions(instr);
	}

	private this(in ubyte[] c)
	{
		code = c;
	}
	
	void assemble(void delegate(void delegate(Instruction[]) send) dg)
	{
		dg(&addInstructions);
	}

	void run()
	{
		size_t pc = 0;
		
		long getImm()
		{
			assert(pc + long.sizeof <= code.length);
			long imm = *cast(long*)(&code[pc]);
			pc += long.sizeof;
			return imm;
		}
		
		while (pc < code.length)
		{
			auto save_pc = pc;
			
			auto ope = code[pc++];
			auto op1 = code[pc++];
			auto op2 = code[pc++];
			auto dst = code[pc++];
			switch (ope) with (Op)
			{
			case NOP:
				break;
			default:
			case HLT:
				writefln("%08x : HLT", save_pc);
				pc = code.length;
				break;
			case MOVR:
				writefln("%08x : MOV R%s:%s -> R%s:%s",
						save_pc, op1, regs[op1], dst, regs[dst]);
				regs[dst] = regs[op1];
				break;
			case MOVI:
				auto imm = getImm();
				writefln("%08x : MOV imm:%s -> R%s:%s",
						save_pc, imm, dst, regs[dst]);
				regs[dst] = imm;
				break;
			case ADDR:
				writefln("%08x : ADD R%s:%s + R%s:%s-> %s(%s)",
						save_pc, op1, regs[op1], op2, regs[op2], dst, regs[dst]);
				regs[dst] = regs[op1] + regs[op2];
				break;
			case SUBR:
				writefln("%08x : SUB R%s:%s - R%s:%s-> R%s:%s",
						save_pc, op1, regs[op1], op2, regs[op2], dst, regs[dst]);
				regs[dst] = regs[op1] - regs[op2];
				break;
			case MULR:
				writefln("%08x : MUL R%s:%s * R%s:%s-> R%s:%s",
						save_pc, op1, regs[op1], op2, regs[op2], dst, regs[dst]);
				regs[dst] = regs[op1] * regs[op2];
				break;
			case DIVR:
				writefln("%08x : DIV R%s:%s / R%s:%s-> R%s:%s",
						save_pc, op1, regs[op1], op2, regs[op2], dst, regs[dst]);
				regs[dst] = regs[op1] / regs[op2];
				break;
			case ADDI:
				auto imm = getImm();
				writefln("%08x : ADD R%s:%s + imm:%s-> %s(%s)",
						save_pc, op1, regs[op1], imm, dst, regs[dst]);
				regs[dst] = regs[op1] + imm;
				break;
			case SUBI:
				auto imm = getImm();
				writefln("%08x : SUB R%s:%s - imm:%s-> %s(%s)",
						save_pc, op1, regs[op1], imm, dst, regs[dst]);
				regs[dst] = regs[op1] - imm;
				break;
			case MULI:
				auto imm = getImm();
				writefln("%08x : MUL R%s:%s * imm:%s -> R%s:%s",
						save_pc, op1, regs[op1], imm, dst, regs[dst]);
				regs[dst] = regs[op1] * imm;
				break;
			case DIVI:
				auto imm = getImm();
				writefln("%08x : DIV R%s:%s / imm:%s-> R%s:%s",
						save_pc, op1, regs[op1], imm, dst, regs[dst]);
				regs[dst] = regs[op1] / imm;
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
	static Instruction MOVI(long imm, ubyte[] regs)
	{
		return new Instruction([cast(ubyte)Op.MOVI] ~ regs ~ (cast(Word*)(&imm))[0 .. long.sizeof]);
	}
	static Instruction ADD(ubyte[] regs)
	{
		return new Instruction([cast(ubyte)Op.ADD] ~ regs);
	}
	static Instruction ADDI(long imm, ubyte[] regs)
	{
		return new Instruction([cast(ubyte)Op.ADDI] ~ regs ~ (cast(Word*)(&imm))[0 .. long.sizeof]);
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
		I.MOVI(10, reg(0, 0)),
		I.MOVI(20, reg(1, 1)),
		I.ADD(reg(0, 1, 0))
	));
	m.run();
	assert(m.regs[0] == 30L);
	assert(m.regs[1] == 20L);
	
}
//void main(){}
+/
