%{
#define MAX_STACK 5000
#include <math.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>
#include <stdarg.h>

typedef struct{
	char* name;
	long long int mem;
	long long int local;
  	long long int array;
  	long long int shift;
  	int initialized;
}Identifier;

typedef struct{
	Identifier stack[MAX_STACK];
	long long int top;
}IdentifierStack;
	
typedef struct{
	char* stack[MAX_STACK];
	long long int top;
}CodeStack;
	
typedef struct{
	long long int stack[MAX_STACK];
	long long int top;
}JumpStack;

typedef struct{
	char* stack[MAX_STACK];
	long long int top;
	char* passed[50];
	long long int passed_top;
}ForStack;


IdentifierStack* identifierStack;
CodeStack* codeStack;
JumpStack* jumpStack;
ForStack* forStack;
long long int registerValues[5] = {-1, -1, -1, -1, -1};
long long int expressionArguments[2] = {-1, -1};
int assignFlag;
int numFlag;
Identifier assignTarget;
long long int assignShift;
int writeFlag;
long long int memCounter;
int arrayFlag;

	
int yylex();
int yylineno;
int yyerror(const char* str);

void createIdentifier(Identifier *s, char* name, long long int isLocal, long long int isArray);
void pushIdentifier(Identifier i);
Identifier popIdentifier();
long long int getIdentifierIndex(char* IdentifierName);
long long int getIdentifierMemory(char *IdentifierName);
long long int getArgumentMem(long long int n);
void pushCommand(char* str);
void pushCommand2(char* str, long long int num);
void pushCommand3(char* str, long long int num, long long int num2);
void printCode(char* outFileName);
void pushToJumpStack(long long int i);
long long int isPassed(char* name);
char* popFromForStack();
void pushToForStack(char* i);
char* popFromPassedStack();
void pushToPassedStack(char* i);
long long int popFromJumpStack();
char *decToBin(char *dec);
void memToRegister(long long int mem, long long int reg);
void registerToMem(long long int reg, long long int mem);
long long int numToRegister(long long int num, long long int reg);
void setRegister(char* number, long long int reg);
void nullifyRegister(long long int reg);
Identifier getIdentifier(char* IdentifierName);
void addInt(long long int command, long long int val);

%}

%define parse.error verbose
%define parse.lac full
%union {
    char* name;
    long long int num;
}
%token <name> NUM
%token <name> VAR BEG END IF THEN ELSE ENDIF 
%token <name> WHILE DO ENDWHILE FOR FROM ENDFOR
%token <name> WRITE READ SKIP PIDENTIFIER SEM TO DOWNTO
%token <name> LQ RQ ASG EQ LT GT LE GE NE ADD SUB MUL DIV MOD

%type <name> value 
%type <name> identifier


%%
program:  VAR vdeclarations BEG commands END {
  	pushCommand("HALT");
  }
;

vdeclarations:
  vdeclarations PIDENTIFIER {
  	if(getIdentifierIndex($2) != -1){
        printf("Błąd <linia %d>: Zmienna %s juz istnieje!\n", yylineno, $<name>2);
        exit(1);
    }
    else{
        Identifier s;
        createIdentifier(&s, $2, 0, 0);
        pushIdentifier(s);
    }
  }
| vdeclarations PIDENTIFIER LQ NUM RQ{
    if(getIdentifierIndex($2) != -1){
        printf("Błąd <linia %d>: Zmienna %s juz istnieje!\n", yylineno, $<name>2);
        exit(1);
    }
    else if (atoll($4) <= 0){
        printf("Błąd <linia %d>: Deklaracja tablicy %s o rozmiarze 0 jest troszkę głupia.\n", yylineno, $<name>2);
        exit(1);
    }
    else{
        long long int size = atoll($4); 
        Identifier s;
        createIdentifier(&s, $2, 0, size);
        pushIdentifier(s);
        memCounter += size - 1;
    }
  }
|
;
commands:  commands command 
| command
;
command:  identifier ASG {
  	assignFlag = 0;
  } 
  expression SEM {
  	if(arrayFlag == 1){
  		memToRegister(5, 4);
  		pushCommand2("COPY", 4);
  		registerValues[0] = -1;
  		pushCommand2("STORE", 1);
  		arrayFlag = 0;
      assignShift = 0;
  	}
  	else if(assignTarget.local == 0){
      long long int assignTemp = assignTarget.mem + assignShift;
        	  registerToMem(1, assignTemp);
        	  assignShift = 0;
  		  	}	
  	else{
  		printf("Błąd <linia %d>: Próba modyfikacji iteratora pętli for!\n", yylineno);
  		exit(1);
  	}
  	assignFlag = 1;
  }
| IF {
  	assignFlag = 0;
  	  } 
  condition {
  	  	pushToJumpStack(codeStack->top);
    pushCommand2("JZERO", 1);
    assignFlag = 1;
  }
  THEN commands {
    pushToJumpStack(codeStack->top);
    pushCommand("JUMP");
    addInt(jumpStack->stack[jumpStack->top - 2], codeStack->top);
    registerValues[0] = -1;
	registerValues[1] = -1;
	registerValues[2] = -1;
	registerValues[3] = -1;
	registerValues[4] = -1;
  } 
  ELSE {
  	assignFlag = 1;
  } 
  commands ENDIF {
    addInt(jumpStack->stack[jumpStack->top - 1], codeStack->top);
    popFromJumpStack();
    popFromJumpStack();
    registerValues[0] = -1;
	registerValues[1] = -1;
	registerValues[2] = -1;
	registerValues[3] = -1;
	registerValues[4] = -1;
	assignFlag = 1;
  }
| WHILE {
	registerValues[0] = -1;
	registerValues[1] = -1;
	registerValues[2] = -1;
    assignFlag = 0;
  	pushToJumpStack(codeStack->top);
  } 
  condition {
    pushToJumpStack(codeStack->top);
    pushCommand2("JZERO", 1);
    assignFlag = 1;
  } 
  DO commands ENDWHILE{
    pushCommand2("JUMP", jumpStack->stack[jumpStack->top - 2]);
    addInt(jumpStack->stack[jumpStack->top - 1], codeStack->top);
    popFromJumpStack();
    popFromJumpStack();
    registerValues[0] = -1;
	registerValues[1] = -1;
	registerValues[2] = -1;
	registerValues[3] = -1;
	registerValues[4] = -1;
	assignFlag = 1;
  }
  
| FOR PIDENTIFIER {
  	if(getIdentifierIndex($2) != -1){
        printf("Błąd <linia %d>: Zmienna %s juz istnieje!\n", yylineno, $<name>2);
        exit(1);
    }
    else{
        Identifier s;
        createIdentifier(&s, $2, 1, 0);
        s.initialized = 1;
        pushIdentifier(s);
    }
    assignFlag = 0;
  	assignTarget = getIdentifier($2);
  	  }
  FROM value {
  	long long int mem = getArgumentMem(0);
	
  	if(numFlag){
  		setRegister(strdup(identifierStack->stack[expressionArguments[0]].name), 1);
  		expressionArguments[0] = -2;
  	}
  	else memToRegister(mem, 1);
  	numFlag = 0;
    long long int assignTemp = assignTarget.mem + assignShift;
  	registerToMem(1, assignTemp);
  	assignShift = 0;
  	 assignFlag = 0;
    pushToForStack($2);
  } forending
  

| READ identifier {
	   assignFlag = 1;
  } 
  SEM {
    pushCommand2("GET", 1);
    registerValues[1] = -1;
    if(arrayFlag == 1){
  		memToRegister(5, 4);
  		pushCommand2("COPY", 4);
  		registerValues[0] = -1;
  		pushCommand2("STORE", 1);
  		arrayFlag = 0;
      assignShift = 0;
  	}
  	else if(assignTarget.local == 0){
      long long int assignTemp = assignTarget.mem + assignShift;
      registerToMem(1, assignTemp);
      assignShift = 0;
          } 
    else{
      printf("Błąd <linia %d>: Próba modyfikacji iteratora pętli for.\n", yylineno);
      exit(1);
    }
    assignFlag = 1;
  }
| WRITE {
	assignFlag = 0;
	writeFlag = 1;
  } 
  value SEM {
  	if(numFlag){
  		long long int mem = getArgumentMem(0);
  		setRegister(strdup(identifierStack->stack[expressionArguments[0]].name), 1);
  		popIdentifier();
  	}
  	else{
  		long long int mem = getArgumentMem(0);
  		memToRegister(mem, 1);
  	}
    pushCommand2("PUT", 1);
    assignFlag = 1;
    numFlag = 0;
    writeFlag = 0;
    expressionArguments[0] = -1;
      }
| SKIP SEM
;
forending:  DOWNTO value {
    char* p_index = popFromForStack();
    long long int mem;
    if(expressionArguments[0] == -2 && numFlag){
      long long int value = registerValues[1] - atoll(identifierStack->stack[expressionArguments[1]].name);
      if(value < 0){
        pushToJumpStack(codeStack->top);
        pushCommand("JUMP");
        pushToPassedStack(strdup(p_index));
      }
      else{
        char *str = (char *)malloc(100);
        sprintf(str, "%lld", value);
        setRegister(str, 1);
        free(str);
      }
      popIdentifier();
      popIdentifier();
    }
    else if(numFlag){
      long long int mem = getArgumentMem(1);
      long long int mem1 = getArgumentMem(0);
      setRegister(strdup(identifierStack->stack[expressionArguments[1]].name), 3);
      setRegister(strdup(identifierStack->stack[expressionArguments[1]].name), 1);
      memToRegister(mem1, 2);

      setRegister(strdup("0"), 0);
      pushCommand2("STORE", 2);
      pushCommand2("SUB", 3);

      pushCommand3("JZERO", 3, codeStack->top+2);
      pushToPassedStack(strdup(p_index));
      pushToJumpStack(codeStack->top);
      pushCommand("JUMP");

      setRegister(strdup("0"), 0);
      pushCommand2("STORE", 1);
      setRegister(strdup("1"), 0);
      pushCommand2("STORE", 2);
      pushCommand2("LOAD", 1);
      setRegister(strdup("0"), 0);
      pushCommand2("SUB", 1);

      popIdentifier();
    }
    else{

      if(expressionArguments[0] == -2){
        long long int mem = getArgumentMem(1);
        char *str = (char *)malloc(100);
        sprintf(str, "%lld", registerValues[1]);
        setRegister(strdup(str), 2);
        
        memToRegister(mem, 3);       
        
        memToRegister(mem, 1);      
      
        setRegister(strdup("0"), 0);
        pushCommand2("STORE", 2);
        pushCommand2("SUB", 3);

        pushCommand3("JZERO", 3, codeStack->top+2);
        pushToPassedStack(strdup(p_index));
        pushToJumpStack(codeStack->top);
        pushCommand("JUMP");

        setRegister(strdup("0"), 0);
        pushCommand2("STORE", 1);
        setRegister(strdup("1"), 0);
        pushCommand2("STORE", 2);
        pushCommand2("LOAD", 1);
        setRegister(strdup("0"), 0);
        pushCommand2("SUB", 1);
        popIdentifier();

        free(str);
      }
      else{
        long long int mem = getArgumentMem(1);
        long long int mem1 = getArgumentMem(0);
        memToRegister(mem, 3);
        memToRegister(mem1, 2);
        memToRegister(mem, 1);

        char *str = (char *)malloc(100);
        sprintf(str, "%lld", mem1);
        setRegister(str, 0);
        free(str);
        
        pushCommand2("SUB", 3);

        pushToPassedStack(strdup(p_index));
        pushCommand3("JZERO", 3, codeStack->top+2);
        pushToJumpStack(codeStack->top);
        pushCommand("JUMP");

        setRegister(strdup("0"), 0);
        pushCommand2("STORE", 1);
        setRegister(strdup("1"), 0);
        pushCommand2("STORE", 2);
        pushCommand2("LOAD", 1);
        setRegister(strdup("0"), 0);
        pushCommand2("SUB", 1);
      
      }
      
    }
    expressionArguments[0] = -1;
    expressionArguments[1] = -1;
    numFlag = 0;
        char *str = (char *)malloc(100);
    sprintf(str, "0%s", p_index);
    Identifier z;
    createIdentifier(&z, str, 0, 0);
    pushIdentifier(z);
    mem = getIdentifierMemory(p_index) + 1;
    free(str);
    registerValues[0] = -1; 
    pushCommand2("INC", 1);
    registerValues[1]++; 
    registerToMem(1, mem);
    
    pushToJumpStack(codeStack->top);

    pushCommand2("ZERO", 0);
    registerValues[0] = 0;
    memToRegister(mem, 1); 

        pushToJumpStack(codeStack->top);
    pushCommand2("JZERO", 1);
    assignFlag = 1;
    pushToForStack(p_index);
  }
  DO commands ENDFOR {
    char* p_index = popFromForStack();
    long long int mem2 = getIdentifierMemory(p_index);
        long long int mem = mem2 + 1;
    pushCommand2("ZERO", 0);
    registerValues[0] = 0;
    memToRegister(mem, 1);

    pushCommand2("DEC", 1);
    registerValues[1]--;
    registerToMem(1, mem);
    memToRegister(mem2, 2);

    pushCommand2("DEC", 2);
    registerValues[2]--;
    
    registerToMem(2, mem2);
    
    pushCommand2("JUMP", jumpStack->stack[jumpStack->top - 2]);
    addInt(jumpStack->stack[jumpStack->top - 1], codeStack->top);
    if (isPassed(p_index)){
      addInt(jumpStack->stack[jumpStack->top - 3], codeStack->top);
      popFromJumpStack();
      popFromPassedStack();
    }
    popFromJumpStack();
    popFromJumpStack();
    registerValues[0] = -1;
 	registerValues[1] = -1;
  	registerValues[2] = -1;
  	registerValues[3] = -1;
  	registerValues[4] = -1;
  	popIdentifier();
  	popIdentifier();
  }
| TO value {     char* p_index = popFromForStack();
        long long int mem;
        if(expressionArguments[0] == -2 && numFlag){ 
      long long int value = atoll(identifierStack->stack[expressionArguments[1]].name) - registerValues[1];
      if(value < 0){
        pushToJumpStack(codeStack->top);
        pushCommand("JUMP");
        pushToPassedStack(strdup(p_index));
      }
      else{
        char *str = (char *)malloc(100);
        sprintf(str, "%lld", value);
        setRegister(str, 1);
        free(str);
      }
      popIdentifier();
      popIdentifier();
    }
    else if(numFlag){
      long long int mem = getArgumentMem(1);
      long long int mem1 = getArgumentMem(0);
     
      memToRegister(mem1, 3);
           
      memToRegister(mem1, 1);
      
      setRegister(identifierStack->stack[expressionArguments[1]].name, 2);

      setRegister(strdup("0"), 0);
      pushCommand2("STORE", 2);
      pushCommand2("SUB", 3);

      pushToPassedStack(strdup(p_index));
      pushCommand3("JZERO", 3, codeStack->top+2);
      pushToJumpStack(codeStack->top);
      pushCommand("JUMP");

      setRegister(strdup("0"), 0);
      pushCommand2("STORE", 1);
      setRegister(strdup("1"), 0);
      pushCommand2("STORE", 2);
      pushCommand2("LOAD", 1);
      setRegister(strdup("0"), 0);
      pushCommand2("SUB", 1);

      popIdentifier();
    }
    else{

      if(expressionArguments[0] == -2){
                long long int mem = getArgumentMem(1);
        char *str = (char *)malloc(100);
        sprintf(str, "%lld", registerValues[1]);
        setRegister(str, 3);
        free(str);

        memToRegister(mem, 2);
        
        setRegister(strdup("0"), 0);
        pushCommand2("STORE", 2);
        pushCommand2("SUB", 3);

        pushToPassedStack(strdup(p_index));
        pushCommand3("JZERO", 3, codeStack->top+2);
        pushToJumpStack(codeStack->top);
        pushCommand("JUMP");

        setRegister(strdup("0"), 0);
        pushCommand2("STORE", 1);
        setRegister(strdup("1"), 0);
        pushCommand2("STORE", 2);
        pushCommand2("LOAD", 1);
        setRegister(strdup("0"), 0);
        pushCommand2("SUB", 1);
        popIdentifier();

      }
      else{
                long long int mem = getArgumentMem(1);
        long long int mem1 = getArgumentMem(0);

        memToRegister(mem1, 3);

        char *str = (char *)malloc(100);
        sprintf(str, "%lld", mem1);
        setRegister(str, 0);
        pushCommand2("SUB", 3);

        sprintf(str, "%lld", mem);
        setRegister(str, 0);

        memToRegister(mem, 2);

        pushToPassedStack(strdup(p_index));
        pushCommand3("JZERO", 3, codeStack->top+2);
        pushToJumpStack(codeStack->top);
        pushCommand("JUMP");

        setRegister(strdup("0"), 0);
        pushCommand2("STORE", 1);
        setRegister(strdup("1"), 0);
        pushCommand2("STORE", 2);
        pushCommand2("LOAD", 1);
        setRegister(strdup("0"), 0);
        pushCommand2("SUB", 1);
      
      }
      
    }
    expressionArguments[0] = -1;
    expressionArguments[1] = -1;
    numFlag = 0;
        char *str = (char *)malloc(100);
    sprintf(str, "0%s", p_index);
    Identifier z;
    createIdentifier(&z, str, 0, 0);
    pushIdentifier(z);
    mem = getIdentifierMemory(p_index) + 1;
    free(str);

    registerValues[0] = -1;
    pushCommand2("INC", 1);
    registerValues[1]++;
    registerToMem(1, mem);

    pushToJumpStack(codeStack->top);

    pushCommand2("ZERO", 0);
    registerValues[0] = 0;
    memToRegister(mem, 1); 

        pushToJumpStack(codeStack->top);
    pushCommand2("JZERO", 1);
    assignFlag = 1;
        pushToForStack(strdup(p_index));
  }
  DO commands ENDFOR {
    char* p_index = popFromForStack();
        long long int mem2 = getIdentifierMemory(p_index);
        long long int mem = mem2 + 1;
    pushCommand2("ZERO", 0);
    registerValues[0] = 0;    
    memToRegister(mem, 1);
    pushCommand2("DEC", 1);
    registerValues[1]--;
    registerToMem(1, mem);       
    memToRegister(mem2, 2);    
    pushCommand2("INC", 2);
    registerValues[2]++;   
    registerToMem(2, mem2);
    pushCommand2("JUMP", jumpStack->stack[jumpStack->top - 2]);
    addInt(jumpStack->stack[jumpStack->top - 1], codeStack->top);
    if (isPassed(p_index)){
      addInt(jumpStack->stack[jumpStack->top - 3], codeStack->top);
      popFromJumpStack();
      popFromPassedStack();
    }
    popFromJumpStack();
    popFromJumpStack();
    registerValues[0] = -1;
    registerValues[1] = -1;
    registerValues[2] = -1;
    registerValues[3] = -1;
    registerValues[4] = -1;
    popIdentifier();
    popIdentifier();
  }
;

expression:  value {
  	long long int mem = getArgumentMem(0);
  	if(numFlag){
  		long long int mem = getArgumentMem(0);
  		setRegister(strdup(identifierStack->stack[expressionArguments[0]].name), 1);
  		popIdentifier();
  	}
  	else memToRegister(mem, 1);
  	numFlag = 0;
  	if (!writeFlag)
  		expressionArguments[0] = -1;
  }
| value{
	long long int mem = getArgumentMem(0);
  	if(numFlag){
  		setRegister(strdup(identifierStack->stack[expressionArguments[0]].name), 1);
  		expressionArguments[0] = -2;
  	}
  	else memToRegister(mem, 1);
  	numFlag = 0;
  	  } 
  ADD value{
  	  	if(expressionArguments[0] == -2 && numFlag){
  			
  		long long int value = registerValues[1] + atoll(identifierStack->stack[expressionArguments[1]].name);
  		char *str = (char *)malloc(100);
		sprintf(str, "%lld", value);
  		setRegister(str, 1);
  		free(str);
  		popIdentifier();
  		popIdentifier();
  	}
  	else if(numFlag){
  		long long int diff = atoll(identifierStack->stack[expressionArguments[1]].name);
  		if(diff <= 20)
  				for(long long int i = 1; i<=diff; i++){
  					pushCommand2("INC", 1);
  					registerValues[1]++;
  				} 
  		else{
  			long long int mem = getArgumentMem(1);
  			setRegister(strdup(identifierStack->stack[expressionArguments[1]].name), 2);
  			registerToMem(2, mem);
			char *str = (char *)malloc(100);
			sprintf(str, "%lld", mem);
			setRegister(str, 0);
			free(str);
			pushCommand2("ADD", 1);
			registerValues[1] = -1;
  		}
  		popIdentifier();
  	}	
  	else{
  		  		long long int mem = getArgumentMem(1);
		char *str = (char *)malloc(100);
		sprintf(str, "%lld", mem);
		setRegister(str, 0);
		free(str);
		pushCommand2("ADD", 1);
		registerValues[1] = -1;
  	}
  	expressionArguments[0] = -1;
	expressionArguments[1] = -1;
	numFlag = 0;
  }
| value {
	long long int mem = getArgumentMem(0);
  	if(numFlag){
  		setRegister(strdup(identifierStack->stack[expressionArguments[0]].name), 1);
  		expressionArguments[0] = -2;
  	}
  	else memToRegister(mem, 1);
  	numFlag = 0;
  	    } 
  SUB value{
	  	if(expressionArguments[0] == -2 && numFlag){
  			
  		long long int value = registerValues[1] - atoll(identifierStack->stack[expressionArguments[1]].name);
  		if(value < 0) value = 0;
  		char *str = (char *)malloc(100);
		sprintf(str, "%lld", value);
  		setRegister(str, 1);
  		free(str);
   		popIdentifier();
  		popIdentifier();
  	}
  	else if(numFlag){
  		long long int diff = atoll(identifierStack->stack[expressionArguments[1]].name);
  		if(diff <= 20)
  				for(long long int i = 1; i<=diff; i++){
  					pushCommand2("DEC", 1);
  					registerValues[1]++;
  				} 
  		else{			
  			long long int mem = getArgumentMem(1);			
  			setRegister(strdup(identifierStack->stack[expressionArguments[1]].name), 2);  			
  			registerToMem(2, mem);
			char *str = (char *)malloc(100);
			sprintf(str, "%lld", mem);
			setRegister(str, 0);
			free(str);
			pushCommand2("SUB", 1);
			registerValues[1] = -1;
  		}
  		popIdentifier();
  	}	
  	else{
  		  		long long int mem = getArgumentMem(1);
		char *str = (char *)malloc(100);
		sprintf(str, "%lld", mem);
		setRegister(str, 0);
		free(str);
		pushCommand2("SUB", 1);
		registerValues[1] = -1;
  	}
  	expressionArguments[0] = -1;
	expressionArguments[1] = -1;
	numFlag = 0;
  }
| value {
	long long int mem = getArgumentMem(0);
  	if(numFlag){
  		setRegister(strdup(identifierStack->stack[expressionArguments[0]].name), 3);
  		expressionArguments[0] = -2;
  	}
  	else memToRegister(mem, 3);
  	numFlag = 0;
  	    } 
  MUL value{
	  	if(expressionArguments[0] == -2 && numFlag){
  			
  		long long int value = registerValues[3] * atoll(identifierStack->stack[expressionArguments[1]].name);
  		char *str = (char *)malloc(100);
		  sprintf(str, "%lld", value);
  		setRegister(str, 1);
  		free(str);
  		popIdentifier();
  		popIdentifier();
  	}
  	else if(numFlag){
  		long long int denom = atoll(identifierStack->stack[expressionArguments[1]].name);
  		long long int power = 0;
  		long long int x = 0;
  		while(denom > 1){
  			div_t result = div(denom, 2);
  			if(result.rem == 1){
  				power = 0;
  				break;
  			}
  			denom = result.quot;
  			power = 1;
  			x++;
  		}
  		if(power){
  				long long int mem = getArgumentMem(0);
  				memToRegister(mem, 1);
  				for(long long int i = 1; i<=x; i++){
  					pushCommand2("SHL", 1);
  					if(registerValues > 0){
  						registerValues[1] *= 2;
  					}
  				} 
  		}
  		else{
  			long long int mem = getArgumentMem(1);

  			char *str = (char *)malloc(100);
			 sprintf(str, "%lld", mem);
  			setRegister(str, 0);
  			free(str);

  			nullifyRegister(1);
  			setRegister(strdup(identifierStack->stack[expressionArguments[1]].name), 2);
  			pushCommand3("JZERO", 3, (codeStack->top+8));
  			pushCommand2("STORE", 2);
  			pushCommand3("JODD", 3, (codeStack->top+2));
  			pushCommand2("JUMP", (codeStack->top+2));
  			pushCommand2("ADD", 1);
  			pushCommand2("SHR", 3);
  			pushCommand2("SHL", 2);
  			pushCommand2("JUMP", (codeStack->top-7));

  		}
  		popIdentifier();	
  	}	
  	else{
  	long long int mem = getArgumentMem(1);
		
		memToRegister(mem, 2);

  		
  		registerToMem(2, 0);

  		setRegister("0", 0);
  		

  		nullifyRegister(1);
  		pushCommand3("JZERO", 3, (codeStack->top+8));
  		pushCommand2("STORE", 2);
  		pushCommand3("JODD", 3, (codeStack->top+2));
  		pushCommand2("JUMP", (codeStack->top+2));
  		pushCommand2("ADD", 1);
  		pushCommand2("SHR", 3);
  		pushCommand2("SHL", 2);
  		pushCommand2("JUMP", (codeStack->top-7));
  	}
  	registerValues[0] = -1;
	registerValues[1] = -1;
	registerValues[2] = -1;
	registerValues[3] = -1;
  	expressionArguments[0] = -1;
	expressionArguments[1] = -1;
	numFlag = 0;
  }
| value {
	long long int mem = getArgumentMem(0);
  	if(numFlag){
  		setRegister(strdup(identifierStack->stack[expressionArguments[0]].name), 3);
  		expressionArguments[0] = -2;
  	}
  	else memToRegister(mem, 3);
  	numFlag = 0;
  	    } 
  DIV value{
  	if(expressionArguments[0] == -2 && numFlag){

  		if(atoll(identifierStack->stack[expressionArguments[1]].name) > 0){
  			long long int value = registerValues[3] / atoll(identifierStack->stack[expressionArguments[1]].name);
  			char *str = (char *)malloc(100);
			sprintf(str, "%lld", value);
  			setRegister(str, 1);
  		  	free(str);
  			popIdentifier();
  			popIdentifier();
  		}
  		else{
  			setRegister(strdup("0"), 1);
  		}
  		
  	}
  	else if(numFlag && atoll(identifierStack->stack[expressionArguments[1]].name) > 0){
  		long long int denom = atoll(identifierStack->stack[expressionArguments[1]].name);
  		long long int power = 0;
  		long long int x = 0;
  		while(denom > 1){
  			div_t result = div(denom, 2);
  			if(result.rem == 1){
  				power = 0;
  				break;
  			}
  			denom = result.quot;
  			power = 1;
  			x++;
  		}
  		if(power){
				long long int mem = getArgumentMem(0);		
  				memToRegister(mem, 1);		
  				for(long long int i = 1; i<=x; i++){
  					pushCommand2("SHR", 1);
  					if(registerValues > 0){
  						registerValues[1] /= 2;
  					}
  				} 
  		}
  		else{
  			long long int mem = getArgumentMem(1);
  			setRegister(strdup("1"), 0);
  			pushCommand2("STORE", 3);
  			setRegister(strdup(identifierStack->stack[expressionArguments[1]].name), 2);
  			setRegister(strdup("0"), 0);
  			setRegister(strdup("0"), 1);
  			setRegister(strdup("1"), 4);

  			pushCommand3("JZERO", 2, (codeStack->top+57));
  			pushCommand2("SUB", 3);
	  		pushCommand3("JZERO", 3, (codeStack->top+3));
	  		pushCommand2("ADD", 3);
	  		pushCommand2("JUMP", (codeStack->top+14));
	  		pushCommand2("ZERO", 0);
	  		pushCommand2("INC", 0);
	  		pushCommand2("LOAD", 3);
	  		pushCommand2("SUB", 2);
	  		pushCommand3("JZERO", 2, (codeStack->top+3));
	  		pushCommand2("ADD", 2);
	  		pushCommand2("JUMP", (codeStack->top+12));
	  		pushCommand2("INC", 1);
	  		pushCommand2("SHR", 4);
	  		pushCommand3("JZERO", 4, (codeStack->top+43));
	  		pushCommand2("SHR", 4);
	  		pushCommand2("SHL", 1);
	  		pushCommand2("JUMP", (codeStack->top-3));
	  		pushCommand2("ZERO", 0);
	  		pushCommand2("SHL", 2);
	  		pushCommand2("STORE", 2);
	  		pushCommand2("SHL", 4);
	  		pushCommand2("JUMP", (codeStack->top-21));

	  		pushCommand2("ZERO", 0);
			pushCommand2("SHR", 2);
			pushCommand2("STORE", 2);
			pushCommand2("SHR", 4);
	  		pushCommand3("JZERO", 4, (codeStack->top+30));
	  		pushCommand2("ZERO", 0);
	  		pushCommand2("INC", 0);
	  		pushCommand2("INC", 0);
	  		pushCommand2("STORE", 4);
	  		pushCommand2("DEC", 0);
	  		pushCommand2("STORE", 3);
	  		pushCommand2("DEC", 0);
	  		pushCommand2("SUB", 3);
	  		pushCommand3("JZERO", 3, (codeStack->top+15));
	  		pushCommand2("JUMP", (codeStack->top+5));
	  		pushCommand2("ZERO", 0);
	  		pushCommand2("INC", 0);
	  		pushCommand2("LOAD", 2);
	  		pushCommand2("ZERO", 3);
	  		pushCommand2("ZERO", 0);
	  		pushCommand2("INC", 0);
	  		pushCommand2("INC", 0);
	  		pushCommand2("ADD", 1);
	  		pushCommand2("SHR", 4);
	  		pushCommand2("SHR", 2);
	  		pushCommand2("ZERO", 0);
	  		pushCommand2("STORE", 2);
	  		pushCommand2("JUMP", (codeStack->top-23));
	  		pushCommand2("INC", 0);
	  		pushCommand2("LOAD", 3);
	  		pushCommand2("SUB", 2);
	  		pushCommand3("JZERO", 2, (codeStack->top-16));
	  		pushCommand2("ADD", 2);
	  		pushCommand2("JUMP", (codeStack->top-10));

			registerValues[0] = -1;
			registerValues[1] = -1;
			registerValues[2] = -1;
			registerValues[3] = -1;
			registerValues[4] = 0;
  		}
  		popIdentifier();	
  	}	
  	else{
  		long long int mem = getArgumentMem(1);	
		memToRegister(mem, 2);
		setRegister(strdup("1"), 0);
  		pushCommand2("STORE", 3);
  		nullifyRegister(0);
  		nullifyRegister(1);
  		setRegister(strdup("1"), 4);

  		pushCommand3("JZERO", 2, (codeStack->top+57));
  		pushCommand2("SUB", 3);
	  	pushCommand3("JZERO", 3, (codeStack->top+3));
	  	pushCommand2("ADD", 3);
	  	pushCommand2("JUMP", (codeStack->top+14));
	  	pushCommand2("ZERO", 0);
	  	pushCommand2("INC", 0);
	  	pushCommand2("LOAD", 3);
	  	pushCommand2("SUB", 2);
	  	pushCommand3("JZERO", 2, (codeStack->top+3));
	  	pushCommand2("ADD", 2);
	  	pushCommand2("JUMP", (codeStack->top+12));
	  	pushCommand2("INC", 1);
	  	pushCommand2("SHR", 4);
	  	pushCommand3("JZERO", 4, (codeStack->top+43));
	  	pushCommand2("SHR", 4);
	  	pushCommand2("SHL", 1);
	  	pushCommand2("JUMP", (codeStack->top-3));
	  	pushCommand2("ZERO", 0);
	  	pushCommand2("SHL", 2);
	 	pushCommand2("STORE", 2);
	  	pushCommand2("SHL", 4);
	  	pushCommand2("JUMP", (codeStack->top-21));

	  	pushCommand2("ZERO", 0);
		pushCommand2("SHR", 2);
		pushCommand2("STORE", 2);
		pushCommand2("SHR", 4);
	  	pushCommand3("JZERO", 4, (codeStack->top+30));
	  	pushCommand2("ZERO", 0);
	  	pushCommand2("INC", 0);
	  	pushCommand2("INC", 0);
	  	pushCommand2("STORE", 4);
	  	pushCommand2("DEC", 0);
	  	pushCommand2("STORE", 3);
	  	pushCommand2("DEC", 0);
	  	pushCommand2("SUB", 3);
	  	pushCommand3("JZERO", 3, (codeStack->top+15));
	  	pushCommand2("JUMP", (codeStack->top+5));
	  	pushCommand2("ZERO", 0);
	  	pushCommand2("INC", 0);
	  	pushCommand2("LOAD", 2);
	  	pushCommand2("ZERO", 3);
	  	pushCommand2("ZERO", 0);
	  	pushCommand2("INC", 0);
	  	pushCommand2("INC", 0);
	  	pushCommand2("ADD", 1);
	  	pushCommand2("SHR", 4);
	  	pushCommand2("SHR", 2);
	  	pushCommand2("ZERO", 0);
	  	pushCommand2("STORE", 2);
	  	pushCommand2("JUMP", (codeStack->top-23));
	  	pushCommand2("INC", 0);
	  	pushCommand2("LOAD", 3);
	  	pushCommand2("SUB", 2);
	  	pushCommand3("JZERO", 2, (codeStack->top-16));
	  	pushCommand2("ADD", 2);
	  	pushCommand2("JUMP", (codeStack->top-10));

		registerValues[0] = -1;
		registerValues[1] = -1;
		registerValues[2] = -1;
		registerValues[3] = -1;
		registerValues[4] = 0;
  	}
  	registerValues[0] = -1;
	registerValues[1] = -1;
	registerValues[2] = -1;
	registerValues[3] = -1;
  	expressionArguments[0] = -1;
	expressionArguments[1] = -1;
	numFlag = 0;
  }
| value {
	long long int mem = getArgumentMem(0);
  	if(numFlag){
  		setRegister(strdup(identifierStack->stack[expressionArguments[0]].name), 1);
  		expressionArguments[0] = -2;
  	}
  	else memToRegister(mem, 1);
  	numFlag = 0;
  	  } 
  MOD value{
	  	 if(expressionArguments[0] == -2 && numFlag){
  			if(atoll(identifierStack->stack[expressionArguments[1]].name) > 0){		
  				long long int value = registerValues[1] % atoll(identifierStack->stack[expressionArguments[1]].name);
  				char *str = (char *)malloc(100);
				sprintf(str, "%lld", value);
  				setRegister(str, 1);
  				free(str);
  				popIdentifier();
  				popIdentifier();
  			}
  			else{
  			setRegister(strdup("0"), 1);
  			}
  	}
  	else if(numFlag){
  		
  		long long int mem = getArgumentMem(1);
  		nullifyRegister(0);
  		setRegister(strdup("1"), 0);
  		pushCommand2("STORE", 1);
  		setRegister(strdup(identifierStack->stack[expressionArguments[1]].name), 2);
  		nullifyRegister(0);
  		pushCommand2("STORE", 2);
  		setRegister(strdup("1"), 3);

  		pushCommand3("JZERO", 2, (codeStack->top+41));
  		pushCommand2("SUB", 1);
		pushCommand3("JZERO", 1, (codeStack->top+3));
		pushCommand2("ADD", 1);
		pushCommand2("JUMP", (codeStack->top+10));
		pushCommand2("ZERO", 0);
		pushCommand2("INC", 0);
		pushCommand2("LOAD", 1);
		pushCommand2("SUB", 2);
		pushCommand3("JZERO", 2, (codeStack->top+3));
		pushCommand2("ADD", 2);
		pushCommand2("JUMP", (codeStack->top+8));
		pushCommand2("ZERO", 1);
		pushCommand2("JUMP", (codeStack->top+29));
		pushCommand2("ZERO", 0);
		pushCommand2("SHL", 2);
		pushCommand2("STORE", 2);
		pushCommand2("SHL", 3);
		pushCommand2("JUMP", (codeStack->top-17));

		pushCommand2("ZERO", 0);
		pushCommand2("SHR", 2);
		pushCommand2("STORE", 2);
		pushCommand2("SHR", 3);
		pushCommand3("JZERO", 3, (codeStack->top+19));
		pushCommand2("ZERO", 0);
		pushCommand2("INC", 0);
		pushCommand2("STORE", 1);
		pushCommand2("DEC", 0);
		pushCommand2("SUB", 1);
		pushCommand3("JZERO", 1, (codeStack->top+6));
		pushCommand2("ZERO", 0);
		pushCommand2("SHR", 3);
		pushCommand2("SHR", 2);
		pushCommand2("STORE", 2);
		pushCommand2("JUMP", (codeStack->top-11));
		pushCommand2("INC", 0);
		pushCommand2("LOAD", 1);
		pushCommand2("SUB", 2);
		pushCommand3("JZERO", 2, (codeStack->top+3));
		pushCommand2("ADD", 2);
		pushCommand2("JUMP", (codeStack->top-10));
		pushCommand2("ZERO", 1);

  		popIdentifier();	
  	}	
  	else{
  		  		long long int mem = getArgumentMem(1);
		memToRegister(mem, 2);
		
		nullifyRegister(0);
		pushCommand2("STORE", 2);
		setRegister(strdup("1"), 0);
  		pushCommand2("STORE", 1);
  		nullifyRegister(0);
  		setRegister(strdup("1"), 3);

  		pushCommand3("JZERO", 2, (codeStack->top+41));
  		pushCommand2("SUB", 1);
		pushCommand3("JZERO", 1, (codeStack->top+3));
		pushCommand2("ADD", 1);
		pushCommand2("JUMP", (codeStack->top+10));
		pushCommand2("ZERO", 0);
		pushCommand2("INC", 0);
		pushCommand2("LOAD", 1);
		pushCommand2("SUB", 2);
		pushCommand3("JZERO", 2, (codeStack->top+3));
		pushCommand2("ADD", 2);
		pushCommand2("JUMP", (codeStack->top+8));
		pushCommand2("ZERO", 1);
		pushCommand2("JUMP", (codeStack->top+29));
		pushCommand2("ZERO", 0);
		pushCommand2("SHL", 2);
		pushCommand2("STORE", 2);
		pushCommand2("SHL", 3);
		pushCommand2("JUMP", (codeStack->top-17));

		pushCommand2("ZERO", 0);
		pushCommand2("SHR", 2);
		pushCommand2("STORE", 2);
		pushCommand2("SHR", 3);
		pushCommand3("JZERO", 3, (codeStack->top+19));
		pushCommand2("ZERO", 0);
		pushCommand2("INC", 0);
		pushCommand2("STORE", 1);
		pushCommand2("DEC", 0);
		pushCommand2("SUB", 1);
		pushCommand3("JZERO", 1, (codeStack->top+6));
		pushCommand2("ZERO", 0);
		pushCommand2("SHR", 3);
		pushCommand2("SHR", 2);
		pushCommand2("STORE", 2);
		pushCommand2("JUMP", (codeStack->top-11));
		pushCommand2("INC", 0);
		pushCommand2("LOAD", 1);
		pushCommand2("SUB", 2);
		pushCommand3("JZERO", 2, (codeStack->top+3));
		pushCommand2("ADD", 2);
		pushCommand2("JUMP", (codeStack->top-10));
		pushCommand2("ZERO", 1);

  	}
  	registerValues[0] = -1;
	registerValues[1] = -1;
	registerValues[2] = -1;
	registerValues[3] = -1;
	registerValues[4] = -1;
  	expressionArguments[0] = -1;
	expressionArguments[1] = -1;
	numFlag = 0;
  }
;
condition:  value {
  	long long int mem = getArgumentMem(0);
  	if(numFlag){
  		setRegister(strdup(identifierStack->stack[expressionArguments[0]].name), 1);
  		expressionArguments[0] = -2;
  	}
  	else memToRegister(mem, 1);
  	numFlag = 0;
  	  } 
  EQ value{
  	  	if(expressionArguments[0] == -2 && numFlag){
  			
  		if(registerValues[1] == atoll(identifierStack->stack[expressionArguments[1]].name))
  			setRegister(strdup("1"), 1);
  		else
  			setRegister(strdup("0"), 1);
  		
  		popIdentifier();
  		popIdentifier();
  	}
  	else if(numFlag){
  		long long int mem = getArgumentMem(1);
  		setRegister(strdup(identifierStack->stack[expressionArguments[1]].name), 2);

		pushCommand2("ZERO", 0);
		pushCommand2("STORE", 1);
		pushCommand2("INC", 0);
		pushCommand2("STORE", 2);
		pushCommand2("SUB", 1);
		pushCommand3("JZERO", 1, (codeStack->top+3));
		pushCommand2("ZERO", 1);
		pushCommand2("JUMP", (codeStack->top+9));
		pushCommand2("DEC", 0);
		pushCommand2("LOAD", 1);
		pushCommand2("SUB", 2);
		pushCommand3("JZERO", 2, (codeStack->top+3));
		pushCommand2("ZERO", 1);
		pushCommand2("JUMP", (codeStack->top+3));
		pushCommand2("ZERO", 1);
		pushCommand2("INC", 1);

		popIdentifier();	
  	}	
  	else{
  		  		long long int mem = getArgumentMem(1);
		memToRegister(mem, 2);		
		
		pushCommand2("ZERO", 0);
		pushCommand2("STORE", 1);
		pushCommand2("INC", 0);
		pushCommand2("STORE", 2);
		pushCommand2("SUB", 1);
		pushCommand3("JZERO", 1, (codeStack->top+3));
		pushCommand2("ZERO", 1);
		pushCommand2("JUMP", (codeStack->top+9));
		pushCommand2("DEC", 0);
		pushCommand2("LOAD", 1);
		pushCommand2("SUB", 2);
		pushCommand3("JZERO", 2, (codeStack->top+3));
		pushCommand2("ZERO", 1);
		pushCommand2("JUMP", (codeStack->top+3));
		pushCommand2("ZERO", 1);
		pushCommand2("INC", 1);

  	}
  	registerValues[0] = -1;
	registerValues[1] = -1;
	registerValues[2] = -1;
  	expressionArguments[0] = -1;
	expressionArguments[1] = -1;
	numFlag = 0;
  }
| value {
	long long int mem = getArgumentMem(0);
  	if(numFlag){
  		setRegister(strdup(identifierStack->stack[expressionArguments[0]].name), 1);
  		expressionArguments[0] = -2;
  	}
  	else memToRegister(mem, 1);
  	numFlag = 0;
  	  } 
  NE value{
	  	if(expressionArguments[0] == -2 && numFlag){
  			
  		if(registerValues[1] != atoll(identifierStack->stack[expressionArguments[1]].name))
  			setRegister(strdup("1"), 1);
  		else
  			setRegister(strdup("0"), 1);
  
  		popIdentifier();
  		popIdentifier();
  	}
  	else if(numFlag){
  		long long int mem = getArgumentMem(1);
  		setRegister(strdup(identifierStack->stack[expressionArguments[1]].name), 2);

		pushCommand2("ZERO", 0);
		pushCommand2("STORE", 1);
		pushCommand2("INC", 0);
		pushCommand2("STORE", 2);
		pushCommand2("SUB", 1);
		pushCommand3("JZERO", 1, (codeStack->top+4));
		pushCommand2("ZERO", 1);
		pushCommand2("INC", 1);
		pushCommand2("JUMP", (codeStack->top+9));
		pushCommand2("DEC", 0);
		pushCommand2("LOAD", 1);
		pushCommand2("SUB", 2);
		pushCommand3("JZERO", 2, (codeStack->top+4));
		pushCommand2("ZERO", 1);
		pushCommand2("INC", 1);
		pushCommand2("JUMP", (codeStack->top+2));
		pushCommand2("ZERO", 1);
		
		popIdentifier();	
  	}	
  	else{
  		  		long long int mem = getArgumentMem(1);
		memToRegister(mem, 2);
		
		pushCommand2("ZERO", 0);
		pushCommand2("STORE", 1);
		pushCommand2("INC", 0);
		pushCommand2("STORE", 2);
		pushCommand2("SUB", 1);
		pushCommand3("JZERO", 1, (codeStack->top+4));
		pushCommand2("ZERO", 1);
		pushCommand2("INC", 1);
		pushCommand2("JUMP", (codeStack->top+9));
		pushCommand2("DEC", 0);
		pushCommand2("LOAD", 1);
		pushCommand2("SUB", 2);
		pushCommand3("JZERO", 2, (codeStack->top+4));
		pushCommand2("ZERO", 1);
		pushCommand2("INC", 1);
		pushCommand2("JUMP", (codeStack->top+2));
		pushCommand2("ZERO", 1);

  	}
  	registerValues[0] = -1;
	registerValues[1] = -1;
	registerValues[2] = -1;
  	expressionArguments[0] = -1;
	expressionArguments[1] = -1;
	numFlag = 0;
  }
| value{
	long long int mem = getArgumentMem(0);
  	if(numFlag){
  		setRegister(strdup(identifierStack->stack[expressionArguments[0]].name), 1);
  		expressionArguments[0] = -2;
  	}
  	else memToRegister(mem, 1);
  	numFlag = 0;
  	  } 
  LT value{
	  	if(expressionArguments[0] == -2 && numFlag){
  			
  		if(registerValues[1] < atoll(identifierStack->stack[expressionArguments[1]].name))
  			setRegister(strdup("1"), 1);
  		else
  			setRegister(strdup("0"), 1);
  		
  		popIdentifier();
  		popIdentifier();
  	}
  	else if(numFlag){
  		long long int mem = getArgumentMem(1);
  		setRegister(strdup(identifierStack->stack[expressionArguments[1]].name), 2);

  		pushCommand3("JZERO", 2, (codeStack->top+16));
		pushCommand2("ZERO", 0);
		pushCommand2("STORE", 1);
		pushCommand2("INC", 0);
		pushCommand2("STORE", 2);
		pushCommand2("SUB", 1);
		pushCommand3("JZERO", 1, (codeStack->top+3));
		pushCommand2("ZERO", 1);
		pushCommand2("JUMP", (codeStack->top+9));
		pushCommand2("DEC", 0);
		pushCommand2("LOAD", 1);
		pushCommand2("SUB", 2);
		pushCommand3("JZERO", 2, (codeStack->top+4));
		pushCommand2("ZERO", 1);
		pushCommand2("INC", 1);
		pushCommand2("JUMP", (codeStack->top+2));
		pushCommand2("ZERO", 1);
		
		popIdentifier();	
  	}	
  	else{
  		  		long long int mem = getArgumentMem(1);
		memToRegister(mem, 2);
		
		pushCommand2("ZERO", 0);
		pushCommand2("STORE", 1);
		pushCommand2("INC", 0);
		pushCommand2("STORE", 2);
		pushCommand2("SUB", 1);
		pushCommand3("JZERO", 1, (codeStack->top+3));
		pushCommand2("ZERO", 1);
		pushCommand2("JUMP", (codeStack->top+9));
		pushCommand2("DEC", 0);
		pushCommand2("LOAD", 1);
		pushCommand2("SUB", 2);
		pushCommand3("JZERO", 2, (codeStack->top+4));
		pushCommand2("ZERO", 1);
		pushCommand2("INC", 1);
		pushCommand2("JUMP", (codeStack->top+2));
		pushCommand2("ZERO", 1);

  	}
  	registerValues[0] = -1;
	registerValues[1] = -1;
	registerValues[2] = -1;
  	expressionArguments[0] = -1;
	expressionArguments[1] = -1;
	numFlag = 0;
  }
| value{
	long long int mem = getArgumentMem(0);
  	if(numFlag){
  		setRegister(strdup(identifierStack->stack[expressionArguments[0]].name), 1);
  		expressionArguments[0] = -2;
  	}
  	else memToRegister(mem, 1);
  	numFlag = 0;
  	  } 
  GT value{
	  	if(expressionArguments[0] == -2 && numFlag){
  			
  		if(registerValues[1] > atoll(identifierStack->stack[expressionArguments[1]].name))
  			setRegister(strdup("1"), 1);
  		else
  			setRegister(strdup("0"), 1);
  		popIdentifier();
  		popIdentifier();
  	}
  	else if(numFlag){
  		long long int mem = getArgumentMem(1);
  		setRegister(strdup(identifierStack->stack[expressionArguments[1]].name), 2);

		pushCommand2("ZERO", 0);
		pushCommand2("INC", 0);
		pushCommand2("STORE", 2);
		pushCommand2("SUB", 1);
		pushCommand3("JZERO", 1, (codeStack->top+4));
		pushCommand2("ZERO", 1);
		pushCommand2("INC", 1);
		pushCommand2("JUMP", (codeStack->top+2));
		pushCommand2("ZERO", 1);
		
		popIdentifier();	
  	}	
  	else{
  		  		long long int mem = getArgumentMem(1);
		memToRegister(mem, 2);
		
		pushCommand2("ZERO", 0);
		pushCommand2("INC", 0);
		pushCommand2("STORE", 2);
		pushCommand2("SUB", 1);
		pushCommand3("JZERO", 1, (codeStack->top+4));
		pushCommand2("ZERO", 1);
		pushCommand2("INC", 1);
		pushCommand2("JUMP", (codeStack->top+2));
		pushCommand2("ZERO", 1);
  	}
  	registerValues[0] = -1;
	registerValues[1] = -1;
	registerValues[2] = -1;
  	expressionArguments[0] = -1;
	expressionArguments[1] = -1;
	numFlag = 0;
  }
| value{
	long long int mem = getArgumentMem(0);
  	if(numFlag){
  		setRegister(strdup(identifierStack->stack[expressionArguments[0]].name), 1);
  		expressionArguments[0] = -2;
  	}
  	else memToRegister(mem, 1);
  	numFlag = 0;
  	  } 
  LE value{
	  	if(expressionArguments[0] == -2 && numFlag){
  			
  		if(registerValues[1] <= atoll(identifierStack->stack[expressionArguments[1]].name))
  			setRegister(strdup("1"), 1);
  		else
  			setRegister(strdup("0"), 1);
  		
  		popIdentifier();
  		popIdentifier();
  	}
  	else if(numFlag){
  		long long int mem = getArgumentMem(1);
  		setRegister(strdup(identifierStack->stack[expressionArguments[1]].name), 2);

		pushCommand2("ZERO", 0);
		pushCommand2("INC", 0);
		pushCommand2("STORE", 2);
		pushCommand2("SUB", 1);
		pushCommand3("JZERO", 1, (codeStack->top+3));
		pushCommand2("ZERO", 1);
		pushCommand2("JUMP", (codeStack->top+3));
		pushCommand2("ZERO", 1);
		pushCommand2("INC", 1);
		
		popIdentifier();	
  	}	
  	else{
  		  		long long int mem = getArgumentMem(1);
  		
		memToRegister(mem, 2);
		
		pushCommand2("ZERO", 0);
		pushCommand2("INC", 0);
		pushCommand2("STORE", 2);
		pushCommand2("SUB", 1);
		pushCommand3("JZERO", 1, (codeStack->top+3));
		pushCommand2("ZERO", 1);
		pushCommand2("JUMP", (codeStack->top+3));
		pushCommand2("ZERO", 1);
		pushCommand2("INC", 1);

  	}
  	registerValues[0] = -1;
	registerValues[1] = -1;
	registerValues[2] = -1;
  	expressionArguments[0] = -1;
	expressionArguments[1] = -1;
	numFlag = 0;
  }
| value{
	long long int mem = getArgumentMem(0);
  	if(numFlag){
  		setRegister(strdup(identifierStack->stack[expressionArguments[0]].name), 1);
  		expressionArguments[0] = -2;
  	}
  	else memToRegister(mem, 1);
  	numFlag = 0;
  	  } 
  GE value{
	  	if(expressionArguments[0] == -2 && numFlag){
  			
  		if(registerValues[1] >= atoll(identifierStack->stack[expressionArguments[1]].name))
  			setRegister(strdup("1"), 1);
  		else
  			setRegister(strdup("0"), 1);
  		
  		popIdentifier();
  		popIdentifier();
  	}
  	else if(numFlag){
  		long long int mem = getArgumentMem(1);
  		setRegister(strdup(identifierStack->stack[expressionArguments[1]].name), 2);

  		pushCommand3("JZERO", 2, (codeStack->top+16));
		pushCommand2("ZERO", 0);
		pushCommand2("STORE", 1);
		pushCommand2("INC", 0);
		pushCommand2("STORE", 2);
		pushCommand2("SUB", 1);
		pushCommand3("JZERO", 1, (codeStack->top+4));
		pushCommand2("ZERO", 1);
		pushCommand2("INC", 1);
		pushCommand2("JUMP", (codeStack->top+9));
		pushCommand2("DEC", 0);
		pushCommand2("LOAD", 1);
		pushCommand2("SUB", 2);
		pushCommand3("JZERO", 2, (codeStack->top+3));
		pushCommand2("ZERO", 1);
		pushCommand2("JUMP", (codeStack->top+3));
		pushCommand2("ZERO", 1);
		pushCommand2("INC", 1);
		
		popIdentifier();	
  	}	
  	else{
  		  		long long int mem = getArgumentMem(1);
		memToRegister(mem, 2);
		
		pushCommand2("ZERO", 0);
		pushCommand2("STORE", 1);
		pushCommand2("INC", 0);
		pushCommand2("STORE", 2);
		pushCommand2("SUB", 1);
		pushCommand3("JZERO", 1, (codeStack->top+4));
		pushCommand2("ZERO", 1);
		pushCommand2("INC", 1);
		pushCommand2("JUMP", (codeStack->top+9));
		pushCommand2("DEC", 0);
		pushCommand2("LOAD", 1);
		pushCommand2("SUB", 2);
		pushCommand3("JZERO", 2, (codeStack->top+3));
		pushCommand2("ZERO", 1);
		pushCommand2("JUMP", (codeStack->top+3));
		pushCommand2("ZERO", 1);
		pushCommand2("INC", 1);

  	}
  	registerValues[0] = -1;
	registerValues[1] = -1;
	registerValues[2] = -1;
  	expressionArguments[0] = -1;
	expressionArguments[1] = -1;
	numFlag = 0;
  }
;
value:  NUM{
  	if(assignFlag){
  		printf("Błąd <linia %d>: Nie można przypisać do stałej!\n", yylineno);
       	exit(1);
  	}
  	Identifier s;
  	createIdentifier(&s, $1, 0, 0);
  	pushIdentifier(s);
  	numFlag = 1;
  	if (expressionArguments[0] == -1){
  		expressionArguments[0] = getIdentifierIndex($1);
  	}
  	else{
  		expressionArguments[1] = getIdentifierIndex($1);
  	}
 }
  
| identifier
;
identifier:  
PIDENTIFIER{
	if(getIdentifierIndex($1) == -1){
		printf("Błąd <linia %d>: Niezadeklarowana zmienna %s!\n", yylineno, $1);
       	exit(1);
	}
    if(identifierStack->stack[getIdentifierIndex($1)].array == 0){ 	
      	if(!assignFlag){
      		if(identifierStack->stack[getIdentifierIndex($1)].initialized == 0){
				printf("Błąd <linia %d>: Użycie niezainicjalizowanej zmiennej %s!\n", yylineno, $1);
       			exit(1);
			}
      		if (expressionArguments[0] == -1){
      			expressionArguments[0] = getIdentifierIndex($1);
      		}
      		else{
      			expressionArguments[1] = getIdentifierIndex($1);
      		}
      			
      	}
      	else {
      		assignTarget = getIdentifier($1);
      		identifierStack->stack[getIdentifierIndex($1)].initialized = 1;
      				}
    }
    else{
      printf("Błąd <linia %d>: Zmienna %s jest tablicą! Brak odwołania do elementu!\n", yylineno, $1);
      exit(1);
    }
    
  }
| PIDENTIFIER LQ PIDENTIFIER RQ {
	if(getIdentifierIndex($1) == -1){
		printf("Błąd <linia %d>: Niezadeklarowana zmienna %s!\n", yylineno, $1);
       	exit(1);
	}
	if(getIdentifierIndex($3) == -1){
		printf("Błąd <linia %d>: Niezadeklarowana zmienna %s!\n", yylineno, $3);
       	exit(1);
	}
    if(identifierStack->stack[getIdentifierIndex($1)].array > 0){
    	if(!assignFlag){
    		if(identifierStack->stack[getIdentifierIndex($1)].initialized == 0){
				printf("Błąd <linia %d>: Użycie niezainicjalizowanej zmiennej %s!\n", yylineno, $1);
       			exit(1);
			}
			if(identifierStack->stack[getIdentifierIndex($3)].initialized == 0){
				printf("Błąd <linia %d>: Użycie niezainicjalizowanej zmiennej %s!\n", yylineno, $3);
       			exit(1);
			}
	        if (expressionArguments[0] == -1){
	          	expressionArguments[0] = -3;
	          	identifierStack->stack[getIdentifierIndex($1)].shift = 0;
	          	long long int mem = getIdentifierMemory($1);
	          	char *str = (char *)malloc(100);
				      sprintf(str, "%lld", mem);
				      setRegister(str, 4);
				      mem = getIdentifierMemory($3);
				      sprintf(str, "%lld", mem);
				      setRegister(str, 0);
				      pushCommand2("ADD", 4);
				      registerValues[4] = -1;
				      pushCommand2("COPY", 4);
				      registerValues[0] = -1;
				      pushCommand2("LOAD", 4);
				      registerToMem(4, 6);
				      free(str);
	        }
	        else{
	          	expressionArguments[1] = -3;
	          	identifierStack->stack[getIdentifierIndex($1)].shift = 0;
	          	long long int mem = getIdentifierMemory($1);
	          	char *str = (char *)malloc(100);
				      sprintf(str, "%lld", mem);
				      setRegister(str, 4);
				      mem = getIdentifierMemory($3);
				      sprintf(str, "%lld", mem);
				      setRegister(str, 0);
				      pushCommand2("ADD", 4);
				      registerValues[4] = -1;
				      pushCommand2("COPY", 4);
				      registerValues[0] = -1;
				      pushCommand2("LOAD", 4);
				      registerToMem(4, 7);
				      free(str);
	        }
	        
	    }
	    else {
	    	identifierStack->stack[getIdentifierIndex($1)].initialized = 1;
	    	assignTarget = getIdentifier($1);
	      identifierStack->stack[getIdentifierIndex($1)].shift = 0;
	      arrayFlag = 1;
	      long long int mem = getIdentifierMemory($1);
	      char *str = (char *)malloc(100);
			  sprintf(str, "%lld", mem);
			   setRegister(str, 4);
			   mem = getIdentifierMemory($3);
			   sprintf(str, "%lld", mem);
			   setRegister(str, 0);
			   pushCommand2("ADD", 4);
         registerValues[4] = -1;
			   registerToMem(4, 5);
			   free(str);
	        	    }
    }
    else{
    	printf("Błąd <linia %d>: Zmienna %s nie jest tablicą! Nie można odwołać się do elementu!\n", yylineno, $1);
    	exit(1);
    }

  }
| PIDENTIFIER LQ NUM RQ {
	if(getIdentifierIndex($1) == -1){
		printf("Błąd <linia %d>: Niezadeklarowana zmienna %s!\n", yylineno, $1);
       	exit(1);
	}
	    if(identifierStack->stack[getIdentifierIndex($1)].array > 0){
    	if(identifierStack->stack[getIdentifierIndex($1)].array > atoll($3)){
    		if(!assignFlag){
    			if(identifierStack->stack[getIdentifierIndex($1)].initialized == 0){
					printf("Błąd <linia %d>: Użycie niezainicjalizowanej zmiennej %s!\n", yylineno, $1);
       				exit(1);
				}
	        	if (expressionArguments[0] == -1){
	          		expressionArguments[0] = getIdentifierIndex($1);
	          		identifierStack->stack[getIdentifierIndex($1)].shift = atoll($3);
	        	}
	        	else{
	          		expressionArguments[1] = getIdentifierIndex($1);
	          		identifierStack->stack[getIdentifierIndex($1)].shift = atoll($3);
	        	}
	        
	      	}
	      	else {
	      		assignShift = atoll($3);
	        	assignTarget = getIdentifier($1);
	        	identifierStack->stack[getIdentifierIndex($1)].shift = atoll($3);
	        	identifierStack->stack[getIdentifierIndex($1)].initialized = 1;
	        	}
    	}
    	else{
    		printf("Błąd <linia %d>: Próba odwołania się do elementu: %s, który znajduje się poza zasięgiem tablicy!\n", yylineno, $3);
      		exit(1);  
    	}
    }
    else{
      printf("Błąd <linia %d>: Zmienna %s nie jest tablicą! Nie można odwołać się do elementu!\n", yylineno, $1);
      exit(1);
    }
      	
  }
;
%%
void memToRegister(long long int mem, long long int reg){
	char *str = (char *)malloc(100);
	sprintf(str, "%lld", mem);
	setRegister(str, 0);
	free(str);
	pushCommand2("LOAD", reg);
	registerValues[reg] = -1;

    }

void registerToMem(long long int reg, long long int mem){
	char *str = (char *)malloc(100);
	sprintf(str, "%lld", mem);
	setRegister(str, 0);
	free(str);
	pushCommand2("STORE", reg);
	
	}

long long int getArgumentMem(long long int n){
	if(n == 0){
				if(expressionArguments[0] >= 0){
									return identifierStack->stack[expressionArguments[0]].mem + identifierStack->stack[expressionArguments[0]].shift;
		}
				return 6;
	}
	else if(n == 1){
				if(expressionArguments[1] >= 0){
									return identifierStack->stack[expressionArguments[1]].mem + identifierStack->stack[expressionArguments[1]].shift;
		}
				return 7;
	}
		return 0;
}

long long int getIdentifierIndex(char* IdentifierName){
	long long int i;
	for(i = 0; i < identifierStack->top; i++)
    	if(!strcmp(identifierStack->stack[i].name, IdentifierName)){
       		return i;
    	}
    	return -1;
}

void createIdentifier(Identifier *s, char* name, long long int isLocal, long long int isArray){
    s->shift = 0;
    s->name = name;
    s->mem = memCounter;
    s->initialized = 0;
    memCounter++;
    if(isLocal){
    	s->local = 1;
    }
    else{
    	s->local = 0;
    }
    if(isArray){
      s->array = isArray;
    }
    else{
      s->array = 0;
    }
}

void pushIdentifier(Identifier i){
	identifierStack->stack[identifierStack->top] = i;
	identifierStack->top++;
	}

Identifier popIdentifier(){
	identifierStack->top--;
	memCounter--;
	return identifierStack->stack[identifierStack->top + 1];
}

Identifier getIdentifier(char* IdentifierName){
	long long int i;
	for(i = 0; i < identifierStack->top; i++)
    	if(!strcmp(identifierStack->stack[i].name, IdentifierName))
    		return identifierStack->stack[i];
}

long long int getIdentifierMemory(char *IdentifierName){
	return identifierStack->stack[getIdentifierIndex(IdentifierName)].mem + identifierStack->stack[getIdentifierIndex(IdentifierName)].shift;
}

void pushCommand(char* str){
	char* temp = (char*)malloc(strlen(str)+1);
	strcpy(temp, str);
	codeStack->stack[codeStack->top] = temp;
	codeStack->top++;
}


void pushCommand2(char* str, long long int num){
	char* temp = (char*)malloc(strlen(str) + 5);
	sprintf(temp, "%s %lld", str, num);
	codeStack->stack[codeStack->top] = temp;
	codeStack->top++;
}

void nullifyRegister(long long int reg){
	if(registerValues[reg] != 0){
		pushCommand2("ZERO", reg);
		registerValues[reg] = 0;
	}
}

void pushCommand3(char* str, long long int num, long long int num2){
	char* temp = (char*)malloc(strlen(str) + 10);
	sprintf(temp, "%s %lld %lld", str, num, num2);
	codeStack->stack[codeStack->top] = temp;
	codeStack->top++;
}

void printCode(char* outFileName){
	FILE* fp = fopen(outFileName, "w");
	if(fp == NULL)
	{
		printf("Błąd: Nie  można otworzyć pliku %s!\n", outFileName);
		exit(2);
	}
	long long int i;
	for(i = 0; i < codeStack->top; i++)
        fprintf(fp, "%s\n", codeStack->stack[i]);
    
    fclose(fp);
}

void pushToJumpStack(long long int i){
	jumpStack->stack[jumpStack->top] = i;
	jumpStack->top++;
}

long long int popFromJumpStack(){
	jumpStack->top--;
	return jumpStack->stack[jumpStack->top + 1];
}

void pushToForStack(char* i){
  char* temp = (char*)malloc(strlen(i)+1);
  strcpy(temp, i);
  forStack->stack[forStack->top] = temp;
  forStack->top++;
}

char* popFromForStack(){
  forStack->top--;
  return forStack->stack[forStack->top];
}

long long int isPassed(char* name){
  for(long long int i = 0; i < forStack->passed_top; i++)
      if(!strcmp(forStack->passed[i], name)){
        return 1;
      }
  return 0;
}

void pushToPassedStack(char* i){
  char* temp = (char*)malloc(strlen(i)+1);
  strcpy(temp, i);
  forStack->passed[forStack->passed_top] = temp;
  forStack->passed_top++;
}

char* popFromPassedStack(){
  forStack->passed_top--;
  return forStack->passed[forStack->passed_top];
}
 
void setRegister(char* number, long long int reg){ 			
	if (atoll(number) == registerValues[reg]){
		return;
	}
    char *bin = decToBin(number);
	long long int limit = strlen(bin);
	long long int i;
    nullifyRegister(reg);
	for(i = 0; i < limit; ++i){
		if(bin[i] == '1'){
			pushCommand2("INC", reg);
			registerValues[reg]++;
		}
		if(i < (limit - 1)){
	        pushCommand2("SHL", reg);
	        registerValues[reg] *= 2;
		}
	}
    free(bin);
        }

void addInt(long long int command, long long int val){
	char **temp = &(codeStack->stack[command]);
	*temp = realloc(*temp, strlen(*temp) + 5);
	sprintf(*temp, "%s %lld", *temp, val);
	}

char *decToBin(char *dec){
    char digit, r, r_temp;
    long long int i, j, k;
    long long int dec_len = strlen(dec);
	
    char *out;
    char *bin = (char*)malloc(4*dec_len*sizeof(char)+1);
	if (!bin)
    return NULL;
    
	i = 0;
    k = 0;
    while (i < dec_len) 
    {
		r = 0;
		for (j = i; j < dec_len; ++j) 
		{
			digit = dec[j] - 48;
			r_temp = digit & 0x01;
			digit = digit / 2;
			if (r)
                digit += 5;
			dec[j] = digit + 48;
			r = r_temp;
		}
		bin[k++] = r + 48;
		if (dec[i]=='0')
            ++i;
    }
    bin[k] = '\0';
    
    out = malloc(k+1);
    if (!out) 
    {
		free(bin);
        return NULL;
    }
    
    for (i = 0; i < k; ++i)
    out[i] = bin[k-1-i];
    out[k] = '\0';
    free(bin);
    
    return out;
} 

void freeMem(){
	long long int i;
	free(identifierStack);
	for(i = 0; i < codeStack->top; i++) free(codeStack->stack[i]);
	free(codeStack);
	free(jumpStack);
	free(forStack);
}

void parser(long long int argv, char* argc[]){
	if(argv < 2){
		printf("Za mało argumentów!\n");
	}
	else{
		identifierStack = (IdentifierStack *)malloc(sizeof(IdentifierStack));
		identifierStack->top = 0;

		codeStack = (CodeStack*)malloc(sizeof(CodeStack));
		codeStack->top = 0;
		
		jumpStack = (JumpStack*)malloc(sizeof(JumpStack));
		jumpStack->top = 0;

    	forStack = (ForStack*)malloc(sizeof(ForStack));
    	forStack->top = 0;
    	forStack->passed_top = 0;

		assignFlag = 1;
		memCounter = 8;
		numFlag = 0;
		writeFlag = 0;
		arrayFlag = 0;

		yyparse();
	
    	printCode(argc[1]);
    
		freeMem();
	}
}

int main(long long int argv, char* argc[]){
	parser(argv, argc);
	return 0;
}

int yyerror(const char* str){
	printf("Błąd: %s w linii %d\n", str, yylineno);
	return 1;
}