DEL .\tmp\*.o
mkdir .\%1
mkdir .\%1\hyforth
copy *.* .\%1
copy .\hyforth\*.* .\%1\hyforth
h:\cc65\bin\ca65.exe -o tmp\all_C02.o -l tmp\all_C02.txt --cpu 65C02 all.s
h:\cc65\bin\ld65.exe -C os_rom_C02.cfg tmp\all_C02.o -o tmp\os_rom_C02.bin -Ln tmp\os_rom_C02.lbl