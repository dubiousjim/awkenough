PREFIX= /usr
AWK= /usr/bin/awk
RUNAWK= runawklite

WARNINGS= -Wall -Wextra -std=gnu99 -pedantic \
      -Wpointer-arith -Wcast-qual -Wcast-align -Wstrict-overflow=4 \
      -Waggregate-return -Wbad-function-cast \
      -Wswitch-default -Wswitch-enum \
      -Wwrite-strings -Wformat=2 \
      -Wshadow -Wuninitialized -Winit-self \
      -Wstrict-prototypes -Wold-style-definition \
      -Werror-implicit-function-declaration \
      -Wredundant-decls \
      -Wnested-externs \
      -Wundef -Wmissing-include-dirs \
      -Wno-unused-function

ifdef STRICT
WARNINGS+=  -Wconversion -Wmissing-prototypes -Wmissing-declarations \
	    -Wunreachable-code -Wunused-function -Wfloat-equal
endif

CFLAGS= -O ${WARNINGS} ${CPPFLAGS}

all: runawk

runawk:
ifeq (${AWK},/bin/busybox)
	${CC} -o runawk -D'AWK="${AWK}"' -D'AWK2="awk"' ${CFLAGS} runawk.c
else
	${CC} -o runawk -D'AWK="${AWK}"' ${CFLAGS} runawk.c
endif

install: all
	install -d -m755 "${DESTDIR}${PREFIX}/bin"
	install -d -m755 "${DESTDIR}${PREFIX}/share/awkenough/utils"
	install -m755 runawk "${DESTDIR}${PREFIX}/bin/${RUNAWK}"
	install -m644 library.awk "${DESTDIR}${PREFIX}/share/awkenough/library.awk"
	cd utils && for f in *; do \
	    sed -e "1 s@#!/[a-z/]*/runawk -f /[a-z/]*/library.awk@#!${PREFIX}/bin/${RUNAWK} -f ${PREFIX}/share/awkenough/library.awk@" "$$f" > "../$$f.new"; \
	    install -m644 "../$$f.new" "${DESTDIR}${PREFIX}/share/awkenough/utils/$$f"; \
	    if [ ! -e "${PREFIX}/bin/$$f" ]; then ln -s "${PREFIX}/share/awkenough/utils/$$f" "${DESTDIR}${PREFIX}/bin/$$f"; fi; \
	done

clean:
	rm -f *.new runawk

