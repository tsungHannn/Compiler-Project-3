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
vector<int> lookup(string s);	/*在symbolTable裡搜尋是否有這個id，有則回傳index[0]:哪一個table    index[1]:table位置 */

void addScope();
void insert(int level, string name, string type, string value, string returnType, bool constant, int address);
void dump();




#endif