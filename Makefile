# This Makefile is intended for developers.  Users simply use jbuilder.
WEB = san@math.umons.ac.be:public_html/software

PKGVERSION = $(shell git describe --always --dirty)

all build byte native:
	jbuilder build @install @tests --dev

test runtest:
	jbuilder runtest --force

install uninstall:
	jbuilder $@

doc:
	sed -e 's/%%VERSION%%/$(PKGVERSION)/' src/docker.mli \
	  > _build/default/src/docker.mli
	jbuilder build @doc
	echo '.def { background: #f0f0f0; }' >> _build/default/_doc/odoc.css

upload-doc: doc
	scp -C -r _build/default/_doc/docker-api/Docker $(WEB)/doc
	scp -C _build/default/_doc/odoc.css $(WEB)/

lint:
	opam lint docker-api.opam

clean:
	jbuilder clean
	$(RM) $(wildcard *~ *.pdf *.ps *.png *.svg)

.PHONY: all build byte native test runtest clean
