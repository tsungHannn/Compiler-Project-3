
parser: lex.yy.cpp y.tab.cpp symbols.cpp symbols.hpp
	g++ y.tab.cpp symbols.cpp -o parser -ll -std=c++17

lex.yy.cpp: project1.l
	lex -o lex.yy.cpp project1.l

y.tab.cpp: project2.y
	yacc -d -v project2.y -o y.tab.cpp
	
clean:
	rm -f parser *.o lex.yy.cpp y.tab.* y.output *.class *.javaa

build: javaa parser
	./parser $(target).st
	./javaa $(basename $(target)).javaa
	java $(basename $(target))

