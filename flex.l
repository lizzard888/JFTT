%option noyywrap
%option yylineno
%{
    #include <stdlib.h>
    #include <string.h>
    #include "bison.h"
    int yylex();
%}

%x COMM

%%

"{"                    { BEGIN(COMM); }
<COMM>"}"              { BEGIN(INITIAL);}
<COMM>[ \t\r\n]+ 	   {;}
<COMM>.				   {;}
<COMM><<EOF>>          { printf("Błąd! Niezakończony komentarz!\n"); yyterminate(); }

[ \t\r\n]+             	{;}
"VAR"                   { return VAR;      }
"BEGIN"                 { return BEG;    }
"END"                   { return END;      }


"IF"                    { return IF;       }
"THEN"                  { return THEN;     }
"ELSE"                  { return ELSE;     }
"ENDIF"                 { return ENDIF;    }
"WHILE"                 { return WHILE;    }
"DO"                    { return DO;       }
"ENDWHILE"              { return ENDWHILE; }
"FOR"                   { return FOR;      }
"FROM"                  { return FROM;     }
"TO"                    { return TO;       }
"DOWNTO"                { return DOWNTO;   }
"ENDFOR"                { return ENDFOR;   }
"WRITE"                 { return WRITE;    }
"READ"                  { return READ;     }
"SKIP"                  { return SKIP;     }

"["						{ return LQ;       }
"]"						{ return RQ;       }
":="                    { return ASG;      }
"="                     { return EQ;       }
"<"                     { return LT;       }
">"                     { return GT;       }
"<="                    { return LE;       }
">="                    { return GE;       }
"<>"                    { return NE;       }

"+"                     { return ADD;      }
"-"                     { return SUB;      }
"*"                     { return MUL;      }
"/"                     { return DIV;      }
"%"                     { return MOD;      }

[0-9]+                  { yylval.name = strdup(yytext); return NUM;}
[_a-z]+                 { yylval.name = strdup(yytext); return PIDENTIFIER ; }

";"                     { return SEM;      }

%%