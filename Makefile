all:
	flex -o flex.c flex.l
	bison -d bison.y -o bison.c
	gcc flex.c bison.c -lfl -o parse