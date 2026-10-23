DEL .\tmp\*.o
mkdir .\%1
mkdir .\%1\hyforth
copy *.* .\%1
copy .\hyforth\*.* .\%1\hyforth
h:\cc65\bin\ca65.exe -o tmp\all.o -l tmp\all.txt --cpu 65C02 all.s
h:\cc65\bin\ld65.exe -C os_rom.cfg tmp\all.o -o tmp\os_rom.bin -Ln tmp\os_rom.lbl