%baseclass-preinclude symengine/visitor.h
%scanner scanner.h
%scanner-token-function d_scanner.lex()
%filenames parser
%parsefun-source parser.cpp
%namespace SymEngine


%polymorphic basic: RCP<const Basic>;
			 basic_vec : vec_basic;
			 string : std::string;

%token <string> INTEGER
%token <string> IDENTIFIER
%token <string> CONSTANT
%token <string> DOUBLE

%left '+' '-'
%left '*' '/'
%right POW
%right UMINUS
%nonassoc '('

%type <basic> st_expr
%type <basic> expr
%type <basic_vec> expr_list
%type <basic> leaf
%type <basic> func

%start st_expr

%%
st_expr :
	expr
	{
		$$ = $1;
		res = $$;
	}
;

expr:
        expr '+' expr
        {
        	$$ = add($1, $3);
        }
|
        expr '-' expr
        {
        	$$ = sub($1, $3);
        }
|
        expr '*' expr
        {
        	$$ = mul($1, $3);
        }
|
        expr '/' expr
        {
        	$$ = div($1, $3);
        }
|
        expr POW expr
        {
        	$$ = pow($1, $3);
        }
|
        '(' expr ')'
        {
        	$$ = $2;
        }
|
       	'-' expr %prec UMINUS
       	{
       		$$ = neg($2);
       	}
|
		leaf
		{
			$$ = $1;
		}
;

leaf:
	IDENTIFIER
	{
		$$ = SymEngine::symbol($1);
	}
|
	INTEGER
	{
		$$ = SymEngine::integer(SymEngine::integer_class($1 .c_str()));
	}
|
	CONSTANT
	{
		$$ = constants[$1];
	}
|
	DOUBLE
	{
		char *endptr = 0;
		double d = std::strtod($1 .c_str(), &endptr);

#ifdef HAVE_SYMENGINE_MPFR
        unsigned digits = 0;
        for (unsigned i = 0; i < expr.length(); ++i) {
            if (expr[i] == '.' or expr[i] == '-')
                continue;
            if (expr[i] == 'E' or expr[i] == 'e')
                break;
            if (digits != 0 or expr[i] != '0') {
                ++digits;
            }
        }
        if (digits <= 15) {
            $$ = SymEngine::real_double(d);
        } else {
            // mpmath.libmp.libmpf.dps_to_prec
            long prec = std::max(long(1), std::lround((digits + 1) * 3.3219280948873626));
            $$ = SymEngine::real_mpfr(mpfr_class(expr, prec));
        }
#else
		$$ = SymEngine::real_double(d);
#endif
	}
|
	func
	{
		$$ = $1;
	}
;

func:
	IDENTIFIER '(' expr_list ')'
	{
		bool found = false;

		if ($3 .size() == 1) {
			if (single_arg_functions.find($1) != single_arg_functions.end()) {
			    $$ = single_arg_functions[$1]($3[0]);
			    found = true;
			}
		} else if ($3 .size() == 2) {
			if (double_arg_functions.find($1) != double_arg_functions.end()) {
			    $$ = double_arg_functions[$1]($3[0], $3[1]);
			    found = true;
			}
		}

		if (not found) {
			if (multi_arg_functions.find($1) != multi_arg_functions.end()) {
			    $$ = multi_arg_functions[$1]($3);
			    found = true;
			}
		}
		
		if (not found) {
			$$ = function_symbol($1, $3);
		}
	}
;

expr_list:

	expr_list ',' expr
	{
		$$ = $1; // TODO : should make copy?
		$$ .push_back($3);
	}
|
	expr
	{
		$$ = {$1};
	}
;