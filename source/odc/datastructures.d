/*
some datastructures; adr didnt have an opinion on the design decisions soooo:
super set of the range api, im adding a .key but trying to mantain some phoboes compadity
I dont give a shit about safety so not any of that complexity
opSlice makes ranges
config flags? nah, just edit the code if you dislike the behavor
whats size_t? no int everywhere

api target:
	~= //todo mojo in thoery wants bool returns
	+=
	.reset
	[].map
	.remove(delete is taken)
	.last
	.lastindex (typeof(lastindex) being important)
	CONSIDER: mojo says he defines isEmpty and IsFull(I dont see these as generic tho, is 2darray suppose to scan for zeros?)
	.isstatic
	
*/
module odc.datastructures;

/* RANT: fail-safe vs fail-dangerous

todo
*/
//copied from `belongsinstd` see that for rants, TODO: merge something and import that
template innate(T,T startingvalue=T.init,discrimination...){
	T innate=startingvalue;
}
//TODO: belongs elsewhere
int clamp(int i,int a,int b){
	if(i<a){return a;}
	if(i>b){return b;}
	return i;
}
unittest{
	assert((-5).clamp(0,5)==0);
	assert(1.clamp(0,5)==1);
	assert(10.clamp(0,5)==5);
}
//copied from min viable std TODO: belongs elsewhere
auto tuple(T...)(T args){
	struct Tuple{
		enum istuple=true;
		T expand; alias expand this;
	}
	return Tuple(args);
}
unittest{
	auto foo=tuple(1,"hi");
	assert(foo[0]==1);
	assert(foo[1]=="hi");
	auto bar=tuple();
}
auto totuple(T)(T a) if(is(typeof(a.istuple)))=>a;
auto totuple(T)(T a) if( ! is(typeof(a.istuple)))=>tuple(a);
auto maybetuple(T...)(T a){
	static if(T.length==1){
		return a[0];
	} else {
		return tuple(a);
}}
struct simplerange(D){
	D* data;
	int key;
	int until;
	ref front()=>(*data)[key];
	void popFront(){key++;}
	bool empty()=>key>=until;
	int length()=>until-key;
}

//CONSIDER: mojo calls this fixedarray
struct maxlengtharray(T,int N){
	T[N] data;
	int length;
	alias opDollar=length;
	ref opIndex(int i)=>data[i.clamp(0,$-1)];
	void opOpAssign(string op:"~")(T a){
		data[length++]=a;
	}
	/*CONSIDER: by abstracting this im changing the behavoir to not react when you append 
elements live, I consider this as a down side, phoboes cant react to it so its not 
compaditity issue, but others think its correct;tradeoffs between line count and enabling my 
hacks; would it be possible to make simple range know?*/
	auto opSlice()=>simplerange!(typeof(this))(&this,0,length);
	//auto opSlice(){
	//	struct range{
	//		maxlengtharray!(T,N)* parent;
	//		int key;
	//		auto front()=>(*parent)[key];
	//		void popFront(){key++;}
	//		bool empty()=>(*parent).length<=key;
	//	}
	//	return range(&this);
	//}
	void reset(){length=0;}
	void remove(int i){
		foreach(j;i..length--){
			data[j]=data[j+1];
	}}
	void removefast(int i){//swaping changes the order and is therefore less correct, meta-programming vs you know what your doing tradeoff //TODO test
		data[i]=data[$-1];
		length--;
	}
}
struct set(T){
	typeof(null)[T] data;
	void opOpAssign(string op:"~")(T a){
		data[a]=null;
	}
	bool opIndex(T a)=>(a in data)!is null;
	void opIndexAssign(T a,T b){
		//import std;
		//writeln(a," ",b);
		remove(b);
		this~=a;
	}
	void opIndexOpAssign(string op)(T a,T b){
		remove(b);
		this~=mixin("b",op,"a");
	}
	void remove(T a){
		data.remove(a);
	}
	void reset(){data=null;}
	auto opSlice()=>data.byKey;//TODO: make work with .key
}

/* RANT:
theres a choice between indexing 2d arrays by vector2 or a tuple, I decided on tuple based on 
this syntax test:
struct foo{
	void opIndex(int i,int j){
		i.writeln;
		j.writeln;
	}
}
unittest{
	foo f;
	f[1,2];
	f[AliasSeq!(3,4)];
}
*/

/* RANT: I rember arguing this with snar about 2d vs nd arrays; my position is that 99% of 
cases will be 2d, *maybe* 5% 3d, so the complexity trade off is mental masterbaition;
I would not upgrade this to an nd array unless like 3 poeple say they want one thats strictly >3d
-monkyyy
*/
struct array2d(T,int W,int H){
	T[W*H] data;
	ref opIndex(int i,int j)=>data[i%W+j*W];
	ref opIndex(int i)=>data[i];
	ref opIndex(T)(T i)if(T.istuple)=>this[i.expand];
	deprecated("WARN: ~= on a static datastructure is incoherent, the behavoir here is hacky and its only by luck if it works as expected")
	void opOpAssign(string op:"~")(T a){//TODO: bug adr about pargma(warn)
		data[innate!(int,0,array2d!(T,W,H))++]=a;
		//leave it here anyway for testing and metaprogramming
		//NOTE: will not work correctly with .reset
	}
	void reset(){
		foreach(ref e;data){
			e=T.init;
	}}
	void remove(I)(I args){this[args]=T.init;}//unnessery but I want a delete api
	auto opSlice(){//TODO: make the 2d slice api
		struct range{
			array2d!(T,W,H)* parent;
			int x,y;
			auto key()=>tuple(x,y);
			ref front()=>(*parent)[x,y];
			void popFront(){
				if(++x>=W){
					x-=W;
					y++;
			}}
			bool empty()=>y>=H;
		}
		return range(&this);
	}
}
//unittest{
//	array2d!(int,3,5) foo;
//	foo[0,0]=10;
//	foo[1,0]=1;
//	foo[0,1]=5;
//	foo[2,4]=9;
//	foo~=1;
//	import std;
//	foo.printkeys;
//}

struct ringarray(T,int N){//note: spelling cuircluar hard
	T[N] data;
	int start,end;
	void opOpAssign(string op:"~")(T a){
		data[end++]=a;
		if(start>=N&&end>N){
			start-=N;end-=N;
		}
	}
	auto opSlice()=>simplerange!(typeof(this))(&this,0,length);
	ref opIndex(int i)=>data[(i+start)%N];
	//CONSIDER: whats a correct-ish way to delete from an overflowed ringbuffer?
	void remove(int i){
		if(i==0){
			start++;
			return;
		}
		if(end-start>N){assert(0,"not yet implimented");}
		//CONSIDER: do I care to make this decide between which direction it slides? O(N) vs O(N/2)?
		foreach(j;i..length-1){
			this[j]=this[j+1];
		}
		end--;
	}
	//TODO: removefast
	void reset(){
		start=0;
		end=0;
	}
	int length()=>end-start;
}
//TODO: stress test ring array after bursting and several random writes and deletions

struct stack(T,int N=-1){
	static if(N==-1){
		T[] data;
		void remove(int i){
			foreach_reverse(j;0..i){
				this[j+1]=this[j];
			}
			data=data[0..$-1];
		}
		void reset(){data=[];}
	} else {
		maxlengtharray!(T,N) data;
		void remove(int i)=>data.remove(length-i-1);
		void reset()=>data.reset;
	}
	void opOpAssign(string op:"~")(T a){
		data~=a;
	}
	auto length()=>cast(int)data.length;
	ref opIndex(int i)=>data[$-i-1];
	auto opSlice()=>simplerange!(typeof(this))(&this,0,length);
}
//--- lazy temp-ish functions
void print(D)(D data){
	import std;
	"[".write;
	foreach(e;data[]){
		e.write;
		','.write;
	}
	"]".writeln;
}
void printheader(string F=__FUNCTION__)(){
	import std;
	F.writeln;
}
void printkeys(D:set!T,T)(D data)=>data.print;//CONSIDER: should this hack be perminate because printing keys is incoherent for sets or should keyed ranges be so offical and everywhere that because sets keys are thier "index" it should be printed anyway
void printkeys(D)(D data){
	import std;
	auto r=data[];
	"[".write;
	while( ! r.empty){
		write(r.key,":",r.front,",");
		r.popFront;
	}
	"]".writeln;
}
import std.algorithm: pmap=map;
import std.algorithm: pfilter=filter;
import std.algorithm: preduce=fold;

//auto filter(alias F,R){//nm filter is harder to impliment then map
//	struct fil{
//		R r;
//		
auto map(alias F,R)(R r){
	struct map_{
		R r;
		auto front()=>F(r.front);
		void popFront(){r.popFront;}
		bool empty()=>r.empty;
		auto key()()=>r.key;
	}
	return map_(r);
}
//--- tests

void test1(D)(){
	//import std;
	//writeln("test1 for "~D.stringof);
	printheader;
	D foo;
	foreach(i;0..5){
		foo~=i;
	}
	foo.print;
	foo[3]=1000;
	foo.print;
	foo[2]*=100;
	foo.print;
	foo~=5;
	foo.remove(1);
	foo.printkeys;
	foo.reset;
	foo.print;
}
void test2(D)(){
	printheader;
	D foo;
	foreach(i;0..5){
		foo~=i;
	}
	import std;
	foo[].pfilter!(a=>a!=0)
		.pmap!(a=>a*100)
		.preduce!((a,b)=>a+b)(1)
		.writeln;
}
void test3(D)(){
	printheader;
	D foo;
	foreach(i;0..5){
		foo~=i;
	}
	auto keytype=foo[].key;
	maxlengtharray!(typeof(keytype),100) keys;
	auto r=foo[].map!(a=>a*20);
	while( ! r.empty){
		if(r.front> 30){
			keys~=r.key;
		}
		r.popFront;
	}
	keys.print;
	foreach(e;keys[]){
		foo.remove(e);
	}
	foo.printkeys;
}

unittest{
	alias mla=maxlengtharray!(int,10);
	alias s=set!int;
	alias d=array2d!(int,3,5);
	alias r=ringarray!(int,10);
	alias k=stack!(int,10);
	alias c=stack!int;
	test1!mla;
	//test1!s;
	//test1!d;
	//test1!r;
	test1!k;
	test1!c;
	test2!mla;
	//test2!s;
	//test2!d;
	//test2!r;
	test2!k;
	test2!c;
	test3!mla;
	////test3!s;//doesnt work yet
	//test3!d;
	//test3!r;
	test3!k;//NOTE: incoherent test for stacks due to reverse order of removal; CONSIDER: api for bulk removal by key?
	test3!c;
}
