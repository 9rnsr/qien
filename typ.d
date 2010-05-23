module typ;

import std.algorithm;
import std.typecons;
import debugs;


alias ulong id_t;
alias id_t TyVar;	//struct TyVar	{ id_t v; alias v this; string toString(){return format("%s", v);} }
alias id_t MetaVar;	//struct MetaVar	{ id_t v; alias v this; string toString(){return format("%s", v);} }


/// 
class Tycon
{
	enum Tag{
		INT,REAL,STR,UNIT,ARROW,
	//	ARRAY,RECORD,
		TYFUN,UNIQ
	}
	Tag tag;
	union{
		//string[] fieldnames;
		struct{ TyVar[] tprms; Ty tyfn; }	//TYFUN
		struct{ Tycon tycon; id_t uniq; }	//UNIQ
	}
	
	private this(Tag tag){
		this.tag = tag;
	}
	bool opEquals(Tag tag) const{
		return this.tag == tag;
	}
	
	string toString(){
		final switch( tag ){
		case Tag.INT:		return "Int";
		case Tag.REAL:		return "Real";
		case Tag.STR:		return "Str";
		case Tag.UNIT:		return "Unit";
		case Tag.ARROW:		return "Arrow";
		case Tag.TYFUN:		return format("TyFun(%s,%s)", tprms, tyfn);
		case Tag.UNIQ:		return format("Uniq(%s,%s)", tycon, uniq);
		}
	}
}

/// 
class Ty
{
	enum Tag{
		NIL,APP,VAR,POLY,META,//FIELD
	}
	Tag	tag;
	union{
		struct{Tycon tycon; Ty[] targs;};	//APP
		struct{TyVar tvnum;}				//VAR
		struct{TyVar[] tvars; Ty polty;}	//POLY
		struct{MetaVar mvnum; Ty actty;}	//META
	}
	
	private this(Tag tag){
		this.tag = tag;
	}
	
	bool opEquals(Tag tag) const{
		return this.tag == tag;
	}
	
	bool opIn_r(Ty t){		// tが内部に出現するか
	/+	final switch( tag ){
		case Tag.NIL:
			return false;
		case Tag.APP:
			return false;
		}+/
		return false;
	}
	
	string toString(){
		final switch( tag ){
		case Tag.NIL:	return "Nil";
		case Tag.APP:	return format("App(%s,%s)", tycon, targs);
		case Tag.VAR:	return format("Var(%s)", tvnum);
		case Tag.POLY:	return format("Poly(%s, %s)", tvars, polty);
		case Tag.META:	return actty ? actty.toString : format("Meta(%s)", mvnum);
		}
	}
}

/// 
class TyEnv
{
private:
	static class Data
	{
		//for Tycon
		id_t		uniq_count = 0;
		Tycon		TyconInt, TyconReal, TyconStr, TyconUnit, TyconArrow;
		
		//for Ty
		TyVar		tvar_count = 0;
		MetaVar		mvar_count = 0;
		
		// Ty singletons
		Ty			Nil, Int, Real, Str, Unit;
	}
private:
	Data	d;
	TyEnv	parent;

public:
	this(){
		auto d = new Data();
		d.TyconInt		= new Tycon(Tycon.Tag.INT);
		d.TyconReal		= new Tycon(Tycon.Tag.REAL);
		d.TyconStr		= new Tycon(Tycon.Tag.STR);
		d.TyconUnit		= new Tycon(Tycon.Tag.UNIT);
		d.TyconArrow	= new Tycon(Tycon.Tag.ARROW);
		d.Nil	= new Ty(Ty.Tag.NIL);
		d.Int	= App(d.TyconInt , []);
		d.Real	= App(d.TyconReal, []);
		d.Str	= App(d.TyconStr , []);
		d.Unit	= App(d.TyconUnit, []);
		this(d);
	}
	this(TyEnv p)
	in{ assert(p !is null); }
	body{
		this(p.d);
		parent = p;
	}
	private this(Data data){
		d = data;
	}
	
	Tycon Unique(Tycon tyc){		//環境の外部から使うのでTycon_prefixを付けない
		auto u = new Tycon(Tycon.Tag.UNIQ);
		u.tycon = tyc;
		u.uniq = d.uniq_count++;
		return u;
	}

public:
	TyVar newtyvar()		{ return d.tvar_count++; }
	MetaVar newmetavar()	{ 
	  version(none){
		//typ.d:153               return d.mvar_count++; }
		//0040b927: 8b4dfc                  mov ecx, [ebp-0x4]			;[edx+0x30] == d.mvar_count
		//0040b92a: 8b5108                  mov edx, [ecx+0x8]			;
		//0040b92d: 8b4230                  mov eax, [edx+0x30]			;d.mvar_countをedx:eaxに取り出し
		//0040b930: 8b5234                  mov edx, [edx+0x34]			;	->ここでEDXを破壊してしまう
		//0040b933: 83423001                add dword [edx+0x30], 0x1	;間接参照でd.mvar_countをIncrement
		//0040b937: 83523400                adc dword [edx+0x34], 0x0	;
		//0040b93b: c9                      leave
		//0040b93c: c3                      ret
		return d.mvar_count++;
	  }else{
		//typ.d:154               auto tmp = d.mvar_count;
		//0040b931: 8b4dec                  mov ecx, [ebp-0x14]			;[edx] == d.mvar_countとする
		//0040b934: 8b5108                  mov edx, [ecx+0x8]			;
		//0040b937: 83c230                  add edx, 0x30				;
		//0040b93a: 8b4a04                  mov ecx, [edx+0x4]			;d.mvar_countをecx:eaxに取り出し
		//0040b93d: 8b02                    mov eax, [edx]				;
		//0040b93f: 8945e4                  mov [ebp-0x1c], eax			;スタックにtmp == ecx:eaxを格納
		//0040b942: 894de8                  mov [ebp-0x18], ecx			;
		//typ.d:155               d.mvar_count++;
		//0040b945: 830201                  add dword [edx], 0x1		;間接参照でd.mvar_countをIncrement
		//0040b948: 83520400                adc dword [edx+0x4], 0x0	;
		//0040b94c: 89ca                    mov edx, ecx				;返り値edx:eax <= ecx:eax
		//typ.d:156               return tmp; }
		//0040b94e: c9                      leave
		//0040b94f: c3                      ret
		auto tmp = d.mvar_count;
		d.mvar_count++;
		return tmp;
	  }
	}
	
	Ty Nil()				{ return d.Nil;  }
	Ty Int()				{ return d.Int;  }
	Ty Real()				{ return d.Real; }
	Ty Str()				{ return d.Str;  }
	Ty Unit()				{ return d.Unit; }
	Ty Arrow(Ty[] a, Ty b)	{ return App(d.TyconArrow, a~b); }
	
	Ty App(Tycon tycon, Ty[] targs){
		auto t = new Ty(Ty.Tag.APP);
		t.tycon = tycon;
		t.targs = targs;
		return t;
	}
	Ty Var(TyVar n){
		auto t = new Ty(Ty.Tag.VAR);
		t.tvnum = n;
		return t;
	}
	Ty Poly(TyVar[] tvars, Ty polty){
		auto t = new Ty(Ty.Tag.POLY);
		t.tvars = tvars;
		t.polty = polty;
		return t;
	}
	Ty Meta(MetaVar n){
		auto t = new Ty(Ty.Tag.META);
		t.mvnum = n;
		return t;
	}

public:
	/// t1とt2を単一化する
	bool unify(Ty t1, Ty t2){
		auto ty12 = tie(t1, t2);
		
		if( (ty12 == tuple(Ty.Tag.APP, Ty.Tag.APP)) && (t1.targs.length == t2.targs.length) ){
			auto tyc12 = tie(t1.tycon, t2.tycon);
			
			if( tyc12 == tuple(Tycon.Tag.INT,	Tycon.Tag.INT)
			 || tyc12 == tuple(Tycon.Tag.REAL,	Tycon.Tag.REAL)
			 || tyc12 == tuple(Tycon.Tag.STR,	Tycon.Tag.STR)
			 || tyc12 == tuple(Tycon.Tag.UNIT,	Tycon.Tag.UNIT)
			 || tyc12 == tuple(Tycon.Tag.ARROW,	Tycon.Tag.ARROW)
		//	 || tyc12 == tuple(Tycon.Tag.ARRAY,	Tycon.Tag.ARRAY)
		//	 || tyc12 == tuple(Tycon.Tag.RECORD,Tycon.Tag.RECORD)
			){
				auto result = true;
				foreach( t; zip(t1.targs, t2.targs) ){
					result = result && unify(t.field[0], t.field[1]);
					if( !result ) break;
				}
				return result;
				
			}else if( t1.tycon == Tycon.Tag.TYFUN ){
				return unify(subst(t1.tycon.tyfn, makeSubstEnv(t1.tycon.tprms, t1.targs)), t2);
			}else if( t2.tycon == Tycon.Tag.TYFUN ){
				return unify(t1, subst(t2.tycon.tyfn, makeSubstEnv(t2.tycon.tprms, t2.targs)));
			}else if( tyc12 == tuple(Tycon.Tag.UNIQ, Tycon.Tag.UNIQ) ){
				if( t1.tycon.uniq == t2.tycon.uniq ){
					auto result = true;
					foreach( a; zip(t1.targs, t2.targs) ){
						result = result && unify(a.field[0], a.field[1]);
						if( !result ) break;
					}
					return result;
				}else{
					return false;
				}
			}else{
				return false;
			}
		
		}else if( ty12 == tuple(Ty.Tag.POLY, Ty.Tag.POLY) ){
			if( t1.tvars.length != t2.tvars.length ) return false;
			auto vars = new Ty[t2.tvars.length];
			foreach( i,ref v; vars ) v = Var(t2.tvars[i]);
			return unify(t1.polty, subst(t2.polty, makeSubstEnv(t1.tvars, vars)));
		
		}else if( ty12 == tuple(Ty.Tag.VAR, Ty.Tag.VAR) ){
			return t1.tvnum == t2.tvnum;
		
		}else if( t1 == Ty.Tag.NIL || t2 == Ty.Tag.NIL ){
			return true;//?
		}else{
			if( t1 == Ty.Tag.META ){
				if( t1.actty ){
					return unify(t1.actty, t2);
				}else if( t2 == Ty.Tag.APP && t2.tycon == Tycon.Tag.TYFUN ){
					return unify(t1, subst(t2.tycon.tyfn, makeSubstEnv(t2.tycon.tprms, t2.targs)));
				}else if( (t2 == Ty.Tag.META) && t2.actty ){
					return unify(t1, t2.actty);
				}else if( (t2 == Ty.Tag.META) && (t1.mvnum == t2.mvnum) ){
				//	debugout("  t1=%s#%s, t2=%s#%s", t1.mvnum, t1, t2.mvnum, t2);
					return true;
				}else if( t1 in t2 ){
					return false;
				}else{
					t1.actty = t2;
					return true;
				}
			}else if( t2 == Ty.Tag.META ){
				return unify(t2, t1);
			}else{
				return false;
			}
		}
	}

	/// tyのUnique/Metaを展開し、実際の型を取り出す
	Ty expand(Ty ty){
		if( ty == Ty.Tag.APP ){
			if( ty.tycon == Tycon.Tag.TYFUN ){
				return expand(subst(ty.tycon.tyfn, makeSubstEnv(ty.tycon.tprms, ty.targs)));
			}else if( ty.tycon == Tycon.Tag.UNIQ ){
				return expand(App(ty.tycon, ty.targs));
			}else{
				return ty;
			}
		}else if( ty == Ty.Tag.META ){
			return ty.actty ? expand(ty.actty) : ty;
		}else{
			return ty;
		}
	}

	/// tを汎化する
	Ty generalize(Ty t){
		// tの構造を書き換える
		
		Ty[MetaVar]	meta_ty;
		TyVar[]		tyvars;
		
		Ty g(Ty t){
			final switch( t.tag ){
			case Ty.Tag.META:
				//debugout(" %s", t);
				if( t.actty ){
					//debugout(" ->actty = %s", t.actty);
					return g(t.actty);
				}else if( auto pt = t.mvnum in meta_ty ){
					//debugout(" ->*pt = %s", *pt);
					return *pt;
				}else{
					auto v = newtyvar();
					tyvars ~= v;
					auto ty = Var(v);
					meta_ty[t.mvnum] = ty;
					//debugout(" ->newtyvar = %s", ty);
					return ty;;
				}
			case Ty.Tag.NIL:
				return Nil;
			case Ty.Tag.APP:
				if( t.tycon == Tycon.Tag.TYFUN ){
					return g(subst(t.tycon.tyfn, makeSubstEnv(t.tycon.tprms, t.targs)));
				}else{
					//debugout("g, App(_, ...), t=%s", t);
					foreach( ref a; t.targs ) a = g(a);
					return t;
				}
			case Ty.Tag.POLY:
				t.polty = g(t.polty);
				return t;
			case Ty.Tag.VAR:
				return t;
			}
		}
		
		auto poly_t = g(t);
		return Poly(tyvars, poly_t);
	}
	
	/// tを実体化する
	Ty instantiate(Ty t){
		if( t.tag == Ty.Tag.POLY ){
			auto ms = new Ty[t.tvars.length];
			foreach( ref m; ms ) m = Meta(newmetavar());
			//debugout(" instantiate t.tvars = [%s]", t.tvars);
			//debugout(" instantiate ms = [%s]", ms);
			return subst(t.polty, makeSubstEnv(t.tvars, ms));
		}else{
			return t;
		}
	}
	
	private Ty[TyVar] makeSubstEnv(TyVar[] vs, Ty[] ts)
	in{ assert(vs.length == ts.length); }
	body{
		typeof(return) result;
		for( size_t i=0; i<vs.length; ++i ){
			result[vs[i]] = ts[i];
		}
		return result;
	}
	
	/// tの中の型変数(Var)にenv内の定義から代入する
	Ty subst(Ty t, Ty[TyVar] env){
		final switch( t.tag ){
		case Ty.Tag.VAR:
			if( auto pt = t.tvnum in env ){
				return *pt;
			}else{
				return t;
			}
		case Ty.Tag.NIL:
			return Nil;
		case Ty.Tag.APP:
			auto args = t.targs;
			if( t.tycon == Tycon.Tag.TYFUN ){
				return subst(subst(t.tycon.tyfn, makeSubstEnv(t.tycon.tprms, args)), env);
			}else{
				auto subst2_res = new Ty[args.length];
				foreach( i,ref e ; subst2_res ) e = subst(args[i], env);
				return App(t.tycon, subst2_res);
			}
		case Ty.Tag.POLY:
		/+	auto ts = new Ty   [t.tvars.length];
			auto vs = new TyVar[t.tvars.length];
			foreach( i,x ; ts ){
				ts[i] = Var(newtyvar());
				vs[i] = x.tvnum;
			}
			auto u_ = subst(t.polty, makeSubstEnv(t.tvars, ts));
			return Poly(vs, subst(u_, env));+/
			return Poly(t.tvars, subst(t.polty, env));	//t.tvarsはenv内に現れないことが前提
		
		case Ty.Tag.META:
			return t.actty ? subst(t.actty, env) : t;
		}
	}

}



Tuple!(Ty.Tag, Ty.Tag) tie(Ty t1, Ty t2){
	return tuple(t1.tag, t2.tag);
}
Tuple!(Tycon.Tag, Tycon.Tag) tie(Tycon tc1, Tycon tc2){
	return tuple(tc1.tag, tc2.tag);
}
Tuple!(T, U)[] zip(T,U)(T[] t, U[] u){
	assert(t.length == u.length);
	auto z = new Tuple!(T, U)[min(t.length, u.length)];
	foreach( i,e ; z ) z[i] = tuple(t[i], u[i]);
	return z;
}



//void main(){
unittest{
	bool res;
	TyEnv tenv;
	Ty t1, t2;
	
	{	tenv = new TyEnv();
		t1 = tenv.Int;
		t2 = tenv.Meta(tenv.newmetavar());
		res = tenv.unify(t1, t2);
		assert(res);
		assert(t2.actty is t1);
		debugout("t1 = %s, t2 = %s", tenv.expand(t1), tenv.expand(t2));
	}
	{
		tenv = new TyEnv();
		t1 = tenv.Arrow([tenv.Int], tenv.Int);
		t2 = tenv.Meta(tenv.newmetavar());
		res = tenv.unify(t1, t2);
		assert(res);
		assert(t2.actty is t1);
		debugout("t1 = %s, t2 = %s", tenv.expand(t1), tenv.expand(t2));
	}
	{	tenv = new TyEnv();
		Ty al1, ar1;
		Ty al2, ar2;
		t1 = tenv.Arrow([al1=tenv.Int],  ar1=tenv.Int);
		t2 = tenv.Arrow([al2=tenv.Meta(tenv.newmetavar())], ar2=tenv.Meta(tenv.newmetavar()));
		res = tenv.unify(t1, t2);
		assert(res);
		assert(al2.actty is al1);
		assert(ar2.actty is ar1);
		debugout("t1 = %s, t2 = %s", tenv.expand(t1), tenv.expand(t2));
	}
/+	{	tenv = new TyEnv();
		auto xv = tenv.new_tyvars(1);
		auto v = tenv.Var(xv[0]);
		t1 = tenv.Poly(xv, tenv.Arrow([v], v));
		t2 = tenv.Arrow([tenv.Int], tenv.Int);
		res = tenv.unify(t1, t2);
		assert(res);
	//	assert(al2.actty is al1);
	//	assert(ar2.actty is ar1);
		debugout("t1 = %s, t2 = %s", tenv.expand(t1), tenv.expand(t2));
	}+/
	
	debugout("test ok");
}
