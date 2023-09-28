// C declarations
%{
#define Trace(t)        printf("Trace: %s", t)
#include "symbols.hpp"

int address = 0;
int level = 0;
int nowTable = 0;
vector<int> returnTable;
vector<string> inputParameter;
string checkResult = ""; //檢查function裡面有沒有result (result是有回傳值的) checkResult = returnValue
bool checkReturn = false; //return沒有回傳值
bool inMain = false;    //檢查是否進入main
bool inFunction = false;    //檢查是否進入function
bool inCondition = false;   //檢查是否進入if else
int functionAddress = 0;    //在function裡面address要從0開始
int label = 0;	//label的數字(為了避免不重複)
bool inLoop = false;    //檢查是否在loop裡面(給exit用)
vector<int> beginStack; //儲存回到的label(loop)
vector<int> trueStack; 
vector<int> falseStack;
vector<int> exitStack;  //儲存exit的label

string fileName = "";   //開啟的檔案的名稱(ex: example.st → fileName = example)

ofstream output;

vector <vector <SymbolTable> > symbolTable;

extern int yylineno;
extern int yylex();
extern FILE *yyin;

void yyerror(string s)
{
    printf("\033[40;31mLine %d Error: \033[0m", yylineno);
    cout<<s<<endl;
    exit(1);
    // fprintf(stderr, "%s\n", s);
}

%}


// yacc declarations
/* tokens */

%union{ 
    char* stringVal;
    Data* dataVal;
}

%token PERIOD COMMA COLON SEMICOLON L_PARENTHESES R_PARENTHESES L_SB R_SB L_CB R_CB

%token PLUS MINUS MULTIPLICATION DIVISION MOD ASSIGN LESS_THAN NO_MORE_THAN NO_LESS_THAN MORE_THAN EQUAL NOT_EQUAL AND OR NOT

%token ARRAY bEGIN BOOL CHAR CONST DECREASING DEFAULT DO ELSE END EXIT FALSE FLOAT FOR FUNCTION GET IF INT LOOP OF PUT PROCEDURE REAL RESULT RETURN SKIP STRING THEN TRUE VAR WHEN
%token RANGE 

%token <stringVal> id
%token <stringVal> INTEGER
%token <stringVal> FLOAT_NUMBER
%token <stringVal> String


%type <stringVal> DATATYPE
%type <dataVal> CONSTANT_VAL  //判斷型態，回傳type
%type <dataVal> VARIABLE_VAL
%type <dataVal> EXPRESSION
%type <stringVal> ARRAY_INV
%type <dataVal> FUNCTION_INV


%left OR
%left AND
%left NOT
%left LESS_THAN NO_MORE_THAN EQUAL NO_LESS_THAN MORE_THAN NOT_EQUAL
%left PLUS MINUS
%left MULTIPLICATION DIVISION MOD
%nonassoc UMINUS
%left L_PARENTHESES R_PARENTHESES


%start program

%%
// Grammar rules
program:        constant_exp
        |       variable_exp
        |       array_exp
        |       function_dec
        |       procedure_dec
        |       statement
        ;


statement:      procedure_inv
        |       block
        |       simple
        |       conditional
        |       loop
        |       epsilon
        ;


constant_exp:   CONST id COLON DATATYPE ASSIGN CONSTANT_VAL 
                {
                    Trace("constant_exp\n");
                    string temp1 = $4, temp2 = $6->type;
                    if(temp1 != temp2)
                    {
                        if((temp1 == "real" || temp1 == "float") && (temp2 == "real" || temp2 == "float"))
                        {
                            //do nothing
                        }
                        else
                        {
                            yyerror("Constant expression datatype doesn't match.");
                        }
                    }
                    insert(level, $2, $4, $6->value, "-", true, address);
                    address++;
                }
                program
        |       CONST id ASSIGN CONSTANT_VAL 
                {
                    Trace("constant_exp\n");
                    insert(level, $2, $4->type, $4->value, "-", true, address);
                    address++;
                }
                program
        ;


variable_exp:   VAR id COLON DATATYPE ASSIGN CONSTANT_VAL 
                {
                    Trace("variable_exp\n");
                    string temp1 = $4, temp2 = $6->type;
                    if(temp1 != temp2)
                    {
                        if((temp1 == "real" || temp1 == "float") && (temp2 == "real" || temp2 == "float"))
                        {
                            //do nothing
                        }
                        else
                        {
                            yyerror("Variable expression datatype doesn't match.");
                        }
                    }
                    //如果是在function內，address要從0開始
                    if(inFunction == false)
                    {
                        insert(level, $2, $4, $6->value, "-", false, address);
                    }
                    else
                    {
                        insert(level, $2, $4, $6->value, "-", false, functionAddress);

                    }
                    
                    vector<int> index = lookup($2);
                    SymbolTable item = symbolTable[index[0]][index[1]];
                    

                    
                    if(inMain == false && nowTable == 0)    //global variable
                    {
                        if(temp1 == "int")
                        {
                            output<<"field static "<<$4<<" "<<$2<<" = "<<$6->value<<endl;
                        }
                        else if(temp1 == "float" || temp1 == "real")
                        {
                            output<<"field static double "<<$2<<" = "<<$6->value<<endl;
                        }
                        else if(temp1 == "boolean")
                        {
                            if($6->value != "0")
                            {
                                output<<"field static boolean "<<$2<<" = 1"<<endl;
                            }
                            else if($6->value == "0")
                            {
                                output<<"field static boolean "<<$2<<" = 0"<<endl;
                            }
                        }
                    }
                    // else if(inFunction == true && inMain == false)  //local variable in function(要用index，而不是address)
                    // {
                    //     if(temp1 == "int")
                    //     {
                    //         output<<"sipush "<<$6->value<<endl;
                    //         output<<"istore "<<item.index<<endl;
                    //     }
                    //     else if(temp1 == "float" || temp1 == "real")
                    //     {
                    //         output<<"ldc2_w "<<$6->value<<endl;
                    //         output<<"dstore "<<item.index<<endl;
                    //     }
                    //     else if(temp1 == "boolean")
                    //     {
                    //         if($6->value != "0")
                    //         {
                    //             output<<"iconst_1"<<endl;
                    //             output<<"istore "<<item.index<<endl;
                    //         }
                    //         else if($6->value == "0")
                    //         {
                    //             output<<"iconst_0"<<endl;
                    //             output<<"istore "<<item.index<<endl;
                    //         }
                    //     }
                    // }
                    else //if(inMain == true) //local variable in main
                    {
                        if(temp1 == "int")
                        {
                            output<<"sipush "<<$6->value<<endl;
                            output<<"istore "<<item.address<<endl;
                        }
                        else if(temp1 == "float" || temp1 == "real")
                        {
                            output<<"ldc2_w "<<$6->value<<endl;
                            output<<"dstore "<<item.address<<endl;
                        }
                        else if(temp1 == "boolean")
                        {
                            if($6->value != "0")
                            {
                                output<<"iconst_1"<<endl;
                                output<<"istore "<<item.address<<endl;
                            }
                            else if($6->value == "0")
                            {
                                output<<"iconst_0"<<endl;
                                output<<"istore "<<item.address<<endl;
                            }
                        }
                    }
                    
                    //如果是在function內，address要從0開始
                    if(inFunction == false)
                    {
                        address++;
                    }
                    else
                    {
                        functionAddress++;
                    }

                    

                }
                program
        |       VAR id COLON DATATYPE 
                {
                    Trace("variable_exp\n");
                    //如果是在function內，address要從0開始
                    if(inFunction == false)
                    {
                        insert(level, $2, $4, "-", "-", false, address);
                    }
                    else
                    {
                        insert(level, $2, $4, "-", "-", false, functionAddress);
                    }
                    string temp1 = $4;
                    if(inMain == false && nowTable == 0)    //global variable
                    {
                        if(temp1 == "int")
                        {
                            output<<"field static "<<$4<<" "<<$2<<endl;
                        }
                        else if(temp1 == "float" || temp1 == "real")
                        {
                            output<<"field static double "<<$2<<endl;
                        }
                        else if(temp1 == "boolean")
                        {
                            output<<"field static boolean "<<$2<<endl;
                        }
                    }
                    else if(inFunction == true && inMain == false)  //local variable in function
                    {
                        //想不到要尬麻
                    }
                    else if(inMain == true) //local variable in main
                    {
                        //想不到要尬麻
                    }
                    

                    //如果是在function內，address要從0開始
                    if(inFunction == false)
                    {
                        address++;
                    }
                    else
                    {
                        functionAddress++;
                    }
                }
                program
        |       VAR id ASSIGN CONSTANT_VAL 
                {
                    Trace("variable_exp\n");
                    insert(level, $2, $4->type, $4->value, "-", false, address);
                    vector<int> index = lookup($2);
                    SymbolTable item = symbolTable[index[0]][index[1]];
                    string temp1 = $4->type;
                    if(inMain == false && nowTable == 0)    //global variable
                    {
                        if(temp1 == "int")
                        {
                            output<<"field static "<<$4->type<<" "<<$2<<" = "<<$4->value<<endl;
                        }
                        else if(temp1 == "float" || temp1 == "real")
                        {
                            output<<"field static double "<<$2<<" = "<<$4->value<<endl;
                        }
                        else if(temp1 == "boolean")
                        {
                            if($4->value != "0")
                            {
                                output<<"field static boolean "<<$2<<" = 1"<<endl;
                            }
                            else if($4->value == "0")
                            {
                                output<<"field static boolean "<<$2<<" = 0"<<endl;
                            }
                        }
                    }
                    // else if(inFunction == true && inMain == false)  //local variable in function
                    // {
                    //     if(temp1 == "int")
                    //     {
                    //         output<<"sipush "<<$4->value<<endl;
                    //         output<<"istore "<<item.index<<endl;
                    //     }
                    //     else if(temp1 == "float" || temp1 == "real")
                    //     {
                    //         output<<"ldc2_w "<<$4->value<<endl;
                    //         output<<"dstore "<<item.index<<endl;
                    //     }
                    //     else if(temp1 == "boolean")
                    //     {
                    //         if($4->value != "0")
                    //         {
                    //             output<<"iconst_1"<<endl;
                    //             output<<"istore "<<item.index<<endl;
                    //         }
                    //         else if($4->value == "0")
                    //         {
                    //             output<<"iconst_0"<<endl;
                    //             output<<"istore "<<item.index<<endl;
                    //         }
                    //     }
                    // }
                    else //if(inMain == true) //local variable in main
                    {
                        if(temp1 == "int")
                        {
                            output<<"sipush "<<$4->value<<endl;
                            output<<"istore "<<item.address<<endl;
                        }
                        else if(temp1 == "float" || temp1 == "real")
                        {
                            output<<"ldc2_w "<<$4->value<<endl;
                            output<<"dstore "<<item.address<<endl;
                        }
                        else if(temp1 == "boolean")
                        {
                            if($4->value != "0")
                            {
                                output<<"iconst_1"<<endl;
                                output<<"istore "<<item.address<<endl;
                            }
                            else if($4->value == "0")
                            {
                                output<<"iconst_0"<<endl;
                                output<<"istore "<<item.address<<endl;
                            }
                        }
                    }

                    //如果是在function內，address要從0開始
                    if(inFunction == false)
                    {
                        address++;
                    }
                    else
                    {
                        functionAddress++;
                    }

                }
                program
        ;


//空字串
epsilon:        {
                    if(inMain == false && inFunction == false)
                    {
                        output<<"method public static void main (java.lang.String[])"<<endl;
                        output<<"max_stack 20"<<endl;
                        output<<"max_locals 20"<<endl;
                        output<<"{"<<endl;

                        inMain = true;
                    }
                }
        ;



DATATYPE:       BOOL {$$ = strdup("boolean");}
        |       REAL {$$ = strdup("real");}
        |       FLOAT {$$ = strdup("float");}
        |       INT {$$ = strdup("int");}
        |       STRING {$$ = strdup("string");}
        ;


//回傳讀到的constant型態
CONSTANT_VAL:   INTEGER
                {
                    Data* data = new Data();
                    data->type = "int";
                    data->value = $1;
                    $$ = data;
                }
        |       FLOAT_NUMBER 
                {
                    Data* data = new Data();
                    data->type = "float";
                    data->value = $1;
                    $$ = data;
                }
        |       String 
                {
                    Data* data = new Data();
                    data->type = "string";
                    data->value = $1;
                    $$ = data;
                }
        |       TRUE
                {
                    Data* data = new Data();
                    data->type = "boolean";
                    data->value = "1";
                    $$ = data;
                }
        |       FALSE
                {
                    Data* data = new Data();
                    data->type = "boolean";
                    data->value = "0";
                    $$ = data;
                }
        |       id
                {
                    vector<int> index = lookup($1);
                    if(index.size() == 0)
                    {
                        cout<<"id: "<<$1<<endl;
                        yyerror("id not found");
                    }
                    
                    SymbolTable item = symbolTable[index[0]][index[1]];
                    string type;
                    //檢查是否是const
                    if(item.constant == false)
                    {
                        yyerror("This id is not a constant");
                    }
                    type = item.type;


                    // if(item.type == "int")
                    // {
                    //     output<<"sipush "<<item.value<<endl;
                    // }
                    // else if(item.type == "float" || item.type == "real")
                    // {
                    //     output<<"ldc2_w "<<item.value<<endl;
                    // }
                    // else if(item.type == "boolean")
                    // {
                    //     if(item.value != "0")
                    //     {
                    //         output<<"iconst_1"<<endl;
                    //     }
                    //     else if(item.value == "0")
                    //     {
                    //         output<<"iconst_0"<<endl;
                    //     }
                    // }
                    // else if(item.type == "string")
                    // {
                    //     output<<"ldc \""<<item.value<<"\""<<endl;
                    // }
                    
                    Data* data = new Data();
                    data->type = item.type;
                    data->value = item.value;
                    $$ = data;


                }
        ;

//回傳value
VARIABLE_VAL:   INTEGER 
                {
                    if(inMain == false && inFunction == false)
                    {
                        output<<"method public static void main (java.lang.String[])"<<endl;
                        output<<"max_stack 20"<<endl;
                        output<<"max_locals 20"<<endl;
                        output<<"{"<<endl;
                        inMain = true;
                    }

                    output<<"sipush "<<$1<<endl;
                    Data* data = new Data();
                    data->type = "int";
                    data->value = $1;
                    $$ = data;
                }
        |       FLOAT_NUMBER 
                {
                    if(inMain == false && inFunction == false)
                    {
                        output<<"method public static void main (java.lang.String[])"<<endl;
                        output<<"max_stack 20"<<endl;
                        output<<"max_locals 20"<<endl;
                        output<<"{"<<endl;
                        inMain = true;
                    }

                    output<<"ldc2_w "<<$1<<endl;
                    Data* data = new Data();
                    data->type = "float";
                    data->value = $1;
                    $$ = data;
                }
        |       String 
                {
                    if(inMain == false && inFunction == false)
                    {
                        output<<"method public static void main (java.lang.String[])"<<endl;
                        output<<"max_stack 20"<<endl;
                        output<<"max_locals 20"<<endl;
                        output<<"{"<<endl;
                        inMain = true;
                    }

                    output<<"ldc "<<"\""<<$1<<"\""<<endl;
                    Data* data = new Data();
                    data->type = "string";
                    data->value = $1;
                    $$ = data;
                }
        |       TRUE   
                {
                    if(inMain == false && inFunction == false)
                    {
                        output<<"method public static void main (java.lang.String[])"<<endl;
                        output<<"max_stack 20"<<endl;
                        output<<"max_locals 20"<<endl;
                        output<<"{"<<endl;
                        inMain = true;
                    }

                    output<<"iconst_1"<<endl;
                    Data* data = new Data();
                    data->type = "boolean";
                    data->value = "1";
                    $$ = data;
                }
        |       FALSE 
                {
                    if(inMain == false && inFunction == false)
                    {
                        output<<"method public static void main (java.lang.String[])"<<endl;
                        output<<"max_stack 20"<<endl;
                        output<<"max_locals 20"<<endl;
                        output<<"{"<<endl;
                        inMain = true;
                    }

                    output<<"iconst_0"<<endl;
                    Data* data = new Data();
                    data->type = "boolean";
                    data->value = "0";
                    $$ = data;
                }
        |       id
                {
                    if(inMain == false && inFunction == false)
                    {
                        output<<"method public static void main (java.lang.String[])"<<endl;
                        output<<"max_stack 20"<<endl;
                        output<<"max_locals 20"<<endl;
                        output<<"{"<<endl;
                        inMain = true;
                    }

                    vector<int> index = lookup($1);
                    if(index.size() == 0)
                    {
                        cout<<"id: "<<$1<<endl;
                        yyerror("id not found");
                    }
                    
                    SymbolTable item = symbolTable[index[0]][index[1]];
                    string type;
                    if(item.type == "int" || item.type == "float" || item.type == "real" || item.type == "boolean" || item.type == "string")
                    {
                        Data* data = new Data();
                        data->type = item.type;
                        data->value = item.value;
                        $$ = data;
                    }
                    else if(item.type == "array")
                    {
                        Data* data = new Data();
                        data->type = item.returnType;
                        data->value = "-";
                        $$ = data;
                    }
                    else
                    {
                        yyerror("id uses error");
                    }

                    //拿constant variable的值
                    if(item.constant == true)
                    {
                        if(item.type == "int")
                        {
                            output<<"sipush "<<item.value<<endl;
                        }
                        else if(item.type == "float" || item.type == "real")
                        {
                            output<<"ldc2_w "<<item.value<<endl;
                        }
                        else if(item.type == "boolean")
                        {
                            if(item.value == "1")
                            {
                                output<<"iconst_1"<<endl;
                            }
                            else if(item.value == "0")
                            {
                                output<<"iconst_0"<<endl;
                            }
                        }
                    }
                    else
                    {
                        if(index[0] == 0)   //Global variable
                        {
                            if(item.type == "int")
                            {
                                output<<"getstatic int "<<fileName<<"."<<item.name<<endl;
                            }
                            else if(item.type == "float" || item.type == "real")
                            {
                                output<<"getstatic double "<<fileName<<"."<<item.name<<endl;
                            }
                            else if(item.type == "boolean")
                            {
                                output<<"getstatic boolean "<<fileName<<"."<<item.name<<endl;
                            }
                        }
                        // else if(inFunction == true) //local variable in function
                        // {
                        //     if(item.type == "int" || item.type == "boolean")
                        //     {
                        //         output<<"iload "<<item.index<<endl;
                        //     }
                        //     else if(item.type == "float" || item.type == "real")
                        //     {
                        //         output<<"dload "<<item.index<<endl;
                        //     }
                        // }
                        else    //local variable in main
                        {
                            if(item.type == "int" || item.type == "boolean")
                            {
                                output<<"iload "<<item.address<<endl;
                            }
                            else if(item.type == "float" || item.type == "real")
                            {
                                output<<"dload "<<item.address<<endl;
                            }
                        }
                    }
                    

                }
        ;


array_exp:      //VAR id COLON ARRAY RANGE1 OF DATATYPE 
                /* {
                    Trace("array_exp\n");
                    insert(level, $2, "array", "-", $7, false, address);
                    address++;
                }
                program */
               VAR id COLON ARRAY EXPRESSION RANGE EXPRESSION OF DATATYPE
                {
                    Trace("array_exp\n");
                    if($5->type != "int" || $7->type != "int")
                    {
                        yyerror("Range of array is not a integer number");
                    }

                    //如果是在function內，address要從0開始
                    if(inFunction == false)
                    {
                        insert(level, $2, "array", "-", $9, false, address);
                        address++;
                    }
                    else
                    {
                        insert(level, $2, "array", "-", $9, false, functionAddress);
                        functionAddress++;
                    }

                }
                program
        ;

//array invocation: Array[integer]
ARRAY_INV:      id L_SB EXPRESSION R_SB
                {
                    Trace("ARRAY_INV\n");
                    vector<int> index = lookup($1);
                    if(index.size() == 0)
                    {
                        yyerror("Array name not found");
                    }

                    if(symbolTable[index[0]][index[1]].type != "array")
                    {
                        yyerror("The type is not array");
                    }
                    
                    string expType = $3->type;
                    if(expType != "int")
                    {
                        yyerror("Array index not a integer");
                    }

                    string returnType = symbolTable[index[0]][index[1]].returnType;
                    $$ = strdup(returnType.data());
                }
        ;

//function declaration
function_dec:   FUNCTION id 
                {
                    Trace("function_dec\n");
                    insert(level, $2, "function", "-", "-", false, address);
                    address++;
                    level++;
                    returnTable.push_back(nowTable);
                    addScope();
                    nowTable = symbolTable.size() - 1;
                    inputParameter.clear();
                    checkResult = "";
                    checkReturn = false;
                    inFunction = true;
                    functionAddress = 0;

                }
                L_PARENTHESES formal_arg R_PARENTHESES COLON DATATYPE 
                {
                    vector<int> index = lookup($2);
                    symbolTable[index[0]][index[1]].returnType = $8;//填上function的returnType
                    symbolTable[index[0]][index[1]].parameter = inputParameter; //填上function的參數型態

                    output<<"method public static "<<$8<<" "<<$2<<"(";
                    if(inputParameter.size() == 0)
                    {
                        output<<")"<<endl;
                    }
                    else
                    {
                        for(int i = 0; i < inputParameter.size(); i++)  //輸出參數
                        {
                            if(i == inputParameter.size() - 1)
                            {
                                output<<inputParameter[i]<<")"<<endl;
                            }
                            else
                            {
                                output<<inputParameter[i]<<", ";
                            }
                        }
                    }
                    
                    output<<"max_stack 20"<<endl;
                    output<<"max_locals 20"<<endl;
                    output<<"{"<<endl;

                }
                inBlock END id 
                {
                    
                    string temp1 = $2, temp2 = $12;
                    if(temp1 != temp2)
                    {
                        yyerror("Function Name Error");
                    }
                    //檢查function是否有result
                    if(checkReturn == true)
                    {
                        yyerror("Function can't Return without value");
                    }
                    if(checkResult == "")
                    {
                        yyerror("Function has no Result");
                    }
                    //檢查result的type跟宣告的是否相同
                    string decType = $8;
                    if(checkResult != decType)
                    {
                        yyerror("Result type doesn't match the declaration");
                    }
                    inFunction = false;
                    output<<"nop"<<endl;
                    output<<"}"<<endl;

                    dump();
                }    
                program
        ;

//procedure declaration
procedure_dec:  PROCEDURE id 
                {
                    Trace("procedure_dec\n");
                    insert(level, $2, "procedure", "-", "-", false, address);
                    address++;
                    level++;
                    returnTable.push_back(nowTable);
                    addScope();
                    nowTable = symbolTable.size() - 1;
                    inputParameter.clear();
                    checkResult = "";
                    checkReturn = false;
                    inFunction = true;
                    functionAddress = 0;
                }
                L_PARENTHESES formal_arg R_PARENTHESES 
                {
                    vector<int> index = lookup($2);
                    symbolTable[index[0]][index[1]].parameter = inputParameter; //填上procedure參數型態
                    
                    output<<"method public static void "<<$2<<"(";
                    if(inputParameter.size() == 0)
                    {
                        output<<")"<<endl;
                    }
                    else
                    {
                        for(int i = 0; i < inputParameter.size(); i++)  //輸出參數
                        {
                            if(i == inputParameter.size() - 1)
                            {
                                output<<inputParameter[i]<<")"<<endl;
                            }
                            else
                            {
                                output<<inputParameter[i]<<", ";
                            }
                        }
                    }
                    output<<"max_stack 20"<<endl;
                    output<<"max_locals 20"<<endl;
                    output<<"{"<<endl;

                }
                inBlock END id
                {
                    string temp1 = $2, temp2 = $10;
                    if(temp1 != temp2)
                    {
                        yyerror("Procedure Name Error");
                    }
                    //檢查procedure是否有result
                    if(checkResult != "")
                    {
                        yyerror("Procedure can't result with value");
                    }
                    if(checkReturn == false)
                    {
                        yyerror("Procedure has no Return");
                    }
                    
                    
                    inFunction = false;
                    output<<"nop"<<endl;
                    output<<"}"<<endl;
                    dump();
                }
                program
        ;


//formal argument: function or procedure的參數
formal_arg      :id COLON DATATYPE COMMA 
                {
                    Trace("formal_arg\n");
                    insert(level, $1, $3, "-", "-", false, functionAddress);
                    functionAddress++;
                    inputParameter.push_back($3);
                }
                formal_arg
        |       id COLON DATATYPE
                {
                    Trace("formal_arg\n");
                    insert(level, $1, $3, "-", "-", false, functionAddress);
                    functionAddress++;
                    inputParameter.push_back($3);
                }
        |       epsilon
        ;

//function invocation
FUNCTION_INV:   id 
                {
                    Trace("FUNCTION_INV\n");
                    vector<int> index = lookup($1);
                    if(index.size() == 0)
                    {
                        yyerror("Function name not found");
                    }
                    inputParameter.clear();
                }
                L_PARENTHESES function_arg R_PARENTHESES
                {
                    Data* data = new Data();

                    vector<int> index = lookup($1);
                    if(inputParameter.size() != symbolTable[index[0]][index[1]].parameter.size())
                    {
                        cout<<"NUMBER: "<<inputParameter.size()<<" "<<symbolTable[index[0]][index[1]].parameter.size()<<endl;
                        yyerror("Parameter number incorrect");
                    }
                    for(int i = 0; i < symbolTable[index[0]][index[1]].parameter.size(); i++)
                    {
                        if(inputParameter[i] != symbolTable[index[0]][index[1]].parameter[i])
                        {
                            yyerror("Parameter type incorrect");
                        }
                    }

                    data->type = symbolTable[index[0]][index[1]].returnType;
                    $$ = data;

                    output<<"invokestatic "<<data->type<<" "<<fileName<<"."<<$1<<"(";
                    if(inputParameter.size() == 0)
                    {
                        output<<")"<<endl;
                    }
                    else
                    {
                        for(int i = 0; i < inputParameter.size(); i++)
                        {
                            if(i == inputParameter.size() - 1)
                            {
                                output<<inputParameter[i]<<")"<<endl;;
                            }
                            else
                            {
                                output<<inputParameter[i]<<", ";
                            }
                        }
                    }
                    

                } 
        ;

//function argument: call function時會傳入的參數
function_arg:   EXPRESSION COMMA 
                {
                    inputParameter.push_back($1->type);
                    
                }
                function_arg
        |       EXPRESSION
                {
                    inputParameter.push_back($1->type);
                }
        |       epsilon
        ;


//procedure invocation
procedure_inv:  id 
                {
                    if(inMain == false && inFunction == false)
                    {
                        output<<"method public static void main (java.lang.String[])"<<endl;
                        output<<"max_stack 20"<<endl;
                        output<<"max_locals 20"<<endl;
                        output<<"{"<<endl;
                        inMain = true;
                    }

                    Trace("procedure_inv\n");
                    vector<int> index = lookup($1);
                    if(index.size() == 0)
                    {
                        yyerror("Procedure name not found");
                    }
                    //function不能直接用，前面要put function()之類的
                    if(symbolTable[index[0]][index[1]].type == "function")
                    {
                        yyerror("Function can't be invocated directed.");
                    }
                    inputParameter.clear();
                }
                L_PARENTHESES function_arg R_PARENTHESES
                {
                    vector<int> index = lookup($1);
                    Data* data = new Data();
                    if(inputParameter.size() != symbolTable[index[0]][index[1]].parameter.size())
                    {
                        yyerror("Parameter number incorrect");
                    }
                    for(int i = 0; i < symbolTable[index[0]][index[1]].parameter.size(); i++)
                    {
                        if(inputParameter[i] != symbolTable[index[0]][index[1]].parameter[i])
                        {
                            yyerror("Parameter type incorrect");
                        }
                    }

                    output<<"invokestatic void "<<fileName<<"."<<$1<<"(";
                    if(inputParameter.size() == 0)
                    {
                        output<<")"<<endl;
                    }
                    else
                    {
                        for(int i = 0; i < inputParameter.size(); i++)
                        {
                            if(i == inputParameter.size() - 1)
                            {
                                output<<inputParameter[i]<<")"<<endl;;
                            }
                            else
                            {
                                output<<inputParameter[i]<<", ";
                            }
                        }
                    }
                } 
                statement
        ;


block:          bEGIN 
                {
                    if(inMain == false && inFunction == false)
                    {
                        output<<"method public static void main (java.lang.String[])"<<endl;
                        output<<"max_stack 20"<<endl;
                        output<<"max_locals 20"<<endl;
                        output<<"{"<<endl;
                        inMain = true;
                    }
                    
                    Trace("block\n");
                    level++;
                    returnTable.push_back(nowTable);
                    addScope();
                    nowTable = symbolTable.size() - 1;
                }
                inBlock END
                {
                    dump();
                } 
                program
        ;

inBlock:        variable_exp
        |       constant_exp
        |       array_exp
        |       statement
        ;


simple:         id ASSIGN 
                {
                    if(inMain == false && inFunction == false)
                    {
                        output<<"method public static void main (java.lang.String[])"<<endl;
                        output<<"max_stack 20"<<endl;
                        output<<"max_locals 20"<<endl;
                        output<<"{"<<endl;
                        inMain = true;
                    }
                    
                    Trace("simple ASSIGN\n");
                }
                EXPRESSION
                {
                    vector<int> index = lookup($1);
                    string expType = $4->type;
                    if(index.size() == 0)
                    {
                        yyerror("id not found ( id := Expression )");
                    }
                    SymbolTable item = symbolTable[index[0]][index[1]];

                    //const 不能修改
                    if(item.constant == true)
                    {
                        yyerror("Constant type can't be assigned.");
                    }
                    //function、procedure不能修改
                    if(item.type == "function")
                    {
                        yyerror("Function can't be assigned.");
                    }
                    if(item.type == "procedure")
                    {
                        yyerror("Procedure can't be assigned");
                    }


                    //int := int
                    if(item.type == "int" && expType != "int")
                    {
                        cout<<"TYPE: "<<item.type<<" "<<expType<<endl;
                        yyerror("Assign type error( int := notInt )");
                    }
                    else if(item.type == "float" || item.type == "real")    //float := float
                    {
                        if (expType != "float" && expType != "real")
                        {
                            yyerror("Assign type error( float or real := notFloat )");
                        }
                    }
                    else if(item.type == "boolean" && expType != "boolean")  //bool := bool
                    {
                        yyerror("Assign type error( Bool := notBool )");
                    }
                    else if(item.type == "string" && expType != "string") //string := string
                    {
                        yyerror("Assign type error( String := notString )");
                    }
                    else if(item.type == "array") //array assign
                    {
                        //int
                        if(item.returnType == "int" && expType != "int")
                        {
                            yyerror("Assign type error( int := notInt )");
                        }
                        else if(item.returnType == "float" || item.returnType == "real") //float or real
                        {
                            if (expType != "float" && expType != "real")
                            {
                                yyerror("Assign type error( float or real := notReal )");
                            }
                        }
                        else if(item.returnType == "boolean" && expType != "boolean") //bool
                        {
                            yyerror("Assign type error( Bool := notBool )");
                        }
                        else if(item.returnType == "string" && expType != "string")   //string
                        {
                            yyerror("Assign type error( String := notString )");
                        }
                        else
                        {
                            yyerror("Assign type error( unknown type )");
                        }
                    }

					if(index[0] == 0)	//global variable
					{
						output<<"putstatic "<<item.type<<" "<<fileName<<"."<<item.name<<endl;
					}
					else	//local variable
					{
                        // if(inFunction == true)  //在function裡面要用自己table的index
                        // {
                        //     output<<"istore "<<item.index<<endl;
                        // }
                        // else
                        // {
                        //     output<<"istore "<<item.address<<endl;
                        // }
						output<<"istore "<<item.address<<endl;
					}
                }
                inBlock
        |       PUT 
                {
                    Trace("PUT\n");
                    if(inMain == false && inFunction == false)
                    {
                        output<<"method public static void main (java.lang.String[])"<<endl;
                        output<<"max_stack 20"<<endl;
                        output<<"max_locals 20"<<endl;
                        output<<"{"<<endl;
                        inMain = true;
                    }
                    
                    output<<"getstatic java.io.PrintStream java.lang.System.out"<<endl;
                }
                EXPRESSION
                {
                    string type = $3->type;
                    if(type == "-")
                    {
                        yyerror("put nothing");
                    }

                    if(type == "string")
                    {
                        output<<"invokevirtual void java.io.PrintStream.println(java.lang.String)"<<endl;
                    }
                    else if(type == "int")
                    {
                        output<<"invokevirtual void java.io.PrintStream.println(int)"<<endl;
                    }
                    else if(type == "float" || type == "real")
                    {
                        output<<"invokevirtual void java.io.PrintStream.println(double)"<<endl;
                    }
					else if(type == "boolean")
					{
						output<<"invokevirtual void java.io.PrintStream.println(boolean)"<<endl;
					}

                }
                inBlock
        |       GET id 
                {
                    if(inMain == false && inFunction == false)
                    {
                        output<<"method public static void main (java.lang.String[])"<<endl;
                        output<<"max_stack 20"<<endl;
                        output<<"max_locals 20"<<endl;
                        output<<"{"<<endl;
                        inMain = true;
                    }
                    
                    Trace("GET\n");
                }
                inBlock
        |       RESULT EXPRESSION 
                {
                    if(inMain == false && inFunction == false)
                    {
                        output<<"method public static void main (java.lang.String[])"<<endl;
                        output<<"max_stack 20"<<endl;
                        output<<"max_locals 20"<<endl;
                        output<<"{"<<endl;
                        inMain = true;
                    }
                    
                    Trace("RESULT\n");
                    checkResult = $2->type;

                    output<<"ireturn"<<endl;
                }
                inBlock
        |       RETURN 
                {
                    if(inMain == false && inFunction == false)
                    {
                        output<<"method public static void main (java.lang.String[])"<<endl;
                        output<<"max_stack 20"<<endl;
                        output<<"max_locals 20"<<endl;
                        output<<"{"<<endl;
                        inMain = true;
                    }
                    
                    Trace("RETURN\n");
                    checkReturn = true;

                    output<<"return"<<endl;
                }
                inBlock
        |       RETURN EXPRESSION
                {
                    if(inMain == false && inFunction == false)
                    {
                        output<<"method public static void main (java.lang.String[])"<<endl;
                        output<<"max_stack 20"<<endl;
                        output<<"max_locals 20"<<endl;
                        output<<"{"<<endl;
                        inMain = true;
                    }
                    
                    yyerror("Can't Return with value");
                }
                inBlock                
        |       EXIT 
                {
                    if(inMain == false && inFunction == false)
                    {
                        output<<"method public static void main (java.lang.String[])"<<endl;
                        output<<"max_stack 20"<<endl;
                        output<<"max_locals 20"<<endl;
                        output<<"{"<<endl;
                        inMain = true;
                    }
                    
                    Trace("EXIT\n");
                    
                    if(inLoop == false)
                    {
                        yyerror("Exit when not in loop");
                    }

                    output<<"goto L"<<label<<endl;    //goto Lexit

                }
                inBlock
        |       EXIT WHEN EXPRESSION
                {
                    if(inMain == false && inFunction == false)
                    {
                        output<<"method public static void main (java.lang.String[])"<<endl;
                        output<<"max_stack 20"<<endl;
                        output<<"max_locals 20"<<endl;
                        output<<"{"<<endl;
                        inMain = true;
                    }

                    Trace("EXIT WHEN\n");
                    string expType = $3->type;
                    if(expType != "boolean")
                    {
                        yyerror("Exit when condition is not a bool_expression");
                    }
                    //檢查是否在loop裡面
                    if(inLoop == false)
                    {
                        yyerror("Exit when no Loop");
                    }
                }
                inBlock
        |       SKIP 
                {
                    if(inMain == false && inFunction == false)
                    {
                        output<<"method public static void main (java.lang.String[])"<<endl;
                        output<<"max_stack 20"<<endl;
                        output<<"max_locals 20"<<endl;
                        output<<"{"<<endl;
                        inMain = true;
                    }

                    Trace("SKIP\n");

					output<<"getstatic java.io.PrintStream java.lang.System.out"<<endl;
					output<<"invokevirtual void java.io.PrintStream.println()"<<endl;
                }
                inBlock
        ;



EXPRESSION:     VARIABLE_VAL
                {
                    if(inMain == false && inFunction == false)
                    {
                        output<<"method public static void main (java.lang.String[])"<<endl;
                        output<<"max_stack 20"<<endl;
                        output<<"max_locals 20"<<endl;
                        output<<"{"<<endl;
                        inMain = true;
                    }

                    Trace("EXPRESSION VARIABLE_VAL\n");
                    Data* data = new Data();
                    data->type = $1->type;
                    data->value = $1->value;
                    $$ = data;
                }
        |       ARRAY_INV
                {
                    if(inMain == false && inFunction == false)
                    {
                        output<<"method public static void main (java.lang.String[])"<<endl;
                        output<<"max_stack 20"<<endl;
                        output<<"max_locals 20"<<endl;
                        output<<"{"<<endl;
                        inMain = true;
                    }

                    Trace("EXPRESSION ARRAY_INV\n");
                    Data* data = new Data();
                    data->type = $1;
                    data->value = "-";
                    $$ = data;
                }
        |       FUNCTION_INV
                {
                    if(inMain == false && inFunction == false)
                    {
                        output<<"method public static void main (java.lang.String[])"<<endl;
                        output<<"max_stack 20"<<endl;
                        output<<"max_locals 20"<<endl;
                        output<<"{"<<endl;
                        inMain = true;
                    }

                    Trace("FUNCTION_INV\n");
                }
        |       L_PARENTHESES EXPRESSION R_PARENTHESES
                {
                    Trace("EXPRESSION PARENTHESES\n");
                    Data* data = new Data();
                    data->type = $2->type;
                    data->value = $2->value;
                    $$ = data;
                }
        |       MINUS EXPRESSION %prec UMINUS
                {
                    Trace("EXPRESSION UNARY_MINUS\n");
                    string temp = $2->type;
                    if(temp != "int" && temp != "float" && temp != "real" && temp != "boolean")
                    {
                        yyerror("Unary minus type error!");
                    }

					output<<"ineg"<<endl;

                    Data* data = new Data();
                    data->type = $2->type;
                    data->value = $2->value;
                    $$ = data;
                }
        |       EXPRESSION MULTIPLICATION EXPRESSION
                {                    
                    Trace("EXPRESSION MULTIPLICATION\n");
                    string temp1 = $1->type, temp2 = $3->type;
                    Data* data = new Data();
                    if(temp1 == "int" && temp2 == "int")
                    {
                        data->type = temp1;
                        // data->value = to_string(stoi($1->value) * stoi($3->value));
                        $$ = data;
                    }
                    else if(temp1 == "float" || temp1 == "real")
                    {
                        if(temp2 == "float" || temp2 == "real")
                        {
                            data->type = temp1;
                            // data->value = to_string(stof($1->value) * stof($3->value));
                            $$ = data;
                        }
                    }
                    else if(temp1 == "boolean" && temp2 == "boolean")
                    {
                        data->type = temp1;
                        // data->value = to_string(stoi($1->value) * stoi($3->value));
                        $$ = data;
                    }
                    else
                    {
                        yyerror("Multiplication type error!");
                    }

					output<<"imul"<<endl;
                }
        |       EXPRESSION DIVISION EXPRESSION
                {
                    Trace("EXPRESSION DIVISION\n");
                    string temp1 = $1->type, temp2 = $3->type;
                    Data* data = new Data();
                    if($3->value == "0")
                    {
                        yyerror("Divide by 0");
                    }
                    if(temp1 == "int" && temp2 == "int")
                    {
                        data->type = temp1;
                        // data->value = to_string(stoi($1->value) / stoi($3->value));
                        $$ = data;
                    }
                    else if(temp1 == "float" || temp1 == "real")
                    {
                        if(temp2 == "float" || temp2 == "real")
                        {
                            data->type = temp1;
                            // data->value = to_string(stof($1->value )/ stof($3->value));
                            $$ = data;
                        }
                    }
                    else if(temp1 == "boolean" && temp2 == "boolean")
                    {
                        data->type = temp1;
                        // data->value = to_string(stoi($1->value) / stoi($3->value));
                        $$ = data;
                    }
                    else
                    {
                        yyerror("Division type error!");
                    }

					output<<"idiv"<<endl;
                }
        |       EXPRESSION MOD EXPRESSION
                {
                    Trace("EXPRESSION MOD\n");
                    string temp1 = $1->type, temp2 = $3->type;
                    Data* data = new Data();
                    if(temp1 != "int")
                    {
                        yyerror("Mod type error! (not int)");
                    }
                    if(temp2 != "int")
                    {
                        yyerror("Mod type error! (not int)");
                    }
                    data->type = "int";
                    // data->value = to_string(stoi($1->value) % stoi($3->value));
                    $$ = data;
					output<<"irem"<<endl;
                }
        |       EXPRESSION PLUS EXPRESSION
                {
                    Trace("EXPRESSION PLUS\n");
                    string temp1 = $1->type, temp2 = $3->type;
                    Data* data = new Data();
                    if(temp1 == "int" && temp2 == "int")
                    {
                        data->type = "int";
                        // data->value = stoi($1->value) + stoi($3->value);
                        $$ = data;
                    }
                    else if(temp1 == "float" || temp1 == "real")
                    {
                        if(temp2 == "float" || temp2 == "real")
                        {
                            data->type = "float";
                            // data->value = to_string(stof($1->value) + stof($3->value));
                            $$ = data;
                        }
                    }
                    else if(temp1 == "boolean" && temp2 == "boolean")
                    {
                        data->type = "boolean";
                        // data->value = to_string(stoi($1->value) + stoi($3->value));
                        $$ = data;
                    }
                    else
                    {
                        yyerror("Plus type error!");
                    }
					output<<"iadd"<<endl;
                }
        |       EXPRESSION MINUS EXPRESSION
                {
                    Trace("EXPRESSION MINUS\n");
                    string temp1 = $1->type, temp2 = $3->type;
                    Data* data = new Data();
                    if(temp1 == "int" && temp2 == "int")
                    {

                        data->type = "int";
                        // data->value = to_string(stoi($1->value) - stoi($3->value));
                        $$ = data;
                    }
                    else if(temp1 == "float" || temp1 == "real")
                    {
                        if(temp2 == "float" || temp2 == "real")
                        {
                            data->type = "int";
                            // data->value = to_string(stof($1->value) - stof($3->value));
                            $$ = data;
                        }
                    }
                    else if(temp1 == "boolean" && temp2 == "boolean")
                    {
                        data->type = "int";
                        // data->value = to_string(stof($1->value) - stof($3->value));
                        $$ = data;
                    }
                    else
                    {
                        yyerror("Minus type error!");
                    }
					output<<"isub"<<endl;
                }
        |       EXPRESSION LESS_THAN EXPRESSION
                {
                    Trace("EXPRESSION LESS_THAN\n");
                    string temp1 = $1->type, temp2 = $3->type;
                    Data* data = new Data();
                    if(temp1 == "int" && temp2 == "int")
                    {
                        data->type = "boolean";
                        data->value = "";
                        $$ = data;
                    }
                    else if(temp1 == "float" || temp1 == "real")
                    {
                        if(temp2 == "float" || temp2 == "real")
                        {
                            data->type = "boolean";
                            data->value = "";
                            $$ = data;
                        }
                    }
                    else if(temp1 == "boolean" && temp2 == "boolean")
                    {
                        data->type = "boolean";
                        data->value = "";
                        $$ = data;
                    }
                    else
                    {
                        yyerror("LESS_THAN type error!");
                    }

					output<<"isub"<<endl;
					output<<"iflt L"<<label<<endl;
					output<<"iconst_0"<<endl;
					output<<"goto L"<<label+1<<endl;
					output<<"L"<<label<<": iconst_1"<<endl;
					output<<"L"<<label+1<<":"<<endl;
                    //在迴圈內
                    if(inLoop == true && inCondition == false)
                    {
                        output<<"ifne L"<<label+2<<endl;
                        exitStack.push_back(label+2);
                        
                    }
					label += 3;
                }
        |       EXPRESSION NO_MORE_THAN EXPRESSION
                {
                    Trace("EXPRESSION NO_MORE_THAN\n");
                    string temp1 = $1->type, temp2 = $3->type;
                    Data* data = new Data();
                    if(temp1 == "int" && temp2 == "int")
                    {
                        data->type = "boolean";
                        data->value = "";
                        $$ = data;
                    }
                    else if(temp1 == "float" || temp1 == "real")
                    {
                        if(temp2 == "float" || temp2 == "real")
                        {
                            data->type = "boolean";
                            data->value = "";
                            $$ = data;
                        }
                    }
                    else if(temp1 == "boolean" && temp2 == "boolean")
                    {
                        data->type = "boolean";
                        data-> value = "";
                        $$ = data;
                    }
                    else
                    {
                        yyerror("NO_MORE_THAN type error!");
                    }

					output<<"isub"<<endl;
					output<<"ifle L"<<label<<endl;
					output<<"iconst_0"<<endl;
					output<<"goto L"<<label+1<<endl;
					output<<"L"<<label<<": iconst_1"<<endl;
					output<<"L"<<label+1<<":"<<endl;
                    //在迴圈內
                    if(inLoop == true && inCondition == false)
                    {
                        output<<"ifne L"<<label+2<<endl;
                        exitStack.push_back(label+2);
                    }
					label += 3;
                }
        |       EXPRESSION NO_LESS_THAN EXPRESSION
                {
                    Trace("EXPRESSION NO_LESS_THAN\n");
                    string temp1 = $1->type, temp2 = $3->type;
                    Data* data = new Data();
                    if(temp1 == "int" && temp2 == "int")
                    {
                        data->type = "boolean";
                        data->value = "";
                        $$ = data;
                    }
                    else if(temp1 == "float" || temp1 == "real")
                    {
                        if(temp2 == "float" || temp2 == "real")
                        {
                            data->type = "boolean";
                            data->value = "";
                            $$ = data;
                        }
                    }
                    else if(temp1 == "boolean" && temp2 == "boolean")
                    {
                        data->type = "boolean";
                        data->value = "";
                        $$ = data;
                    }
                    else
                    {
                        yyerror("NO_LESS_THAN type error!");
                    }

					output<<"isub"<<endl;
					output<<"ifge L"<<label<<endl;
					output<<"iconst_0"<<endl;
					output<<"goto L"<<label+1<<endl;
					output<<"L"<<label<<": iconst_1"<<endl;
					output<<"L"<<label+1<<":"<<endl;
                    //在迴圈內
                    if(inLoop == true && inCondition == false)
                    {
                        output<<"ifne L"<<label+2<<endl;
                        exitStack.push_back(label+2);
                    }
					label += 3;
                }
        |       EXPRESSION MORE_THAN EXPRESSION
                {
                    Trace("EXPRESSION MORE_THAN\n");
                    string temp1 = $1->type, temp2 = $3->type;
                    Data* data = new Data();
                    if(temp1 == "int" && temp2 == "int")
                    {
                        data->type = "boolean";
                        data->value = "";
                        $$ = data;
                    }
                    else if(temp1 == "float" || temp1 == "real")
                    {
                        if(temp2 == "float" || temp2 == "real")
                        {
                            data->type = "boolean";
                            data->value = "";
                            $$ = data;
                        }
                    }
                    else if(temp1 == "boolean" && temp2 == "boolean")
                    {
                        data->type = "boolean";
                        data->value = "";
                        $$ = data;
                    }
                    else
                    {
                        yyerror("EXPRESSION type error!");
                    }
                    
                    // a > b
					output<<"isub"<<endl;   //a - b
					output<<"ifgt L"<<label<<endl;  //if a-b>0, goto Ltrue
					output<<"iconst_0"<<endl;   //false = 0
					output<<"goto L"<<label+1<<endl;    //goto Lexit
					output<<"L"<<label<<": iconst_1"<<endl; //Ltrue: true = 1
					output<<"L"<<label+1<<":"<<endl;    //進行下一步
                    //在迴圈內
                    if(inLoop == true && inCondition == false)
                    {
                        output<<"ifne L"<<label+2<<endl;
                        exitStack.push_back(label+2);
                    }
                    
                    label += 3;
                    
					
                }
        |       EXPRESSION EQUAL EXPRESSION
                {
                    Trace("EXPRESSION EQUAL\n");
                    string temp1 = $1->type, temp2 = $3->type;
                    Data* data = new Data();
                    if(temp1 == "int" && temp2 == "int")
                    {
                        data->type = "boolean";
                        data->value = "";
                        $$ = data;
                    }
                    else if(temp1 == "float" || temp1 == "real")
                    {
                        if(temp2 == "float" || temp2 == "real")
                        {
                            data->type = "boolean";
                            data->value = "";
                            $$ = data;
                        }
                    }
                    else if(temp1 == "boolean" && temp2 == "boolean")
                    {
                        data->type = "boolean";
                        data->value = "";
                        $$ = data;
                    }
                    else if(temp1 == "string" && temp2 == "string")
                    {
                        data->type = "boolean";
                        data->value = "";
                        $$ = data;
                    }
                    else
                    {
                        yyerror("EQUAL type error!");
                    }

					output<<"isub"<<endl;
					output<<"ifeq L"<<label<<endl;
					output<<"iconst_0"<<endl;
					output<<"goto L"<<label+1<<endl;
					output<<"L"<<label<<": iconst_1"<<endl;
					output<<"L"<<label+1<<":"<<endl;
                    //在迴圈內
                    if(inLoop == true && inCondition == false)
                    {
                        output<<"ifne L"<<label+2<<endl;
                        exitStack.push_back(label+2);
                    }
					label += 3;
                }
        |       EXPRESSION NOT_EQUAL EXPRESSION
                {
                    Trace("EXPRESSION NOT_EQUAL\n");
                    string temp1 = $1->type, temp2 = $3->type;
                    Data* data = new Data();
                    if(temp1 == "int" && temp2 == "int")
                    {
                        data->type = "boolean";
                        data->value = "";
                        $$ = data;
                    }
                    else if(temp1 == "float" || temp1 == "real")
                    {
                        if(temp2 == "float" || temp2 == "real")
                        {
                            data->type = "boolean";
                            data->value = "";
                            $$ = data;
                        }
                    }
                    else if(temp1 == "boolean" && temp2 == "boolean")
                    {
                        data->type = "boolean";
                        data->value = "";
                        $$ = data;
                    }
                    else
                    {
                        yyerror("NOT_EQUAL type error!");
                    }

					output<<"isub"<<endl;
					output<<"ifne L"<<label<<endl;
					output<<"iconst_0"<<endl;
					output<<"goto L"<<label+1<<endl;
					output<<"L"<<label<<": iconst_1"<<endl;
					output<<"L"<<label+1<<":"<<endl;
                    //在迴圈內
                    if(inLoop == true && inCondition == false)
                    {
                        output<<"ifne L"<<label+2<<endl;
                        exitStack.push_back(label+2);
                    }
					label += 3;
                }
        |       NOT EXPRESSION
                {
                    Trace("EXPRESSION NOT\n");
                    string temp = $2->type;
                    Data* data = new Data();
                    if(temp != "int" && temp != "float" && temp != "real" && temp != "boolean")
                    {
                        yyerror("NOT type error! (not number)");
                    }
                    
                    if(temp == "int")
                    {
                        data->type = "int";
                        data->value = "";
                        $$ = data;
                    }
                    else if (temp == "float" || temp == "real")
                    {
                        data->type = "float";
                        data->value = "";
                        $$ = data;
                    }
                    else if(temp == "boolean")
                    {
                        data->type = "boolean";
                        data->value = "";
                        $$ = data;
                    }
                    
					output<<"ixor"<<endl;
                }
        |       EXPRESSION AND EXPRESSION
                {
                    Trace("EXPRESSION AND\n");
                    string temp1 = $1->type, temp2 = $3->type;
                    Data* data = new Data();
                    if(temp1 == "int" && temp2 == "int")
                    {
                        data->type = "boolean";
                        data->value = "";
                        $$ = data;
                    }
                    else if(temp1 == "float" || temp1 == "real")
                    {
                        if(temp2 == "float" || temp2 == "real")
                        {
                            data->type = "boolean";
                            data->value = "";
                            $$ = data;
                        }
                    }
                    else if(temp1 == "boolean" && temp2 == "boolean")
                    {
                        data->type = "boolean";
                        data->value = "";
                        $$ = data;
                    }
                    else
                    {
                        yyerror("AND type error!");
                    }

					output<<"iand"<<endl;
                }
        |       EXPRESSION OR EXPRESSION
                {
                    Trace("EXPRESSION OR\n");
                    string temp1 = $1->type, temp2 = $3->type;
                    Data* data = new Data();
                    if(temp1 == "int" && temp2 == "int")
                    {
                        data->type = "boolean";
                        data->value = "";
                        $$ = data;
                    }
                    else if(temp1 == "float" || temp1 == "real")
                    {
                        if(temp2 == "float" || temp2 == "real")
                        {
                            data->type = "boolean";
                            data->value = "";
                            $$ = data;
                        }
                    }
                    else if(temp1 == "boolean" && temp2 == "boolean")
                    {
                        data->type = "boolean";
                        data->value = "";
                        $$ = data;
                    }
                    else
                    {
                        yyerror("OR type error!");
                    }

					output<<"ior"<<endl;
                }
        ;



conditional:    IF 
                {
                    inCondition = true;
                }
                EXPRESSION THEN
                {
                    if(inMain == false && inFunction == false)
                    {
                        output<<"method public static void main (java.lang.String[])"<<endl;
                        output<<"max_stack 20"<<endl;
                        output<<"max_locals 20"<<endl;
                        output<<"{"<<endl;
                        inMain = true;
                    }

                    Trace("conditional\n");
                    string expType = $3->type;
                    if(expType != "boolean")
                    {
                        yyerror("Conditional expression not boolean_expr");
                    }

                    
					output<<"ifeq L"<<label<<endl;  //如果condition為非，要跳到else
                    level++;
                    falseStack.push_back(label);
                    label++;
                    returnTable.push_back(nowTable);
                    addScope();
                    nowTable = symbolTable.size() - 1;
                }
                inBlock 
                {
					output<<"goto L"<<label<<endl;    //goto exit
                    exitStack.push_back(label);
                    label++;
                    dump();
                }
                elseCondition statement
        ;

elseCondition:  ELSE
                {
					output<<"L"<<falseStack[falseStack.size() - 1]<<":"<<endl;  //Lfalse
					falseStack.pop_back();
                    level++;
                    returnTable.push_back(nowTable);
                    addScope();
                    nowTable = symbolTable.size() - 1;
                }
                inBlock END IF
                {
                    output<<"nop"<<endl;
                    output<<"L"<<exitStack[exitStack.size() - 1]<<":"<<endl;    //Lexit
                    exitStack.pop_back();
                    label += 2;
                    dump();
                    inCondition = false;

                }
        |       END IF  //沒有else
                {
                    output<<"nop"<<endl;
                    output<<"L"<<falseStack[falseStack.size() - 1]<<":"<<endl;
                    falseStack.pop_back();
                    output<<"nop"<<endl;
                    output<<"L"<<exitStack[exitStack.size() - 1]<<":"<<endl;
                    exitStack.pop_back();
                    label += 2;
                    inCondition = false;
                }
        ;

loop:           LOOP 
                {
                    if(inMain == false && inFunction == false)
                    {
                        output<<"method public static void main (java.lang.String[])"<<endl;
                        output<<"max_stack 20"<<endl;
                        output<<"max_locals 20"<<endl;
                        output<<"{"<<endl;
                        inMain = true;
                    }


                    Trace("loop\n");
                    level++;
                    returnTable.push_back(nowTable);
                    addScope();
                    nowTable = symbolTable.size() - 1;
                    inLoop = true;

                    //避免兩個Label連在一起
                    output<<"nop"<<endl;
                    output<<"L"<<label<<":"<<endl;  //Lbegin
                    beginStack.push_back(label);
                    label++;

                }
                inBlock 
                {
                    //goto begin
                    output<<"goto L"<<beginStack[beginStack.size()-1]<<endl; 
                    beginStack.pop_back();
                }
                END LOOP
                {
                    inLoop = false;
                   
                
                    output<<"L"<<exitStack[exitStack.size() - 1]<<":"<<endl;  //Lexit
                    exitStack.pop_back();
                    label++;
                    
                    
                    
                    dump();
                }
                statement
        |       FOR DECREASING id COLON CONSTANT_VAL RANGE CONSTANT_VAL
                {
                    if(inMain == false && inFunction == false)
                    {
                        output<<"method public static void main (java.lang.String[])"<<endl;
                        output<<"max_stack 20"<<endl;
                        output<<"max_locals 20"<<endl;
                        output<<"{"<<endl;
                        inMain = true;
                    }

                    Trace("loop\n");
                    string temp1 = $5->type, temp2 = $7->type;
                    if(temp1 != temp2)
                    {
                        yyerror("For loop range is not the same type ( CONSTANT_VAL )");
                    }
                    if(stoi($5->value) < stoi($7->value))
                    {
                        yyerror("not decreasing (a..b,  a < b)");
                    }
                    
                    level++;
                    returnTable.push_back(nowTable);
                    addScope();
                    nowTable = symbolTable.size() - 1;
                    if(inFunction == false)
                    {
                        insert(level, $3, $5->type, "-", "-", false, address);
                        address++;
                    }
                    else
                    {
                        insert(level, $3, $5->type, "-", "-", false, functionAddress);
                        functionAddress++;
                    }
                    
                    


                    //只能用int做?
                    if(temp1 != "int")
                    {
                        yyerror("Constant expression in for loop is not a int.");
                    }

                    vector<int> index = lookup($3);
                    SymbolTable item = symbolTable[index[0]][index[1]];

                    output<<"sipush "<<$5->value<<endl;
                    output<<"istore "<<item.address<<endl;
                    output<<"L"<<label<<":"<<endl;  //Lbegin
                    beginStack.push_back(label);
                    //判斷跳出迴圈條件
                    output<<"iload "<<item.address<<endl;   //把item讀進來
                    output<<"sipush "<<$7->value<<endl; //終止條件
                    output<<"isub"<<endl;   //相減
                    output<<"iflt L"<<label+1<<endl;    //條件成立前往 Ltrue
                    output<<"iconst_0"<<endl;
                    output<<"goto L"<<label+2<<endl;    //goto Lfalse
                    output<<"L"<<label+1<<":"<<endl;    //Ltrue
                    output<<"iconst_1"<<endl;
                    output<<"L"<<label+2<<":"<<endl;    //Lfalse
                    output<<"ifne L"<<label+3<<endl;    //條件不成立前往Lexit
                    exitStack.push_back(label+3);
                    label += 4;
                }
                inBlock
                {
                    vector<int> index = lookup($3);
                    SymbolTable item = symbolTable[index[0]][index[1]];
                    cout<<"index: "<<index[0]<<" "<<index[1]<<endl;
                    //條件+1(i = i + 1)
                    output<<"iload "<<item.address<<endl;
                    output<<"sipush 1"<<endl;
                    output<<"isub"<<endl;
                    output<<"istore "<<item.address<<endl;
                    output<<"goto L"<<beginStack[beginStack.size() - 1]<<endl;
                }
                END FOR
                {
                    beginStack.pop_back();
                    output<<"L"<<exitStack[exitStack.size() - 1]<<":"<<endl;
                    exitStack.pop_back();
                    label++;
                    dump();
                }
                statement
        |       FOR id COLON CONSTANT_VAL RANGE CONSTANT_VAL
                {
                    if(inMain == false && inFunction == false)
                    {
                        output<<"method public static void main (java.lang.String[])"<<endl;
                        output<<"max_stack 20"<<endl;
                        output<<"max_locals 20"<<endl;
                        output<<"{"<<endl;
                        inMain = true;
                    }

                    Trace("loop\n");
                    string temp1 = $4->type, temp2 = $6->type;
                    if(temp1 != temp2)
                    {
                        yyerror("For loop range is not the same type ( CONSTANT_VAL )");
                    }


                    level++;
                    returnTable.push_back(nowTable);
                    addScope();
                    nowTable = symbolTable.size() - 1;
                    if(inFunction == false)
                    {
                        insert(level, $2, $4->type, "-", "-", false, address);
                        address++;
                    }
                    else
                    {
                        insert(level, $2, $4->type, "-", "-", false, functionAddress);
                        functionAddress++;
                    }


                    //只能用int做?
                    if(temp1 != "int")
                    {
                        yyerror("Constant expression in for loop is not a int.");
                    }

                    vector<int> index = lookup($2);
                    SymbolTable item = symbolTable[index[0]][index[1]];

                    output<<"sipush "<<$4->value<<endl;
                    output<<"istore "<<item.address<<endl;
                    output<<"L"<<label<<":"<<endl;  //Lbegin
                    beginStack.push_back(label);
                    //判斷跳出迴圈條件
                    output<<"iload "<<item.address<<endl;   //把item讀進來
                    output<<"sipush "<<$6->value<<endl; //終止條件
                    output<<"isub"<<endl;   //相減
                    output<<"ifgt L"<<label+1<<endl;    //條件成立前往 Ltrue
                    output<<"iconst_0"<<endl;
                    output<<"goto L"<<label+2<<endl;    //goto Lfalse
                    output<<"L"<<label+1<<":"<<endl;    //Ltrue
                    output<<"iconst_1"<<endl;
                    output<<"L"<<label+2<<":"<<endl;    //Lfalse
                    output<<"ifne L"<<label+3<<endl;    //條件不成立前往Lexit
                    exitStack.push_back(label+3);
                    label += 4;
                }
                inBlock 
                {
                    vector<int> index = lookup($2);
                    SymbolTable item = symbolTable[index[0]][index[1]];
                    cout<<"index: "<<index[0]<<" "<<index[1]<<endl;
                    //條件+1(i = i + 1)
                    output<<"iload "<<item.address<<endl;
                    output<<"sipush 1"<<endl;
                    output<<"iadd"<<endl;
                    output<<"istore "<<item.address<<endl;
                    output<<"goto L"<<beginStack[beginStack.size() - 1]<<endl;
                }
                END FOR
                {
 
                    beginStack.pop_back();
                    output<<"L"<<exitStack[exitStack.size() - 1]<<":"<<endl;
                    exitStack.pop_back();
                    label++;
                    dump();
                }
                statement
        ;
                





%%
// Additional C code
#include "lex.yy.cpp"
//FILE *yyin;  /* file descriptor of source program */


void createTable()
{
    symbolTable.resize(1);
    SymbolTable temp;
    temp.level = 0;
    symbolTable[0].push_back(temp);
    /* returnTable.push_back(0); */
}

void addScope()
{
    vector<SymbolTable> temp;
    SymbolTable tempSymbol;
    tempSymbol.level = level;
    symbolTable.push_back(temp);
    symbolTable[symbolTable.size() - 1].push_back(tempSymbol);
}


vector<int> lookup(string s)
{
    vector<int> ans;
    ans.resize(0);

    //目前的table
    for(int i = 0; i < symbolTable[nowTable].size(); i++)
    {
        if(symbolTable[nowTable][i].name == s)
        {
            ans.push_back(nowTable);
            ans.push_back(i);
            return ans;
        }
    }

    //往大的scope找
    if(returnTable.size() == 0)
    {
        for(int j = 1; j < symbolTable[0].size(); j++)
        {
            if(symbolTable[0][j].name == s)
            {
                ans.push_back(0);
                ans.push_back(j);
                return ans;
            }
        }
    }
    else
    {
        for(int i = returnTable.size() - 1; i >= 0; i--)
        {
            for(int j = symbolTable[returnTable[i]].size() - 1; j >= 0; j--)
            {
                //cout<<symbolTable[returnTable[i]][j].name<<endl;
                if(symbolTable[returnTable[i]][j].name == s)
                {
                   ans.push_back(i);
                   ans.push_back(j);
                   return ans;
                }
            }
        }
    }  

    return ans;
}


void insert(int level, string name, string type, string value, string returnType, bool constant, int address)
{
    vector<int> temp = lookup(name);
    //在symbolTable已經有相同名字
    if(temp.size() != 0)
    {
        //可以在新的block裡面覆蓋之前的variable
        if(temp[0] == nowTable)
        {
            cout<<"The name already exists: "<<name<<endl;
            yyerror("Name already exists");
        }
    }

    SymbolTable input;
    input.level = level;
    input.index = symbolTable[nowTable].size() - 1;
    input.type = type;
    input.value = value;
    input.returnType = returnType;
    input.name = name;
    input.constant = constant;
    input.address = address;
    symbolTable[nowTable].push_back(input);

}



void dump()
{
    cout<<"=============================================================================================="<<endl;
    cout<<"Level: "<<symbolTable[nowTable][0].level<<endl;
    cout<<"index\ttype      name      value     returnType  constant  address  parameter"<<endl;
    for(int i = 1; i < symbolTable[nowTable].size(); i++)
    {
        printf("%-8d", symbolTable[nowTable][i].index);
        string s = symbolTable[nowTable][i].type;
        s = symbolTable[nowTable][i].type;
        printf("%-10s", s.data());
        s = symbolTable[nowTable][i].name;
        printf("%-10s", s.data());
        s = symbolTable[nowTable][i].value;
        printf("%-10s", s.data());
        s = symbolTable[nowTable][i].returnType;
        printf("%-12s", s.data());
        if(symbolTable[nowTable][i].constant == true)
        {
            printf("true      ");
        }
        else
        {
            printf("false     ");
        }
        s = symbolTable[nowTable][i].address;
        printf("%-9d", symbolTable[nowTable][i].address);
        if(symbolTable[nowTable][i].parameter.size() == 0)
        {
            cout<<"-";
        }
        else
        {
            for(int j = 0; j < symbolTable[nowTable][i].parameter.size(); j++)
            {
                if(j == symbolTable[nowTable][i].parameter.size() - 1)
                {
                    cout<<symbolTable[nowTable][i].parameter[j];
                }
                else
                {
                    cout<<symbolTable[nowTable][i].parameter[j]<<", ";
                }
            }
        }
        
        cout<<endl;
    }
    cout<<"=============================================================================================="<<endl;
    level--;
    if(returnTable.size() != 0)
    {
        nowTable = returnTable.back();
        returnTable.pop_back();
    }
    
}




int main(int argc, char **argv)
{
    /* open the source program file */
    if (argc != 2) {
        printf ("Usage: sc filename\n");
        exit(1);
    }
    yyin = fopen(argv[1], "r");         /* open input file */

    /* perform parsing */
    for(int i = 0; i < strlen(argv[1]); i++)
    {
        if(argv[1][i] == '.')
        {
            break;
        }
        fileName += argv[1][i];
    }

    createTable();
    output.open(fileName + ".javaa", ios::out | ios::trunc);
    
    
    
    output<<"class "<<fileName<<endl;
    output<<"{"<<endl;
    
    


    if(!output.is_open())
    {
        yyerror("Failed to open file.");
    }

    if (yyparse() == 1)                 /* parsing */
    {    
        yyerror("Parsing error !");     /* syntax error */
    }
    
    output<<"return"<<endl;
    output<<"}"<<endl;

    output<<"}"<<endl;
    output.close();
    dump();
}











