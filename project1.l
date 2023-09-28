%{
/* C Declarations and includes*/
#define LIST     strcat(buf, yytext)
// #define token(t) {LIST; printf("<%s>\n", #t);}
// #define tokenInteger(t, i) {LIST; printf("<%s:%d>\n", #t, i);}
// #define tokenString(t, s) {LIST; printf("<%s:%s>\n", #t, s);}
#define token(t) {LIST;}
#define tokenInteger(t, i) {LIST;}
#define tokenString(t, s) {LIST;}
#define MAX_LINE_LENG 256

int linenum = 1;
char buf[MAX_LINE_LENG];
char str[MAX_LINE_LENG];

%}

/* <name> <regular expression> */

ASCII [ -~]
LETTER [a-zA-Z_]
DIGIT [0-9]
IDENTIFIER {LETTER}({LETTER}|{DIGIT})*
INTEGER (\-?[1-9]{DIGIT}*)|0
FLOAT_NUMBER (\-?{DIGIT}+\.{DIGIT}+)
STRING \"{ASCII}*\"
RANGE \.\.


NEWLINE \n
%option yylineno
COMMENT1 \{\%(.|\r|\n)*\%\}
COMMENT2 \%.*

%%


"."     {token('PERIOD'); return PERIOD;}
","     {token('COMMA'); return COMMA;}
":"     {token('COLON'); return COLON;}
";"     {token('SEMICOLON'); return SEMICOLON;}
"("     {token('L_PARENTHESES'); return L_PARENTHESES;}
")"     {token('R_PARENTHESES'); return R_PARENTHESES;}
"["     {token('L_SB'); return L_SB;}
"]"     {token('R_SB'); return R_SB;}
"{"     {token('L_CB'); return L_CB;}
"}"     {token('R_CB'); return R_CB;}


"+"         {token('PLUS'); return PLUS;}
"-"         {token('MINUS'); return MINUS;}
"*"         {token('MULTIPLICATION'); return MULTIPLICATION;}
"/"         {token('DIVISION'); return DIVISION;}
"mod"       {token('MOD'); return MOD;}
":="        {token('ASSIGN'); return ASSIGN;}
"<"         {token('LESS_THAN'); return LESS_THAN;}
"<="        {token('NO_MORE_THAN'); return NO_MORE_THAN;}
">="        {token('NO_LESS_THAN'); return NO_LESS_THAN;}
">"         {token('MORE_THAN'); return MORE_THAN;}
"="         {token('EQUAL'); return EQUAL;}
"not="      {token('NOT_EQUAL'); return NOT_EQUAL;}
"and"       {token('AND'); return AND;}
"or"        {token('OR'); return OR;}
"not"       {token('NOT'); return NOT;}

"array"         {token('ARRAY'); return ARRAY;}
"begin"         {token('bEGIN'); return bEGIN;}
"bool"          {token('BOOL'); return BOOL;}
"char"          {token('CHAR'); return CHAR;}
"const"         {token('CONST'); return CONST;}
"decreasing"    {token('DECREASING'); return DECREASING;}
"default"       {token('DEFAULT'); return DEFAULT;}
"do"            {token('DO'); return DO;}
"else"          {token('ELSE'); return ELSE;}
"end"           {token('END'); return END;}
"exit"          {token('EXIT'); return EXIT;}
"false"         {token('FALSE'); return FALSE;}
"float"			{token('FLOAT'); return FLOAT;}
"for"           {token('FOR'); return FOR;}
"function"      {token('FUNCTION'); return FUNCTION;}
"get"           {token('GET'); return GET;}
"if"            {token('IF'); return IF;}
"int"           {token('INT'); return INT;}
"loop"          {token('LOOP'); return LOOP;}
"of"            {token('OF'); return OF;}
"put"           {token('PUT'); return PUT;}
"procedure"     {token('PROCEDURE'); return PROCEDURE;}
"real"          {token('REAL'); return REAL;}
"result"        {token('RESULT'); return RESULT;}
"return"        {token('RETURN'); return RETURN;}
"skip"          {token('SKIP'); return SKIP;}
"string"        {token('STRING'); return STRING;}
"then"          {token('THEN'); return THEN;}
"true"          {token('TRUE'); return TRUE;}
"var"           {token('VAR'); return VAR;}
"when"          {token('WHEN'); return WHEN;}



{IDENTIFIER}	{yylval.stringVal = strdup(yytext); tokenString('id', yytext); return id;} 
{INTEGER}		{yylval.stringVal = strdup(yytext); tokenString('INTEGER', yytext); return INTEGER;}
{FLOAT_NUMBER}	{yylval.stringVal = strdup(yytext); tokenString('FLOAT_NUMBER', yytext); return FLOAT_NUMBER;}

{STRING}		{
					str[0] = '\0';
					for(int i = 1; i < yyleng - 1; i++)
					{
						char temp[1];
						temp[0] = yytext[i];
						if(yytext[i] == '"' && yytext[i + 1] == '"')
						{
							continue;
						}
						strcat(str, temp);
					}
					yylval.stringVal = strdup(str);
					tokenString("String", str);
					return String;
				}


{COMMENT1}		{
					for(int i = 0; i < yyleng; i++)
					{
						char temp[1];
						temp[0] = yytext[i];
						strcat(buf, temp);
						if(yytext[i] == '\n')
						{
							printf("%d: %s", linenum++, buf);
							buf[0] = '\0';
						}
					}
				}
{COMMENT2}		{LIST;}

{RANGE}		{token('RANGE'); return RANGE;}



{NEWLINE}	{
			LIST;
			//printf("%d: %s", linenum++, buf);
			buf[0] = '\0';
			}

[ \t]*  {LIST;}

.       {
        LIST;
        printf("%d:%s\n", linenum+1, buf);
        printf("bad characte:'%s'\n",yytext);
        exit(-1);
        }
%%


