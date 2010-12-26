import tree;
import sym;
import typecons.match;
import std.conv, std.string, std.stdio;
import std.metastrings;
import debugs;

import machine;

//debug = munch;

/+
class Instruction
{
	mixin TagUnion!(
		"OPE",	string, Temp[], Temp[], Label[],
		"LBL",	string, Label,
		"MOV",	Temp, Temp
	);
	string toString()
	{
		final switch (tag)
		{
		case Tag.OPE:	""
		}
	}
}
alias Instruction I;
+/
alias Instruction I;

class Munch
{
	Instruction[] munch(Stm[] stms)
	{
		code = [];
		
		foreach (s; stms)
			munchStm(s);
		
		return code;
	}

private:
	Instruction[] code;

	void emit(Instruction instr)
	{
		code ~= instr;
	}

	Temp munchExp(tree.Exp exp)
	{
		Temp		t;
		tree.Exp	e, e1, e2;
		long		n;
		BinOp		binop;
		
		static Temp result(void delegate(Temp) gen)
		{
			auto t = newTemp();
			gen(t);
			return t;
		}
		
		static string BinImmCode(string binop)
		{
			return mixin(expand!q{
				case BinOp.${binop}:
					if (MEM[TEMP[&t]] <<= e)
					{
						debug(munch) debugout("munchExp : BIN[BinOp.${binop}, VINT[&n] / MEM[TEMP[&t]]]");
						return result((Temp r){ emit(I.${binop}I(t, n, r)); });
					}
					else
					{
						debug(munch) debugout("munchExp : BIN[BinOp.${binop}, VINT[&n] / &e]");
						return result((Temp r){ emit(I.${binop}I(munchExp(e), n, r)); });
					}
					break;
			});
		}
		static string BinRegCode(string binop)
		{
			return mixin(expand!q{
				case BinOp.${binop}:
					debug(munch) debugout("munchExp : BIN[BinOp.${binop}, &e1, &e2]");
					emit(I.${binop}R(t1, t2, r));
					break;
			});
		}
		
		debug(munch) writefln("* munchExp : exp =");
		debug(munch) debugout(exp);
		return match(exp,
			BIN[&binop, VINT[&n], &e],{
				switch (binop)
				{
				mixin(BinImmCode("ADD"));
				mixin(BinImmCode("SUB"));
				mixin(BinImmCode("MUL"));
				mixin(BinImmCode("DIV"));
				default:	assert(0);
				}
			},
			BIN[&binop, &e, VINT[&n]],{
				switch (binop)
				{
				mixin(BinImmCode("ADD"));
				mixin(BinImmCode("SUB"));
				mixin(BinImmCode("MUL"));
				mixin(BinImmCode("DIV"));
				default:	assert(0);
				}
			},
			BIN[&binop, &e1, &e2],{
				return result((Temp r){
					auto t1 = munchExp(e1);
					auto t2 = munchExp(e2);
					switch (binop)
					{
					mixin(BinRegCode("ADD"));
					mixin(BinRegCode("SUB"));
					mixin(BinRegCode("MUL"));
					mixin(BinRegCode("DIV"));
					default:	assert(0);
					}
				});
			},
			MEM[&e],{
				debug(munch) debugout("munchExp : MEM[&e]");
				return result((Temp r){ ; });
			},
			TEMP[&t],{
				debug(munch) debugout("munchExp : TEMP[&t]");
				return t;
			},
			_,{
				assert(0);
				return result((Temp r){ ; });
			}
		);
	}

	void munchStm(tree.Stm stm)
	{
		long		n;
		Temp		t;
		tree.Exp	e, e1 ,e2;
		
		debug(munch) writefln("* munchStm : stm = ");
		debug(munch) debugout(stm);
		match(stm,
			MOVE[VINT[&n], MEM[TEMP[&t]]],{
				debug(munch) debugout("munchStm : MOVE[VINT[&n], MEM[&t]]");
				emit(I.MOVI(n, t));
			},
			MOVE[VINT[&n], &e],{
				debug(munch) debugout("munchStm : MOVE[VINT[&n], &e]");
				emit(I.MOVI(n, munchExp(e)));
				assert(0);
			},
			MOVE[&e1, &e2],{
				debug(munch) debugout("MOVE[&e1, &e2]");
				auto t1 = munchExp(e1);
				auto t2 = munchExp(e2);
				emit(I.MOVR(t1, t2));
			},
			MOVE[&t, &e],{
				debug(munch) debugout("munchStm : MOVE[&t, &e]");
				emit(I.MOVR(t, munchExp(e)));
			},
			_,{
				assert(0);
			}
		);
	}
}

/+
/**
 *
 */
class Fragment
{
	enum Tag{ PROC, STR };
	Tag tag;
	union{
		Tuple!(Instruction[])		p;
		Tuple!(Label, Constant!string)	s;
	}
	this(Instruction[] instr)
	{
		tag = Tag.PROC;
		p = tuple(instr);
	}
	this(Label label, Constant!string str)
	{
		tag = Tag.STR;
		s = tuple(label, str);
	}
	
	void debugOut()
	{
		final switch (tag)
		{
		case Tag.PROC:
			foreach (instr; p.field[0])
				writefln("%s", instr);
			break;
		case Tag.STR:
			return debugout(format("String: %s, %s", s.field[0], s.field[1]));
		}
	}
}
+/