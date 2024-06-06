######################################################
# Makefile for sparsenc
######################################################

TOP = .
SRCDIR := src
OBJDIR := src
INCLUDEDIR = include src
INC_PARMS = $(INCLUDEDIR:%=-I%)

UNAME := $(shell uname)
CC := gcc
ifeq ($(UNAME), Darwin)
	SED = gsed
	CC  = gcc-9
	#CC  = clang
	HAS_SSSE3 := $(shell sysctl -a | grep supplementalsse3)
	HAS_AVX2  := $(shell sysctl -a | grep avx2)
endif
ifeq ($(UNAME), Linux)
	SED = sed
	CC  = gcc
	HAS_NEON32  := $(shell grep -i neon /proc/cpuinfo)
	HAS_NEON64  := $(shell uname -a | grep -i aarch64)
	HAS_SSSE3 := $(shell grep -i ssse3 /proc/cpuinfo)
	HAS_AVX2  := $(shell grep -i avx2 /proc/cpuinfo)
endif

GNCENC  := $(OBJDIR)/common.o $(OBJDIR)/bipartite.o $(OBJDIR)/sncEncoder.o $(OBJDIR)/galois.o $(OBJDIR)/gaussian.o $(OBJDIR)/mt19937ar.o

CFLAGS0 = -Winline -std=c99 -lm -O3 -DNDEBUG $(INC_PARMS)
ifneq ($(HAS_NEON32),)
	CFLAGS1 = -DARM_NEON32 -mfloat-abi=hard -mfpu=neon -O3 -std=c99
	GNCENC  := $(OBJDIR)/common.o $(OBJDIR)/bipartite.o $(OBJDIR)/sncEncoder.o $(OBJDIR)/galois_neon.o $(OBJDIR)/gaussian.o $(OBJDIR)/mt19937ar.o
endif
ifneq ($(HAS_NEON64),)
	CFLAGS1 = -DARM_NEON64 -mfloat-abi-hard -mfpu=neon -O3 -std=c99
	GNCENC  := $(OBJDIR)/common.o $(OBJDIR)/bipartite.o $(OBJDIR)/sncEncoder.o $(OBJDIR)/galois_neon.o $(OBJDIR)/gaussian.o $(OBJDIR)/mt19937ar.o
endif
ifneq ($(HAS_SSSE3),)
	CFLAGS1 = -mssse3 -DINTEL_SSSE3
endif
ifneq ($(HAS_AVX2),)
	CFLAGS1 += -mavx2 -DINTEL_AVX2
endif
# Additional compile options
# CFLAGS2 = 

vpath %.h src include
vpath %.c src examples

DEFS    := sparsenc.h common.h galois.h decoderGG.h decoderOA.h decoderBD.h decoderCBD.h decoderPP.h
RECODER := $(OBJDIR)/sncRecoder.o $(OBJDIR)/sncRecoderBATS.o 
DECODER := $(OBJDIR)/sncDecoder.o
GGDEC   := $(OBJDIR)/decoderGG.o 
OADEC   := $(OBJDIR)/decoderOA.o $(OBJDIR)/pivoting.o
BDDEC   := $(OBJDIR)/decoderBD.o $(OBJDIR)/pivoting.o
CBDDEC  := $(OBJDIR)/decoderCBD.o
PPDEC   := $(OBJDIR)/decoderPP.o

.PHONY: all
all: sncDecoder sncDecoderFile sncRecoder2Hop sncRestore

libsparsenc.so: $(GNCENC) $(GGDEC) $(OADEC) $(BDDEC) $(CBDDEC) $(PPDEC) $(RECODER) $(DECODER)
	$(CC) -shared -o libsparsenc.so $^

libsparsenc.a: $(GNCENC) $(GGDEC) $(OADEC) $(BDDEC) $(CBDDEC) $(PPDEC) $(RECODER) $(DECODER)
	ar rcs $@ $^
	
sncRLNC: $(GNCENC) $(GGDEC) $(OADEC) $(BDDEC) $(CBDDEC) $(PPDEC) $(RECODER) $(DECODER) test.RLNC.c
	$(CC) -o $@ $(CFLAGS0) $(CFLAGS1) $^

nhopRLNC_E2E: $(GNCENC) $(GGDEC) $(OADEC) $(BDDEC) $(CBDDEC) $(PPDEC) $(RECODER) $(DECODER) test.e2e.nhopRLNC.c
	$(CC) -o $@ $(CFLAGS0) $(CFLAGS1) $^ -lm

#Test snc decoder
sncDecoders: libsparsenc.so test.decoders.c
	$(CC) -o $@ $(CFLAGS0) $(CFLAGS1) $^ -L. -lsparsenc -lm
#Test snc decoder linked statically
sncDecoderST: $(GNCENC) $(GGDEC) $(OADEC) $(BDDEC) $(CBDDEC) $(PPDEC) $(RECODER) $(DECODER) test.decoders.c
	$(CC) -o $@ $(CFLAGS0) $(CFLAGS1) $^
#Test snc store/restore decoder
sncRestore: libsparsenc.so test.restore.c
	$(CC) -L. -lsparsenc -o $@ $(CFLAGS0) $(CFLAGS1) $^ 
#Test decoder for files
sncDecodersFile: libsparsenc.so test.file.decoders.c
	$(CC) -L. -lsparsenc -o $@ $(CFLAGS0) $(CFLAGS1) $^
#Test recoder
sncRecoder2Hop: libsparsenc.so test.2hopRecoder.c
	$(CC) -L. -lsparsenc -o $@ $(CFLAGS0) $(CFLAGS1) $^
#Test recoder
sncRecoder-n-Hop: libsparsenc.so test.nhopRecoder.c
	$(CC) -o $@ $(CFLAGS0) $(CFLAGS1) $^ -L. -lm -lsparsenc
#Test recoder, statically linked
sncRecoder-n-Hop-ST: $(GNCENC) $(GGDEC) $(OADEC) $(BDDEC) $(CBDDEC) $(PPDEC) $(RECODER) $(DECODER) test.nhopRecoder.c
	$(CC) -o $@ $(CFLAGS0) $(CFLAGS1) $^ -lm
#Test recoder, statically linked
sncRecoder-n-Hop-Gilbert-ST: $(GNCENC) $(GGDEC) $(OADEC) $(BDDEC) $(CBDDEC) $(PPDEC) $(RECODER) $(DECODER) test.nhopRecoder-gilbert.c
	$(CC) -o $@ $(CFLAGS0) $(CFLAGS1) $^ -lm
#Test recoder
sncRecoderFly: libsparsenc.so test.butterfly.c
	$(CC) -L. -lsparsenc -o $@ $(CFLAGS0) $(CFLAGS1) $^

sncHAPmulticast: libsparsenc.so test.HAPmulticast.c
	$(CC) -L. -lsparsenc -o $@ $(CFLAGS0) $(CFLAGS1) $^

sncD2Dmulticast: libsparsenc.so test.D2Dmulticast.c
	$(CC) -L. -lsparsenc -o $@ $(CFLAGS0) $(CFLAGS1) $^

snc2UserD2D: libsparsenc.so test.2UserD2DCoop.c
	$(CC) -L. -lsparsenc -o $@ $(CFLAGS0) $(CFLAGS1) $^

snc2pairD2D: libsparsenc.so test.2pairD2D.c
	$(CC) -L. -lsparsenc -o $@ $(CFLAGS0) $(CFLAGS1) $^

snc4pairD2D: libsparsenc.so test.4pairD2D.c
	$(CC) -L. -lsparsenc -o $@ $(CFLAGS0) $(CFLAGS1) $^

sncRecoderNhopBATS: $(GNCENC) $(GGDEC) $(OADEC) $(BDDEC) $(CBDDEC) $(PPDEC) $(RECODER) $(DECODER) test.batsRecoder.c
	$(CC) -L. -o $@ $(CFLAGS0) $(CFLAGS1) $^ -lm

sncRecoderDynChanNhopBATS: $(GNCENC) $(GGDEC) $(OADEC) $(BDDEC) $(CBDDEC) $(PPDEC) $(RECODER) $(DECODER) test.batsRecoder-dynchan.c
	$(CC) -L. -o $@ $(CFLAGS0) $(CFLAGS1) $^ -lm

sncMatureD2D: $(GNCENC) $(GGDEC) $(OADEC) $(BDDEC) $(CBDDEC) $(PPDEC) $(RECODER) $(DECODER) test.matureD2D.c
	$(CC) -o $@ $(CFLAGS0) $(CFLAGS1) $^

sncBroadcast: $(GNCENC) $(GGDEC) $(OADEC) $(BDDEC) $(CBDDEC) $(PPDEC) $(RECODER) $(DECODER) test.broadcast.c
	$(CC) -o $@ $(CFLAGS0) $(CFLAGS1) $^ -lm

sncMultiPairD2D: $(GNCENC) $(GGDEC) $(OADEC) $(BDDEC) $(CBDDEC) $(PPDEC) $(RECODER) $(DECODER) test.multipairD2D.c
	$(CC) -o $@ $(CFLAGS0) $(CFLAGS1) $^ -lm

sncKeshtkarD2D: $(GNCENC) $(GGDEC) $(OADEC) $(BDDEC) $(CBDDEC) $(PPDEC) $(RECODER) $(DECODER) test.KeshtkarD2D.c
	$(CC) -o $@ $(CFLAGS0) $(CFLAGS1) $^ -lm

sncLeyvaD2D: $(GNCENC) $(GGDEC) $(OADEC) $(BDDEC) $(CBDDEC) $(PPDEC) $(RECODER) $(DECODER) test.LeyvaD2D.c
	$(CC) -o $@ $(CFLAGS0) $(CFLAGS1) $^ -lm

sncMultiPairD2DNoAlter: libsparsenc.so test.multipairD2D_noalter.c
	$(CC) -o $@ $(CFLAGS0) $(CFLAGS1) $^ -L. -lsparsenc -lm

$(OBJDIR)/%.o: $(OBJDIR)/%.c $(DEFS)
	$(CC) -c -fpic -o $@ $< $(CFLAGS0) $(CFLAGS1) $(CFLAGS2)
#$(CC) -c -o $@ $< $(CFLAGS0) $(CFLAGS1) $(CFLAGS2)

.PHONY: clean
clean:
	rm -f *.o $(OBJDIR)/*.o libsparsenc.so libsparsenc.a sncDecoders sncDecoderST sncDecodersFile sncRecoder2Hop sncRecoder-n-Hop sncRecoder-n-Hop-ST sncRecoderFly sncRestore sncRLNC sncHAPmulticast sncD2Dmulticast snc2UserD2D sncRecoderNhopBATS sncRecoderDynChanNhopBATS snc2pairD2D snc4pairD2D sncRecoder-n-Hop-Gilbert-ST nhopRLNC_E2E
	rm -f sncMatureD2D sncBroadcast sncMultiPairD2D sncMultiPairD2DNoAlter sncKeshtkarD2D sncLeyvaD2D

install: libsparsenc.so
	cp include/sparsenc.h /usr/include/
	if [[ `uname -a | grep -o x86_64` == "x86_64" ]]; then \
		cp libsparsenc.so /usr/lib64/; \
	else \
		cp libsparsenc.so /usr/lib/; \
	fi

.PHONY: uninstall
uninstall:
	rm -f /usr/include/sparsenc.h
	if [[ `uname -a | grep -o x86_64` == "X86_64" ]]; then \
		rm -f /usr/lib64/libsparsenc.so; \
	else \
		rm -f /usr/lib/libsparsenc.so; \
	fi
