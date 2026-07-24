MONO = mono
VELATO = Release/Velato.exe
.PHONY: ly2midi compile run clean

ly2midi:
	lilypond $(filter %.ly,$(MAKECMDGOALS))

playmidi:
	timidity $(filter %.mid,$(MAKECMDGOALS)) $(filter %.midi,$(MAKECMDGOALS))

compile:
	$(MONO) $(VELATO) $(firstword $(filter-out $@,$(MAKECMDGOALS)))
	mv $(firstword $(filter-out $@,$(MAKECMDGOALS))).exe a.exe
	rm $(firstword $(filter-out $@,$(MAKECMDGOALS))).exe.mdb

run:
	./a.exe

%:
        @:

install:
	git clone git@github.com:rottytooth/Velato && \
	cd Velato && \
	xbuild Rottytooth.Esolang.Velato/Rottytooth.Esolang.Velato.csproj /p:Configuration=Release && \
	cp -r Rottytooth.Esolang.Velato/bin/Release/ ../ && \
	cd ../ && \
	rm -rf Velato/

clean:
	rm -f *.exe *.mdb
