module frame;

static import tree;

import sym;
import std.string;
import std.typecons;
import debugs;

/*
	関数Body毎に作られる、
	newFrameは関数毎の新しいFrameを生成して返す
	→nameは現在のFrameが作られた時のlabelを返す
	→formalsは引数のaccess listを返す
*/
/+
	signature FRAME =
	sig type frame
		type access
		val newFrame : {name:Temp.label, formals: bool list} -> frame
		val name : frame -> Temp.label
		val formals : frame -> access list
		val allocLocal : frame -> bool -> access
		
	end


	structure MipsFrame : FRAME = struct ... end


	Frame.newFrame{name=/g/, formals=[true, false,false]}


	structure MipsFrame : FRAME = struct ...
		
		datatype access = InFrame of int | InReg of Temp.temp


	Frame.allocLocal(f)(true)
	//FramePointerからのOffsetでInFrameアクセスを返す
+/

/**
 * VM向けFrame
 */
class VmFrame
{
	/**
	 * FrameやRegisterに保持された値へのアクセスを表現するクラス
	 */
	static class Slot
	{
	private:
		enum{ IN_REG, IN_FRAME }
		int tag;
		union{
			size_t index;
		}
		this(VmFrame f, bool esc){
			if( esc ){
				tag = IN_FRAME;
				index = f.formals.length;
			}else{
				tag = IN_REG;
			}
		}
	}
	
	/**
	 * 新しいFrameを生成する
	 */
	static VmFrame newFrame(Label label, bool[] formals){
		return new VmFrame(label, formals);
	}
	
	/**
	 * 
	 */
	Label name(){
		return namelabel;
	}
	
	/**
	 * 
	 */
	Slot[] formals(){
		return acclist;
	}
	
	/**
	 * 新しいローカル変数を確保する
	 * Params:
	 */
	Slot allocLocal(bool escape){
		auto acc = new Slot(this, /*escape*/true);	//常にescapeする
		acclist ~= acc;
		return acc;
	}
	
	static tree.Exp frame_ptr;
	static tree.Exp return_val;
	static this(){
		frame_ptr = tree.TEMP(newTemp("FP"));
		return_val = tree.TEMP(newTemp("RV"));
	}
	
	tree.Stm procEntryExit1(tree.Stm stm){
		return stm;	//todo 本来のprologue/epilogueコードを付加していない
	}
	
	tree.Exp exp(tree.Exp fp, Slot access){
		tree.Exp x;
		
		if( access.tag == Slot.IN_FRAME ){
			return tree.MEM(
				access.index > 0
					? tree.BIN(tree.BinOp.ADD, fp, tree.VINT(cast(IntT)(wordSize * access.index)))
					: fp
			);
		}else{
			assert(0);	//常にescapeする
		}
		
		
		return null;	//todo
	}
	
	static class Fragment
	{
		enum Tag{ PROC, STR };
		Tag tag;
		union{
			Tuple!(tree.Stm[], VmFrame)			p;
			Tuple!(Label, Const!string)	s;
		}
		this(tree.Stm[] body_stm, VmFrame frame){
			tag = Tag.PROC;
			p = tuple(body_stm, frame);
		}
		this(Label label, Const!string str){
			tag = Tag.STR;
			s = tuple(label, str);
		}
		
		void debugOut(){
			final switch( tag ){
			case Tag.PROC:
				foreach( s; p.field[0] ) debugout(s);
				break;
			case Tag.STR:	return debugout(format("String: %s, %s", s.field[0], s.field[1]));
			}
		}
	}

private:
	Label namelabel;
	Slot[] acclist;
	
	static size_t wordSize = 4;
	
	
	this(Label label, bool[] escapes){
		namelabel = label;
		foreach( esc; escapes ) allocLocal(esc);		//formalsを割り当て
	}
}


/*「エスケープ」の定義
	変数の定義スコープの内側に定義される関数からアクセスされる
	＝静的リンクを辿ってアクセスされる
	＝フレームに割り付ける必要がある


	structure FindEscape: sig val findEscape: Absyn.exp -> unit
	                      end =
	struct
		type depth = int
		type escEnv = (depth * bool ref) Symbol.table
		
		fun traverseVar(env:escEnv, d:depth, s:Absyn.var): unit = ...
		fun traverseExp(env:escEnv, d:depth, s:Absyn.exp): unit = ...
		fun traverseDecs(env, d, s:Absyn.dec list): escEnv = ...
		
		fun findEscape(prog: Absyn.exp) : unit = ...
	end
*/



struct FindEscape
{
	alias int Depth;
	
}


