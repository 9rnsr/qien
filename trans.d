module trans;

static import tree;
static import temp;

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
	class Level
	{
	public:
		Access[] formals(){
			return acclist;
		}
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
	static this() { outermost = new Level(null, Frame.newFrame(temp.namedLabel("__toplevel"), [])); }
	
	/// 
	Level newLevel(Level parent, temp.Label name, bool[] formals){
		return new Level(parent, Frame.newFrame(name, true ~ formals));		//フレームポインタを追加
	}
	
	static Frame.Fragment[] frag;
	void procEntryExit(Level level, Exp bodyexp){
		auto lx = linearize(unNx(bodyexp));
		frag ~= new Frame.Fragment(lx, level.frame);
	}
	
	Frame.Fragment[] getResult(){
		return frag;
	}
	
	/// Translateによる処理の結果として生成されるIR
	class Exp
	{
	private:
		enum Tag{ EX, NX, CX }
		Tag tag;
		union{
			tree.Exp ex;
			tree.Stm nx;
			tree.Stm delegate(temp.Label t, temp.Label f) cx;
		}
		this(tree.Exp exp)										{ tag = Tag.EX; ex = exp; }
		this(tree.Stm stm)										{ tag = Tag.NX; nx = stm; }
		this(tree.Stm delegate(temp.Label t, temp.Label f) cnd)	{ tag = Tag.CX; cx = cnd; }
	public:
		string toString(){
			final switch( tag ){
			case Tag.EX:	return ex.toString;
			case Tag.NX:	return nx.toString;
			case Tag.CX:	return "Cx";	//todo
			}
		}
	}

	Exp constInt(IntT v){
		return new Exp(tree.VINT(v));
	}
//	Exp constReal(RealT v){
//		return new Exp(tree.REAL(v));
//	}
	
	/// 
	Exp getVar(Level level, Access access){
		auto slink = Frame.frame_ptr;
		debugout("* %s", slink);
		while( level !is access.level ){
			slink = level.frame.exp(slink, level.frame.formals[static_link_index]);	//静的リンクを取り出す
			level = level.parent;
			debugout("* %s", slink);
		}
		return new Exp(level.frame.exp(slink, access.access));
	}
	Exp getFun(Level level, Level bodylevel, temp.Label label){
		auto funlevel = bodylevel.parent;
		auto slink = Frame.frame_ptr;
		while( level !is funlevel ){
			slink = level.frame.exp(slink, level.frame.formals[static_link_index]);	//静的リンクを取り出す
			level = level.parent;
		}
		return new Exp(tree.VFUN(slink, label));
	}
	
	Exp callFun(Exp fun, Exp[] args){
		return new Exp(tree.CALL(unEx(fun), array(map!(unEx)(args))));
	}
	
	Exp binAddInt(Exp lhs, Exp rhs){
		return new Exp(tree.BIN(tree.BinOp.ADD, unEx(lhs), unEx(rhs)));
	}
	Exp binSubInt(Exp lhs, Exp rhs){
		return new Exp(tree.BIN(tree.BinOp.SUB, unEx(lhs), unEx(rhs)));
	}
	Exp binMulInt(Exp lhs, Exp rhs){
		return new Exp(tree.BIN(tree.BinOp.MUL, unEx(lhs), unEx(rhs)));
	}
	Exp binDivInt(Exp lhs, Exp rhs){
		return new Exp(tree.BIN(tree.BinOp.DIV, unEx(lhs), unEx(rhs)));
	}
	
	Exp sequence(Exp s1, Exp s2){
		return new Exp(tree.SEQ([unNx(s1), unNx(s2)]));
	}
	
	
	/**
	 * Params:
	 *   level:		クロージャが定義されるレベル
	 *   bodylevel:	クロージャ本体のレベル
	 *   label:		クロージャ本体のラベル
	 */
	Exp makeClosure(Level level, Level bodylevel, temp.Label label){
		return new Exp(tree.ESEQ(
			tree.CLOS(label),							// クロージャ命令(escapeするFrameをHeapにコピーし、env_ptr==frame_ptrをすり替える)
			tree.VFUN(Frame.frame_ptr, label)));		// 現在のframe_ptrとクロージャ本体のラベルの組＝クロージャ値
	}
	
	Exp assign(Level level, Access access, Exp value){
		auto slink = Frame.frame_ptr;
		while( level !is access.level ){
			slink = level.frame.exp(slink, level.frame.formals[static_link_index]);	//静的リンクを取り出す
			level = level.parent;
		}
		return new Exp(tree.MOVE(unEx(value), level.frame.exp(slink, access.access)));
	}

private:
	enum size_t static_link_index = 0;
	static tree.Exp nilTemp;
	static this(){
		nilTemp = tree.TEMP(temp.newTemp("Nil"));
	}

public:
	tree.Exp unEx(Exp exp){
		final switch( exp.tag ){
		case Exp.Tag.EX:
			return exp.ex;
		case Exp.Tag.NX:
			return tree.ESEQ(exp.nx, tree.VINT(0L));	//文は式として0を返す
		case Exp.Tag.CX:
			auto r = temp.newTemp();
			auto t = temp.newLabel(), f = temp.newLabel();
			return tree.ESEQ(
				tree.SEQ([
					tree.MOVE(tree.VINT(1L), tree.TEMP(r)),
					exp.cx(t, f),
					tree.LABEL(f),
					tree.MOVE(tree.VINT(0L), tree.TEMP(r)),
					tree.LABEL(t)
				]),
				tree.TEMP(r)
			);
		}
		return null;
	}
	tree.Stm unNx(Exp exp){
		final switch( exp.tag ){
		case Exp.Tag.EX:
			//auto t = temp.newTemp();	//不要な値を格納するテンポラリ
			return tree.MOVE(exp.ex, nilTemp/*tree.TEMP(t)*/);
		case Exp.Tag.NX:
			return exp.nx;
		case Exp.Tag.CX:
			auto l = temp.newLabel();
			return tree.SEQ([exp.cx(l, l), tree.LABEL(l)]);
		}
	}
	tree.Stm delegate(temp.Label, temp.Label) unCx(Exp exp){
		final switch( exp.tag ){
		case Exp.Tag.EX:
			auto x = exp.ex;
			return delegate(temp.Label t, temp.Label f){
				assert(0);
				return tree.Stm.init;	//todo
			};
		case Exp.Tag.NX:
			return delegate(temp.Label t, temp.Label f){
				assert(0);
				return tree.Stm.init;	//todo
			};
		case Exp.Tag.CX:
			return exp.cx;
		}
	}
}

