MONO = mono
VELATO = Velato/Rottytooth.Esolang.Velato/bin/Release/Velato.exe
.PHONY: ly2midi compile run clean

ly2midi:
	lilypond $(filter %.ly,$(MAKECMDGOALS))

playmidi:
	timidity $(filter %.mid,$(MAKECMDGOALS)) $(filter %.midi,$(MAKECMDGOALS))

compile:
	$(MONO) $(VELATO) $(firstword $(filter-out $@,$(MAKECMDGOALS)))
	mv $(firstword $(filter-out $@,$(MAKECMDGOALS))).exe a.exe

run:
	./a.exe

%:
        @:

clean:
	rm -f *.exe *.mdb
