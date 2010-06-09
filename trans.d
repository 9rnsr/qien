module trans;

import tree;
import temp;

import sym;
import debugs;
import std.algorithm, std.array;

import canon;

/+
	Temp	局所変数に対する抽象的な名前
	label	静的なメモリ番地に対する抽象的な名前

	structure Temp :
	sig
		eqtype temp
		val newtemp : unit -> temp
		structure Table : TABLE sharing type Table.key -> temp
		val makestring: temp -> string
		
		type label = Symbol.symbol			//テンポラリの無限集合から新しいテンポラリを返す
		val newlabel : unit -> label		//ラベルの無限集合から新しいラベルを返す
		val namedlabel : string -> label	//名前付きの新しいラベルを返す
	end
+/

/+
	Translate	（静的リンクを通じて）入れ子になった有効範囲の概念を扱う

	signature TRANSLATE =
	sig
		type level
		type access	//not the same as Frame.access
		
		val outermost : level
		val newLevel : (parent: level, name: Temp.label,
						formals: bool list) -> level
		val formals: level -> access list
		val allocLocal: level -> bool -> access
	end

	structure Translate : TRANSLATE = ...

	意味解析フェーズで、transDecはTranslate.newLevelを呼び出して新しい「入れ子レベル」を生成する
	さらにその関数はFrame.newFrameを呼び出して新しいフレームを生成する

	signature ENV =
	sig
		datatype enventry =
			  VarEntry of {access: Translate.acdess, ty: ty}
			| FunEntry of {level: Translate.level,
						   label:Temp.label,
						   formals: ty list, result: ty}
		...
	end


	type Translate.access = level * Frame.access
+/

template Translate(Frame)
{
public:
	/**
	 *
	 */
	class Level
	{
	public:
		/// 
		Access[] formals(){
			return acclist;
		}
		/// 
		Access allocLocal(bool escape){
			auto acc = new Access(this, frame.allocLocal(escape));
			acclist ~= acc;
			return acc;
		}
	private:
		Level parent;
		Frame frame;
		Access[] acclist;
		this(Level p, Frame f){
			parent = p;
			frame = f;
		}
	}
	
	/**
	 *
	 */
	class Access
	{
	private:
		Level			level;
		Frame.Access	access;
		this(Level lvl, Frame.Access acc){
			level = lvl;
			access = acc;
		}
	}
	
	/// 
	Level outermost;
	static this() { outermost = new Level(null, Frame.newFrame(namedLabel("__toplevel"), [])); }
	
	/// 
	Level newLevel(Level parent, Label name, bool[] formals){
		return new Level(parent, Frame.newFrame(name, true ~ formals));		//フレームポインタを追加
	}
	
	/// 
	void procEntryExit(Level level, Ex bodyexp){
		auto lx = linearize(unNx(bodyexp));
		frag ~= new Frame.Fragment(lx, level.frame);
	}
	static Frame.Fragment[] frag;
	
	/// 
	Frame.Fragment[] getResult(){
		return frag;
	}
	
	/// Translateによる処理の結果として生成されるIR
	class Ex
	{
	private:
		enum Tag{ EX, NX, CX }
		Tag tag;
		union{
			Exp ex;
			Stm nx;
			Stm delegate(Label t, Label f) cx;
		}
		this(Exp exp)								{ tag = Tag.EX; ex = exp; }
		this(Stm stm)								{ tag = Tag.NX; nx = stm; }
		this(Stm delegate(Label t, Label f) cnd)	{ tag = Tag.CX; cx = cnd; }
	public:
		string toString(){
			final switch( tag ){
			case Tag.EX:	return ex.toString;
			case Tag.NX:	return nx.toString;
			case Tag.CX:	return "Cx";	//todo
			}
		}
	}

	/// 
	Ex constInt(IntT v){
		return new Ex(VINT(v));
	}
//	/// 
//	Ex constReal(RealT v){
//		return new Ex(REAL(v));
//	}
	
	/// 
	Ex getVar(Level level, Access access){
		auto slink = Frame.frame_ptr;
		debugout("* %s", slink);
		while( level !is access.level ){
			slink = level.frame.exp(slink, level.frame.formals[static_link_index]);	//静的リンクを取り出す
			level = level.parent;
			debugout("* %s", slink);
		}
		return new Ex(level.frame.exp(slink, access.access));
	}
	/// 
	Ex getFun(Level level, Level bodylevel, Label label){
		auto funlevel = bodylevel.parent;
		auto slink = Frame.frame_ptr;
		while( level !is funlevel ){
			slink = level.frame.exp(slink, level.frame.formals[static_link_index]);	//静的リンクを取り出す
			level = level.parent;
		}
		return new Ex(VFUN(slink, label));
	}
	
	/// 
	Ex callFun(Ex fun, Ex[] args){
		return new Ex(CALL(unEx(fun), array(map!(unEx)(args))));
	}
	
	/// 
	Ex binAddInt(Ex lhs, Ex rhs){
		return new Ex(BIN(BinOp.ADD, unEx(lhs), unEx(rhs)));
	}
	/// 
	Ex binSubInt(Ex lhs, Ex rhs){
		return new Ex(BIN(BinOp.SUB, unEx(lhs), unEx(rhs)));
	}
	/// 
	Ex binMulInt(Ex lhs, Ex rhs){
		return new Ex(BIN(BinOp.MUL, unEx(lhs), unEx(rhs)));
	}
	/// 
	Ex binDivInt(Ex lhs, Ex rhs){
		return new Ex(BIN(BinOp.DIV, unEx(lhs), unEx(rhs)));
	}
	
	/// 
	Ex sequence(Ex s1, Ex s2){
		return new Ex(SEQ([unNx(s1), unNx(s2)]));
	}
	
	
	/**
	 * Params:
	 *   level:		クロージャが定義されるレベル
	 *   bodylevel:	クロージャ本体のレベル
	 *   label:		クロージャ本体のラベル
	 */
	Ex makeClosure(Level level, Level bodylevel, Label label){
		return new Ex(ESEQ(
			CLOS(label),						// クロージャ命令(escapeするFrameをHeapにコピーし、env_ptr==frame_ptrをすり替える)
			VFUN(Frame.frame_ptr, label)));		// 現在のframe_ptrとクロージャ本体のラベルの組＝クロージャ値
	}
	
	/// 
	Ex assign(Level level, Access access, Ex value){
		auto slink = Frame.frame_ptr;
		while( level !is access.level ){
			slink = level.frame.exp(slink, level.frame.formals[static_link_index]);	//静的リンクを取り出す
			level = level.parent;
		}
		return new Ex(MOVE(unEx(value), level.frame.exp(slink, access.access)));
	}

private:
	enum size_t static_link_index = 0;
	static Exp nilTemp;
	static this(){
		nilTemp = TEMP(newTemp("Nil"));
	}

public:
	Exp unEx(Ex exp){
		final switch( exp.tag ){
		case Ex.Tag.EX:
			return exp.ex;
		case Ex.Tag.NX:
			return ESEQ(exp.nx, VINT(0L));	//文は式として0を返す
		case Ex.Tag.CX:
			auto r = newTemp();
			auto t = newLabel(), f = newLabel();
			return ESEQ(
				SEQ([
					MOVE(VINT(1L), TEMP(r)),
					exp.cx(t, f),
					LABEL(f),
					MOVE(VINT(0L), TEMP(r)),
					LABEL(t)
				]),
				TEMP(r)
			);
		}
		return null;
	}
	Stm unNx(Ex exp){
		final switch( exp.tag ){
		case Ex.Tag.EX:
			return MOVE(exp.ex, nilTemp);
		case Ex.Tag.NX:
			return exp.nx;
		case Ex.Tag.CX:
			auto l = newLabel();
			return SEQ([exp.cx(l, l), LABEL(l)]);
		}
	}
	Stm delegate(Label, Label) unCx(Ex exp){
		final switch( exp.tag ){
		case Ex.Tag.EX:
			auto x = exp.ex;
			return delegate(Label t, Label f){
				assert(0);
				return Stm.init;	//todo
			};
		case Ex.Tag.NX:
			return delegate(Label t, Label f){
				assert(0);
				return Stm.init;	//todo
			};
		case Ex.Tag.CX:
			return exp.cx;
		}
	}
}

