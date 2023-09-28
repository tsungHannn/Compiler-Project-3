#ifndef _SYMBOLS_HPP_
#define _SYMBOLS_HPP_

#include <iostream>
#include <vector>
#include <string>
#include <string.h>
#include <iomanip>
#include <fstream>
#include <algorithm>
using namespace std;


class Data
{
public:
	Data();
	~Data();

	string type;
	string value;

};

class SymbolTable
{
	
public:
	SymbolTable();
	~SymbolTable();

	int level;
	int index;
	string type;	//int float real bool string array function procedure
	string name;
	string value;
	string returnType;
	vector <string> parameter;
	bool constant;
	int address;
};

void createTable();	/*create symbolTable*/
vector<int> lookup(string s);	/*�bsymbolTable�̷j�M�O�_���o��id�A���h�^��index[0]:���@��table    index[1]:table��m */

void addScope();
void insert(int level, string name, string type, string value, string returnType, bool constant, int address);
void dump();




#endif