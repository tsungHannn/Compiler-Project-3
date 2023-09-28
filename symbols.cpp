#include "symbols.hpp"


Data::Data()
{
	type = "";
	value = "";
}

Data::~Data()
{

}

SymbolTable::SymbolTable()
{
	level = 0;
	index = 0;
	name = "";
	type = "";
	address = 0;
	constant = false;
	parameter.clear();
}

SymbolTable::~SymbolTable()
{

}



