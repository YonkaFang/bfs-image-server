CV_LIB=-lopencv_core -lopencv_imgproc  -lopencv_highgui                                                                                                                                                                                                                                                                                                                                                                                                                                   
LUA_LIB=-llua
LUA_MAC_LIB=-llua
CFLAGS=-I/usr/include/lua5.1/ --shared -Wall -fPIC -O2

.PHONY: all linux mac

all : 
	@echo Please do \'make PLATFORM\' where PLATFORM is one of these:
	@echo linux mac

linux: opencv.so

mac: opencv.dylib

opencv.dylib : opencv.cpp
	g++  $^ -o $@ $(CFLAGS) $(LIB) $(LUA_MAC_LIB) $(CV_LIB)

opencv.so : opencv.cpp
	g++  $^ -o $@ $(CFLAGS) $(LUA_LIB) $(CV_LIB) 

clean:
	rm -f opencv.so opencv.dylib
                                 