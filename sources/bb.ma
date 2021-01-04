mafile 40
  1 bb.m                 641     1750   0
  2 bb_decls.m         13104     2416   0
  3 bb_tables.m        50094    15546   0
  4 bb_pclcommon.m     36848    65669   0
  5 bb_lib.m           45044   102540   0
  6 msyslib.m          34947   147608   0
  7 mclib.m             3432   182577   0
  8 mlibnew.m          26089   186033   0
  9 mwindows.m         12837   212147   0
 10 bb_support.m       14700   225012   0
 11 bb_libsources.m      467   239743   0
 12 msyslib.m          34947   240235   1
 13 mlibnew.m          26089   275207   1
 14 mclib.m             3432   301319   1
 15 mwindows.m         12837   304777   1
 16 mwindll.m           2115   317639   1
 17 bb_lex.m           40760   319778   0
 18 bb_diags.m         14944   360564   0
 19 bb_start.m         23898   375534   0
 20 bb_help.txt         1089   399459   1
 21 bb_x64.m            2573   400572   0
 22 bb_genpcl.m        17023   403172   0
 23 bb_libpcl.m        11090   420222   0
 24 bb_blockpcl.m      47528   431341   0
 25 bb_genmcl.m        70619   478896   0
 26 bb_libmcl.m        45423   549542   0
 27 bb_mcldecls.m      13780   594994   0
 28 bb_stackmcl.m      27454   608803   0
 29 bb_optim.m          5769   636283   0
 30 ma_genss.m         47768   642078   0
 31 ma_decls.m          1699   689872   0
 32 ma_lib.m            2329   691595   0
 33 ma_objdecls.m       4345   693953   0
 34 ma_writeexe.m      27239   698327   0
 35 ma_writess.m        5187   725594   0
 36 ma_disasm.m        26507   730808   0
 37 bb_parse.m         93235   757341   0
 38 bb_name.m          20489   850601   0
 39 bb_type.m          77301   871115   0
 40 bb_export.m         3842   948443   0
=== bb.m 1/40 ===
mapmodule mm_gen => mm_genwx64
mapmodule bb_target => bb_x64



import bb_decls
import bb_start

proc start=

	addmodulemapping("mlib","mlibnew")
	addmodulemapping("clib","mclib")

	addmodulemapping("oslib","mwindows")

	addmodulemapping("osdll","mwindll")


	start_common('W','X64')
end
=== bb_decls.m 2/40 ===
import bb_tables
import bb_pclcommon

global const maxmodule=200
global const maxlibfile=50
global const maxsourcefile=1000

global type unit = ref unitrec


global record tokenrec =		!should be 32-byte record
	byte symbol
	byte subcode
	word16 spare
	word32 pos: (lineno:24, fileno:8)

	union
		ref strec symptr		!pointer to symbol table entry for name
		int64 value				!64-bit int
		real xvalue				!64-bit float
		word64 uvalue			!64-bit word
		ichar svalue			!pointer to string or charconst (not terminated)
		ref int128 pvalue128	!128-bit int/word
	end
end

global record overloadrec =
	int32 amode
	int32 bmode
	int32 rmode
	int16 moduleno
	int16 flags
	unit fncode
	ref overloadrec nextoverload
end

global record dllprocrec =
	ichar name
	ref proc address
	int dllindex
end

global record procrec =
	ref strec def
	ref procrec nextproc
end

global record fwdrec =
	ref fwdrec nextfwd
	int32 offset
	int16 reltype
	int16 seg
end

global record typenamerec=
	ref strec owner			!owner of scope where typename was encountered
							!moduleno required by resolvetypename can be derived from owner
	ref strec defa
	union
		ref strec defb
		ref strec def
	end
	ref int32 pmode
end

global record posrec=
	word32 pos: (lineno:24, fileno:8)
end

global record uflagsrec =
	[7]byte	codes
	byte	ulength
end

global record strec =
	ichar name
	ref strec owner
	ref strec deflist
	union
		ref strec deflistx
		ref pstrec pdef
	end
	ref strec nextdef
	ref strec nextdupl
	ref strec firstdupl			!point to generic version

	unit code			!var idata/proc body/taggedunion tag value/etc
	int32 mode

	byte namelen
	byte symbol
	byte nameid
	byte subcode

	union
		int32 index					!needs to hold pcindex (also indices for all symbols or .bc files)
		int32 labelno				!for mcl anonymous labels; and for proc labels?
	end
	int32 offset

	word32 pos: (lineno:24, fileno:8)
	byte flags: (isglobal:2, isstatic:1, used:1, txdone:1, circflag:1,
				 islet:1, haspdef:1)
	byte flags2: (isimport:1, iscimport:1, isqexport:1)
	byte moduleno
	byte namecat

	union
		struct				!when a proc
			ichar truename			!for imported name only
			ref strec paramlist

			byte asmused			!1 when proc contains asmcode
			byte dllindex			!for dllproc: which dll in dlltable
			byte extmodno			!for proc call chains: module no of proc owner
			byte fflang				!0 windowsff. etc.
			byte nretvalues			!function: number of return values (0 for proc)
			byte varparams			!0 or 1; variadic params in B and FF
			byte isthreaded			!0 or 1; variadic params in B and FF
		end

		struct				!when a record or record field
			ref strec equivfield
			uflagsrec uflags
			int32 baseclass
			byte bitfieldwidth		!width of bitfield in record
			byte align				!0, 2, 4, 8, 16 or 255 (auto-align)
			byte at					!0 or 1 if @ used (fields only)
			byte bitoffset		!0..31 for bitfields in records
		end

		struct				!when a param name
			ref strec nextparam
			byte parammode			!0=var_param, in_param, out_param
			byte optional			!0 or 1	
			byte variadic			!variadic parameter for B code
		end

		struct				!when a static or frame name
			unit equivvar
			byte equals				!0 or 1 if @ used (static/frame vars only)
		end

		struct						!macro param
			ref void macro_dummy	!needs nextparam
			ref strec nulldef		!generic st entry
		end

		struct						!when a tagged union
			int32 enumtagmode
		end


		[24]byte dummy
	end

		struct
			ref fwdrec fwdrefs	!fwd ref chain
			int16 importindex
			int16 regsize
			byte reftype			!AX fields
			byte segment
		end
	union
		int16 stindex		!label pass 2: 0, or 1-based index within coff symboltable
		int16 maxalign		!for record types (doesn't fit above)
	end
end

global record unitrec =
	byte tag				!kcode tag number
	byte hasa, hasb, hasc	!whether .a, .b or .c points to a unit/unitlist
	word32 pos: (lineno:24, fileno:8)

	unit nextunit

	union
		struct
			union
				unit			a
				ref strec		def
				ref strec		labeldef
				int64			value
				word64			uvalue
				real64			xvalue
				ichar			svalue
				int64			range_lower
			end

			union
				unit			b
				int64			range_upper
			end
		end
		int128					value128
		word128					uvalue128
		struct
			word64				low128
			word64				high128
		end
	end

	union
		unit			c
		[4]int16		cmpopindex
	end

	union						!misc stuff depends on tag
		struct					!const string
			word32 slength
			byte isastring
		end

		struct					!name
			byte dottedname		!for j_name: 1=resolved from fully qualified dotted seq
			byte avcode			!j_name for/autovars: 'I','T','S' = index/to/step autovars
		end

		union					!asssemreg/xreg/mem
			struct
				byte reg
				byte regix
				byte scale
				byte prefixmode
				byte regsize
				byte cond
				byte spare2,spare3
			end
			word64 reginfo
		end

		union					!for makelist
			word32 length		!number of elements
			byte makearray		!1 for makelist to create array-var not list-var
		end
		byte addroffirst	!1 for j_nameaddr when derived from &.name

		word32 offset			!for j_dot
		byte ifretflag		!1 when 'if' in return value path (force "if" in C target)
		int32 whenlabel		!label no associated with when expr; for recase

		int32 trylevel

		struct
			union
				int16 opindex		!op_add_i64 etc
				int16 fnindex		!sysfn_add_var etc
				int16 condcode		!pcl_eq etc; for j_eq etc
				int16 asmopcode		!for j_assem
				int16 bfcode
			end
		end
		int32 index
		[4]byte cmpgenop			!cmpchain: up to 8 genops
	end

	int32 mode
	union
		int32 convmode	!convert/typepun: target mode (will be widened to give unit mode)
		int32 memmode	!name/ptr/index/dot: void=LVALUE; non-void=RVALUE
	end
	byte moduleno
	byte initlet		!1 for an assignment that initialises a let
	byte isconst		!1 for j_const, and j_makerange with const range
	byte resultflag		!1 when the result of this unit is needed; 0=void or discarded
	byte genop			!generic operator for j_bin, incr etc

	byte istrueconst	!1 for actual "123" etc, not result of reduction
	[2]byte spare
end


global record modulerec =
	ichar name
	ref strec stmodule
	int fileno
	union
		ichar asmstr
		ichar clangstr
	end
	int strlength
	[maxmodule]byte importmap
	ref strec stinitproc
	ref tokenrec tklist
end

global const maxsearchdirs=10
global [maxsearchdirs]ichar searchdirs
global int nsearchdirs=0

global ref strec stprogram		!root into the symbol table
global ref strec stmodule		!main module
global ref strec stsysmodule	!optional sys module (needed for name resolving)
global ref strec alldeflist		!link together all (user) symbols

global tokenrec lx				!provides access to current token data

global [0..maxmodule]modulerec moduletable
global [0..maxmodule]ichar inputfiles
global [0..maxlibfile]ichar libfiles
global [0..maxsourcefile]ichar sourcefilenames
global [0..maxsourcefile]ichar sourcefilepaths
global [0..maxsourcefile]ichar sourcefiletext
global [0..maxsourcefile]int sourcefilesizes
global [0..maxsourcefile]byte issupportfile
global int nmodules
global int nsourcefiles
global int ninputfiles
global int nlibfiles

global [0..maxsourcefile]ichar mafilenames
global [0..maxsourcefile]int mafilesizes
global [0..maxsourcefile]int mafileoffsets
global [0..maxsourcefile]ichar mafiletext
global [0..maxsourcefile]byte mafilefileno			!0 or index into sourcefile tables
global [0..maxsourcefile]byte mafilesupport			!1 means support file eg. for strinclude
global int nmafiles
global ichar mafilesource

global ref strec currmodule
global int currmoduleno				!used when compiling modules

global const int maxtype=6'000

global int ntypes

global [0..maxtype]ref strec ttnamedef
global [0..maxtype]ref strec	ttowner		!for	ttlowerexpr/rtlengthexpr

global [0..maxtype]int32	ttbasetype		!basetype
global [0..maxtype]ichar	ttname

global [0..maxtype]int32	ttsize
global [0..maxtype]byte	ttsizeset
global [0..maxtype]int32	ttlower 		!.lbound (default 1)
global [0..maxtype]int32	ttlength 		!elements in array/record/tuple
global [0..maxtype]ref[]int32	ttmult 	!ttlength elements in tuple

global [0..maxtype]unit	ttdimexpr		!length, lower:length, or lower..upper

global [0..maxtype]int32	tttarget 		!for array/ref types
global [0..maxtype]int32	ttkeytype 		!for dict
global [0..maxtype]byte	ttusercat
global [0..maxtype]int32	ttlineno

global [0..maxtype]byte	tttabtype
global [0..maxtype]byte	tttabtype2
global [0..maxtype]byte	ttpcltype
global [0..maxtype]byte	ttcat
global [0..maxtype]byte	ttcat2

global [0..maxtype]byte	ttisint			!is i8 i16 i32 i64 i128
global [0..maxtype]byte	ttisword			!is u8 u16 u32 u64 u128
global [0..maxtype]byte	ttisreal			!is r32 r64
global [0..maxtype]byte	ttisinteger		!is i8..i64/u8..u64/c8..c64
global [0..maxtype]byte	ttisallnum		!all numeric types including short/decimal
global [0..maxtype]byte	ttismainnum		!all numerics excl short
global [0..maxtype]byte	ttisshort		!is i8/i16/i32/u8/u16/u32/c8/c16
global [0..maxtype]byte	ttisref			!is a pointer

global const int maxtypename=12'000
global [0..maxtypename]typenamerec typenames
global [0..maxtypename]posrec typenamepos
global int ntypenames

global [0..maxtype]byte typestarterset

global ref strec currproc

global int alineno=0

global int debug=0
global int assemmode=0

global ref procrec proclist,proclistx			!linked list of all procs
global int nproclist
global ref procrec staticlist,staticlistx		!linked list of all static
global int nstaticlist
global ref procrec constlist,constlistx		!linked list of all export consts
global int nconstlist

GLOBAL INT NUNITS

global const maxmodulemap=25
global [maxmodulemap]ichar genericmodules
global [maxmodulemap]ichar actualmodules
global int nmodulemap

global unit nullunit

global int targetbits=64
global int targetsize=8

global [20]ichar docstrings
global int ndocstrings

global const maxdlllib=50
global const maxdllproc=500

global int ndllnametable
global int ndllproctable
global [maxdlllib]ichar dllnametable
global [maxdlllib]word64 dllinsttable
global [maxdllproc]dllprocrec dllproctable

global int fverbose=1		!1=normal, 0=less verbose, 2/3 = more verbose

global int msyslevel=-1
global byte fvarnames=0		!display of names in asm/mcl

global byte fbundled=0		!1 when .ma file is being compiler
global ichar mafilename
global byte fwritema
global byte fwriteexports
global byte fwritedocs

global byte fexe
global byte fobj
global byte fwritelibs
global byte fshowtiming
global byte fshowss
global byte fshowpcl
global byte fshowmcl
global byte fshowast1
global byte fshowast2
global byte fshowast3
global byte fshowst
global byte fshowstflat
global byte fshowtypes
global byte fshowoverloads
global byte foptimise
global byte fshowasm
global byte fcheckunusedlocals=0
global byte fwindows
global byte flinux
global byte fx64
global byte fssonly

global byte dointlibs=1

global tabledata() []ichar passnames =
	(load_pass,		$),
	(parse_pass,	$),
	(fixup_pass,	$),
	(name_pass,		$),
	(type_pass,		$),
	(pcl_pass,		$),
	(mcl_pass,		$),		!all-inclusive up to this point (includes all prev passes)
	(asm_pass,		$),		!only one of these 3 will be done
	(obj_pass,		$),		!
	(exe_pass,		$),		!
	(dll_pass,		$),		!
	(run_pass,		$),		!will do up to .exe then run the .exe
end

global const clang_pass = asm_pass

global int passlevel=0
global int prodmode=0
global int debugmode=0

global ichar outfile					!one of the following two
global ichar destfilename				!nil, or sets outfilebin
global ichar destfilepath				!nil, or sets path (can't be mixed with destfilename)
global ichar destext					!default extension for dest file

global ref strec extendtypelist

global [0:jtagnames.len]ref overloadrec overloadtable

global const maxcclibs=10				!libs passed to gcc/tcc
global [maxcclibs]ichar cclibtable
global int ncclibs

global ichar infotext					!mainprog.txt for c target; nil if not used
=== bb_tables.m 3/40 ===
import bb_pclcommon

IMPORT BB_LIB


global tabledata() [0:]ichar jtagnames, [0:]byte jisexpr =




	(j_none=0,		$,		0), ! For tagname lookups when tag is zero
	(j_const,		$,		3), ! value/etc=value, typeno=type code
	(j_null,		$,		3), ! Place holder unit: means 'param no present' when used where a param is expected
	(j_name,		$,		3), ! def=nameptr
	(j_namelv,		$,		3), ! def=nameptr
	(j_block,		$,		0), ! a=L
	(j_stmtblock,	$,		0), ! a=L
	(j_decimal,		$,		3), ! svalue=str, slength
	(j_assem,		$,		0), ! svalue=str, slength
	(j_assemmacro,	$,		0), !
	(j_assemreg,	$,		0), !
	(j_assemxreg,	$,		0), !
	(j_assemmem,	$,		0), !


	(j_andl,		$,		2), ! a b	This group are for conditional expressions (no result)
	(j_orl,			$,		2), ! a b
	(j_xorl,		$,		2), ! a b
	(j_notl,		$,		1), ! a
	(j_istruel,		$,		1), ! a


	(j_makelist,	$,		3), ! a=L, b=[u], length=N; element list/lower bound expr
	(j_makerange,	$,		3), ! a b
	(j_makeset,		$,		3), ! a=L, length=N
	(j_makedict,	$,		3), !
	(j_makeslice,	$,		3), !
	(j_exprlist,	$,		3), ! a=u...	List of expressions, as (a;b;c,	0), rather than (a,b,c)
	(j_multexpr,	$,		3), !
	(j_returnmult,	$,		3), !

	(j_keyword,		$,		3), ! def=st entry
	(j_keyvalue,	$,		3), ! a b
	(j_assign,		$,		3), ! a b
	(j_deepcopy,	$,		3), ! a b
	(j_callfn,		$,		3), ! a b
	(j_new,			$,		3), ! newmode=T, a=L, length=N
	(j_destroy,		$,		0), ! a=L, length=N
	(j_clear,		$,		0), !

	(j_cmp,			$,		2), ! a b
	(j_cmpchain,	$,		1), ! a b
	(j_bin,			$,		2), ! a b
	(j_unary,		$,		1), ! a b
	(j_binto,		$,		2), ! a b
	(j_unaryto,		$,		1), ! a b
	(j_incr,		$,		3), ! a	++a

	(j_inrev,		$,		2), ! a b
	(j_inrange,		$,		2), ! a b
	(j_inset,		$,		2), ! a b
	(j_clamp,		$,		2), ! a b

	(j_flexptr,		$,		3), ! a b
	(j_stringz,		$,		3), ! a b
	(j_sliceptr,	$,		3), ! a b

	(j_index,		$,		3), ! a b		a[b]
	(j_indexlv,		$,		3), ! a b		a[b]
	(j_slice,		$,		3), ! a b		a[b]
	(j_dot,			$,		3), ! a b opcode	a.b; opcode=0/1/2 used for signalling in rx pass
	(j_dotlv,		$,		3), ! a b opcode	a.b; opcode=0/1/2 used for signalling in rx pass
	(j_dotindex,	$,		3), ! a b		a[b]
	(j_dotslice,	$,		3), ! a b		a[b]
	(j_anddotslice,	$,		3), ! a b		a[b]
	(j_anddotindex,	$,		3), ! a b		a[b]

	(j_ptr,			$,		3), ! a		a^
	(j_ptrlv,		$,		3), ! a		a^
	(j_addrof,		$,		3), ! a		&a
	(j_addroffirst,	$,		3), ! a		&a
	(j_convert,		$,		3), ! typeno=T a		T(a)			T
	(j_shorten,		$,		3), !
	(j_autocast,	$,		3), ! typeno=T a		T(a)			T
	(j_typepun,		$,		3), ! typeno=T a		T@(a)			T
	(j_typeconst,	$,		3), ! typeno=T			typeconst(T)
	(j_operator,	$,		3), ! opcode=opc
	(j_upper,		$,		3), ! a		$					T

	(j_bitwidth,	$,		1), ! a
	(j_bytesize,	$,		1), ! a
	(j_typeof,		$,		3), ! a
	(j_typestr,		$,		1), ! a
	(j_bitfield,	$,		3), ! a

	(j_minvalue,	$,		3), ! a
	(j_maxvalue,	$,		3), ! a


	(j_cvlineno,	$,		3), ! 
	(j_cvstrlineno,	$,		3), ! 
	(j_cvmodulename,$,		3), ! 
	(j_cvfilename,	$,		3), ! 
	(j_cvfunction,	$,		3), ! 
	(j_cvdate,		$,		3), ! 
	(j_cvtime,		$,		3), ! 
	(j_cvversion,	$,		3), ! 
	(j_cvtypename,	$,		3), ! 
	(j_cvtargetbits,$,		3), ! 
	(j_cvtargetsize,$,		3), ! 
	(j_cvtargetcode,$,		3), ! 
	(j_cvnil,		$,		3), ! 
	(j_cvpi,		$,		3), ! 
	(j_cvtrue,		$,		3), ! 
	(j_cvfalse,		$,		3), ! 

	(j_whenthen,	$,		0), ! a=L b=u
	(j_elsif,		$,		0), ! opcode=condcode, a
	(j_fmtitem,		$,		3), ! a b  x/fmtstr
	(j_nogap,		$,		3), ! 


	(j_callproc,	$,		0), ! a=fn b=L, length
	(j_return,		$,		0), ! a=x/nil
	(j_syscall,		$,		0), ! a=x or nil

	(j_to,			$,		0), ! a=N, b=body, c=tempvar/nil, def=name
	(j_if,			$,		3), ! condcode a=then b=else
	(j_longif,		$,		3), ! a=(elsif ...) b=else		L is series of kelsif pairs
	(j_forup,		$,		0), ! 
	(j_fordown,		$,		0), !
	(j_forall,		$,		0), !
	(j_forallrev,	$,		0), !
	(j_while,		$,		0), ! a=x b=u
	(j_repeat,		$,		0), ! a=u b=x
	(j_goto,		$,		0), ! a=x
	(j_labeldef,	$,		0), ! def=nameptr
	(j_restart,		$,		0), ! [a=x]
	(j_redo,		$,		0), ! [a=x]
	(j_next,		$,		0), ! [a=x]
	(j_exit,		$,		0), ! [a=x]
	(j_do,			$,		0), ! [a=u
	(j_case,		$,		3), ! a=x b=L [c=else]		L is series of whenthen pairs
	(j_docase,		$,		0), ! a=x b=L [c=else]
	(j_switch,		$,		3), ! a=x b=L [c=else]
	(j_doswitch,	$,		0), ! a=x b=L [c=else]
	(j_swap,		$,		0), ! a b
	(j_select,		$,		3), ! Not implemented
	(j_recase,		$,		0), ! Not implemented

	(j_print,		$,		0), ! [a=dev] b=L
	(j_println,		$,		0), ! [a=dev] b=L
	(j_fprint,		$,		0), ! [a=dev] b=fmtstr c=L
	(j_fprintln,	$,		0), ! [a=dev] b=fmtstr c=L
	(j_cprint,		$,		0), ! [a=dev] b=fmtstr c=L
	(j_cprintln,	$,		0), ! [a=dev] b=fmtstr c=L
	(j_sprint,		$,		0), !         b=L 
	(j_sfprint,		$,		0), !         b=L
	(j_read,		$,		0), ! [a=dev] b=L
	(j_readln,		$,		0), ! [a=dev] b=L
	(j_sread,		$,		0), ! [a=dev] b=L
	(j_sreadln,		$,		0), ! [a=dev] b=L
	(j_stop,		$,		0), ! [a=x]
	(j_try,			$,		0), ! a=try block; b=except list
	(j_except,		$,		0), ! a=except block; b=exception code list (constants)
	(j_yield,		$,		0), ! "
	(j_raise,		$,		0), ! "
	(j_eval,		$,		3), ! "
	(j_emitc,		$,		1), ! "
	(j_stack,		$,		0), ! "
	(j_unstack,		$,		0), ! "

	(j_dummy,		$,		3)
end

global tabledata() []ichar bitfieldnames=
	(bf_msb,		$),
	(bf_lsb,		$),
	(bf_msbit,		$),
	(bf_lsbit,		$),
	(bf_msw,		$),
	(bf_lsw,		$),
	(bf_odd,		$),
	(bf_even,		$),
end

global tabledata() [0:]ichar optypenames =
	(no_op=0,		$),
	(bin_op,		$),
	(mon_op,		$),
	(prop_op,		$),
end

global tabledata() []ichar symbolnames,
					[]byte symboloptypes,
					[]byte symbolgenops,
					[]byte symbolgentoops,
					[]byte symbolopprios,
					[]byte exprstarter =
	(errorsym,			$,			0,	0,	0,	0,	0),		! Lex error
	(dotsym,			".",		0,	0,	0,	0,	0),		! "."
	(lexdotsym,			$,			0,	0,	0,	0,	0),		! ".", used at bol to prefix lexical 
	(anddotsym,			"&.",		0,	0,	0,	0,	1),		! "&."
	(commasym,			",",		0,	0,	0,	0,	0),		! ","
	(semisym,			";",		0,	0,	0,	0,	0),		! ";"
	(colonsym,			":",		0,	0,	0,	0,	0),		! ":"
	(dcolonsym,			"::",		0,	0,	0,	0,	0),		! "::"
	(assignsym,			":=",		bin_op,	assign_op,	0,	1,	0),		! :=
	(deepcopysym,		"::=",		0,	0,	0,	1,	0),		! ::=
	(sendtosym,			"=>",		0,	0,	0,	0,	0),		! =>
	(lbracksym,			"(",		0,	0,	0,	0,	1),		! (
	(rbracksym,			")",		0,	0,	0,	0,	0),		! )
	(lsqsym,			"[",		0,	0,	0,	0,	1),		! [
	(rsqsym,			"]",		0,	0,	0,	0,	0),		! ]
	(lcurlysym,			"{",		0,	0,	0,	0,	0),		! {
	(rcurlysym,			"}",		0,	0,	0,	0,	0),		! }
	(ptrsym,			"^",		0,	0,	0,	0,	0),		! ^
	(barsym,			"|",		0,	0,	0,	0,	0),		! |
	(dbarsym,			"||",		0,	0,	0,	0,	0),		! ||
	(atsym,				"@",		0,	0,	0,	0,	0),		! @
	(datsym,			"@@",		0,	0,	0,	0,	0),		! @@
	(questionsym,		"?",		0,	0,	0,	0,	0),		! ?
	(addrsym,			"&",		0,	0,	0,	0,	1),		! &
	(daddrsym,			"&&",		0,	0,	0,	0,	0),		! &&
	(curlsym,			"~",		0,	0,	0,	0,	0),		! ~
	(rangesym,			"..",		bin_op,	makerange_op,	0,	5,	0),		! ..
	(ellipsissym,		"...",		0,	0,	0,	0,	0),		! ...
	(hashsym,			"#",		0,	0,	0,	0,	0),		! #


	(addsym,			"+",		bin_op,		add_op,		addto_op,	4,	1),
	(subsym,			"-",		bin_op,		sub_op,		subto_op,	4,	1),
	(mulsym,			"*",		bin_op,		mul_op,		multo_op,	3,	0),
	(divsym,			"/",		bin_op,		div_op,		divto_op,	3,	0),
	(idivsym,			"%",		bin_op,		idiv_op,	idivto_op,	3,	0),
	(iremsym,			"rem",		bin_op,		irem_op,	iremto_op,	3,	0),
	(iandsym,			"iand",		bin_op,		iand_op,	iandto_op,	4,	0),
	(iorsym,			"ior",		bin_op,		ior_op,		iorto_op,	4,	0),
	(ixorsym,			"ixor",		bin_op,		ixor_op,	ixorto_op,	4,	0),
	(shlsym,			"<<",		bin_op,		shl_op,		shlto_op,	3,	0),
	(shrsym,			">>",		bin_op,		shr_op,		shrto_op,	3,	0),
	(minsym,			"min",		bin_op,		min_op,		minto_op,	4,	1),
	(maxsym,			"max",		bin_op,		max_op,		maxto_op,	4,	1),
	(andlsym,			"and",		bin_op,		andl_op,	andlto_op,	7,	0),
	(orlsym,			"or",		bin_op,		orl_op,		orlto_op,	8,	0),
	(xorlsym,			"xor",		bin_op,		0,			0,			8,	0),

	(eqsym,				"=",		bin_op,		eq_op,		0,			6,	1),
	(cmpsym,			"cmp",		bin_op,		0,			0,			6,	1),
	(appendsym,			"append",	bin_op,		append_op,	appendto_op,4,	0),
	(concatsym,			"concat",	bin_op,		concat_op,	concatto_op,4,	0),
	(powersym,			"**",		bin_op,		power_op,	0,			2,	0),
	(samesym,			"==",		bin_op,		same_op,	0,			6,	0),
	(insym,				"in",		bin_op,		in_op,		0,			6,	0),
	(notinsym,			"notin",	bin_op,		notin_op,	0,			6,	0),
	(inrevsym,			"inrev",	0,			0,			0,			0,	0),

	(negsym,			"$neg",		mon_op,		neg_op,		0,			0,	1),
	(notlsym,			"not",		mon_op,		notl_op,	notlto_op,	0,	1),
	(istruelsym,		"istrue",	mon_op,		istruel_op,	istruelto_op,	0,	1),
	(inotsym,			"inot",		mon_op,		inot_op,	inotto_op,	0,	1),
	(abssym,			"abs",		mon_op,		abs_op,		absto_op,	0,	1),
	(signsym,			"sign",		mon_op,		sign_op,	0,			0,	1),
	(sqrtsym,			"sqrt",		mon_op,		sqrt_op,	0,			0,	1),
	(sqrsym,			"sqr",		mon_op,		sqr_op,		0,			0,	1),

	(propsym,				$,			prop_op,	0,			0,			0,	0),
	(mathsopsym,		$,		0,	0,	0,	0,	1),		! sin etc
	(maths2opsym,		$,		0,	0,	0,	0,	1),		! atan2 etc

	(bitfieldsym,		$,		0,	0,	0,	0,	0),		! Special bit selections
	(eolsym,			$,		0,	0,	0,	0,	0),		! End of line
	(eofsym,			$,		0,	0,	0,	0,	0),		! Eof seen
	(rawxnamesym,		$,		0,	0,	0,	0,	0),		! unassigned name, case-sensitive, that is never a reserved word
	(docstringsym,		$,		0,	0,	0,	0,	0),		! ! #comment used as documentation string
	(incrsym,			$,		0,	0,	0,	0,	1),		! 1/2 = ++/--; later may add +2 for x++/x--
	(intconstsym,		$,		0,	0,	0,	0,	1),		! 123 32 bits signed
	(decimalconstsym,	$,		0,	0,	0,	0,	1),		! 123 or 123.4 decimal
	(realconstsym,		$,		0,	0,	0,	0,	1),		! 123.4 64 bits
	(charconstsym,		$,		0,	0,	0,	0,	1),		! 'A' or 'ABCD'
	(wcharconstsym,		$,		0,	0,	0,	0,	1),		! 'A'W or 'ABCD'W (but don't have a syntax yet)
	(stringconstsym,	$,		0,	0,	0,	0,	1),		! "ABC"
	(astringconstsym,	$,		0,	0,	0,	0,	1),		! A"ABC"
	(wstringconstsym,	$,		0,	0,	0,	0,	1),		! "ABC"W

	(unitnamesym,		$,		0,	0,	0,	0,	0),		! 
	(namesym,			$,		0,	0,	0,	0,	1),		! identifier symbol
	(ksourcedirsym,		$,		0,	0,	0,	0,	0),		! 
	(regsym,			$,		0,	0,	0,	0,	0),		! x64 registers
	(xregsym,			$,		0,	0,	0,	0,	0),		! XMM registers
	(fregsym,			$,		0,	0,	0,	0,	0),		! ST registers
	(mregsym,			$,		0,	0,	0,	0,	0),		! MMX registers
	(jmpccsym,			$,		0,	0,	0,	0,	0),		! 
	(setccsym,			$,		0,	0,	0,	0,	0),		! 
	(movccsym,			$,		0,	0,	0,	0,	0),		! 
	(segnamesym,		$,		0,	0,	0,	0,	0),		! 
	(asmopcodesym,		$,		0,	0,	0,	0,	0),		! MOV etc

	(stdtypesym,		$,		0,	0,	0,	0,	1),		! INT, CHAR etc
	(machinetypesym,	$,		0,	0,	0,	0,	1),		! INTM etc
	(ktypeofsym,		$,		0,	0,	0,	0,	0),		! TYPEOF
	(ksubrangesym,		$,		0,	0,	0,	0,	0),		! SUBRANGE
	(koutsym,			$,		0,	0,	0,	0,	0),		! OUT
	(kicharsym,			$,		0,	0,	0,	0,	1),		! ICHAR
	(kifsym,			$,		0,	0,	0,	0,	1),		! 
	(kthensym,			$,		0,	0,	0,	0,	0),		! 
	(kelsifsym,			$,		0,	0,	0,	0,	0),		! 
	(kelsesym,			$,		0,	0,	0,	0,	0),		! 
	(kelsecasesym,		$,		0,	0,	0,	0,	0),		! 
	(kelseswitchsym,	$,		0,	0,	0,	0,	0),		! 
	(kelseselectsym,	$,		0,	0,	0,	0,	0),		! 
	(kendsym,			$,		0,	0,	0,	0,	0),		! 
	(kunlesssym,		$,		0,	0,	0,	0,	0),		! 
	(kcasesym,			$,		0,	0,	0,	0,	1),		! CASE
	(kdocasesym,		$,		0,	0,	0,	0,	0),		! DOCASE
	(krecasesym,		$,		0,	0,	0,	0,	0),		! RECASE
	(kwhensym,			$,		0,	0,	0,	0,	0),		! 
	(kforsym,			$,		0,	0,	0,	0,	0),		! FOR
	(ktosym,			$,		0,	0,	0,	0,	0),		! TO/DOWNTO
	(kbysym,			$,		0,	0,	0,	0,	0),		! 
	(kdosym,			$,		0,	0,	0,	0,	0),		! 
	(kwhilesym,			$,		0,	0,	0,	0,	0),		! 
	(krepeatsym,		$,		0,	0,	0,	0,	0),		! 
	(kuntilsym,			$,		0,	0,	0,	0,	0),		! 
	(kreturnsym,		$,		0,	0,	0,	0,	0),		! 
	(kstopsym,			$,		0,	0,	0,	0,	0),		! 
	(kloopsym,			$,		0,	0,	0,	0,	0),		! EXIT/NEXT/LOOP/REDO/RESTART
	(kgotosym,			$,		0,	0,	0,	0,	0),		! GO/GOTO
	(kswitchsym,		$,		0,	0,	0,	0,	0),		! SWITCH
	(kdoswitchsym,		$,		0,	0,	0,	0,	0),		! DOSWITCH
	(kprintsym,			$,		0,	0,	0,	0,	0),		! PRINT/PRINTLN/FPRINT/FPRINTLN
	(ksprintsym,		$,		0,	0,	0,	0,	0),		! SPRINT/SFPRINT
	(kreadsym,			$,		0,	0,	0,	0,	0),		! READ/READLN
	(ksreadsym,			$,		0,	0,	0,	0,	0),		! SREAD
	(ksreadlnsym,		$,		0,	0,	0,	0,	0),		! SREADLN
	(kprocsym,			$,		0,	0,	0,	0,	0),		! PROC
	(kfunctionsym,		$,		0,	0,	0,	0,	0),		! FUNCTION
	(klabelsym,			$,		0,	0,	0,	0,	0),		! LABEL
	(krecordsym,		$,		0,	0,	0,	0,	0),		! RECORD
	(kstructsym,		$,		0,	0,	0,	0,	0),		! STRUCT
	(kunionsym,			$,		0,	0,	0,	0,	0),		! UNION
	(ktaggedunionsym,	$,		0,	0,	0,	0,	0),		! TAGGEDUNION
	(kimportsym,		$,		0,	0,	0,	0,	0),		! IMPORT
	(kimportmodulesym,	$,		0,	0,	0,	0,	0),		! IMPORTDLL/IMPORTMODULE
	(kimportpathsym,	$,		0,	0,	0,	0,	0),		! IMPORTPATH
	(kmapmodulesym,		$,		0,	0,	0,	0,	0),		! MAPMODULE
	(ktypesym,			$,		0,	0,	0,	0,	0),		! TYPE
	(ktypealiassym,		$,		0,	0,	0,	0,	0),		! TYPEALIAS
	(kextendtypesym,	$,		0,	0,	0,	0,	0),		! EXTENDTYPE
	(krefsym,			$,		0,	0,	0,	0,	1),		! REF
	(kmutsym,			$,		0,	0,	0,	0,	0),		! MUT
	(kletsym,			$,		0,	0,	0,	0,	0),		! LET
	(kslicesym,			$,		0,	0,	0,	0,	0),		! SLICE/SLICE2D
	(karraysym,			$,		0,	0,	0,	0,	0),		! ARRAY
	(kdictsym,			$,		0,	0,	0,	0,	0),		! DICT
	(kmacrosym,			$,		0,	0,	0,	0,	0),		! MACRO
	(kexpandsym,		$,		0,	0,	0,	0,	0),		! EXPAND
	(koperatorsym,		$,		0,	0,	0,	0,	0),		! OPERATOR
	(kconstsym,			$,		0,	0,	0,	0,	0),		! 
	(kenumsym,			$,		0,	0,	0,	0,	0),		! 
	(knewsym,			$,		0,	0,	0,	0,	0),		! NEW
	(kdestroysym,		$,		0,	0,	0,	0,	0),		! DESTROY
	(kclearsym,			$,		0,	0,	0,	0,	0),		! CLEAR
	(kclasssym,			$,		0,	0,	0,	0,	0),		! CLASS
	(kfflangsym,		$,		0,	0,	0,	0,	0),		! JLANG CLANG WINDOWS HOST
	(kglobalsym,		$,		0,	0,	0,	0,	0),		! global
	(kstaticsym,		$,		0,	0,	0,	0,	0),		! STATIC

	(ktrysym,			$,		0,	0,	0,	0,	0),		! 
	(kexceptsym,		$,		0,	0,	0,	0,	0),		! 
	(kfinallysym,		$,		0,	0,	0,	0,	0),		! 
	(kraisesym,			$,		0,	0,	0,	0,	0),		! 
	(kyieldsym,			$,		0,	0,	0,	0,	0),		! 
	(kcastsym,			$,		0,	0,	0,	0,	1),		! CAST
	(ktypeconstsym,		$,		0,	0,	0,	0,	0),		! TYPECONST
	(compilervarsym,	$,		0,	0,	0,	0,	1),		! $lineno etc
	(dollarsym,			$,		0,	0,	0,	0,	1),		! to be used for current array upperbound; also tabledata names
	(kevalsym,			$,		0,	0,	0,	0,	0),		! EVAL
	(ktabledatasym,		$,		0,	0,	0,	0,	0),		! tabledata
	(kstacksym,			$,		0,	0,	0,	0,	0),		! STACK/UNSTACK
	(kclampsym,			$,		0,	0,	0,	0,	1),			! CLAMP
	(kswapsym,			$,		0,	0,	0,	0,	0),		! SWAP
	(kerrorsym,			$,		0,	0,	0,	0,	0),		! PC_ERROR etc
	(kassemsym,			$,		0,	0,	0,	0,	0),		! ASM/ASSEM
	(ksyscallsym,		$,		0,	0,	0,	0,	1),		! $get_procname etc
	(kemitcsym,			$,		0,	0,	0,	0,	0),		! EMITC

	(kdummysym,			$,		0,	0,	0,	0,	0),		!
end

global tabledata() []ichar sourcedirnames =
	(includedir,	$),
	(strincludedir,	$),
	(binincludedir,	$),
	(textincludedir,$),
	(defineunitdir,	$),
	(emitcdir,		$),
	(cclibdir,		$),
end


global tabledata() [0:]ichar fflangnames=
	(noff=0,		$), ! 
	(windowsff,		$), ! 
	(clangff,		$), ! 
	(mlangff,		$), ! 
	(callbackff,	$), ! 
end

global tabledata() [0:]ichar scopenames=
	(local_scope=0,		$), ! 
	(program_scope,		$), ! 
	(export_scope,		$), ! 
	(exportq_scope,		$), ! 
end

global tabledata() =
	(thousand_unit),
	(million_unit),
	(billion_unit),
	(kilo_unit),
	(mega_unit),
	(giga_unit)
end

global tabledata() [0:]ichar parammodenames=
	(var_param=0,		"Var "),
	(in_param,			"In "),
	(out_param,			"Out "),
	(optional_param,	"Opt "),
end

global tabledata() [0:]ichar namecatnames, [0:]byte qualifiedname =
	(normal_cat=0,	 	"-",		0),
	(proc_cat, 			"proc",		1),
	(globalproc_cat,	"gproc",	1),
	(dllproc_cat,		"dllproc",	0),
	(dllmodule_cat,		"dllmodule",0),
	(dllvar_cat,		"dllvar",	0),
	(static_cat,		"static",	1),
	(frame_cat,			"frame",	1),
end

global tabledata() [0:]ichar namenames, [0:]byte pclidtable, [0:]byte defaultnamecat =
	(nullid=0,		$,	0,				0),				!Not assigned (sometimes converted to genfieldid)
	(programid,		$,	0,				0),				!Main root
	(moduleid,		$,	module_name,	0),				!Current or imported module
	(dllmoduleid,	$,	0,				dllmodule_cat),		!
	(typeid,		$,	0,				0),				!Type name in type, proc or module
	(procid,		$,	proc_name,		proc_cat),		!Proc/method/function/op name
	(dllprocid,		$,	dllproc_name,	dllproc_cat),	!Dll Proc/function name
	(dllvarid,		$,	0,				dllvar_cat),	!Dll variable name
	(genprocid,		$,	0,				proc_cat),		!generic proc name
	(generatorid,	$,	0,				proc_cat),		!generator proc name
	(constid,		$,	0,				0),				!Named constant in type, proc or module
	(staticid,		$,	zstatic_name,	static_cat),	!Static in type or proc or module
	(frameid,		$,	frame_name,		frame_cat),		!Local var
	(paramid,		$,	param_name,		frame_cat),		!Local param
	(fieldid,		$,	0,				0),				!Field of Record or Class
	(genfieldid,	$,	0,				0),				!Generic Field of Record or Class
	(enumid,		$,	0,				0),				!Enum name, part of enum type only
	(labelid,		$,	label_name,		0),				!Label name in proc only
	(blockid,		$,	0,				0),				!Codeblock label name in proc only
	(aliasid,		$,	0,				0),				!Alias to another name
	(macroid,		$,	0,				0),				!Name of macro
	(macroparamid,	$,	0,				0),				!Macro formal parameter name
	(linkid,		$,	0,				0),				!Name in class defined in a base class
	(functionopid,	$,	0,				0),				!Function-operator
end

global tabledata []ichar stnames, []int stsymbols, []int stsubcodes=

	("if",			kifsym,			j_if),
	("then",		kthensym,		0),
	("elsif",		kelsifsym,		j_if),
	("else",		kelsesym,		0),
	("elsecase",	kelsecasesym,	j_case),
	("elseswitch",	kelseswitchsym,	j_switch),
	("case",		kcasesym,		j_case),
	("docase",		kdocasesym,		j_docase),
	("recase",		krecasesym,		j_recase),
	("when",		kwhensym,		0),
	("for",			kforsym,		0),
	("forall",		kforsym,		0),
	("to",			ktosym,			0),
	("downto",		ktosym,			1),
	("by",			kbysym,			0),
	("do",			kdosym,			0),
	("end",			kendsym,		0),
	("while",		kwhilesym,		0),
	("repeat",		krepeatsym,		0),
	("until",		kuntilsym,		0),
	("always",		kuntilsym,		1),
	("return",		kreturnsym,		0),
	("yield",		kyieldsym,		0),
	("stop",		kstopsym,		0),
	("restart",		kloopsym,		j_restart),
	("redo",		kloopsym,		j_redo),
	("loop",		kloopsym,		j_redo),
	("next",		kloopsym,		j_next),
	("exit",		kloopsym,		j_exit),
	("goto",		kgotosym,		0),
	("go",			kgotosym,		1),
	("switch",		kswitchsym,		j_switch),
	("doswitch",	kdoswitchsym,	j_doswitch),
	("tabledata",	ktabledatasym,	0),
	("clamp",		kclampsym,		0),
	("eval",		kevalsym,		0),
	("extendtype",	kextendtypesym,	0),

	("print",		kprintsym,		j_print),
	("println",		kprintsym,		j_println),
	("fprint",		kprintsym,		j_fprint),
	("fprintln",	kprintsym,		j_fprintln),
	("cprint",		kprintsym,		j_cprint),
	("cprintln",	kprintsym,		j_cprintln),
	("sprint",		ksprintsym,		j_sprint),
	("sfprint",		ksprintsym,		j_sfprint),

	("stack",		kstacksym,		j_stack),
	("unstack",		kstacksym,		j_unstack),

	("cp",			kprintsym,		j_print),
	("cpl",			kprintsym,		j_println),

	("read",		kreadsym,		j_read),
	("readln",		kreadsym,		j_readln),
	("cast",		kcastsym,		j_convert),

	("proc",		kprocsym,		0),
	("function",	kfunctionsym,	0),
	("threadedproc",		kprocsym,		1),
	("threadedfunction",	kfunctionsym,	1),

	("type",		ktypesym,		0),
	("class",		kclasssym,		0),
	("record",		krecordsym,		0),
	("struct",		kstructsym,		0),
	("union",		kunionsym,		0),
	("taggedunion",	ktaggedunionsym,0),
	("ref",			krefsym,		0),
	("var",			kmutsym,		0),
	("mut",			kmutsym,		0),
	("let",			kletsym,		0),

	("include",		ksourcedirsym,	includedir),
	("strinclude",	ksourcedirsym,	strincludedir),
	("bininclude",	ksourcedirsym,	binincludedir),
	("textinclude",	ksourcedirsym,	textincludedir),
	("defineunit",	ksourcedirsym,	defineunitdir),
	("macro",		kmacrosym,		0),
	("operator",	koperatorsym,	0),
	("emitc",		ksourcedirsym,	emitcdir),
	("cclib",		ksourcedirsym,	cclibdir),

	("assem",		kassemsym,		1),
	("asm",			kassemsym,		0),

	("static",		kstaticsym,		0),
	
	("const",		kconstsym,		0),
	("enum",		kenumsym,		0),

	("$get_nprocs",		ksyscallsym,		sysfn_get_nprocs),
	("$get_procname",	ksyscallsym,		sysfn_get_procname),
	("$get_procaddr",	ksyscallsym,		sysfn_get_procaddr),

	("$get_nexports",	ksyscallsym,		sysfn_get_nexports),
	("$get_procexport",	ksyscallsym,		sysfn_get_procexport),


	("importdll",	kimportmodulesym,	0),
	("importlib",	kimportmodulesym,	0),
	("import",		kimportsym,			0),
	("importx",		kimportsym,			'X'),
	("importd",		kimportsym,			'D'),
	("importpath",	kimportpathsym,		0),
	("mapmodule",	kmapmodulesym,		0),
	("unless",		kunlesssym,			0),

	("try",			ktrysym,		0),
	("except",		kexceptsym,		0),
	("finally",		kfinallysym,	0),
	("raise",		kraisesym,		0),
	("out",			koutsym,		0),

	("new",			knewsym,		j_new),
	("destroy",		kdestroysym,	j_destroy),
	("clear",		kclearsym,		j_clear),

	("global",		kglobalsym,		program_scope),
	("exportq",		kglobalsym,		exportq_scope),
	("export",		kglobalsym,		export_scope),

	("clang",		kfflangsym,		clangff),
	("mlang",		kfflangsym,		mlangff),
	("windows",		kfflangsym,		windowsff),
	("callback",	kfflangsym,		callbackff),

	("swap",		kswapsym,		0),

	("void",		stdtypesym,		tvoid),

	("int",			stdtypesym,		tint),

	("word",		stdtypesym,		tword),

	("real",		stdtypesym,		treal),

	("ichar",		kicharsym,		0),

	("int8",		stdtypesym,		ti8),
	("int16",		stdtypesym,		ti16),
	("int32",		stdtypesym,		ti32),
	("int64",		stdtypesym,		ti64),
	("int128",		stdtypesym,		ti128),

	("i8",			stdtypesym,		ti8),
	("i16",			stdtypesym,		ti16),
	("i32",			stdtypesym,		ti32),
	("i64",			stdtypesym,		ti64),
	("i128",		stdtypesym,		ti128),

	("real32",		stdtypesym,		tr32),
	("real64",		stdtypesym,		tr64),
	("r32",			stdtypesym,		tr32),
	("r64",			stdtypesym,		tr64),

	("float32",		stdtypesym,		tr32),
	("float64",		stdtypesym,		tr64),

	("byte",		stdtypesym,		tu8),
	("u1",			stdtypesym,		tu1),
	("u2",			stdtypesym,		tu2),
	("u4",			stdtypesym,		tu4),
	("u8",			stdtypesym,		tu8),
	("u16",			stdtypesym,		tu16),
	("u32",			stdtypesym,		tu32),
	("u64",			stdtypesym,		tu64),
	("u128",		stdtypesym,		tu128),

	("word8",		stdtypesym,		tu8),
	("word16",		stdtypesym,		tu16),
	("word32",		stdtypesym,		tu32),
	("word64",		stdtypesym,		tu64),
	("word128",		stdtypesym,		tu128),

	("bit",			stdtypesym,		tu1),
	("bit2",		stdtypesym,		tu2),
	("bit4",		stdtypesym,		tu4),

	("char",		stdtypesym,		tc8),
	("wchar",		stdtypesym,		tc16),
	("char64",		stdtypesym,		tc64),

	("array",		karraysym,		tlist),

	("string",		stdtypesym,		tstring),
	("set",			stdtypesym,		tset),
	("dict",		kdictsym,		0),
	("decimal",		stdtypesym,		tdecimal),
	("generator",	stdtypesym,		tgen),

	("$t",			stdtypesym,		tparam1),
	("$u",			stdtypesym,		tparam2),
	("$v",			stdtypesym,		tparam3),
	("$w",			stdtypesym,		tparam4),

	("range",		stdtypesym,		trange),
	("auto",		stdtypesym,		tauto),


	("intm",		machinetypesym,	'I'),
	("intp",		machinetypesym,	'i'),
	("wordm",		machinetypesym,	'W'),
	("wordp",		machinetypesym,	'w'),
	("slice",		kslicesym,		tslice),
	("typeof",		ktypeofsym,			0),

	("million",		unitnamesym,	million_unit),
	("billion",		unitnamesym,	billion_unit),
	("thousand",	unitnamesym,	thousand_unit),
	("kb",			unitnamesym,	kilo_unit),
	("mb",			unitnamesym,	mega_unit),
	("gb",			unitnamesym,	giga_unit),

	("$lineno",		compilervarsym,	j_cvlineno),
	("$strlineno",	compilervarsym,	j_cvstrlineno),
	("$filename",	compilervarsym,	j_cvfilename),
	("$modulename",	compilervarsym,	j_cvmodulename),
	("$function",	compilervarsym,	j_cvfunction),
	("$date",		compilervarsym,	j_cvdate),
	("$time",		compilervarsym,	j_cvtime),
	("$version",	compilervarsym,	j_cvversion),
	("$typename",	compilervarsym,	j_cvtypename),
	("$targetbits",	compilervarsym,	j_cvtargetbits),
	("$targetsize",	compilervarsym,	j_cvtargetsize),
	("$targetcode",	compilervarsym,	j_cvtargetcode),
	("nil",			compilervarsym,	j_cvnil),
	("pi",			compilervarsym,	j_cvpi),
	("true",		compilervarsym,	j_cvtrue),
	("false",		compilervarsym,	j_cvfalse),
	("$",			dollarsym,		0),

	("and",			andlsym,		0),
	("or",			orlsym,			0),
	("xor",			xorlsym,		0),
	("iand",		iandsym,		0),
	("ior",			iorsym,			0),
	("ixor",		ixorsym,		0),
	("in",			insym,			in_op),
	("notin",		notinsym,		notin_op),
	("inrev",		inrevsym,		0),
	("rem",			iremsym,		0),
	("min",			minsym,			0),
	("max",			maxsym,			0),

	("not",			notlsym,		0),
	("inot",		inotsym,		0),
	("istrue",		istruelsym,		0),
	("abs",			abssym,			abs_op),
	("$neg",		negsym,			0),

	("sqr",			sqrsym,			0),
	("sqrt",		sqrtsym,		0),
	("sign",		signsym,		0),

	("sin",			mathsopsym,		sin_op),
	("cos",			mathsopsym,		cos_op),
	("tan",			mathsopsym,		tan_op),
	("asin",		mathsopsym,		asin_op),
	("acos",		mathsopsym,		acos_op),
	("atan",		mathsopsym,		atan_op),
	("ln",			mathsopsym,		ln_op),
	("log",			mathsopsym,		log_op),
	("lg",			mathsopsym,		lg_op),
	("exp",			mathsopsym,		exp_op),
	("round",		mathsopsym,		round_op),
	("floor",		mathsopsym,		floor_op),
	("ceil",		mathsopsym,		ceil_op),
	("fract",		mathsopsym,		fract_op),

	("atan2",		maths2opsym,	atan2_op),
	("fmod",		maths2opsym,	fmod_op),

	("append",		appendsym,		0),
	("concat",		concatsym,		0),
	("sliceptr",	propsym,		sliceptr_op),

	("len",			propsym,	len_op),
	("lwb",			propsym,	lwb_op),
	("upb",			propsym,	upb_op),
	("bounds",		propsym,	bounds_op),
	("lenstr",		propsym,	lenstr_op),
	("bitwidth",	propsym,	bitwidth_op),
	("bytes",		propsym,	bytesize_op),
	("minvalue",	propsym,	minvalue_op),
	("maxvalue",	propsym,	maxvalue_op),
	("typestr",		propsym,	typestr_op),

	("msb",			bitfieldsym,	bf_msb),
	("lsb",			bitfieldsym,	bf_lsb),
	("msbit",		bitfieldsym,	bf_msbit),
	("lsbit",		bitfieldsym,	bf_lsbit),
	("msw",			bitfieldsym,	bf_msw),
	("lsw",			bitfieldsym,	bf_lsw),
	("odd",			bitfieldsym,	bf_odd),
	("even",		bitfieldsym,	bf_even),

	("endif",		kendsym,	kifsym),
	("fi",			kendsym,	kifsym),
	("endcase",		kendsym,	kcasesym),
	("esac",		kendsym,	kcasesym),
	("enddocase",	kendsym,	kdocasesym),
	("endswitch",	kendsym,	kswitchsym),
	("enddoswitch",	kendsym,	kdoswitchsym),
	("endfor",		kendsym,	kforsym),
	("od",			kendsym,	kdosym),
	("endproc",		kendsym,	kprocsym),
	("endfunction",	kendsym,	kfunctionsym),
	("endwhile",	kendsym,	kwhilesym),
	("endto",		kendsym,	ktosym),
	("enddo",		kendsym,	kdosym),
	("endunless",	kendsym,	kunlesssym),
	("endimportmodule",	kendsym,kimportmodulesym),
	("endtry",		kendsym,	ktrysym),
	("endrecord",	kendsym,	krecordsym),
	("endassem",	kendsym,	kassemsym),

	("$caligned",	atsym,		1),


	("$$dummy",		0,				0)
end

global []int D_typestarterset= (stdtypesym,lsqsym,krefsym,kenumsym,krecordsym,
		kicharsym, ktypeofsym, kslicesym, kdictsym)

global [,3]int16 genspecmappings = (
	(add_op,        ti64,      op_add_i64),
	(add_op,        ti128,     op_add_i128),
	(add_op,        tr32,      op_add_r32),
	(add_op,        tr64,      op_add_r64),
	(add_op,        tdec,      op_add_dec),
	(add_op,        tvar,      op_add_var),

	(sub_op,        ti64,      op_sub_i64),
	(sub_op,        ti128,     op_sub_i128),
	(sub_op,        tr32,      op_sub_r32),
	(sub_op,        tr64,      op_sub_r64),
	(sub_op,        tdec,      op_sub_dec),
	(sub_op,        tref,      op_sub_ref),
	(sub_op,        tvar,      op_sub_var),

	(mul_op,        ti64,      op_mul_i64),
	(mul_op,        ti128,     op_mul_i128),
	(mul_op,        tr32,      op_mul_r32),
	(mul_op,        tr64,      op_mul_r64),
	(mul_op,        tdec,      op_mul_dec),
	(mul_op,        tvar,      op_mul_var),

	(div_op,        tr32,      op_div_r32),
	(div_op,        tr64,      op_div_r64),
	(div_op,        tdec,      op_div_dec),

	(idiv_op,       tu64,      op_idiv_u64),
	(idiv_op,       ti64,      op_idiv_i64),
	(idiv_op,       tu128,     op_idiv_u128),
	(idiv_op,       ti128,     op_idiv_i128),
	(idiv_op,       tdec,      op_idiv_dec),

	(irem_op,       tu64,      op_irem_u64),
	(irem_op,       ti64,      op_irem_i64),
	(irem_op,       tu128,     op_irem_u128),
	(irem_op,       ti128,     op_irem_i128),
	(irem_op,       tdec,      op_irem_dec),

	(iand_op,       ti64,      op_iand_i64),
	(iand_op,       ti128,     op_iand_i128),
	(iand_op,       tvar,      op_iand_var),

	(ior_op,        ti64,      op_ior_i64),
	(ior_op,        ti128,     op_ior_i128),
	(ior_op,        tvar,      op_ior_var),

	(ixor_op,       ti64,      op_ixor_i64),
	(ixor_op,       ti128,     op_ixor_i128),
	(ixor_op,       tvar,      op_ixor_var),

	(shl_op,        tu64,      op_shl_i64),
	(shl_op,        ti64,      op_shl_i64),
	(shl_op,        tu128,     op_shl_i128),
	(shl_op,        ti128,     op_shl_i128),
	(shl_op,        tdec,      op_shl_dec),

	(shr_op,        tu64,      op_shr_u64),
	(shr_op,        ti64,      op_shr_i64),
	(shr_op,        tu128,     op_shr_u128),
	(shr_op,        ti128,     op_shr_i128),
	(shr_op,        tdec,      op_shr_dec),

	(min_op,        tu64,      op_min_u64),
	(min_op,        ti64,      op_min_i64),
	(min_op,        tu128,     op_min_u128),
	(min_op,        ti128,     op_min_i128),
	(min_op,        tr32,      op_min_r32),
	(min_op,        tr64,      op_min_r64),
	(min_op,        tdec,      op_min_dec),

	(max_op,        tu64,      op_max_u64),
	(max_op,        ti64,      op_max_i64),
	(max_op,        tu128,     op_max_u128),
	(max_op,        ti128,     op_max_i128),
	(max_op,        tr32,      op_max_r32),
	(max_op,        tr64,      op_max_r64),
	(max_op,        tdec,      op_max_dec),

	(concat_op,     tvar,      op_concat_var),

	(append_op,     tvar,      op_append_var),

	(neg_op,        ti64,      op_neg_i64),
	(neg_op,        ti128,     op_neg_i128),
	(neg_op,        tr32,      op_neg_r32),
	(neg_op,        tr64,      op_neg_r64),
	(neg_op,        tdec,      op_neg_dec),

	(abs_op,        ti64,      op_abs_i64),
	(abs_op,        ti128,     op_abs_i128),
	(abs_op,        tr32,      op_abs_r32),
	(abs_op,        tr64,      op_abs_r64),
	(abs_op,        tdec,      op_abs_dec),

	(inot_op,       ti64,      op_inot_i64),
	(inot_op,       ti128,     op_inot_i128),
	(inot_op,       tvar,      op_inot_var),

	(sqr_op,        ti64,      op_sqr_i64),
	(sqr_op,        ti128,     op_sqr_i128),
	(sqr_op,        tr32,      op_sqr_r32),
	(sqr_op,        tr64,      op_sqr_r64),
	(sqr_op,        tdec,      op_sqr_dec),

	(sqrt_op,       tr32,      op_sqrt_r32),
	(sqrt_op,       tr64,      op_sqrt_r64),
	(sqrt_op,       tdec,      op_sqrt_dec),

	(sin_op,        tr32,      op_sin_r32),
	(sin_op,        tr64,      op_sin_r64),
	(sin_op,        tdec,      op_sin_dec),

	(cos_op,        tr32,      op_cos_r32),
	(cos_op,        tr64,      op_cos_r64),
	(cos_op,        tdec,      op_cos_dec),

	(tan_op,        tr32,      op_tan_r32),
	(tan_op,        tr64,      op_tan_r64),
	(tan_op,        tdec,      op_tan_dec),

	(asin_op,       tr32,      op_asin_r32),
	(asin_op,       tr64,      op_asin_r64),
	(asin_op,       tdec,      op_asin_dec),

	(acos_op,       tr32,      op_acos_r32),
	(acos_op,       tr64,      op_acos_r64),
	(acos_op,       tdec,      op_acos_dec),

	(atan_op,       tr32,      op_atan_r32),
	(atan_op,       tr64,      op_atan_r64),
	(atan_op,       tdec,      op_atan_dec),

	(ln_op,         tr32,      op_ln_r32),
	(ln_op,         tr64,      op_ln_r64),
	(ln_op,         tdec,      op_ln_dec),

	(lg_op,         tr32,      op_lg_r32),
	(lg_op,         tr64,      op_lg_r64),
	(lg_op,         tdec,      op_lg_dec),

	(log_op,        tr32,      op_log_r32),
	(log_op,        tr64,      op_log_r64),
	(log_op,        tdec,      op_log_dec),

	(exp_op,        tr32,      op_exp_r32),
	(exp_op,        tr64,      op_exp_r64),
	(exp_op,        tdec,      op_exp_dec),

	(round_op,      tr32,      op_round_r32),
	(round_op,      tr64,      op_round_r64),
	(round_op,      tdec,      op_round_dec),

	(floor_op,      tr32,      op_floor_r32),
	(floor_op,      tr64,      op_floor_r64),
	(floor_op,      tdec,      op_floor_dec),

	(ceil_op,       tr32,      op_ceil_r32),
	(ceil_op,       tr64,      op_ceil_r64),
	(ceil_op,       tdec,      op_ceil_dec),

	(fract_op,      tr32,      op_fract_r32),
	(fract_op,      tr64,      op_fract_r64),
	(fract_op,      tdec,      op_fract_dec),

	(sign_op,       ti64,      op_sign_i64),
	(sign_op,       tr32,      op_sign_r32),
	(sign_op,       tr64,      op_sign_r64),
	(sign_op,       tdec,      op_sign_dec),

	(atan2_op,      tr32,      op_atan2_r32),
	(atan2_op,      tr64,      op_atan2_r64),
	(atan2_op,      tdec,      op_atan2_dec),

	(power_op,      tu64,      op_power_u64),
	(power_op,      ti64,      op_power_i64),
	(power_op,      tu128,     op_power_u128),
	(power_op,      ti128,     op_power_i128),
	(power_op,      tr32,      op_power_r32),
	(power_op,      tr64,      op_power_r64),
	(power_op,      tdec,      op_power_dec),

	(fmod_op,       tr32,      op_fmod_r32),
	(fmod_op,       tr64,      op_fmod_r64),
	(fmod_op,       tdec,      op_fmod_dec),

	(lwb_op,        tvar,      op_lwb_var),

	(upb_op,        tvar,      op_upb_var),

	(len_op,        tvar,      op_len_var),

	(bounds_op,     tvar,      op_bounds_var),

	(lenstr_op,     tvar,      op_lenstr_var),

	(sliceptr_op,   tslice,    op_sliceptr_slice),

	(incr_op,       tu8,       op_incr_short),
	(incr_op,       ti64,      op_incr_i64),
	(incr_op,       ti128,     op_incr_i128),
	(incr_op,       tdec,      op_incr_dec),
	(incr_op,       tref,      op_incr_ref),
	(incr_op,       tenum,     op_incr_enum),

	(decr_op,       tu8,       op_decr_short),
	(decr_op,       ti64,      op_decr_i64),
	(decr_op,       ti128,     op_decr_i128),
	(decr_op,       tdec,      op_decr_dec),
	(decr_op,       tref,      op_decr_ref),
	(decr_op,       tenum,     op_decr_enum),

	(incrload_op,   tu8,       op_incrload_short),
	(incrload_op,   ti64,      op_incrload_i64),
	(incrload_op,   ti128,     op_incrload_i128),
	(incrload_op,   tdec,      op_incrload_dec),
	(incrload_op,   tref,      op_incrload_ref),
	(incrload_op,   tenum,     op_incrload_enum),

	(decrload_op,   tu8,       op_decrload_short),
	(decrload_op,   ti64,      op_decrload_i64),
	(decrload_op,   ti128,     op_decrload_i128),
	(decrload_op,   tdec,      op_decrload_dec),
	(decrload_op,   tref,      op_decrload_ref),
	(decrload_op,   tenum,     op_decrload_enum),

	(loadincr_op,   tu8,       op_loadincr_short),
	(loadincr_op,   ti64,      op_loadincr_i64),
	(loadincr_op,   ti128,     op_loadincr_i128),
	(loadincr_op,   tdec,      op_loadincr_dec),
	(loadincr_op,   tref,      op_loadincr_ref),
	(loadincr_op,   tenum,     op_loadincr_enum),

	(loaddecr_op,   tu8,       op_loaddecr_short),
	(loaddecr_op,   ti64,      op_loaddecr_i64),
	(loaddecr_op,   ti128,     op_loaddecr_i128),
	(loaddecr_op,   tr32,      op_loaddecr_r32),
	(loaddecr_op,   tr64,      op_loaddecr_r64),
	(loaddecr_op,   tdec,      op_loaddecr_dec),
	(loaddecr_op,   tref,      op_loaddecr_ref),
	(loaddecr_op,   tenum,     op_loaddecr_enum),

	(addto_op,      tu8,       op_addto_short),
	(addto_op,      ti64,      op_addto_i64),
	(addto_op,      ti128,     op_addto_i128),
	(addto_op,      tr32,      op_addto_r32),
	(addto_op,      tr64,      op_addto_r64),
	(addto_op,      tdec,      op_addto_dec),
	(addto_op,      tvar,      op_addto_var),

	(subto_op,      tu8,       op_subto_short),
	(subto_op,      ti64,      op_subto_i64),
	(subto_op,      ti128,     op_subto_i128),
	(subto_op,      tr32,      op_subto_r32),
	(subto_op,      tr64,      op_subto_r64),
	(subto_op,      tdec,      op_subto_dec),

	(multo_op,      tu8,       op_multo_short),
	(multo_op,      ti64,      op_multo_i64),
	(multo_op,      ti128,     op_multo_i128),
	(multo_op,      tr32,      op_multo_r32),
	(multo_op,      tr64,      op_multo_r64),
	(multo_op,      tdec,      op_multo_dec),

	(divto_op,      tr32,      op_divto_r32),
	(divto_op,      tr64,      op_divto_r64),
	(divto_op,      tdec,      op_divto_dec),

	(idivto_op,     tu8,       op_idivto_short),
	(idivto_op,     tu64,      op_idivto_u64),
	(idivto_op,     ti64,      op_idivto_i64),
	(idivto_op,     tu128,     op_idivto_u128),
	(idivto_op,     ti128,     op_idivto_i128),
	(idivto_op,     tdec,      op_idivto_dec),

	(iremto_op,     tu64,      op_iremto_u64),
	(iremto_op,     ti64,      op_iremto_i64),
	(iremto_op,     tu128,     op_iremto_u128),
	(iremto_op,     ti128,     op_iremto_i128),
	(iremto_op,     tdec,      op_iremto_dec),

	(iandto_op,     tu8,       op_iandto_short),
	(iandto_op,     ti64,      op_iandto_i64),
	(iandto_op,     ti128,     op_iandto_i128),

	(iorto_op,      tu8,       op_iorto_short),
	(iorto_op,      ti64,      op_iorto_i64),
	(iorto_op,      ti128,     op_iorto_i128),

	(ixorto_op,     tu8,       op_ixorto_short),
	(ixorto_op,     ti64,      op_ixorto_i64),
	(ixorto_op,     ti128,     op_ixorto_i128),

	(shlto_op,      tu8,       op_shlto_short),
	(shlto_op,      tu64,      op_shlto_i64),
	(shlto_op,      ti64,      op_shlto_i64),
	(shlto_op,      tu128,     op_shlto_u128),
	(shlto_op,      ti128,     op_shlto_i128),
	(shlto_op,      tdec,      op_shlto_dec),

	(shrto_op,      tu8,       op_shrto_short),
	(shrto_op,      tu64,      op_shrto_u64),
	(shrto_op,      ti64,      op_shrto_i64),
	(shrto_op,      tu128,     op_shrto_u128),
	(shrto_op,      ti128,     op_shrto_i128),
	(shrto_op,      tdec,      op_shrto_dec),

	(appendto_op,   tvar,      op_appendto_var),

	(concatto_op,   tvar,      op_concatto_var),

	(minto_op,      tu64,      op_minto_u64),
	(minto_op,      ti64,      op_minto_i64),
	(minto_op,      tu128,     op_minto_u128),
	(minto_op,      ti128,     op_minto_i128),
	(minto_op,      tr32,      op_minto_r32),
	(minto_op,      tr64,      op_minto_r64),
	(minto_op,      tdec,      op_minto_dec),

	(maxto_op,      tu64,      op_maxto_u64),
	(maxto_op,      ti64,      op_maxto_i64),
	(maxto_op,      tu128,     op_maxto_u128),
	(maxto_op,      ti128,     op_maxto_i128),
	(maxto_op,      tr32,      op_maxto_r32),
	(maxto_op,      tr64,      op_maxto_r64),
	(maxto_op,      tdec,      op_maxto_dec),

	(negto_op,      ti64,      op_negto_i64),
	(negto_op,      ti128,     op_negto_i128),
	(negto_op,      tr32,      op_negto_r32),
	(negto_op,      tr64,      op_negto_r64),
	(negto_op,      tdec,      op_negto_dec),

	(absto_op,      ti64,      op_absto_i64),
	(absto_op,      ti128,     op_absto_i128),
	(absto_op,      tr32,      op_absto_r32),
	(absto_op,      tr64,      op_absto_r64),
	(absto_op,      tdec,      op_absto_dec),

	(inotto_op,     ti64,      op_inotto_i64),
	(inotto_op,     ti128,     op_inotto_i128),


	(tostr_op,      tc64,      op_tostr_c64),
	(tostr_op,      tu64,      op_tostr_u64),
	(tostr_op,      ti64,      op_tostr_i64),
	(tostr_op,      tu128,     op_tostr_u128),
	(tostr_op,      ti128,     op_tostr_i128),
	(tostr_op,      tr32,      op_tostr_r32),
	(tostr_op,      tr64,      op_tostr_r64),
	(tostr_op,      tdec,      op_tostr_dec),
	(tostr_op,      tref,      op_tostr_ref),
	(tostr_op,      tenum,     op_tostr_enum),
	(tostr_op,      tvar,      op_tostr_var),

	(tostrfmt_op,   tc64,      op_tostrfmt_c64),
	(tostrfmt_op,   tu64,      op_tostrfmt_u64),
	(tostrfmt_op,   ti64,      op_tostrfmt_i64),
	(tostrfmt_op,   tu128,     op_tostrfmt_u128),
	(tostrfmt_op,   ti128,     op_tostrfmt_i128),
	(tostrfmt_op,   tr32,      op_tostrfmt_r32),
	(tostrfmt_op,   tr64,      op_tostrfmt_r64),
	(tostrfmt_op,   tdec,      op_tostrfmt_dec),
	(tostrfmt_op,   tref,      op_tostrfmt_ref),
	(tostrfmt_op,   tenum,     op_tostrfmt_enum),
	(tostrfmt_op,   tvar,      op_tostrfmt_var),


	(eq_op,         ti64,      op_eq_i64),
	(eq_op,         ti128,     op_eq_i128),
	(eq_op,         tr32,      op_eq_r32),
	(eq_op,         tr64,      op_eq_r64),
	(eq_op,         tdec,      op_eq_dec),
	(eq_op,         tref,      op_eq_ref),
	(eq_op,         tenum,     op_eq_enum),
	(eq_op,         tvar,      op_eq_var),
	(eq_op,         tblock,    op_eq_block),

	(ne_op,         ti64,      op_ne_i64),
	(ne_op,         ti128,     op_ne_i128),
	(ne_op,         tr32,      op_ne_r32),
	(ne_op,         tr64,      op_ne_r64),
	(ne_op,         tdec,      op_ne_dec),
	(ne_op,         tref,      op_ne_ref),
	(ne_op,         tenum,     op_ne_enum),
	(ne_op,         tvar,      op_ne_var),
	(ne_op,         tblock,    op_ne_block),

	(lt_op,         tu64,      op_lt_u64),
	(lt_op,         ti64,      op_lt_i64),
	(lt_op,         tu128,     op_lt_u128),
	(lt_op,         ti128,     op_lt_i128),
	(lt_op,         tr32,      op_lt_r32),
	(lt_op,         tr64,      op_lt_r64),
	(lt_op,         tdec,      op_lt_dec),
	(lt_op,         tenum,     op_lt_enum),
	(lt_op,         tvar,      op_lt_var),
	(lt_op,         tref,      op_lt_ref),

	(le_op,         tu64,      op_le_u64),
	(le_op,         ti64,      op_le_i64),
	(le_op,         tu128,     op_le_u128),
	(le_op,         ti128,     op_le_i128),
	(le_op,         tr32,      op_le_r32),
	(le_op,         tr64,      op_le_r64),
	(le_op,         tdec,      op_le_dec),
	(le_op,         tenum,     op_le_enum),
	(le_op,         tvar,      op_le_var),
	(le_op,         tref,      op_le_ref),

	(ge_op,         tu64,      op_ge_u64),
	(ge_op,         ti64,      op_ge_i64),
	(ge_op,         tu128,     op_ge_u128),
	(ge_op,         ti128,     op_ge_i128),
	(ge_op,         tr32,      op_ge_r32),
	(ge_op,         tr64,      op_ge_r64),
	(ge_op,         tdec,      op_ge_dec),
	(ge_op,         tenum,     op_ge_enum),
	(ge_op,         tvar,      op_ge_var),
	(ge_op,         tref,      op_ge_ref),

	(gt_op,         tu64,      op_gt_u64),
	(gt_op,         ti64,      op_gt_i64),
	(gt_op,         tu128,     op_gt_u128),
	(gt_op,         ti128,     op_gt_i128),
	(gt_op,         tr32,      op_gt_r32),
	(gt_op,         tr64,      op_gt_r64),
	(gt_op,         tdec,      op_gt_dec),
	(gt_op,         tenum,     op_gt_enum),
	(gt_op,         tvar,      op_gt_var),
	(gt_op,         tref,      op_gt_ref),

	(same_op,       tvar,      op_same_var),

	(andl_op,       ti64,      op_andl_i64),

	(orl_op,        ti64,      op_orl_i64),

	(notl_op,       ti64,      op_notl_i64),

	(istruel_op,    ti64,      op_istruel_i64),
	(istruel_op,    ti128,     op_istruel_i128),
	(istruel_op,    tr32,      op_istruel_r32),
	(istruel_op,    tr64,      op_istruel_r64),
	(istruel_op,    tdec,      op_istruel_dec),
	(istruel_op,    tenum,     op_istruel_enum),
	(istruel_op,    tvar,      op_istruel_var),

	(andlto_op,     ti64,      op_andlto_i64),

	(orlto_op,      ti64,      op_orlto_i64),

	(notlto_op,     ti64,      op_notlto_i64),

	(istruelto_op,  ti64,      op_istruelto_i64))


[]byte intresultlist = (
	in_op, notin_op, lwb_op, upb_op, len_op, lenstr_op, bitwidth_op,
	bytesize_op, eq_op, ne_op, lt_op, le_op, ge_op, gt_op,
	andl_op, orl_op, notl_op, istruel_op)

global [,3]int16 softconvmappings =(
	(tc64,	tc64,	op_softconv),
	(tc64,	tu64,	op_softconv),
	(tc64,	tu128,	op_widen_u64_u128),
	(tc64,	ti64,	op_softconv),
	(tc64,	ti128,	op_widen_u64_u128),
	(tc64,	tr32,	op_float_u64_r32),
	(tc64,	tr64,	op_float_u64_r64),
	(tc64,	tdec,	op_todec_u64_dec),

	(tu64,	tc64,	op_softconv),
	(tu64,	tu64,	op_softconv),
	(tu64,	tu128,	op_widen_u64_u128),
	(tu64,	ti64,	op_softconv),
	(tu64,	ti128,	op_widen_u64_u128),
	(tu64,	tr32,	op_float_u64_r32),
	(tu64,	tr64,	op_float_u64_r64),
	(tu64,	tdec,	op_todec_u64_dec),

	(tu128,	tc64,	op_softtrunc_128_64),
	(tu128,	tu64,	op_softtrunc_128_64),
	(tu128,	tu128,	op_softconv),
	(tu128,	ti64,	op_softtrunc_128_64),
	(tu128,	ti128,	op_softconv),
	(tu128,	tr32,	op_error),
	(tu128,	tr64,	op_error),
	(tu128,	tdec,	op_error),

	(ti64,	tc64,	op_softconv),
	(ti64,	tu64,	op_softconv),
	(ti64,	tu128,	op_widen_i64_i128),
	(ti64,	ti64,	op_softconv),
	(ti64,	ti128,	op_widen_i64_i128),
	(ti64,	tr32,	op_float_i64_r32),
	(ti64,	tr64,	op_float_i64_r64),
	(ti64,	tdec,	op_todec_i64_dec),

	(ti128,	tc64,	op_softtrunc_128_64),
	(ti128,	tu64,	op_softtrunc_128_64),
	(ti128,	tu128,	op_softconv),
	(ti128,	ti64,	op_softtrunc_128_64),
	(ti128,	ti128,	op_softconv),
	(ti128,	tr32,	op_error),
	(ti128,	tr64,	op_error),
	(ti128,	tdec,	op_error),

	(tr32,	tc64,	op_fix_r32_u64),
	(tr32,	tu64,	op_fix_r32_u64),
	(tr32,	tu128,	op_error),
	(tr32,	ti64,	op_fix_r32_i64),
	(tr32,	ti128,	op_error),
	(tr32,	tr32,	op_softconv),
	(tr32,	tr64,	op_fwiden_r32_r64),
	(tr32,	tdec,	op_todec_r32_dec),

	(tr64,	tc64,	op_fix_r64_u64),
	(tr64,	tu64,	op_fix_r64_u64),
	(tr64,	tu128,	op_error),
	(tr64,	ti64,	op_fix_r64_i64),
	(tr64,	ti128,	op_error),
	(tr64,	tr32,	op_fnarrow_r64_r32),
	(tr64,	tr64,	op_softconv),
	(tr64,	tdec,	op_todec_r64_dec),

	(tdec,	tc64,	op_decto_dec_u64),
	(tdec,	tu64,	op_decto_dec_u64),
	(tdec,	tu128,	op_error),
	(tdec,	ti64,	op_decto_dec_i64),
	(tdec,	ti128,	op_error),
	(tdec,	tr32,	op_error),
	(tdec,	tr64,	op_error),
	(tdec,	tdec,	op_softconv))


global [firstgenop..lastgenop, tfirsttabletype..tlasttabletype]int16 optypetable

global [firstgenop..lastgenop]byte intresult

global [tfirstnum..tlastnum, tfirstnum..tlastnum]int64 softconvtable

global [specopnames.lwb..specopnames.upb]byte specoptogen
global [specopnames.lwb..specopnames.upb]byte specoptotype

global proc inittypetables=
	int genop, s,t, a, specop

	for i in genspecmappings.bounds do
		genop:=genspecmappings[i,1]
		t:=genspecmappings[i,2]
		specop:=genspecmappings[i,3]

		optypetable[genop,t] := specop

		specoptogen[specop]:=genop
		specoptotype[specop]:=t
	od

	for genop in firstgenop..lastgenop do
		for t in tfirsttabletype..tlasttabletype do
			if optypetable[genop,t]=0 then
				case t
				when tc64 then
					if a:=optypetable[genop,tu64] then optypetable[genop,tc64]:=a
					elsif a:=optypetable[genop,ti64] then optypetable[genop,tc64]:=a
					fi
				when tu64 then
					if a:=optypetable[genop,ti64] then optypetable[genop,tu64]:=a fi
				when tu128 then
					if a:=optypetable[genop,ti128] then optypetable[genop,tu128]:=a fi
				esac
			fi
		od
	od

	for i in intresultlist.bounds do
		intresult[intresultlist[i]]:=1
	od

	for i in softconvmappings.bounds do
		s:=softconvmappings[i,1]
		t:=softconvmappings[i,2]
		specop:=softconvmappings[i,3]

		softconvtable[s,t]:=specop
	od
end

=== bb_pclcommon.m 4/40 ===
import bb_decls

global type pcl = ref pclrec

global record pstrec =
	ichar name
	ref pstrec owner
	ref pstrec nextpst
	word32 mode
	word32 size
	byte id
	word16 flags:(isglobal:2, isexport:1, isimport:1, iscallback:1,
		isframe:1, isequiv:1, isstart:1, isequivtarget:1, noreg:1)
	int16 nrefs
	byte addrof
	byte moduleno
	byte isthreaded
	word32 pos: (lineno:24, fileno:8)
	ref pstrec equiv

	union
		int32 offset
		int32 labelno
	end
	int32 index
	int16 reg

	byte reftype			!AX fields
	byte segment
	ref fwdrec fwdrefs	!fwd ref chain
	int32 stindex		!label pass 2: 0, or 1-based index within coff symboltable
	int32 importindex
	int32 regsize

end

global tabledata() [0:]ichar pstnames =
	(no_name = 0,		$),
	(proc_name,			$),
	(dllproc_name,		$),
	(dllstatic_name,	$),
	(istatic_name,		$),
	(zstatic_name,		$),
	(param_name,		$),
	(frame_name,		$),
	(module_name,		$),
	(label_name,		$),
end

global tabledata() 	[0:]ichar stdnames,
		[0:]byte stdbits,
		[0:]byte stdcodes,
		[0:]byte stdtabtype,
		[0:]byte stdtabtype2,
		[0:]byte stdpcltype,
		[0:]byte stdcat,
		[0:]byte stdcat2 =
    (tvoid=0,    "void",    0,    0,   tvoid,      tvoid,      tvoid,      void_cat,   void_cat ),

    (tc64,       "c64",    64,   'C',  tc64,       tc64,       tu64,       d64_cat,    d64_cat  ),
    (tu64,       "u64",    64,   'U',  tu64,       tu64,       tu64,       d64_cat,    d64_cat  ),
    (tu128,      "u128",  128,   'U',  tu128,      tu128,      tu128,      wide_cat,   wide_cat ),
    (ti64,       "i64",    64,   'I',  ti64,       ti64,       ti64,       d64_cat,    d64_cat  ),
    (ti128,      "i128",  128,   'I',  ti128,      ti128,      ti128,      wide_cat,   wide_cat ),
    (tr32,       "r32",    32,   'R',  tr32,       tr32,       tr32,       x32_cat,    short_cat),
    (tr64,       "r64",    64,   'R',  tr64,       tr64,       tr64,       x64_cat,    d64_cat  ),
    (tdecimal,   "dec",    64,   'D',  tdecimal,   tvar,       tdecimal,   var_cat,    var_cat  ),

    (trange,     "range", 128,   'G',  trange,     trange,     tu128,      wide_cat,   wide_cat ),
    (tstring,    "str",    64,     0,  tstring,    tvar,       tstring,    var_cat,    var_cat  ),
    (tset,       "set",    64,     0,  tset,       tvar,       tset,       var_cat,    var_cat  ),
    (tref,       "ref",    64,   'P',  tref,       tref,       tu64,       d64_cat,    d64_cat  ),
    (trefchar,   "ichar",  64,   'P',  trefchar,   tref,       tu64,       d64_cat,    d64_cat  ),
    (trefbit,    "refbt", 128,   'Q',  trefbit,    trefbit,    tu128,      wide_cat,   wide_cat ),
    (tarray,     "array",   0,   'A',  tblock,     tblock,     tblock,     block_cat,  block_cat),
    (tslice,     "slice", 128,     0,  tslice,     tslice,     tu128,      wide_cat,   wide_cat ),
    (tbits,      "bits",    0,     0,  tblock,     tblock,     tblock,     block_cat,  block_cat),
    (tlist,      "list",   64,     0,  tlist,      tvar,       tlist,      var_cat,    var_cat  ),
    (tdict,      "dict",   64,     0,  tdict,      tvar,       tdict,      var_cat,    var_cat  ),
    (trecord,    "rec",     0,     0,  tblock,     tblock,     tblock,     block_cat,  block_cat),
    (ttagunion,  "tagun",   0,     0,  tblock,     tblock,     tblock,     block_cat,  block_cat),

    (tblock,     "block",   0,     0,  tblock,     tblock,     tblock,     block_cat,  block_cat),
    (tshort,     "short",   0,     0,  tshort,     tshort,     tvoid,      void_cat,   void_cat ),
    (tvar,       "var",    64,     0,  tvar,       tvar,       tvar,       void_cat,   void_cat ),

    (tc8,        "c8",      8,   'C',  tshort,     tshort,     tu8,        short_cat,  short_cat),
    (tc16,       "c16",    16,   'C',  tshort,     tshort,     tu16,       short_cat,  short_cat),
    (ti8,        "i8",      8,   'I',  tshort,     tshort,     ti8,        short_cat,  short_cat),
    (ti16,       "i16",    16,   'I',  tshort,     tshort,     ti16,       short_cat,  short_cat),
    (ti32,       "i32",    32,   'I',  tshort,     tshort,     ti32,       short_cat,  short_cat),
    (tu8,        "u8",      8,   'U',  tshort,     tshort,     tu8,        short_cat,  short_cat),
    (tu16,       "u16",    16,   'U',  tshort,     tshort,     tu16,       short_cat,  short_cat),
    (tu32,       "u32",    32,   'U',  tshort,     tshort,     tu32,       short_cat,  short_cat),

    (tenum,      "enum",   64,     0,  ti64,       ti64,       tu64,       d64_cat,    d64_cat  ),
    (trecordx,   "recx",   64,     0,  trecordx,   tvar,       trecordx,   var_cat,    var_cat  ),

    (tu1,        "u1",      1,   'B',  tvoid,      tvoid,      tvoid,      void_cat,   void_cat ),
    (tu2,        "u2",      2,   'B',  tvoid,      tvoid,      tvoid,      void_cat,   void_cat ),
    (tu4,        "u4",      4,   'B',  tvoid,      tvoid,      tvoid,      void_cat,   void_cat ),

    (tauto,      "auto",    0,     0,  tvoid,      tvoid,      tvoid,      void_cat,   void_cat ),
    (tany,       "any",     0,     0,  tvoid,      tvoid,      tvoid,      void_cat,   void_cat ),
    (tproc,      "proc",    0,     0,  tvoid,      tvoid,      tu64,       void_cat,   void_cat ),
    (tlabel,     "label",   0,     0,  tvoid,      tvoid,      tvoid,      void_cat,   void_cat ),
    (tgen,       "gen",     0,     0,  tvoid,      tvoid,      tvoid,      void_cat,   void_cat ),
    (ttype,      "type",   64,     0,  tvoid,      tvoid,      tvoid,      void_cat,   void_cat ),
    (tbitfield,  "bitfl",   8,     0,  tvoid,      tvoid,      tvoid,      void_cat,   void_cat ),
    (ttuple,     "tuple",   0,     0,  tvoid,      tvoid,      tvoid,      void_cat,   void_cat ),
    (tpending,   "pend",    0,     0,  tvoid,      tvoid,      tvoid,      void_cat,   void_cat ),

    (tparam1,    "pm1",     0,     0,  tvoid,      tvoid,      tvoid,      void_cat,   void_cat ),
    (tparam2,    "pm2",     0,     0,  tvoid,      tvoid,      tvoid,      void_cat,   void_cat ),
    (tparam3,    "pm3",     0,     0,  tvoid,      tvoid,      tvoid,      void_cat,   void_cat ),
    (tparam4,    "pm4",     0,     0,  tvoid,      tvoid,      tvoid,      void_cat,   void_cat ),

    (tlast,      "last ",   0,     0,  tlast,      tlast,      tlast,      void_cat,   void_cat ),
end

global const tuser	= tlast

global const tint	= ti64
global const tword	= tu64
global const treal	= tr64
global const tdec	= tdecimal
global const tfirstnum	= tc64
global const tlastnum	= tdecimal

global const tfirsttabletype	= tc64			!bounds used in optables
global const tlasttabletype		= tenum

global const maxtuplesize = 4

global int trefproc
global int treflabel

global []int typerank=(
	1,	!tc64
	2,	!tu64
	4,	!tu128
	3,	!ti64
	5,	!ti128
	6,	!tr32
	7,	!tr64
	8)	!tdecimal


global tabledata() [0:]ichar typecatnames =
	(void_cat=0,	"void"),
	(short_cat,		"short"),		!u8/u16/u32 i8/i16/i64 normally widened to u64/i64
	(d64_cat,		"d64"),			!i64, u64, pointers, r64 as data; anything of that size
	(x32_cat,		"x32"),			!r32, which are not normally widened to r64
	(x64_cat,		"x64"),			!r64
	(wide_cat,		"wide"),		!u128/i128, also used for slices, anything of that size
	(block_cat,		"block"),		!N-byte block of any size, that is not 1/2/4/8/16 bytes
	(var_cat,		"var"),			!u64 pointer/refernce to flex string/array etc
end


global tabledata() [0:]ichar opndnames =
	(no_opnd=0,			$),
	(mem_opnd,			$),
	(memaddr_opnd,		$),
	(int_opnd,			$),
	(int128_opnd,		$),
	(real_opnd,			$),
	(real32_opnd,		$),
	(string_opnd,		$),		!data string
	(label_opnd,		$),
	(reg_opnd,			$),
	(xreg_opnd,			$),
	(metastring_opnd,	$),		!for comments, names of ext. functions etc
	(assem_opnd,		$),		!inline assembly (links back to ast)
end

global record pclrec =
	union
		int64 value
		real64 xvalue
		ref int128 pvalue128
		ichar svalue
		ref pstrec def
		int tempno
		int labelno
		unit code
	end
	byte opndtype
	ref pclrec nextpcl
	byte opcode
	byte flags:(isglobal:2, isvariadic:1)
	byte align

	word16 opindex				!spec-op
	union
		byte oldmode			!for ifix/ifloat
		byte newmode			!for truncate
	end
	byte spare1

	int32 pos:(lineno:24, fileno:8)
	int32 mode
	int32 size
	int32 spare2
	[16]byte spare3

	union						!two 32-bit params used according to opcode
		struct					!pointer ops
			int32 scale			!scale factor for offset
			int32 extra			!extra constant byte offset, already scaled
		end
		struct					!call/etc
			byte nargs			!number of args
			byte nvariadics		!for ffi, parameter number at which variadics start
			byte nmult			!0, or n for call mult
			union
				int16 fnindex		!for sysfn
				[4]byte retcats
			end
		end
		struct					!switch
			int32 minlab
			int32 maxlab
		end

		int32 index				!general sequential index for setparam/temp etc
		int32 cond				!pcl condition code for jumpcc etc
		int32 step				!always +ve fixed step size for forup/fordown; also INCR
		int32 truncmode			!convert/truncate: truncated mode

		struct
			int32 x				!common access to these two params
			int32 y
		end
	end
end

global tabledata() [0:]ichar opndnames_ma =
	(a_none=0,	$),
	(a_reg,		$),		! Ri
	(a_imm,		$),		! d including def name, label etc
	(a_mem,		$),		! any memory modes: [d], [R], [R*4+R2+d+imm] etc
	(a_cond,	$),		! a condition code for jcc/setcc
	(a_xreg,	$),		! xmm register
	(a_wreg,	$),		! Wide integer register, means Ri and Ri+1
	(a_regvar,	$),		! Reg holding a regvar
end


global tabledata() [0:]ichar pclnames, [0:]byte pcluseindex =
	(k_none = 0,		$,	0),	!      (0 0) 
	(k_comment,			$,	0),	!      (0 0) 
	(k_blank,			$,	0),	!      (0 0) 
	(k_end,				$,	0),	!      (0 0) 
	(k_debug,			$,	0),	!      (0 0) 
	(k_test,			$,	0),	!      (0 0) 

	(k_procdef,			$,	0),	!      (0 0) 
	(k_procend,			$,	0),	!      (0 0) 
	(k_procentry,		$,	0),	!      (0 0) 
	(k_label,			$,	0),	!      (0 0) 
	(k_labelname,		$,	0),	!      (0 0) 
	(k_frame,			$,	0),	!      (0 0) 
	(k_param,			$,	0),	!      (0 0) 
	(k_istatic,			$,	0),	!      (0 0) 
	(k_zstatic,			$,	0),	!      (0 0) 
	(k_initmemz,		$,	0),	!      (0 0) 
	(k_freemem,			$,	0),	!      (0 0) 
	(k_equiv,			$,	0),	!      (0 0) 
	(k_extern,			$,	0),	!      (0 0) 
	(k_endextern,		$,	0),	!      (0 0) 
	(k_info,			$,	0),	!      (0 0) 

	(k_startmult,		$,	0),	!      (0 0) 
	(k_resetmult,		$,	0),	!      (0 0) 
	(k_endmult,			$,	0),	!      (0 0) 

	(k_pushint,			$,	0),	!      (0 1)
	(k_pushint128,		$,	0),	!      (0 1)
	(k_pushreal,		$,	0),	!      (0 1)
	(k_pushreal32,		$,	0),	!      (0 1)
	(k_pushstring,		$,	0),	!      (0 1)
	(k_pushmem,			$,	0),	!      (0 1)
	(k_pushmemaddr,		$,	0),	!      (0 1)
	(k_popmem,			$,	0),	!      (1 0) 
	(k_storemem,		$,	0),	!      (1 1) 
	(k_opnd,			$,	0),	!      (0 0) 
	(k_addtoptr,		$,	0),	!      (1 1) 
	(k_suboffset,		$,	0),	!      (2 1) 
	(k_pushptroff,		$,	0),	!      (2 1) 
	(k_popptroff,		$,	0),	!      (3 0) 
	(k_storeptroff,		$,	0),	!      (3 1) 
	(k_pushptr,			$,	0),	!      (1 1) 
	(k_popptr,  		$,	0),	!      (2 0) 
	(k_storeptr,		$,	0),	!      (2 1) 
	(k_free,			$,	0),	!      (1 0) 
	(k_unstack,			$,	0),	!      (1 0) 
	(k_eval,			$,	0),	!      (1 0) 

	(k_callproc,		$,	0),	! n    (n 0) 
	(k_callfn,			$,	0),	! n    (n 1) 
	(k_callprocptr,		$,	0),	! n    (n+1 0) 
	(k_callfnptr,		$,	0),	! n    (n+1 1) 
	(k_retproc,			$,	0),	!      (0 0) 
	(k_retfn,			$,	0),	!      (0 0) 
	(k_syscallfn,		$,	0),	! n fn (n 1) 
	(k_syscallproc,		$,	0),	! n fn (n 0) 
	(k_setret,			$,	0),	!      (1 1) 
	(k_setretmult,		$,	0),	! n    (n n) 
	(k_setalign,		$,	0),	! n    (0 0) 

	(k_jump,			$,	0),	!      (0 0) goto L
	(k_jumpcc,			$,	1),	! cc   (2 0) goto L when cc
	(k_jumptrue,		$,	1),	!      (1 0) goto L when Xa is true
	(k_jumpfalse,		$,	1),	!      (1 0) L
	(k_jumpptr,			$,	0),	!      (1 0) goto Xa
	(k_jumpinrange,		$,	0),	!      (3 0) goto L when Xc in Yb..Za
	(k_jumpnotinrange,	$,	0),	!      (3 0) goto L when Xc not in Yb..Za
	(k_setjumpeq,		$,	0),	!      (2 1) goto L when 
	(k_setjumpeqx,		$,	0),	!      (2 2) 
	(k_setjumpne,		$,	0),	!      (2 2) 
	(k_setcc,			$,	1),	! cc   (2 1) X:=Xb cc Ya
	(k_casejumpeq,		$,	0),	!      (0 0) 
	(k_selectcc,		$,	1),	!      (4 1) Xa:=(Yb cc Za|Wd|Xc)
	(k_selecttrue,		$,	1),	!      (3 1) Xa:=(Za|Xc|Yb)

	(k_to,				$,	0),	!      (1 0) L
	(k_forup,			$,	0),	!      (2 0) L
	(k_fordown,			$,	0),	!      (2 0) L

	(k_swap,			$,	0),	!      (2 0) 
	(k_bin,				$,	1),	! op   (2 1) 
	(k_unary,			$,	1),	! op   (1 1) 
	(k_binto,			$,	1),	! op   (2 0) 
	(k_unaryto,			$,	1),	! op   (1 0) 
	(k_incr,			$,	1),	!      (1 0) 
	(k_incrx,			$,	1),	!      (1 1) 
	(k_convert,			$,	1),	!      (1 1) 
	(k_typepun,			$,	0),	!      (1 1) 
	(k_makerange,		$,	0),	!      (2 1) 
	(k_makeslice,		$,	0),	!      (2 1) 
	(k_makeset,			$,	0),	!      (n 1) 
	(k_makearray,		$,	0),	!      (n 1) 
	(k_dotindex,		$,	0),	!      (0 0) 
	(k_dotslice,		$,	0),	!      (2 1) 
	(k_popdotindex,		$,	0),	!      (3 0) 
	(k_storedotindex,	$,	0),	!      (3 1) 
	(k_popdotslice,		$,	0),	!      (4 0) 
	(k_storedotslice,	$,	0),	!      (4 1) 
	(k_slice,			$,	0),	!      (? ?) 
	(k_switch,			$,	0),	! x y  (0 0) A=jumptab label; info/A=elselab; minlab/maxlab
	(k_switchlabel,		$,	0),	!      (0 0) 
	(k_endswitch,		$,	0),	!      (0 0) 
	(k_db,				$,	0),	!      (0 0) 
	(k_dw,				$,	0),	!      (0 0) 
	(k_dd,				$,	0),	!      (0 0) 
	(k_dq,				$,	0),	!      (0 0) 
	(k_assem,			$,	0),	!      (0 0) 
	(k_dummy,			$,	0),	!      (0 0) 
end

global tabledata() []ichar sysfnnames, []byte sysfnparams, []byte sysfnres =
	(sysfn_mul_i128,			$,	2,	1),	
	(sysfn_idiv_i128,			$,	2,	1),
	(sysfn_float_u64_r64,		$,	1,	1),
	(sysfn_dotindex,			$,	2,	1),
	(sysfn_dotslice,			$,	3,	1),
	(sysfn_popdotindex,			$,	2,	0),
	(sysfn_popdotslice,			$,	3,	0),
	(sysfn_power_i64,			$,	2,	1),

	(sysfn_cmp_block,			$,	2,	1),

	(sysfn_init,				$,	0,	0),
	(sysfn_initstatics,			$,	0,	0),
	(sysfn_stop,				$,	1,	0),
	(sysfn_print_startfile,		$,	0,	0),
	(sysfn_print_startstr,		$,	0,	0),
	(sysfn_print_startptr,		$,	0,	0),
	(sysfn_print_startcon,		$,	0,	0),
	(sysfn_print_setfmt,		$,	0,	0),
	(sysfn_print_nogap,			$,	0,	0),
	(sysfn_print_i64,			$,	0,	0),
	(sysfn_print_i64_nf,		$,	0,	0),
	(sysfn_print_u64,			$,	0,	0),
	(sysfn_print_r64,			$,	0,	0),
	(sysfn_print_r32,			$,	0,	0),
	(sysfn_print_i128,			$,	0,	0),
	(sysfn_print_u128,			$,	0,	0),
	(sysfn_print_str,			$,	0,	0),
	(sysfn_print_str_nf,		$,	0,	0),
	(sysfn_print_strsl,			$,	0,	0),
	(sysfn_print_ptr,			$,	0,	0),
	(sysfn_print_ptr_nf,		$,	0,	0),
	(sysfn_print_c8,			$,	0,	0),
	(sysfn_print_newline,		$,	0,	0),
	(sysfn_print_end,			$,	0,	0),
	(sysfn_read_i64,			$,	0,	0),
	(sysfn_read_r64,			$,	0,	0),
	(sysfn_read_str,			$,	0,	0),
	(sysfn_read_fileline,		$,	0,	0),
	(sysfn_read_strline,		$,	0,	0),
	(sysfn_read_conline,		$,	0,	0),

	(sysfn_get_nprocs,			$,	0,	1),		!access functions
	(sysfn_get_nexports,		$,	0,	1),
	(sysfn_get_procname,		$,	0,	1),
	(sysfn_get_procaddr,		$,	0,	1),
	(sysfn_get_procexport,		$,	0,	1),

	(sysfn_nprocs,				$,	0,	0),		!data labels
	(sysfn_nexports,			$,	0,	0),
	(sysfn_procnames,			$,	0,	0),
	(sysfn_procaddrs,			$,	0,	0),
	(sysfn_procexports,			$,	0,	0),

	(sysfn_sin,					$,	1,	1),
	(sysfn_cos,					$,	1,	1),
	(sysfn_tan,					$,	1,	1),
	(sysfn_asin,				$,	1,	1),
	(sysfn_acos,				$,	1,	1),
	(sysfn_atan,				$,	1,	1),
	(sysfn_ln,					$,	1,	1),
	(sysfn_lg,					$,	1,	1),
	(sysfn_log,					$,	1,	1),
	(sysfn_exp,					$,	1,	1),
	(sysfn_floor,				$,	1,	1),
	(sysfn_ceil,				$,	1,	1),
	(sysfn_fract,				$,	1,	1),
	(sysfn_round,				$,	1,	1),
	(sysfn_lenstr_stringz,		$,	1,	1),

	(sysfn_atan2,				$,	2,	1),
	(sysfn_fmod,				$,	2,	1),


	(sysfn_initmemz_var,		$,	0,	0),
	(sysfn_freemem_var,			$,	0,	0),
	(sysfn_free_var,			$,	0,	0),
	(sysfn_share_var,			$,	0,	0),
	(sysfn_unshare_var,			$,	0,	0),
	(sysfn_dupl_var,			$,	0,	0),
	(sysfn_popmem_var,			$,	0,	0),
	(sysfn_storemem_var,		$,	0,	0),

	(sysfn_add_dec,         $,	0,	0),
	(sysfn_sub_dec,         $,	0,	0),
	(sysfn_mul_dec,         $,	0,	0),
	(sysfn_div_dec,         $,	0,	0),
	(sysfn_irem_dec,        $,	0,	0),
	(sysfn_shr_dec,         $,	0,	0),
	(sysfn_min_dec,         $,	0,	0),
	(sysfn_max_dec,         $,	0,	0),
	(sysfn_neg_dec,         $,	0,	0),
	(sysfn_abs_dec,         $,	0,	0),
	(sysfn_istruel_dec,     $,	0,	0),
	(sysfn_sqr_dec,         $,	0,	0),
	(sysfn_sqrt_dec,        $,	0,	0),
	(sysfn_addto_dec,       $,	0,	0),
	(sysfn_subto_dec,       $,	0,	0),
	(sysfn_multo_dec,       $,	0,	0),
	(sysfn_divto_dec,       $,	0,	0),
	(sysfn_idivto_dec,      $,	0,	0),
	(sysfn_iremto_dec,      $,	0,	0),
	(sysfn_shlto_dec,       $,	0,	0),
	(sysfn_shrto_dec,       $,	0,	0),
	(sysfn_minto_dec,       $,	0,	0),
	(sysfn_maxto_dec,       $,	0,	0),
	(sysfn_negto_dec,       $,	0,	0),
	(sysfn_absto_dec,       $,	0,	0),

	(sysfn_add_var,				$,	0,	0),
	(sysfn_sub_var,				$,	0,	0),
	(sysfn_mul_var,				$,	0,	0),
	(sysfn_div_var,				$,	0,	0),
	(sysfn_idiv_var,			$,	0,	0),
	(sysfn_irem_var,			$,	0,	0),
	(sysfn_power_var,			$,	0,	0),
	(sysfn_eq_var,				$,	0,	0),
	(sysfn_ne_var,				$,	0,	0),
	(sysfn_lt_var,				$,	0,	0),
	(sysfn_le_var,				$,	0,	0),
	(sysfn_ge_var,				$,	0,	0),
	(sysfn_gt_var,				$,	0,	0),
	(sysfn_isequal_var,			$,	0,	0),
	(sysfn_iand_var,			$,	0,	0),
	(sysfn_ior_var,				$,	0,	0),
	(sysfn_ixor_var,			$,	0,	0),
	(sysfn_shl_var,				$,	0,	0),
	(sysfn_shr_var,				$,	0,	0),
	(sysfn_andl_var,			$,	0,	0),
	(sysfn_orl_var,				$,	0,	0),
	(sysfn_append_var,			$,	0,	0),
	(sysfn_concat_var,			$,	0,	0),
	(sysfn_min_var,				$,	0,	0),
	(sysfn_max_var,				$,	0,	0),
	(sysfn_in_var,				$,	0,	0),
	(sysfn_notin_var,			$,	0,	0),

	(sysfn_neg_var,				$,	0,	0),
	(sysfn_abs_var,				$,	0,	0),
	(sysfn_inot_var,			$,	0,	0),
	(sysfn_notl_var,			$,	0,	0),
	(sysfn_istruel_var,		$,	0,	0),
	(sysfn_sqr_var,			$,	0,	0),
	(sysfn_sqrt_var,			$,	0,	0),
	(sysfn_sin_var,				$,	0,	0),
	(sysfn_cos_var,				$,	0,	0),
	(sysfn_tan_var,				$,	0,	0),
	(sysfn_asin_var,			$,	0,	0),
	(sysfn_acos_var,			$,	0,	0),
	(sysfn_atan_var,			$,	0,	0),
	(sysfn_exp_var,				$,	0,	0),
	(sysfn_ln_var,				$,	0,	0),
	(sysfn_log_var,				$,	0,	0),
	(sysfn_round_var,			$,	0,	0),
	(sysfn_floor_var,			$,	0,	0),
	(sysfn_ceil_var,			$,	0,	0),
	(sysfn_fract_var,			$,	0,	0),
	(sysfn_asc_var,				$,	0,	0),
	(sysfn_chr_var,				$,	0,	0),
	(sysfn_lwb_var,				$,	0,	0),
	(sysfn_upb_var,				$,	0,	0),
	(sysfn_len_var,				$,	0,	0),
	(sysfn_bounds_var,			$,	0,	0),

	(sysfn_addto_var,			$,	0,	0),
	(sysfn_subto_var,			$,	0,	0),
	(sysfn_multo_var,			$,	0,	0),
	(sysfn_divto_var,			$,	0,	0),
	(sysfn_idivto_var,			$,	0,	0),
	(sysfn_iremto_var,			$,	0,	0),
	(sysfn_iandto_var,			$,	0,	0),
	(sysfn_iorto_var,			$,	0,	0),
	(sysfn_ixorto_var,			$,	0,	0),
	(sysfn_shlto_var,			$,	0,	0),
	(sysfn_shrto_var,			$,	0,	0),
	(sysfn_andto_var,			$,	0,	0),
	(sysfn_orto_var,			$,	0,	0),
	(sysfn_andlto_var,			$,	0,	0),
	(sysfn_orlto_var,			$,	0,	0),
	(sysfn_appendto_var,		$,	0,	0),
	(sysfn_concatto_var,		$,	0,	0),
	(sysfn_minto_var,			$,	0,	0),
	(sysfn_maxto_var,			$,	0,	0),

	(sysfn_negto_var,			$,	0,	0),
	(sysfn_absto_var,			$,	0,	0),
	(sysfn_inotto_var,			$,	0,	0),
	(sysfn_notlto_var,			$,	0,	0),
	(sysfn_istruelto_var,		$,	0,	0),
	(sysfn_incrto_var,			$,	0,	0),
	(sysfn_decrto_var,			$,	0,	0),

	(sysfn_new_var,				$,	0,	0),
	(sysfn_print_var,			$,	0,	0),
	(sysfn_tostr_var,			$,	0,	0),
	(sysfn_getdot_var,			$,	0,	0),
	(sysfn_putdot_var,			$,	0,	0),
	(sysfn_getindex_var,		$,	0,	0),
	(sysfn_putindex_var,		$,	0,	0),
	(sysfn_getdotindex_var,		$,	0,	0),
	(sysfn_putdotindex_var,		$,	0,	0),
	(sysfn_getslice_var,		$,	0,	0),
	(sysfn_putslice_var,		$,	0,	0),
	(sysfn_getdotslice_var,		$,	0,	0),
	(sysfn_putdotslice_var,		$,	0,	0),
	(sysfn_getkeyindex_var,		$,	0,	0),
	(sysfn_putkeyindex_var,		$,	0,	0),
	(sysfn_insert_var,			$,	0,	0),
	(sysfn_delete_var,			$,	0,	0),
	(sysfn_resize_var,			$,	0,	0),

	(sysfn_make_int,			$,	0,	0),
	(sysfn_make_real,			$,	0,	0),
	(sysfn_make_string,			$,	0,	0),
	(sysfn_make_dec,			$,	0,	0),
	(sysfn_make_list,			$,	0,	0),
	(sysfn_make_listz,			$,	0,	0),
	(sysfn_make_array,			$,	0,	0),
	(sysfn_make_range,			$,	0,	0),

	(sysfn_var_to_int,			$,	0,	0),
	(sysfn_var_to_real,			$,	0,	0),
	(sysfn_var_to_string,		$,	0,	0),

end

global [sysfnnames.len]byte sysfnmap

global tabledata() [0:]ichar genopnames =
	(error_op=0,		$),

	(add_op,			$),
	(sub_op,			$),
	(mul_op,			$),
	(div_op,			$),
	(idiv_op,			$),
	(irem_op,			$),
	(iand_op,			$),
	(ior_op,			$),
	(ixor_op,			$),
	(shl_op,			$),
	(shr_op,			$),
	(in_op,				$),
	(notin_op,			$),
	(min_op,			$),
	(max_op,			$),
	(concat_op,			$),
	(append_op,			$),

	(neg_op,			$),
	(abs_op,			$),
	(inot_op,			$),

	(sqr_op,			$),
	(sqrt_op,			$),
	(sin_op,			$),
	(cos_op,			$),
	(tan_op,			$),
	(asin_op,			$),
	(acos_op,			$),
	(atan_op,			$),
	(ln_op,				$),
	(lg_op,				$),
	(log_op,			$),
	(exp_op,			$),
	(round_op,			$),
	(floor_op,			$),
	(ceil_op,			$),
	(fract_op,			$),
	(sign_op,			$),

	(atan2_op,			$),
	(power_op,			$),
	(fmod_op,			$),

	(lwb_op,			$),
	(upb_op,			$),
	(len_op,			$),
	(bounds_op,			$),
	(lenstr_op,			$),
	(bitwidth_op,		$),
	(bytesize_op,		$),
	(typestr_op,		$),
	(minvalue_op,		$),
	(maxvalue_op,		$),
	(sliceptr_op,		$),

	(incr_op,			$),
	(decr_op,			$),
	(incrload_op,		$),
	(decrload_op,		$),
	(loadincr_op,		$),
	(loaddecr_op,		$),

	(addto_op,			$),
	(subto_op,			$),
	(multo_op,			$),
	(divto_op,			$),
	(idivto_op,			$),
	(iremto_op,			$),
	(iandto_op,			$),
	(iorto_op,			$),
	(ixorto_op,			$),
	(shlto_op,			$),
	(shrto_op,			$),
	(appendto_op,		$),
	(concatto_op,		$),
	(minto_op,			$),
	(maxto_op,			$),

	(negto_op,			$),
	(absto_op,			$),
	(inotto_op,			$),

	(softconv_op,		$),
	(widen_op,			$),
	(float_op,			$),
	(fix_op,			$),
	(todec_op,			$),
	(decto_op,			$),
	(softtrunc_op,		$),
	(fwiden,			$),
	(fnarrow,			$),

	(truncate_op,		$),
	(arraytoslice_op,	$),
	(ichartostring_op,	$),
	(stringtostring_op,	$),
	(tostr_op,			$),
	(tostrfmt_op,		$),

	(eq_op,				$),
	(ne_op,				$),
	(lt_op,				$),
	(le_op,				$),
	(ge_op,				$),
	(gt_op,				$),
	(same_op,			$),

	(andl_op,			$),
	(orl_op,			$),
	(notl_op,			$),
	(istruel_op,		$),

	(andlto_op,			$),
	(orlto_op,			$),
	(notlto_op,			$),
	(istruelto_op,		$),

	(index_op,			$),
	(slice_op,			$),
	(dot_op,			$),
	(dotindex_op,		$),
	(dotslice_op,		$),

	(indexto_op,		$),
	(sliceto_op,		$),
	(dotto_op,			$),
	(dotindexto_op,		$),
	(dotsliceto_op,		$),

	(assign_op,			$),
	(makerange_op,		$),
end

global const firstgenop = genopnames.lwb
global const lastgenop = genopnames.upb

global tabledata() [0:]ichar specopnames =
	(op_error=0,          $),
	(op_add_i64,          $),
	(op_add_i128,         $),
	(op_add_r32,          $),
	(op_add_r64,          $),
	(op_add_dec,          $),
	(op_add_var,          $),
	(op_add_refoff,       $),

	(op_sub_i64,          $),
	(op_sub_i128,         $),
	(op_sub_r32,          $),
	(op_sub_r64,          $),
	(op_sub_dec,          $),
	(op_sub_ref,          $),
	(op_sub_var,          $),
	(op_sub_refoff,       $),

	(op_mul_i64,          $),
	(op_mul_i128,         $),
	(op_mul_r32,          $),
	(op_mul_r64,          $),
	(op_mul_dec,          $),
	(op_mul_var,          $),

	(op_div_r32,          $),
	(op_div_r64,          $),
	(op_div_dec,          $),

	(op_idiv_u64,         $),
	(op_idiv_i64,         $),
	(op_idiv_u128,        $),
	(op_idiv_i128,        $),
	(op_idiv_dec,         $),

	(op_irem_u64,         $),
	(op_irem_i64,         $),
	(op_irem_u128,        $),
	(op_irem_i128,        $),
	(op_irem_dec,         $),

	(op_iand_i64,         $),
	(op_iand_i128,        $),
	(op_iand_var,         $),

	(op_ior_i64,          $),
	(op_ior_i128,         $),
	(op_ior_var,          $),

	(op_ixor_i64,         $),
	(op_ixor_i128,        $),
	(op_ixor_var,         $),

	(op_shl_i64,          $),
	(op_shl_u128,         $),
	(op_shl_i128,         $),
	(op_shl_dec,          $),

	(op_shr_u64,          $),
	(op_shr_i64,          $),
	(op_shr_u128,         $),
	(op_shr_i128,         $),
	(op_shr_dec,          $),

	(op_min_u64,          $),
	(op_min_i64,          $),
	(op_min_u128,         $),
	(op_min_i128,         $),
	(op_min_r32,          $),
	(op_min_r64,          $),
	(op_min_dec,          $),

	(op_max_u64,          $),
	(op_max_i64,          $),
	(op_max_u128,         $),
	(op_max_i128,         $),
	(op_max_r32,          $),
	(op_max_r64,          $),
	(op_max_dec,          $),

	(op_concat_var,       $),

	(op_append_var,       $),

	(op_neg_i64,          $),
	(op_neg_i128,         $),
	(op_neg_r32,          $),
	(op_neg_r64,          $),
	(op_neg_dec,          $),

	(op_abs_i64,          $),
	(op_abs_i128,         $),
	(op_abs_r32,          $),
	(op_abs_r64,          $),
	(op_abs_dec,          $),

	(op_inot_i64,         $),
	(op_inot_i128,        $),
	(op_inot_var,         $),

	(op_sqr_i64,          $),
	(op_sqr_i128,         $),
	(op_sqr_r32,          $),
	(op_sqr_r64,          $),
	(op_sqr_dec,          $),

	(op_sqrt_i64,         $),
	(op_sqrt_i128,        $),
	(op_sqrt_r32,         $),
	(op_sqrt_r64,         $),
	(op_sqrt_dec,         $),

	(op_sin_r32,          $),
	(op_sin_r64,          $),
	(op_sin_dec,          $),

	(op_cos_r32,          $),
	(op_cos_r64,          $),
	(op_cos_dec,          $),

	(op_tan_r32,          $),
	(op_tan_r64,          $),
	(op_tan_dec,          $),

	(op_asin_r32,         $),
	(op_asin_r64,         $),
	(op_asin_dec,         $),

	(op_acos_r32,         $),
	(op_acos_r64,         $),
	(op_acos_dec,         $),

	(op_atan_r32,         $),
	(op_atan_r64,         $),
	(op_atan_dec,         $),

	(op_ln_r32,           $),
	(op_ln_r64,           $),
	(op_ln_dec,           $),

	(op_lg_r32,           $),
	(op_lg_r64,           $),
	(op_lg_dec,           $),

	(op_log_r32,          $),
	(op_log_r64,          $),
	(op_log_dec,          $),

	(op_exp_r32,          $),
	(op_exp_r64,          $),
	(op_exp_dec,          $),

	(op_round_r32,        $),
	(op_round_r64,        $),
	(op_round_dec,        $),

	(op_floor_r32,        $),
	(op_floor_r64,        $),
	(op_floor_dec,        $),

	(op_ceil_r32,         $),
	(op_ceil_r64,         $),
	(op_ceil_dec,         $),

	(op_fract_r32,        $),
	(op_fract_r64,        $),
	(op_fract_dec,        $),

	(op_sign_i64,         $),
	(op_sign_r32,         $),
	(op_sign_r64,         $),
	(op_sign_dec,         $),

	(op_atan2_r32,        $),
	(op_atan2_r64,        $),
	(op_atan2_dec,        $),

	(op_power_u64,        $),
	(op_power_i64,        $),
	(op_power_u128,       $),
	(op_power_i128,       $),
	(op_power_r32,        $),
	(op_power_r64,        $),
	(op_power_dec,        $),

	(op_fmod_r32,         $),
	(op_fmod_r64,         $),
	(op_fmod_dec,         $),

	(op_lwb_var,          $),

	(op_upb_slice,        $),
	(op_upb_var,          $),

	(op_len_slice,        $),
	(op_len_var,          $),

	(op_bounds_slice,     $),
	(op_bounds_var,       $),

	(op_lenstr_var,       $),
	(op_lenstr_ichar,     $),

	(op_sliceptr_slice,   $),

	(op_incr_short,       $),		!stands for all short types
	(op_incr_i64,         $),
	(op_incr_i128,        $),
	(op_incr_dec,         $),
	(op_incr_ref,         $),
	(op_incr_enum,        $),

	(op_decr_short,       $),
	(op_decr_i64,         $),
	(op_decr_i128,        $),
	(op_decr_dec,         $),
	(op_decr_ref,         $),
	(op_decr_enum,        $),

	(op_incrload_short,   $),
	(op_incrload_i64,     $),
	(op_incrload_i128,    $),
	(op_incrload_dec,     $),
	(op_incrload_ref,     $),
	(op_incrload_enum,    $),

	(op_decrload_short,   $),
	(op_decrload_i64,     $),
	(op_decrload_i128,    $),
	(op_decrload_dec,     $),
	(op_decrload_ref,     $),
	(op_decrload_enum,    $),

	(op_loadincr_short,   $),
	(op_loadincr_i64,     $),
	(op_loadincr_i128,    $),
	(op_loadincr_dec,     $),
	(op_loadincr_ref,     $),
	(op_loadincr_enum,    $),

	(op_loaddecr_short,   $),
	(op_loaddecr_i64,     $),
	(op_loaddecr_i128,    $),
	(op_loaddecr_r32,     $),
	(op_loaddecr_r64,     $),
	(op_loaddecr_dec,     $),
	(op_loaddecr_ref,     $),
	(op_loaddecr_enum,    $),

	(op_addto_short,      $),
	(op_addto_i64,        $),
	(op_addto_i128,       $),
	(op_addto_r32,        $),
	(op_addto_r64,        $),
	(op_addto_dec,        $),
	(op_addto_var,        $),
	(op_addto_refoff,     $),

	(op_subto_short,      $),
	(op_subto_i64,        $),
	(op_subto_i128,       $),
	(op_subto_r32,        $),
	(op_subto_r64,        $),
	(op_subto_dec,        $),
	(op_subto_refoff,     $),

	(op_multo_short,      $),
	(op_multo_i64,        $),
	(op_multo_i128,       $),
	(op_multo_r32,        $),
	(op_multo_r64,        $),
	(op_multo_dec,        $),

	(op_divto_r32,        $),
	(op_divto_r64,        $),
	(op_divto_dec,        $),

	(op_idivto_short,     $),
	(op_idivto_u64,       $),
	(op_idivto_i64,       $),
	(op_idivto_u128,      $),
	(op_idivto_i128,      $),
	(op_idivto_dec,       $),

	(op_iremto_short,     $),
	(op_iremto_u64,       $),
	(op_iremto_i64,       $),
	(op_iremto_u128,      $),
	(op_iremto_i128,      $),
	(op_iremto_dec,       $),

	(op_iandto_short,     $),
	(op_iandto_i64,       $),
	(op_iandto_i128,      $),

	(op_iorto_short,      $),
	(op_iorto_i64,        $),
	(op_iorto_i128,       $),

	(op_ixorto_short,     $),
	(op_ixorto_i64,       $),
	(op_ixorto_i128,      $),

	(op_shlto_short,      $),
	(op_shlto_i64,        $),
	(op_shlto_u128,       $),
	(op_shlto_i128,       $),
	(op_shlto_dec,        $),

	(op_shrto_short,      $),
	(op_shrto_u64,        $),
	(op_shrto_i64,        $),
	(op_shrto_u128,       $),
	(op_shrto_i128,       $),
	(op_shrto_dec,        $),

	(op_appendto_var,     $),

	(op_concatto_var,     $),

	(op_minto_u64,        $),
	(op_minto_i64,        $),
	(op_minto_u128,       $),
	(op_minto_i128,       $),
	(op_minto_r32,        $),
	(op_minto_r64,        $),
	(op_minto_dec,        $),

	(op_maxto_u64,        $),
	(op_maxto_i64,        $),
	(op_maxto_u128,       $),
	(op_maxto_i128,       $),
	(op_maxto_r32,        $),
	(op_maxto_r64,        $),
	(op_maxto_dec,        $),

	(op_negto_short,      $),
	(op_negto_i64,        $),
	(op_negto_i128,       $),
	(op_negto_r32,        $),
	(op_negto_r64,        $),
	(op_negto_dec,        $),

	(op_absto_short,      $),
	(op_absto_i64,        $),
	(op_absto_i128,       $),
	(op_absto_r32,        $),
	(op_absto_r64,        $),
	(op_absto_dec,        $),

	(op_inotto_short,     $),
	(op_inotto_i64,       $),
	(op_inotto_i128,      $),

	(op_softconv,         $),
	(op_softtrunc_short,  $),
	(op_softtrunc_128_64, $),
	(op_widen_u64_u128,   $),
	(op_widen_i64_i128,   $),
	(op_float_u64_r32,    $),
	(op_float_u64_r64,    $),
	(op_float_i64_r32,    $),
	(op_float_i64_r64,    $),
	(op_fix_r32_u64,      $),
	(op_fix_r32_i64,      $),
	(op_fix_r64_u64,      $),
	(op_fix_r64_i64,      $),
	(op_todec_u64_dec,    $),
	(op_todec_i64_dec,    $),
	(op_todec_r32_dec,    $),
	(op_todec_r64_dec,    $),
	(op_decto_dec_u64,    $),
	(op_decto_dec_i64,    $),
	(op_decto_dec_r32,    $),
	(op_decto_dec_r64,    $),

	(op_fwiden_r32_r64,   $),
	(op_fnarrow_r64_r32,  $),


	(op_truncate_i128,   $),		!hard truncation from i128 to 8/16/32/64
	(op_truncate_i64,    $),		!hard truncation from i64 to 8/16/32

	(op_ichartostring,    $),
	(op_arraytoslice,     $),
	(op_ichartoslice,     $),
	(op_charaxtoichar,    $),

	(op_tostr_c64,        $),
	(op_tostr_u64,        $),
	(op_tostr_i64,        $),
	(op_tostr_u128,       $),
	(op_tostr_i128,       $),
	(op_tostr_r32,        $),
	(op_tostr_r64,        $),
	(op_tostr_dec,        $),
	(op_tostr_ref,        $),
	(op_tostr_enum,       $),
	(op_tostr_var,        $),

	(op_tostrfmt_c64,     $),
	(op_tostrfmt_u64,     $),
	(op_tostrfmt_i64,     $),
	(op_tostrfmt_u128,    $),
	(op_tostrfmt_i128,    $),
	(op_tostrfmt_r32,     $),
	(op_tostrfmt_r64,     $),
	(op_tostrfmt_dec,     $),
	(op_tostrfmt_ref,     $),
	(op_tostrfmt_enum,    $),
	(op_tostrfmt_var,     $),

	(op_eq_i64,           $),
	(op_eq_i128,          $),
	(op_eq_r32,           $),
	(op_eq_r64,           $),
	(op_eq_dec,           $),
	(op_eq_ref,           $),
	(op_eq_enum,          $),
	(op_eq_var,           $),
	(op_eq_block,         $),

	(op_ne_i64,           $),
	(op_ne_i128,          $),
	(op_ne_r32,           $),
	(op_ne_r64,           $),
	(op_ne_dec,           $),
	(op_ne_ref,           $),
	(op_ne_enum,          $),
	(op_ne_var,           $),
	(op_ne_block,         $),

	(op_lt_u64,           $),
	(op_lt_i64,           $),
	(op_lt_u128,          $),
	(op_lt_i128,          $),
	(op_lt_r32,           $),
	(op_lt_r64,           $),
	(op_lt_dec,           $),
	(op_lt_ref,           $),
	(op_lt_enum,          $),
	(op_lt_var,           $),

	(op_le_u64,           $),
	(op_le_i64,           $),
	(op_le_u128,          $),
	(op_le_i128,          $),
	(op_le_r32,           $),
	(op_le_r64,           $),
	(op_le_dec,           $),
	(op_le_ref,           $),
	(op_le_enum,          $),
	(op_le_var,           $),

	(op_ge_u64,           $),
	(op_ge_i64,           $),
	(op_ge_u128,          $),
	(op_ge_i128,          $),
	(op_ge_r32,           $),
	(op_ge_r64,           $),
	(op_ge_dec,           $),
	(op_ge_ref,           $),
	(op_ge_enum,          $),
	(op_ge_var,           $),

	(op_gt_u64,           $),
	(op_gt_i64,           $),
	(op_gt_u128,          $),
	(op_gt_i128,          $),
	(op_gt_r32,           $),
	(op_gt_r64,           $),
	(op_gt_dec,           $),
	(op_gt_ref,           $),
	(op_gt_enum,          $),
	(op_gt_var,           $),

	(op_same_var,         $),

	(op_andl_i64,         $),

	(op_orl_i64,          $),

	(op_notl_i64,         $),

	(op_istruel_i64,      $),
	(op_istruel_i128,     $),
	(op_istruel_r32,      $),
	(op_istruel_r64,      $),
	(op_istruel_dec,      $),
	(op_istruel_ref,      $),
	(op_istruel_enum,     $),
	(op_istruel_var,      $),

	(op_andlto_i64,       $),

	(op_orlto_i64,        $),

	(op_notlto_i64,       $),

	(op_istruelto_i64,    $),

	(op_dummy,            $),
end

global ref pclrec allpclcode

global int labelno=0
global [sysfnnames.len]int sysfnproclabels

global int mlineno
global byte fshowpst
=== bb_lib.m 5/40 ===
import msys
import mlib
import clib
import oslib

import bb_decls
import bb_tables
import bb_support
import bb_lex
import bb_diags
import bb_pclcommon


int autotypeno=0
global int nextavindex=0
int nextsvindex=0

strbuffer exprstrvar
ref strbuffer exprstr=&exprstrvar

const int unitheapsize=32768
ref unitrec unitheapptr=nil
int remainingunits=0

strbuffer sbuffer
global ref strbuffer dest=&sbuffer

global ichar framevarname			!normally nil, set to frame var def to display in comment

global function newstrec:ref strec=
ref strec p
p:=pcm_alloc(strec.bytes)
memset(p,0,strec.bytes)

p^.pos:=lx.pos
p^.moduleno:=currmoduleno
return p
end

global function getduplnameptr(ref strec owner,symptr,int id)ref strec=
ref strec p,q

p:=newstrec()

p^.name:=symptr^.name
p^.namelen:=symptr^.namelen
p^.symbol:=namesym
p^.owner:=owner
p^.nameid:=id
p^.namecat:=defaultnamecat[id]

if id=frameid or id=paramid then
fi

p^.nextdupl:=symptr^.nextdupl
p^.firstdupl:=symptr
symptr^.nextdupl:=p

return p
end

global proc adddef(ref strec owner,p)=
ref strec q

if q:=p^.nextdupl then
	if q^.owner=owner then
		cpl q^.name,"in",owner^.name
		serror("Duplicate name")
	fi
fi

if owner.haspdef then
	CPL "LATE ADDDEF",p.name
	return
fi

if owner^.deflist=nil then			!first def
	owner^.deflist:=p
else
	owner^.deflistx^.nextdef:=p
fi

owner^.deflistx:=p

end


global function createname(ref strec p)ref unitrec=
ref unitrec u

u:=allocunitrec()
u^.tag:=j_name
u^.def:=p

return u
end

global function createunit0(int tag)ref unitrec=
ref unitrec u

u:=allocunitrec()
u^.tag:=tag
return u
end

global function createunit1(int tag, ref unitrec p)ref unitrec=
ref unitrec u
u:=allocunitrec()
u.tag:=tag
u.a:=p
u.hasa:=1
return u
end

global function createunit2(int tag, ref unitrec p,q)ref unitrec=
ref unitrec u

u:=allocunitrec()

u^.tag:=tag
u^.a:=p
u^.b:=q
u.hasa:=1
u.hasb:=1
return u
end

global function createunit3(int tag, ref unitrec p,q,r)ref unitrec=
ref unitrec u

u:=allocunitrec()
u^.tag:=tag
u^.a:=p
u^.b:=q
u^.c:=r
u.hasa:=1
u.hasb:=1
u.hasc:=1
return u
end

global proc insertunit(unit p,int tag)=		!INSERTUNIT
unit q,nextunit
int mode

q:=allocunitrec()
q^:=p^
mode:=q^.mode
nextunit:=q^.nextunit
q^.nextunit:=nil

memset(p,0,unitrec.bytes)
p^.tag:=tag
p^.pos:=q^.pos
p^.a:=q
p.hasa:=1
p^.mode:=mode
p^.nextunit:=nextunit
p.resultflag:=q.resultflag
end

global proc deleteunit(unit p,q)=
unit r:=p^.nextunit
p^:=q^
p^.nextunit:=r
end

global function createconstunit(word64 a, int t)ref unitrec=
ref unitrec u
u:=allocunitrec()
u^.tag:=j_const
u^.value:=a
u^.mode:=t

if t in [ti128,tu128] then
	u.value128:=ref int128(a)^
fi

u^.isconst:=1
return u
end

global function createstringconstunit(ichar s, int length)ref unitrec=
ref unitrec u
u:=allocunitrec()
u^.tag:=j_const
u^.svalue:=s
u^.mode:=trefchar
u^.isastring:=1
if length=-1 then
	u^.slength:=strlen(s)
else
	u^.slength:=length
fi
return u
end

global function getoptocode(int opc)int=		!GETOPTOCODE
static [0:jtagnames.len]int16 opctotable
int n,opcto,i
[20]char str

opcto:=opctotable[opc]
if opcto then return opcto fi				!find

strcpy(&.str,jtagnames[opc])					!"add" etc
strcat(&.str,"to")							!"addto" etc

for i:=0 to jtagnames.upb do
	if eqstring(jtagnames[i],&.str) then
		opctotable[opc]:=i
		return i
	fi
od

cpl jtagnames[opc]
serror("Can't find -to version")
return 0
end

global function createtype(ref strec d)int=			!CREATETYPE

if d^.nameid=typeid then	!has already been resolved as type
	return d^.mode
fi
return createusertype(d)
end


global function newtypename(ref strec a,b)int=
	if ntypenames>=maxtypename then
		serror("Too many type names")
	fi
	++ntypenames
	typenames[ntypenames].defa:=a		!leave .owner/.pmode to be filled in
	typenames[ntypenames].defb:=b		!used type's mode is used

	typenamepos[ntypenames].pos:=lx.pos

	return -ntypenames
end

global function createusertype(ref strec stname)int=
if ntypes>=maxtype then
cpl ntypes,stname^.name
	serror("Too many types")
fi

++ntypes
ttname[ntypes]:=stname^.name

ttnamedef[ntypes]:=stname
ttbasetype[ntypes]:=tvoid
ttlineno[ntypes]:=lx.pos

stname^.mode:=ntypes

return ntypes
end

global function createusertypefromstr(ichar name)int=
ref strec stname

stname:=getduplnameptr(stmodule,addnamestr(name),typeid)


return createusertype(stname)
end

global function getconstvalue(ref unitrec p,int ID=0)int64=	!GETCONSTVALUE
if p and p^.tag=j_const then
	return p^.value
fi
serror("GCV Not constant")
return 0
end

global function getrangelwbunit(ref unitrec p)ref unitrec=				!GETRANGELWB
if p^.tag=j_makerange then
	return p^.a
else
	p:=createunit1(j_unary,p)
	p.genop:=lwb_op
	return p
fi
end

global function getrangeupbunit(ref unitrec p)ref unitrec=				!GETRANGEUPB
if p^.tag=j_makerange then
	return p^.b
else
	p:=createunit1(j_unary,p)
	p.genop:=upb_op
	return p
fi
end

global function createarraymode(ref strec owner,int target,unit dimexpr, int typedefx)int=		!CREATEARRAYMODE
int k,m


if typedefx=0 then		!anon type
	for k:=tlast to ntypes do
		if ttusercat[k]=0 and ttbasetype[k]=tarray and tttarget[k]=target and
				sameunit(dimexpr, ttdimexpr[k],owner, ttowner[k]) then
			return k
		fi
	od
	m:=createusertypefromstr(nextautotype())
else
	m:=typedefx
fi

ttbasetype[m]:=(target in [tu1,tu2,tu4]|tbits|tarray)
ttlower[m]:=1
ttdimexpr[m]:=dimexpr
storemode(owner,target,tttarget[m])
ttowner[m]:=owner
settt(m, pcltype:tblock, tabtype:tblock)

return m
end

proc settt(int m, pcltype=0, tabtype=0, tabtype2=0)=
	if pcltype then
		ttpcltype[m]:=pcltype
	fi
	if tabtype2=0 then tabtype2:=tabtype fi
	if tabtype then
		tttabtype[m]:=tabtype
	fi
	if tabtype2 then
		tttabtype2[m]:=tabtype2
	fi


	ttcat[m]:=stdcat[pcltype]
	ttcat2[m]:=stdcat2[pcltype]
end


function sameunit(unit p,q, ref strec powner=nil, qowner=nil)int=
	ref strec d,e

	if p=q then return 1 fi
	if p=nil or q=nil then return 0 fi

	if p.tag<>q.tag then return 0 fi

	case p.tag
	when j_const then
		return p.value=q.value
	when j_makerange,j_keyvalue then
		return sameunit(p.a, q.a) and sameunit(p.b, q.b)
	when j_name then
		if p.def=q.def and powner=qowner then
			return 1
		fi
	esac

	return 0

end

global function createarraymodek(ref strec owner,int target,int lower,length, int typedefx)int=		!CREATEARRAYMODE
int atype,k,m

atype:=tarray

if typedefx=0 then		!anon type
	m:=createusertypefromstr(nextautotype())
else
	m:=typedefx
fi

ttbasetype[m]:=atype
ttlower[m]:=lower
ttlength[m]:=length
IF TARGET<0 THEN
	SERROR("CREATEARRAYMODEK/TARGET NOT RESOLVED")
FI
ttsize[m]:=length*ttsize[target]

storemode(owner,target,tttarget[m])
ttowner[m]:=owner
settt(m, pcltype:tblock, tabtype:tblock)

return m
end


global function nextautotype:ichar=
static [32]char str

print @&.str,"$T",,++autotypeno
return &.str
end

global proc converttoslice(int t,sltype)=
ttbasetype[t]:=sltype
ttsize[t]:=ttsize[tslice]
end

global function createslicemode(ref strec owner,int slicetype,target,unit dimexpr, int typedefx=0)int=
int k,m

if typedefx=0 then		!anon type
	m:=createusertypefromstr(nextautotype())
else
	m:=typedefx
fi

ttbasetype[m]:=slicetype
if dimexpr then
	ttdimexpr[m]:=dimexpr
else
	ttlower[m]:=1
fi
storemode(owner,target,tttarget[m])
ttowner[m]:=owner
settt(m, pcltype:tu128, tabtype:tslice)

return m
end

global function createslicemodek(ref strec owner,int target,lower, int typedefx=0)int=
int k,m

if typedefx=0 then		!anon type
	m:=createusertypefromstr(nextautotype())
else
	m:=typedefx
fi

ttbasetype[m]:=tslice
ttlower[m]:=lower
storemode(owner,target,tttarget[m])
ttowner[m]:=owner
settt(m, pcltype:tu128, tabtype:tslice)

return m
end

global function createrefmode(ref strec owner,int target,typedefx=0)int=		!CREATEREFPACKMODE
int k,m

if typedefx=0 then		!anon type
	for k:=tlast to ntypes do
		if ttusercat[k]=0 and ttbasetype[k]=tref and tttarget[k]=target then
			return k
		fi
	od
	m:=createusertypefromstr(nextautotype())
else
	m:=typedefx
fi

storemode(owner,target,tttarget[m])
ttbasetype[m]:=(target in [tu1,tu2,tu4]|trefbit|tref)
ttsize[m]:=ttsize[tref]
ttisref[m]:=1
settt(m, pcltype:tu64, tabtype:tref)

return m
end



global function createrefprocmode(ref strec owner,stproc, paramlist,int kwd, prettype,typedefx)int=		!CREATEREFPROCMODE
int m, mproc

mproc:=createusertype(stproc)


stproc.paramlist:=paramlist
stproc.mode:=prettype
ttbasetype[mproc]:=tproc
ttpcltype[mproc]:=tu64

if typedefx=0 then		!anon type
	m:=createusertypefromstr(nextautotype())
else
	m:=typedefx
fi


tttarget[m]:=mproc
ttbasetype[m]:=tref

ttsize[m]:=ttsize[tref]
ttisref[m]:=1
settt(m, pcltype:tu64, tabtype:tref)

return m
end

global function createdictmode(ref strec owner,int keytype, valuetype,int typedefx=0)int=
int m

if typedefx=0 then		!anon type
	m:=createusertypefromstr(nextautotype())
else
	m:=typedefx
fi

ttbasetype[m]:=tdict
storemode(owner,valuetype,tttarget[m])
storemode(owner,keytype,ttkeytype[m])
ttowner[m]:=owner
ttsize[m]:=ttsize[tdict]
settt(m, pcltype:tdict, tabtype:tdict, tabtype2:tvar)

return m
end

global proc copyttvalues(int dest, source)=
	ttisint[dest]		:= ttisint[source]
	ttisword[dest]		:= ttisword[source]
	ttisreal[dest]		:= ttisreal[source]
	ttisinteger[dest]	:= ttisinteger[source]
	ttisallnum[dest]	:= ttisallnum[source]
	ttismainnum[dest]	:= ttismainnum[source]
	ttisshort[dest]		:= ttisshort[source]
	ttisref[dest]		:= ttisref[source]
	ttpcltype[dest]		:= ttpcltype[source]
	tttabtype[dest]		:= tttabtype[source]
	tttabtype2[dest]	:= tttabtype2[source]
	ttcat[dest]			:= ttcat[source]
	ttcat2[dest]		:= ttcat2[source]

end

global proc setnameptr(ref unitrec p)=		!SETNAMEPTR

p^.def^.code:=p
end

global function getdottedname(ref strec p)ichar=		!GETDOTTEDNAME
static [256]char str
[256]char str2
ref strec owner

strcpy(&.str,p^.name)
owner:=p^.owner
while owner and owner^.nameid<>programid do
	strcpy(&.str2,&.str)
	strcpy(&.str,owner^.name)
	strcat(&.str,".")
	strcat(&.str,&.str2)
	owner:=owner^.owner
od
return &.str
end

global function getavname(ref strec owner,int id=frameid)ref strec=
ref strec p
[32]char str
ichar name

if id=frameid and owner^.nameid<>procid then
	serror("Auto frame not in proc")
fi

if id=frameid then
	print @&.str,"av$",,++nextavindex
else
	print @&.str,"sv$",++nextsvindex
fi

name:=pcm_copyheapstring(&.str)
addnamestr(name)

p:=getduplnameptr(owner,addnamestr(name),id)
p^.namecat:=frame_cat
p^.used:=1

p^.mode:=tint

adddef(owner,p)
return p
end

global proc unionstr_clear(ref uflagsrec u)=

((ref word64(u))^:=0)		!clear flags and length togetjer
end

global proc unionstr_append(ref uflagsrec u, int c)=
if u^.ulength=(u^.codes.len-1) then
	serror("Uflags overflow/a")
fi
++u^.ulength
u^.codes[u^.ulength]:=c
end

global proc unionstr_concat(ref uflagsrec u, v)=
int ulen,vlen,i

ulen:=u^.ulength
vlen:=v^.ulength
if ulen+vlen>u^.codes.len then
	serror("Uflags overflow/c")
fi
for i:=1 to vlen do
	u^.codes[i+ulen]:=v^.codes[i]
od
u^.ulength:=ulen+vlen
end

global function unionstr_last(ref uflagsrec u)int=
if u^.ulength then
	return u^.codes[u^.ulength]
fi
return 0 
end

global proc unionstr_copy(ref uflagsrec u,v)=
memcpy(u,v,uflagsrec.bytes)
end

global proc unionstr_print(ref uflagsrec u)=
printstrn(cast(&u^.codes),u^.ulength)
end

global function createrecordmode(ref strec owner,int typedefx)int=	!CREATERECORDMODE
int m

if typedefx=0 then
	m:=createusertype(owner)
else
	m:=typedefx
fi
ttbasetype[m]:=trecord
ttusercat[m]:=1
settt(m, pcltype:tblock, tabtype:tblock)

return m
end

global function createtaggedunionmode(ref strec owner,int typedefx)int=	!CREATERECORDMODE
int m

if typedefx=0 then
	m:=createusertype(owner)
else
	m:=typedefx
fi
ttbasetype[m]:=ttagunion
ttusercat[m]:=1

return m
end

global function createtuplemode(ref strec owner,slice[]int elements,int typedefx)int=
int m

if typedefx=0 then
	m:=createusertype(owner)
else
	m:=typedefx
fi
ttbasetype[m]:=ttuple
ttusercat[m]:=1
ttlength[m]:=elements.len
ttmult[m]:=pcm_alloc(elements.len*int32.bytes)
for i to elements.len do
	storemode(owner,elements[i],ttmult[m,i])
od

return m
end

global function createenummode(ref strec owner,int typedefx)int=
int m

if typedefx=0 then
	m:=createusertype(owner)
else
	m:=typedefx
fi
ttbasetype[m]:=tenum
ttusercat[m]:=1
settt(m, pcltype:tu64, tabtype:tu64)

return m
end

global proc convertstring(ichar s, t)=		!CONVERTSTRING
int c

while c:=s++^ do
	switch c
	when '"' then
		t++^:='\\'
		t++^:='"'
	when 10 then
		t++^:='\\'
		t++^:='n'
	when 13 then
		t++^:='\\'
		t++^:='c'
	when 9 then
		t++^:='\\'
		t++^:='t'
	when '\\' then
		t++^:='\\'
		t++^:='\\'
	when 7,8,26,27 then
		t++^:='<'
		t++^:=c/10+'0'
		t++^:=(c rem 10)+'0'
		t++^:='>'
	else
		t++^:=c
	endswitch
od
t^:=0
end

global function strexpr(ref unitrec p)ref strbuffer=		!STREXPR
gs_init(exprstr)

jeval(exprstr,p)
return exprstr
end

global proc jeval(ref strbuffer dest, ref unitrec p)=			!JEVAL
unit q,a,b
[500]char str

if p=nil then
	return
fi

a:=p^.a
b:=p^.b

switch p^.tag
when j_const then

	case ttbasetype[p^.mode]
	when ti32,ti64,ti8,ti16 then
		getstrint(p.value,&.str)
	when tu32,tu64,tu8,tu16 then
		strcpy(&.str,strword(p.uvalue))
	when tc8,tc16,tc64 then
		str[1]:=p.uvalue
		str[0]:=0
	when ti128 then
		print @&.str,p.value128
	when tu128 then
		print @&.str,p.uvalue128

	when treal then
		print @&.str,p^.xvalue
	when tref then
		if p^.mode=trefchar and p^.isastring then
			if p^.slength>str.len/2 then
				strcpy(&.str,"LONGSTR)")
			else
				convertstring(p^.svalue,&.str)
			fi
			gs_additem(dest,"""")
			gs_additem(dest,&.str)
			gs_additem(dest,"""")
			return
		else
			print @&.str,ref void(p^.value)
		fi
	else
SPRINTF(&.STR,"<EVAL/CONST PROBABLY VOID>")
	esac
	gs_additem(dest,&.str)

when j_name then
	gs_additem(dest,p^.def^.name)

when j_bin,j_cmp then

	strcpy(&.str,genopnames[p.genop])
	gs_additem(dest,"(")
	jeval(dest,a)
	gs_additem(dest,&.str)
	jeval(dest,b)
	gs_additem(dest,")")

when j_unary then

	strcpy(&.str,genopnames[p.genop])
	gs_additem(dest,&.str)
	gs_additem(dest,"(")
	jeval(dest,a)
	gs_additem(dest,")")

when j_callfn,j_callproc then
	jeval(dest,a)
	gs_additem(dest,"(")

	q:=b
	while q do
		jeval(dest,q)
		q:=q^.nextunit
		if q then gs_additem(dest,",") fi
	od
	gs_additem(dest,")")

when j_index,j_dotindex,j_slice,j_dotslice then
	jeval(dest,a)
	if p^.tag=j_dotindex or p^.tag=j_dotslice then
		gs_additem(dest,".")
	fi
	gs_additem(dest,"[")
	jeval(dest,b)
	gs_additem(dest,"]")

when j_dot then
	jeval(dest,a)
	gs_additem(dest,".")
	jeval(dest,b)

when j_makelist then
	gs_additem(dest,"(")

	q:=a
	while q do
		jeval(dest,q)
		q:=q^.nextunit
		if q then gs_additem(dest,",") fi
	od
	gs_additem(dest,")")

when j_makerange then
	gs_additem(dest,"(")
	jeval(dest,a)
	gs_additem(dest,"..")
	jeval(dest,b)
	gs_additem(dest,")")

when j_assign then
	jeval(dest,a)
	gs_additem(dest,":=")
	jeval(dest,b)

when j_if then
	gs_additem(dest,"(")
	jeval(dest,a)
	gs_additem(dest,"|")
	jeval(dest,b)
	gs_additem(dest,"|")
	jeval(dest,p^.c)
	gs_additem(dest,")")

when j_typeconst then
	gs_additem(dest,strmode(p^.mode))

when j_convert then

	gs_additem(dest,strmode(p^.convmode))
	gs_additem(dest,"(")
	jeval(dest,a)
	gs_additem(dest,")")

when j_shorten then

	gs_additem(dest,"shorten(")
	jeval(dest,a)
	gs_additem(dest,")")
when j_autocast then

	gs_additem(dest,"cast(")
	jeval(dest,a)
	gs_additem(dest,")")
when j_keyvalue then
	jeval(dest,a)
	gs_additem(dest,":")
	if b then
		jeval(dest,p^.b)
	else
		gs_str(dest,"-")
	fi

when j_ptr then
	jeval(dest,a)
	gs_additem(dest,"^")

when j_clamp then
	gs_additem(dest,"(")
	jeval(dest,a)
	gs_additem(dest,",")
	jeval(dest,b)
	gs_additem(dest,",")
	jeval(dest,p^.c)
	gs_additem(dest,")")

when j_block then
	gs_additem(dest,"<JBLOCK>")

when j_null then
	gs_str(dest,"<nullunit>")

when j_addrof then
	gs_additem(dest,"&")
	jeval(dest,a)
	if b then
		gs_str(dest,"+")
		gs_strint(dest,b.value)
	fi

when j_addroffirst then
	gs_additem(dest,"&.")
	jeval(dest,a)


when j_typestr then
	gs_additem(dest,"TYPESTR(")
	jeval(dest,a)
	gs_additem(dest,")")

when j_cvlineno, j_cvfilename, j_cvmodulename then
	gs_str(dest,"$")
	gs_str(dest,jtagnames[p^.tag]+2)

when j_bitfield then
	jeval(dest,a)
	gs_str(dest,".")
	gs_str(dest,bitfieldnames[p^.opindex])

when j_fmtitem then
	jeval(dest,a)
	gs_str(dest,":")
	jeval(dest,b)

when j_typeof then
	gs_str(dest,"typeof(")
	jeval(dest,a)
	gs_str(dest,")")

when j_syscall then
	gs_str(dest,sysfnnames[p.fnindex]+6)
	gs_str(dest,"(")
	if a then jeval(dest,a) fi
	gs_str(dest,")")



else
	CPL jtagnames[p^.tag]
	gerror("CAN'T DO JEVAL",p)
end
end

global function getopcjname(int opc)ichar=		!GETOPCJNAME
int i
[20]char str

ABORTPROGRAM("GETOPCJNAME")
return jtagnames[opc]+2				!return standard jtag name
end

global function strmode(int m,expand=1)ichar=		!STRMODE
static [4096]char str
istrmode(m,expand,&.str)
return &.str
end

global function strmode2(int m,expand=1)ichar=		!STRMODE
static [4096]char str
istrmode(m,expand,&.str)
return &.str
end

global proc istrmode(int m,expand=1,ichar dest)=		!ISTRMODE
ref strec d,q,e
int value,needcomma,x,i,target,mbase,n
strbuffer sxx
ref strbuffer xx:=&sxx
ref strbuffer sdim,slength
[100]char strdim
ichar prefix
typenamerec tn


if m<0 then
	strcpy(dest,"XX*")
	tn:=typenames[-m]

	if tn.defb=nil then			!assume typeof
		strcat(dest,"typeof(")
		strcat(dest,tn.defa.name)
		strcat(dest,")")
    else
		if tn.defa then
			strcat(dest,tn.defa.name)
			strcat(dest,".")
		fi
		strcat(dest,tn.def.name)
	fi
	return
fi

if m<tlast and m<>tref then
	strcpy(dest,typename(m))
	return
fi

case mbase:=ttbasetype[m]
when tref then
	strcpy(dest,"ref ")
	target:=tttarget[m]
	if target>=0 and ttbasetype[target]=trecord then
		strcat(dest,typename(target))
	else
		istrmode(tttarget[m],0,dest+strlen(dest))
	fi

when trefbit then
	strcpy(dest,"refbit ")
	istrmode(tttarget[m],0,dest+strlen(dest))


when tarray,tbits then
	if ttdimexpr[m] then
		gs_copytostr(strexpr(ttdimexpr[m]),&.strdim)
		fprint @dest,"@[#]",&.strdim
	else
		if ttlength[m] then
			if ttlower[m]=1 then
				fprint @dest,"[#]",ttlength[m]+ttlower[m]-1
			else
				fprint @dest,"[#..#]",ttlower[m],ttlength[m]+ttlower[m]-1
			fi
		else
			if ttlower[m]=1 then
				fprint @dest,"[]"
			else
				fprint @dest,"[#:]",ttlower[m]
			fi
		fi
	fi
	istrmode(tttarget[m],0,dest+strlen(dest))

when tslice,tlist then
	prefix:=stdnames[mbase]

	if ttdimexpr[m] then
		gs_copytostr(strexpr(ttdimexpr[m]),&.strdim)
		fprint @dest,"@#[#:]",prefix,&.strdim
	else
		if ttlower[m]=1 then
			strcpy(dest,prefix)
			strcat(dest,"[]")
		else
			fprint @dest,"#[#:]",prefix,ttlower[m]
		fi
	fi
	istrmode(tttarget[m],0,dest+strlen(dest))

when tdict then
	strcpy(dest,"dict[")
	istrmode(ttkeytype[m],0,dest+strlen(dest))
	strcat(dest,"]")
	istrmode(tttarget[m],0,dest+strlen(dest))

when tenum then
	d:=ttnamedef[m]
	if not expand then
		strcpy(dest,d.name)
		return
	fi

	strcpy(dest,"enum(")

	value:=1
	needcomma:=0
	q:=d^.deflist
	while q do
		if needcomma then strcat(dest,",") fi
		needcomma:=1
		strcat(dest,q^.name)
		q:=q^.nextdef
	od

	strcat(dest,")")

when trecord,ttagunion then
	if not expand then
		strcpy(dest,typename(m))
		return
	fi
	strcpy(dest,"")
	if expand<>2 then
		strcat(dest,typename(ttbasetype[m]))
	fi
	strcat(dest,"(")
	d:=ttnamedef[m]
	needcomma:=0

	q:=d^.deflist
	while q do
		if needcomma then strcat(dest,",") fi
		needcomma:=1
		istrmode(q^.mode,0,dest+strlen(dest))
		strcat(dest," ")
		strcat(dest,q^.name)
		q:=q^.nextdef
	od
	strcat(dest,")")

when tvoid then			!must be a usertype that is not defined (as normal voids checked above)
	strcpy(dest,"void")

when tuser then
	strcpy(dest,typename(m))
when tproc then

	d:=ttnamedef[m]

	strcpy(dest,"proc(")
	q:=d^.paramlist
	needcomma:=0
	while q<>nil do
		if needcomma then strcat(dest,",") fi
		needcomma:=1
		istrmode(q^.mode,0,dest+strlen(dest))
		strcat(dest," ")
		strcat(dest,q^.name)
		q:=q^.nextdef
	od
	strcat(dest,")")
	if d^.mode<>tvoid then
		istrmode(d^.mode,0,dest+strlen(dest))
	fi

when ttuple then
	strcpy(dest,"Tuple(")
	n:=ttlength[m]
	for i to n do
		istrmode(ttmult[m,i],0,dest+strlen(dest))
		if i<n then strcat(dest,",") fi
	od

	strcat(dest,")")



when tbitfield then
	strcpy(dest,"bitfield")

elsif ttbasetype[m]<tlast then
	strcpy(dest,"Alias for:")
	istrmode(tttarget[m],0,dest+strlen(dest))

else
CPL typename(m),STRMODE(TTBASETYPE[M])
	mcerror("NEWSTRMODE")
esac
end


global function finddefstr(ref strec owner,ichar name)ref strec=	!FINDDEFSTRING
ref strec d

d:=owner^.deflist
while d do
	if eqstring(d^.name,name) then
		return d
	fi
	d:=d^.nextdef
od

return nil
end

global proc addtoproclist(ref strec d)=
	ref procrec pp
	++nproclist
	pp:=pcm_alloc(procrec.bytes)

	if proclist=nil then
		proclist:=proclistx:=pp
	else
		proclistx.nextproc:=pp
		proclistx:=pp
	fi
	pp^.def:=d
end

global proc addstatic(ref strec d)=
	ref procrec pp
	++nstaticlist
	pp:=pcm_alloc(procrec.bytes)

	if staticlist=nil then
		staticlist:=staticlistx:=pp
	else
		staticlistx.nextproc:=pp
		staticlistx:=pp
	fi

	pp^.def:=d
end

global proc addconst(ref strec d)=
	ref procrec pp
	++nconstlist
	pp:=pcm_alloc(procrec.bytes)

	if constlist=nil then
		constlist:=constlistx:=pp
	else
		constlistx.nextproc:=pp
		constlistx:=pp
	fi
	pp^.def:=d
end

global function typename(int m)ichar=
	if m>=0 then
		return ttname[m]
	fi
	return typenames[-m].def.name

end

global function allocunitrec:ref unitrec=
ref unitrec p
ref int64 q
int nwords


if remainingunits-- then
	p:=unitheapptr
	++unitheapptr
	p^.pos:=lx.pos
	p^.moduleno:=currmoduleno
	return p
fi

p:=unitheapptr:=pcm_alloc(unitheapsize*unitrec.bytes)

memset(p,0,unitheapsize*unitrec.bytes)
remainingunits:=unitheapsize-1
++unitheapptr
p.pos:=lx.pos

p^.moduleno:=currmoduleno
return p
end

global function createdupldef(ref strec owner,symptr, int id)ref strec=
ref strec p,q

p:=newstrec()

p^.name:=symptr^.name
p^.namelen:=symptr^.namelen
p^.symbol:=namesym
p^.owner:=owner
p^.nameid:=id

p^.nextdupl:=symptr^.nextdupl
symptr^.nextdupl:=p

if owner then
	if owner^.deflist=nil then			!first def
		owner^.deflist:=owner^.deflistx:=p
	else
		owner^.deflistx^.nextdef:=p
		owner^.deflistx:=p
	fi
fi

return p
end

global function createnewmoduledef(ref strec owner,symptr)ref strec=
ref strec p,q

p:=createdupldef(owner,symptr,moduleid)
return p
end

global function duplunit(unit p,int lineno=0)unit=
unit q
if p=nil then return nil fi


q:=createunit0(p^.tag)

q^:=p^
q.nextunit:=nil
if q.hasa then q.a:=duplunit(q.a); q.hasa:=1 fi
if q.hasb then q.b:=duplunit(q.b); q.hasb:=1 fi
if q.hasc then q.c:=duplunit(q.c); q.hasc:=1 fi

return q
end




global function checkblockreturn(unit p)int=
unit e,wt
int m,res

if p=nil then return 0 fi

m:=p.mode

case p^.tag
when j_return then			!that's an easy one...
	return 1
when j_stop then
	return 1
when j_if then
	p.ifretflag:=1
	return checkblockreturn(p^.b) and checkblockreturn(p^.c)		!all branches must have a return

when j_longif then
	e:=p^.a
	p.ifretflag:=1
	while e do
		if not checkblockreturn(e^.b) then
			return 0
		fi
		e:=e^.nextunit
	od
	return checkblockreturn(p^.b)		!else must have return too
when j_block then
	e:=p^.a
	if e then
		while e and e^.nextunit do
			e:=e^.nextunit
		od
		return checkblockreturn(e)
	fi

when j_case, j_switch, j_docase, j_doswitch then
	p.ifretflag:=1
	wt:=p^.b
	while wt do
		if not checkblockreturn(wt^.b) then
			return 0
		fi

		wt:=wt^.nextunit
	od

	return checkblockreturn(p^.c)		!else

when j_assem then						!assume yes
	return 1
esac

if jisexpr[p.tag] and m<>tvoid then
	return 1							!any non-void expr allowed as return value
else
	return 0
fi
end

global function isconstunit(unit a)int=
return a^.isconst
end


global proc getownername(ref strec d, ichar dest)=
ref strec owner

owner:=d^.owner

if owner=nil or owner^.nameid=programid then return fi
getownername(owner,dest)
strcat(dest,owner^.name)
strcat(dest,".")
end

global function strconstopnd(unit p)ichar=
	static [256]char str
	int i,a,t
	real32 x32

	t:=p^.mode
	a:=p^.value

	if t=trefchar then
		if p^.slength>=256 then
			print @&.str,"""",,"(LONGSTR)",""" *",,p^.slength
		elsif p^.slength then
			print @&.str,"""",,p^.svalue,,""" *",,p^.slength
		else
			print @&.str,""""""
		fi

	elsecase ttbasetype[t]
	when ti8 then print @&.str,int8(a)
	when ti16 then print @&.str,int16(a)
	when ti32 then print @&.str,int32(a)
	when ti64 then print @&.str,int64(a)
	when tu8 then print @&.str,word8(a)
	when tu16 then print @&.str,word16(a)
	when tu32 then print @&.str,word32(a)
	when tu64 then print @&.str,word64(a)
	when tc8,tc16,tc64 then
 print @&.str,"C64"
	when tr32 then
		x32:=p^.xvalue
		print @&.str,real64(x32)
	when tr64 then
		print @&.str,p^.xvalue
	when ti128 then
		print @&.str,p.value128
	when tu128 then
		print @&.str,p.uvalue128
	when tref then
		if p^.value then
			print @&.str,"#",,p^.value,P^.SLENGTH
		else
			print @&.str,"NIL"
		fi
	else
		cpl typename(t),typename(ttbasetype[t])
		gerror("STROPND CONST?")

	fi

	return &.str
end

global function getalignment(int m)int=
int a

case ttbasetype[m]
when tarray then
	return getalignment(tttarget[m])
when trecord then
	RETURN 16
esac


a:=ttsize[m]
case a
when 1,2,4,8,16 then
	return a
when 0 then
	return 8
esac
cpl Strmode(m)
gerror("GETALIGN SIZE NOT 1248")

return 0
end

global function ispoweroftwo(int64 x)int=
int64 a
int n

a:=1
n:=0
to 60 do
	++n
	a:=a<<1
	if a=x then
		return n
	fi
od
return 0
end

global proc addlistunit(ref unit ulist,ulistx,unit p)=
if ulist^=nil then		!first
	ulist^:=ulistx^:=p
else
	ulistx^^.nextunit:=p
fi
ulistx^:=p			!update end-of-list pointer
end

global function issimpletype(int m, biss)int=
	if ttcat[m]=var_cat then
		return 0
	fi

	if not biss and ttpcltype[m]=tblock then
		return 0
	fi
	return 1
end

global function getlow128(ref int128 a)word=
	return cast(a,ref word)^
end

global function gethigh128(ref int128 a)word=
	return (cast(a,ref word)+1)^
end

global proc putlow128(ref int128 a,word x)=
	cast(a,ref word)^:=x
end

global proc puthigh128(ref int128 a,word x)=
	(cast(a,ref word)+1)^:=x
end


global function storemode(ref strec owner, int m, int32 &pmode)int =
	ref typenamerec r

	if m>=0 then
		pmode:=m
		return m
	fi

	r:=&typenames[-m]


	if r.pmode=nil then
		r.owner:=owner
		pmode:=m
		r.pmode:=&pmode

IF R.PMODE=NIL THEN SERROR("PMODE=NIL") FI

		return m
	fi

	m:=newtypename(r.defa, r.defb)
	r:=&typenames[-m]

	r.owner:=owner
	pmode:=m
	r.pmode:=&pmode
	return m
end

global proc addoverload(int moduleno, opc, amode, bmode, rmode, unit pfunc)=
	ref overloadrec p
	ref strec owner


	p:=pcm_allocz(overloadrec.bytes)

	p.moduleno:=moduleno
	owner:=moduletable[moduleno].stmodule
	storemode(stmodule, amode, p.amode)
	storemode(stmodule, bmode, p.bmode)
	storemode(stmodule, rmode, p.rmode)
	p.fncode:=pfunc

	p.nextoverload:=overloadtable[opc]

	overloadtable[opc]:=p
end

global function gettypebase(int m)int=
	switch ttbasetype[m]
	when ti8,ti16,ti32 then ti64
	when tu8,tu16,tu32 then ti64

	when tr32 then

CPL "GETTYPEBASE R32=R64?"
 tr64

	when tc8,tc16 then tc64
	else
		m
	end switch
end

global proc writegsfile(ichar filename, ref strbuffer d)=
	filehandle f

	f:=fopen(filename,"w")
	gs_println(d,f)
	fclose(f)
end

global proc addtolog(ichar filename, filehandle logdest)=
filehandle f
int c

f:=fopen(filename,"rb")

if f=nil then return fi

do
	c:=fgetc(f)
	exit when c=c_eof
	fputc(c,logdest)
od
fclose(f)
end

global function getprocretmodes(unit p)ref strec=
ref strec d
unit a

if p^.tag<>j_callfn then txerror("multass/need multfn") fi
a:=p^.a

case a^.tag
when j_name then
	return a^.def
else
	return ttnamedef[tttarget[a^.mode]]
esac
end

global function getmemmode(unit p)int =
	if p.memmode then
		return p.memmode
	fi
	return p.mode
end

global function getmemsize(unit p)int =
	if p.memmode then
		return ttsize[p.memmode]
	fi
	return ttsize[p.mode]
end

global function isvar(int m)int=
	return ttcat[m]=var_cat
end

global function isvarnd(int m)int=
	if m=tdecimal then return 0 fi
	return ttcat[m]=var_cat
end

global function isnum(int m)int=

	if m>=tfirstnum and m<=tlastnum then
		return 1
	fi
	return 0
end

global function isboolunit(unit p)int=

	case p.tag
	when j_cmp,j_andl, j_orl, j_notl, j_istruel, j_inrange, j_inset,
			j_cmpchain then
		return 1
	else
		0
	esac
end



global proc addcclib(ichar name)=
	for i to ncclibs do
		if eqstring(name, cclibtable[i]) then return fi
	od
	if ncclibs>=maxcclibs then serror("Too many cclibs") fi
	cclibtable[++ncclibs]:=pcm_copyheapstring(name)
end
=== msyslib.m 6/40 ===
import clib
import mlib

global record procinforec=
	word16		fnindex
	byte		rettype
	byte		nparams
	[12]byte	paramlist
end

record fmtrec=	! (default)
	byte	minwidth	! n (0)   min field width (0 if not used or don't care)
	i8		precision	! .n (0)   number of decimals/significant figures/max width
	byte	base		! B,H or Xn (10)  2 to 16

	char	quotechar	! Qc (0)   0 or '"' or c
	char	padchar		! Pc, Z (' ')
	char	realfmt		! E,F,G ('f') 'e' or 'f' or 'g'

	char	plus		! (0)   0 or '+'
	char	sepchar		! Sc (0)   0 or ',' or c placed every 3 (base=10) or 4 digits
	char	lettercase	! A,a ('A') 'A' or 'a'
	char	justify		! JL, JR, JC ('R') 'L' or 'R' or 'C'?
	char	suffix		! Tc (0)   0 or 'B' or 'H' or c
	char	usigned		! W (0)   0 or 'W' force unsigned o/p for ints (eg. for hex display)
	char	charmode	! C,D (0)  0 or 'C' or 'D'	o/p int as int or single char or double/multi-char
	char	heapmode	! M (0)  'M' for str-functions, return ptr tp heap string
	char	param		! Use int value for <fmtparam>
	byte	spare
end

int fmtparam			!as set with :'V'

enum (std_io,file_io,str_io)

const comma = ','

global int needgap			= 0
int outdev			= std_io
filehandle outchan	= nil
ref char fmtstr 	= nil

const maxiostack=10
[maxiostack]filehandle	outchan_stack
[maxiostack]int			outdev_stack
[maxiostack]ref char	fmtstr_stack
[maxiostack]byte		needgap_stack

[maxiostack]ref char	ptr_stack		!this one doesn't need pushing, as each is pointed to from outchan
int niostack=0

[0:]char digits=A"0123456789ABCDEF"
const onesixty=360
fmtrec defaultfmt = (0,0, 10, 0,' ','f', 0,0,0,'R',0,0, 0,0,0,0)

const rd_buffersize = 16384	!total capacity of line buffer

ref char rd_buffer		! point to start of read buffer
int rd_length			! length of this line (as read by readln)
ref char rd_pos			! current position it's up to (next read starts here)
ref char rd_lastpos		! set by sread() just before reading used for reread()
int termchar			! terminator char set by readxxx()
int itemerror			!	set by some read functions, eg for reals


const maxparam=128
global int nsysparams
global [maxparam]ichar sysparams

const maxcallback=8
[0..maxcallback,8]word64 callbackstack
int ncallbacks=0

word64 mask63	= 0x7FFF'FFFF'FFFF'FFFF
real offset64	= 9223372036854775808.0		! 2**63 as r64
real offset32	= 9223372036854775808.0		! 2**63 as r32

global proc m$init=
int32 nargs
int nargs64
ref[]ichar args
ref[]ichar env
static [128]byte startupinfo			! 68 or 104 bytes
int res
ichar s


res:=__getmainargs(&nargs,cast(&args),cast(&env),0,cast(&startupinfo))

nsysparams:=nargs

if nsysparams>maxparam then
	printf("Too many params\n")
	stop 50
fi

nargs64:=nargs			!bug when using 32-bit limit when compild with mm
for i:=1 to nargs64 do
	sysparams[i]:=args^[i]
od

m$print_startcon()		!allow most print stmts without startcon/end

end

global proc m$stop(int n)=
	`exit(n)
end

global function m$lenstr_stringz(ref char s)int=
	strlen(s)
end



proc pushio=
	if niostack>=maxiostack then
		printf("Too many io levels\n")
		stop 53
	fi
	++niostack
	outchan_stack[niostack]	:= outchan
	outdev_stack[niostack]	:= outdev
	fmtstr_stack[niostack]	:= fmtstr
	needgap_stack[niostack]	:= needgap
	needgap:=0
	fmtstr:=nil
	outchan:=nil
end

global proc m$print_startfile(ref void dev)=
	pushio()
	outchan:=cast(dev)
	if dev then
		outdev:=file_io
	else
		outdev:=std_io
	fi
end

global proc m$print_startstr(ref char s)=
	ref ref char p
	pushio()

	ptr_stack[niostack]:=s
	p:=&ptr_stack[niostack]

	outchan:=cast(p)
	outdev:=str_io
end

global proc m$print_startptr(ref ref char p)=
	pushio()

	outchan:=cast(p)
	outdev:=str_io
end

global proc m$print_startcon=
	pushio()
	outdev:=std_io
end

global proc m$print_setfmt(ref char format)=
	fmtstr:=format
end

global proc m$print_end=
	needgap:=0
	nextfmtchars(1)
	if niostack=0 then return fi
	outchan	:= outchan_stack[niostack]
	outdev	:= outdev_stack[niostack]
	fmtstr	:= fmtstr_stack[niostack]
	needgap	:= needgap_stack[niostack]
	--niostack
end

global proc m$print_ptr(u64 a,ichar fmtstyle=nil)=
	[20]char s

	if fmtstyle=nil then
		fmtstyle:="z8H"
	fi
	m$print_u64(a,fmtstyle)
end

global proc m$print_ptr_nf(u64 a)=
	m$print_ptr(a)
end

global proc m$print_i64(int64 a,ichar fmtstyle=nil)=
	[40]char s
	fmtrec fmt
	int n

	nextfmtchars()
	if fmtstyle=nil then
		if a>=0 then
			n:=u64tostr(a,&.s,10,0)
		else
			s[1]:='-'
			n:=u64tostr(-a,&s[2],10,0)+1
		fi
		printstr_n(&.s,n)

	else

		strtofmt(fmtstyle,-1,&fmt)
		if fmt.param='V' then
			fmtparam:=a
			needgap:=0
		else
			tostr_i64(a,&fmt)
		fi
	fi
	needgap:=1
end

global proc m$print_i64_nf(int64 a)=
	m$print_i64(a)
end

global proc m$print_u64(word64 a,ichar fmtstyle=nil)=
	[40]char s
	fmtrec fmt

	nextfmtchars()
	if fmtstyle=nil then
		sprintf(&.s,"%llu",a)
		printstr(&.s)
	else
		strtofmt(fmtstyle,-1,&fmt)
		tostr_u64(a,&fmt)
	fi
	needgap:=1
end

global proc m$print_i128(int128 a,ichar fmtstyle=nil)=
	[40]char s
	fmtrec fmt

	nextfmtchars()
	strtofmt(fmtstyle,-1,&fmt)
	if a>=0 then
		tostr_u128(a,&fmt,0)
	else
		tostr_u128(-a,&fmt,1)
	fi

	needgap:=1
end

global proc m$print_u128(word128 a,ichar fmtstyle=nil)=
	[40]char s
	fmtrec fmt

	nextfmtchars()
	strtofmt(fmtstyle,-1,&fmt)
	tostr_u128(a,&fmt,0)
	needgap:=1
end

global proc m$print_r64(real x,ichar fmtstyle=nil)=
	[360]char s
	fmtrec fmt

	nextfmtchars()
	if fmtstyle=nil then
		sprintf(&.s,"%f",x)
		printstr(&.s)
	else
		strtofmt(fmtstyle,-1,&fmt)
		tostr_r64(x,&fmt)
	fi

	needgap:=1
end

global proc m$print_r32(real32 x,ichar fmtstyle=nil)=
	m$print_r64(x,fmtstyle)
end

global proc m$print_c8(int64 a,ichar fmtstyle=nil)=
	[40]char s
	fmtrec fmt
	int n

	nextfmtchars()

	s[1]:=a
	s[2]:=0
	printstr(&.s)
	needgap:=1
end

global proc m$print_str(ichar s, fmtstyle=nil)=
	nextfmtchars()

	if s=nil then
		printstr("<null>")
		return
	fi


	fmtrec fmt
	if fmtstyle=nil then
		printstr(s)
	else
		strtofmt(fmtstyle,-1,&fmt)
		tostr_str(s,&fmt)
	fi
	needgap:=1
end

global proc m$print_str_nf(ichar s)=
	m$print_str(s)
end

global proc m$print_strsl(slice[]char s, ichar fmtstyle=nil)=
	nextfmtchars()
	fmtrec fmt
	if fmtstyle=nil then
		printstr_n(cast(s.sliceptr),s.len)
	else
		abortprogram("FORMATED PRINT SLICE NOT READY")
	fi
	needgap:=1
end

global proc m$print_newline=
	needgap:=0
	nextfmtchars(1)
	printstr("\w")
end

global proc m$print_nogap=
	needgap:=0
end

global proc printstr(ichar s)=
	int n
	ref ref char p

	case outdev
	when std_io then
		printf("%s",s)
	when file_io then
		fprintf(outchan,"%s",s)
	when str_io then
		p:=cast(outchan)
		strcpy(p^,s)
		p^+:=strlen(s)
		p^^:=0
	esac
end

global proc printstr_n(ichar s,int n=-1)=
	ref ref char p

	case n
	when -1 then n:=strlen(s)
	when 0 then return
	esac

	case outdev
	when std_io then
		printf("%.*s",n,s)
	when file_io then
		fprintf(outchan,"%.*s",n,s)
	when str_io then
		p:=cast(outchan)
		memcpy(p^,s,n)
		p^+:=n
		p^^:=0
	esac
end

global proc printstrn_app(ichar s, int length, filehandle f=nil)=
if length then
	if f=nil then
		printf("%.*s",length,s)
	else
		fprintf(f,"%.*s",length,s)
	fi
fi
end

proc printchar(int ch)=
	ref ref char p
	case outdev
	when std_io then
		printf("%c",ch)
	when file_io then
		fprintf(outchan,"%c",ch)
	when str_io then
		p:=cast(outchan)
		p^^:=ch
		p^+:=1
		p^^:=0
	esac
end

global proc nextfmtchars(int lastx=0)=
	char c
	ref char pstart
	int n
	if not fmtstr then			!format not in use
		if needgap then
			printchar(' ')
		fi
		needgap:=0
		return
	fi

	pstart:=fmtstr
	n:=0

	do
		c:=fmtstr^
		switch c
		when '#' then
			if lastx then
				goto skip
			fi
			++fmtstr
			if n then
				printstr_n(pstart,n)
			fi
			return
		when 0 then
			if n then
				printstr_n(pstart,n)
			elsif not lastx then
				printstr_n("|",1)
			fi
			return
		when '~' then
			if n then
				printstr_n(pstart,n)
				n:=0
			fi
			++fmtstr
			c:=fmtstr^
			if c then
				++fmtstr
				printchar(c)
			fi
			pstart:=fmtstr
		else
	skip::
			++n
			++fmtstr
		endswitch
	od
end

global proc strtofmt(ref char s,int slen,ref fmtrec fmt) =		!PC_STRTOFMT

	int c
	byte wset
	int n
	[0:100]char str

	fmt^:=defaultfmt

	if s=nil then return fi

	if slen=-1 then slen:=strlen(s) fi

	memcpy(&.str,s,slen)		!convert s/slen to zero-terminated string
	str[slen]:=0
	s:=&.str

	wset:=0
	while s^ do
		c:=s^
		++s
		switch c
		when 'B', 'b' then fmt^.base:=2
		when 'H', 'h' then fmt^.base:=16
		when 'O', 'o' then fmt^.base:=8
		when 'X', 'x' then
			c:=s^
			if c then
				switch c
				when '0'..'9' then c:=c-'0'
				when 'A'..'F' then c:=c-'A'+10
				when 'a'..'f' then c:=c-'a'+10
				else
					c:=10
				end
				fmt^.base:=c
				++s
			fi
		when 'Q', 'q' then fmt^.quotechar:='"'
		when '~' then fmt^.quotechar:='~'
		when 'J', 'j' then
			fmt^.justify:=toupper(s^)
			if s^ then
				++s
			fi
		when 'A' then fmt^.lettercase:='A'
		when 'a' then fmt^.lettercase:='a'
		when 'Z', 'z' then fmt^.padchar:='0'
		when 'S', 's' then
			fmt^.sepchar:=s^
			if s^ then
				++s
			fi
		when 'P', 'p' then
			fmt^.padchar:=s^
			if s^ then
				++s
			fi
		when 'T', 't' then
			fmt^.suffix:=s^
			if s^ then
				++s
			fi
		when 'W', 'w' then fmt^.usigned:='W'
		when 'E', 'e' then fmt^.realfmt:='e'
		when 'F', 'f' then fmt^.realfmt:='f'
		when 'G', 'g' then fmt^.realfmt:='g'
		when '.' then
			wset:=1
		when comma,'_' then fmt^.sepchar:=c
		when '+' then fmt^.plus:='+'
		when 'D', 'd' then fmt^.charmode:='D'
		when 'C', 'c' then fmt^.charmode:='C'
		when 'M', 'm' then fmt^.heapmode:='M'
		when 'V','v' then fmt.param:='V'
		when '*' then
			n:=fmtparam
			goto gotwidth
		else
			if c>='0' and c<='9' then
				n:=c-'0'
				do
					c:=s^
					if s^=0 then
						exit
					fi
					if c>='0' and c<='9' then
						++s
						n:=n*10+c-'0'
					else
						exit
					fi
				od
gotwidth::
				if not wset then
					fmt^.minwidth:=n
					wset:=1
				else
					fmt^.precision:=n
				fi
			fi
		endswitch
	od
end

function domultichar (ref char p,int n,ref char dest,ref fmtrec fmt)int =
	[0:20]char str
	ref char q
	int i,nchars

	q:=&.str

	nchars:=n

	to n do
		if p^=0 then exit fi
		q^:=p^
		++q
		++p
	od
	q^:=0

	return expandstr(&.str,dest,strlen(&.str),fmt)
end

function expandstr(ref char s,ref char t,int n,ref fmtrec fmt)int =		!EXPANDSTR

	int i,w,m

	w:=fmt^.minwidth
	if w=0 or w<=n then		! allow str to be longer than minwidth
		strncpy(t,s,n)
		(t+n)^:=0
		return n
	fi

	if fmt^.justify='L' then	! left-justify
		strncpy(t,s,n)
		t+:=n
		for i:=1 to w-n do
			t^:=fmt^.padchar
			++t
		od
		t^:=0
	elsif fmt^.justify='R' then
		if fmt^.padchar='0' and fmt^.base and (s^='-' or s^='+') then ! need to move sign outside 
			t^:=s^
			++t
			to w-n do
				t^:=fmt^.padchar
				++t
			od
			strncpy(t,s+1,n-1)
			(t+n-1)^:=0
		else
			to w-n do
				t^:=fmt^.padchar
				++t
			od
			strncpy(t,s,n)
			(t+n)^:=0
		fi

	else				! centre-justify?

		m:=(w-n+1)/2
		to m do
			t^:=fmt^.padchar
			++t
		od
		strncpy(t,s,n)
		t+:=n
		to w-n-m do
			t^:=fmt^.padchar
			++t
		od
		t^:=0

	fi
	return w
end


function u64tostr(u64 aa,ref char s,word base,int sep)int =		!U64TOSTR
	[0:onesixty]char t
	u64 dd
	int i,j,k,g
	int cc
	int dummy
	ref char s0

	i:=0
	k:=0
	g:=(base=10|3|4)

	repeat
		dd:=aa rem base
		aa:=aa/base

		t[++i]:=digits[dd]

		++k
		if sep and aa<>0 and k=g then
			t[++i]:=sep
			k:=0
		fi
	until aa=0

	j:=i
	s0:=s
	while i do
		s^:=t[i--]
		++s
	od
	s^:=0

	return j
end

function u128tostr(u128 aa,ref char s,word base,int sep)int =
	[0:160]char t
	u64 dd
	int i,j,k,g
	int dummy
	ref char s0

	i:=0
	k:=0
	g:=(base=10|3|4)

	repeat
		aa:=xdivrem128(aa,base,dd)
		t[++i]:=digits[dd]


		++k
		if sep and aa<>0 and k=g then
			t[++i]:=sep
			k:=0
		fi
	until aa=0

	j:=i
	s0:=s
	while i do
		s^:=t[i--]
		++s
	od
	s^:=0

	return j
end

function xdivrem128(word128 a, word64 b, &remainder)word128=
	word128 d,e,r
	word rlow

	d:=a/b
	r:=a-d*b

	assem
		mov d0,[r]
		mov [rlow],d0
	end
	remainder:=rlow
	return d
end

function i64tostrfmt(i64 aa,ref char s,ref fmtrec fmt)int =
	[0:onesixty]char str				! allow for binary with separators!
	int i,j,k,n,w,usigned
	const i64 mindint=0x8000'0000'0000'0000

	usigned:=0
	if fmt^.usigned then
		usigned:=1
	fi

	if aa=mindint and not usigned then		! minint

		str[0]:='-'
		n:=i64mintostr(&str[1],fmt^.base,fmt^.sepchar)+1
	else
		if (not usigned and aa<-0) or fmt^.plus then
			if aa<0 then
				aa:=-aa
				str[0]:='-'
			else
				str[0]:='+'
			fi
			n:=u64tostr(aa,&str[1],fmt^.base,fmt^.sepchar)+1
		else
			n:=u64tostr(aa,&.str,fmt^.base,fmt^.sepchar)
		fi
	fi

	if fmt^.suffix then
		str[n]:=fmt^.suffix
		str[++n]:=0
	fi

	if (fmt^.base>10 or fmt^.suffix) and fmt^.lettercase='a'	then	! need lower when
		convlcstring(&.str)
	fi

	return expandstr(&.str,s,n,fmt)
end

function u64tostrfmt(i64 aa,ref char s,ref fmtrec fmt)int =		!U64TOSTRFMT
	[0:onesixty]char str				! allow for binary with separators!
	int i,j,k,n,w

	n:=u64tostr(aa,&.str,fmt^.base,fmt^.sepchar)

	if fmt^.suffix then
		str[n]:=fmt^.suffix
		str[++n]:=0
	fi

	if fmt^.base>10 or fmt^.suffix and fmt^.lettercase='a'	then	! need lower when
	fi

	return expandstr(&.str,s,n,fmt)
end

function u128tostrfmt(i128 aa,ref char s,ref fmtrec fmt)int =		!U64TOSTRFMT
	[0:onesixty]char str				! allow for binary with separators!
	int i,j,k,n,w

	n:=u128tostr(aa,&.str,fmt^.base,fmt^.sepchar)

	if fmt^.suffix then
		str[n]:=fmt^.suffix
		str[++n]:=0
	fi

	if fmt^.base>10 or fmt^.suffix and fmt^.lettercase='a'	then	! need lower when
		convlcstring(&.str)
	fi

	return expandstr(&.str,s,n,fmt)
end

function i64mintostr(ref char s,int base,int sep)int =		!I64MINTOSTR
	[0:onesixty]char t
	int i,j,k,g,neg

	switch base
	when 10 then
		strcpy(&t[0],"9223372036854775808")
		j:=3
	when 16 then
		strcpy(&t[0],"8000000000000000")
		j:=1
	when 2 then
		strcpy(&t[0],"1000000000000000000000000000000000000000000000000000000000000000")
		j:=7
	else
		strcpy(&t[0],"<mindint>")
	endswitch

	i:=strlen(&t[0])
	s+:=i
	if sep then
		s+:=j
	fi
	s^:=0

	k:=0
	g:=(base=10|3|4)

	while i do
		--s
		s^:=t[i-- -1]
		if sep and i and ++k=g then
			--s
			s^:=sep
			k:=0
		fi
	od
	return strlen(s)
end

function strtostrfmt(ref char s,ref char t,int n,ref fmtrec fmt)int =
	ref char u,v
	[256]char str
	int w,nheap		! whether any heap storage is used  bytes allocated

	nheap:=0

	if fmt^.quotechar or fmt^.lettercase then		! need local copy
		if n<256 then
			u:=&.str
		else
			nheap:=n+3					! allow for quotes+terminator
			u:=pcm_alloc(nheap)
		fi
		if fmt^.quotechar then
			v:=u
			v^:=fmt^.quotechar
			++v
			if n then
				strcpy(v,s)
				v+:=n
			fi
			v^:=fmt^.quotechar
			++v
			v^:=0
			n+:=2
		else
			memcpy(u,s,n)
		fi
		switch fmt^.lettercase
		when 'a' then	! need lower when
			convlcstring(u)
		when 'A' then
			convucstring(u)
		endswitch
		s:=u
	fi

	w:=fmt^.minwidth
	if w>n then
		n:=expandstr(s,t,n,fmt)
	else
		memcpy(t,s,n)
	fi
	if nheap then
		pcm_free(u,nheap)
	fi
	return n
end

proc tostr_i64(int64 a, ref fmtrec fmt)=
	[360]char str
	int n

	case fmt^.charmode
	when 0 then
		n:=i64tostrfmt(a,&.str,fmt)
	when 'D','d' then
		n:=domultichar(ref char(&a),8,&.str,fmt)

	else						!assume 'C'
		printchar(a)			!no other formatting allowed
		return
	esac

	printstr_n(&.str,n)
end

proc tostr_u64(word64 a, ref fmtrec fmt)=
	[360]char str
	int n

	case fmt^.charmode
	when 'D','d' then
		n:=domultichar(ref char(&a),8,&.str,fmt)

	when 'C','c' then
		printchar(a)			!no other formatting allowed
		return

	else
		n:=u64tostrfmt(a,&.str,fmt)
	esac

	printstr_n(&.str,n)
end

proc tostr_u128(word128 a, ref fmtrec fmt,int neg)=
	[360]char str
	int n

	case fmt^.charmode
	when 'D','d' then
		n:=domultichar(ref char(&a),8,&.str,fmt)

	when 'C','c' then
		printchar(a)			!no other formatting allowed
		return

	else
		if neg then
			str[1]:='-'
			n:=u128tostrfmt(a,&str[2],fmt)+1
		else
			n:=u128tostrfmt(a,&.str,fmt)
		fi
	esac

	printstr_n(&.str,n)
end

proc tostr_r64(real x,ref fmtrec fmt) =
	[360]char str,str2
	[0:10]char cfmt
	int n

	cfmt[0]:='%'

	if fmt^.precision then
		cfmt[1]:='.'
		cfmt[2]:='*'
		cfmt[3]:=fmt^.realfmt
		cfmt[4]:=0
		sprintf(&.str,&.cfmt,fmt^.precision,x)
	else
		cfmt[1]:=fmt^.realfmt
		cfmt[2]:=0
		sprintf(&.str,&.cfmt,x)
	fi


	n:=strlen(&.str)		! current length

	if n<fmt^.minwidth then
		n:=expandstr(&.str,&.str2,n,fmt)
		strcpy(&.str,&.str2)
	fi

	printstr_n(&.str,n)
end

proc tostr_str(ref char s, ref fmtrec fmt) =
	int oldlen,newlen,n
	ref char t

	oldlen:=strlen(s)
	newlen:=oldlen

	if fmt^.quotechar or fmt^.minwidth>newlen or fmt^.lettercase or fmt.precision then
		if fmt^.quotechar then
			newlen+:=2
		fi
		if fmt^.minwidth>newlen then
			newlen:=fmt^.minwidth
		fi
		t:=pcm_alloc(newlen+1)
		n:=strtostrfmt(s,t,oldlen,fmt)
		if fmt.precision then
			n min:=fmt.precision
		fi

		printstr_n(t,n)
		pcm_free(t,newlen+1)
	else
		printstr_n(s,oldlen)
	fi
end

global function getfmt(ichar fmtstyle)ref fmtrec=
	static fmtrec fmt
	if fmtstyle then
		strtofmt(fmtstyle,-1,&fmt)
		return &fmt
	else
		return &defaultfmt
	fi
end

global function strint(int64 a, ichar fmtstyle=nil)ichar=
	static [100]char str
	ref fmtrec fmt

	m$print_startstr(&.str)
	tostr_i64(a,fmt:=getfmt(fmtstyle))
	m$print_end()
	return getstr(&.str,fmt)
end

global proc getstrint(int64 a, ichar dest)=
	m$print_startstr(dest)
	tostr_i64(a,getfmt(nil))
	m$print_end()
end

global function strword(word64 a, ichar fmtstyle=nil)ichar=
	static [100]char str
	ref fmtrec fmt

	m$print_startstr(&.str)
	tostr_u64(a,fmt:=getfmt(fmtstyle))
	m$print_end()
	return getstr(&.str,fmt)
end

global function strreal(real a, ichar fmtstyle=nil)ichar=
	static [320]char str
	ref fmtrec fmt

	m$print_startstr(&.str)
	tostr_r64(a,fmt:=getfmt(fmtstyle))
	m$print_end()
	return getstr(&.str,fmt)
end

function getstr(ichar s, ref fmtrec fmt)ichar=
	if fmt^.heapmode then
		return pcm_copyheapstring(s)
	else
		return s
	fi
end

proc initreadbuffer=
	if rd_buffer then return fi
	rd_buffer:=pcm_alloc(rd_buffersize)
	rd_buffer^:=0
	rd_pos:=rd_lastpos:=rd_buffer
end

global proc m$read_conline=
	initreadbuffer()

	readlinen(nil,rd_buffer,rd_buffersize)

	rd_length:=strlen(rd_buffer)
	rd_pos:=rd_buffer
	rd_lastpos:=nil
end

global proc m$read_fileline(filehandle f)=
	initreadbuffer()
	readlinen(f,rd_buffer,rd_buffersize)

	rd_length:=strlen(rd_buffer)
	rd_pos:=rd_buffer
	rd_lastpos:=nil
end

global proc m$read_strline(ichar s)=
	int n

	initreadbuffer()
	n:=strlen(s)

	if n<rd_buffersize then
		strcpy(rd_buffer,s)
	else
		memcpy(rd_buffer,s,rd_buffersize-1)
		(rd_buffer+rd_buffersize-1)^:=0
	fi
	rd_length:=n
	rd_pos:=rd_buffer
	rd_lastpos:=nil
end

function readitem(int &itemlength)ref char =
	ref char p,s,itemstr
	char quotechar, c

	unless rd_buffer then 
		initreadbuffer()
	end unless


	s:=rd_pos

	while s^=' ' or s^=9 do
		++s
	od

	itemstr:=s				!assume starts here
	rd_lastpos:=rd_pos:=s

	if s^=0 then			! No more chars left to read return null string
		termchar:=0
		itemlength:=0
		return s
	fi

	quotechar:=0			! Allow possible enclosing single or double quotes
	if s^='"' then
		quotechar:='"'
		++s
	elsif s^='\'' then
		quotechar:='\''
		++s
	fi

	p:=itemstr:=s

	while s^ do
		c:=s++^
		switch c
		when ' ', 9, comma, '=' then		! separator
			if quotechar or p=s then			!can be considered part of name if inside quotes, or is only char
				goto normalchar
			fi
			termchar:=c
			exit
		else
	normalchar::
			if c=quotechar then
				if s^=quotechar then	! embedded quote
					p^:=c
					++s
					++p
				else					! end of name
					termchar:=s^
					if termchar=',' or termchar='=' then
						++s
						termchar:=s^
					fi
					exit
				fi
			else
				p^:=c
				++p
			fi
		endswitch
	od

	if s^=0 then
		termchar:=0
	fi
	itemlength:=p-itemstr				! actual length of token
	rd_pos:=s

	return itemstr
end

global function strtoint(ichar s,int length=-1, word base=10)int64=
	byte signd
	word64 aa
	word c,d

	itemerror:=0

	if length=-1 then
		length:=strlen(s)
	fi
	signd:=0
	if length and s^='-' then
		signd:=1; ++s; --length
	elsif length and s^='+' then
		++s; --length
	fi

	aa:=0
	while length do
		c:=s++^
		--length
		switch c
		when 'A'..'F' then d:=c-'A'+10
		when 'a'..'f' then d:=c-'a'+10
		when '0'..'9' then d:=c-'0'
		when '_', '\'' then
			next
		else
			itemerror:=1
			exit
		endswitch

		if d>=base then
			itemerror:=1
			exit
		fi
		aa:=aa*base+d
	od

	if signd then
		return -aa
	else
		return aa
	fi
end

global function m$read_i64(int fmt=0)int64=
	ref char s
	int length,c
	int64 aa

	case fmt
	when 'C','c' then
		rd_lastpos:=rd_pos
		if rd_pos^ then
			return rd_pos++^
		else
			return 0
		fi
	when 'T','t' then
		return termchar
	when 'E','e' then
		return itemerror
	esac

	s:=readitem(length)

	case fmt
	when 0,'I','i' then
		return strtoint(s,length)
	when 'B','b' then
		return strtoint(s,length,2)
	when 'H','h' then
		return strtoint(s,length,16)
	esac
	return 0
end

global function m$read_r64(int fmt=0)real=
	[512]char str
	ref char s
	int length
	int32 numlength
	real x

	s:=readitem(length)

	if length=0 or length>=str.len then		!assume not a real
		return 0.0
	fi
	memcpy(&.str,s,length)
	str[length+1]:=0

	itemerror:=0

	if sscanf(&.str,"%lf%n", &x, &numlength)=0 or numlength<>length then
		x:=0.0
		itemerror:=1
	fi

	return x
end

global proc m$read_str(ref char dest, int destlen=0,fmt=0)=
	ref char s
	int length,numlength
	real x

	itemerror:=0
	if fmt='L' or fmt='l' then
		s:=rd_pos
		length:=rd_buffer+rd_length-rd_pos

	else
		s:=readitem(length)

		if fmt='N' or fmt='n' then
			iconvlcn(s,length)
		fi
	fi

	if destlen>0 then
		if length>=destlen then
			length:=destlen-1
			itemerror:=1
		fi
	fi
	memcpy(dest,s,length)
	(dest+length)^:=0
end

global proc readstr(ref char dest, int fmt=0,destlen=0)=
	m$read_str(dest,destlen,fmt)
end

global proc rereadln=
	rd_pos:=rd_buffer
	rd_lastpos:=rd_pos
end

global proc reread=
	rd_pos:=rd_lastpos
end

global function valint(ichar s, int fmt=0)int64=
ref char old_pos, old_lastpos
int64 aa

initreadbuffer()
old_pos:=rd_pos
old_lastpos:=rd_lastpos

rd_pos:=s
aa:=m$read_i64(fmt)
rd_pos:=old_pos
rd_lastpos:=old_lastpos
return aa
end

global function valreal(ichar s)real=
ref char old_pos, old_lastpos
real x

initreadbuffer()
old_pos:=rd_pos
old_lastpos:=rd_lastpos

rd_pos:=s
x:=m$read_r64()
rd_pos:=old_pos
rd_lastpos:=old_lastpos
return x
end

proc iconvlcn(ref char s,int n) =		!ICONVLCN
to n do
	s^:=tolower(s^)
	++s
od
end

proc iconvucn(ref char s,int n) =		!ICONVUCN
to n do
	s^:=toupper(s^)
	++s
od
end

proc convlcstring(ref char s)=		!CONVLCSTRING
while (s^) do
	s^:=tolower(s^)
	++s
od
end

proc convucstring(ref char s)=		!CONVUCSTRING
while (s^) do
	s^:=toupper(s^)
	++s
od
end

global proc m$float_u64_r64(word a)=
	assem
		cmp D10,0
		jl fl1
		cvtsi2sd XMM0,D10
		jmp flx
fl1:						!negative value
		and D10,[mask63]		!clear top bit (subtract 2**63)
		cvtsi2sd XMM0,D10
		addsd XMM0,[offset64]	!(add 2**63 back to result)
flx:
	end
end

global function m$power_i64(int64 a,n)int64=
	if n<0 then
		return 0
	elsif n=0 then
		return 1
	elsif n=1 then
		return a
	elsif n.even then
		return m$power_i64(sqr a, n/2)
	else			!assume odd
		return m$power_i64(sqr a, (n-1)/2)*a
	fi
end


global proc m$mul_i128(word128 aa,bb)=
	assem
		push d3
		push d4
		push d5
		mov d2,[aa]			!a1
		mov d3,[aa+8]		!a2
		mov d4,[bb]			!b1
		mov d5,[bb+8]		!b2


		mov d0,d2			!a1
		imul2 d0,d5			!*b2	
		mov d6,d0			!=>d6

		mov d0,d3			!a2
		imul2 d0,d4			!*b1
		mov d7,d0			!=>d7

		mov d0,d2			!a1
		mul d4				!*b1
		add d11,d6			! + a1*b2<<64
		add d11,d7			! + a2*b1<<64
		mov d1,d11
		pop d5
		pop d4
		pop d3
	end
end

global proc m$idiv_i128(word128 aa,bb)=
charlie::
	assem
		push d3
		push d4
		push d6


		mov d2,[aa]
		mov d3,[aa+8]

		mov d4,[bb]
		or d4,d4
		jz divbyzero

		mov d0,d3		!a2
		xor d11,d11
		div d4			!a2/b
		mov d6,d0		! => c2
		mul d4			!c2*b
		sub d3,d0		!a2-:=c2*b

		mov d0,d2
		mov d11,d3		!a2:a1
		div d4			!/b
		mov d1,d6
		pop d6
		pop d4
		pop d3

	end
	return

asm divbyzero:
CPL "DIV BY ZERO"
	stop 1
end

global proc m$dotindex(word i,a)=
end

global proc m$dotslice(word j,i,a)=
end

global proc m$popdotindex(word i,ref word p,word x)=
end

global proc m$popdotslice(word j,i, ref word p, word x)=
end



global proc mclunimpl(ichar mess)=
	printf("MCL-UNIMPL: %s\n",mess)
	stop 1
end
=== mclib.m 7/40 ===
global type filehandle=ref void

importlib $cstd=
	clang function malloc	(word64)ref void
	clang function realloc	(ref void, wordm)ref void
	clang proc     free		(ref void)
	clang proc     memset	(ref void, int32, wordm)
	clang proc     memcpy	(ref void, ref void, wordm)
	clang function clock	:int32
	clang function ftell	(filehandle)int32
	clang function fseek	(filehandle, int32, int32)int32
	clang function fread	(ref void, wordm, wordm, filehandle)wordm
	clang function fwrite	(ref void, wordm, wordm, filehandle)wordm
	clang function getc		(filehandle)int32
	clang function ungetc	(int32, filehandle)int32
	clang function fopen	(ichar,ichar="rb")filehandle
	clang function fclose	(filehandle)int32
	clang function fgets	(ichar, int, filehandle)ichar
	clang function remove	(ichar)int32
	clang function rename	(ichar, ichar)int32
	clang function getchar	:int32
	clang proc     putchar	(int32)
	clang proc     setbuf	(filehandle, ref byte)

	clang function strlen	(ichar)int
	clang function strcpy	(ichar, ichar)ichar
	clang function strcmp	(ichar, ichar)int32
	clang function strncmp	(ichar, ichar, wordm)int32
	clang function strncpy	(ichar, ichar, wordm)wordm
	clang function memcmp	(ref void, ref void, wordm)int32
	clang function strcat	(ichar, ichar)ichar
	clang function tolower	(int32)int32
	clang function toupper	(int32)int32
	clang function isalpha	(int32)int32
	clang function isupper	(int32)int32
	clang function islower	(int32)int32
	clang function isalnum	(int32)int32
	clang function isspace	(int32)int32
	clang function strstr	(ichar, ichar)ichar
	clang function atol		(ichar)intm
	clang function atoi		(ichar)int32
	clang function strtod	(ichar,ref ref char)real64

	clang function puts		(ichar)int32
	clang function puts99	(ichar)int32
	clang function printf	(ichar, ...)int32

	clang function sprintf	(ichar, ichar, ...)int32

	clang function sscanf	(ichar, ichar, ...)int32
	clang function scanf	(ichar, ...)int32

	clang function rand		:int32
	clang proc     srand	(word32)
	clang function system	(ichar)int32

	clang function fgetc	(filehandle)int32
	clang function fputc	(int32,  filehandle)int32
	clang function fprintf	(filehandle, ichar, ...)int32
	clang function fputs	(ichar,  filehandle)int32
	clang function feof		(filehandle)int32
	clang function getch	:int32
	clang function kbhit	:int32
	clang function _mkdir	(ichar)int32
	clang function mkdir	(ichar)int32
	clang function dummy	(real)real
	clang function strchr	(ichar,int32)ichar

	clang proc     _exit	(int32)
	clang proc     "exit"	(int32)
	clang function	pow		(real,real)real

	clang function	`sin	(real)real
	clang function	`cos	(real)real
	clang function	`tan	(real)real
	clang function	`asin	(real)real
	clang function	`acos	(real)real
	clang function	`atan	(real)real
	clang function	`log	(real)real
	clang function	`log10	(real)real
	clang function	`exp	(real)real
	clang function	`floor	(real)real
	clang function	`ceil	(real)real

	clang proc      qsort   (ref void, word64, word64, ref proc)

end

importlib $cstdextra=
	clang function __getmainargs(ref int32, ref void, ref void, int, ref void)int32
end

global const c_eof		=-1
global const seek_set	= 0
global const seek_curr	= 1
global const seek_end	= 2
=== mlibnew.m 8/40 ===
import msys
import clib
import oslib

const mem_check=0

GLOBAL INT MDEBUG
GLOBAL INT NPCMALLOC


global [0..300]u64 allocupper
global int alloccode				!set by heapalloc
global int allocbytes				!set by heapalloc
global int fdebug=0
global int rfsize

const threshold=1<<25
const alloc_step=1<<25
word maxmemory
int  maxalloccode

byte pcm_setup=0

int show=0

global int memtotal=0
global int64 smallmemtotal=0
global int smallmemobjs=0
global int maxmemtotal=0

const int maxmemalloc=(mem_check|500000|2)
[maxmemalloc+1]ref int32 memalloctable
[maxmemalloc+1]int32 memallocsize

const pcheapsize=1048576*2
ref byte pcheapstart
ref byte pcheapend			!points to first address past heap
ref byte pcheapptr

const int maxblockindex = 8 		!2048
global const int maxblocksize = 2048

[0:maxblocksize+1]byte sizeindextable	!convert byte size to block index 1..maxblockindex

const int size16   = 1			!the various index codes
const int size32   = 2
const int size64   = 3
const int size128  = 4
const int size256  = 5
const int size512  = 6
const int size1024 = 7
const int size2048 = 8

GLOBAL [0:9]ref wordp freelist

global record strbuffer =
	ichar strptr
	int32 length
	int32 allocated
end

global tabledata() [0:]ichar pmnames=
	(pm_end=0,		$),
	(pm_option,		$),
	(pm_sourcefile,	$),
	(pm_libfile,	$),
	(pm_colon,		$),
	(pm_extra,		$),
end

[2]word seed = (0x2989'8811'1111'1272',0x1673'2673'7335'8264)

global function pcm_alloc(int n)ref void =		!PCM_ALLOC
ref byte p

if not pcm_setup then
	pcm_init()
fi

if n>maxblocksize then			!large block allocation

	alloccode:=pcm_getac(n)
	allocbytes:=allocupper[alloccode]

	p:=allocmem(allocbytes)
	if not p then
		abortprogram("pcm_alloc failure")
	fi

	if mem_check then addtomemalloc(ref int32(p),allocbytes) fi

	return p
fi

alloccode:=sizeindextable[n]		!Size code := 0,1,2 etc for 0, 16, 32 etc

allocbytes:=allocupper[alloccode]

if p:=ref byte(freelist[alloccode]) then		!Items of this block size available
if mem_check then addtomemalloc(ref int32(p),allocbytes) fi
	freelist[alloccode]:=ref wordp(int((freelist[alloccode])^))

	return p
fi

p:=pcheapptr				!Create item at start of remaining pool in heap block
pcheapptr+:=allocbytes			!Shrink remaining pool

if pcheapptr>=pcheapend then		!Overflows?
	p:=pcm_newblock(allocbytes)		!Create new heap block, and allocate from start of that
	return p
fi
if mem_check then addtomemalloc(ref int32(p),allocbytes) fi

return p
end

global proc pcm_free(ref void p,int n) =		!PCM_FREE
int acode

if n=0 then return fi

if n>maxblocksize then		!large block
	if mem_check then removefrommemalloc(p,n) fi

	free(p)
	return
fi

if p then
	acode:=sizeindextable[n]		!Size code := 0,1,2 etc for 0, 16, 32 etc

	smallmemtotal-:=allocupper[acode]

	if mem_check then removefrommemalloc(p,allocupper[acode]) fi

	cast(p,ref wordp)^:=wordp(int(freelist[acode]))
	freelist[acode]:=p
fi
end

global proc pcm_freeac(ref void p,int alloc) =		!PCM_FREEAC
pcm_free(p,allocupper[alloc])
end

global proc pcm_copymem4(ref void p,q,int n) =	!PCM_COPYMEM4

memcpy(p,q,n)
end

global proc pcm_clearmem(ref void p,int n) =		!PCM_CLEARMEM
memset(p,0,n)
end

global proc pcm_init =		!PCM_INIT
int j,k,k1,k2
int64 size
const limit=1<<33

if pcm_setup then
	return
fi

pcm_newblock(0)

for i to maxblocksize do	!table converts eg. 78 to 4 (4th of 16,32,64,128)
	j:=1
	k:=16
	while i>k do
		k:=k<<1
		++j
	od
	sizeindextable[i]:=j
od

allocupper[1]:=16
size:=16

for i:=2 to 27 do
	size*:=2
	allocupper[i]:=size
	if size>=threshold then
			k:=i
		exit
	fi
od

for i:=k+1 to allocupper.upb do
	size+:=alloc_step
	if size<limit then
		allocupper[i]:=size
		maxmemory:=size
	else
		maxalloccode:=i-1
		exit
	fi
		
od
pcm_setup:=1
end

global function pcm_getac(int size)int =		!PCM_GETAC


if size<=maxblocksize then
	return sizeindextable[size]		!size 0 to 2KB
fi

size:=(size+255)>>8					!scale by 256


if size<=maxblocksize then
	return sizeindextable[size]+8
fi

size:=(size+63)>>6					!scale by 256

if size<=maxblocksize then
	return sizeindextable[size]+14
fi



size:=(size-2048+2047)/2048+22
return size
end

global function pcm_newblock(int itemsize)ref void=
static int totalheapsize
ref byte p

totalheapsize+:=pcheapsize
alloccode:=0
p:=allocmem(pcheapsize)	!can't free this block until appl terminates
if p=nil then
	abortprogram("Can't alloc pc heap")
fi

pcheapptr:=p
pcheapend:=p+pcheapsize

if pcheapstart=nil then		!this is first block
	pcheapstart:=p
fi
pcheapptr+:=itemsize
return ref u32(p)
end

global function pcm_round(int n)int =		!PCM_ROUND
static [0:maxblockindex+1]int32 allocbytes=(0,16,32,64,128,256,512,1024,2048)

if n>maxblocksize then
	return n
else
	return allocbytes[sizeindextable[n]]
fi
end

global function pcm_array(int n)int =		!PCM_ARRAY
int m

if n<=maxblocksize then	!automatic rounding up used for small heap
	return pcm_round(n)
else				!devise some strategy probably doubling up.
	m:=2048
	while n>m do
		m<<:=1
	od
	return m
fi

end

global proc pcm_printfreelist(int size,ref wordp p) =		!PCM_PRINTFREELIST
println "Size: ",size
while p do
	print " ",,p:"h"
	p:=ref wordp(int(p^))
od
puts("")
end

global proc pcm_diags(ref char caption) =		!PCM_DIAGS
int m

println "HEAP FREELISTS:",caption

m:=16
for i:=1 to 8 do
	pcm_printfreelist(m,freelist[i])
	m<<:=1
od
end

global function pcm_allocz(int n)ref void =		!PCM_ALLOCZ
ref void p
p:=pcm_alloc(n)

memset(p,0,n)
return p
end

global function pcm_copyheapstring(ref char s)ref char =
ref char q
int n
if s=nil then return nil fi

n:=strlen(s)+1
q:=pcm_alloc(n)
memcpy(q,s,n)
return q
end

global function pcm_copyheapstringn(ref char s,int n)ref char =
ref char q
if s=nil then return nil fi

q:=pcm_alloc(n+1)
memcpy(q,s,n)
(q+n)^:=0
return q
end

global function pcm_copyheapblock(ref char s, int length)ref char =
	ref char q
	if length=0 then return nil fi

	q:=pcm_alloc(length)
	memcpy(q,s,length)
	return q
end

proc addtomemalloc(ref int32 ptr,int size)=


for i to maxmemalloc do
	if memalloctable[i]=ptr then
		CPL "ALLOC ERROR:",ptr,"ALREADY ALLOCATED\n\n\n"
CPL
CPL
		stop 2
	fi

	if memalloctable[i]=nil then		!unused entry
		memalloctable[i]:=ptr
		memallocsize[i]:=size
		return
	fi
od
CPL "MEMALLOCTABLE FULL\n\n\n\n"; os_getch()
stop 3
end

proc removefrommemalloc(ref int32 ptr,int size)=


for i to maxmemalloc do
	if memalloctable[i]=ptr then

if memallocsize[i]<>size then
	CPL "REMOVE:FOUND",ptr,"IN MEMALLOCTABLE, FREESIZE=",size,", BUT STORED AS BLOCK SIZE:",memallocsize[i]
CPL
CPL
	abortprogram("MEMSIZE")
fi

		memalloctable[i]:=nil
		return
	fi
od
CPL "CAN'T FIND",ptr,"IN MEMALLOCTABLE",size
CPL
CPL
abortprogram("MEM")
stop 4
end

global function allocmem(int n)ref void =		!ALLOCMEM
ref void p

p:=malloc(n)
if (p) then
	return p
fi
println n,memtotal
abortprogram("Alloc mem failure")
return nil
end

global function reallocmem(ref void p,int n)ref void =		!REALLOCMEM
p:=realloc(p,n)
return p when p
println n
abortprogram("Realloc mem failure")
return nil
end

global proc abortprogram(ref char s) =		!ABORTPROGRAM
println s
print   "ABORTING: Press key..."
os_getch()
stop 5
end

global function getfilesize(filehandle handlex)int=		!GETFILESIZE
	word32 p,size

	p:=ftell(handlex)		!current position
	fseek(handlex,0,2)		!get to eof
	size:=ftell(handlex)		!size in bytes
	fseek(handlex,p,seek_set)	!restore position
	return size
end

global proc readrandom(filehandle handlex, ref byte mem, int offset, size) =		!READRANDOM
	int a
	fseek(handlex,offset,seek_set)
	a:=fread(mem,1,size,handlex)			!assign so as to remove gcc warning
end

global function writerandom(filehandle handlex, ref byte mem, int offset,size)int =		!WRITERANDOM
	fseek(handlex,offset,seek_set)
	return fwrite(mem,1,size,handlex)
end

global function setfilepos(filehandle file,int offset)int=
	return fseek(file,offset,0)
end

global function getfilepos(filehandle file)int=
	return ftell(file)
end

global function readfile(ref char filename)ref byte =		!READFILE
filehandle f
int size
ref byte m,p

f:=fopen(filename,"rb")
if f=nil then
	return nil
fi
rfsize:=size:=getfilesize(f)

m:=malloc(size+4)		!allow space for etx/zeof etc

if m=nil then
	return nil
fi

readrandom(f,m,0,size)
p:=m+size			!point to following byte
p^:=0
(p+1)^:=26
(p+2)^:=0			!allow use as string

fclose(f)
return m
end

global function writefile(ref char filename,ref byte data,int size)int =
filehandle f
int n

f:=fopen(filename,"wb")
if f=nil then
	return 0
fi

n:=writerandom(f,data,0,size)
fclose(f)
return n
end

global function checkfile(ref char file)int=		!CHECKFILE
filehandle f
if f:=fopen(file,"rb") then
	fclose(f)
	return 1
fi
return 0
end

global proc readlinen(filehandle handlex,ref char buffer,int size) =		!READLINEN
int ch
ref char p
int n
[0:100]char buff
byte crseen

if handlex=nil then
	handlex:=filehandle(os_getstdin())
fi
if handlex=nil then
	n:=0
	p:=buffer
	do
		ch:=getchar()
		if ch=13 or ch=10 or ch=-1 then
			p^:=0
			return
		fi
		p++^:=ch
		++n
		if n>=(size-2) then
			p^:=0
			return
		fi
	od
fi

buffer^:=0
if fgets(buffer,size-2,handlex)=nil then
	return
fi

n:=strlen(buffer)
if n=0 then
	return
fi

p:=buffer+n-1		!point to last char
crseen:=0
while (p>=buffer and (p^=13 or p^=10)) do
	if p^=13 or p^=10 then crseen:=1 fi
	p--^ :=0
od


if not crseen and (n+4>size) then
	cpl size,n
	abortprogram("line too long")
fi
end

global proc iconvlcn(ref char s,int n) =		!ICONVLCN
to n do
	s^:=tolower(s^)
	++s
od
end

global proc iconvucn(ref char s,int n) =		!ICONVUCN
to n do
	s^:=toupper(s^)
	++s
od
end

global proc convlcstring(ref char s)=		!CONVLCSTRING
while (s^) do
	s^:=tolower(s^)
	++s
od
end

global proc convucstring(ref char s)=		!CONVUCSTRING
while (s^) do
	s^:=toupper(s^)
	++s
od
end

global function changeext(ref char s,newext)ichar=		!CHANGEEXT
static [260]char newfile
[32]char newext2
ref char sext
int n

strcpy(&newfile[1],s)

case newext^
when 0 then
	newext2[1]:=0
	newext2[2]:=0
when '.' then
	strcpy(&newext2[1],newext)
else
	strcpy(&newext2[1],".")
	strcat(&newext2[1],newext)
esac


sext:=extractext(s,1)			!include "." when it is only extension

case sext^
when 0 then						!no extension not even "."
	strcat(&newfile[1],&newext2[1])
when '.' then						!no extension not even "."
	strcat(&newfile[1],&newext2[2])
else							!has extension
	n:=sext-s-2			!n is number of chars before the "."
	strcpy(&newfile[1]+n+1,&newext2[1])
esac

return &newfile[1]
end

global function extractext(ref char s,int period=0)ichar=		!EXTRACTEXT
ref char t,u

t:=extractfile(s)

if t^=0 then			!s contains no filename
	return ""
fi

u:=t+strlen(t)-1		!u points to last char of t

while u>=t do
	if u^='.' then		!start extension found
		if (u+1)^=0 then		!null extension
			return (period|"."|"")
		fi
		return u+1			!return last part of filename as extension exclude the dot
	fi
	--u
od
return ""			!no extension seen
end

global function extractpath(ref char s)ichar=		!EXTRACTPATH
static [0:260]char str
ref char t
int n

t:=s+strlen(s)-1		!t points to last char

while (t>=s) do
	switch t^
	when '\\','/',':' then		!path separator or drive letter terminator assume no extension
		n:=t-s+1			!n is number of chars in path, which includes rightmost / or \ or :
		memcpy(&.str,s,n)
		str[n]:=0
		return &.str
	endswitch
	--t
od
return ""			!no path found
end

global function extractfile(ref char s)ichar=		!EXTRACTFILE
ref char t

t:=extractpath(s)

if t^=0 then			!s contains no path
	return s
fi

return s+strlen(t)		!point to last part of s that contains the file
end

global function extractbasefile(ref char s)ichar=		!EXTRACTBASEFILE
static [0:100]char str
ref char f,e
int n,flen

f:=extractfile(s)
flen:=strlen(f)
if flen=0 then		!s contains no path
	return ""
fi
e:=extractext(f,0)

if e^ then			!not null extension
	n:=flen-strlen(e)-1
	memcpy(&str,f,n)
	str[n]:=0
	return &.str
fi
if (f+flen-1)^='.' then
	memcpy(&str,f,flen-1)
	str[flen-1]:=0
	return &.str
fi
return f
end

global function addext(ref char s,ref char newext)ichar=		!ADDEXT
ref char sext

sext:=extractext(s,1)

if sext^=0 then						!no extension not even "."
	return changeext(s,newext)
fi

return s							!has own extension; use that
end

global function alloctable(int n, size)ref void =		!ALLOCTABLE
ref void p

p:=malloc((n+1)*size)

if not p then
	abortprogram("Alloctable failure")
fi
return p
end

global function zalloctable(int n, size)ref void =		!ALLOCTABLE
ref int p

p:=alloctable(n,size)

pcm_clearmem(p,(n+1)*size)
return p
end

global proc checkfreelists(ichar s)=
ref wordp p,q
int64 aa

for i:=2 to 2 do
	p:=freelist[i]

	while p do
		aa:=int64(p)
		if aa>0xffff'FFFF or aa<100 then
			CPL s,"FREE LIST ERROR",i,p,q
		fi
		q:=p
		p:=ref wordp(int(p^))
	od

od
end


global function pcm_alloc32:ref void =		!PCM_ALLOC
ref byte p

allocbytes:=32


return pcm_alloc(32)
end

global proc pcm_free32(ref void p) =

smallmemtotal-:=32
if mem_check then removefrommemalloc(p,32) fi

cast(p,ref wordp)^:=wordp(int(freelist[2]))
freelist[2]:=p
end

global proc outbyte(filehandle f,int x)=
fwrite(&x,1,1,f)
end

global proc outword16(filehandle f,word x)=
fwrite(&x,2,1,f)
end

global proc outword(filehandle f,word x)=
fwrite(&x,4,1,f)
end

global proc outword64(filehandle f,word64 x)=
fwrite(&x,8,1,f)
end

global function myeof(filehandle f)int=
int c

c:=fgetc(f)
if c=c_eof then return 1 fi
ungetc(c,f)
return 0;
end

global function pcm_smallallocz(int n)ref void =
ref byte p

allocbytes:=allocupper[alloccode:=sizeindextable[n]]

p:=pcheapptr				!Create item at start of remaining pool in heap block
pcheapptr+:=allocbytes			!Shrink remaining pool

if pcheapptr>=pcheapend then		!Overflows?
	p:=pcm_newblock(allocbytes)		!Create new heap block, and allocate from start of that
	memset(p,0,n)
	return p
fi

memset(p,0,n)

return p
end

global function pcm_smallalloc(int n)ref void =
ref byte p

allocbytes:=allocupper[alloccode:=sizeindextable[n]]

p:=pcheapptr				!Create item at start of remaining pool in heap block
pcheapptr+:=allocbytes			!Shrink remaining pool

if pcheapptr>=pcheapend then		!Overflows?
	p:=pcm_newblock(allocbytes)		!Create new heap block, and allocate from start of that
	return p
fi

return p
end

global proc strbuffer_add(ref strbuffer dest, ichar s, int n=-1)=
int newlen,oldlen
ichar newptr

IF N=0 THEN CPL "N=0" FI

if n=-1 then
	n:=strlen(s)
fi

oldlen:=dest^.length

if oldlen=0 then				!first string
	dest^.strptr:=pcm_alloc(n+1)
	dest^.allocated:=allocbytes
	dest^.length:=n				!length always excludes terminator
	memcpy(dest^.strptr,s,n)
	(dest^.strptr+n)^:=0
	return
fi

newlen:=oldlen+n
if newlen+1>dest^.allocated then
	newptr:=pcm_alloc(newlen+1)
	memcpy(newptr,dest^.strptr,oldlen)
	dest^.strptr:=newptr
	dest^.allocated:=allocbytes
fi

memcpy(dest^.strptr+oldlen,s,n)
(dest^.strptr+newlen)^:=0

dest^.length:=newlen
end

global proc gs_init(ref strbuffer dest)=			!INITGENSTR
pcm_clearmem(dest,strbuffer.bytes)
end

global proc gs_free(ref strbuffer dest)=
if dest^.allocated then
	pcm_free(dest^.strptr,dest^.allocated)
fi
end

global proc gs_str(ref strbuffer dest,ichar s)=			!GENSTR
strbuffer_add(dest,s)
end

global proc gs_char(ref strbuffer dest,int c)=
[16]char s

s[1]:=c
s[2]:=0

strbuffer_add(dest,&.s,1)
end

global proc gs_strn(ref strbuffer dest,ichar s,int length)=
strbuffer_add(dest,s,length)
end

global proc gs_strvar(ref strbuffer dest,s)=			!GENSTR
strbuffer_add(dest,s^.strptr)
end

global proc gs_strint(ref strbuffer dest,int64 a)=
strbuffer_add(dest,strint(a))
end

global proc gs_strln(ref strbuffer dest,ichar s)=		!GENSTRLN
gs_str(dest,s)
gs_line(dest)
end

global proc gs_strsp(ref strbuffer dest,ichar s)=
gs_str(dest,s)
gs_str(dest," ")
end

global proc gs_line(ref strbuffer dest)=
strbuffer_add(dest,"\w")
end

global function gs_getcol(ref strbuffer dest)int=
return dest^.length
end

global proc gs_leftstr(ref strbuffer dest, ichar s, int w, padch=' ')=
int col,i,n,slen
[2560]char str
col:=dest^.length
strcpy(&.str,s)
slen:=strlen(s)
n:=w-slen
if n>0 then
	for i:=1 to n do
		str[slen+i]:=padch
	od
	str[slen+n+1]:=0
fi
gs_str(dest,&.str)
end

global proc gs_leftint(ref strbuffer dest, int a, int w, padch=' ')=
gs_leftstr(dest,strint(a),w,padch)
end

global proc gs_padto(ref strbuffer dest,int col, ch=' ')=
int n
[2560]char str

n:=col-dest^.length
if n<=0 then return fi
for i:=1 to n do
	str[i]:=ch
od
str[n+1]:=0
gs_str(dest,&.str)
end

global proc gs_println(ref strbuffer dest,filehandle f=nil)=
(dest.strptr+dest.length)^:=0

if f=nil then
	println dest.strptr,,"\c"
else
	println @f,dest.strptr,,"\c"
fi
end

global function nextcmdparam(int &paramno, ichar &name, &value, ichar defext=nil)int=
static int infile=0
static ichar filestart=nil
static ichar fileptr=nil
static byte colonseen=0
ref char q
ichar item,fileext
ichar rest
int length
static [300]char str

reenter::
value:=nil
name:=nil

if infile then
	if readnextfileitem(fileptr,item)=0 then		!eof
		free(filestart)								!file allocated via malloc
		infile:=0
		goto reenter
	fi
else
	if paramno>nsysparams then
		return pm_end
	fi
	item:=sysparams[paramno]
	++paramno

	length:=strlen(item)

	if item^='@' then		!@ file
		filestart:=fileptr:=cast(readfile(item+1))
		if filestart=nil then
			println "Can't open",item
			stop 7
		fi
		infile:=1
		goto reenter
	fi

	if item^=':' then
		colonseen:=1
		return pm_colon
	fi
fi

value:=nil
if item^='-' then
	name:=item+(colonseen|0|1)
	q:=strchr(item,':')
	if not q then
		q:=strchr(item,'=')
	fi
	if q then
		value:=q+1
		q^:=0
	fi
	return (colonseen|pm_extra|pm_option)
fi

fileext:=extractext(item,0)
name:=item

if fileext^=0 then							!no extension
	strcpy(&.str,name)
	if defext and not colonseen then
		name:=addext(&.str,defext)				!try .c
	fi
elsif eqstring(fileext,"dll") then
	return (colonseen|pm_extra|pm_libfile)
fi
return (colonseen|pm_extra|pm_sourcefile)
end

function readnextfileitem(ichar &fileptr,&item)int=
ref char p,pstart,pend
int n
static [256]char str

p:=fileptr

reenter::
do
	case p^
	when ' ','\t',13,10 then	!skip white space
		++p
	when 26,0 then				!eof
		return 0
	else
		exit
	esac
od

case p^
when '!', '#' then			!comment
	++p
	docase p++^
	when 10 then
		goto reenter
	when 26,0 then
		fileptr:=p-1
		return 0
	else

	enddocase
esac


case p^
when '"' then				!read until closing "
	pstart:=++p
	do
		case p^
		when 0,26 then
			println "Unexpected EOF in @file"
			stop 8
		when '"' then
			pend:=p++
			if p^=',' then ++p fi
			exit
		esac
		++p
	od
else
	pstart:=p
	do
		case p^
		when 0,26 then
			pend:=p
			exit
		when ' ','\t',',',13,10 then
			pend:=p++
			exit
		esac
		++p
	od
esac

n:=pend-pstart
if n>=str.len then
	println "@file item too long"
	stop 9
fi
memcpy(&.str,pstart,n)
str[n+1]:=0
item:=&.str
fileptr:=p

return 1
end

global proc ipadstr(ref char s,int width,ref char padchar=" ")=
int n

n:=strlen(s)
to width-n do
	strcat(s,padchar)
od
end

global function padstr(ref char s,int width,ref char padchar=" ")ichar=
static [256]char str

strcpy(&.str,s)
ipadstr(&.str,width,padchar)
return &.str
end

global function chr(int c)ichar=
static [8]char str

str[1]:=c
str[2]:=0
return &.str
end

global function cmpstring(ichar s,t)int=
	int res
	if (res:=strcmp(s,t))<0 then
		return -1
	elsif res>0 then
		return 1
	else
		return 0
	fi
end

global function cmpstringn(ichar s,t,int n)int=
	int res
	if (res:=strncmp(s,t,n))<0 then
		return -1
	elsif res>0 then
		return 1
	else
		return 0
	fi
end

global function eqstring(ichar s,t)int=
	return strcmp(s,t)=0
end

global function cmpbytes(ref void p,q,int n)int=
	int res
	if (res:=memcmp(p,q,n))<0 then
		return -1
	elsif res>0 then
		return 1
	else
		return 0
	fi
end

global function eqbytes(ref void p,q,int n)int=
	return memcmp(p,q,n)=0
end

global proc mseed(word64 a,b=0)=
seed[1]:=a
if b then
	seed[2]:=b
else
	seed[2] ixor:=a
fi
end

global function mrandom:word =
	word64 x,y
	x:=seed[1]
	y:=seed[2]
	seed[1]:=y
	x ixor:=(x<<23)
	seed[2]:= x ixor y ixor (x>>17) ixor (y>>26)
	return seed[2]+y
end

global function mrandomp:int =
	return mrandom() iand 0x7FFF'FFFF'FFFF'FFFF
end

global function mrandomint(int n)int=
	return mrandomp() rem n
end

global function mrandomrange(int a,b)int=
	int span
	span:=b-a+1
	if span<=0 then
		return 0
	fi
	return (mrandomp() rem span)+a
end

global function mrandomreal:real x=
	repeat x:=mrandomp()/9223372036854775808.0 until x<>1.0
	return x
end

global function mrandomreal1:real=
	return mrandomp()/9223372036854775807
end

global function checkpackfile:ref byte=

int a,offset,i,size
[100]char name
[300]char exefile
ref byte packexeptr			!for embedded pack files, contains pointer to in-memory version of this .exe file plus extras; else nil
int packexesize				!byte size
ref char packfilename
int packfilesize
ref byte packfileptr

macro getfileint(data,offset)=cast(data+offset,ref int32)^

strcpy(&exefile[1],os_gethostname())
println "Attempting to open",&exefile
packexeptr:=readfile(&exefile[1])

if not packexeptr then
	cpl "Can't open",&exefile,&packexeptr
	stop
fi

packexesize:=rfsize
cpl "File read OK. Size",packexesize

a:=getfileint(packexeptr,packexesize-int32.bytes)
if a<>'PCAK' then
	free(packexeptr)
	packfileptr:=nil
	return nil
fi

offset:=getfileint(packexeptr,packexesize-int32.bytes*2)

packfilename:=cast(packexeptr+offset)
offset+:=strlen(packfilename)+1
packfilesize:=getfileint(packexeptr,offset)
packfileptr:=packexeptr+offset+int32.bytes

return packfileptr
end

global function pcm_allocx:ref void =
const n=32
ref word p

allocbytes:=32

if p:=ref word(freelist[2]) then		!Items of this block size available
	freelist[2]:=ref wordp(int((freelist[2])^))

else

	p:=cast(pcheapptr)				!Create item at start of remaining pool in heap block
	pcheapptr+:=32			!Shrink remaining pool

	if pcheapptr>=pcheapend then		!Overflows?
		p:=pcm_newblock(32)		!Create new heap block, and allocate from start of that
	fi

	p^:=0
	(p+1)^:=0
	(p+2)^:=0
	(p+3)^:=0

	return p
fi
end

=== mwindows.m 9/40 ===
import clib
import mlib

const wm_destroy=2

type wt_word	= word16
type wt_wordpm	= word32
type wt_bool	= word32
type wt_dword	= word32
type wt_wchar	= word16
type wt_wcharpm	= word32
type wt_char	= byte
type wt_ichar	= ref char
type wt_ptr		= ref void
type wt_wndproc	= ref proc
type wt_handle	= ref void
type wt_int		= int32
type wt_uint	= word32
type wt_long	= int32
type wt_wparam	= wordm
type wt_lparam	= wordm
type wt_point	= rpoint

global record rsystemtime =
	wt_word year
	wt_word month
	wt_word dayofweek
	wt_word day
	wt_word hour
	wt_word minute
	wt_word second
	wt_word milliseconds
end

importdll $windowsdlls=
	windows function "GetStdHandle"(wt_dword)wt_handle
	windows function "GetConsoleScreenBufferInfo"(wt_handle,wt_ptr)int
	windows function "SetConsoleCtrlHandler"(wt_wndproc,int)int
	windows function "SetConsoleMode"(wt_handle,wt_dword)int
	windows function "CreateProcessA"(wt_ichar,wt_ichar,wt_ptr,wt_ptr, int,
						wt_dword, wt_ptr,wt_ichar,wt_ptr,wt_ptr)int
	windows function "GetLastError":wt_dword
	windows function "WaitForSingleObject"(wt_handle,wt_dword)wt_dword
	windows function "GetExitCodeProcess"(wt_handle,wt_ptr)int
	windows function "CloseHandle"(wt_handle)int
	windows function "GetNumberOfConsoleInputEvents"(wt_handle,wt_ptr)int
	windows function "FlushConsoleInputBuffer"(wt_handle)int
	windows function "LoadLibraryA"(wt_ichar)wt_handle
	windows function "GetProcAddress"(wt_handle,wt_ichar)ref void
	windows function "LoadCursorA"(wt_handle,wt_ichar)wt_handle
	windows function "RegisterClassExA"(wt_ptr)wt_wordpm
	windows function "DefWindowProcA"(wt_handle,wt_uint,wt_wparam,wt_lparam)intm
	windows function "ReadConsoleInputA"(wt_handle,wt_ptr,wt_dword,wt_ptr)int
	windows proc     "Sleep"(wt_dword)
	windows function "GetModuleFileNameA"(wt_handle,wt_ichar,wt_dword)wt_dword

	windows proc     "ExitProcess"(wt_uint)
	windows proc	 "PostQuitMessage"(wt_int)


	windows proc	 "MessageBoxA"(wt_int x=0,wt_ichar message, caption="Caption",wt_int y=0)

	windows function "QueryPerformanceCounter"(ref int64)wt_bool
	windows function "QueryPerformanceFrequency"(ref int64)wt_bool

	windows function "CreateFileA"(wt_ichar,wt_dword,wt_dword,wt_ptr,wt_dword,wt_dword,wt_handle)wt_handle
	windows function "GetFileTime"(wt_handle,wt_ptr,wt_ptr,wt_ptr)wt_bool

	windows proc     "GetSystemTime"(ref rsystemtime)
	windows proc     "GetLocalTime"(ref rsystemtime)

	windows function "GetTickCount":wt_dword
	windows function "PeekMessageA"		(ref void, ref wt_handle, wt_uint,wt_uint,wt_uint)wt_bool

end

record input_record =
	wt_word	eventtype
	word16	padding
		wt_bool	keydown			!key event record (was inside 'Event' union in win32)
		wt_word	repeatcount
		wt_word	virtualkeycode
		wt_word	virtualscancode
		union
			wt_word unicodechar
			wt_char asciichar
		end
		wt_dword controlkeystate
end

record rspoint=(int16 x,y)

record rsrect=
	int16 leftx,top,rightx,bottom
end

global record rpoint =
	wt_long x,y
end

record rconsole=
	rspoint size,pos
	word16 attributes
	rsrect window
	rspoint maxwindowsize
end

record rstartupinfo =
	wt_dword	size
	word32 dummy1
	wt_ichar	reserved
	wt_ichar	desktop
	wt_ichar	title
	wt_dword	x
	wt_dword	y
	wt_dword	xsize
	wt_dword	ysize
	wt_dword	xcountchars
	wt_dword	ycountchars
	wt_dword	fillattribute
	wt_dword	flags
	wt_word		showwindow
	wt_word		reserved2
	word32 dummy2
	wt_ptr		reserved4
	wt_handle	stdinput
	wt_handle	stdoutput
	wt_handle	stderror
end

record rprocess_information =
	wt_handle process
	wt_handle thread
	wt_dword processid
	wt_dword threadid
end

record rwndclassex =
	wt_uint		size
	wt_uint		style
	wt_wndproc	wndproc
	wt_int		clsextra
	wt_int		wndextra
	wt_handle	instance
	wt_handle	icon
	wt_handle	cursor
	wt_handle	background
	wt_ichar	menuname
	wt_ichar	classname
	wt_handle	iconsm
end

global record rmsg =
	wt_handle	hwnd
	wt_uint		message
	word32		dummy1
	wt_wparam	wParam
	wt_lparam	lParam
	wt_dword	time
	word32		dummy2
	wt_point	pt
end

const NORMAL_PRIORITY_CLASS=32
const CREATE_NEW_CONSOLE=16
const DETACHED_PROCESS=16

wt_handle hconsole, hconsolein

input_record lastkey, pendkey
int keypending			!whether pendkey contains a new key event detected by flushkbd

ref function(ref void)int wndproc_callbackfn=nil	!windows call-back: address of handler

int init_flag=0

global proc os_init=
int i,count
rconsole info

hconsole:=GetStdHandle(u32(-11))
hconsolein:=GetStdHandle(u32(-10))

lastkey.repeatcount:=0
keypending:=0

SetConsoleCtrlHandler(nil,1)

SetConsoleMode(hconsole,1 ior 2)

init_flag:=1

end

global function os_execwait(ichar cmdline,int newconsole=0,ichar workdir=nil)int =
wt_dword exitcode
int status
int cflags:=0

rstartupinfo si
rprocess_information xpi

memset(&si,0,si.bytes)
memset(&xpi,0,xpi.bytes)

switch newconsole
when 0 then cflags := NORMAL_PRIORITY_CLASS
when 1 then cflags := NORMAL_PRIORITY_CLASS ior CREATE_NEW_CONSOLE
when 2 then cflags := NORMAL_PRIORITY_CLASS ior DETACHED_PROCESS
endswitch

si.size := rstartupinfo.bytes

status:=CreateProcessA(
	nil,
	cmdline,
	nil,

	nil,
	1,
	cflags,

	nil,
	nil,
	&si,
	&xpi )

if status=0 then		!fails
	status:=GetLastError()
	println "Winexec error:",status
	return -1
end

WaitForSingleObject(xpi.process, 0xFFFF'FFFF)
GetExitCodeProcess(xpi.process,&exitcode)

CloseHandle(xpi.process)
CloseHandle(xpi.thread)

return exitcode
end

global function os_execcmd(ichar cmdline, int newconsole=0)int =
wt_dword exitcode
int i,j,k

rstartupinfo si
rprocess_information xpi

memset(&si,0,si.bytes)
memset(&xpi,0,xpi.bytes)

si.size := rstartupinfo.bytes

CreateProcessA( nil,
	cmdline,
	nil,
	nil,
	1,
	NORMAL_PRIORITY_CLASS ior (newconsole|CREATE_NEW_CONSOLE|0),
	nil,
	nil,
	&si,
	&xpi )

CloseHandle(xpi.process)
CloseHandle(xpi.thread)

return 1
end

global function os_getch:int=
int k

k:=os_getchx() iand 255

return k
end

global function os_kbhit:int=
wt_dword count

unless init_flag then os_init() end

GetNumberOfConsoleInputEvents(hconsolein,&count)
return count>1
end

global proc os_flushkeys=
FlushConsoleInputBuffer(hconsolein)
end

global function os_getconsolein:ref void=
return ref void(hconsolein)
end

global function os_getconsoleout:ref void=
return ref void(hconsole)
end

global function os_proginstance:ref void=
abortprogram("PROGINST")
return nil
end

global function os_getdllinst(ichar name)u64=
wt_handle hinst

hinst:=LoadLibraryA(name)
return cast(hinst)
end

global function os_getdllprocaddr(int hinst,ichar name)ref void=

return GetProcAddress(cast(int(hinst)),name)
end

global proc os_initwindows=
os_init()
os_gxregisterclass("pcc001")
end

global proc os_gxregisterclass(ichar classname)=
const idcarrow=32512
rwndclassex r
static byte registered

if registered then
	return
fi


memset(&r,0,r.bytes)
r.size:=r.bytes
r.style:=8 ior 32		!CS_DBLCLKS | CS_OWNDC
r.wndproc:=cast(&mainwndproc)
r.instance:=nil

r.icon:=nil		!loadicon(proginstance,"SCW32")
r.cursor:=LoadCursorA(nil,ref void(idcarrow))		!IDC_ARROW)
r.background:=cast(15+1)					!COLOR_BTNFACE+1
r.menuname:=nil
r.classname:=classname
r.iconsm:=nil	!loadicon(proginstance,"SCW32")

if RegisterClassExA(&r)=0 then
	println classname,GetLastError
	abortprogram("Registerclass error")
end
registered:=1
end

global callback function mainwndproc (
		wt_handle hwnd, wt_uint message, wt_wparam wParam, wt_lparam lParam)intm=
rmsg m
int i,result
intm l
static int count=0


m.hwnd:=hwnd
m.message:=message
m.wParam:=wParam
m.lParam:=lParam
m.pt.x:=0
m.pt.y:=0

if (wndproc_callbackfn) then
	result:=(wndproc_callbackfn^)(&m)
else
	result:=0
fi

if m.message=wm_destroy then
	return 0
fi

if not result then
	return DefWindowProcA(hwnd,message,wParam,lParam)
else
	return 0
fi
end

proc timerproc(wt_handle hwnd, int msg, id, time)=
println "TIMERPROC"
end

global proc os_setmesshandler(ref void addr)=
wndproc_callbackfn:=addr
end

global function os_getchx:int=
const rightaltmask	= 1
const leftaltmask	= 2
const leftctrlmask	= 8
const rightctrlmask	= 4
const shiftmask		= 16
const capsmask		= 128
const scrollmask	= 64
int count
int charcode,keyshift,keycode
int altdown,ctrldown,shiftdown,capslock

unless init_flag then os_init() end

if keypending then
	lastkey:=pendkey
	keypending:=0
else
	if lastkey.repeatcount=0 then
		repeat
			count:=0
			ReadConsoleInputA(hconsolein,&lastkey,1,&count)
		until (lastkey.eventtype=1 and lastkey.keydown=1)
	fi
fi


altdown		:= ((lastkey.controlkeystate iand (leftaltmask ior rightaltmask))|1|0)
ctrldown	:= ((lastkey.controlkeystate iand (leftctrlmask ior rightctrlmask))|1|0)
shiftdown	:= ((lastkey.controlkeystate iand shiftmask)|1|0)
capslock	:= ((lastkey.controlkeystate iand capsmask)|1|0)

--lastkey.repeatcount		!count this key out

charcode:=lastkey.asciichar
keycode:=lastkey.virtualkeycode iand 255

if charcode<0 then
	if charcode<-128 then
		charcode:=0
	else
		charcode+:=256
	fi
fi


if altdown and ctrldown and charcode=166 then
	altdown:=ctrldown:=0
else
	if altdown or ctrldown then
		charcode:=0
		if keycode>='A' and keycode<= 'Z' then
			charcode:=keycode-'@'
		fi
	fi
fi

keyshift:=capslock<<3 ior altdown<<2 ior ctrldown<<1 ior shiftdown

return keyshift<<24 ior keycode<<16 ior charcode
end

global function os_getos=>ichar=
if $targetbits=32 then
	return "W32"
else
	return "W64"
fi
end

global function os_gethostsize=>int=
return $targetbits
end

global function os_shellexec(ichar opc, file)int=
return system(file)
end

global proc  os_sleep(int a)=
Sleep(a)
end

global function os_getstdin:filehandle =
return fopen("con","rb")
end

global function os_getstdout:filehandle =
return fopen("con","wb")
end

global function os_gethostname:ichar=
static [300]char name
static int n

GetModuleFileNameA(nil,&.name,name.bytes)
strcat(&.name,"/")
return &.name
end

global function os_getmpath:ichar=
return F"C:\m\"
end

global proc os_exitprocess(int x)=
stop x
end

global function os_clock:int64=
return clock()
end

global function os_getclockspersec:int64=
return 1000
end

global function os_iswindows:int=
return 1
end

global function os_filelastwritetime(ichar filename)int64=
wt_handle f;
int64 ctime,atime,wtime;

if filename=nil then				!used to test whether supported
	return 1
fi

f:=CreateFileA(filename,0x80000000,1,nil, 3,3,nil);
if int64(f)=-1 then
	return 0
fi

GetFileTime(f,&ctime,&atime,&wtime);
CloseHandle(f);

return wtime;
end

global proc os_getsystime(ref rsystemtime tm)=
GetLocalTime(tm)
end

global proc os_messagebox(ichar s,t)=
messageboxa(0,s,t,0)
end

global function os_hpcounter:int64=
int64 a

queryperformancecounter(&a)
return a

end

global function os_hpfrequency:int64=
int64 a

queryperformancefrequency(&a)
return a

end

global proc os_peek=
int ticks
static int lastticks
[100]byte m
	ticks:=GetTickCount()
	if ticks-lastticks>=1000 then
		lastticks:=ticks
		PeekMessageA(&m,nil,0,0,0)
	fi
end
=== bb_support.m 10/40 ===
import clib
import msys
import mlib
import oslib

import bb_decls
import bb_lib
import bb_tables
import bb_pclcommon
import bb_libsources

global [0:]byte bytemasks=(1,2,4,8,16,32,64,128)



global function loadsourcefile(ichar filespec)int=
	ichar s,shortfile

	if nsourcefiles>maxsourcefile then
		loaderror("Too many source files")
	fi

	shortfile:=extractfile(filespec)


	++nsourcefiles
	sourcefilepaths[nsourcefiles]:=pcm_copyheapstring(filespec)
	sourcefilenames[nsourcefiles]:=pcm_copyheapstring(shortfile)

	s:=cast(readfile(filespec))			!will overallocate by a few bytes
	if not s then				!unexpected error
		loaderror("LSF can't load ",filespec)
	fi
	sourcefiletext[nsourcefiles]:=s

	if fwritema then
		mafiletext[nsourcefiles]:=pcm_copyheapstring(s)
	fi

	sourcefilesizes[nsourcefiles]:=rfsize
	(s+rfsize)^:=0				!replace etx,0 by 0,0 (effectively, just zero)
	return nsourcefiles
end

global function loadbuiltin(ichar shortfile, text)int=
	ichar s
	[128]char str

	if nsourcefiles>maxsourcefile then
		loaderror("Too many source files")
	fi
	++nsourcefiles
	fprint @&.str,"<Built-in: #>",shortfile

	sourcefilepaths[nsourcefiles]:=pcm_copyheapstring(&.str)
	sourcefilenames[nsourcefiles]:=pcm_copyheapstring(shortfile)

	sourcefiletext[nsourcefiles]:=pcm_copyheapstring(text)
	if fwritema then
		mafiletext[nsourcefiles]:=pcm_copyheapstring(text)
	fi

	sourcefilesizes[nsourcefiles]:=strlen(text)
	return nsourcefiles
end

global function loadbundledfile(ichar filespec,int support=0)int fileno=
	ichar file
	int n,lastmatch

	file:=extractfile(filespec)


	for i to nmafiles do
		if eqstring(file,mafilenames[i]) and support=mafilesupport[i] then		!found
			fileno:=mafilefileno[i]
			if not fileno then					!cannot overflow sourcefiles; same limits?
				fileno:=++nsourcefiles
				mafilefileno[i]:=fileno

				sourcefilepaths[nsourcefiles]:=mafilenames[i]
				sourcefilenames[nsourcefiles]:=mafilenames[i]
				sourcefiletext[nsourcefiles]:=mafiletext[i]
				sourcefilesizes[nsourcefiles]:=mafilesizes[i]

					sourcefiletext[nsourcefiles]:=pcm_copyheapstring(mafiletext[i])
			ELSE
				CPL "FOUND BUNDLED FILE SUBSEQ TIME",FILE

			fi
			return fileno
		fi
	od
	loaderror("Can't find bundled file: # #",filespec)
	return 0
end

global proc mcerror(ichar mess)=
println "MC Error:",mess

stop 1
end

global proc serror_gen(ichar mess)=

if currproc and currproc^.nameid=procid then
	print "In function",currproc^.name,," "
fi

println "On line",lx.lineno,"in file",sourcefilepaths[lx.fileno],sourcefilenames[lx.fileno]

println
println "**** Syntax Error:",mess,"****"
stopcompiler(sourcefilepaths[lx.fileno],lx.lineno)
end

global proc stopcompiler(ichar filename,int lineno)=
	filehandle f
	f:=fopen("$error.tmp","w")
	println @f,filename,lineno
	fclose(f)
	println
	println
	stop 1
end

global proc serror(ichar mess)=

serror_gen(mess)
end

global proc serror_s(ichar mess,a)=
[256]char str
fprint @&.str,mess,a
serror_gen(&.str)
end

global proc error_gen(int pass,ichar mess,unit p=nil)=
int lineno,fileno


if p then
	fileno:=p.fileno
	lineno:=p.lineno
else
	fileno:=mlineno>>24
	lineno:=mlineno iand 16777215
fi

if currproc and currproc^.nameid=procid then
	print "In function",currproc^.name,," "
fi

println "On line",lineno iand 16777215,"in file",sourcefilepaths[fileno]
println
case pass
when 'N' then print "**** RX Name Error: "
when 'T' then print "**** TX Type Error: "
when 'G' then print "**** GX Code Gen Error: "
when 'A' then print "**** 'AX Code Gen Error: "
esac
println mess

os_getch()

stopcompiler(sourcefilepaths[fileno],lineno iand 16777215)
end

global proc rxerror(ichar mess,unit p=nil)=
error_gen('N',mess,p)
end

global proc gerror(ichar mess,unit p=nil)=
error_gen('G',mess,p)
end

global proc axerror(ichar mess)=
CPL =ALINENO
error_gen('A',mess)
end

global proc txerror(ichar mess,unit p=nil)=
error_gen('T',mess,p)
end

global proc txerror_s(ichar mess,a,unit p=nil)=
[256]char str
fprint @&.str,mess,a
error_gen('T',&.str,p)
end

global proc txerror_ss(ichar mess,a,b)=
[256]char str
fprint @&.str,mess,a,b
error_gen('T',&.str)
end

global proc rxerror_s(ichar mess,a,unit p=nil)=
[256]char str
fprint @&.str,mess,a
error_gen('N',&.str,p)
end

global proc gerror_s(ichar mess,s,ref unitrec p=nil)=
[256]char str

fprint @&.str,mess,s
error_gen('G',&.str,p)
end

global proc lxerror_gen(ichar mess)=

println "On line",lx.lineno,"in file",sourcefilepaths[lx.fileno]

println
println "**** Lex Error:",mess,"****"
println

stopcompiler(sourcefilepaths[lx.fileno],lx.lineno)
end

global proc lxerror_s(ichar mess,a)=
[256]char str
fprint @&.str,mess,a
lxerror_gen(&.str)
end

global proc lxerror(ichar mess)=
lxerror_gen(mess)
end

global function testelem(ref[0:]byte p,int n)int =		!TESTELEM
return ((p^[n>>3] iand bytemasks[n iand 7])|1|0)
end

global proc setelem(ref[0:]byte p,int n) =		!SETELEM
p^[n>>3] ior:= bytemasks[n iand 7]
end

global function nextpoweroftwo(int x)int=

if x=0 then return 0 fi

int a:=1
while a<x do
	a<<:=1
od
return a
end

global proc loaderror(ichar mess,mess2="",mess3="")=
	[512]char str
	fprint @&.str,mess,mess2,mess3

	println "Load Error:",&.str
	println "Stopping"
	stop 1
end

global proc gs_additem(ref strbuffer dest,ichar s)=		!GENITEM
ichar d
int lastchar,nextchar

d:=dest^.strptr

if dest^.length then
	lastchar:=(d+dest^.length-1)^
	nextchar:=s^
	if isalphanum(lastchar) and isalphanum(nextchar) then
		strbuffer_add(dest," ")
	fi
fi
strbuffer_add(dest,s)
end

global proc gs_copytostr(ref strbuffer source,ref char s)=
if source^.length then
	memcpy(s,source^.strptr,source^.length)
	(s+source^.length)^:=0
else
	s^:=0
fi
end

global function isalphanum(int c)int=
if c>='A' and c<='Z' or c>='a' and c<='z' or c>='0' and c<='9' then
	return 1
fi
return 0
end

global proc init_tt_tables=
int i,size,bitsize
int s,t,u,v


for i:=0 to tlast-1 do

	ttname[i]:=stdnames[i]
	ttbasetype[i]:=i
	bitsize:=stdbits[i]

	switch bitsize
	when 0 then
		size:=0
	when 1,2,4 then
		size:=1
	else
		size:=bitsize/8
	endswitch

	ttsize[i]:=size

	case stdcodes[i]
	when 'I' then
		ttisint[i]:=1
		ttisinteger[i]:=1
	when 'U','C' then
		ttisword[i]:=1
		ttisinteger[i]:=1
	when 'R' then
		ttisreal[i]:=1
	when 'P','Q' then
		ttisref[i]:=1
	esac


	if ttisinteger[i] and size<8 then
		ttisshort[i]:=1
	fi

	if (ttisinteger[i] or ttisreal[i] or i=tdecimal) then
		ttisallnum[i]:=1
		if not ttisshort[i] then
			ttismainnum[i]:=1
		fi
	fi

	ttlower[i]:=1

	tttabtype[i]:=stdtabtype[i]
	tttabtype2[i]:=stdtabtype2[i]
	ttpcltype[i]:=stdpcltype[i]
	ttcat[i]:=stdcat[i]
	ttcat2[i]:=stdcat2[i]
od



ttbasetype[trefchar]:=tref
tttarget[trefchar]:=tc8


ntypes:=tlast-1


end

global proc addspecialtypes=
	trefproc:=createrefmode(nil,tproc,0)
	treflabel:=createrefmode(nil,tlabel,0)
end

function findfile(ichar filename)ichar=
	static [300]char filespec

	if fverbose=3 then
		println "Finding",filename
	fi

	for i:=nsearchdirs downto 1 do
		strcpy(&.filespec,searchdirs[i])
		strcat(&.filespec,filename)
		if fverbose=3 then
			println "	Checking:",&.filespec
		fi

		if checkfile(&.filespec) then
			if fverbose=3 then
					println "	Found:",&.filespec
			fi
			return &.filespec
		fi
	od

	return nil
end


global function getmainfile(ichar filename)int =
	if fbundled then
		return loadbundledfile(filename)
	fi
	if not checkfile(filename) then
		loaderror("Can't find main module: ##",filename)
	fi
	return loadsourcefile(filename)
end

global function getmodulefile(ichar modulename, ownername, int xdflag)int =
	[300]char filename
	ichar file,libtext


	strcpy(&.filename,addext(modulename,(xdflag|"exp"|"m")))

	if fbundled then
		return loadbundledfile(&.filename)
	fi

	if dointlibs then
		libtext:=findstdlib(&.filename)
		if libtext then
			return loadbuiltin(&.filename,libtext)
		fi
	fi

	file:=findfile(&.filename)

	if file=nil then
		loaderror("Can't find import module: # imported in: #",&.filename,ownername)
	fi
	return loadsourcefile(file)
end

global function getsupportfile(ichar filename)int =
	ichar path,file
	int fileno

	if fbundled then
		return loadbundledfile(filename,1)
	fi

	path:=extractpath(filename)
	if path^ in ['\\','/'] or path^<>0 and (path+1)^=':' then	!absolute path
		file:=filename
	else
		file:=findfile(filename)
	fi

	if file=nil or not checkfile(file) then
		loaderror("Can't find include file: # #",filename)
	fi


	fileno:=loadsourcefile(file)
	issupportfile[fileno]:=1
	return fileno
end

global proc writemafile(ichar leadmodule,destfile)=
	[256]char filename
	filehandle f
	[maxsourcefile]int fileoffsets, headeroffsets
	int offset,nn,NEWOFFSET

	strcpy(&.filename, changeext(leadmodule,"ma"))

	if destfile then
		strcpy(&.filename,destfile)
	fi

	println "Writing MA File",&.filename

	f:=fopen(&.filename,"wb")
	if not f then loaderror("Can't create ma file #",&.filename) fi

	println @f,"mafile",nsourcefiles

	for i to nsourcefiles do
		print @f,i:"3",sourcefilenames[i]:"16jl",sourcefilesizes[i]:"7"
		headeroffsets[i]:=getfilepos(f)+1
		println @f,"           ",issupportfile[i]
	od

	for i to nsourcefiles do
		fprintln @f,"=== # #/# ===",sourcefilenames[i],i,nsourcefiles

		offset:=getfilepos(f)
		fileoffsets[i]:=offset
		nn:=writerandom(f,cast(mafiletext[i]),offset,sourcefilesizes[i])
	od

	println @f,"=== end ==="

	for i to nsourcefiles do
		setfilepos(f,headeroffsets[i])
		print @f,fileoffsets[i]:"8"
	od
	fclose(f)
end

global proc loadmafile=
	filehandle f
	[16]char kwd
	[256]char filename
	int index, size, offset, issupport

	f:=fopen(mafilename,"rb")
	if not f then
		loaderror("Can't open ##",mafilename)
	fi

	readln @f

	readstr(&.kwd,'n',kwd.len)
	if not eqstring(&.kwd,"mafile") then
		loaderror("Bad sig in ma file: # '#'",mafilename,&.kwd)
	fi

	read nmafiles

	for i to nmafiles do
		readln @f,index
		readstr(&.filename,'n',filename.len)
		read size, offset, issupport
		mafilenames[i]:=pcm_copyheapstring(&.filename)
		mafilesizes[i]:=size
		mafileoffsets[i]:=offset
		mafilefileno[i]:=0
		mafilesupport[i]:=issupport
	od
	fclose(f)

	mafilesource:=cast(readfile(mafilename))
	if not mafilesource then loaderror("MA load?") fi

	for i to nmafiles do
		size:=mafilesizes[i]
		offset:=mafileoffsets[i]

		mafiletext[i]:=mafilesource+offset
		(mafilesource+offset+size)^:=0
	od
end
global function mapimport(ichar name)ichar=
	for i to nmodulemap do
		if eqstring(name,genericmodules[i]) then
			return actualmodules[i]
		fi
	od
	return name
end

global proc initbblib=
for i:=1 to D_typestarterset.len do typestarterset[D_typestarterset[i]]:=1 od
end
=== bb_libsources.m 11/40 ===
import mlib

global tabledata []ichar stdlibnames, []ichar stdlibtext =
	("msyslib.m",		strinclude "msyslib.m"),
	("mlibnew.m",		strinclude "mlibnew.m"),
	("mclib.m",			strinclude "mclib.m"),
	("mwindows.m",		strinclude "mwindows.m"),
	("mwindll.m",		strinclude "mwindll.m"),
end

global function findstdlib(ichar name)ichar=
	for i:=1 to stdlibnames.len do
		if eqstring(name,stdlibnames[i]) then
			return stdlibtext[i]
		fi
	od
	return nil
end

=== msyslib.m 12/40 ===
import clib
import mlib

global record procinforec=
	word16		fnindex
	byte		rettype
	byte		nparams
	[12]byte	paramlist
end

record fmtrec=	! (default)
	byte	minwidth	! n (0)   min field width (0 if not used or don't care)
	i8		precision	! .n (0)   number of decimals/significant figures/max width
	byte	base		! B,H or Xn (10)  2 to 16

	char	quotechar	! Qc (0)   0 or '"' or c
	char	padchar		! Pc, Z (' ')
	char	realfmt		! E,F,G ('f') 'e' or 'f' or 'g'

	char	plus		! (0)   0 or '+'
	char	sepchar		! Sc (0)   0 or ',' or c placed every 3 (base=10) or 4 digits
	char	lettercase	! A,a ('A') 'A' or 'a'
	char	justify		! JL, JR, JC ('R') 'L' or 'R' or 'C'?
	char	suffix		! Tc (0)   0 or 'B' or 'H' or c
	char	usigned		! W (0)   0 or 'W' force unsigned o/p for ints (eg. for hex display)
	char	charmode	! C,D (0)  0 or 'C' or 'D'	o/p int as int or single char or double/multi-char
	char	heapmode	! M (0)  'M' for str-functions, return ptr tp heap string
	char	param		! Use int value for <fmtparam>
	byte	spare
end

int fmtparam			!as set with :'V'

enum (std_io,file_io,str_io)

const comma = ','

global int needgap			= 0
int outdev			= std_io
filehandle outchan	= nil
ref char fmtstr 	= nil

const maxiostack=10
[maxiostack]filehandle	outchan_stack
[maxiostack]int			outdev_stack
[maxiostack]ref char	fmtstr_stack
[maxiostack]byte		needgap_stack

[maxiostack]ref char	ptr_stack		!this one doesn't need pushing, as each is pointed to from outchan
int niostack=0

[0:]char digits=A"0123456789ABCDEF"
const onesixty=360
fmtrec defaultfmt = (0,0, 10, 0,' ','f', 0,0,0,'R',0,0, 0,0,0,0)

const rd_buffersize = 16384	!total capacity of line buffer

ref char rd_buffer		! point to start of read buffer
int rd_length			! length of this line (as read by readln)
ref char rd_pos			! current position it's up to (next read starts here)
ref char rd_lastpos		! set by sread() just before reading used for reread()
int termchar			! terminator char set by readxxx()
int itemerror			!	set by some read functions, eg for reals


const maxparam=128
global int nsysparams
global [maxparam]ichar sysparams

const maxcallback=8
[0..maxcallback,8]word64 callbackstack
int ncallbacks=0

word64 mask63	= 0x7FFF'FFFF'FFFF'FFFF
real offset64	= 9223372036854775808.0		! 2**63 as r64
real offset32	= 9223372036854775808.0		! 2**63 as r32

global proc m$init=
int32 nargs
int nargs64
ref[]ichar args
ref[]ichar env
static [128]byte startupinfo			! 68 or 104 bytes
int res
ichar s


res:=__getmainargs(&nargs,cast(&args),cast(&env),0,cast(&startupinfo))

nsysparams:=nargs

if nsysparams>maxparam then
	printf("Too many params\n")
	stop 50
fi

nargs64:=nargs			!bug when using 32-bit limit when compild with mm
for i:=1 to nargs64 do
	sysparams[i]:=args^[i]
od

m$print_startcon()		!allow most print stmts without startcon/end

end

global proc m$stop(int n)=
	`exit(n)
end

global function m$lenstr_stringz(ref char s)int=
	strlen(s)
end



proc pushio=
	if niostack>=maxiostack then
		printf("Too many io levels\n")
		stop 53
	fi
	++niostack
	outchan_stack[niostack]	:= outchan
	outdev_stack[niostack]	:= outdev
	fmtstr_stack[niostack]	:= fmtstr
	needgap_stack[niostack]	:= needgap
	needgap:=0
	fmtstr:=nil
	outchan:=nil
end

global proc m$print_startfile(ref void dev)=
	pushio()
	outchan:=cast(dev)
	if dev then
		outdev:=file_io
	else
		outdev:=std_io
	fi
end

global proc m$print_startstr(ref char s)=
	ref ref char p
	pushio()

	ptr_stack[niostack]:=s
	p:=&ptr_stack[niostack]

	outchan:=cast(p)
	outdev:=str_io
end

global proc m$print_startptr(ref ref char p)=
	pushio()

	outchan:=cast(p)
	outdev:=str_io
end

global proc m$print_startcon=
	pushio()
	outdev:=std_io
end

global proc m$print_setfmt(ref char format)=
	fmtstr:=format
end

global proc m$print_end=
	needgap:=0
	nextfmtchars(1)
	if niostack=0 then return fi
	outchan	:= outchan_stack[niostack]
	outdev	:= outdev_stack[niostack]
	fmtstr	:= fmtstr_stack[niostack]
	needgap	:= needgap_stack[niostack]
	--niostack
end

global proc m$print_ptr(u64 a,ichar fmtstyle=nil)=
	[20]char s

	if fmtstyle=nil then
		fmtstyle:="z8H"
	fi
	m$print_u64(a,fmtstyle)
end

global proc m$print_ptr_nf(u64 a)=
	m$print_ptr(a)
end

global proc m$print_i64(int64 a,ichar fmtstyle=nil)=
	[40]char s
	fmtrec fmt
	int n

	nextfmtchars()
	if fmtstyle=nil then
		if a>=0 then
			n:=u64tostr(a,&.s,10,0)
		else
			s[1]:='-'
			n:=u64tostr(-a,&s[2],10,0)+1
		fi
		printstr_n(&.s,n)

	else

		strtofmt(fmtstyle,-1,&fmt)
		if fmt.param='V' then
			fmtparam:=a
			needgap:=0
		else
			tostr_i64(a,&fmt)
		fi
	fi
	needgap:=1
end

global proc m$print_i64_nf(int64 a)=
	m$print_i64(a)
end

global proc m$print_u64(word64 a,ichar fmtstyle=nil)=
	[40]char s
	fmtrec fmt

	nextfmtchars()
	if fmtstyle=nil then
		sprintf(&.s,"%llu",a)
		printstr(&.s)
	else
		strtofmt(fmtstyle,-1,&fmt)
		tostr_u64(a,&fmt)
	fi
	needgap:=1
end

global proc m$print_i128(int128 a,ichar fmtstyle=nil)=
	[40]char s
	fmtrec fmt

	nextfmtchars()
	strtofmt(fmtstyle,-1,&fmt)
	if a>=0 then
		tostr_u128(a,&fmt,0)
	else
		tostr_u128(-a,&fmt,1)
	fi

	needgap:=1
end

global proc m$print_u128(word128 a,ichar fmtstyle=nil)=
	[40]char s
	fmtrec fmt

	nextfmtchars()
	strtofmt(fmtstyle,-1,&fmt)
	tostr_u128(a,&fmt,0)
	needgap:=1
end

global proc m$print_r64(real x,ichar fmtstyle=nil)=
	[360]char s
	fmtrec fmt

	nextfmtchars()
	if fmtstyle=nil then
		sprintf(&.s,"%f",x)
		printstr(&.s)
	else
		strtofmt(fmtstyle,-1,&fmt)
		tostr_r64(x,&fmt)
	fi

	needgap:=1
end

global proc m$print_r32(real32 x,ichar fmtstyle=nil)=
	m$print_r64(x,fmtstyle)
end

global proc m$print_c8(int64 a,ichar fmtstyle=nil)=
	[40]char s
	fmtrec fmt
	int n

	nextfmtchars()

	s[1]:=a
	s[2]:=0
	printstr(&.s)
	needgap:=1
end

global proc m$print_str(ichar s, fmtstyle=nil)=
	nextfmtchars()

	if s=nil then
		printstr("<null>")
		return
	fi


	fmtrec fmt
	if fmtstyle=nil then
		printstr(s)
	else
		strtofmt(fmtstyle,-1,&fmt)
		tostr_str(s,&fmt)
	fi
	needgap:=1
end

global proc m$print_str_nf(ichar s)=
	m$print_str(s)
end

global proc m$print_strsl(slice[]char s, ichar fmtstyle=nil)=
	nextfmtchars()
	fmtrec fmt
	if fmtstyle=nil then
		printstr_n(cast(s.sliceptr),s.len)
	else
		abortprogram("FORMATED PRINT SLICE NOT READY")
	fi
	needgap:=1
end

global proc m$print_newline=
	needgap:=0
	nextfmtchars(1)
	printstr("\w")
end

global proc m$print_nogap=
	needgap:=0
end

global proc printstr(ichar s)=
	int n
	ref ref char p

	case outdev
	when std_io then
		printf("%s",s)
	when file_io then
		fprintf(outchan,"%s",s)
	when str_io then
		p:=cast(outchan)
		strcpy(p^,s)
		p^+:=strlen(s)
		p^^:=0
	esac
end

global proc printstr_n(ichar s,int n=-1)=
	ref ref char p

	case n
	when -1 then n:=strlen(s)
	when 0 then return
	esac

	case outdev
	when std_io then
		printf("%.*s",n,s)
	when file_io then
		fprintf(outchan,"%.*s",n,s)
	when str_io then
		p:=cast(outchan)
		memcpy(p^,s,n)
		p^+:=n
		p^^:=0
	esac
end

global proc printstrn_app(ichar s, int length, filehandle f=nil)=
if length then
	if f=nil then
		printf("%.*s",length,s)
	else
		fprintf(f,"%.*s",length,s)
	fi
fi
end

proc printchar(int ch)=
	ref ref char p
	case outdev
	when std_io then
		printf("%c",ch)
	when file_io then
		fprintf(outchan,"%c",ch)
	when str_io then
		p:=cast(outchan)
		p^^:=ch
		p^+:=1
		p^^:=0
	esac
end

global proc nextfmtchars(int lastx=0)=
	char c
	ref char pstart
	int n
	if not fmtstr then			!format not in use
		if needgap then
			printchar(' ')
		fi
		needgap:=0
		return
	fi

	pstart:=fmtstr
	n:=0

	do
		c:=fmtstr^
		switch c
		when '#' then
			if lastx then
				goto skip
			fi
			++fmtstr
			if n then
				printstr_n(pstart,n)
			fi
			return
		when 0 then
			if n then
				printstr_n(pstart,n)
			elsif not lastx then
				printstr_n("|",1)
			fi
			return
		when '~' then
			if n then
				printstr_n(pstart,n)
				n:=0
			fi
			++fmtstr
			c:=fmtstr^
			if c then
				++fmtstr
				printchar(c)
			fi
			pstart:=fmtstr
		else
	skip::
			++n
			++fmtstr
		endswitch
	od
end

global proc strtofmt(ref char s,int slen,ref fmtrec fmt) =		!PC_STRTOFMT

	int c
	byte wset
	int n
	[0:100]char str

	fmt^:=defaultfmt

	if s=nil then return fi

	if slen=-1 then slen:=strlen(s) fi

	memcpy(&.str,s,slen)		!convert s/slen to zero-terminated string
	str[slen]:=0
	s:=&.str

	wset:=0
	while s^ do
		c:=s^
		++s
		switch c
		when 'B', 'b' then fmt^.base:=2
		when 'H', 'h' then fmt^.base:=16
		when 'O', 'o' then fmt^.base:=8
		when 'X', 'x' then
			c:=s^
			if c then
				switch c
				when '0'..'9' then c:=c-'0'
				when 'A'..'F' then c:=c-'A'+10
				when 'a'..'f' then c:=c-'a'+10
				else
					c:=10
				end
				fmt^.base:=c
				++s
			fi
		when 'Q', 'q' then fmt^.quotechar:='"'
		when '~' then fmt^.quotechar:='~'
		when 'J', 'j' then
			fmt^.justify:=toupper(s^)
			if s^ then
				++s
			fi
		when 'A' then fmt^.lettercase:='A'
		when 'a' then fmt^.lettercase:='a'
		when 'Z', 'z' then fmt^.padchar:='0'
		when 'S', 's' then
			fmt^.sepchar:=s^
			if s^ then
				++s
			fi
		when 'P', 'p' then
			fmt^.padchar:=s^
			if s^ then
				++s
			fi
		when 'T', 't' then
			fmt^.suffix:=s^
			if s^ then
				++s
			fi
		when 'W', 'w' then fmt^.usigned:='W'
		when 'E', 'e' then fmt^.realfmt:='e'
		when 'F', 'f' then fmt^.realfmt:='f'
		when 'G', 'g' then fmt^.realfmt:='g'
		when '.' then
			wset:=1
		when comma,'_' then fmt^.sepchar:=c
		when '+' then fmt^.plus:='+'
		when 'D', 'd' then fmt^.charmode:='D'
		when 'C', 'c' then fmt^.charmode:='C'
		when 'M', 'm' then fmt^.heapmode:='M'
		when 'V','v' then fmt.param:='V'
		when '*' then
			n:=fmtparam
			goto gotwidth
		else
			if c>='0' and c<='9' then
				n:=c-'0'
				do
					c:=s^
					if s^=0 then
						exit
					fi
					if c>='0' and c<='9' then
						++s
						n:=n*10+c-'0'
					else
						exit
					fi
				od
gotwidth::
				if not wset then
					fmt^.minwidth:=n
					wset:=1
				else
					fmt^.precision:=n
				fi
			fi
		endswitch
	od
end

function domultichar (ref char p,int n,ref char dest,ref fmtrec fmt)int =
	[0:20]char str
	ref char q
	int i,nchars

	q:=&.str

	nchars:=n

	to n do
		if p^=0 then exit fi
		q^:=p^
		++q
		++p
	od
	q^:=0

	return expandstr(&.str,dest,strlen(&.str),fmt)
end

function expandstr(ref char s,ref char t,int n,ref fmtrec fmt)int =		!EXPANDSTR

	int i,w,m

	w:=fmt^.minwidth
	if w=0 or w<=n then		! allow str to be longer than minwidth
		strncpy(t,s,n)
		(t+n)^:=0
		return n
	fi

	if fmt^.justify='L' then	! left-justify
		strncpy(t,s,n)
		t+:=n
		for i:=1 to w-n do
			t^:=fmt^.padchar
			++t
		od
		t^:=0
	elsif fmt^.justify='R' then
		if fmt^.padchar='0' and fmt^.base and (s^='-' or s^='+') then ! need to move sign outside 
			t^:=s^
			++t
			to w-n do
				t^:=fmt^.padchar
				++t
			od
			strncpy(t,s+1,n-1)
			(t+n-1)^:=0
		else
			to w-n do
				t^:=fmt^.padchar
				++t
			od
			strncpy(t,s,n)
			(t+n)^:=0
		fi

	else				! centre-justify?

		m:=(w-n+1)/2
		to m do
			t^:=fmt^.padchar
			++t
		od
		strncpy(t,s,n)
		t+:=n
		to w-n-m do
			t^:=fmt^.padchar
			++t
		od
		t^:=0

	fi
	return w
end


function u64tostr(u64 aa,ref char s,word base,int sep)int =		!U64TOSTR
	[0:onesixty]char t
	u64 dd
	int i,j,k,g
	int cc
	int dummy
	ref char s0

	i:=0
	k:=0
	g:=(base=10|3|4)

	repeat
		dd:=aa rem base
		aa:=aa/base

		t[++i]:=digits[dd]

		++k
		if sep and aa<>0 and k=g then
			t[++i]:=sep
			k:=0
		fi
	until aa=0

	j:=i
	s0:=s
	while i do
		s^:=t[i--]
		++s
	od
	s^:=0

	return j
end

function u128tostr(u128 aa,ref char s,word base,int sep)int =
	[0:160]char t
	u64 dd
	int i,j,k,g
	int dummy
	ref char s0

	i:=0
	k:=0
	g:=(base=10|3|4)

	repeat
		aa:=xdivrem128(aa,base,dd)
		t[++i]:=digits[dd]


		++k
		if sep and aa<>0 and k=g then
			t[++i]:=sep
			k:=0
		fi
	until aa=0

	j:=i
	s0:=s
	while i do
		s^:=t[i--]
		++s
	od
	s^:=0

	return j
end

function xdivrem128(word128 a, word64 b, &remainder)word128=
	word128 d,e,r
	word rlow

	d:=a/b
	r:=a-d*b

	assem
		mov d0,[r]
		mov [rlow],d0
	end
	remainder:=rlow
	return d
end

function i64tostrfmt(i64 aa,ref char s,ref fmtrec fmt)int =
	[0:onesixty]char str				! allow for binary with separators!
	int i,j,k,n,w,usigned
	const i64 mindint=0x8000'0000'0000'0000

	usigned:=0
	if fmt^.usigned then
		usigned:=1
	fi

	if aa=mindint and not usigned then		! minint

		str[0]:='-'
		n:=i64mintostr(&str[1],fmt^.base,fmt^.sepchar)+1
	else
		if (not usigned and aa<-0) or fmt^.plus then
			if aa<0 then
				aa:=-aa
				str[0]:='-'
			else
				str[0]:='+'
			fi
			n:=u64tostr(aa,&str[1],fmt^.base,fmt^.sepchar)+1
		else
			n:=u64tostr(aa,&.str,fmt^.base,fmt^.sepchar)
		fi
	fi

	if fmt^.suffix then
		str[n]:=fmt^.suffix
		str[++n]:=0
	fi

	if (fmt^.base>10 or fmt^.suffix) and fmt^.lettercase='a'	then	! need lower when
		convlcstring(&.str)
	fi

	return expandstr(&.str,s,n,fmt)
end

function u64tostrfmt(i64 aa,ref char s,ref fmtrec fmt)int =		!U64TOSTRFMT
	[0:onesixty]char str				! allow for binary with separators!
	int i,j,k,n,w

	n:=u64tostr(aa,&.str,fmt^.base,fmt^.sepchar)

	if fmt^.suffix then
		str[n]:=fmt^.suffix
		str[++n]:=0
	fi

	if fmt^.base>10 or fmt^.suffix and fmt^.lettercase='a'	then	! need lower when
	fi

	return expandstr(&.str,s,n,fmt)
end

function u128tostrfmt(i128 aa,ref char s,ref fmtrec fmt)int =		!U64TOSTRFMT
	[0:onesixty]char str				! allow for binary with separators!
	int i,j,k,n,w

	n:=u128tostr(aa,&.str,fmt^.base,fmt^.sepchar)

	if fmt^.suffix then
		str[n]:=fmt^.suffix
		str[++n]:=0
	fi

	if fmt^.base>10 or fmt^.suffix and fmt^.lettercase='a'	then	! need lower when
		convlcstring(&.str)
	fi

	return expandstr(&.str,s,n,fmt)
end

function i64mintostr(ref char s,int base,int sep)int =		!I64MINTOSTR
	[0:onesixty]char t
	int i,j,k,g,neg

	switch base
	when 10 then
		strcpy(&t[0],"9223372036854775808")
		j:=3
	when 16 then
		strcpy(&t[0],"8000000000000000")
		j:=1
	when 2 then
		strcpy(&t[0],"1000000000000000000000000000000000000000000000000000000000000000")
		j:=7
	else
		strcpy(&t[0],"<mindint>")
	endswitch

	i:=strlen(&t[0])
	s+:=i
	if sep then
		s+:=j
	fi
	s^:=0

	k:=0
	g:=(base=10|3|4)

	while i do
		--s
		s^:=t[i-- -1]
		if sep and i and ++k=g then
			--s
			s^:=sep
			k:=0
		fi
	od
	return strlen(s)
end

function strtostrfmt(ref char s,ref char t,int n,ref fmtrec fmt)int =
	ref char u,v
	[256]char str
	int w,nheap		! whether any heap storage is used  bytes allocated

	nheap:=0

	if fmt^.quotechar or fmt^.lettercase then		! need local copy
		if n<256 then
			u:=&.str
		else
			nheap:=n+3					! allow for quotes+terminator
			u:=pcm_alloc(nheap)
		fi
		if fmt^.quotechar then
			v:=u
			v^:=fmt^.quotechar
			++v
			if n then
				strcpy(v,s)
				v+:=n
			fi
			v^:=fmt^.quotechar
			++v
			v^:=0
			n+:=2
		else
			memcpy(u,s,n)
		fi
		switch fmt^.lettercase
		when 'a' then	! need lower when
			convlcstring(u)
		when 'A' then
			convucstring(u)
		endswitch
		s:=u
	fi

	w:=fmt^.minwidth
	if w>n then
		n:=expandstr(s,t,n,fmt)
	else
		memcpy(t,s,n)
	fi
	if nheap then
		pcm_free(u,nheap)
	fi
	return n
end

proc tostr_i64(int64 a, ref fmtrec fmt)=
	[360]char str
	int n

	case fmt^.charmode
	when 0 then
		n:=i64tostrfmt(a,&.str,fmt)
	when 'D','d' then
		n:=domultichar(ref char(&a),8,&.str,fmt)

	else						!assume 'C'
		printchar(a)			!no other formatting allowed
		return
	esac

	printstr_n(&.str,n)
end

proc tostr_u64(word64 a, ref fmtrec fmt)=
	[360]char str
	int n

	case fmt^.charmode
	when 'D','d' then
		n:=domultichar(ref char(&a),8,&.str,fmt)

	when 'C','c' then
		printchar(a)			!no other formatting allowed
		return

	else
		n:=u64tostrfmt(a,&.str,fmt)
	esac

	printstr_n(&.str,n)
end

proc tostr_u128(word128 a, ref fmtrec fmt,int neg)=
	[360]char str
	int n

	case fmt^.charmode
	when 'D','d' then
		n:=domultichar(ref char(&a),8,&.str,fmt)

	when 'C','c' then
		printchar(a)			!no other formatting allowed
		return

	else
		if neg then
			str[1]:='-'
			n:=u128tostrfmt(a,&str[2],fmt)+1
		else
			n:=u128tostrfmt(a,&.str,fmt)
		fi
	esac

	printstr_n(&.str,n)
end

proc tostr_r64(real x,ref fmtrec fmt) =
	[360]char str,str2
	[0:10]char cfmt
	int n

	cfmt[0]:='%'

	if fmt^.precision then
		cfmt[1]:='.'
		cfmt[2]:='*'
		cfmt[3]:=fmt^.realfmt
		cfmt[4]:=0
		sprintf(&.str,&.cfmt,fmt^.precision,x)
	else
		cfmt[1]:=fmt^.realfmt
		cfmt[2]:=0
		sprintf(&.str,&.cfmt,x)
	fi


	n:=strlen(&.str)		! current length

	if n<fmt^.minwidth then
		n:=expandstr(&.str,&.str2,n,fmt)
		strcpy(&.str,&.str2)
	fi

	printstr_n(&.str,n)
end

proc tostr_str(ref char s, ref fmtrec fmt) =
	int oldlen,newlen,n
	ref char t

	oldlen:=strlen(s)
	newlen:=oldlen

	if fmt^.quotechar or fmt^.minwidth>newlen or fmt^.lettercase or fmt.precision then
		if fmt^.quotechar then
			newlen+:=2
		fi
		if fmt^.minwidth>newlen then
			newlen:=fmt^.minwidth
		fi
		t:=pcm_alloc(newlen+1)
		n:=strtostrfmt(s,t,oldlen,fmt)
		if fmt.precision then
			n min:=fmt.precision
		fi

		printstr_n(t,n)
		pcm_free(t,newlen+1)
	else
		printstr_n(s,oldlen)
	fi
end

global function getfmt(ichar fmtstyle)ref fmtrec=
	static fmtrec fmt
	if fmtstyle then
		strtofmt(fmtstyle,-1,&fmt)
		return &fmt
	else
		return &defaultfmt
	fi
end

global function strint(int64 a, ichar fmtstyle=nil)ichar=
	static [100]char str
	ref fmtrec fmt

	m$print_startstr(&.str)
	tostr_i64(a,fmt:=getfmt(fmtstyle))
	m$print_end()
	return getstr(&.str,fmt)
end

global proc getstrint(int64 a, ichar dest)=
	m$print_startstr(dest)
	tostr_i64(a,getfmt(nil))
	m$print_end()
end

global function strword(word64 a, ichar fmtstyle=nil)ichar=
	static [100]char str
	ref fmtrec fmt

	m$print_startstr(&.str)
	tostr_u64(a,fmt:=getfmt(fmtstyle))
	m$print_end()
	return getstr(&.str,fmt)
end

global function strreal(real a, ichar fmtstyle=nil)ichar=
	static [320]char str
	ref fmtrec fmt

	m$print_startstr(&.str)
	tostr_r64(a,fmt:=getfmt(fmtstyle))
	m$print_end()
	return getstr(&.str,fmt)
end

function getstr(ichar s, ref fmtrec fmt)ichar=
	if fmt^.heapmode then
		return pcm_copyheapstring(s)
	else
		return s
	fi
end

proc initreadbuffer=
	if rd_buffer then return fi
	rd_buffer:=pcm_alloc(rd_buffersize)
	rd_buffer^:=0
	rd_pos:=rd_lastpos:=rd_buffer
end

global proc m$read_conline=
	initreadbuffer()

	readlinen(nil,rd_buffer,rd_buffersize)

	rd_length:=strlen(rd_buffer)
	rd_pos:=rd_buffer
	rd_lastpos:=nil
end

global proc m$read_fileline(filehandle f)=
	initreadbuffer()
	readlinen(f,rd_buffer,rd_buffersize)

	rd_length:=strlen(rd_buffer)
	rd_pos:=rd_buffer
	rd_lastpos:=nil
end

global proc m$read_strline(ichar s)=
	int n

	initreadbuffer()
	n:=strlen(s)

	if n<rd_buffersize then
		strcpy(rd_buffer,s)
	else
		memcpy(rd_buffer,s,rd_buffersize-1)
		(rd_buffer+rd_buffersize-1)^:=0
	fi
	rd_length:=n
	rd_pos:=rd_buffer
	rd_lastpos:=nil
end

function readitem(int &itemlength)ref char =
	ref char p,s,itemstr
	char quotechar, c

	unless rd_buffer then 
		initreadbuffer()
	end unless


	s:=rd_pos

	while s^=' ' or s^=9 do
		++s
	od

	itemstr:=s				!assume starts here
	rd_lastpos:=rd_pos:=s

	if s^=0 then			! No more chars left to read return null string
		termchar:=0
		itemlength:=0
		return s
	fi

	quotechar:=0			! Allow possible enclosing single or double quotes
	if s^='"' then
		quotechar:='"'
		++s
	elsif s^='\'' then
		quotechar:='\''
		++s
	fi

	p:=itemstr:=s

	while s^ do
		c:=s++^
		switch c
		when ' ', 9, comma, '=' then		! separator
			if quotechar or p=s then			!can be considered part of name if inside quotes, or is only char
				goto normalchar
			fi
			termchar:=c
			exit
		else
	normalchar::
			if c=quotechar then
				if s^=quotechar then	! embedded quote
					p^:=c
					++s
					++p
				else					! end of name
					termchar:=s^
					if termchar=',' or termchar='=' then
						++s
						termchar:=s^
					fi
					exit
				fi
			else
				p^:=c
				++p
			fi
		endswitch
	od

	if s^=0 then
		termchar:=0
	fi
	itemlength:=p-itemstr				! actual length of token
	rd_pos:=s

	return itemstr
end

global function strtoint(ichar s,int length=-1, word base=10)int64=
	byte signd
	word64 aa
	word c,d

	itemerror:=0

	if length=-1 then
		length:=strlen(s)
	fi
	signd:=0
	if length and s^='-' then
		signd:=1; ++s; --length
	elsif length and s^='+' then
		++s; --length
	fi

	aa:=0
	while length do
		c:=s++^
		--length
		switch c
		when 'A'..'F' then d:=c-'A'+10
		when 'a'..'f' then d:=c-'a'+10
		when '0'..'9' then d:=c-'0'
		when '_', '\'' then
			next
		else
			itemerror:=1
			exit
		endswitch

		if d>=base then
			itemerror:=1
			exit
		fi
		aa:=aa*base+d
	od

	if signd then
		return -aa
	else
		return aa
	fi
end

global function m$read_i64(int fmt=0)int64=
	ref char s
	int length,c
	int64 aa

	case fmt
	when 'C','c' then
		rd_lastpos:=rd_pos
		if rd_pos^ then
			return rd_pos++^
		else
			return 0
		fi
	when 'T','t' then
		return termchar
	when 'E','e' then
		return itemerror
	esac

	s:=readitem(length)

	case fmt
	when 0,'I','i' then
		return strtoint(s,length)
	when 'B','b' then
		return strtoint(s,length,2)
	when 'H','h' then
		return strtoint(s,length,16)
	esac
	return 0
end

global function m$read_r64(int fmt=0)real=
	[512]char str
	ref char s
	int length
	int32 numlength
	real x

	s:=readitem(length)

	if length=0 or length>=str.len then		!assume not a real
		return 0.0
	fi
	memcpy(&.str,s,length)
	str[length+1]:=0

	itemerror:=0

	if sscanf(&.str,"%lf%n", &x, &numlength)=0 or numlength<>length then
		x:=0.0
		itemerror:=1
	fi

	return x
end

global proc m$read_str(ref char dest, int destlen=0,fmt=0)=
	ref char s
	int length,numlength
	real x

	itemerror:=0
	if fmt='L' or fmt='l' then
		s:=rd_pos
		length:=rd_buffer+rd_length-rd_pos

	else
		s:=readitem(length)

		if fmt='N' or fmt='n' then
			iconvlcn(s,length)
		fi
	fi

	if destlen>0 then
		if length>=destlen then
			length:=destlen-1
			itemerror:=1
		fi
	fi
	memcpy(dest,s,length)
	(dest+length)^:=0
end

global proc readstr(ref char dest, int fmt=0,destlen=0)=
	m$read_str(dest,destlen,fmt)
end

global proc rereadln=
	rd_pos:=rd_buffer
	rd_lastpos:=rd_pos
end

global proc reread=
	rd_pos:=rd_lastpos
end

global function valint(ichar s, int fmt=0)int64=
ref char old_pos, old_lastpos
int64 aa

initreadbuffer()
old_pos:=rd_pos
old_lastpos:=rd_lastpos

rd_pos:=s
aa:=m$read_i64(fmt)
rd_pos:=old_pos
rd_lastpos:=old_lastpos
return aa
end

global function valreal(ichar s)real=
ref char old_pos, old_lastpos
real x

initreadbuffer()
old_pos:=rd_pos
old_lastpos:=rd_lastpos

rd_pos:=s
x:=m$read_r64()
rd_pos:=old_pos
rd_lastpos:=old_lastpos
return x
end

proc iconvlcn(ref char s,int n) =		!ICONVLCN
to n do
	s^:=tolower(s^)
	++s
od
end

proc iconvucn(ref char s,int n) =		!ICONVUCN
to n do
	s^:=toupper(s^)
	++s
od
end

proc convlcstring(ref char s)=		!CONVLCSTRING
while (s^) do
	s^:=tolower(s^)
	++s
od
end

proc convucstring(ref char s)=		!CONVUCSTRING
while (s^) do
	s^:=toupper(s^)
	++s
od
end

global proc m$float_u64_r64(word a)=
	assem
		cmp D10,0
		jl fl1
		cvtsi2sd XMM0,D10
		jmp flx
fl1:						!negative value
		and D10,[mask63]		!clear top bit (subtract 2**63)
		cvtsi2sd XMM0,D10
		addsd XMM0,[offset64]	!(add 2**63 back to result)
flx:
	end
end

global function m$power_i64(int64 a,n)int64=
	if n<0 then
		return 0
	elsif n=0 then
		return 1
	elsif n=1 then
		return a
	elsif n.even then
		return m$power_i64(sqr a, n/2)
	else			!assume odd
		return m$power_i64(sqr a, (n-1)/2)*a
	fi
end


global proc m$mul_i128(word128 aa,bb)=
	assem
		push d3
		push d4
		push d5
		mov d2,[aa]			!a1
		mov d3,[aa+8]		!a2
		mov d4,[bb]			!b1
		mov d5,[bb+8]		!b2


		mov d0,d2			!a1
		imul2 d0,d5			!*b2	
		mov d6,d0			!=>d6

		mov d0,d3			!a2
		imul2 d0,d4			!*b1
		mov d7,d0			!=>d7

		mov d0,d2			!a1
		mul d4				!*b1
		add d11,d6			! + a1*b2<<64
		add d11,d7			! + a2*b1<<64
		mov d1,d11
		pop d5
		pop d4
		pop d3
	end
end

global proc m$idiv_i128(word128 aa,bb)=
charlie::
	assem
		push d3
		push d4
		push d6


		mov d2,[aa]
		mov d3,[aa+8]

		mov d4,[bb]
		or d4,d4
		jz divbyzero

		mov d0,d3		!a2
		xor d11,d11
		div d4			!a2/b
		mov d6,d0		! => c2
		mul d4			!c2*b
		sub d3,d0		!a2-:=c2*b

		mov d0,d2
		mov d11,d3		!a2:a1
		div d4			!/b
		mov d1,d6
		pop d6
		pop d4
		pop d3

	end
	return

asm divbyzero:
CPL "DIV BY ZERO"
	stop 1
end

global proc m$dotindex(word i,a)=
end

global proc m$dotslice(word j,i,a)=
end

global proc m$popdotindex(word i,ref word p,word x)=
end

global proc m$popdotslice(word j,i, ref word p, word x)=
end



global proc mclunimpl(ichar mess)=
	printf("MCL-UNIMPL: %s\n",mess)
	stop 1
end
=== mlibnew.m 13/40 ===
import msys
import clib
import oslib

const mem_check=0

GLOBAL INT MDEBUG
GLOBAL INT NPCMALLOC


global [0..300]u64 allocupper
global int alloccode				!set by heapalloc
global int allocbytes				!set by heapalloc
global int fdebug=0
global int rfsize

const threshold=1<<25
const alloc_step=1<<25
word maxmemory
int  maxalloccode

byte pcm_setup=0

int show=0

global int memtotal=0
global int64 smallmemtotal=0
global int smallmemobjs=0
global int maxmemtotal=0

const int maxmemalloc=(mem_check|500000|2)
[maxmemalloc+1]ref int32 memalloctable
[maxmemalloc+1]int32 memallocsize

const pcheapsize=1048576*2
ref byte pcheapstart
ref byte pcheapend			!points to first address past heap
ref byte pcheapptr

const int maxblockindex = 8 		!2048
global const int maxblocksize = 2048

[0:maxblocksize+1]byte sizeindextable	!convert byte size to block index 1..maxblockindex

const int size16   = 1			!the various index codes
const int size32   = 2
const int size64   = 3
const int size128  = 4
const int size256  = 5
const int size512  = 6
const int size1024 = 7
const int size2048 = 8

GLOBAL [0:9]ref wordp freelist

global record strbuffer =
	ichar strptr
	int32 length
	int32 allocated
end

global tabledata() [0:]ichar pmnames=
	(pm_end=0,		$),
	(pm_option,		$),
	(pm_sourcefile,	$),
	(pm_libfile,	$),
	(pm_colon,		$),
	(pm_extra,		$),
end

[2]word seed = (0x2989'8811'1111'1272',0x1673'2673'7335'8264)

global function pcm_alloc(int n)ref void =		!PCM_ALLOC
ref byte p

if not pcm_setup then
	pcm_init()
fi

if n>maxblocksize then			!large block allocation

	alloccode:=pcm_getac(n)
	allocbytes:=allocupper[alloccode]

	p:=allocmem(allocbytes)
	if not p then
		abortprogram("pcm_alloc failure")
	fi

	if mem_check then addtomemalloc(ref int32(p),allocbytes) fi

	return p
fi

alloccode:=sizeindextable[n]		!Size code := 0,1,2 etc for 0, 16, 32 etc

allocbytes:=allocupper[alloccode]

if p:=ref byte(freelist[alloccode]) then		!Items of this block size available
if mem_check then addtomemalloc(ref int32(p),allocbytes) fi
	freelist[alloccode]:=ref wordp(int((freelist[alloccode])^))

	return p
fi

p:=pcheapptr				!Create item at start of remaining pool in heap block
pcheapptr+:=allocbytes			!Shrink remaining pool

if pcheapptr>=pcheapend then		!Overflows?
	p:=pcm_newblock(allocbytes)		!Create new heap block, and allocate from start of that
	return p
fi
if mem_check then addtomemalloc(ref int32(p),allocbytes) fi

return p
end

global proc pcm_free(ref void p,int n) =		!PCM_FREE
int acode

if n=0 then return fi

if n>maxblocksize then		!large block
	if mem_check then removefrommemalloc(p,n) fi

	free(p)
	return
fi

if p then
	acode:=sizeindextable[n]		!Size code := 0,1,2 etc for 0, 16, 32 etc

	smallmemtotal-:=allocupper[acode]

	if mem_check then removefrommemalloc(p,allocupper[acode]) fi

	cast(p,ref wordp)^:=wordp(int(freelist[acode]))
	freelist[acode]:=p
fi
end

global proc pcm_freeac(ref void p,int alloc) =		!PCM_FREEAC
pcm_free(p,allocupper[alloc])
end

global proc pcm_copymem4(ref void p,q,int n) =	!PCM_COPYMEM4

memcpy(p,q,n)
end

global proc pcm_clearmem(ref void p,int n) =		!PCM_CLEARMEM
memset(p,0,n)
end

global proc pcm_init =		!PCM_INIT
int j,k,k1,k2
int64 size
const limit=1<<33

if pcm_setup then
	return
fi

pcm_newblock(0)

for i to maxblocksize do	!table converts eg. 78 to 4 (4th of 16,32,64,128)
	j:=1
	k:=16
	while i>k do
		k:=k<<1
		++j
	od
	sizeindextable[i]:=j
od

allocupper[1]:=16
size:=16

for i:=2 to 27 do
	size*:=2
	allocupper[i]:=size
	if size>=threshold then
			k:=i
		exit
	fi
od

for i:=k+1 to allocupper.upb do
	size+:=alloc_step
	if size<limit then
		allocupper[i]:=size
		maxmemory:=size
	else
		maxalloccode:=i-1
		exit
	fi
		
od
pcm_setup:=1
end

global function pcm_getac(int size)int =		!PCM_GETAC


if size<=maxblocksize then
	return sizeindextable[size]		!size 0 to 2KB
fi

size:=(size+255)>>8					!scale by 256


if size<=maxblocksize then
	return sizeindextable[size]+8
fi

size:=(size+63)>>6					!scale by 256

if size<=maxblocksize then
	return sizeindextable[size]+14
fi



size:=(size-2048+2047)/2048+22
return size
end

global function pcm_newblock(int itemsize)ref void=
static int totalheapsize
ref byte p

totalheapsize+:=pcheapsize
alloccode:=0
p:=allocmem(pcheapsize)	!can't free this block until appl terminates
if p=nil then
	abortprogram("Can't alloc pc heap")
fi

pcheapptr:=p
pcheapend:=p+pcheapsize

if pcheapstart=nil then		!this is first block
	pcheapstart:=p
fi
pcheapptr+:=itemsize
return ref u32(p)
end

global function pcm_round(int n)int =		!PCM_ROUND
static [0:maxblockindex+1]int32 allocbytes=(0,16,32,64,128,256,512,1024,2048)

if n>maxblocksize then
	return n
else
	return allocbytes[sizeindextable[n]]
fi
end

global function pcm_array(int n)int =		!PCM_ARRAY
int m

if n<=maxblocksize then	!automatic rounding up used for small heap
	return pcm_round(n)
else				!devise some strategy probably doubling up.
	m:=2048
	while n>m do
		m<<:=1
	od
	return m
fi

end

global proc pcm_printfreelist(int size,ref wordp p) =		!PCM_PRINTFREELIST
println "Size: ",size
while p do
	print " ",,p:"h"
	p:=ref wordp(int(p^))
od
puts("")
end

global proc pcm_diags(ref char caption) =		!PCM_DIAGS
int m

println "HEAP FREELISTS:",caption

m:=16
for i:=1 to 8 do
	pcm_printfreelist(m,freelist[i])
	m<<:=1
od
end

global function pcm_allocz(int n)ref void =		!PCM_ALLOCZ
ref void p
p:=pcm_alloc(n)

memset(p,0,n)
return p
end

global function pcm_copyheapstring(ref char s)ref char =
ref char q
int n
if s=nil then return nil fi

n:=strlen(s)+1
q:=pcm_alloc(n)
memcpy(q,s,n)
return q
end

global function pcm_copyheapstringn(ref char s,int n)ref char =
ref char q
if s=nil then return nil fi

q:=pcm_alloc(n+1)
memcpy(q,s,n)
(q+n)^:=0
return q
end

global function pcm_copyheapblock(ref char s, int length)ref char =
	ref char q
	if length=0 then return nil fi

	q:=pcm_alloc(length)
	memcpy(q,s,length)
	return q
end

proc addtomemalloc(ref int32 ptr,int size)=


for i to maxmemalloc do
	if memalloctable[i]=ptr then
		CPL "ALLOC ERROR:",ptr,"ALREADY ALLOCATED\n\n\n"
CPL
CPL
		stop 2
	fi

	if memalloctable[i]=nil then		!unused entry
		memalloctable[i]:=ptr
		memallocsize[i]:=size
		return
	fi
od
CPL "MEMALLOCTABLE FULL\n\n\n\n"; os_getch()
stop 3
end

proc removefrommemalloc(ref int32 ptr,int size)=


for i to maxmemalloc do
	if memalloctable[i]=ptr then

if memallocsize[i]<>size then
	CPL "REMOVE:FOUND",ptr,"IN MEMALLOCTABLE, FREESIZE=",size,", BUT STORED AS BLOCK SIZE:",memallocsize[i]
CPL
CPL
	abortprogram("MEMSIZE")
fi

		memalloctable[i]:=nil
		return
	fi
od
CPL "CAN'T FIND",ptr,"IN MEMALLOCTABLE",size
CPL
CPL
abortprogram("MEM")
stop 4
end

global function allocmem(int n)ref void =		!ALLOCMEM
ref void p

p:=malloc(n)
if (p) then
	return p
fi
println n,memtotal
abortprogram("Alloc mem failure")
return nil
end

global function reallocmem(ref void p,int n)ref void =		!REALLOCMEM
p:=realloc(p,n)
return p when p
println n
abortprogram("Realloc mem failure")
return nil
end

global proc abortprogram(ref char s) =		!ABORTPROGRAM
println s
print   "ABORTING: Press key..."
os_getch()
stop 5
end

global function getfilesize(filehandle handlex)int=		!GETFILESIZE
	word32 p,size

	p:=ftell(handlex)		!current position
	fseek(handlex,0,2)		!get to eof
	size:=ftell(handlex)		!size in bytes
	fseek(handlex,p,seek_set)	!restore position
	return size
end

global proc readrandom(filehandle handlex, ref byte mem, int offset, size) =		!READRANDOM
	int a
	fseek(handlex,offset,seek_set)
	a:=fread(mem,1,size,handlex)			!assign so as to remove gcc warning
end

global function writerandom(filehandle handlex, ref byte mem, int offset,size)int =		!WRITERANDOM
	fseek(handlex,offset,seek_set)
	return fwrite(mem,1,size,handlex)
end

global function setfilepos(filehandle file,int offset)int=
	return fseek(file,offset,0)
end

global function getfilepos(filehandle file)int=
	return ftell(file)
end

global function readfile(ref char filename)ref byte =		!READFILE
filehandle f
int size
ref byte m,p

f:=fopen(filename,"rb")
if f=nil then
	return nil
fi
rfsize:=size:=getfilesize(f)

m:=malloc(size+4)		!allow space for etx/zeof etc

if m=nil then
	return nil
fi

readrandom(f,m,0,size)
p:=m+size			!point to following byte
p^:=0
(p+1)^:=26
(p+2)^:=0			!allow use as string

fclose(f)
return m
end

global function writefile(ref char filename,ref byte data,int size)int =
filehandle f
int n

f:=fopen(filename,"wb")
if f=nil then
	return 0
fi

n:=writerandom(f,data,0,size)
fclose(f)
return n
end

global function checkfile(ref char file)int=		!CHECKFILE
filehandle f
if f:=fopen(file,"rb") then
	fclose(f)
	return 1
fi
return 0
end

global proc readlinen(filehandle handlex,ref char buffer,int size) =		!READLINEN
int ch
ref char p
int n
[0:100]char buff
byte crseen

if handlex=nil then
	handlex:=filehandle(os_getstdin())
fi
if handlex=nil then
	n:=0
	p:=buffer
	do
		ch:=getchar()
		if ch=13 or ch=10 or ch=-1 then
			p^:=0
			return
		fi
		p++^:=ch
		++n
		if n>=(size-2) then
			p^:=0
			return
		fi
	od
fi

buffer^:=0
if fgets(buffer,size-2,handlex)=nil then
	return
fi

n:=strlen(buffer)
if n=0 then
	return
fi

p:=buffer+n-1		!point to last char
crseen:=0
while (p>=buffer and (p^=13 or p^=10)) do
	if p^=13 or p^=10 then crseen:=1 fi
	p--^ :=0
od


if not crseen and (n+4>size) then
	cpl size,n
	abortprogram("line too long")
fi
end

global proc iconvlcn(ref char s,int n) =		!ICONVLCN
to n do
	s^:=tolower(s^)
	++s
od
end

global proc iconvucn(ref char s,int n) =		!ICONVUCN
to n do
	s^:=toupper(s^)
	++s
od
end

global proc convlcstring(ref char s)=		!CONVLCSTRING
while (s^) do
	s^:=tolower(s^)
	++s
od
end

global proc convucstring(ref char s)=		!CONVUCSTRING
while (s^) do
	s^:=toupper(s^)
	++s
od
end

global function changeext(ref char s,newext)ichar=		!CHANGEEXT
static [260]char newfile
[32]char newext2
ref char sext
int n

strcpy(&newfile[1],s)

case newext^
when 0 then
	newext2[1]:=0
	newext2[2]:=0
when '.' then
	strcpy(&newext2[1],newext)
else
	strcpy(&newext2[1],".")
	strcat(&newext2[1],newext)
esac


sext:=extractext(s,1)			!include "." when it is only extension

case sext^
when 0 then						!no extension not even "."
	strcat(&newfile[1],&newext2[1])
when '.' then						!no extension not even "."
	strcat(&newfile[1],&newext2[2])
else							!has extension
	n:=sext-s-2			!n is number of chars before the "."
	strcpy(&newfile[1]+n+1,&newext2[1])
esac

return &newfile[1]
end

global function extractext(ref char s,int period=0)ichar=		!EXTRACTEXT
ref char t,u

t:=extractfile(s)

if t^=0 then			!s contains no filename
	return ""
fi

u:=t+strlen(t)-1		!u points to last char of t

while u>=t do
	if u^='.' then		!start extension found
		if (u+1)^=0 then		!null extension
			return (period|"."|"")
		fi
		return u+1			!return last part of filename as extension exclude the dot
	fi
	--u
od
return ""			!no extension seen
end

global function extractpath(ref char s)ichar=		!EXTRACTPATH
static [0:260]char str
ref char t
int n

t:=s+strlen(s)-1		!t points to last char

while (t>=s) do
	switch t^
	when '\\','/',':' then		!path separator or drive letter terminator assume no extension
		n:=t-s+1			!n is number of chars in path, which includes rightmost / or \ or :
		memcpy(&.str,s,n)
		str[n]:=0
		return &.str
	endswitch
	--t
od
return ""			!no path found
end

global function extractfile(ref char s)ichar=		!EXTRACTFILE
ref char t

t:=extractpath(s)

if t^=0 then			!s contains no path
	return s
fi

return s+strlen(t)		!point to last part of s that contains the file
end

global function extractbasefile(ref char s)ichar=		!EXTRACTBASEFILE
static [0:100]char str
ref char f,e
int n,flen

f:=extractfile(s)
flen:=strlen(f)
if flen=0 then		!s contains no path
	return ""
fi
e:=extractext(f,0)

if e^ then			!not null extension
	n:=flen-strlen(e)-1
	memcpy(&str,f,n)
	str[n]:=0
	return &.str
fi
if (f+flen-1)^='.' then
	memcpy(&str,f,flen-1)
	str[flen-1]:=0
	return &.str
fi
return f
end

global function addext(ref char s,ref char newext)ichar=		!ADDEXT
ref char sext

sext:=extractext(s,1)

if sext^=0 then						!no extension not even "."
	return changeext(s,newext)
fi

return s							!has own extension; use that
end

global function alloctable(int n, size)ref void =		!ALLOCTABLE
ref void p

p:=malloc((n+1)*size)

if not p then
	abortprogram("Alloctable failure")
fi
return p
end

global function zalloctable(int n, size)ref void =		!ALLOCTABLE
ref int p

p:=alloctable(n,size)

pcm_clearmem(p,(n+1)*size)
return p
end

global proc checkfreelists(ichar s)=
ref wordp p,q
int64 aa

for i:=2 to 2 do
	p:=freelist[i]

	while p do
		aa:=int64(p)
		if aa>0xffff'FFFF or aa<100 then
			CPL s,"FREE LIST ERROR",i,p,q
		fi
		q:=p
		p:=ref wordp(int(p^))
	od

od
end


global function pcm_alloc32:ref void =		!PCM_ALLOC
ref byte p

allocbytes:=32


return pcm_alloc(32)
end

global proc pcm_free32(ref void p) =

smallmemtotal-:=32
if mem_check then removefrommemalloc(p,32) fi

cast(p,ref wordp)^:=wordp(int(freelist[2]))
freelist[2]:=p
end

global proc outbyte(filehandle f,int x)=
fwrite(&x,1,1,f)
end

global proc outword16(filehandle f,word x)=
fwrite(&x,2,1,f)
end

global proc outword(filehandle f,word x)=
fwrite(&x,4,1,f)
end

global proc outword64(filehandle f,word64 x)=
fwrite(&x,8,1,f)
end

global function myeof(filehandle f)int=
int c

c:=fgetc(f)
if c=c_eof then return 1 fi
ungetc(c,f)
return 0;
end

global function pcm_smallallocz(int n)ref void =
ref byte p

allocbytes:=allocupper[alloccode:=sizeindextable[n]]

p:=pcheapptr				!Create item at start of remaining pool in heap block
pcheapptr+:=allocbytes			!Shrink remaining pool

if pcheapptr>=pcheapend then		!Overflows?
	p:=pcm_newblock(allocbytes)		!Create new heap block, and allocate from start of that
	memset(p,0,n)
	return p
fi

memset(p,0,n)

return p
end

global function pcm_smallalloc(int n)ref void =
ref byte p

allocbytes:=allocupper[alloccode:=sizeindextable[n]]

p:=pcheapptr				!Create item at start of remaining pool in heap block
pcheapptr+:=allocbytes			!Shrink remaining pool

if pcheapptr>=pcheapend then		!Overflows?
	p:=pcm_newblock(allocbytes)		!Create new heap block, and allocate from start of that
	return p
fi

return p
end

global proc strbuffer_add(ref strbuffer dest, ichar s, int n=-1)=
int newlen,oldlen
ichar newptr

IF N=0 THEN CPL "N=0" FI

if n=-1 then
	n:=strlen(s)
fi

oldlen:=dest^.length

if oldlen=0 then				!first string
	dest^.strptr:=pcm_alloc(n+1)
	dest^.allocated:=allocbytes
	dest^.length:=n				!length always excludes terminator
	memcpy(dest^.strptr,s,n)
	(dest^.strptr+n)^:=0
	return
fi

newlen:=oldlen+n
if newlen+1>dest^.allocated then
	newptr:=pcm_alloc(newlen+1)
	memcpy(newptr,dest^.strptr,oldlen)
	dest^.strptr:=newptr
	dest^.allocated:=allocbytes
fi

memcpy(dest^.strptr+oldlen,s,n)
(dest^.strptr+newlen)^:=0

dest^.length:=newlen
end

global proc gs_init(ref strbuffer dest)=			!INITGENSTR
pcm_clearmem(dest,strbuffer.bytes)
end

global proc gs_free(ref strbuffer dest)=
if dest^.allocated then
	pcm_free(dest^.strptr,dest^.allocated)
fi
end

global proc gs_str(ref strbuffer dest,ichar s)=			!GENSTR
strbuffer_add(dest,s)
end

global proc gs_char(ref strbuffer dest,int c)=
[16]char s

s[1]:=c
s[2]:=0

strbuffer_add(dest,&.s,1)
end

global proc gs_strn(ref strbuffer dest,ichar s,int length)=
strbuffer_add(dest,s,length)
end

global proc gs_strvar(ref strbuffer dest,s)=			!GENSTR
strbuffer_add(dest,s^.strptr)
end

global proc gs_strint(ref strbuffer dest,int64 a)=
strbuffer_add(dest,strint(a))
end

global proc gs_strln(ref strbuffer dest,ichar s)=		!GENSTRLN
gs_str(dest,s)
gs_line(dest)
end

global proc gs_strsp(ref strbuffer dest,ichar s)=
gs_str(dest,s)
gs_str(dest," ")
end

global proc gs_line(ref strbuffer dest)=
strbuffer_add(dest,"\w")
end

global function gs_getcol(ref strbuffer dest)int=
return dest^.length
end

global proc gs_leftstr(ref strbuffer dest, ichar s, int w, padch=' ')=
int col,i,n,slen
[2560]char str
col:=dest^.length
strcpy(&.str,s)
slen:=strlen(s)
n:=w-slen
if n>0 then
	for i:=1 to n do
		str[slen+i]:=padch
	od
	str[slen+n+1]:=0
fi
gs_str(dest,&.str)
end

global proc gs_leftint(ref strbuffer dest, int a, int w, padch=' ')=
gs_leftstr(dest,strint(a),w,padch)
end

global proc gs_padto(ref strbuffer dest,int col, ch=' ')=
int n
[2560]char str

n:=col-dest^.length
if n<=0 then return fi
for i:=1 to n do
	str[i]:=ch
od
str[n+1]:=0
gs_str(dest,&.str)
end

global proc gs_println(ref strbuffer dest,filehandle f=nil)=
(dest.strptr+dest.length)^:=0

if f=nil then
	println dest.strptr,,"\c"
else
	println @f,dest.strptr,,"\c"
fi
end

global function nextcmdparam(int &paramno, ichar &name, &value, ichar defext=nil)int=
static int infile=0
static ichar filestart=nil
static ichar fileptr=nil
static byte colonseen=0
ref char q
ichar item,fileext
ichar rest
int length
static [300]char str

reenter::
value:=nil
name:=nil

if infile then
	if readnextfileitem(fileptr,item)=0 then		!eof
		free(filestart)								!file allocated via malloc
		infile:=0
		goto reenter
	fi
else
	if paramno>nsysparams then
		return pm_end
	fi
	item:=sysparams[paramno]
	++paramno

	length:=strlen(item)

	if item^='@' then		!@ file
		filestart:=fileptr:=cast(readfile(item+1))
		if filestart=nil then
			println "Can't open",item
			stop 7
		fi
		infile:=1
		goto reenter
	fi

	if item^=':' then
		colonseen:=1
		return pm_colon
	fi
fi

value:=nil
if item^='-' then
	name:=item+(colonseen|0|1)
	q:=strchr(item,':')
	if not q then
		q:=strchr(item,'=')
	fi
	if q then
		value:=q+1
		q^:=0
	fi
	return (colonseen|pm_extra|pm_option)
fi

fileext:=extractext(item,0)
name:=item

if fileext^=0 then							!no extension
	strcpy(&.str,name)
	if defext and not colonseen then
		name:=addext(&.str,defext)				!try .c
	fi
elsif eqstring(fileext,"dll") then
	return (colonseen|pm_extra|pm_libfile)
fi
return (colonseen|pm_extra|pm_sourcefile)
end

function readnextfileitem(ichar &fileptr,&item)int=
ref char p,pstart,pend
int n
static [256]char str

p:=fileptr

reenter::
do
	case p^
	when ' ','\t',13,10 then	!skip white space
		++p
	when 26,0 then				!eof
		return 0
	else
		exit
	esac
od

case p^
when '!', '#' then			!comment
	++p
	docase p++^
	when 10 then
		goto reenter
	when 26,0 then
		fileptr:=p-1
		return 0
	else

	enddocase
esac


case p^
when '"' then				!read until closing "
	pstart:=++p
	do
		case p^
		when 0,26 then
			println "Unexpected EOF in @file"
			stop 8
		when '"' then
			pend:=p++
			if p^=',' then ++p fi
			exit
		esac
		++p
	od
else
	pstart:=p
	do
		case p^
		when 0,26 then
			pend:=p
			exit
		when ' ','\t',',',13,10 then
			pend:=p++
			exit
		esac
		++p
	od
esac

n:=pend-pstart
if n>=str.len then
	println "@file item too long"
	stop 9
fi
memcpy(&.str,pstart,n)
str[n+1]:=0
item:=&.str
fileptr:=p

return 1
end

global proc ipadstr(ref char s,int width,ref char padchar=" ")=
int n

n:=strlen(s)
to width-n do
	strcat(s,padchar)
od
end

global function padstr(ref char s,int width,ref char padchar=" ")ichar=
static [256]char str

strcpy(&.str,s)
ipadstr(&.str,width,padchar)
return &.str
end

global function chr(int c)ichar=
static [8]char str

str[1]:=c
str[2]:=0
return &.str
end

global function cmpstring(ichar s,t)int=
	int res
	if (res:=strcmp(s,t))<0 then
		return -1
	elsif res>0 then
		return 1
	else
		return 0
	fi
end

global function cmpstringn(ichar s,t,int n)int=
	int res
	if (res:=strncmp(s,t,n))<0 then
		return -1
	elsif res>0 then
		return 1
	else
		return 0
	fi
end

global function eqstring(ichar s,t)int=
	return strcmp(s,t)=0
end

global function cmpbytes(ref void p,q,int n)int=
	int res
	if (res:=memcmp(p,q,n))<0 then
		return -1
	elsif res>0 then
		return 1
	else
		return 0
	fi
end

global function eqbytes(ref void p,q,int n)int=
	return memcmp(p,q,n)=0
end

global proc mseed(word64 a,b=0)=
seed[1]:=a
if b then
	seed[2]:=b
else
	seed[2] ixor:=a
fi
end

global function mrandom:word =
	word64 x,y
	x:=seed[1]
	y:=seed[2]
	seed[1]:=y
	x ixor:=(x<<23)
	seed[2]:= x ixor y ixor (x>>17) ixor (y>>26)
	return seed[2]+y
end

global function mrandomp:int =
	return mrandom() iand 0x7FFF'FFFF'FFFF'FFFF
end

global function mrandomint(int n)int=
	return mrandomp() rem n
end

global function mrandomrange(int a,b)int=
	int span
	span:=b-a+1
	if span<=0 then
		return 0
	fi
	return (mrandomp() rem span)+a
end

global function mrandomreal:real x=
	repeat x:=mrandomp()/9223372036854775808.0 until x<>1.0
	return x
end

global function mrandomreal1:real=
	return mrandomp()/9223372036854775807
end

global function checkpackfile:ref byte=

int a,offset,i,size
[100]char name
[300]char exefile
ref byte packexeptr			!for embedded pack files, contains pointer to in-memory version of this .exe file plus extras; else nil
int packexesize				!byte size
ref char packfilename
int packfilesize
ref byte packfileptr

macro getfileint(data,offset)=cast(data+offset,ref int32)^

strcpy(&exefile[1],os_gethostname())
println "Attempting to open",&exefile
packexeptr:=readfile(&exefile[1])

if not packexeptr then
	cpl "Can't open",&exefile,&packexeptr
	stop
fi

packexesize:=rfsize
cpl "File read OK. Size",packexesize

a:=getfileint(packexeptr,packexesize-int32.bytes)
if a<>'PCAK' then
	free(packexeptr)
	packfileptr:=nil
	return nil
fi

offset:=getfileint(packexeptr,packexesize-int32.bytes*2)

packfilename:=cast(packexeptr+offset)
offset+:=strlen(packfilename)+1
packfilesize:=getfileint(packexeptr,offset)
packfileptr:=packexeptr+offset+int32.bytes

return packfileptr
end

global function pcm_allocx:ref void =
const n=32
ref word p

allocbytes:=32

if p:=ref word(freelist[2]) then		!Items of this block size available
	freelist[2]:=ref wordp(int((freelist[2])^))

else

	p:=cast(pcheapptr)				!Create item at start of remaining pool in heap block
	pcheapptr+:=32			!Shrink remaining pool

	if pcheapptr>=pcheapend then		!Overflows?
		p:=pcm_newblock(32)		!Create new heap block, and allocate from start of that
	fi

	p^:=0
	(p+1)^:=0
	(p+2)^:=0
	(p+3)^:=0

	return p
fi
end

=== mclib.m 14/40 ===
global type filehandle=ref void

importlib $cstd=
	clang function malloc	(word64)ref void
	clang function realloc	(ref void, wordm)ref void
	clang proc     free		(ref void)
	clang proc     memset	(ref void, int32, wordm)
	clang proc     memcpy	(ref void, ref void, wordm)
	clang function clock	:int32
	clang function ftell	(filehandle)int32
	clang function fseek	(filehandle, int32, int32)int32
	clang function fread	(ref void, wordm, wordm, filehandle)wordm
	clang function fwrite	(ref void, wordm, wordm, filehandle)wordm
	clang function getc		(filehandle)int32
	clang function ungetc	(int32, filehandle)int32
	clang function fopen	(ichar,ichar="rb")filehandle
	clang function fclose	(filehandle)int32
	clang function fgets	(ichar, int, filehandle)ichar
	clang function remove	(ichar)int32
	clang function rename	(ichar, ichar)int32
	clang function getchar	:int32
	clang proc     putchar	(int32)
	clang proc     setbuf	(filehandle, ref byte)

	clang function strlen	(ichar)int
	clang function strcpy	(ichar, ichar)ichar
	clang function strcmp	(ichar, ichar)int32
	clang function strncmp	(ichar, ichar, wordm)int32
	clang function strncpy	(ichar, ichar, wordm)wordm
	clang function memcmp	(ref void, ref void, wordm)int32
	clang function strcat	(ichar, ichar)ichar
	clang function tolower	(int32)int32
	clang function toupper	(int32)int32
	clang function isalpha	(int32)int32
	clang function isupper	(int32)int32
	clang function islower	(int32)int32
	clang function isalnum	(int32)int32
	clang function isspace	(int32)int32
	clang function strstr	(ichar, ichar)ichar
	clang function atol		(ichar)intm
	clang function atoi		(ichar)int32
	clang function strtod	(ichar,ref ref char)real64

	clang function puts		(ichar)int32
	clang function puts99	(ichar)int32
	clang function printf	(ichar, ...)int32

	clang function sprintf	(ichar, ichar, ...)int32

	clang function sscanf	(ichar, ichar, ...)int32
	clang function scanf	(ichar, ...)int32

	clang function rand		:int32
	clang proc     srand	(word32)
	clang function system	(ichar)int32

	clang function fgetc	(filehandle)int32
	clang function fputc	(int32,  filehandle)int32
	clang function fprintf	(filehandle, ichar, ...)int32
	clang function fputs	(ichar,  filehandle)int32
	clang function feof		(filehandle)int32
	clang function getch	:int32
	clang function kbhit	:int32
	clang function _mkdir	(ichar)int32
	clang function mkdir	(ichar)int32
	clang function dummy	(real)real
	clang function strchr	(ichar,int32)ichar

	clang proc     _exit	(int32)
	clang proc     "exit"	(int32)
	clang function	pow		(real,real)real

	clang function	`sin	(real)real
	clang function	`cos	(real)real
	clang function	`tan	(real)real
	clang function	`asin	(real)real
	clang function	`acos	(real)real
	clang function	`atan	(real)real
	clang function	`log	(real)real
	clang function	`log10	(real)real
	clang function	`exp	(real)real
	clang function	`floor	(real)real
	clang function	`ceil	(real)real

	clang proc      qsort   (ref void, word64, word64, ref proc)

end

importlib $cstdextra=
	clang function __getmainargs(ref int32, ref void, ref void, int, ref void)int32
end

global const c_eof		=-1
global const seek_set	= 0
global const seek_curr	= 1
global const seek_end	= 2
=== mwindows.m 15/40 ===
import clib
import mlib

const wm_destroy=2

type wt_word	= word16
type wt_wordpm	= word32
type wt_bool	= word32
type wt_dword	= word32
type wt_wchar	= word16
type wt_wcharpm	= word32
type wt_char	= byte
type wt_ichar	= ref char
type wt_ptr		= ref void
type wt_wndproc	= ref proc
type wt_handle	= ref void
type wt_int		= int32
type wt_uint	= word32
type wt_long	= int32
type wt_wparam	= wordm
type wt_lparam	= wordm
type wt_point	= rpoint

global record rsystemtime =
	wt_word year
	wt_word month
	wt_word dayofweek
	wt_word day
	wt_word hour
	wt_word minute
	wt_word second
	wt_word milliseconds
end

importdll $windowsdlls=
	windows function "GetStdHandle"(wt_dword)wt_handle
	windows function "GetConsoleScreenBufferInfo"(wt_handle,wt_ptr)int
	windows function "SetConsoleCtrlHandler"(wt_wndproc,int)int
	windows function "SetConsoleMode"(wt_handle,wt_dword)int
	windows function "CreateProcessA"(wt_ichar,wt_ichar,wt_ptr,wt_ptr, int,
						wt_dword, wt_ptr,wt_ichar,wt_ptr,wt_ptr)int
	windows function "GetLastError":wt_dword
	windows function "WaitForSingleObject"(wt_handle,wt_dword)wt_dword
	windows function "GetExitCodeProcess"(wt_handle,wt_ptr)int
	windows function "CloseHandle"(wt_handle)int
	windows function "GetNumberOfConsoleInputEvents"(wt_handle,wt_ptr)int
	windows function "FlushConsoleInputBuffer"(wt_handle)int
	windows function "LoadLibraryA"(wt_ichar)wt_handle
	windows function "GetProcAddress"(wt_handle,wt_ichar)ref void
	windows function "LoadCursorA"(wt_handle,wt_ichar)wt_handle
	windows function "RegisterClassExA"(wt_ptr)wt_wordpm
	windows function "DefWindowProcA"(wt_handle,wt_uint,wt_wparam,wt_lparam)intm
	windows function "ReadConsoleInputA"(wt_handle,wt_ptr,wt_dword,wt_ptr)int
	windows proc     "Sleep"(wt_dword)
	windows function "GetModuleFileNameA"(wt_handle,wt_ichar,wt_dword)wt_dword

	windows proc     "ExitProcess"(wt_uint)
	windows proc	 "PostQuitMessage"(wt_int)


	windows proc	 "MessageBoxA"(wt_int x=0,wt_ichar message, caption="Caption",wt_int y=0)

	windows function "QueryPerformanceCounter"(ref int64)wt_bool
	windows function "QueryPerformanceFrequency"(ref int64)wt_bool

	windows function "CreateFileA"(wt_ichar,wt_dword,wt_dword,wt_ptr,wt_dword,wt_dword,wt_handle)wt_handle
	windows function "GetFileTime"(wt_handle,wt_ptr,wt_ptr,wt_ptr)wt_bool

	windows proc     "GetSystemTime"(ref rsystemtime)
	windows proc     "GetLocalTime"(ref rsystemtime)

	windows function "GetTickCount":wt_dword
	windows function "PeekMessageA"		(ref void, ref wt_handle, wt_uint,wt_uint,wt_uint)wt_bool

end

record input_record =
	wt_word	eventtype
	word16	padding
		wt_bool	keydown			!key event record (was inside 'Event' union in win32)
		wt_word	repeatcount
		wt_word	virtualkeycode
		wt_word	virtualscancode
		union
			wt_word unicodechar
			wt_char asciichar
		end
		wt_dword controlkeystate
end

record rspoint=(int16 x,y)

record rsrect=
	int16 leftx,top,rightx,bottom
end

global record rpoint =
	wt_long x,y
end

record rconsole=
	rspoint size,pos
	word16 attributes
	rsrect window
	rspoint maxwindowsize
end

record rstartupinfo =
	wt_dword	size
	word32 dummy1
	wt_ichar	reserved
	wt_ichar	desktop
	wt_ichar	title
	wt_dword	x
	wt_dword	y
	wt_dword	xsize
	wt_dword	ysize
	wt_dword	xcountchars
	wt_dword	ycountchars
	wt_dword	fillattribute
	wt_dword	flags
	wt_word		showwindow
	wt_word		reserved2
	word32 dummy2
	wt_ptr		reserved4
	wt_handle	stdinput
	wt_handle	stdoutput
	wt_handle	stderror
end

record rprocess_information =
	wt_handle process
	wt_handle thread
	wt_dword processid
	wt_dword threadid
end

record rwndclassex =
	wt_uint		size
	wt_uint		style
	wt_wndproc	wndproc
	wt_int		clsextra
	wt_int		wndextra
	wt_handle	instance
	wt_handle	icon
	wt_handle	cursor
	wt_handle	background
	wt_ichar	menuname
	wt_ichar	classname
	wt_handle	iconsm
end

global record rmsg =
	wt_handle	hwnd
	wt_uint		message
	word32		dummy1
	wt_wparam	wParam
	wt_lparam	lParam
	wt_dword	time
	word32		dummy2
	wt_point	pt
end

const NORMAL_PRIORITY_CLASS=32
const CREATE_NEW_CONSOLE=16
const DETACHED_PROCESS=16

wt_handle hconsole, hconsolein

input_record lastkey, pendkey
int keypending			!whether pendkey contains a new key event detected by flushkbd

ref function(ref void)int wndproc_callbackfn=nil	!windows call-back: address of handler

int init_flag=0

global proc os_init=
int i,count
rconsole info

hconsole:=GetStdHandle(u32(-11))
hconsolein:=GetStdHandle(u32(-10))

lastkey.repeatcount:=0
keypending:=0

SetConsoleCtrlHandler(nil,1)

SetConsoleMode(hconsole,1 ior 2)

init_flag:=1

end

global function os_execwait(ichar cmdline,int newconsole=0,ichar workdir=nil)int =
wt_dword exitcode
int status
int cflags:=0

rstartupinfo si
rprocess_information xpi

memset(&si,0,si.bytes)
memset(&xpi,0,xpi.bytes)

switch newconsole
when 0 then cflags := NORMAL_PRIORITY_CLASS
when 1 then cflags := NORMAL_PRIORITY_CLASS ior CREATE_NEW_CONSOLE
when 2 then cflags := NORMAL_PRIORITY_CLASS ior DETACHED_PROCESS
endswitch

si.size := rstartupinfo.bytes

status:=CreateProcessA(
	nil,
	cmdline,
	nil,

	nil,
	1,
	cflags,

	nil,
	nil,
	&si,
	&xpi )

if status=0 then		!fails
	status:=GetLastError()
	println "Winexec error:",status
	return -1
end

WaitForSingleObject(xpi.process, 0xFFFF'FFFF)
GetExitCodeProcess(xpi.process,&exitcode)

CloseHandle(xpi.process)
CloseHandle(xpi.thread)

return exitcode
end

global function os_execcmd(ichar cmdline, int newconsole=0)int =
wt_dword exitcode
int i,j,k

rstartupinfo si
rprocess_information xpi

memset(&si,0,si.bytes)
memset(&xpi,0,xpi.bytes)

si.size := rstartupinfo.bytes

CreateProcessA( nil,
	cmdline,
	nil,
	nil,
	1,
	NORMAL_PRIORITY_CLASS ior (newconsole|CREATE_NEW_CONSOLE|0),
	nil,
	nil,
	&si,
	&xpi )

CloseHandle(xpi.process)
CloseHandle(xpi.thread)

return 1
end

global function os_getch:int=
int k

k:=os_getchx() iand 255

return k
end

global function os_kbhit:int=
wt_dword count

unless init_flag then os_init() end

GetNumberOfConsoleInputEvents(hconsolein,&count)
return count>1
end

global proc os_flushkeys=
FlushConsoleInputBuffer(hconsolein)
end

global function os_getconsolein:ref void=
return ref void(hconsolein)
end

global function os_getconsoleout:ref void=
return ref void(hconsole)
end

global function os_proginstance:ref void=
abortprogram("PROGINST")
return nil
end

global function os_getdllinst(ichar name)u64=
wt_handle hinst

hinst:=LoadLibraryA(name)
return cast(hinst)
end

global function os_getdllprocaddr(int hinst,ichar name)ref void=

return GetProcAddress(cast(int(hinst)),name)
end

global proc os_initwindows=
os_init()
os_gxregisterclass("pcc001")
end

global proc os_gxregisterclass(ichar classname)=
const idcarrow=32512
rwndclassex r
static byte registered

if registered then
	return
fi


memset(&r,0,r.bytes)
r.size:=r.bytes
r.style:=8 ior 32		!CS_DBLCLKS | CS_OWNDC
r.wndproc:=cast(&mainwndproc)
r.instance:=nil

r.icon:=nil		!loadicon(proginstance,"SCW32")
r.cursor:=LoadCursorA(nil,ref void(idcarrow))		!IDC_ARROW)
r.background:=cast(15+1)					!COLOR_BTNFACE+1
r.menuname:=nil
r.classname:=classname
r.iconsm:=nil	!loadicon(proginstance,"SCW32")

if RegisterClassExA(&r)=0 then
	println classname,GetLastError
	abortprogram("Registerclass error")
end
registered:=1
end

global callback function mainwndproc (
		wt_handle hwnd, wt_uint message, wt_wparam wParam, wt_lparam lParam)intm=
rmsg m
int i,result
intm l
static int count=0


m.hwnd:=hwnd
m.message:=message
m.wParam:=wParam
m.lParam:=lParam
m.pt.x:=0
m.pt.y:=0

if (wndproc_callbackfn) then
	result:=(wndproc_callbackfn^)(&m)
else
	result:=0
fi

if m.message=wm_destroy then
	return 0
fi

if not result then
	return DefWindowProcA(hwnd,message,wParam,lParam)
else
	return 0
fi
end

proc timerproc(wt_handle hwnd, int msg, id, time)=
println "TIMERPROC"
end

global proc os_setmesshandler(ref void addr)=
wndproc_callbackfn:=addr
end

global function os_getchx:int=
const rightaltmask	= 1
const leftaltmask	= 2
const leftctrlmask	= 8
const rightctrlmask	= 4
const shiftmask		= 16
const capsmask		= 128
const scrollmask	= 64
int count
int charcode,keyshift,keycode
int altdown,ctrldown,shiftdown,capslock

unless init_flag then os_init() end

if keypending then
	lastkey:=pendkey
	keypending:=0
else
	if lastkey.repeatcount=0 then
		repeat
			count:=0
			ReadConsoleInputA(hconsolein,&lastkey,1,&count)
		until (lastkey.eventtype=1 and lastkey.keydown=1)
	fi
fi


altdown		:= ((lastkey.controlkeystate iand (leftaltmask ior rightaltmask))|1|0)
ctrldown	:= ((lastkey.controlkeystate iand (leftctrlmask ior rightctrlmask))|1|0)
shiftdown	:= ((lastkey.controlkeystate iand shiftmask)|1|0)
capslock	:= ((lastkey.controlkeystate iand capsmask)|1|0)

--lastkey.repeatcount		!count this key out

charcode:=lastkey.asciichar
keycode:=lastkey.virtualkeycode iand 255

if charcode<0 then
	if charcode<-128 then
		charcode:=0
	else
		charcode+:=256
	fi
fi


if altdown and ctrldown and charcode=166 then
	altdown:=ctrldown:=0
else
	if altdown or ctrldown then
		charcode:=0
		if keycode>='A' and keycode<= 'Z' then
			charcode:=keycode-'@'
		fi
	fi
fi

keyshift:=capslock<<3 ior altdown<<2 ior ctrldown<<1 ior shiftdown

return keyshift<<24 ior keycode<<16 ior charcode
end

global function os_getos=>ichar=
if $targetbits=32 then
	return "W32"
else
	return "W64"
fi
end

global function os_gethostsize=>int=
return $targetbits
end

global function os_shellexec(ichar opc, file)int=
return system(file)
end

global proc  os_sleep(int a)=
Sleep(a)
end

global function os_getstdin:filehandle =
return fopen("con","rb")
end

global function os_getstdout:filehandle =
return fopen("con","wb")
end

global function os_gethostname:ichar=
static [300]char name
static int n

GetModuleFileNameA(nil,&.name,name.bytes)
strcat(&.name,"/")
return &.name
end

global function os_getmpath:ichar=
return F"C:\m\"
end

global proc os_exitprocess(int x)=
stop x
end

global function os_clock:int64=
return clock()
end

global function os_getclockspersec:int64=
return 1000
end

global function os_iswindows:int=
return 1
end

global function os_filelastwritetime(ichar filename)int64=
wt_handle f;
int64 ctime,atime,wtime;

if filename=nil then				!used to test whether supported
	return 1
fi

f:=CreateFileA(filename,0x80000000,1,nil, 3,3,nil);
if int64(f)=-1 then
	return 0
fi

GetFileTime(f,&ctime,&atime,&wtime);
CloseHandle(f);

return wtime;
end

global proc os_getsystime(ref rsystemtime tm)=
GetLocalTime(tm)
end

global proc os_messagebox(ichar s,t)=
messageboxa(0,s,t,0)
end

global function os_hpcounter:int64=
int64 a

queryperformancecounter(&a)
return a

end

global function os_hpfrequency:int64=
int64 a

queryperformancefrequency(&a)
return a

end

global proc os_peek=
int ticks
static int lastticks
[100]byte m
	ticks:=GetTickCount()
	if ticks-lastticks>=1000 then
		lastticks:=ticks
		PeekMessageA(&m,nil,0,0,0)
	fi
end
=== mwindll.m 16/40 ===
import clib
import mlib


global function os_calldllfunction(ref proc fnaddr,
		int retcode, nargs, ref[]i64 args, ref[]byte argcodes)word64 =
	word64 a
	real64 x
	int oddstack, nextra, pushedbytes


	oddstack:=nextra:=0

	assem
		test astack,8
		jz L100
		mov byte [oddstack],1
L100:
	end

	if oddstack then
		if nargs<5 then
			nextra:=5-nargs
		elsif nargs.even then
			nextra:=1
		fi

	else
		if nargs<4 then
			nextra:=4-nargs
		elsif nargs.odd then
			nextra:=1
		fi
	fi

	pushedbytes:=(nextra+nargs)*8


	to nextra do
		assem
			push 0
		end
	od

	for i:=nargs downto 1 do
		a:=args^[i]					!get generic 64-bit value to push
		assem
			push word64 [a]
		end
	od


	assem
		mov D10,[Dstack]
		movq XMM0,[Dstack]
		mov D11,[Dstack+8]
		movq XMM1,[Dstack+8]
		mov D12,[Dstack+16]
		movq XMM2,[Dstack+16]
		mov D13,[Dstack+24]
		movq XMM3,[Dstack+24]
	end

	if retcode='I' then
		a:=((ref function:int64(fnaddr))^())
		asm add Dstack,[pushedbytes]
		return a
	else
		x:=((ref function:real64(fnaddr))^())
		asm add Dstack,[pushedbytes]
		return word64@(x)
	fi
end	

global function os_pushargs(ref[]word64 args, int nargs, nextra,
					ref proc fnaddr, int isfloat)word64=
	word64 a
	real64 x

CPL "PUSH ARGS",NARGS, NEXTRA

	to nextra do
		asm	push 0
	end

CPL "PUSH ARGS2"
	for i to nargs do
		a:=args[i]
		asm push word64 [a]
	od
CPL "PUSH ARGS3"

	if isfloat then
		x:=((ref function:real64(fnaddr))^())
		a:=int64@(x)
	else
		a:=((ref function:int64(fnaddr))^())
	fi

	return a
end
=== bb_lex.m 17/40 ===
import msys
import mlib
import clib

import bb_decls
import bb_tables
import bb_support
import bb_lib
import bb_pclcommon


macro hashc(hsum,c)=hsum<<4-hsum+c

macro hashw(hsum)=(hsum<<5-hsum)

const maxstackdepth=20
[maxstackdepth]ref char lxstart_stack
[maxstackdepth]ref char lxsptr_stack
[maxstackdepth]int lxfileno_stack
[maxstackdepth]int lxlineno_stack
[maxstackdepth]byte isfile_stack
int sourcelevel=0

const cr	= 13
const lf	= 10
const tab	= 9


ref char lxstart
ref char lxsptr
int lxifcond
int longsuffix			!for real nos

int lxfileno


global const hstsize	= 32768
global const hstmask	= hstsize-1

global [0:hstsize]strec hashtable
global [0:hstsize]word hashkeys

const inittokensize = 65536

ref[]tokenrec tokenlist
int tokenlistsize
global ref tokenrec nexttoken

byte prescanmode=0

[]ichar maxnumlist=(
	"",					!1
	"1111111111111111111111111111111111111111111111111111111111111111",   	!2
	"11112220022122120101211020120210210211220",                          	!3
	"33333333333333333333333333333333",                                   	!4
	"2214220303114400424121122430",                                       	!5
	"3520522010102100444244423",                                          	!6
	"45012021522523134134601",                                            	!7
	"1777777777777777777777",                                             	!8
	"145808576354216723756",                                              	!9
	"18446744073709551615",                                               	!10
	"335500516A429071284",                                                	!11
	"839365134A2A240713",                                                 	!12
	"219505A9511A867B72",                                                 	!13
	"8681049ADB03DB171",                                                  	!14
	"2C1D56B648C6CD110",                                                  	!15
	"FFFFFFFFFFFFFFFF")                                                   	!16
[maxnumlist.len]int maxnumlen

global proc lex=
	lx:=nexttoken^
	++nexttoken
end


global function nextlx:ref tokenrec=
	return nexttoken
end

global proc lexreadtoken=
int c,hsum,commentseen,hashindex,length
ref char pstart,pnext,p,ss,lxsvalue

lx.subcode:=0

doswitch lxsptr++^
when 'a'..'z','$','_' then
	lxsvalue:=lxsptr-1
doname::
	hsum:=lxsvalue^

	doswitch c:=lxsptr++^
	when 'a'..'z','0'..'9','_','$' then
		hsum:=hashc(hsum,c)
	when 'A'..'Z' then
		(lxsptr-1)^:=c+' '
		hsum:=hashc(hsum,c+' ')
	when '"' then
		--lxsptr
		if lxsvalue+1=ref char(lxsptr) then
			case lxsvalue^
			when  'F','f','R','r' then 
				readrawstring()
				return
			when  'A','a','Z','z' then 
				readarraystring(lxsvalue^)
				return
			esac
		fi
		exit
	else
		--lxsptr
		exit
	end doswitch

	do_name(lxsvalue, lxsptr-lxsvalue, hashw(hsum))
	return

when 'A'..'Z' then
	lxsvalue:=lxsptr-1
	lxsvalue^+:=32
	goto doname

when '0'..'9' then
	c:=(lxsptr-1)^
	case lxsptr^
	when ' ',')',cr,',','|' then		!assume single digit decimal
		lx.symbol:=intconstsym
		lx.subcode:=tint
		lx.value:=c-'0'
	when 'x','X' then
		case c
		when '0' then		!0x
			++lxsptr
			readnumber(16)
		when '1' then
			lxerror("Bad base")
		else				!other base 2..9
			++lxsptr
			readnumber(c-'0')
		esac

	else
		--lxsptr
		readdecimalnumber()
	esac
	return

when '!' then			!comment to eol
docomment::
	doswitch c:=lxsptr++^
	when 13 then
		++lxsptr
		exit
	when 10 then
		exit
	when 0 then
		--lxsptr
		exit
	end
	++lx.pos
	lx.symbol:=eolsym
	return

when '#' then			!docstring to eol
	lxsvalue:=cast(lxsptr)

	doswitch c:=lxsptr++^
	when 13,10,0 then			!leave eol for next symbol
		--lxsptr
		exit
	end

	length:=lxsptr-cast(lxsvalue,ref char)
	lx.symbol:=docstringsym
	lx.svalue:=pcm_copyheapstringn(lxsvalue,length)
	return

when '\\' then			!line continuation

	commentseen:=0
	doswitch lxsptr++^			!read until end of this line
	when cr then
		++lx.pos
		++lxsptr				!skip lf
		exit
	when lf then
		++lx.pos
		exit
	when 0 then
		lx.symbol:=eofsym
		--lxsptr
		return
	when ' ',tab then
	when '!' then
		commentseen:=1
	else
		if not commentseen then
			lxerror("\\ not followed by eol")
		fi
enddoswitch

	doswitch lxsptr++^
	when cr then
		++lx.pos
		++lxsptr				!skip lf
	when lf then
		++lx.pos
	when ' ',tab then
	else
		--lxsptr
		exit
	enddoswitch

when '{' then
	lx.symbol:=lcurlysym
	return

when '}' then
	lx.symbol:=rcurlysym
	return

when '.' then
	switch lxsptr^
	when '.' then				!.. or ...
		++lxsptr
		if lxsptr^='.' then
			++lxsptr
			lx.symbol:=ellipsissym
		else
			lx.symbol:=rangesym
			lx.subcode:=j_makerange		!helps treat as opsym which all have k-code as subcode
		fi
		return
	when '0'..'9' then			!real const: deal with this after the switch
		--lxsptr
		readrealnumber(nil,0,10)
		return
	else
			lx.symbol:=dotsym
		return
	endswitch

when ',' then
	lx.symbol:=commasym
	return

when ';' then
	lx.symbol:=semisym
	return

when ':' then
	switch lxsptr^
	when '=' then
		++lxsptr
		lx.symbol:=assignsym
		lx.subcode:=j_assign		!helps treat as opsym which all have k-code as subcode
	when ':' then
		++lxsptr
		case lxsptr^
		when '=' then
			++lxsptr
			lx.symbol:=deepcopysym
			lx.subcode:=j_deepcopy
		else
			lx.symbol:=dcolonsym
		esac
	else
		lx.symbol:=colonsym
	endswitch
	return

when '(' then
	lx.symbol:=lbracksym
	return

when ')' then
	lx.symbol:=rbracksym
	return

when '[' then
	lx.symbol:=lsqsym
	return

when ']' then
	lx.symbol:=rsqsym
	return

when '|' then

	if lxsptr^='|' then
		++lxsptr
		lx.symbol:=dbarsym
	else
		lx.symbol:=barsym
	fi
	return

when '^' then
	lx.symbol:=ptrsym
	return

when '@' then
	if lxsptr^='@' then
		++lxsptr
		lx.symbol:=datsym
	else
		lx.symbol:=atsym
	fi
	return

when '?' then
	lx.symbol:=questionsym
	return

when '~' then
	lx.symbol:=curlsym
	return

when '+' then
	lx.symbol:=addsym
	if lxsptr^='+' then
		++lxsptr
		lx.symbol:=incrsym
		lx.subcode:=incr_op
		return
	fi
	return

when '-' then
	lx.symbol:=subsym
	if lxsptr^='-' then
		++lxsptr
		lx.symbol:=incrsym
		lx.subcode:=decr_op
		return
	fi
	return

when '*' then
	if lxsptr^='*' then
		++lxsptr
		lx.symbol:=powersym
	else
		lx.symbol:=mulsym
	fi
	return

when '/' then
	lx.symbol:=divsym
	return

when '%' then
	lx.symbol:=idivsym
	return

when '=' then
	case lxsptr^
	when '>' then
		lx.symbol:=sendtosym
		++lxsptr
	when '=' then
		lx.symbol:=samesym
		++lxsptr
	else
		lx.symbol:=eqsym
		lx.subcode:=eq_op
	esac
	return

when '<' then
	lx.symbol:=cmpsym
	switch lxsptr^
	when '=' then
		++lxsptr
		lx.subcode:=le_op
	when '>' then
		++lxsptr
		lx.subcode:=ne_op
	when '<' then
		++lxsptr
		lx.symbol:=shlsym
	else
		lx.subcode:=lt_op
	endswitch
	return

when '>' then
	lx.symbol:=cmpsym
	switch lxsptr^
	when '=' then
		++lxsptr
		lx.symbol:=cmpsym
		lx.subcode:=ge_op
	when '>' then
		++lxsptr
		lx.symbol:=shrsym
	else
		lx.symbol:=cmpsym
		lx.subcode:=gt_op
	endswitch
	return

when '&' then
	case lxsptr^
	when '.' then
		++lxsptr
		lx.symbol:=anddotsym
		lx.subcode:=0
	else
		lx.symbol:=addrsym
		lx.subcode:=j_addrof
	esac
	return

when '\'' then
	lxreadstring('\'')
	return

when '"' then
	lxreadstring('"')
	return

when '`' then
	readrawxname()
	return

when ' ',tab then

when cr then
	++lxsptr				!skip lf
	++lx.pos
	lx.symbol:=eolsym
	return
when lf then			!only lfs not preceded by cr
	++lx.pos
	lx.symbol:=eolsym
	return

when 0 then
	if sourcelevel then
		unstacksource()
	else
		lx.symbol:=eofsym
		--lxsptr
		return
	fi

else
	lx.symbol:=errorsym
	return

end doswitch

end

proc readnumber(int base)=
ref char pstart,dest
int c
ref char p

dest:=pstart:=lxsptr

if base=10 then
	doswitch c:=lxsptr++^
	when '0'..'9' then
		dest++^:=c
	when '_','\'','`' then
	else
		--lxsptr
		exit
	end doswitch
else
	dest:=scannumber(base)
	c:=lxsptr^
fi

switch c			!terminator character
when '.' then		!possible real number
	if (lxsptr+1)^<>'.' then

		readrealnumber(pstart,dest-pstart,base)
		return
	fi
when 'e','E' then
	if base<15 then
		readrealnumber(pstart,dest-pstart,base)
		return
	fi
when 'p','P' then
	if base>=15 then
		readrealnumber(pstart,dest-pstart,base)
		return
	fi
end switch

stringtonumber(pstart,dest-pstart,base)
end

proc readdecimalnumber=
ref char pstart,dest
int c,n,base,suffix
ref char p

dest:=pstart:=lxsptr
suffix:=0

doswitch c:=lxsptr++^
when '0'..'9' then
	dest++^:=c
when '_','\'','`' then
else
	--lxsptr
	exit
end doswitch

switch c			!terminator character
when '.' then		!possible real number
	if (lxsptr+1)^<>'.' then

		readrealnumber(pstart,dest-pstart,10)
		return
	fi
when 'e','E' then
	readrealnumber(pstart,dest-pstart,10)
	return
when 'b','B' then
	++lxsptr
	n:=dest-pstart
	p:=pstart
	to n do
		if p^<'0' or p^>'1' then
			lxerror("1101B: bad digit")
		fi
		++p
	od
	stringtonumber(pstart,n,2)
	return

end switch

stringtodecimalnumber(pstart,dest-pstart,suffix)
end

proc readrealnumber(ichar intstart, int intlen, base)=
ref char fractstart,ss
int fractlen,expon,i,c,n
real basex,x
const maxrealdigits=500
[maxrealdigits]char realstr
[32]char str

fractstart:=nil
fractlen:=0
expon:=0
longsuffix:=0

if lxsptr^='.' then		!read
	fractstart:=++lxsptr
	fractlen:=scannumber(base)-fractstart
fi

case lxsptr^
when 'e','E' then
	if base<15 then
		++lxsptr
		expon:=readexponent(base)
	fi
when 'p','P' then
	if base>=15 then
		++lxsptr
		expon:=readexponent(base)
	fi
when 'l','L' then
	if longsuffix then lxerror("LL?") fi
	longsuffix:='L'
	++lxsptr

esac

if longsuffix='L' then
	ss:=pcm_alloc(intlen+fractlen+16)		!add ".", "e", exponent, 0 terminator
	memcpy(ss,intstart,intlen)
	memcpy(ss+intlen,".",1)
	memcpy(ss+intlen+1,fractstart,fractlen)
	memcpy(ss+intlen+fractlen+1,"e",1)
	getstrint(expon,&.str)
	memcpy(ss+intlen+fractlen+2,&.str,strlen(&.str)+1)

	lx.symbol:=decimalconstsym
	lx.svalue:=ss
	return
fi

if intlen+fractlen>maxrealdigits then
	lxerror("Real too long")
fi
if intlen then
	memcpy(&realstr,intstart,intlen)
fi
if fractlen then
	memcpy(&realstr[1]+intlen,fractstart,fractlen)
fi

if base=10 then
	x:=readrealbest(intlen,fractlen,expon,&.realstr)
else
	basex:=base
	expon-:=fractlen
	x:=0.0
	for i:=1 to intlen+fractlen do		!digits already range-checked
		c:=realstr[i]
		if c>='0' and c<='9' then
			x:=x*basex+c-'0'
		elsif c>'a' then
			x:=x*basex+c-'a'+10
		else
			x:=x*basex+c-'A'+10
		fi
	od

	if expon>=0 then
		to expon do
			x*:=basex
		od
	else
		to -expon do
			x/:=basex
		od
	fi
fi

lx.symbol:=realconstsym
lx.subcode:=treal
lx.xvalue:=x
end

function readrealbest(int intlen,fractlen,expon, ichar realstr)real=
	[32]char expstr

	(realstr+intlen+fractlen)^:=0
	expon-:=fractlen

	print @&.expstr,"e",,expon
	strcat(realstr,&.expstr)
	return strtod(realstr,nil)
end

function readexponent(int base)int=
ref char numstart,numend
int expon,length,neg

neg:=0
case lxsptr^
when '+' then ++lxsptr
when '-' then ++lxsptr; neg:=1
esac

numstart:=lxsptr
length:=scannumber(base)-numstart

if length=0 then
	lxerror("Bad expon")
fi

stringtonumber(numstart, length, base)
return (neg|-lx.value|lx.value)
end

global proc printsymbol(ref tokenrec lp)=
tokenrec l
l:=lp^

printf("%-18s",symbolnames[l.symbol])

case l.symbol
when namesym then
	printstrn(l.symptr^.name,l.symptr^.namelen)

	if l.subcode then
		fprint " [#]",symbolnames[l.subcode]
	fi

when intconstsym then
	case l.subcode
	when tint then print l.value,"int"
	when tword then print l.uvalue,"word"
	else print l.value
	esac

when realconstsym then
	print l.xvalue

when stringconstsym then
	print """"
	printstr(l.svalue)
	print """",strlen(l.svalue)
when charconstsym then
	print "'"
	printstr(l.svalue)
	print "'"
when decimalconstsym then
	printstr(l.svalue)
	print "L"
when assignsym,addrsym,ptrsym,deepcopysym,rangesym,
	andlsym,orlsym,eqsym,cmpsym,addsym,subsym,
	mulsym,divsym,idivsym,iremsym,iandsym,iorsym,ixorsym,shlsym,shrsym,
	minsym,maxsym,concatsym,powersym,samesym then
	print symbolnames[l.symbol]
elsif l.subcode then
	fprint "SUBCODE:",l.subcode
end

println

end

proc stringtonumber(ichar s, int length, base)=
int64 a
word64 b
int c

while length>=2 and s^='0' do		!trim leading zeros
	++s
	--length
od

lx.symbol:=intconstsym

if length>maxnumlen[base] or 
		(length=maxnumlen[base] and strncmp(s,maxnumlist[base],length)>0) then
	if base<>16 then
		lxerror("longint const")

	else
		if length>32 or 
			(length=32 and strncmp(s,"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",32)>0) then
			lxerror("longint const")

		else						!greater than 64 bits, up to 128 bits

			if length=32 and strncmp(s,"7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",32)>0 then
				lx.subcode:=tu128
			else
				lx.subcode:=ti128
			fi

			lx.pvalue128:=stringtonumber128(s,length,16)
		fi
	fi
	return
fi

a:=0

if base<=10 then
	to length do
		a:=a*base+s++^-'0'
	od
else
	to length do
		c:=s++^
		if c>='a' then
			a:=a*base+c-'a'+10
		elsif c>='A' then
			a:=a*base+c-'A'+10
		else
			a:=a*base+c-'0'
		fi
	od
fi

lx.value:=a

lx.subcode:=setinttype(a)
end

proc stringtodecimalnumber(ichar s, int length,suffix=0)=
int64 a
word64 b
int c

while length>=2 and s^='0' do		!trim leading zeros
	++s
	--length
od

lx.symbol:=intconstsym

if length>20 or 
		(length=20 and strncmp(s,"18446744073709551615",20)>0) or suffix then

	if length>39 or 
		(length=39 and strncmp(s,"340282366920938463463374607431768211455",39)>0) then
		if suffix='W' then
			lxerror("-W overflows 128 bits")
		fi
dolongint::
		lx.symbol:=decimalconstsym
		lx.svalue:=pcm_copyheapstring(s)
	else						!greater than 64 bits, up to 128 bits

		if suffix='L' then goto dolongint fi

		if (length=39 and strncmp(s,"170141183460469231731687303715884105727",39)>0) then
			lx.subcode:=tu128
		else
			lx.subcode:=ti128
		fi

		lx.pvalue128:=stringtonumber128(s,length,10)
	fi
	return
fi

a:=0

to length do
	a:=a*10+s++^-'0'
od

lx.value:=a

lx.subcode:=setinttype(a)
end

global proc lexsetup=
int i!,n
static int n

for i to maxnumlist.len do
	maxnumlen[i]:=strlen(maxnumlist[i])
od


inithashtable()
end

proc newtokenlist=
	tokenlist:=pcm_alloc(tokenrec.bytes*inittokensize)
	tokenlistsize:=inittokensize
end

global proc printstrn(ichar s, int length)=
if length then
	print length:"v",s:".*"
fi
end

function scannumber(int base)ref char=
ref char dest
int c

dest:=lxsptr

doswitch c:=lxsptr++^
when '0'..'9' then
	dest++^:=c
	if c>='0'+base then
		lxerror("Digit out of range")
	fi
when 'A'..'D','F','a'..'d','f' then
	if 11<=base<=16 then		!NEEDS TO CHECK LIMITS FOR BASES 10..15
		dest++^:=c
	else
		--lxsptr
		exit
	fi
when 'E','e' then
	if base<15 then
		--lxsptr
		exit
	else
		dest++^:=c
	fi

when '_','\'','`' then
when 'l','L' then
	longsuffix:='L'
	exit

else
	--lxsptr
	exit
end doswitch
return dest
end

proc readrawstring=
ichar dest
int c

lx.symbol:=stringconstsym
lx.svalue:=++lxsptr

dest:=lxsptr				!form string into same buffer

doswitch c:=lxsptr++^
when '"' then
	if lxsptr^='"' then		!repeated, assume embedded term char
		dest++^:='"'
		++lxsptr
	else			!was end of string
		(lxsptr-1)^:=0
		exit
	fi
when cr,lf,0 then
	lxerror("Raw string not terminated")
	--lxsptr
	exit
else
	dest++^:=c
enddoswitch
end

proc lookup(ref char name, int length, hashindex0)=
	int wrapped, hashindex,INDEX

	hashindex:=hashindex0 iand hstmask

	lx.symptr:=&hashtable[hashindex]
	wrapped:=0

	do
		case lx.symptr^.namelen
		when 0 then
			exit
		when length then
			if memcmp(lx.symptr.name,name,length)=0 then	!match
				lx.symbol:=lx.symptr.symbol
				lx.subcode:=lx.symptr.subcode
				return
			fi
		esac

		++lx.symptr
		if ++hashindex>=hstsize then
			if wrapped then
				abortprogram("HASHTABLE FULL")
			fi
			wrapped:=1
			lx.symptr:=&hashtable[0]
			hashindex:=0
		fi
	od

	lx.symptr.name:=pcm_copyheapstringn(name,length)
	lx.symptr.namelen:=length
	lx.symptr.symbol:=namesym
	lx.symbol:=namesym
end

function lookupsys(ref char name)int=
int j, wrapped, hashvalue

j:=gethashvaluez(name) iand hstmask

lx.symptr:=&hashtable[j]
wrapped:=0

do
	if lx.symptr^.namelen=0 then
		exit
	elsif eqstring(lx.symptr^.name,name) then	!match
		cpl name
		lxerror("sys dupl name?")
	fi

	++lx.symptr
	if ++j>=hstsize then
		if wrapped then
			abortprogram("SYS:HASHTABLE FULL")
		fi
		wrapped:=1
		lx.symptr:=&hashtable[0]
		j:=0
	fi
od


lx.symptr^.name:=name				!assume can be shared (stored in a table)
lx.symptr^.namelen:=strlen(name)
lx.symptr^.symbol:=namesym			!usually replaced with actual symbol details

return 0
end

function gethashvaluez(ichar s)int=
int c,hsum

if s^=0 then return 0 fi

hsum:=s++^

do
	c:=s++^
	exit when c=0
	hsum:=hashc(hsum,c)
od
return hashw(hsum)
end

proc inithashtable=
int i
memset(&hashtable,0,hashtable.bytes)

for i:=1 to stnames.len do
	lookupsys(stnames[i])

	lx.symptr.symbol:=stsymbols[i]

	case stsymbols[i]
	when unitnamesym then
		lx.symptr.index:=stsubcodes[i]
		lx.symptr.subcode:=unitnamesym
		lx.symptr.symbol:=namesym		!masquerades as normal identifier
	else
		lx.symptr.subcode:=stsubcodes[i]
	esac
od
end

GLOBAL proc printhashtable=
	println "Hashtable:"

	for i:=0 to hstsize-1 do
		if hashtable[i].namelen then
			println i,hashtable[i].name,symbolnames[hashtable[i].symbol]
		fi
	od
end

global proc addreservedword(ichar name,int symbol,subcode, regsize=0)=

	lookupsys(name)

	lx.symptr.symbol:=namesym
	lx.symptr.subcode:=symbol
	lx.symptr.index:=subcode
	lx.symptr.regsize:=regsize
end

function dolexdirective(int index)int=
ref strec symptr
ref char p
ichar file
int i,lastsymbol,cond,fileno,length
[256]char str

case index
when strincludedir,binincludedir then
	lexreadtoken()
	if lx.symbol<>stringconstsym then
			lxerror("strincl: string expected")
	else
		file:=lx.svalue
	fi

	fileno:=getsupportfile(file)
	lx.svalue:=sourcefiletext[fileno]
	length:=sourcefilesizes[fileno]

	lx.symbol:=(index=strincludedir|stringconstsym|astringconstsym)
	lx.subcode:='A'			!for use when an astring
	(lx.svalue+length)^:=0			!sometimes .length is not used (eg. in newstringobj())
	return 1						!so get it right. Don't need the etx

when includedir then
	lexreadtoken()
	if lx.symbol<>stringconstsym then lxerror("include: string expected") fi
	file:=lx.svalue
	convlcstring(file)
	file:=addext(file,".m")		!add in extension if not present; assume same as source

	stacksourcefile(file)
	return 0

when defineunitdir then
	LXERROR("DEFINE UNIT NOT DONE")

when emitcdir then
	lexreadtoken()
	if lx.symbol<>stringconstsym then lxerror("emitc/not str") fi
	lx.symbol:=kemitcsym
	return 1

when cclibdir then
	do
		lexreadtoken()
		case lx.symbol
		when stringconstsym then
CPL "ADD/S",LX.SVALUE
			addcclib(lx.svalue)
		when namesym then
CPL "ADD/N",LX.SYMPTR.NAME
			addcclib(lx.symptr.name)
		else
			lxerror("cclib/not str/name")
		esac

		lexreadtoken()
		if lx.symbol<>commasym then exit fi
	od
	return 0


else
	cpl sourcedirnames[index]
	lxerror("Directive not implemented")
esac
return 0
END

proc lexreadline=

doswitch lxsptr^
when cr,lf then
	return
when 0 then
	--lxsptr
	return
else
	++lxsptr
enddoswitch
END

global proc startlex(ichar caption,int fileno)=

lxsptr:=sourcefiletext[fileno]


lxfileno:=fileno
lx.pos:=1

lx.symbol:=semisym
lx.subcode:=0
end

global function convertzstring(ichar s, int length)ichar=
static [300]char str

if length>str.len then
	abortprogram("convertzstr")
fi
memcpy(&.str,s,length)
str[length+1]:=0
return &.str
end

global function addnamestr(ichar name)ref strec=
	tokenrec oldlx
	ref strec symptr

	oldlx:=lx
	lookup(name,strlen(name), gethashvaluez(name))
	symptr:=lx.symptr
	lx:=oldlx

	return symptr
end

global function findname(ichar name)ref strec=

	lookup(name,strlen(name),gethashvaluez(name))
	return lx.symptr
end

global proc ps(ichar caption)=
print caption,,": "
printsymbol(&lx)
end

global proc showhashtablesize=
int i,n

n:=0
for i:=0 to hstmask do
	if hashtable[i].name then
		++n
	fi
od
end

function getstrfile(ichar filename,int32 &length)ichar=
	

ichar file
static [300]char filespec
int i

for i:=nsearchdirs downto 1 do
	strcpy(&.filespec,searchdirs[i])
	strcat(&.filespec,filename)

	if checkfile(&.filespec) then
		file:=cast(readfile(&.filespec))
		length:=rfsize
		return file
	fi
od

return nil
end

proc stacksourcefile(ichar file,int ismainmodule=0)=
int fileno
ichar basefile,sptr,path

fileno:=getsupportfile(file)

stacksource(sourcefiletext[fileno],fileno,1)
end

proc stacksource(ichar sptr,int fileno,isfile)=

if sourcelevel>=maxstackdepth then
	lxerror("Include file/macro overflow")
fi
++sourcelevel
lxstart_stack[sourcelevel]:=lxstart
lxsptr_stack[sourcelevel]:=lxsptr
lxfileno_stack[sourcelevel]:=lxfileno
lxlineno_stack[sourcelevel]:=lx.pos
isfile_stack[sourcelevel]:=isfile

lxstart:=lxsptr:=sptr
lx.pos:=1
lxfileno:=fileno
end

proc unstacksource=
if sourcelevel>0 then			!check that some source is stacked
	lxstart:=lxstart_stack[sourcelevel]
	lxsptr:=lxsptr_stack[sourcelevel]
	lx.pos:=lxlineno_stack[sourcelevel]
	lxfileno:=lxfileno_stack[sourcelevel]
	--sourcelevel
fi
end

proc readarraystring(int prefix)=
++lxsptr
lxreadstring('"')
lx.symbol:=astringconstsym
lx.subcode:=toupper(prefix)
end


function stringtonumber128(ichar s, int length,base)ref int128=
ref int128 aa
int c,d

aa:=pcm_allocz(int128.bytes)

to length do
	aa^:=aa^*base

		c:=s++^

		if c>='a' then
			d:=c-'a'+10
		elsif c>='A' then
			d:=c-'A'+10
		else
			d:=c-'0'
		fi

	aa^:=aa^+d
od

return aa
end

function setinttype(word64 a)int=
	if a<=u64(0x7FFF'FFFF'FFFF'FFFF) then
		return ti64
	else
		return tu64
	fi
end

proc readrawxname=
	int c,hsum,length

	lx.svalue:=lxsptr
	hsum:=0

	doswitch c:=lxsptr++^
	when 'A'..'Z','a'..'z','0'..'9','_','$' then
		hsum:=hashc(hsum,c)
	else
		--lxsptr
		exit
	end doswitch

	length:=lxsptr-lx.svalue

	if length=0 then
		lxerror("Bad ` name")
	fi
	lookup(lx.svalue,length, hashw(hsum))
	lx.symbol:=rawxnamesym

	return
end


proc lxerror_s(ichar mess,s)=
	lxerror(mess)
end

proc lxreadstring(int termchar)=

	ichar s,t
	int c, d, length, hasescape
	[8]char str

	if termchar='"' then
		lx.symbol:=stringconstsym
	else
		lx.symbol:=charconstsym
		lx.subcode:=tint
	fi

	s:=lxsptr

	length:=0
	hasescape:=0

	doswitch c:=lxsptr++^
	when '\\' then			!escape char
		c:=lxsptr^
		if c in 'A'..'Z' then c+:=' ' fi
		++lxsptr
		hasescape:=1

		switch c
		when 'a','b','c','r','f','l','n','s','t','v','y','z','0','"','q','\\','\'' then
			++length
		when 'w' then
			++length
		when 'x' then	!2-digit hex code follows
			lxsptr+:=2
			++length
		else
			lxerror("Bad str escape")
		endswitch
	when '"','\'' then		!possible terminators
		if c=termchar then		!terminator char
			if lxsptr^=c then		!repeated, assume embedded term char
				hasescape:=1
				++lxsptr
				++length
			else			!was end of string
				exit
			fi
		else
			++length
		fi
	when cr,lf,0 then
		lxerror("String not terminated")
	else
		++length
	end doswitch

	if length=0 then
		lx.svalue:=""
		return
	elsif not hasescape then
		lx.svalue:=pcm_copyheapstringn(s,length)
		return
	fi


	lx.svalue:=t:=pcm_alloc(length+1)

	do
		switch c:=s++^
		when '\\' then			!escape char
			c:=s^
			if c>='A'  and c<='Z' then c+:=' ' fi
			++s
			switch c
			when 'a' then			!bell ('alert')
				c:=7
			when 'b' then			!backspace
				c:=8
			when 'c','r' then		!carriage return
					c:=cr
			when 'e' then			!end-of-text
				c:=26
			when 'f' then			!formfeed
				c:=12
			when 'l','n' then		!linefeed, or linux/c-style newline
				c:=lf
			when 's' then			!eScape
				c:=27
			when 't' then			!tab
				c:=9
			when 'v' then			!vertical tab
				c:=11
			when 'w' then			!windows-style cr-lf
				t++^:=cr
				c:=lf
			when 'x' then	!2-digit hex code follows
				c:=0
				to 2 do
					case d:=s++^
					when 'A','B','C','D','E','F' then
						c:=c*16+d-'A'+10
					when 'a','b','c','d','e','f' then
						c:=c*16+d-'a'+10
					when '0','1','2','3','4','5','6','7','8','9' then
						c:=c*16+d-'0'
					else
						lxerror("Bad \\x code")
					esac
				od
			when 'y' then			!CCI/SM backwards tab
				c:=16
			when 'z','0' then		!null (not fully supported in code)
				c:=0
			when '"','Q' then		!embedded double quote
				c:='"'
			when '\\' then
				c:='\\'
			when '\'' then			!embedded single quote
				c:='\''
			else
				str[1]:=c; str[2]:=0
				lxerror_s("Unknown string escape: \\%s",&.str)
			end
		when '"','\'' then		!possible terminators
			if c=termchar then		!terminator char
				if s^=c then		!repeated, assume embedded term char
					++s
				else			!was end of string
					exit
				fi
			fi
		when cr,lf,0 then
			lxerror("String not terminated")
		endswitch

		t++^:=c
	od

	t^:=0
end

proc do_name(ichar s, int length, hashindex)=




	lookup(s,length, hashindex)
end

proc extendtokenlist(int ntokens)=
	ref[]tokenrec oldtokenlist
	int oldtokenlistsize

	oldtokenlistsize:=tokenlistsize
	oldtokenlist:=tokenlist

CPL "EXTENDING TOKEN LIST TO", TOKENLISTSIZE,"TO",TOKENLISTSIZE*2

	tokenlistsize*:=2

	tokenlist:=pcm_alloc(tokenrec.bytes*tokenlistsize)

	memcpy(tokenlist,oldtokenlist,ntokens*tokenrec.bytes)

	pcm_free(oldtokenlist,tokenrec.bytes*oldtokenlistsize)
end

global proc starttkscan(int moduleno)=
	nexttoken:=moduletable[moduleno].tklist
end

global function readtokens_a(int fileno, &ntokens)ref tokenrec=
	ref tokenrec lastlx
	ref char p
	int lena,lenb,lastsymbol

	newtokenlist()

	ntokens:=0
	lastsymbol:=0

	startlex("",fileno)

	repeat
		lexreadtoken()



		switch lx.symbol
		when kcasesym,kswitchsym,kdocasesym,kdoswitchsym,kforsym,
				kdosym,ktosym,kprocsym,kfunctionsym,kimportmodulesym,kunlesssym,
				krecordsym,kstructsym,kunionsym,ktypesym,kwhilesym,kclasssym,
				ktrysym,ktabledatasym,kassemsym,kifsym then

			if lastsymbol=kendsym then
				if lastlx.subcode then lxerror("end if if?") fi
				lastlx.subcode:=lx.symbol
				next
			fi


		when eolsym then
			if lastsymbol in [commasym, lsqsym, lbracksym] then !ignore eol
				next
			elsif symboloptypes[lastsymbol]=bin_op and not assemmode and 
				lastsymbol not in [maxsym, minsym] then
				next
			else
				lx.symbol:=semisym
			fi

		when stringconstsym then
			if lastsymbol=stringconstsym then
				lena:=strlen(lastlx.svalue)
				lenb:=strlen(lx.svalue)
				p:=pcm_alloc(lena+lenb+1)
				memcpy(p,lastlx.svalue,lena)
				memcpy(p+lena,lx.svalue,lenb)
				(p+lena+lenb)^:=0
				lastlx.svalue:=p
				next
			fi
		when ksourcedirsym then
			if not dolexdirective(lx.subcode) then		!skip symbol
				next
			fi

		when namesym then
			if lx.subcode=unitnamesym then
				case lastsymbol
				when intconstsym then
					if lastlx.subcode in [ti128,tu128] then
						lxerror("No suffix on i128/u128")
					fi
					case lx.symptr^.index
					when million_unit then lastlx.value *:= 1 million
					when billion_unit then lastlx.value *:= 1 billion
					when thousand_unit then lastlx.value *:= 1 thousand
					when kilo_unit then lastlx.value *:= 1024
					when mega_unit then lastlx.value *:= 1048576
					when giga_unit then lastlx.value *:= (1048576*1024)
					else
						lxerror("Can't do this unit index")
					esac
					lastlx.subcode:=setinttype(lastlx.value)
					next
				when realconstsym then
					lxerror("Unit suffix after float not implem")
				esac
			fi
		when machinetypesym then
			case lx.subcode
			when 'I','i' then lx.subcode:=ti64
			when 'W','w' then lx.subcode:=tu64
			esac
			lx.symbol:=stdtypesym

		when rawxnamesym then
			lx.symbol:=namesym

		when insym then
			if lastsymbol=notlsym then
				lastlx.symbol:=notinsym
				lastlx.subcode:=notin_op
				next
			fi
		when eqsym then
			if lastsymbol=notlsym then
				lastlx.symbol:=cmpsym
				lastlx.subcode:=ne_op
				next
			fi
		end switch

SKIP::
		if (ntokens+4) >= tokenlistsize then			!some margin
			extendtokenlist(ntokens)
		fi
		++ntokens

		lx.pos :=lx.pos ior lxfileno<<24

		tokenlist[ntokens]:=lx
		lastlx:=&tokenlist[ntokens]
		lastsymbol:=lx.symbol

	until lx.symbol=eofsym

	tokenlist[ntokens+1].symbol:=eofsym					!end with 2 eofs

	return &tokenlist[1]
end




=== bb_diags.m 18/40 ===
import mlib
import clib
import oslib

import bb_decls
import bb_tables
import bb_support
import bb_lex
import bb_lib
import bb_pclcommon

int currlineno
int currfileno

global proc printoverloads(filehandle f)=
	ref overloadrec p

	println @f,"OVERLOADS"
	for i to overloadtable.upb do
		p:=overloadtable[i]
		if p then
			while p do
				if p.bmode then
					fprint @f,"operator (#)(#,#)#",
						jtagnames[i]+2,strmode(p.amode), strmode(p.bmode), strmode(p.rmode)
				else
					fprint @f,"operator (#)(#)#",
						jtagnames[i]+2,strmode(p.amode), strmode(p.rmode)
				fi
				if p.fncode then
					print @f,"=",p.fncode,strexpr(p.fncode).strptr
				fi
				println @f
				p:=p.nextoverload
			od
			println @f
		fi
	od

end

global proc printst(filehandle f,ref strec p,int level=0)=	!PRINTST
ref strec q

if p^.symbol<>namesym then
	mcerror("PRINTST not name")
fi

printstrec(f,p,level)

q:=p^.deflist

while q<>nil do
	printst(f,q,level+1)
	q:=q^.nextdef
od
end

proc printstrec(filehandle f,ref strec p,int level)=		!PRINTSTREC
strec dd
ref byte q
strbuffer v
ref strbuffer d:=&v
int col,offset,n
const tabstr="    "
[256]char str

gs_init(d)

offset:=0
to level do
	gs_str(d,tabstr)
	offset+:=4
od
gs_str(d,":")

gs_leftstr(d,p^.name,28-offset,'-')
gs_leftstr(d,namenames[p^.nameid],12,'.')

col:=gs_getcol(d)
dd:=p^


gs_str(d,"[")
if p^.isimport then
	gs_str(d,(p^.iscimport|"Imp/CLIB "|"Imp "))
else
	gs_str(d,(p^.isglobal|"Prog ","Exp ", "ExpQ "|"Loc "))
fi

if dd.isstatic then
	gs_str(d,"Stat")
fi
if dd.fflang then
	gs_strsp(d,fflangnames[dd.fflang])
fi

if dd.nameid=paramid and dd.parammode then
	gs_str(d,parammodenames[dd.parammode])
fi

if dd.align then
	gs_str(d,"@@")
	gs_strint(d,dd.align)
	gs_str(d," maxalign:")
	gs_strint(d,dd.maxalign)
	gs_str(d," ")
fi
if dd.optional then
	gs_str(d,"Opt ")
fi
if dd.varparams then
	gs_str(d,"Var:")
	gs_strint(d,dd.varparams)
	gs_str(d," ")
fi
if dd.moduleno then
	print @&.str,"Modno#",,dd.moduleno
	gs_str(d,&.str)
fi
if dd.equals then
	gs_str(d,":= ")
fi

if dd.used then
	gs_str(d,"U ")
fi

if dd.isthreaded then
	gs_str(d,"Threaded ")
fi


gs_str(d,"]")
gs_padto(d,col+10,'=')

if p^.owner then
	fprint @&.str,"(#)",p.owner.name
	gs_leftstr(d,&.str,18,'-')
else
	gs_leftstr(d,"()",18,'-')
fi

case p^.mode
when tvoid then
	gs_str(d,"Void ")
else
	GS_STRINT(D,P^.MODE)
	GS_STR(D,":")

	gs_str(d,strmode(p.mode))
	gs_str(d," ")
esac

case p^.nameid
when fieldid,paramid then
	gs_str(d," Offset:")
	gs_strint(d,p^.offset)
	if p^.mode=tbitfield then
		gs_str(d," Bitoffset:")
		gs_strint(d,p^.bitoffset)
		gs_str(d,":")
		gs_strint(d,p^.bitfieldwidth)
	fi

	print @&.str,p^.uflags.ulength:"v",ichar(&p^.uflags.codes):".*"
	gs_str(d," UFLAGS:")
	gs_str(d,&.str)
	gs_str(d,"-")
	gs_strint(d,p^.uflags.ulength)

	if p^.code then
		gs_str(d,"/:=")
		gs_strvar(d,strexpr(p^.code))
	fi

	if p.nameid=paramid and p.variadic then
		gs_str(d,"...")
	fi
when genfieldid then
	gs_str(d,"Index:")
	gs_strint(d,p^.offset)

when procid,genprocid then

	gs_str(d,"Index:")
	gs_strint(d,p^.index)

	gs_str(d," Nret:")
	gs_strint(d,p^.nretvalues)

when dllprocid then
	gs_str(d,"Index/PCaddr:")
	gs_strint(d,p^.index)
	if p^.truename then
		gs_str(d," Truename:")
		gs_str(d,p^.truename)
	fi

when staticid then
	if p^.code then
		gs_str(d,"=")
		gs_strvar(d,strexpr(p^.code))
	fi

when frameid then
	if p^.code then
		gs_str(d,":=")
		gs_strvar(d,strexpr(p^.code))
	fi

when constid then
	gs_str(d,"Const:")
	gs_strvar(d,strexpr(p^.code))

when typeid then
	if p^.baseclass then
		gs_str(d,"Baseclass:")
GS_STR(D,"<HAS BASECLASS>")
	fi
	if ttbasetype[p.mode]=ttagunion then
		gs_str(d,"Tagmode:")
		gs_str(d,strmode(p.enumtagmode))
	fi
when enumid then
	gs_str(d,"Enum:")
	gs_strint(d,p^.index)
when dllmoduleid then
	gs_str(d,"DLL#:")
	gs_strint(d,p^.dllindex)
esac

case p^.at
when 2 then
	if p.nameid=fieldid then
		gs_str(d," @")
		gs_str(d,p^.equivfield^.name)
	fi
when 1 then
	if p.nameid in [frameid, staticid] then
		gs_strvar(d,strexpr(p^.equivvar))
	fi
esac

gs_str(d," Module# ")
gs_strint(d,p^.moduleno)

gs_str(d," Lineno:")
gs_strint(d,p^.lineno iand 16777215)

gs_println(d,f)

case p^.nameid
when constid,frameid,staticid,macroid then
	if p^.code then
		printunit(p^.code,dev:f)
	fi
esac
end

global proc printstflat(filehandle f)=
int i
ref strec p
println @f,"GLOBAL SYMBOL TABLE:"

for i:=0 to hashtable.upb-1 do
	p:=&hashtable[i]
	if p^.name then
		case p^.symbol
		when namesym then
			println @f,i,p,":",p^.name,symbolnames[p^.symbol],namenames[p^.nameid]
			p:=p^.nextdupl
			while p do
				println @f,"	",p,p^.name,symbolnames[p^.symbol],namenames[p^.nameid],
					"(From",(p^.owner|p^.owner^.name|"-"),,")"
				p:=p^.nextdupl
			od
		esac
	fi
od
end

global proc printcode(filehandle f,ichar caption)=
ref strec p
ref procrec pp

pp:=proclist
while pp do
	p:=pp.def

	print @f,p^.name,,"=",(p^.isglobal|"Global","Export","ExportQ"|"Local")
	if p.owner.nameid=typeid then
		print @f," in record",p.owner.name
	fi
	println @f
	printunit(p^.code,,"1",dev:f)
	println @f
	pp:=pp^.nextproc
od
end

global proc printunit(ref unitrec p,int level=0,ichar prefix="*",filehandle dev=nil)=		!PRINTUNIT
ref unitrec q
ref strec d
int t
ichar idname
int64 a
real32 x32
static int cmpchain=0

if p=nil then
	return
fi

if p^.lineno then
	currlineno:=p^.lineno
	currfileno:=p^.fileno
fi

print @dev,p,":"
print @dev,getprefix(level,prefix,p)

idname:=jtagnames[p^.tag]+2
print @dev,idname,,": "

case p^.tag
when j_name then
	d:=p^.def

	print @dev,d^.name,namenames[d^.nameid]

	if d^.code then
		print @dev," {",,jtagnames[d^.code^.tag],,"}"
	fi

	print @dev," ",,getdottedname(d)!,q
	print @dev,(p^.dottedname|" {Dotted}"|"")

	if p^.c then
		print @dev," Lastcall:",p^.c
	fi

	if p^.addroffirst then
		print @dev," Addroffirst."
	fi

	print @dev," Moduleno:",p^.moduleno

	if p.avcode then print @dev," AV:",char(p.avcode) fi

when j_labeldef then
	println @dev,p^.def^.name

when j_const,j_emitc then
	t:=p^.mode
	a:=p^.value
	if t=trefchar then
		if p^.slength>256 then
			print @dev,"""",,"(LONGSTR)",""" *",,p^.slength
		elsif p^.slength then
			print @dev,"""",,p^.svalue,,""" *",,p^.slength
		else
			print @dev,""""""
		fi

	elsecase ttbasetype[t]
	when ti64,ti32,ti16,ti8 then print @dev,int64(a)
	when tu64,tu32,tu16,tu8 then print @dev,word64(a)
	when tc64,tc8,tc16 then print @dev,chr(a)

	when tr32 then
		x32:=p^.xvalue
		print @dev,real64(x32)
	when tr64 then
		print @dev,p^.xvalue
	when tref then
		if p^.value then
			print @dev,"#",,p^.value,P^.SLENGTH
		else
			print @dev,"NIL"
		fi
	when ti128 then
		print @dev,p.value128
	when tu128 then
		print @dev,p.uvalue128
	else
			cpl =typename(t),typename(ttbasetype[t])
PRINT @DEV,"<PRINTUNIT BAD CONST PROBABLY VOID"
	fi
	print @dev," ",,typename(t)
	if p^.isastring then
		print @dev," <isstr>"
	fi

	if p^.whenlabel then
		print @dev," *L",,p^.whenlabel
	fi

when j_decimal then
	print @dev,p^.svalue,"Len:",p^.slength

when j_typeconst then
	print @dev,typename(p^.mode),typename(p^.value)


when j_bitfield then
	print @dev,bitfieldnames[p.bfcode]+3

when j_convert,j_typepun then
	print @dev," Convmode:",strmode(p^.convmode)

when j_makelist,j_multexpr then
	print @dev,"Len:",p^.length," Makeax:",p.makearray

when j_dot then
	print @dev,"Offset:",p^.offset

when j_index, j_ptr then

when j_exit,j_redo,j_restart,j_next then
	print @dev,"#",,p^.index

when j_syscall then
	print @dev,sysfnnames[p.fnindex]+6

when j_assem then

when j_assemreg then

when j_assemxreg then

when j_assemmem then

when j_makeset then
when j_cmpchain then
	for i to p.cmpgenop.len do
		if p.cmpgenop[i]=0 then exit fi
		print @dev,genopnames[p.cmpgenop[i]],," "
	od
	if p.cmpopindex[1] then
		print @dev,"//"
		for i to p.cmpopindex.len do
			if p.cmpopindex[i]=0 then exit fi
			print @dev,specopnames[p.cmpopindex[i]],," "
		od
	fi

esac

case p.tag
when j_name, j_ptr, j_index, j_dot,j_callproc, j_callfn, j_assign then
	if p.memmode=tvoid then
	else
		print @dev," WIDEN FROM:",strmode(p.memmode)
	fi
esac

if p^.isconst then
	print @dev," Is const"
fi

case p.tag
when j_bin, j_binto, j_unary, j_unaryto, j_cmp, j_incr, j_convert,
	j_andl, j_orl, j_notl, j_istruel then
	if p.opindex then
		fprint @dev," <#>",specopnames[p.opindex]+3
	elsif p.genop then
		fprint @dev," Genop<#>",genopnames[p.genop]
	else
		fprint @dev," no-op"
	fi
esac





println @dev

if p.hasa then printunitlist(dev,p^.a,level+1,"1") fi
if p.hasb then printunitlist(dev,p^.b,level+1,"2") fi
if p.hasc then printunitlist(dev,p^.c,level+1,"3") fi
end

proc printunitlist(filehandle dev,ref unitrec p,int level=0,ichar prefix="*")=		!PRINTUNIT
if p=nil then return fi

while p do
	printunit(p,level,prefix,dev)
	p:=p^.nextunit
od
end

function getprefix(int level,ichar prefix,ref unitrec p)ichar=		!GETPREFIX
static [1024]char str
[1024]char indentstr
[16384]char modestr
ichar isexpr

indentstr[1]:=0
if level>10 then level:=10 fi

to level do
	strcat(&.indentstr,"- ")
od

isexpr:="S"
if jisexpr[p.tag] then isexpr:="E" fi

case p.tag
when j_if, j_switch, j_case, j_select then
	if p.mode=tvoid then
		isexpr:="S"
	fi
esac

fprint @&.modestr,"# #:#",isexpr,(p^.resultflag|"RES"|"---"),strmode(p^.mode)
modestr[256]:=0

strcat(&.modestr,"-----------------------------")
modestr[17]:=' '
modestr[18]:=0

strcpy(&.str,getlineinfok())
strcat(&.str,&.modestr)
strcat(&.str,&.indentstr)
strcat(&.str,prefix)
if prefix^ then
	strcat(&.str," ")
fi

return &.str
end

function getlineinfok:ichar=			!GETLINEINFO
static [40]char str

fprint @&.str,"# # ",CURRFILENO:"Z2",currlineno:"z4"
return &.str
end

global proc printmodelist(filehandle f)=		!PRINTMODELIST
int mbase
static ichar tab="\t"

println @f,"MODELIST",ntypes

for m:=0 to ntypes do
	println @f,m:"4",strmode(m)
	mbase:=ttbasetype[m]

	println @f,tab,"Basetype:",mbase,strmode(mbase)
	println @f,tab,"ttname:",ttname[m]
	println @f,tab,"ttnamedef:",ttnamedef[m],(ttnamedef[m]|ttnamedef[m].name|"-")
	println @f,tab,"Target:",strmode(tttarget[m])
	println @f,tab,"Code:",stdcodes[mbase]:"c"
	println @f,tab,"Size:",ttsize[m],"Sizeset",ttsizeset[m]
	fprintln @f,"# Bounds: #..#  Length:#",tab,ttlower[m],ttlower[m]+ttlength[m]-1,ttlength[m]
	println @f,tab,"Tabtype:",strmode(tttabtype[m]),"Tabtype2:",strmode(tttabtype2[m])
	println @f,tab,"PCLtype:",strmode(ttpcltype[m])
	println @f,tab,"Cat:",typecatnames[ttcat[m]],"Cat2:",typecatnames[ttcat2[m]]
	if mbase=ttuple then
		print @f,tab,"Mult:"
		for i to ttlength[m] do print @f,strmode(ttmult[m,i]),," " od
		println @f
	fi
	println @f,tab,"Keytype:",strmode(ttkeytype[m])
	println @f,tab,"Isint:",ttisint[m]
	println @f,tab,"Isword:",ttisword[m]
	println @f,tab,"Isreal:",ttisreal[m]
	println @f,tab,"Isinteger:",ttisinteger[m]
	println @f,tab,"Isallnum:",ttisallnum[m]
	println @f,tab,"Ismainnum:",ttismainnum[m]
	println @f,tab,"Isshort:",ttisshort[m]
	println @f,tab,"Isref:",ttisref[m]
	


	println @f
od

end

=== bb_start.m 19/40 ===
import msys
import clib
import mlib
import oslib

import bb_target

import bb_lex
import bb_decls
import bb_support
import bb_tables
import bb_parse
import bb_lib
import bb_diags
import bb_mcldecls
import bb_name

import bb_type

import bb_genpcl
import bb_libpcl

import bb_genmcl
import bb_libmcl
import bb_pclcommon
import bb_export

tabledata() []ichar optionnames, []byte proddebug=

	(exe_sw,		"exe",		'P'),
	(dll_sw,		"dll",		'P'),
	(obj_sw,		"obj",		'P'),
	(asm_sw,		"asm",		'P'),
	(asm2_sw,		"c",		'P'),
	(pcl_sw,		"pcl",		'P'),
	(ma_sw,			"ma",		'P'),
	(run_sw,		"run",		'P'),

	(docs_sw,		"docs",		'P'),
	(export_sw,		"exp",		'P'),

	(sys_sw,		"sys",		'P'),
	(minsys_sw,		"minsys",	'P'),
	(nosys_sw,		"nosys",	'P'),

	(dload_sw,		"dload",	'D'),
	(dfixup_sw,		"dfixup",	'D'),
	(dparse_sw,		"dparse",	'D'),
	(dname_sw,		"dname",	'D'),
	(dtype_sw,		"dtype",	'D'),
	(dpcl_sw,		"dpcl",		'D'),
	(dmcl_sw,		"dmcl",		'D'),
	(dasm_sw,		"dasm",		'D'),
	(dobj_sw,		"dobj",		'D'),
	(dexe_sw,		"dexe",		'D'),
	(ddll_sw,		"ddll",		'D'),
	(dsys_sw,		"dsys",		'D'),
	(dminsys_sw,	"dminsys",	'D'),
	(dnosys_sw,		"dnosys",	'D'),
	(dssonly_sw,	"dssonly",	'D'),

	(opt_sw,		"opt",		0),

	(ast1_sw,		"ast1",		'D'),
	(ast2_sw,		"ast2",		'D'),
	(ast3_sw,		"ast3",		'D'),
	(showpcl_sw,	"showpcl",	'D'),
	(showmcl_sw,	"showmcl",	'D'),
	(st_sw,			"st",		'D'),
	(pst_sw,		"pst",		'D'),
	(stflat_sw,		"stflat",	'D'),
	(types_sw,		"types",	'D'),
	(overloads_sw,	"overloads",'D'),
	(ss_sw,			"ss",		'D'),

	(time_sw,		"time",		0),
	(v_sw,			"v",		0),
	(vv_sw,			"vv",		0),
	(quiet_sw,		"q",		0),
	(help_sw,		"h",		0),
	(help2_sw,		"help",		0),
	(ext_sw,		"ext",		0),
	(out_sw,		"out",		0),
	(outpath_sw,	"outpath",	0),
	(unused_sw,		"unused",	0),
	(set_sw,		"set",		0),
end

const logfile="bx.log"

[sysparams.len]ichar extraparams	!after ":"
[sysparams.len]ichar extravalues
int nextraparams=0

const maxoptionvar=25
[maxoptionvar]ichar optionvars
[maxoptionvar]ichar optionvalues
int noptionvars

int startclock,endclock

global proc start_common(int os, target)=
	unit p,q,r
	int m,fileno,ntokens,t




startclock:=os_clock()


	initdata(os,target)

	getinputoptions()



	if debugmode and passlevel<parse_pass then return fi

	if fverbose>=1 then
		fprintln "Compiling # to #",inputfiles[1]:"14jlp-",outfile
	fi

	initsearchdirs()
	remove(logfile)

	starttimer()
	do_loadmodules()
	stoptimer("LOAD")


	do_writema()



	do_parse()
	stoptimer("PARSE")



	do_name()
	stoptimer("NAME")

	do_type()

	do_writeexports(outfile)

	stoptimer("TYPE")

	do_genpcl()
	stoptimer("PCL")



	laterpasses()

	if passlevel=run_pass then
		do_runprog()
	fi


	if fverbose>=2 then
		println "Finished."
	fi

	showlogfile()

end

proc do_loadmodules=
	if fbundled then
		loadmafile()
	fi
	loadmainmodule(inputfiles[1])
end

proc do_parse=
	if debugmode and passlevel<parse_pass then return fi

	if fwritedocs then
CPL "CREATING DOC FILE"
		docfile:=fopen(changeext(outfile,"txt"),"w")
	fi

	for i:=2 to nmodules do
		parsemodule(i)
	od
	parsemodule(1)

	if docfile then
		fclose(docfile)
	fi


	if not debugmode or passlevel>=fixup_pass then
		fixusertypes()
	fi

	if debugmode and fshowast1 then showast("AST1") fi
end

proc do_name=
	if debugmode and passlevel<name_pass then return fi

	rx_typetable()
	for i:=2 to nmodules do
		rx_module(i)
	od
	rx_module(1)

	if debugmode and fshowast2 then showast("AST2") fi
end

proc do_type=
	if debugmode and passlevel<type_pass then return fi

	tx_typetable()
		fixblockparams()

	for i:=1 to nmodules do
		tx_module(i)
	od
	tx_allprocs()

	if debugmode and fshowast3 then showast("AST3") fi
end

proc do_genpcl=
	if debugmode and passlevel<pcl_pass then return fi

	codegen_pcl()
	if debugmode and fshowpcl then showpcl("PCL") fi
end

proc showlogfile=
[256]char str
filehandle logdev
int size

if not debugmode then return fi

logdev:=fopen(logfile,"w")

target_show(logdev)

if fshowpcl and passlevel>=pcl_pass then    addtolog("PCL",logdev) fi
if fshowast3 and passlevel>=type_pass then	addtolog("AST3",logdev) fi
if fshowast2 and passlevel>=name_pass then	addtolog("AST2",logdev) fi
if fshowast1 and passlevel>=parse_pass then	addtolog("AST1",logdev) fi
if fshowst then								showsttree("SYMBOL TABLE",logdev) fi
if fshowstflat then							showstflat("FLAT SYMBOL TABLE",logdev) fi

if fshowtypes then							printmodelist(logdev) fi

if fshowoverloads then						printoverloads(logdev) fi

size:=getfilesize(logdev)
fclose(logdev)

if size then

	print @&.str,"\\m\\ed.bat -w ",logfile

	if checkfile("bb.m") then
		os_execwait(&.str,1,nil)
	else
		println "Diagnostic outputs written to",logfile
	fi
fi

stop 0
end

proc initdata(int os, target)=
	pcm_init()
	lexsetup()
	initassemsymbols()
	init_tt_tables()
	initbblib()

	if os='W' then
		fwindows:=1
	else
		flinux:=1
	fi

	case target
	when 'X64' then
		fx64:=1
		if flinux then loaderror("Linux/x64") fi
	else
		loaderror("Bad os/target")
	esac

	addoptionvar("bb","1")
end

function loadmainmodule(ichar filespec)int=
	[100]char modulename
	[300]char path
	ref byte source
	int status
	modulerec m
	int i,flag,fileno

	pcm_clearmem(&moduletable[0],modulerec.bytes)

	sourcefilenames[0]:="<dummy file>"
	sourcefilepaths[0]:="<dummy path>"
	sourcefiletext[0]:="<sourcefile0>"
	sourcefilesizes[0]:=strlen(sourcefiletext[0])

	moduletable[0].name:="PROGRAM"
	moduletable[0].fileno:=0

	stprogram:=createdupldef(nil,addnamestr("$prog"),programid)
	moduletable[0].stmodule:=stprogram

	fileno:=getmainfile(filespec)

	infotext:=nil

	strcpy(&.modulename,extractbasefile(filespec))
	strcpy(&.path,extractpath(filespec))
	if path[1] then
		addsearchdir(&.path)
	fi

	addmodule(&.modulename,fileno,flag)
	addspecialtypes()


return 1
end

function addmodule(ichar modulename,int fileno,&exportflag)int=


modulerec m
const maximports=maxmodule
[maximports]ichar importnames
[0..maximports]byte importflags, importxd
[maximports]int importmoduleno
int nimports,i,status,k,flag,j,newmodno
ref modulerec pmodule

convlcstring(modulename)

pcm_clearmem(&m,m.bytes)

m.name:=pcm_copyheapstring(modulename)
m.fileno:=fileno

stmodule:=createnewmoduledef(stprogram,addnamestr(m.name))
m.stmodule:=stmodule

if nmodules>=maxmodule then
	loaderror("Too many modules",modulename)
fi

pmodule:=&moduletable[newmodno:=++nmodules]

pmodule^:=m
pmodule^.importmap[newmodno]:=1
m.stmodule^.moduleno:=newmodno

memset(&importflags,0,importflags.bytes)

tokenisemodule(newmodno)


nimports:=readimportlist(newmodno,&importnames,&importflags,&importxd,maximports)

for i to nimports do
	flag:=0
	if fverbose=3 then
		println "Load import for",modulename,=importnames[i]
	fi
	k:=loadimport(importnames[i],flag,importxd[i],modulename)
	if flag then
		importflags[i]:=1
	fi
	pmodule^.importmap[k]:=1
	importmoduleno[i]:=k
od

for i:=1 to nimports when importflags[i] do
	k:=importmoduleno[i]
	for j:=1 to nmodules do
		if moduletable[k].importmap[j] then		!add that to this module
			pmodule^.importmap[j]:=1
		fi
	od
od

exportflag:=importflags[0]

return newmodno
end

function readimportlist(int m, ref[]ichar importnames,
							ref[0:]byte importflags, importxd, int maximports)int=
int n,flag,exportflag,xdflag
ichar s
[100]char name,libname
ichar iname

starttkscan(m)

exportflag:=0

n:=0

do
	lex()
	case lx.symbol
	when eofsym then
		exit
	when semisym,eolsym then

	when kimportsym then
		xdflag:=lx.subcode
		flag:=0
		lex()
		if lx.symbol=mulsym then
			flag:=1
			lex()
		fi

		if lx.symbol<>namesym then
			abortprogram("import: modulename expected")
		fi
		if ++n>=maximports then			!allow for extra msys module
			abortprogram("too many imports")
		fi

		iname:=mapimport(lx.symptr.name)
		importnames[n]:=pcm_copyheapstring(iname)
		importflags[n]:=flag
		importxd[n]:=xdflag

		repeat lex() until lx.symbol<>namesym


	when kimportpathsym then
		lex()
		if lx.symbol=stringconstsym then
			addsearchdir(lx.svalue)
			lex()
		else
			abortprogram("string path expected")
		fi

	when kmapmodulesym then
		domapmodule()

	else
		exit
	esac
od

int needbsys,needclib
ichar bsysname

case msyslevel
when 1 then
	bsysname:="msystemp"
when 2 then
	bsysname:="msyslib"
esac


if nmodules=1 then
	if msyslevel then
		needbsys:=1

		for i to n do
			if eqstring(importnames^[i],bsysname) then
					needbsys:=0
					exit
			fi
		od
	else
		needbsys:=0
	fi

	if needbsys then
		++n
		importnames^[n]:=pcm_copyheapstring(bsysname)
		importflags^[n]:=0
		importxd[n]:=0
	fi
fi

importflags^[0]:=exportflag

return n
end

function loadimport(ichar modulename,int &exportflag,xdflag,ichar ownername)int=

int i,fileno
ichar ifilespec
[300]char filespec
ref char source
ichar newname

newname:=modulename

for i:=1 to nmodules do
	if eqstring(moduletable[i].name,newname) then		!already loaded
		return i
	fi
od

fileno:=getmodulefile(modulename,ownername,xdflag)

if xdflag then
	addcclib(modulename)
fi

return addmodule(newname,fileno, exportflag)
end

proc lextest(ichar file)=

int fileno,t, ntokens
ref tokenrec tk

CPL =strec.bytes
CPL =unitrec.bytes

t:=clock()

lexsetup()

fileno:=getmainfile(file)

if not fileno then
	CPL "CAN'T LOAD", FILE
	stop
fi

readtokens_a(fileno, ntokens)


repeat
	lex()
	printsymbol(&lx)
until lx.symbol=eofsym

CPL CLOCK()-T,"msec"

CPL "READ",=NTOKENS


end

proc initsearchdirs=
[300]char str1,str2
int i


nsearchdirs:=0
addsearchdir("c:/bx/")
addsearchdir(os_getmpath())
addsearchdir(os_gethostname())
addsearchdir("./")
end

proc addsearchdir(ichar path)=
	for i to nsearchdirs do
		if eqstring(searchdirs[i],path) then return fi
	od
	if nsearchdirs>maxsearchdirs then
		loaderror("Too many search paths")
	fi
	searchdirs[++nsearchdirs]:=pcm_copyheapstring(path)
end

proc tokenisemodule(int moduleno)=
	ref modulerec m:=&moduletable[moduleno]
	int ntokens

	m.tklist:=readtokens_a(m.fileno, ntokens)

end

proc getinputoptions=
const slash='-'
int i,j,k
int paramno,pmtype,sw,ncolons,passfixed
ichar name,value,filename,ext
[300]char filespec

paramno:=2
ncolons:=0

while pmtype:=nextcmdparam(paramno,name,value,"m") do

	case pmtype
	when pm_option then

		convlcstring(name)
		for sw to optionnames.len do
			if eqstring(name,optionnames[sw]) then
				do_option(sw,value)
				exit
			fi
		else
			println "Unknown option:",name
			stop 99
		od
	when pm_sourcefile then
		if ninputfiles>=maxmodule then
			loaderror("Too many input files")
		fi
		convlcstring(name)
		inputfiles[++ninputfiles]:=pcm_copyheapstring(name)
	when pm_libfile then
		if nlibfiles>=maxlibfile then
			loaderror("Too many lib files")
		fi
		libfiles[++nlibfiles]:=pcm_copyheapstring(name)
	when pm_colon then
		if ++ncolons>1 then
			name:=":"
			value:=nil
			goto doextra
		fi
	when pm_extra then
doextra::
		extraparams[++nextraparams]:=pcm_copyheapstring(name)
		extravalues[nextraparams]:=pcm_copyheapstring(value)
	esac

od

if prodmode=debugmode=0 then
	passlevel:=exe_pass
	prodmode:=1
elsif prodmode and passlevel=0 then
	passlevel:=exe_pass
elsif debugmode and passlevel=0 then
	passlevel:=mcl_pass
fi
if not destext then destexT:=(prodmode|"exe"|"") fi

if msyslevel=-1 then
	msyslevel:=(prodmode|2|0)
fi

if ninputfiles=0 then
	showcaption()
	println "Usage:"
	println "	",,sysparams[1],"filename[.m]     # Compile project to executable"
	println "	",,sysparams[1],"-help            # Other options"
	stop

elsif ninputfiles=1 then
	filename:=inputfiles[1]				!primary file name

	ext:=extractext(filename)
	if eqstring(ext,"ma") then
		fbundled:=1
		mafilename:=pcm_copyheapstring(filename)
		inputfiles[1]:=pcm_copyheapstring(changeext(filename,"m"))
	fi

	outfile:=pcm_copyheapstring(changeext(filename,destext))

	if destfilename then
		outfile:=pcm_copyheapstring(addext(destfilename,destext))
	elsif destfilepath then
		strcpy(&.filespec,destfilepath)
		strcat(extractfile(&.filespec), outfile)
		outfile:=pcm_copyheapstring(&.filespec)	
	fi
else
	loaderror("Specify one lead module only")
fi

case msyslevel
when 1 then
	addmodulemapping("msys","msystemp")
when 0,2 then	
	addmodulemapping("msys","msyslib")
esac

end

proc do_option(int sw, ichar value)=
static byte outused, outpathused

case proddebug[sw]
when 'P' then
	prodmode:=1
	if debugmode then loaderror("Mixed prod/debug options") fi
when 'D' then
	debugmode:=1
	if prodmode then loaderror("Mixed prod/debug options") fi
esac

switch sw
when exe_sw then passlevel:=exe_pass; destext:="exe"
when dll_sw then passlevel:=dll_pass; destext:="dll"
when obj_sw then passlevel:=obj_pass; destext:="obj"
when asm_sw, asm2_sw then passlevel:=asm_pass; destext:="asm"
when pcl_sw then passlevel:=pcl_pass; destext:=""
when run_sw then passlevel:=run_pass; destext:="exe"

when sys_sw then msyslevel:=2
when minsys_sw then msyslevel:=1
when nosys_sw then msyslevel:=0

when dload_sw then passlevel:=load_pass
when dparse_sw then passlevel:=parse_pass
when dfixup_sw then passlevel:=fixup_pass
when dname_sw then passlevel:=name_pass
when dtype_sw then passlevel:=type_pass
when dpcl_sw then passlevel:=pcl_pass
when dmcl_sw then passlevel:=mcl_pass
when dasm_sw then passlevel:=asm_pass; destext:="asm"
when dobj_sw then passlevel:=obj_pass; destext:="obj"
when dexe_sw then passlevel:=exe_pass; destext:="exe"
when ddll_sw then passlevel:=dll_pass; destext:="dll"
when dsys_sw then msyslevel:=2
when dminsys_sw then msyslevel:=1
when dnosys_sw then msyslevel:=0
when dssonly_sw then fssonly:=1

when opt_sw then foptimise:=1

when time_sw then fshowtiming:=1

when v_sw then fverbose:=2

when vv_sw then fverbose:=3

when quiet_sw then fverbose:=0

when help_sw,help2_sw then showhelp(); stop

when ext_sw then dointlibs:=0

when out_sw then
	if outpathused then loaderror("mixed out/path") fi
	destfilename:=pcm_copyheapstring(value)
	outused:=1

when outpath_sw then
	if outused then loaderror("mixed out/path") fi
	if (value+strlen(value)-1)^ not in ['\\','/'] then
		loaderror("Path needs to end with \\ or /")
	fi
	destfilepath:=pcm_copyheapstring(value)
	outpathused:=1

when unused_sw then fcheckunusedlocals:=1

when ast1_sw then fshowast1:=1
when ast2_sw then fshowast2:=1
when ast3_sw then fshowast3:=1
when showpcl_sw then fshowpcl:=1
when showmcl_sw then fshowmcl:=1
when st_sw then fshowst:=1
when pst_sw then fshowpst:=1
when stflat_sw then fshowstflat:=1
when types_sw then fshowtypes:=1
when overloads_sw then fshowoverloads:=1
when ss_sw then fshowss:=1


when ma_sw then fwritema:=1; destext:="ma"
when export_sw then fwriteexports:=1
when docs_sw then fwritedocs:=1
endswitch

end

proc showcaption=
	println "Mosaic/'M' Compiler", $date, $time
end

proc showstflat(ichar caption,filehandle f)=
println @f,"PROC",caption
printstflat(f)
println @f
end

proc showsttree(ichar caption,filehandle f)=
println @f,"PROC",caption
printst(f,stprogram)
println @f
end

global proc showhelp=
	static ichar helptext=strinclude "bb_help.txt"
	println helptext
end

proc showast(ichar filename)=
	filehandle f

	f:=fopen(filename,"w")
	return unless f

	println @f,"PROC",filename
	printcode(f,"")
	println @f
	fclose(f)
end

proc domapmodule=
	[256]char genname, actualname,optionname,valuename
	int cond,option

	getpsname(&.genname)

	if lx.symbol<>sendtosym then abortprogram("=> expected") fi

	getpsname(&.actualname)

	cond:=0

	if lx.symbol=kwhensym then
		getpsname(&.optionname)
		if lx.symbol=eqsym then
			getpsname(&.valuename)
		else
			strcpy(&.valuename,"1")
		fi
		cond:=1
	fi

	while lx.symbol not in [semisym,eofsym] do lex() od

	if cond then
		addmodulemapping(&.genname, &.actualname, &.optionname, &.valuename)
	else
		addmodulemapping(&.genname, &.actualname, nil,nil)
	fi
end

global function mapimport(ichar name)ichar=
	for i to nmodulemap do
		if eqstring(name,genericmodules[i]) then
			return actualmodules[i]
		fi
	od
	return name
end

proc getpsname(ichar dest)=

	lex()	
	case lx.symbol
	when namesym then
		strcpy(dest,lx.symptr.name)
	when stringconstsym then
		strcpy(dest,lx.svalue)
	when intconstsym then
		lx.svalue:=strint(int(lx.value))

	else
		abortprogram("map1")
	esac
	lex()
end

global proc addmodulemapping(ichar old, newx, optionname=nil, valuename=nil)=
	int option

	if optionname then					!conditional
		option:=findoptionvar(optionname)
		if option then

			if eqstring(optionname,optionvars[option]) then
				if not eqstring(optionvalues[option],valuename) then
					return
				fi
			fi
		else
			return						!just assume false when not found
		fi
	fi

	if nmodulemap>=maxmodulemap then
		abortprogram("Too many module mappings")
	fi
	for i to nmodulemap do
		if eqstring(old,genericmodules[i]) then
			println old
			abortprogram("Dupl module mapping")
		fi
	od
	genericmodules[++nmodulemap]:=pcm_copyheapstring(old)
	actualmodules[nmodulemap]:=pcm_copyheapstring(newx)
end

proc addoptionvar(ichar name, value)=
	if noptionvars>=maxoptionvar then
		abortprogram("Too many option vars")
	fi
	for i to noptionvars do
		if eqstring(name,optionvars[i]) then
			println name
			abortprogram("Dupl optionvar")
		fi
	od

	optionvars[++noptionvars]:=pcm_copyheapstring(name)
	if value=nil then
		optionvalues[noptionvars]:="1"
	else
		optionvalues[noptionvars]:=pcm_copyheapstring(value)
	fi
end

proc dosetoptionvar(ichar s)=
	ref char t
	[256]char name
	[256]char value

	if s=nil or s^=0 then
		abortprogram("set:no option")
	fi

	t:=&.name
	strcpy(t,s)
	value[1]:=0

	while t^ do
		if t^=':' then
			t^:=0
			strcpy(&.value,t+1)
			exit
		fi
		++t
	od

	if value[1]=0 then
		strcpy(&.value,"1")
	fi

	addoptionvar(&.name,&.value)
end

function findoptionvar(ichar name)int=
	for i to noptionvars do
		if eqstring(name, optionvars[i]) then
			return i
		fi
	od
	return 0
end

global proc initassemsymbols=
[32]char str
int i

for i to mclnames.len do
	addreservedword(mclnames[i]+2,asmopcodesym,i)
od

for i to dregnames.len do
	addreservedword(dregnames[i],regsym,regindices[i],regsizes[i])
od


for i to xmmregnames.len do
	addreservedword(xmmregnames[i],xregsym,i)
od

for i to fregnames.len do
	addreservedword(fregnames[i],fregsym,i)
od

for i to mregnames.len do
	addreservedword(mregnames[i],mregsym,i)
od

for i to jmpccnames.len do
	addreservedword(jmpccnames[i],jmpccsym,jmpcccodes[i])
od

for i to setccnames.len do
	addreservedword(setccnames[i],setccsym,setcccodes[i])
od

for i to cmovccnames.len do
	addreservedword(cmovccnames[i],movccsym,cmovcccodes[i])
od

for i to segmentnames.upb do
	strcpy(&.str,segmentnames[i])
	str[strlen(&.str)-3]:=0
	addreservedword(pcm_copyheapstring(&.str),segnamesym,i)
od

addreservedword("aframe",regsym,r14,4)
addreservedword("dframe",regsym,r14,8)
addreservedword("astack",regsym,r15,4)
addreservedword("dstack",regsym,r15,8)
addreservedword("dprog",regsym,r8,8)
addreservedword("dsptr",regsym,r9,8)
end

proc showmodules=

println "Searchdirs:",nsearchdirs
FOR I TO NSEARCHDIRS DO
	CPL I, SEARCHDIRS[I]
OD

println "Modules:",nmodules
for i to nmodules do
	cpl moduletable[i].name, sourcefilepaths[moduletable[i].fileno]
od

println "CClibs",ncclibs
for i to ncclibs do
	cpl cclibtable[i]
od

end

global proc showpcl(ichar filename)=
	ref strbuffer pclstr

	gs_init(dest)
	pclstr:=writepclcode(filename)

	writegsfile(filename,pclstr)
end

proc do_writema=
	if fwritema then
		if fbundled then
			loaderror("-ma used with .ma input")
		fi
		writemafile(inputfiles[1],destfilename)
		stop
	fi
end

proc do_writeexports(ichar expfile)=
	[300]char str

	if not fwriteexports and passlevel<>dll_pass then
		return
	fi

	if passlevel=dll_pass then
		strcpy(&.str,changeext(expfile,"exp"))
		expfile:=&.str
	fi

	writeexports(expfile,moduletable[1].name)
	if fwriteexports then
		stop
	fi
end

proc showoptions=
CPL =PRODMODE
CPL =DEBUGMODE
CPL =PASSNAMES[PASSLEVEL]
CPL =FSHOWPCL
CPL =FSHOWMCL
CPL =FSHOWAST1
CPL =FSHOWAST2
CPL =FSHOWAST3
CPL =FSHOWST
CPL =FSHOWSTFLAT
CPL =FSHOWTYPES
CPL =FSHOWOVERLOADS
CPL =MSYSLEVEL
CPL =FSSONLY


end

proc starttimer=
static int tt

tt:=clock()
end

proc stoptimer(ichar mess)=
int newtt:=clock()


end

proc do_runprog=
[300]char str
int i

	strcpy(&.str,outfile)

	for i to nextraparams do
		strcat(&.str," ")
		strcat(&.str,extraparams[i])
		if extravalues[i] then
			strcat(&.str,":")
			strcat(&.str,extravalues[i])
		fi
	od

	os_execwait(&.str)

end

=== bb_help.txt 20/40 ===
'BB' Mosaic Compiler Generating x64 native code - Windows Version

Whole-program compiler builds entire program from the lead module
into a executable file.

    bb main              # Create main.exe from lead module main.m
    bb main.m            # Same (.m extension is default)
    bb -c main           # Create single-file main.asm intermediate ASM

Options:

    -c  or -asm           # Generate only intermediate ASM file only
    -exe                  # Generate .exe executable file
    -dll                  # Generate .dll library and .exp file

    -opt                  # Apply simple optimiser

    -out:file             # Name of output file 

    -ma                   # Create .ma file combining source/support files
    -docs                 # Create .txt with docstrings of exported files (not finished)
    -run                  # For -exe mode only: run resulting executable

    @file                 # Read options from file

Example:

     bb -run prog : abc def

Any parameters for the new program must follow " : " (spaces needed).
=== bb_x64.m 21/40 ===
import msys
import clib
import mlib
import oslib

import bb_decls
import bb_support
import bb_tables
import bb_lib
import bb_diags
import bb_genpcl

import bb_genmcl
import bb_libmcl
import bb_pclcommon

import ma_genss
import ma_writeexe
import ma_writess

import BB_START

global proc laterpasses=
	unit p,q,r
	int m,fileno,ntokens,t

	do_genmcl()
BB_START.STOPTIMER("MCL")

	case passlevel
	when asm_pass then
			do_genasm()
	when obj_pass then
		CPL "<OBJ>"
		LOADERROR("OBJ NOT READY")
	when exe_pass, dll_pass, run_pass then
		do_genexe()

	esac
end

proc do_genmcl=
	if debugmode and passlevel<mcl_pass then return fi

	codegen_mcl()

	if debugmode and fshowmcl then writeasm() fi
end

proc do_genasm=
	writeasm()
end

proc do_genexe=
	[256]char str
	if debugmode and passlevel<exe_pass then return fi

	genss()

	initsectiontable()
	if debugmode and fshowss then showss("SS",0) fi

	if fssonly then return fi

	if not labelcheck() then return fi
	genexe(nil,outfile,passlevel=dll_pass)
	if debugmode and fshowss then showss("SS",1) fi
	writeexe(outfile,passlevel=dll_pass)


end

global proc target_show(filehandle logdev) =

	if debugmode and fshowss and passlevel in [obj_pass,exe_pass,dll_pass] then
		addtolog("SS",logdev)
	fi
	if fshowmcl and passlevel>=mcl_pass then
		addtolog(outfile,logdev)
	fi
end

global proc writeasm=
	ref strbuffer asmstr

	gs_init(dest)
	asmstr:=writemclcode(outfile)

	writegsfile(outfile,asmstr)
end

global proc showhelp=
	println "Help Text"
end

global proc showss(ichar filename,int fexe)=
	ref strbuffer ssstr

	gs_init(dest)
	ssstr:=writessdata(fexe)
	writegsfile(filename,ssstr)
end

function labelcheck:int=
	int isok:=1

	for i to labelno when not labeltable[i] do
		fprintln "Undefined label: L#:",i
		isok:=0
	od

	if not isok then
		println "Can't proceed to build obj/exe"
		return 0
	fi
	return 1
end
=== bb_genpcl.m 22/40 ===
import mlib
import clib
import oslib

import bb_decls
import bb_support
import bb_tables
import bb_lib
import bb_libpcl
import bb_diags
import bb_pclcommon
import bb_blockpcl


const entrypointname = "start"
const entrypointname2 = "main"

global int retindex
global int initstaticsindex

global int framebytes, parambytes

global ref strec pclcurrproc

REF STREC FIRSTJ
REF PSTREC FIRSTJPDEF

const maxnestedloops	= 50

global [maxnestedloops,4]int loopstack
global int loopindex							!current level of nested loop/switch blocks

unitrec zero_unit
global unit pzero=&zero_unit

global function codegen_pcl:int=
ref strec d,e
ref procrec pp


pclinit()



pp:=staticlist
while pp do
	d:=pp^.def
		dostaticvar(d)
	pp:=pp^.nextproc
od

genpc(k_blank)

geninitproc()

pp:=proclist
while pp do
	if not eqbytes(pp.def.owner.name,"msys",4) then
		genprocdef(currproc:=pp^.def)
	fi
	pp:=pp^.nextproc
od

pp:=proclist
while pp do
	if eqbytes(pp.def.owner.name,"msys",4) then
		genprocdef(currproc:=pp^.def)
	fi
	pp:=pp^.nextproc
od




allpclcode:=pccode

return 1
end

proc genprocdef (ref strec p) =	!GENPROCDEF
[1256]char str
[1256]char name
int paramoffset,nparams,retaddrbytes
ref strec d
int n,lab,np,offset,reg,i,xreg,isstart,structret,isfloat,hasparams,hasequiv
unit q
pcl pcproc
pcl oldpccode,oldpccodex, pp,qq

d:=p^.deflist


isstart:=0
if p.isglobal and (eqstring(p^.name,entrypointname) or
					 eqstring(p.name,entrypointname2)) then
	isstart:=1
	p.index:=labelno
fi

retpending:=1


MLINENO:=P.POS
genpc(k_procdef,genmem_d(p))
pcproc:=pccodex
pclastframe:=pcproc
pcltempindex:=0
pccodex.def.isstart:=isstart

d:=p^.deflist
while d do
	MLINENO:=D.POS
	case d^.nameid
	when frameid then
		genpc(k_frame,genmem_d(d))
		setmode(d.mode)
		pclastframe:=pccodex
	when paramid then
		genpc(k_param,genmem_d(d))
		setmode(d.mode)
	esac
	d:=d^.nextdef
od


genprocentry(isstart)



if isstart then
	genpc_sysproc(sysfn_init)
	genpc_sysproc(sysfn_initstatics)
fi



retindex:=lab:=createfwdlabel()

gencomment("-------------------------------------------------")


evalunit(p.code)


gencomment("-------------------------------------------------")


definefwdlabel(retindex)

d:=p^.deflist
while d do
	if d.nameid in [frameid,paramid] and ttcat[d.mode]=var_cat then
		freeframevar(d)
	fi
	d:=d^.nextdef
od

if isstart then
	genpc_sysproc(sysfn_stop, pzero)
	genreturn(framebytes,parambytes)
else
		genreturn(framebytes,parambytes)
fi

if p^.mode<>tvoid then
	if not checkblockreturn(p^.code) then
		gerror_s("Function needs explicit return: ",p^.name)
	fi
fi



genpc(k_procend)

gencomment("")
end

proc genprocentry(int isstart)=

	genpc(k_procentry)
	pccodex^.isglobal:=isstart
end

proc genframedef(ref strec d)=
[256]char str
int offset

GENCOMMENT("GENFRAMEDEF")
end

proc dostaticvar(ref strec d)=
	unit p

	if d^.isimport then return fi

	if d^.at=1 then
		p:=d^.equivvar

		case p^.tag
		when j_addrof then
GERROR("@ADDR")
		when j_const then
			genpc(k_equiv,genmem_d(d))
			pccodex.size:=p.value
		else
			printunit(p)
			gerror("equiv/not simple")
		esac
	elsif d^.code then
		if ttcat[d.mode]<>var_cat then
			genpc(k_istatic,genmem_d(d))
			pccodex.align:=getalignment(d.mode)
			pccodex.size:=ttsize[d.mode]
			genidata(d.code)
		else
			goto dozstatic
		fi
	else
dozstatic::
		genpc(k_zstatic,genmem_d(d))
		pccodex.size:=ttsize[d^.mode]
		pccodex^.align:=getalignment(d^.mode)
	fi
end

proc dostaticvariant(ref strec d)=
	int pmode

	if d^.isimport or d^.at=1 then return fi

	pmode:=ttpcltype[d.mode]
	if ttcat[pmode]<>var_cat then return fi




	if d^.code then				!have an expression to assign
	else
		genpc(k_initmemz,genmem_d(d))
	fi
	pccodex^.mode:=pmode

end

proc genidata(unit p,int doterm=1, am='A',offset=0)=
int t,length,n,i,j,nwords,offset1,offset2,size,padding,isunion,tbase
unit q,a,b
ref strec d
real32 sx

t:=p^.mode
mlineno:=p^.lineno
tbase:=ttbasetype[t]

case p^.tag
when j_const then
	if ttisref[p.mode] then
		if p^.mode=trefchar then
			if p^.svalue then
				genpc(k_dq,genstring(p^.svalue))
			else
				genpc(k_dq,genint(0))
			fi
		else
			genpc(k_dq,genint(p.value))
		fi
	elsif ttisreal[p.mode] then
		case ttsize[p^.mode]
		when 4 then
			genpc(k_dd,genreal32(p.xvalue))
		when 8 then
			genpc(k_dq,genreal(p.xvalue))
		else
			gerror_s("IDATA/REAL:",strmode(p^.mode),p)
		esac

	else						!assume int/word
		case ttsize[getmemmode(p)]
		when 1 then
			genpc(k_db,genint(p.value))
		when 2 then
			genpc(k_dw,genint(p.value))
		when 4 then
			genpc(k_dd,genint(p.value))
		when 8 then
			genpc(k_dq,genint(p.value))
		when 16 then
			genpc(k_dq,genint(p.range_lower))
			genpc(k_dq,genint(p.range_upper))
		else
			gerror_s("IDATA/INT:",strmode(p^.mode),p)
		esac

	fi

when j_makelist then
	q:=p^.a
	while q do
		genidata(q)
		q:=q^.nextunit
	od

when j_name then
	d:=p^.def
	case d^.nameid
	when staticid,procid,dllprocid then
		genpc((am='P' or ttsize[p^.mode]=8|k_dq|k_dd), genmemaddr_d(d))
		if offset then
			pccodex.extra:=offset
			pccodex.scale:=1
		fi
	else
		gerror("Idata &frameXXX")
	esac	
	return
when j_convert then
	genidata(p^.a)
when j_shorten then
	a:=p.a
	case ttsize[p.mode]
	when 1 then
		genpc(k_db,genint(a.value))
	when 2 then
		genpc(k_dw,genint(a.value))
	when 4 then
		genpc(k_dd,genint(a.value))
	else
		gerror_s("IDATA/SHORTEN:",strmode(p.mode),p)
	esac

when j_addrof,j_addroffirst then
	genidata(p^.a,am:'P',offset:(p.b|p.b.value|0))
else
	gerror_s("IDATA: ",jtagnames[p^.tag],p)

esac
end

proc geninitproc=
ref procrec pp
ref pstrec p
ref strec d



p:=makepst("m$initstatics")
p.owner:=getpst(stmodule)

genpc(k_procdef,genmem(p))
initstaticsindex:=definelabel()
genpc(k_procentry)

pccodex^.isglobal:=1


gencomment("-------------------------------------------------")

for i:=nmodules downto 1 do
	d:=moduletable[i].stinitproc
	if d then
		genpc(k_setalign)
		genpc(k_callproc, genmemaddr_d(d))
		setmode(ti64)
	fi
od

genpc(k_retproc)
genpc(k_procend)
gencomment("")
end

proc initframedef(ref strec d)=
end

proc freeframevar(ref strec d)=
	genpc(k_freemem,genmem_d(d))
	setmode(d.mode)
end

function getconstframeoffset(unit p)int=
unit a
ref strec d
int offset

a:=p^.a
d:=nil
offset:=0


case p^.tag
when j_addrof,j_addroffirst then
	if a^.tag=j_name then
		d:=a^.def
	fi
when j_bin then
GERROR("GETCONSTFRAMEOFFSET/BIN")
esac

if d=nil then
PRINTUNIT(P)
	gerror("Can't do @Frame var")
fi
if d^.nameid not in [frameid,paramid] then
	gerror("@ local static")
fi

return d^.offset+offset
end

proc genimports(ref strec d)=
	ref strec e

	case d.nameid
	when dllprocid then
		genpc(k_extern,genmem_d(d))


		e:=d.paramlist
		while e do
			if e.nameid=paramid then
			fi
			e:=e.nextparam
		od
		if d.varparams then
		fi

		genpc(k_endextern)
		return
	when programid, moduleid then
		e:=d.deflist
		while e do
			genimports(e)
			e:=e.nextdef
		od
	esac
end

global function genmem_u(unit p)pcl=
	return genmem(getpst(p.def))
end

global function genmem_d(ref strec d)pcl=
	return genmem(getpst(d))
end

global proc genpushmem_d(ref strec d)=
	genpc(k_pushmem,genmem(getpst(d)))
end

global function genmemaddr_d(ref strec d)pcl=
	return genmemaddr(getpst(d))
end

global proc genpushmemaddr_d(ref strec d)=
	genpc(k_pushmemaddr,genmemaddr(getpst(d)))
end

global function getpst(ref strec d)ref pstrec p=

	if d=nil then return nil fi


	if d.haspdef then			!already done
		return d.pdef
	fi

	p:=pcm_allocz(pstrec.bytes)
	p.name:=d.name

	if d.nameid=dllprocid and d.truename then
		p.name:=d.truename
	fi

	d.haspdef:=1
	d.pdef:=p

	p.owner:=getpst(d.owner)
	p.isglobal:=d.isglobal
	p.isimport:=d.nameid=dllprocid
	p.iscallback:=d.fflang=callbackff
	p.isequiv:=d.at and d.equivvar
	p.moduleno:=d.moduleno
	if p.isequiv then
		p.equiv:=getpst(d.equivvar.def)
		p.equiv.isequivtarget:=1
	fi

	p.index:=d.index
	p.isthreaded:=d.isthreaded
	p.pos:=d.pos

	p.id:=pclidtable[d.nameid]
	if p.id=zstatic_name and d.code then
		p.id:=istatic_name
	fi
	if d.nameid=dllvarid then
		p.id:=dllstatic_name
	fi

	p.mode:=ttpcltype[d.mode]
	p.size:=ttsize[d.mode]

	if ttbasetype[d.mode] in [tarray,trecord] or p.isequivtarget or p.isequiv then
		p.noreg:=1
	fi

	if pstlist then
		pstlistx.nextpst:=p
		pstlistx:=p
	else
		pstlist:=pstlistx:=p
	fi


	return p
end

global proc setmode(int m)=
	pccodex^.mode:=ttpcltype[m]
	pccodex^.size:=ttsize[m]
end

global proc setmode_u(unit p)=
	pccodex^.mode:=ttpcltype[p.mode]
	pccodex^.size:=ttsize[p.mode]

end

global function definelabel:int =
	genpc(k_label,genlabel(++labelno))
	return labelno
end

global function createfwdlabel:int =
	return ++labelno
end

global proc definefwdlabel(int lab) =
	genpc(k_label,genlabel(lab))
end

global proc genjumpl(int lab) =
	genpc(k_jump,genlabel(lab))
end

global proc genreturn(int fbytes,pbytes)=


	case currproc.nretvalues
	when 0 then
		genpc(k_retproc)
	when 1 then
		genpc(k_retfn)
		pccodex.mode:=retpmode
		pccodex.size:=retsize
	else
		genpc_n(k_retfn,currproc.nretvalues)
	esac



end

global function reversecond(int op)int=
	int genop, t
	genop:=specoptogen[op]
	t:=specoptotype[op]

	case genop
	when eq_op then genop:=ne_op
	when ne_op then genop:=eq_op
	when lt_op then genop:=ge_op
	when le_op then genop:=gt_op
	when ge_op then genop:=lt_op
	when gt_op then genop:=le_op
	esac

	op:=optypetable[genop,t]		!fresh lookup
	if op=0 then
		gerror("reversecond?")
	fi

	return op
end

global proc stacklooplabels(int a,b,c,d)=
	++loopindex
	if loopindex>maxnestedloops then
		gerror("Too many nested loops")
	fi

	loopstack[loopindex,1]:=a
	loopstack[loopindex,2]:=b
	loopstack[loopindex,3]:=c
	loopstack[loopindex,4]:=d

end

global function findlooplabel(int k,n)int=
int i

i:=loopindex-(n-1)		!point to entry
if i<1 or i>loopindex then gerror("Bad loop index") fi
return loopstack[i,k]
end

global proc genpc_sysfn(int fnindex, unit a=nil,b=nil,c=nil)=
	genpc_sysproc(fnindex, a,b,c, 1)
end

function getslots(unit p)int=
	if ttcat[p.mode]=wide_cat then return 2 fi
	return 1
end

global proc genpc_sysproc(int fnindex, unit a=nil,b=nil,c=nil, int asfunc=0)=
	int nargs:=0


	if c then evalunit(c); nargs+:=getslots(c) fi
	if b then evalunit(b); nargs+:=getslots(b) fi
	if a then evalunit(a); nargs+:=getslots(a) fi



	genpc((asfunc|k_syscallfn|k_syscallproc))
	pccodex.fnindex:=fnindex
	pccodex.nargs:=nargs
	sysfnmap[fnindex]:=1
end

proc $init=
	zero_unit.tag:=j_const
	zero_unit.mode:=ti64
	zero_unit.value:=0
	zero_unit.resultflag:=1
end

global function newframetemp(ref pstrec owner,int size)ref pstrec d=
[32]char str

	fprint @&.str,"$T#",++pcltempindex

	d:=pcm_allocz(pstrec.bytes)
	
	d.name:=pcm_copyheapstring(&.str)

	d.owner:=owner

	d.id:=frame_name
	d.mode:=tblock
	d.size:=size
CPL =SIZE

	pstlistx.nextpst:=d
	pstlistx:=d
	return d
end

global proc addframetemp(ref pstrec d)=
	pcl oldpccodex,pnew,pnext

	oldpccodex:=pccodex

	genpc(k_frame,genmem(d))
	setmode(d.mode)
	pccodex.size:=d.size

	pnew:=pccodex
	pccodex:=oldpccodex
	pccodex.nextpcl:=nil

	pnext:=pclastframe.nextpcl
	pclastframe.nextpcl:=pnew
	pnew.nextpcl:=pnext
	pclastframe:=pnew

end
=== bb_libpcl.m 23/40 ===
import msys
import clib
import mlib

import bb_pclcommon
import bb_decls

import BB_LIB

global pcl pccode,pccodex, tempentry
global int pclseqno
global pcl pclastframe
global int pcltempindex

global ref pstrec pstlist,pstlistx

global const maxparam=100
global const maxret=10
global const maxlist=100

global int retpmode
global int retsize
global int retpending					!1 means not set

strbuffer sbuffer
ref strbuffer dest=&sbuffer
int destlinestart

macro newpcl = pcm_allocz(pclrec.bytes)

proc $init=

	pclinit()
end

global proc pclinit=
	pccode:=pccodex:=nil
end

global proc genpc(int opcode, pcl p=nil)=
	static pcl lastpcl,lastlastpcl

	case opcode
	when k_label then
		if lastpcl.opcode=k_jump and lastpcl.labelno=p.labelno then
			lastpcl.opcode:=k_blank
		fi

	when k_pushmem then
		if lastpcl.opcode=k_popmem and lastpcl.def=p.def and p.def.size=8 then
			lastpcl.opcode:=k_storemem
			return
		fi


	esac

	if p=nil then
		p:=newpcl()
	fi

	p.opcode:=opcode
	p.pos:=mlineno

	if pccode then



		pccodex.nextpcl:=p
		pccodex:=p
	else
		pccode:=pccodex:=p
	fi

	case opcode
	when k_comment then
	else
		lastlastpcl:=lastpcl
		lastpcl:=pccodex
	esac

end

global proc genpc_op(int opcode, opc, pcl p=nil)=
	genpc(opcode,p)
	pccodex.opindex:=opc
end

global proc genpc_n(int opcode, n, pcl p=nil)=
	genpc(opcode,p)
	pccodex.index:=n
end

global proc genpc_cond(int opcode, cond, pcl p=nil)=
	genpc(opcode,p)
	pccodex.opindex:=cond
end

global function genint(int a,mode=ti64)pcl p=
	p:=newpcl()
	p.value:=a
	p.opndtype:=int_opnd
	p.mode:=mode
	return p
end

global proc genpushint(int a,mode=ti64)=
	genpc(k_pushint, genint(a,mode))
end

global function genassem(unit p)pcl a=
	a:=newpcl()
	a.opndtype:=assem_opnd
	a.code:=p
	return a
end

global function genint128(int128 a,int mode=ti128)pcl p=
	p:=newpcl()
	p.pvalue128:=pcm_alloc(int128.bytes)
	p.pvalue128^:=a
	p.opndtype:=int128_opnd
	p.mode:=mode
	return p
end

global function genreal(real x)pcl p=
	p:=newpcl()
	p.xvalue:=x
	p.opndtype:=real_opnd
	p.mode:=tr64
	return p
end

global proc genpushreal(real x)=
	genpc(k_pushreal,genreal(x))
end

global proc genpushreal32(real x)=
	genpc(k_pushreal32,genreal32(x))
end

global function genreal32(real x)pcl p=
	p:=newpcl()
	p.xvalue:=x
	p.opndtype:=real32_opnd
	p.mode:=tr32
	return p
end

global function genstring(ichar s)pcl p=
	p:=newpcl()
	p.svalue:=pcm_copyheapstring(s)
	p.opndtype:=string_opnd
	p.mode:=trefchar
	return p
end

global proc genpushstring(ichar s)=
	genpc(k_pushstring,genstring(s))
end


global function genmetastring(ichar s)pcl p=
	p:=newpcl()
	p.svalue:=pcm_copyheapstring(s)
	p.opndtype:=metastring_opnd
	return p
end

global function genlabel(int a)pcl p=
	p:=newpcl()
	p.labelno:=a
	p.opndtype:=label_opnd
	return p
end

global function genmem(ref pstrec d)pcl p=
	p:=newpcl()
	p.def:=d
	p.opndtype:=mem_opnd
	p.mode:=d.mode
	p.size:=d.size
	return p
end

global function genmemaddr(ref pstrec d)pcl p=
	p:=newpcl()
	p.def:=d
	p.opndtype:=memaddr_opnd
	p.mode:=tu64
	p.size:=8
	return p
end

global proc gencomment(ichar s)=
	if not debugmode then return fi
	genpc(k_comment,genmetastring(s))
end

global proc genblank=
	if not debugmode then return fi
	genpc(k_blank)
end

global function makepst(ichar name)ref pstrec p=

	p:=pcm_allocz(pstrec.bytes)
	p.name:=name

	p.id:=proc_name

	if pstlist then
		pstlistx.nextpst:=p
		pstlistx:=p
	else
		pstlist:=pstlistx:=p
	fi

	return p
end

global function writepclcode(ichar caption)ref strbuffer=
[256]char str
[32]char str2
[32]char str3
pcl p
ref pstrec d,e

gs_str(dest,"PROC ")
gs_strln(dest,caption)
gs_strln(dest,"------------------------------------------------------")
destlinestart:=dest.length

p:=pccode

while p do
	writepcl(p)
	p:=p^.nextpcl
	destlinestart:=dest.length
od

gs_strln(dest,"------------------------------------------------------")


return dest
end

global proc printpst(ref strbuffer dest)=
[256]char str
[32]char str2
[32]char str3
ref pstrec d,e

if not fshowpst then return fi
GS_STRLN(DEST,"PROC")
GS_STRLN(DEST,"PST")
d:=pstlist
while d do
	if d.id then
		strcpy(&.str2,pstnames[d.id])
		str2[strlen(&.str2)-4]:=0
	else
		str2[1]:=0
	fi
	str3[1]:=0
	e:=d.owner
	while e do
		strcat(&.str3,"- ")
		e:=e.owner
	od


	fprint @&.str,"    ## # (in #) #:# # refs:#",
		&.str3,d.name:"jl20p-", &.str2:"jl7",
		(d.owner|d.owner.name|""), ttname[d.mode],d.size,
		(d.addrof|"& used"|""),d.nrefs

	gs_strln(dest,&.str)
	d:=d.nextpst
od
end

proc writepcl(pcl p)=
	gs_leftint(dest,p.lineno,4)
	gs_str(dest,"--")
	strpcl(p)
	gs_line(dest)
end

proc psstr(ichar s)=
	gs_str(dest,s)
end

proc psint(int a)=
	gs_str(dest,strint(a))
end

proc psassign=
	gs_str(dest,":=")
end

proc pstabto(int n)=
	int col:=dest.length-destlinestart
	while n>col do psstr(" "); ++col od
end

proc convertstring(ichar s, t)=		!CONVERTSTRING
int c

while c:=s++^ do
	switch c
	when '"' then
		t++^:='\\'
		t++^:='"'
	when 10 then
		t++^:='\\'
		t++^:='n'
	when 13 then
		t++^:='\\'
		t++^:='c'
	when 9 then
		t++^:='\\'
		t++^:='t'
	when '\\' then
		t++^:='\\'
		t++^:='\\'
	when 7,8,26,27 then
		t++^:='<'
		t++^:=c/10+'0'
		t++^:=(c rem 10)+'0'
		t++^:='>'
	else
		t++^:=c
	endswitch
od
t^:=0
end

proc strlabel(int labelno,colon=0)=
	psstr("L")
	psint(labelno)
	if colon then
		psstr(":")
	fi
	psstr(" ")
end

proc psopnd(pcl p)=
	psstr(stropnd(p))
end

proc pclerror(ichar mess)=
	println "LIBPCL Error:",mess
	stop 1
end

global proc strpcl(pcl p)=
[256]char pmodestr
[256]char str
int opcode,defused

const showformatted=1

opcode:=p.opcode


case opcode
when k_label then
	strlabel(p.labelno,1)
	return
when k_comment then
	psstr("!")
	psstr(p.svalue)
	return
when k_blank then
	return
when k_procdef then
	psstr("Proc ")
	psstr(p.def.name)
	psstr(":")
	return

when k_procend then
	psstr("End")
	return


esac

psstr("    ")
strcpy(&.str,pclnames[opcode]+2)


case p.opcode
when k_jumpcc, k_setcc,k_jumpfalse, k_jumptrue then
	if p.opindex then
		strcat(&.str,".")
		strcat(&.str,specopnames[p.opindex]+3)
	fi
when k_syscallproc, k_syscallfn then
	strcat(&.str,".")
	if p.fnindex then
		strcat(&.str,sysfnnames[p.fnindex]+6)
	fi

when k_pushmem,k_popmem,k_storemem then
	strcat(&.str,".")
	strcat(&.str,typecatnames[ttcat[p.mode]])

elsif p.opindex then

	strcat(&.str,".")
	strcat(&.str,specopnames[p.opindex]+3)

esac
SKIP::


gs_leftstr(dest,&.str,26)

psstr(stropnd(p))

PSTABTO(60)


if p.mode then
	if ttcat[p.mode]=block_cat then
		fprint @&.pmodestr,"(#:#)",ttname[p.mode],p.size
	else
		fprint @&.pmodestr,"(#)",ttname[p.mode]
	fi

	if p.oldmode then
		fprint @&.str,"(#)",ttname[p.oldmode]
		strcat(&.pmodestr,&.str)
	fi

else
	pmodestr[1]:=0
fi

psstr(&.pmodestr)

case p.opcode
when k_callproc, k_callfn, k_callprocptr, k_callfnptr, k_setalign,
	k_syscallproc, k_syscallfn then
	psstr(" Nargs:")
	psint(p.nargs)
	psstr(" Nvar:")
	psint(p.nvariadics)

	if p.nmult then
		psstr(" Mult:(")
		for i to p.nmult do
			psstr(typecatnames[p.retcats[i]])
			psstr(" ")
		od
		psstr(")")
	fi

esac

case p.opcode
when k_bin, k_binto, k_addtoptr, k_suboffset, k_pushptr, k_slice,k_dq,
		k_storeptr, k_popptroff, k_pushptroff, k_storeptroff, k_popptroff then
	psstr(" Scale:")
	psint(p.scale)
	psstr(" Extra:")
	psint(p.extra)
esac

case p.opcode
when k_setretmult then
	psstr(" N:")
	psint(p.index)
esac

if p.isglobal then psstr(" Isglobal") fi
if p.isvariadic then psstr(" Isvariadic") fi
end

global function stropnd(pcl p)ichar=
	static[512]char str

	if p=nil then
		return ""
	fi

	case p.opndtype
	when int_opnd then
		return strint(p.value)
	when real_opnd, real32_opnd then
		return strreal(p.xvalue)

	when string_opnd then
		if strlen(p.svalue)<str.len/2 then
			strcpy(&.str,"""")
			convertstring(p.svalue,&.str+1)
			strcat(&.str,"""")
		else
			return "<Long str>"
		fi

	when metastring_opnd then
		fprint @&.str,"{#}",p.svalue

	when mem_opnd then
		if p.def.size>=8 then
			fprint @&.str,"#",p.def.name
		else
			fprint @&.str,"#:",p.def.name,ttname[p.mode]
		fi


	when memaddr_opnd then
		fprint @&.str,"&#",p.def.name

	when label_opnd then
		fprint @&.str,"L# ",p.labelno

	when no_opnd then
		return ""
	when assem_opnd then
		return ""
	when int128_opnd then
		print @&.str,p.pvalue128^

	else
CPL OPNDNAMES[P.OPNDTYPE]
		return "<PCLOPND?>"
	esac

	return &.str
end

=== bb_blockpcl.m 24/40 ===
import mlib
import clib
import oslib

import bb_decls
import bb_support
import bb_tables
import bb_lib
import bb_libpcl
import bb_diags
import bb_pclcommon
import bb_genpcl

const kjumpt = 1		!pseudo ops used for conditional jump logic
const kjumpf = 0

const dodotchains=1

const maxnestedloops	= 50

const maxparams=100

const maxswitchrange=500
const maxcases=maxswitchrange

const maxcasedepth=20
[maxcasedepth]unit casestmt
[maxcasedepth]int caseelse
int casedepth

ref[]int sw_labeltable			!set from do-switch
ref[]int sw_valuetable
int sw_lower
int sw_ncases					!1..n for serial switch; 0 for simple
byte sw_defaultseen				!starts at 0, set to 1 when default: seen
int sw_defaultlabel
int sw_breaklabel

int maxreg=0

global proc evalunit(unit p)=
	unit a,b
	ref strec d
	ref[]int32 pmult

	if p=nil then return fi
	mlineno:=p^.pos

	a:=p^.a
	b:=p^.b


	switch p^.tag
	when j_const         then do_const(p)
	when j_null          then
	when j_name          then do_name(p)
	when j_block,j_stmtblock then
				         do_block(p)
	when j_callproc      then do_callproc(p,a,b,0)
	when j_return        then do_return(p,a)
	when j_returnmult    then do_returnmult(p,a)
	when j_assign        then do_assign(p,a,b)
	when j_to            then do_to(p,a,b)
	when j_if            then do_if(p,a,b,p.c,0)
	when j_longif        then do_longif(p,a,b,0)
	when j_forup         then do_for(p,a,b,p.c,0)
	when j_fordown       then do_for(p,a,b,p.c,1)
	when j_forall        then do_forall(p,a,b,p.c,0)
	when j_forallrev     then do_forall(p,a,b,p.c,1)
	when j_while         then do_while(p,a,b)
	when j_repeat        then do_repeat(p,a,b)
	when j_goto          then do_goto(a)
	when j_labeldef      then do_labeldef(p)
	when j_restart       then do_exit(p,1)
	when j_redo          then do_exit(p,2)
	when j_next          then do_exit(p,3)
	when j_exit          then do_exit(p,4)
	when j_do            then do_do(p,a,b)
	when j_case          then do_case(p,a,b,p.c,0,0)
	when j_docase        then do_case(p,a,b,p.c,1,0)
	when j_switch        then do_switch(p,a,b,p.c,0,0)
	when j_doswitch      then do_switch(p,a,b,p.c,1,0)
	when j_recase        then do_recase(p,a)
	when j_swap          then do_swap(p,a,b)
	when j_select        then do_select(p,a,b,p.c,0)
	when j_print,j_println then
		do_print(p,a,b)
	when j_fprint,j_fprintln, j_cprint, j_cprintln then
		do_print(p,a,b)
	when j_read	        then do_read(p,a)
	when j_readln        then do_readln(a)
	when j_stop          then do_stop(p,a)
	when j_eval          then
		evalunit(a)
		genpc(k_eval)
	when j_andl          then do_andl(p,a,b)
	when j_orl           then do_orl(p,a,b)

	when j_makerange     then GENCOMMENT("MAKERANGE")

	when j_callfn        then do_callproc(p,a,b,1)

	when j_cmp           then do_setcc(p,a,b)
	when j_cmpchain      then do_setccchain(p,a)

	when j_bin           then do_bin(p,a,b)



	when j_index         then do_index(p,a,b)
	when j_slice         then do_slice(a,b)
	when j_makeslice     then
		evalunit(b)
		evalunit(a)
		genpc(k_makeslice)
		setmode(tu128)

	when j_dotindex      then do_dotindex(p,a,b)
	when j_dotslice      then do_dotslice(p,a,b)
	when j_dot           then do_dot(p)
	when j_ptr           then do_ptr(p,a)
	when j_addrof        then evalref(a,b)
	when j_addroffirst   then evalref(a)
	when j_convert       then do_convert(p,a)
	when j_typepun       then do_typepun(p,a)
	when j_shorten       then do_shorten(p,a)

	when j_unary         then do_unary(p,a)

	when j_notl          then do_notl(p,a)
	when j_istruel       then do_istruel(p,a)

	when j_incr          then
		if p.genop in [incr_op, decr_op] then
			do_incr(p,a)
		else
			do_incrload(p,a)
		fi
	when j_binto         then do_binto(p,a,b)
	when j_unaryto       then do_unaryto(p,a)
	when j_syscall then
		do_syscall(p,a)

	when j_assem         then
		genpc(k_assem,genassem(p))
		setmode_u(p)

	when j_cvlineno      then
		genpc(k_pushint,genint(p.lineno iand 16777215))

	else
CPL "UNSUPPORTED TAG: ",JTAGNAMES[P^.TAG],
	MLINENO IAND 16777215, SOURCEFILENAMES[MLINENO>>24]
		gencomment("Unimplemented:")
		gencomment(jtagnames[p.tag])
		return

	endswitch


	if p.mode<>tvoid and not p.resultflag then
		case p.tag
		when j_assign, j_callproc, j_syscall then

		else
			genpc(k_free)
			setmode_u(p)
		esac
	fi
end

proc evalref(unit p, q=nil)=
	unit a,b,c
	a:=p.a
	b:=p.b
	c:=p.c
	mlineno:=p^.pos

	switch p^.tag
	when j_name then
		genpushmemaddr_d(p.def)
		if q then					!addrof may have optional byte offset
			genpushint(q.value)
			genpc_op(k_bin, op_add_refoff)
			pccodex.scale:=1
		fi
	when j_index then
		do_indexref(a,b)

	when j_dot then
		do_dotref(p)

	when j_ptr then
		evalunit(p.a)

	else
		case p^.tag
		when j_if then
			do_if(p,a,b,c,1)
		when j_longif then
			do_longif(p,a,b,1)
		else
			PRINTUNIT(P)
			gerror("evalref")
		esac
	end switch
end

proc evallv(unit p)=
	evalref(p)
end

global proc evalunitx(unit p, int isref) =
	if isref then
		evalref(p)
	else
		evalunit(p)
	fi
end

global proc evalblock(unit p) =
	evalunit(p)
end

proc evalarray(unit p)=
	if ttbasetype[p.mode]=tslice then
		evalunit(p)
		genpc_op(k_unary, op_sliceptr_slice)
		setmode(tu64)
	elsif p.mode=trefchar then
		evalunit(p)
	else
		evalref(p)
	fi

end

proc do_block(unit p)=
	unit a:=p.a

	while a do
		evalunit(a)
		a:=a^.nextunit
	od
end

proc genjumpcond(int opc,unit p,int lab)=
unit q,r,s
int lab2,i

q:=p.a
r:=p.b

switch p^.tag
when j_andl then
	case opc
	when kjumpf then
		genjumpcond(kjumpf,q,lab)
		genjumpcond(kjumpf,r,lab)
	when kjumpt then
		lab2:=createfwdlabel()
		genjumpcond(kjumpf,q,lab2)
		genjumpcond(kjumpt,r,lab)
		definefwdlabel(lab2)
	esac

when j_orl then
	case opc
	when kjumpf then
		lab2:=createfwdlabel()
		genjumpcond(kjumpt,q,lab2)
		genjumpcond(kjumpf,r,lab)
		definefwdlabel(lab2)
	when kjumpt then
		genjumpcond(kjumpt,q,lab)
		genjumpcond(kjumpt,r,lab)
	esac

when j_notl then
	case opc
	when kjumpf then
		genjumpcond(kjumpt,q,lab)
	when kjumpt then
		genjumpcond(kjumpf,q,lab)
	esac

when j_istruel then
	evalunit(q)

	genpc_op((opc=kjumpt|k_jumptrue|k_jumpfalse),p.opindex,genlabel(lab))
	setmode_u(q)

when j_block then
	while q and q^.nextunit do
		evalunit(q)
		q:=q^.nextunit
	od
	genjumpcond(opc,q,lab)

when j_cmp then

	gcomparejump(opc,p.opindex,q,r,lab)

when j_inrange then
	evalunit(q)
	evalunit(r.a)
	evalunit(r.b)
	genpc((opc=kjumpf|k_jumpnotinrange|k_jumpinrange),genlabel(lab))
	setmode_u(q)

when j_inset then
	s:=r.a
	if s=nil then
		gerror("empty set")
	fi

	if opc=kjumpf then
		lab2:=createfwdlabel()
		evalunit(q)

		while s do
			evalunit(s)
			s:=s.nextunit
			if s then
				genpc(k_setjumpeq,genlabel(lab2))
			else
				genpc(k_setjumpne,genlabel(lab))
			fi
			setmode_u(q)
		od
		definefwdlabel(lab2)
	else
		evalunit(q)

		while s do
			evalunit(s)
			s:=s.nextunit
			genpc((s|k_setjumpeq|k_setjumpeqx),genlabel(lab))
			setmode_u(q)
		od
	fi

when j_cmpchain then
	r:=q.nextunit
	i:=1
	if opc=kjumpf then
		while r do
			evalunit(q)
			evalunit(r)
			genpc_cond(k_jumpcc,reversecond(p.cmpopindex[i]),genlabel(lab))
			setmode_u(q)
			++i
			q:=r
			r:=r.nextunit
		od
	
	else
		lab2:=createfwdlabel()
		while r do
			evalunit(q)
			evalunit(r)
			if r.nextunit then
				genpc_cond(k_jumpcc,reversecond(p.cmpopindex[i]),genlabel(lab2))
			else
				genpc_cond(k_jumpcc,p.cmpopindex[i],genlabel(lab))
			fi
			setmode_u(q)
			++i
			q:=r
			r:=r.nextunit
		od
		definefwdlabel(lab2)
	fi
else			!other, single expression
	evalunit(p)
	if p.mode not in [ti64,tu64] then gerror("jumptrue/not i64") fi

	genpc_op((opc=kjumpt|k_jumptrue|k_jumpfalse),op_istruel_i64,genlabel(lab))
	setmode(ti64)
endswitch
end

proc gcomparejump(int jumpopc,int cond,unit lhs,rhs,int lab)=
	if jumpopc=kjumpf then			!need to reverse condition
		cond:=reversecond(cond)		!eqop => neop, etc
	fi

	evalunit(lhs)
	evalunit(rhs)

	genpc_cond(k_jumpcc,cond,genlabel(lab))
	setmode_u(lhs)
end

proc genjumpl(int lab)=
	genpc(k_jump,genlabel(lab))
end

proc unimpl(ichar mess)=
	gerror_s("Unimplemented: #",mess)
end

proc do_const(unit p) =
	int mode:=p.mode

	if ttisinteger[mode] then
		if ttsize[mode]<16 then
			genpushint(p.value,mode)
		else
			genpc(k_pushint128, genint128(p.value128,mode))
		fi
	elsif ttisreal[mode] then
		if ttsize[mode]=4 then
			genpushreal32(p.xvalue)
		else
			genpushreal(p.xvalue)
		fi

	elsif ttisref[mode] then
		if p.isastring then
			genpushstring(p.svalue)
		else
			genpushint(p.value)
		fi
	else
		gerror("do_const")
	fi
end

proc do_null(unit p,a,b) =
	unimpl("do_null")
end

proc do_name(unit p)=
	ref strec d

	d:=p.def
	case d.nameid
	when procid,dllprocid then
		genpushmemaddr_d(d)
	when labelid then
		if d^.index=0 then
			d^.index:=++labelno
		fi
		genpc(k_jump, genlabel(d^.index))
		p^.resultflag:=0
		p.mode:=tvoid
	else
		if ttcat[p.mode]=block_cat then
			genpushmemaddr_d(d)
		else
			genpushmem_d(d)
		fi
		setmode(getmemmode(p))
	esac
end

proc do_stop(unit p,a) =
	if a then
		genpc_sysproc(sysfn_stop,a)
	else
		genpc_sysproc(sysfn_stop,pzero)
	fi
end

proc do_andl(unit p,a,b) =
	int labfalse, labend

	genpc(k_startmult)

	labfalse:=createfwdlabel()
	labend:=createfwdlabel()

	genjumpcond(kjumpf,a,labfalse)
	genjumpcond(kjumpf,b,labfalse)

	genpushint(1)
	genpc(k_resetmult)

	genjumpl(labend)

	definefwdlabel(labfalse)
	genpushint(0)
	genpc(k_endmult)

	definefwdlabel(labend)
end

proc do_orl(unit p,a,b) =
	int labtrue, labfalse, labend

	genpc(k_startmult)
	labtrue:=createfwdlabel()
	labfalse:=createfwdlabel()
	labend:=createfwdlabel()

	genjumpcond(kjumpt,a,labtrue)
	genjumpcond(kjumpf,b,labfalse)

	definefwdlabel(labtrue)
	genpushint(1)
	genpc(k_resetmult)
	genjumpl(labend)

	definefwdlabel(labfalse)
	genpushint(0)
	genpc(k_endmult)

	definefwdlabel(labend)

end

proc do_notl(unit p,a) =
	evalunit(a)
	genpc_op(k_unary, p.opindex)
	setmode(ti64)
end

proc do_istruel(unit p,a) =
	evalunit(a)
	if islogical(a) then
		return
	fi
	genpc_op(k_unary, p.opindex)
	setmode(ti64)
end

proc do_typepun(unit p, a) =
	evalunit(a)
	setmode_u(a)
	if a.mode=p.mode then return fi
	genpc(k_typepun)
	setmode(p.convmode)
end

proc do_shorten(unit p, a) =
	evalunit(a)
end

global function islogical(unit p)int=			!ISLOGICAL
case p^.tag
when j_istruel,j_notl,j_andl,j_orl,j_xorl then
	return 1
esac
return 0
end

proc do_assign(unit p,a,b) =
	unit c
	ref strec d
	int offset


	if a.tag<>j_makelist and b.tag=j_makelist then
		if not p.resultflag then
			do_assignblock(p,a,b)		!(avoids pushing/popping block data)
			return
		fi
	fi

	if a.tag=j_makelist then
		if p.resultflag then gerror("multass/store") fi
		do_multassign(a,b)
		return
	elsif b.tag=j_callfn and ttbasetype[b.mode]=ttuple then
		do_multassign(a,b)
		return
	fi

	case a^.tag
	when j_index then

		do_storeindex(p,a.a,a.b,b)
		return
	when j_slice then
GERROR("ASS/SLICE")

	when j_dot then
		do_storedot(a,a.b,b)
		return
	esac

	switch a^.tag
	when j_name then
		evalunit(b)
		genpc((p.resultflag|k_storemem|k_popmem), genmem_u(a))
	when j_ptr then
		evalunit(b)
		evalref(a)

		if pccodex.opcode=k_bin and pccodex.opindex=op_add_refoff then 
			pccodex.opcode:=(p.resultflag|k_storeptroff|k_popptroff)
			pccodex.opindex:=0
		else
			genpc((p.resultflag|k_storeptr|k_popptr))
		fi
		setmode(getmemmode(a))

	when j_dotindex then
		evalunit(b)
		evalref(a.a)
		evalunit(a.b)
		genpc((p.resultflag|k_storedotindex|k_popdotindex))
		setmode_u(a.a)
		return
	when j_dotslice then
		evalunit(b)
		evalref(a.a)
		evalunit(a.b.a)
		evalunit(a.b.b)
		genpc((p.resultflag|k_storedotslice|k_popdotslice))
		setmode_u(a.a)
		return
	else
		cpl jtagnames[a^.tag]
		gerror("Can't assign")
	end switch

	setmode_u(a)

end

proc do_bin(unit p,a,b) =
	int offset

	evalunit(a)

	if pccodex.opcode=k_bin and pccodex.opindex=op_add_refoff and
			p.opindex in [op_add_refoff,op_sub_refoff] and
		ttisref[a.mode] and ttisinteger[b.mode] and b.tag=j_const then
		offset:=ttsize[tttarget[a.mode]]*b.value
		if p.opindex=op_add_refoff then
			pccodex.extra+:=offset
		else
			pccodex.extra-:=offset
		fi
		return
	fi

	evalunit(b)

	genpc_op(k_bin, p.opindex)
	setmode_u(p)

	if ttisref[a.mode] and ttisinteger[b.mode] then
		pccodex.scale:=ttsize[tttarget[a.mode]]
	fi

	if p.opindex=op_sub_ref then
		pccodex.scale:=ttsize[tttarget[a.mode]]
	fi
end

proc do_setcc(unit p,a,b) =
	evalunit(a)
	evalunit(b)
	genpc_cond(k_setcc, p.opindex)
	setmode_u(a)
end

proc do_setccchain(unit p,q) =
	int lab1,lab2,i
	unit r

	lab1:=createfwdlabel()
	lab2:=createfwdlabel()

	r:=q.nextunit
	i:=1

	genpc(k_startmult)

	while r do
		evalunit(q)
		evalunit(r)
		genpc_cond(k_jumpcc,reversecond(p.cmpopindex[i]),genlabel(lab1))
		setmode_u(q)
		++i
		q:=r
		r:=r.nextunit
	od

	genpushint(1)
	genpc(k_resetmult)
	genpc(k_jump, genlabel(lab2))

	definefwdlabel(lab1)
	genpushint(0)
	genpc(k_endmult)
	definefwdlabel(lab2)
end

proc do_addoffset(unit p,a,b) =
	evalunit(a)
	evalunit(b)
	genpc_op(k_bin, op_add_refoff)

	pccodex.scale:=ttsize[tttarget[a.mode]]
	setmode(tref)
end

proc do_suboffset(unit p,a,b) =
	evalunit(a)
	evalunit(b)
	genpc(k_suboffset)
	pccodex.scale:=ttsize[tttarget[a.mode]]

	setmode(tref)
end

proc do_binto(unit p,a,b)=
	evallv(a)
	evalunit(b)

	genpc_op(k_binto,p.opindex)
	setmode_u(a)

	if ttisref[a.mode] and ttisinteger[b.mode] then
		pccodex.scale:=ttsize[tttarget[a.mode]]
	fi

end

proc do_unary(unit p,a) =
	evalunit(a)

	genpc_op(k_unary, p.opindex)
	setmode_u(p)
	if p.opindex=op_upb_slice then
		pccodex.extra:=ttlower[a.mode]
	fi

end

proc do_unaryto(unit p,a)=
	evallv(a)

		genpc_op(k_unaryto,p.opindex)
	setmode_u(a)
end

proc do_ptr(unit p,a)=

	evalunit(a)

	if ttcat[p.mode]=block_cat then
		return
	fi

	if pccodex.opcode=k_bin and pccodex.opindex=op_add_refoff then 
		pccodex.opcode:=k_pushptroff
		pccodex.opindex:=0
	else
		genpc(k_pushptr)
	fi
	setmode(getmemmode(p))
end

proc do_labeldef(unit p)=
	ref strec d
	[256]char str

	d:=p.def
	if d.index=0 then
		d.index:=++labelno
	fi
	print @&.str,d.name,,"::"
	gencomment(&.str)
	genpc(k_label,genlabel(d.index))
end

proc do_goto(unit a)=
	ref strec d

	case a.tag
	when j_name then
		d:=a.def
		if d.index=0 then
			d.index:=++labelno
		fi
		genpc(k_jump, genlabel(d.index))

	else
		gerror("goto ptr?")
	esac
end

proc do_do(unit p,a,b) =
	int lab_abc,lab_d

	lab_abc:=definelabel()
	lab_d:=createfwdlabel()

	stacklooplabels(lab_abc, lab_abc, lab_abc, lab_d)

	evalblock(a)

	genjumpl(lab_abc)
	definefwdlabel(lab_d)
	--loopindex
end

proc do_to(unit p,a,b) =
	unit cvar
	int lab_a,lab_b,lab_c,lab_d,count

	cvar:=p.c

	lab_a:=definelabel()
	a.mode:=ti64

	evalunit(a)
	genpc(k_popmem,genmem_u(cvar))
	setmode(ti64)

	lab_b:=createfwdlabel()
	lab_c:=createfwdlabel()
	lab_d:=createfwdlabel()
	stacklooplabels(lab_a,lab_b,lab_c,lab_d)

	if a.tag<>j_const then			!assume const limit is non-zero
		evalunit(cvar)
		evalunit(pzero)

		genpc_cond(k_jumpcc,op_le_i64,genlabel(lab_d))
		setmode(ti64)

	else
		count:=a.value
		if count<=0 then
			genjumpl(lab_d)
		fi
	fi

	definefwdlabel(lab_b)
	evalblock(b)			!main body

	definefwdlabel(lab_c)

	genpc(k_to,genlabel(lab_b))
	setmode(ti64)
	genpc(k_opnd,genmem_u(cvar))
	setmode(ti64)

	definefwdlabel(lab_d)
	--loopindex
end

proc do_while(unit p,pcond,pbody) =
	int lab_b,lab_c,lab_d

	lab_b:=createfwdlabel()
	lab_c:=createfwdlabel()
	lab_d:=createfwdlabel()

	stacklooplabels(lab_c, lab_b, lab_c, lab_d)

	genjumpl(lab_c)		!direct to condition code which is at the end

	definefwdlabel(lab_b)

	evalblock(pbody)

	definefwdlabel(lab_c)

	docond(kjumpt,pcond,lab_b)
	definefwdlabel(lab_d)
	--loopindex
end

proc do_repeat(unit p,a,b) =
	int lab_ab, lab_c, lab_d

	lab_ab:=definelabel()
	lab_c:=createfwdlabel()
	lab_d:=createfwdlabel()

	stacklooplabels(lab_ab, lab_ab, lab_c, lab_d)

	evalblock(a)

	definefwdlabel(lab_c)

	unless b^.tag=j_const and b^.value=0 then
		docond(kjumpf,b,lab_ab)
	end

	definefwdlabel(lab_d)
	--loopindex
end

proc do_exit(unit p,int k) =
	int n,index

	index:=p^.index
	if index=0 then index:=loopindex fi

	n:=findlooplabel(k,index)
	if n=0 then
		gerror("Bad exit/loop index",p)
	else
		genjumpl(n)
	fi
end

proc do_if(unit p,a,b,c, int isref) =
	int lab1,lab2,ismult

	ismult:=p.mode<>tvoid
	if ismult and b.tag in [j_const, j_name] and c.tag in [j_const,j_name] then
		case a.tag
		when j_cmp then
			if a.opindex in [op_eq_i64, op_ne_i64,
				 op_lt_i64, op_le_i64, op_lt_i64, op_le_i64] then
				evalunit(c)
				evalunit(b)
				evalunit(a.a)
				evalunit(a.b)
				genpc_cond(k_selectcc, a.opindex)
				setmode_u(p)
				return
			fi
		when j_istruel then
			if a.opindex=op_istruel_i64 then
				evalunit(c)
				evalunit(b)
				evalunit(a.a)
				genpc_cond(k_selecttrue,a.opindex)
				setmode_u(p)
				return
			fi
		esac
	fi

	if ismult then genpc(k_startmult) fi

	lab1:=createfwdlabel()

	docond(kjumpf,a,lab1)

	evalunitx(b,isref)
	if ismult then genpc(k_resetmult) fi

	if c then
		lab2:=createfwdlabel()			!label past else part
		genjumpl(lab2)
		definefwdlabel(lab1)
		evalunitx(c,isref)
		if ismult then genpc(k_endmult) fi
		definefwdlabel(lab2)
	else
		definefwdlabel(lab1)
	fi
end

proc do_longif(unit p,a,b, int isref) =
	int labend,i,lab2,ismult
	unit pcond

	labend:=createfwdlabel()
	ismult:=p.mode<>tvoid

	pcond:=a
	i:=0
	if ismult then genpc(k_startmult) fi

	while pcond do
		++i
		lab2:=createfwdlabel()

		docond(kjumpf,pcond.a,lab2)

		evalunitx(pcond.b,isref)
		if ismult then genpc(k_resetmult) fi

		if pcond.nextunit or b then
			genjumpl(labend)
		fi
		definefwdlabel(lab2)
		pcond:=pcond.nextunit
	od

	if b then
		evalunitx(b,isref)
		if ismult then genpc(k_endmult) fi
	fi
	definefwdlabel(labend)
end

proc do_return(unit p,a) =
	if a then
		evalunit(a)

		if ttcat[a.mode]=wide_cat then
			genpc_n(k_setretmult,2)
		else
			genpc(k_setret)
		fi
		setmode_u(a)
	fi
	genjumpl(retindex)
end

proc do_returnmult(unit p,a) =
	[maxparams]unit params
	unit q
	int nparams

	q:=a
	nparams:=0
	while q do
		if nparams>=maxparams then gerror("Mult?") fi
		params[++nparams]:=q
		q:=q.nextunit
	od

	for i:=nparams downto 1 do
		evalunit(params[i])
	od

	genpc_n(k_setretmult, nparams)

	genjumpl(retindex)
	p.resultflag:=1
end

proc do_callproc(unit p,a,b,int isfn) =
	[maxparams]unit paramlist
	int nparams,nmult,ffi,isptr,nslots,nvariadics, blockret, nret
	ref strec d
	ref pstrec dtemp
	ref[]int32 pmult
	unit q

	isptr:=0
	case a.tag
	when j_name then
		d:=a.def
	when j_ptr then
		d:=ttnamedef[a.mode]
		isptr:=1
	else
		gerror("call/not ptr")
	esac

	nparams:=0
	nslots:=0
	nvariadics:=0
	blockret:=0
	ffi:=0

	if d.fflang in [clangff,windowsff] then
		ffi:=1
		if ttcat[p.mode]=block_cat then
			blockret:=1
		fi
	fi

	q:=b
	while q do
		++nslots
		if nparams>=maxparams then gerror("maxparams") fi
		paramlist[++nparams]:=q
		if ffi and d.varparams and nparams>=d.varparams and nparams<=4 and nvariadics=0 then
			nvariadics:=nparams
		fi
		if ttcat[q.mode]=wide_cat then
			++nslots
		fi
		q:=q.nextunit
	od

	if blockret then ++nslots fi

	genpc(k_setalign)
	pccodex.nargs:=nslots

	for i:=nparams downto 1 do
		evalunit(paramlist[i])
	od

	if blockret then
		dtemp:=newframetemp(nil,ttsize[p.mode])		
		addframetemp(dtemp)
		genpc(k_pushmemaddr, genmemaddr(dtemp))
	fi

	if not isptr then
		genpc_n((isfn|k_callfn|k_callproc), nslots, genmemaddr_d(d))
	else
		evalunit(a.a)
		genpc_n((isfn|k_callfnptr|k_callprocptr), nslots)
	fi
	pccodex.nvariadics:=nvariadics
	setmode(getmemmode(p))

	if d.nretvalues>1 then
		nret:=d.nretvalues
		pmult:=ttmult[d.mode]

		pccodex.nmult:=nret
		for i to nret do
			pccodex.retcats[i]:=ttcat[pmult[i]]
		od
	fi
end

proc do_print(unit p,a,b) =
	unit q,r,fmt
	int m, fn, needprintend

	if a then
		needprintend:=1
		if ttbasetype[a^.mode]<>tref then gerror("@dev no ref") fi
		case ttbasetype[tttarget[a^.mode]]
		when tvoid then
			genpc_sysproc(sysfn_print_startfile,a)
		when tc8 then
			genpc_sysproc(sysfn_print_startstr,a)
		when tref then
			genpc_sysproc(sysfn_print_startptr,a)
		else
			gerror("@dev?")
		esac
	else
		needprintend:=0
	fi

	q:=b

	case p^.tag
	when j_fprint,j_fprintln then
		if not needprintend then
			needprintend:=1
			genpc_sysproc(sysfn_print_startcon)
		fi

		if ttbasetype[q^.mode]<>tref or ttbasetype[tttarget[q^.mode]]<>tc8 then
			gerror("string expected")
		fi
		genpc_sysproc(sysfn_print_setfmt,q)
		q:=p.c
	when j_cprint, j_cprintln then
		if needprintend then gerror("cprint@") fi
		needprintend:=1
		genpc_sysproc(sysfn_print_startcon)

	esac

	while q do
		case q^.tag
		when j_fmtitem then
			fmt:=q.b
			r:=q^.a
			m:=r^.mode
		when j_nogap then
			genpc_sysproc(sysfn_print_nogap)
			q:=q^.nextunit
			next
		else
			fmt:=nil
			r:=q
			m:=q^.mode
		esac

		switch ttbasetype[m]
		when ti64 then
			fn:=sysfn_print_i64
			if not fmt then fn:=sysfn_print_i64_nf fi
		when tu64 then
			fn:=sysfn_print_u64
		when tr32 then
			fn:=sysfn_print_r32
		when tr64 then
			fn:=sysfn_print_r64
		when ti128 then
			fn:=sysfn_print_i128
		when tu128 then
			fn:=sysfn_print_u128
		when tref then
			if tttarget[m]=tc8 or tttarget[m]=tarray and tttarget[tttarget[m]]=tc8 then
				fn:=sysfn_print_str
				if not fmt then fn:=sysfn_print_str_nf fi
			else
				fn:=sysfn_print_ptr
				if not fmt then fn:=sysfn_print_ptr_nf fi
			fi
		when tarray then
			GERROR("PRINTARRAY")
			q:=q^.nextunit
		when trecord then
			GERROR("PRINTRECORD")
		when tslice then
			if tttarget[m]=tc8 then
				fn:=sysfn_print_strsl
			else
				gerror("PRINTSLICE")
			fi

		when tc64 then
			fn:=sysfn_print_c8

		else
			gerror_s("PRINT/T=#",strmode(m))
		end switch

		case fn
		when sysfn_print_i64_nf, sysfn_print_str_nf, sysfn_print_ptr_nf then
			genpc_sysproc(fn, r)
		else
			genpc_sysproc(fn, r, (fmt|fmt|pzero))
		esac

		q:=q^.nextunit
	od

	case p^.tag
	when j_println,j_fprintln then
		genpc_sysproc(sysfn_print_newline)
	esac
	if needprintend then
		genpc_sysproc(sysfn_print_end)
	fi

end

proc do_incr(unit p,a) =

		evallv(a)
		genpc_op(k_incr, p.opindex)

	setmode_u(a)
	setincrstep(a.mode)
end

proc setincrstep(int m)=
	pccodex.step:=1

	if ttisref[m] then
		pccodex.step:=ttsize[tttarget[m]]
	fi
end

proc do_incrload(unit p,a) =
	int opc

		evallv(a)
		genpc_op(k_incrx, p.opindex)
	setmode_u(a)
	setincrstep(a.mode)
end

proc do_for(unit p,pindex,pfrom, pbody, int down) =
	unit pto, pstep, pelse, px, plimit, ptoinit
	int lab_a,lab_b,lab_c,lab_d,lab_e
	int a,b,step

	pto:=pfrom.nextunit
	pstep:=pto.nextunit
	pelse:=pbody^.nextunit
	ptoinit:=pindex.nextunit

	if pto^.tag=j_ptr then
		px:=pto^.a
		ref strec d
		if px^.tag=j_name and (d:=px^.def)^.nameid=paramid and
			 d^.parammode=out_param then
			gerror("Possibly using &param as for-loop limit")
		fi
	fi

	lab_a:=definelabel()
	lab_b:=createfwdlabel()
	lab_c:=createfwdlabel()
	lab_d:=createfwdlabel()

	if pelse then
		lab_e:=createfwdlabel()
	else
		lab_e:=lab_d
	fi

	stacklooplabels(lab_a, lab_b, lab_c, lab_d)

	evalunit(pfrom)
	genpc(k_popmem,genmem_u(pindex))
	setmode_u(pindex)

	if ptoinit then			!using temp for limit
		ptoinit.resultflag:=0
		evalunit(ptoinit)
	fi

	if pfrom.tag=j_const and pto.tag=j_const then
		a:=pfrom.value
		b:=pto.value
		if (down and a>=b) or (not down and a<=b) then	!in range
		else							!loop not executed
			genpc(k_jump, genlabel(lab_e))
		fi
	else
		if pfrom.tag=j_const then				!reverse condition; compare mem:imm
			evalunit(pto)
			evalunit(pfrom)
			genpc_cond(k_jumpcc, (down|op_gt_i64|op_lt_i64),genlabel(lab_e))
		else
			evalunit(pindex)
			evalunit(pto)
			genpc_cond(k_jumpcc, (down|op_lt_i64|op_gt_i64),genlabel(lab_e))
		fi
		setmode_u(pindex)
	fi

	definefwdlabel(lab_b)

	evalblock(pbody)				!do loop body

	definefwdlabel(lab_c)

	if pstep then
		if pstep.tag<>j_const then
			gerror("for/step non-const not ready")
		fi
		step:=pstep.value
		if step<=0 then
			gerror("Bad for-step")
		fi
		genpc_n((down|k_fordown|k_forup),step, genlabel(lab_b))
		setmode_u(pindex)
	else
		genpc_n((down|k_fordown|k_forup),1, genlabel(lab_b))
		setmode_u(pindex)
	fi

	genpc(k_opnd, genmem_u(pindex))
	if pto.tag=j_const then
		genpc(k_opnd, genint(pto.value))
	else
		genpc(k_opnd, genmem_u(pto))
	fi

	if pelse then
		definefwdlabel(lab_e)
		evalblock(pelse)
	fi

	definefwdlabel(lab_d)
	--loopindex
end

proc do_forall(unit p,pindex,plist, pbody, int down) =
	unit plocal, pfrom, pto, pelse, px, plimit, passign
	int lab_a,lab_b,lab_c,lab_d,lab_e
	int a,b,step

	plocal:=pindex.nextunit
	pfrom:=plocal.nextunit
	pto:=pfrom.nextunit
	passign:=plist.nextunit
	pelse:=pbody^.nextunit

	lab_a:=definelabel()
	lab_b:=createfwdlabel()
	lab_c:=createfwdlabel()
	lab_d:=createfwdlabel()

	if pelse then
		lab_e:=createfwdlabel()
	else
		lab_e:=lab_d
	fi

	stacklooplabels(lab_a, lab_b, lab_c, lab_d)


	evalunit(pfrom)
	genpc(k_popmem, genmem_u(pindex))
	
	setmode_u(pindex)

	if pfrom.tag=j_const and pto.tag=j_const then
		a:=pfrom.value
		b:=pto.value
		if (down and a>=b) or (not down and a<=b) then	!in range
		else							!loop not executed
			genpc(k_jump, genlabel(lab_e))
		fi
	else
		if pfrom.tag=j_const then				!reverse condition; compare mem:imm
			evalunit(pfrom)
			evalunit(pto)
			genpc_cond(k_jumpcc, (down|op_gt_i64|op_lt_i64),genlabel(lab_e))
		else
			evalunit(pfrom)
			evalunit(pto)
			genpc_cond(k_jumpcc, (down|op_lt_i64|op_gt_i64),genlabel(lab_e))
		fi
		setmode_u(pindex)
	fi

	definefwdlabel(lab_b)

PRINTUNIT(PASSIGN)
	passign.resultflag:=0
	evalunit(passign)

	evalblock(pbody)				!do loop body

	definefwdlabel(lab_c)

	genpc_n((down|k_fordown|k_forup),1, genlabel(lab_b))
	setmode_u(pindex)

	genpc(k_opnd, genmem_u(pindex))
	if pto.tag=j_const then
		genpc(k_opnd, genint(pto.value))
	else
		genpc(k_opnd, genmem_u(pto))
	fi

	if pelse then
		definefwdlabel(lab_e)
		evalblock(pelse)
	fi

	definefwdlabel(lab_d)
	--loopindex
end

proc do_swap(unit p,a,b) =
		evallv(a)
		evallv(b)
		genpc(k_swap)
	setmode_u(a)
end

proc do_convert(unit p,a) =
	int opc

	case p^.tag
	when j_makelist, j_makeset then
	else
		case p.opindex
		when op_softconv then
gerror("CONV/SOFTCONV")
		when op_error then
gerror("CONV/ERROR")

		else
			evalunit(a)
			genpc_op(k_convert,p.opindex)
		esac

		setmode_u(p)

		if p.opindex in [op_truncate_i64, op_truncate_i128] then
			pccodex.truncmode:=p.convmode
		fi
	esac
end

proc do_dot(unit pdot) =
	int offset
	unit a,pname

	if ttcat[pdot.mode]=block_cat then
		do_dotref(pdot)
		return
	fi
	a:=pdot.a

	if dodotchains then
		pname:=nil
		offset:=checkdotchain(a,pname)
		offset+:=pdot.offset
		a:=pname
	else
		offset:=pdot.offset
	fi

	evalref(a)

	if offset then
		genpushint(offset)
		genpc(k_pushptroff)
	else
		genpc(k_pushptr)
	fi
	pccodex.scale:=1

	setmode(getmemmode(pdot))
end

global function checkdotchain(unit p, &pname)int=
	int offset,axmode

	case p.tag
	when j_dot then
		offset:=checkdotchain(p.a,pname)
		return p.offset+offset

	else							!anything else, is the start expression
		pname:=p
		return 0
	esac
return 0
end

proc do_dotref(unit pdot) =
	int imode:=createrefmode(nil,pdot.mode,0)
	int offset
	unit a,pname


	a:=pdot.a

	if dodotchains then
		pname:=nil
		offset:=checkdotchain(a,pname)
			offset+:=pdot.offset
			a:=pname
	else
		offset:=pdot.offset
	fi

	evalref(a)

	if offset then
		genpushint(offset)
		genpc_op(k_bin, op_add_refoff)
		pccodex.scale:=1
	fi
	setmode(imode)
end

proc do_storedot(unit pdot,pfield, rhs) =
	int offset
	unit a,pname

	evalunit(rhs)
	a:=pdot.a

	if dodotchains then
		pname:=nil
		offset:=checkdotchain(a,pname)
			offset+:=pdot.offset
			a:=pname
	else
		offset:=pdot.offset
	fi

	evalref(a)
	genpushint(offset)

	genpc((pdot.resultflag|k_storeptroff|k_popptroff))
	pccodex.scale:=1
	setmode_u(pdot)
end

proc do_index(unit p,parray,pindex) =
	int addoffset
	if ttcat[p.mode]=block_cat then
		do_indexref(parray,pindex)
		return
	fi
	addoffset:=getindexoffset(pindex)

	evalarray(parray)
	evalunit(pindex)
	genpc(k_pushptroff)
	setmode(getmemmode(p))

	pccodex.scale:=ttsize[tttarget[parray.mode]]
	pccodex.extra:=-ttlower[parray.mode]*pccodex.scale + addoffset*pccodex.scale
end

proc do_storeindex(unit p,parray,pindex,rhs) =
	int addoffset
	addoffset:=getindexoffset(pindex)

	evalunit(rhs)
	evalarray(parray)
	evalunit(pindex)

	genpc((p.resultflag|k_storeptroff|k_popptroff))
	setmode_u(p.a)

	pccodex.scale:=ttsize[tttarget[parray.mode]]
	pccodex.extra:=-ttlower[parray.mode]*pccodex.scale+addoffset*pccodex.scale
end

proc do_indexref(unit parray,pindex) =
	int addoffset
	addoffset:=getindexoffset(pindex)

	evalarray(parray)
	evalunit(pindex)

	genpc_op(k_bin, op_add_refoff)
	setmode(tttarget[parray.mode])
	pccodex.scale:=ttsize[tttarget[parray.mode]]
	pccodex.extra:=-ttlower[parray.mode]*pccodex.scale+addoffset*pccodex.scale
end

function getindexoffset(unit &pindex)int offset=
	int addoffset:=0

	if pindex.tag=j_bin and pindex.genop in [add_op, sub_op] then

		if pindex.b.tag=j_const then		!incorporate const offset into lwb adjustment
			addoffset:=(pindex.genop=add_op|pindex.b.value|-pindex.b.value)
			pindex:=pindex.a
		fi
	fi
	return addoffset
end

proc do_switch(unit p,pindex,pwhenthen,pelse, int loopsw,isref) =
	const maxlabels = 1000
	int minlab,maxlab,n,iscomplex,i
	int lab_a,lab_b,lab_d, labjump, elselab, labstmt,ax,bx,ismult
	[0..maxlabels]ref pclrec labels
	unit w,wt

	ismult:=p^.mode<>tvoid and not loopsw

	minlab:=1000000
	maxlab:=-1000000		!highest index seen

	n:=0				!no. different values
	iscomplex:=0			!whether complex switch

	wt:=pwhenthen
	while wt do
		w:=wt.a
		while w do		!for each when expression
			case w.tag
			when j_makerange then
				ax:=w.a.value
				bx:=w.b.value
	dorange::
				for i:=ax to bx do
					minlab := min(i,minlab)
					maxlab := max(i,maxlab)
				od
			when j_const then		!assume int
				ax:=bx:=w.value
				goto dorange
			else
				gerror_s("Switch when2: not const: #",strexpr(w).strptr)
			esac
			w:=w.nextunit
		od
		wt:=wt.nextunit
	od

	n:=maxlab-minlab+1
	if n>maxlabels then
		gerror("Switch too big")
	fi

	if loopsw then
		lab_a:=definelabel()
		lab_d:=createfwdlabel()
		stacklooplabels(lab_a,lab_a,lab_a,lab_d)
	else
		lab_d:=createfwdlabel()
	fi

	labjump:=createfwdlabel()
	elselab:=createfwdlabel()

	if ismult then genpc(k_startmult) fi

	evalunit(pindex)
	genpc(k_info,genlabel(elselab))
	genpc(k_switch, genlabel(labjump))

	pccodex.minlab:=minlab
	pccodex.maxlab:=maxlab

	definefwdlabel(labjump)

	for i:=minlab to maxlab do			!fill with else labels first
		genpc(k_switchlabel,genlabel(elselab))
		labels[i]:=pccodex
	od
	genpc(k_endswitch)


	wt:=pwhenthen
	while wt do
		labstmt:=definelabel()
		w:=wt.a
		while w do
			case w.tag
			when j_makerange then
				ax:=w.a.value
				bx:=w.b.value
			when j_const then
					ax:=bx:=int(w.value)
			esac
			for i:=ax to bx do
				labels[i].labelno:=labstmt
			od
			w:=w.nextunit
		od

		evalunitx(wt.b,isref)
		if ismult then genpc(k_resetmult) fi
		genjumpl((loopsw|lab_a|lab_d))
		wt:=wt.nextunit
	od

	definefwdlabel(elselab)
	if pelse then
		evalunitx(pelse,isref)
		if ismult then genpc(k_endmult) fi
	fi

	if loopsw then
		genjumpl(lab_a)
		definefwdlabel(lab_d)
		--loopindex
	else
		definefwdlabel(lab_d)
	fi
end

proc do_select(unit p,a,b,c, int isref) =
	const maxlabels=256
	[maxlabels]ref pclrec labels
	int labend,labjump,n,i,elselab,labstmt,ismult
	unit q

	ismult:=p^.mode<>tvoid and p.resultflag

	q:=b
	n:=0
	while q do
		if n>=maxlabels then gerror("selectx: too many labels") fi
		++n
		q:=q.nextunit
	od

	labend:=createfwdlabel()
	labjump:=createfwdlabel()
	elselab:=createfwdlabel()

	if ismult then genpc(k_startmult) fi
	evalunit(a)
	genpc(k_info,genlabel(elselab))

	genpc(k_switch, genlabel(labjump))
	pccodex.minlab:=1
	pccodex.maxlab:=n

	definefwdlabel(labjump)

	q:=b
	i:=0
	for i:=1 to n do
		genpc(k_switchlabel,genlabel(elselab))
		labels[i]:=pccodex
	od
	genpc(k_endswitch)

	q:=b
	i:=0
	while q do
		labstmt:=definelabel()
		++i
		labels[i].labelno:=labstmt
		evalunitx(q,isref)
		if ismult then genpc(k_resetmult) fi
		genjumpl(labend)
		q:=q.nextunit
	od

	definefwdlabel(elselab)

	evalunitx(c,isref)
	if ismult then genpc(k_endmult) fi

	definefwdlabel(labend)
end

proc do_case(unit p,pindex,pwhenthen,pelse, int loopsw,isref) =
	const maxcase=256
	[maxcase]int labtable
	[maxcase]unit unittable
	int ncases, opc, ismult

	int lab_abc, lab_d, fmult, labnextwhen, labstmtstart, labelse
	unit w,wt

	if pindex=nil then
		GERROR("EMPTY CASE NOT DONE")
	fi

	ismult:=p.mode<>tvoid and not loopsw

	if loopsw then
		lab_abc:=definelabel()		!start of loop
		lab_d:=createfwdlabel()	!end of case/end of loop
		stacklooplabels(lab_abc,lab_abc,lab_abc,lab_d)
	else
		lab_d:=createfwdlabel()	!end of case/end of loop
	fi

	if ismult then genpc(k_startmult) fi
	evalunit(pindex)

	if casedepth>=maxcasedepth then
		gerror("case nested too deeply")
	fi
	casestmt[++casedepth]:=p

	ncases:=0
	wt:=pwhenthen
	while wt do
		w:=wt.a
		if ncases>=maxcase then
			gerror("too many cases")
		fi
		labtable[++ncases]:=createfwdlabel()
		unittable[ncases]:=wt.b

		while w do
			evalunit(w)
			opc:=optypetable[eq_op,ttbasetype[pindex.mode]]
			if opc=0 then gerror("case/ix") fi
	
			genpc_op(k_casejumpeq,op_eq_i64,genlabel(w.whenlabel:=labtable[ncases]))
			setmode_u(w)
			w:=w.nextunit
		od

		wt:=wt.nextunit
	od

	genpc(k_free)
	setmode_u(pindex)

	labelse:=createfwdlabel()
	caseelse[casedepth]:=labelse
	genjumpl(labelse)

	for i:=1 to ncases do
		definefwdlabel(labtable[i])
		evalunitx(unittable[i],isref)
		if ismult then genpc(k_resetmult) fi

		if loopsw then
			genjumpl(lab_abc)
		else
			genjumpl(lab_d)
		fi
	od

	definefwdlabel(labelse)

	if pelse then
		evalunitx(pelse,isref)
		if ismult then genpc(k_endmult) fi
	fi

	if loopsw then
		genjumpl(lab_abc)
		definefwdlabel(lab_d)
		--loopindex
	else
		definefwdlabel(lab_d)
	fi

	--casedepth
end

proc do_dotindex(unit p,a,b) =
	evalunit(a)
	evalunit(b)

	genpc(k_dotindex)
	setmode(ti64)
end

proc do_dotslice(unit p,a,b) =
	evalunit(a)
	evalunit(b.a)
	evalunit(b.b)

	genpc(k_dotslice)
	setmode(ti64)
end

proc do_read(unit p,a) =
	int m

	m:=p.mode

	if a=nil then
		a:=pzero
	fi

	if ttisinteger[m] then
		genpc_sysfn(sysfn_read_i64,a)
	elsif ttisreal[m] and ttsize[m]=8 then
		genpc_sysfn(sysfn_read_r64,a)
	elsif m=trefchar then
		genpc_sysfn(sysfn_read_str,a)
	else
		GERROR("CAN'T READ THIS ITEM")
	fi
	setmode_u(p)
end

proc do_readln(unit a) =
	if a then
		if ttbasetype[a.mode]<>tref then gerror("@dev no ref") fi

		case ttbasetype[tttarget[a.mode]]
		when tvoid then
			genpc_sysproc(sysfn_read_fileline, a)
		when tu8,tc8 then
			genpc_sysproc(sysfn_read_strline, a)
		else
			gerror("rd@dev?")
		esac
	else
		genpc_sysproc(sysfn_read_conline)
	fi
end

proc docond(int opc,unit p,int lab)=
	genjumpcond(opc,p,lab)
end

proc do_syscall(unit p,a)=
	int fnindex:=p.fnindex

	if p.resultflag then
		if not sysfnres[fnindex] then
			gerror_s("Sysfn has not result",sysfnnames[fnindex])
		fi
		genpc_sysfn(fnindex,a)
	else
		genpc_sysproc(fnindex,a)
	fi
end


proc do_slice(unit a,b, int doref=0) =


IF DOREF THEN GERROR("DOSLICE/REF?") fi

	if b=nil then

		if a.tag=j_const then			!assume string
			genpushint(strlen(a.svalue))
		else
			genpushint(ttlength[a.mode])
		fi
		evalarray(a)

	else
		if b.a.tag=b.b.tag=j_const then
			genpushint(b.b.value-b.a.value+1)
		else
			evalunit(b.b)
			evalunit(b.a)
			genpc_op(k_bin, op_sub_i64)
			setmode(ti64)
			genpushint(1)
			genpc_op(k_bin, op_add_i64)
		fi
		setmode(ti64)

		do_indexref(a,b.a)
	fi

	genpc(k_makeslice)
	setmode(tu128)
end

proc do_assignblock(unit p,a,b) =

	if b.tag=j_makelist then
		if ttbasetype[a.mode]=tarray then
			do_assignarray(a,b)
		else
			do_assignrecord(a,b)
		fi
	else
GERROR("ASSIGN BLOCK")
	fi
end

proc do_assignarray(unit a,b)=
	unit passign, pindex, pconst,q
	int index

	if ttbasetype[tttarget[a.mode]]=tc8 then
		gerror("Assignment not suitable for []char type")
	fi

	pconst:=createconstunit(1,ti64)
	pindex:=createunit2(j_index,a,pconst)
	passign:=createunit2(j_assign,pindex, b.a)
	passign.mode:=pindex.mode:=tttarget[a.mode]

	index:=ttlower[a.mode]
	q:=b.a

	while q do
		pconst.value:=index
		pconst.resultflag:=1
		passign.b:=q
		evalunit(passign)

		++index
		q:=q.nextunit
	od

end

proc do_assignrecord(unit a,b)=
	unit passign, pdot, pfield,q
	int m,fieldtype
	ref strec d,e

	pfield:=createunit0(j_name)
	pdot:=createunit2(j_dot,a,pfield)
	passign:=createunit2(j_assign,pdot, b.a)
	passign.mode:=pdot.mode:=tttarget[a.mode]

	m:=a.mode
	d:=ttnamedef[m]
	e:=d.deflist
	q:=b.a
	while e do
		if e.nameid=fieldid and e.mode<>tbitfield then
			fieldtype:=e.mode
			pfield.def:=e
			passign.mode:=pfield.mode:=pdot.mode:=fieldtype
			passign.b:=q
			pdot.offset:=e.offset
			evalunit(passign)
			q:=q.nextunit
		fi
		e:=e.nextdef
	od
end

proc pushrhs(unit a)=
	if a=nil then return fi
	pushrhs(a.nextunit)
	evalunit(a)
end

proc do_multassign(unit a,b)=
	unit p
	int nlhs,nrhs
	ref strec d

	nlhs:=a.length

	if b.tag=j_callfn then
		evalunit(b)
		if b.a.tag<>j_name then
			gerror("multassign from fn: not simple fn")
		fi
		d:=b.a.def
		nrhs:=d.nretvalues

		if a.tag<>j_makelist then		!mult-ret fn assigned to scalar
			if a.nextunit then GERROR("MULTASS?") fi
			nlhs:=1
		else
			a:=a.a					!point to elements of makelist
		fi

	else
		nrhs:=b.length
		pushrhs(b.a)			!push rhs elements in right-to-left order
		a:=a.a					!point to elements of makelist

	fi

	repeat
		switch a.tag
		when j_name then
			genpc(k_popmem,genmem_u(a))
		when j_index, j_slice,j_dot then
			evalref(a)
			genpc(k_popptr,genint(0))
		when j_ptr then
			evalunit(a.a)
			genpc(k_popptr,genint(0))
		when j_if, j_longif, j_case, j_switch, j_select then
			evalref(a)
			genpc(k_popptr,genint(0))
		when j_dotindex then
			evalref(a.a)
			evalunit(a.b)
			genpc(k_popdotindex)
		else
			cpl jtagnames[a.tag]
			gerror("Bad mult assign element")
		end switch

		setmode_u(a)

		a:=a.nextunit
	until a=nil

	d:=getprocretmodes(b)

	for i:=nlhs+1 to nrhs do
		genpc(k_free)
		setmode(ttmult[d.mode,i])
	od
end

proc do_recase(unit p,a)=
	unit q,wt,w
	int destlab,casevalue

	if casedepth=0 then
		gerror("recase outside case stmt")
	fi

	if a then
		casevalue:=a.value
	else				!a=null means goto else
		genjumpl(caseelse[casedepth])
	fi

	q:=casestmt[casedepth]

	destlab:=0

	wt:=q^.b
	while wt do
		w:=wt^.a
		while w do
			if w^.tag=j_const and ttisinteger[w.mode] and w^.value=casevalue then
				destlab:=w^.whenlabel
				exit all
			fi
			w:=w^.nextunit
		od
		wt:=wt^.nextunit
	od

	if destlab=0 then
		genjumpl(caseelse[casedepth])
	else
		genjumpl(destlab)
	fi
end

=== bb_genmcl.m 25/40 ===
import msys
import mlib
import clib
import oslib

import bb_support

import bb_libmcl as mm
import bb_stackmcl
import bb_libpcl as pp
import bb_mcldecls
import bb_optim
import bb_diags

import bb_decls

import bb_pclcommon
import bb_tables

import BB_LIB

INT DEB

const fshowpcl=0
const fshowopndstack=0

const fshowbothmcl=0


type pcl = ref pclrec

[pclnames.len, void_cat..var_cat]ref proc(pcl) pc_handlertable
[0..specopnames.upb]ref proc(pcl) pcx_handlertable

pcl currpcl
pcl	procdefpcl			!points to last k_procdef instr
ref mclrec procdefmcl	!points to first mcl instr for proc
pcl infopcl
int	pcljump				!set to 1 to continue from update version of currpcl
ref pstrec currproc
int frameoffset,paramoffset

int swmin,swmax

const maxparams=32
const maxlocals=256

const targetsize=8

[maxparams]ref pstrec paramdefs
[maxlocals]ref pstrec localdefs
int nparams, nlocals
int retmode
global ref pstrec procdef
int passno
int sa_nargs

[]int multregs=(r0,r1,r2,r10,r11,r12)
[]int multxregs=(r0,r1,r2,r3,r4,r5)

global proc codegen_mcl=
	pcl p

	inithandlers()

	mclinit()

	currpcl:=allpclcode
	passno:=1
	pcljump:=0

	mgencomment("Starting PCL->MCL:")

	while currpcl do
		convertpcl(currpcl)

		if not pcljump then
			currpcl:=currpcl.nextpcl
		else						!pclpointer has been reset; continue from new
			pcljump:=0				!currpcl value
		fi
	od

	mgencomment("Finished PCL->MCL:")

	genabsneg()
	genstringtable()
	genrealtable()
	genfunctiondata()

	gensysfntable()

	genmc(m_nop)
	genmc(m_nop)

	allmclcode:=mccode

end

proc convertpcl(pcl p)=
	[1256]char str
	ichar ss
	int m

	if fshowpcl  then
		case p.opcode
		when k_label, k_comment, k_frame, k_procdef, k_procentry,
			k_retproc, k_procend, k_blank, k_param then
		else
				strcpy(&.str,"                       ")
				strcat(&.str,pclnames[p.opcode])
				mgencomment(&.str)
		esac
	fi

	mlineno:=p.pos


	if pcluseindex[p.opcode] then
		pcx_handlertable[p.opindex]^(p)
	else
		pc_handlertable[p.opcode,ttcat[p.mode]]^(p)
	fi

	if fshowopndstack then
		case p.opcode
		when k_label, k_comment, k_frame, k_procdef, k_procentry,
			k_procend, k_blank, k_param then
		else
			showopndstack()
		esac
	fi
end

proc inithandlers=
	ichar name
	ref void fnaddr

	int n:=$get_nprocs()

	for i to n do
		name:=$get_procname(i)
		if eqbytes(name,"pc_",3) then
			dopchandler(name,$get_procaddr(i))
		elsif eqbytes(name,"pcx_",4) then
			dopcxhandler(name,$get_procaddr(i))
		fi
	od

	for i in pc_handlertable.bounds do
		for j in typecatnames.bounds do
			fnaddr:=pc_handlertable[i,j]
			if not fnaddr then
				fnaddr:=pc_handlertable[i,void_cat]
				if not fnaddr then fnaddr:=cast(&pc_dummy) fi
				pc_handlertable[i,j]:=fnaddr
			fi
		od
	od

	for i in pcx_handlertable.bounds do
		if not pcx_handlertable[i] then
			pcx_handlertable[i]:=cast(&pcx_dummy)
		fi
	od
end

proc dopchandler(ichar name, ref proc fnaddr)=
	[128]char name2
	ichar scat,sopcode
	int opcode,cat

	sopcode:=&.name2
	strcpy(sopcode, name+3)		!name2 has pushmem_d64

	scat:=strchr(sopcode,'_')
	if scat then				!_ found and cat code exists
		scat^:=0
		++scat
	fi

	for i in pclnames.bounds do
		if eqstring(sopcode,pclnames[i]+2) then
			opcode:=i
			exit
		fi
	else
		gerror_s("No opcode exists for pc-handler: #",name)
	od

	cat:=void_cat

	if scat then
		for i in typecatnames.bounds do
			if eqstring(scat,typecatnames[i]) then
				cat:=i
				exit
			fi
		else
			gerror_s("No typecat exists for pc-handler: #",name)
		od
	fi

	pc_handlertable[opcode,cat]:=cast(fnaddr)
end

proc dopcxhandler(ichar name, ref proc fnaddr)=
	int opindex

	for i in specopnames.bounds do
		if eqstring(name+4,specopnames[i]+3) then
			opindex:=i
			exit
		fi
	else
		gerror_s("No opindex exists for pcx-handler: #",name)
	od

	pcx_handlertable[opindex]:=cast(fnaddr)
end

proc pc_dummy(pcl p) =
	[256]char str

	fprint @&.str,"pc_#",pclnames[p^.opcode]+2

	unimpl(&.str,p.pos)
end

proc pcx_dummy(pcl p) =
	[256]char str

	fprint @&.str,"pcx_#",specopnames[p^.opindex]+3

	unimpl(&.str,p.pos)
end

proc unimpl(ichar mess,int lineno)=
	[256]char str
	mcloperand lx

fprint @&.str,"Unimpl: # on line # in # (#)",mess, mlineno iand 16777215,
		sourcefilenames[mlineno>>24],ttname[currpcl.mode]

	mgencomment(&.str)

	println &.str

end

function findsysfn(ichar name)int=
	for i to sysfnnames.len do
		if eqstring(sysfnnames[i]+6,name) then
			return i
		fi
	od
	return 0
end

proc pc_comment(pcl p)=
	mgencomment(p.svalue)
end

proc pc_blank(pcl p)=
	mgencomment("")
end

proc pc_procdef(pcl p)=
	[256]char str
	int fnindex,labno
	ichar name

	procdefpcl:=currpcl

	procdef:=p.def
	name:=procdef.name

	setsegment('C')
	if passno=1 then
		mgencomment("DUMMY")
		procdefmcl:=mccodex
	fi

	genmc(m_procstart,mgenmemaddr(procdef))
	genmc(m_labelname,mgenmemaddr(procdef))
	mccodex.isglobal:=procdef.isglobal

	if name^='m' and (name+1)^='$' then		!assume sysfn definition
		fnindex:=findsysfn(name+2)
		if fnindex=0 then
			merror("Bad SYSFN name:",name)
		fi
		labno:=sysfnproclabels[fnindex]
		if labno=0 then
			labno:=sysfnproclabels[fnindex]:=++labelno
		fi
		genmc(m_label,mgenlabel(labno))
	fi

	nlocals:=nparams:=0

	if passno=2 then
		MGENCOMMENT("!**************** PASS 2 ****************")
	fi

end

proc pc_frame(pcl p)=
	if nlocals>=maxlocals then gerror("Too many locals") fi
	++nlocals
	case ttcat[p.mode]
	when d64_cat then
		++inf_proclocals
	when x64_cat then
		++inf_procxlocals
	esac
	localdefs[nlocals]:=p.def
end

proc pc_param(pcl p)=
	if nparams>=maxparams then gerror("Too many params") fi
	++nparams
	paramdefs[nparams]:=p.def
	if ttcat[p.mode]=wide_cat then
		++nparams
		paramdefs[nparams]:=p.def
	fi

end

proc pc_procentry(pcl p)=
	int np, regoffset, offset, dreg, xreg, nregparams, nspill,hasequiv
	mcloperand ax
	ref pstrec d

	framebytes:=0
	frameoffset:=0
	paramoffset:=0
	needstackframe:=0
	ndsaveregs:=nxsaveregs:=0			!not of if b=non-vol regs to be spilled
	ndsavepush:=0
	nregparams:=nspill:=0
	needshadow48:=0			!duplicate caller's shadow space
	needshadow32:=0			!local shadow space
	hasequiv:=0

	if inf_assem then skip fi

	if passno=2 and inf_leafproc then	!no point in pass1 as no info avialable
		dreg:=r10			!next available dreg
		xreg:=r0			!next available xreg

		for i to nparams do
			if i>4 then exit fi
			d:=paramdefs[i]
			case ttcat[d.mode]
			when d64_cat then
				if not d.addrof and not d.noreg and d.nrefs then
					d.reg:=dreg
					if dreg=r10 then inf_r10used:=1 fi
					if dreg=r11 then inf_r11used:=1 fi
					if dreg=r13 then inf_r13used:=1 fi
					++nregparams
				fi
			when x64_cat then
				if not d.addrof and d.nrefs then
					d.reg:=xreg
					++nregparams
				fi
			esac
			++dreg
			++xreg
		od
	fi

	if passno=2 then		!no point in pass1 as no info avialable
		dreg:=r9			!next available dreg
		xreg:=r15			!next available xreg
		for i to nlocals do
			d:=localdefs[i]
			case ttcat[d.mode]
			when d64_cat then
				if not d.addrof and not d.noreg and d.nrefs then
					if dreg<=inf_highreg or dreg<r3 then next fi
					dsaveregs[++ndsaveregs]:=dreg
					d.reg:=dreg
					--dreg
				fi
			when x64_cat then
				if not d.addrof and d.nrefs and not d.noreg then
					if xreg<=inf_highxreg or xreg<r6 then next fi
					xsaveregs[++nxsaveregs]:=xreg
					d.reg:=xreg
					--xreg
				fi
			esac
		od

		if not inf_leafproc then
			for i to nparams do
				if i>4 then exit fi
				d:=paramdefs[i]
				case ttcat[d.mode]
				when d64_cat then
					if not d.addrof and d.nrefs and not d.noreg then
						if dreg<=inf_highreg or dreg<r3 then next fi
						dsaveregs[++ndsaveregs]:=dreg
						d.reg:=dreg
						--dreg
						++nregparams
					fi
				when x64_cat then
					if not d.addrof and d.nrefs and not d.noreg then
						if xreg<=inf_highxreg or xreg<r6 then next fi
						xsaveregs[++nxsaveregs]:=xreg
						d.reg:=xreg
						--xreg
						++nregparams
					fi
				esac
			od
		fi

	fi
SKIP::

	for i to nparams do
		d:=paramdefs[i]

		if not d.reg then			!not a regvar
			if i>1 and iswide(d.mode) and paramdefs[i-1]=d then
			else
				d.offset:=paramoffset+16
				genmc(m_define, mgenname(mm.getfullname(d)), mgenint(d.offset))
			fi

		elsif ttcat[d.mode]=d64_cat then
			genmc(m_definereg, mgenname(mm.getfullname(d)), mgenreg(d.reg))
		else
			genmc(m_definereg, mgenname(mm.getfullname(d)), mgenxreg(d.reg))
		fi
		paramoffset+:=8
	od

	for i:=r3 to inf_highreg do		!add any non-vol regs
		dsaveregs[++ndsaveregs]:=i
	od

	for i:=r6 to inf_highxreg do		!add any non-vol xregs
		xsaveregs[++nxsaveregs]:=i
	od



	if nparams>4 then
		needstackframe:=1
		nspill:=4-nregparams
	else
		ndsavepush:=ndsaveregs
		ndsaveregs:=0
		nspill:=nparams-nregparams
		if nspill then needstackframe:=1 fi
	fi

	for i to nlocals do
		d:=localdefs[i]
		if d.isequiv then
			hasequiv:=1
        elsif not d.reg then
			frameoffset-:=roundsizetg(d.size)
			d.offset:=frameoffset
			if d.owner=nil then d.owner:=procdef fi
			genmc(m_define, mgenname(mm.getfullname(d)), mgenint(d.offset))
		elsif ttcat[d.mode]=d64_cat then
			genmc(m_definereg, mgenname(mm.getfullname(d)), mgenreg(d.reg))
		else
			genmc(m_definereg, mgenname(mm.getfullname(d)), mgenxreg(d.reg))
		fi
	od

	if hasequiv then
		for i to nlocals do
			d:=localdefs[i]
			if d.isequiv then
				d.offset:=d.equiv.offset
				if d.reg then merror("@ on reg var") fi
				genmc(m_define, mgenname(mm.getfullname(d)), mgenname(mm.getfullname(d.equiv)))
			fi
		od
	fi

	frameoffset-:=ndsaveregs*8			!non-vol reg spill area
	dsaveoffset:=frameoffset
	frameoffset-:=nxsaveregs*8
	xsaveoffset:=frameoffset

	framebytes:=-frameoffset

	if (nlocals or nparams) and procdef.isthreaded then
		merror("params/locals in threaded?")
	fi
	if framebytes then needstackframe:=1 fi	!may already be set

	while framebytes iand 15 do ++framebytes od	!multiple of 16

	if needstackframe and ndsavepush.odd then framebytes+:=8 fi	!alignment

	if needstackframe and not inf_leafproc then
		framebytes +:= 32
	fi

	if needstackframe and ndsavepush then needshadow48:=1 fi

	if not needstackframe and not inf_leafproc and not procdef.isthreaded then
		needshadow32:=(ndsavepush.odd | 32 | 40)
	fi


	for i to ndsavepush do
		genmc(m_push, mgenreg(dsaveregs[i]))
	od

	if needshadow48 then			!create new shadow space to spill params
		pushstack(48)
	fi

	if needstackframe then
		genmc(m_push, dframeopnd)
		genmc(m_mov, dframeopnd, dstackopnd)
		if framebytes then
			pushstack(framebytes)
		fi
	elsif needshadow32 then
		pushstack(needshadow32)
	fi

	offset:=dsaveoffset
	for i to ndsaveregs do
		genmc(m_mov, mgenindex(areg:rframe, size:8, offset:offset),
			mgenreg(dsaveregs[i]))
		offset+:=8
	od

	offset:=xsaveoffset
	for i to nxsaveregs do
		genmc(m_movq, mgenindex(areg:rframe, size:8, offset:offset),
			mgenxreg(xsaveregs[i]))
		offset+:=8
	od

	offset:=16
	regoffset:=0
	for i to nparams do
		if regoffset>3 then exit fi
		d:=paramdefs[i]
		IF NOT D.REG THEN
			ax:=mgenindex(areg:rframe, size:8, offset:offset)
			case ttcat[d.mode]
			when x64_cat then
				genmc(m_movq, ax, mgenxreg(r0+regoffset))
			when x32_cat then
				genmc(m_movd, changeopndsize(ax,4), mgenxreg(r0+regoffset))
			else
				genmc(m_mov, ax, mgenreg(regoffset+r10))
			esac
		elsif d.reg then			!may use non-vol regs
			case ttcat[d.mode]
			when x64_cat then
				if d.reg<>r0+regoffset then
					genmc(m_movq, mgenxreg(d.reg), mgenxreg(r0+regoffset))
				fi
			when d64_cat then
				if d.reg<>r10+regoffset then
					genmc(m_mov, mgenreg(d.reg), mgenreg(regoffset+r10))
				fi
			esac

		fi
		offset+:=8
		++regoffset
	od
end

proc pc_retproc(pcl p)=
	int offset

	offset:=dsaveoffset
	for i to ndsaveregs do
		genmc(m_mov, mgenreg(dsaveregs[i]),
			mgenindex(areg:rframe, size:8, offset:offset))
		offset+:=8
	od

	offset:=xsaveoffset
	for i to nxsaveregs do
		genmc(m_movq, mgenxreg(xsaveregs[i]),
			mgenindex(areg:rframe, size:8, offset:offset))
		offset+:=8
	od


	if needstackframe then
		if framebytes then
			genmc(m_add, dstackopnd, mgenint(framebytes))
		fi
		genmc(m_pop, dframeopnd)
	elsif needshadow32 then
		popstack(needshadow32)
	fi

	if needshadow48 then
		popstack(48)
	fi
	for i:=ndsavepush downto 1 do
		genmc(m_pop, mgenreg(dsaveregs[i]))
	od

	genmc(m_ret)
end

proc pc_procend(pcl p)=
	genmc(m_procend)

	if passno=1 then
		resetopnds1()

		if inf_assem then
			inf_assem:=0
			resetopnds2()

		elsif foptimise then
			passno:=2
			currpcl:=procdefpcl
			pcljump:=1

			if not fshowbothmcl then
				mccodex:=procdefmcl
				mccodex.nextmcl:=nil
			fi

		fi
	else
		peephole(procdefmcl)
		resetopnds2()
		passno:=1
	fi
end

proc pc_syscallproc(pcl p)=
	int nslots

	pc_setalign(p)

	nslots:=do_pushparams(p,0)
	genmc_sys(p.fnindex)

	to p.nargs do
		poparg()
	od
	popslots(nslots)
end

proc pc_syscallfn(pcl p)=

	pc_syscallproc(p)

	dogetretvalue(p)
end

proc pc_label(pcl p)=
	genmc(m_label, mgenlabel(p.labelno))
end

proc pc_jump(pcl p)=
	genmc(m_jmp, mgenlabel(p.labelno))
end

proc pc_pushint(pcl p)=
	addint(p.value)
end

proc pc_pushint128(pcl p)=
	addint128(cast(p.pvalue128,ref int))
end

proc pc_pushreal(pcl p)=
	addreal(p.xvalue)
end

proc pc_pushreal32(pcl p)=
	addreal32(p.xvalue)
end

proc pc_pushstring(pcl p)=
	addstring(p.svalue)
end

proc pc_popmem_d64(pcl p)=

	for i to noperands do
		case pclstack[i].loc
		when stack_loc then		!should not be any more
			exit
		when mem_loc then
			if pclstack[i].def=p.def then
				genopnd_ld(i)
			fi
		esac
	od

	genmc(m_mov, mgenmem(p.def), genopnd_ld(xa))

	delopnd()
end

proc pc_popmem_x64(pcl p)=
	genmc(m_movq, mgenmem(p.def), genopnd_ld(xa))
	delopnd()
end

proc pc_popmem_x32(pcl p)=
	genmc(m_movd, mgenmem(p.def), genopnd_ld(xa))
	delopnd()
end

proc pc_popmem_block(pcl p)=
	mcloperand ax,bx
	bx:=genopnd_ind()
	addmemaddr(p.def)
	ax:=genopnd_ind()

	copyblock(ax,bx,p.size)

	delopnd()
	delopnd()
end

proc pc_popmem_wide(pcl p)=
	genmc(m_mov, mgenmem(p.def), genopnd_ld(xa))
	delopnd()
	genmc(m_mov, mgenmemhigh(p.def), genopnd_ld(xa))
	delopnd()
end

proc pc_storemem_wide(pcl p)=
	genmc(m_mov, mgenmem(p.def), genopnd_ld(xa))
	genmc(m_mov, mgenmemhigh(p.def), genopnd_ld(xa))
end

proc pc_popmem_short(pcl p)=
	genmc(m_mov, mgenmem(p.def,p.size), genopnd_ld(xa,p.size))
	delopnd()
end

proc pc_storemem_short(pcl p)=
	genmc(m_mov, mgenmem(p.def,p.size), genopnd_ld(xa,p.size))
end

proc pc_storemem_d64(pcl p)=
	genmc(m_mov, mgenmem(p.def), genopnd_ld(xa))
end

proc pc_storemem_x64(pcl p)=
	genmc(m_movq, mgenmem(p.def), genopnd_ld(xa))
end

proc pc_storemem_x32(pcl p)=
	genmc(m_movd, mgenmem(p.def), genopnd_ld(xa))
end

proc pc_pushmem(pcl p)=
	addmem(p)
end

proc pc_pushmemaddr(pcl p)=
	addmemaddr(p.def)
end

proc pc_eval(pcl p)=
	if pclstack[1].wide='L' then
		genopnd_ld(ya)
		genopnd_ld(xb)
		delopnd()
		delopnd()
	else
		genopnd_ld(xa)
		delopnd()
	fi
end

proc pcx_add_i64(pcl p)=
	mcloperand ax,bx
	ax:=genopnd_ld(xb)

	if pclstack[1].fmt=imm_d64 and pclstack[1].value=1 then
		genmc(m_inc, ax)
	else
		bx:=genopnd(ya)
		genmc(m_add,ax,bx)
	fi

	delopnd()
end

proc pcx_sub_i64(pcl p)=
	mcloperand ax,bx
	ax:=genopnd_ld(xb)


	if pclstack[1].fmt=imm_d64 and pclstack[1].value=1 then
		genmc(m_dec, ax)
	else
		bx:=genopnd(ya)
		genmc(m_sub,ax,bx)
	fi

	delopnd()
end

proc pcx_sub_ref(pcl p)=
	mcloperand ax,bx
	int n

	ax:=genopnd_ld(xb)
	bx:=genopnd(ya)
	genmc(m_sub,ax,bx)

	if p.scale>1 then
		n:=ispoweroftwo(p.scale)
		if n then
			genmc(m_shr, ax, mgenint(n))
		else
			MERROR("SUB/REF NOT POWER OF TWO")
		fi
	fi

	delopnd()
end

proc pcx_add_i128(pcl p)=
	mcloperand axl,axh, bxl, bxh

	axl:=genopnd_ld(3)
	axh:=genopnd_ld(4)
	bxl:=genopnd(1)
	bxh:=genopnd(2)

	if specoptogen[p.opindex]=add_op then	
		genmc(m_add, axl, bxl)
		genmc(m_adc, axh, bxh)
	else
		genmc(m_sub, axl, bxl)
		genmc(m_sbb, axh, bxh)
	fi

	delopnd()
	delopnd()
end

proc pcx_sub_i128(pcl p)=
	pcx_add_i128(p)
end

proc pcx_iand_i128(pcl p)=
	mcloperand axl,axh, bxl, bxh
	int opc

	axl:=genopnd_ld(3)
	axh:=genopnd_ld(4)
	bxl:=genopnd(1)
	bxh:=genopnd(2)

	case p.opindex
	when op_iand_i128 then opc:=m_andx
	when op_ior_i128 then opc:=m_orx
	when op_ixor_i128 then opc:=m_xorx
	esac

	genmc(opc, axl, bxl)
	genmc(opc, axh, bxh)

	delopnd()
	delopnd()
end

proc pcx_ior_i128(pcl p)=
	pcx_iand_i128(p)
end

proc pcx_ixor_i128(pcl p)=
	pcx_iand_i128(p)
end

proc pcx_mul_i128(pcl p)=
	do_syscall(sysfn_mul_i128,4,wide_cat)
end

proc pcx_idiv_i128(pcl p)=
	swapopnds(1,3)
	swapopnds(2,4)
	do_syscall(sysfn_idiv_i128,4,wide_cat)
end

proc pcx_idiv_u128(pcl p)=
	pcx_idiv_i128(p)
end

proc pcx_neg_i128(pcl p)=
	mcloperand axlow, axhigh, bxlow, bxhigh

	axlow:=genopnd_ld()
	axhigh:=genopnd_ld(2)

	bxhigh:=genopnd_d64()
	bxlow:=genopnd_d64()

	genmc(m_xorx,bxlow,bxlow)
	genmc(m_xorx,bxhigh,bxhigh)
	genmc(m_sub,bxlow,axlow)
	genmc(m_sbb,bxhigh,axhigh)

	swapopnds(1,3)
	swapopnds(2,4)

	delopnd()
	delopnd()
end

proc pcx_power_i64(pcl p)=
	swapopnds(1,2)
	do_syscall(sysfn_power_i64,2,d64_cat)
end

proc pcx_iand_i64(pcl p)=
	mcloperand ax,bx
	ax:=genopnd_ld(xb)
	bx:=genopnd(ya)

	genmc(m_andx,ax,bx)
	delopnd()
end

proc pcx_ior_i64(pcl p)=
	mcloperand ax,bx
	ax:=genopnd_ld(xb)
	bx:=genopnd(ya)

	genmc(m_orx,ax,bx)
	delopnd()
end

proc pcx_ixor_i64(pcl p)=
	mcloperand ax,bx
	ax:=genopnd_ld(xb)
	bx:=genopnd(ya)

	genmc(m_xorx,ax,bx)
	delopnd()
end

proc pcx_mul_i64(pcl p)=
	mcloperand ax,bx
	int n, shifts
	ax:=genopnd_ld(xb)

	if  pclstack[1].fmt=imm_d64 then
		mulimm(ax,pclstack[1].value)
		delopnd()
		return
	fi

	bx:=genopnd(ya)

	genmc(m_imul2,ax,bx)
	delopnd()
end

proc pcx_add_r64(pcl p)={do_bin_r64(p, m_addsd)}
proc pcx_sub_r64(pcl p)={do_bin_r64(p, m_subsd)}
proc pcx_mul_r64(pcl p)={do_bin_r64(p, m_mulsd)}
proc pcx_div_r64(pcl p)={do_bin_r64(p, m_divsd)}

proc pcx_add_r32(pcl p)={do_bin_r64(p, m_addss)}
proc pcx_sub_r32(pcl p)={do_bin_r64(p, m_subss)}
proc pcx_mul_r32(pcl p)={do_bin_r64(p, m_mulss)}
proc pcx_div_r32(pcl p)={do_bin_r64(p, m_divss)}

proc do_bin_r64(pcl p, int opc)=

	mcloperand ax,bx
	ax:=genopnd_ld(xb)
	bx:=genopnd(ya)

	genmc(opc,ax,bx)
	delopnd()
end


proc pc_to(pcl p)=
	pcl q
	mcloperand ax

	q:=currpcl:=currpcl.nextpcl

	ax:=mgenmem(q.def)
	genmc(m_dec, ax)
	genmc_cond(m_jmpcc, nz_cond, mgenlabel(p.labelno))
end

proc pc_setalign(pcl p)=
	int nslots,shadow,align,nargs,opcode

	if p then
		nargs:=p.nargs
		opcode:=p.opcode
	else
		nargs:=sa_nargs		!set via global
		opcode:=0
	fi

	nslots:=0			!total slots to be recovered after a call
	shadow:=0			!whether 4-slot shadow space to be created
	align:=0			!whether stack alignment fix needed

	case opcode
	when k_setalign then
		saveallopnds()		!get latest mstackdepth
	else
		saveallopnds(nargs+1)
	esac

	if nargs<=4 then					!no pushed args needed
		if mstackdepth=0 then
		else
			shadow:=1
			align:=mstackdepth.odd
			nslots:=4
		fi
	else								!some pushed params
		shadow:=1
		nslots:=nargs
		align:=(mstackdepth+nslots).odd
	fi

	nslots+:=align
	if align then
		if opcode=k_setalign then		!normal
			pushslots(1)
			align:=0
		fi								!else leave to be stored in callalign
	fi

	if ncalldepth>=maxcalldepth then
		merror("Too many nested calls")
	fi
	++ncalldepth
IF NCALLDEPTH<1 THEN
	ABORTPROGRAM("CALLDEPTH?")
FI

	callslots[ncalldepth]:=nslots
	callshadow[ncalldepth]:=shadow
	callalign[ncalldepth]:=align
end

proc pc_callproc(pcl p)=
	int nslots

	nslots:=do_pushparams(p,0)

	genmc(m_call, mgenmemaddr(p.def))

	to p.nargs do
		poparg()
	od
	popslots(nslots)
end

proc pc_callfn(pcl p)=
	pc_callproc(p)

	dogetretvalue(p)
end


proc pc_callprocptr(pcl p)=
	int nslots

	nslots:=do_pushparams(p,1)

	genmc(m_call, genopnd_ld(xa))

	delopnd()			!the ptr

	to p.nargs do
		poparg()
	od
	popslots(nslots)
end

proc pc_callfnptr(pcl p)=
	pc_callprocptr(p)

	dogetretvalue(p)
end

function do_pushparams(pcl p, int isptr)int=

	int pushedslots, nparams, nvar, nargs

	if p then
		nargs:=p.nargs
		nvar:=p.nvariadics
	else
		nargs:=isptr; isptr:=0
		nvar:=0
	fi

	if nargs>inf_maxargs and nargs<=4 then inf_maxargs:=nargs fi
	nparams:=nargs

	if nparams>4 then
		pushallopnds(isptr+4+1)
	fi

	do_pushlowparams(nparams,nvar,isptr)

	if callshadow[ncalldepth] then
		pushslots(callalign[ncalldepth]+4)
	fi

	pushedslots:=callslots[ncalldepth]
	--ncalldepth

	return pushedslots
end

proc do_pushlowparams(int nparams, nvariadics=0, isptr=0)=

	int ireg, xreg, j

	if nparams=0 then return fi
	nparams min:=4

	for i to nparams do
		j:=i+isptr
		ireg:=r10+i-1
		xreg:=xr0+i-1

		if pclstack[j].float then
			unless nvariadics and i>=nvariadics then ireg:=0 end
		else
			xreg:=0
		fi

		if ireg then loadparam(j,ireg) fi
		if xreg then loadxparam(j,xreg) fi
	od
end

proc pc_retfn(pcl p)=
	pc_retproc(p)
end

proc pc_setret(pcl p)=
do_setret(r0,r0)

	regset[r0]:=0
	xregset[r0]:=0
end

proc pc_setretmult(pcl p)=
	int k,wide

	k:=0

	for i:=1 to p.index do
		++k
		wide:=pclstack[1].wide
		do_setret(multregs[k],multxregs[k])
	od

	for i:=1 to k do
		regset[multregs[i]]:=xregset[multxregs[i]]:=0
	od
end

proc pc_free(pcl p)=
	delopnd()
end

proc pc_zstatic(pcl p)=
	ref pstrec d

	d:=p.def
	setsegment('Z',p.align)
	genmc(m_labelname,mgenmemaddr(d))

	genmc(m_resb,mgenint(p.size))
end

proc pc_istatic(pcl p)=
	setsegment('I',p.align)
	genmc(m_labelname,mgenmemaddr(p.def))
end

proc pc_db(pcl p)=
	do_db(p,m_db)
end

proc pc_dw(pcl p)=
	do_db(p,m_dw)
end

proc pc_dd(pcl p)=
	do_db(p,m_dd)
end

proc pc_dq(pcl p)=
	do_db(p,m_dq)
end

proc do_db(pcl p, int opc) =
	mcloperand ax

	case p.opndtype
	when int_opnd then ax:=mgenint(p.value)
	when real_opnd,real32_opnd then ax:=mgenrealimm(p.xvalue,p.size)
	when string_opnd then
		 ax:=mgenlabel(getstringindex(p.svalue))

	when memaddr_opnd then
		ax:=mgenmemaddr(p.def)
		ax.offset:=p.extra
	else
		merror("db/dq optype? #", opndnames[p.opndtype])
	esac

	genmc(opc,ax)
end

proc pcx_istruel_i64(pcl p) =
	mcloperand ax,bx,cx,dx

	ax:=genopnd_ld(xa)
	genmc(m_test, ax,ax)

	case p.opcode
	when k_unary then
		genmc_cond(m_setcc, ne_cond, bx:=changeopndsize(ax,1))
		genmc(m_movzx, changeopndsize(ax,4),bx)
		return

	when k_selecttrue then
		noxorclear:=1
		dx:=genopnd_ld(yb)
		cx:=genopnd_ld(xc)
		noxorclear:=0
		genmc_cond(m_cmovcc, nz_cond, cx,dx)
		delopnd()

	when k_jumpfalse then
		genmc_cond(m_jmpcc, z_cond, mgenlabel(p.labelno))
	else
		genmc_cond(m_jmpcc, nz_cond, mgenlabel(p.labelno))
	esac

	delopnd()
end

proc pcx_incr_i64(pcl p)=
	if ismemaddr(xa) then
		genmc(m_inc, mgenmem(pclstack[1].def))
	else
		genmc(m_inc, genopnd_ind(xa))
	fi
	delopnd()
end

proc pcx_decr_i64(pcl p)=
	if ismemaddr(xa) then
		genmc(m_dec, mgenmem(pclstack[1].def))
	else
		genmc(m_dec, genopnd_ind(xa))
	fi
	delopnd()
end

proc pcx_incr_short(pcl p)=
	genmc(m_inc, genopnd_ind(xa, size:p.size))
	delopnd()
end

proc pcx_decr_short(pcl p)=
	genmc(m_dec, genopnd_ind(xa, size:p.size))
	delopnd()
end

proc pcx_incr_ref(pcl p)=
	mcloperand ax
	if ismemaddr(xa) then
		ax:=mgenmem(pclstack[1].def)
	else
		ax:=genopnd_ind(xa)
	fi
	if p.scale=1 then
		genmc(m_inc, ax)
	else
		genmc(m_add, ax, mgenint(p.scale))
	fi
	delopnd()
end

proc pcx_decr_ref(pcl p)=
	mcloperand ax
	if ismemaddr(xa) then
		ax:=mgenmem(pclstack[1].def)
	else
		ax:=genopnd_ind(xa)
	fi
	if p.scale=1 then
		genmc(m_dec, ax)
	else
		genmc(m_sub, ax, mgenint(p.scale))
	fi
	delopnd()
end

proc pcx_incrload_i64(pcl p)=
	mcloperand ax,mx

	if ismemaddr(xa) then
		mx:=mgenmem(pclstack[1].def)
		ax:=makeregopnd(xa)
	else	
		mx:=genopnd_ind(xa)
		ax:=genopnd(xa)
	fi
	genmc((p.opindex=op_incrload_i64|m_inc|m_dec),mx)
	genmc(m_mov,ax,mx)
end

proc pcx_decrload_i64(pcl p)=
	pcx_incrload_i64(p)
end

proc pcx_incrload_short(pcl p)=
	mcloperand ax,px

	px:=genopnd_ind(xa,p.size)
	ax:=genopnd(xa)

	genmc((p.opindex=op_incrload_i64|m_inc|m_dec),px)
	genmc((ttisint[p.mode]|m_movsx|m_movzx),ax,px)
end

proc pcx_decrload_short(pcl p)=
	pcx_incrload_short(p)
end

proc pcx_incrload_ref(pcl p)=
	mcloperand ax,mx

	if ismemaddr(xa) then
		mx:=mgenmem(pclstack[1].def)
		ax:=makeregopnd(xa)
	else
		mx:=genopnd_ind(xa)
		ax:=genopnd(xa)
	fi

	if p.scale=1 then
		genmc((p.opindex=op_incrload_ref|m_inc|m_dec),mx)
	else
		genmc((p.opindex=op_incrload_ref|m_add|m_sub),mx, mgenint(p.scale))
	fi
	genmc(m_mov,ax,mx)
end

proc pcx_decrload_ref(pcl p)=
	pcx_incrload_ref(p)
end

proc pcx_loadincr_i64(pcl p)=
	mcloperand ax,mx

	if ismemaddr(xa) then
		mx:=mgenmem(pclstack[1].def)
	else
		mx:=genopnd_ind(xa)
	fi

	addreg_d64()
	ax:=genopnd()

	genmc(m_mov,ax,mx)
	genmc((p.opindex=op_loadincr_i64|m_inc|m_dec),mx)

	swapopnds(1,2)
	delopnd()
end

proc pcx_loaddecr_i64(pcl p)=
	pcx_loadincr_i64(p)
end

proc pcx_loadincr_ref(pcl p)=
	mcloperand ax,mx

	if ismemaddr(xa) then
		mx:=mgenmem(pclstack[1].def)
	else
		mx:=genopnd_ind(xa)
	fi

	addreg_d64()
	ax:=genopnd()

	genmc(m_mov,ax,mx)
	if p.scale=1 then
		genmc((p.opindex=op_loadincr_ref|m_inc|m_dec),mx)
	else
		genmc((p.opindex=op_loadincr_ref|m_add|m_sub),mx, mgenint(p.scale))
	fi

	swapopnds(1,2)
	delopnd()
end

proc pcx_loaddecr_ref(pcl p)=
	pcx_loadincr_ref(p)
end

function getcondcode(int opindex)int=
	case specoptogen[opindex]
	when eq_op then return eq_cond
	when ne_op then return ne_cond
	when lt_op then return lt_cond
	when le_op then return le_cond
	when ge_op then return ge_cond
	when gt_op then return gt_cond
	esac
	0	
end

function getcondcodeu(int opindex)int=
	case specoptogen[opindex]
	when eq_op then return eq_cond
	when ne_op then return ne_cond
	when lt_op then return ltu_cond
	when le_op then return leu_cond
	when ge_op then return geu_cond
	when gt_op then return gtu_cond
	esac
	0	
end

proc pcx_eq_i64(pcl p)=
	mcloperand ax,bx, cx,dx

	ax:=genopnd_ld(xb)
	bx:=genopnd(ya)

	if p.opindex in [op_ne_i64, op_eq_i64] and pclstack[1].fmt=imm_d64 and
			 pclstack[1].value=0 then
		genmc(m_test,ax,ax)
	else
		genmc(m_cmp,ax,bx)
	fi

	case p.opcode
	when k_jumpcc then
		genmc_cond(m_jmpcc,getcondcode(p.opindex), mgenlabel(p.labelno))
		delopnd()
		delopnd()
	when k_setcc then
		genmc_cond(m_setcc, getcondcode(p.opindex), bx:=changeopndsize(ax,1))
		genmc(m_movzx, changeopndsize(ax,4), bx)
		delopnd()
	else					!assume selectcc

		noxorclear:=1
		dx:=genopnd_ld(xc)
		cx:=genopnd_ld(wd)
		noxorclear:=0
		genmc_cond(m_cmovcc, getcondcode(p.opindex), cx,dx)
		delopnd()
		delopnd()
		delopnd()
	esac
end

proc pcx_ne_i64(pcl p)= {pcx_eq_i64(p)}
proc pcx_lt_i64(pcl p)= {pcx_eq_i64(p)}
proc pcx_le_i64(pcl p)= {pcx_eq_i64(p)}
proc pcx_ge_i64(pcl p)= {pcx_eq_i64(p)}
proc pcx_gt_i64(pcl p)= {pcx_eq_i64(p)}

proc pcx_lt_u64(pcl p)=
	mcloperand ax,bx
	ax:=genopnd_ld(xb)
	bx:=genopnd(ya)

	genmc(m_cmp,ax,bx)
	if p.opcode=k_jumpcc then
		genmc_cond(m_jmpcc,getcondcodeu(p.opindex), mgenlabel(p.labelno))
		delopnd()
		delopnd()

	else							!setcc
		genmc_cond(m_setcc, getcondcodeu(p.opindex), bx:=changeopndsize(ax,1))
		genmc(m_movzx, changeopndsize(ax,4), bx)
		delopnd()
	fi
end

proc pcx_le_u64(pcl p)= {pcx_lt_u64(p)}
proc pcx_ge_u64(pcl p)= {pcx_lt_u64(p)}
proc pcx_gt_u64(pcl p)= {pcx_lt_u64(p)}

proc pcx_eq_r64(pcl p)=
	mcloperand ax,bx
	ax:=genopnd_ld(xb)
	bx:=genopnd(ya)

IF P.OPCODE=K_SETCC THEN MERROR("EQ/R64/SETCC") FI
	genmc(m_comisd,ax,bx)
	genmc_cond(m_jmpcc,getcondcodeu(p.opindex), mgenlabel(p.labelno))
	delopnd()
	delopnd()
end

proc pcx_eq_r32(pcl p)=
	mcloperand ax,bx
	ax:=genopnd_ld(xb)
	bx:=genopnd(ya)

IF P.OPCODE=K_SETCC THEN MERROR("EQ/R32/SETCC") FI
	genmc(m_comiss,ax,bx)
	genmc_cond(m_jmpcc,getcondcodeu(p.opindex), mgenlabel(p.labelno))
	delopnd()
	delopnd()
end

proc pcx_ne_r64(pcl p)= {pcx_eq_r64(p)}
proc pcx_lt_r64(pcl p)= {pcx_eq_r64(p)}
proc pcx_le_r64(pcl p)= {pcx_eq_r64(p)}
proc pcx_ge_r64(pcl p)= {pcx_eq_r64(p)}
proc pcx_gt_r64(pcl p)= {pcx_eq_r64(p)}

proc pcx_ne_r32(pcl p)= {pcx_eq_r32(p)}
proc pcx_lt_r32(pcl p)= {pcx_eq_r32(p)}
proc pcx_le_r32(pcl p)= {pcx_eq_r32(p)}
proc pcx_ge_r32(pcl p)= {pcx_eq_r32(p)}
proc pcx_gt_r32(pcl p)= {pcx_eq_r32(p)}

proc pcx_eq_i128(pcl p)=
	mcloperand axlow,axhigh,bxlow,bxhigh, cx,dx, lxtrue, lxfalse

	if p.opcode<>k_jumpcc then
		merror("setcc/selcc/128")
	fi

	lxtrue:=mgenlabel(p.labelno)

	axhigh:=genopnd_ld(4)
	axlow:=genopnd_ld(3)
	bxhigh:=genopnd(2)
	bxlow:=genopnd(1)

	case p.opindex
	when op_eq_i128 then
		genmc(m_cmp,axlow,bxlow)
		genmc_cond(m_jmpcc,ne_cond,lxfalse:=mgenlabel())
		genmc(m_cmp,axhigh,bxhigh)
		genmc_cond(m_jmpcc,eq_cond,lxtrue)
		genmc(m_label,lxfalse)
	when op_ne_i128 then
		genmc(m_cmp,axlow,bxlow)
		genmc_cond(m_jmpcc,ne_cond,lxtrue)
		genmc(m_cmp,axhigh,bxhigh)
		genmc_cond(m_jmpcc,ne_cond,lxtrue)
	else
		genmc(m_sub, axlow,bxlow)
		genmc(m_sbb, axhigh,bxhigh)

		genmc(m_cmp,axhigh, mm.zero_opnd)
		case p.opindex
		when op_lt_i128 then
			genmc_cond(m_jmpcc, lt_cond, lxtrue)
		when op_le_i128 then
			genmc_cond(m_jmpcc, lt_cond, lxtrue)
			genmc(m_orx,axlow,axhigh)
			genmc_cond(m_jmpcc, eq_cond, lxtrue)
		when op_gt_i128 then
			genmc_cond(m_jmpcc, lt_cond, lxfalse:=mgenlabel())
			genmc(m_orx,axlow,axhigh)
			genmc_cond(m_jmpcc, ne_cond, lxtrue)
			genmc(m_label,lxfalse)
		when op_ge_i128 then
			genmc_cond(m_jmpcc, ge_cond, lxtrue)
	ELSE
MERROR("I128/EQA")
		esac
	esac

	delopnd()
	delopnd()
	delopnd()
	delopnd()

end


proc pcx_ne_i128(pcl p) = {pcx_eq_i128(p)}
proc pcx_lt_i128(pcl p) = {pcx_eq_i128(p)}
proc pcx_le_i128(pcl p) = {pcx_eq_i128(p)}
proc pcx_ge_i128(pcl p) = {pcx_eq_i128(p)}
proc pcx_gt_i128(pcl p) = {pcx_eq_i128(p)}

proc pcx_le_u128(ref pclrec p) = {pcx_lt_u128(p)}
proc pcx_ge_u128(ref pclrec p) = {pcx_lt_u128(p)}
proc pcx_gt_u128(ref pclrec p) = {pcx_lt_u128(p)}

proc pcx_lt_u128(ref pclrec p) =
	mcloperand lxtrue,lxfalse, ax1,bx1,ax2,bx2
	int cond1,cond2,cond3

	case p.opindex
	when op_gt_u128 then
		cond1:=gtu_cond
		cond2:=ltu_cond
		cond3:=gtu_cond
	when op_ge_u128 then
		cond1:=gtu_cond
		cond2:=ltu_cond
		cond3:=geu_cond
	when op_lt_u128 then
		cond1:=ltu_cond
		cond2:=gtu_cond
		cond3:=ltu_cond
	when op_le_u128 then
		cond1:=ltu_cond
		cond2:=gtu_cond
		cond3:=leu_cond
	else
MERROR("JCC/U128")
	esac

	lxtrue:=mgenlabel(p.labelno)
	lxfalse:=mgenlabel(++labelno)

	ax2:=genopnd_ld(4)
	ax1:=genopnd_ld(3)
	bx2:=genopnd(2)
	bx1:=genopnd(1)

	genmc(m_cmp,ax2,bx2)
	genmc_cond(m_jmpcc, cond1, lxtrue)
	genmc_cond(m_jmpcc, cond2, lxfalse)
	genmc(m_cmp,ax1,bx1)
	genmc_cond(m_jmpcc, cond3, lxtrue)

	genmc(m_label,lxfalse)

	delopnd()
	delopnd()
	delopnd()
	delopnd()
end

proc pc_startmult(pcl p)=
	pushallopnds()
end

proc pc_endmult(pcl p)=
	pc_resetmult(p)
end

proc pc_resetmult(pcl p)=

	if pclstack[1].float then

MERROR("RESETMULT/XREG")

	else
		movetoreg(r0)
	fi

	if p.opcode=k_resetmult then
		delopnd()
	fi
end

proc pc_forup(pcl p)=
	do_for(p, m_inc, m_add, le_cond)
end

proc do_for(pcl p, int incop, addop, cond)=
	pcl q,r
	mcloperand ax,bx,cx,dx,mx
	int reg

	q:=currpcl.nextpcl
	r:=currpcl:=q.nextpcl

	mx:=mgenmem(q.def)

	if q.def.reg then
		if p.step=1 then
			genmc(incop, mx)
		else
			genmc(addop, mx, mgenint(p.step))
		fi
		ax:=mx
	else
		ax:=mgenreg(getnextreg())
		genmc(m_mov, ax,mx)
		if p.step=1 then
			genmc(incop, ax)
		else
			genmc(addop, ax, mgenint(p.step))
		fi
		genmc(m_mov, mx, ax)
	fi

	if r.opndtype=int_opnd then
		bx:=mgenint(r.value)
	else
		bx:=mgenmem(r.def)
	fi

	genmc(m_cmp, ax, bx)
	freereg(ax.reg)

	genmc_cond(m_jmpcc, cond, mgenlabel(p.labelno))
end

proc pc_fordown(pcl p) =
	do_for(p, m_dec, m_sub, ge_cond)
end

proc pcx_addto_i64(pcl p)= {do_binto_i64(p,m_add)}
proc pcx_subto_i64(pcl p)= {do_binto_i64(p,m_sub)}
proc pcx_iandto_i64(pcl p)= {do_binto_i64(p,m_andx)}
proc pcx_iorto_i64(pcl p)= {do_binto_i64(p,m_orx)}
proc pcx_ixorto_i64(pcl p)= {do_binto_i64(p,m_xorx)}

proc pcx_addto_short(pcl p)= {do_binto_i64(p,m_add)}
proc pcx_subto_short(pcl p)= {do_binto_i64(p,m_sub)}
proc pcx_iandto_short(pcl p)= {do_binto_i64(p,m_andx)}
proc pcx_iorto_short(pcl p)= {do_binto_i64(p,m_orx)}
proc pcx_ixorto_short(pcl p)= {do_binto_i64(p,m_xorx)}

proc do_binto_i64(pcl p, int opc)=
	mcloperand ax,bx,rx
	int reg,size

	size:=p.size

	if size=8 and ismemaddr(xb) then
		ax:=mgenmem(pclstack[2].def)
		reg:=getnextreg()
		rx:=mgenreg(reg)
		genmc(m_mov, rx, ax)
		bx:=genopnd(ya)
		genmc(opc,rx,bx)
		genmc(m_mov, ax,rx)
		freereg(reg)
	else
		ax:=genopnd_ind(xb,size:size)
		bx:=genopnd_ld(ya,size)

		genmc(opc,ax,bx)
	fi
	delopnd()
	delopnd()
end

proc do_binto_r64(pcl p, int opc)=
	mcloperand ax,bx,cx

	addreg_x64()
	ax:=genopnd_ind(xc)
	bx:=genopnd(yb)
	cx:=genopnd(za)

	genmc(m_movq, cx,ax)
	genmc(opc, cx,bx)
	genmc(m_movq, ax,cx)

	delopnd()
	delopnd()
	delopnd()
end

proc do_binto_r32(pcl p, int opc)=
	mcloperand ax,bx,cx

	addreg_x32()
	ax:=genopnd_ind(xc,4)
	bx:=genopnd(yb)
	cx:=genopnd(za)

	genmc(m_movd, cx,ax)
	genmc(opc, cx,bx)
	genmc(m_movd, ax,cx)

	delopnd()
	delopnd()
	delopnd()
end

proc pcx_addto_r64(pcl p)= {do_binto_r64(p, m_addsd)}
proc pcx_subto_r64(pcl p)= {do_binto_r64(p, m_subsd)}
proc pcx_multo_r64(pcl p)= {do_binto_r64(p, m_mulsd)}
proc pcx_divto_r64(pcl p)= {do_binto_r64(p, m_divsd)}

proc pcx_addto_r32(pcl p)= {do_binto_r32(p, m_addss)}
proc pcx_subto_r32(pcl p)= {do_binto_r32(p, m_subss)}
proc pcx_multo_r32(pcl p)= {do_binto_r32(p, m_mulss)}
proc pcx_divto_r32(pcl p)= {do_binto_r32(p, m_divss)}


proc pcx_multo_i64(pcl p)=
	mcloperand ax,bx,cx

	addreg_d64()
	ax:=genopnd_ind(xc)
	bx:=genopnd(yb)

	cx:=genopnd(za)

	genmc(m_mov, cx,ax)

	if  pclstack[2].fmt=imm_d64 then
		mulimm(cx, pclstack[2].value)
	else
		genmc(m_imul2, cx,bx)
	fi
	genmc(m_mov, ax,cx)

	delopnd()
	delopnd()
	delopnd()
end

proc pcx_maxto_i64(pcl p)=
	mcloperand ax,bx,lx
	int lab, cond

	ax:=genopnd_ind(xb)
	bx:=genopnd_ld(ya)

	case p.opindex
	when op_minto_i64 then cond:=le_cond
	when op_maxto_i64 then cond:=ge_cond
	when op_minto_u64 then cond:=leu_cond
	when op_maxto_u64 then cond:=geu_cond
	esac

	genmc(m_cmp, ax, bx)
	lab:=++labelno

	genmc_cond(m_jmpcc, cond, lx:=mgenlabel(lab))
	genmc(m_mov, ax,bx)
	genmc(m_label, lx)
	delopnd()
	delopnd()
end

proc pcx_minto_i64(pcl p)={pcx_maxto_i64(p)}
proc pcx_maxto_u64(pcl p)={pcx_maxto_i64(p)}
proc pcx_minto_u64(pcl p)={pcx_maxto_i64(p)}

proc pcx_minto_r64(pcl p)={pcx_maxto_r64(p)}

proc pcx_maxto_r64(pcl p)=
	mcloperand px,ax,bx,lx
	int lab, cond

	px:=genopnd_ind(xb)
	bx:=genopnd_ld(ya)
	addreg_x64()
	ax:=genopnd(xa)

	case p.opindex
	when op_minto_r64 then cond:=leu_cond
	when op_maxto_r64 then cond:=geu_cond
	esac

	genmc(m_movq, ax, px)

	genmc(m_comisd, ax, bx)
	lab:=++labelno

	genmc_cond(m_jmpcc, cond, lx:=mgenlabel(lab))
	genmc(m_movq, px,bx)
	genmc(m_label, lx)
	delopnd()
	delopnd()
	delopnd()
end

proc pcx_add_refoff(pcl p)=
	mcloperand ax,cx

	cx:=do_addrmode(p)

	if pclstack[2].loc<>reg_loc then
		pclstack[2].fmt:=reg_d64			!reg not needed to load addr, but
		pclstack[2].loc:=reg_loc			!need to prepare it for result
		pclstack[2].reg:=getnextreg()		!(although wasted for floats)
	fi
	ax:=genopnd(xb)

	genmc(m_lea, ax, cx)
	delopnd()
end

proc pcx_sub_refoff(pcl p)=
	int scale, extra, offset
	mcloperand ax,bx

	scale:=p.scale
	extra:=p.extra

	ax:=genopnd_ld(xb)

	if pclstack[1].fmt=imm_d64 then
		genmc(m_sub, ax, mgenint(pclstack[1].value*scale+extra))
	else
		bx:=genopnd_ld(xa)
		scale:=scaleindex(bx,scale)
		if scale>1 then
			mulimm(bx,scale)
		fi
		genmc(m_sub, ax, bx)
		if extra then
MERROR("SUBREF/EXTRA")
		fi
	fi
	delopnd()
end

proc pcx_addto_refoff(pcl p)=
	int scale, extra,offset
	scale:=p.scale
	extra:=p.extra
	offset:=pclstack[1].value*scale+extra	!in case imm_d64

	mcloperand ax,bx,rx
	int reg,size


	if ismemaddr(xb) then
		ax:=mgenmem(pclstack[2].def)
		reg:=getnextreg()
		rx:=mgenreg(reg)

		genmc(m_mov, rx, ax)

		if pclstack[1].fmt=imm_d64 then
			genmc(m_add,rx,mgenint(offset))
		else
			bx:=genopnd_ld(ya)
			mulimm(bx,scale)
			genmc(m_add,rx,bx)
		fi

		genmc(m_mov, ax,rx)
		freereg(reg)
	else
		ax:=genopnd_ind(xb)
		if pclstack[1].fmt=imm_d64 then
			genmc(m_add,ax,mgenint(offset))
		else
			bx:=genopnd_ld(ya)
			mulimm(bx,scale)
			genmc(m_add,ax,bx)
		fi
	fi
	delopnd()
	delopnd()
end

proc pcx_subto_refoff(pcl p)=
	int scale, extra
	mcloperand ax,bx

	scale:=p.scale
	extra:=p.extra

	ax:=genopnd_ind(xb)

	if pclstack[1].fmt=imm_d64 then
		genmc(m_sub, ax, mgenint(pclstack[1].value*scale+extra))
	else
		bx:=genopnd_ld(xa)
		scale:=scaleindex(bx,scale)
		if scale>1 then
			mulimm(bx,scale)
		fi
		genmc(m_sub, ax, bx)
		if extra then
MERROR("SUBTOREF/EXTRA")
		fi
	fi

	delopnd()
	delopnd()
end

proc pc_pushptroff(pcl p)=
	mcloperand ax,bx,cx,fx
	int m

	m:=p.mode

	cx:=do_addrmode(p)

	if pclstack[2].loc<>reg_loc then
		pclstack[2].fmt:=reg_d64			!reg not needed to load addr, but
		pclstack[2].loc:=reg_loc			!need to prepare it for result
		pclstack[2].reg:=getnextreg()		!(although wasted for floats)
	fi
	ax:=genopnd(xb)


	case ttcat[m]
	when d64_cat then
		genmc(m_mov, ax, cx)

	when x64_cat then
		addreg_x64()
		swapopnds(1,3)
		fx:=genopnd(xc)

		genmc(m_movq, fx, cx)
		delopnd()

	when x32_cat then
		addreg_x32()
		swapopnds(1,3)
		fx:=genopnd(xc)

		genmc(m_movd, fx, changeopndsize(cx,4))
		delopnd()

	when short_cat then
		cx.size:=ttsize[m]
		genmc((ttisint[m]|m_movsx|m_movzx), ax, cx)

	when wide_cat then
		bx:=genopnd_d64()
		swapopnds(1,2)
		swapopnds(2,3)
		genmc(m_mov, bx, applyoffset(cx,8,8))
		genmc(m_mov, ax, changeopndsize(cx,8))
		delopnd()
		setwideopnd()
		return
	when block_cat then
		genmc(m_lea, ax, cx)

	else
		merror("pushptroff ",stdnames[m])
	esac	

	delopnd()

end

function scaleindex(mcloperand ax, int scale)int=
	int n
	if scale in [1,2,4,8] then return scale fi
	mulimm(ax,scale)
	return 1
end

function scaleregvar(int reg, &scale, n)int=
	int regix
	mcloperand ax

	if scale in [1,2,4,8] then return reg fi

	regix:=getnextreg()
	ax:=mgenreg(regix)
	genmc(m_mov,ax, mgenreg(reg))

	pclstack[n].fmt:=reg_d64
	pclstack[n].loc:=reg_loc
	pclstack[n].reg:=regix
	mulimm(ax,scale)
	scale:=1

	return regix
end

proc pc_popptroff(pcl p)=
	mcloperand ax,bx,cx,px
	int m

	m:=p.mode

	px:=do_addrmode(p)
	cx:=genopnd_ld(xc)

	case ttcat[m]
	when d64_cat then
		genmc(m_mov, px,cx)

	when x64_cat then
		genmc(m_movq, px,cx)

	when x32_cat then
		genmc(m_movd, changeopndsize(px,4),cx)

	when short_cat then
		px.size:=ttsize[m]
		genmc(m_mov, px,changeopndsize(cx,ttsize[m]))

	when wide_cat then
		genmc(m_mov, changeopndsize(px,8),cx)
		genmc(m_mov, applyoffset(px,8,8),genopnd_ld(xc+1))

	when block_cat then
		copyblock(px,makeopndind(cx),p.size)

	else
		merror("popptroff ",stdnames[m])
	esac	

	delopnd()
	delopnd()
	if p.opcode=k_popptroff then
		delopnd()
		if ttcat[m]=wide_cat then
			delopnd()
		fi
	fi
end

proc pc_storeptroff(pcl p)=
	pc_popptroff(p)
end

proc pc_pushptr(pcl p)=
	mcloperand ax,px,cx,fx,bx
	int m

	m:=p.mode
	if isregvaropnd(xa) and ttcat[m]<>block_cat then
		cx:=mgenireg(pclstack[1].reg)
		ax:=makeregopnd(xa)
	elsif pclstack[xa].fmt=imm_memaddr then
		cx:=mgenmem(pclstack[1].def)
		ax:=makeregopnd(1)
	else
		ax:=genopnd_ld()
		cx:=makeopndind(ax)
	fi

	case ttcat[m]
	when d64_cat then
		genmc(m_mov, ax, cx)

	when short_cat then
		genmc((ttisint[m]|m_movsx|m_movzx), ax, changeopndsize(cx,ttsize[m]))

	when x64_cat then
		addreg_x64()
		swapopnds(1,2)
		fx:=genopnd(xb)

		genmc(m_movq, fx, cx)
		delopnd()

	when x32_cat then
		addreg_x32()
		swapopnds(1,2)
		fx:=genopnd(xb)

		genmc(m_movd, fx, changeopndsize(cx,4))
		delopnd()

	when wide_cat then
		bx:=genopnd_d64()
		genmc(m_mov, bx, applyoffset(cx,8))
		genmc(m_mov, ax, cx)
		setwideopnd()

	when block_cat then		!nothing further needed

	else

		MGENCOMMENT("****PUSHPTR")
	esac	

end

proc pc_popptr(pcl p)=
	mcloperand ax,bx,cx,px
	int m

	m:=p.mode
	bx:=genopnd_ld(xb)
	if isregvaropnd(xa) and ttcat[m]<>block_cat then
		ax:=mgenireg(pclstack[1].reg)
	else
		ax:=genopnd_ind(ya)
	fi

	case ttcat[m]
	when d64_cat then
		genmc(m_mov, ax,bx)

	when short_cat then
		genmc(m_mov, changeopndsize(ax,ttsize[m]),changeopndsize(bx,ttsize[m]))

	when x64_cat then
		genmc(m_movq, ax,bx)

	when x32_cat then
		genmc(m_movd, changeopndsize(ax,4),bx)

	when wide_cat then
		genmc(m_mov, ax,bx)
		genmc(m_mov, applyoffset(ax,8),genopnd_ld(xb+1))

	when block_cat then
		copyblock(ax,makeopndind(bx),p.size)

	else
		merror("popptr ",stdnames[m])
	esac	

	delopnd()
	if p.opcode=k_popptr then
		delopnd()
		if ttcat[m]=wide_cat then
			delopnd()
		fi
	fi

end

proc pc_storeptr(pcl p)=
	pc_popptr(p)
end

proc pc_swap(pcl p)=
	mcloperand ax,bx

	mcloperand px:=genopnd_ind(xb,p.size)
	mcloperand qx:=genopnd_ind(ya,p.size)

	ax:=mgenreg(getnextreg(),p.size)
	bx:=mgenreg(getnextreg(),p.size)

	case ttcat[p.mode]
	when d64_cat,short_cat then
		genmc(m_mov, ax, px)
		genmc(m_mov, bx, qx)
		genmc(m_mov, qx, ax)
		genmc(m_mov, px, bx)

	else
		merror("swap",stdnames[p.mode])
	esac

	freereg(ax.reg)
	freereg(bx.reg)

	delopnd()
	delopnd()

end

proc pcx_neg_i64(pcl p)=
	mcloperand ax
	ax:=genopnd_ld(xa)

	genmc(m_neg,ax)
end

proc pcx_neg_r64(pcl p)=
	if not labneg64 then labneg64:=mcreatefwdlabel() fi
	genmc(m_xorpd,genopnd_ld(xa),mgenlabelmem(labneg64))
end

proc pcx_neg_r32(pcl p)=
	if not labneg32 then labneg32:=mcreatefwdlabel() fi
	genmc(m_xorps,genopnd_ld(xa),mgenlabelmem(labneg32))
end

proc pcx_abs_r64(pcl p)=
	if not lababs64 then lababs64:=mcreatefwdlabel() fi
	genmc(m_andpd,genopnd_ld(xa),mgenlabelmem(lababs64))
end

proc pcx_abs_r32(pcl p)=
	if not lababs32 then lababs32:=mcreatefwdlabel() fi
	genmc(m_andps,genopnd_ld(xa),mgenlabelmem(lababs32))
end

proc pcx_inot_i64(pcl p)=
	mcloperand ax
	ax:=genopnd_ld(xa)

	genmc(m_notx,ax)
end

proc pcx_abs_i64(pcl p)=
	mcloperand ax, lx

	ax:=genopnd_ld(xa)
	genmc(m_cmp, ax, mgenint(0))

	genmc_cond(m_jmpcc, ge_cond, lx:=mgenlabel(++labelno))
	genmc(m_neg,ax)
	genmc(m_label, lx)

end

proc pcx_sqr_i64(pcl p)=
	mcloperand ax
	ax:=genopnd_ld(xa)

	genmc(m_imul2,ax,ax)
end

proc pcx_sqr_r64(pcl p)=
	mcloperand ax
	ax:=genopnd_ld(xa)

	genmc(m_mulsd,ax,ax)
end

proc pcx_sqr_r32(pcl p)=
	mcloperand ax
	ax:=genopnd_ld(xa)

	genmc(m_mulss,ax,ax)
end

proc pcx_sqrt_r64(pcl p)=
	mcloperand ax
	ax:=genopnd_ld(xa)

	genmc(m_sqrtsd,ax,ax)
end

proc pcx_sqrt_r32(pcl p)=
	mcloperand ax
	ax:=genopnd_ld(xa)

	genmc(m_sqrtss,ax,ax)
end

proc do_shift(pcl p, int opc)=
	mcloperand ax
	ax:=genopnd_ld(xb)

	if pclstack[1].fmt=imm_d64 then
		genmc(opc, ax, mgenint(pclstack[1].value))
	else
		if inf_r10used then merror("shift:cl in use") fi
		loadparam(reg:r10)
		genmc(opc,ax, mgenreg(r10,1))
	fi
	delopnd()
end

proc pcx_shr_i64(pcl p)= {do_shift(p, m_sar)}
proc pcx_shr_u64(pcl p)= {do_shift(p, m_shr)}
proc pcx_shl_i64(pcl p)= {do_shift(p, m_shl)}

proc pcx_idiv_i64(pcl p)= {do_divrem(p, issigned:1, isdiv:1)}
proc pcx_irem_i64(pcl p)= {do_divrem(p, issigned:1, isdiv:0)}
proc pcx_idiv_u64(pcl p)= {do_divrem(p, issigned:0, isdiv:1)}
proc pcx_irem_u64(pcl p)= {do_divrem(p, issigned:0, isdiv:0)}

proc do_divrem(pcl p, int issigned, isdiv)=
	int opc, n, shifts

	loadopnd(2)

	if isdiv and pclstack[1].fmt=imm_d64 then
		n:=pclstack[1].value
		case n
		when 0 then
			merror("Divide by zero")
		when 1 then
			delopnd()
			return
		else
			shifts:=ispoweroftwo(n)
			if shifts then
				genmc((issigned|m_sar|m_shr), genopnd(xb), mgenint(shifts))
				delopnd()
				return
			fi
		esac
	fi 

	loadopnd(1)
	saverdx()
	fixdivopnds()

	if issigned then
		genmc(m_cqo)
		opc:=m_idiv
	else
		genmc(m_xorx, mgenreg(r11),mgenreg(r11))
		opc:=m_div
	fi

	genmc(opc, genopnd(ya,p.size))

	if not isdiv then
		genmc(m_xchg,mgenreg(r0),mgenreg(r11))
	fi
	restorerdx()

	delopnd()

end

proc fixdivopnds=
	int regx,regy,zop

	regx:=pclstack[2].reg
	regy:=pclstack[1].reg

	if regx=r0 then			!regy will be OK
		return
	fi
	if regy=r0 then			!need to swap then
		genmc(m_xchg,genopnd(xb),genopnd(ya))
		swapopnds(1,2)		!switch operands
		return
	fi

	if regset[r0]=0 then	!d0 not in use
		genmc(m_xchg,mgenreg(r0),genopnd(xb))
		regset[regx]:=0
		pclstack[2].reg:=r0
		regset[r0]:=1
		return
	fi

	for zop:=noperands downto 1 do
		if pclstack[zop].loc=reg_loc and pclstack[zop].reg=r0 then exit fi
	od

	genmc(m_xchg,mgenreg(r0),genopnd(xb))	
	swap(pclstack[2].reg,pclstack[zop].reg)		!switch registers

end

proc saverdx=
	if inf_r11used then
		genmc(m_push, mgenreg(r11))
	fi
end

proc restorerdx=
	if inf_r11used then
		genmc(m_pop, mgenreg(r11))
	fi
end

proc pcx_fix_r64_i64(pcl p)=
	mcloperand fx,ax
	fx:=genopnd_ld(xa)
	addreg_d64()
	ax:=genopnd(xa)
	genmc(m_cvttsd2si, ax, fx)
	swapopnds(1,2)
	delopnd()
end

proc pcx_fix_r32_i64(pcl p)=
	mcloperand fx,ax
	fx:=genopnd_ld(xa)
	addreg_d64()
	ax:=genopnd(xa)
	genmc(m_cvttss2si, ax, fx)
	swapopnds(1,2)
	delopnd()
end

proc pcx_float_i64_r64(pcl p)=
	mcloperand fx,ax
	ax:=genopnd_ld(xa)
	addreg_x64()
	fx:=genopnd(xa)
	genmc(m_cvtsi2sd, fx, ax)
	swapopnds(1,2)
	delopnd()
end

proc pcx_float_u64_r64(pcl p)=
	do_syscall(sysfn_float_u64_r64,1,x64_cat)
end

proc pcx_float_i64_r32(pcl p)=
	mcloperand fx,ax
	ax:=genopnd_ld(xa)
	addreg_x32()
	fx:=genopnd(xa)
	genmc(m_cvtsi2ss, fx, ax)
	swapopnds(1,2)
	delopnd()
end

proc pcx_fnarrow_r64_r32(pcl p)=
	mcloperand ax:=genopnd_ld(xa)
	genmc(m_cvtsd2ss, ax,ax)
	pclstack[1].fmt:=xreg_x32
end

proc pc_switchlabel(pcl p)=
	genmc(m_dq, mgenlabel(p.labelno))
end

proc pc_endswitch(pcl p)=
	setsegment('C')
end

proc pc_info(pcl p)=
	infopcl:=p
end

proc pc_switch(pcl p)=
	int minlab, maxlab, jumplab, elselab
	mcloperand ax

	minlab:=p.minlab
	maxlab:=p.maxlab
	jumplab:=p.labelno
	elselab:=infopcl.labelno

	ax:=genopnd_ld(xa)
	if minlab<>0 then
		genmc(m_sub,ax,mgenint(minlab))
	fi
	genmc(m_cmp,ax,mgenint(maxlab-minlab+1))
	genmc_cond(m_jmpcc,geu_cond,mgenlabel(elselab))
	genmc(m_jmp, mgenindex(ireg:ax.reg,scale:8,labno:jumplab))

	delopnd()

	setsegment('I')
end

proc pc_casejumpeq_d64(pcl p)=
	genmc(m_cmp, genopnd_ld(xb), genopnd(ya))
	genmc_cond(m_jmpcc, eq_cond, mgenlabel(p.labelno))
	delopnd()
end

proc pcx_truncate_i64(pcl p)=
	mcloperand ax
	int mask

	case ttsize[p.truncmode]
	when 1 then mask:=255
	when 2 then mask:=65535
	when 4 then mask:=0xFFFF'FFFF
	esac

	ax:=genopnd_ld(xa)
	genmc(m_andx, ax, mgenint(mask))

	genmc((ttisint[p.truncmode]|m_movsx|m_movzx), ax, changeopndsize(ax,ttsize[p.truncmode]))
end

proc pcx_fwiden_r32_r64(pcl p)=
	mcloperand fx
	fx:=genopnd_ld()
	genmc(m_cvtss2sd, fx,fx)
	pclstack[1].fmt:=xreg_x64
end

proc pcx_widen_i64_i128(pcl p)=
	mcloperand ax,bx,bx2,lx

	ax:=genopnd_ld()
	bx:=genopnd_d64()
	bx2:=changeopndsize(bx,4)

	swapopnds(1,2)

	genmc(m_xorx,bx2,bx2)
	genmc(m_cmp,ax,mgenint(0))
	genmc_cond(m_jmpcc, ge_cond, lx:=mgenlabel(++labelno))
	genmc(m_notx, bx)
	genmc(m_label,lx)

	setwideopnd()
end

proc pcx_widen_u64_u128(pcl p)=
	mcloperand ax,bx,bx2,lx

	ax:=genopnd_ld()
	bx:=genopnd_d64()
	bx2:=changeopndsize(bx,4)

	swapopnds(1,2)

	genmc(m_xorx,bx2,bx2)

	setwideopnd()
end

proc pcx_softtrunc_128_64(pcl p)=
	mcloperand ax,bx,bx2,lx

	ax:=genopnd_ld()
	swapopnds(1,2)
	delopnd()
	unsetwideopnd()
end

proc pcx_notl_i64(pcl p)=
	genmc(m_xorx, genopnd_ld(), mgenint(1))
end

proc pcx_max_i64(pcl p)=
	mcloperand ax,bx
	int cond

	ax:=genopnd_ld(xb)
	bx:=genopnd_ld(ya)

	case p.opindex
	when op_min_i64 then cond:=gt_cond
	when op_max_i64 then cond:=lt_cond
	when op_min_u64 then cond:=gtu_cond
	when op_max_u64 then cond:=ltu_cond
	esac

	genmc(m_cmp, ax, bx)
	genmc_cond(m_cmovcc, cond, ax, bx)

	delopnd()
end

proc pcx_max_u64(pcl p)={pcx_max_i64(p)}
proc pcx_min_i64(pcl p)={pcx_max_i64(p)}
proc pcx_min_u64(pcl p)={pcx_max_i64(p)}

proc pc_jumpnotinrange(pcl p)=
	mcloperand ax,bx,cx,lx
	int issigned

	ax:=genopnd_ld(xc)
	bx:=genopnd(yb)
	cx:=genopnd(za)

	lx:=mgenlabel(p.labelno)
	issigned:=ttisint[p.mode]

	genmc(m_cmp, ax,bx)

	genmc_cond(m_jmpcc, (issigned|lt_cond|ltu_cond),lx)
	genmc(m_cmp, ax, cx)
	genmc_cond(m_jmpcc, (issigned|gt_cond|gtu_cond),lx)

	delopnd()
	delopnd()
	delopnd()
end

proc pc_jumpinrange(pcl p)=
	mcloperand ax,bx,cx,lx,nolx
	int issigned,nolab

	ax:=genopnd_ld(xc)
	bx:=genopnd(yb)
	cx:=genopnd(za)

	lx:=mgenlabel(p.labelno)
	issigned:=ttisint[p.mode]

	genmc(m_cmp, ax,bx)

	nolx:=mgenlabel(nolab:=mcreatefwdlabel())
	genmc_cond(m_jmpcc, (issigned|lt_cond|ltu_cond),nolx)
	genmc(m_cmp, ax, cx)
	genmc_cond(m_jmpcc, (issigned|le_cond|leu_cond),lx)
	mdefinefwdlabel(nolab)

	delopnd()
	delopnd()
	delopnd()
end

proc pc_setjumpeq_d64(pcl p) =
	genmc(m_cmp,genopnd_ld(xb),genopnd(ya))

	genmc_cond(m_jmpcc, eq_cond, mgenlabel(p.labelno))
	delopnd()
end

proc pc_setjumpeqx_d64(pcl p) =
	genmc(m_cmp,genopnd_ld(xb),genopnd(ya))

	genmc_cond(m_jmpcc, eq_cond, mgenlabel(p.labelno))
	delopnd()
	delopnd()
end

proc pc_setjumpne_d64(ref pclrec p) =
	genmc(m_cmp,genopnd(xb),genopnd(ya))

	genmc_cond(m_jmpcc, ne_cond, mgenlabel(p.labelno))
	delopnd()
	delopnd()
end

proc do_shiftnto(pcl p,int opc)=
	mcloperand px

	px:=genopnd_ind(xb)

	if pclstack[1].fmt=imm_d64 then
		genmc(opc, px, mgenint(pclstack[1].value))
	else
		if inf_r10used then merror("shiftto:cl in use") fi
		loadparam(1,r10)
		genmc(opc, px, mgenreg(r10,1))
	fi

	delopnd()
	delopnd()
end

proc pcx_shrto_i64(pcl p) = {do_shiftnto(p, m_sar)}
proc pcx_shrto_u64(pcl p) = {do_shiftnto(p, m_shr)}
proc pcx_shlto_i64(pcl p) = {do_shiftnto(p, m_shl)}

proc pc_typepun(pcl p)=
	mcloperand ax,bx,cx

	bx:=genopnd_ld(xa)

	case ttcat[p.mode]
	when d64_cat then
		case pclstack[1].fmt
		when xreg_x64 then
			addreg_d64()
			ax:=genopnd(xa)
            genmc(m_movq,ax,bx)
			swapopnds(1,2)
			delopnd()
		when reg_d64 then
		else
			goto error
		esac

	when x64_cat then
		case pclstack[1].fmt
		when reg_d64 then
			addreg_x64()
			ax:=genopnd(xa)
            genmc(m_movq,ax,bx)
			swapopnds(1,2)
			delopnd()
		else
			goto error
		esac
	when short_cat then
		case pclstack[1].fmt
		when xreg_x32 then
			addreg_d64()
			ax:=genopnd(xa)
			cx:=changeopndsize(ax,4)
            genmc(m_movd, cx,bx)
			swapopnds(1,2)
			delopnd()

			genmc((ttisint[p.mode]|m_movsx|m_movzx),ax,cx)
		when reg_d64 then

		else
			goto error
		esac

	else
error::
CPL =STRMODE(P.MODE)
CPL =FMTNAMES[PCLSTACK[1].FMT]
CPL "TYPEPUN"
		MERROR("TYPEPUN")
	esac

end

proc pcx_sin_r64(pcl p) = {do_maths(p,"sin*")}
proc pcx_cos_r64(pcl p) = {do_maths(p,"cos*")}
proc pcx_atan_r64(pcl p) = {do_maths(p,"atan*")}
proc pcx_ln_r64(pcl p) = {do_maths(p,"log*")}
proc pcx_log_r64(pcl p) = {do_maths(p,"log*")}
proc pcx_exp_r64(pcl p) = {do_maths(p,"exp*")}
proc pcx_floor_r64(pcl p) = {do_maths(p,"floor*")}
proc pcx_ceil_r64(pcl p) = {do_maths(p,"ceil*")}

proc do_maths(pcl p, ichar opname)=
	int nslots
	p.nargs:=1

	pc_setalign(p)

	nslots:=do_pushparams(p,0)

	genmc(m_call, mgenextname(opname))

	poparg()

	popslots(nslots)

	dogetretvalue(p)
end

proc dogetretvalue(pcl p)=
	int reg,xreg

	if p.nmult<=1 then
		dogetretvalue_n(r0,r0,ttcat[p.mode])
		if ttcat[p.mode]=short_cat then
			genmc((ttisint[p.mode]|m_movsx|m_movzx), mgenreg(r0),mgenreg(r0,p.size))
		fi
	else
		for i:=p.nmult downto 1 do
			dogetretvalue_n(multregs[i],multxregs[i],p.retcats[i])
			if p.retcats[i]=short_cat then merror("mult/short") fi
			if p.retcats[i]=wide_cat then merror("mult/wide") fi
		od
	fi
end

proc dogetretvalue_n(int reg,xreg,cat)=

	case cat
	when d64_cat,short_cat then
		addreg0(reg)
	when x64_cat then
		addxreg0(xreg,xreg_x64)
	when x32_cat then
		addxreg0(xreg,xreg_x32)
	when wide_cat then
		addwidereg0(reg)
	else
CPL TYPECATNAMES[CAT]
		merror("getretval/n?")
	esac
end

proc getretvalue_bycat(int cat)=

	case cat
	when 0 then
		return
	when d64_cat then
		addreg0(r0)
	when x64_cat then
		addxreg0(r0,xreg_x64)
	when x32_cat then
		addxreg0(r0,xreg_x32)
	when wide_cat then
		addwidereg0(r0)
	else
		merror("getval bycat")
	esac
end

function isregvaropnd(int n)int=
	if pclstack[n].loc=regvar_loc then return 1 fi
	return 0
end

function ismemaddr(int n)int=
	if pclstack[n].fmt=imm_memaddr then return 1 fi
	return 0
end

function isimm64(int n)int=
	if pclstack[n].fmt=imm_d64 then return 1 fi
	return 0
end

function do_addrmode(pcl p)mcloperand px =

	mcloperand ax,bx
	int m, scale, extra,offset, reg,regix
	ref pstrec d

	scale:=p.scale
	extra:=p.extra
	offset:=pclstack[1].value*scale+extra	!for imm offset

	m:=p.mode

	px:=nil

	if isregvaropnd(xb) then
		if isregvaropnd(ya) then			!regvar/regvar
			reg:=pclstack[1].reg
			regix:=scaleregvar(reg,scale,1)
			px:=mgenindex(areg:pclstack[2].reg,ireg:regix, offset:extra, scale:scale)

		elsif isimm64(ya) then			!regvar/imm
			px:=mgenindex(areg:pclstack[2].reg, offset:offset)
		else							!regvar/any
			scale:=scaleindex(bx:=genopnd_ld(ya),scale)
			px:=mgenindex(areg:pclstack[2].reg, ireg:bx.reg, scale:scale, offset:extra)
		fi
	elsif ismemaddr(xb) then
		d:=pclstack[2].def
		if isregvaropnd(ya) then			!memaddr/regvar
			reg:=pclstack[1].reg
			regix:=scaleregvar(reg,scale,1)
			px:=mgenindex(ireg:regix, def:d, offset:extra, scale:scale)

		elsif isimm64(ya) then			!memaddr/imm
			px:=mgenindex(def:d, offset:offset)
		else							!memaddr/any
			scale:=scaleindex(bx:=genopnd_ld(ya),scale)
			px:=mgenindex(ireg:bx.reg, def:d, offset:extra, scale:scale)
		fi
	else								!
		ax:=genopnd_ld(xb)
		if isregvaropnd(ya) then			!any/regvar
			reg:=pclstack[1].reg
			regix:=scaleregvar(reg,scale,1)
			px:=mgenindex(areg:ax.reg, ireg:regix, offset:extra, scale:scale)
		elsif isimm64(ya) then			!any/imm
			px:=mgenindex(areg:ax.reg, offset:offset)
		else							!any/any
			scale:=scaleindex(bx:=genopnd_ld(ya),scale)
			px:=mgenindex(areg:ax.reg, ireg:bx.reg, scale:scale, offset:extra)

		fi
	fi

	if px.size=0 then px.size:=p.size fi
	return px
end

function makeregopnd(int n)mcloperand ax=

	pclstack[n].fmt:=reg_d64
	pclstack[n].loc:=reg_loc
	pclstack[n].reg:=getnextreg()

	return genopnd(n)
end

proc pc_assem(pcl p) =
	unit pcode

	inf_assem:=1
	pcode:=p.code
	genmc(pcode.asmopcode, genasmopnd(pcode.a),genasmopnd(pcode.b))
	mccodex.cond:=pcode.cond

	case pcode.asmopcode
	when m_pcmpistri,m_pcmpistrm then
		if pcode.c=nil or pcode.c.tag<>j_const then gerror("pcmpistr/no imm") fi
		mccodex.c:=pcode.c.value

	esac
	mccodex.cond:=pcode.cond

	if p.mode then
		dogetretvalue(p)
	fi
end

proc mulimm(mcloperand ax, int n)=
	int shifts,m

	case n
	when 0 then
		genmc(m_xorx, ax,ax)
		return
	when 1 then
		return
	when -1 then
		genmc(m_neg, ax)
		return
	esac

	shifts:=0
	m:=n

	while m.even do
		m>>:=1
		++shifts
	od

	if shifts then
		genmc(m_shl, ax, mgenint(shifts))
	fi

	case m
	when 1 then
		return
	when 3, 5, 9 then
		genmc(m_lea, ax, mgenindex(areg: ax.reg, ireg:ax.reg, scale:m-1))
	else						!mul needed anyway; forget the shift
		if shifts then
			mccodex.opcode:=m_imul2
			mccodex.b:=mgenint(n)
		else
			genmc(m_imul2, ax, mgenint(n))
		fi
	esac

end

proc pc_dotindex(pcl p)=
	mcloperand ax
	int i

	if pclstack[1].fmt<>imm_d64 then
		merror("dotix i not imm")
	fi

	ax:=genopnd_ld(xb)
	i:=pclstack[1].value

	if i then
		genmc(m_shr, ax, mgenint(i))
	fi
	genmc(m_andx, changeopndsize(ax,4), mgenint(1))

	delopnd()
end

proc pc_popdotindex(pcl p)=
	mcloperand ax,bx,cx,rx,mx
	int i,size,cxfmt,rhs,axoffset

	if pclstack[3].fmt=imm_d64 then
		rhs:=pclstack[3].value
		cx:=nil
	else
		cx:=genopnd_ld(xc)
	fi

	if pclstack[1].fmt<>imm_d64 then
		merror("dotix i not imm")
	fi
	i:=pclstack[1].value
	size:=p.size

	axoffset:=xb

	addreg_d64()
	rx:=genopnd()
	addreg_d64()
	mx:=genopnd()

		ax:=genopnd_ind(axoffset+2,size:size)
		genmc((size=8|m_mov|m_movzx),rx,ax)


	genmc(m_mov,mx,mgenint(inot(1<<i)))
	genmc(m_andx,rx,mx)

	if cx then
		if i then genmc(m_shl, cx, mgenint(i)) fi
		genmc(m_orx, rx, cx)
	elsif rhs<>0 then
		genmc(m_orx, rx, mgenint(1<<i))
	fi

		genmc(m_mov,ax,changeopndsize(rx,size))

	delopnd()			!mx
	delopnd()			!rx
	delopnd()			!bx/index
	delopnd()			!addr
	if p.opcode=k_popdotindex then
		delopnd()		!value being stored
	fi

end

proc pc_dotslice(pcl p)=
	mcloperand ax,mx,mx4
	int i,j
	word mask

	if pclstack[yb].fmt<>imm_d64 or pclstack[za].fmt<>imm_d64 then
		merror("dotslice i/j not imm")
	fi

	ax:=genopnd_ld(xc)
	i:=pclstack[yb].value
	j:=pclstack[za].value

	if i then
		genmc(m_shr, ax, mgenint(i))
	fi

	mask:=inot(0xFFFF'FFFF'FFFF'FFFF<<(j-i+1))
	if mask<=word(int32.maxvalue) then			!use immediate
		genmc(m_andx, ax, mgenint(mask))
	else
		mx:=makeregopnd(yb)
		genmc(m_mov, mx, mgenint(mask))
		genmc(m_andx, ax, mx)
	fi

	delopnd()
	delopnd()
end

proc loadtoreg(mcloperand rx, ax, int m)=
	if ttcat[m]=d64_cat then
		genmc(m_mov, rx, ax)
	elsif ttisint[m] then
		genmc(m_movsx, rx, ax)
	else
		genmc(m_movzx, rx, ax)
	fi
end

proc storefromreg(mcloperand ax, rx, int size)=
	genmc(m_mov, ax, changeopndsize(rx,size))
end

proc pc_popdotslice(pcl p)=
	mcloperand ax,rx,mx,mx4,dx
	int i,j,size
	word mask

	if pclstack[yb].fmt<>imm_d64 or pclstack[za].fmt<>imm_d64 then
		merror("popdotslice i/j not imm")
	fi

	dx:=genopnd_ld(wd)

	size:=p.size
	ax:=genopnd_ind(xc,size:size)

	i:=pclstack[yb].value
	j:=pclstack[za].value

	mx:=makeregopnd(yb)
	rx:=makeregopnd(za)

	loadtoreg(rx,ax,p.mode)

	mask:=inot((inot(0xFFFF'FFFF'FFFF'FFFF<<(j-i+1)))<<i)

	genmc(m_mov, mx, mgenint(mask))

	if i then
		genmc(m_shl, dx, mgenint(i))
	fi

	genmc(m_andx, rx, mx)
	genmc(m_orx, rx, dx)

	storefromreg(ax,rx,size)

	delopnd()			!j
	delopnd()			!i
	delopnd()			!A
	if p.opcode=k_popdotslice then
		delopnd()		!x
	fi

end

proc do_syscall(int fnindex, nargs, retcat)=

	int nslots

	sa_nargs:=nargs
	pc_setalign(nil)

	nslots:=do_pushparams(nil,nargs)
	genmc_sys(fnindex)

	to nargs do
		poparg()
	od
	popslots(nslots)

	getretvalue_bycat(retcat)
end

proc pc_makeslice(pcl p)=
	setwideopnd()
end

proc pcx_len_slice(pcl p)=
	delopnd()
	unsetwideopnd()
end

proc pcx_upb_slice(pcl p)=
	int offset

	delopnd()
	offset:=p.extra-1

	if offset then
		genmc(m_add, genopnd_ld(),mgenint(offset))
	fi

	unsetwideopnd()
end

proc pcx_sliceptr_slice(pcl p)=
	swapopnds(1,2)
	delopnd()
	unsetwideopnd()
end

proc do_setretfloat(int destreg)=
	int currreg
	mcloperand ax,rx

	rx:=mgenxreg(destreg)

	ax:=genopnd_ld(1)
	currreg:=ax.reg

	case pclstack[1].loc
	when xreg_loc then
		if currreg<>destreg then

			if regset[destreg] then
				merror("setretfloat/dest in use")
			else
				genmc(m_movq, rx, ax)
				xregset[destreg]:=1
			fi
		fi
	else
		merror("setretf?")
	esac
	delopnd()		!assume next is a jump to return point

end

proc do_setret(int destreg,destxreg)=


	int currreg
	mcloperand ax,rx

	if pclstack[1].float then
		do_setretfloat(destxreg)
		return
	fi

	rx:=mgenreg(destreg)


	ax:=genopnd_ld(1)
	currreg:=ax.reg

	case pclstack[1].loc
	when reg_loc then
		if currreg<>destreg then

			if regset[destreg] then
				swapopndregs(destreg)
				genmc(m_xchg, rx, ax)
			else
				genmc(m_mov, rx, ax)
			fi
		fi
	else
		merror("setret?")
	esac
	delopnd()						!assume next is a jump to return point
	regset[destreg]:=1
	mccodex.regend[destreg]:=0			!d0 will not be freed
end
=== bb_libmcl.m 26/40 ===
import msys
import mlib
import clib
import oslib

import bb_decls
import bb_support
import bb_tables
import bb_libpcl
import bb_mcldecls
import bb_genmcl
import bb_stackmcl
import bb_genpcl

import bb_pclcommon

IMPORT BB_LIB

GLOBAL INT NALLFRAME
GLOBAL INT NALLMCLOPND


const fshortnames=0

const fasmformat=1

const fuseregtable=1

const targetsize=8

global int ptrsize

global int fshowmsource=0

global int lababs32, lababs64
global int labneg32, labneg64
global int labzero
global int kk0used=0

global int stackaligned
global const initial_stackalignment = 1

global const rtos=rnone			!means stack operand


global ref mclrec mccode, mccodex		!genmc adds to this linked list

global int currsegment=0		!

global int currzdataalign=0
global int curridataalign=0

global int frameoffset
global int isthreadedproc
global int iscallbackproc

global int structretoffset			!0, or offset of R9 copy within struct
global ref mclrec stacksetinstr		!caller of any fn: instr that sets sp
global int currblocksize			!0, or set to largest block ret value
global ref mclrec allmclcode
global ichar allasmstr
global int allasmstrlen

global mcloperand dstackopnd
global mcloperand dframeopnd

global mcloperand zero_opnd=nil

global [r0..r15,1..16]mcloperand regtable

const maxsmallint=32
[0..maxsmallint]mcloperand smallinttable

[-128..64]mcloperand frameregtable

const initstringsize	= 1024
const initrealsize		= 16

global ref []ichar	stringtable
global ref []int32   stringlabtable
global ref []real	realtable
global ref []int32	reallabtable

int stringtablesize
int realtablesize

global int nstrings=0
global int nreals=0

global const maxlabelno=1400'000
global [maxlabelno]ref mclrec labeltable

int framebytes, parambytes

strbuffer sbuffer
ref strbuffer dest=&sbuffer
int destlinestart

global macro isframex(d) = (d.id in [frame_name, param_name])


global proc mclinit=
mcloperand a
int r,s


ptrsize:=8

for r:=r0 to r15 do
	regtable[r,1]:=mgenreg0(r,1)
	regtable[r,2]:=mgenreg0(r,2)
	regtable[r,4]:=mgenreg0(r,4)
	regtable[r,8]:=mgenreg0(r,8)
	regtable[r,16]:=mgenreg0(r,16)
od

zero_opnd:=mgenint0(0)

for i:=0 to maxsmallint do
	smallinttable[i]:=mgenint0(i)
od

for i in frameregtable.bounds do
	a:=newmclopnd()
	a.mode:=a_mem
	a.reg:=rframe
	a.size:=8
	a.offset:=i
	frameregtable[i]:=a
end

dframeopnd:=mgenreg(rframe,8)
dstackopnd:=mgenreg(rstack,8)

initmcdest()

setsegment('C')

stringtable:=pcm_alloc(ref void.bytes*initstringsize)
stringlabtable:=pcm_alloc(int32.bytes*initstringsize)
realtable:=pcm_alloc(real.bytes*initrealsize)
reallabtable:=pcm_alloc(int32.bytes*initrealsize)

nstrings:=0
nreals:=0


stringtablesize:=initstringsize
realtablesize:=initrealsize

pclstack:=cast(&pclopndstack[maxoperands])

end

global proc initmcdest=
mccode:=mccodex:=nil
end

global proc genmc(int opcode, mcloperand a=nil,b=nil)=
ref mclrec m, oldm
int labno

M:=PCM_ALLOCZ(MCLREC.BYTES)

m.pos:=mlineno
m.opcode:=opcode


m.a:=a
m.b:=b

case opcode
when m_call then
	++inf_proccalls

when m_lea then
	if b and b.valtype=def_val then
		b.def.addrof:=1
	fi
when m_label then
	labno:=a.labelno
	if labno>maxlabelno then
		merror("Too many labels")
	fi
	labeltable[labno]:=m

esac

if mccode then
	mccodex.nextmcl:=m
	mccodex:=m
else
	mccode:=mccodex:=m
fi
end

global proc genmc_cond(int opcode, cond, mcloperand a=nil,b=nil)=
genmc(opcode,a,b)
mccodex.cond:=cond
end

global function lastmc:ref mclrec=
return mccodex
end

global proc genmc_str(int opcode,ichar s)=

genmc(opcode,mgenstring(s))
end

function newmclopnd:mcloperand=
mcloperand a
++NALLMCLOPND

a:=pcm_allocz(mclopndrec.bytes)
return a
end

global function duplopnd(mcloperand a)mcloperand=
mcloperand b
b:=pcm_alloc(mclopndrec.bytes)
b^:=a^
return b
end

global function mgenxreg(int xreg,size=8)mcloperand=
	mcloperand a

	a:=newmclopnd()

	a.mode:=a_xreg
	a.reg:=xreg
	a.size:=size
	return a
end

global function mgenindex(int areg=0,ireg=0,scale=1,offset=0,size=0, labno=0, ref pstrec def=nil)mcloperand=
mcloperand a
a:=newmclopnd()

a.mode:=a_mem
a.reg:=areg

a.regix:=ireg
a.scale:=scale
a.size:=size

a.offset:=offset

if labno then
	a.value:=labno
	a.valtype:=label_val
elsif def then
	a.def:=def
	++def.nrefs
	a.valtype:=def_val
	if isframex(def) then
		a.reg:=rframe
	fi
fi

return a
end

global function writemclcode(ichar caption)ref strbuffer=
ref pstrec d,e
ref mclrec m
[32]char str2,str3
int i

gs_init(dest)
gs_str(dest,"PROC ")
gs_strln(dest,caption)
gs_strln(dest,"!---------------------------------------------")

m:=allmclcode
i:=1
while m do
	if m.opcode=m_procstart then
		procdef:=m.a.def
	fi

	writemcl(i,m)
	++i
	m:=m.nextmcl
od

gs_strln(dest,"!---------------------------------------------")


return dest
end

global proc mgencomment(ichar s)=
if not debugmode then return fi
if s=nil or s^=0 then
	genmc(m_blank)
else
	genmc_str(m_comment,s)
fi
end

global proc mgeninfo(ichar s, int value)=
	[256]char str
	fprint @&.str,"# #",s,value
	genmc_str(m_comment,&.str)
end

global proc mgeninfos(ichar s, svalue)=
	[256]char str
	fprint @&.str,"# #",s,svalue
	genmc_str(m_comment,&.str)
end

global function mgenstring(ichar s,int length=-1)mcloperand=
	mcloperand a
	a:=newmclopnd()
	a.mode:=a_imm
	if length<0 then
		length:=strlen(s)
	fi
	a.svalue:=pcm_alloc(length+1)
	memcpy(a.svalue,s,length)
	(a.svalue+length)^:=0

	a.valtype:=stringimm_val
	a.size:=ptrsize
	return a
end

global function mgenname(ichar s)mcloperand=
	[64]char str
	mcloperand a
	a:=newmclopnd()
	a.mode:=a_imm
	a.svalue:=pcm_copyheapstring(s)
	a.valtype:=name_val
	a.size:=ptrsize

RETURN A

	ref pstrec d

	strcpy(&.str,s)
	str[strlen(s)]:=0

	d:=pcm_allocz(pstrec.bytes)
	d.name:=pcm_copyheapstring(&.str)
	d.owner:=procdef

	d.id:=dllproc_name

	d.mode:=tu64

	pstlistx.nextpst:=d
	pstlistx:=d

RETURN MGENMEM(D)


	a.def:=d
	a.valtype:=def_val

	return a

end

global function mgenextname(ichar s)mcloperand=
	[64]char str
	ref pstrec d

	strcpy(&.str,s)
	str[strlen(s)]:=0

	d:=pcm_allocz(pstrec.bytes)
	d.name:=pcm_copyheapstring(&.str)

	d.id:=dllproc_name

	d.mode:=tu64

	pstlistx.nextpst:=d
	pstlistx:=d

	return mgenmemaddr(d)
end

global proc genmc_sys(int fnindex)=
	genmc_cond(m_call, fnindex, mgenlabel(getsysproclabel(fnindex)))

	mccodex.a.size:=8
end

global function getsysproclabel(int fnindex)int=
	if sysfnproclabels[fnindex]=0 then
		sysfnproclabels[fnindex]:=++labelno
		return labelno
	fi
	return sysfnproclabels[fnindex]
end

proc writemcl(int index,ref mclrec mcl)=




case mcl.opcode
when m_deleted then
else
	strmcl(mcl)
	gs_line(dest)
esac

end

global proc strmcl(ref mclrec mcl)=
	static [512]char str
	[128]char opcname
	mcloperand a,b
	int opcode,cond,sizepref
	ichar s,comment
	ref pstrec d

	opcode:=mcl.opcode




	cond:=mcl.cond
	a:=mcl.a
	b:=mcl.b
	comment:=nil




	case opcode

	when m_procstart then
		asmstr(";Proc ")
		asmstr(a.def.name)

		return

	when m_procend then
		asmstr(";End ")

		return

	when m_blank then
		return
	when m_comment then
		asmchar(';')
		asmstr(a.svalue)
GOTO DOCOMMENTS
		return
	when m_deleted then
		asmstr("; <deleted>")
		GOTO DOCOMMENTS

		return

	when m_labelname then				!label name will be complete and will have colon(s)
		d:=a.def
		case a.valtype
		when def_val then
			asmstr(getfullname(d))
		when stringimm_val then
			asmstr(a.svalue)
			return
		else
			merror("strmcl/lab")
		esac

		asmstr(":")

		if d.isglobal=export_scope then
			asmstr("\n")
			asmstr(d.name)
			asmstr("::")
		fi



		return

	when m_label then

		fprint @&.str,"L#:",a.value
		asmstr(&.str)
		return

	when m_define then
		asmstr("          ")
		asmstr(a.svalue)
		asmstr(" = ")
asmopnd(b)
		return

	when m_definereg then
		asmstr("          ")
		asmstr(a.svalue)
		asmstr(" = ")
		asmopnd(b)
		return

	esac

	case opcode
	when m_jmpcc then
		print @&.opcname,"j",,asmcondnames[cond]

	when m_setcc then
		print @&.opcname,"set",,asmcondnames[cond]

	when m_cmovcc then
		print @&.opcname,"cmov",,asmcondnames[cond]

	when m_call then
		if cond then
			comment:=sysfnnames[cond]+6
		fi
		strcpy(&.opcname,"call")
	when m_andx then
		strcpy(&.opcname,"and")
	when m_orx then
		strcpy(&.opcname,"or")
	when m_xorx then
		strcpy(&.opcname,"xor")
	when m_notx then
		strcpy(&.opcname,"not")

	ELSIF OPCODE>M_HALT THEN
	STRCPY(&.OPCNAME,STRINT(OPCODE))

	else
		strcpy(&.opcname,mclnames[opcode]+2)
	esac
	ipadstr(&.opcname,10," ")

	if not fasmformat then
		if a and b then
			fprint @&.str,"  #/#",a.size,b.size
		elsif a then
			fprint @&.str,"  #",a.size
		else
			strcpy(&.str,"  ")
		fi
	else
		strcpy(&.str,"  ")
	fi

	ipadstr(&.str,10)

	strcat(&.str,&.opcname)

	asmstr(&.str)


	if a and b then		!2 operands
		sizepref:=needsizeprefix(opcode,a,b)

		asmopnd(a,sizepref)
		asmstr(",	")
		asmopnd(b,sizepref)

	elsif a and a.mode then								!1 operand
		if opcode=m_call then
			asmopnd(a,0)
		else
			asmopnd(a,1)
		fi
	fi

DOCOMMENTS::
RETURN
	asmstr(" !")

	if comment then
		asmstr(comment)
	fi

	IF MCL.COMMENT THEN
		ASMSTR(" ")
		ASMSTR(MCL.COMMENT)
	FI

	for i in mcl.regend.bounds do
		if mcl.regend[i] then
			asmstr(" Free:")
			asmstr(getregname(i))
		fi
	od

end

global proc asmopnd(mcloperand a,int sizeprefix=0,debug=0)=
	asmstr(stropnd(a,sizeprefix,debug))
end

global proc setsegment(int seg,align=1)=
int opc

if seg<>currsegment then

	case seg
	when 'I' then opc:=m_isegment
	when 'Z' then opc:=m_zsegment
	when 'C' then opc:=m_csegment
	when 'R' then MERROR("CAN'T DO RODATA SEG")
	ELSE
		MERROR("BAD SEG CODE")
	esac
	if mccodex and mccodex.opcode in [m_isegment,m_zsegment,m_csegment] then
		mccodex.opcode:=opc
	else
		genmc(opc)
	fi

	currsegment:=seg
fi


if align<>1 then
	genmc(m_align,mgenint(align))
fi
end

global function getprocname(ref pstrec d)ichar=
		return getdottedname(d)
	return ""
end

global function widenstr(ichar s,int w)int=

while strlen(s)>=(w-2) do
	w+:=8
od  
return w
end

global function strlabel(int n)ichar=
static [16]char str
print @&.str,"L",,n
return &.str
end


global function getsizeprefix(int size,enable=0)ichar=
if not enable then return "" fi
case size
when 1 then return "byte "
when 2 then return "word16 "
when 4 then return "word32 "
when 8 then return "word64 "
when 16 then return "word128 "
esac
return ""
end

global function needsizeprefix(int opcode,mcloperand a,b)int=

case opcode
when m_movsx, m_movzx, m_cvtsi2ss, m_cvtsi2sd then
	return 1

when m_cvtss2si,m_cvtsd2si, m_cvttss2si,m_cvttsd2si then
	return 1
when m_shl, m_shr, m_sar then
	if a.mode=a_mem then return 1 fi
	return 0
esac

if a.mode=a_reg or a.mode=a_xreg or b.mode=a_reg or b.mode=a_xreg then
	return 0
fi
return 1
end

global function changeopndsize(mcloperand a,int size)mcloperand=
mcloperand b

if a.size<>size then
	if a.mode=a_reg then
		b:=regtable[a.reg, size]
	else
		b:=duplopnd(a)
		b.size:=size
	fi
	return b
fi
return a
end

global function makeopndind(mcloperand a,int size=0)mcloperand=
	mcloperand b

	if a.mode<>a_reg then
		merror("makeopndind")
	fi

	return mgenireg(a.reg,size)
end

global function applyoffset(mcloperand a,int offset,int size=0)mcloperand=
mcloperand b

if offset=0 and size=0 then
	return a
fi
b:=duplopnd(a)
b.offset+:=offset
if size then
	b.size:=size
fi

return b
end

global function mgenint(int64 x,int size=8)mcloperand=
	if x in 0..maxsmallint and size=8 then
		return smallinttable[x]
	fi

	return mgenint0(x,size)
end

global function mgenint0(int64 x,int size=8)mcloperand a=

	a:=newmclopnd()
	a.mode:=a_imm

	a.value:=x
	a.valtype:=intimm_val
	a.size:=size

	return a
end

global function mgenrealmem(real64 x,int size=8)mcloperand=
mcloperand a


a:=newmclopnd()
a.mode:=a_mem
a.value:=getrealindex(x,size)
a.valtype:=label_val
a.size:=size
return a
end

global function mgenrealimm(real64 x,int size=8)mcloperand=
mcloperand a

a:=newmclopnd()
a.mode:=a_imm
a.xvalue:=x
a.valtype:=realimm_val
a.size:=size
return a
end
global function mgenlabel(int x=0)mcloperand=
mcloperand a

a:=newmclopnd()
a.mode:=a_imm
if x=0 then x:=++labelno fi
a.value:=x
a.valtype:=label_val
return a
end

global function mgenlabelmem(int x)mcloperand=
mcloperand a

a:=mgenlabel(x)
a.mode:=a_mem
return a
end

global function mgenregvar(ref pstrec d)mcloperand a=
	a:=mgenreg0(d.reg,8)

	a.mode:=a_regvar
	a.def:=d
	a.valtype:=def_val

	return a
end

global function mgenxregvar(ref pstrec d)mcloperand a=
	a:=mgenxreg(d.reg)

	a.mode:=a_regvar
	a.def:=d
	a.valtype:=def_val

	return a
end

global function mgenmem(ref pstrec d,int size=0)mcloperand a=
	int reg

	if d.reg then
		return mgenregvar(d)
	fi

	reg:=rnone
	if isframex(d) then
		if not foptimise and not debugmode and (int(d.offset) in -128..64) and d.size=8 then
			return frameregtable[d.offset]
		fi

		reg:=rframe
	fi

	a:=newmclopnd()
	a.mode:=a_mem
	a.reg:=reg
	a.def:=d
	++d.nrefs
	a.valtype:=def_val

	a.size:=(size|size|d.size)
	if a.size>8 then a.size:=8 fi

	return a
end

global function mgenmem0(ref pstrec d,int size=0)mcloperand a=
	a:=newmclopnd()
	a.mode:=a_mem

	if d.reg then
		return mgenregvar(d)
	fi

	if isframex(d) then
		a.reg:=rframe
	fi
	a.def:=d
	++d.nrefs
	a.valtype:=def_val

	a.size:=(size|size|d.size)
	if a.size>8 then a.size:=8 fi

	return a
end

global function mgenmemhigh(ref pstrec d)mcloperand a=
	a:=newmclopnd()
	a.mode:=a_mem

	if isframex(d) then
		a.reg:=rframe
	fi
	++d.nrefs
	a.def:=d
	a.valtype:=def_val
	a.offset:=8
	a.size:=8

	return a
end

global function mgenmemaddr(ref pstrec d)mcloperand=
	mcloperand a

	d.addrof:=1
	++d.nrefs

	a:=newmclopnd()
	a.mode:=a_imm

	if d.isframe then
		a.reg:=rframe
	fi
	a.def:=d
	++d.nrefs
	a.valtype:=def_val
	a.size:=ptrsize

	return a
end

global function mgenreg(int reg,size=8)mcloperand=

if fuseregtable then
	return regtable[reg,size]
fi
return mgenreg0(reg,size)
end

global function mgenreg0(int reg,size=8)mcloperand=
mcloperand a

a:=newmclopnd()
a.mode:=a_reg
a.reg:=reg
a.size:=size
return a
end


global function mgenireg(int reg,size=8,offset=0)mcloperand=
	mcloperand a

	a:=newmclopnd()
	a.mode:=a_mem
	a.reg:=reg
	a.size:=size
	a.offset:=offset

	return a
end


global function roundsizetg(int size)int=
while size iand (targetsize-1) do ++size od
return size
end

global function getregname(int reg,size=8)ichar=
static [1..17]ichar prefix=("B","W","","A","","","","D","","","","","","","","Q","N")
static [32]char str
[16]char str2
ichar rs
int size2

size2:=size
if size2>16 then
	size2:=17
FI

case reg
when rnone then return "-"
when rframe then rs:="frame"
when rstack then rs:="stack"
else
	getstrint(reg-r0,&.str2)
	rs:=&.str2
esac

print @&.str,prefix[size2],,rs
return &.str
end

global function fgetregname(int reg,size=8)ichar=
static [32]char str

if reg=rnone then return "-" fi

if fasmformat then
	print @&.str,"XMM",,reg-xr0
else
	print @&.str,(size=8|"DX"|"SX"),,reg-xr0
fi
return &.str
end

global function sameoperand(mcloperand a,b)int=

return memcmp(a,b,a^.bytes)=0


end

global function sameregopnd(mcloperand a,b)int=
	unless a.mode=b.mode=a_reg then return 0 end
	return a.reg=b.reg
end

global function roundto(int64 a,n)int64=
--n
while (a iand n) do ++a od
return a
end


global proc mgenjumpl(int lab) =
genmc(m_jmp,mgenlabel(lab))
end

global function getstringindex(ichar s)int=

	if s=nil then			!assume nil
		kk0used:=++labelno
		return kk0used
	fi

	if nstrings>=stringtablesize then
		extendstringtable()
	fi

	if nstrings and eqstring(stringtable^[nstrings],s) then
		return stringlabtable^[nstrings]
	fi

	stringtable^[++nstrings]:=s
	stringlabtable^[nstrings]:=++labelno

	return labelno
end

global function getrealindex(real x,int size)int=
	if nreals>=realtablesize then
		extendrealtable()
	fi

	realtable^[++nreals]:=x
	++labelno
	reallabtable^[nreals]:=(size=8|labelno|-labelno)
	return labelno
end

proc extendstringtable=
	ref[]ichar oldstringtable
	ref[]int32 oldstringlabtable
	int oldstringtablesize


	oldstringtablesize:=stringtablesize
	oldstringtable:=stringtable
	oldstringlabtable:=stringlabtable

	stringtablesize*:=2

	stringtable:=pcm_alloc(ichar.bytes*stringtablesize)
	stringlabtable:=pcm_alloc(int32.bytes*stringtablesize)

	for i:=1 to nstrings do
		stringtable^[i]:=oldstringtable^[i]
		stringlabtable^[i]:=oldstringlabtable^[i]
	od

	pcm_free(oldstringtable,ichar.bytes*oldstringtablesize)
	pcm_free(oldstringlabtable,int32.bytes*oldstringtablesize)
end

proc extendrealtable=
	ref[]real oldrealtable
	ref[]int32 oldreallabtable
	int oldrealtablesize

	oldrealtablesize:=realtablesize
	oldrealtable:=realtable
	oldreallabtable:=reallabtable

	realtablesize*:=2

	realtable:=pcm_alloc(real.bytes*realtablesize)
	reallabtable:=pcm_alloc(int32.bytes*realtablesize)

	for i:=1 to nreals do
		realtable^[i]:=oldrealtable^[i]
		reallabtable^[i]:=oldreallabtable^[i]
	od

	pcm_free(oldrealtable,real.bytes*oldrealtablesize)
	pcm_free(oldreallabtable,int32.bytes*oldrealtablesize)
end

proc asmstr(ichar s)=
	gs_str(dest,s)
end

proc asmchar(int c)=
	gs_char(dest,c)
end

proc asmint(int a)=
	gs_strint(dest,a)
end

function getfullname(ref pstrec d)ichar=
	static [256]char str


	if fshortnames then
		return d.name
	fi

	if d.owner=nil then
		fprint @&.str,"`#*",d.name
		return &.str
	fi

	case d.owner.id
	when proc_name then
		if d.reg then
			fprint @&.str,"#.#.#.#",(ttcat[d.mode]=x64_cat|"X"|"R"),d.owner.owner.name, d.owner.name, d.name
		else
			fprint @&.str,"`#.#.#",d.owner.owner.name, d.owner.name, d.name
		fi
		return &.str
	when module_name then
		case d.id
		when dllproc_name,dllstatic_name then
			fprint @&.str,"`#*",d.name
		else
			fprint @&.str,"#.#",d.owner.name, d.name
		esac
		return &.str
	else
		return d.name
	esac
end 

global function getfulltempname(int tempno)ichar=
	static [256]char str
	if fshortnames then
		fprint @&.str,"T#",tempno
	else
		fprint @&.str,"#.#.T#",procdef.owner.name, procdef.name,tempno
	fi
	return &.str
end 

function getdottedname(ref pstrec d)ichar=
	return d.name
end 

global proc merror(ichar mess,ichar param="")=
	fprintln "MCL Error: # (#) on Line: # in #",mess,param,
		mlineno iand 16777215, sourcefilenames[mlineno>>24]
	PRINTLN
	stopcompiler(sourcefilepaths[mlineno>>24],mlineno iand 16777215)
end

global proc genstringtable=
	int i, col

	setsegment('I',8)

	if kk0used then
		genmc(m_label,mgenlabel(kk0used))
		gendb(0)
	fi
	return unless nstrings


	for i to nstrings do
		genmc(m_label,mgenlabel(stringlabtable[i]))

			genstring(stringtable^[i],1)
	od
end

global proc genstring(ichar s, int doterm)=
	int i, c, seqlen, length
	ref char seq

	length:=strlen(s)

	if length=0 then
		gendb(0)
		return
	fi

	seqlen:=0

	to length do
		c:=s++^
		if c<32 or c>=127 or c='\"' then
			if seqlen then
				gendbstring(seq, seqlen)
				seqlen:=0
			fi
			gendb(c)
		else
			if seqlen=0 then
				seqlen:=1
				seq:=s-1
			else
				++seqlen
			fi
		fi
	od
	if seqlen then
		gendbstring(seq,seqlen)
	fi
	if doterm then
		gendb(0)
	fi
end

proc gendb(int a)=
	genmc(m_db,mgenint(a))
end

proc gendw(int a)=
	genmc(m_dw,mgenint(a))
end

proc gendbstring(ichar s, int length)=
	genmc(m_db,mgenstring(s,length))
end

proc gendq(int a)=
	genmc(m_dq,mgenint(a))
end

proc gendqname(ref pstrec d)=
	genmc(m_dq,mgenmemaddr(d))
end

proc gendqlabel(int lab)=
	genmc(m_dq,mgenlabel(lab))
end

global proc genrealtable=
	real x

	return unless nreals

	mgencomment("Real Table")
	setsegment('I',8)

	for i to nreals do
		genmc(m_label,mgenlabel(abs(reallabtable[i])))
		x:=realtable[i]

		if reallabtable[i]>0 then
			genmc(m_dq, mgenrealimm(x,8))
		else
			genmc(m_dd, mgenrealimm(x,4))
		fi
	od
end

global proc genfunctiondata=

	int i,nprocs,n,nexports,nparams,optflag
	int labelbase

	ref pstrec d,e
	const maxparams=100
	[maxparams]ref strec params

	nprocs:=0

	setsegment('I',8)
	genmc(m_labelname,mgenstring("m$fnaddresses:"))
	genmc(m_label, mgenlabel(getsysproclabel(sysfn_procaddrs)))

	d:=pstlist
	while d do
		if d.id=proc_name then
			++nprocs
			gendqname(d)
		fi

		d:=d.nextpst
	od

	gendq(0)

	genmc(m_labelname,mgenstring("m$fnnames:"))
	genmc(m_label, mgenlabel(getsysproclabel(sysfn_procnames)))
	n:=0
	labelbase:=labelno

	d:=pstlist
	while d do
		if d.id=proc_name then
			gendqlabel(++labelno)
		fi
		d:=d.nextpst
	od

	gendq(0)

	n:=0
	d:=pstlist
	while d do
		if d.id=proc_name then
			++n
			genmc(m_label,mgenlabel(n+labelbase))
			gendbstring(d.name,-1)
			gendb(0)
		fi
		d:=d.nextpst
	od

	gendq(0)
	genmc(m_labelname,mgenstring("m$fnnprocs:"))
	genmc(m_label, mgenlabel(getsysproclabel(sysfn_nprocs)))
	gendq(nprocs)

GENSPECIALSYSFNS(NPROCS)

nprocs:=nexports:=0




end

proc genspecialsysfns(int nprocs)=
	int ilab,alab
	mcloperand rx0
	setsegment('C')

MGENCOMMENT("===SPECIAL===================================")

	rx0:=mgenreg(r0)

	dosysfnhdr(sysfn_get_nprocs)
	genmc(m_mov, rx0, mgenint(nprocs))
	genmc(m_ret)

	dosysfnhdr(sysfn_get_procname)
	genmc(m_mov,rx0,mgenindex(ireg:r10, scale:8, offset:-8,
		 labno:getsysproclabel(sysfn_procnames)))
	genmc(m_ret)

	dosysfnhdr(sysfn_get_procaddr)
	genmc(m_mov,rx0,mgenindex(ireg:r10, scale:8, offset:-8,
		 labno:getsysproclabel(sysfn_procaddrs)))
	genmc(m_ret)
	genmc(m_blank)

MGENCOMMENT("======================================")

	setsegment('I')
end

proc dosysfnhdr(int fnindex)=
	genmc(m_blank)
	mgencomment(sysfnnames[fnindex])
	if sysfnproclabels[fnindex] then
		genmc(m_label,mgenlabel(sysfnproclabels[fnindex]))
	else
		sysfnproclabels[fnindex]:=mdefinelabel()
	fi
end

global proc gensysfntable=
[256]char name
int proclab
ref pstrec d

mgencomment("SYSFN TABLE")
mgencomment("<NO LONGER NEEDED>")



end

global proc genabsneg=
	setsegment('I',16)

	if lababs32 then
mgencomment("lababs32")
		genmc(m_label,mgenlabel(lababs32))
		gendq(0x7FFF'FFFF'7FFF'FFFF)
		gendq(0x7FFF'FFFF'7FFF'FFFF)
	fi
	if lababs64 then
mgencomment("lababs64")
		genmc(m_label,mgenlabel(lababs64))
		gendq(0x7FFF'FFFF'FFFF'FFFF)
		gendq(0x7FFF'FFFF'FFFF'FFFF)
	fi

	if labneg32 then
mgencomment("labneg32")
		genmc(m_label,mgenlabel(labneg32))
		gendq(0x8000'0000'8000'0000)
		gendq(0x8000'0000'8000'0000)
	fi
	if labneg64 then
mgencomment("labneg64")
		genmc(m_label,mgenlabel(labneg64))
		gendq(0x8000'0000'0000'0000)
		gendq(0x8000'0000'0000'0000)
	fi

	if labzero then
mgencomment("labzero")
		genmc(m_label,mgenlabel(labzero))
		gendq(0)
	fi
end


global function getindexmode(pcl px, ix, int size,scale, offset)mcloperand ax=
	int reg, regix, indexoffset, regscale
	ref pstrec d
	mcloperand wx

	return nil
end



global function mdefinelabel:int =
	genmc(m_label,mgenlabel(++labelno))
	return labelno
end

global function mcreatefwdlabel:int =
	return ++labelno
end

global proc mdefinefwdlabel(int lab) =
	genmc(m_label,mgenlabel(lab))
end

global function stropnd(mcloperand a,int sizeprefix=0,debug=0)ichar=
	static [512]char str
	[128]char str2
	ichar plus,t
	int offset,tc


str[1]:=0

	case a.mode
	when a_reg then
		strcpy(&.str,getregname(a.reg,a.size))

	when a_regvar then
		return strvalue(a)

	when a_imm then
		strcpy(&.str,strvalue(a))

	when a_mem then
		case a.valtype
		when intimm_val then
			strcpy(&.str,strint(a.value))
		when realimm_val then
			strcpy(&.str,strreal(a.xvalue))
		when realmem_val then
			fprint @&.str,"M#",a.xvalue
		esac

		strcat(&.str,getsizeprefix(a.size,sizeprefix))
		strcat(&.str,"[")

		plus:=""
		if a.reg then
UNLESS A.REG=RFRAME AND FSHORTNAMES THEN
			strcat(&.str,getregname(a.reg,ptrsize))
			plus:="+"
END
		fi
		if a.regix then
			strcat(&.str,plus)
			strcat(&.str,getregname(a.regix,ptrsize))
			plus:="+"
			if a.scale>1 then
				strcat(&.str,"*")
				strcat(&.str,strint(a.scale))
			fi
		fi

		if a.valtype in [def_val,label_val, temp_val] then
			if plus^='+' then
				strcat(&.str,plus)
			fi
			strcat(&.str,strvalue(a))
	    elsif offset:=a.offset then
			print @&.str2,offset:"+"
			strcat(&.str,&.str2)
		fi
		strcat(&.str,"]")

	when a_xreg then
		strcat(&.str,fgetregname(a.reg,a.size))


	else
	CPL "BAD OPND",A.MODE
		return "<BAD OPND>"
	esac

	return &.str
end

global function strvalue(mcloperand a)ichar=
static [512]char str
[128]char str2
ref pstrec def
int64 value,offset,length
ichar ss

def:=a.def
value:=a.value

strcpy(&.str,"")

case a.valtype
when def_val then
	strcat(&.str,getfullname(def))

addoffset::
	if offset:=a.offset then
		print @&.str2,(offset>0|"+"|""),,offset
		strcat(&.str,&.str2)
	fi

when temp_val then
	strcat(&.str,getfulltempname(a.tempno))

when intimm_val then
	strcat(&.str,strint(value))

when realimm_val then
	print @&.str,a.xvalue:"20.20"

when realmem_val then
	strcat(&.str,"M")
	strcat(&.str,strreal(a.xvalue))

when stringimm_val then
	strcat(&.str,"""")
	strcat(&.str,a.svalue)
	strcat(&.str,"""")

when name_val then
	strcat(&.str,a.svalue)

when syscall_val then
	strcat(&.str,"XXX")

when label_val then
	strcat(&.str,"L")
	strcat(&.str,strint(a.labelno))
	goto addoffset

else
esac

return &.str

end

global proc copyblock(mcloperand ax,bx, int n)=
	mcloperand rx, rcount
	int nwords,lab,oddbytes,offset,workreg, countreg


	oddbytes:=n rem 8		!will be zero, or 1..7
	n-:=oddbytes			!n will always be a multiple of 8; n can be zero too
	nwords:=n/8				!number of word64s (ie. octobytes)

	rx:=mgenreg(workreg:=getnextreg())		!work reg

	offset:=0

	if 1<=nwords<=4 then		!use unrolled code (no loop)
		ax:=changeopndsize(ax,targetsize)
		bx:=changeopndsize(bx,targetsize)

		to nwords do
			genmc(m_mov,rx,applyoffset(bx,offset))
			genmc(m_mov,applyoffset(ax,offset),rx)
			offset+:=8
		od



	elsif nwords<>0 then		!use a loop
		rcount:=mgenreg(countreg:=getnextreg())	!count
		lab:=++labelno

		ax:=makesimpleaddr(ax)
		bx:=makesimpleaddr(bx)

		genmc(m_mov,rcount,mgenint(nwords))
		genmc(m_label,mgenlabel(lab))
		genmc(m_mov,rx,bx)
		genmc(m_mov,ax,rx)

		genmc(m_add,mgenreg(ax.reg),mgenint(targetsize))
		genmc(m_add,mgenreg(bx.reg),mgenint(targetsize))

		genmc(m_dec,rcount)
		genmc_cond(m_jmpcc,ne_cond,mgenlabel(lab))

		offset:=0
		freereg(countreg)
	fi

	if oddbytes then
		n:=oddbytes						!1..7

		if n>=4 then
			rx:=changeopndsize(rx,4)
			genmc(m_mov,rx,applyoffset(bx,offset,4))
			genmc(m_mov,applyoffset(ax,offset,4),rx)
			n-:=4
			offset+:=4
		fi
		if n>=2 then
			rx:=changeopndsize(rx,2)
			genmc(m_mov,rx,applyoffset(bx,offset,2))
			genmc(m_mov,applyoffset(ax,offset,2),rx)
			n-:=2
			offset+:=2
		fi
		if n=1 then
			rx:=changeopndsize(rx,1)
			genmc(m_mov,rx,applyoffset(bx,offset,1))
			genmc(m_mov,applyoffset(ax,offset,1),rx)
		fi
	fi

	freereg(workreg)
end

function makesimpleaddr(mcloperand ax)mcloperand bx=
	int newreg

	if ax.reg and not ax.regix then return ax fi
	newreg:=(ax.reg | ax.reg | (ax.regix | ax.regix | getnextreg()))
	bx:=mgenireg(newreg)

	genmc(m_lea, mgenreg(newreg), ax)
	return bx
end

GLOBAL proc addnote(ichar mess, ref mclrec m=mccodex)=
[512]CHAR STR
	IF M.COMMENT THEN
		STRCPY(&.STR,M.COMMENT)
		STRCAT(&.STR," // ")
		STRCAT(&.STR,MESS)
		MESS:=&.STR
	FI

	m.comment:=pcm_copyheapstring(mess)
end

global function genasmopnd(unit p)mcloperand ax=
	ref pstrec d
	int offset,labno
	unit a				!expr: nil/name/const/(add name, const)
	unit x,y

	if p=nil then return nil fi


	case p.tag
	when j_assemreg then
		ax:=mgenreg(p.reg,p.regsize)

	when j_const then
		ax:=mgenint(p.value)

	when j_assemmem then
		a:=p.a
		d:=nil
		offset:=labno:=0

		if a then
			case a.tag
			when j_const then
				offset:=a.value
			when j_name then
				d:=getpst(a.def)
				if d.id=label_name then
					if d.index=0 then d.index:=++labelno fi
					labno:=d.index
					d:=nil
				fi
			when j_bin then
				x:=a.a
				y:=a.b
				if x.tag=j_name and y.tag=j_const then
					d:=getpst(x.def)
					if d.id=label_name then
						if d.index=0 then d.index:=++labelno fi
						labno:=d.index
						d:=nil
					fi
				else
					goto error
				fi
				offset:=(a.genop=add_op|y.value|-y.value)
			when j_unary then
				if a.genop<>neg_op then merror("assume/unary") fi
				unless a.a.tag=j_const then gerror("-name") end
				offset:=-a.a.value
			when j_syscall then
MERROR("ASSEM/SYSFN?")

			else
error::
				cpl jtagnames[a.tag]
				gerror("Can't do memexpr")
			esac
		fi

		ax:=mgenindex(areg:p.reg, ireg:p.regix, scale:p.scale, size:ttsize[p.prefixmode],
			offset:offset, labno:labno, def:d)

	when j_name then
		d:=getpst(p.def)
		if d.id=label_name then
			if d.index=0 then
				d.index:=++labelno
			fi
			ax:=mgenlabel(d.index)
		else
			ax:=mgenmemaddr(d)
		fi

	when j_assemxreg then
		ax:=mgenxreg(p.reg)
	when j_bin then				!assume add/sub
		x:=p.a
		y:=p.b
		if x.tag=j_name and y.tag=j_const then
			d:=getpst(x.def)
			offset:=(p.genop=add_op|y.value|-y.value)
			if d.id=label_name then
				if d.index=0 then
					d.index:=++labelno
				fi
				ax:=mgenlabel(d.index)
			else
				ax:=mgenmemaddr(d)
			fi
			ax.offset:=offset
		else
			gerror("ax:imm/add")
		fi
	else
		cpl jtagnames[p.tag]
		gerror("genasmopnd?")
	esac

	return ax

end

global function iswide(int m)int=
	return ttcat[m]=wide_cat
end
=== bb_mcldecls.m 27/40 ===
import bb_pclcommon

global type mcloperand = ref mclopndrec

global record mclopndrec =		!up to 32 bytes
	union
		ref pstrec def
		int64 value		!immediate value
		real64 xvalue	!immediate real value, mainly for dq
		ichar svalue	!immediate string
		int labelno
		int sysfn
		int tempno
	end

	byte size			!byte size of operand: usually 1,2,4,8,16
	byte mode			!a_reg etc, low level operand details
	byte reg			!0, or main register
	byte regix			!0, or index register

	byte valtype		!interpretation of def/code/value/svalue
	byte scale			!1, or scale factor for regix
	int32 offset		!extra offset to label for mem/imm modes

	byte addrsize		!4 or 8 for a_mem when regs are involved

end

global record mclrec =		!32 bytes
	ref mclrec nextmcl
	mcloperand a,b
	byte opcode
	union
		byte cond
		byte isglobal
		byte sysindex
	end
	byte c
	int pos:(lineno:24, fileno:8)
	ichar comment
	[r0..r15]byte regend		!1 indicates register freed.
end

global tabledata() [0:]ichar valtypenames =
	(no_val=0,		$),		!no operand
	(intimm_val,	$),		!immediate int
	(realimm_val,	$),		!immediate real (mainly for dq etc)
	(realmem_val,	$),		!indirect real (for movq etc)
	(stringimm_val,	$),		!immediate string, for comments, or address of string etc
	(def_val,		$),		!var/proc name
	(temp_val,		$),		!temporary
	(label_val,		$),		!label index
	(name_val,		$),		!immediate string must be output as ah unquoted name
	(syscall_val,	$),		!
end

global tabledata() []ichar mclnames, []byte mclnopnds, []byte mclcodes =

	(m_procstart,		$,		0,		0),		!
	(m_procend,			$,		0,		0),		!
	(m_comment,			$,		0,		0),		!
	(m_blank,			$,		0,		0),		!
	(m_deleted,			$,		0,		0),		!
	(m_labelname,		$,		0,		0),		!
	(m_define,			$,		0,		0),		!
	(m_definereg,		$,		0,		0),		!

	(m_label,			$,		1,		0),		!
	(m_nop,				$,		0,		0x90),		!
	(m_param,			$,		1,		0),		!

	(m_mov,				$,		2,		0),		!
	(m_push,			$,		1,		0),		!
	(m_pop,				$,		1,		0),		!
	(m_lea,				$,		2,		0),		!
	(m_cmovcc,			$,		2,		0),		!

	(m_movd,			$,		2,		0),		!
	(m_movq,			$,		2,		0),		!

	(m_movsx,			$,		2,		0),		!
	(m_movzx,			$,		2,		0),		!
	(m_movsxd,			$,		2,		0),		!

	(m_call,			$,		1,		0xE8),		!
	(m_ret,				$,		0,		0xC3),	!
	(m_leave,			$,		0,		0xC9),	!
	(m_retn,			$,		1,		0),		!

	(m_jmp,				$,		1,		0xE9),	!
	(m_jmpcc,			$,		2,		0),		!
	(m_xchg,			$,		2,		0),		!

	(m_add,				$,		2,		0),		!
	(m_sub,				$,		2,		5),		!
	(m_adc,				$,		2,		2),		!
	(m_sbb,				$,		2,		3),		!
	(m_imul,			$,		1,		5),		!
	(m_mul,				$,		1,		4),		!
	(m_imul2,			$,		2,		0),		!
	(m_imul3,			$,		3,		0),		!

	(m_idiv,			$,		1,		7),		!
	(m_div,				$,		1,		6),		!

	(m_andx,			$,		2,		0x04),	!
	(m_orx,				$,		2,		0x01),	!
	(m_xorx,			$,		2,		0x06),	!
	(m_test,			$,		2,		0),		!

	(m_cmp,				$,		2,		0x07),	!

	(m_shl,				$,		2,		0x04),	!
	(m_sar,				$,		2,		0x07),	!
	(m_shr,				$,		2,		0x05),	!
	(m_rol,				$,		2,		0x00),	!
	(m_ror,				$,		2,		0x01),	!
	(m_rcl,				$,		2,		0x02),	!
	(m_rcr,				$,		2,		0x03),	!

	(m_neg,				$,		1,		3),		!
	(m_notx,			$,		1,		2),		!

	(m_inc,				$,		1,		0),		!
	(m_dec,				$,		1,		1),		!

	(m_cbw,				$,		0,		0),	!
	(m_cwd,				$,		0,		0),	!
	(m_cdq,				$,		0,		0),		!
	(m_cqo,				$,		0,		0),		!
	(m_setcc,			$,		2,		0),		!

	(m_bsf,				$,		2,		0xBC),	!
	(m_bsr,				$,		2,		0xBD),	!

	(m_sqrtsd,			$,		2,		0x51),	!
	(m_sqrtss,			$,		2,		0x51),	!
	(m_addss,			$,		2,		0x58),	!
	(m_subss,			$,		2,		0x5C),	!
	(m_mulss,			$,		2,		0x59),	!
	(m_divss,			$,		2,		0x5E),	!

	(m_addsd,			$,		2,		0x58),	!
	(m_subsd,			$,		2,		0x5C),	!
	(m_mulsd,			$,		2,		0x59),	!
	(m_divsd,			$,		2,		0x5E),	!

	(m_comiss,			$,		2,		0),		!
	(m_comisd,			$,		2,		0),		!
	(m_xorpd,			$,		2,		0x57),	!
	(m_xorps,			$,		2,		0x57),	!
	(m_andpd,			$,		2,		0x54),	!
	(m_andps,			$,		2,		0x54),	!
	(m_pxor,			$,		2,		0xEF),	!
	(m_pand,			$,		2,		0xDB),	!
	(m_cvtss2si,		$,		2,		0),		!
	(m_cvtsd2si,		$,		2,		0),		!
	(m_cvttss2si,		$,		2,		0),		!
	(m_cvttsd2si,		$,		2,		0),		!

	(m_cvtsi2ss,		$,		2,		0),		!
	(m_cvtsi2sd,		$,		2,		0),		!

	(m_cvtsd2ss,		$,		2,		0),		!
	(m_cvtss2sd,		$,		2,		0),		!

	(m_movdqa,			$,		2,		0x66),	!
	(m_movdqu,			$,		2,		0xF3),	!

	(m_pcmpistri,		$,		3,		0x63),	!
	(m_pcmpistrm,		$,		3,		0x62),	!

	(m_fld,				$,		1,		0),		!
	(m_fst,				$,		1,		2),		!
	(m_fstp,			$,		1,		3),		!

	(m_fild,			$,		1,		0),		!
	(m_fist,			$,		1,		2),		!
	(m_fistp,			$,		1,		3),		!

	(m_fadd,			$,		0,		0xC1),	!
	(m_fsub,			$,		0,		0xE9),	!
	(m_fmul,			$,		0,		0xC9),	!
	(m_fdiv,			$,		0,		0xF9),	!
	(m_fsqrt,			$,		0,		0xFA),	!
	(m_fsin,			$,		0,		0xFE),	!
	(m_fcos,			$,		0,		0xFF),	!
	(m_fsincos,			$,		0,		0xFB),	!
	(m_fptan,			$,		0,		0xF2),	!
	(m_fpatan,			$,		0,		0xF3),	!
	(m_fabs,			$,		0,		0xE1),	!
	(m_fchs,			$,		0,		0xE0),	!

	(m_minss,			$,		2,		0x5D),	!
	(m_maxss,			$,		2,		0x5F),	!
	(m_minsd,			$,		2,		0x5D),	!
	(m_maxsd,			$,		2,		0x5F),	!

	(m_db,				$,		1,		0),		!
	(m_dw,				$,		1,		0),		!
	(m_dd,				$,		1,		0),		!
	(m_dq,				$,		1,		0),		!
	(m_ddoffset,		$,		1,		0),		!

	(m_segment,			$,		1,		0),		!
	(m_isegment,		$,		0,		0),		!
	(m_zsegment,		$,		0,		0),		!
	(m_csegment,		$,		0,		0),		!

	(m_align,			$,		1,		0),		!
	(m_resb,			$,		1,		1),		!
	(m_resw,			$,		1,		2),		!
	(m_resd,			$,		1,		4),		!
	(m_resq,			$,		1,		8),		!

	(m_xlat,			$,		0,		0xD7),	!
	(m_loopnz,			$,		1,		0xE0),	!
	(m_loopz,			$,		1,		0xE1),	!
	(m_loopcx,			$,		1,		0xE2),	!
	(m_jecxz,			$,		1,		0xE3),	!
	(m_jrcxz,			$,		1,		0xE3),	!

	(m_cmpsb,			$,		0,		0),		!
	(m_cmpsw,			$,		0,		0),		!
	(m_cmpsd,			$,		0,		0),		!
	(m_cmpsq,			$,		0,		0),		!

	(m_rdtsc,			$,		0,		0x31),	!
	(m_popcnt,			$,		2,		0),		!

	(m_finit,			$,		0,		0),		!

	(m_fldz,			$,		0,		0xEE),	!
	(m_fld1,			$,		0,		0xE8),	!
	(m_fldpi,			$,		0,		0xEB),	!
	(m_fld2t,			$,		0,		0xE9),	!
	(m_fld2e,			$,		0,		0xEA),	!
	(m_fldlg2,			$,		0,		0xEC),	!
	(m_fldln2,			$,		0,		0xED),	!

	(m_halt,			$,		0,		0xF4),	!
end

global tabledata() [0:]ichar regnames, [0:]byte regcodes =
	(rnone=0,	$,	0),			!
	(r0,		$,	0),			!d0 rax
	(r1,		$,	10),		!d1 r10
	(r2,		$,	11),		!d2 r11
	(r3,		$,	7),			!d3 rdi
	(r4,		$,	3),			!d4 rbx
	(r5,		$,	6),			!d5 rsi
	(r6,		$,	12),		!d6 r12
	(r7,		$,	13),		!d7 r13
	(r8,		$,	14),		!d8 r14
	(r9,		$,	15),		!d9 r15
	(r10,		$,	1),			!d10 rcx
	(r11,		$,	2),			!d11 rdx
	(r12,		$,	8),			!d12 r8
	(r13,		$,	9),			!d13 r9
	(r14,		$,	5),			!d14 rbp
	(r15,		$,	4),			!d15 rsp

	(r16,		$,	4),			!b0h ah
	(r17,		$,	7),			!b1h bh
	(r18,		$,	5),			!b10h ch
	(r19,		$,	6),			!b11h dh
end

global const rframe = r14
global const rstack = r15

global tabledata() [0:]ichar condnames, [0:]ichar asmcondnames,
		[0:]int asmrevcond =

	(ov_cond=0,		"ov",	"o",		nov_cond),
	(nov_cond=1,	"nov",	"no",		ov_cond),

	(ltu_cond=2,	"ltu",	"b",		geu_cond),
	(geu_cond=3,	"geu",	"ae",		ltu_cond),

	(eq_cond=4,		"eq",	"z",		ne_cond),
	(ne_cond=5,		"ne",	"nz",		eq_cond),

	(leu_cond=6,	"leu",	"be",		gtu_cond),
	(gtu_cond=7,	"gtu",	"a",		leu_cond),

	(s_cond=8,		"s",	"s",		ns_cond),
	(ns_cond=9,		"ns",	"ns",		s_cond),

	(p_cond=10,		"p",	"p",		np_cond),
	(np_cond=11,	"np",	"np",		p_cond),

	(lt_cond=12,	"lt",	"l",		ge_cond),
	(ge_cond=13,	"ge",	"ge",		lt_cond),

	(le_cond=14,	"le",	"le",		gt_cond),
	(gt_cond=15,	"gt",	"g",		le_cond),

	(flt_cond=16,	"flt",	"b",		fge_cond),		!special floating point codes
	(fge_cond=17,	"fge",	"ae",		flt_cond),
	(fle_cond=18,	"fle",	"be",		fgt_cond),
	(fgt_cond=19,	"fgt",	"a",		fle_cond)
end

global const z_cond = eq_cond
global const nz_cond = ne_cond



global tabledata []ichar dregnames, []byte regsizes, []byte regindices =
	("d0",		8,	r0),		!rax	d0..d9 are for general use
	("d1",		8,	r1),		!r10	d0..d2 are volatile in ABI
	("d2",		8,	r2),		!r11

	("d3",		8,	r3),		!rdi	d3..d9 are preserved across funcs in ABI
	("d4",		8,	r4),		!rbx
	("d5",		8,	r5),		!rsi
	("d6",		8,	r6),		!r12
	("d7",		8,	r7),		!r13
	("d8",		8,	r8),		!r14
	("d9",		8,	r9),		!r15

	("d10",		8,	r10),		!rcx	d10..d13 are win64 ABI register passing regs
	("d11",		8,	r11),		!rdx	..
	("d12",		8,	r12),		!r8		..
	("d13",		8,	r13),		!r9		..

	("d14",		8,	r14),		!rbp	frame pointer
	("d15",		8,  r15),		!rsp	stack pointer

	("a0",		4,	r0),
	("a1",		4,	r1),
	("a2",		4,	r2),
	("a3",		4,	r3),
	("a4",		4,	r4),
	("a5",		4,	r5),
	("a6",		4,	r6),
	("a7",		4,	r7),
	("a8",		4,	r8),
	("a9",		4,	r9),
	("a10",		4,	r10),
	("a11",		4,	r11),
	("a12",		4,	r12),
	("a13",		4,	r13),
	("a14",		4,	r14),
	("a15",		4,  r15),

	("w0",		2,	r0),
	("w1",		2,	r1),
	("w2",		2,	r2),
	("w3",		2,	r3),
	("w4",		2,	r4),
	("w5",		2,	r5),
	("w6",		2,	r6),
	("w7",		2,	r7),
	("w8",		2,	r8),
	("w9",		2,	r9),
	("w10",		2,	r10),
	("w11",		2,	r11),
	("w12",		2,	r12),
	("w13",		2,	r13),
	("w14",		2,	r14),
	("w15",		2,  r15),


	("b0",		1,	r0),
	("b1",		1,	r1),
	("b2",		1,	r2),
	("b3",		1,	r3),
	("b4",		1,	r4),
	("b5",		1,	r5),
	("b6",		1,	r6),
	("b7",		1,	r7),
	("b8",		1,	r8),
	("b9",		1,	r9),
	("b10",		1,	r10),
	("b11",		1,	r11),
	("b12",		1,	r12),
	("b13",		1,	r13),
	("b14",		1,	r14),
	("b15",		1,  r15),
	("b16",		1,  r16),
	("b17",		1,  r17),
	("b18",		1,  r18),
	("b19",		1,  r19),

	("rax",		8,	r0),
	("rbx",		8,	r1),
	("rcx",		8,	r10),
	("rdx",		8,	r11),
	("rsi",		8,	r2),
	("rdi",		8,	r3),
	("rbp",		8,	r14),
	("rsp",		8,	r15),
	("r8",		8,	r12),
	("r9",		8,	r13),
	("r10",		8,	r4),
	("r11",		8,	r5),
	("r12",		8,	r6),
	("r13",		8,	r7),
	("r14",		8,	r8),
	("r15",		8,	r9),

	("eax",		4,	r0),
	("ebx",		4,	r1),
	("ecx",		4,	r10),
	("edx",		4,	r11),
	("esi",		4,	r2),
	("edi",		4,	r3),
	("ebp",		4,	r14),
	("esp",		4,	r15),
	("r8d",		4,	r12),
	("r9d",		4,	r13),
	("r10d",	4,	r4),
	("r11d",	4,	r5),
	("r12d",	4,	r6),
	("r13d",	4,	r7),
	("r14d",	4,	r8),
	("r15d",	4,	r9),

	("ax",		2,	r0),
	("bx",		2,	r1),
	("cx",		2,	r10),
	("dx",		2,	r11),
	("si",		2,	r2),
	("di",		2,	r3),
	("bp",		2,	r14),
	("sp",		2,	r15),
	("r8w",		2,	r12),
	("r9w",		2,	r13),
	("r10w",	2,	r4),
	("r11w",	2,	r5),
	("r12w",	2,	r6),
	("r13w",	2,	r7),
	("r14w",	2,	r8),
	("r15w",	2,	r9),


	("al",		1,	r0),
	("bl",		1,	r1),
	("cl",		1,	r10),
	("dl",		1,	r11),

	("ah",		1,	r16),
	("bh",		1,	r17),
	("ch",		1,	r18),
	("dh",		1,	r19),

	("sil",		1,	r2),
	("dil",		1,	r3),
	("bpl",		1,	r14),
	("spl",		1,	r15),

	("r8b",		1,	r12),
	("r9b",		1,	r13),
	("r10b",	1,	r4),
	("r11b",	1,	r5),
	("r12b",	1,	r6),
	("r13b",	1,	r7),
	("r14b",	1,	r8),
	("r15b",	1,	r9),

end

global []ichar xmmregnames = (
	"xmm0",
	"xmm1",
	"xmm2",
	"xmm3",
	"xmm4",
	"xmm5",
	"xmm6",
	"xmm7",
	"xmm8",
	"xmm9",
	"xmm10",
	"xmm11",
	"xmm12",
	"xmm13",
	"xmm14",
	"xmm15")

global []ichar fregnames = (
	"st0",
	"st1",
	"st2",
	"st3",
	"st4",
	"st5",
	"st6",
	"st7")

global []ichar mregnames = (
	"mmx0",
	"mmx1",
	"mmx2",
	"mmx3",
	"mmx4",
	"mmx5",
	"mmx6",
	"mmx7")


global tabledata []ichar jmpccnames, []byte jmpcccodes =
	("jo",		ov_cond),
	("jno",		nov_cond),
	("jb",		ltu_cond),
	("jae",		geu_cond),
	("jz",		eq_cond),
	("jnz",		ne_cond),
	("jbe",		leu_cond),
	("ja",		gtu_cond),
	("js",		s_cond),
	("jns",		ns_cond),
	("jp",		p_cond),
	("jnp",		np_cond),
	("jl",		lt_cond),
	("jge",		ge_cond),
	("jle",		le_cond),
	("jg",		gt_cond),
end

global tabledata []ichar setccnames, []byte setcccodes =
	("seto",	ov_cond),
	("setno",	nov_cond),
	("setb",	ltu_cond),
	("setae",	geu_cond),
	("setz",	eq_cond),
	("setnz",	ne_cond),
	("setbe",	leu_cond),
	("seta",	gtu_cond),
	("sets",	s_cond),
	("setns",	ns_cond),
	("setp",	p_cond),
	("setnp",	np_cond),
	("setl",	lt_cond),
	("setge",	ge_cond),
	("setle",	le_cond),
	("setg",	gt_cond),
end

global tabledata []ichar cmovccnames, []byte cmovcccodes =
	("cmovo",	ov_cond),
	("cmovno",	nov_cond),
	("cmovb",	ltu_cond),
	("cmovae",	geu_cond),
	("cmovz",	eq_cond),
	("cmovnz",	ne_cond),
	("cmovbe",	leu_cond),
	("cmova",	gtu_cond),
	("cmovs",	s_cond),
	("cmovns",	ns_cond),
	("cmovp",	p_cond),
	("cmovnp",	np_cond),
	("cmovl",	lt_cond),
	("cmovge",	ge_cond),
	("cmovle",	le_cond),
	("cmovg",	gt_cond),
end

global tabledata() [0:]ichar segmentnames =
	(no_seg=0,		$),
	(code_seg,		$),
	(idata_seg,		$),
	(zdata_seg,		$),
	(rodata_seg,	$),
	(impdata_seg,	$),
end

global tabledata() [0:]ichar reftypenames =	!use during pass2
	(extern_ref=0,		$),		!is external
	(fwd_ref,			$),		!not yet reached
	(back_ref,			$),		!has been reached
end

=== bb_stackmcl.m 28/40 ===
import msys
import mlib
import clib

import bb_decls
import bb_support
import bb_libpcl
import bb_mcldecls
import bb_genmcl
import bb_libmcl
import bb_pclcommon
import bb_LIB

global const regmax=r9				!can use r0 to regmax inclusive; only those regs
global const xregmax=xr6
									!can appear in opndstack; rest must be rtos


global const maxoperands=100

global [maxoperands+1]pclstackrec pclopndstack
global int noperands
global int mstackdepth

global record pclstackrec =
	byte fmt
	byte loc
	byte reg
	byte float
	byte wide			!0 or 'H' or 'L'
	int16 spare
	union
		int value
		real xvalue
		ichar svalue
		ref pstrec def
	end
end

global ref[]pclstackrec pclstack
pclstackrec pclzero

global const maxcalldepth=16
global [maxcalldepth]int callshadow
global [maxcalldepth]int callslots
global [maxcalldepth]byte callalign		!pending 1-slot alignment for syscalls
global int ncalldepth


global tabledata() [0:]ichar locnames =
	(no_loc=0,		$),			! not set
	(reg_loc,		$),			! in a d64 register
	(xreg_loc,		$),			! in an x64
	(stack_loc,		$),			! on the hardware stack (must be ordered properly)
	(imm_loc,		$),			! still as an immediate value
	(mem_loc,		$),			! still in variable
	(memhigh_loc,	$),			! still in variable
	(regvar_loc,	$),			! still in a reg variable
	(xregvar_loc,	$),			! still in an xreg variable
end

global tabledata() [0:]ichar fmtnames, [0:]byte loccodes, [0:]byte catcodes,
		[0:]byte loadfmt, [0:]byte pushfmt =
	(nofmt_void=0,	$,	0,				0,			0,			0),
	(reg_d64,		$,	reg_loc,		d64_cat,	0,			stack_d64),
	(reg_var,		$,	reg_loc,		var_cat,	0,			stack_var),

	(xreg_x64,		$,	xreg_loc,		x64_cat,	0,			stack_x64),
	(xreg_x32,		$,	xreg_loc,		x32_cat,	0,			stack_x32),

	(stack_d64,		$,	stack_loc,		d64_cat,	reg_d64,	0),
	(stack_var,		$,	stack_loc,		var_cat,	reg_var,	0),
	(stack_x64,		$,	stack_loc,		x64_cat,	xreg_x64,	0),
	(stack_x32,		$,	stack_loc,		x32_cat,	xreg_x32,	0),

	(imm_d64,		$,	imm_loc,		d64_cat,	reg_d64,	stack_d64),
	(imm_x64,		$,	imm_loc,		x64_cat,	xreg_x64,	stack_x64),
	(imm_x32,		$,	imm_loc,		x32_cat,	xreg_x32,	stack_x32),
	(imm_str,		$,	imm_loc,		d64_cat,	reg_d64,	stack_d64),
	(imm_memaddr,	$,	imm_loc,		d64_cat,	reg_d64,	stack_d64),

	(mem_d64,		$,	mem_loc,		d64_cat,	reg_d64,	stack_d64),
	(mem_x64,		$,	mem_loc,		x64_cat,	xreg_x64,	stack_x64),
	(mem_x32,		$,	mem_loc,		x32_cat,	xreg_x32,	stack_x32),
	(mem_var,		$,	mem_loc,		var_cat,	reg_var,	stack_var),

	(memhigh_d64,	$,	mem_loc,		d64_cat,	reg_var,	stack_d64),

	(regvar_d64,	$,	regvar_loc,		d64_cat,	reg_d64,	stack_d64),

	(xregvar_x64,	$,	xregvar_loc,	x64_cat,	xreg_x64,	stack_x64),
end

global [r0..r15]byte regset			!register in-use flags: 0/1: free/in-use
global [r0..r15]byte xregset		!same for xregs



global int inf_proccalls
global int inf_proclocals
global int inf_procxlocals

global int inf_leafproc
global int inf_highreg
global int inf_highxreg
global int inf_maxargs
global int inf_assem

global int inf_r10used		!these may be set in pass2 when occupied by params
global int inf_r11used
global int inf_r13used


global [16]int dsaveregs
global [16]int xsaveregs
global int ndsaveregs	!set in procentry; at one or both will be zero
global int ndsavepush
global int nxsaveregs
global int dsaveoffset
global int xsaveoffset
global int needstackframe
global int framebytes
global int needshadow48
global int needshadow32		!has value 0, 32 or 40, the actual spaced needed

global byte noxorclear		!1 to suppress xor optimisation

global const wd = 4
global const xc = 3
global const yb = 2
global const za = 1

global const xb = 2
global const ya = 1

global const xa = 1

global tabledata() [0:]ichar xregnames =
	(xnone=0,	$),
	(xr0,		$),
	(xr1,		$),
	(xr2,		$),
	(xr3,		$),
	(xr4,		$),
	(xr5,		$),
	(xr6,		$),
	(xr7,		$),
	(xr8,		$),
	(xr9,		$),
	(xr10,		$),
	(xr11,		$),
	(xr12,		$),
	(xr13,		$),
	(xr14,		$),
	(xr15,		$)
end

global macro freereg(r) =
	(regset[r]:=0; mccodex.regend[r]:=1)


global proc resetopnds1=

	if mstackdepth then
		println "1:HW stack not empty",procdef.name,=mstackdepth
		MSTACKDEPTH:=0
	fi
	if noperands then
		println "1:Reset:pcl stack not empty:",procdef.name,=noperands
		NOPERANDS:=0
	fi


	for i in regset.bounds do
		if regset[i] or xregset[i] then
			println "Reset: reg flag set",procdef.name
			exit
		fi
	od

	if inf_proccalls=0 then inf_leafproc:=1 fi



	memset(&.regset,0,regset.bytes)
	memset(&.xregset,0,xregset.bytes)

	if not foptimise then			!else needed for pass 2 procentry
		inf_proccalls:=0
		inf_maxargs:=0
		inf_proclocals:=0
		inf_procxlocals:=0

		inf_leafproc:=0
		inf_highreg:=inf_highxreg:=rnone
		inf_assem:=0
	else

		inf_proccalls:=0
		inf_maxargs:=0
		inf_proclocals:=0
		inf_procxlocals:=0



	fi
end

global proc resetopnds2=

	if mstackdepth then
		println "2:HW stack not empty",procdef.name,=mstackdepth
	fi
	if noperands then
		println "2:Reset:pcl stack not empty:",procdef.name,=noperands
		NOPERANDS:=0
	fi


	for i in regset.bounds do
		if regset[i] or xregset[i] then
			println "2:Reset: reg flag set",regnames[i],procdef.name
			exit
		fi
	od

	inf_proccalls:=0
	inf_maxargs:=0
	inf_proclocals:=0
	inf_procxlocals:=0

	inf_leafproc:=0
	inf_highreg:=inf_highxreg:=rnone
	inf_assem:=0

	inf_r10used:=inf_r11used:=inf_r13used:=0

	memset(&.regset,0,regset.bytes)
	memset(&.xregset,0,xregset.bytes)
end

proc newopnd(int fmt)=
	if noperands>=maxoperands then
		merror("PCL stack overflow")
	fi
	++noperands
	pclstack:=cast(&pclstack[0])
	pclstack[1]:=pclzero
	pclstack[1].fmt:=fmt
	pclstack[1].loc:=loccodes[fmt]
	pclstack[1].reg:=rnone
	pclstack[1].float:=(catcodes[fmt] in [x64_cat,x32_cat]|1|0)
end

global proc addint(int a)=
	newopnd(imm_d64)
	pclstack[1].value:=a
end

global proc addint128(ref int p)=
	newopnd(imm_d64)
	pclstack[1].value:=(p+1)^
	newopnd(imm_d64)
	pclstack[1].value:=p^
	setwideopnd()
end

global proc addreal(real x)=
	newopnd(imm_x64)
	pclstack[1].xvalue:=x
end

global proc addreal32(real x)=
	newopnd(imm_x32)
	pclstack[1].xvalue:=x
end

global proc addstring(ichar s)=
	newopnd(imm_str)
	pclstack[1].svalue:=s
end

global proc addmem(pcl p)=
	mcloperand ax
	ref pstrec d:=p.def

	switch ttcat[p.mode]
	when d64_cat then
		if d.reg then
			newopnd(regvar_d64)
			pclstack[1].reg:=d.reg
		else
			newopnd(mem_d64)
		fi
	when x64_cat then
		if d.reg then
			newopnd(xregvar_x64)
			pclstack[1].reg:=d.reg
		else
			newopnd(mem_x64)
		fi
	when x32_cat then newopnd(mem_x32)
	when var_cat then newopnd(mem_var)
	when wide_cat then
		newopnd(memhigh_d64)
		pclstack[1].def:=d
		pclstack[1].wide:='H'
		newopnd(mem_d64)
		pclstack[1].wide:='L'

	when short_cat then
		ADDREG_D64()
		ax:=genopnd(xa)
		genmc((ttisint[d.mode]|m_movsx|m_movzx), ax, mgenmem(d))
		return

	when block_cat then newopnd(mem_d64)

	else

CPL TYPECATNAMES[TTCAT[P.MODE]]
CPL TYPECATNAMES[TTCAT[D.MODE]]
		ADDREG_D64()
		 merror("ADDMEM?")
	endswitch

	pclstack[1].def:=d
end

global proc addmemaddr(ref pstrec d)=
	newopnd(imm_memaddr)
	pclstack[1].def:=d
end

global proc addreg0(int reg)=
	newopnd(reg_d64)
	pclstack[1].reg:=reg
	if regset[reg] then
		merror("addreg0/reg in use")
	fi
	regset[reg]:=1
end

global proc addwidereg0(int reg)=
	int reg2
	reg2:=reg+1
	if reg2=r3 then reg2:=r10 fi
	newopnd(reg_d64)
	newopnd(reg_d64)
	pclstack[2].reg:=reg2
	pclstack[1].reg:=reg
	if regset[reg] then
		merror("addwidereg/reg(s) in use")
	fi
	regset[reg]:=1
	setwideopnd(1)
end

global proc addxreg0(int reg,fmt)=
	newopnd(fmt)
	pclstack[1].reg:=reg
	if xregset[reg] then merror("addxreg0/reg in use") fi
	xregset[reg]:=1
end

global proc addreg_d64=
	newopnd(reg_d64)
	pclstack[1].reg:=getnextreg()
end

global proc addreg_x64=
	newopnd(xreg_x64)
	pclstack[1].reg:=getnextxreg()
end

global proc addreg_x32=
	newopnd(xreg_x32)
	pclstack[1].reg:=getnextxreg()
end

global function stropndstack(int indent=0)ichar=
	static [512]char str
	[512]char str2
	ichar s:=&.str, t
	pclstackrec pc

	if indent then
		fprint @s, "                                     ("
	else
		fprint @s, "("
	fi

	for i:=noperands downto 1 do
		pc:=pclstack[i]
		case pc.loc
		when reg_loc then
			strcat(s, regnames[pc.reg])

		when regvar_loc then
			strcat(s, regnames[pc.reg])
			strcat(s, "=")
			strcat(s, pc.def.name)

		when xreg_loc then
			strcat(s, xregnames[pc.reg])
			strcat(s, ":")
			strcat(s, fmtnames[pc.fmt])
		when xregvar_loc then
			strcat(s, xregnames[pc.reg])
			strcat(s, "=")
			strcat(s, pc.def.name)


		when stack_loc then
			strcat(s, "T")
		when mem_loc then
			strcat(s,"M:")
			strcat(s,pc.def.name)
		elsecase pc.fmt
		when imm_d64 then
			strcat(s, strint(pc.value))
		when imm_x64 then
				strcat(s, strreal(pc.xvalue))
		when imm_str then
			t:=pc.svalue
			if strlen(t)>20 then
				strcat(s,"LONG STR")
			else
				strcat(s,"""")
				convertstring(t,s+strlen(s))
				strcat(s,"""")
			fi
		when imm_memaddr then
			strcat(s,"&")
			strcat(s,pc.def.name)
		else
			strcat(s,FMTNAMES[pc.fmt])
		esac
		if pc.wide then strcat(s,(pc.wide='H'|"(H)"|"(L)")) fi

		if i>1 then strcat(s,",") fi
	od
	strcat(s,") (")
	for r:=r0 to regmax do
		strcat(s,(regset[r]|"1 "|"0 "))
	od
	strcat(s,") (")
	for r:=r0 to xregmax do
		strcat(s,(xregset[r]|"1 "|"0 "))
	od

	strcat(s,") hwstack:")
	strcat(s,strint(mstackdepth))
	strcat(s," noperands:")
	strcat(s,strint(noperands))
	strcat(s," ncalldepth:")
	strcat(s,strint(ncalldepth))
	strcat(s," callslots[]:")
	strcat(s,strint(callslots[ncalldepth]))
	return s
end

global proc showopndstack=
	mgencomment(stropndstack(1))
end

global proc loadopnd(int n=1, int nvreg=0)=
	int reg,value
	mcloperand ax

	if n>noperands then
MGENCOMMENT("UNDERFLOW")
RETURN
		merror("loadopnd/underflow")
	fi
	if pclstack[n].loc=reg_loc then
		return
	fi

	if pclstack[n].loc=xreg_loc then
		return
	fi

	if pclstack[n].float then
		reg:=getnextxreg(nvreg)
	else
		reg:=getnextreg(nvreg)
	fi

	case pclstack[n].loc
	when xreg_loc then
		MERROR("LOADOPND/XREG")
	elsecase pclstack[n].fmt
	when imm_d64 then
		value:=pclstack[n].value


		if value=0 and not noxorclear then
			ax:=mgenreg(reg,4)
			genmc(m_xorx,ax,ax)
		else
			genmc(m_mov,mgenreg(reg),mgenint(pclstack[n].value))
		fi

	when imm_x64 then
		genmc(m_movq,mgenxreg(reg),mgenrealmem(pclstack[n].xvalue))

	when imm_x32 then
		genmc(m_movd,mgenxreg(reg),mgenrealmem(pclstack[n].xvalue,4))

	when imm_str then
		genmc(m_mov,mgenreg(reg),mgenlabel(getstringindex(pclstack[n].svalue)))

	when mem_d64 then
		genmc(m_mov,mgenreg(reg),mgenmem(pclstack[n].def))

	when mem_x64 then
		genmc(m_movq,mgenxreg(reg),mgenmem(pclstack[n].def))

	when mem_x32 then
		genmc(m_movd,mgenxreg(reg),mgenmem(pclstack[n].def))

	when memhigh_d64 then
		genmc(m_mov,mgenreg(reg),mgenmemhigh(pclstack[n].def))

	when regvar_d64 then
		genmc(m_mov,mgenreg(reg),mgenregvar(pclstack[n].def))

	when xregvar_x64 then
		genmc(m_movq,mgenxreg(reg),mgenxregvar(pclstack[n].def))

	when stack_d64 then
		genmc(m_pop, mgenreg(reg))
		--mstackdepth

	when stack_x64 then
		if inf_r13used then merror("R13 in use") fi
		genmc(m_pop, mgenreg(r13))
		genmc(m_movq, mgenxreg(reg), mgenreg(r13))
		--mstackdepth

	when stack_x32 then
		if inf_r13used then merror("R13 in use") fi
		genmc(m_pop, mgenreg(r13))
		genmc(m_movd, mgenxreg(reg), mgenreg(r13,4))
		--mstackdepth

	when imm_memaddr then
		genmc(m_lea,mgenreg(reg),mgenmem(pclstack[n].def))

	else
CPL STROPNDSTACK()
		MERROR("LOADOPND??",fmtnames[pclstack[n].fmt])
	esac

	pclstack[n].reg:=reg
	pclstack[n].fmt:=loadfmt[pclstack[n].fmt]
	pclstack[n].loc:=loccodes[pclstack[n].fmt]


end


global proc loadparam(int n=1, reg)=
	int oldreg, value
	mcloperand ax

	ax:=mgenreg(reg)
	oldreg:=pclstack[n].reg

	case pclstack[n].fmt
	when reg_d64, regvar_d64, reg_var then
		genmc(m_mov, ax, mgenreg(oldreg))
		freereg(oldreg)

	when xreg_x64, xregvar_x64 then
		genmc(m_movq, ax, mgenxreg(oldreg))
		return							!leave loc unchanged
	when xreg_x32 then
		genmc(m_movd, changeopndsize(ax,4), mgenxreg(oldreg))
		return

	when imm_d64 then
		value:=pclstack[n].value
		if value=0 then
			ax:=mgenreg(reg,4)
			genmc(m_xorx, ax,ax)
		else
			genmc(m_mov, ax, mgenint(pclstack[n].value))
		fi
	when imm_x64 then
		genmc(m_mov, ax, mgenrealmem(pclstack[n].xvalue))
	when imm_str then
		genmc(m_mov,ax, mgenlabel(getstringindex(pclstack[n].svalue)))

	when mem_d64 then
		genmc(m_mov,ax,mgenmem(pclstack[n].def))

	when memhigh_d64 then
		genmc(m_mov,ax,mgenmemhigh(pclstack[n].def))

	when imm_memaddr then
		genmc(m_lea,ax,mgenmem(pclstack[n].def))
	when mem_x64 then
		genmc(m_mov,ax,mgenmem(pclstack[n].def))

	when stack_d64 then

		genmc(m_pop, ax)
		--mstackdepth

	else
CPL "LOADPARAM:",FMTNAMES[pclstack[n].FMT]
CPL("LOADPARAM??")
MGENCOMMENT("****LOADPARAM??")
		MERROR("LOADPARAM??",fmtnames[pclstack[n].fmt])
	esac
	pclstack[n].loc:=reg_loc
	pclstack[n].reg:=reg
end

global proc loadxparam(int n=1, reg)=
	mcloperand ax


	ax:=mgenxreg(reg)

	case pclstack[n].fmt
	when reg_d64, regvar_d64 then
		genmc(m_movq, ax, mgenreg(pclstack[n].reg))

	when xreg_x64, xregvar_x64 then
		genmc(m_movq, ax, mgenxreg(pclstack[n].reg))
	when xreg_x32 then
		genmc(m_movd, ax, mgenxreg(pclstack[n].reg))
	when imm_x64 then
		genmc(m_movq, ax, mgenrealmem(pclstack[n].xvalue))

	when imm_x32 then
		genmc(m_movd, ax, mgenrealmem(pclstack[n].xvalue,4))

	when mem_d64, mem_x64 then
		genmc(m_movq,ax,mgenmem(pclstack[n].def))

	when mem_x32 then
		genmc(m_movd,ax,mgenmem(pclstack[n].def,4))
	else
CPL "??LOADXPARAM",N,NOPERANDS
		MGENCOMMENT("****LOADXPARAM??")
		MERROR("LOADXPARAM??",fmtnames[pclstack[n].fmt])
	esac
end

global function genopnd(int index=1,size=8)mcloperand ax=
	int reg, value

	case pclstack[index].loc
	when reg_loc then
		return mgenreg(pclstack[index].reg,size)

	when regvar_loc then
		return mgenregvar(pclstack[index].def)

	when xreg_loc then
		return mgenxreg(pclstack[index].reg,size)

	when xregvar_loc then
		return mgenxregvar(pclstack[index].def)

	elsecase pclstack[index].fmt
	when mem_d64, mem_x64, mem_x32 then
		return mgenmem(pclstack[index].def)

	when memhigh_d64 then
		return mgenmemhigh(pclstack[index].def)
	when imm_d64 then
		value:=pclstack[index].value
		if int32.minvalue<=value<=int32.maxvalue then
			return mgenint(value)
		fi
		ax:=mgenreg(getnextreg())
		genmc(m_mov, ax, mgenint(value))
		pclstack[index].reg:=ax.reg
		pclstack[index].fmt:=reg_d64
		pclstack[index].loc:=reg_loc
		return ax

	when imm_x64 then
		return mgenrealmem(pclstack[index].xvalue)

	when imm_x32 then
		return mgenrealmem(pclstack[index].xvalue,4)

	when imm_memaddr then
		reg:=getnextreg()
		ax:=mgenreg(reg)
		genmc(m_lea,ax,mgenmem(pclstack[index].def))
		pclstack[index].reg:=ax.reg
		pclstack[index].fmt:=reg_d64
		pclstack[index].loc:=reg_loc
		return ax
	when imm_str then
		genmc(m_lea,ax:=mgenreg(getnextreg()),mgenlabel(getstringindex(pclstack[index].svalue)))
		pclstack[index].reg:=ax.reg
		pclstack[index].fmt:=reg_d64
		pclstack[index].loc:=reg_loc
		return ax

	else
CPL =LOCNAMES[PCLSTACK[INDEX].LOC]
CPL =FMTNAMES[PCLSTACK[INDEX].FMT]
CPL("GENOPND??")
MGENCOMMENT("****GENOPND??")
	esac

	return nil
end

global function genopnd_ld(int index=1,size=8)mcloperand=
	loadopnd(index)
	return genopnd(index,size)
end

global function genopnd_ind(int index=1,size=8)mcloperand=
	case pclstack[index].loc
	when reg_loc then
		return mgenireg(pclstack[index].reg,size)
		return mgenireg(pclstack[index].reg,size)
		return mgenireg(pclstack[index].reg,size)
	esac

	loadopnd(index)

	return genopnd_ind(index,size)
end

global function genopnd_d64:mcloperand=
	addreg_d64()
	return genopnd()
end

global proc setwideopnd(int n=1)=
	pclstack[n].wide:='L'
	pclstack[n+1].wide:='H'
end

global proc unsetwideopnd(int n=1)=
	pclstack[n].wide:=0
end

global function getnextreg(int nvreg=0)int=
	int reg,firstreg

	firstreg:=(nvreg|r3|r0)

	for r:=firstreg to regmax do
		if regset[r]=0 then
			regset[r]:=1
			inf_highreg max:=r


			return r
		fi
	od

	for i:=noperands downto 1 do
		if pclstack[i].loc=reg_loc then
			reg:=pclstack[i].reg
			if reg>=firstreg then
				pushopnd(i)
				return getnextreg(nvreg)
			fi
		fi
	od
	merror("NO FREE REGS")
	return 0
end

global function getnextxreg(int nvreg=0)int=
	int reg,firstreg

	firstreg:=(nvreg|r6|r4)

	for r:=firstreg to regmax do
		if xregset[r]=0 then
			xregset[r]:=1
				inf_highxreg max:=r
			return r
		fi
	od

	for i:=noperands downto 1 do
		if pclstack[i].loc=reg_loc then
			reg:=pclstack[i].reg
			if reg>=firstreg then
				pushopnd(i)
				return getnextxreg(nvreg)
			fi
		fi
	od
	merror("NO FREE XREGS")
	return 0
end

global proc delopnd=
	if noperands<=0 then
MGENCOMMENT("****DELND/UNDERFLOW"); RETURN
 merror("popopnd/underflow") fi

	case pclstack[1].loc
	when reg_loc,regvar_loc then
		freereg(pclstack[1].reg)
	when xreg_loc,xregvar_loc then
		freexreg(pclstack[1].reg)
	when mem_loc then
	when imm_loc then
	else
		merror("Can't pop opnd: #",locnames[pclstack[1].loc])
	esac

	--noperands
	pclstack:=cast(&pclstack[2])
end


global proc freexreg(int xr)=
	xregset[xr]:=0
end

global proc pushopnd(int n)=

	case pclstack[n].loc
	when reg_loc then
		genmc(m_push, mgenreg(pclstack[n].reg))
		freereg(pclstack[n].reg)

	when regvar_loc then
		genmc(m_push, mgenreg(pclstack[n].reg))

	when xreg_loc then
		if inf_r13used then merror("2:R13 in use") fi
		genmc(m_movq,mgenreg(r13), mgenxreg(pclstack[n].reg))
		genmc(m_push, mgenreg(r13))
		freexreg(pclstack[n].reg)

	when stack_loc then
		return
	elsecase pclstack[n].fmt
	when memhigh_d64 then
		genmc(m_push, mgenmemhigh(pclstack[n].def))

	when mem_d64, mem_x64 then
		genmc(m_push, mgenmem(pclstack[n].def))

	when mem_x32 then
		if inf_r13used then merror("4:R13 in use") fi
		genmc(m_mov,mgenreg(r13,4), mgenmem(pclstack[n].def,4))
		genmc(m_push, mgenreg(r13))

	when imm_d64 then
		genmc(m_push, mgenint(pclstack[n].value))

	when imm_x64 then
		genmc(m_push, mgenrealmem(pclstack[n].xvalue))

	when imm_str then
		genmc(m_push, mgenlabel(getstringindex(pclstack[n].svalue)))

	when imm_memaddr then
		if inf_r13used then merror("3:R13 in use") fi
		genmc(m_lea, mgenreg(r13), mgenmem(pclstack[n].def))
		genmc(m_push, mgenreg(r13))

	else
		merror("Can't push opnd: #",fmtnames[pclstack[n].fmt])
	esac

	pclstack[n].loc:=stack_loc
	pclstack[n].fmt:=pushfmt[pclstack[n].fmt]
	++mstackdepth
end

global proc pushallopnds(int n=1)=
	for i:=noperands downto n do

		pushopnd(i)
	od
end

global proc poparg=
	case pclstack[1].loc
	when reg_loc then freereg(pclstack[1].reg)
	when xreg_loc then freexreg(pclstack[1].reg)
	when stack_loc then
	when imm_loc then
	when mem_loc then
	when regvar_loc then
	when xregvar_loc then
	else
CPL "POPARG:",LOCNAMES[PCLSTACK[1].LOC]
MGENCOMMENT("****POPARG?")
		merror("poparg? #",locnames[pclstack[1].loc])
	esac
	--noperands
	pclstack:=cast(&pclstack[2])
end

global proc pushslots(int nslots)=
	pushstack(nslots*8)
	mstackdepth+:=nslots
end

global proc popslots(int nslots)=
	popstack(nslots*8)
	mstackdepth-:=nslots
end

global proc pushstack(int n)=
	if n then
		genmc(m_sub,dstackopnd,mgenint(n))
	fi
end

global proc popstack(int n)=
	if n then
		genmc(m_add,dstackopnd,mgenint(n))
	fi
end

global proc saveopnd(int n)=
	int reg

	case pclstack[n].loc
	when reg_loc then
		reg:=pclstack[n].reg
		if reg in r0..r2 then
			pushopnd(n)
		fi

	when xreg_loc then
		reg:=pclstack[n].reg
		if reg in r0..r5 then
			pushopnd(n)
		fi
	when stack_loc then
	when regvar_loc, xregvar_loc then
	when imm_loc then
		pushopnd(n)
	elsecase pclstack[n].fmt
	when memhigh_d64 then
		pushopnd(n)
	when mem_d64, mem_x64,mem_x32 then
		pushopnd(n)

	else

		merror("Can't save opnd: #",fmtnames[pclstack[n].fmt])
	esac
end

global proc saveallopnds(int n=1)=
	for i:=noperands downto n do
		saveopnd(i)
	od
end

global proc movetoreg(int newreg)=
	int oldreg

	loadopnd()

	oldreg:=pclstack[1].reg

	if oldreg=newreg then
		return
	fi

	if regset[newreg] then merror("movereg/reg in use") fi
	genmc(m_mov, mgenreg(newreg), mgenreg(oldreg))
	freereg(oldreg)
	pclstack[1].reg:=newreg
	regset[newreg]:=1
	if newreg>=r10 then inf_highreg max:=newreg fi
end

proc checkstackorder(int n)=
	for i:=n-1 downto 1 do
		if pclstack[i].loc=stack_loc then
[256]CHAR STR

MGENCOMMENT("****LOADOPND/POP MSTACK OUT OF ORDER")
		fi
	od
end

global proc swapopnds(int m,n)=
pclstackrec t

t:=pclstack[m]
pclstack[m]:=pclstack[n]
pclstack[n]:=t

end

global proc swapopndregs(int reg2)=

	int reg1:=pclstack[1].reg

	for i:=2 to noperands do
		if pclstack[i].loc=reg_loc and pclstack[i].reg=reg2 then
			swap(pclstack[1].reg, pclstack[2].reg)
			return
		fi
	else
CPL PROCDEF.NAME
		merror("swapopndregs/reg not found")
	od
end
=== bb_optim.m 29/40 ===
import msys
import mlib
import clib
import oslib

import bb_support

import bb_libmcl as mm
import bb_stackmcl
import bb_libpcl as pp
import bb_mcldecls
import bb_diags

import bb_decls

import bb_pclcommon
import bb_tables

global proc peephole(ref mclrec m)=
	ref mclrec m2,m3,mtarget,lastmcl
	int lab1,lab2
STATIC INT COUNT=0

	lastmcl:=nil


	do
		m2:=m.nextmcl
		while m2 and m2.opcode in [m_comment, m_deleted] do m2:=m2.nextmcl od

		switch m.opcode
		when m_procstart then

		when m_procend then
			exit

		when m_jmp then
dojmp::
			if m.a.valtype<>label_val then skip fi
			mtarget:=labeltable[m.a.labelno].nextmcl
			while mtarget.opcode=m_label do mtarget:=mtarget.nextmcl od
			if mtarget.opcode=m_jmp then
				m.a:=mgenlabel(mtarget.a.labelno)
			fi

			if m.opcode=m_jmp and m2.opcode=m_jmp then
				deletemcl(m2,101)
			fi


		when m_jmpcc then
			if m2.opcode<>m_jmp then goto dojmp fi
			lab1:=m.a.labelno
			m3:=m2.nextmcl
			if m3.opcode=m_label and m3.a.labelno=lab1 then
				m.a:=mgenlabel(m2.a.labelno)
				m.cond:=asmrevcond[m.cond]
				deletemcl(m2,102)
			fi

		when m_test then
			case lastmcl.opcode
			when m_andx, m_orx, m_xorx then
				if sameregopnd(m.a,m.b) and sameregopnd(m.a,lastmcl.a) then
					deletemcl(m,103)
				fi
			esac

		when m_movzx then
			if m.a.mode=a_reg and m.a.size=8 and m.b.size<4 then
				m.a:=changeopndsize(m.a,4)
			fi
			if m2.opcode=m_test and isreg(m2.a,r0) and isreg(m2.b,r0) and
					m2.nextmcl.opcode=m_jmpcc then
				m.opcode:=m_cmp
				m.a:=m.b
				m.b:=mgenint(0)
				deletemcl(m2,104)
			fi

		when m_mov then
			if m.a.mode=a_reg and m.a.reg=r10 and m.b.mode=a_reg and m.b.reg<=r1 then
				if lastmcl.a.mode=a_reg and lastmcl.a.reg=m.b.reg and
						lastmcl.opcode in [m_mov, m_movsx, m_movzx, m_lea] then
					lastmcl.a:=mgenreg(r10)
					deletemcl(m,105)
				fi
			fi

			if isreg0(m.a) and isregvar(m.b) then
				if isreg0(m2.b) and m2.regend[r0] AND M2.A.SIZE=8 then
					m2.b:=m.b
					deletemcl(m,106)
					skip
				fi

				if not isreg0(m2.a) then skip fi
				m3:=m2.nextmcl

				if m2.opcode=m_cmp and m3.opcode=m_jmpcc and m3.regend[r0] then
					m2.a:=m.b
					deletemcl(m,107)
				elsif m2.opcode=m_test and isreg0(m2.b) and
						m3.opcode=m_jmpcc and m3.regend[r0] then
					m2.a:=m.b
					m2.b:=m.b
					deletemcl(m,108)
				elsif m2.opcode in [m_inc, m_dec] and isreg0(m2.a) then
					m.opcode:=m_lea
					m.b:=mgenindex(areg:m.b.reg,offset:(m2.opcode=m_inc|1|-1))
					deletemcl(m2,120)
					redo
				elsif m2.opcode in [m_add, m_sub] and isreg0(m2.a) then
					if isconst(m2.b) and (m2.b.value in int32.minvalue..int32.maxvalue) then
						m.opcode:=m_lea
						m.b:=mgenindex(areg:m.b.reg,
							offset:(m2.opcode=m_add|m2.b.value|-m2.b.value))
						deletemcl(m2,121)
						redo
					elsif isregvar(m2.b) and m2.opcode=m_add then
						m.opcode:=m_lea
						m.b:=mgenindex(areg:m.b.reg,ireg:m2.b.reg)
						deletemcl(m2,122)
						redo
					fi
				fi
			fi

			if isreg0(m.a) and isconst(m.b) and
					 (m.b.value in int32.minvalue..int32.maxvalue) then
				if isreg0(m2.b) and m2.regend[r0] then
					m2.b:=m.b
					deletemcl(m,109)
				fi
			fi

			if m.b.mode=a_reg and m2.opcode=m_mov and m2.a.mode=a_reg and
				m.b.reg=m2.a.reg and sameoperand(m.a,m2.b) then
				deletemcl(m2,141)
			fi



			if m.b.mode=a_reg and m2.opcode=m_mov and m2.a.mode=a_reg then
				 if m.a.mode=a_mem and sameoperand(m.a, m2.b) then		!mov [MEM1],Da; mov Db,[MEM1] => mov Db,Da
					m2.b:=mgenreg(m.b.reg)
				fi
			fi

		when m_xorx then
			if isreg0(m.a) and isreg0(m.b) then
				if isreg0(m2.b) and m2.regend[r0] then
					m2.b:=mgenint(0)
					deletemcl(m,110)
				fi
			fi

		when m_lea then
			if isreg0(m.a) and m2.opcode=m_mov then
				if isregvar(m2.a) and isreg0(m2.b) and m2.regend[r0] then
					m.a:=m2.a
					deletemcl(m2,131)
				fi
			fi

		end switch

skip::
		lastmcl:=m
		m:=m2
	od
end

function isreg(mcloperand a, int reg=rnone)int=
	if not a then return 0 fi
	if not a.mode=a_reg then return 0 fi
	if reg=rnone then return 0 fi
	return reg=a.reg
end

function isreg0(mcloperand a)int=
	if not a then return 0 fi
	if a.mode=a_reg and a.reg=r0 then return 1 fi
	return 0
end

function isregvar(mcloperand a)int=
	if not a then return 0 fi
	return a.mode=a_regvar
end
function isconst(mcloperand a)int=
	if not a then return 0 fi
	if a.mode=a_imm and a.valtype=intimm_val then
		return 1
	fi
	return 0
end

proc deletemcl(ref mclrec m,int id=0)=
	[128]char str



	m.opcode:=m_deleted
end
=== ma_genss.m 30/40 ===
import clib
import mlib
import oslib
import ma_decls
import ma_lib
import ma_objdecls

import bb_decls
import bb_tables
import bb_mcldecls
import bb_support
import bb_libmcl

import bb_pclcommon

INT NCOMMENTS
INT NBLANKS
INT NDELETED

const wmask = 2x1000				!1 means 64-bit operand size
const rmask = 2x0100				!extends mod/rm reg field
const xmask = 2x0010				!extends sib index field
const bmask = 2x0001				!extends mod/rm r/m field, also sib base field

int rex
int sizeoverride					!32=>16 switch
int addroverride					!32=>16 switch
int f2override						!xmm regs
int f3override						!xmm regs

mcloperand extraparam

int currseg=0
ref dbuffer currdata				!copy of ss_idata or ss_code
ref relocrec currrelocs
int nrelocs

int instrno=2

REF MCLREC CURRMCL

global proc genss=
int index
ref mclrec m


initlib(labelno)

ss_zdatalen:=0
ss_zdata:=buffercreate()
ss_idata:=buffercreate()
ss_code:=buffercreate()
ss_idatarelocs:=nil
ss_coderelocs:=nil
ss_nsymbols:=0

switchseg(code_seg)

alineno:=9999
extraparam:=nil

fixregvar()

m:=mccode
index:=0


while m do
	mlineno:=m.pos
	doinstr(m,++index)
	m:=m^.nextmcl
od

switchseg(0)					!update ss_currrelocs etc

if bufferlength(ss_zdata) then
	axerror("Zdata contains code or data")
fi


end

proc doinstr(ref mclrec m,int index)=
mcloperand a,b
ref pstrec d,e
int x,offset,shortjmp,n

buffercheck(currdata)

rex:=sizeoverride:=addroverride:=f2override:=f3override:=0

a:=m^.a
b:=m^.b

++instrno
alineno:=instrno



CURRMCL:=M


switch m^.opcode
when m_procstart then
when m_procend then
when m_define then

when m_definereg then
when m_deleted then
++NDELETED

when m_labelname then
	case a.valtype
	when stringimm_val then
	when def_val then

		d:=a.def

		d^.reftype:=back_ref
		d^.segment:=currseg
		d^.offset:=getcurrdatalen(6)

		if d.isglobal then
			getstindex(d)
		fi

		dofwdrefs(d)
	esac

when m_label then
	d:=labeldeftable[a.labelno]

	d^.reftype:=back_ref
	d^.segment:=currseg
	d^.offset:=getcurrdatalen(6)
	dofwdrefs(d)

when m_call then
	do_call(a)

when m_jmp then
	do_jmp(a,m)

when m_jmpcc then
	d:=getdef(a,1)
	offset:=getrel32(d,getcurrdatalen(7)+1)
	if offset<0 then			!backjump
		if offset<-126 then
			genbyte(0x0F)
			genbyte(0x80+m.cond)
			gendword(offset-4)
		else
			genbyte(0x70+m.cond)
			genbyte(offset)
		fi
	else
		shortjmp:=checkshortjump(m,d)
		if not shortjmp then
			genbyte(0x0F)
			genbyte(0x80+m.cond)
			genrel32(a)
		else
			genbyte(0x70+m.cond)
			genrel8(a)
		fi
	fi

when m_db then
	genopnd(a,1)
when m_dw then
	genopnd(a,2)
when m_dd then
	genopnd(a,4)
when m_dq then
	genopnd(a,8)

when m_ddoffset then
	genrel32(a)

when m_segment then
	switchseg(a^.value)

when m_csegment then
	switchseg(code_seg)
when m_isegment then
	switchseg(idata_seg)
when m_zsegment then
	switchseg(zdata_seg)

when m_nop, m_halt then
	genbyte(mclcodes[m^.opcode])

when m_cbw then
	genbyte(0x66)
	genbyte(0x98)

when m_cwd then
	genbyte(0x66)
	genbyte(0x99)

when m_cdq then
	genbyte(0x99)

when m_cqo then
	genbyte(0x48)
	genbyte(0x99)

when m_ret then
	genbyte(0xC3)

when m_retn then
	if a^.mode<>a_imm then axerror("retn?") fi
	genbyte(0xC2)
	genword(a^.value)

when m_push then
	do_push(a)

when m_pop then
	do_pop(a)

when m_inc, m_dec then
	do_inc(a,mclcodes[m^.opcode])

when m_neg, m_notx, m_mul, m_imul, m_div, m_idiv then
	do_neg(a,mclcodes[m^.opcode])

when m_add, m_sub, m_andx, m_orx, m_xorx, m_adc, m_sbb, m_cmp then
	do_arith(a,b, mclcodes[m^.opcode])

when m_mov then
	do_mov(a,b)
when m_lea then
	do_lea(a,b)

when m_movsx then
	do_movsx(a,b,0xBE)

when m_movzx then
	do_movsx(a,b,0xB6)

when m_movsxd then
	do_movsxd(a,b)

when m_xchg then
	do_exch(a,b)

when m_imul2 then
	do_imul2(a,b)


when m_resb, m_resw, m_resd, m_resq then
	if a^.mode=a_imm then
		n:=a^.value*mclcodes[m^.opcode]
		case currseg
		when code_seg then
			to n do genbyte(0x90) od
		when idata_seg then
			to n do genbyte(0) od
		else
			ss_zdatalen+:=n
		esac
	
	else
		axerror("resb?")
	fi

when m_align then
	if a^.mode=a_imm then
		x:=a^.value
		if x<1 or x>16384 then axerror("align2") fi
		if currseg<>zdata_seg then
			while bufferlength(currdata) rem x do genbyte((currseg=code_seg|0x90|0)) od
		else
			while ss_zdatalen rem x do	++ss_zdatalen od
		fi
	else
		axerror("align?")
	fi

when m_shl,m_shr,m_sar,m_rol,m_ror,m_rcl,m_rcr then
	do_shift(a,b,mclcodes[m^.opcode])

when m_test then
	do_test(a,b)

when m_loopcx, m_loopz, m_loopnz then
	do_loop(a,mclcodes[m^.opcode])

when m_jecxz then
	do_jcxz(a,4)

when m_jrcxz then
	do_jcxz(a,8)

when m_xlat then
	genbyte(0xD7)

when m_setcc then
	do_setcc(m.cond,a)

when m_movd then
	do_movxmm(a,b,4)

when m_movq then
	do_movxmm(a,b,8)

when m_addss, m_subss, m_mulss, m_divss, m_sqrtss, m_minss, m_maxss then
	do_arithxmm(a,b,0xF3,mclcodes[m^.opcode])

when m_addsd, m_subsd, m_mulsd, m_divsd, m_sqrtsd, m_minsd, m_maxsd then
	do_arithxmm(a,b,0xF2,mclcodes[m^.opcode])

when m_andps,m_xorps then
	do_logicxmm(a,b,mclcodes[m^.opcode],4)

when m_andpd,m_xorpd,m_pand,m_pxor then
	do_logicxmm(a,b,mclcodes[m^.opcode],8)


when m_comiss then
	do_arithxmm(a,b,0,0x2F)

when m_comisd then
	do_arithxmm(a,b,0x66,0x2F)

when m_cvtss2sd then
	do_convertfloat(a,b,0xF3)

when m_cvtsd2ss then
	do_convertfloat(a,b,0xF2)

when m_cvtss2si then
	do_fix(a,b,0xF3,0x2D)

when m_cvtsd2si then
	do_fix(a,b,0xF2,0x2D)

when m_cvttss2si then
	do_fix(a,b,0xF3,0x2C)

when m_cvttsd2si then
	do_fix(a,b,0xF2,0x2C)

when m_cvtsi2ss then
	do_float(a,b,0xF3)

when m_cvtsi2sd then
	do_float(a,b,0xF2)

when m_param then
	extraparam:=a

when m_cmovcc then
	do_cmovcc(m.cond, a,b)

when m_fsqrt,m_fsin,m_fcos,m_fsincos,m_fptan, m_fpatan,m_fabs,m_fchs then
	genbyte(0xD9)
	genbyte(mclcodes[m^.opcode])

when m_fld, m_fst, m_fstp then
	do_fmem(a,1,mclcodes[m^.opcode])

when m_fild, m_fist, m_fistp then
	do_fmem(a,0,mclcodes[m^.opcode])

when m_fadd, m_fsub, m_fmul, m_fdiv then
	genbyte(0xDE)
	genbyte(mclcodes[m^.opcode])

when m_cmpsb then
	genbyte(0xA6)

when m_cmpsw then
	genbyte(0x66)
	genbyte(0xA7)
when m_cmpsd then
	genbyte(0xA7)
when m_cmpsq then
	genbyte(0x48)
	genbyte(0xA7)

when m_rdtsc then		!single opcodes that need a 0x0F prefix
	genbyte(0x0F)
	genbyte(mclcodes[m^.opcode])

when m_movdqa, m_movdqu then
	do_movdqx(a,b,mclcodes[m^.opcode])

when m_finit then
	genbyte(0xDB)
	genbyte(0xE3)

when m_fldz, m_fld1, m_fldpi, m_fld2t, m_fld2e, m_fldlg2, m_fldln2 then
	genbyte(0xD9)
	genbyte(mclcodes[m^.opcode])

when m_popcnt then
	do_popcnt(a,b)

when m_bsf, m_bsr then
	do_bsf(a,b,mclcodes[m.opcode])

when m_comment then
	++NCOMMENTS
when m_blank then
	++NBLANKS
else
	println "*** Can't do opcode",mclnames[m^.opcode],"line",alineno,=M.OPCODE,=M_HALT
CPL
CPL
AXERROR("STOPPING")
endswitch

end

proc genbyte(int x)=
currdata^.pcurr++^:=x
end

proc genword(int x)=
addword(currdata,x)
end

proc gendword(int x)=
adddword(currdata,x)
end

proc genqword(int64 x)=
addqword(currdata,x)
end

proc genopnd(mcloperand a,int size=0)=
ref char s
int64 x
int length

if size=0 then size:=a^.size fi

case a.valtype
when stringimm_val then
	s:=a^.svalue
	length:=strlen(s)
	if length>100 then
		buffercheck(currdata,max(1024,length+1))
	fi
	while s^ do
		genbyte(s++^)
	od
	return
WHEN NAME_VAL THEN
CPL "GENSS/NAME OPND"
esac

if getdef(a) and size<=2 then
	axerror("8/16-BIT RELOC")
fi


case size
when 1 then
	genbyte(a^.value)
when 2 then
	genword(a^.value)
when 4 then
	case a.valtype
	when intimm_val then
		gendword(a.value)
	when realimm_val then
real32 x32
x32:=a.xvalue
		gendword(int32@(x32))
	when realmem_val then
CPL "		OPND/REALMEM4"
	when stringimm_val then
CPL "		OPND/STRINGIMM4"
	when def_val,label_val then
		genabs32(a)
	when name_val then
CPL "		OPND/NAME4"
	else
		cpl valtypenames[a.valtype]
		axerror("OPND/4/VALTYPE?")
	esac

when 8 then
	case a.valtype
	when intimm_val then
		genqword(a.value)
	when realimm_val then
		genqword(int64@(a.xvalue))
	when realmem_val then
CPL "		OPND/REALMEM8",ALINENO
	when stringimm_val then
CPL "		OPND/STRINGIMM8"
	when def_val,label_val then

		genabs64(a)
	when name_val then
CPL "		OPND/NAME8"
	else
		cpl valtypenames[a.valtype]
		axerror("OPND/8/VALTYPE?")
	esac

esac
end

proc addrelocitem(int reloctype, ref pstrec d)=
ref relocrec r
int stindex, adjust


stindex:=getstindex(d)

adjust:=4
if reloctype=addr64_rel then adjust:=8 fi

r:=pcm_alloc(relocrec.bytes)
r^.nextreloc:=currrelocs
r^.reloctype:=reloctype
r^.offset:=getcurrdatalen(1)-adjust
r^.stindex:=stindex

++nrelocs
currrelocs:=r
end

function getstindex(ref pstrec d)int=

if d^.stindex=0 then
	if ss_nsymbols>=ss_symboltablesize then
		extendsymboltable()
	fi
	d^.stindex:=++ss_nsymbols
	ss_symboltable^[d^.stindex]:=d


	if d.segment=0 then
		if d.id=dllproc_name then
			d.segment:=code_seg
		fi
	fi


fi
return d^.stindex
end

proc genrel32(mcloperand a)=
ref pstrec d

d:=getdef(a)

if d=nil then				!constant
	gendword(a^.value)
	return
fi


case d^.reftype
when back_ref then
	if d^.segment<>currseg then
		axerror("Rel label across segments")			!might be Ok if treated as external?
	fi
	gendword(d^.offset-(getcurrdatalen(2)+4)+a.offset)
when fwd_ref then
	d^.fwdrefs:=addfwdref(d^.fwdrefs,getcurrdatalen(3),rel32_rel)
	gendword(a.offset)
else								!external symbol

	gendword(a.offset)		!this is probably just zero
	addrelocitem(rel32_rel,d)
esac
end

function getdef(mcloperand a,int dneeded=0)ref pstrec =
	ref pstrec d

	if a.mode in [a_mem,a_imm] then
		case a.valtype
		when label_val then
			return labeldeftable[a.labelno]
		when def_val then
			d:=a.def
			if d.reftype=0 then
				if d.id<>dllproc_name then
					d.reftype:=fwd_ref
				fi
			fi

			return d
		esac
	fi
	if dneeded then				!must return a non-nil value
		println opndnames_ma[a.mode],valtypenames[a.valtype]
		axerror("getdef/no def")
	fi
	return nil
end

proc genabs32(mcloperand a)=
ref pstrec d

d:=getdef(a,1)


case d^.reftype
when back_ref then

	gendword(d^.offset+a.offset)
	addrelocitem(addr32_rel,d)

when fwd_ref then
	d^.fwdrefs:=addfwdref(d^.fwdrefs,getcurrdatalen(4),addr32_rel,currseg)
	if d.id in [frame_name,param_name] then
		gendword(d.offset+a.offset)
	else
		gendword(a.offset)
		addrelocitem(addr32_rel,d)
	fi

else								!external symbol
	gendword(a.offset)					!this is probably just zero
	addrelocitem(addr32_rel,d)
esac
end

proc genabs64(mcloperand a)=
ref pstrec d

d:=getdef(a,1)


case d^.reftype
when back_ref then
	genqword(d^.offset+a.offset)
	addrelocitem(addr64_rel,d)

when fwd_ref then
	d^.fwdrefs:=addfwdref(d^.fwdrefs,getcurrdatalen(5),addr64_rel,currseg)
	if d.id in [frame_name,param_name] then
		genqword(d.offset+a.offset)
	else
		genqword(a.offset)
		addrelocitem(addr64_rel,d)
	fi

else								!external symbol
	genqword(a.offset)				!this is probably just zero
	addrelocitem(addr64_rel,d)
esac
end

function getrel32(ref pstrec d,int offset)int=


if d^.reftype=back_ref then					!defined earlier in this segment
	if d^.segment<>currseg then
		axerror("Rel label across segments2")
	fi
	return d^.offset-(offset+1)
else
	return int32.maxvalue
fi
end

proc dofwdrefs(ref pstrec d)=
ref fwdrec f
int offset, seg
ref byte p8
ref int32 p32
ref int64 p64
ref dbuffer data


if d^.fwdrefs=nil then return fi

f:=d^.fwdrefs

while f do
	offset:=f^.offset

	case f^.reltype
	when rel32_rel then
		p32:=bufferelemptr(currdata,offset)
		p32^:=d^.offset-offset-4

	when addr32_rel,addr64_rel then
		case f^.seg
		when code_seg then data:=ss_code
		when zdata_seg then axerror("Fwd ref in zdata")
		when idata_seg then data:=ss_idata
		esac

		p32:=bufferelemptr(data,offset)
		if f^.reltype=addr32_rel then
			p32^:=p32^+d^.offset
		else
			p64:=cast(p32)
			p64^:=p64^+d^.offset
		fi
	when rel8_rel then
		p8:=bufferelemptr(currdata,offset)
		p8^:=d^.offset-offset-1
	else
CPL RELOCNAMES[F^.RELTYPE]
		GERROR("DOFWDREFS/CAN'T DO RELTYPE")
	esac

	f:=f^.nextfwd

od
end

proc genrex=
	if sizeoverride then
		genbyte(0x66)
	fi
	if addroverride then
		genbyte(0x67)
	fi
	if rex then
		if rex<0x40 then
			genbyte(0x40+rex)
		else
			genbyte(rex)
		fi
	fi
end

function isbytesized(int64 x)int=
return -128<=x<=127
end

function isdwordsized(int64 x)int=
return int32.minvalue<=x<=int32.maxvalue
end

proc do_push(mcloperand a)=
int code,am

	case a^.mode
	when a_reg then
		if a^.size<>8 then axerror("pushreg not 64-bit") fi
		code:=regcodes[a^.reg]
		if code>=8 then
			rex :=bmask
			code iand:=7
		fi
		genrex()
		genbyte(0x50+code)

	when a_imm then
		if getdef(a) then
			genbyte(0x68)
			genopnd(a,4)
		elsif isbytesized(a^.value) then
			genbyte(0x6A)
			genbyte(a^.value)
		elsif isdwordsized(a^.value) then
			genbyte(0x68)
			gendword(a^.value)
		else
			axerror("push imm value too large")
		fi

	when a_mem then
		if a^.size<>8 then axerror("push not 64-bit") fi
		am:=genrm(a,6)
		genrex()
		genbyte(0xFF)
		genamode(a,am)
	else
		axerror("push opnd?")
	esac
end

proc do_pop(mcloperand a)=
int code, am

	case a^.mode
	when a_reg then
		if a^.size<>8 then axerror("popreg not 64-bit") fi
		code:=regcodes[a^.reg]
		if code>=8 then
			rex :=bmask
			code iand:=7
		fi
		genrex()
		genbyte(0x58+code)

	when a_mem then
		if a^.size<>8 then axerror("pop not 64-bit") fi
		am:=genrm(a,0)
		genrex()
		genbyte(0x8F)
		genamode(a,am)
	else
		axerror("pop opnd?")
	esac
end

proc do_inc(mcloperand a,int code)=
int opc, am

	opc:=(a^.size=1|0xFE|0xFF)

	case a^.mode
	when a_reg, a_mem then
		am:=genrm(a,code)
		checkhighreg(a)
		setopsize(a)
		genrex()
		genbyte(opc)
		genamode(a,am)

	else
		axerror("inc/opnd?")
	esac
end

proc do_neg(mcloperand a,int code)=
int opc, am

	opc:=(a^.size=1|0xF6|0xF7)

	case a^.mode
	when a_reg, a_mem then
		am:=genrm(a,code)
		checkhighreg(a)
		setopsize(a)
		genrex()
		genbyte(opc)
		genamode(a,am)

	else
		axerror("neg/div/etc opnd?")
	esac
end

proc genamode(mcloperand a,int am)=
int sib,mode,dispsize,offset
ref pstrec d

sib:=am>>16

mode:=(am>>8)iand 255
dispsize:=am iand 255

genbyte(mode)			!modrm byte

if sib>=0 then		!sib byte
	genbyte(sib)
fi


case dispsize			!disp bytes
when 0 then
when 1 then
	getdispsize(a,offset)
	genbyte(offset)
when 4 then

	case a.mode
	when a_mem then

		case a.valtype
		when def_val, label_val then
			genabs32(a)
		when no_val then
			getdispsize(a,offset)
			gendword(offset)
		else
			axerror("genam/3")
		esac
	else
CPL OPNDNAMES_MA[A.MODE]
		axerror("GENAMODE/MODE?")
	esac
else
	axerror("genamode size 2/8")
esac
end

function makemodrm(int mode,opc,rm)int=
	return mode<<6+opc<<3+rm
end

proc setopsize(mcloperand a)=
case a^.size
when 1 then			!assume set via specific opcodes
when 2 then			!override default 4 bytes
	sizeoverride:=1
when 8 then			!override default 4 bytes
    rex ior:=wmask
when 4 then			!assume 4 bytes is default
else
	axerror("Operand size not set")
esac
end

proc setaddrsize(mcloperand a)=
if a^.mode=a_mem and a^.addrsize=4 then
	addroverride:=1
fi
end

function getdispsize(mcloperand a, int &offset)int=
	ref pstrec d

	d:=getdef(a)
	offset:=a.offset

	if d then
		if d.id in [frame_name,param_name] then
			offset+:=d.offset
		else
			return 4
		fi
	fi

	if offset then
		return (isbytesized(offset)|1|4)
	else
		return 0
	fi
end

function genrm(mcloperand a,int opc)int=
	static []int scaletable=( 0, 1, 0, 2, 0, 0, 0, 3)
	int mode, rm, scale, dispsize, sib, index, base
	int reg, regix, code, offset

	mode:=rm:=0				!modrm is (mode, x, rm), of (2,3,3) bits
	scale:=0				!0=modrm only; 1/2/4/8 means sib used
	dispsize:=0
	sib:=-1

	if a^.mode=a_mem and a^.addrsize=4 then
		addroverride:=1
	fi

	case a^.mode
	when a_reg then			!modrm can only ref to a single register
		code:=getregcodeb(a^.reg)
		return makeam(makemodrm(3,opc,code), sib, dispsize)

	when a_mem then

	when a_xreg then
		code:=getregcodebx(a^.reg)
		return makeam(makemodrm(3,opc,code), sib, dispsize)		!NEW

	else
		axerror("genrm not mem")
	esac

	reg:=a^.reg
	regix:=a^.regix

	if reg=regix=0 then						!address only
		mode:=0
		rm:=4
		scale:=1
		index:=4
		base:=5
		dispsize:=4

	elsif a^.scale<=1 and regix=0 then			!simple address mode (no sib)
		dispsize:=getdispsize(a,offset)
		if dispsize then
			mode:=(dispsize=1|1|2)
		fi

		rm:=regcodes[reg]

		if rm<>4 and rm<>12 then
			base:=rm
			if (rm=5 or rm=13) and dispsize=0 then
				mode:=1; dispsize:=1
			fi
			index:=0
		else
			index:=4				!means no index
			base:=rm
			scale:=1				!force sib

		fi
	elsif regix and reg=0 then
		dispsize:=4
		mode:=0
		rm:=4
		scale:=(a^.scale|a^.scale|1)
		base:=5
		index:=regcodes[regix]
		if regix=rstack then axerror("Scaled rstack?") fi

	else										!assume regix used; optional reg and disp
		dispsize:=getdispsize(a,offset)
		if dispsize then
			mode:=(dispsize=1|1|2)
		fi
		rm:=4


		scale:=(a^.scale|a^.scale|1)
		if reg=0 then
			base:=5
		else
			if reg in [rframe,r7] and dispsize=0 then
				mode:=1; dispsize:=1
			fi
			base:=regcodes[reg]
		fi

		if regix=0 then
			index:=4
		else
			index:=regcodes[regix]
		fi

		if regix and not reg then
			dispsize:=4
		fi

		if regix=rstack and scale>1 then axerror("Can't scale rstack") fi

	fi

	if index>=8 then rex ior:= xmask; index iand:=7 fi
	if base>=8  then rex ior:= bmask; base  iand:=7 fi

	if scale then
		sib:=scaletable[scale]<<6 + index<<3 + base
	fi
	rm iand:=7

	return makeam(makemodrm(mode:mode,opc:opc,rm:rm), sib, dispsize)
end

proc genrmbyte(int mode,opc,rm)=
	genbyte(mode<<6+opc<<3+rm)
end

function makeam(int m,s,d)int=
return s<<16+m<<8+d
end

proc do_arith(mcloperand a,b,int code)=
int am, regcode, opc, dispsize
int64 x

case a^.mode
when a_reg,a_regvar then
	case b^.mode
	when a_reg,a_regvar, a_mem then
		regcode:=getregcoder(a^.reg)
		am:=genrm(b,regcode)
		checkhighreg(a)
		checkhighreg(b)
		setopsize(a)
		opc:=code<<3 ior (a^.size=1|0x02|0x03)
		genrex()
		genbyte(opc)
		genamode(b,am)

	when a_imm then
doregimm::
		if getdef(b) then
			if code<0 or code>7 then axerror("non-add arith/label") fi
			if a^.size<4 then axerror("add imm/size") fi
			am:=genrm(a,code)
			setopsize(a)
			genrex()
			genbyte(0x81)
			genamode(a,am)
			genopnd(b,4)
			return

		fi

		x:=b^.value
		dispsize:=1
		if a^.size=1 then
			opc:=0x80
		elsif -128<=x<=127 then
			opc:=0x83
		else
			unless -0x8000'0000 <= x <= 0xFFFF'FFFF then axerror("3:exceeding word32 value") end
			opc:=0x81
			dispsize:=(a^.size=2|2|4)
		fi

		am:=genrm(a,code)
		checkhighreg(a)
		setopsize(a)
		genrex()
		genbyte(opc)
		genamode(a,am)
		case dispsize
		when 1 then genbyte(x)
		when 2 then genword(x)
		when 4 then gendword(x)
		esac

	else
		axerror("ADD reg,???")
	esac

when a_mem then
	case b^.mode
	when a_reg then
		regcode:=getregcoder(b^.reg)
		am:=genrm(a,regcode)
		checkhighreg(b)
		setopsize(b)
		opc:=code<<3 ior (b^.size=1|0x00|0x01)
		genrex()
		genbyte(opc)
		genamode(a,am)

	when a_imm then
		go to doregimm
	else
		axerror("ADD mem,???")
	esac

else
CPL OPNDNAMES_MA[A.MODE]
	axerror("Can't add to this opnd")
esac
end

proc do_mov(mcloperand a,b)=
int regcode, am
int64 value

case a^.mode
when a_reg then
	case b^.mode
	when a_reg, a_mem then
		if a^.size<>b^.size and b^.size then
CPL =A.SIZE, B.SIZE
			axerror("1:Opnd size mismatch")
		fi
		checkhighreg(a)
		checkhighreg(b)
		regcode:=getregcoder(a^.reg)
		am:=genrm(b,regcode)

		setopsize(a)
		genrex()
		genbyte((a^.size=1|0x8A|0x8B))
		genamode(b,am)

	when a_imm then
		value:=b^.value
		regcode:=getregcodeb(a^.reg)
		if getdef(b) and a^.size<=2 then axerror("mov imm?") fi
		case a^.size
		when 1 then
			checkhighreg(a)
			case a^.reg
			when r5,r3,r14,r15 then
				rex ior:=0x40
			esac
			unless -128<=value<=255 then axerror("exceeding byte value") end
			genrex()
			genbyte(0xB0+regcode)
			genbyte(value)

		when 2 then
			unless -32768<=value<=65535 then axerror("exceeding word16 value") end
			genbyte(0x66)
			genrex()
			genbyte(0xB8+regcode)
			genword(value)
		when 4 then
			if getdef(b) then
				genrex()
				genbyte(0xB8+regcode)
				genopnd(b,4)
			else
				unless -0x8000'0000<=value<=u32(0xFFFF'FFFF) then
CPL value,ref void(value)
					axerror("1:exceeding word32 value")
				end
doreg32::
				genrex()
				genbyte(0xB8+regcode)
				gendword(value)
			fi

		else							!assum 8 bytes
			if getdef(b) then
				rex ior:=wmask
				genrex()
				genbyte(0xB8+regcode)
				genopnd(b,8)
			else
				if value>=0 and value<=0xFFFF'FFFF then
					goto doreg32			!load 32-bit value which is zero-extended to 64
				fi
				rex ior:=wmask
				genrex()
				genbyte(0xB8+regcode)
				genqword(value)
			fi

		esac

	else
		axerror("MOV REG/??")
	esac
when a_mem then
	case b^.mode
	when a_reg then
		if a^.size<>b^.size and a^.size then
			axerror("2:Opnd size mismatch")
		fi
		regcode:=getregcoder(b^.reg)
		checkhighreg(b)
		am:=genrm(a,regcode)
		setopsize(b)
		genrex()
		genbyte((b^.size=1|0x88|0x89))
		genamode(a,am)

	when a_imm then
		value:=b^.value
		am:=genrm(a,0)
		if getdef(b) and a^.size<=2 then axerror("mov imm?") fi

		if a^.size=0 then a^.size:=1 fi

		case a^.size
		when 0,1 then
			unless -128<=value<=255 then axerror("exceeding byte value") end

			setopsize(a)
			genrex()
			genbyte(0xC6)
			genamode(a,am)
			genbyte(value)

		when 2 then
			unless -32768<=value<=65535 then axerror("exceeding word16 value") end
			setopsize(a)
			genrex()
			genbyte(0xC7)
			genamode(a,am)
			genword(value)
		when 4,8 then
			if not getdef(b) then
				unless -0x8000'0000<=value<=0xFFFF'FFFF then axerror("2:exceeding word32 value") end
			fi
			setopsize(a)
			genrex()
			genbyte(0xC7)
			genamode(a,am)
			genopnd(b,4)
		esac

	else
CPL OPNDNAMES_MA[A.MODE]
CPL OPNDNAMES_MA[B.MODE]
		axerror("MOV MEM/?")
	esac
else
	axerror("MOV ?/..")
esac
end

function getregcoder(int reg)int=
int regcode

regcode:=regcodes[reg]
if regcode>=8 then
	regcode-:=8
	rex ior:=rmask
fi
return regcode
end

function getregcodeb(int reg)int=
int regcode

regcode:=regcodes[reg]
if regcode>=8 then
	regcode-:=8
	rex ior:=bmask
fi
return regcode
end

function getregcodebx(int reg)int=

int regcode

regcode:=reg-1
if regcode>=8 then
	regcode-:=8
	rex ior:=bmask
fi
return regcode
end

function getregcoderx(int reg)int=
int regcode

regcode:=reg-1
if regcode>=8 then
	regcode-:=8
	rex ior:=rmask
fi
return regcode
end


proc do_lea(mcloperand a,b)=
int regcode, am

unless a^.mode=a_reg and b^.mode=a_mem then
	axerror("LEA not reg/mem")
end

if a^.size<4 then axerror("LEA size error") fi
regcode:=getregcoder(a^.reg)

am:=genrm(b,regcode)
setopsize(a)
genrex()
genbyte(0x8D)
genamode(b,am)

end

proc do_movsx(mcloperand a,b,int opc)=
	int am, regcode

	if a^.mode<>a_reg then axerror("movsx not reg") fi

	if a^.size=8 and b^.size=4 then
		if opc=0xBE then
			do_movsxd(a,b)
		else						!movsx 4->8 bytes, do normal move 4->4
			a:=regtable[a^.reg,4]
			do_mov(a,b)
		fi
		return
	fi

	if a^.size=1 or a^.size<=b^.size then axerror("movsx size error") fi

	if opc=0xB6 and b^.size=4 then axerror("movsx 4=>8 bytes?") fi

	case b^.mode
	when a_reg then
	when a_mem then
		if b^.size=0 then axerror("movsx need size prefix") fi
		if b^.size=8 then axerror("movsx size 8") fi
	else
		axerror("movsx not reg/mem")
	esac

	regcode:=getregcoder(a^.reg)

	am:=genrm(b,regcode)
	setopsize(a)
	checkhighreg(b)
	genrex()
	genbyte(0x0F)
	genbyte((b^.size=1|opc|opc+1))
	genamode(b,am)
end

proc checkhighreg(mcloperand a)=
if a^.mode=a_reg then
	case a^.reg
	when r5,r3,r14,r15 then
		rex ior:=0x40
	esac
fi
end

proc do_exch(mcloperand a,b)=
int regcode, am

if a^.mode=a_reg and b^.mode=a_reg and (a^.reg=r0 or b^.reg=r0) and a^.size<>1 then		!simple r0/reg
	if a^.reg<>r0 then				!get a to be r0
		swap(a,b)
	fi
	if a^.size<>b^.size then axerror("exch size") fi

	setopsize(a)
	regcode:=getregcodeb(b^.reg)
	genrex()
	genbyte(0x90+regcode)
	return
fi

if a^.mode=a_mem then swap(a,b) fi

unless a^.mode=a_reg and (b^.mode=a_reg or b^.mode=a_mem) then axerror("exch opnds") end
if b^.size=0 and b^.mode=a_mem then b^.size:=a^.size fi
if a^.size<>b^.size then axerror("exch size") fi

if a^.size=1 then
	checkhighreg(a)
	checkhighreg(b)
fi

regcode:=getregcoder(a^.reg)

am:=genrm(b,regcode)
setopsize(a)
genrex()
genbyte((a^.size=1|0x86|0x87))
genamode(b,am)

end

proc do_movsxd(mcloperand a,b)=
int regcode, am

if b^.mode=a_mem and b^.size=0 then b^.size:=4 fi

if a^.size<>8 or b^.size>4 then axerror("movsxd size") fi

if a^.mode<>a_reg or (b^.mode<>a_reg and b^.mode<>a_mem) then
	axerror("movsxd opnds")
fi

regcode:=getregcoder(a^.reg)
am:=genrm(b,regcode)

setopsize(a)
genrex()
genbyte(0x63)
genamode(b,am)

end

proc do_imul2(mcloperand a,b)=
int regcode, am, opc
int64 value

if a^.mode<>a_reg then
	axerror("imul2 opnds")
fi
if b^.size=0 then b^.size:=a^.size fi
if a^.size=1 then axerror("imul2 byte") fi

case b^.mode
when a_reg,a_mem then
	if a^.size<>b^.size then axerror("imul2 size") fi
	regcode:=getregcoder(a^.reg)
	am:=genrm(b,regcode)

	setopsize(a)
	genrex()
	genbyte(0x0F)
	genbyte(0xAF)
	genamode(b,am)

when a_imm then						!imul reg1,reg2,imm but implemented as imul reg,imm
	if getdef(b) then axerror("mul/label") fi
	value:=b^.value
	regcode:=getregcoder(a^.reg)		!same reg used in two places
	regcode:=getregcodeb(a^.reg)
	opc:=0xC0+regcode<<3+regcode
	setopsize(a)
	genrex()

	if -128<=value<=127 then
		genbyte(0x6B)
		genbyte(opc)
		genbyte(value)
	elsif a^.size=2 then
		genbyte(0x69)
		genbyte(opc)
		genword(value)
	else
		genbyte(0x69)
		genbyte(opc)
		gendword(value)
	fi
else
	axerror("imul2 opnds")
esac
end

proc do_imul3(mcloperand a,b,c)=
int64 value
int regcode1, regcode2, opc

if a^.mode<>a_reg or b^.mode<>a_reg then
	axerror("imul3 opnds")
fi
if a^.size=1 then axerror("imul3 byte") fi
if c^.mode<>a_imm then axerror("imul3 not imm") fi

value:=c^.value
regcode1:=getregcoder(a^.reg)
regcode2:=getregcodeb(b^.reg)
opc:=0xC0+regcode1<<3+regcode2
setopsize(a)
genrex()

if -128<=value<=127 then
	genbyte(0x6B)
	genbyte(opc)
	genbyte(value)
elsif a^.size=2 then
	genbyte(0x69)
	genbyte(opc)
	genword(value)
else
	genbyte(0x69)
	genbyte(opc)
	gendword(value)
fi
end

proc do_shift(mcloperand a,b,int opc)=
int am, w

if a^.mode<>a_reg and a^.mode<>a_mem then axerror("shift opnds1?") fi

am:=genrm(a,opc)
checkhighreg(a)
setopsize(a)
genrex()
w:=(a^.size=1|0|1)

case b^.mode
when a_imm then
	if getdef(b) then axerror("shift/label") fi
	if b^.value=1 then
		genbyte(0xD0+w)
		genamode(a,am)
	else
		genbyte(0xC0+w)
		genamode(a,am)
		genbyte(b^.value)
	fi
when a_reg then
	if b^.reg<>r10 or b^.size<>1 then axerror("cl or b10 needed") fi
	genbyte(0xD2+w)
	genamode(a,am)

else
	axerror("shift opnds2?")
esac
end

proc do_test(mcloperand a,b)=
int64 value
int opc, am, regcode

if a^.mode=a_reg and a^.reg=r0 and b^.mode=a_imm then
	value:=b^.value
	case a^.size
	when 1 then
		genbyte(0xA8)
		genbyte(value)
	when 2 then
		genbyte(0x66)
		genbyte(0xA9)
		genword(value)
	when 4 then
		genbyte(0xA9)
		gendword(value)
	else
		genbyte(0x48)
		genbyte(0xA9)
		gendword(value)
	esac

elsif (a^.mode=a_reg or a^.mode=a_mem) and b^.mode=a_imm then
	opc:=(a^.size=1|0xF6|0xF7)
	value:=b^.value

	am:=genrm(a,0)
	checkhighreg(a)
	setopsize(a)
	genrex()
	genbyte(opc)
	genamode(a,am)
	case a^.size
	when 1 then
		genbyte(value)
	when 2 then
		genword(value)
	else
		gendword(value)
	esac

elsif a^.mode=a_reg and (b^.mode=a_reg or b^.mode=a_mem) then
doregmem::
	regcode:=getregcoder(a^.reg)
	am:=genrm(b,regcode)
	checkhighreg(a)
	checkhighreg(b)
	setopsize(a)
	genrex()
	genbyte((a^.size=1|0x84|0x85))
	genamode(b,am)

elsif a^.mode=a_mem and b^.mode=a_reg then
	swap(a,b)
	goto doregmem
else
	axerror("test opnds")
fi

end

proc do_loop(mcloperand a,int opc)=
int offset

offset:=getrel32(getdef(a,1),getcurrdatalen(9)+1)
if offset<0 then			!backjump
	if offset<-126 then
		axerror("loop jmp out of range")
	fi
	genbyte(opc)
	genbyte(offset)
else
	axerror("Can't do loopxx fwd jump")
fi
end

proc do_jcxz(mcloperand a,int opsize)=
int offset

offset:=getrel32(getdef(a,1),getcurrdatalen(10)+1)
if offset<0 then			!backjump
	if offset<-126 then
		axerror("jcxz jmp out of range")
	fi
	if opsize=4 then genbyte(0x67) fi
	genbyte(0xE3)
	genbyte(offset)
else
	axerror("Can't do jcxz fwd jump")
fi
end

proc do_setcc(int cond, mcloperand a)=
int am

if (a^.mode<>a_reg and a^.reg<>a_mem) or a^.size>1 then axerror("setcc opnd/size") fi

am:=genrm(a,0)
checkhighreg(a)
genrex()
genrex()
genbyte(0x0F)
genbyte(0x90+cond)
genamode(a,am)
end

proc do_movxmm(mcloperand a,b,int size)=
int am, regcode, regcode1, regcode2


case a^.mode
when a_reg then
	case b^.mode
	when a_xreg then
		if a^.size<>size then axerror("1:movdq size") fi


		regcode:=getregcoderx(b^.reg)
		am:=genrm(a,regcode)
		setopsize(a)
		genbyte(0x66)
		genrex()
		genbyte(0x0F)
		genbyte(0x7E)
		genamode(b,am)

	else
		axerror("movdq reg,?")
	esac
when a_xreg then
	case b^.mode
	when a_reg then

		if b^.size<>size then axerror("3:movdq size") fi
		regcode:=getregcoderx(a^.reg)
		am:=genrm(b,regcode)
		setopsize(b)
		genbyte(0x66)
		genrex()
		genbyte(0x0F)
		genbyte(0x6E)
		genamode(a,am)

	when a_xreg then
		regcode1:=getregcoderx(a^.reg)
		regcode2:=getregcodebx(b^.reg)
		genbyte(0xF3)
		genrex()
		genbyte(0x0F)
		genbyte(0x7E)
		genbyte(0xC0+regcode1<<3+regcode2)

	when a_mem then
		if b^.size and b^.size<>size then axerror("4:movdq size") fi
		regcode:=getregcoderx(a^.reg)
		am:=genrm(b,regcode)
		if size=4 then
			genbyte(0x66)
			genrex()
			genbyte(0x0F)
			genbyte(0x6E)
		else
			genbyte(0xF3)
			genrex()
			genbyte(0x0F)
			genbyte(0x7E)
		fi
		genamode(b,am)

	else
		axerror("movdq xreg,?")
	esac
when a_mem then
	case b^.mode
	when a_xreg then
		if a^.size and a^.size<>size then axerror("5:movdq size") fi
		regcode:=getregcoderx(b^.reg)
		am:=genrm(a,regcode)
		if size=4 then
			genbyte(0x66)
			genrex()
			genbyte(0x0F)
			genbyte(0x7E)
		else
			genbyte(0x66)
			genrex()
			genbyte(0x0F)
			genbyte(0xD6)
		fi
		genamode(a,am)

	else
		axerror("movdq mem,?")
	esac
else
	axerror("movdq opnds")
esac

end

proc do_arithxmm(mcloperand a,b,int prefix,opc)=
int am, regcode

if a^.mode<>a_xreg or (b^.mode<>a_xreg and b^.mode<>a_mem) then
	axerror("arithxmm opnds")
fi

if b^.mode=a_xreg then


	regcode:=getregcoderx(a^.reg)
	am:=genrm(b,regcode)
	if prefix then genbyte(prefix) fi
	genrex()
	genbyte(0x0F)
	genbyte(opc)
	genamode(a,am)
else
	regcode:=getregcoderx(a^.reg)
	am:=genrm(b,regcode)
	if prefix then genbyte(prefix) fi
	genrex()
	genbyte(0x0F)
	genbyte(opc)
	genamode(b,am)
fi
end

proc do_logicxmm(mcloperand a,b,int opc,size)=
int am, regcode

if a^.mode<>a_xreg or (b^.mode<>a_xreg and b^.mode<>a_mem) then
	axerror("logicxmm opnds")
fi

if size=8 then
	genbyte(0x66)
fi

if b^.mode=a_xreg then
	regcode:=getregcoderx(a.reg)
	am:=genrm(b,regcode)
	genrex()
	genbyte(0x0F)
	genbyte(opc)
	genamode(b,am)
else
	regcode:=getregcoderx(a^.reg)
	am:=genrm(b,regcode)
	genrex()
	genbyte(0x0F)
	genbyte(opc)
	genamode(b,am)
fi
end

proc do_convertfloat(mcloperand a,b,int prefix)=
int am, regcode

if a^.mode<>a_xreg or (b^.mode<>a_xreg and b^.mode<>a_mem) then
	axerror("convertfloat opnds")
fi

genbyte(prefix)

if a^.mode=a_xreg then
	regcode:=getregcodeRx(a^.reg)
	am:=genrm(b,regcode)
	genrex()
	genbyte(0x0F)
	genbyte(0x5A)
	genamode(b,am)
else
	regcode:=getregcoderx(b^.reg)
	am:=genrm(a,regcode)
	genrex()
	genbyte(0x0F)
	genbyte(0x5A)
	genamode(b,am)
fi
end

proc do_fix(mcloperand a,b,int prefix,opc)=
int am, regcode

if a^.mode<>a_reg or (b^.mode<>a_xreg and b^.mode<>a_mem) then
	axerror("fix opnds")
fi

genbyte(prefix)

if b^.mode=a_xreg then
	regcode:=getregcoder(a^.reg)
	am:=genrm(b,regcode)
	setopsize(a)
else
	regcode:=getregcoder(a^.reg)
	am:=genrm(b,regcode)
	setopsize(a)
fi

genrex()
genbyte(0x0F)
genbyte(opc)
genamode(b,am)
end

proc do_float(mcloperand a,b,int prefix)=
int am, regcode

if a^.mode<>a_xreg or (b^.mode<>a_reg and b^.mode<>a_mem) then
	axerror("float opnds")
fi

if b^.mode=a_mem then
	if b^.size=0 then b^.size:=4 fi
	if b^.size<>4 and b^.size<>8 then axerror("float size") fi
fi

genbyte(prefix)

regcode:=getregcoderx(a^.reg)
am:=genrm(b,regcode)
setopsize(b)
genrex()
genbyte(0x0F)
genbyte(0x2A)
genamode(b,am)
end

proc do_call(mcloperand a)=
int am, regcode
	case a^.mode
	when a_imm then
		genbyte(0xE8)
		genrel32(a)
	else				!indirect call
		case a^.size
		when 0 then a^.size:=8
		when 1,2,4 then
			axerror("call[]size")
		esac
		am:=genrm(a,2)
		setopsize(a)
		setaddrsize(a)
		genrex()
		genbyte(0xFF)
		genamode(a,am)

	esac
end

proc do_jmp(mcloperand a,ref mclrec m)=
	int am, regcode, offset, shortjmp
	ref pstrec d

	case a^.mode
	when a_imm then				!assume label_val
		case a.valtype
		when label_val,def_val then
			d:=getdef(a,1)
			offset:=getrel32(d,getcurrdatalen(11)+1)+a.offset
			if offset<0 and offset>-126 then
				genbyte(0xEB)
				genbyte(offset)
			else
				shortjmp:=0
				if offset>0 then				!fwd jump
					shortjmp:=checkshortjump(m,d)
				fi

				if not shortjmp then
					genbyte(0xE9)
					genrel32(a)
				else
					genbyte(0xEB)
					genrel8(a)
				fi
			fi
		else
CPL VALTYPENAMES[A.VALTYPE]
			AXERROR("JMP/IMM NOT LABELNO")
		esac
	else				!indirect jump
		case a^.size
		when 0 then a^.size:=8
		when 1,2,4 then
			axerror("jmp[]size")
		esac
		am:=genrm(a,4)
		setopsize(a)
		setaddrsize(a)
		genrex()
		genbyte(0xFF)
		genamode(a,am)
	esac

end

function getcurrdatalen(int id)int=

if currseg=zdata_seg then
	return ss_zdatalen
fi
return bufferlength(currdata)
end

proc do_cmovcc(int cond, mcloperand a,b)=
int am, regcode
	if a^.size<>b^.size and b^.size then
		axerror("3:Opnd size mismatch")
	fi
	if a^.size=1 then axerror("cmov/byte") fi
	regcode:=getregcoder(a^.reg)
	am:=genrm(b,regcode)

	setopsize(a)
	genrex()
	genbyte(0x0F)
	genbyte(0x40+cond)
	genamode(b,am)
end

proc do_fmem(mcloperand a, int freal, code)=
int am, regcode, mf

if a^.mode<>a_mem then
	axerror("fmem/not mem")
fi

if freal then
	case a^.size
	when 4 then mf:=0
	when 8 then mf:=2
	when 16 then
		mf:=1
		case code
		when 0 then code:=5
		when 3 then code:=7
		else
			axerror("r80 not allowed")
		esac
	else
CPL "SIZE=",A^.SIZE
		axerror("fmem size")
	esac
else
	case a^.size
	when 2 then mf:=3
	when 4 then mf:=1
	when 8 then
		mf:=3
		case code
		when 0 then code:=5
		when 3 then code:=7
		else
			axerror("fst i64?")
		esac
	else
		axerror("fmem int size")
	esac
fi

am:=genrm(a,code)
genrex()
genbyte(0xD9+mf<<1)
genamode(a,am)
end

function getr32bits(real x)int=
real32 sx:=x
return int32@(sx)
end

proc genrel8(mcloperand a)=
ref pstrec d

d:=getdef(a,1)

if d^.reftype=fwd_ref then
	d^.fwdrefs:=addfwdref(d^.fwdrefs,getcurrdatalen(3),rel8_rel)
	genbyte(0)
else								!external symbol
	axerror("genrel8")
fi
end

function checkshortjump(ref mclrec m,ref pstrec d)int=
int n

n:=0
m:=m^.nextmcl
while m and n<=8 do
	case m.opcode
	when m_label then
		if m.a.labelno=d.labelno then
			return 1
		fi
	when m_comment, m_blank then
	else
		++n
	esac

	m:=m^.nextmcl
od

return 0
end

function addfwdref(ref fwdrec p, int offset, reltype, seg=0)ref fwdrec=
ref fwdrec q

q:=pcm_alloc(fwdrec.bytes)
q^.nextfwd:=p
q^.offset:=offset
q^.reltype:=reltype
q^.seg:=seg
return q
end

proc switchseg(int newseg)=
	if newseg=currseg then return fi

	case currseg						!reloc linked list roots must be updated
	when code_seg then
		ss_coderelocs:=currrelocs
		ss_ncoderelocs:=nrelocs
	when idata_seg then
		ss_idatarelocs:=currrelocs
		ss_nidatarelocs:=nrelocs
	esac

	currseg:=newseg

	case currseg
	when code_seg then
		currdata:=ss_code
		currrelocs:=ss_coderelocs
		nrelocs:=ss_ncoderelocs
	when idata_seg then
		currdata:=ss_idata
		currrelocs:=ss_idatarelocs
		nrelocs:=ss_nidatarelocs
	when zdata_seg then
		currdata:=ss_zdata
	esac							!else 0, done at end to update linked lists

end

proc do_movdqx(mcloperand a,b, int opc)=
int am,regcode

case a^.mode
when a_xreg then
	case b^.mode
	when a_xreg then
		regcode:=getregcodebx(b^.reg)
		am:=genrm(a,regcode)
		genbyte(opc)
		genrex()
		genbyte(0x0F)
		genbyte(0x6F)
		genamode(a,am)

	when a_mem then
		regcode:=getregcoderx(a^.reg)
		am:=genrm(b,regcode)
		genbyte(opc)
		genrex()
		genbyte(0x0F)
		genbyte(0x6F)
		genamode(b,am)

	else
		axerror("movdqx?")
	esac
when a_mem then
	case b^.mode
	when a_xreg then
		regcode:=getregcoderx(b^.reg)
		am:=genrm(a,regcode)
		genbyte(opc)
		genrex()
		genbyte(0x0F)
		genbyte(0x7F)
		genamode(a,am)

	else
		axerror("movdqx")
	esac
else
	axerror("movdqx")
esac

end

proc do_popcnt(mcloperand a,b)=
int am, regcode

if b^.mode=a_mem then
	if b^.size=0 then b^.size:=8 fi
fi

genbyte(0xF3)

regcode:=getregcodebx(a^.reg)
am:=genrm(b,regcode)
setopsize(a)
genrex()
genbyte(0x0F)
genbyte(0xB8)
genamode(b,am)
end

proc do_bsf(mcloperand a,b, int opc)=
int am, regcode

if b^.mode=a_mem then
	if b^.size=0 then b^.size:=8 fi
fi
if a.size<>b.size then gerror("bsf size") fi

regcode:=getregcodebx(a^.reg)
am:=genrm(b,regcode)
setopsize(a)
genrex()
genbyte(0x0F)
genbyte(opc)
genamode(b,am)
end

proc extendsymboltable=
	ref[]ref pstrec oldsymboltable
	int oldsymboltablesize

	oldsymboltablesize:=ss_symboltablesize
	oldsymboltable:=ss_symboltable

	ss_symboltablesize*:=2
CPL "EXTENDING SYMBOL TABLE TO",SS_SYMBOLTABLESIZE

	ss_symboltable:=pcm_alloc(ref void.bytes*ss_symboltablesize)

	for i:=1 to ss_nsymbols do
		ss_symboltable^[i]:=oldsymboltable^[i]
	od

	pcm_free(oldsymboltable,ref void.bytes*oldsymboltablesize)
end

PROC SHOWOPND(ICHAR CAPTION,MCLOPERAND A)=
CPL CAPTION,OPNDNAMES_MA[A.MODE],VALTYPENAMES[A.VALTYPE]
END


proc fixregvar=
	ref mclrec m
	m:=mccode

	while m do
		if m.a then fixopnd(m.a) fi
		if m.b then fixopnd(m.b) fi
		m:=m.nextmcl
	od
end

proc fixopnd(mcloperand a)=
	case a.mode
	when a_regvar then
		a.mode:=a_reg
		if ttcat[a.def.mode]=x64_cat then
			a.mode:=a_xreg
		fi

		a.def:=nil
		a.valtype:=0
	esac
end
=== ma_decls.m 31/40 ===
import bb_decls
import bb_pclcommon

global const compilerversion="2018.1.22"

global record relocrec =			!informal version
	ref relocrec nextreloc
	int reloctype
	int offset
	int stindex
end

global record dbuffer =
	ref byte pstart
	union
		ref byte pcurr
		ref word16 pcurr16
		ref word32 pcurr32
		ref word64 pcurr64
	end
	ref byte pend
	int alloc
end

global const maxsearchlibs=30
global [maxsearchlibs]ichar searchlibs
global int nmodules
global int nsearchlibs


global int LINECOUNT=0

global int nundefined=0

global int ss_zdatalen
global ref dbuffer ss_zdata			!used for error checking only (should be empty at end)
global ref dbuffer ss_idata
global ref dbuffer ss_code
global ref relocrec ss_idatarelocs
global ref relocrec ss_coderelocs
global int ss_nidatarelocs
global int ss_ncoderelocs

global const init_ss_symbols=32768				!exported to coff
global ref []ref pstrec ss_symboltable
global int ss_nsymbols
global int ss_symboltablesize


global ref[]ref pstrec labeldeftable

global int currmoduleno

GLOBAL INT NMCLASM
GLOBAL INT NMCLOPNDSASM

=== ma_lib.m 32/40 ===
import clib
import msys
import mlib
import ma_decls

import bb_decls
import bb_mcldecls
import bb_support
import bb_lib
import bb_pclcommon

const ptrsize=8

global int currsegment=0		!



strbuffer destv
global ref strbuffer dest=&destv


TYPE FREDDY=INT

global proc initlib(int nlabels)=
[256]char str


ss_symboltable:=pcm_alloc(init_ss_symbols*ref void.bytes)
ss_symboltablesize:=init_ss_symbols
ss_nsymbols:=0

labeldeftable:=pcm_alloc(nlabels*ref void.bytes)
for i to nlabels do
	labeldeftable[i]:=pcm_allocz(pstrec.bytes)
	labeldeftable[i].labelno:=i
	fprint @&.str,"(L#)",i
	labeldeftable[i].name:=pcm_copyheapstring(&.str)
	labeldeftable[i].reftype:=fwd_ref
od

end

function getsizetag(int size)ichar=			!GETSIZETAG
case size
when 1 then return "b"
when 2 then return "h"
when 4 then return "w"
when 8 then return "d"
esac
AXERROR("GETSIZETAG?")
return nil
end

global function buffercreate(int size=1024)ref dbuffer=
ref dbuffer a

a:=pcm_alloc(dbuffer.bytes)

a^.alloc:=size
a^.pstart:=a^.pcurr:=pcm_alloc(a^.alloc)
a^.pend:=a^.pstart+a^.alloc
return a
end

proc bufferexpand(ref dbuffer a)=
int newalloc,usedbytes
ref byte p

newalloc:=a^.alloc*2
usedbytes:=a^.pcurr-a^.pstart

if usedbytes>a^.alloc then
	println "dbuffer error"
	stop
fi

p:=pcm_alloc(newalloc)
memcpy(p,a^.pstart,usedbytes)
a^.pstart:=p
a^.pcurr:=p+usedbytes
a^.alloc:=newalloc
a^.pend:=p+newalloc
end

global proc buffercheck(ref dbuffer a,int n=1024)=
while a^.pend-a^.pcurr<n do
	bufferexpand(a)
od
end

global function bufferlength(ref dbuffer a)int=
return a^.pcurr-a^.pstart
end

global function bufferelemptr(ref dbuffer a, int offset)ref void=
return a^.pstart+offset
end

global proc addbyte(ref dbuffer a, int x)=
a^.pcurr^:=x
++a^.pcurr
end

global proc addword(ref dbuffer a, int x)=
a^.pcurr16^:=x
++a^.pcurr16
end

global proc adddword(ref dbuffer a, int x)=
a^.pcurr32^:=x
++a^.pcurr32
end

global proc addqword(ref dbuffer a, int64 x)=
a^.pcurr64^:=x
++a^.pcurr64
end

=== ma_objdecls.m 33/40 ===
import ma_decls
import bb_pclcommon

global record imagefileheader =
	word16	machine
	word16	nsections
	word32	timedatestamp
	word32	symtaboffset
	word32	nsymbols
	word16	optheadersize
	word16	characteristics
end

global record imagedir =
	word32	virtualaddr
	word32	size
end

global record optionalheader =			!exe/dll only
	word16  magic
	byte     majorlv
	byte     minorlv
	word32 codesize
	word32 idatasize
	word32 zdatasize
	word32 entrypoint
	word32 codebase
	word64	imagebase
	word32 sectionalignment
	word32 filealignment
	word16  majorosv
	word16  minorosv
	word16  majorimagev
	word16  minorimagev
	word16  majorssv
	word16  minorssv
	word32 win32version
	word32 imagesize
	word32 headerssize
	word32 checksum
	word16  subsystem
	word16  dllcharacteristics
	word64   stackreserve
	word64   stackcommit
	word64   heapreserve
	word64   heapcommit
	word32 loaderflags
	word32 rvadims
	imagedir exporttable
	imagedir importtable
	imagedir resourcetable
	imagedir exceptiontable
	imagedir certtable
	imagedir basereloctable
	imagedir debug
	imagedir architecture
	imagedir globalptr
	imagedir tlstable
	imagedir loadconfigtable
	imagedir boundimport
	imagedir iat
	imagedir delayimportdescr
	imagedir clrheader
	imagedir reserved
end

global record imagesectionheader =
	[8]char name
	union
		word32	physical_address
		word32	virtual_size
	end
	word32	virtual_address
	word32	rawdata_size
	word32	rawdata_offset
	word32	relocations_ptr
	word32	linenos_offset
	word16	nrelocs
	word16	nlinenos
	word32	characteristics
end

global record imagesymbol =
	union
		[8]char shortname
		struct
			word32	shortx
			word32	longx
		end
		word64 longname
	end
	word32	value
	int16	sectionno
	word16	symtype
	byte	storageclass
	byte	nauxsymbols
end

global record importdirrec =
	word32	implookuprva
	word32	timedatestamp
	word32	fwdchain
	word32	namerva
	word32	impaddressrva
end

global record coffrelocrec =
	int32	virtualaddr
	int32	stindex
	int16	reloctype
end

global tabledata() [0:]ichar relocnames =
	(abs_rel = 0,	$),
	(addr64_rel,	$),
	(addr32_rel,	$),
	(addr32nb_rel,	$),
	(rel32_rel,		$),
	(rel321_rel,	$),
	(rel8_rel,		$),				!used within assembler only, not in coff format
end


global record auxsectionrec = 
	int32 length
	int16 nrelocs
	int16 nlines
	int32 checksum
	int16 sectionno
	int32 dummy
end

global record sectionrec =
	union
		ref dbuffer data		!copy of ss_zdata etc
		ref byte bytedata		!added later, eg, import dir block
	end
	ichar name					!name like ".bss" as it will be in obj/exe file
	int segtype					!code_seg etc
	int rawsize					!in file
	int rawoffset				!offset in exe file
	int virtsize				!in image
	int virtoffset				!offset from imagebase
	ref relocrec relocs			!for idata/code: reloc info needs to be processed
	int nrelocs					!
end

global record importrec = 				!details about all imported symbols
	ref pstrec def				!full st entry
	int libno					!which dll lib this belongs to
	ichar name					!name of symbol (extracted from lib.name if needed)
	int hintnameoffset			!voffset of hint/name entry in impdir section
	int iatoffset				!voffset of IAT entry
	int thunkoffset				!offset within code section of thunk entry
end

global record exportrec = 		!details about all exported symbols
	ref pstrec def				!full st entry
	ichar name					!name of symbol (extracted from lib.name if needed)
end

global record dllrec =					!all imported libraries
	ichar name					!name of library, including .dll
	int nprocs					!no. of imports which use this library
	int nametableoffset			!start of name table in impdir
	int addrtableoffset			!start of addr table (IAT)
	int dllnameoffset			!offset of name within impdir
	int dllextraoffset			!offset of mysterious region just before the name
end

global record exportdirrec =
	word32 exportflags
	word32 timedatestamp
	word16 majorversion
	word16 minorversion
	word32 namerva
	word32 ordinalbase
	word32 naddrtable
	word32 nnamepointers
	word32 expaddressrva
	word32 namepointerrva
	word32 ordtablerva
end
=== ma_writeexe.m 34/40 ===

import clib
import mlib
import oslib
import bb_decls
import bb_support
import ma_objdecls
import bb_tables
import ma_decls
import ma_lib
import bb_mcldecls

import bb_pclcommon

[maxsearchlibs]int64 libinsttable
[maxsearchlibs]ichar libinstnames
[maxsearchlibs]int libnotable			!index into dlltable

global const zsect=3
global const dsect=2
global const csect=1
global const isect=4

record basereloc =
	ref basereloc nextitem
	word32 address				!virtual address
	int32 reloctype
end

ref basereloc basereloclist
int nbaserelocs
int maxrelocaddr
const maxbaseblock=500
[maxbaseblock]int blockbases
[maxbaseblock]int32 blockcounts
[maxbaseblock]int32 blockbytes
[maxbaseblock]byte blockpadding
int nbaseblocks
int basetablesize


const filealign = 512
const sectionalign = 4096
const exe_imagebase = 0x40'0000
const dll_imagebase = 0x6624'0000
global int imagebase

int imagesize
int filesize
ref[]int64 thunktable				!point into code segment
int fileiatoffset
int fileiatsize
ref pstrec stentrypoint				!symbol to be the entry point
ref pstrec stentrypoint2
ref pstrec stentrypoint3

const maxsection = 10
global [maxsection]sectionrec sectiontable
global int nsections

ref byte importdir				!allowed section data for import directort in .idata

global const maximports = 3000
global [maximports]importrec importtable
global int nimports

global const maxexports = 1000
global [maxexports]exportrec exporttable
global int nexports
ichar dllfilename
int isdll

global const maxlibs = 50
global [maxlibs]dllrec dlltable
global int ndlls

ref byte datastart
ref byte dataptr
ichar userentrypoint

int exportdirvirtaddr
int exportdirvirtsize
int exportdiroffset				!from start of imp dir

int blockdirvirtaddr
int blockdirvirtsize
int blockdiroffset

global proc writeexe(ichar outfile,int dodll)=
imagefileheader header
optionalheader optheader
int offset,i
int64 aa

	dllfilename:=outfile
	isdll:=dodll

	datastart:=dataptr:=pcm_allocz(filesize)

	writedosstub()
	writepesig()
	writefileheader()
	writeoptheader()
	for i to nsections do
		writesectionheader(&sectiontable[i])
	od
	writepadding(sectiontable[1].rawoffset)
	for i to nsections do
		writesectiondata(&sectiontable[i])
	od


	if fverbose>=2 then
		CPL "Writing file:",outfile
	fi

	if writefile(outfile,datastart,dataptr-datastart)=0 then
		println "Error writing exe file (possibly still running)"
		stop 1
	fi
end

global proc genexe(ichar entrypoint, outfile, int dodll)=

	dllfilename:=outfile
	isdll:=dodll

	setuplibfiles()

	imagebase:=(isdll|dll_imagebase|exe_imagebase)

	userentrypoint:=entrypoint
	loadlibs()
	scanst()				!build dll/import tables

	getoffsets()

	relocdata(&sectiontable[csect])
	relocdata(&sectiontable[dsect])

end

proc loadlibs=
int i
int64 hinst
ichar file
[300]char filename

for i to nsearchlibs do

	strcpy(&.filename,searchlibs[i])
	hinst:=os_getdllinst(&.filename)
	if hinst=0 then
		cpl "File:",&.filename
		axerror("Can't load search lib")
	fi
	libinsttable[i]:=hinst
	libinstnames[i]:=pcm_copyheapstring(&.filename)
od
end

global proc initsectiontable=

sectiontable[csect].name:=".text"
sectiontable[csect].segtype:=code_seg
sectiontable[csect].data:=ss_code
sectiontable[csect].virtsize:=bufferlength(ss_code)


if bufferlength(ss_idata)=0 then
	addqword (ss_idata,0)
fi

sectiontable[dsect].name:=".data"
sectiontable[dsect].segtype:=idata_seg
sectiontable[dsect].data:=ss_idata

sectiontable[dsect].virtsize:=bufferlength(ss_idata)
sectiontable[dsect].rawsize:=roundtoblock(sectiontable[dsect].virtsize,filealign)
sectiontable[dsect].nrelocs:=ss_nidatarelocs
sectiontable[dsect].relocs:=ss_idatarelocs

if ss_zdatalen=0 then
	ss_zdatalen:=16
fi

sectiontable[zsect].name:=".bss"
sectiontable[zsect].segtype:=zdata_seg
sectiontable[zsect].virtsize:=ss_zdatalen


sectiontable[csect].rawsize:=roundtoblock(sectiontable[csect].virtsize,filealign)
sectiontable[csect].nrelocs:=ss_ncoderelocs
sectiontable[csect].relocs:=ss_coderelocs

sectiontable[isect].name:=".idata"
sectiontable[isect].segtype:=impdata_seg
sectiontable[isect].virtsize:=0
sectiontable[isect].rawsize:=0

nsections:=4
end

function roundtoblock(int n,align)int=
if n iand (align-1)=0 then return n fi

return n+(align-(n iand (align-1)))
end

function extractlibname(ichar name, int &libno,moduleno)ichar=
ref char s,name2
[256]char str
[256]char str2
int i

name2:=nil

reenter::
s:=name
libno:=0

while s^ do
	if s^='.' then			!assume lib.name
		memcpy(&.str,name,s-name)
		str[s-name+1]:=0
		strcat(&.str,".dll")

		for i:=1 to ndlls do
			if eqstring(&.str,dlltable[i].name) then
				libno:=i
				++dlltable[libno].nprocs
				return (name2|name2|s+1)
			fi
		od
		if ndlls>=maxlibs then axerror("Too many libs") fi
		libno:=++ndlls

		dlltable[libno].name:=pcm_copyheapstring(&.str)
		dlltable[libno].nprocs:=1
		return (name2|name2|s+1)
	fi

	++s
od

int n


for i:=1 to nsearchlibs do
	if os_getdllprocaddr(libinsttable[i],name) then
		n:=i
		exit				!don't need the actual address; just whether it exists
	fi
else
	println name,"in module",moduletable[moduleno].name
	axerror("Can't find external function")
od

if libno:=libnotable[n] then			!already added this library
	++dlltable[libno].nprocs
	return name
fi

strcpy(&.str,searchlibs[n])
strcat(&.str,".dll")
if ndlls>=maxlibs then axerror("2:Too many libs") fi
libno:=++ndlls

dlltable[libno].name:=pcm_copyheapstring(&.str)
dlltable[libno].nprocs:=1
libnotable[n]:=libno

return name
end

proc scanst=

	int i,libno
	ref pstrec d
	ichar name, libname


	for i:=1 to ss_nsymbols do
		d:=ss_symboltable^[i]


		if imported(d) then
			if nimports>=maximports then axerror("genexe: Too many imports") fi
			++nimports

			name:=extractlibname(d.name,libno,d^.moduleno)
			importtable[nimports].libno:=libno			!0 if no lib
			importtable[nimports].name:=name				!original, or 2nd part of lib.name
			importtable[nimports].def:=d

			d^.importindex:=nimports
		elsif exported(d) then
			if userentrypoint then
				if eqstring(d^.name,userentrypoint) then
					stentrypoint:=d
				fi
			else
				if eqstring(d^.name,"main") and not isdll then
					stentrypoint:=d
				elsif eqstring(d^.name,"start") and not isdll then
					stentrypoint2:=d
				elsif eqstring(d^.name,"dllmain") and isdll then
					stentrypoint:=d
				fi
			fi


			if nexports>=maxexports then gerror("gendll: Too many exports") fi
			++nexports

			exporttable[nexports].def:=d
			exporttable[nexports].name:=d.name

		fi
	od
end

proc relocdata(ref sectionrec s)=
ref sectionrec u
ref relocrec r
ref byte p
ref word32 p32
ref word64 p64
ref pstrec d
int offset,index,thunkoffset,iatoffset


p:=bufferelemptr(s^.data,0)
r:=s^.relocs

while r do
	d:=ss_symboltable^[r^.stindex]
	index:=d^.importindex				!into importtable
	thunkoffset:=importtable[index].thunkoffset

	case r^.reloctype
	when rel32_rel then
		if not imported(d) then
			axerror("rel32/not imported")
		fi
		(ref word32(p+r^.offset)^:=thunkoffset-r^.offset-4)
	when addr32_rel, addr64_rel then				!for addr64, just leave top half zero
		if imported(d) then
			(ref word32(p+r^.offset)^:=imagebase+thunkoffset+sectiontable[csect].virtoffset)
		else
			u:=nil
			case d^.segment
			when zdata_seg then u:=&sectiontable[zsect]
			when idata_seg then u:=&sectiontable[dsect]
			when code_seg then u:=&sectiontable[csect]
			else
				CPL D.NAME,D.SEGMENT
				AXERROR("RELOCDATA/SEG?")
			esac


				p32:=cast(p+r^.offset)
				if r.reloctype=addr32_rel then
					p32^:=p32^+u^.virtoffset+imagebase
				else
					p64:=cast(P32)
					p64^:=p64^+u^.virtoffset+imagebase
				fi
		fi
	else
		cpl relocnames[r^.reloctype]
		axerror("Can't do this rel type")
	esac

	r:=r^.nextreloc
od

end

proc getbaserelocs(ref sectionrec s)=
	ref sectionrec u
	ref relocrec r
	ref byte p
	ref pstrec d
	int index

	p:=bufferelemptr(s^.data,0)
	r:=s^.relocs

	while r do
		d:=ss_symboltable^[r^.stindex]

		case r^.reloctype
		when addr32_rel, addr64_rel then				!for addr64, just leave top half zero
			if imported(d) then
			else
				case d^.segment
				when zdata_seg then u:=&sectiontable[zsect]
				when idata_seg then u:=&sectiontable[dsect]
				when code_seg then u:=&sectiontable[csect]
				esac

				newbasereloc(u.virtoffset+r.offset, r.reloctype)

			fi
		esac

		r:=r^.nextreloc
	od

end

proc writerecordx(ref void r, int length)=
memcpy(dataptr,r,length)
dataptr+:=length
end

proc writedosstub=
static []byte stubdata = (
	0x4D, 0x5A, 0x90, 0x00, 0x03, 0x00, 0x00, 0x00, 
	0x04, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00, 
	0xB8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
	0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
	0x00, 0x00, 0x00, 0x00, 0x80, 0x00, 0x00, 0x00, 
	0x0E, 0x1F, 0xBA, 0x0E, 0x00, 0xB4, 0x09, 0xCD, 
	0x21, 0xB8, 0x01, 0x4C, 0xCD, 0x21, 0x54, 0x68, 
	0x69, 0x73, 0x20, 0x70, 0x72, 0x6F, 0x67, 0x72, 
	0x61, 0x6D, 0x20, 0x63, 0x61, 0x6E, 0x6E, 0x6F, 
	0x74, 0x20, 0x62, 0x65, 0x20, 0x72, 0x75, 0x6E, 
	0x20, 0x69, 0x6E, 0x20, 0x44, 0x4F, 0x53, 0x20, 
	0x6D, 0x6F, 0x64, 0x65, 0x2E, 0x0D, 0x0D, 0x0A, 
	0x24, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)

writerecordx(&stubdata,stubdata.bytes)
end

proc writepesig=
dataptr++^:='P'
dataptr++^:='E'
dataptr++^:=0
dataptr++^:=0
end

proc writepadding(int offset)=
dataptr:=datastart+offset			!data will have been cleared
end

proc writefileheader=
imagefileheader header

memset(&header,0,header.bytes)

header.machine:=0x8664
header.nsections:=nsections
header.optheadersize:=optionalheader.bytes
header.characteristics:=0x22F

writerecordx(&header,header.bytes)
end

proc writeoptheader=
	optionalheader header

	memset(&header,0,header.bytes)

	header.magic:=0x20B
	header.majorlv:=1
	header.minorlv:=0
	header.codesize:=sectiontable[csect].rawsize
	header.idatasize:=sectiontable[dsect].rawsize+sectiontable[isect].rawsize
	header.zdatasize:=roundtoblock(sectiontable[zsect].virtsize,filealign)
	
	if stentrypoint=nil then
		stentrypoint:=stentrypoint2
	fi

	if stentrypoint=nil then
		if userentrypoint then
			cpl userentrypoint
			gerror("User entry point not found")
		else
			if not isdll then
				gerror("Entry point not found: main or start")
			fi
		fi
	else
		header.entrypoint:=sectiontable[csect].virtoffset+stentrypoint^.offset
	fi


	header.codebase:=sectionalign
	header.imagebase:=imagebase
	header.sectionalignment:=sectionalign
	header.filealignment:=filealign
	header.majorosv:=4
	header.minorosv:=0
	header.majorssv:=5
	header.minorssv:=2
	header.imagesize:=imagesize
	header.headerssize:=sectiontable[1].rawoffset
	header.subsystem:=3

	header.stackreserve:=4194304
	header.stackcommit:=2097152

	header.heapreserve:=1048576
	header.heapcommit:=4096
	header.rvadims:=16

	header.importtable.virtualaddr:=sectiontable[isect].virtoffset
	header.importtable.size:=sectiontable[isect].virtsize-exportdirvirtsize-blockdirvirtsize

	if isdll then
		header.dllcharacteristics:=0x40		!relocatable
		header.exporttable.virtualaddr:=exportdirvirtaddr
		header.exporttable.size:=exportdirvirtsize

		header.basereloctable.virtualaddr:=blockdirvirtaddr
		header.basereloctable.size:=blockdirvirtsize
	fi

	header.iat.virtualaddr:=fileiatoffset
	header.iat.size:=fileiatsize

	writerecordx(&header,header.bytes)

end

proc writesectionheader(ref sectionrec s)=
imagesectionheader sheader

memset(&sheader,0,sheader.bytes)

strcpy(&sheader.name[1],s^.name)
sheader.virtual_size:=s^.virtsize
sheader.virtual_address:=s^.virtoffset
sheader.rawdata_offset:=s^.rawoffset
sheader.rawdata_size:=s^.rawsize

int64 aa
case s^.segtype
when zdata_seg then
	aa:=0xC050'0080
	sheader.characteristics:=aa
when idata_seg then
	aa:=0xC050'0040
	sheader.characteristics:=aa
when code_seg then
	aa:=0x6050'0020
	sheader.characteristics:=aa
when impdata_seg then
	aa:=0xC030'0040
	sheader.characteristics:=aa
esac
writerecordx(&sheader,sheader.bytes)
end

proc writesectiondata(ref sectionrec s)=

case s^.segtype
when impdata_seg then
	writerecordx(s^.bytedata,s^.virtsize)		!rest of section will be zeros
	if s^.rawsize>s^.virtsize then
		dataptr+:=(s^.rawsize-s^.virtsize)
	fi

when zdata_seg then					!nothing goes to disk
else
	writerecordx(bufferelemptr(s^.data,0),s^.rawsize)
esac
end

proc getoffsets=
	int fileoffset, imageoffset,i,diroffset,impdirno,hinttableoffset,j,n
	int codesize,length,thunkoffset,offset,dirstartoffset

	fileoffset:=128+4+imagefileheader.bytes+optionalheader.bytes	!dosstub+sig
	fileoffset+:=imagesectionheader.bytes*nsections

	fileoffset:=roundtoblock(fileoffset,filealign)
	imageoffset:=4096

	ref byte pcode
	codesize:=sectiontable[csect].virtsize
	pcode:=bufferelemptr(ss_code,codesize)
	while codesize iand 7 do pcode++^:=0x90; ++codesize od
	thunkoffset:=codesize
	codesize+:=nimports*8

	sectiontable[csect].virtsize:=codesize
	sectiontable[csect].rawsize:=roundtoblock(codesize,filealign)

	buffercheck(ss_code, codesize-thunkoffset+16)		!just ensure it's there for now

	for i:=1 to nsections do
		if sectiontable[i].segtype<>zdata_seg then
			sectiontable[i].rawoffset:=fileoffset
		fi
		if sectiontable[i].segtype<>zdata_seg then
			fileoffset:=roundtoblock(fileoffset+sectiontable[i].virtsize,filealign)
		fi
		sectiontable[i].virtoffset:=imageoffset

		if sectiontable[i].segtype=impdata_seg then
			diroffset:=imageoffset
			impdirno:=i
		fi

		imageoffset:=roundtoblock(imageoffset+sectiontable[i].virtsize,sectionalign)
	od

	if isdll then
		getbaserelocs(&sectiontable[csect])
		getbaserelocs(&sectiontable[dsect])
	fi


	diroffset+:=(ndlls+1)*importdirrec.bytes			!need blank entry as terminator


	for i to ndlls do
		dlltable[i].nametableoffset:=diroffset				!data will be filled in later
		diroffset+:=(dlltable[i].nprocs+1)*8
	od
	fileiatoffset:=diroffset
	for i to ndlls do
		dlltable[i].addrtableoffset:=diroffset				!data will be filled in later
		diroffset+:=(dlltable[i].nprocs+1)*8
	od
	fileiatsize:=diroffset-fileiatoffset

	hinttableoffset:=diroffset
	for i to nimports do
		length:=strlen(importtable[i].name)+3
		if length iand 1 then ++length fi		!keep even
		importtable[i].hintnameoffset:=diroffset
		diroffset+:=length
	od


	diroffset:=roundtoblock(diroffset,4)

	for i to ndlls do
		length:=strlen(dlltable[i].name)+1
		if length iand 1 then ++length fi		!keep even
		dlltable[i].dllextraoffset:=diroffset
		diroffset+:=dlltable[i].nprocs*4		!space for back-links to dir entry
		dlltable[i].dllnameoffset:=diroffset
		diroffset+:=length
	od

	dirstartoffset:=sectiontable[impdirno].virtoffset

	if isdll then

		exportdirvirtaddr:=diroffset
		exportdiroffset:=diroffset-dirstartoffset
		exportdirvirtsize:=getexporttablesize()
		diroffset+:=exportdirvirtsize

		scanbaserelocs()

		blockdirvirtaddr:=diroffset
		blockdiroffset:=diroffset-dirstartoffset
		blockdirvirtsize:=basetablesize
		diroffset+:=blockdirvirtsize
	fi

	offset:=diroffset-dirstartoffset


	sectiontable[impdirno].virtsize:=offset
	sectiontable[impdirno].rawsize:=roundtoblock(offset,filealign)
	filesize:=roundtoblock(fileoffset+offset,filealign)

	imagesize:=roundtoblock(imageoffset+(diroffset-dirstartoffset),sectionalign)

	ref byte pimpdir

	pimpdir:=sectiontable[impdirno].bytedata:=pcm_allocz(offset)

	ref importdirrec pdir
	ref int64 paddr,pname
	int iatoffset
	pdir:=cast(pimpdir)

	for i:=1 to ndlls do
		pdir^.implookuprva:=dlltable[i].nametableoffset
		pdir^.impaddressrva:=dlltable[i].addrtableoffset
		pdir^.namerva:=dlltable[i].dllnameoffset
		++pdir

		iatoffset:=dlltable[i].addrtableoffset
		paddr:=cast(pimpdir+iatoffset-dirstartoffset)
		pname:=cast(pimpdir+dlltable[i].nametableoffset-dirstartoffset)
		for j to nimports when importtable[j].libno=i do
			pname^:=paddr^:=importtable[j].hintnameoffset
			importtable[j].iatoffset:=iatoffset
			iatoffset+:=8
			++pname
			++paddr
		od
	od

	ref byte phint
	ref word32 pextra

	for i to nimports do
		phint:=pimpdir+importtable[i].hintnameoffset-dirstartoffset
		phint+:=2					!leave hint as 0
		strcpy(cast(phint),importtable[i].name)
	od
	int xxx
	xxx:=dirstartoffset
	for i to ndlls do
		pextra:=cast(pimpdir+dlltable[i].dllextraoffset-dirstartoffset)
		for j to dlltable[i].nprocs do
			pextra^:=xxx
			++pextra
		od
		xxx+:=importdirrec.bytes
		phint:=pimpdir+dlltable[i].dllnameoffset-dirstartoffset
		strcpy(cast(phint),dlltable[i].name)
	od

	if isdll then
		writeexporttable(ref byte(pimpdir)+exportdiroffset)
		writebasereloctable(ref byte(pimpdir)+blockdiroffset)
	fi

	ref byte thunkptr,codebase
	int thunkaddr
	thunkptr:=bufferelemptr(ss_code,thunkoffset)
	codebase:=bufferelemptr(ss_code,0)

	for i to nimports do
		importtable[i].thunkoffset:=thunkptr-codebase
		thunkptr++^:=0x48
		thunkptr++^:=0xFF
		thunkptr++^:=0x24
		thunkptr++^:=0x25
		thunkaddr:=imagebase+importtable[i].iatoffset
		(ref int32(thunkptr)^:=thunkaddr)

		thunkptr+:=4
	od
end

function imported(ref pstrec d)int=
	if d.id in [dllproc_name, dllstatic_name] then return 1 fi

	return 0
end

function exported(ref pstrec d)int=
	return d.isglobal=export_scope
end

proc addsearchlib(ichar name) =
	name:=changeext(name,"")

	for i to nsearchlibs do
		if eqstring(searchlibs[i],name) then return fi
	od

	if nsearchlibs>=maxsearchlibs then
		axerror("Too many LIB files")
	fi
	searchlibs[++nsearchlibs]:=pcm_copyheapstring(name)
end

proc setuplibfiles=

nsearchlibs:=0

searchlibs[1]:="msvcrt"
searchlibs[2]:="gdi32"
searchlibs[3]:="user32"
searchlibs[4]:="kernel32"
nsearchlibs:=4	

for i to nlibfiles do addsearchlib(libfiles[i]) od
for i to ncclibs do addsearchlib(cclibtable[i]) od
for i to ndllnametable when dllnametable[i]^<>'$' do
	addsearchlib(dllnametable[i])
od

end

proc writeexporttable(ref byte pstart)=
	const maxexports=2000
	[maxexports]int sortindex
	ref exportdirrec phdr := cast(pstart)
	ref word32 paddrtable
	ref word32 pnametable
	ref word16 pordtable
	ref char pdllname
	ref char pnames
	int addrtableoffset
	int nametableoffset
	int ordtableoffset
	int dllnameoffset
	int namesoffset
	int virtoffset
	int sectionno
	ref pstrec d

	phdr.timedatestamp:=0x5f89f4f8

	phdr.ordinalbase:=1
	phdr.naddrtable:=nexports
	phdr.nnamepointers:=nexports

	addrtableoffset:=exportdirrec.bytes
	nametableoffset:=addrtableoffset+nexports*4
	ordtableoffset:=nametableoffset+nexports*4
	dllnameoffset:=ordtableoffset+nexports*2
	namesoffset:=dllnameoffset+strlen(dllfilename)+1

	virtoffset:=sectiontable[isect].virtoffset+exportdiroffset

	paddrtable:=cast(pstart+addrtableoffset)
	pnametable:=cast(pstart+nametableoffset)
	pordtable:=cast(pstart+ordtableoffset)
	pdllname:=cast(pstart+dllnameoffset)
	pnames:=cast(pstart+namesoffset)

	phdr.namerva:=dllnameoffset+virtoffset
	phdr.expaddressrva:=addrtableoffset+virtoffset
	phdr.namepointerrva:=nametableoffset+virtoffset
	phdr.ordtablerva:=ordtableoffset+virtoffset

	strcpy(pdllname,dllfilename)

	if nexports>maxexports then
		gerror("Too many exports - can't sort")
	fi

	sortexports(sortindex)

	for i to nexports do
		d:=exporttable[sortindex[i]].def
		sectionno:=getsectionno(d.segment)

		strcpy(pnames,d.name)
		pnametable^:=namesoffset+virtoffset
		++pnametable
		namesoffset+:=strlen(d.name)+1
		pnames+:=strlen(d.name)+1

		paddrtable^:=d.offset+sectiontable[sectionno].virtoffset
		++paddrtable
		pordtable^:=i-1
		++pordtable
	od


end

function getexporttablesize:int=
	int size

	size:=exportdirrec.bytes
	size+:=nexports*4			!address table entries
	size+:=nexports*4			!name pointers
	size+:=nexports*2			!ordinal table

	size+:=strlen(dllfilename)+1
	for i to nexports do
		size+:=strlen(exporttable[i].def.name)+1
	od

	return size
end

proc newbasereloc(int addr, reltype)=
	ref basereloc p

	p:=pcm_allocz(basereloc.bytes)
	p.address:=addr
	p.reloctype:=reltype

	p.nextitem:=basereloclist

	basereloclist:=p
	++nbaserelocs
	maxrelocaddr max:=addr

end

proc scanbaserelocs=
	int baseaddr,addr,nextblock
	ref basereloc p

	baseaddr:=0x1000
	nbaseblocks:=0

	repeat
		nextblock:=baseaddr+0x1000
		if nbaseblocks>=maxbaseblock then gerror("Too many blocks") fi
		++nbaseblocks
		blockbases[nbaseblocks]:=baseaddr
		blockcounts[nbaseblocks]:=0


		p:=basereloclist
		while p do
			addr:=p.address
			if addr>=baseaddr and addr<nextblock then
				++blockcounts[nbaseblocks]
			fi

			p:=p.nextitem
		od

		baseaddr:=nextblock
	until baseaddr>maxrelocaddr

	for i to nbaseblocks when blockcounts[i] do
		if blockcounts[i].odd then
			++blockcounts[i]
			++blockpadding[i]
		fi
		blockbytes[i]:=blockcounts[i]*2+8
		basetablesize+:=blockbytes[i]
	od
end

proc writebasereloctable(ref byte pstart)=
	
	ref word32 p32
	ref word16 p16
	int baseaddr,addr,nextblock
	ref basereloc q

	p32:=cast(pstart)

	for i to nbaseblocks when blockcounts[i] do
		p32^:=blockbases[i]
		++p32
		p32^:=blockbytes[i]
		++p32
		p16:=cast(p32)

		q:=basereloclist
		baseaddr:=blockbases[i]
		nextblock:=baseaddr+4096

		while q do
			addr:=q.address
			if addr>=baseaddr and addr<nextblock then
				p16^:=addr-baseaddr+(q.reloctype=addr32_rel|3|10)<<12
				++p16
			fi
			q:=q.nextitem
		od
		if blockpadding[i] then p16++^:=0 fi

		p32:=cast(p16)

	od
end

proc sortexports([]int &sortindex)=
	ref pstrec d,e
	for i to nexports do
		sortindex[i]:=i
	od

	int swapped

	repeat
		swapped:=0
		for i:=1 to nexports-1 do

			d:=exporttable[sortindex[i]].def
			e:=exporttable[sortindex[i+1]].def

			if strcmp(d.name, e.name)>0 then
				swapped:=1
				swap(sortindex[i], sortindex[i+1])
			fi
		od
	until not swapped

end

function getsectionno(int segment)int=
	case segment
	when zdata_seg then zsect
	when idata_seg then dsect
	when code_seg then csect
	else gerror("GSN"); 0
	esac
end

=== ma_writess.m 35/40 ===
import clib
import mlib
import oslib
import ma_objdecls
import bb_tables
import ma_decls
import ma_lib
import ma_disasm
import bb_mcldecls

import ma_writeexe

global function writessdata(int fexe)ref strbuffer=
	gs_init(dest)
	showssdata(fexe)

	gs_line(dest)
	return dest
end

proc showssdata(int fexe)=
gs_strln(dest,(fexe|"EXE FORMAT"|"AFTER GENSS"))

	showsections()

	gs_line(dest)

	showsectionrelocs2("Idata",ss_idatarelocs,ss_nidatarelocs)
	showsectionrelocs2("Code",ss_coderelocs,ss_ncoderelocs)

	gs_str(dest,"proc Section Zdata: ")
	gs_strint(dest,ss_zdatalen)
	gs_line(dest)

	showsectiondata(&sectiontable[dsect])
	showsectioncode(&sectiontable[csect])
	if fexe then
		showsectiondata(&sectiontable[isect])
	fi

	showsymboltable2()
	showimporttable()
	gs_strln(dest,"END OF GENSS")

end

proc showsectiondata(ref sectionrec d)=
int i,k,length,bb
	[128]char str,str2
	ref byte p

	gs_str(dest,"proc Section ")
	gs_str(dest,d^.name)
	gs_str(dest," Size:")
	gs_strint(dest,d^.virtsize)
	gs_line(dest)
	gs_line(dest)

	k:=0
	if d^.segtype<>impdata_seg then
		p:=bufferelemptr(d^.data,0)
	else
		p:=d^.bytedata
	fi
	length:=d^.virtsize

	str[1]:=0

	ref byte baseaddr:=cast(imagebase+d^.virtoffset)

	print @&.str2,baseaddr:"Z8H",,": "

	gs_str(dest,&.str2)

	for i:=1 to length do
		bb:=p++^
		print @&.str2,bb:"z2H",," "
		gs_str(dest,&.str2)

		if 32<=bb<=127 then
			str2[1]:=bb
			str2[2]:=0
			strcat(&.str,&.str2)
		else
			strcat(&.str,".")
		fi
		if ++k=16 or i=length then
			if k<16 then
				to 16-k do
					gs_str(dest,"   ")
					strcat(&.str," ")
				od
			fi
			gs_str(dest,"	[")
			gs_str(dest,&.str)
			gs_strln(dest,"]")
			k:=0
			str[1]:=0
			baseaddr+:=16
			print @&.str2,baseaddr:"z8h",,": "
			gs_str(dest,&.str2)
		fi
	od
	if k=0 then
		gs_line(dest)
	fi

	gs_line(dest)
	if k then gs_line(dest) fi
end

proc showsectioncode(ref sectionrec p)=
ref byte codeptr,codeend,codestart
	int length,offset
	ichar s
	[16]char str

	gs_strln(dest, "proc Section Code")

	length:=p^.virtsize
	codestart:=codeptr:=bufferelemptr(p^.data,0)
	codeend:=codeptr+length

	ref byte baseaddr:=cast(imagebase+p^.virtoffset)

	while codeptr<codeend do
		offset:=codeptr-codestart
		s:=decodeinstr(codeptr,baseaddr+offset)
		exit when s=nil

		print @&.str,offset:"4",," "
		gs_str(dest,&.str)

		gs_strln(dest,s)
	od

	gs_line(dest)
end

proc showsectionrelocs2(ichar caption,ref relocrec relocs, int nrelocs)=
	ref relocrec r

	gs_str(dest,"proc Section Relocs: ")
	gs_str(dest,caption)
	gs_str(dest," ")
	gs_strint(dest,nrelocs)
	gs_line(dest)

	r:=relocs

	while r do

		gs_str(dest,"Reloc: ")
		gs_str(dest,relocnames[r^.reloctype])
		gs_str(dest," Offset: ")
		gs_strint(dest,r^.offset)
		gs_str(dest," ST Index: ")
		gs_strint(dest,r^.stindex)
		gs_str(dest," ")
		gs_str(dest,ss_symboltable^[r^.stindex]^.name)
		gs_line(dest)

		r:=r^.nextreloc
	od
	gs_line(dest)

end

proc gs_value(ichar caption, int64 value)=
	[256]char str

	strcpy(&.str,caption)
	strcat(&.str,":")
	ipadstr(&.str,20)
	gs_str(dest,&.str)

	fprint @&.str,"0x# #",value:"H",value
	gs_strln(dest,&.str)
end

proc showsymboltable2=

	gs_strln(dest,"Proc Symbol Table")
	int i
	for i:=1 to ss_nsymbols do
		gs_strint(dest,i)
		gs_str(dest,": ")
		gs_strln(dest,ss_symboltable^[i]^.name)
	od
	gs_line(dest)
end

proc showimporttable=
	[256]char str
	dllrec d
	importrec p


	gs_strln(dest,"Proc Dll List")
	int i
	for i:=1 to ndlls do
		gs_strint(dest,i)
		gs_str(dest,": ")
		gs_str(dest,dlltable[i].name)
		gs_str(dest," ")
		gs_strint(dest,dlltable[i].nprocs)
		gs_line(dest)
		gs_value("		Name Table Offset",dlltable[i].nametableoffset)
		gs_value("		Addr Table Offset",dlltable[i].addrtableoffset)
		gs_value("		DLL Name Offset  ",dlltable[i].dllnameoffset)
	od
	gs_line(dest)
	gs_strln(dest,"Proc Import List")

	for i:=1 to nimports do
		p:=importtable[i]

		gs_strint(dest,i)
		gs_str(dest,": ")
		if p.libno then
			strcpy(&.str,p.name)
			ipadstr(&.str,16)
			gs_str(dest,&.str)
			gs_str(dest," (")
			gs_str(dest,dlltable[p.libno].name)
			gs_strln(dest,")")

			gs_value("	IAT Offset        ",p.iatoffset)
			gs_value("	Thunk Offset      ",p.thunkoffset)
			gs_value("	Hint/Name Offset  ",p.hintnameoffset)

		else
			strcpy(&.str,p.name)
			ipadstr(&.str,20)
			gs_str(dest,&.str)
			gs_strln(dest," (---)")
		fi
	od
	gs_line(dest)
end

proc showsections=
	sectionrec s
	int i

	gs_strln(dest,"proc Section Headersxxx")
	gs_line(dest)

	for i:=1 to nsections do
		s:=sectiontable[i]

		gs_str(dest,"Section ")
		gs_strint(dest,i)
		gs_str(dest,": ")
		gs_str(dest,s.name)
		gs_str(dest,"  (")
		gs_str(dest,segmentnames[s.segtype])
		gs_strln(dest,")")

		gs_value("    Raw Offset",s.rawoffset)
		gs_value("    Raw Size",s.rawsize)
		gs_value("    Virtual Offset",s.virtoffset)
		gs_value("    Virtual Size",s.virtsize)
		gs_value("    Nrelocs",s.nrelocs)
		gs_value("    Data",int(s.data))
		gs_line(dest)

	od
end

=== ma_disasm.m 36/40 ===
import clib
import msys
import oslib

const showmregs=1

const halt=0xF4

int abc
real xyz

int res2
int lx

int nmodules
int xfchsmask_pd

tabledata() [0:]ichar opnames =
	(add_op=0,	"add"),
	(or_op,		"or"),
	(adc_op,	"adc"),
	(sbb_op,	"sbb"),
	(and_op,	"and"),
	(sub_op,	"sub"),
	(xor_op,	"xor"),
	(cmp_op,	"cmp")
end

[0:]ichar condnames = 
("o", "no", "b","ae","z","nz","be","a","s","ns","p","np",
 "l","ge","le","g")

tabledata() []ichar addrmodenames=		! rm modes
	(amreg,			$),				! R
	(ammem,			$),				! [R+d]
	(amrel,			$)				! [RIP+d]
end

const wmask = 2x1000
const rmask = 2x0100
const xmask = 2x0010
const bmask = 2x0001

const rstack=5						!1-base register codes
const rframe=6

int rex

int addrmode						!amreg/ammem/amrel
int rmreg							!0, or 1..16; adjusted middle value of modrm byte
int rmopc							!0 to 7; middle value of modrm byte 
int basereg							!0, or 1..16
int indexreg						!0, or 1..16
int scale							!1,2,4
int opsize							!1,2,4,8
int offset
int offsetsize						!1 or 4
int sizeoverride					!32=>16 switch
int addroverride					!32=>16 switch
int f2override						!xmm regs
int f3override						!xmm regs

[256]char deststr
ichar destptr


ref byte codeptr

global function decodeinstr(ref byte &cptr,baseaddr=nil)ichar=
int n,w
int opc,reg,op,xxx,oldopsize,dispsize
ref byte pstart
static [256]char str
[128]char str2
const maxinstrlen=14
ichar s

deststr[1]:=0

pstart:=codeptr:=cptr

rex:=0
opsize:=1
f2override:=f3override:=sizeoverride:=addroverride:=0
basereg:=indexreg:=offset:=0

retry::						!back here after prefix byte seen

switch opc:=codeptr++^
when 0x00,0x1, 0x08,0x9, 0x10,0x11, 0x18,0x19,
					0x20,0x21, 0x28,0x29, 0x30,0x31, 0x38,0x39 then	!arith R/M, R
	op:=opc>>3
	decodeaddr(opc iand 1)
	getsilx(basereg)
	getsil(rmreg)
	genstr(opnames[op])
	printaddrmode()
	genstr(", ")
	genstr(strreg(rmreg,opsize))

when 0x02,0x3, 0x0A,0xB, 0x12,0x13, 0x1A,0x1B,
					0x22,0x23, 0x2A,0x2B, 0x32,0x33, 0x3A,0x3B then	!arith R,R/M
	op:=opc>>3
	decodeaddr(opc iand 1)
	genstr(opnames[op])
	genstr(" ")
	getsil(rmreg)
	genstr(strreg(rmreg,opsize))
	genstr(", ")
	printaddrmode()

when 0x04,0x5, 0x0C,0xD, 0x14,0x15, 0x1C,0x1D,
					0x24,0x25, 0x2C,0x2D, 0x34,0x35, 0x3C,0x3D then	!arith rAX,imm
	genstr(opnames[opc>>3])
	genstr(" ")
	if opc iand 1 then
		opsize:=4
		if sizeoverride then opsize:=2 fi
		if rex iand wmask then opsize:=8 fi
	fi
	genstr(strreg(1,opsize))
	genstr(", ")
	genintd(readimm())

when 0x0F then
	decodetwobyteinstr()

when 0x40 .. 0x4F then
	rex:=opc

	goto retry

when 0x50 .. 0x57 then
	reg:=getreg(opc iand 7,rex iand bmask)
	genstr("push ")
	genstr(strreg(reg,8))

when 0x58 .. 0x5F then
	reg:=getreg(opc iand 7,rex iand bmask)
	genstr("pop ")
	genstr(strreg(reg,8))

when 0x63 then
	decodeaddr(1)
	genstr("movsxd ")
	genstr(strreg(rmreg,opsize))
	genstr(", ")
	opsize:=4
	printaddrmode()

when 0x66 then
	sizeoverride:=1
	goto retry

when 0x67 then
	addroverride:=1
	goto retry

when 0x68 then
	genstr("push ")
	genintd(readint32())

when 0x6A then
	genstr("push ")
	genintd(readsbyte())

when 0x69, 0x6B then
	decodeaddr(1)
	if basereg<>rmreg then
		genstr("imul3")
		genstr(" ")
		genstr(strreg(rmreg,opsize))
		genstr(", ")
	else
		genstr("imul2")
	fi
	printaddrmode()
	genstr(", ")
	opsize:=(opc iand 2|1|opsize)
	genintd(readimm())

when 0x70..0x7F then
	genstr("j")
	genstr(condnames[opc iand 15])
	genstr(" ")
	genintd(readsbyte())

when 0x80..0x83 then			!arith r/m,imm
	decodeaddr(opc iand 1)
	genstr(opnames[rmopc])
	getsilx(basereg)
	printaddrmode()
	genstr(", ")
	if opc<>0x83 then
		genintd(readimm())
	else
		genintd(readsbyte())
	fi

when 0x84, 0x85 then			!test reg,reg/mem
	decodeaddr(opc iand 1)
	getsilx(basereg)
	getsil(rmreg)
	genstr("test ")
	printaddrmode()
	genstr(", ")
	genstr(strreg(rmreg,opsize))

when 0x86,0x87 then				!complex excg
	decodeaddr(opc iand 1)
	genstr("exch2 ")
	getsilx(basereg)
	getsil(rmreg)
	genstr(strreg(rmreg,opsize))
	genstr(",")
	printaddrmode()

when 0x88, 0x89 then			!mov r/m,reg
	decodeaddr(opc iand 1)
	genstr("mov")
	getsilx(basereg)
	getsil(rmreg)

	printaddrmode()
	genstr(", ")
	genstr(strreg(rmreg,opsize))

when 0x8A, 0x8B then			!mov reg,r/m
	decodeaddr(opc iand 1)
	genstr("mov ")
	getsilx(basereg)
	getsil(rmreg)
	genstr(strreg(rmreg,opsize))
	genstr(", ")
	printaddrmode()

when 0x8D then
	decodeaddr(1)
	genstr("lea ")
	genstr(strreg(rmreg,opsize))
	genstr(", ")
	printaddrmode()

when 0x8F then
	decodeaddr(1)
	opsize:=1
	genstr("pop")
	printaddrmode()

when 0x90 then
	if rex then goto doexch fi
	genstr("nop")

when 0x91..0x97 then			!exch eax/reg
doexch::
	reg:=(opc iand 7)+1
	if rex iand bmask then reg+:=8 fi
	opsize:=(sizeoverride|2|4)
	if rex iand wmask then opsize:=8 fi
	genstr("xchg ")
	genstr(strreg(1,opsize))
	genstr(", ")
	genstr(strreg(reg,opsize))

when 0x98 then
	if sizeoverride then
		genstr("cbw")
	else
		genstr("cbw???")
	fi
when 0x99 then
	if sizeoverride then
		genstr("cwd")
	elsif rex iand wmask then
		genstr("cqo")
	else
		genstr("cdq")
	fi
when 0x9B then genstr("wait")

when 0x9C then genstr("pushf")
when 0x9D then genstr("popf")
when 0x9E then genstr("sahf")
when 0x9F then genstr("lahf")

when 0xA4..0xA7, 0xAA..0xAF then
	genstr((opc>>1 iand 7|"?","movs","cmps","?","stos","lods","scas"|"?"))
	if opc iand 1=0 then
		genstr("b")
	else
		if rex iand wmask then
			genstr("q")
		elsif sizeoverride then
			genstr("w")
		else
			genstr("d")
		fi
	fi

when 0xA8, 0xA9 then				!test r0,imm
	genstr("test ")
	if opc iand 1 then
		opsize:=(sizeoverride |2|4)
		if rex iand wmask then opsize:=8 fi
	fi
	genstr(strreg(1,opsize))
	genstr(", ")
	genintd(readimm())

when 0xB0..0xBF then			!mov reg,imm
	reg:=(opc iand 7)+1
	if rex iand bmask then reg+:=8 fi
	if (opc iand 2x1000) then
		opsize:=(sizeoverride |2|4)
		if rex iand wmask then opsize:=8 fi
	fi
	genstr("mov ")
	getsil(reg)

	genstr(strreg(reg,opsize))
	genstr(", ")
	genintd(readimm8())

when 0xC0, 0xC1, 0xD0..0xD3 then
	decodeaddr(opc iand 1)
	getsilx(basereg)
	genstr((rmopc+1|"rol","ror","rcl","rcr","shl","shr","?","sar"|"?"))
	printaddrmode()
	if opc<=0xC1 then
		genstr(", ")
		genintd(readbyte())
	else
		genstr((opc iand 2|", cl"|", 1"))
	fi

when 0xC2 then
	genstr("retn ")
	genintd(readword16())

when 0xC3 then
	genstr("ret")

when 0xC6,0xC7 then
	decodeaddr(opc iand 1)
	genstr("mov")
	printaddrmode()
	genstr(", ")
	genintd(readimm())

when 0xD7 then genstr("xlat")

when 0xD8..0xDF then
	decode8087(opc iand 7)

when 0xE0 then genstr("loopnz "); genintd(readsbyte())
when 0xE1 then genstr("loopz "); genintd(readsbyte())
when 0xE2 then genstr("loop "); genintd(readsbyte())

when 0xE3 then
	if addroverride then
		genstr("jecxz ")
	else
		genstr("jrcxz ")
	fi
	genintd(readsbyte())

when 0xE8 then
	genstr("call ")
	genintd(readint32())

when 0xE9 then
	genstr("[4] jmp ")
	genintd(readint32())

when 0xEB then
	genstr("jmp ")
	genintd(readsbyte())

when 0xF2 then
	if codeptr^<>0x0F and (codeptr^<0x40 and codeptr^>0x4F) then
		genstr("repne")
	else
		f2override:=1
		goto retry
	fi
when 0xF3 then
	if codeptr^<>0x0F and (codeptr^<0x40 and codeptr^>0x4F) then
		genstr("repe")
	else
		f3override:=1
		goto retry
	fi

when 0xF4 then
	return nil

when 0xF6,0xF7 then
	decodeaddr(opc iand 1)
	getsilx(basereg)
	genstr((rmopc+1|"test","?","not","neg","mul","imul","div","idiv"|"?"))
	printaddrmode()
	if rmopc=0 then
		if opsize=8 then opsize:=4 fi
		genstr(", ")
		genintd(readimm())
	fi

when 0xFE then
	w:=0
	goto doff

when 0xFF then			!various
	w:=1
doff::
	decodeaddr(w)
	case rmopc
	when 2x_000 then	!inc
		getsilx(basereg)
		genstr("inc")
	when 2x_001 then	!dec
		getsilx(basereg)
		genstr("dec")
	when 2x_010 then	!call
		opsize:=8
		genstr("icall")
	when 2x_100 then	!jmp
		opsize:=8
		genstr("jmp")
	when 2x_110 then	!push
		opsize:=8
		genstr("push")
	else
genstr("FFXX")
		println "FFxx?"
	esac
	printaddrmode()

else
	genstr("Unknown opcode: ")
    genhex(opc)
endswitch


if baseaddr then
	print @&.str,baseaddr:"z6h",,": "
else
	print @&.str,pstart:"z6h",,": "
fi

n:=codeptr-pstart
to n do
	print @&.str2,int(pstart++^):"z2H",," "

	strcat(&.str,&.str2)
od
to maxinstrlen-n do
	strcat(&.str,"-- ")
od
strcat(&.str,&.deststr)

cptr:=codeptr

return &.str
end

proc decodetwobyteinstr=
int opc,rhssize,third,imm
ichar opcstr

switch opc:=codeptr++^
when 0x2A then					!cvtsi2ss/sd XMM, REG/MEM
	decodeaddr(1)
	if f3override then
		genstr("cvtsi2ss ")
	else
		genstr("cvtsi2sd ")
	fi
	genstr(strxmm(rmreg))
	genstr(", ")
	printaddrmode(0)
	
when 0x2C then					!cvt2ss/sd2si XMM, REG/MEM
	decodeaddr(1)
	if f3override then
		genstr("cvttss2si ")
		rhssize:=4
	else
		genstr("cvttsd2si ")
		rhssize:=8
	fi
	if rex iand wmask then
		genstr(strreg(rmreg,8))
	else
		genstr(strreg(rmreg,4))
	fi
	genstr(", ")
	opsize:=rhssize
	printaddrmode(1)

when 0x2D then					!cvt2ss/sd2si XMM, REG/MEM
	decodeaddr(1)
	if f3override then
		genstr("cvtss2si ")
		rhssize:=4
	else
		genstr("cvtsd2si ")
		rhssize:=8
	fi
	if rex iand wmask then
		genstr(strreg(rmreg,8))
	else
		genstr(strreg(rmreg,4))
	fi
	genstr(", ")
	opsize:=rhssize
	printaddrmode(1)

when 0x2F then					!comiss/comisd XMM, REG/MEM
	decodeaddr(1)
	if sizeoverride then
		opsize:=8
		genstr("comisd ")
	else
		opsize:=4
		genstr("comiss ")
	fi
	genstr(strxmm(rmreg))
	genstr(", ")
	printaddrmode(1)

when 0x3A then					!possible pcmpistri
	third:=codeptr++^

	case third
	when 0x63 then
		genstr("pcmpistri ")
	else
		genstr("Unknown opcode 2-byte opcode: 0F ")
	    genhex(opc)
		return
	esac

	decodeaddr(1)
	genstr(strxmm(rmreg))
	genstr(", ")
	printaddrmode(1)
	genstr(", ")
	imm:=codeptr++^
	genintd(imm)

when 0x40..0x4F then
	decodeaddr(1)
	genstr("cmov")
	genstr(condnames[opc iand 15])
	genstr(" ")
	genstr(strreg(rmreg,opsize))
	genstr(", ")
	printaddrmode()

when 0x51 then					!sqrtss/sd
	decodeaddr(1)
	opsize:=(f3override|4|8)
	genstr((opsize=4|"sqrtss "|"sqrtsd "))
	genstr(strxmm(rmreg))
	genstr(", ")
	printaddrmode(1)

when 0x54 then					!ANDPD
	decodeaddr(1)
	genstr((sizeoverride|"andpd "|"andps "))
	genstr(strxmm(rmreg))
	genstr(", ")
	opsize:=(sizeoverride|8|4)
	printaddrmode(1)

when 0x57 then					!XORPD
	decodeaddr(1)
	genstr((sizeoverride|"xorpd "|"xorps "))
	genstr(strxmm(rmreg))
	genstr(", ")
	opsize:=(sizeoverride|8|4)
	printaddrmode(1)

when 0x58 then					!addss/addsd
	opcstr:="adds"
doarith::
	genstr(opcstr)
	decodeaddr(1)
	if f2override then
		opsize:=8
		genstr("d ")
	else
		opsize:=4
		genstr("s ")
	fi
	genstr(strxmm(rmreg))
	genstr(", ")
	printaddrmode(1)

when 0x59 then					!mulss/mulsd
	opcstr:="muls"
	goto doarith

when 0x5A then					!cvtss2sd/cvtsd2ss
	decodeaddr(1)
	if f3override then
		genstr("cvtss2sd ")
		rhssize:=4
	else
		genstr("cvtsd2ss ")
		rhssize:=8
	fi
	genstr(strxmm(rmreg))
	genstr(", ")
	opsize:=rhssize
	printaddrmode(1)

when 0x5C then					!subss/subsd
	opcstr:="subs"
	goto doarith

when 0x5D then
	opcstr:="mins"
	goto doarith

when 0x5E then					!divss/divsd
	opcstr:="divs"
	goto doarith

when 0x5F then
	opcstr:="maxs"
	goto doarith


when 0x6E then					!mov X/MM, REG/MEM
	decodeaddr(1)
	opsize:=(rex iand wmask|8|4)
	genstr((opsize=4|"movd "|"movq "))
	if sizeoverride then		!xmm
		genstr(strxmm(rmreg))
	else
		genstr(strmmx(rmreg))
	fi
	genstr(", ")
	printaddrmode()

when 0x6F then					!movdqa/dqu, X/MEM, X/X
	decodeaddr(1)
	opsize:=16
	if sizeoverride then		!66
		genstr("movdqa ")
	elsif f3override then		!F3
		genstr("movdqu ")
	else
		genstr("No 66/F3 ")
	fi
	genstr(strxmm(rmreg))
	genstr(", ")
	printaddrmode(1)

when 0x7E then					!mov REG/MEM, X/MM
	decodeaddr(1)
	if f3override then
		opsize:=8
		genstr("movq ")
		genstr(strxmm(rmreg))
		genstr(", ")
		printaddrmode(1)
	elsif rex iand wmask then
		opsize:=8
		genstr("movq ")
		printaddrmode()
		genstr(", ")
		genstr(strxmm(rmreg))
	else
		opsize:=4
		genstr("movd ")
		printaddrmode()
		genstr(", ")
		if sizeoverride then		!xmm
			genstr(strxmm(rmreg))
		else
			genstr(strmmx(rmreg))
		fi
	fi

when 0x7F then					!movdqa/dqu, MEM/X
	decodeaddr(1)
	opsize:=16
	if sizeoverride then		!66
		genstr("movdqa ")
	elsif f3override then		!F3
		genstr("movdqu ")
	else
		genstr("No 66/F3 ")
	fi
	printaddrmode(1)
	genstr(", ")
	genstr(strxmm(rmreg))

when 0x80..0x8F then			!long rel jumps
	genstr("[long] j")
	genstr(condnames[opc iand 15])
	genstr(" ")
	if sizeoverride then
		genintd(readint16())
	else
		genintd(readint32())
	fi

when 0x90..0x9F then
	decodeaddr(0)
	genstr("set")
	genstr(condnames[opc iand 15])
	genstr(" ")
	getsilx(basereg)
	printaddrmode()

when 0xAF then
	decodeaddr(1)
	genstr("imul ")
	genstr(strreg(rmreg,opsize))
	genstr(", ")
	printaddrmode()

when 0xB6, 0xB7, 0xBE, 0xBF then
	decodeaddr(1)
	genstr((opc<0xBE|"movzx "|"movsx "))
	genstr(strreg(rmreg,opsize))
	genstr(", ")
	opsize:=(opc iand 1|2|1)
	printaddrmode()

when 0xB8 then
	decodeaddr(1)
	genstr("popcnt ")
	genstr(strreg(rmreg,opsize))
	genstr(", ")
	printaddrmode()

when 0xD6 then
	decodeaddr(1)
	opsize:=8
	genstr("movq ")
	printaddrmode(1)
	genstr(",")
	genstr(strxmm(rmreg))	

when 0xDB then					!PAND
	decodeaddr(1)
	genstr("pand ")
	genstr(strxmm(rmreg))
	genstr(", ")
	opsize:=8	!(sizeoverride|8|4)
	printaddrmode(1)

when 0xEF then					!PXOR
	decodeaddr(1)
	genstr("pxor ")
	genstr(strxmm(rmreg))
	genstr(", ")
	opsize:=8	!(sizeoverride|8|4)
	printaddrmode(1)

else
	genstr("Unknown opcode 2-byte opcode: 0F ")
    genhex(opc)
endswitch
end

proc decodeaddr(int w=0)=
int modrm,xxx,mode,sib,rm

basereg:=indexreg:=0
scale:=1
offset:=0
if w then
	opsize:=(sizeoverride|2|4)
	if rex iand wmask then opsize:=8 fi
else
	opsize:=1
fi

modrm:=codeptr++^

mode:=modrm>>6
xxx:=(modrm>>3) iand 7
rm:=modrm iand 7


if mode=3 then		!plain register access
	basereg:=rm+1
	addrmode:=amreg


elsif rm<>4 then				!not esp; no sib
	if mode=0 and rm=5 then		![ebp] is actually [rip+disp]
		offset:=readint32()
		addrmode:=ammem

	else
		basereg:=rm+1
		addrmode:=ammem
		case mode
		when 1 then
			offset:=readsbyte()
		when 2 then
			offset:=readint32()
		esac
	fi
else			!sib follows
	addrmode:=ammem
	sib:=readbyte()
	indexreg:=((sib>>3) iand 7)+1
	basereg:=(sib iand 7)+1
	scale:=(sib>>6+1|1,2,4,8|0)

	if mode=0 and basereg=rframe then	!no base register, only index; disp is 32bits
		basereg:=0
		offset:=readint32()

	else
		case mode
		when 1 then
			offset:=readsbyte()
		when 2 then
			offset:=readint32()
		esac
	fi

	if indexreg=rstack then				!stack means no index reg
		indexreg:=0
	fi

fi

if basereg and rex iand bmask then basereg+:=8 fi
if indexreg and rex iand xmask then indexreg+:=8 fi

rmreg:=xxx+1
if rex iand rmask then rmreg+:=8 fi
rmopc:=xxx
end

function readbyte:int=
return codeptr++^
end

function readsbyte:int=
return (ref int8(codeptr++))^
end

function readword16:word=
word a
a:=ref word16(codeptr)^
codeptr+:=2
return a
end

function readint16:int=
int a
a:=ref int16(codeptr)^
codeptr+:=2
return a
end

function readword32:word=
word a
a:=ref word32(codeptr)^
codeptr+:=4
return a
END

function readint32:int=
int a
a:=ref int32(codeptr)^
codeptr+:=4
return a
END

function readint64:int64=
int64 a
a:=ref int64(codeptr)^
codeptr+:=8
return a
END

function getreg(int regcode,upper)int=
if upper then
	return regcode+8+1
fi
return regcode+1
end

function strreg(int reg,opsize)ichar=
static []ichar regnames8=("al","cl","dl","bl","ah","ch","dh","bh",
						"r8b","r9b","r10b","r11b","r12b","r13b","r14b","r15b",
				"spl","bpl","sil","dil")

static []ichar regnames16=("ax","cx","dx","bx","sp","bp","si","di",
						"r8w","r9w","r10w","r11w","r12w","r13w","r14w","r15w")

static []ichar regnames32=("eax","ecx","edx","ebx","esp","ebp","esi","edi",
						"r8d","r9d","r10d","r11d","r12d","r13d","r14d","r15d")

static []ichar regnames64=("rax","rcx","rdx","rbx","rsp","rbp","rsi","rdi",
						"r8","r9","r10","r11","r12","r13","r14","r15")

static []ichar mregnames8=("B0","B10","B11","B1","B16","B18","B19","B17",
						"B12","B13","B4","B5","B6","B7","B8","B9",
					"B14","B15","B2","B3")

static []ichar mregnames16=("W0","W10","W11","W1","Wsp","Wbp","W2","W3",
						"W12","W13","W4","W5","W6","W7","W8","W9")

static []ichar mregnames32=("A0","A10","A11","A1","Astack","Aframe","A2","A3",
						"A12","A13","A4","A5","A6","A7","A8","A9")

static []ichar mregnames64=("D0","D10","D11","D1","Dstack","Dframe","D2","D3",
						"D12","D13","D4","D5","D6","D7","D8","D9")

if reg=0 then return "<>" fi

if showmregs then
	case opsize
	when 1 then return mregnames8[reg]
	when 2 then return mregnames16[reg]
	when 4 then return mregnames32[reg]
	when 8 then return mregnames64[reg]
	esac
else
	case opsize
	when 1 then return regnames8[reg]
	when 2 then return regnames16[reg]
	when 4 then return regnames32[reg]
	when 8 then return regnames64[reg]
	esac
fi
return ""
end

function strfreg(int freg)ichar=
static []ichar fregnames=("st0","st1","st2","st3","st4","st5","st6","st7")
return fregnames[freg]
end

proc printaddrmode(int xmm=0)=
static [100]char str
ichar plus
int addrsize

genstr(" ")

case addrmode
when amreg then
	if xmm then
		genstr(strxmm(basereg))
	else
		getsilx(basereg)
		genstr(strreg(basereg,opsize))
	fi
	return
esac

case opsize
when 1 then genstr("byte ")
when 2 then genstr("word ")
when 4 then genstr("dword ")
when 8 then genstr("qword ")
when 10 then genstr("tword ")
when 16 then genstr("oword ")
else
CPL "///OPSIZE",opsize
esac

genstr("[")
plus:=""
addrsize:=(addroverride|4|8)

if basereg then
	genstr(strreg(basereg,addrsize))
	plus:="+"
fi
if indexreg then
	genstr(plus)
	genstr(strreg(indexreg,addrsize))
	if scale>1 then
		genstr("*")
		genintd(scale)
	fi
	plus:="+"
fi

if offset or (basereg=0 and indexreg=0) then
	if basereg=0 and indexreg=0 then
		genhex(offset)
	else
		if offset>0 then genstr(plus) fi
		genintd(offset)
	fi
fi
genstr("]")
if addrmode=amrel then genstr("+RIP") fi
end

proc genstr(ichar s)=
strcat(&.deststr,s)
end

proc genintd(int64 a)=
genstr(strint(a))
end

proc genhex(int64 a)=
genstr(strint(a,"h"))
end

function readimm:int=

case opsize
when 1 then return readsbyte()
when 2 then return readint16()
when 4,8 then return readint32()			!64-bit uses 32-bit immediate
esac
return 0
end

function readimm8:int64=
if opsize<8 then return readimm() fi

return readint64()
end

function strxmm(int reg)ichar=
static [32]char str

print @&.str,"xmm",,reg-1
return &.str
end

function strmmx(int reg)ichar=
static [32]char str

print @&.str,"mmx",,reg-1
return &.str
end

proc decode8087(int ttt)=
byte bb
int longopc,freg,shortopc,code

bb:=codeptr++^			!following byte

longopc:=ttt<<8+bb		!bottom 11 bits of 2-bytes opcode
freg:=(bb iand 7)+1		!where bb specifies a register in bottom 3 bits


case longopc
when 2x'110'1101'1001 then genstr("fcompp")
when 2x'001'1110'0100 then genstr("ftst")
when 2x'001'1110'0101 then genstr("fxam")
when 2x'001'1110'1110 then genstr("fldz")
when 2x'001'1110'1000 then genstr("fld1")
when 2x'001'1110'1011 then genstr("fldpi")
when 2x'001'1110'1001 then genstr("fldl2t")
when 2x'001'1110'1010 then genstr("fldl2e")
when 2x'001'1110'1100 then genstr("fldlg2")
when 2x'001'1110'1101 then genstr("fldln2")

when 2x'001'1111'1010 then genstr("fsqrt")
when 2x'001'1111'1110 then genstr("fsin")
when 2x'001'1111'1111 then genstr("fcos")
when 2x'001'1111'1011 then genstr("fsincos")
when 2x'001'1111'1101 then genstr("fscale")
when 2x'001'1111'1000 then genstr("fprem")
when 2x'001'1111'1100 then genstr("frndint")
when 2x'001'1111'0100 then genstr("fxtract")
when 2x'001'1110'0001 then genstr("fabs")
when 2x'001'1110'0000 then genstr("fchs")

when 2x'001'1111'0010 then genstr("fptan")
when 2x'001'1111'0011 then genstr("fpatan")
when 2x'001'1111'0000 then genstr("f2xm1")
when 2x'001'1111'0001 then genstr("fyl2x")
when 2x'001'1111'1001 then genstr("fyl2xp1")

when 2x'011'1110'0011 then genstr("finit")
when 2x'011'1110'0000 then genstr("feni")
when 2x'011'1110'0001 then genstr("fdisi")

when 2x'011'1110'0010 then genstr("fclex")

when 2x'001'1111'0111 then genstr("fincstp")
when 2x'001'1111'0110 then genstr("fdecstp")
when 2x'001'1101'0000 then genstr("fnop")

elsecase longopc iand 2x'111'11111'000			!ignore bottom 3 bits

when 2x'001'11000'000 then genstr("fld "); genstr(strfreg(freg))
when 2x'101'11010'000 then genstr("fst "); genstr(strfreg(freg))
when 2x'101'11011'000 then genstr("fstp "); genstr(strfreg(freg))
when 2x'001'11001'000 then genstr("fxch "); genstr(strfreg(freg))
when 2x'000'11010'000 then genstr("fcom "); genstr(strfreg(freg))
when 2x'000'11011'000 then genstr("fcomp "); genstr(strfreg(freg))
when 2x'101'11000'000 then genstr("ffree "); genstr(strfreg(freg))

elsecase longopc iand 2x'001'11111'000			!ignore bottom 3 bits and top 2

when 2x'000'11000'000 then do87arith("fadd",ttt,freg)

when 2x'000'11100'000 then do87arith("fsub",ttt,freg)
when 2x'000'11101'000 then do87arith("fsubr",ttt,freg)

when 2x'000'11001'000 then do87arith("fmul",ttt,freg)

when 2x'000'11110'000 then do87arith("fdiv",ttt,freg)
when 2x'000'11111'000 then do87arith("fdivr",ttt,freg)

else	!finally, have to deal with modrm etc
	--codeptr					!put back modrm byte
	decodeaddr(0)			!code is middle bits
	shortopc:=ttt<<3 + rmopc

	case shortopc				!look at combination of ttt and code (middle bits of modrm)
	when 2x'111'101 then do87mem("fld",4)
	when 2x'011'101 then do87mem("fld",5)
	when 2x'111'100 then do87mem("fldbcd")

	when 2x'111'111 then do87mem("fstp",4)
	when 2x'011'111 then do87mem("fstp",5)
	when 2x'111'110 then do87mem("fstpbcd")

	when 2x'001'101 then do87mem("fldcw")
	when 2x'001'111 then do87mem("fstcw")
	when 2x'101'111 then do87mem("fstsw")

	when 2x'001'110 then do87mem("fstenv")
	when 2x'001'100 then do87mem("fldenv")
	when 2x'101'110 then do87mem("fsave")
	when 2x'101'100 then do87mem("frstor")

	elsecase shortopc iand 2x001'111		!ignore top two bits (mf code)

	when 2x'001'000 then do87mem("fld",ttt>>1)
	when 2x'001'010 then do87mem("fst",ttt>>1)
	when 2x'001'011 then do87mem("fstp",ttt>>1)
	when 2x'000'010 then do87mem("fcom",ttt>>1)
	when 2x'000'011 then do87mem("fcomp",ttt>>1)
	when 2x'000'000 then do87mem("fadd",ttt>>1)
	when 2x'000'100 then do87mem("fsub",ttt>>1)
	when 2x'000'101 then do87mem("fsubr",ttt>>1)
	when 2x'000'001 then do87mem("fmul",ttt>>1)
	when 2x'000'110 then do87mem("fdiv",ttt>>1)
	when 2x'000'111 then do87mem("fdivr",ttt>>1)

	else
		genstr("UNKNOWN x87 OPCODE")
	esac
esac

end

proc do87arith(ichar opcstr, int ttt,freg)=
int d, p

d:=ttt iand 2x100		!d=0:  to st0; d<>0: to freg
p:=ttt iand 2x010		!p<>0: pop after operation

genstr(opcstr)
if p then
	genstr("p")
fi
genstr(" ")

if d=0 then
	genstr("st0, ")
    genstr(strfreg(freg))
else
    genstr(strfreg(freg))
	genstr(", st0")
fi
end

proc do87mem(ichar opcstr,int mf=-1)=
genstr("f")

case mf
when 2x'00 then opsize:=4
when 2x'01 then genstr("i"); opsize:=4
when 2x'10 then opsize:=8
when 2x'11 then genstr("i"); opsize:=2
when 4 then genstr("i"); opsize:=8
when 5 then opsize:=10
esac
genstr(opcstr+1)

genstr(" ")
printaddrmode()
end

proc getsil(int &reg)=
if opsize=1 and rex and reg>=5 and reg<=8 then
	reg+:=12				!5..8 => 17..20
fi
end

proc getsilx(int &reg)=

if addrmode=amreg and opsize=1 and rex and reg>=5 and reg<=8 then
	reg+:=12				!5..8 => 17..20
fi
end
=== bb_parse.m 37/40 ===
import msys
import mlib
import clib
import oslib

import bb_decls
import bb_tables
import bb_support
import bb_lex
import bb_lib
import bb_diags
import bb_mcldecls
import bb_pclcommon

[100]INT LOOPSTACK
INT NLOOPS


macro readunit=readassignment()

mut int intabledata=0		!1 means reading table data line; $ gives tabledataname
mut int inreadprint=0
mut int inparamlist=0
mut int inrecordbody=0
mut int inimportmodule=0
mut int labelseen=0
mut ichar tabledataname=nil

const maxprocstack=10
[maxprocstack]ref strec procstack
int nprocstack=0

uflagsrec unionstring, unionpend
ref strec unionlastvar=nil
ref strec dretvar			!part of read-proc: nil, or symptr of retval variable

int try_level=0
int varattribs=0

const maxdollarstack=10
[maxdollarstack]unit dollarstack		!used for a[$]
int ndollar=0
int inmultexpr=0
int insiderecord=0
int insidedllimport=0
int yieldseen=0

global filehandle docfile

global function parsemodule(int n)int=
modulerec m
ref strec p, owner
int globalflag,status

initparser()

m:=moduletable[n]
currmoduleno:=n

stmodule:=moduletable[n].stmodule
currproc:=stmodule

starttkscan(n)

owner:=stmodule
lex()



status:=readmoduledefs(owner)


if not status then
	return 0
fi

return status
end

global function readmoduledefs(ref strec owner)int=
ref strec p,dimport,stimport
int globalflag,i,callbackflag
ichar name


globalflag:=local_scope
callbackflag:=0

do
	switch lx.symbol
	when kglobalsym then
		if globalflag then serror("global global?") fi
		globalflag:=lx.subcode
		lex()

	when kprocsym,kfunctionsym then	!todo
		readprocdef(owner,globalflag,callbackflag)
		callbackflag:=0
		globalflag:=local_scope

	when stdtypesym,namesym,lsqsym,krefsym,kicharsym,ktypeofsym,
		kdictsym,kslicesym then
		readvardef(owner,globalflag,0,staticid, 0)
		globalflag:=local_scope

	when kmutsym then
		lex()
		readvardef(owner,globalflag,0,staticid,kmutsym)
		globalflag:=local_scope

	when kletsym then
		lex()
		readvardef(owner,globalflag,0,staticid,kletsym)
		globalflag:=local_scope

	when kimportmodulesym then
		readimportmodule(owner)

	when kimportpathsym then
		lexchecksymbol(stringconstsym)
		lex()

	when kmapmodulesym then
		repeat
			lex()
		until lx.symbol in [semisym,eofsym]

	when ktypesym then
		readtypedef(owner,globalflag)
		globalflag:=local_scope

	when kconstsym then
		readconstdef(owner,globalflag)
		globalflag:=local_scope

	when kclasssym,krecordsym then
		readclassdef(owner,globalflag)
		globalflag:=local_scope

	when ktaggedunionsym then
		readtaggeduniondef(owner,globalflag)
		globalflag:=local_scope

	when kenumsym then
		lex()
		readenumtype(owner,0,globalflag)
		globalflag:=local_scope

	when ktabledatasym then
		readtabledef(owner,globalflag)
		globalflag:=local_scope

	when docstringsym then
		adddocstring(lx.svalue)
		lex()

	when kimportsym then
		if globalflag then serror("glob/import?") fi
		lex()
		if lx.symbol=mulsym then
			lex()
		fi
		checksymbol(namesym)

		dimport:=lx.symptr
		name:=mapimport(dimport^.name)

		for i:=1 to nmodules do
			if eqstring(name, moduletable[i].name) then
				stimport:=moduletable[i].stmodule
				exit
			fi
		else
			CPL lx.symptr^.name
			serror("Import stmt out of position?")
		od
		lex()

		domappedalias(dimport,stimport)
		if lx.symbol=namesym and eqstring(lx.symptr.name,"as") then
			readimportalias(dimport)
		fi

	when semisym then
		lex()

	when eofsym then
		exit

	when kfflangsym then
		if lx.subcode=callbackff then
			callbackflag:=callbackff
			lex()
		else
			goto error
		fi

	when kmacrosym then
		readmacrodef(owner,globalflag)
		globalflag:=local_scope


	when koperatorsym then
		readoperatordef(owner)

	when kextendtypesym then
		readextendtype(owner)

	when dotsym then
		SERROR("MODULE/DOT")
	else
error::
		PS("symbol")
		serror("Not allowed at module level")
	endswitch
od

return 1
end

proc initparser=

unless nullunit then
	nullunit:=createunit0(j_null)
end unless

try_level:=0
currproc:=nil
varattribs:=0

intabledata:=0		!1 means reading table data line; $ gives tabledataname
inreadprint:=0
inparamlist:=0
inrecordbody:=0
inimportmodule:=0
ichar tabledataname:=""
labelseen:=0

ndollar:=0
end

proc skipsemi=
while lx.symbol=semisym do lex() od
end

function makeblock(unit p)unit=
return createunit1(j_block,p)
end

function makestmtblock(unit p)unit=
return createunit1(j_stmtblock,p)
end

proc checkequals=			!CHECKEQUALS
if lx.symbol<>eqsym then
	serror("""="" expected")
fi
end

function getcurrline:int=
return lx.pos
end

function checkbegin(int fbrack)int=				!CHECKBEGIN
int closesym

skipsemi()

if lx.symbol=lbracksym and fbrack then
	closesym:=rbracksym
	lex()
elsif lx.symbol=lcurlysym then
	closesym:=rcurlysym
	lex()
else
	closesym:=kendsym
fi
return closesym
end

proc checkbeginend(int closesym,kwd,startline=0)=		!CHECKBEGINEND
skipsemi()
if closesym=rbracksym or closesym=rcurlysym then
	checksymbol(closesym)
else
	checkend(closesym,kwd,startline:startline)
fi
lex()
end

proc checkend(int endsym,endkwd1, endkwd2=0,startline=0)=		!CHECKEND
[100]char str

if endsym=lx.symbol=rbracksym then
	return
fi

if lx.symbol<>kendsym then
	strcpy(&.str,"Bad 'end' ")
error::

	if startline then
		fprint @(&.str+strlen(&.str))," (from line #)",startline iand 16777215
	fi
	serror(&.str)
fi

if lx.subcode=0 then					!plain end; for now, that always matches
	return
fi

unless (endkwd1 and endkwd1=lx.subcode) or (endkwd2 and endkwd2=lx.subcode) then
	strcpy(&.str,"Mismatched 'end'")
	goto error
end unless
end

function readvardef(ref strec owner,int isglobal=0,isstatic=0,varid=staticid, k)unit=


unit ulist,ulistx, p
int nvars,m
ref strec stname

ulist:=ulistx:=nil

if istypestarter() then
	m:=readtypespec(owner)
elsif k then
	m:=tauto
else
	serror("Readvar?")
fi

nvars:=0
while lx.symbol=namesym do

	++nvars
	stname:=getduplnameptr(owner,lx.symptr,varid)

	stname^.isglobal:=isglobal

	stname^.isstatic:=isstatic
	stname^.islet:=(k=kletsym)
	if varid=dllvarid then
		stname.isimport:=1
	fi

	adddef(owner,stname)
	if varid=staticid then
		addstatic(stname)
	fi

	lex()

	if lx.symbol=colonsym then
		if m<>tauto then serror("Mixed var T x:T") fi
		lex()
		m:=readtypespec(owner)
	fi

	storemode(owner,m,stname.mode)	

	if lx.symbol in [assignsym,eqsym] then
		if lx.symbol=assignsym then
			if varid=staticid then
				serror("Need = on static not :=")
			fi
		else
			if varid=frameid then
				serror("Need 'static' for '='")
				addstatic(stname)
			fi
		fi
		lex()
		stname^.code:=readunit()
		stname^.equals:=1
		if varid=frameid then
			p:=createunit2(j_assign,createname(stname),stname^.code)
			p.initlet:=1
			addlistunit(&ulist,&ulistx,p)
		fi

	elsif lx.symbol=atsym then
		if k=kletsym then serror("let@") fi
		lex()
		stname^.at:=1
		stname^.equivvar:=readunit()
	elsif k=kletsym then
		serror("let needs :=/=")
	fi

	if lx.symbol<>commasym then
		exit
	fi
	lex()
od


if nvars=0 then
	serror("No vars declared")
fi
return ulist
end

proc readconstdef(ref strec owner,int isglobal=0)=
int nconsts,deft,m
ref strec stname

lex()

nconsts:=0

if istypestarter() then
	deft:=readtypespec(owner)
else
	deft:=tauto
fi

while lx.symbol=namesym do
	stname:=getduplnameptr(owner,lx.symptr,constid)

	lex()

	checkequals()
	lex()
	stname^.code:=readconstexpr(1)

	m:=deft

	storemode(owner,m,stname.mode)	
	++nconsts

	stname^.isglobal:=isglobal

	adddef(owner,stname)
	if isglobal=export_scope then
		addconst(stname)
	fi

	if lx.symbol<>commasym then
		exit
	fi
	lex()
od

if nconsts=0 then
	serror("No consts declared")
fi

end

function readlbrack:unit=


unit ulist,ulistx, p,q,r, plower
int oldirp,length

lex()					!first symbol of first expression
ulist:=ulistx:=nil
plower:=nil
length:=0

if lx.symbol=atsym then			!lwb override
	lex()
	oldirp:=inreadprint
	inreadprint:=1
	plower:=readunit()

	inreadprint:=oldirp
	checksymbol(colonsym)
	lex()

elsif lx.symbol=intconstsym and nexttoken.symbol=colonsym then
	plower:=createconstunit(lx.value,lx.subcode)
	plower.istrueconst:=1
	lex()
	lex()

elsif symboloptypes[lx.symbol]=bin_op and nexttoken.symbol=rbracksym then	!operator constant
	p:=createunit0(j_operator)
	p^.opindex:=lx.subcode
	lex()
	lex()
	return p
elsif symboloptypes[lx.symbol]=bin_op and nexttoken.symbol=assignsym then	!operator:= constant
	p:=createunit0(j_operator)
	p^.genop:=symbolgentoops[lx.symbol]
	lex()			!read :=
	lexchecksymbol(rbracksym)
	lex()
	return p
elsif istypestarter() then
	p:=readunit()
	checksymbol(rbracksym)
	lex()
	return p
fi

case lx.symbol
when rbracksym then			!empty list
	lex()
	p:=createunit0(j_makelist)
	p.b:=plower
	p^.length:=0
	return p
else					!assume normal expression follows
	p:=readxunit()
esac

case lx.symbol
when rbracksym then			!simple (x) expression
	lex()

	return p

when commasym then
	length:=1
	if nexttoken.symbol=rbracksym then		!means one-element list
		lex()
		lex()
		p:=createunit1(j_makelist,p)
		p^.length:=length
		p^.b:=plower
		return p
	fi

	ulist:=ulistx:=p
	repeat
		lex()							!skip comma
		if lx.symbol=rbracksym then		!allow ,) to end list
			exit
		fi
		if lx.symbol=commasym then
			serror(",, null expr not allowed")
		fi
		addlistunit(&ulist,&ulistx,readxunit())
		++length
		skipsemi()						!allow a,b,c;) (works better with a,b,c\ followed by comment on next line followed by ")")
	until lx.symbol<>commasym
	checksymbol(rbracksym)
	lex()
	p:=createunit1(j_makelist,ulist)
	p^.length:=length
	p^.b:=plower
	return p

when barsym then			!ifx/selectx expression; p is selector expression
	lex()
	q:=readxunit()
	case lx.symbol
	when barsym then		!(a|b|c)
		lex()
		r:=readsunit()
		checksymbol(rbracksym)
		lex()
		return createunit3(j_if,fixcond(p),q,r)
	when rbracksym then
		lex()
		return createunit3(j_if,fixcond(p),q,nil)

	esac

	addlistunit(&ulist,&ulistx,q)	!start with one-element list
	checksymbol(commasym)
	if nexttoken.symbol<>barsym then		!(n|a,| using one-element list; not useful but allow it...
		repeat
			lex()				!skip comma
			addlistunit(&ulist,&ulistx,readxunit())
		until lx.symbol<>commasym
		checksymbol(barsym)
	else
		lex()					!skip |
	fi
	lex()
	r:=readxunit()
	checksymbol(rbracksym)
	lex()
	return createunit3(j_select,p,ulist,r)

else
	serror("(x ...")
esac
return nil
end

proc addlistparam(ref ref strec ulist,ulistx,ref strec p)=
if ulist^=nil then		!first
	ulist^:=ulistx^:=p
else
	ulistx^^.nextparam:=p
fi
ulistx^:=p			!update end-of-list pointer
end

function readcast:unit=
unit p
int opc,t

t:=readtypespec(currproc)

case lx.symbol
when rbracksym then
	p:=createunit0(j_typeconst)
	p.mode:=ttype
	return p

when atsym then
	opc:=j_typepun
	lex()
when dotsym then			!allow T.type, but also just T (followed by . which
							!might be T.minvalue etc)
	if nexttoken.symbol=ktypesym then
		lex()
		p:=createunit0(j_typeconst)
		p.value:=t
		p.mode:=ttype
		lex()
	else					!leave dot to be processed by caller
		p:=createunit0(j_typeconst)
		p.value:=t
	fi
	return p
else
	opc:=j_convert
esac

checksymbol(lbracksym)
lex()
p:=readunit()
checksymbol(rbracksym)
lex()

p:=createunit1(opc,p)
storemode(currproc,t,p.convmode)
return p
end

function readopc:unit=			!READOPC
unit p,q,r
int tag,opc,firstsym

firstsym:=lx.symbol


case lx.symbol
when mathsopsym then
	tag:=j_unary
	opc:=lx.subcode
when maths2opsym then
	tag:=j_bin
	opc:=lx.subcode
else
	tag:=j_unary
	opc:=symbolgenops[firstsym]
esac

lex()
case firstsym
when addsym then			!ignore +
	return readterm2()
when subsym then			!convert minus to negate
	opc:=neg_op
when minsym,maxsym,concatsym,appendsym,maths2opsym then
	p:=readterm2()

	if p.tag=j_makelist then
		if p.length<>2 then serror("Needs (x,y)") fi
		q:=p.a
		r:=q.nextunit
		q.nextunit:=nil
		p:=createunit2(j_bin,q,r)
		p.genop:=opc
		return p
	else		!assume single operand
SERROR("READOPC/SINGLE OPND?")
		return createunit1(opc,p)

	fi
else
	if symboloptypes[firstsym]=bin_op then
		serror("Can't be used as unary op")
	fi

esac

if lx.symbol=assignsym then	!op:=, not normally allowed inside expressions
	lex()
	tag:=j_unaryto
	case firstsym
	when subsym then
		opc:=negto_op
	else
		opc:=symbolgentoops[firstsym]
		if opc=0 then
			serror("op:= not available")
		fi
	esac
fi

p:=createunit1(tag,q:=readterm2())

p.genop:=opc

if q.tag=j_makelist then
	serror("Too many opnds")
fi

return p
end

function readsprint:unit=			!READSPRINT
int oldinreadprint,opc,isfprint
unit pformat, pdev, printlist, printlistx, p

oldinreadprint:=inreadprint
inreadprint:=1
opc:=lx.subcode
lexchecksymbol(lbracksym)
lex()

case opc
when j_sfprint,j_cprint then
	isfprint:=1
else
	isfprint:=0
esac

printlist:=printlistx:=nil
pformat:=pdev:=nil

if lx.symbol=atsym then
	lex()
	pdev:=readunit()
	if lx.symbol=commasym then lex() else goto finish fi
fi
if isfprint then
	pformat:=readunit()
	if lx.symbol=commasym then lex() else goto finish fi
fi

if lx.symbol=rbracksym then
	goto finish
fi

do
	if lx.symbol=commasym then		!assume extra comma, meaning nogap
		addlistunit(&printlist,&printlistx,createunit0(j_nogap))
	else
		p:=readunit()
		if lx.symbol=colonsym then
			lex()
			p:=createunit2(j_fmtitem,p,readunit())
		fi
		addlistunit(&printlist,&printlistx,p)
	fi
	if lx.symbol<>commasym then exit fi
	lex()
od

checksymbol(rbracksym)

finish::
lex()
inreadprint:=oldinreadprint
if (opc=j_print or opc=j_fprint) and printlist=nil then
	serror("No print items")
fi

if isfprint then
	if pformat^.tag=j_null then
		serror("No fmt str")
	fi
	return createunit3(opc,pdev,pformat,printlist)
else
	return createunit2(opc,pdev,printlist)
fi
end

function readsread:unit=		!READSREAD
int oldinreadprint,opc
unit pformat,pdev,p, readlist,readlistx

oldinreadprint:=inreadprint
inreadprint:=1
opc:=lx.subcode
lexchecksymbol(lbracksym)
lex()

readlist:=readlistx:=nil
pformat:=pdev:=nil

if lx.symbol=atsym then
	if opc=j_read then
		serror("@ on read")
	fi
	lex()
	pdev:=readunit()
	if lx.symbol=commasym then lex() else goto finish fi
fi

if lx.symbol=rbracksym then
	goto finish
fi

do
	p:=readunit()
	if lx.symbol=colonsym then
		lex()
		p:=createunit2(j_fmtitem,p,readunit())
	fi
	addlistunit(&readlist,&readlistx,p)
	if lx.symbol<>commasym then exit fi
	lex()
od

checksymbol(rbracksym)

finish::
lex()
inreadprint:=oldinreadprint
if opc=j_read and readlist=nil then
	serror("No read items")
fi

return createunit2(opc,pdev,readlist)
end

function readcompilervar:unit=		!READCOMPILERVAR
[100]char str
rsystemtime tm
static []ichar monthnames=("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec")
unit p

switch lx.subcode
when j_cvnil then
	p:=createconstunit(0,tref)
	lex()
	return p

when j_cvpi then
	p:=createconstunit(int64@(3.14159'265358'979'3238'4626'433'832),treal)
	lex()
	return p

when j_cvlineno then

	p:=createunit0(j_cvlineno)
	lex()
	return p

when j_cvstrlineno then
	getstrint(lx.lineno,&.str)

when j_cvmodulename then
	p:=createunit0(j_cvmodulename)
	lex()
	return p

when j_cvfilename then
	p:=createunit0(j_cvfilename)
	lex()
	return p

when j_cvfunction then
	strcpy(&.str,currproc^.name)

when j_cvdate then
	os_getsystime(&tm)
	fprint @&.str,"#-#-#",tm.day,monthnames[tm.month],tm.year:"4"

when j_cvtime then
	os_getsystime(&tm)
	fprint @&.str,"#:#:#",tm.hour:"z2",tm.minute:"z2",tm.second:"z2"

when j_cvtargetbits then
	lex()
	return createconstunit(targetbits,tint)
when j_cvtargetsize then
	lex()
	return createconstunit(targetsize,tint)
when j_cvtargetcode then
	strcpy(&.str,"wx64")

when j_cvversion then
	strcpy(&.str,"Compiler:BX Experimental")

when j_cvtrue,j_cvfalse then
	p:=createconstunit(lx.subcode=j_cvtrue,tint)
	lex()
	return p
	
else
	serror_s("compiler var not impl: #",jtagnames[lx.subcode])
end switch
lex()

return createstringconstunit(pcm_copyheapstring(&.str),-1)
end

function readcastx:unit=
	int opc,m
	unit p

	lex()
	opc:=j_convert
	if lx.symbol=atsym then
		opc:=j_typepun
		lex()
	fi
	checksymbol(lbracksym)
	lex()
	m:=tvoid
	p:=readunit()
	if lx.symbol<>commasym then
		if opc=j_typepun then serror("@ type missing") fi
		opc:=j_autocast
	else
		lex()
		m:=readtypespec(currproc)
	fi
	checksymbol(rbracksym)
	lex()

	p:=createunit1(opc,p)
	storemode(currproc,m,p.convmode)

	return p
end

global proc checksymbol(int symbol)=
[100]char str

if lx.symbol<>symbol then
	fprint @&.str,"# expected, not #",symbolnames[symbol],symbolnames[lx.symbol]
	serror(&.str)
fi
end

proc lexchecksymbol(int symbol)=
	lex()
	checksymbol(symbol)
end

global function readtypespec(ref strec owner,int typedefx=0)int=			!READTYPESPEC

ref strec d,e
int t,kwd,fflang,sltype,w
unit x,pupper,plx
unit dim,length
const maxdim=30
[maxdim]unit dims
int ndims,i,n,k

case lx.symbol
when lsqsym then		!array bounds
arraybounds::
	lex()

	ndims:=0
	inreadprint:=1
	do
		length:=nil				!both bounds unspecified
		if lx.symbol=rsqsym or lx.symbol=commasym then		![]
			dim:=nil
		else
			dim:=readunit()
			case lx.symbol
			when rsqsym,commasym then			![n]
			when colonsym then				!a:n
				lex()
				if not (lx.symbol=commasym or lx.symbol=rsqsym) then	!lower:length
					length:=readunit()
					dim:=createunit2(j_keyvalue,dim,length)
				else													!lower::
					dim:=createunit1(j_keyvalue,dim)
				fi
			esac
		fi
		if ndims>=maxdim then serror("Too many array dims") fi
		dims[++ndims]:=dim
		exit when lx.symbol<>commasym
		lex()
	od
	inreadprint:=0
	checksymbol(rsqsym)
	lex()
	t:=readtypespec(owner)
	for i:=ndims downto 1 do
		t:=createarraymode(owner,t,dims[i],(i=1|typedefx|0))
	od
	return t

when stdtypesym then
	t:=lx.subcode
	lex()

when namesym then
	d:=lx.symptr
	lex()

	if lx.symbol=dotsym then
		lexchecksymbol(namesym)
		t:=newtypename(d,lx.symptr)
		lex()
	else
		t:=newtypename(nil,d)
	fi

when kenumsym then		!enum
	lex()
	t:=readenumtype(owner,typedefx)

when lbracksym then
	t:=readenumtype(owner,typedefx)

when krecordsym,kstructsym then
	serror("Use 'record name =' syntax")

when kunionsym then
	serror("Top-level union not allowed")

when krefsym then		!ref T
	fflang:=0
retry::

	lex()
	case lx.symbol
	when kprocsym,kfunctionsym then	!function pointer being created
		t:=readrefproc(owner,typedefx,fflang)

	when kfflangsym then
		fflang:=lx.subcode
		goto retry
	elsif lx.symbol=stdtypesym then
		case lx.subcode
		when tc8 then
			t:=trefchar
			if typedefx then tttarget[typedefx]:=tc8 fi
		else
			goto readtarget
		esac

		lex()
	else						!assume normal type
readtarget::
		t:=readtypespec(owner)
		t:=createrefmode(owner,t,typedefx)
	esac

when kicharsym then
	lex()
	t:=trefchar
	if typedefx then tttarget[typedefx]:=tc8 fi

when ktypeofsym then
	lexchecksymbol(lbracksym)
	lexchecksymbol(namesym)

	t:=newtypename(cast(lx.symptr),nil)
	lexchecksymbol(rbracksym)
	lex()

when kslicesym then
	t:=readslicetype(owner,lx.subcode,typedefx)

when kdictsym then
	lexchecksymbol(lsqsym)
	lex()
	k:=readtypespec(owner)
	checksymbol(rsqsym)
	lex()
	t:=readtypespec(owner)
	t:=createdictmode(owner,k,t,typedefx)

else
	serror("Bad type starter")
esac

if typedefx then			!assume a simple alias
	ttbasetype[typedefx]:=ttbasetype[t]
fi

return t
end

function readslicetype(ref strec owner, int slicetype, typedefx)int=
	unit plower
	int t

	lexchecksymbol(lsqsym)
	lex()
	if lx.symbol<>rsqsym then
		inreadprint:=1
		plower:=readunit()
		inreadprint:=0
		checksymbol(colonsym)
		lexchecksymbol(rsqsym)
	else
		plower:=nil
	fi
	lex()
	t:=readtypespec(owner,typedefx)


	return createslicemode(owner,slicetype,t,plower,typedefx)
end

function readslist(int iscall=0,donulls)unit=		!READSLIST
unit ulist,ulistx
int oldinparamlist

ulist:=ulistx:=nil

skipsemi()
if lx.symbol=rbracksym then		!empty list
	return ulist
fi

oldinparamlist:=inparamlist
inparamlist:=iscall

do
	skipsemi()
	case lx.symbol
	when commasym then
		if donulls then
			addlistunit(&ulist,&ulistx,createunit0(j_null))
		else
			serror("null comma expr not allowed")
		fi
		lex()
	when rbracksym then
		if donulls then
			addlistunit(&ulist,&ulistx,nullunit)
		fi
		exit
	else
		addlistunit(&ulist,&ulistx,readunit())
		if lx.symbol in [commasym,semisym] then
			lex()
			if lx.symbol=rbracksym then
				exit
			fi
		else
			skipsemi()
			if lx.symbol=rbracksym then
				exit
			fi
			serror("SLIST?")
		fi
	esac
od
inparamlist:=oldinparamlist

return ulist
end

function readindex(unit p,int dot)unit=		!READINDEX
unit q,plower,pupper

lex()

if not dot then
	case lx.symbol
	when rsqsym then
fullslice::
		lex()
		plower:=createunit1(j_unary,duplunit(p))
		plower.genop:=lwb_op
		pupper:=createunit1(j_unary,duplunit(p))
		pupper.genop:=upb_op
		p:=createunit2(j_slice, p, createunit2(j_makerange,plower, pupper))
		return p
	when rangesym,colonsym then
		lexchecksymbol(rsqsym)
		goto fullslice
	esac
fi

do
	if ndollar>=maxdollarstack then
		serror("Too many nested a[$]")
	fi
	dollarstack[++ndollar]:=p
	q:=readunit()
	--ndollar

	if q^.tag=j_makerange then		!convert into a discrete slice
		p:=createunit2((dot|j_dotslice|j_slice),p,q)
	else
		p:=createunit2((dot|j_dotindex|j_index),p,q)
	fi
	exit when lx.symbol<>commasym
	lex()
od
checksymbol(rsqsym)
lex()
return p
end

function readdotsuffix(unit p)unit=		!READDOTSUFFIX
unit q
int t

while lx.symbol=dotsym do
	lex()
	switch lx.symbol
	when lsqsym then
		p:=readindex(p,1)
	when namesym then
		p:=createunit2(j_dot,p,createname(lx.symptr))
		lex()
	when propsym then
doprop::
		p:=createunit1(j_unary,p)
		p.genop:=lx.subcode
		lex()
	when bitfieldsym then
		p:=createunit1(j_bitfield,p)
		p^.bfcode:=lx.subcode
		lex()
	when ktypesym then			!.type, convert to .gettype
		case p^.tag
		when j_typeconst then			!int.type=>int

		else
			p:=createunit1(j_typeof,p)
		esac
		lex()

	when maxsym then
		lx.subcode:=maxvalue_op
		goto doprop

	when minsym then
		lx.subcode:=minvalue_op
		goto doprop
	when stdtypesym then
		if p.tag=j_typeconst and lx.subcode=trange then
			q:=createunit2(j_makerange,
				createunit1(j_unary,p),
				createunit1(j_unary,p))
			q.a.genop:=minvalue_op
			q.b.genop:=maxvalue_op
		else
			error
		fi
		lex()
		p:=q

	else
error::
		serror("Unknown dot suffix")
	endswitch
od
return p
end

global function isconstexpr(unit p)int=		!ISCONSTEXPR
return p^.tag=j_const
end

function readconstexpr(int needconst=1)unit=
return readunit()
end

function readconstint:int=		!READCONSTINT
int64 x

if lx.symbol=intconstsym then
	x:=lx.value
	lex()
	return x
elsif lx.symbol=subsym then
	lex()
	if lx.symbol=intconstsym then
		x:=lx.value
		lex()
		return -x
	fi
fi

serror("Can't do complex expr")
return 0
end

proc readprocdef(ref strec procowner,int isglobal,fflang=0)=
int kwd,startline,closesym
ref strec stproc,q,stname

kwd:=lx.symbol
yieldseen:=0

stproc:=readprocdecl(procowner,isglobal,fflang)

checkequals()
lex()

startline:=getcurrline()

closesym:=checkbegin(0)

pushproc(stproc)
nextavindex:=0

IF DRETVAR THEN
	stname:=getduplnameptr(stproc,dretvar,frameid)
	storemode(procowner,stproc.mode,stname.mode)
	adddef(stproc,stname)
fi

addtoproclist(stproc)

stproc^.code:=readsunit()

checkbeginend(closesym,kwd,startline)

if yieldseen then
	stproc.nameid:=generatorid
fi

if ndocstrings and docfile and stproc.isglobal=export_scope then
	println @docfile,"proc",stproc.name
	for i to ndocstrings do
		println @docfile,docstrings[i]
		pcm_free(docstrings[i],strlen(docstrings[i]+1))
	od
	println @docfile

	ndocstrings:=0
fi

popproc()


end

global function readprocdecl(ref strec procowner,int isglobal,fflang)ref strec=

int kwd,varparams,try_level, nparams, nretvalues, isthreaded
[maxtuplesize]int retmodes
int prettype@&retmodes

ichar metadata, truename
ref strec pequiv, stproc, owner, paramlist,nameptr

kwd:=lx.symbol				!remember keyword
isthreaded:=lx.subcode

pequiv:=nil
metadata:=""
truename:=nil
varparams:=0
try_level:=0

lex()

if lx.symbol=stringconstsym then		!assume dll truename
	truename:=pcm_copyheapstring(lx.svalue)
	convlcstring(lx.svalue)
	lx.symptr:=addnamestr(lx.svalue)
else
	checksymbol(namesym)
fi

nameptr:=lx.symptr

stproc:=getduplnameptr(procowner,nameptr,(insidedllimport|dllprocid|procid))
if insidedllimport then isglobal:=program_scope fi
stproc.isthreaded:=isthreaded

if truename then
	stproc^.truename:=truename
fi

if stproc^.name^='$' and eqstring(stproc^.name,"$init") then
	moduletable[stmodule^.moduleno].stinitproc:=stproc
fi

adddef(procowner,stproc)
if stproc^.nameid=dllprocid then
	stproc^.isimport:=1
	if eqstring(procowner^.name,"cstd") then
		stproc^.iscimport:=2
	fi
fi

owner:=stproc
pushproc(stproc)

lex()

paramlist:=nil
prettype:=tvoid
nparams:=0
nretvalues:=0

nretvalues:=0
if lx.symbol=lbracksym then		!possible params
	lex()
	if lx.symbol<>rbracksym then
		paramlist:=readparams(procowner,stproc,fflang,varparams,nparams)
		checksymbol(rbracksym)
	fi
	lex()

	if lx.symbol=colonsym or lx.symbol=sendtosym then
		lex()
		nretvalues:=readreturntype(owner,retmodes)
	elsif typestarterset[lx.symbol] or lx.symbol=namesym then
		nretvalues:=readreturntype(owner,retmodes)
	fi
elsif lx.symbol=colonsym or lx.symbol=sendtosym then
	lex()
	nretvalues:=readreturntype(owner,retmodes)
fi

dretvar:=nil
if nretvalues=1 then
	if lx.symbol=namesym then
		dretvar:=lx.symptr
		lex()
	fi
fi

unless nretvalues or (kwd<>kfunctionsym) then		!function: no result given
	serror("Function needs ret type")
endunless

if nretvalues and (kwd<>kfunctionsym) then		!proc: result given
	serror("Proc can't return value")
fi


stproc^.paramlist:=paramlist
stproc^.nretvalues:=nretvalues

case nretvalues
when 0 then
	stproc.mode:=tvoid
when 1 then
	storemode(procowner,retmodes[1],stproc.mode)
else
	stproc.mode:=createtuplemode(procowner,(&.retmodes,nretvalues),0)
esac

if lx.symbol=atsym then			!equivalence
	lexchecksymbol(namesym)
SERROR("READPROCDEF @")
	lex()
	stproc^.at:=1
fi

stproc^.code:=nil

case fflang
when clangff,windowsff then
else			!assume this language
	case procowner^.nameid
	when moduleid then
	when dllmoduleid then
		serror("Need FF specifier")
	esac
esac
stproc^.isglobal:=isglobal
stproc^.varparams:=varparams
stproc^.fflang:=fflang

if procowner=stmodule and 
	(stproc^.namelen=5 and eqstring(stproc^.name,"start")) or 
	(stproc^.namelen=4 and eqstring(stproc^.name,"main")) then
	stproc^.isglobal:=export_scope
fi

popproc()


return stproc
end

function readparams(ref strec procowner,owner,int fflang,&varparams,&nparams)ref strec=			!READPARAMS
	ref strec stlist, stlistx, stname, d
	int parammode, pmode, m, pmprefix

	[30]char str
	stlist:=stlistx:=nil
	pmode:=tvoid
	nparams:=0
	pmprefix:=0
	parammode:=var_param

	if fflang=0 then fflang:=mlangff fi

	if lx.symbol in [koutsym,addrsym] then
		parammode:=out_param
		pmprefix:=1
		lex()
	elsif lx.symbol=insym then
		parammode:=in_param
		pmprefix:=1
		lex()
	fi

	if lx.symbol=namesym and nextlx().symbol in [commasym,rbracksym] then	!types only
		pmode:=readtypespec(procowner)
typesonly::
		return readparams_types(procowner,owner,fflang,varparams,nparams,pmode,parammode)
	else
		pmode:=readtypespec(procowner)
		if lx.symbol in [commasym,rbracksym] then			!types only
			goto typesonly
		fi
	fi

	if pmprefix then
		serror("&/out must be applied to param name")
	fi

	goto gotmode

	do										!expect type of name at start of loop
		if istypestarter() then				!assume new mode
			pmode:=readtypespec(procowner)
		fi
gotmode::

		case lx.symbol
		when insym then
			parammode:=in_param
			lex()
			if lx.symbol=colonsym then lex() fi
		when koutsym,addrsym then
			parammode:=out_param
			lex()
			if lx.symbol=colonsym then lex() fi
		esac

		checksymbol(namesym)
		++nparams
		stname:=getduplnameptr(owner,lx.symptr,paramid)
		adddef(owner,stname)
		lex()
		if parammode=out_param then
			m:=createrefmode(procowner,pmode)
		else
			m:=pmode
		fi

		storemode(owner,m,stname^.mode)
		stname^.parammode:=parammode
		addlistparam(&stlist,&stlistx,stname)
		parammode:=var_param

		case lx.symbol
		when assignsym then
			lex()
dodefvalue::
			stname^.code:=readunit()
			stname^.equals:=1
			stname^.optional:=1
		when eqsym then
			lex()
			goto dodefvalue
		esac

		case lx.symbol
		when commasym then
			lex()
		when rbracksym then
			exit
		else
			serror("nameparams1")
		esac
	od

return stlist
end

function readparams_types(ref strec procowner,owner,int fflang,&varparams,&nparams,
			int pmode, parammode)ref strec=
	ref strec stlist, stlistx, stname
	int firstparam,m

	[30]char str
	stlist:=stlistx:=nil
	stname:=nil
	nparams:=0
	goto gotmode

	do
		if lx.symbol=ellipsissym then
			varparams:=nparams+1		!pos of 1st varparam
			lex()
			checksymbol(rbracksym)
			exit
		fi

		pmode:=readtypespec(procowner)
gotmode::
		++nparams
		print @&.str,"$",,nparams
		stname:=getduplnameptr(owner,addnamestr(&.str),paramid)
		adddef(owner,stname)
		if parammode=out_param then
			m:=createrefmode(procowner,pmode)
		else
			m:=pmode
		fi

		storemode(owner,m,stname^.mode)
		stname^.parammode:=parammode
		addlistparam(&stlist,&stlistx,stname)
		parammode:=var_param

		case lx.symbol
		when assignsym,eqsym then
			lex()
			stname^.code:=readunit()
			stname^.equals:=1
		when namesym then
			serror("Can't mixed unnamed/named params")
		endcase

		case lx.symbol
		when commasym then
			lex()
			if lx.symbol=addrsym then
				parammode:=out_param
				lex()
			fi
		when rbracksym then
			exit
		else
			serror("typeparams3")
		endcase

	od
	return stlist
end

function readcondsuffix(unit p)unit=			!READCONDSUFFIX
unit q

switch lx.symbol
when kwhensym then
	lex()
	return createunit2(j_if,fixcond(readunit()),createunit1(j_block,p))
when kunlesssym then
	lex()
	q:=createunit1(j_notl,fixcond(readunit()))
	q.genop:=notl_op
	return createunit2(j_if, q,createunit1(j_block,p))
else
	return p
endswitch
end

function readif:unit=
int pos1, kwd, pos2
unit pthen,pcond, plist,plistx, pelse, p, pelsif

pos1:=lx.pos

kwd:=lx.symbol			!in case coming from elsecase etc

lex()
pcond:=fixcond(readsunit())
skipsemi()

checksymbol(kthensym)
lex()

pthen:=readsunit()

if lx.symbol=kelsifsym then
	pos2:=lx.pos
	plist:=plistx:=createunit2(j_elsif,pcond,pthen)

	while lx.symbol=kelsifsym do
		pos2:=lx.pos
		lex()
		pcond:=fixcond(readunit())
		checksymbol(kthensym)
		lex()
		pthen:=readsunit()
		pelsif:=createunit2(j_elsif,pcond,pthen)
		pelsif^.pos:=pos2
		addlistunit(&plist,&plistx,pelsif)

	od

	case lx.symbol
	when kelsesym then		!get r=any else stmt or nil
		lex()
		pelse:=readsunit()
		checkend(kendsym,kwd,0)
		lex()
	when kelsecasesym,kelseswitchsym then
		lx.symbol:=kwd
		pelse:=makeblock(readswitchcase())
	else
		PELSE:=NIL
		checkend(kendsym,kwd,0)
		lex()
	esac

	p:=createunit2(j_longif,plist,pelse)
	p^.pos:=pos1
	return p
fi

case lx.symbol
when kelsesym then		!get r=any else stmt or nil
	lex()
	pelse:=readsunit()
	checkend(kendsym,kwd)
	lex()
when kelsecasesym,kelseswitchsym then
	lx.symbol:=kwd
	pelse:=makeblock(readswitchcase())
else
	PELSE:=NIL
	checkend(kendsym,kwd)
	lex()
esac

p:=createunit3(j_if,pcond,pthen,pelse)
p^.pos:=pos1
return p
end

function readgoto(int gototag=j_goto)unit=	!READGOTO
ref strec d
unit p

if lx.subcode=1 then		!go used
	lexchecksymbol(ktosym)
fi
lex()

if lx.symbol=namesym and nexttoken.symbol<>ptrsym and nexttoken.symbol<>lsqsym and
	nexttoken.symbol<>dotsym then			!assume simple label
	p:=createname(lx.symptr)

	lex()
else
	serror("GOTO LABEL EXPR")
fi

return readcondsuffix(createunit1(gototag,p))
end

function readunless:unit=
int pos
unit pcond, pthen, pelse, p,q
pos:=lx.pos
lex()
pcond:=fixcond(readsunit())
checksymbol(kthensym)
lex()

pthen:=readsunit()

if lx.symbol=kelsesym then
	lex()
	pelse:=readsunit()
else			!assume simple if-then
	PELSE:=NIL
fi
checkend(kendsym,kunlesssym)
lex()
p:=createunit3(j_if,q:=createunit1(j_notl,pcond),pthen,pelse)
q.genop:=notl_op
p.pos:=pos
return p
end

function readswitchcase:unit=
int pos1, kwd, opc, pos2,rangeused, nwhen
unit pexpr,pwhenlist,pwhenlistx,pwhen,pwhenx,pelse,p,pthen,pwhenthen,q

pos1:=lx.pos
kwd:=lx.symbol			!remember kcasesym etc
opc:=lx.subcode			!pick up tag: kcase etc

lex()

skipsemi()
if lx.symbol=kwhensym then
	if kwd=kswitchsym then
		serror("switch expr missing")
	fi
	pexpr:=nil
else
	pexpr:=readsunit()		!index expression
fi

pwhenlist:=pwhenlistx:=nil
rangeused:=0
nwhen:=0

skipsemi()
while lx.symbol=kwhensym do	!read list of when-then pairs
	pos2:=lx.pos
	lex()
	pwhen:=pwhenx:=nil
	do
		p:=readunit()
		++nwhen
		p^.pos:=pos2
		if p^.tag=j_makerange then rangeused:=1 fi
		addlistunit(&pwhen,&pwhenx,p)
		if lx.symbol<>commasym then exit fi
		lex()
	od
	checksymbol(kthensym)
	lex()
	pthen:=readsunit()
	pwhenthen:=createunit2(j_whenthen,pwhen,pthen)
	pwhenthen^.pos:=pos2
	addlistunit(&pwhenlist,&pwhenlistx,pwhenthen)
od

if opc=j_switch and not rangeused then
	if nwhen<=8 then
		opc:=j_case
	fi
fi

case lx.symbol
when kelsesym then		!get r=any else stmt or nil
	lex()
	pelse:=readsunit()

	checkend(kendsym,kwd)
	lex()
when kelsifsym then
	lx.symbol:=kwd
	pelse:=makeblock(readif())
when kelsecasesym, kelseswitchsym then
	lx.symbol:=kwd
	pelse:=makeblock(readswitchcase())
else
	PELSE:=NIL
	checkend(kendsym,kwd)
	lex()
esac

p:=createunit3(opc,pexpr,pwhenlist,pelse)
p^.pos:=pos1
return p
end

function readstop:unit=
unit p
int i
lex()
if exprstarter[lx.symbol] then
	p:=createunit1(j_stop,readunit())
else
	p:=createunit0(j_stop)
fi
return readcondsuffix(p)
end

function readreturn:unit=
unit p,q,r

lex()
if exprstarter[lx.symbol] then
	q:=readunit()
	p:=createunit1(j_return,q)
	p^.length:=1
else
	p:=createunit0(j_return)
	p^.length:=0
fi

return readcondsuffix(p)
end

function readdo:unit=
	unit p
	int pos

	pos:=lx.pos
	lex()
	p:=readsunit()
	checkend(kendsym,kdosym)
	lex()
	p:=createunit1(j_do,p)
	p^.pos:=pos
	return p
end

function readto:unit=
int pos,id
unit p, pcount, pbody

pos:=lx.pos
lex()

pcount:=readunit()

checksymbol(kdosym)
lex()
pbody:=readsunit()
checkend(kendsym,ktosym,kdosym)
lex()
id:=frameid
if currproc^.nameid<>procid then id:=staticid fi

p:=createunit3(j_to,pcount,pbody,createname(getavname(currproc,id)))
p^.pos:=pos
return p
end

function readwhile:unit=
int pos,id
unit pcond, pa, pb, pc, pbody, p

pos:=lx.pos
lex()

pcond:=fixcond(readsunit(1))

checksymbol(kdosym)
lex()
pbody:=readsunit()

checkend(kendsym,kwhilesym,kdosym)
lex()

p:=createunit2(j_while,pcond,pbody)
p^.pos:=pos

return p
end

function readrepeat:unit=
int pos
unit pbody, pcond, p

pos:=lx.pos
lex()
pbody:=readsunit()
checksymbol(kuntilsym)
lex()
pcond:=fixcond(readunit())
p:=createunit2(j_repeat,pbody,pcond)
p^.pos:=pos

return p
end

function readloopcontrol:unit=
int opc
unit p

opc:=lx.subcode
lex()
if lx.symbol=namesym and eqstring(lx.symptr^.name,"all") then
	lex()
	p:=createunit1(opc,createconstunit(0,tint))

elsif exprstarter[lx.symbol] then
	p:=createunit1(opc,readconstexpr(1))
else
	p:=createunit1(opc,createconstunit(1,tint))
fi
return readcondsuffix(p)
end

function readprint:unit=
int oldinreadprint, opc, isfprint, fshowname, length
unit pformat, pdev, printlist,printlistx, p,q
ref strbuffer expr

ichar s

oldinreadprint:=inreadprint
inreadprint:=1
opc:=lx.subcode

case opc
when j_fprint,j_fprintln,j_cprint,j_cprintln then
	isfprint:=1
else
	isfprint:=0
esac

lex()

printlist:=printlistx:=nil
pformat:=pdev:=nil

if lx.symbol=atsym then
	lex()
	pdev:=readunit()
	if lx.symbol=commasym then lex() else goto finish fi
fi
if isfprint then
	if not exprstarter[lx.symbol] and opc=j_cprintln then
		goto finish
	fi
	pformat:=readunit()
	if lx.symbol=commasym then lex() else goto finish fi
fi

if not exprstarter[lx.symbol] then
	goto finish
fi

do
	case lx.symbol
	when commasym then		!assume extra comma, meaning nogap
		addlistunit(&printlist,&printlistx, createunit0(j_nogap))
	when dollarsym then		!assume extra comma, meaning nogap
		addlistunit(&printlist,&printlistx, createunit0(j_nogap))
		lex()

	else

		fshowname:=0
		if lx.symbol=eqsym then
			fshowname:=1
			lex()
		fi

		p:=readunit()
		if lx.symbol=colonsym then
			lex()
			p:=createunit2(j_fmtitem,p,readunit())
		fi
		if fshowname then
			expr:=strexpr(p)
			strbuffer_add(expr,"=")
			s:=expr^.strptr
			iconvucn(expr^.strptr,expr^.length)

			addlistunit(&printlist,&printlistx,q:=createstringconstunit(s,expr^.length))
		fi
		addlistunit(&printlist,&printlistx,p)
	esac
	if lx.symbol<>commasym then exit fi
	lex()
od

finish::
inreadprint:=oldinreadprint
if opc=j_print and printlist=nil then
	serror("No print items")
fi
if opc=j_fprint and printlist=nil and pformat=nil then
	serror("No print items")
fi
if opc=j_cprint and printlist=nil and pformat=nil then
	serror("No cprint items")
fi

if isfprint then
	if pformat=nil and opc<>j_cprintln then
		serror("No fmt str")
	fi
	return createunit3(opc,pdev,pformat,printlist)
else
	return createunit2(opc,pdev,printlist)
fi
end

function readread:unit=
int oldinreadprint,opc
unit pformat, pdev, readlist, readlistx, p, pread

oldinreadprint:=inreadprint
inreadprint:=1
opc:=lx.subcode
lex()

readlist:=readlistx:=nil
pformat:=pdev:=nil

if lx.symbol=atsym then
	if opc=j_read then
		serror("@ on read")
	fi
	lex()
	pdev:=readunit()
	if lx.symbol=commasym then lex() fi
fi

if opc=j_readln then
	addlistunit(&readlist,&readlistx,createunit1(j_readln,pdev))
fi

if not exprstarter[lx.symbol] then
	goto finish
fi

do
	p:=readunit()
	if lx.symbol=colonsym then
		lex()
		pformat:=readunit()
	else
		pformat:=nil
	fi

	pread:=createunit1(j_read,pformat)


	p:=createunit2(j_assign,p,pread)

	addlistunit(&readlist,&readlistx,p)
	if lx.symbol<>commasym then exit fi
	lex()
od

finish::
inreadprint:=oldinreadprint
if opc=j_read and readlist=nil then
	serror("No read items")
fi

return makestmtblock(readlist)
end

function readtry:unit=
unit ptry, pexceptlist, pexceptlistx, px, q, exlist,exlistx
++try_level
lex()

ptry:=readsunit()
pexceptlist:=pexceptlistx:=nil			!list of j_except items

while lx.symbol=kexceptsym do
	lex()
	exlist:=exlistx:=nil				!list of exception codes for this 'except'
	do
		addlistunit(&exlist,&exlistx,readconstexpr())
		if lx.symbol<>commasym then exit fi
		lex()
	od
	checksymbol(kthensym)
	lex()
	px:=readsunit()
	addlistunit(&pexceptlist,&pexceptlistx,createunit2(j_except,exlist,px))
od
checkend(kendsym,ktrysym)
lex()

--try_level

return createunit2(j_try,ptry,pexceptlist)
end

function readraise:unit=
unit p

lex()
p:=readunit()
return createunit1(j_raise,p)
end

function readfor:unit=


	int pos, opc, kwd
	unit pindex, plocal				!for index; for index,local
	unit pfrom, pto, pstep, ptoinit	!for INDEX:=FROM to/downto TO [by STEP]/ INDEX in FROM..TO
	unit plist, passign				!for INDEX in/inrev LIST (also LIST.BOUNDS)
	unit pcond, pbody, pelse
	unit p
	pos:=lx.pos
	lex()						!skip 'for' kwd

	plocal:=nil
	ptoinit:=nil
	pindex:=readname()

	if lx.symbol=commasym then
		lex()
		plocal:=readname()
	fi

	opc:=j_forup
	pstep:=nil
	pcond:=nil

	if lx.symbol in [insym, inrevsym] then				!assume forall
		if lx.symbol=j_inrev then
			opc:=j_fordown				!tentative; may be changed to forall
		fi
		lex()

		plist:=readunit()

		if plist.tag=j_unary and plist.genop=bounds_op then
			pfrom:=getrangelwbunit(plist.a)
			pto:=getrangeupbunit(plist.a)
		elsif plist.tag=j_makerange then
			pfrom:=plist.a
			pto:=plist.b
		else
			opc:=(opc=j_forup|j_forall|j_forallrev)
			pfrom:=getrangelwbunit(duplunit(plist))
			pto:=getrangeupbunit(duplunit(plist))
		fi

	else
		if lx.symbol=assignsym then
			lex()
			pfrom:=readunit()
		else
			pfrom:=createconstunit(1,tint)
		fi
		checksymbol(ktosym)
		opc:=(lx.subcode=1|j_fordown|j_forup)
		lex()
		pto:=readunit()

		if lx.symbol=kbysym then
			lex()
			pstep:=readconstexpr(0)
			if pstep^.tag=j_const then
				if pstep^.value=1 then		!by 1
					pstep:=nil
				fi
			fi
		fi
	fi

	if lx.symbol=kwhensym then
		lex()
		pcond:=fixcond(readunit())
	fi
	checksymbol(kdosym)
	lex()
	pbody:=readsunit()
	pelse:=nil

	if lx.symbol=kelsesym then
		lex()
		pelse:=readsunit()
	fi
	checkend(kendsym,kforsym,kdosym)
	lex()


	if pcond<>nil then
		pbody:=makeblock(createunit2(j_if,pcond,pbody))
	fi
	pbody.nextunit:=pelse



	case opc
	when j_forup, j_fordown then
		if plocal then serror("for i,x?") fi
		pindex.avcode:='I'
		if pto.tag not in [j_const, j_name] then
			plocal:=createname(getavname(currproc))
			plocal.avcode:='I'
			ptoinit:=createunit2(j_assign, plocal, pto)
			pindex.nextunit:=ptoinit
			pto:=plocal
		fi

		pfrom.nextunit:=pto
		pto.nextunit:=pstep

		p:=createunit3(opc, pindex, pfrom, pbody)

	else										!assume forall/rev

		if plocal=nil then						!only for x
			plocal:=pindex
			pindex:=createname(getavname(currproc))
		fi
		pindex.avcode:='I'
		plocal.avcode:='L'
		pindex.nextunit:=plocal
		plocal.nextunit:=pfrom
		pfrom.nextunit:=pto

		passign:=createunit2(j_assign,duplunit(plocal),
					createunit2(j_index,duplunit(plist),duplunit(pindex)))
		plist.nextunit:=passign

		p:=createunit3(opc, pindex, plist, pbody)

	esac

	p.pos:=pos
	return p
end

function readname:unit p=
	p:=readterm2()
	if p.tag<>j_name then serror("Name expected") fi
	return p
end

global proc readtypedef(ref strec owner,int isglobal=0)=
ref strec sttype,stname
int t,m

lexchecksymbol(namesym)
stname:=lx.symptr

lex()
checkequals()
lex()

sttype:=getduplnameptr(owner,stname,typeid)
adddef(owner,sttype)
m:=createusertype(sttype)
ttusercat[m]:=1

t:=readtypespec(sttype,m)		!should return filled-in version of m

sttype.isglobal:=isglobal

storemode(owner,t,sttype.mode)

if t>=0 then
	if ttisallnum[t] then
		tttarget[m]:=t
	elsif ttisref[t] then
	elsecase ttbasetype[t]
	when tarray,tbits then
	when tslice then
	when trecord then
	when tenum then
	when tdict then
	else
		tttarget[m]:=t
	fi
else
	storemode(owner,t,tttarget[m])
fi

if t>=0 then
	copyttvalues(m,t)
else
	ttbasetype[m]:=tpending
fi
end

global proc readrecordfields(ref strec owner,int m)=
int nvars
ref strec stname,stbitfield

nvars:=0
while lx.symbol=namesym do

	stname:=getduplnameptr(owner,lx.symptr,fieldid)
	storemode(owner,m,stname.mode)
	++nvars

	if unionpend.ulength then
		unionstr_copy(&stname^.uflags,&unionpend)
		unionstr_concat(&unionstring,&unionpend)
		unionstr_clear(&unionpend)
	else
		unionstr_clear(&stname^.uflags)
	fi
	unionlastvar:=stname			!filled in from outside with 'E' codes

	adddef(owner,stname)

	lex()

	case lx.symbol
	when atsym then
		lex()
		stname^.at:=2
		stname^.equivfield:=readequivfield(owner)

	when datsym then
		lexchecksymbol(intconstsym)
		case lx.value
		when 1,2,4,8,16 then
			stname^.align:=lx.value
		when 0 then
			stname^.align:=255
		else
			serror("@@ bad align")
		esac
		lex()	
	when colonsym then				!read bitfields
		lexchecksymbol(lbracksym)

		repeat
			lexchecksymbol(namesym)
			stbitfield:=getduplnameptr(owner,lx.symptr,fieldid)
			stbitfield^.mode:=tbitfield
			adddef(owner,stbitfield)

			stbitfield^.at:=2
			stbitfield^.equivfield:=stname

			lexchecksymbol(colonsym)
			lexchecksymbol(intconstsym)
			stbitfield^.bitfieldwidth:=lx.value
			lex()

		until lx.symbol<>commasym
		checksymbol(rbracksym)
		lex()

	esac

	if lx.symbol<>commasym then
		exit
	fi
	lex()
od

if nvars=0 then
	serror("No fields declared")
fi
end

global proc readtabledef(ref strec owner,int isglobal=0)=
int i,ncols,nrows,enums,nextenumvalue,firstval,lastval,startline,closesym
int ltype
unit plower
ichar enumtypename
ref strec stvar,stenum,stgen
const maxcols=20
[maxcols]ref strec varnameptrs
[maxcols]int varlisttypes
[maxcols]unit plist,plistx
const maxrows=500
[maxrows]int enumvalues

lex()
enums:=0						!whether there is an enums column
enumtypename:=nil

if lx.symbol=lbracksym then		!tabledate(...) read enum type
	enums:=1
	lex()
	if lx.symbol=namesym then		!named type
		enumtypename:=lx.symptr^.name
		lex()
	fi					!else unnamed type (just named constants)
	checksymbol(rbracksym)
	lex()
fi

nextenumvalue:=1
nrows:=0			!number of data rows appearing
ncols:=0			!number of data columns (varnames appearing)

while lx.symbol<>eqsym do
	ltype:=readtypespec(owner)
	checksymbol(namesym)
	if ++ncols>maxcols then
		serror("tabledata/too many columns")
	fi
	varnameptrs[ncols]:=lx.symptr
	varlisttypes[ncols]:=ltype

	lex()
	if lx.symbol=commasym then
		lex()
	else
		exit
	fi
od

lex()					!skip =

skipsemi()
startline:=getcurrline()
closesym:=checkbegin(0)

skipsemi()
firstval:=lastval:=0

for i:=1 to ncols do
	plist[i]:=plistx[i]:=nil
od

intabledata:=1
do			!loop per row
	skipsemi()
	checksymbol(lbracksym)
	lex()
	if ++nrows>maxrows then
		serror("tabledata:too many rows")
	fi

	if enums then
		checksymbol(namesym)
		stgen:=lx.symptr				!generic symbol entry
		tabledataname:=stgen^.name		!allow to be picked up by $ lx.symbol
		lex()
		if lx.symbol=eqsym then
			lex()
			nextenumvalue:=readconstint()
		fi
		enumvalues[nrows]:=nextenumvalue

		stenum:=getduplnameptr(owner,stgen,constid)
		stenum.mode:=tint
		stenum^.code:=createconstunit(nextenumvalue,tint)
		stenum^.isglobal:=isglobal
		adddef(owner,stenum)

		if nrows=1 then firstval:=nextenumvalue fi
		lastval:=nextenumvalue

		++nextenumvalue
		if ncols then				!comma always expected
			checksymbol(commasym)		!check it
		fi
		lex()
	fi

	for i:=1 to ncols do
		addlistunit(&plist[i],&plistx[i],readunit())
		if i=ncols then
			checksymbol(rbracksym)
		else
			checksymbol(commasym)
		fi
		lex()
	od

	if lx.symbol<>commasym then exit fi
	lex()					!should be ( for next entry
	if lx.symbol=closesym then exit fi		!allow trailing comma on last entry
od

intabledata:=0

skipsemi()
checkbeginend(closesym,ktabledatasym,startline)





if nrows=0 then serror("No table data") fi


for i:=1 to ncols do

	stvar:=getduplnameptr(owner,varnameptrs[i],staticid)
	stvar^.code:=createunit1(j_makelist,plist[i])
	stvar^.code^.length:=nrows

	storemode(owner,varlisttypes[i],stvar.mode)
	stvar^.isglobal:=isglobal

	adddef(owner,stvar)
	addstatic(stvar)
od
end

global proc readclassdef(ref strec owner,int isglobal)=
int kwd, baseclass, m, startline, closesym, mrec, normalexit,isrecord, align
ref strec nameptr, sttype, newd, d,e

kwd:=lx.symbol
isrecord:=kwd=krecordsym

lexchecksymbol(namesym)
nameptr:=lx.symptr

lex()
baseclass:=0
if lx.symbol=lbracksym then
	lex()
	baseclass:=readtypespec(owner)
	checksymbol(rbracksym)
	lex()
fi

checkequals()
lex()

align:=0
if lx.symbol=atsym then
	if lx.subcode=0 then
		lex()
		align:=readconstint()
	else
		lex()
	fi
	align:=1
fi



sttype:=getduplnameptr(owner,nameptr,typeid)
adddef(owner,sttype)
m:=createusertype(sttype)

mrec:=createrecordmode(owner, m)
storemode(owner,mrec,sttype.mode)	

storemode(owner,baseclass,sttype.baseclass)	
sttype.align:=align

closesym:=checkbegin(1)

startline:=getcurrline()

readclassbody(sttype,kwd)

checkbeginend(closesym,kwd,startline)

sttype^.isglobal:=isglobal
end

proc readclassbody(ref strec owner,int classkwd)=
int kwd,t
ref strec d

unionstr_clear(&unionstring)
unionstr_clear(&unionpend)

doswitch lx.symbol
when kconstsym then
	readconstdef(owner,0)
when kfunctionsym,kprocsym then
	kwd:=lx.symbol

	if owner^.isimport then
		readprocdecl(owner,0,0)
	else
		readprocdef(owner,0)
	fi
when kclasssym,krecordsym then
	readclassdef(owner,0)

when ktypesym then
	readtypedef(owner)
when eofsym then
	serror("Class eof?")
	exit
when semisym then
	lex()

when kenumsym then
	lex()
	readenumtype(owner,0,0)

when ktabledatasym then
	readtabledef(owner,0)

when kmacrosym then
	readmacrodef(owner,0)

when kstructsym,kunionsym then
	unionstr_append(&unionpend,(lx.symbol=kstructsym|'S'|'U'))
	unionlastvar:=nil
	lex()
when kendsym,rbracksym,rcurlysym then
	if unionstring.ulength then
		checkend(kendsym,(unionstr_last(&unionstring)='S'|kstructsym|kunionsym))
		lex()
		if unionlastvar=nil or unionpend.ulength then
			serror("Empty union group")
		fi
		case unionstr_last(&unionlastvar^.uflags)
		when 'E','*' then
		else
			unionstr_append(&unionlastvar^.uflags,'*')
		esac
		unionstr_append(&unionlastvar^.uflags,'E')
		unionstring.ulength--
	else
		exit
	fi

when kmutsym then

	lex()
	if istypestarter() then
readmut::
		++insiderecord
		t:=readtypespec(owner)
		--insiderecord
	else
		serror("need type")
	fi
	readrecordfields(owner,t)

when kletsym then
	serror("Let not allowed")


else
	if istypestarter() then
		goto readmut
	else
		exit
	fi
enddoswitch
end

function readenumtype(ref strec owner,int typedefx,isglobal=0)int=		!READENUMTYPE
ref strec enumowner, stname, nameptr
int isanon, index, startline, closesym, knownindex
unit pone,pindex

enumowner:=owner			!owner of enum typeid
isanon:=0
if not typedefx then			!informal declaration
	if lx.symbol=namesym then		!name provided
		stname:=getduplnameptr(owner,lx.symptr,typeid)
		owner:=stname
		lex()
		checkequals()
		lex()
		adddef(enumowner,owner)
	else
		isanon:=1
	fi
	checksymbol(lbracksym)
	lex()
else
	owner:=ttnamedef[typedefx]
	startline:=getcurrline()
	closesym:=checkbegin(1)
fi

pone:=createconstunit(1,tint)
pindex:=pone
knownindex:=1
index:=1

while lx.symbol=namesym do
	nameptr:=lx.symptr
	lex()
	if lx.symbol=eqsym then	!= follows
		lex()
		pindex:=readunit()
		knownindex:=0
		if pindex.tag=j_const then
			knownindex:=1
			index:=pindex.value
		fi
	fi

	if not isanon then
		stname:=getduplnameptr(owner,nameptr,enumid)
	else
		stname:=getduplnameptr(enumowner,nameptr,constid)
	fi

	if knownindex then
		pindex:=createconstunit(index,ti64)
		stname.code:=pindex
		++index
	else
		stname.code:=pindex
		pindex:=createunit2(j_bin,pindex,pone)
		pindex.genop:=add_op
	fi
	stname.mode:=tint

	if not isanon then
		adddef(owner,stname)
	else
		adddef(enumowner,stname)
	fi

	stname^.isglobal:=isglobal

	if lx.symbol<>commasym then exit fi
	lex()
od

if not typedefx then
	checksymbol(rbracksym)
	lex()
else
	checkbeginend(closesym,kenumsym,startline)
fi

if not isanon then
	typedefx:=createenummode(owner,typedefx)
	return typedefx
else
	return tvoid
fi
end

proc readimportmodule(ref strec owner)=
int isnew,startline,closesym
ref strec d,stname,stname0


if insidedllimport then serror("nested importdll") fi

lex()
if lx.symbol=stringconstsym then
	stname:=addnamestr(lx.svalue)
else
	checksymbol(namesym)
	stname:=lx.symptr
fi

lex()
checkequals()
lex()


isnew:=1
d:=stname^.nextdupl
while d do
	if d^.nameid=dllmoduleid then
		stname:=d
		isnew:=0
		exit
	fi
	d:=d^.nextdupl
od

if isnew then			!new
	stname:=getduplnameptr(stmodule,stname,dllmoduleid)
	if eqstring(stname^.name,"sys") then
		stsysmodule:=stname
	fi
	adddef(stmodule,stname)
	if ndllnametable>=maxdlllib then
		serror("Too many DLL libs")
	fi
	dllnametable[++ndllnametable]:=stname^.name
	stname^.dllindex:=ndllnametable
fi

startline:=getcurrline()
closesym:=checkbegin(0)

insidedllimport:=1

readimportbody(owner)

insidedllimport:=0

checkbeginend(closesym,kimportmodulesym,startline)

end

proc readimportbody(ref strec owner)=
int pos,fflang

pos:=lx.pos

do
	skipsemi()
	switch lx.symbol
	when kfflangsym then
		fflang:=lx.subcode
		lex()
		case lx.symbol
		when kprocsym,kfunctionsym then
			readprocdecl(owner,0,fflang)
		esac	

	when kprocsym,kfunctionsym then
		readprocdecl(owner,0,0)

	when ktypesym then
		readtypedef(owner,program_scope)

	when kconstsym then
		readconstdef(owner,program_scope)

	when kclasssym,krecordsym then
		readclassdef(owner,program_scope)

	when kmutsym then
		lex()
		readvardef(owner,program_scope,0,dllvarid, kmutsym)

	when eofsym then
		exit

	when kendsym then
		exit
	else
		PS("symbol")
		serror("Not allowed in importmodule")
	endswitch
od
end

function readequivfield(ref strec owner)ref strec=
ref strec p,d

checksymbol(namesym)
d:=lx.symptr
lex()

p:=owner^.deflist
while p do
	if eqstring(p^.name,d^.name) then
		return p
	fi

	p:=p^.nextdef
od
cpl d^.name
serror("Can't find @ field")
return nil
end

function readrefproc(ref strec owner,int typedefx,int fflang)int=			!READREFPROC
int kwd,prettype,m,varparams,nparams
[4]int retmodes
ref strec paramlist,stproc
int rettype2, rettype3, nretvalues
ichar name

kwd:=lx.symbol				!remember whether proc or function
lex()

paramlist:=nil
prettype:=tvoid
nretvalues:=0

name:=nextautotype()
stproc:=getduplnameptr(stmodule,addnamestr(name),typeid)
adddef(stmodule,stproc)
retmodes[1]:=tvoid

if kwd=kfunctionsym then
	if lx.symbol=lbracksym then		!possible params
		lex()
		if lx.symbol<>rbracksym then
			paramlist:=readparams(owner,stproc,0,varparams,nparams)
			checksymbol(rbracksym)
		fi
		lex()
		if lx.symbol=colonsym or lx.symbol=sendtosym then
			lex()
			nretvalues:=readreturntype(stproc,retmodes)
		elsif typestarterset[lx.symbol] or lx.symbol=namesym then
			nretvalues:=readreturntype(stproc,retmodes)
		fi
	elsif lx.symbol=colonsym or lx.symbol=sendtosym then
		lex()
		nretvalues:=readreturntype(stproc,retmodes)
	fi
	if nretvalues=0 then
		serror("Function needs return type")
	end

	if nretvalues and kwd=kprocsym then		!proc: result given
		serror("Proc can't return value")
	fi
else					!proc with no result
	if lx.symbol=lbracksym then		!possible params
		lex()
		if lx.symbol<>rbracksym then
			paramlist:=readparams(owner,stproc,0,varparams,nparams)
			checksymbol(rbracksym)
		fi
		lex()
	fi
	if typestarterset[lx.symbol] or lx.symbol=colonsym or lx.symbol=sendtosym then
		serror("proc can't have ret value")
	fi
fi

m:=createrefprocmode(owner,stproc,paramlist,kwd,prettype,typedefx)

	storemode(owner,retmodes[1],stproc.mode)
stproc^.nretvalues:=nretvalues

ttnamedef[m]:=stproc
stproc^.fflang:=fflang

return m
end

proc pushproc(ref strec p)=
if nprocstack>=maxprocstack then
	serror("Too many nested proc")
fi
procstack[++nprocstack]:=currproc
currproc:=p
end

proc popproc=
if nprocstack then
	currproc:=procstack[nprocstack--]
else
	currproc:=stmodule
fi
end

function readassemline:unit=
lex()
return assembleline(1)
end

function readassemblock:unit=
unit ulist,ulistx,u

ulist:=ulistx:=nil

do
	lex()			!first symbol on line
	case lx.symbol
	when eofsym then
		serror("EOF: 'End' missing in Assembler code")
	when kendsym then
		checkend(lx.symbol,kassemsym)
		lex()
		exit
	when semisym then		!assume blank line
	else				!assume some asm code follows
		u:=assembleline(0)
		addlistunit(&ulist,&ulistx,u)
	esac
od


return makeblock(ulist)
end

function assembleline(int oneline)unit=

unit dlist,dlistx,p,pname,q
ichar name
int opc,noperands
ref strec stname

dlist:=dlistx:=nil



if lx.symbol=namesym and nexttoken.symbol in [colonsym,dcolonsym] then	!normal label
	p:=createunit0(j_labeldef)
	stname:=getduplnameptr(currproc,lx.symptr,labelid)
	p^.def:=stname
	adddef(currproc,stname)
	lex()			!skip colon
	if oneline then
		lex()
	fi
	return p

elsif lx.symbol=mulsym then		!*name	macro invocation
	lexchecksymbol(namesym)
	pname:=createname(lx.symptr)
	pname^.pos:=lx.pos

	lex()
	if lx.symbol<>semisym then
		repeat
			addlistunit(&dlist,&dlistx,readunit())
			if lx.symbol=commasym then
				lex()
			fi

		until lx.symbol in [semisym,eofsym]
	fi

	return createunit2(j_assemmacro,pname,dlist)
fi

case lx.symbol
when andlsym then
	opc:=m_andx
doop::
	p:=createunit0(j_assem)
	p.asmopcode:=opc
	lex()
when orlsym then
	opc:=m_orx
	goto doop

when xorlsym then
	opc:=m_xorx
	goto doop

when notlsym then
	opc:=m_notx
	goto doop

elsif lx.symbol=namesym then				!assume opcode

	p:=createunit0(j_assem)

	case lx.subcode
	when asmopcodesym then
		p.asmopcode:=lx.symptr.index

	when jmpccsym then
		p.asmopcode:=m_jmpcc
		p.cond:=lx.symptr.index
	when setccsym then
		p.asmopcode:=m_setcc
		p.cond:=lx.symptr.index
	when movccsym then
		p.asmopcode:=m_cmovcc
		p.cond:=lx.symptr.index
	else
PS("ASM")
		serror("x64 op expected")
	esac

	lex()
else
	SERROR("ASM???")
esac

if lx.symbol not in [semisym,eofsym] then

noperands:=0

	do
		q:=readassemopnd()

		++noperands
		case noperands
		when 1 then p.a:=q; p.hasa:=1
		when 2 then p.b:=q; p.hasb:=1
		when 3 then p.c:=q; p.hasc:=1
		else
			serror("Too many asm opnds")
		esac

		if lx.symbol<>commasym then
			exit
		else
			lex()
		fi
	od

fi

checksymbol(semisym)

return p
end

function readassemopnd:unit p =
	int reg,regix,scale,prefixmode
	unit pcode

	case lx.symbol
	when intconstsym,realconstsym then
		return readunit()
	when namesym then
		case lx.symptr^.subcode
		when regsym then
			p:=createunit0(j_assemreg)
			p.index:=lx.symptr.index
			p.regsize:=lx.symptr.regsize
			lex()
			return p
		when xregsym then
			p:=createunit0(j_assemxreg)
			p.index:=lx.symptr.index
			lex()
			return p
		esac
		return readunit()
	when addsym, subsym then
		return readunit()

	when stdtypesym then
		case lx.subcode
		when tu8,tu16,tu32,tu64 then
		else
			serror("Bad prefix")
		esac
		prefixmode:=lx.subcode
		lexchecksymbol(lsqsym)
		goto gotprefix

	when lsqsym then
		prefixmode:=tvoid
gotprefix::
		reg:=regix:=0
		pcode:=nil
		scale:=1

		lex()
		if lx.symbol=namesym and lx.symptr.subcode=regsym then
			reg:=lx.symptr.index
			lex()
		fi

		if lx.symbol=addsym and nexttoken.symbol=namesym and nextlx().symptr.subcode=regsym then
			lex()
		fi
		if lx.symbol=namesym and lx.symptr.subcode=regsym then
			regix:=lx.symptr.index
			lex()
		fi

		if lx.symbol=mulsym then
			lexchecksymbol(intconstsym)
			case scale:=lx.value
			when 1,2,4,8 then
			else
				serror("Bad scale")
			esac
			lex()
		fi

		case lx.symbol
		when addsym, subsym, intconstsym, namesym, lbracksym,ksyscallsym then
			pcode:=readunit()
		esac
		checksymbol(rsqsym)
		lex()
		p:=createunit1(j_assemmem,pcode)
		if regix=0 and scale>1 then
			regix:=reg
			reg:=0
		fi
		if pcode=nil and reg+regix=0 then serror("Empty []") fi
		p.reg:=reg
		p.regix:=regix
		p.scale:=scale
		p.prefixmode:=prefixmode
		return p

	else
PS("BAD OPND")
		serror("ASM: Bad operand?")
	esac
	return nil
end

function makeastring:unit =
unit ulist,ulistx, p, pconst
ref char s
int length

ulist:=ulistx:=nil

s:=lx.svalue
length:=strlen(s)
to length do
	pconst:=createconstunit(s^,ti64)
	addlistunit(&ulist,&ulistx,pconst)
	++s
od

if lx.subcode='Z' then
	pconst:=createconstunit(0,ti64)
	addlistunit(&ulist,&ulistx,pconst)
	++length
fi

p:=createunit1(j_makelist,ulist)
p^.length:=length
return p
end

function readreturntype(ref strec owner, []int &retmodes)int=
int nretvalues

retmodes[1]:=readtypespec(owner)
nretvalues:=1
while lx.symbol=commasym do
	if nretvalues>=maxtuplesize then
		serror("Too many return values")
	fi
	lex()
	retmodes[++nretvalues]:=readtypespec(owner)
od

return nretvalues
end

function readset:unit=
	int length,nkeyvalues,oldirp
	unit p,ulist,ulistx

	lex()					!first symbol of first expression

	case lx.symbol
	when rsqsym then		!empty set, same as 0
		lex()
		return createunit1(j_makeset,nil)
	when colonsym then
		lexchecksymbol(rsqsym)
		lex()
		return createunit1(j_makedict,nil)
	esac

	length:=0
	nkeyvalues:=0

	ulist:=ulistx:=nil

	do
		oldirp:=inreadprint
		inreadprint:=0
		p:=readunit()
		inreadprint:=oldirp
		if p^.tag=j_keyvalue then ++nkeyvalues fi
		++length

		addlistunit(&ulist,&ulistx,p)

		case lx.symbol
		when commasym then
			lex()
			if lx.symbol=rsqsym then exit fi
		when semisym then
			lexchecksymbol(rsqsym)
			exit
		when rsqsym then
			exit
		else
			serror("readset?")
		esac	
		skipsemi()						!allow a,b,c;]
	od
	lex()

	if nkeyvalues then
		if length>nkeyvalues then serror("dict: mixed elements") fi
		p:=createunit1(j_makedict,ulist)
	else
		p:=createunit1(j_makeset,ulist)
	fi
	p^.length:=length
	return p
end

function istypestarter:int=
	if typestarterset[lx.symbol] then return 1 fi
	if lx.symbol=namesym then				!name ...
		case nexttoken.symbol
		when namesym then					!name name
			return 1
		when dotsym then					!name. ...
			if (nexttoken+1).symbol=namesym and (nexttoken+2).symbol=namesym then
				return 1					!name.name name
			fi
		when addrsym then
			return 1
		esac
	fi
	return 0
end

function readassignment:unit p=
	int pos,opc

	case lx.symbol
	when namesym then
		case nexttoken.symbol
		when semisym, commasym, rbracksym then
			p:=createname(lx.symptr)
			p.pos:=lx.pos
			lex()
			return p
		esac
	esac

	p:=readorterms()

	if (opc:=lx.symbol) in [assignsym,deepcopysym] then
		pos:=lx.pos
		lex()
		p:=createunit2((opc=assignsym|j_assign|j_deepcopy),p,readassignment())
		p.pos:=pos
	fi
	return p
end

function readorterms:unit p=
	int pos

	p:=readandterms()

	while lx.symbol=orlsym do
		pos:=lx.pos
		lex()

		if lx.symbol=assignsym then
			lex()
			p:=createunit2(j_binto,p,readassignment())
			p.genop:=orlto_op
			p.pos:=pos
			exit
		fi

		p:=createunit2(j_orl,p,readandterms())
		p.genop:=orl_op
		p.pos:=pos
	od

	return p
end

function readandterms:unit p=
	int pos

	p:=readcmpterms()

	while lx.symbol=andlsym do
		pos:=lx.pos
		lex()

		if lx.symbol=assignsym then
			lex()
			p:=createunit2(j_binto,p,readassignment())
			p.genop:=andlto_op
			p.pos:=pos
			exit
		fi

		p:=createunit2(j_andl,p,readcmpterms())
		p.genop:=andl_op
		p.pos:=pos
	od

	return p
end

function readcmpterms:unit p=
	int pos,opc,n
	unit ulist,ulistx,q
	[4]byte genops

	p:=readinterms()

	if lx.symbol not in [eqsym,cmpsym] then
		return p
	fi

	ulist:=ulistx:=p
	p:=createunit1(j_cmpchain,p)
	n:=0				!n counts operand after the first
	memset(&genops,0,genops.bytes)

	doswitch lx.symbol
	when eqsym, cmpsym then
		++n
		if n>genops.len then serror("cmpchain: Too many items") fi
		genops[n]:=lx.subcode

		pos:=lx.pos
		lex()

		q:=readinterms()
		addlistunit(&ulist,&ulistx,q)
		q.pos:=pos
	else
		exit
	end doswitch

	if n=1 then
		p.tag:=j_cmp
		q:=p.a
		p.genop:=genops[1]
		p.b:=q.nextunit
		q.nextunit:=nil
		p.hasb:=1
	else
		p.cmpgenop:=genops
	fi	

	return p
end

function readinterms:unit p=
	int pos,opc

	p:=readrangeterm()

	doswitch lx.symbol
	when insym, notinsym then
		opc:=lx.subcode

		pos:=lx.pos
		lex()

		p:=createunit2(j_bin,p,readrangeterm())
		p.genop:=opc
		p.pos:=pos
	else
		exit
	end doswitch

	return p
end

function readrangeterm:unit p=
	int pos,opc

	p:=readaddterms()

	if lx.symbol=rangesym then
		pos:=lx.pos
		lex()
		p:=createunit2(j_makerange,p,readaddterms())
		p.pos:=pos
	fi

	return p
end

function readaddterms:unit p=
	int pos,sym

	p:=readmulterms()

	doswitch sym:=lx.symbol
	when addsym, subsym, iandsym, iorsym, ixorsym,
		concatsym, appendsym, minsym, maxsym then
		pos:=lx.pos
		lex()

		if lx.symbol=assignsym then
			lex()
			p:=createunit2(j_binto,p,readassignment())
			p.genop:=symbolgentoops[sym]
			p.pos:=pos
			exit
		fi

		p:=createunit2(j_bin,p,readmulterms())
		p.genop:=symbolgenops[sym]
		p.pos:=pos
	else
		exit
	end doswitch

	return p
end

function readmulterms:unit p=
	int pos,sym

	p:=readpowerterms()

	doswitch sym:=lx.symbol
	when mulsym, divsym, idivsym, iremsym, shlsym, shrsym then
		pos:=lx.pos
		lex()

		if lx.symbol=assignsym then
			lex()
			p:=createunit2(j_binto,p,readassignment())
			p.genop:=symbolgentoops[sym]
			p.pos:=pos
			exit
		fi

		p:=createunit2(j_bin,p,readpowerterms())
		p.genop:=symbolgenops[sym]
		p.pos:=pos
	else
		exit
	end doswitch

	return p
end

function readpowerterms:unit p=
	int pos

	p:=readterm2()

	while lx.symbol=powersym do
		pos:=lx.pos
		lex()
		p:=createunit2(j_bin,p,readpowerterms())
		p.genop:=power_op
		p.pos:=pos
	od

	return p
end

function readterm2:unit=
	unit p,q,r
	ref char pbyte
	word64 a
	int oldipl,opc,oldinrp,pos,shift,t

	pos:=lx.pos

	p:=readterm()

	doswitch lx.symbol
	when lbracksym then
		lex()
		oldinrp:=inreadprint
		inreadprint:=0
		q:=readslist(1,1)
		checksymbol(rbracksym)
		lex()
		if p.tag=j_syscall then
			p.a:=q; p.hasa:=1
		else
			p:=createunit2(j_callfn,p,q)
		fi
		inreadprint:=oldinrp
		p:=readcondsuffix(p)

	when ptrsym then
		p:=createunit1(j_ptr,p)
		lex()

	when lsqsym then
		p:=readindex(p,0)

	when dotsym then
		p:=readdotsuffix(p)

	when colonsym then
		if inreadprint then exit fi
		lex()
		q:=readunit()
		p:=createunit2((inparamlist|j_keyword|j_keyvalue),p,q)

	when incrsym then
		case lx.subcode
		when incr_op then opc:=loadincr_op
		when decr_op then opc:=loaddecr_op
		esac
		lex()
		p:=createunit1(j_incr,p)
		p.genop:=opc

	when anddotsym then
		lexchecksymbol(lsqsym)
		lex()
		q:=readunit()
		if q^.tag=j_makerange then
			p:=createunit2(j_anddotslice,p,q)
		else
			p:=createunit2(j_anddotindex,p,q)
		fi
		checksymbol(rsqsym)
		lex()

	else
		exit
	enddoswitch

	p^.pos:=pos

	return p
end

function readterm:unit=
unit p,q,r
ref char pbyte
word64 a
int oldipl,opc,oldinrp,pos,shift,t

	pos:=lx.pos

	switch lx.symbol
	when namesym then
		if nexttoken.symbol=atsym then		!type-punning with user type
			p:=readcast()
		else
			p:=createname(lx.symptr)
			p^.pos:=lx.pos
			lex()
		fi

	when intconstsym,realconstsym then
		p:=createconstunit(lx.value,lx.subcode)
		p.istrueconst:=1
		lex()

	when stringconstsym then
		p:=createstringconstunit(lx.svalue,-1)
		lex()

	when astringconstsym then
		p:=makeastring()
		lex()

	when decimalconstsym then
		p:=createunit0(j_decimal)
		p^.svalue:=lx.svalue
		p^.slength:=strlen(p.svalue)
		p^.mode:=tdecimal
		lex()

	when charconstsym then
		a:=0
		shift:=0
		pbyte:=lx.svalue
		to strlen(lx.svalue) do
			a:=a ior word64(pbyte^)<<shift
			shift+:=8
			++pbyte
		od
		if a<=0x7FFF'FFFF'FFFF'FFFF then
			t:=tc64
		else
			t:=tc64
		fi
		p:=createconstunit(a,t)
		p.istrueconst:=1
		lex()

	when lbracksym then
		p:=readlbrack()

	when stdtypesym,krefsym,kicharsym,ktypeofsym then
		p:=readcast()

	when addsym, subsym, minsym, maxsym, abssym, inotsym,
		mathsopsym, sqrtsym, sqrsym, maths2opsym,signsym then
		p:=readopc()

	when notlsym then
		if nextlx().symbol=assignsym then
			p:=readopc()
		else
			lex()
			p:=createunit1(j_notl, readterm2())
			p.genop:=notl_op
		fi

	when istruelsym then
		if nextlx().symbol=assignsym then
			p:=readopc()
		else
			lex()
			p:=createunit1(j_istruel, readterm2())
			p.genop:=istruel_op
		fi

	when lsqsym then
		p:=readset()

	when incrsym then
		opc:=lx.subcode
		lex()
		p:=createunit1(j_incr,readterm2())
		p.genop:=opc

	when ksprintsym then
		p:=readsprint()

	when ksreadsym,ksreadlnsym then
		p:=readsread()

	when addrsym then
		lex()
		p:=createunit1(j_addrof,readterm2())
		if p^.a^.tag=j_callfn then
			if p^.a^.b then
				serror("Params not allowed")
			fi
			p^.a:=p^.a^.a			!lose the call
		fi

	when anddotsym then
		lex()
		p:=createunit1(j_addroffirst,readterm2())

	when compilervarsym then
		p:=readcompilervar()

	when kerrorsym then
		p:= createconstunit(lx.subcode,tint)
		lex()

	when dollarsym then
		if intabledata then
			p:=createstringconstunit(tabledataname,-1)
		else
			if ndollar<=0 then
				serror("[$] No array")
			fi
			p:=createunit1(j_unary,dollarstack[ndollar])
			p.genop:=upb_op
		fi
		lex()

	when kcastsym then
		p:=readcastx()

	when ktypeconstsym then
		lexchecksymbol(lbracksym)
		lex()
		p:=createunit0(j_typeconst)

		p.value:=readtypespec(currproc)
		checksymbol(rbracksym)
		lex()

	when kclampsym then
		lexchecksymbol(lbracksym)
		lex()
		p:=readunit()
		checksymbol(commasym)
		lex()
		q:=readunit()
		if lx.symbol=rbracksym and q^.tag=j_makerange then
			r:=q^.b
			q:=q^.a
		else
			checksymbol(commasym)
			lex()
			r:=readunit()
			checksymbol(rbracksym)
		fi
		lex()

		q:=createunit2(j_bin,p,q)
		q.genop:=max_op
		p:=createunit2(j_bin,q,r)
		p.genop:=min_op

	when kgotosym then
		p:=readgoto()

	when kifsym then
		p:=readif()

	when kunlesssym then
		p:=readunless()

	when kcasesym,kdocasesym,kswitchsym,kdoswitchsym then
		p:=readswitchcase()

	when krecasesym then
		p:=readrecase()

	when kforsym then
		p:=readfor()

	when ktosym then
		p:=readto()

	when kdosym then
		p:=readdo()

	when kwhilesym then
		p:=readwhile()

	when krepeatsym then
		p:=readrepeat()

	when kloopsym then
		p:=readloopcontrol()

	when kreturnsym then
		p:=readreturn()

	when kstopsym then
		p:=readstop()

	when kprintsym then
		p:=readprint()

	when kreadsym then
		p:=readread()

	when ktrysym then	!todo
		p:=readtry()

	when kraisesym then	!todo
		p:=readraise()

	when kyieldsym then
		lex()
		p:=createunit1(j_yield,readunit())
		yieldseen:=1

	when kswapsym then			!swap using function syntax
		lexchecksymbol(lbracksym)
		lex()
		p:=readunit()
		checksymbol(commasym)
		lex()
		q:=readunit()
		checksymbol(rbracksym)
		lex()
		p:=createunit2(j_swap,p,q)

	when kevalsym then
		lex()
		p:=createunit1(j_eval,readunit())

	when kassemsym then
		currproc^.asmused:=1
		assemmode:=1
		if lx.subcode=0 then
			p:=readassemline()
		else
			p:=readassemblock()
		fi
		assemmode:=0

	when ksyscallsym then
		p:=createunit0(j_syscall)
		p.fnindex:=lx.subcode
		lex()

	when knewsym, kdestroysym, kclearsym then
		p:=readnew()

	when kemitcsym then
		p:=createstringconstunit(lx.svalue,-1)
		p.tag:=j_emitc
		lex()

	else
		cpl symbolnames[lx.symbol],=LX.SYMBOL
		serror("readterm?")
	endswitch

	p^.pos:=pos
	return p
end

function readxunit:unit=
	return readsunit()
end

function readsunit(int inwhile=0)unit=
int pos,m,sym,opc
unit ulist,ulistx,p,q,r
ref strec stname

pos:=lx.pos
ulist:=ulistx:=nil

repeat
	while lx.symbol=semisym do
		lex()
	od
	switch lx.symbol
	when kstaticsym then
		lex()
		if lx.symbol in [kletsym,kmutsym] then
			opc:=lx.symbol
			lex()
		else
			opc:=0
		fi
		readvardef(currproc,0,1,staticid,opc)

	when kprocsym,kfunctionsym then
		readprocdef(currproc,0)

	when stdtypesym,lsqsym,krefsym,kicharsym,ktypeofsym,kdictsym,kslicesym then
		if nexttoken.symbol in [lbracksym, atsym, dotsym] then		!is a cast etc
			goto doexec
		else
			sym:=0
			goto dovar
		fi

	when kmutsym,kletsym then
		sym:=lx.symbol
		lex()
dovar::
		q:=readvardef(currproc,0,0,frameid,sym)
		while q do								!initialised decls involve code
			r:=q^.nextunit						!unlink from this block first
			q^.nextunit:=nil
			addlistunit(&ulist,&ulistx,q)		!add one by-one
			q:=r
		od

	when ktypesym then
		readtypedef(currproc,0)

	when kconstsym then
		readconstdef(currproc,0)

	when kclasssym,krecordsym then
		readclassdef(currproc,0)

	when docstringsym then
		adddocstring(lx.svalue)
		lex()

	when kenumsym then		!enum
		lex()
		readenumtype(currproc,0)

	when kmacrosym then
		readmacrodef(currproc,0)

	when ktabledatasym then
		readtabledef(currproc,0)

	when eofsym then
		cpl currproc^.name
		serror("Unexpected EOF in proc")

	when rbracksym,kthensym,kelsifsym,kelsesym,kuntilsym,kwhensym,
			kelsecasesym,kelseswitchsym,kexceptsym,kendsym,rcurlysym then
		exit
	when namesym then
		case nexttoken.symbol
		when dcolonsym then
			p:=createunit0(j_labeldef)
			stname:=getduplnameptr(currproc,lx.symptr,labelid)
			adddef(currproc,stname)
			p^.def:=stname
			p^.trylevel:=try_level
			lex()
			lx.symbol:=semisym
			addlistunit(&ulist,&ulistx,p)
		when namesym then
			sym:=kmutsym
			goto dovar
		goto doexec

		else
			goto doexec
		esac
	when kdosym then				!u;u;u;do rather than u;u;u do
		if inwhile then
			exit
		fi
		goto doexec

	when kextendtypesym then
		readextendtype(currproc)

	when semisym then
	else							!assume a statement
doexec::
		p:=readunit()
doexec2::
		if p^.tag=j_name and lx.symbol=namesym then
			serror("Possibly var/let needed")
		fi
		addlistunit(&ulist,&ulistx,p)
		if lx.symbol=kdosym then
			exit
		fi

	endswitch
until lx.symbol<>semisym

case lx.symbol
when rbracksym,kthensym,kelsifsym,kelsesym,kuntilsym,kwhensym,kdosym,
	kelsecasesym,kelseswitchsym,kexceptsym,kendsym,rcurlysym,commasym,
	barsym then
else
	serror("Readsunit: "";"" expected, or bad unit starter")
esac

if ulist=nil or ulist^.nextunit then
	return createunit1(j_block,ulist)
else
	return ulist
fi
end

proc readmacrodef(ref strec owner, int isglobal)=

ref strec nameptr,stmacro, paramlist,paramlistx, stname

lexchecksymbol(namesym)

nameptr:=lx.symptr
stmacro:=getduplnameptr(owner,nameptr,macroid)
adddef(owner,stmacro)

owner:=stmacro

lex()

paramlist:=paramlistx:=nil

if lx.symbol=lbracksym then			!may have parameters
	lex()
	if lx.symbol<>rbracksym then
		do
			case lx.symbol
			when namesym then
				stname:=getduplnameptr(owner,lx.symptr,macroparamid)
				adddef(owner,stname)
				addlistparam(&paramlist,&paramlistx,stname)
				stname^.nulldef:=lx.symptr

				lex()
				if lx.symbol=rbracksym then
					exit
				fi
				checksymbol(commasym)
				lex()
			else
				serror("macro def params")
			esac
		od
	fi
	lex()						!skip )
fi
stmacro^.paramlist:=paramlist
stmacro^.isglobal:=isglobal

checkequals()
lex()
stmacro^.code:=readunit()
end

proc readimportalias(ref strec dimport)=
	ref strec stmacro

	lexchecksymbol(namesym)			!alias name to use
	stmacro:=getduplnameptr(stmodule,lx.symptr,macroid)
	adddef(stmodule,stmacro)

	lex()

	stmacro^.paramlist:=nil
	stmacro^.code:=createname(dimport)
end

proc domappedalias(ref strec dimport, stimport)=
	ref strec stmacro

	if eqstring(dimport.name,stimport.name) then
		return
	fi

	stmacro:=getduplnameptr(stmodule,dimport,macroid)
	adddef(stmodule,stmacro)
	stmacro^.paramlist:=nil
	stmacro^.code:=createname(stimport)
end

function readrecase:unit=
	lex()
	if lx.symbol=kelsesym then
		lex()
		return createunit0(j_recase)
	else
		return createunit1(j_recase,readunit())
	fi
end

function createblock(unit p, q)unit=
	if q=nil then
		return p
	elsif q.tag=j_block then			!add as first block element
		p.nextunit:=q.a
		q.a:=p
		return q
	else
		p.nextunit:=q
		return makeblock(p)
	fi
end

proc adddocstring(ichar s)=
	if ndocstrings>docstrings.len then
		serror("Too many docstrings")
	fi
	docstrings[++ndocstrings]:=pcm_copyheapstringn(s,strlen(s))
end

global proc readtaggeduniondef(ref strec owner,int isglobal)=
int  m, startline, closesym, mtagged,enummode
ref strec nameptr, sttype

lexchecksymbol(namesym)
nameptr:=lx.symptr
lexchecksymbol(lbracksym)
lex()
enummode:=readtypespec(owner,0)
checksymbol(rbracksym)

lex()
checkequals()

lex()

sttype:=getduplnameptr(owner,nameptr,typeid)
adddef(owner,sttype)
m:=createusertype(sttype)

mtagged:=createtaggedunionmode(owner, m)
sttype.mode:=mtagged
sttype.enumtagmode:=enummode

closesym:=checkbegin(1)

startline:=getcurrline()

readtaggedunionbody(sttype)

checkbeginend(closesym,ktaggedunionsym,startline)

sttype^.isglobal:=isglobal
end

proc readtaggedunionbody(ref strec owner)=
int kwd,t
ref strec d,stname
unit tagvalue

doswitch lx.symbol
when semisym then
	lex()

when kendsym,rbracksym,rcurlysym then
	exit

else
	inreadprint:=1
	tagvalue:=readunit()
	inreadprint:=0
	checksymbol(colonsym)
	lex()

	case lx.symbol
	when kmutsym then

		lex()
		if istypestarter() then
	readvar::
			++insiderecord
			t:=readtypespec(owner)
			--insiderecord
		else
			serror("need type")
		fi
		checksymbol(namesym)
		stname:=getduplnameptr(owner,lx.symptr,fieldid)
		storemode(owner,t,stname.mode)
		adddef(owner,stname)

		stname.code:=tagvalue

		lex()

	else
		if istypestarter() then
			goto readvar
		else
			serror("tagged union?")
		fi
	esac
enddoswitch
end

proc readtaggedfields(ref strec owner,int m)=
int nvars
ref strec stname,stbitfield

nvars:=0
while lx.symbol=namesym do

	stname:=getduplnameptr(owner,lx.symptr,fieldid)
	storemode(owner,m,stname.mode)
	++nvars
	adddef(owner,stname)

	lex()

	if lx.symbol<>commasym then
		exit
	fi
	lex()
od

if nvars=0 then
	serror("No tagged fields")
fi
end

proc readextendtype(ref strec owner)=
	ref strec e
	int t, closesym, startline

	lex()
	t:=readtypespec(owner,0)
	checkequals()
	lex()


	e:=pcm_allocz(strec.bytes)
	e.name:="<extendtype>"
	e.namelen:=1

	e.nextdef:=extendtypelist
	extendtypelist:=e

	closesym:=checkbegin(1)

	startline:=getcurrline()

	readclassbody(e,0)
	e.mode:=t

	checkbeginend(closesym,kextendtypesym,startline)
end

function readnew:unit p=
	unit q
	int n

	p:=createunit0(lx.subcode)
	lexchecksymbol(lbracksym)
	lex()

	if lx.symbol<>rbracksym then

		n:=0

		do
			q:=readunit()
			case ++n
			when 1 then p.a:=q; p.hasa:=1
			when 2 then p.b:=q; p.hasb:=1
			when 3 then p.c:=q; p.hasc:=1
			else
				serror("too many args")
			esac
			if lx.symbol=commasym then
				lex()
			else
				exit
			fi
		od

		checksymbol(rbracksym)
	fi
	lex()

	return p
end

proc readoperatordef(ref strec owner)=
	int opc,opsymbol,amode, bmode,rmode
	unit p

	if owner.nameid<>moduleid then
		serror("Opdef not at module level")
	fi

	lexchecksymbol(lbracksym)
	lex()
	opsymbol:=lx.symbol
	if symboloptypes[opsymbol] not in [bin_op,mon_op, prop_op] then
		case opsymbol
		when lsqsym then
			lexchecksymbol(rsqsym)
			opc:=j_index
		when knewsym then
			opc:=j_new
		when kclearsym then
			opc:=j_clear
		else
			serror("Operator name expected")
		esac
	else
		opc:=symbolgenops[opsymbol]
	fi
	lex()
	if lx.symbol=assignsym then
		opc:=symbolgentoops[opsymbol]
		if opc=0 then
			serror("op:= not supported")
		fi
		lex()
	fi
	checksymbol(rbracksym)
	lexchecksymbol(lbracksym)

	lex()
	amode:=readtypespec(owner)
	if lx.symbol=commasym then
		lex()
		bmode:=readtypespec(owner)
	else
		bmode:=tvoid
	fi
	checksymbol(rbracksym)
	lex()
	rmode:=readtypespec(owner)
	checkequals()

	lex()
	p:=readunit()

CPL =P

	addoverload(owner.moduleno,opc, amode,bmode,rmode,p)
end

function fixcond(unit p)unit=
	if not isboolunit(p) then
		insertunit(p, j_istruel)
		p.genop:=istruel_op
	fi
	return p
end
=== bb_name.m 38/40 ===
import mlib
import clib

import bb_decls
import bb_tables
import bb_support
import bb_lib
import bb_diags

import bb_pclcommon

ref strec currstproc
int allowmodname=0
int noexpand, noassem
int macrolevels

const maxmacroparams=50
[maxmacroparams]ref strec macroparams
[maxmacroparams]ref strec macroparamsgen
[maxmacroparams]unit macroargs
int nmacroparams
int nmacroargs

global proc rx_typetable=
	ref strec d

	for i:=tuser to ntypes do
		if ttbasetype[i]=trecord then
			d:=ttnamedef[i]
			if d.baseclass then
				do_baseclass(d)
			fi
		fi
	od
end

global proc rx_unit(ref strec owner, unit p)=
ref strec d
unit a,b
int n,oldnoexpand,oldnoassem

a:=p^.a
b:=p^.b
mlineno:=p.pos


switch p^.tag
when j_name then
	resolvename(owner,p)
	if p^.def^.nameid=macroid and not noexpand then
		++macrolevels
		expandmacro(p,p,nil)
		rx_unit(owner,p)
		--macrolevels
	fi

when j_keyword then
	rx_unit(owner,b)		!do param value only

when j_dot then
	if b.tag=j_name then
		d:=resolvetopname(owner,b.def,b.moduleno,fmodule:0,fdoambig:0)
		if d and d.nameid=macroid and not noexpand then
			b.def:=d
			++macrolevels
			expandmacro(b,b,nil)
			rx_unit(owner,b)
			--macrolevels

			if b.tag=j_makeset then
				rx_unit(owner,a)
				p.tag:=j_dotslice
				deleteunit(b,b.a)
				return
			fi
		fi
	fi
	resolvedot(owner,p)

when j_callproc, j_callfn then
	if a^.tag=j_name then			!can expand possible macro if params not ready
		oldnoexpand:=noexpand; noexpand:=1
		rx_unit(owner,a)
		noexpand:=oldnoexpand
	else
		rx_unit(owner,a)
	fi

	rx_unitlist(owner,b)


	if a^.tag=j_name then
		d:=a^.def
		case d^.nameid
		when typeid then		!change to type conversion
			p^.tag:=j_convert
			storemode(owner,d^.mode,p.convmode)
			p^.a:=b
			p^.b:=nil; p.hasb:=0
			if b^.nextunit then
				p^.a:=createunit1(j_makelist,b)
				n:=0
				while b do
					++n
					b:=b^.nextunit
				od
				p^.a^.length:=n
			fi
		when macroid then
			++macrolevels
			expandmacro(p,a,b)
			rx_unit(owner,p)
			--macrolevels
		else
			if d^.mode=tvoid then
				p^.tag:=j_callproc
			fi
		esac
	fi


when j_andl, j_orl then
	rx_unit(owner,a)
	rx_unit(owner,b)
	if not isboolunit(a) then insertunit(a,j_istruel); a.genop:=istruel_op fi
	if not isboolunit(b) then insertunit(b,j_istruel); b.genop:=istruel_op fi

when j_istruel then
doistruel::
	rx_unit(owner,a)

	if isboolunit(a) then
		deleteunit(p,a)
	fi
	goto doabc

when j_notl then
	rx_unit(owner,a)
	if a.tag=j_notl then
		deleteunit(p,a)
		p.tag:=j_istruel
		p.genop:=istruel_op
		a:=p.a
		goto doistruel
	fi
	if not isboolunit(a) then
		insertunit(a,j_istruel); a.genop:=istruel_op
		a:=p.a	
	fi
	goto doabc


when j_assemmacro then
	resolvename(owner,a)
	if not noexpand then
		++macrolevels
		oldnoassem:=noassem
		noassem:=1
		expandmacro(p,a,b)
		noassem:=oldnoassem
		rx_unit(owner,p)
		--macrolevels
	fi

else
doabc::
	if p.hasa then rx_unitlist(owner,a) fi
	if p.hasb then rx_unitlist(owner,b) fi
	if p.hasc then rx_unitlist(owner,p.c) fi
endswitch
end

global function rx_module(int n)int=
modulerec m
ref strec stmodule, d
int globalflag,status

currmoduleno:=n

rx_passdef(stprogram,moduletable[n].stmodule)

return 1
end

global proc rx_deflist(ref strec owner,p)=
ref strec pstart:=p
	while p do
		rx_passdef(owner,p)
		p:=p^.nextdef
	od
end

global proc rx_passdef(ref strec owner,p)=
ref strec d

case p^.nameid
when moduleid,dllmoduleid then
	rx_deflist(p,p^.deflist)

when procid then
	rx_deflist(p,p^.deflist)
	currstproc:=p
	rx_unit(p,p^.code)
	currstproc:=nil

when dllprocid then
	rx_deflist(p,p^.deflist)

when constid,staticid,frameid,paramid then
	if p^.at=1 then
		rx_unit(owner,p^.equivvar)
	fi
	if p^.code then
		rx_unit(owner,p^.code)
	fi
when typeid then
	rx_deflist(p,p.deflist)

else
esac
end

proc rx_unitlist(ref strec owner, unit p)=
while p do
	rx_unit(owner,p)
	p:=p^.nextunit
od
end

global function resolvetopname(ref strec owner,stnewname,int moduleno,
	fmodule,fdoambig=1)ref strec=

int i,m,extcount,modno
ref strec p,powner,d,e,dlldef,extdef,moddef,extmod,q
[10]ref strec ambiglist
STATIC INT MAXDUPL
INT NDUPL

if owner^.nameid=procid then
	q:=owner^.deflist
	while q do
		if q^.firstdupl=stnewname then		!use that match
			return q
		fi
		q:=q^.nextdef
	od
fi

p:=stnewname^.nextdupl

extcount:=0
extmod:=dlldef:=extdef:=moddef:=nil
NDUPL:=0

while p do						!for each possibe st entry of the same name
++NDUPL

	powner:=p^.owner			!the owner of that entry

	switch powner^.nameid
	when procid then
		if powner=owner then			!immediate match
			return p
		fi
	when moduleid then			!p is file-scope item
		if powner^.moduleno=moduleno then		!same module
			if owner^.nameid=moduleid then	!immediate match
				return p
			fi
			moddef:=p			!take note, but continue searching (in case proc etc)
		elsif moduletable[moduleno].importmap[powner^.moduleno] then
			if p^.isglobal then
								!matches an external module imported by this name's module
				++extcount			!if an ext match is closest, there can only be one
				extdef:=p
				if extcount<ambiglist.len then
					ambiglist[extcount]:=extdef
				fi
			fi
		fi
	when dllmoduleid then
		modno:=powner^.owner^.moduleno
		if modno=moduleno or moduletable[moduleno].importmap[modno] then
			dlldef:=p
		fi

	when typeid then
		if powner=owner then			!immediate match
			return p
		fi
		if powner=owner.owner then
			return p
		fi
	when programid then					!p is a module
		if p^.nameid=moduleid then		!match a module name
			if p^.moduleno=moduleno then
				if fmodule then
					return p			!immediate match (unless proc but that would have
				fi						!matched by now
			else						!ext module
				extmod:=p				!keep it in reserve
			fi
		fi
	endswitch

	p:=p^.nextdupl
od


if moddef then				!go with that first
	return moddef
fi
if extdef then
	if extcount>1 and fdoambig then
		for i:=1 to extcount do
			extdef:=ambiglist[i]
			println i,extdef^.owner^.name,namenames[extdef^.owner^.nameid]
		od
		rxerror_s("Ambiguous ext name: #",extdef^.name)
	fi
	return extdef
fi
if extmod then return extmod fi
return dlldef				!will be nil when no match
end

global proc resolvename(ref strec owner, unit p)=

	ref strec d,e
	unit q
	int moduleno, mode


	d:=p^.def
	moduleno:=p^.moduleno

	if d^.nameid<>nullid then			!assume already resolved
		return
	fi

	e:=resolvetopname(owner,d,moduleno,allowmodname)
	if not e then
		mode:=tvoid
		case p.avcode
		when 'I', 'T', 'S' then mode:=ti64
		when 'L','A' then mode:=tany
		esac
			


		if mode=tvoid then
			rxerror_s("Undefined: #",d^.name,p)
		else
			e:=addframevar(owner,d,moduleno,mode)
			e^.lineno:=p^.lineno
			if mode<>tany then e^.islet:=1 fi
		fi
	fi

	e^.used:=1

	if e^.nameid=paramid and e^.parammode=out_param then
		p^.tag:=j_ptr
		p^.a:=createname(e)
		p.hasa:=1; p.hasb:=p.hasc:=0
	else
		p^.def:=e			!update link in kcode

		case e^.nameid
		when procid then
			if e^.isglobal then e^.namecat:=globalproc_cat fi
		esac
	fi

end

global function finddupl(ref strec d, pdupl)ref strec=

if pdupl^.nameid<>nullid then		!assume already resolved
	return pdupl
fi
pdupl:=pdupl^.nextdupl

while pdupl do
	if pdupl^.owner=d then
		return pdupl
	fi
	pdupl:=pdupl^.nextdupl
od
return nil
end

proc resolvedot(ref strec owner,unit p)=
unit lhs,rhs
ref strec d,e,t
int m

lhs:=p^.a
rhs:=p^.b
e:=rhs^.def				!p.b will be a name type (could perhaps be stored as p^.def)


rx_unit(owner,lhs)


case lhs^.tag
when j_name then
	d:=lhs^.def
	case d^.nameid
	when moduleid,typeid,procid,typeid,dllmoduleid then
		e:=finddupl(d,e)
		if e then
			p^.tag:=j_name			!convert to dot to name
			p^.a:=p^.b:=nil
			p.hasa:=p.hasb:=0
			p^.def:=e
			case e^.nameid
			when enumid then
			when constid then
			when macroid then
				if e^.nameid=macroid and not noexpand then
					++macrolevels
					expandmacro(p,p,nil)
					rx_unit(owner,p)
					--macrolevels
				fi
			esac
		else
			rxerror_s("Can't resolve .#",p^.b^.def^.name,p)
		fi

	when frameid, staticid, paramid then		!.x applied to normal var
		m:=d^.mode
		case ttbasetype[m]
		when trecord then
		when tref then
			do
				m:=tttarget[m]
				case ttbasetype[m]
				when trecord then
					exit
				when tref then
				else
					rxerror("2:record expected")
				esac
			od
		else
			rxerror("record expected")
		esac
		t:=ttnamedef[m]

		e:=finddupl(t,e)
		if e then
			p^.b^.def:=e
		else
			rxerror_s("Not a field: #",rhs^.def^.name)
		fi
	esac

else
	unless e^.nextdupl then
		rxerror_s("Not a field: #",e^.name)
	endunless
esac
end

proc fixmode(ref typenamerec p)=
	ref int32 pmode
	ref strec a,d,e,f,owner
	int m,moduleno

	pmode:=p.pmode

	m:=-pmode^					!typename index


	d:=owner:=p.owner
	while d.nameid<>moduleid do d:=d.owner od
	moduleno:=d.moduleno

	a:=p.defa
	d:=p.defb

	if a=nil and d then			!simple type name V

		e:=resolvetopname(owner,d,moduleno,0)

	elsif d=nil and a then		!typeno
		rxerror("Fixmode can't do typeof yet")
	else						!assume a.d type reference
		e:=resolvetopname(owner,a,moduleno,0)
		if e then
			f:=e.deflist
			e:=nil
			while f do
				if f.nameid=typeid and f.firstdupl=d then

					e:=f
					exit
				fi
				f:=f.nextdef
			od

		fi

	fi

	if e and e.nameid=typeid then
		pmode^:=e.mode

	else
		rxerror_s("2:Can't resolve tentative type: #",d.name)
	fi
end

global proc fixusertypes=
	ref typenamerec p
	int npasses,notresolved,m,zerosizes
	ref strec d

	npasses:=0
	repeat
		++npasses
		notresolved:=0

		for i to ntypenames do
			p:=&typenames[i]

			if p.pmode^<0 then
				mlineno:=typenamepos[i].pos
				fixmode(p)
				if p.pmode^<0 then
					++notresolved
				fi
			fi
		od

		if npasses>5 then
			println "Type phase errors - check these user types:"

			for i to ntypenames do
				p:=&typenames[i]

				if p.pmode^<0 then
					d:=p.defb
					if d=nil then d:=p.defa fi
					println "	",d.name
				fi
			od

			rxerror("Fixtypes: too many passes (cyclic ref?)")
		fi

	until notresolved=0
end

global proc fixblockparams=

	ref procrec pp
	ref strec d,e

	pp:=proclist
	while pp do
		d:=pp^.def
		e:=d.deflist
		while e do
			if e.nameid=paramid then
				if ttcat[e.mode]=block_cat and e.parammode<>out_param then
					e.parammode:=out_param
					e.mode:=createrefmode(d,e.mode,0)
				fi
			fi
			e:=e.nextdef
		od
		
		pp:=pp^.nextproc
	od
end

proc rx_assem(ref strec owner, unit p,a,b)=

unit q
ref strec d
ref char s,pdest
[512]char str
ref strbuffer expr
int c


q:=b
while q do					!resolve name list
	if q^.tag=j_name then
		resolvename(owner, q)
	fi
	q:=q^.nextunit
od

pdest:=&.str

s:=a^.svalue
q:=b

while c:=s++^ do
	if c='#' then

		case q^.tag
		when j_name then

			d:=q^.def
			case d^.nameid
			when constid then
RXERROR("ASM/TXNC")
			when frameid, paramid then
			else
			esac
		when j_const then
			if not ttisint[q^.mode]<>'I' then rxerror("assem/macro/not int") fi
		else
			rxerror("assem/macro/arg?")
		esac
		q:=q^.nextunit
	else
	fi
od
pdest^:=0
a^.svalue:=pcm_copyheapstring(&.str)
a^.slength:=strlen(&.str)
end

global function resolve_equiv_name(ref strec owner,p)ref strec=
if p^.nameid=fieldid then
	return p
fi

RXERROR("RESOLVE EQUIV FIELD/COMPLEX")

return nil
end

function addframevar(ref strec owner, d, int moduleno, mode)ref strec=
	ref strec e
	e:=getduplnameptr(owner,d,frameid)
	storemode(owner,mode,e^.mode)
	adddef(owner,e)
	return e
end


function copylistunit(unit p)unit=
unit q

unit plist,plistx
plist:=plistx:=nil
while p do
	q:=copyunit(p)
	addlistunit(&plist,&plistx,q)
	p:=p^.nextunit
od
return plist
end

function copyunit(unit p)unit=
unit q
ref strec d

if p=nil then return nil fi


if p^.tag=j_name then
	d:=p^.def
	for i to nmacroparams do
		if macroparamsgen[i]=d then
			return copyunit(macroargs[i])
			exit
		fi
	od
fi

q:=createunit0(p^.tag)


q^:=p^
q.nextunit:=nil
if q.hasa then q.a:=copylistunit(q.a); q.hasa:=1 fi
if q.hasb then q.b:=copylistunit(q.b); q.hasb:=1 fi
if q.hasc then q.c:=copylistunit(q.c); q.hasc:=1 fi

return q
end

proc replaceunit(unit p,q)=
unit pnext
pnext:=p^.nextunit
p^:=q^
p^.nextunit:=pnext
end

proc expandmacro(unit p, a, b)=
ref strec d,pm
unit pnew
int ignoreargs

if macrolevels>10 then
	rxerror("Too many macro levels (recursive macro?)")
fi

d:=a^.def


pm:=d^.paramlist
nmacroparams:=0
while pm do
	if nmacroparams>=maxmacroparams then
		rxerror("macro param overflow")
	fi
	macroparams[++nmacroparams]:=pm
	macroparamsgen[nmacroparams]:=pm^.nulldef
	pm:=pm^.nextparam
od


nmacroargs:=0


while b do
	if nmacroargs>=maxmacroparams then
		rxerror("macro arg overflow")
	fi
	macroargs[++nmacroargs]:=b
	b:=b^.nextunit
od

if nmacroargs<nmacroparams then
	rxerror("Too few macro args")
fi

ignoreargs:=0
if nmacroargs>0 and nmacroparams=0 then		!ignore extra params
	ignoreargs:=1
	nmacroargs:=nmacroparams:=0

elsif nmacroargs>nmacroparams then
	rxerror("Too many macro args")
fi

pnew:=copyunit(d.code)

if not ignoreargs then				!normal expansion
	replaceunit(p,pnew)
else								!keep call and paramlist; just replace fn name
	p^.a:=pnew						!with expansion
fi
end

proc duplfield(ref strec owner,p,q)=

	if p^.code then
		serror("DUPLFIELD")
	fi


	q^.at:=p^.at

	q^.uflags:=p^.uflags		!for ^.uflags
	storemode(owner,p^.mode,q^.mode)
end

proc do_baseclass(ref strec p)=
	ref strec d,e,newd,dbase
	int normalexit

	dbase:=ttnamedef[p.baseclass]
	d:=dbase.deflist

	while d do				!for each element of base class
		e:=p.deflist

		normalexit:=1
		while e do			!for each element of new class
			if eqstring(d^.name,e^.name) then
				normalexit:=0
				exit
			fi
			e:=e^.nextdef
		od
		if normalexit then
			case d^.nameid
			when procid,linkid then
				newd:=getduplnameptr(p,d,linkid)
				newd^.equivfield:=d
			else
				newd:=getduplnameptr(p,d,d^.nameid)
				duplfield(p.owner,d,newd)
			esac
			adddef(p,newd)
		fi
		d:=d^.nextdef
	od
end
=== bb_type.m 39/40 ===
import msys
import mlib
import clib
import oslib

import bb_decls
import bb_tables
import bb_support
import bb_lib
import bb_name
import bb_diags
import bb_pclcommon

import bb_blockpcl

const nolv=0
const needlv=1

const maxparams=100
const maxfields=200
int countedfields
int inassem

global proc $init=
	inittypetables()
end

global proc tx_allprocs=
ref procrec pp
unit pcode

pp:=proclist
while pp do
	currproc:=pp.def
	pcode:=currproc.code

	if ttisshort[currproc.mode] then
mlineno:=currproc.pos
 txerror("proc short ret type") fi

    tpass(pcode,(currproc.nretvalues>1|ttuple|currproc.mode))

	case ttbasetype[currproc.mode]
	when tvoid then		!PROC
	when ttuple then	!MULT FN
	else				!REGULAR FN
		if pcode.tag<>j_return then
			insertunit(pcode,j_return)
			pcode.mode:=currproc.mode
			pcode.resultflag:=1
		fi
	esac

	pp:=pp.nextproc
od
end

proc tpass(unit p, int t=tany, lv=nolv)=
ref strec d
unit a,b,c
int oldmlineno,m,nparams,paramtype,restype

if p=nil then return fi

oldmlineno:=mlineno

mlineno:=p.pos


a:=p.a
b:=p.b

p.resultflag:=t<>tvoid

switch p.tag
when j_name then
	tx_name(p,t,lv)
when j_const, j_decimal then

when j_typeconst then
	p.mode:=ti64

when j_bytesize, j_bitwidth then
	tx_bytesize(p,a)

when j_bin then
	tx_bin(p,a,b)

when j_unary then
	tx_unary(p,a)

when j_binto then
	tx_binto(p,a,b)

when j_unaryto then
	tx_unaryto(p,a)

when j_assign,j_deepcopy then
	tx_assign(p,a,b,t)

when j_multexpr then
	while a do
		tpass(a)
		a:=a.nextunit
	od

when j_cmp then
	tx_cmp(p,a,b)

when j_addrof then
	if a.tag=j_ptr then
		deleteunit(p,a)
		deleteunit(p,p.a)
		tpass(p,t)
	else
		tpass(a,,needlv)
		p.mode:=createrefmode(nil,a.mode)
	fi

when j_addroffirst then
	tx_addroffirst(p,a,t)

when j_if then
	tx_if(p,a,b,p.c,t,lv)

when j_longif then
	tx_longif(p,a,b,t,lv)

when j_index then
	tx_index(p,a,b,t,lv)

when j_ptr then
	tx_ptr(p,a,t,lv)

when j_callproc, j_callfn then
	tx_callproc(p,a,b,t)

when j_dot then
	tx_dot(p,a,b,lv)

when j_andl, j_orl, j_xorl then
	tx_andl(p,a,b)

when j_notl then
	tx_notl(p,a)

when j_istruel then
	tx_istruel(p,a)

when j_convert then
	tx_convert(p,a,1)

when j_typepun then
	tx_typepun(p,a)

when j_sliceptr then
	tx_sliceptr(p,a)


when j_incr then
	tx_incrto(p,a,t)

when j_makerange then
	tx_makerange(p,a,b)

when j_makeset then
	tx_makeset(p,a,t)

when j_makedict then
	tx_makedict(p,a,t)

when j_swap then
	tx_swap(p,a,b)

when j_select then
	tx_select(p,a,b,p.c,t,lv)

when j_switch, j_doswitch then
	tx_switch(p,a,b,p.c,t,lv)

when j_case, j_docase then
	tx_case(p,a,b,p.c,t,lv)

when j_exprlist then
	tx_exprlist(p,a,t)


when j_dotindex, j_dotslice, j_anddotindex then
	tx_dotindex(p,a,b,lv)

when j_slice then
	tx_slice(p,a,b)





when j_block,j_stmtblock then
	tx_block(p,a,t,lv)

when j_eval then
	tpass(a,tany)

when j_do then
	tpass(a,tvoid)


when j_return then
	tx_return(p,a,t)

when j_print,j_println,j_fprint,j_fprintln then

	tx_unitlist(a)
	fixchararray(a)

	while b do
		if b.tag=j_fmtitem then
			tpass(c:=b.a)
			tpass(b.b,trefchar)
		else
			tpass(c:=b)
		fi
		fixchararray(c)
		b:=b.nextunit
	od
	tx_unitlist(p.c)

when j_forup, j_fordown then
	tx_for(a,b,p.c)

when j_forall, j_forallrev then
	tx_forall(a,b,p.c)

when j_to then
	tpass(a,ti64)
	tpass(b,tvoid)
	tpass(p.c,ti64)		!when autovar present

when j_autocast then
	tpass(a)
	if t=tany then txerror("cast() needs type") fi
	coerceunit(a,t,1)
	deleteunit(p,a)

when j_makelist then
	tx_makelist(p,a,t,lv)

when j_stop then
	tpass(a,ti64)

when j_exit,j_redo, j_restart, j_next then
	tx_exit(p,a)

when j_goto then
	tx_goto(p,a)

when j_labeldef then

when j_while then

	tcond(a)
	if iscondtrue(a) then
		p.tag:=j_do
		p.a:=b
		p.hasb:=0
	elsif iscondfalse(a) then
		p.tag:=j_null
		p.hasa:=p.hasb:=0
	fi
	tpass(b,tvoid)

when j_repeat then
	tpass(a,tvoid)
	tcond(b)
	if iscondtrue(b) or iscondfalse(b) then txerror("repeat/const cond") fi

when j_nogap then

when j_assem then
	if t<>tvoid then
		p.mode:=t
	fi

	inassem:=1
	tx_unitlist(a)
	tx_unitlist(b)
	tx_unitlist(p.c)
	inassem:=0

when j_assemreg,j_assemxreg then
when j_assemmem then
	tpass(a)

when j_typeof then
	tpass(a)
	if a.tag=j_typeconst then
		p.value:=a.value
	else
		p.value:=a.mode
	fi
	p.tag:=j_typeconst
	p.mode:=ti64
	p.a:=nil
	p.hasa:=0

when j_typestr then
	tpass(a)
	if a.tag=j_typeconst then
		m:=a.value
	else
		tpass(a)
		m:=a.mode
	fi
	p.tag:=j_const
	p.mode:=trefchar
	p.a:=nil; p.hasa:=0
	p.svalue:=pcm_copyheapstring(strmode(m,0))
	p.slength:=strlen(p.svalue)
	p.isastring:=1


when j_fmtitem then
	tpass(a)
	tpass(b)

when j_readln then
	tpass(a)

when j_read then
	if a then
		tpass(a,tc64)
	fi
	if ttisallnum[t] then
		t:=gettypebase(t)
	fi
	p.mode:=t


when j_recase then
	if a then
		tpass(a,ti64)
		if a.tag<>j_const then
			txerror("recase must be const")
		fi
	fi


when j_cvlineno then
	p.mode:=ti64
when j_cvfilename,j_cvmodulename then
	p.mode:=trefchar

when j_bitfield then
	tx_bitfield(p,a,lv)

when j_syscall then
	restype:=tvoid
	paramtype:=tvoid
	case p.fnindex
	when sysfn_get_nprocs then restype:=ti64
	when sysfn_get_nexports then restype:=ti64
	when sysfn_get_procname then paramtype:=ti64; restype:=trefchar; 
	when sysfn_get_procaddr then paramtype:=ti64; restype:=tref; 
	when sysfn_get_procexport then paramtype:=ti64; restype:=tref; 
	esac

	if paramtype<>tvoid then
		if a=nil then txerror("sys: arg missing") fi
		tpass(a,paramtype)
		if a.nextunit then txerror("sys: too many args") fi
	elsif a then txerror("sys: too many args")
	fi

	p.mode:=restype

when j_emitc then

when j_cmpchain then
	tx_cmpchain(p,a)

else
	CPL "TXUNIT: CAN'T DO:",jtagnames[p.tag]
doelse::
	if p.hasa then tx_unitlist(a,t) fi
	if p.hasb then tx_unitlist(b,t) fi
	if p.hasc then tx_unitlist(p.c,t) fi
endswitch


tevaluate(p)

case p.tag
when j_makelist, j_return then
else
	if t<>tany and t<>tvoid and p.mode<>t then		!does not already match
		coerceunit(p,t)			!apply soft conversion
	fi
esac
IF T=TVOID THEN
	CASE P.TAG
	WHEN J_CONST, J_BIN, j_UNARY, J_CMP THEN
		TXERROR("Eval needed")
	WHEN J_NAME THEN
		unless ttisref[p.mode] and tttarget[p.mode]=tlabel then
			TXERROR("Eval needed2")
		end

	esac
fi


mlineno:=oldmlineno
end

proc tx_block(unit p,a, int t,lv)=
	while a and a.nextunit do
		tpass(a,tvoid)
		a:=a.nextunit
	od
	if a then
		tx_unitlist(a,t,lv)
		p.mode:=(t<>tvoid|a.mode|tvoid)
	fi
end

global proc tx_typetable=
	ref strec d

	for i:=tuser to ntypes do
		if ttbasetype[i]=trecord then
			tx_passdef(d:=ttnamedef[i])
		fi
		setmodesize(i)
	od
end

proc setmodesize(int m)=
	int size,target

	if ttsize[m] then return fi

	mlineno:=ttlineno[m]
	case ttbasetype[m]
	when tarray then
		setarraysize(m)
	when trecord then
		setrecordsize(m)
	when tvoid,tproc then
	when tslice then
		setslicesize(m)
	when tauto then
TXERROR("SETMODESIZE/AUTO?")
	when tany then

	when tpending then
		target:=tttarget[m]
		setmodesize(target)

		ttbasetype[m]:=ttbasetype[target]
		ttsize[m]:=ttsize[target]
		ttlower[m]:=ttlower[target]
		ttlength[m]:=ttlength[target]
		ttnamedef[m]:=ttnamedef[target]
		ttpcltype[m]:=ttpcltype[target]

	when tenum then
		ttsize[m]:=8
	when ttuple then

	else
		if size:=ttsize[ttbasetype[m]] then
			ttsize[m]:=size
			return
		fi
		cpl "SIZE 0:",strmode(m),=m,=stdnames[ttbasetype[m]]
		CPL("Can't set mode size")
	esac
end

proc setarraysize(int m)=
int lower,length,elemsize,target,size
unit pdim,a,b

	if ttsizeset[m] then return fi

	pdim:=ttdimexpr[m]

	if pdim then
		a:=pdim.a
		b:=pdim.b
		rx_unit(ttowner[m],pdim)

		case pdim.tag
		when j_makerange then
			tpass(a)
			tpass(b)
			lower:=getconstint(a)
			length:=getconstint(b)-lower+1
		when j_keyvalue then
			tpass(a)
			lower:=getconstint(a)
			if b then
				tpass(b)
				length:=getconstint(b)
			else
				length:=0
			fi
		else
			tpass(pdim)
			length:=getconstint(pdim)
			lower:=1
		esac
	else
		lower:=1
		length:=0
	fi

	ttdimexpr[m]:=nil

	ttlower[m]:=lower
	ttlength[m]:=length

	target:=tttarget[m]
	setmodesize(target)
	elemsize:=ttsize[tttarget[m]]
	ttsize[m]:=size:=length*elemsize
	ttsizeset[m]:=1

	case size
	when 8 then
		ttpcltype[m]:=tu64
		ttcat[m]:=d64_cat
		ttcat2[m]:=d64_cat
	when 4,2,1 then
		ttcat[m]:=ttcat2[m]:=short_cat
		ttpcltype[m]:=(size=4|tu32|(size=2|tu16|tu8))
	esac


end

proc setslicesize(int m)=
unit pdim

	if ttsize[m] then return fi

	pdim:=ttdimexpr[m]

	if pdim then
		rx_unit(ttowner[m],pdim)
		tpass(pdim)
		ttlower[m]:=getconstint(pdim)
		ttdimexpr[m]:=nil
	else
		ttlower[m]:=1
	fi

	setmodesize(tttarget[m])
	ttsize[m]:=ttsize[tslice]
end

proc tcond(unit p)=
unit a,b

a:=p.a
b:=p.b

tpass(p)

end

global function tx_module(int n)int=
modulerec m
ref strec stmodule, d
int globalflag,status

currmoduleno:=n


tx_passdef(moduletable[n].stmodule)

return 1
end

global proc tx_passdef(ref strec p)=
ref strec d
int oldmlineno
unit q


if p.txdone then
	return
fi

oldmlineno:=mlineno
mlineno:=p.pos

d:=p.deflist
while d do


	tx_passdef(d)

	d:=d.nextdef
od

q:=p.code

case p.nameid
when procid then
	currproc:=nil
when constid,enumid then
	tx_namedconst(p)
when staticid, frameid, paramid then
	tx_namedef(p)
esac

p.txdone:=1
mlineno:=oldmlineno
end

proc tx_unitlist(unit p, int t=tany, lv=nolv)=
	while p do
		tpass(p,t)
		p:=p.nextunit
	od
end

proc tx_namedef(ref strec d)=
int m,mold
unit dcode,pequiv

m:=d.mode
setmodesize(m)

if d.circflag then
	txerror("Circular reference detected")
fi
if d.txdone then return fi
dcode:=d.code

d.circflag:=1

if d.at=1 then
	pequiv:=d.equivvar
	if pequiv.tag=j_addrof then deleteunit(pequiv,pequiv.a) fi
	if pequiv.tag<>j_name then
		txerror("@name needed")
	fi
	tpass(pequiv)
fi

if dcode and d.nameid<>frameid then


	mold:=m
	m:=gettypebase(m)


	if ttbasetype[m]=tslice and dcode.tag=j_const and dcode.mode=trefchar then
		tpass(dcode,trefchar)
	else
		tpass(dcode,m)
	fi
	d.circflag:=0
	d.txdone:=1
	if ttbasetype[m]=tarray and ttlength[m]=0 then
		d.mode:=dcode.mode
	fi

	if mold<>m then
		if ttisinteger[m] and ttisshort[mold] then
			insertunit(d.code,j_shorten)
			d.code.mode:=mold
		elsif mold=tr32 then
			d.code.mode:=mold
		fi

	fi

	if d.nameid=staticid then
		checkconstexpr(d.code)
	fi

elsif dcode and d.nameid=frameid and ttbasetype[m]=tarray and ttlength[m]=0 then
	tpass(dcode,m)
	d.mode:=dcode.mode
	d.circflag:=0
	d.txdone:=1

else
	d.circflag:=0
	d.txdone:=1
fi
end

global proc tx_namedconst(ref strec d)=
	int m

	if d.circflag then
		txerror("Circular const reference detected")
	fi

	unit q
	if d.txdone then return fi
	q:=d.code

	m:=d.mode

	d.circflag:=1
	tx_expr(q,(m=tauto|tany|m))

	d.circflag:=0
	checkconstexpr(q)
	if m=tauto then
		d.mode:=q.mode
	fi

	d.txdone:=1
end

proc tx_expr(unit p, int t=tany)=
tpass(p,t)
end

proc checkconstexpr(unit p)=
unit q
int pmode

case p.tag
when j_const then
	return
when j_makelist then
	q:=p.a
	while q do
		checkconstexpr(q)
		q:=q.nextunit
	od

when j_convert then

	if ttbasetype[p.a.mode]=tref then
		if tttarget[p.a.mode]=tvoid then
			p.a.mode:=p.mode
			deleteunit(p,p.a)
		else
			goto error
		fi
	fi
	goto error


when j_shorten then
	checkconstexpr(p.a)

when j_addrof, j_addroffirst then
	case p.a.tag
	when j_name then
	else
		goto error
	esac

else
error::
	println jtagnames[p.tag],STRMODE(P.MODE)
PRINTUNIT(P)
	txerror("Getconstexpr: not const")
esac
end

function getconstint(unit q, int t=tany)int64=
checkconstexpr(q)

if ttisinteger[q.mode] then
	if ttsize[q.mode]=16 then
		GERROR("GETCONSTINT/128")
	fi
	return q.value
elsif ttisreal[q.mode] then
	return q.xvalue
else
	cpl strmode(q.mode)
	txerror("Getconstint: not int32/64")
fi
return 0
end

proc makenewconst(unit p,int64 x,int t=tvoid)=

	p.tag:=j_const
	p.a:=p.b:=nil
	p.hasa:=p.hasb:=0
	p.value:=x
	p.isconst:=1
	if t<>tvoid then
		p.mode:=t
	fi
end

proc tx_name(unit p,int t,lv)=
ref strec d
int oldmlineno
unit pcode
oldmlineno:=mlineno

d:=p.def
mlineno:=d.pos

switch d.nameid
when constid,enumid then			!note: currently, rxpass converts names to constants

	if lv then txerror("&const") fi

	tx_namedconst(d)
	pcode:=d.code

	p.tag:=j_const
	p.def:=nil
	p.a:=nil
    p.c:=nil
	p.hasa:=p.hasc:=0

	if pcode.tag=j_convert then		!assume c_soft
		p.value:=pcode.a.value

	else
		p.value:=pcode.value
	fi

	p.slength:=pcode.slength
	p.mode:=d.mode
	p.isconst:=1
	p.isastring:=pcode.isastring

when staticid,frameid,paramid then

if d.islet and lv then
CPL D.NAME,=LV,D.ISLET
	txerror("Can't use 'let' as lvalue")
fi

	tx_namedef(d)

	if not inassem then
		p.mode:=d.mode
		twiden(p,lv)
	else
		p.mode:=trefchar
	fi

when procid,dllprocid then

	p.mode:=trefproc	!use generic refproc mode (yields return type of actual proc mode
			!after a call op, or actual refproc in other context. Don't use actual
			!refproc here, to avoid generating thousands of ref proc modes, one
			!for each call, that will never be needed

when labelid,blockid then
	p.mode:=treflabel

when moduleid then
	txerror_s("Module name can't be used on it's own: #",d.name)

when fieldid then
	p.mode:=d.mode

when typeid then
	p.tag:=j_typeconst
	p.value:=d.mode
	p.mode:=ti64

when dllvarid then
	if d.code then
		txerror("Can't init dllvar")
	fi
	p.mode:=d.mode

else
MLINENO:=P.POS
CPL NAMENAMES[D.NAMEID]
	txerror_ss("TNAME? # #",namenames[d.nameid],d.name)
endswitch
mlineno:=oldmlineno

end

proc tx_bin(unit p,a,b)=
	int amode,bmode,abase,bbase,cmode, opc, relop

	tpass(a)
	tpass(b)

	amode:=a.mode
	bmode:=b.mode

	abase:=ttbasetype[amode]
	bbase:=ttbasetype[bmode]
	relop:=0


	case p.genop
	when add_op then				!ref+ref not allowed; or ref+int (later refchar+refchar)
		if abase=tref and bbase=tref then
			if a.isastring and b.isastring then
				combinestrings(p)
				return
			fi

			txerror("ref+ref")
		fi
		if abase=tref and bbase<=tlastnum then
			coerceunit(b,ti64)
			p.opindex:=op_add_refoff
			p.mode:=amode
			return
		fi
	when sub_op then				!ref-int or ref-ref
		if abase=tref and bbase=tref then
			if not comparemodes(amode, bmode) then
				txerror("ref-ref: not compat")
			fi
			p.opindex:=op_sub_ref
			p.mode:=ti64
		elsif abase=tref and bbase<=tlastnum then
			coerceunit(b,ti64)
			p.opindex:=op_sub_refoff
			p.mode:=amode
			return
		fi
	when shl_op, shr_op then
		coerceunit(b,ti64)
		p.opindex:=optypetable[p.genop,abase]

		if p.opindex=0 then txerror("shl/shr?") fi
		p.mode:=amode
		return
	when eq_op, ne_op, lt_op, le_op, ge_op, gt_op then
		if abase=bbase=tref then
			p.opindex:=optypetable[p.genop,ti64]
			p.mode:=ti64		
			return
		fi
		if p.genop not in [eq_op, ne_op] then
			relop:=1
		fi

	when in_op, notin_op then
		if not isnum(abase) then txerror("IN lhs not int") fi
		case b.tag
		when j_makerange,j_makeset then
			p.tag:=(b.tag=j_makerange|j_inrange|j_inset)
			p.mode:=ti64
			if p.genop=notin_op then
				addnotl(p)
			fi
			return
		else
			txerror("IN ?")
		esac

	esac

	if isnum(abase) and isnum(bbase) then	!num op num

		if relop and ttsize[abase]<16 then

			if abase=tu64 and bbase<>tu64 then
				if b.tag=j_const and b.istrueconst and b.value.[63]=0 then
					bbase:=b.mode:=tu64
				fi
			elsif abase<>tu64 and bbase=tu64 then
				if a.tag=j_const and a.istrueconst and a.value.[63]=0 then
					abase:=a.mode:=tu64
				fi
			fi

			if abase=tu64 and bbase<>tu64 or abase<>tu64 and bbase=tu64 then
				txerror("Mixed sign")
			fi
		fi

		if typerank[abase]>=typerank[bbase] then
			cmode:=abase
		else
			cmode:=bbase
		fi

		if p.genop=div_op and ttisinteger[cmode] then
			p.genop:=idiv_op
		fi

		opc:=optypetable[p.genop,cmode]

		if opc=0 then
CPL JTAGNAMES[P.TAG],=GENOPNAMES[P.GENOP],=STRMODE(AMODE), =STRMODE(BMODE)
			txerror("bin/num?")
		fi
		coerceunit(a,cmode)
		coerceunit(b,cmode)

	elsif isvarnd(abase) and isvarnd(bbase) then	!num op num
		if not comparemodes(amode, bmode) then
			txerror("bin/var: not compat")
		fi
		cmode:=amode
		opc:=optypetable[p.genop,tvar]
		if opc=0 then txerror("bin/var?") fi

	else
		if not comparemodes(amode,bmode) then
			txerror_ss("BIN: modes not compatible: # #",strmode(amode),strmode2(bmode))
		fi
		cmode:=amode
		opc:=optypetable[p.genop, getnewbase(abase)]
		if opc=0 then
			txerror_ss("1:BIN/other: Can't find op: #:#",genopnames[p.genop],strmode(abase))
		fi
	fi

	if intresult[p.genop] or opc in [op_sub_ref] then
		cmode:=ti64
	fi

	p.opindex:=opc
	p.mode:=cmode
end

proc tx_binto(unit p,a,b)=
	int abase, bbase, amode,bmode, opc

	tpass(a,,needlv)
	tpass(b)

	amode:=a.mode
	bmode:=b.mode

	abase:=ttbasetype[amode]
	bbase:=ttbasetype[bmode]

	if p.genop=divto_op and ttisinteger[abase] then
		p.genop:=idivto_op
	fi

	p.mode:=tvoid

	case p.genop
	when addto_op then				!ref+ref not allowed; or ref+int (later refchar+refchar)
		if abase=tref and bbase=tref then
			txerror("to:ref+ref")
		fi
		if abase=tref and bbase<=tlastnum then
			coerceunit(b,ti64)
			p.opindex:=op_addto_refoff
			return
		fi
	when subto_op then				!ref-int
		if abase=tref and bbase<=tlastnum then
			coerceunit(b,ti64)
			p.opindex:=op_subto_refoff
			return
		fi
	when shlto_op, shrto_op then
		coerceunit(b,ti64)
		p.opindex:=optypetable[p.genop,abase]
		return
	esac

	if isnum(abase) and isnum(bbase) then	!num op num
		opc:=optypetable[p.genop,abase]
		if opc=0 then txerror("binto/num?") fi
		coerceunit(b,abase)

	elsif isvarnd(abase) and isvarnd(bbase) then	!num op num
		if not comparemodes(amode, bmode) then
			txerror("binto/var: not compat")
		fi
		opc:=optypetable[p.genop,tvar]
		if opc=0 then txerror("bin/var?") fi
	elsif ttisshort[abase] and isnum(bbase) then
		opc:=optypetable[p.genop,tu8]
		if opc=0 then txerror("binto/u8?") fi
		coerceunit(b,abase)

	else
		if not comparemodes(amode,bmode) then
			txerror_ss("BIN: modes not compatible: # #",strmode(amode),strmode(bmode))
		fi
		opc:=optypetable[p.genop, getnewbase(amode)]
		if opc=0 then
			txerror_ss("2:BIN/other: Can't find op",jtagnames[p.tag],strmode(amode))
		fi
	fi

	p.opindex:=opc
end

function getdominantmode(int amode,bmode)int=
	int abase,bbase

	abase:=ttbasetype[amode]
	bbase:=ttbasetype[bmode]

	if abase<=tlastnum and bbase<=tlastnum then	!num op num
		if typerank[abase]>=typerank[bbase] then
			return abase
		else
			return bbase
		fi

	elsif amode=tvar or bmode=tvar then
		return tvar

	else
		if not comparemodes(amode,bmode) then
			txerror("Getdom: no dominant mode")
		fi
		return amode
	fi
end

function getdominantmodepp(unit a,b)int=
	int amode:=a.mode, bmode:=b.mode	
	int abase,bbase

	abase:=ttbasetype[amode]
	bbase:=ttbasetype[bmode]

	if abase<=tlastnum and bbase<=tlastnum then	!num op num
		if typerank[abase]>=typerank[bbase] then
			return abase
		else
			return bbase
		fi

	elsif amode=tvar or bmode=tvar then
		return tvar

	else
		if not comparemodes(amode,bmode) then
			txerror("Getdom: no dominant mode")
		fi
		return amode
	fi
end

proc tx_cmp(unit p,a,b)=
	int abase,bbase,atype,btype,u,v

	tx_bin(p,a,b)
end

proc tx_cmpchain(unit p,a)=
	int u,genop
	unit q,r

	q:=a
	while q do
		tpass(q,tany)

		if q=a then
			u:=q.mode
		else
			u:=getdominantmode(u,q.mode)
		fi

		q:=q.nextunit
	od

	q:=a
	r:=a.nextunit
	while q do
		coerceunit(q,u)
		q:=q.nextunit
	od

	for i:=1 to p.cmpgenop.len do
		genop:=p.cmpgenop[i]
		if genop=0 then exit fi
		p.cmpopindex[i]:=optypetable[genop,tttabtype[u]]
	od

	p.mode:=ti64
end

proc tx_callproc (unit p,a,pargs,int t)=
unit q
ref strec d,e,pm
[maxparams]ref strec paramlist
[maxparams]unit arglist,newarglist
int nparams,i,j,k,nargs,m,kwdused,qm
ichar name

tpass(a)

nargs:=nparams:=0


retry::

case a.tag
when j_name then
	d:=a.def

	if d.nameid in [procid, dllprocid] then
getparams::
		e:=d.deflist
		while e do
			if e.nameid=paramid then
				if nparams>=maxparams then txerror("Param overflow") fi
				paramlist[++nparams]:=e
			fi
			e:=e.nextdef
		od

	else					!assume fn ptr
		while ttbasetype[a.mode]=tref do
			insertunit(a,j_ptr)
			a.mode:=tttarget[a.mode]
		od
		goto dorefproc
	fi

when j_if,j_select then

TXERROR("Can't do ifx/function")

else
dorefproc::
	if a.tag=j_dot then
		tmethodcall(p,a,pargs)
		a:=p.a
		pargs:=p.b
		goto retry
	fi

	if ttbasetype[a.mode]<>tproc then
		txerror("Function pointer expected")
	fi

	d:=ttnamedef[a.mode]

	if d=nil then txerror("Function expected") fi
	goto getparams
esac

q:=pargs
while q do
	if nargs>=maxparams then txerror("Param overflow") fi
	arglist[++nargs]:=q
	q:=q.nextunit
od

p.mode:=d.mode				!type returned by function (will be void for procs)




if p.mode=tvoid and p.tag=j_callfn then
	p.tag:=j_callproc
fi

if p.mode and t<>tvoid then
	twiden(p,nolv)
fi

if d.varparams then
	for i to nargs do

		if i<=nparams then
			tpass(arglist[i],paramlist[i].mode)
		else
			tpass(arglist[i])
		fi
	od
	if t=tvoid then
		p.tag:=j_callproc
	fi
	return

fi


k:=0
kwdused:=0
for i to nparams do
	newarglist[i]:=nil
od

for i to nargs do
	q:=arglist[i]
	switch q.tag
	when j_keyword then
		name:=q.a.def.name
		for j to nparams do
			if eqstring(paramlist[j].name,name) then
				exit
			fi
		else
			txerror_s("Can't find kwd param: #",name)
		od

		if newarglist[j] then
			txerror_s("Kwd: # already used or was implicit",name)
		fi
		newarglist[j]:=q.b
		kwdused:=1

	when j_null then			!missing param
		if kwdused then
			txerror("Normal param follows kwd")
		fi
		q:=nil
		goto doregparam
	else
doregparam::
		if kwdused then
			txerror("Normal param follows kwd")
		fi
		if k>=nparams then
			cpl =k, =nparams
			txerror("Too many params supplied")
		fi
		newarglist[++k]:=q
	endswitch
od


for i to nparams do
	q:=newarglist[i]			!will be nil of not supplied
	pm:=paramlist[i]			!formal param (an st entry)
	if q=nil then
		unless pm.optional then
			txerror_s("Param not optional: #",strint(i))
		end
		if pm.code then		!provide default value
			newarglist[i]:=duplunit(pm.code,p.lineno)
		else
			newarglist[i]:=createconstunit(0,ti64)
		fi
	fi
od

unit ulist:=nil, ulistx

for i to nparams do
	pm:=paramlist[i]
	q:=newarglist[i]

	if pm.parammode=out_param then
		tpass(q,,needlv)
		m:=tttarget[pm.mode]
		qm:=q.mode

		if not comparemodes(qm,m) then
			txerror("&param: type mismatch")
		fi

		insertunit(q,j_addrof)
		q.mode:=createrefmode(nil,qm)

	else
		tpass(q,pm.mode)
	fi

	if ulist=nil then
		ulist:=q
	else
		ulistx.nextunit:=q
	fi
	ulistx:=q
	q.nextunit:=nil
od
p.b:=ulist

if t=tvoid then
	p.tag:=j_callproc
fi

end

proc tx_unary(unit p,a)=
	int opc,size,amode,mbase,tmax,x,xhigh

	tpass(a)
	amode:=a.mode

	switch p.genop
	when lwb_op, upb_op, len_op, bounds_op then
		do_bounds(p,a)
		return
	when bytesize_op,bitwidth_op then
		size:=ttsize[(a.tag=j_typeconst|a.value|amode)]*(p.genop=bytesize_op|1|8)
		makenewconst(p,size)
		p.mode:=ti64
		return
	when minvalue_op, maxvalue_op then
		tmax:=ti64
		if a.tag=j_typeconst then
			mbase:=ttbasetype[a.value]
		else
			mbase:=ttbasetype[getmemmode(a)]
		fi

		if p.genop=minvalue_op then
			case mbase
			when ti8 then x:=-128
			when ti16 then x:=-32768
			when ti32 then x:=-2_147_483_648
			when ti64 then x:=int64.minvalue
			when ti128 then
				xhigh:=0x8000'0000'0000'0000
				x:=0
				tmax:=ti128
			when tu128 then
				x:=xhigh:=0
			when tu8,tu16,tu32,tu64,tu128,tc8,tc16,tc64 then x:=0
			else
 	           txerror_s("Can't do minvalue on #",strmode(mbase))
			esac
		else
			case mbase
			when ti8 then x:=127
			when ti16 then x:=32767
			when ti32 then x:=2_147_483_647
			when ti64 then x:=0x7fff'ffff'ffff'ffff
			when ti128 then
				x:=0xFFFF'FFFF'FFFF'FFFF
				xhigh:=0x7FFF'FFFF'FFFF'FFFF
				tmax:=ti128
			when tu8,tc8 then x:=255
			when tu16,tc16 then x:=65535
			when tu32 then x:=4294967295
			when tu64 then x:=0; --x; tmax:=tu64
			when tu128 then
				x:=0xFFFF'FFFF'FFFF'FFFF
				xhigh:=0xFFFF'FFFF'FFFF'FFFF
				tmax:=tu128
			else
				txerror_s("Can't do maxvalue on #",strmode(mbase))
			esac
		fi
		p.tag:=j_const
		p.a:=nil; p.hasa:=0
		p.value:=x
	    p.high128:=xhigh
		p.mode:=tmax
		p.isconst:=1
		return
	when atan_op, Ln_op, exp_op then
		if ttisinteger[amode] then coerceunit(a,amode:=tr64) fi
	when sin_op,cos_op,tan_op, asin_op, acos_op then
		coerceunit(a,amode:=tr64)
	when typestr_op then
		p.tag:=j_const
		p.mode:=trefchar
		p.hasa:=0
		p.svalue:=pcm_copyheapstring(strmode(amode))
		p.isastring:=1
		p.length:=strlen(p.svalue)
		return
	endswitch

	opc:=optypetable[p.genop, getnewbase(amode)]
	if opc=0 then
		if ttisinteger[amode] then
			opc:=optypetable[p.genop, tr64]
			if opc then
				coerceunit(a,tr64)
				amode:=tr64
			fi
		fi
	fi
	if opc=0 then
		txerror("Unary/bad type")
	fi

	p.opindex:=opc

	case opc
	when op_sliceptr_slice then
		amode:=createrefmode(nil,tttarget[amode])
	esac

	p.mode:=amode
end

proc tx_unaryto(unit p,a)=
	int abase, amode, opc

	tpass(a,,needlv)

	amode:=a.mode

	abase:=ttbasetype[amode]

	if ttisshort[abase] then
		abase:=gettypebase(abase)
	fi

	case p.genop
	when negto_op,absto_op,inotto_op, istruelto_op, notlto_op then
		opc:=optypetable[p.genop,abase]
		if opc=0 then
			txerror("neg/absto?")
		fi
		p.opindex:=opc
	else
		txerror_s("?unaryto: ",genopnames[p.genop])
	esac
	p.mode:=tvoid
end

proc tx_if(unit p,a,b,c,int t,lv) =
	int u

	tcond(a)


	tpass(b,t,lv)
	if t<>tvoid and not c then
		txerror("if needs else")
	fi
	tpass(c,t,lv)

	if t=tany then			!unknown types (eg. print)
		u:=getdominantmodepp(b,c)
		coerceunit(b,u)
		coerceunit(c,u)
		p.mode:=u
	else				!know exactly what type needed
		p.mode:=t
	fi

	if iscondtrue(a) then		!branch b only
		deleteunit(p,b)
	elsif iscondfalse(a) then	!branch c only
		if c=nil then
			c:=createunit0(j_block)
		fi
		deleteunit(p,c)
	fi

end

proc tx_longif(unit p,a,b,int t,lv) =
	unit q,r
	int u

	u:=tvoid

	q:=a
	while q do				!all elseif unots
		tcond(q.a)
		r:=q.b
		tpass(r,t,lv)

		if t=tany then
			if u=tvoid then
				u:=r.mode
			else
				u:=getdominantmode(u,r.mode)
			fi
		fi

		q:=q.nextunit
	od

	if t<>tvoid and b=nil then
		txerror("longif needs else")
	fi
	tpass(b,t,lv)

	if t=tany then
		u:=getdominantmode(u,b.mode)
	fi

	if t<>tvoid then
		q:=a
		while q do				!all elseif unots
			if t=tany then
				coerceunit(q.b,u)
			fi
			q.mode:=q.b.mode
			q:=q.nextunit
		od
		if t=tany then
			coerceunit(b,u)
		fi
		p.mode:=b.mode
	fi
end

proc tx_incrto(unit p,a,int t)=
	int opc

	tpass(a,,needlv)

	if t<>tvoid then
		case p.genop
		when incr_op then p.genop:=incrload_op
		when decr_op then p.genop:=decrload_op
		esac
		p.mode:=gettypebase(a.mode)
	else				!a++ a-- to ++a --a
		case p.genop
		when loadincr_op then p.genop:=incr_op
		when loaddecr_op then p.genop:=decr_op
		esac
		p.mode:=tvoid
	fi

	if ttisshort[a.mode] then
		opc:=optypetable[p.genop, tu8]
	else
		opc:=optypetable[p.genop, ttbasetype[a.mode]]
	fi

	if opc=0 then
		txerror("Incr/bad type")
	fi

	p.opindex:=opc

	twiden(p,0)
end

proc tx_for(unit pindex,pfrom,pbody)=
	unit pto, pstep, plocal, plist
	int u

	pto:=pfrom.nextunit
	pstep:=pto.nextunit

	tpass(pindex)
	if pindex.tag<>j_name then
		txerror("Loop index not a variable")
	fi
	u:=pindex.mode
	tpass(pindex.nextunit)

	tpass(pfrom,u)
	tpass(pto,u)
	tpass(pstep,u)

	tpass(pbody,tvoid)
	tpass(pbody.nextunit,tvoid)	!optional else
end

proc tx_forall(unit pindex,plist,pbody)=
	unit plocal,pfrom,pto,passign
	int u,mlist,elemtype

	plocal:=pindex.nextunit
	pfrom:=plocal.nextunit
	pto:=pfrom.nextunit
	passign:=plist.nextunit

	tpass(pindex,ti64)
	tpass(pfrom,ti64)
	tpass(pto,ti64)

	tpass(plist)
	mlist:=plist.mode

	case ttbasetype[mlist]
	when tarray then
		elemtype:=tttarget[mlist]
	when tslice then
		elemtype:=tttarget[mlist]
	else
		txerror("forall/can't iterate")
	esac

	tpass(plocal)
	if plocal.mode=tany then
		plocal.mode:=elemtype
		plocal.def.mode:=elemtype
	fi

	tpass(passign)

	tpass(pbody,tvoid)
	tpass(pbody.nextunit,tvoid)	!optional else
end

proc tx_index(unit p,a,b,int t,lv) =
	int amode,emode,pmode,tmode,tbasemode

	tpass(a,,lv)
	deref(a,t<>tvoid)
	amode:=a.mode

	tpass(b,ti64)			!index

	if ttbasetype[amode] not in [tarray, tslice, tlist] then
		txerror_s("Can't index: #",strmode(amode))
	fi
	p.mode:=tttarget[amode]
	twiden(p,lv)
end

proc tx_makerange(unit p,a,b)=
int amode,bmode

tpass(a)
tpass(b)

amode:=a.mode
bmode:=b.mode


if not ttisinteger[amode] or not ttisinteger[bmode] then
	txerror("range not int")
fi

if ttisint[amode] then
	coerceunit(a,ti64)
	coerceunit(b,ti64)
else
	coerceunit(a,tu64)
	coerceunit(b,tu64)
fi
p.mode:=trange
end

proc tx_makeset(unit p,a, int t)=
int x,y,isconst
int64 lower,upper
ref void pvoid

if t=tvoid then
	txerror("open(var) set type")
fi

lower:=2 billion
upper:=-2 billion

isconst:=1

while a do
	tpass(a)

	if not a.isconst then
		isconst:=0
	else
		case a.tag
		when j_makerange then
			lower min:=a.a.value
			upper max:=a.b.value
		when j_const then
			coerceunit(a,ti64)
			lower min:=y:=a.value
			upper max:=y:=a.value
		esac
	fi
	a:=a.nextunit
od

p.isconst:=isconst

p.mode:=tset
end

proc tx_makedict(unit p,a, int t)=
int x,y,isconst,km,vm
ref void pvoid

if t=tvoid then
	txerror("open(var) dict type")
fi

p.isconst:=isconst
p.mode:=tdict
end

proc tx_ptr(unit p,a,int t,lv)=
	ref strec d

	tpass(a)

	case ttbasetype[a.mode]
	when tvoid then
		txerror("Deref Void")
	when tref then
		p.mode:=tttarget[a.mode]

	when tslice then
		txerror("Can't deref slice")
	else
		txerror("PTR: need ref T")
	esac

	twiden(p,lv)
end

proc setrecordsize(int m)=
	[maxfields+8]ref strec fieldlist
	int i,nfields,indent,nrfields,size,index, maxalign
	ref strec d,e
	ref char flags
	const ss='S', ee='E'
	int flag

	if ttsize[m] then return fi

	d:=ttnamedef[m]
	e:=d.deflist
	nfields:=0

	fieldlist[++nfields]:=ref strec@(ss)

	while e do
		if e.nameid=fieldid then
			if nfields>=maxfields then
				gerror("srs:too many fields")
			fi

			setmodesize(e.mode)
			flags:=cast(&e.uflags)
			docase flags^
			when 'S', 'U' then
				flag:=flags^
				fieldlist[++nfields]:=ref strec@(flag)
				++flags
			else
				exit
			end docase

			fieldlist[++nfields]:=e

			do
				flag:=flags++^
				case flag
				when '*'  then
				when 'E' then
					fieldlist[++nfields]:=ref strec@(ee)
				else
					exit
				esac
			od
		fi

		e:=e.nextdef
	od

	fieldlist[++nfields]:=ref strec@(ee)
	fieldlist[nfields+1]:=nil			!terminator

	countedfields:=0
	index:=2
	maxalign:=1
	scanrecord('S',&fieldlist,index,size,0, d.align, maxalign)

	if d.align then
		size:=roundoffset(size,maxalign)
		d.maxalign:=maxalign
	else
		d.maxalign:=1
	fi

	ttsize[m]:=size
	ttlength[m]:=countedfields
	ttlower[m]:=1


	case size
	when 8 then
		ttpcltype[m]:=tu64
		ttcat[m]:=d64_cat
		ttcat2[m]:=d64_cat
	when 4,2,1 then
		ttcat[m]:=ttcat2[m]:=short_cat
		ttpcltype[m]:=(size=4|tu32|(size=2|tu16|tu8))
	esac

end

proc scanrecord(int state,ref[]ref strec fields, int &index, &isize, offset, calign, &maxalign)=
 	ref strec e,f,ea
	int size:=0,fieldsize,bitoffset, alignment, newoffset

	while f:=fields^[index++] do
		case int(f)
		when 'S','U' then
			scanrecord(int(f),fields, index,fieldsize, offset, calign, maxalign)
		when 'E' then			!end of this nested block
			if state='U' then ++countedfields fi
			isize:=size
			return
		else
			if f.mode=tbitfield then
				fieldsize:=0	
				ea:=f.equivfield
				f.offset:=ea.offset
				f.bitoffset:=bitoffset
				bitoffset+:=f.bitfieldwidth
				if bitoffset>ttsize[f.equivfield.mode]*8 then
					txerror("Bit fields overflow type")
				fi

			elsif f.at then
				bitoffset:=0
				e:=f.equivfield
				fieldsize:=0
				ea:=resolve_equiv_name(f.owner,e)
				f.offset:=ea.offset
			else
				bitoffset:=0
				if state='S' then ++countedfields fi
				fieldsize:=ttsize[f.mode]
				if calign then
					alignment:=getalignment(f.mode)
					if alignment>maxalign then maxalign:=alignment fi
					newoffset:=roundoffset(offset,alignment)
					size+:=newoffset-offset
				else
					newoffset:=offset
				fi
				f.offset:=newoffset
				offset:=newoffset
			fi
		esac
		if state='S' then
			offset+:=fieldsize
			size+:=fieldsize
		else
			size:=max(size,fieldsize)
		fi
	od
end

function roundoffset(int offset, alignment)int=
int mask

if alignment=1 then return offset fi
mask:=alignment-1
while offset iand mask do ++offset od

return offset
end

global function getalignment(int m)int=
int a

case ttbasetype[m]
when tarray then
	return getalignment(tttarget[m])
when trecord then
	return ttnamedef[m].maxalign
esac

a:=ttsize[m]
case a
when 1,2,4,8 then
	return a
esac
cpl Strmode(m),A
serror("GETALIGN SIZE NOT 1248")

return 0
end

proc tx_convert(unit p,a,int hard=0)=
if a.tag=j_makelist then
	tx_makelist(a,a.a,p.convmode,nolv)
else
	tpass(a)
	coerceunit(a,p.convmode,hard)
fi
deleteunit(p,a)			!get rid of this convert (may be replaced by new convert unit)
end

proc tx_makelist(unit p,a, int t,lv)=
	int alength,tlength,elemtype,newt, i, nfields,isconst, m
	unit q,b
	ref strec e

	alength:=p.length
	newt:=0
	isconst:=1

	tlength:=ttlength[t]

	if tlength then
		if alength<tlength then
			txerror("Too few elements")
		elsif alength>tlength then
CPL =alength, =tlength
			txerror("Too many elements")
		fi
	fi

	case ttbasetype[t]
	when tarray then
		elemtype:=tttarget[t]
		if tlength=0 then
			newt:=createarraymodek(nil, elemtype, ttlower[t],alength,0)
		else
			newt:=t
		fi
		q:=a
		while q do
			tpass(q,elemtype,lv)

			unless q.tag=j_const then isconst:=0 end
			q:=q.nextunit
		od

		p.mode:=newt

	when trecord then
		e:=ttnamedef[t].deflist
		q:=a
		while q and e do
			if e.nameid=fieldid then 
				while e.mode=tbitfield do
					e:=e.nextdef
					if not e then exit fi
				od

				tpass(q,e.mode,lv)
				unless q.tag=j_const then isconst:=0 end
				q:=q.nextunit
			fi

			e:=e.nextdef
		od
		while e and (e.nameid<>fieldid or e.mode=tbitfield) do
			e:=e.nextdef
		od
		if q or e then
			txerror("Can't initialise unions")
		fi
		p.mode:=t
	when tslice then
		if a=nil or (b:=a.nextunit; b=nil) or b.nextunit then
			txerror("bad slice init")
		fi
		p.b:=b
		p.hasb:=1
		a.nextunit:=nil
		tpass(a,,lv)
		if ttbasetype[a.mode]<>tref then txerror("slice init not ref") fi
		if tttarget[a.mode]<>tvoid then
			if not comparemodes(tttarget[a.mode],tttarget[t]) then
				txerror("slice/ptr mismatch")
			fi
		fi

		tpass(b,ti64)
		p.mode:=t
		p.tag:=j_makeslice
		p.resultflag:=1

	when tvoid then
		q:=a
		if p.makearray then
			if q=nil then txerror("array()?") fi
			tpass(q,,lv)
			m:=q.mode
			q:=q.nextunit
		else
TXERROR("MAKELIST1")
		fi

		while q do
			tpass(q,m,lv)
			unless q.tag=j_const then isconst:=0 end
			q:=q.nextunit
		od

	else
		txerror_s("Unknown makelist type: #",strmode(t))
	esac

	p.isconst:=isconst

	tpass(p.b,ti64)

end

proc tx_dot(unit p,a,b,int lv)=
int recmode,recbasemode,i,j,newtag,tmode
unit q,pindex
ref strec d,dequiv

tpass(a)			!lhs, yeields ref array type

recmode:=a.mode

recbasemode:=ttbasetype[recmode]

while recbasemode=tref do
	tmode:=tttarget[recmode]
	insertunit(a,j_ptr)
	recmode:=a.mode:=tmode
	recbasemode:=ttbasetype[recmode]
od

if ttbasetype[recmode]<>trecord then
	txerror("Bad record type")
fi

d:=b.def

if d.nameid=nullid then			!not resolved; lhs mode wasn't available
	d:=b.def:=resolvefield(d,recmode)
fi

if d.mode=tbitfield then
	i:=d.bitoffset
	j:=i+d.bitfieldwidth-1
	dequiv:=d.equivfield
	b.def:=dequiv				!change from bitfield field to containing int
	b.mode:=dequiv.mode
	p.offset:=d.offset

	if i=j then					!single bit
		pindex:=createconstunit(i,ti64)
		newtag:=j_dotindex
	else						!bit slice
		pindex:=createunit2(j_makerange,createconstunit(i,ti64),createconstunit(j,ti64))
		pindex.mode:=trange
		pindex.a.resultflag:=1
		pindex.b.resultflag:=1
		newtag:=j_dotslice
	fi

	p.mode:=b.mode
	twiden(p,lv)
	insertunit(p,newtag)
	p.mode:=tu64
	p.b:=pindex
	p.hasb:=1
	p.a.resultflag:=1
	p.b.resultflag:=1
	p.resultflag:=1

	return

fi

b.mode:=d.mode
p.mode:=d.mode

p.offset:=d.offset
twiden(p,lv)
end

function resolvefield(ref strec d, int m)ref strec=
	ref strec e,t

	case ttbasetype[m]
	when trecord then
	when tref then
		m:=tttarget[m]
		if ttbasetype[m]<>trecord then
			txerror("3:record expected")
		fi
	else
		txerror("4:record expected")
	esac
	t:=ttnamedef[m]

	e:=finddupl(t,d)
	if not e then
		txerror_s("Not a field: #",d.name)
	fi
	return e
end

proc tx_andl(unit p,a,b)=
	tpass(a)
	tpass(b)

	p.opindex:=optypetable[andl_op,ti64]
	p.mode:=ti64

	if iscondfalse(a) or iscondfalse(b) then
		makenewconst(p,0,ti64)
	elsif iscondtrue(a) then
		deleteunit(p,b)
	elsif iscondtrue(b) then
		deleteunit(p,a)
	fi

end

proc convintconst(unit p,int64 x)=				!CONVINTCONST
	p.tag:=j_const
	p.mode:=ti64
	p.a:=p.b:=p.c:=nil
	p.hasa:=p.hasb:=p.hasc:=0
	p.value:=x
	p.isconst:=1
end


proc tx_sliceptr(unit p,a)=
int m,tmode

tpass(a)
m:=a.mode

case ttbasetype[m]
when tslice then
else
	txerror_s("SLICEPTR #",strmode(m))
esac

tmode:=createarraymodek(nil, tttarget[m], ttlower[m],0,0)


p.mode:=createrefmode(nil,tmode)
end

proc tx_swap(unit p,a,b)=
tpass(a,,needlv)
tpass(b,,needlv)

if not comparemodes(a.mode,b.mode) then
	txerror("SWAP: type mismatch")
fi

p.mode:=tvoid
end

proc tx_select(unit p,a,b,c, int t,lv)=
int i,u
unit q

tpass(a,ti64)

q:=b
while q do
	tpass(q,t,lv)
	if q=b then
		u:=q.mode
	else
		u:=getdominantmode(u,q.mode)
	fi

	q:=q.nextunit
od

tpass(c,t,lv)
u:=getdominantmode(u,c.mode)

q:=b
while q do
	coerceunit(q,u)
	q:=q.nextunit
od

p.mode:=u
end

proc tx_case(unit p,a,b,c, int t,lv)=
int amode,u
unit wt,w

if p.tag=j_docase and lv then gerror("&docase") fi

tpass(a)

if a=nil then
	amode:=tany
else
	amode:=a.mode
fi

if ttisinteger[amode] and ttsize[amode]<8 then
	coerceunit(a,tint)
	amode:=tint
fi
u:=tvoid


wt:=b
while wt do				!whenthen chain
	w:=wt.a
	while w do				!each expr between when...then
		tpass(w)
		if w.tag=j_makerange then
			unless ttisinteger[amode] then txerror("case: need int index") end
		else
			if amode=tany then
					if not isboolunit(w) then
TXERROR("CASE/BOOL?")
						insertunit(w,j_istruel)
					fi
			else
				coerceunit(w,amode)
			fi
		fi
		w:=w.nextunit
	od
	tpass(wt.b,t,lv)			!process block
	if t<>tvoid then
		if u then
			u:=getdominantmode(u,wt.b.mode)
		else
			u:=wt.b.mode
		fi
	fi
	wt:=wt.nextunit
od

if c then
	tpass(c,t,lv)
	if t=tany then
		u:=getdominantmode(u,c.mode)
	fi
elsif t<>tvoid then
	txerror("case needs else")
fi

if t<>tvoid then
	p.mode:=u
else
	p.mode:=tvoid
fi

end

proc tx_notl(unit p,a)=
tpass(a)


p.mode:=ti64
p.opindex:=op_notl_i64
end

proc tx_istruel(unit p,a)=
	int abase

	tpass(a)

	if isboolunit(a) then
		deleteunit(p,a)
		return
	fi

	abase:=ttbasetype[a.mode]
	if abase=tref then abase:=ti64 fi

	p.mode:=ti64
	p.opindex:=optypetable[istruel_op,abase]
	if p.opindex=0 then
		txerror("Istrue?")
	fi
end

proc tx_typepun(unit p,a)=
	int smode
case a.tag
when j_makelist then
	TXERROR("TYPEPUN/LIST")
else
	tpass(a)

	smode:=getmemmode(a)

	if ttsize[smode]<ttsize[p.convmode] then
		txerror("Typepun: sizes must match")
	fi

	p.mode:=gettypebase(p.convmode)
esac
end

proc tx_bytesize(unit p,a)=
tpass(a)
p.mode:=ti64
end

proc tx_exit(unit p,a)=
if a=nil then return fi
tpass(a,ti64)
if a.tag<>j_const then
	txerror("exit/etc not const")
fi
p.index:=a.value
p.a:=nil
p.hasa:=0

end

proc tx_goto(unit p,a)=
int m

tpass(a)
m:=a.mode
if ttbasetype[m]<>tref or ttbasetype[tttarget[m]]<>tlabel then
	txerror("goto: not label")
fi
end

proc tx_switch(unit p,a,b,c,int t,lv)=
[0:2001]byte valueset
unit wt, w
int ax,bx,i,u

if p.tag=j_doswitch and lv then gerror("&doswitch") fi

tpass(a,ti64)

memset(&valueset,0,valueset.bytes)
u:=tvoid

wt:=b
while wt do

	w:=wt.a
	while w do
		tpass(w)

		if not isconstunit(w) then txerror("Switch not constant") fi

		case ttbasetype[w.mode]
		when trange then			!assume makerange
			ax:=w.a.value
			bx:=w.b.value
dorange::
			for i:=ax to bx do
				if i<valueset.lwb or i>valueset.upb then
					txerror("switch: value out of range")
				fi
				if valueset[i] then
					cpl i
					txerror("Duplicate switch value")
				fi
				valueset[i]:=1
			od
		else
			coerceunit(w,ti64,0)
			tevaluate(w)
			if w.tag<>j_const then
				txerror("Switch value: not const int")
			fi
			ax:=bx:=w.value
			goto dorange
		esac
		w:=w.nextunit
	od
	tpass(wt.b,t,lv)

	if t=tany then
		if u then
			u:=getdominantmode(u,wt.b.mode)
		else
			u:=wt.b.mode
		fi
	fi

	wt:=wt.nextunit
od

if c then
	tpass(c,t,lv)
	if t=tany then
		u:=getdominantmode(u,c.mode)
	fi
elsif t<>tvoid then
	txerror("switch needs else")
fi

if t<>tvoid then
	w:=b.a
	while w do				!all elseif unots
		if t=tany then
			coerceunit(b.b,u)
		fi
		w.mode:=b.b.mode
		w:=w.nextunit
	od
	if t=tany then
		coerceunit(c,u)
		p.mode:=u
	else
		p.mode:=t
	fi
else
	p.mode:=tvoid
fi
end

proc tx_addroffirst(unit p,a,int t)=
	int m

	tpass(a)
	m:=a.mode
	if ttbasetype[m]<>tarray then
		txerror("&. ref[] expected")
	fi

	m:=createrefmode(nil,tttarget[m])
	if a.tag=j_name then
		a.addroffirst:=1
	fi
	p.mode:=m
end

proc tx_minvalue(unit p,a)=
int u,tmax
int64 x,xhigh

if a.tag=j_typeconst then
	u:=ttbasetype[a.value]
dotypeconst::
    tmax:=ti64
    if p.tag=j_minvalue then
        case u
        when ti8 then x:=-128
        when ti16 then x:=-32768
        when ti32 then x:=-2_147_483_648
        when ti64 then x:=int64.minvalue
        when ti128 then
			xhigh:=0x8000'0000'0000'0000
			x:=0
			tmax:=ti128
      	when tu128 then
			x:=xhigh:=0
		when tu8,tu16,tu32,tu64,tu128,tc8,tc16 then x:=0
        else
            txerror_s("Can't do minvalue on #",strmode(u))
        esac
    else
        case u
        when ti8 then x:=127
        when ti16 then x:=32767
        when ti32 then x:=2_147_483_647
        when ti64 then x:=0x7fff'ffff'ffff'ffff
        when ti128 then
			x:=0xFFFF'FFFF'FFFF'FFFF
			xhigh:=0x7FFF'FFFF'FFFF'FFFF
			tmax:=ti128
        when tu8,tc8 then x:=255
        when tu16,tc16 then x:=65535
        when tu32 then x:=4294967295
        when tu64 then x:=0; --x; tmax:=tu64
        when tu128 then
			x:=0xFFFF'FFFF'FFFF'FFFF
			xhigh:=0xFFFF'FFFF'FFFF'FFFF
			tmax:=tu128
        else
            txerror_s("Can't do maxvalue on #",strmode(u))
        esac
    fi
    p.tag:=j_const
    p.a:=nil
	p.hasa:=0
    p.value:=x
    p.high128:=xhigh
    p.mode:=tmax
	p.isconst:=1
else
	tpass(a)
	if a.tag=j_typeconst then
		u:=ttbasetype[a.value]
	else
		u:=ttbasetype[a.mode]
	fi
	goto dotypeconst
fi
end

proc tx_return(unit p,a, int t)=
 	int m,nvalues,nret,i
	ref[]int32 pmult
	unit q

	m:=currproc.mode
	nret:=currproc.nretvalues
	pmult:=ttmult[currproc.mode]

	if a=nil then
		if nret then
			txerror("return value(s) missing")
		fi
		return
	elsif nret=0 then
		txerror("Superfluous return value")
	fi

	if a.tag=j_makelist then
		a.tag:=j_returnmult
		if a.length<>nret then
			txerror("Wrong number of return values")
		fi
		q:=a.a				!point to list of return values
		for i to nret do
			tpass(q,pmult[i])
			q:=q.nextunit
		od

		deleteunit(p,a)			!don't need return
		if t=tvoid then
			p.mode:=tvoid
		else
			p.mode:=ttuple
		fi

	else
		if nret>1 then txerror("RETERROR?") fi
		tpass(a,m)

		if t=tvoid then					!regular out-of-line return
			p.mode:=tvoid
		else
			deleteunit(p,a)
		fi
	fi

IF TTISSHORT[P.MODE] THEN TXERROR("SHORT RET TYPE") FI


end

proc tx_dotindex(unit p,a,b,int lv) =
int pmode
unit i,j

tpass(a,,lv)			!lhs

pmode:=tu64

if not ttisinteger[a.mode] then
		txerror("a.[i]: not int/str value")
fi

tpass(b)			!index

case ttbasetype[b.mode]
when trange then
	i:=b.a
	j:=b.b
	if i.tag=j.tag=j_const then
		if i.value>j.value then
			swap(b.a,b.b)
		fi
	fi
else					!assume simple index
	coerceunit(b,ti64)
esac

p.mode:=pmode
end

proc tx_slice(unit p,a,b) =

	tpass(a)			!lhs
	tpass(b)			!will be a range

	if a.mode=trefchar then
		p.mode:=createslicemodek(currproc,tc8,1,0)
	else
		deref(a)
		case ttbasetype[a.mode]
		when tarray then
			p.mode:=createslicemodek(currproc,tttarget[a.mode],1, 0)
	
		when tslice then
			p.mode:=a.mode
	
		else
	CPL =STRMODE(A.MODE)
			txerror("a[i..j]: not array")
		esac
	fi
end

proc tx_assign(unit p,a,b,int t)=
int m,mm
ref strec d



case a.tag
when j_makelist then
	tx_multassign(a,b)
when j_dotindex, j_dotslice then
	tx_dotindex(a,a.a,a.b,needlv)
	tpass(b,a.mode)
	p.mode:=ti64
else
	if a.tag=j_name and a.def.islet and p.initlet then
		tpass(a)
	else
		tpass(a,,needlv)
	fi
	m:=a.mode


	a.resultflag:=t<>tvoid

	if ttbasetype[m]=tslice and b.tag=j_makelist then
		tx_makelist(b,b.a,m,0)

	elsif ttisshort[m] and t<>tvoid then
		p.memmode:=m
		p.mode:=gettypebase(m)
		tpass(b,p.mode)

	else
		if b.genop in [idiv_op, irem_op] then		!CAN'T JUST OVERRIDE MODE
			tpass(b)
		elsif b.tag=j_read then
			tpass(b,m)
		else
			mm:=m
			if ttisshort[m] then
				mm:=gettypebase(m)
			fi
			case b.tag
			when j_autocast then
				tpass(b,mm)
			when j_makelist then
				tpass(b,m)
			else
				tpass(b)
			esac
			if ttbasetype[b.mode]=ttuple then
				d:=getprocretmodes(b)
				coerceunit(a,ttmult[d.mode,1])
				p.mode:=a.mode
			else
				coerceunit(b,mm)
				p.mode:=mm
			fi
		fi
	fi
esac
end

proc tx_multassign(unit a,b)=
unit p,q,lhs,rhs
int nretmodes,i
ref[]int32 pmult
ref strec d				!point to def containing return mode info

nretmodes:=0

if b.tag<>j_makelist then

	tpass(b)
	d:=getprocretmodes(b)
	nretmodes:=d.nretvalues

	if ttbasetype[d.mode]<>ttuple then txerror("Not a tuple") fi

	if a.length>nretmodes then
		txerror("mult ass/mult returns don't agree in number")
	fi
	if nretmodes<=1 then
		txerror("mult ass rhs needs fn yielding 2+ values")
	fi

	p:=a.a
	pmult:=ttmult[d.mode]
	i:=1

	while p do
		tpass(p,,needlv)
		if p.mode<>pmult[i++] then
			txerror("mult ass/mult fn needs exact type match")
		fi
		p:=p.nextunit
	od
	return
fi

if a.length<>b.length then
	txerror("Mult assign: count mismatch")
fi
if a.length=0 then
	txerror("Invalid assignment")
fi
rhs:=b.a
lhs:=a.a

p:=lhs
while p do
	tpass(p,,needlv)
	p:=p.nextunit
od

p:=lhs

q:=rhs
while q do
	tpass(q,p.mode)
	p:=p.nextunit
	q:=q.nextunit
od
end


proc tx_exprlist(unit p,a,int t)=
unit q

q:=a
while q and q.nextunit do
	tpass(q)
	q:=q.nextunit
od


tpass(q,t)
p.mode:=q.mode
end

proc tx_sign(unit p,a)=

tpass(a)
if ttisreal[a.mode] then
	coerceunit(a,tr64)
	p.mode:=tr64
else
	coerceunit(a,ti64)
	p.mode:=ti64
fi
end

proc twiden(unit p, int lv)=
	int m,u,mbase

	mbase:=ttbasetype[m:=p.mode]

	if mbase=tvoid then return fi		!nothing to widen (error?)
	if lv then return fi				!lv, keep memory mode as dest

	if not ttisshort[mbase] then return fi	!no widening needed
	case p.tag
	when j_name, j_ptr, j_index, j_dot then
			p.memmode:=m				!non-void marks this as non-lv too
			p.mode:=gettypebase(m)
	when j_callproc,j_callfn then
		p.memmode:=m
		p.mode:=gettypebase(m)
	else
		PRINTUNIT(P)
		txerror_s("widen? #",jtagnames[p.tag])
	esac
end

proc twidenshort(unit p)=
CPL "WIDENSHORT"
	if p.tag=j_const then
		p.mode:=gettypebase(p.mode)
	fi

	p.resultflag:=1
end

proc tx_concat(unit p,a,b)=
	int u

	tpass(a)
	tpass(b)
	p.mode:=a.mode
		txerror("head/etc can't be used with this type")

	u:=getdominantmodepp(a,b)
	coerceunit(a,u)
	coerceunit(b,u)

end

proc twidenopnd(unit p)=
	if ttisshort[p.mode] then
		twidenshort(p)
	fi
end

proc joinstrings(unit p,a,b)=
	int newlen,alen:=a.slength, blen:=b.slength
	ref char newstr
	newlen:=alen+blen
	newstr:=pcm_alloc(newlen+1)

	if alen then memcpy(newstr,a.svalue,alen) fi
	if blen then memcpy(newstr+alen,b.svalue,blen) fi
	(newstr+alen+blen)^:=0

	a.svalue:=newstr
	a.slength:=newlen

	deleteunit(p,a)

end

proc removeaddrof(unit p)=
if p=nil then return fi
case p.tag
when j_addrof then
	deleteunit(p,p.a)
when j_if then
	removeaddrof(p.b)
	removeaddrof(p.c)
else
	txerror("dot/flex: complex record expr, can't remove &")
esac

end

proc tstringslice(unit p, int slicemode)=
	unit a,b,prange
	int length

	if tttarget[slicemode]<>tc8 then
		txerror("Not char slice")
	fi
	a:=p
	insertunit(p,j_slice)


	if p.a.tag=j_const then
	else
		b:=duplunit(p.a)
		insertunit(b,j_unary)
		b.opindex:=op_lenstr_ichar
		prange:=createunit2(j_makerange,createconstunit(1,ti64),b)

		prange.mode:=trange
		p.b:=prange
		p.hasb:=1
	fi

	p.mode:=slicemode
end

proc tx_bitfield(unit p,a,int lv)=
	int i,j,bitsize,topbit
	unit r

	tpass(a,,lv)

	if not ttisinteger[a.mode] and not ttisref[a.mode] then
		txerror("Int/ref needed")
	fi

	bitsize:=ttsize[ttbasetype[a.mode]]*8
	topbit:=bitsize-1

	case p.bfcode
	when bf_lsb then
		i:=0; j:=7

	when bf_msb then
		j:=topbit
		i:=topbit-7

	when bf_lsbit then
		i:=j:=0

	when bf_odd,bf_even then
		if lv then
			txerror("Can't assign")
		fi
		i:=j:=0

	when bf_msbit then
		i:=j:=topbit

	when bf_lsw then
		i:=0
		j:=bitsize/2-1

	when bf_msw then
		i:=bitsize/2
		j:=topbit
	else
	CPL P.BFCODE
		TXERROR("BITFIELD")
	esac

	if i=j then			!single bit
		p.tag:=j_dotindex
		p.b:=createconstunit(i,ti64)
		p.hasb:=1
		p.resultflag:=1
		p.b.resultflag:=1

		if p.opindex=bf_even then
			p.mode:=tu64
			addnotl(p)
		fi

	else
		r:=createunit2(j_makerange,createconstunit(i,ti64),createconstunit(j,ti64))
		r.a.resultflag:=1
		r.b.resultflag:=1
		r.mode:=trange
		p.tag:=j_dotslice
		p.hasb:=1
		p.b:=r
	fi

	p.mode:=tu64
end

proc deref(unit a, int needres=1)=
int abasemode, tmode

abasemode:=ttbasetype[a.mode]

while abasemode=tref do
	tmode:=tttarget[a.mode]

	insertunit(a,j_ptr)
	a.mode:=tmode

	abasemode:=ttbasetype[a.mode]
od

end

proc tx_sqrt(unit p,a)=
	tpass(a)

	unless ttisallnum[a.mode] then
		txerror("maths: not numeric")
	end unless
	coerceunit(a,tr64)
	p.mode:=tr64
end


function same(unit p,q)int=
	if p.tag=q.tag=j_name and p.def=q.def then
		return 1
	fi
	return 0
end

proc tmethodcall(unit p, pdot, pargs)=
	int mrec
	unit prec, pfield, pfunc
	ref strec d,e

	prec:=pdot.a
	pfield:=pdot.b
	mrec:=prec.mode
	d:=pfield.def

	e:=resolvefield(d,mrec)

	if e=nil then
		txerror_s("Can't resolve method:",d.name)
	fi

	pfunc:=createname(e)
	pfunc.mode:=e.mode
	prec.nextunit:=pargs

	p.a:=pfunc
	p.b:=prec
end

function softconvert(int s,t,hard=0)int=

	int sbase, tbase

	if s=t then return op_softconv fi

	sbase:=ttbasetype[s]
	tbase:=ttbasetype[t]


	if sbase<=tlastnum and tbase<=tlastnum then		!both numeric
		return softconvtable[sbase,tbase]
	fi

	if sbase=tbase=tref then
		if s=tref or t=tref then						!at least one is ref void
			return op_softconv
		fi												!ref T/ref U
		return (comparemodes(s,t)|op_softconv|op_error)
	fi

	if sbase=trefchar and tbase=tstring then
		return op_ichartostring
	fi

	if sbase=tarray and t=trefchar and tttarget[s]=tc8 then
		return op_charaxtoichar
	fi

	if not hard and sbase<=tlastnum and ttisshort[tbase] then
		return op_softtrunc_short		!soft truncate needed for idata
	fi

	if sbase=tbase=tarray then
		if comparemodes(s,t) then
			return op_softconv
		fi
	fi


	if sbase=tarray and tbase=tslice then
		if not comparemodes(tttarget[s],tttarget[t]) then
			txerror("Bad array to slice")
		fi
		return op_arraytoslice
	fi
	if s=trefchar and tbase=tslice then
		if tttarget[t] not in [tu8,tc8] then
			txerror("Bad string to slice")
		fi

		return op_ichartoslice
	fi
	if sbase=tslice and tbase=tslice then
		if comparemodes(s,t) then
			return op_softconv
		fi
	fi




	return op_error
end

function comparemodes(int s,t)int=
	int sbase, tbase, starg, ttarg
	ref strec d,e

	if s=t then return 1 fi


	sbase:=ttbasetype[s]
	tbase:=ttbasetype[t]

	if sbase<>tbase then return 0 fi

	case sbase
	when tref then
		starg:=tttarget[s]
		ttarg:=tttarget[t]
		if starg=tvoid or ttarg=tvoid then
			return 1
		fi
	
		return comparemodes(tttarget[s],tttarget[t])

	when tarray then
		if comparemodes(tttarget[s],tttarget[t]) and (ttlength[s]=ttlength[t] or
			ttlength[s]=0 or ttlength[t]=0) then
			return 1
		fi
	when tslice then
		return comparemodes(tttarget[s],tttarget[t])

	when tproc then
		d:=ttnamedef[s]
		e:=ttnamedef[t]
		if d and e then
			if not comparemodes(d^.mode,e^.mode) then return 0 fi
			if d^.paramlist=nil and e^.paramlist=nil then return 1 fi
		fi
	esac
	return 0
end

function hardconvert(int s,t)int=
	int opc, sbase, tbase
	int sint, tint, sref, tref

	opc:=softconvert(s,t,1)				!implicit conversion anyway?
	if opc<>op_error then				!yes
		return opc
	fi

	if s=tvoid then						!assume t<>tvoid, as that is tested above
		txerror("Non-void type expected")
	fi

	sbase:=ttbasetype[s]
	tbase:=ttbasetype[t]
	sref:=ttisref[s]
	tref:=ttisref[t]
	sint:=ttisinteger[s]
	tint:=ttisinteger[t]

	if sref and tint or sint and tref or sref and tref then
		return op_softconv
	elsif sbase=tenum and tint or sint and tbase=tenum then
		return op_softconv
	elsif sint and ttisshort[tbase] then
		return (ttsize[sbase]=16|op_truncate_i128|op_truncate_i64)
	fi

	return op_error
end

proc applyconversion(unit p, int s,t, opc)=
	int cmpop

	case opc
	when op_error then
		txerror("No conversion possible")
	when op_softconv then
		p.mode:=t
		return
	when op_softtrunc_short then
		insertunit(p,j_shorten)
		p.mode:=t			!don't use the short target mode
		return

	when op_arraytoslice then
		insertunit(p,j_slice)
		p.mode:=t
		return
	when op_ichartoslice then
		tstringslice(p,t)
		return

	when op_charaxtoichar then
		insertunit(p,j_addroffirst)
		p.mode:=trefchar
		return

	esac

	if tevalconvert(p,s,t,opc) then		!try and apply it directly
		return
	fi


	insertunit(p, j_convert)
	p.opindex:=opc

	p.convmode:=s
	p.resultflag:=1

	if ttisshort[t] then
		p.convmode:=t
		t:=gettypebase(t)
	fi

	p.mode:=t
end

proc coerceunit(unit p, int t, hard=0)=
	int opc,s

	s:=p.mode



	if t=tvoid or s=t then return fi
	if s=tvoid and t<>tvoid then
		txerror("Void type in expression/return value missing")
	fi

	if hard then
		opc:=hardconvert(s,t)
	else
		opc:=softconvert(s,t)
	fi

	if opc=op_error then
		println strmode(s),"=>",strmode(t)
		if not hard and hardconvert(s,t)<>op_error then
			txerror("Need explicit conversion")
		else
			txerror("Can't do conversion")
		fi
	fi

	applyconversion(p,s,t,opc)
end

function tevalconvert(unit p,int s,t,opc)int=
	real x,z
	int a,c
	int128 aa


	a:=p.value

	if p.tag<>j_const then
		return 0
	fi

	case opc
	when op_float_i64_r64 then
		z:=p.value

	when op_float_i64_r32 then
		z:=p.value

	when op_float_u64_r64 then

		if p.value>=0 then
			z:=p.value
		else
			txerror("CAN'T EVALC/U64->R64")
		FI

	when op_widen_i64_i128 then
		p.value128:=a
		p.mode:=ti128
		return 1

	when op_fnarrow_r64_r32 then
		z:=p.xvalue


	else
		return 0
	esac

	if ttisreal[t] then
		makenewconst(p,int64@(z),t)

	else
		makenewconst(p,c,t)
	fi

	return 1
end

proc do_bounds(unit p,a) =
	int m,mbase,opc,lower,upper

	deref(a)

	m:=a.mode
	if a.tag=j_typeconst then m:=a.value fi

	mbase:=ttbasetype[m]
	p.mode:=ti64

	case p.genop
	when lwb_op then
		case mbase
		when tarray,tslice then
			convintconst(p,ttlower[m])
			return
		when tstring then
			convintconst(p,1)
			return
		when tlist then
			p.opindex:=op_lwb_var
		else
error::
			txerror("lwb/upb/len?")
		esac

	when upb_op then
		case mbase
		when tarray then
			convintconst(p,ttlower[m]+ttlength[m]-1)
		when tslice then
			p.opindex:=op_upb_slice
		when tstring,tlist then
			p.opindex:=op_upb_var
		else
			goto error
		esac

	when len_op then
		case mbase
		when tarray then
			convintconst(p,ttlength[m])
		when tslice then
			p.opindex:=op_len_slice
		when tstring,tlist then
			p.opindex:=op_len_var
		else
			goto error
		esac
	when bounds_op then
		p.mode:=trange
		case mbase
		when tarray then
			p.range_lower:=ttlower[m]
			p.range_upper:=p.range_lower+ttlength[m]-1
			p.tag:=j_const
			p.a:=p.b:=p.c:=nil
			p.hasa:=p.hasb:=p.hasc:=0
			p.isconst:=1
			return

		when tslice then
			p.opindex:=op_bounds_slice
		when tstring,tlist then
			p.opindex:=op_bounds_var
		else
			goto error
		esac
	esac
end

proc addnotl(unit p)=
	insertunit(p,j_notl)
	p.mode:=ti64
	p.genop:=notl_op
	p.opindex:=op_notl_i64
end

proc tevaluate(unit p)=
unit a,b,pname
int offset

int tag:=p.tag

if jisexpr[tag]=2 then
	tevalbinop(p)

elsif jisexpr[tag]=1 then
	tevalmonop(p)

elsecase tag
when j_makerange then
	a:=p.a
	b:=p.b
	if ttsize[a.mode]<=8 then			!const range only for 32-bits
		tevaluate(a)
		tevaluate(b)
		if a.tag=j_const and b.tag=j_const then
			p.isconst:=a.isconst iand b.isconst
		fi
	fi

when j_addrof then
	a:=p.a

	pname:=addrdotindex(a, offset)

	if pname then
		deleteunit(a,pname)
		if p.b=nil then
			p.hasb:=1
			p.b:=createconstunit(offset,ti64)
		else 
			p.b.value+:=offset
		fi
	fi

fi

end

function addrdotindex(unit p, int &offset)unit q=
	int axmode

	case p.tag
	when j_dot then
		if p.a.tag=j_name then
			offset:=p.offset
			return p.a
		else
			q:=addrdotindex(p.a,offset)
			offset+:=p.offset
			return q
		fi
	when j_index then
		axmode:=p.a.mode
		if p.b.tag=j_const then
			if p.a.tag=j_name then
				offset:=(p.b.value-ttlower[axmode])*ttsize[tttarget[axmode]]
				return p.a
			else
				q:=addrdotindex(p.a,offset)
				if q then
					offset+:=(p.b.value-ttlower[axmode])*ttsize[tttarget[axmode]]
				fi
				return q
			fi
		else
			return nil
		fi
	else
		return nil
	esac

end

proc tevalbinop(unit p)=
	int64 a,b,c,offset
	real x,y,z
	unit lhs, rhs

	lhs:=p.a
	rhs:=p.b

	unless lhs.tag=rhs.tag=j_const then
		if lhs.tag=j_addrof and rhs.tag=j_const then
			if lhs.a.tag=j_name then			!reduce addrof(a)+k => addrof(a,k)
				offset:=rhs.value*ttsize[tttarget[lhs.mode]]
				if lhs.b=nil then
					lhs.hasb:=1
					lhs.b:=createconstunit(offset,ti64)
				else
					lhs.b.value+:=offset
				fi
				deleteunit(p,lhs)
			fi
		fi
		return
	end

	if ttisreal[p.mode] then
		x:=p.a.xvalue
		y:=p.b.xvalue
	else
		a:=p.a.value
		b:=p.b.value
	fi

	switch p.opindex
	when op_add_i64 then c:=a+b

	when op_add_r64 then z:=x+y

	when op_sub_i64 then c:=a-b

	when op_sub_r64 then z:=x-y

	when op_mul_i64 then c:=a*b

	when op_mul_r64 then z:=x*y
	when op_div_r64 then z:=x/y

	when op_idiv_i64 then c:=a/b

	when op_shl_i64 then c:=a<<b

	when op_eq_i64 then c:=a=b

	when op_ne_i64 then c:=a<>b

	when op_lt_i64 then c:=a<b

	when op_le_i64 then c:=a<=b

	when op_ge_i64 then c:=a>=b

	when op_gt_i64 then c:=a>b

	when op_andl_i64 then c:=a and b

	when op_orl_i64 then c:=a or b

	when op_iand_i64 then c:=a iand b
	when op_ior_i64 then c:=a ior b

	else
		return
	end switch

	if ttisreal[p.mode] then
		makenewconst(p,int64@(z))
	else
		makenewconst(p,c)
	fi


end

proc tevalmonop(unit p)=
	int64 a,b,c
	real x,z
	ref int128 q


	unless p.a.tag=j_const then
		return
	end

	a:=p.a.value
	x:=p.a.xvalue

	switch p.opindex
	when op_neg_i64 then c:=-a

	when op_neg_r64 then z:=-x

	when op_istruel_i64 then c:=istrue a

	when op_notl_i64 then c:=not a
	when op_inot_i64 then c:=inot a
	when op_abs_i64 then c:=abs a

	else
		return
	end switch

	if ttisreal[p.mode] then
		makenewconst(p,int64@(z))
	else
		makenewconst(p,c)
	fi


end

function getnewbase(int m)int=
	m:=ttbasetype[m]
	case m
	when tarray, trecord then
		return tblock
	esac
	return m
end

function iscondtrue(unit p)int =
	if p.tag=j_const and p.value<>0 then 1 else 0 fi
end

function iscondfalse(unit p)int =
	if p.tag=j_const and p.value=0 then 1 else 0 fi
end

proc removestmt(unit p)=
	deleteunit(p,createunit0(j_block))
	p.a:=p.b:=p.c:=nil
end

proc fixchararray(unit a)=
	if a and ttbasetype[a.mode]=tarray and tttarget[a.mode]=tc8 then
		coerceunit(a,trefchar,0)
	fi
end

proc combinestrings(unit p)=
	unit a:=p.a, b:=p.b
	int alen:=a.length
	int blen:=b.length
	int clen:=alen+blen
	ichar s

	if blen=0 then
		deleteunit(p,a)
		return
	elsif alen=0 then
		deleteunit(p,b)
		return
	fi

	s:=pcm_alloc(clen+1)
	memcpy(s,a.svalue,alen)
	memcpy(s+alen,b.svalue,blen)
	(s+clen)^:=0

	deleteunit(p,a)
	p.length:=clen
	p.svalue:=s

end
=== bb_export.m 40/40 ===
import msys
import clib
import mlib

import bb_decls
import bb_tables
import bb_lib
import bb_pclcommon

strbuffer sbuffer
ref strbuffer dest=&sbuffer

const expscope=export_scope

global proc writeexports(ichar outfile, modulename)=
	ref strec d,e
	ref procrec pp
	[300]char filename
	filehandle f

	println "Writing exports file to",outfile

	gs_init(dest)
	wxstr("importlib $")
	wxstr(modulename)
	wxstrln(" =")

	for i:=tuser to ntypes do
		d:=ttnamedef[i]
		if d.isglobal=expscope and d.name^<>'$' then
			case ttbasetype[i]
			when trecord then
				exportrecord(d)
			when tenum then
				exportenum(d)
			else
				wxstr("    type ")
				wxstr(d.name)
				wxstr(" = ")
				wxstr(strmode(d.mode,0))
				wxline()
			esac
		fi
	od

	pp:=staticlist
	while pp do
		d:=pp^.def
		if d.isglobal=expscope then
			exportstatic(d)
		fi
		pp:=pp^.nextproc
	od
	if nstaticlist then wxline() fi

	pp:=constlist
	while pp do
		d:=pp^.def
		exportconst(d)
		pp:=pp^.nextproc
	od
	if nconstlist then wxline() fi

	pp:=proclist
	while pp do
		d:=pp.def
		if d.isglobal=expscope then
			exportproc(d)
		fi
		pp:=pp^.nextproc
	od

	wxstrln("end importlib")

	f:=fopen(outfile,"wb")
	gs_println(dest,f)
	fclose(f)
end

proc exportstatic(ref strec d)=
	wxstr("    var ")
	wxmode(d.mode)
	wxstr(" ")
	wxstr(d.name)
	wxline()
end

proc exportconst(ref strec d)=
	wxstr("    const ")
	wxmode(d.mode)
	wxstr(" ")
	wxstr(d.name)
	wxstr(" = ")
	jeval(dest,d.code)
	wxline()
end

proc exportproc(ref strec d)=
	ref strec e
	int currmode,needcomma

	wxstr("    mlang ")
	wxstr((d.mode=tvoid|"proc     "|"function "))
	wxstr(d.name)
	wxstr("(")

	e:=d.deflist
	needcomma:=0
	currmode:=tvoid

	while e do
		if e.nameid=paramid then
			if needcomma then wxstr(",") fi
			if e.parammode<>out_param then
				if e.mode<>currmode then
					wxmode(e.mode)
					wxstr(" ")
					currmode:=e.mode
				fi
			else
				wxmode(tttarget[e.mode])
				wxstr(" &")
				currmode:=tvoid
			fi
			wxstr(e.name)
			if e.code then
				wxstr("=")
				if ttisref[e.mode] and e.code.tag=j_const and e.code.value=0 then
					wxstr("nil")
				else
					jeval(dest,e.code)
				fi
			fi
			needcomma:=1
		fi
		e:=e.nextdef
	od

	wxstr(")")
	if d.mode then
		wxstr(" => ")
		wxmode(d.mode)
	fi
	wxline()
end

proc exportenum(ref strec d)=
	ref strec e
	wxstr("    type ")
	wxstr(d.name)
	wxstr(" = enum(")

	e:=d.deflist
	while e do
		wxstr(e.name)
		wxstr("=")
		jeval(dest,e.code)
		e:=e.nextdef
		if e then
			wxstr(", ")
		fi
	od

	wxstrln(")")
end

proc wxstr(ichar s)=
	gs_str(dest,s)
end

proc wxstrln(ichar s)=
	gs_strln(dest,s)
end

proc wxline=
	gs_line(dest)
end

proc exportrecord(ref strec d)=
	ref strec e
	ref char flags
	int flag,indent
	const tab="    "

	e:=d.deflist

	wxstr("    record ")
	wxstr(d.name)
	wxstr(" = ")
	wxline()

	indent:=2

	while e do
		if e.nameid=fieldid then
			flags:=cast(&e.uflags)
			docase flags^
			when 'S' then
				to indent do wxstr(tab) od
				wxstrln("struct")
				++indent
				++flags
			when 'U' then
				to indent do wxstr(tab) od
				wxstrln("union")
				++indent
				++flags
			else
				exit
			end docase

			to indent do wxstr(tab) od
			wxmode(e.mode)
			wxstr(" ")
			wxstrln(e.name)

			do
				flag:=flags++^
				case flag
				when '*'  then
				when 'E' then
					--indent
					to indent do wxstr(tab) od
					wxstrln("end")
				else
					exit
				esac
			od
		fi

		e:=e.nextdef
	od

	wxstrln("    end")
	wxline()
end

proc wxmode(int mode)=
	ichar name
	if mode>=tuser then
		name:=ttnamedef[mode].name
		if name^<>'$' then
			wxstr(name)
			return
		fi
	fi
	wxstr(strmode(mode,0))
end
=== end ===
