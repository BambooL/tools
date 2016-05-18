%{

#include <cstdlib>
#include <sstream>
#include <string>
#include "scanner.h"

typedef Dyninst_aarch64::Parser::token token;
typedef Dyninst_aarch64::Parser::token_type token_type;

#define yyterminate() return token::END

%}

%option c++

%option batch

%{
#define YY_USER_ACTION  yylloc->columns(yyleng);
%}

%%

%{
    yylloc->step();
%}

##[a-z_]+   {
                yylval->strVal = new std::string(yytext+2);
                return token::INSN_START;
            }

@@          {   return token::INSN_END;    }

bits\((datasize|64)\)\ (target|result|(operand[1|2]?))[^\n]+\n    {
                                               int operandIdx;
                                               std::stringstream val;
                                               std::string matched(yytext);

                                               if(matched.find("target") == std::string::npos)
                                               {
                                                   if(matched.find(std::string("result")) != std::string::npos)
                                                       operandIdx = 0;

                                                   val<<"uint64_t "<<matched.substr(15, operandIdx == 0?6:8);
                                                   if(operandIdx != 0)
                                                   {
                                                       char idxChar = *(yytext + 22);
                                                       operandIdx = (matched.find("X[t]") != std::string::npos)?0:(idxChar == '1')?1:2;
                                                       val<<" = policy.readGPR(operands["<<operandIdx<<"])";
                                                   }
                                               }
                                               else
                                               {
                                                    val<<"uint64_t "<<matched.substr(9, 6);
                                                    val<<" = policy.readGPR(operands[0])";
                                               }
                                               val<<";";
                                               yylval->strVal = new std::string(val.str());
                                               return token::OPERAND;
                                           }

bits\(64\)\ base\ =\ PC\[\] {   return token::READ_PC;  }

if\ branch_type[^_]+_CALL[^\n]+\n    {	return token::SET_LR;   }

imm|bit_pos                 {
                        yylval->strVal = new std::string("policy.readOperand(1)");
                        return token::OPERAND;
                    }

PC\[\]\ \+\ offset   {
			yylval->strVal = new std::string("policy.readOperand(0)");
			return token::OPERAND;
		     }

bit(s\([0-9]\))?     {   return token::DTYPE_BITS;   }

AddWithCarry|Zeros|NOT|BranchTo|ConditionHolds|IsZero	      {
					yylval->strVal = new std::string(yytext);
					return token::FUNCNAME; 
				      }

if          {   return token::COND_IF;   }

then        {   return token::COND_THEN; }

else        {   return token::COND_ELSE; }

end         {   return token::COND_END; }

\<	    {	return token::SYMBOL_LT;    }

>	    {	return token::SYMBOL_GT;    }

:	    {	return token::SYMBOL_COLON;	}

!|\+|==|&&		{
			    yylval->strVal = new std::string(yytext);    
			    return token::OPER;	
			}

(SP|W|X)\[[a-z]?\]      {  return token::REG;  }

PSTATE[^<]C    {   return token::FLAG_CARRY;   }

PSTATE\.<[^\n]+  {   return token::SET_NZCV;     }

[0-9]+      {
                yylval->intVal = atoi(yytext);
                return token::NUM;
            }

[A-Za-z_]+[0-9]* {
                    yylval->strVal = new std::string(yytext);
                    return token::IDENTIFIER;
                 }

=           {   return token::SYMBOL_EQUAL;    }

\(          {   return token::SYMBOL_OPENROUNDED;  }

\)          {   return token::SYMBOL_CLOSEROUNDED; }

,           {   return token::SYMBOL_COMMA;    }

[ \t;\n]    ;

.           ;


%%

namespace Dyninst_aarch64 {

std::map<std::string, std::string> Scanner::operandExtractorMap;

Scanner::Scanner(std::istream* instream,
		 std::ostream* outstream)
    : yyFlexLexer(instream, outstream)
{
    initOperandExtractorMap();
}

Scanner::~Scanner()
{
}

void Scanner::initOperandExtractorMap() {
    operandExtractorMap[std::string("sub_op")] = std::string("(field<30, 30>(insn) == 1)");
    operandExtractorMap[std::string("setflags")] = std::string("(field<29, 29>(insn) == 1)");
    operandExtractorMap[std::string("d")] = std::string("(field<0, 4>(insn))");
    operandExtractorMap[std::string("condition")] = std::string("(field<0, 4>(insn))");
    operandExtractorMap[std::string("page")] = std::string("(field<31, 31>(insn) == 1)");
    operandExtractorMap[std::string("iszero")] = std::string("(field<24, 24>(insn) == 0)");
    operandExtractorMap[std::string("bit_val")] = std::string("field<24, 24>(insn)");
}

}

#ifdef yylex
#undef yylex
#endif

int yyFlexLexer::yylex()
{
    return 0;
}

int yyFlexLexer::yywrap()
{
    return 1;
}
